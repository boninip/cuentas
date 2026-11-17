/* Cuentas: caché mínima. Nunca toca Supabase ni datos de la cuenta.
   - Página (HTML): red primero, sin caché del navegador (siempre la versión nueva); si la red tarda más de 2,5 s o falla, la última guardada.
   - Imágenes, íconos y manifest: guardados primero y se actualizan por detrás (arranque rápido en el segundo uso). */
const V='cuentas-v2',SHELL=['./','manifest.webmanifest','assets/icon-192.png','assets/icon-512.png','assets/hero-bg.jpg'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(V).then(c=>c.addAll(SHELL)).then(()=>self.skipWaiting()))});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==V).map(x=>caches.delete(x)))).then(()=>self.clients.claim()))});
const put=(r,res)=>{if(res&&res.ok){const c=res.clone();caches.open(V).then(x=>x.put(r,c))}return res};
self.addEventListener('fetch',e=>{
 const r=e.request,u=new URL(r.url);
 if(r.method!=='GET'||u.origin!==location.origin)return;
 if(r.mode==='navigate'||r.destination==='document'){
  const net=fetch(r,{cache:'no-store'}).then(res=>put(r,res));
  const slow=new Promise(ok=>setTimeout(()=>ok(null),2500));
  e.respondWith(Promise.race([net,slow]).then(res=>res||caches.match(r).then(m=>m||caches.match('./')).then(m=>m||net)).catch(()=>caches.match(r).then(m=>m||caches.match('./'))));
  return;
 }
 e.respondWith(caches.match(r).then(m=>{const net=fetch(r).then(res=>put(r,res)).catch(()=>m);return m||net}));
});
