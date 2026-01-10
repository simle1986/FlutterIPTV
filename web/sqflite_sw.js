// SQLite Service Worker for Web
// This service worker is required for sqflite_common_ffi_web to work properly

const CACHE_NAME = 'sqflite-cache-v1';

self.addEventListener('install', function(event) {
  console.log('SQLite Service Worker installing...');
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  console.log('SQLite Service Worker activating...');
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', function(event) {
  // Let sqflite handle its own requests
  if (event.request.url.includes('sqflite')) {
    return;
  }
  
  // For other requests, just pass through
  event.respondWith(fetch(event.request));
});

// Handle messages from the main thread
self.addEventListener('message', function(event) {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});