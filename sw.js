/* Service worker do Reembolsos Maradel.
   Estratégia:
   - O HTML/JS do app (documento e navegação) usa REDE PRIMEIRO, caindo no cache
     só quando estiver offline. Assim novas versões aparecem sem forçar atualização.
   - Os demais arquivos locais (ícones, manifest) usam cache primeiro (rápido).
   - Dados (Supabase) e bibliotecas de CDN passam direto pela rede, sem cache aqui. */
const CACHE = 'reembolsos-maradel-v60-saas';
const SHELL = ['./', './index.html', './console.html', './manifest.webmanifest', './icons/icon.svg',
  './fonts/inter-latin.woff2', './fonts/inter-latin-ext.woff2'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET' || new URL(req.url).origin !== self.location.origin) return;

  const ehDocumento = req.mode === 'navigate' || req.destination === 'document' ||
    /\.html$/.test(new URL(req.url).pathname) || new URL(req.url).pathname.endsWith('/');

  if (ehDocumento) {
    // Rede primeiro: sempre pega a versão nova; offline cai no cache.
    e.respondWith(
      fetch(req).then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => {});
        return res;
      }).catch(() => caches.match(req).then((h) => h || caches.match('./index.html')))
    );
    return;
  }
  // Demais arquivos locais: cache primeiro.
  e.respondWith(
    caches.match(req).then((hit) => hit || fetch(req).then((res) => {
      const copy = res.clone();
      caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => {});
      return res;
    }).catch(() => caches.match('./index.html')))
  );
});
