#!/bin/bash
set -e
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)
    TOOLCHAIN_TRIPLE="x86_64-unknown-linux-gnu"
    ;;
  aarch64)
    TOOLCHAIN_TRIPLE="aarch64-unknown-linux-gnu"
    ;;
  *)
    echo "rustup-wrapper: unsupported arch $ARCH" >&2
    exit 1
    ;;
esac
case "$1" in
  toolchain)
    case "$2" in
      list) echo "stable-$TOOLCHAIN_TRIPLE (default)";;
      install) ;;
      *) echo "rustup-wrapper: unknown toolchain cmd $2" >&2; exit 1;;
    esac;;
  target)
    case "$2" in
      add) ;;
      list) echo "$TOOLCHAIN_TRIPLE (installed)";;
      *) echo "rustup-wrapper: unknown target cmd $2" >&2; exit 1;;
    esac;;
  component) [ "$2" = "add" ] || { echo "rustup-wrapper: unknown component cmd $2" >&2; exit 1; } ;;
  run) shift 2; exec "$@";;
  *) echo "rustup-wrapper: unhandled: $*" >&2; exit 1;;
esac
