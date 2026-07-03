#!/usr/bin/env node
// EMBERFALL test harness: run the ROM headless in jsnes, feed scripted input,
// dump PNG screenshots.
//
// usage: node test/run.js <script.json> [outdir]
// script: [{frame, press|release|hold: "A|B|START|SELECT|UP|DOWN|LEFT|RIGHT",
//           holdFrames}, {frame, shot: "name"} ...], plus {frames: N} total.
const fs = require("fs");
const path = require("path");
const { NES, Controller } = require(path.join(__dirname, "node_modules", "jsnes", "src", "index.js"));
const { PNG } = require(path.join(__dirname, "node_modules", "pngjs"));

const BTN = {
  A: Controller.BUTTON_A, B: Controller.BUTTON_B,
  SELECT: Controller.BUTTON_SELECT, START: Controller.BUTTON_START,
  UP: Controller.BUTTON_UP, DOWN: Controller.BUTTON_DOWN,
  LEFT: Controller.BUTTON_LEFT, RIGHT: Controller.BUTTON_RIGHT,
};

const scriptPath = process.argv[2];
const outdir = process.argv[3] || path.join(__dirname, "shots");
const romPath = path.join(__dirname, "..", "build", "emberfall.nes");
fs.mkdirSync(outdir, { recursive: true });

const script = JSON.parse(fs.readFileSync(scriptPath, "utf8"));
const events = script.events || [];
const total = script.frames || 600;

let fb = null;
const nes = new NES({
  onFrame: (buf) => { fb = buf; },
  onAudioSample: () => {},
});
nes.loadROM(fs.readFileSync(romPath, "binary"));

function shot(name) {
  const png = new PNG({ width: 256, height: 240 });
  for (let i = 0; i < 256 * 240; i++) {
    const c = fb[i];
    png.data[i * 4 + 0] = c & 0xff;
    png.data[i * 4 + 1] = (c >> 8) & 0xff;
    png.data[i * 4 + 2] = (c >> 16) & 0xff;
    png.data[i * 4 + 3] = 0xff;
  }
  fs.writeFileSync(path.join(outdir, name + ".png"), PNG.sync.write(png));
  console.log("shot", name);
}

// expand hold events into press/release
const timeline = new Map();
function at(f) {
  if (!timeline.has(f)) timeline.set(f, []);
  return timeline.get(f);
}
for (const e of events) {
  if (e.press) at(e.frame).push({ press: e.press });
  if (e.release) at(e.frame).push({ release: e.release });
  if (e.hold) {
    at(e.frame).push({ press: e.hold });
    at(e.frame + (e.holdFrames || 8)).push({ release: e.hold });
  }
  if (e.shot) at(e.frame).push({ shot: e.shot });
}

for (let f = 0; f <= total; f++) {
  const evs = timeline.get(f) || [];
  for (const e of evs) {
    if (e.press) nes.buttonDown(1, BTN[e.press]);
    if (e.release) nes.buttonUp(1, BTN[e.release]);
  }
  nes.frame();
  for (const e of evs) if (e.shot) shot(e.shot);
}
// state probe for debugging: dump some zero page
const ram = [];
for (let i = 0; i < 96; i++) ram.push(nes.cpu.mem[i]);
console.log("zp:", ram.map((v, i) => i.toString(16) + "=" + v.toString(16)).join(" "));
