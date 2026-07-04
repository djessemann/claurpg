const {chromium}=require("/opt/node22/lib/node_modules/playwright");
(async()=>{
  const b=await chromium.launch({executablePath:"/opt/pw-browsers/chromium-1194/chrome-linux/chrome"});
  const p=await b.newPage();
  const url="file:///tmp/claude-0/-home-user-claurpg/3a4cefe1-2cc6-50a8-815a-688239a84201/scratchpad/guide/guide.html";
  await p.goto(url,{waitUntil:"networkidle"});
  await p.pdf({path:"/tmp/claude-0/-home-user-claurpg/3a4cefe1-2cc6-50a8-815a-688239a84201/scratchpad/EREBUS-Guide.pdf",
    format:"Letter", printBackground:true, preferCSSPageSize:true});
  // also capture page-1 and a few pages as PNG for visual QA
  await p.setViewportSize({width:816,height:1056});
  for(const [i,y] of [[1,0],[3,2],[5,4],[8,7],[9,8],[12,11],[13,12]]){
    await p.evaluate(n=>window.scrollTo(0,(n-1)*1056),i);
  }
  await b.close();
  console.log("pdf done");
})().catch(e=>{console.error(e.stack||e.message);process.exit(1)});
