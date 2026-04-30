/* ============================================================
   SERVICE WORKER — SaludEscolar AR
   Versión: 1.0.0
   Estrategia: Cache-first para assets estáticos,
               Network-first para datos de Supabase.
   ============================================================ */

const CACHE_NAME    = 'saludescolar-v1';
const CACHE_OFFLINE = 'saludescolar-offline-v1';

// Assets que se cachean en la instalación — disponibles siempre offline
const ASSETS_PRECACHE = [
  '/',
  '/index.html',
  'https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800;900&family=DM+Sans:ital,opsz,wght@0,9..40,400;0,9..40,500;0,9..40,600;0,9..40,700&display=swap',
  'https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.min.js',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js',
];

// URLs de Supabase — siempre se intenta la red primero
const SUPABASE_ORIGIN = 'https://kpqsgnhhichlgmfiaxwh.supabase.co';

/* ---- INSTALL: precachear assets críticos ---- */
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => {
      return cache.addAll(ASSETS_PRECACHE).catch(err => {
        // Si algún asset externo falla, no bloquear la instalación
        console.warn('[SW] Algunos assets no pudieron cachearse:', err);
      });
    }).then(() => self.skipWaiting())
  );
});

/* ---- ACTIVATE: limpiar caches viejos ---- */
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(
        keys
          .filter(k => k !== CACHE_NAME && k !== CACHE_OFFLINE)
          .map(k => {
            console.log('[SW] Eliminando cache viejo:', k);
            return caches.delete(k);
          })
      )
    ).then(() => self.clients.claim())
  );
});

/* ---- FETCH: estrategia inteligente por tipo de request ---- */
self.addEventListener('fetch', event => {
  const { request } = event;
  const url = new URL(request.url);

  // 1. Supabase — siempre red primero (datos siempre frescos)
  if (url.origin === SUPABASE_ORIGIN) {
    event.respondWith(networkFirst(request));
    return;
  }

  // 2. Google Fonts — cache primero (no cambian)
  if (url.origin === 'https://fonts.googleapis.com' || url.origin === 'https://fonts.gstatic.com') {
    event.respondWith(cacheFirst(request));
    return;
  }

  // 3. CDN assets (Chart.js, Supabase JS) — cache primero
  if (url.hostname.includes('cdnjs.cloudflare.com') || url.hostname.includes('jsdelivr.net')) {
    event.respondWith(cacheFirst(request));
    return;
  }

  // 4. El HTML principal y todo lo demás — stale-while-revalidate
  //    Responde inmediatamente desde cache y actualiza en background
  event.respondWith(staleWhileRevalidate(request));
});

/* ---- Estrategia: Network first (Supabase) ---- */
async function networkFirst(request) {
  try {
    const response = await fetch(request.clone());
    // Solo cachear respuestas GET exitosas
    if (request.method === 'GET' && response.ok) {
      const cache = await caches.open(CACHE_NAME);
      cache.put(request, response.clone());
    }
    return response;
  } catch {
    // Sin red: intentar desde cache
    const cached = await caches.match(request);
    return cached || offlineFallback();
  }
}

/* ---- Estrategia: Cache first (assets estáticos) ---- */
async function cacheFirst(request) {
  const cached = await caches.match(request);
  if (cached) return cached;
  try {
    const response = await fetch(request.clone());
    if (response.ok) {
      const cache = await caches.open(CACHE_NAME);
      cache.put(request, response.clone());
    }
    return response;
  } catch {
    return offlineFallback();
  }
}

/* ---- Estrategia: Stale-while-revalidate (HTML principal) ---- */
async function staleWhileRevalidate(request) {
  const cache  = await caches.open(CACHE_NAME);
  const cached = await cache.match(request);

  // Actualizar en background sin esperar
  const networkPromise = fetch(request.clone()).then(response => {
    if (response.ok) cache.put(request, response.clone());
    return response;
  }).catch(() => null);

  // Si hay cache, responder inmediatamente; si no, esperar la red
  return cached || networkPromise || offlineFallback();
}

/* ---- Página offline de fallback ---- */
function offlineFallback() {
  return new Response(`
    <!DOCTYPE html>
    <html lang="es">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Sin conexión — SaludEscolar AR</title>
      <style>
        * { margin:0; padding:0; box-sizing:border-box; }
        body {
          font-family: 'DM Sans', Arial, sans-serif;
          background: #0d2137;
          color: white;
          min-height: 100dvh;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          padding: 32px 24px;
          text-align: center;
        }
        .icon { font-size: 56px; margin-bottom: 20px; }
        h1 { font-size: 22px; font-weight: 800; margin-bottom: 10px; }
        p { font-size: 14px; color: rgba(255,255,255,0.65); line-height: 1.6; margin-bottom: 6px; }
        .tip {
          margin-top: 28px;
          background: rgba(255,255,255,0.08);
          border-radius: 14px;
          padding: 16px 20px;
          font-size: 12px;
          color: rgba(255,255,255,0.5);
          max-width: 320px;
        }
        button {
          margin-top: 24px;
          padding: 12px 28px;
          border-radius: 10px;
          border: none;
          background: #2980b9;
          color: white;
          font-size: 14px;
          font-weight: 700;
          cursor: pointer;
        }
      </style>
    </head>
    <body>
      <div class="icon">📡</div>
      <h1>Sin conexión</h1>
      <p>SaludEscolar AR necesita internet</p>
      <p>para acceder a los datos en tiempo real.</p>
      <div class="tip">
        💡 Para registrar eventos sin conexión, consultá con tu administrador sobre el modo de trabajo offline institucional.
      </div>
      <button onclick="window.location.reload()">Reintentar conexión</button>
    </body>
    </html>
  `, {
    status: 503,
    headers: { 'Content-Type': 'text/html; charset=utf-8' }
  });
}

/* ---- Recibir mensajes desde la app (ej: forzar update) ---- */
self.addEventListener('message', event => {
  if (event.data === 'SKIP_WAITING') {
    self.skipWaiting();
  }
  if (event.data === 'CLEAR_CACHE') {
    caches.keys().then(keys => Promise.all(keys.map(k => caches.delete(k))));
  }
});
