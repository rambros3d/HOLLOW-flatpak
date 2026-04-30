#!/usr/bin/env python3
"""Benchmark JSON vs binary wire protocol on the Hollow relay."""

import asyncio
import json
import os
import ssl
import struct
import time
import base64
from nacl.signing import SigningKey

import websockets

URL = "wss://relay.anonlisten.com/ws"
ROOM = "bench:test-room-001"
NUM_MESSAGES = 200
PAYLOAD_SIZES = [64, 256, 1024, 4096]


def make_identity():
    sk = SigningKey.generate()
    vk = sk.verify_key
    raw_pub = bytes(vk)
    proto_pub = b'\x08\x01\x12\x20' + raw_pub
    pub_b64 = base64.b64encode(proto_pub).decode()

    # peer_id: base58 of multihash of protobuf key (simplified — just hex for bench)
    peer_id = "12D3KooW" + raw_pub[:20].hex()
    return sk, pub_b64, peer_id


def sign_auth(sk, peer_id, timestamp):
    msg = f"hollow-ws-auth:{peer_id}:{timestamp}".encode()
    signed = sk.sign(msg)
    return base64.b64encode(signed.signature).decode()


async def connect_and_auth(ctx, sk, pub_b64, peer_id):
    ws = await websockets.connect(URL, ssl=ctx, max_size=10 * 1024 * 1024)
    ts = int(time.time())
    sig = sign_auth(sk, peer_id, ts)
    auth = json.dumps({
        "type": "auth",
        "peer_id": peer_id,
        "public_key": pub_b64,
        "timestamp": ts,
        "signature": sig,
    })
    await ws.send(auth)
    resp = await ws.recv()
    parsed = json.loads(resp)
    if parsed.get("type") != "auth_ok":
        raise Exception(f"Auth failed: {resp}")
    return ws


async def bench_json(ctx, payload_size):
    """Old path: JSON text messages with base64-encoded data."""
    sk1, pub1, pid1 = make_identity()
    sk2, pub2, pid2 = make_identity()

    ws1 = await connect_and_auth(ctx, sk1, pub1, pid1)
    ws2 = await connect_and_auth(ctx, sk2, pub2, pid2)

    # Join room
    await ws1.send(json.dumps({"type": "join", "room": ROOM}))
    await ws1.recv()  # members
    await ws2.send(json.dumps({"type": "join", "room": ROOM}))
    await ws2.recv()  # members
    await ws1.recv()  # peer_joined

    payload = os.urandom(payload_size)
    payload_b64 = base64.b64encode(payload).decode()

    total_sent = 0
    total_recv = 0

    for _ in range(NUM_MESSAGES):
        msg = json.dumps({"type": "msg", "room": ROOM, "data": payload_b64})
        total_sent += len(msg.encode())
        await ws1.send(msg)
        resp = await ws2.recv()
        total_recv += len(resp.encode()) if isinstance(resp, str) else len(resp)

    await ws1.send(json.dumps({"type": "leave", "room": ROOM}))
    await ws2.send(json.dumps({"type": "leave", "room": ROOM}))
    await ws1.close()
    await ws2.close()

    return total_sent, total_recv


async def bench_binary(ctx, payload_size):
    """New path: binary 0x03 frames with raw payload (no base64)."""
    sk1, pub1, pid1 = make_identity()
    sk2, pub2, pid2 = make_identity()

    ws1 = await connect_and_auth(ctx, sk1, pub1, pid1)
    ws2 = await connect_and_auth(ctx, sk2, pub2, pid2)

    # Join room (still JSON)
    await ws1.send(json.dumps({"type": "join", "room": ROOM}))
    await ws1.recv()  # members
    await ws2.send(json.dumps({"type": "join", "room": ROOM}))
    await ws2.recv()  # members
    await ws1.recv()  # peer_joined

    payload = os.urandom(payload_size)

    total_sent = 0
    total_recv = 0

    for _ in range(NUM_MESSAGES):
        # Build [0x03][room\0][payload]
        frame = b'\x03' + ROOM.encode() + b'\x00' + payload
        total_sent += len(frame)
        await ws1.send(frame)
        resp = await ws2.recv()
        total_recv += len(resp)

    await ws1.send(json.dumps({"type": "leave", "room": ROOM}))
    await ws2.send(json.dumps({"type": "leave", "room": ROOM}))
    await ws1.close()
    await ws2.close()

    return total_sent, total_recv


async def main():
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    print(f"Sending {NUM_MESSAGES} messages per test, room: {ROOM}")
    print()
    print(f"{'Payload':>8} | {'JSON sent':>12} {'JSON recv':>12} | {'Binary sent':>12} {'Binary recv':>12} | {'Sent save':>10} {'Recv save':>10}")
    print("-" * 100)

    for size in PAYLOAD_SIZES:
        json_sent, json_recv = await bench_json(ctx, size)
        binary_sent, binary_recv = await bench_binary(ctx, size)

        sent_save = (1 - binary_sent / json_sent) * 100
        recv_save = (1 - binary_recv / json_recv) * 100

        print(f"{size:>7}B | {json_sent:>10,}B {json_recv:>10,}B | {binary_sent:>10,}B {binary_recv:>10,}B | {sent_save:>8.1f}% {recv_save:>8.1f}%")

    print()
    print("Sent = client->relay bytes. Recv = relay->client bytes.")
    print("Savings = how much smaller binary is vs JSON.")


asyncio.run(main())
