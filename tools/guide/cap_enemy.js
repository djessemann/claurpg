// node cap_enemy.js <rom> <outpng>
const fs=require("fs");
const {NES,Controller}=require("/home/user/claurpg/test/node_modules/jsnes/src/index.js");
const {PNG}=require("/home/user/claurpg/test/node_modules/pngjs");
const rom=process.argv[2], out=process.argv[3];
let fb=null;const nes=new NES({onFrame:b=>{fb=b;},onAudioSample:()=>{}});
nes.loadROM(fs.readFileSync(rom,"binary"));
const B=Controller;
function run(n){for(let i=0;i<n;i++)nes.frame();}
function step(btn){nes.buttonDown(1,btn);run(9);nes.buttonUp(1,btn);run(3);}
function nonblack(){let n=0;for(let i=0;i<256*240;i++){if((fb[i]&0xffffff)!==0)n++;}return n;}
run(50);step(B.BUTTON_START);run(30);step(B.BUTTON_DOWN);
let inbattle=false;
for(let i=0;i<40 && !inbattle;i++){ step(B.BUTTON_RIGHT);
  if(nonblack() < 256*240*0.35) inbattle=true; // battle screen is mostly black
}
run(12); step(B.BUTTON_A); run(16); // advance intro -> command menu
const png=new PNG({width:256,height:240});for(let i=0;i<256*240;i++){const c=fb[i];png.data[i*4]=c&255;png.data[i*4+1]=(c>>8)&255;png.data[i*4+2]=(c>>16)&255;png.data[i*4+3]=255;}
fs.writeFileSync(out,PNG.sync.write(png));
console.log(out, "inbattle:",inbattle);
