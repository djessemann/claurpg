// usage: node cap_area.js <rompath> <outpng> [extraSteps]
const fs=require("fs");
const {NES,Controller}=require("/home/user/claurpg/test/node_modules/jsnes/src/index.js");
const {PNG}=require("/home/user/claurpg/test/node_modules/pngjs");
const rom=process.argv[2], out=process.argv[3];
let fb=null;const nes=new NES({onFrame:b=>{fb=b;},onAudioSample:()=>{}});
nes.loadROM(fs.readFileSync(rom,"binary"));
const B=Controller;
function run(n){for(let i=0;i<n;i++)nes.frame();}
run(50);nes.buttonDown(1,B.BUTTON_START);run(6);nes.buttonUp(1,B.BUTTON_START);run(40);
const png=new PNG({width:256,height:240});for(let i=0;i<256*240;i++){const c=fb[i];png.data[i*4]=c&255;png.data[i*4+1]=(c>>8)&255;png.data[i*4+2]=(c>>16)&255;png.data[i*4+3]=255;}
fs.writeFileSync(out,PNG.sync.write(png));
console.log("shot",out);
