/* ============================================================
   SaludEscolar AR — Service Worker
   ------------------------------------------------------------
   Objetivo: que la app sea INSTALABLE (PWA) y abra aunque no
   haya señal, PERO sin servir datos médicos desactualizados.

   Estrategia:
   - App shell (el HTML, íconos, manifest): "network-first".
     Siempre intenta traer la última versión de la red; si no
     hay conexión, usa la copia cacheada para que la app abra.
   - Datos de Supabase, fuentes y CDNs (Chart.js, supabase-js):
     NO se cachean acá. Van siempre a la red. Así los eventos,
     alumnos y KPIs siempre son los reales y frescos.

   Al publicar una versión nueva de la app, subí el número de
   CACHE_VERSION para forzar la actualización en los dispositivos.
   ============================================================ */

const CACHE_VERSION = 'saludescolar-v1';
const APP_SHELL = [
  '/',
  '/index.html',
  '/manifest.json',
  '/icon-192.png',
  '/icon-512.png',
  '/icon-maskable-512.png',
  '/apple-touch-icon.png'
];

// Instalación: precachea el shell
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_VERSION)
      .then((cache) => cache.addAll(APP_SHELL).catch(() => {}))
      .then(() => self.skipWaiting())
  );
});

// Activación: limpia caches viejos de versiones anteriores
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_VERSION).map((k) => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;

  // Solo manejamos GET; el resto (POST a Supabase, etc.) pasa directo a la red
  if (req.method !== 'GET') return;

  const url = new URL(req.url);

  // NO interceptar nada que no sea de nuestro propio origen:
  // Supabase, Google Fonts, CDNs → siempre red directa, sin cache.
  if (url.origin !== self.location.origin) return;

  // App shell → network-first con fallback a cache (para offline)
  event.respondWith(
    fetch(req)
      .then((res) => {
        // Guardamos una copia fresca del shell
        const copy = res.clone();
        caches.open(CACHE_VERSION).then((cache) => cache.put(req, copy)).catch(() => {});
        return res;
      })
      .catch(() =>
        caches.match(req).then((cached) => cached || caches.match('/index.html'))
      )
  );
});
