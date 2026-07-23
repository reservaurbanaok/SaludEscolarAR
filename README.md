# 🏥 SaludEscolar AR

**Sistema de enfermería escolar digital · Provincia de Buenos Aires**

App web progresiva (PWA) para registro y gestión de eventos de salud en escuelas.
Desarrollada para enfermeros/as escolares, directivos e inspectores de la DGCyE.

---

## 📁 Estructura del repositorio

```
saludescolar-ar/
├── index.html           → App completa (HTML + CSS + JS en un único archivo)
├── manifest.json        → Configuración PWA (nombre, íconos, colores)
├── service-worker.js    → Cache offline y estrategia de red
├── icon-192.png         → Ícono de la app (pantalla de inicio)
├── icon-512.png         → Ícono de la app (splash screen)
├── vercel.json          → Headers y rewrites para Vercel
└── README.md            → Este archivo
```

---

## 🚀 Deploy en Vercel

### Primera vez

1. Subí todos los archivos a un repositorio **privado** en GitHub
2. Entrá a [vercel.com](https://vercel.com) e iniciá sesión con tu cuenta de GitHub
3. Hacé click en **"Add New Project"**
4. Seleccioná el repositorio `saludescolar-ar`
5. En la pantalla de configuración:
   - **Framework Preset:** `Other`
   - **Build Command:** *(dejar vacío)*
   - **Output Directory:** *(dejar vacío)*
   - **Install Command:** *(dejar vacío)*
6. Click en **Deploy** — en 30 segundos está online

Vercel te asigna una URL del tipo `saludescolar-ar.vercel.app`.

### Deploys siguientes

Cada vez que hacés `git push` al branch `main`, Vercel redespliega automáticamente.
No hace falta entrar al panel — el deploy es instantáneo.

---

## 🌐 Dominio propio (saludescolar.ar)

### Paso 1 — Registrar el dominio

1. Entrá a [nic.ar](https://nic.ar)
2. Buscá `saludescolar.ar` y registralo (~$3.000 ARS/año)
3. En la configuración DNS del dominio, agregá estos registros:

| Tipo  | Nombre | Valor                    |
|-------|--------|--------------------------|
| A     | @      | 76.76.21.21              |
| CNAME | www    | cname.vercel-dns.com     |

### Paso 2 — Conectar en Vercel

1. Vercel → tu proyecto → **Settings → Domains**
2. Escribí `saludescolar.ar` → **Add**
3. Repetí con `www.saludescolar.ar`
4. Vercel configura el SSL automáticamente en menos de 5 minutos

---

## 🔐 Credenciales y seguridad

### ⚠️ Mantené este repositorio PRIVADO

El archivo `index.html` contiene las credenciales de Supabase (`SUPABASE_URL` y `SUPABASE_ANON_KEY`).
Aunque la `anon key` de Supabase está diseñada para ser pública, es buena práctica no exponerla en un repo público.

### Row Level Security (RLS)

La seguridad real está en Supabase, no en las keys del cliente.
Antes de cargar datos reales, ejecutá el archivo `RLS_SaludEscolarAR.sql` en el SQL Editor de Supabase.
Con RLS activo, aunque alguien tenga la anon key, **solo puede ver los datos de su propia escuela**.

### Usuarios del sistema

| Rol        | Email                          | Acceso                                      |
|------------|-------------------------------|---------------------------------------------|
| Enfermero/a | `m.rodriguez@saludescolar.ar` | Panel + Registro + Historial + Protocolos   |
| Docente    | `docente@saludescolar.ar`     | Solo Protocolos                             |
| Director/a | `director@saludescolar.ar`    | Todo + Panel Ejecutivo (requiere PIN: 9999) |

Contraseña: configurada en Supabase Auth (no hardcodeada en el código).

---

## 📱 PWA — Instalación en celulares

Una vez desplegada en Vercel, la app puede instalarse como aplicación nativa:

**Android (Chrome):**
> El navegador muestra un banner automático: *"Agregar SaludEscolar a pantalla de inicio"*. Un toque y queda instalada.

**iOS (Safari):**
> Botón compartir → *"Agregar a pantalla de inicio"* → *Agregar*

La app instalada funciona sin barra del navegador, tiene ícono propio y muestra una pantalla de error amigable si no hay conexión.

---

## 📦 Empaquetado para Google Play y App Store

Una vez que la URL de Vercel esté funcionando con el dominio propio:

### Android — Google Play

1. Entrá a [pwabuilder.com](https://pwabuilder.com)
2. Pegá la URL: `https://saludescolar.ar`
3. Click en **"Package for stores"** → **Android**
4. Descargás un `.aab` (Android App Bundle)
5. Subís el `.aab` a [Google Play Console](https://play.google.com/console)
6. Necesitás una cuenta de desarrollador Google: **$25 USD pago único**
7. Revisión de Google: 3-7 días hábiles

### iOS — App Store

1. En [pwabuilder.com](https://pwabuilder.com) → **iOS**
2. Descargás el paquete `.zip` con el proyecto Xcode
3. Necesitás una Mac con Xcode instalado para compilar y subir
4. Cuenta Apple Developer: **$99 USD/año**
5. Revisión de Apple: 1-5 días hábiles

### Instalación directa en Android (sin Play Store)

Para distribuir la app internamente entre el personal de las escuelas **sin pasar por Google Play**:

1. En [pwabuilder.com](https://pwabuilder.com) → Android → seleccioná **APK** en lugar de AAB
2. Descargás el `.apk`
3. Lo enviás por WhatsApp o email a cada celular
4. El usuario activa "Instalar desde fuentes desconocidas" y lo instala directo

> ✅ Esta es la opción más rápida para el lanzamiento interno con las 3 escuelas.

---

## 🗄️ Base de datos — Supabase

**Proyecto:** `kpqsgnhhichlgmfiaxwh`
**Región:** South America (São Paulo)

### Tablas

| Tabla              | Descripción                              |
|--------------------|------------------------------------------|
| `usuarios`         | Perfiles del personal (enfermeros, directivos) |
| `escuelas`         | Instituciones activas en el sistema      |
| `alumnos`          | Fichas de alumnos (activo = true)        |
| `eventos`          | Registros de eventos de salud            |
| `notificaciones`   | Alertas del sistema por usuario          |

### Vista

| Vista                    | Descripción                               |
|--------------------------|-------------------------------------------|
| `v_estadisticas_escuela` | KPIs agregados por escuela y período      |

### Storage

| Bucket          | Uso                                        |
|-----------------|--------------------------------------------|
| `fotos-eventos` | Imágenes privadas; acceso temporal mediante URL firmada |

La arquitectura, las pruebas entre escuelas y el uso recomendado de
estadísticas están documentados en `SEGURIDAD_Y_DATOS.md`.

### Estadísticas

El panel, el dashboard avanzado y los informes se calculan directamente desde
las tablas `eventos` y `alumnos` de Supabase. RLS limita automáticamente cada
consulta a la escuela del usuario autenticado. Si todavía no hay registros, la
app muestra indicadores en cero; nunca reemplaza un error con datos demo.

---

## 🛠️ Stack tecnológico

| Tecnología              | Uso                                      |
|-------------------------|------------------------------------------|
| HTML5 + CSS3 + JS ES6+  | App completa — sin frameworks, sin build |
| Supabase                | Base de datos, autenticación, storage    |
| Chart.js 4.4.1          | Gráficos del panel ejecutivo             |
| Google Fonts            | Outfit (display) + DM Sans (cuerpo)      |
| Vercel                  | Hosting con deploy automático desde Git  |
| PWA (manifest + SW)     | Instalable como app nativa en celulares  |

---

## 📋 Tareas pendientes antes del lanzamiento oficial

- [x] Confirmar y restaurar el proyecto Supabase configurado
- [x] Ejecutar `RLS_SaludEscolarAR.sql` en Supabase SQL Editor
- [ ] Verificar aislamiento con dos usuarios de escuelas diferentes
- [x] Confirmar que `fotos-eventos` sea privado
- [ ] Registrar dominio `saludescolar.ar` en NIC Argentina
- [ ] Cargar datos reales de alumnos en tabla `alumnos`
- [ ] Crear usuarios reales en Supabase Auth para todo el personal
- [ ] Verificar PWA en [pwabuilder.com](https://pwabuilder.com) (debe dar 100%)
- [ ] Generar APK para distribución interna entre las 3 escuelas
- [ ] Capacitación del personal (enfermeros, docentes, directivos)
- [ ] Marco legal — Ley 25.326 protección de datos personales Argentina

---

## 👤 Contacto y soporte

Sistema desarrollado para uso institucional de la DGCyE — Provincia de Buenos Aires.
Para soporte técnico o nuevas funcionalidades, contactar al administrador del sistema.

---

*SaludEscolar AR · Abril 2026 · Versión 1.0.0*
