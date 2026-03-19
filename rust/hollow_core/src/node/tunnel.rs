//! Embedded Shadowsocks tunnel for censorship bypass.
//!
//! When proxy mode is enabled, starts local TCP tunnels that forward
//! traffic through a Shadowsocks server on the VPS. TSPU sees only
//! random noise on port 443 — libp2p's protocol fingerprint is hidden.
//!
//! Two tunnels run simultaneously:
//! - localhost:14001 → relay 141.227.186.209:4001 (libp2p relay)
//! - localhost:18080 → signaling 141.227.186.209:8080 (HTTP signaling API)

use std::net::SocketAddr;
use std::sync::Arc;

use shadowsocks_service::shadowsocks::config::{Mode, ServerConfig};
use shadowsocks_service::shadowsocks::crypto::CipherKind;
use shadowsocks_service::shadowsocks::relay::socks5::Address;
use shadowsocks_service::shadowsocks::ServerAddr;

use shadowsocks_service::config::ServerInstanceConfig;
use shadowsocks_service::local::context::ServiceContext;
use shadowsocks_service::local::loadbalancing::PingBalancerBuilder;
use shadowsocks_service::local::tunnel::server::TunnelBuilder;

// ── Configuration ─────────────────────────────────────────────
// The Shadowsocks server runs on the VPS alongside the Haven relay.
// Password is not a secret — the goal is protocol obfuscation, not
// hiding the server address (TSPU already knows the IP).

const SS_SERVER_ADDR: &str = "141.227.186.209";
const SS_SERVER_PORT: u16 = 443;
const SS_METHOD: CipherKind = CipherKind::AEAD2022_BLAKE3_AES_256_GCM;

// TODO: Replace with actual key generated on VPS via:
//   ssservice genkey -m 2022-blake3-aes-256-gcm
const SS_PASSWORD: &str = "Xt2Zag/6cWLSYEYru4b14d98R7QaAn6WBc5lHnD44/8=";

// Local tunnel endpoints (Haven connects to these instead of the real relay).
const LOCAL_RELAY_PORT: u16 = 14001;
const LOCAL_SIGNALING_PORT: u16 = 18080;

// Remote destinations (where the SS server forwards decrypted traffic).
// Use localhost since ssserver runs on the same machine as the relay.
const REMOTE_RELAY_ADDR: &str = "127.0.0.1";
const REMOTE_RELAY_PORT: u16 = 4001;
const REMOTE_SIGNALING_ADDR: &str = "127.0.0.1";
const REMOTE_SIGNALING_PORT: u16 = 8080;

/// Start the Shadowsocks tunnels. Returns join handles for both tunnel tasks.
/// Must be called before the swarm starts dialing the relay.
pub(crate) async fn start_tunnels() -> Result<Vec<tokio::task::JoinHandle<()>>, String> {
    let server_config = ServerConfig::new(
        SocketAddr::new(SS_SERVER_ADDR.parse().unwrap(), SS_SERVER_PORT),
        SS_PASSWORD.to_string(),
        SS_METHOD,
    )
    .map_err(|e| format!("Failed to create SS server config: {e}"))?;

    let context = Arc::new(ServiceContext::new());
    let mut handles = Vec::new();

    // Tunnel 1: relay (libp2p TCP)
    let relay_handle = start_single_tunnel(
        context.clone(),
        server_config.clone(),
        LOCAL_RELAY_PORT,
        REMOTE_RELAY_ADDR,
        REMOTE_RELAY_PORT,
    )
    .await?;
    handles.push(relay_handle);

    // Tunnel 2: signaling (HTTP API)
    let sig_handle = start_single_tunnel(
        context,
        server_config,
        LOCAL_SIGNALING_PORT,
        REMOTE_SIGNALING_ADDR,
        REMOTE_SIGNALING_PORT,
    )
    .await?;
    handles.push(sig_handle);

    hollow_log!("[HOLLOW] [PROXY] Shadowsocks tunnels started (relay=127.0.0.1:{LOCAL_RELAY_PORT}, signaling=127.0.0.1:{LOCAL_SIGNALING_PORT})");

    Ok(handles)
}

/// Start a single tunnel: listen on `local_port`, forward through SS server to `remote_addr:remote_port`.
async fn start_single_tunnel(
    context: Arc<ServiceContext>,
    server_config: ServerConfig,
    local_port: u16,
    remote_addr: &str,
    remote_port: u16,
) -> Result<tokio::task::JoinHandle<()>, String> {
    let forward_addr = Address::SocketAddress(SocketAddr::new(
        remote_addr.parse().unwrap(),
        remote_port,
    ));
    let client_addr = ServerAddr::SocketAddr(SocketAddr::new(
        "127.0.0.1".parse().unwrap(),
        local_port,
    ));

    // Build the PingBalancer with our single SS server.
    let mut balancer_builder = PingBalancerBuilder::new(context.clone(), Mode::TcpOnly);
    balancer_builder.add_server(ServerInstanceConfig::with_server_config(server_config));
    let balancer = balancer_builder
        .build()
        .await
        .map_err(|e| format!("Failed to build SS balancer: {e}"))?;

    // Build and run the tunnel.
    let tunnel = TunnelBuilder::new(forward_addr, client_addr, balancer)
        .build()
        .await
        .map_err(|e| format!("Failed to build SS tunnel on port {local_port}: {e}"))?;

    let handle = tokio::spawn(async move {
        if let Err(e) = tunnel.run().await {
            hollow_log!("[HOLLOW] [PROXY] Tunnel on port {local_port} stopped: {e}");
        }
    });

    Ok(handle)
}

/// The relay multiaddr that libp2p should dial when proxy is enabled.
pub(crate) const PROXY_RELAY_ADDR: &str = "/ip4/127.0.0.1/tcp/14001";

/// The signaling URL to use when proxy is enabled.
pub(crate) const PROXY_SIGNALING_URL: &str = "http://127.0.0.1:18080";
