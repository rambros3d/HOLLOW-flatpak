use std::time::Duration;

use libp2p::futures::StreamExt;
use libp2p::{identity, mdns, noise, swarm::SwarmEvent, tcp, yamux, Multiaddr, SwarmBuilder};
use tokio::sync::mpsc;

/// A discovered peer on the local network.
pub(crate) struct DiscoveredPeer {
    pub peer_id: String,
    pub addresses: Vec<String>,
}

/// Events emitted by the network node.
pub(crate) enum NetworkEvent {
    PeerDiscovered { peer: DiscoveredPeer },
    PeerExpired { peer_id: String },
    Listening { address: String },
    Error { message: String },
}

/// Our libp2p network behaviour — just mDNS for now.
#[derive(libp2p::swarm::NetworkBehaviour)]
struct HavenBehaviour {
    mdns: mdns::tokio::Behaviour,
}

/// Build and spawn the libp2p swarm. Returns the local peer ID and a join handle.
pub(crate) async fn spawn_node(
    keypair: identity::Keypair,
    event_tx: mpsc::Sender<NetworkEvent>,
) -> Result<(String, tokio::task::JoinHandle<()>), String> {
    let swarm = SwarmBuilder::with_existing_identity(keypair)
        .with_tokio()
        .with_tcp(
            tcp::Config::default(),
            noise::Config::new,
            yamux::Config::default,
        )
        .map_err(|e| format!("TCP setup failed: {e}"))?
        .with_behaviour(|key| {
            let mdns_config = mdns::Config {
                ttl: Duration::from_secs(300),
                query_interval: Duration::from_secs(5),
                enable_ipv6: false,
            };
            let mdns = mdns::tokio::Behaviour::new(mdns_config, key.public().to_peer_id())
                .expect("Failed to create mDNS behaviour");
            Ok(HavenBehaviour { mdns })
        })
        .map_err(|e| format!("Behaviour setup failed: {e}"))?
        .build();

    let peer_id_str = swarm.local_peer_id().to_string();
    let handle = tokio::spawn(run_swarm(swarm, event_tx));

    Ok((peer_id_str, handle))
}

/// The main swarm event loop. Runs until the task is aborted.
async fn run_swarm(
    mut swarm: libp2p::Swarm<HavenBehaviour>,
    event_tx: mpsc::Sender<NetworkEvent>,
) {
    // Listen on all interfaces, random port.
    let listen_addr: Multiaddr = "/ip4/0.0.0.0/tcp/0".parse().unwrap();
    if let Err(e) = swarm.listen_on(listen_addr) {
        let _ = event_tx
            .send(NetworkEvent::Error {
                message: format!("Failed to listen: {e}"),
            })
            .await;
        return;
    }

    loop {
        match swarm.select_next_some().await {
            SwarmEvent::NewListenAddr { address, .. } => {
                let _ = event_tx
                    .send(NetworkEvent::Listening {
                        address: address.to_string(),
                    })
                    .await;
            }
            SwarmEvent::Behaviour(HavenBehaviourEvent::Mdns(mdns::Event::Discovered(peers))) => {
                for (peer_id, addr) in peers {
                    let _ = event_tx
                        .send(NetworkEvent::PeerDiscovered {
                            peer: DiscoveredPeer {
                                peer_id: peer_id.to_string(),
                                addresses: vec![addr.to_string()],
                            },
                        })
                        .await;
                }
            }
            SwarmEvent::Behaviour(HavenBehaviourEvent::Mdns(mdns::Event::Expired(peers))) => {
                for (peer_id, _addr) in peers {
                    let _ = event_tx
                        .send(NetworkEvent::PeerExpired {
                            peer_id: peer_id.to_string(),
                        })
                        .await;
                }
            }
            _ => {}
        }
    }
}
