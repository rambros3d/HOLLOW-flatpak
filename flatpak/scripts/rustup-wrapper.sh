#!/bin/bash
set -e
case "$1" in
  toolchain)
    case "$2" in
      list) echo "stable-x86_64-unknown-linux-gnu (default)";;
      install) ;;
      *) echo "rustup-wrapper: unknown toolchain cmd $2" >&2; exit 1;;
    esac;;
  target)
    case "$2" in
      add) ;;
      list) echo "x86_64-unknown-linux-gnu (installed)";;
      *) echo "rustup-wrapper: unknown target cmd $2" >&2; exit 1;;
    esac;;
  component) [ "$2" = "add" ] || { echo "rustup-wrapper: unknown component cmd $2" >&2; exit 1; } ;;
  run) shift 2; exec "$@";;
  *) echo "rustup-wrapper: unhandled: $*" >&2; exit 1;;
esac
