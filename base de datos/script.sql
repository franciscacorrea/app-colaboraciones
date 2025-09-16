DROP TABLE IF EXISTS entregable        CASCADE;
DROP TABLE IF EXISTS feedback          CASCADE;
DROP TABLE IF EXISTS colaboracion      CASCADE;
DROP TABLE IF EXISTS publicacion       CASCADE;
DROP TABLE IF EXISTS necesidad_habilidad CASCADE;
DROP TABLE IF EXISTS perfil_habilidad  CASCADE;
DROP TABLE IF EXISTS habilidad         CASCADE;
DROP TABLE IF EXISTS necesidad         CASCADE;
DROP TABLE IF EXISTS descartado        CASCADE;
DROP TABLE IF EXISTS match             CASCADE;
DROP TABLE IF EXISTS guardado          CASCADE;
DROP TABLE IF EXISTS perfil            CASCADE;
DROP TABLE IF EXISTS suscripcion       CASCADE;
DROP TABLE IF EXISTS plan              CASCADE;
DROP TABLE IF EXISTS usuario           CASCADE;

-- =====================================================================
-- Maestro: USUARIO / PLAN / SUSCRIPCION / PERFIL
-- =====================================================================

CREATE TABLE plan (
    id_plan        BIGSERIAL PRIMARY KEY,
    nombre         VARCHAR(80)        NOT NULL,
    techo          INTEGER            CHECK (techo IS NULL OR techo >= 0),
    precio         NUMERIC(12,2)      NOT NULL CHECK (precio >= 0)
);

CREATE TABLE usuario (
    id_usuario     BIGSERIAL PRIMARY KEY,
    id_plan        BIGINT REFERENCES plan(id_plan),
    nombre         VARCHAR(60)        NOT NULL,
    apellido       VARCHAR(60)        NOT NULL,
    email          VARCHAR(120)       NOT NULL UNIQUE,
    telefono       VARCHAR(30),
    contrasena     TEXT               NOT NULL,
    zona_horaria   VARCHAR(64),
    pais           VARCHAR(60)
);

CREATE TABLE suscripcion (
    id_suscripcion BIGSERIAL PRIMARY KEY,
    id_usuario     BIGINT NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    id_plan        BIGINT NOT NULL REFERENCES plan(id_plan),
    estado         VARCHAR(20) NOT NULL CHECK (estado IN ('activa','pendiente','pausada','vencida','cancelada')),
    inicio         DATE NOT NULL,
    fin            DATE
);

CREATE TABLE perfil (
    id_perfil      BIGSERIAL PRIMARY KEY,
    id_usuario     BIGINT NOT NULL UNIQUE REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    biografia      TEXT,
    whatsapp_url   TEXT,
    linkedin_url   TEXT,
    visibilidad    VARCHAR(20) NOT NULL DEFAULT 'publico' CHECK (visibilidad IN ('publico','privado')),
    reputacion     NUMERIC(3,2) CHECK (reputacion BETWEEN 0 AND 5)
);

-- =====================================================================
-- HABILIDADES y relaciones de N–M con Perfil y Necesidad
-- =====================================================================

CREATE TABLE habilidad (
    id_habilidad   BIGSERIAL PRIMARY KEY,
    nombre         VARCHAR(80) NOT NULL UNIQUE,
    descripcion    TEXT
);

CREATE TABLE perfil_habilidad (
    id_perfil_habilidad BIGSERIAL PRIMARY KEY,
    id_perfil      BIGINT NOT NULL REFERENCES perfil(id_perfil) ON DELETE CASCADE,
    id_habilidad   BIGINT NOT NULL REFERENCES habilidad(id_habilidad) ON DELETE CASCADE,
    UNIQUE (id_perfil, id_habilidad)
);

-- =====================================================================
-- PUBLICACION / NECESIDAD / MATCH / DESCARTADO / GUARDADO
-- =====================================================================

CREATE TABLE publicacion (
    id_publicacion BIGSERIAL PRIMARY KEY,
    id_usuario     BIGINT NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    tipo           VARCHAR(30) NOT NULL CHECK (tipo IN ('oferta','busqueda','anuncio')),
    descripcion    TEXT,
    estado         VARCHAR(20) NOT NULL DEFAULT 'activa' CHECK (estado IN ('activa','pausada','cerrada','eliminada')),
    fecha_creacion TIMESTAMP NOT NULL DEFAULT NOW(),
    fecha_cierre   TIMESTAMP
);

CREATE TABLE necesidad (
    id_necesidad   BIGSERIAL PRIMARY KEY,
    id_perfil      BIGINT NOT NULL REFERENCES perfil(id_perfil) ON DELETE CASCADE,
    descripcion    TEXT,
    modo           VARCHAR(20) CHECK (modo IN ('por_horas','por_entrega')),
    urgencia       VARCHAR(20) CHECK (urgencia IN ('alta','media','baja')),
    franja_horaria VARCHAR(60),
    estado         VARCHAR(20) NOT NULL DEFAULT 'abierta' CHECK (estado IN ('abierta','en_proceso','cerrada','cancelada')),
    deadline       TIMESTAMP
);

