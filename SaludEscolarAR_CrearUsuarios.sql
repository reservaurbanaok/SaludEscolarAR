-- ============================================================
-- CREAR USUARIOS INICIALES EN SUPABASE AUTH
-- Ejecutá esto en el SQL Editor de Supabase
-- DESPUÉS de haber ejecutado el schema principal
-- ============================================================

-- PASO 1: Crear usuarios en Supabase Auth
-- Ir a Authentication → Users → Add user (en el dashboard)
-- O ejecutar con el cliente admin:

-- Usuario 1: Enfermera (Escuela N°42)
-- Email: m.rodriguez@saludescolar.ar
-- Password: SaludEscolar2026!
-- Rol: enfermero

-- Usuario 2: Docente (Escuela N°42)  
-- Email: docente@saludescolar.ar
-- Password: SaludEscolar2026!
-- Rol: docente

-- Usuario 3: Director (Escuela N°42)
-- Email: director@saludescolar.ar
-- Password: SaludEscolar2026!
-- Rol: director

-- ============================================================
-- PASO 2: Después de crear los usuarios en Auth,
-- ejecutar este SQL para crear sus perfiles:
-- (Reemplazá los UUID con los reales que te da Supabase Auth)
-- ============================================================

-- Primero obtener los IDs de escuelas:
SELECT id, nombre, codigo FROM escuelas;

-- Luego insertar perfiles (reemplazá 'UUID-DEL-USUARIO' con el ID real):
/*
INSERT INTO usuarios (id, nombre_completo, rol, matricula, escuela_id) VALUES
  ('UUID-DE-M-RODRIGUEZ',  'Rodríguez, María Elena', 'enfermero', 'MP 12345', (SELECT id FROM escuelas WHERE codigo='ESC42')),
  ('UUID-DE-DOCENTE',      'Pérez, Ana',             'docente',   NULL,       (SELECT id FROM escuelas WHERE codigo='ESC42')),
  ('UUID-DE-DIRECTOR',     'González, Roberto',      'director',  NULL,       (SELECT id FROM escuelas WHERE codigo='ESC42'));
*/

-- ============================================================
-- VERIFICAR que todo quedó bien:
-- ============================================================
SELECT 
  u.nombre_completo,
  u.rol,
  e.nombre AS escuela,
  u.activo
FROM usuarios u
JOIN escuelas e ON u.escuela_id = e.id
ORDER BY u.rol;

-- ============================================================
-- DESHABILITAR confirmación de email (para desarrollo):
-- Ir a Authentication → Settings → Email Auth
-- Desactivar "Enable email confirmations"
-- ============================================================
