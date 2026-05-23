#!/bin/sh
# copy-flutter-libs.sh — install app libs into /app/bin/lib/ matching RPATH=$ORIGIN/lib
mkdir -p /app/bin/lib
for f in build/linux/x64/release/bundle/lib/lib*.so*; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in
    libapp.so) continue ;;
  esac
  install -Dm644 "$f" /app/bin/lib/
done