CREATE TABLE necesidad_habilidad (
    id_neces_habilidad BIGSERIAL PRIMARY KEY,
    id_necesidad   BIGINT NOT NULL REFERENCES necesidad(id_necesidad) ON DELETE CASCADE,
    id_habilidad   BIGINT NOT NULL REFERENCES habilidad(id_habilidad) ON DELETE CASCADE,
    UNIQUE (id_necesidad, id_habilidad)
);

-- Perfiles que un usuario guarda (bookmarks)
CREATE TABLE guardado (
    id_guardado    BIGSERIAL PRIMARY KEY,
    id_usuario     BIGINT NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    id_perfil      BIGINT NOT NULL REFERENCES perfil(id_perfil)   ON DELETE CASCADE,
    fecha_guardado TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (id_usuario, id_perfil)
);

-- Relación de “match” entre usuario y (publicación / necesidad)
CREATE TABLE match (
    id_match       BIGSERIAL PRIMARY KEY,
    id_usuario     BIGINT NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    id_publicacion BIGINT REFERENCES publicacion(id_publicacion) ON DELETE CASCADE,
    id_necesidad   BIGINT REFERENCES necesidad(id_necesidad)     ON DELETE CASCADE,
    estado         VARCHAR(20) NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente','aceptado','rechazado'))
    -- Regla: al menos uno de (id_publicacion, id_necesidad)
    ,CONSTRAINT chk_match_objetivo CHECK (
        (id_publicacion IS NOT NULL) OR (id_necesidad IS NOT NULL)
    )
);

-- Publicaciones descartadas por un usuario (con motivo)
CREATE TABLE descartado (
    id_descartado  BIGSERIAL PRIMARY KEY,
    id_usuario     BIGINT NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    id_publicacion BIGINT NOT NULL REFERENCES publicacion(id_publicacion) ON DELETE CASCADE,
    motivo         TEXT,
    fecha_descartado TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (id_usuario, id_publicacion)
);

-- =====================================================================
-- COLABORACION / FEEDBACK / ENTREGABLE
-- =====================================================================

CREATE TABLE colaboracion (
    id_colaboracion BIGSERIAL PRIMARY KEY,
    id_usuario     BIGINT NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    id_necesidad   BIGINT REFERENCES necesidad(id_necesidad) ON DELETE SET NULL,
    id_publicacion BIGINT REFERENCES publicacion(id_publicacion) ON DELETE SET NULL,
    modo           VARCHAR(20) CHECK (modo IN ('por_horas','por_entrega')),
    descripcion    TEXT,
    estado         VARCHAR(20) NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente','aceptada','rechazada','en_curso','finalizada','cancelada')),
    deadline       TIMESTAMP,
    calificacion   NUMERIC(3,2) CHECK (calificacion IS NULL OR (calificacion >= 0 AND calificacion <= 5))
    ,CONSTRAINT chk_colab_origen CHECK (
        (id_necesidad IS NOT NULL) OR (id_publicacion IS NOT NULL)
    )
);

CREATE TABLE feedback (
    id_feedback    BIGSERIAL PRIMARY KEY,
    id_colaboracion BIGINT NOT NULL REFERENCES colaboracion(id_colaboracion) ON DELETE CASCADE,
    id_usuario     BIGINT NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    cantidad_estrellas INTEGER NOT NULL CHECK (cantidad_estrellas BETWEEN 1 AND 5),
    fecha_resena   TIMESTAMP NOT NULL DEFAULT NOW(),
    comentario     TEXT,
    UNIQUE (id_colaboracion, id_usuario)  -- 1 reseña por usuario por colaboración
);

CREATE TABLE entregable (
    id_entregable  BIGSERIAL PRIMARY KEY,
    id_colaboracion BIGINT NOT NULL REFERENCES colaboracion(id_colaboracion) ON DELETE CASCADE,
    titulo         VARCHAR(160) NOT NULL,
    estado         VARCHAR(20) NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente','enviado','aprobado','rechazado')),
    url            TEXT
);

-- =====================================================================
-- ÍNDICES útiles
-- =====================================================================

CREATE INDEX idx_usuario_plan        ON usuario(id_plan);
CREATE INDEX idx_perfil_usuario      ON perfil(id_usuario);
CREATE INDEX idx_pub_usuario_estado  ON publicacion(id_usuario, estado);
CREATE INDEX idx_pub_fechas          ON publicacion(fecha_creacion);
CREATE INDEX idx_nec_perfil_estado   ON necesidad(id_perfil, estado);
CREATE INDEX idx_colab_usuario_estado ON colaboracion(id_usuario, estado);
CREATE INDEX idx_feedback_colab      ON feedback(id_colaboracion);
CREATE INDEX idx_guardado_usuario    ON guardado(id_usuario);
CREATE INDEX idx_descartado_usuario  ON descartado(id_usuario);
CREATE INDEX idx_match_usuario       ON match(id_usuario);

-- =====================================================================
-- Valores de ejemplo mínimos (opcional)
-- INSERTS de referencia pueden ir aquí si los necesitás para probar.
-- =====================================================================
 
