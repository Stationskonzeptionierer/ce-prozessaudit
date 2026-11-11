const CACHE='ce-audit-public-v04';
const CORE=['./','./index.html','./app.js','./fragen.json','./manifest.webmanifest','./icon-192.png','./icon-512.png'];
self.addEventListener('install',e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll(CORE)).then(()=>self.skipWaiting())));
self.addEventListener('activate',e=>e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('ce-audit-')&&k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',e=>{if(e.request.method!=='GET')return;let u=new URL(e.request.url);if(u.origin!==location.origin)return;if(!CORE.some(p=>new URL(p,location.href).pathname===u.pathname))return;e.respondWith(caches.match(e.request,{ignoreSearch:true}).then(x=>x||fetch(e.request)));});
