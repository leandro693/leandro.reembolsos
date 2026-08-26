// Gera docs/<NOME>.html a partir de docs/<NOME>.md. Identidade Maradel + CSS de impressão.
// Conversor GFM (subset): headings, parágrafos, bold, inline code, code fences,
// listas (ul/ol), tabelas, blockquote, hr, links.
// Uso: node build-handoff.mjs [NOME] [TÍTULO] [--compact]
//   NOME   = basename do doc em docs/ (default HANDOFF-TECNICO)
//   TÍTULO = <title> do HTML (default "Handoff Técnico — Reembolsos Maradel")
//   --compact = sem quebra de página forçada por seção (para docs curtos, ex.: ENTREGA)
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');   // scripts/ -> raiz do repo
const NAME = process.argv[2] && !process.argv[2].startsWith('--') ? process.argv[2] : 'HANDOFF-TECNICO';
const TITLE = process.argv[3] && !process.argv[3].startsWith('--') ? process.argv[3] : 'Handoff Técnico — Reembolsos Maradel';
const COMPACT = process.argv.includes('--compact');
const md = readFileSync(join(ROOT, `docs/${NAME}.md`), 'utf8');

const esc = s => s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
// inline: `code` (primeiro, protege), **bold**, [txt](url)
function inline(t){
  const codes=[]; t=t.replace(/`([^`]+)`/g,(m,c)=>{codes.push(c);return `\u0000${codes.length-1}\u0000`;});
  t=esc(t);
  t=t.replace(/\*\*([^*]+)\*\*/g,'<strong>$1</strong>');
  t=t.replace(/\[([^\]]+)\]\(([^)]+)\)/g,'<a href="$2">$1</a>');
  t=t.replace(/\u0000(\d+)\u0000/g,(m,i)=>`<code>${esc(codes[+i])}</code>`);
  return t;
}
const lines = md.split(/\r?\n/);
let html='', i=0;
const flushParas=(buf)=>{ if(buf.length){ html+=`<p>${inline(buf.join(' '))}</p>\n`; buf.length=0; } };
let para=[];
while(i<lines.length){
  let ln=lines[i];
  // code fence
  if(/^```/.test(ln)){ flushParas(para); i++; let code=[]; while(i<lines.length && !/^```/.test(lines[i])){ code.push(lines[i]); i++; } i++; html+=`<pre><code>${esc(code.join('\n'))}</code></pre>\n`; continue; }
  // hr
  if(/^---+\s*$/.test(ln)){ flushParas(para); html+='<hr>\n'; i++; continue; }
  // heading
  let h=ln.match(/^(#{1,4})\s+(.*)$/);
  if(h){ flushParas(para); const lvl=h[1].length; const id=h[2].toLowerCase().replace(/[^a-z0-9áàâãéêíóôõúç ]/gi,'').trim().replace(/\s+/g,'-'); html+=`<h${lvl} id="${id}">${inline(h[2])}</h${lvl}>\n`; i++; continue; }
  // blockquote
  if(/^>\s?/.test(ln)){ flushParas(para); let q=[]; while(i<lines.length && /^>\s?/.test(lines[i])){ q.push(lines[i].replace(/^>\s?/,'')); i++; } html+=`<blockquote>${inline(q.join(' '))}</blockquote>\n`; continue; }
  // table (linha com | e próxima com ---|)
  if(/\|/.test(ln) && i+1<lines.length && /^\s*\|?[\s:-]*\|[\s:|-]*$/.test(lines[i+1]) && /-/.test(lines[i+1])){
    flushParas(para);
    const parseRow=r=>r.replace(/^\s*\|/,'').replace(/\|\s*$/,'').split('|').map(c=>c.trim());
    const head=parseRow(ln); i+=2; let rows=[];
    while(i<lines.length && /\|/.test(lines[i]) && lines[i].trim()!==''){ rows.push(parseRow(lines[i])); i++; }
    html+='<table><thead><tr>'+head.map(c=>`<th>${inline(c)}</th>`).join('')+'</tr></thead><tbody>';
    html+=rows.map(r=>'<tr>'+head.map((_,k)=>`<td>${inline(r[k]||'')}</td>`).join('')+'</tr>').join('');
    html+='</tbody></table>\n'; continue;
  }
  // list (ul/ol), com aninhamento por indentação de 2 espaços
  if(/^\s*([-*]|\d+\.)\s+/.test(ln)){
    flushParas(para);
    const items=[]; while(i<lines.length && /^\s*([-*]|\d+\.)\s+/.test(lines[i])){ const m=lines[i].match(/^(\s*)([-*]|\d+\.)\s+(.*)$/); items.push({indent:m[1].length, ord:/\d/.test(m[2]), txt:m[3]}); i++; }
    const render=(arr,pos)=>{ let out=''; const base=arr[pos].indent; const ord=arr[pos].ord; out+=ord?'<ol>':'<ul>'; let k=pos; while(k<arr.length && arr[k].indent>=base){ if(arr[k].indent>base){ const sub=render(arr,k); out+=sub.html; k=sub.k; continue; } out+=`<li>${inline(arr[k].txt)}</li>`; k++; } out+=ord?'</ol>':'</ul>'; return {html:out,k}; };
    html+=render(items,0).html+'\n'; continue;
  }
  // blank
  if(ln.trim()===''){ flushParas(para); i++; continue; }
  para.push(ln); i++;
}
flushParas(para);

const CSS=`
:root{ --accent:#DB8438; --accent-2:#B96C28; --ink:#39393B; --ink-2:#5c5c5f; --line:#e4e0da; --bg:#ffffff; --soft:#faf7f2; --code:#f4f1ec; }
*{box-sizing:border-box}
html{-webkit-print-color-adjust:exact; print-color-adjust:exact;}
body{font-family:"Segoe UI",Inter,Roboto,Arial,sans-serif; color:var(--ink); background:var(--bg); line-height:1.55; font-size:11.5pt; margin:0; padding:0 22mm;}
h1,h2,h3,h4{color:var(--ink); line-height:1.25; font-weight:700;}
h1{font-size:26pt; margin:0 0 4pt; color:var(--accent);}
h2{font-size:17pt; margin:26pt 0 8pt; padding-bottom:5pt; border-bottom:2.5px solid var(--accent); ${COMPACT?'':'break-before:page;'}}
h3{font-size:13pt; margin:16pt 0 5pt; color:var(--accent-2);}
h4{font-size:11.5pt; margin:12pt 0 3pt; color:var(--ink);}
p{margin:6pt 0;}
a{color:var(--accent-2); text-decoration:none;}
code{font-family:"Cascadia Code","Consolas",monospace; background:var(--code); padding:1px 5px; border-radius:4px; font-size:9.5pt; color:#7a3d0b;}
pre{background:var(--ink); color:#f5f2ec; padding:12px 14px; border-radius:8px; overflow-x:auto; font-size:9pt; line-height:1.45; break-inside:avoid;}
pre code{background:none; color:inherit; padding:0;}
ul,ol{margin:6pt 0 6pt 0; padding-left:20pt;}
li{margin:2.5pt 0;}
blockquote{margin:8pt 0; padding:7pt 12pt; background:var(--soft); border-left:4px solid var(--accent); color:var(--ink-2); border-radius:0 6px 6px 0;}
table{border-collapse:collapse; width:100%; margin:9pt 0; font-size:9.5pt; break-inside:avoid;}
th{background:var(--accent); color:#fff; text-align:left; padding:6px 9px; font-weight:600;}
td{border:1px solid var(--line); padding:5px 9px; vertical-align:top;}
tr:nth-child(even) td{background:var(--soft);}
hr{border:none; border-top:1px solid var(--line); margin:16pt 0;}
strong{color:var(--ink);}
/* Cabeçalho/rodapé com título e paginação são injetados pelo Chrome (CDP) na impressão. */
@media screen{ body{max-width:900px; margin:0 auto; padding:28px;} }
@page{ size:A4; margin:20mm 0 18mm; }
.capa{break-after:page; padding-top:32mm;}
.capa .sub{color:var(--ink-2); font-size:13pt; margin-top:2pt;}
.capa .badge{display:inline-block; margin-top:14pt; background:var(--accent); color:#fff; padding:4px 12px; border-radius:20px; font-size:10pt; font-weight:600;}
.capa .meta{margin-top:20pt; font-size:10pt; color:var(--ink-2);}
${COMPACT ? `
/* Modo compacto (docs curtos como ENTREGA): mais denso p/ caber em 1-2 páginas. */
body{font-size:10pt; padding:0 16mm;}
h1{font-size:20pt;} h2{font-size:13.5pt; margin:12pt 0 5pt;} h3{font-size:11.5pt; margin:9pt 0 3pt;}
p{margin:4pt 0;} li{margin:1.5pt 0;} ul,ol{margin:4pt 0;}
` : ''}`;
const titulo=TITLE;
const out=`<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${titulo}</title><style>${CSS}</style></head><body>
${html}
</body></html>`;
writeFileSync(join(ROOT, `docs/${NAME}.html`), out, 'utf8');
console.log(`HTML gerado: docs/${NAME}.html (${Math.round(out.length/1024)} KB)`);
