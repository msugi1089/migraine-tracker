const CACHE_NAME = 'migraine-tracker-v1.0.3';
const ASSETS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/icon-192.png',
  '/icon-512.png'
];

// インストール時：全リソースをキャッシュ
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => {
      return cache.addAll(ASSETS.filter(url => !url.endsWith('.png') || false));
    }).catch(() => {
      // アイコンが未生成でも失敗しないよう
    })
  );
  self.skipWaiting();
});

// アクティベート時：古いキャッシュを削除
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

// フェッチ時：HTML はネットワーク優先、それ以外はキャッシュ優先
self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  const isHtml = url.pathname === '/' || url.pathname.endsWith('.html');

  if (isHtml) {
    // HTML は常にネットワークから取得（オフライン時はキャッシュにフォールバック）
    event.respondWith(
      fetch(event.request).then(response => {
        if (!response || response.status !== 200) return response;
        const clone = response.clone();
        caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
        return response;
      }).catch(() => caches.match(event.request))
    );
  } else {
    // その他はキャッシュ優先
    event.respondWith(
      caches.match(event.request).then(cached => {
        if (cached) return cached;
        return fetch(event.request).then(response => {
          if (!response || response.status !== 200) return response;
          const clone = response.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
          return response;
        }).catch(() => caches.match('/index.html'));
      })
    );
  }
});
