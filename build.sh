#!/bin/sh
# EREBUS build: generators -> ca65 -> ld65 -> build/erebus.nes
set -e
cd "$(dirname "$0")"
python3 tools/gfx.py
[ -f tools/maps.py ] && python3 tools/maps.py || true
[ -f tools/music.py ] && python3 tools/music.py || true
mkdir -p build
ca65 -g -o build/erebus.o -I src src/erebus.s
ca65 -g -o build/boot.o   -I src src/boot.s
ca65 -g -o build/ppu.o    -I src src/ppu.s
ca65 -g -o build/game.o   -I src src/game.s
  ca65 -g -o build/ui.o     -I src src/ui.s
ca65 -g -o build/sound.o  -I src src/sound.s
ca65 -g -o build/gfxdata.o -I src src/gen/gfxdata.s
ld65 -C rom.cfg -o build/erebus.nes --dbgfile build/erebus.dbg \
     build/erebus.o build/boot.o build/ppu.o build/game.o build/ui.o build/sound.o build/gfxdata.o
echo "built build/erebus.nes ($(wc -c < build/erebus.nes) bytes)"
