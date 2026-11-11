// CE Prozessaudit v0.7: versioned, same-origin offline shell.
const CACHE = 'ce-audit-public-v07';
const CORE = ['./','./index.html','./app.js?v=07','./style.css?v=07','./fragen.json','./manifest.webmanifest','./icon-192.png','./icon-512.png'];
const SHELL = new Set(CORE.map(p => new URL(p,self.registration.scope).pathname));
self.addEventListener('install', event => event.waitUntil((async () => {
  const cache = await caches.open(CACHE);
  await cache.addAll(CORE.map(p => new Request(new URL(p,self.registration.scope), {cache:'reload'})));
  await self.skipWaiting();
})()));
self.addEventListener('activate', event => event.waitUntil((async () => {
  const keys = await caches.keys();
  await Promise.all(keys.filter(k => k.startsWith('ce-audit-public-') && k !== CACHE).map(k => caches.delete(k)));
  await self.clients.claim();
})()));
self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin || !SHELL.has(url.pathname)) return;
  if (request.mode === 'navigate') {
    event.respondWith((async () => {
      try { const response=await fetch(request); if(response.ok)return response; } catch(e) {}
      const cache=await caches.open(CACHE);
      return await cache.match('./index.html') || await cache.match('./') || Response.error();
    })());
    return;
  }
  event.respondWith((async()=>{
    const cache=await caches.open(CACHE);
    const cached=await cache.match(request,{ignoreSearch:true});
    if(cached)return cached;
    return fetch(request);
  })());
});
