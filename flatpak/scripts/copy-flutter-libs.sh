#!/bin/sh
set -eu
ARCH="${1:-x64}"
mkdir -p /app/bin/lib
for f in "build/linux/$ARCH/release/bundle/lib/lib"*.so*; do
  [ -f "$f" ] || continue
  install -Dm755 "$f" /app/bin/lib/
done
