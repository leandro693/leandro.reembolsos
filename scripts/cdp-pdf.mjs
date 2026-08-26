// Gera docs/HANDOFF-TECNICO.pdf via Chrome DevTools Protocol (Page.printToPDF),
// com header/footer (título + paginação) na identidade Maradel. Node 24 (WebSocket nativo).
import { spawn } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');   // scripts/ -> raiz do repo
// Caminho do Chrome: env CHROME_PATH tem prioridade; fallback para o padrão do Windows.
const CHROME = process.env.CHROME_PATH || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const URL = pathToFileURL(join(ROOT, 'docs/HANDOFF-TECNICO.html')).href;
const OUT = join(ROOT, 'docs/HANDOFF-TECNICO.pdf');
const PORT=9333;
const sleep=ms=>new Promise(r=>setTimeout(r,ms));

const chrome=spawn(CHROME,['--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check',
  `--remote-debugging-port=${PORT}`,'about:blank'],{stdio:'ignore'});

async function main(){
  // espera o endpoint de depuração subir
  let ver=null;
  for(let i=0;i<40;i++){ try{ const r=await fetch(`http://127.0.0.1:${PORT}/json/version`); if(r.ok){ ver=await r.json(); break; } }catch(e){} await sleep(250); }
  if(!ver) throw new Error('Chrome debugging não subiu');
  // cria uma aba já navegando para o HTML
  let tab; { const r=await fetch(`http://127.0.0.1:${PORT}/json/new?${encodeURIComponent(URL)}`,{method:'PUT'});
    if(!r.ok){ const r2=await fetch(`http://127.0.0.1:${PORT}/json/new?${encodeURIComponent(URL)}`); tab=await r2.json(); } else tab=await r.json(); }
  const ws=new WebSocket(tab.webSocketDebuggerUrl);
  let id=0; const pending=new Map(); const events=[];
  const send=(method,params={})=>{ const mid=++id; ws.send(JSON.stringify({id:mid,method,params})); return new Promise((res,rej)=>pending.set(mid,{res,rej})); };
  await new Promise((res,rej)=>{ ws.onopen=res; ws.onerror=rej; });
  ws.onmessage=(ev)=>{ const m=JSON.parse(ev.data); if(m.id&&pending.has(m.id)){ const {res,rej}=pending.get(m.id); pending.delete(m.id); m.error?rej(new Error(m.error.message)):res(m.result); } else if(m.method){ events.push(m.method); } };

  await send('Page.enable');
  await send('Page.navigate',{url:URL});
  // espera o load
  for(let i=0;i<80;i++){ if(events.includes('Page.loadEventFired')) break; await sleep(150); }
  await sleep(600); // fontes/ícones

  const mkBox=(txt)=>`<div style="font-size:8px;width:100%;padding:0 12mm;color:#5c5c5f;display:flex;justify-content:space-between;font-family:Segoe UI,Arial,sans-serif;">${txt}</div>`;
  const header=mkBox(`<span style="color:#DB8438;font-weight:700;letter-spacing:.5px;">MARADEL · Reembolsos</span><span>Handoff Técnico · v62</span>`);
  const footer=mkBox(`<span>Confidencial — Reembolsos Maradel</span><span>Página <span class="pageNumber"></span> de <span class="totalPages"></span></span>`);

  const { data } = await send('Page.printToPDF',{
    printBackground:true, displayHeaderFooter:true, headerTemplate:header, footerTemplate:footer,
    paperWidth:8.27, paperHeight:11.69, marginTop:0.85, marginBottom:0.7, marginLeft:0, marginRight:0, preferCSSPageSize:false
  });
  writeFileSync(OUT, Buffer.from(data,'base64'));
  const kb=Math.round(Buffer.from(data,'base64').length/1024);
  console.log(`PDF OK (CDP): docs/HANDOFF-TECNICO.pdf (${kb} KB)`);
  ws.close();
}
main().then(()=>{ chrome.kill(); process.exit(0); }).catch(e=>{ console.error('FALHA:', e.message); chrome.kill(); process.exit(1); });
