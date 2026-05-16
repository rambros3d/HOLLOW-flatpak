#!/usr/bin/env bash
# fetch_ffmpeg.sh — Download a static LGPL ffmpeg binary for macOS or Linux.
#
# Sources:
#   - macOS arm64/x64: https://www.osxexperts.net/ (community static builds)
#                      We pin to a current release URL.
#   - Linux x64:       BtbN/FFmpeg-Builds release (statically linked).
#
# Output:
#   - macOS:  vendor/ffmpeg/ffmpeg-macos-{arch}
#   - Linux:  vendor/ffmpeg/ffmpeg-linux-x64
#   alongside LICENSE.ffmpeg.txt + VERSION.txt
#
# Usage: from the repo root run `bash scripts/fetch_ffmpeg.sh`. Safe to re-run.

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="${REPO_ROOT}/vendor/ffmpeg"
TMP_DIR="$(mktemp -d -t hollow_ffmpeg.XXXXXX)"
trap 'rm -rf "${TMP_DIR}"' EXIT

UNAME_S="$(uname -s)"
UNAME_M="$(uname -m)"

case "${UNAME_S}" in
  Darwin)
    if [[ "${UNAME_M}" == "arm64" ]]; then
      ARCH="arm64"
      URL="https://www.osxexperts.net/ffmpeg7arm.zip"
    else
      ARCH="x64"
      URL="https://www.osxexperts.net/ffmpeg7intel.zip"
    fi
    OUT_NAME="ffmpeg-macos-${ARCH}"
    ;;
  Linux)
    ARCH="x64"
    URL="https://github.com/BtbN/FFmpeg-Builds/releases/latest/download/ffmpeg-master-latest-linux64-lgpl.tar.xz"
    OUT_NAME="ffmpeg-linux-x64"
    ;;
  *)
    echo "Unsupported platform: ${UNAME_S}" >&2
    exit 1
    ;;
esac

mkdir -p "${VENDOR_DIR}"
echo "==> Hollow ffmpeg fetcher (${UNAME_S} ${ARCH})"
echo "    Source: ${URL}"
echo "    Target: ${VENDOR_DIR}/${OUT_NAME}"

ARCHIVE="${TMP_DIR}/ffmpeg-archive"
echo "==> Downloading…"
curl -fL --retry 3 --retry-delay 2 -o "${ARCHIVE}" "${URL}"

echo "==> Extracting…"
mkdir -p "${TMP_DIR}/extract"
case "${URL}" in
  *.zip)
    unzip -q "${ARCHIVE}" -d "${TMP_DIR}/extract"
    ;;
  *.tar.xz)
    tar -xJf "${ARCHIVE}" -C "${TMP_DIR}/extract"
    ;;
  *)
    echo "Unknown archive format: ${URL}" >&2
    exit 1
    ;;
esac

# Find the ffmpeg binary in the extracted tree.
FFMPEG_BIN="$(find "${TMP_DIR}/extract" -type f -name ffmpeg -perm -u+x 2>/dev/null | head -n1 || true)"
if [[ -z "${FFMPEG_BIN}" ]]; then
  # Some archives ship without exec bit; broaden the search.
  FFMPEG_BIN="$(find "${TMP_DIR}/extract" -type f -name ffmpeg 2>/dev/null | head -n1 || true)"
fi
if [[ -z "${FFMPEG_BIN}" ]]; then
  echo "Could not find ffmpeg binary in extracted archive" >&2
  exit 1
fi

cp "${FFMPEG_BIN}" "${VENDOR_DIR}/${OUT_NAME}"
chmod +x "${VENDOR_DIR}/${OUT_NAME}"

# Record version for traceability.
"${VENDOR_DIR}/${OUT_NAME}" -version | head -n1 > "${VENDOR_DIR}/VERSION.txt" || true

# Drop a placeholder LICENSE — adjust per upstream when curating a release.
cat > "${VENDOR_DIR}/LICENSE.ffmpeg.txt" <<'EOF'
This bundled ffmpeg build is distributed under the LGPL.
See https://www.ffmpeg.org/legal.html and the source for the full text.
EOF

echo "==> Done. ${VENDOR_DIR}/${OUT_NAME}"
