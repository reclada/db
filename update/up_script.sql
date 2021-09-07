-- version = 17
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/
DROP TABLE IF EXISTS reclada.staging;
\i 'function/reclada.load_staging.sql'
\i 'view/reclada.staging.sql'
\i 'trigger/load_staging.sql'


