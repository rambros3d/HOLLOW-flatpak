// Hollow relay CPU churn-rate benchmark.
//
// Measures the max sustainable auth/join rate a given CPU can handle before the
// relay's auth latency degrades or failures appear. Outputs per-CPU-tier
// throughput numbers for the capacity calculator.
//
// Method:
//   1. Maintain a steady pool of `--baseline` live connections for realism.
//   2. Drive churn: continuously disconnect one connection and start a new one
//      at rate R conns/sec. Each churn event = 1 full TCP+WS+auth+join cycle.
//   3. Ramp R through a schedule (50, 100, 200, 400, 800, 1600, ...), holding
//      each tier for `--hold-secs` while measuring auth latency + failure rate.
//   4. Stop when p99 auth latency > 1s OR failure rate > 2% sustained.
//   5. Report the highest sustainable rate = CPU's auth throughput ceiling.
//
// Usage:
//   hollow-churntest --target ws://127.0.0.1:8080/ws --baseline 5000 --tiers 50,100,200,400,800,1600

use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use base64::Engine;
use clap::Parser;
use ed25519_dalek::{Signer, SigningKey};
use futures_util::{SinkExt, StreamExt};
use rand::rngs::OsRng;
use serde::Serialize;
use tokio::sync::Mutex;
use tokio::time::{sleep, MissedTickBehavior};
use tokio_tungstenite::tungstenite::Message;

#[derive(Parser, Clone)]
#[command(name = "hollow-churntest")]
struct Args {
    #[arg(long)]
    target: String,

    /// Number of baseline long-lived connections held throughout the test
    #[arg(long, default_value = "5000")]
    baseline: usize,

    /// Distinct rooms for distributing connections
    #[arg(long, default_value = "100")]
    rooms: usize,

    /// Churn rate schedule: comma-separated auths/sec to try in order
    #[arg(long, default_value = "50,100,200,400,800,1600,3200")]
    tiers: String,

    /// Hold each tier for N seconds to get a stable measurement
    #[arg(long, default_value = "60")]
    hold_secs: u64,

    /// Break conditions: stop if sustained failure rate exceeds this (as fraction, e.g. 0.02 = 2%)
    #[arg(long, default_value = "0.02")]
    max_fail_rate: f64,

    /// Break conditions: stop if sustained p99 auth latency exceeds this (ms)
    #[arg(long, default_value = "1000")]
    max_p99_ms: u64,

    /// Skip baseline and run only churn loop (for smaller CPU tests)
    #[arg(long)]
    no_baseline: bool,
}

#[derive(Default)]
struct TierStats {
    success: AtomicU64,
    fail: AtomicU64,
    latency_samples_us: Mutex<Vec<u64>>, // cap at a few thousand for memory
}

#[derive(Clone, Default)]
struct Stats {
    baseline_connected: Arc<AtomicUsize>,
    current_tier: Arc<AtomicU64>,
    tier_stats: Arc<Mutex<Option<Arc<TierStats>>>>,
}

#[derive(Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum ClientMsg<'a> {
    Auth {
        peer_id: &'a str,
        public_key: &'a str,
        timestamp: u64,
        signature: &'a str,
    },
    Join { room: &'a str },
}

