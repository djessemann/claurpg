const fs=require("fs");
const {PNG}=require("/home/user/claurpg/test/node_modules/pngjs");
// crop enemy region: centered x=128, upper area y ~ 44..128
const CX0=80, CY0=42, CW=96, CH=92;
for(const n of ["nanite","drone","crawler","husk","turret","node"]){
  const src=PNG.sync.read(fs.readFileSync(`${process.env.G}/en_${n}.png`));
  const out=new PNG({width:CW,height:CH});
  for(let y=0;y<CH;y++)for(let x=0;x<CW;x++){
    const si=((CY0+y)*src.width+(CX0+x))*4, di=(y*CW+x)*4;
    out.data[di]=src.data[si];out.data[di+1]=src.data[si+1];out.data[di+2]=src.data[si+2];out.data[di+3]=255;
  }
  fs.writeFileSync(`${process.env.G}/en_${n}.png`,PNG.sync.write(out)); // overwrite in-place (assets copy)
}
// boss crop too (bigger sprite) center x=128 y~50..150
{
  const src=PNG.sync.read(fs.readFileSync(`${process.env.G}/boss.png`));
  // keep boss full (it shows menu+name nicely) -> skip
}
console.log("cropped");
