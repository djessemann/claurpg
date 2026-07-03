#!/bin/sh
# EMBERFALL build: generators -> ca65 -> ld65 -> build/emberfall.nes
set -e
cd "$(dirname "$0")"
python3 tools/gfx.py
python3 tools/maps.py
python3 tools/music.py
ca65 -o build/emberfall.o -I src src/emberfall.s
ld65 -C rom.cfg -o build/emberfall.nes build/emberfall.o
echo "built build/emberfall.nes ($(wc -c < build/emberfall.nes) bytes)"