#[tokio::main(flavor = "multi_thread")]
async fn main() {
    rustls::crypto::ring::default_provider()
        .install_default()
        .ok();

    let args = Args::parse();
    let tiers: Vec<u64> = args
        .tiers
        .split(',')
        .filter_map(|s| s.trim().parse().ok())
        .collect();

    if tiers.is_empty() {
        eprintln!("No tiers specified");
        std::process::exit(1);
    }

    println!(
        "Target: {}\nBaseline concurrent: {}\nTiers (auths/sec): {:?}\nHold per tier: {}s\nBreak: fail>{:.0}%%, p99>{}ms",
        args.target, args.baseline, tiers, args.hold_secs,
        args.max_fail_rate * 100.0, args.max_p99_ms,
    );

    let stats = Stats::default();

    // Hold baseline connections (non-churning) for realism.
    let mut baseline_handles = Vec::new();
    if !args.no_baseline && args.baseline > 0 {
        println!("\n--- Ramping baseline {} connections ---", args.baseline);
        for i in 0..args.baseline {
            let target = args.target.clone();
            let room = format!("churn-baseline-{}", i % args.rooms);
            let stats_c = stats.clone();
            let h = tokio::spawn(async move {
                run_baseline(target, room, stats_c).await;
            });
            baseline_handles.push(h);
            if i % 200 == 0 && i > 0 {
                sleep(Duration::from_millis(10)).await;
            }
            sleep(Duration::from_micros(2000)).await;
        }
        // Wait for baseline to settle.
        loop {
            let c = stats.baseline_connected.load(Ordering::Relaxed);
            if c >= (args.baseline * 9 / 10) { break; }
            println!("  baseline connected: {}/{}", c, args.baseline);
            sleep(Duration::from_secs(2)).await;
        }
        println!("Baseline stable at {} conns. Starting churn test.", stats.baseline_connected.load(Ordering::Relaxed));
    }

    // Churn loop — for each tier, drive R auths/sec for hold_secs, measure.
    let mut results: Vec<(u64, u64, u64, f64, u64, u64)> = Vec::new();
    // (tier_rate, success, fail, fail_rate, p50_ms, p99_ms)

    for tier in &tiers {
        println!("\n=== Tier: {} auths/sec (hold {}s) ===", tier, args.hold_secs);
        let tier_stats = Arc::new(TierStats {
            success: AtomicU64::new(0),
            fail: AtomicU64::new(0),
            latency_samples_us: Mutex::new(Vec::with_capacity(5000)),
        });
        *stats.tier_stats.lock().await = Some(tier_stats.clone());
        stats.current_tier.store(*tier, Ordering::Relaxed);

        let delay_us = 1_000_000 / *tier;
        let end = Instant::now() + Duration::from_secs(args.hold_secs);
        let mut churn_handles = Vec::new();
        let mut churn_ticker = tokio::time::interval(Duration::from_micros(delay_us));
        churn_ticker.set_missed_tick_behavior(MissedTickBehavior::Skip);

        let reporter_end = end;
        let reporter_stats = tier_stats.clone();
        let reporter = tokio::spawn(async move {
            let mut tick = tokio::time::interval(Duration::from_secs(5));
            tick.set_missed_tick_behavior(MissedTickBehavior::Skip);
            while Instant::now() < reporter_end {
                tick.tick().await;
                let s = reporter_stats.success.load(Ordering::Relaxed);
                let f = reporter_stats.fail.load(Ordering::Relaxed);
                let samples = reporter_stats.latency_samples_us.lock().await;
                let (p50, p99) = percentiles(&samples);
                println!("    [live] ok={} fail={} p50={:.0}ms p99={:.0}ms", s, f, p50 / 1000.0, p99 / 1000.0);
            }
        });

        while Instant::now() < end {
            churn_ticker.tick().await;
            let target = args.target.clone();
            let room = format!("churn-{}-{}", tier, rand::random::<u32>() % args.rooms as u32);
            let stats_c = tier_stats.clone();
            let h = tokio::spawn(async move {
                run_churn_once(target, room, stats_c).await;
            });
            churn_handles.push(h);

            // Drain finished handles periodically to avoid unbounded growth
            if churn_handles.len() > 5000 {
                churn_handles.retain(|h| !h.is_finished());
            }
        }

        reporter.abort();
        // Wait a bit for in-flight to land
        sleep(Duration::from_secs(3)).await;

        let s = tier_stats.success.load(Ordering::Relaxed);
        let f = tier_stats.fail.load(Ordering::Relaxed);
        let total = s + f;
        let fail_rate = if total > 0 { f as f64 / total as f64 } else { 0.0 };
        let samples = tier_stats.latency_samples_us.lock().await;
        let (p50_us, p99_us) = percentiles(&samples);
        let p50_ms = (p50_us / 1000.0) as u64;
        let p99_ms = (p99_us / 1000.0) as u64;

        println!(
            "    Tier {} results: success={} fail={} fail_rate={:.2}% p50={}ms p99={}ms",
            tier, s, f, fail_rate * 100.0, p50_ms, p99_ms
        );
        results.push((*tier, s, f, fail_rate, p50_ms, p99_ms));

        let broken = fail_rate > args.max_fail_rate || p99_ms > args.max_p99_ms;
        if broken {
            println!("    *** BREAK condition hit: fail_rate={:.1}%%, p99={}ms — CPU ceiling reached ***",
                     fail_rate * 100.0, p99_ms);
            break;
        }
    }

    // Tear down baseline
    for h in baseline_handles {
        h.abort();
    }

    // Final report
    println!("\n\n============= FINAL =============");
    println!("{:<10} {:<10} {:<10} {:<12} {:<10} {:<10}", "tier", "success", "fail", "fail_rate", "p50_ms", "p99_ms");
    for (tier, s, f, fr, p50, p99) in &results {
        println!("{:<10} {:<10} {:<10} {:<12.2} {:<10} {:<10}",
                 tier, s, f, fr * 100.0, p50, p99);
    }
    // The sustainable tier is the highest with fail_rate <= max and p99 <= max.
    let sustainable = results.iter()
        .filter(|(_, _, _, fr, _, p99)| *fr <= args.max_fail_rate && *p99 <= args.max_p99_ms)
        .map(|(t, _, _, _, _, _)| *t)
        .max();
    match sustainable {
        Some(r) => println!("\n>>> MAX SUSTAINABLE CHURN RATE: {} auths/sec <<<", r),
        None => println!("\n>>> All tiers failed — start lower <<<"),
    }
}

