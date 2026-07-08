#!/bin/bash
set -e

SDK="/Users/edoardo.davini/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2"
MONKEYC="$SDK/bin/monkeyc"
DEVICE="fenix8solar51mm"
KEY="developer_key.der"
OUT="bin/watchface.prg"

mkdir -p bin

"$MONKEYC" \
  -f monkey.jungle \
  -o "$OUT" \
  -d "$DEVICE" \
  -y "$KEY" \
  -w

echo "Built: $OUT"
