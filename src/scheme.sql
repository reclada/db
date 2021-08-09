CREATE EXTENSION "postgres-json-schema";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "plpython3u";
CREATE SCHEMA reclada;

\i recladaobj_scheme.sql
\i dev.sql

