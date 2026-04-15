#!/usr/bin/env python3
"""
Hollow relay capacity calculator.

Given a server's specs (RAM, network bandwidth, CPU cores/threads, price,
optional setup fee, optional monthly traffic cap), prints how many concurrent
Hollow users that server can realistically hold and the per-user cost.

Uses the measurements from the 2026-04-15 load test and the planned
Phase 7 optimizations (TCP buffer tuning, bounded mpsc, native TLS,
permessage-deflate, binary framing).

Usage:
    python capacity.py --ram 256 --bw 10 --cores 24 --threads 48 --price 232 --setup 562 --name "Hetzner EX130-R"
    python capacity.py --ram 192 --bw 3 --cores 12 --threads 24 --price 248 --name "GThost DET-SM6029TP-HTR-26-2"
    python capacity.py --help

Output is a single-line summary designed to paste into a txt for comparison.
"""

from __future__ import annotations

import argparse
import sys


# ---- Measured + projected constants (see HOLLOW_PLAN.md Phase 7) ----

# Baseline measurements from load test (no optimizations applied).
RAM_KB_PER_CONN_BASELINE_NGINX = 186
RAM_KB_PER_CONN_BASELINE_NATIVE = 133

# Post-optimization (TCP buffer tuning + bounded mpsc + native TLS).
# TCP buffers capped at 16 KB recv + 16 KB send = 32 KB kernel.
# Rust process state ~5-13 KB. Total ~30 KB with safety margin.
RAM_KB_PER_CONN_OPTIMIZED = 30

# Per-conn idle bandwidth (bytes/sec), sustained 24/7 average.
# Baseline = raw JSON over WS. After permessage-deflate + binary framing,
# typical Hollow chat payloads shrink ~3x (50 → 17 B/sec).
BW_BYTES_PER_CONN_BASELINE = 50
BW_BYTES_PER_CONN_OPTIMIZED = 17

# Realistic mixed traffic: 90% idle + 10% actively chatting
# sending ~10x the idle rate to ~30 room-mates.
# Mixed avg per conn, post-optimization, sustained 24/7.
BW_BYTES_PER_CONN_REALISTIC_OPTIMIZED = 33

# OS overhead reserve (GB) — don't count this against the per-conn budget.
OS_RESERVE_GB = 1

# CPU cost per handshake (Ed25519 verify + room join + HashMap inserts).
# Measured: ~200 auths/sec on 4 modest vCores brought load avg to 18.6.
# Extrapolated: per core, a modern CPU handles ~200-400 auths/sec steady-state.
# Auction Xeon E5 ~150/core-sec, modern Xeon Gold / i5-13xxx ~400/core-sec.
# We use a conservative middle value; see --cpu-generation for tuning.
CPU_AUTHS_PER_THREAD_PER_SEC_OLD = 460   # Xeon E5-v3 (2014), Ryzen 1000-2000 (2017)
CPU_AUTHS_PER_THREAD_PER_SEC_MID = 620   # Ryzen 3000-5000, Xeon E-2xxx, Silver 4310
CPU_AUTHS_PER_THREAD_PER_SEC_NEW = 800   # Genoa MEASURED, i5-13500, Xeon Gold, Ryzen 7000

# Assume typical peak reconnect rate: 0.1% of concurrent users / sec.
# (Mass reconnect after a network blip; steady-state is much lower.)
RECONNECT_RATE_PCT_PER_SEC = 0.0005

# Peak concurrency vs registered users: at scale, typically 20-30% of
# registered users are online at peak. We default to 25% for projections.
PEAK_CONCURRENCY_PCT = 0.25


# ---- Scenarios ----

