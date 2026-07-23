# Seguridad, datos y estadísticas — SaludEscolar AR

## Estado detectado el 23/07/2026

- La interfaz está publicada en Vercel.
- El `SUPABASE_URL` configurado en `index.html` apunta al proyecto
  `kpqsgnhhichlgmfiaxwh`.
- Ese hostname no resuelve actualmente en DNS. Hasta corregir el proyecto y
  sus credenciales públicas, la app no puede persistir información real.
- La cuenta Supabase disponible en Chrome sólo tiene acceso al proyecto
  `netroom-ia-docentes-salud` (`vbbvaiaokwvrpmtkqkml`). Sus tablas pertenecen
  a otra aplicación (`enrollments`, `profiles`, `progress`, cuestionarios y
  entregas), por lo que no debe reutilizarse sin una decisión explícita.

## Arquitectura de datos recomendada

Supabase debe ser la única fuente oficial de información:

- **Auth:** identidad y sesión del personal.
- **`usuarios`:** rol y escuela asignada a cada cuenta.
- **`escuelas`:** instituciones.
- **`alumnos`:** ficha escolar y antecedentes necesarios.
- **`eventos`:** cada atención, intervención, derivación y seguimiento.
- **`notificaciones`:** alertas operativas.
- **Storage privado `fotos-eventos`:** fotografías, organizadas por
  `<escuela_uuid>/<evento_uuid>/<archivo>`.

Vercel sólo aloja la interfaz. GitHub guarda el código, no los registros.
El navegador puede conservar una sesión y el service worker, pero no debe ser
la fuente oficial de fichas médicas.

## Estadísticas

La app puede consultar Supabase y construir directamente:

- eventos por día, mes, trimestre y escuela;
- tipos de evento más frecuentes;
- gravedad y derivaciones;
- porcentaje resuelto en la escuela;
- tiempos de respuesta de ambulancia;
- recurrencia por grado;
- evolución temporal.

Chart.js dibuja los gráficos, pero los números deben salir de consultas o
vistas SQL sobre Supabase. Para pocos registros puede agregarlos el cliente.
Cuando crezca el volumen, conviene crear vistas o funciones SQL agregadas para
evitar descargar fichas individuales al navegador.

Google Sheets/Excel debe usarse sólo para exportaciones autorizadas, análisis
puntuales o reportes desidentificados. No debe convertirse en una segunda base
paralela de datos médicos.

## Orden seguro de puesta en producción

1. Recuperar acceso al proyecto Supabase correcto o crear uno exclusivo.
2. Ejecutar el esquema base si el proyecto está vacío.
3. Ejecutar `RLS_SaludEscolarAR.sql`.
4. Configurar el URL y la publishable/anon key correctos en la app.
5. Crear dos usuarios de prueba en escuelas diferentes.
6. Probar lectura, inserción y actualización cruzadas.
7. Desplegar la versión de la app que usa fotografías privadas.
8. Cargar datos reales sólo después de superar todas las pruebas.

## Prueba obligatoria entre escuelas

Con un registro señuelo no sensible en cada escuela:

| Prueba | Usuario Escuela 42 | Resultado esperado |
|---|---|---|
| Leer alumnos de Escuela 42 | Permitido | Sólo Escuela 42 |
| Leer alumnos de Escuela 17 | Intentar | Cero filas |
| Leer eventos de Escuela 17 | Intentar | Cero filas |
| Insertar evento con `escuela_id` 17 | Intentar | Rechazado por RLS |
| Cambiar un evento propio a escuela 17 | Intentar | Rechazado por RLS |
| Descargar foto de Escuela 17 | Intentar | 403/denegado |

Repetir la misma matriz invirtiendo los usuarios. También debe comprobarse que
una solicitud sin sesión no obtenga filas de ninguna tabla clínica.

## Datos mínimos y privacidad

- Registrar solamente lo necesario para la atención escolar.
- Evitar exportar DNI, teléfono, antecedentes o fotografías a planillas.
- No usar datos reales durante pruebas.
- Definir responsables, plazos de retención, copias de seguridad y respuesta
  ante incidentes antes del lanzamiento.
- Revisar el tratamiento con asesoría legal y de protección de datos aplicable.
