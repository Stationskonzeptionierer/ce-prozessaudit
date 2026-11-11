// CE Prozessaudit v0.9: fully self-contained app shell, cache controlled by version.
const CACHE='ce-audit-public-v09';
const CORE=['./index.html','./manifest.webmanifest','./icon-192.png','./icon-512.png'];
self.addEventListener('install', event=>event.waitUntil((async()=>{
 const c=await caches.open(CACHE);
 await c.addAll(CORE.map(x=>new Request(new URL(x,self.registration.scope),{cache:'reload'})));
 await self.skipWaiting();
})()));
self.addEventListener('activate',event=>event.waitUntil((async()=>{
 const keys=await caches.keys();
 await Promise.all(keys.filter(k=>k.startsWith('ce-audit-public-')&&k!==CACHE).map(k=>caches.delete(k)));
 await self.clients.claim();
})()));
self.addEventListener('fetch',event=>{
 if(event.request.method!=='GET')return;
 const u=new URL(event.request.url);
 if(u.origin!==self.location.origin)return;
 if(event.request.mode==='navigate'){
  event.respondWith((async()=>{
   const c=await caches.open(CACHE);
   try{const r=await fetch(event.request);if(r.ok){await c.put('./index.html',r.clone());return r}}catch(e){}
   return await c.match('./index.html')||Response.error();
  })());return;
 }
 if(!CORE.some(p=>new URL(p,self.registration.scope).pathname===u.pathname))return;
 event.respondWith((async()=>{const c=await caches.open(CACHE);return await c.match(event.request,{ignoreSearch:true})||fetch(event.request)})());
});
