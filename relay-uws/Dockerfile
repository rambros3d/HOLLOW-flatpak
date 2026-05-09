FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake g++ make \
    libssl-dev libsodium-dev zlib1g-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY CMakeLists.txt ./
COPY src/ src/
COPY uWebSockets/ uWebSockets/
COPY uSockets/ uSockets/

RUN mkdir build && cd build \
    && cmake .. -DCMAKE_BUILD_TYPE=Release \
    && make -j$(nproc)

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 libsodium23 zlib1g ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/build/hollow-relay /usr/local/bin/hollow-relay

EXPOSE 443

ENTRYPOINT ["hollow-relay"]
