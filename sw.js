const K='absensi-v6',F=['./','index.html','manifest.json','icon.svg'];
self.addEventListener('install',e=>e.waitUntil(caches.open(K).then(c=>c.addAll(F)).then(()=>self.skipWaiting())));
self.addEventListener('activate',e=>e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==K).map(k=>caches.delete(k)))).then(()=>clients.claim())));
self.addEventListener('fetch',e=>{
  const u=new URL(e.request.url);
  if(e.request.method!=='GET'||u.hostname.endsWith('supabase.co'))return;
  e.respondWith(fetch(e.request,{cache:'no-cache',redirect:'follow'}).then(r=>{const c=r.clone();caches.open(K).then(x=>x.put(e.request,c));return r}).catch(()=>caches.match(e.request)));
});