fn percentiles(samples: &[u64]) -> (f64, f64) {
    if samples.is_empty() { return (0.0, 0.0); }
    let mut s = samples.to_vec();
    s.sort_unstable();
    let p50 = s[s.len() * 50 / 100] as f64;
    let p99 = s[(s.len() * 99 / 100).min(s.len() - 1)] as f64;
    (p50, p99)
}

async fn run_baseline(target: String, room: String, stats: Stats) {
    let _ = do_auth_and_join(&target, &room, None).await;
    stats.baseline_connected.fetch_add(1, Ordering::Relaxed);
    // Keep the connection open via a simple sleep — the socket stays alive until abort
    sleep(Duration::from_secs(86400)).await;
}

async fn run_churn_once(target: String, room: String, tier_stats: Arc<TierStats>) {
    let start = Instant::now();
    match do_auth_and_join(&target, &room, Some(Duration::from_secs(10))).await {
        Ok(_) => {
            let elapsed_us = start.elapsed().as_micros() as u64;
            tier_stats.success.fetch_add(1, Ordering::Relaxed);
            let mut samples = tier_stats.latency_samples_us.lock().await;
            if samples.len() < 5000 {
                samples.push(elapsed_us);
            }
        }
        Err(_) => {
            tier_stats.fail.fetch_add(1, Ordering::Relaxed);
        }
    }
}

/// Perform TCP connect + WS upgrade + auth + join. Return Ok only after auth_ok + join sent.
/// The connection is immediately dropped after success (this is churn — short-lived).
async fn do_auth_and_join(target: &str, room: &str, timeout: Option<Duration>) -> Result<(), String> {
    let signing_key = SigningKey::generate(&mut OsRng);
    let verifying_key = signing_key.verifying_key();
    let pubkey_raw = verifying_key.to_bytes();

    let mut pubkey_proto = Vec::with_capacity(36);
    pubkey_proto.extend_from_slice(&[0x08, 0x01, 0x12, 0x20]);
    pubkey_proto.extend_from_slice(&pubkey_raw);
    let pubkey_b64 = base64::engine::general_purpose::STANDARD.encode(&pubkey_proto);

    let mut multihash = Vec::with_capacity(2 + pubkey_proto.len());
    multihash.push(0x00);
    multihash.push(pubkey_proto.len() as u8);
    multihash.extend_from_slice(&pubkey_proto);
    let peer_id = bs58::encode(&multihash).with_alphabet(bs58::Alphabet::BITCOIN).into_string();

    let connect_fut = tokio_tungstenite::connect_async(target);
    let ws_stream = if let Some(t) = timeout {
        tokio::time::timeout(t, connect_fut).await
            .map_err(|_| "timeout".to_string())?
            .map_err(|e| format!("ws: {e}"))?.0
    } else {
        connect_fut.await.map_err(|e| format!("ws: {e}"))?.0
    };
    let (mut write, mut read) = ws_stream.split();

    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    let signed_msg = format!("hollow-ws-auth:{}:{}", peer_id, timestamp);
    let signature = signing_key.sign(signed_msg.as_bytes());
    let sig_b64 = base64::engine::general_purpose::STANDARD.encode(signature.to_bytes());

    let auth = ClientMsg::Auth {
        peer_id: &peer_id,
        public_key: &pubkey_b64,
        timestamp,
        signature: &sig_b64,
    };
    let auth_json = serde_json::to_string(&auth).unwrap();
    write.send(Message::Text(auth_json.into())).await.map_err(|e| format!("send: {e}"))?;

    let auth_ok = if let Some(t) = timeout {
        tokio::time::timeout(t, read.next()).await.map_err(|_| "auth timeout".to_string())?
    } else {
        read.next().await
    };
    let ok = matches!(auth_ok, Some(Ok(Message::Text(ref t))) if t.contains("auth_ok"));
    if !ok {
        return Err("auth failed".to_string());
    }

    let join = ClientMsg::Join { room };
    let join_json = serde_json::to_string(&join).unwrap();
    write.send(Message::Text(join_json.into())).await.map_err(|e| format!("join: {e}"))?;

    Ok(())
}
