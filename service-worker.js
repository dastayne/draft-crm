const CACHE_NAME = 'draft-crm-v79';
const ASSETS = [
  './',
  './index.html',
  './manifest.webmanifest',
  './icons/icon-180.png',
  './icons/icon-192.png',
  './icons/icon-512.png'
];

function shouldCacheRequest(request) {
  const url = new URL(request.url);
  const isSameOrigin = url.origin === self.location.origin;
  const isDraftPhoto = url.hostname.endsWith('supabase.co') &&
    url.pathname.includes('/storage/v1/object/public/draft-photos/');

  return isSameOrigin || isDraftPhoto;
}

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(ASSETS)));
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys => Promise.all(keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key))))
  );
  self.clients.claim();
});

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;
  if (!shouldCacheRequest(request)) return;

  event.respondWith(
    fetch(request).then(response => {
      if (response.ok || response.type === 'opaque') {
        const clone = response.clone();
        caches.open(CACHE_NAME).then(cache => cache.put(request, clone)).catch(() => {});
      }
      return response;
    }).catch(() => caches.match(request).then(cached => {
      if (cached) return cached;
      if (request.mode === 'navigate' || request.destination === 'document') {
        return caches.match('./index.html');
      }
      return Response.error();
    }))
  );
});
