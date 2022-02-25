-- version = 49
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

\i 'function/reclada_object.list.sql'
\i 'function/reclada.load_staging.sql'


DROP VIEW reclada.staging;

CREATE TABLE reclada.staging(
    data    jsonb   NOT NULL  
);

\i 'trigger/load_staging.sql'
