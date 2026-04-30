-- ============================================================
-- SALUDESCOLAR AR — Schema completo de base de datos
-- Ejecutar en Supabase SQL Editor
-- ============================================================

-- Habilitar extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- TABLA: escuelas
-- ============================================================
CREATE TABLE IF NOT EXISTS escuelas (
  id          UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  nombre      TEXT NOT NULL,
  distrito    TEXT NOT NULL,
  codigo      TEXT UNIQUE NOT NULL,
  direccion   TEXT,
  telefono    TEXT,
  activa      BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Escuelas iniciales de prueba
INSERT INTO escuelas (nombre, distrito, codigo, direccion) VALUES
  ('Escuela N° 42', 'La Plata',  'ESC42', 'Calle 7 Nº 1234, La Plata'),
  ('Escuela N° 17', 'Berisso',   'ESC17', 'Av. Montevideo 456, Berisso'),
  ('Escuela N° 58', 'Ensenada',  'ESC58', 'Calle Roma 789, Ensenada');

-- ============================================================
-- TABLA: usuarios (extendida sobre auth.users de Supabase)
-- ============================================================
CREATE TABLE IF NOT EXISTS usuarios (
  id              UUID REFERENCES auth.users(id) PRIMARY KEY,
  nombre_completo TEXT NOT NULL,
  rol             TEXT NOT NULL CHECK (rol IN ('docente','enfermero','director')),
  matricula       TEXT,
  escuela_id      UUID REFERENCES escuelas(id) NOT NULL,
  activo          BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLA: alumnos
-- ============================================================
CREATE TABLE IF NOT EXISTS alumnos (
  id                  UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  escuela_id          UUID REFERENCES escuelas(id) NOT NULL,
  nombre_completo     TEXT NOT NULL,
  dni                 TEXT NOT NULL,
  edad                INTEGER,
  grado               TEXT,
  turno               TEXT,
  antecedentes        TEXT[] DEFAULT '{}',
  medicacion          TEXT,
  alergias            TEXT,
  medico_cabecera     TEXT,
  contacto1_nombre    TEXT,
  contacto1_tel       TEXT,
  contacto2_nombre    TEXT,
  contacto2_tel       TEXT,
  activo              BOOLEAN DEFAULT true,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLA: eventos
-- ============================================================
CREATE TABLE IF NOT EXISTS eventos (
  id                      UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  codigo                  TEXT UNIQUE NOT NULL,
  escuela_id              UUID REFERENCES escuelas(id) NOT NULL,
  alumno_id               UUID REFERENCES alumnos(id),
  alumno_nombre           TEXT NOT NULL,
  alumno_grado            TEXT,
  alumno_dni              TEXT,
  alumno_edad             INTEGER,
  registrado_por          UUID REFERENCES usuarios(id),
  rol_registro            TEXT,
  fecha                   DATE NOT NULL DEFAULT CURRENT_DATE,
  hora                    TIME NOT NULL DEFAULT CURRENT_TIME,
  lugar                   TEXT,
  tipo_evento             TEXT NOT NULL,
  gravedad                TEXT NOT NULL,
  descripcion             TEXT,
  sintomas                TEXT,
  frecuencia_cardiaca     TEXT,
  saturacion_o2           TEXT,
  temperatura             TEXT,
  glucemia                TEXT,
  medicamento             TEXT,
  dosis                   TEXT,
  hora_admin              TEXT,
  intervencion            TEXT,
  derivacion              TEXT,
  familia_notificada      BOOLEAN DEFAULT false,
  directivos_notificados  BOOLEAN DEFAULT false,
  docente_notificado      BOOLEAN DEFAULT false,
  alumno_retirado         BOOLEAN DEFAULT false,
  enfermero_nombre        TEXT,
  matricula               TEXT,
  observaciones           TEXT,
  fotos_urls              TEXT[] DEFAULT '{}',
  created_at              TIMESTAMPTZ DEFAULT NOW(),
  updated_at              TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLA: notificaciones
-- ============================================================
CREATE TABLE IF NOT EXISTS notificaciones (
  id          UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  escuela_id  UUID REFERENCES escuelas(id) NOT NULL,
  para_rol    TEXT NOT NULL DEFAULT 'todos',
  titulo      TEXT NOT NULL,
  cuerpo      TEXT NOT NULL,
  urgente     BOOLEAN DEFAULT false,
  leida       BOOLEAN DEFAULT false,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ROW LEVEL SECURITY — AISLAMIENTO TOTAL POR ESCUELA
-- ============================================================

-- Habilitar RLS en todas las tablas sensibles
ALTER TABLE alumnos        ENABLE ROW LEVEL SECURITY;
ALTER TABLE eventos        ENABLE ROW LEVEL SECURITY;
ALTER TABLE notificaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuarios       ENABLE ROW LEVEL SECURITY;

-- Función helper: obtener escuela_id del usuario actual
CREATE OR REPLACE FUNCTION mi_escuela_id()
RETURNS UUID AS $$
  SELECT escuela_id FROM usuarios WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER;

-- Función helper: obtener rol del usuario actual
CREATE OR REPLACE FUNCTION mi_rol()
RETURNS TEXT AS $$
  SELECT rol FROM usuarios WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER;

-- ============ POLÍTICAS: alumnos ============
-- Solo ver alumnos de mi escuela
CREATE POLICY "alumnos_select" ON alumnos
  FOR SELECT USING (escuela_id = mi_escuela_id());

-- Insertar alumnos solo en mi escuela (enfermero y director)
CREATE POLICY "alumnos_insert" ON alumnos
  FOR INSERT WITH CHECK (
    escuela_id = mi_escuela_id()
    AND mi_rol() IN ('enfermero','director')
  );

-- Editar alumnos de mi escuela (enfermero y director)
CREATE POLICY "alumnos_update" ON alumnos
  FOR UPDATE USING (
    escuela_id = mi_escuela_id()
    AND mi_rol() IN ('enfermero','director')
  );

-- ============ POLÍTICAS: eventos ============
-- Ver eventos solo de mi escuela
CREATE POLICY "eventos_select" ON eventos
  FOR SELECT USING (escuela_id = mi_escuela_id());

-- Insertar eventos en mi escuela (todos los roles)
CREATE POLICY "eventos_insert" ON eventos
  FOR INSERT WITH CHECK (escuela_id = mi_escuela_id());

-- Editar eventos (enfermero y director)
CREATE POLICY "eventos_update" ON eventos
  FOR UPDATE USING (
    escuela_id = mi_escuela_id()
    AND mi_rol() IN ('enfermero','director')
  );

-- ============ POLÍTICAS: notificaciones ============
CREATE POLICY "notif_select" ON notificaciones
  FOR SELECT USING (escuela_id = mi_escuela_id());

CREATE POLICY "notif_update" ON notificaciones
  FOR UPDATE USING (escuela_id = mi_escuela_id());

-- ============ POLÍTICAS: usuarios ============
-- Solo ver usuarios de mi escuela
CREATE POLICY "usuarios_select" ON usuarios
  FOR SELECT USING (escuela_id = mi_escuela_id());

-- ============================================================
-- ÍNDICES para performance
-- ============================================================
CREATE INDEX idx_eventos_escuela    ON eventos(escuela_id);
CREATE INDEX idx_eventos_fecha      ON eventos(fecha DESC);
CREATE INDEX idx_eventos_alumno     ON eventos(alumno_id);
CREATE INDEX idx_alumnos_escuela    ON alumnos(escuela_id);
CREATE INDEX idx_alumnos_dni        ON alumnos(dni);
CREATE INDEX idx_notif_escuela      ON notificaciones(escuela_id);

-- ============================================================
-- TRIGGER: generar código de evento automático
-- ============================================================
CREATE OR REPLACE FUNCTION generar_codigo_evento()
RETURNS TRIGGER AS $$
DECLARE
  año TEXT;
  correlativo TEXT;
  cod TEXT;
BEGIN
  año := TO_CHAR(NOW(), 'YYYY');
  SELECT LPAD((COUNT(*)+1)::TEXT, 4, '0')
    INTO correlativo
    FROM eventos
    WHERE DATE_PART('year', created_at) = DATE_PART('year', NOW())
    AND escuela_id = NEW.escuela_id;
  NEW.codigo := 'EVT-' || año || '-' || correlativo;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_codigo_evento
  BEFORE INSERT ON eventos
  FOR EACH ROW
  WHEN (NEW.codigo IS NULL OR NEW.codigo = '')
  EXECUTE FUNCTION generar_codigo_evento();

-- ============================================================
-- TRIGGER: updated_at automático
-- ============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_alumnos_updated_at
  BEFORE UPDATE ON alumnos
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_eventos_updated_at
  BEFORE UPDATE ON eventos
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- VISTA: estadísticas por escuela (para dashboard)
-- Accesible solo dentro de la escuela del usuario
-- ============================================================
CREATE OR REPLACE VIEW v_estadisticas_escuela AS
SELECT
  e.escuela_id,
  COUNT(*)                                         AS total_eventos,
  COUNT(*) FILTER (WHERE DATE_TRUNC('month', e.fecha) = DATE_TRUNC('month', NOW())) AS eventos_mes,
  COUNT(*) FILTER (WHERE e.derivacion = 'Resuelto in situ')     AS resueltos_insitu,
  COUNT(*) FILTER (WHERE e.gravedad = 'grave')                  AS graves,
  COUNT(*) FILTER (WHERE e.gravedad = 'emergencia')             AS emergencias,
  COUNT(*) FILTER (WHERE e.fecha = CURRENT_DATE)                AS eventos_hoy,
  ROUND(COUNT(*) FILTER (WHERE e.derivacion = 'Resuelto in situ')::NUMERIC / NULLIF(COUNT(*),0) * 100, 1) AS pct_insitu,
  DATE_TRUNC('year', NOW())::DATE                               AS año
FROM eventos e
WHERE e.escuela_id = mi_escuela_id()
GROUP BY e.escuela_id;

