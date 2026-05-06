use std::collections::HashMap;

use tokio::sync::mpsc;

use super::crypto_handler::{peer_is_reachable, send_message_to_peer};
use super::types::*;

/// Handle a WebRTC broadcast received from a gossip neighbor.
/// Checks all overlays for the broadcast_id, and relays to gossip targets if TTL > 0.
pub(crate) async fn handle_webrtc_broadcast_received(
    gossip_overlays: &mut HashMap<String, super::gossip::GossipOverlay>,
    event_tx: &mpsc::Sender<NetworkEvent>,
    webrtc_peers: &std::collections::HashSet<String>,
    broadcast_id: String,
    ttl: u8,
    origin_peer_id: String,
    sender_peer_id: String,
    temp_path: String,
    total_size: u64,
    kind: String,
    shard_index: u16,
) {
    // Find which server this broadcast belongs to by checking overlays.
    // For now, check all overlays for the broadcast_id.
    let mut relayed = false;
    for overlay in gossip_overlays.values_mut() {
        if overlay.should_relay_broadcast(&broadcast_id) {
            if ttl > 0 {
                let relay_targets = overlay.get_relay_targets(Some(&sender_peer_id));
                for target in &relay_targets {
                    if webrtc_peers.contains(target) {
                        let _ = event_tx.send(NetworkEvent::GossipRelayFile {
                            broadcast_id: broadcast_id.clone(),
                            ttl: ttl - 1,
                            origin_peer_id: origin_peer_id.clone(),
                            file_path: temp_path.clone(),
                            total_size,
                            kind: kind.clone(),
                            shard_index,
                            exclude_peer_id: sender_peer_id.clone(),
                            server_id: overlay.server_id.clone(),
                            channel_id: String::new(),
                        }).await;
                    }
                }
            }
            relayed = true;
            break;
        }
    }
    if !relayed {
        hollow_log!("[HOLLOW-GOSSIP] Broadcast {broadcast_id} already seen or no overlay, skipping relay");
    }
}

/// Handle gossip overlay rotation timer tick.
/// Rotates neighbors for large servers and emits connect/disconnect events.
pub(crate) async fn handle_gossip_rotation(
    gossip_overlays: &mut HashMap<String, super::gossip::GossipOverlay>,
    event_tx: &mpsc::Sender<NetworkEvent>,
    global_webrtc_count: usize,
) {
    for overlay in gossip_overlays.values_mut() {
        if overlay.known_peers.len() < super::gossip::GOSSIP_ACTIVATION_THRESHOLD {
            continue; // skip small servers
        }
        let (to_connect, to_disconnect) = overlay.rotate_with_budget(global_webrtc_count);
        for peer_id in to_connect {
            hollow_log!("[HOLLOW-GOSSIP] Rotation: connect to {peer_id} (server={})", overlay.server_id);
            let _ = event_tx.send(NetworkEvent::GossipConnect { peer_id }).await;
        }
        for peer_id in to_disconnect {
            hollow_log!("[HOLLOW-GOSSIP] Rotation: disconnect {peer_id} (server={})", overlay.server_id);
            let _ = event_tx.send(NetworkEvent::GossipDisconnect { peer_id }).await;
        }
    }
}

/// Handle gossip broadcast dedup eviction timer tick.
/// Evicts stale broadcasts and falls back to direct request for timed-out relays.
pub(crate) fn handle_gossip_eviction(
    gossip_overlays: &mut HashMap<String, super::gossip::GossipOverlay>,
    ws_cmd_tx: &tokio::sync::mpsc::UnboundedSender<super::ws_client::WsCommand>,
    ws_room_peers: &HashMap<String, std::collections::HashSet<String>>,
) {
    for overlay in gossip_overlays.values_mut() {
        // Check for timed-out pending relays — file didn't arrive via gossip.
        let timed_out = overlay.get_timed_out_relays();
        for file_id in &timed_out {
            if let Some(relay) = overlay.pending_relays.get(file_id) {
                hollow_log!(
                    "[HOLLOW-GOSSIP] Broadcast timeout for file {} (bid={}) — requesting directly from origin {}",
                    file_id, relay.broadcast_id, relay.origin
                );
                // Fall back: request the file from the origin via normal FileRequest.
                if peer_is_reachable(ws_room_peers, &relay.origin) {
                    send_message_to_peer(
                        ws_cmd_tx, ws_room_peers,
                        &relay.origin,
                        HavenMessage::FileProbe { file_id: file_id.clone() },
                    );
                }
            }
        }
        overlay.evict_stale_broadcasts();
    }
}

/// Handle gossip peer exchange timer tick.
/// Sends neighbor list only to gossip neighbors (not the entire room).
pub(crate) fn handle_gossip_exchange(
    gossip_overlays: &HashMap<String, super::gossip::GossipOverlay>,
    ws_cmd_tx: &tokio::sync::mpsc::UnboundedSender<super::ws_client::WsCommand>,
    ws_room_peers: &HashMap<String, std::collections::HashSet<String>>,
) {
    for overlay in gossip_overlays.values() {
        if overlay.neighbors.is_empty() { continue; }
        let peers_list: Vec<String> = overlay.neighbors.iter().cloned().collect();
        let msg = HavenMessage::PeerExchange {
            server_id: overlay.server_id.clone(),
            peers: peers_list,
        };
        for neighbor in &overlay.neighbors {
            if peer_is_reachable(ws_room_peers, neighbor) {
                send_message_to_peer(ws_cmd_tx, ws_room_peers, neighbor, msg.clone());
            }
        }
    }
}