def compute_ram_cap(ram_gb: float, kb_per_conn: int) -> int:
    """Max concurrent conns allowed by RAM, after OS reserve."""
    usable_gb = max(0.0, ram_gb - OS_RESERVE_GB)
    usable_bytes = usable_gb * 1024 * 1024 * 1024
    return int(usable_bytes // (kb_per_conn * 1024))


def compute_bandwidth_cap(bw_gbps: float, bytes_per_conn_per_sec: int) -> int:
    """Max concurrent conns allowed by sustained network bandwidth."""
    bw_bytes_per_sec = bw_gbps * 1_000_000_000 / 8  # Gbps → B/s
    return int(bw_bytes_per_sec // bytes_per_conn_per_sec)


def compute_cpu_cap(threads: int, auths_per_thread_per_sec: int) -> int:
    """Max concurrent conns allowed by CPU, given expected reconnect churn.

    Assumes steady-state reconnect rate consumes a fraction of CPU; we give
    the relay ~50% of CPU headroom for churn before calling it CPU-bound.
    """
    auths_per_sec_budget = threads * auths_per_thread_per_sec * 0.5
    return int(auths_per_sec_budget / RECONNECT_RATE_PCT_PER_SEC)


def compute_traffic_monthly_gb(concurrent_conns: int, bytes_per_conn_per_sec: int) -> float:
    """Sustained monthly outbound traffic at this concurrency."""
    bytes_per_month = concurrent_conns * bytes_per_conn_per_sec * 86400 * 30
    return bytes_per_month / 1_000_000_000  # GB


def pick_cpu_rate(generation: str) -> int:
    return {
        "old": CPU_AUTHS_PER_THREAD_PER_SEC_OLD,
        "mid": CPU_AUTHS_PER_THREAD_PER_SEC_MID,
        "new": CPU_AUTHS_PER_THREAD_PER_SEC_NEW,
    }[generation]


def fmt_n(n: int) -> str:
    """Format 3_456_789 as '3.46M', 12_345 as '12.3k'."""
    if n >= 1_000_000:
        return f"{n/1_000_000:.2f}M"
    if n >= 1_000:
        return f"{n/1_000:.1f}k"
    return str(n)


def fmt_usd(x: float, sig: int = 6) -> str:
    if x < 0.001:
        return f"${x:.{sig}f}"
    if x < 1:
        return f"${x:.4f}"
    return f"${x:,.2f}"


def main() -> int:
    p = argparse.ArgumentParser(
        description="Hollow relay capacity calculator. Outputs a one-line summary per server.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument("--ram", type=float, required=True, help="RAM in GB (e.g. 256)")
    p.add_argument("--bw", type=float, required=True, help="Network bandwidth in Gbps (e.g. 10 for 10 Gbit port, 0.4 for 400 Mbit)")
    p.add_argument("--cores", type=int, default=0, help="Physical CPU cores (unused in calc but logged)")
    p.add_argument("--threads", type=int, required=True, help="CPU threads / vCPUs")
    p.add_argument("--price", type=float, required=True, help="Monthly price in USD")
    p.add_argument("--setup", type=float, default=0, help="One-time setup fee USD (default 0)")
    p.add_argument("--traffic-tb", type=float, default=0, help="Free monthly traffic cap in TB (0 = unmetered)")
    p.add_argument("--overage-per-tb", type=float, default=1.0, help="USD per TB over the cap (default $1, Hetzner rate)")
    p.add_argument("--cpu-generation", choices=["old", "mid", "new"], default="mid",
                   help="CPU generation: old=pre-2018 (Xeon E5-v3/v4, Ryzen 1000-2000), mid=2018-2022 (Xeon Silver, Ryzen 3000-5000), new=2023+ (Xeon Gold, i5-13xxx, Ryzen 7000+). Default: mid.")
    p.add_argument("--name", type=str, default="server", help="Server name for the output line")
    p.add_argument("--months", type=int, default=12, help="Months to amortize setup fee over (default 12)")
    p.add_argument("--scenario", choices=["baseline", "optimized", "both"], default="both",
                   help="baseline = current relay code, optimized = Phase 7 optimizations applied (default both)")
    p.add_argument("--bw-mode", choices=["idle", "realistic"], default="realistic",
                   help="idle = heartbeat only, realistic = 10%% of users actively chatting (default)")
    p.add_argument("--format", choices=["line", "full"], default="full",
                   help="line = one-liner for pasting into txt, full = detailed breakdown")
    args = p.parse_args()

    cpu_rate = pick_cpu_rate(args.cpu_generation)

    results = {}
    scenarios = [args.scenario] if args.scenario != "both" else ["baseline", "optimized"]

    for scenario in scenarios:
        if scenario == "baseline":
            ram_kb = RAM_KB_PER_CONN_BASELINE_NATIVE
            bw_bytes = BW_BYTES_PER_CONN_BASELINE if args.bw_mode == "idle" else BW_BYTES_PER_CONN_BASELINE * 0.66
        else:
            ram_kb = RAM_KB_PER_CONN_OPTIMIZED
            bw_bytes = (BW_BYTES_PER_CONN_OPTIMIZED if args.bw_mode == "idle"
                        else BW_BYTES_PER_CONN_REALISTIC_OPTIMIZED)

        ram_cap = compute_ram_cap(args.ram, ram_kb)
        bw_cap = compute_bandwidth_cap(args.bw, bw_bytes)
        cpu_cap = compute_cpu_cap(args.threads, cpu_rate)

        real_cap = min(ram_cap, bw_cap, cpu_cap)
        bottleneck = min(
            [("RAM", ram_cap), ("BW", bw_cap), ("CPU", cpu_cap)],
            key=lambda x: x[1]
        )[0]

        monthly_traffic_gb = compute_traffic_monthly_gb(real_cap, int(bw_bytes))
        monthly_traffic_tb = monthly_traffic_gb / 1000

        # Overage cost
        if args.traffic_tb > 0 and monthly_traffic_tb > args.traffic_tb:
            overage_tb = monthly_traffic_tb - args.traffic_tb
            overage_cost = overage_tb * args.overage_per_tb
        else:
            overage_tb = 0
            overage_cost = 0

        effective_monthly = args.price + overage_cost + (args.setup / args.months)
        per_user_cost = effective_monthly / real_cap if real_cap > 0 else float("inf")
        registered_users = int(real_cap / PEAK_CONCURRENCY_PCT)  # accounting for peak vs DAU

        results[scenario] = {
            "ram_cap": ram_cap,
            "bw_cap": bw_cap,
            "cpu_cap": cpu_cap,
            "real_cap": real_cap,
            "bottleneck": bottleneck,
            "monthly_traffic_tb": monthly_traffic_tb,
            "overage_tb": overage_tb,
            "overage_cost": overage_cost,
            "effective_monthly": effective_monthly,
            "per_user_cost": per_user_cost,
            "registered_users": registered_users,
        }

    if args.format == "line":
        # Compact one-liner designed for pasting into a txt to compare servers.
        if "optimized" in results:
            r = results["optimized"]
            print(
                f"{args.name} | ${args.price}/mo"
                + (f" (+${args.setup} setup)" if args.setup > 0 else "")
                + f" | {args.ram:g}GB/{args.bw:g}Gbps/{args.threads}t"
                + f" | cap={fmt_n(r['real_cap'])} ({r['bottleneck']}-bound)"
                + f" | registered={fmt_n(r['registered_users'])}"
                + f" | {fmt_usd(r['per_user_cost'])}/user/mo"
                + (f" | traffic={r['monthly_traffic_tb']:.1f}TB/mo" if r['monthly_traffic_tb'] >= 1 else "")
                + (f" (+${r['overage_cost']:.0f} overage)" if r['overage_cost'] > 0 else "")
            )
        else:
            r = results["baseline"]
            print(
                f"{args.name} | ${args.price}/mo | cap={fmt_n(r['real_cap'])} ({r['bottleneck']}-bound)"
                f" | {fmt_usd(r['per_user_cost'])}/user/mo (BASELINE)"
            )
    else:
        # Full breakdown.
        print(f"\n=== {args.name} ===")
        print(f"  Specs:  RAM {args.ram:g} GB | BW {args.bw:g} Gbps | CPU {args.cores}c/{args.threads}t ({args.cpu_generation}-gen)")
        print(f"  Cost:   ${args.price}/mo"
              + (f" + ${args.setup} setup (amortized over {args.months} mo = +${args.setup/args.months:.2f}/mo)" if args.setup > 0 else "")
              + (f" | {args.traffic_tb:g} TB/mo free, ${args.overage_per_tb}/TB over" if args.traffic_tb > 0 else " | unmetered"))
        print(f"  Mode:   {args.bw_mode} bandwidth")
        print()

        for scenario, r in results.items():
            tag = "CURRENT CODE" if scenario == "baseline" else "POST-OPTIMIZATION (Phase 7)"
            print(f"  --- {tag} ---")
            print(f"    RAM ceiling:       {fmt_n(r['ram_cap'])} conns")
            print(f"    Bandwidth ceiling: {fmt_n(r['bw_cap'])} conns")
            print(f"    CPU ceiling:       {fmt_n(r['cpu_cap'])} conns")
            print(f"    >> REAL ceiling:   {fmt_n(r['real_cap'])} conns ({r['bottleneck']}-bound)")
            print(f"       -> ~{fmt_n(r['registered_users'])} registered users (at {int(PEAK_CONCURRENCY_PCT*100)}% peak concurrency)")
            print(f"    Sustained traffic: {r['monthly_traffic_tb']:.2f} TB/mo at ceiling")
            if r['overage_cost'] > 0:
                print(f"    ** Traffic overage: {r['overage_tb']:.1f} TB → ${r['overage_cost']:.0f}/mo extra")
            print(f"    Effective cost:    ${r['effective_monthly']:.2f}/mo")
            print(f"    Per-user cost:     {fmt_usd(r['per_user_cost'])}/user/mo")
            print()

    return 0


if __name__ == "__main__":
    sys.exit(main())
