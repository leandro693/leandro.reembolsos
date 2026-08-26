// Harness — Ajustes em CARTÕES (Conta · Preferências · Pagamento) + versão em destaque (v61).
// VERSIONADO no repo (antes vivia só no scratchpad e se perdeu entre sessões). Semente da
// suíte de testes; novas áreas ganham seus próprios arquivos em tests/ conforme forem mexidas.
// Roda sem segredo: node tests/ajustes.test.mjs (regex/estrutura sobre index.html/sw.js).
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const src = readFileSync(join(root, 'index.html'), 'utf8');
const sw  = readFileSync(join(root, 'sw.js'), 'utf8');
let f=0; const ok=(n,c)=>{ if(!c) f++; console.log(`${c?'OK    ':'FALHA '} ${n}`); };
const grab=(s,re)=>{ const m=s.match(re); if(!m){ throw new Error('não achei: '+re); } return m[0]; };

// Recorta o bloco do scAjustes para provar que os controles estão DENTRO da tela.
const aj = grab(src, /<section id="scAjustes"[\s\S]*?<\/section>/);

(async()=>{
  console.log('\n=== (1) Os 3 cartões presentes (Conta · Preferências · Pagamento) + Sobre ===');
  ok('cartão Conta (.chart + ch-head "Conta")', /<div class="chart">\s*<div class="ch-head"><h3>[\s\S]*?Conta<\/h3>/.test(aj));
  ok('cartão Preferências (ch-head "Preferências")', /<div class="ch-head"><h3>[\s\S]*?Preferências<\/h3>/.test(aj));
  ok('cartão Pagamento (ch-head "Pagamento")', /<div class="ch-head"><h3>[\s\S]*?Pagamento<\/h3>/.test(aj));
  ok('cartão Sobre (ch-head "Sobre")', /<div class="ch-head"><h3>[\s\S]*?Sobre<\/h3>/.test(aj));
  ok('4 cartões .chart no scAjustes', (aj.match(/<div class="chart">/g)||[]).length===4);

  console.log('\n=== (1) Cada cartão com TODOS os controles (ids/onclick preservados) ===');
  // Conta: senha + mostrar + alterar + sair
  ok('Conta: cfgSenha1/cfgSenha2 + verSenha + alterarSenha + sair',
     /id="cfgSenha1"/.test(aj) && /id="cfgSenha2"/.test(aj) && /onchange="verSenha\(this\.checked\)"/.test(aj) &&
     /onclick="alterarSenha\(\)"/.test(aj) && /onclick="sair\(\)"/.test(aj));
  // Preferências: tema + contraste + visualização (escopo)
  ok('Preferências: tema tcLight/tcDark/tcBlack via setTema',
     /id="tcLight" onclick="setTema\('light'\)"/.test(aj) && /id="tcDark" onclick="setTema\('dark'\)"/.test(aj) && /id="tcBlack" onclick="setTema\('black'\)"/.test(aj));
  ok('Preferências: contraste dcNormal/dcReforcado via setDensidade',
     /id="dcNormal" onclick="setDensidade\('normal'\)"/.test(aj) && /id="dcReforcado" onclick="setDensidade\('reforcado'\)"/.test(aj));
  ok('Preferências: Visualização (secVisualDiv + secVisual + escopo setEscopo)',
     /id="secVisualDiv"/.test(aj) && /id="secVisual"/.test(aj) &&
     /id="cfgEscMeus" onclick="setEscopo\('meus'\)"/.test(aj) && /id="cfgEscTodos" onclick="setEscopo\('todos'\)"/.test(aj));
  // Pagamento: PIX
  ok('Pagamento: cfgPixTipo/Chave/Nome/Banco + salvarPix',
     /id="cfgPixTipo"/.test(aj) && /id="cfgPixChave"/.test(aj) && /id="cfgPixNome"/.test(aj) && /id="cfgPixBanco"/.test(aj) && /onclick="salvarPix\(\)"/.test(aj));

  console.log('\n=== (2) Todas as funções seguem IGUAIS (nada de comportamento muda) ===');
  ok('funções presentes: setTema/setDensidade/setEscopo/salvarPix/alterarSenha/verSenha/mostrarVersao',
     /function setTema\(/.test(src) && /function setDensidade\(/.test(src) && /function setEscopo\(/.test(src) &&
     /async function salvarPix\(/.test(src) && /function alterarSenha\(|async function alterarSenha\(/.test(src) &&
     /function verSenha\(/.test(src) && /async function mostrarVersao\(/.test(src));
  ok('sair() existe (logout)', /function sair\(/.test(src));

  console.log('\n=== (3) Versão em DESTAQUE (não mais rodapé cinza 11px) ===');
  ok('ajVersao dentro do cartão "Sobre" (linha aj-versao-row)',
     /Sobre<\/h3>[\s\S]*?class="aj-versao-row">[\s\S]*?id="ajVersao"/.test(aj));
  ok('rodapé cinza 11px REMOVIDO (sem <div class="foot" font-size:11px ... Maradel ... ajVersao)',
     !/font-size:11px;margin-top:16px">Maradel/.test(src));
  ok('CSS .aj-versao-row com valor em destaque (15px, text-strong)',
     /\.aj-versao-row\{display:flex;align-items:center;justify-content:space-between/.test(src) && /\.aj-versao-row b\{font-size:15px;color:var\(--text-strong\)\}/.test(src));
  ok('mostrarVersao ainda escreve em ajVersao ("Versão N")', /el\('ajVersao'\)/.test(src) && /Versão \$\{APP_VERSION\}/.test(src));

  console.log('\n=== (4) prepararAjustes INALTERADO (Visualização segue só-gestão) ===');
  const prep = grab(src, /function prepararAjustes\(\)\{[\s\S]*?\n\}/);
  ok('prepararAjustes usa veTudo() para mostrar/esconder a Visualização',
     /const most=veTudo\(\);/.test(prep) &&
     /el\('secVisual'\)\.classList\.toggle\('hidden', !most\)/.test(prep) &&
     /el\('secVisualDiv'\)\.classList\.toggle\('hidden', !most\)/.test(prep));
  ok('prepararAjustes ainda preenche PIX + marca prefs/escopo',
     /el\('cfgPixTipo'\)\.value/.test(prep) && /marcarEscopo\(\)/.test(prep) && /marcarPrefs\(\)/.test(prep));
  ok('irAjustes chama prepararAjustes', /function irAjustes\(\)\{ tela\('scAjustes'\); prepararAjustes\(\); \}/.test(src));

  console.log('\n=== (extra) nota antiga do Console REMOVIDA + estrutura + versão ===');
  ok('nota "Console ... no menu lateral" removida', !/Console de Gestão agora ficam no menu lateral/.test(src));
  const secAbre=(src.match(/<section\b/g)||[]).length, secFecha=(src.match(/<\/section>/g)||[]).length;
  ok(`<section> balanceado (${secAbre}=${secFecha})`, secAbre===secFecha);
  const idsScreen=(src.match(/<section id="(sc[A-Za-z]+)"/g)||[]).map(s=>s.match(/"(sc[A-Za-z]+)"/)[1]);
  ok('8 seções de tela (Ajustes continua UMA section)', idsScreen.length===8 && idsScreen.includes('scAjustes'));
  const appV=(src.match(/const APP_VERSION\s*=\s*'(\d+)'/)||[])[1];
  const swV=(sw.match(/reembolsos-maradel-v(\d+)-saas/)||[])[1];
  ok('APP_VERSION = 61', appV==='61');
  ok('sw.js = v61', swV==='61');
  ok('APP_VERSION == cache do SW', appV===swV);

  console.log(f===0 ? '\n=== TODOS OS TESTES OK ===' : `\n=== ${f} FALHA(S) ===`);
  process.exit(f?1:0);
})();
