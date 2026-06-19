'use strict';

const CACHE_NAME = 'storelink-v4';

// URLs that must NEVER be cached or intercepted (storefront, auth flows, API)
const BYPASS_PATTERNS = [
  '/store/',        // customer storefront — always fetch fresh, never serve cached root
  '/auth-callback',
  '/v1/',
  'supabase',
  'access_token',
  'refresh_token',
  'code=',
  'error=',
];

function shouldBypass(url) {
  return BYPASS_PATTERNS.some((p) => url.includes(p));
}

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(['/']).catch(() => {});
    })
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))
      );
    }).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  const url = event.request.url;

  // Bypass: auth callbacks, API calls, cross-origin, Supabase
  if (shouldBypass(url)) return;
  if (!url.startsWith(self.location.origin)) return;

  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) return cached;
      return fetch(event.request).then((response) => {
        // Only cache same-origin 200 responses for static assets
        if (
          response &&
          response.status === 200 &&
          response.type === 'basic' &&
          !shouldBypass(url)
        ) {
          const toCache = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, toCache));
        }
        return response;
      });
    }).catch(() => fetch(event.request))
  );
});
