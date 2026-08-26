// Segurança das Edge Functions de IA/ERP (v62): identidade derivada do JWT + validação de
// pertencimento (fecha o vetor de empresa_id/usuario_id vindos do corpo). Checagens de
// estrutura sobre os index.ts + teste da LÓGICA do gate espelhada. Roda com: node tests/edge-seguranca.test.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const rd = p => readFileSync(join(root, p), 'utf8');
const LC = rd('supabase/functions/ler-comprovante/index.ts');
const LP = rd('supabase/functions/ler-pagamento/index.ts');
const IE = rd('supabase/functions/importar-erp/index.ts');
let f=0; const ok=(n,c)=>{ if(!c) f++; console.log(`${c?'OK    ':'FALHA '} ${n}`); };

const comuns = [['ler-comprovante',LC],['ler-pagamento',LP],['importar-erp',IE]];

console.log('\n=== (a) As 3 funções exigem JWT e validam pertencimento ===');
for(const [nome,src] of comuns){
  ok(`${nome}: getCaller via /auth/v1/user (identidade do JWT)`,
     /async function getCaller\(token: string\)/.test(src) && /\/auth\/v1\/user/.test(src) && /Authorization: `Bearer \$\{token\}`/.test(src));
  ok(`${nome}: helper autorizarEmpresa (owner OU membro ativo; exigeGestor -> gestor)`,
     /async function autorizarEmpresa\(callerId: string, empresaId: string, exigeGestor = false\)/.test(src) &&
     /is_owner === true\) return \{ ok: true \}/.test(src) &&
     /empresa_usuarios\?empresa_id=eq\.\$\{empresaId\}&usuario_id=eq\.\$\{callerId\}&select=papel,ativo/.test(src) &&
     /exigeGestor && v\.papel !== "gestor"/.test(src));
  ok(`${nome}: 401 nao_autenticado + 403 sem_permissao`,
     /erro: "nao_autenticado" \}, 401\)/.test(src) && /erro: "sem_permissao"/.test(src));
  ok(`${nome}: lê ANON_KEY do ambiente (para getCaller)`, /const ANON_KEY\s*=\s*Deno\.env\.get\("SUPABASE_ANON_KEY"\)/.test(src));
  ok(`${nome}: comentário de versão v62 no cabeçalho`, /v62 \(2026-08-13\)/.test(src));
}

console.log('\n=== (a) Leitoras de IA: usuario_id = caller.id (não do corpo) ===');
for(const [nome,src] of [['ler-comprovante',LC],['ler-pagamento',LP]]){
  ok(`${nome}: empresa_id vem do corpo mas é VALIDADO (autorizarEmpresa false)`,
     /const empresa_id = String\(body\.empresa_id \?\? ""\);/.test(src) &&
     /autorizarEmpresa\(caller\.id, empresa_id, false\)/.test(src));
  ok(`${nome}: usuario_id = caller.id (ignora o do corpo)`, /const usuario_id = caller\.id;/.test(src));
  ok(`${nome}: NÃO desestrutura mais usuario_id do corpo`, !/usuario_id, nomeArquivo \} = await req\.json\(\)/.test(src) && !/empresa_id, usuario_id, nomeArquivo \} = await req\.json/.test(src));
}
ok('importar-erp: exige GESTOR ou dono (autorizarEmpresa true)', /autorizarEmpresa\(caller\.id, empresaId, true\)/.test(IE));

console.log('\n=== (b) Gate ESPELHADO (mesma lógica do servidor) ===');
// Espelho fiel de autorizarEmpresa: caller = {is_owner}, vinc = {papel,ativo} da empresa do body.
function autorizar({ owner=false, vinc=null, empresaBody='E', exigeGestor=false }){
  if(!empresaBody) return { ok:false, status:400, erro:'empresa_ausente' };
  if(owner===true) return { ok:true };
  if(!vinc || vinc.ativo===false) return { ok:false, status:403, erro:'sem_permissao' };
  if(exigeGestor && vinc.papel!=='gestor') return { ok:false, status:403, erro:'sem_permissao' };
  return { ok:true };
}
// leitura de IA (exigeGestor=false)
ok('IA: membro ativo da empresa X + body X -> permite', autorizar({vinc:{papel:'operador',ativo:true}}).ok===true);
ok('IA: body de empresa DIFERENTE do JWT -> 403 (vínculo nulo p/ aquela empresa)', autorizar({vinc:null}).status===403);
ok('IA: membro INATIVO -> 403', autorizar({vinc:{papel:'gestor',ativo:false}}).status===403);
ok('IA: DONO do SaaS -> permite qualquer empresa', autorizar({owner:true, vinc:null}).ok===true);
ok('IA: financeiro ativo -> permite (membro)', autorizar({vinc:{papel:'financeiro',ativo:true}}).ok===true);
// importar-erp (exigeGestor=true)
ok('ERP: operador -> 403', autorizar({vinc:{papel:'operador',ativo:true}, exigeGestor:true}).status===403);
ok('ERP: financeiro -> 403 (não é gestor)', autorizar({vinc:{papel:'financeiro',ativo:true}, exigeGestor:true}).status===403);
ok('ERP: gestor ativo -> permite', autorizar({vinc:{papel:'gestor',ativo:true}, exigeGestor:true}).ok===true);
ok('ERP: dono -> permite', autorizar({owner:true, vinc:null, exigeGestor:true}).ok===true);
ok('empresa ausente -> 400', autorizar({empresaBody:'', vinc:{papel:'gestor',ativo:true}}).status===400);

console.log('\n=== (c) Fluxo legítimo NÃO regride ===');
// operador da empresa X lendo comprovante da X: membro ativo, exigeGestor=false -> permitido
ok('(c) operador da empresa X lê comprovante da X -> permitido', autorizar({vinc:{papel:'operador',ativo:true}, empresaBody:'X', exigeGestor:false}).ok===true);
// e a leitura de IA segue com toda a blindagem anterior intacta (anti-injeção/quarentena)
ok('(c) blindagem anti-injeção preservada (temInjecao/registrar_evento_seguranca)',
   /const temInjecao =/.test(LC) && /registrar_evento_seguranca/.test(LC) && /registrar_leitura_ia/.test(LC));

console.log('\n=== (extra) gestao-usuarios permanece o padrão (inalterada) ===');
const GU = rd('supabase/functions/gestao-usuarios/index.ts');
ok('gestao-usuarios: getCaller + gate owner/gestor intactos', /async function getCaller\(token: string\)/.test(GU) && /erro: "sem_permissao" \}, 403\)/.test(GU));

console.log(f===0 ? '\n=== TODOS OS TESTES OK ===' : `\n=== ${f} FALHA(S) ===`);
process.exit(f?1:0);
