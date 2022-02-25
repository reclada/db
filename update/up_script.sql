-- version = 49
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

\i 'function/reclada_object.list.sql'
\i 'view/reclada.v_ui_active_object.sql' 

\i 'function/reclada_object.update.sql'
\i 'function/reclada_object.create.sql'
\i 'function/reclada_object.merge.sql'
\i 'view/reclada.v_object_unifields.sql'

ALTER SEQUENCE IF EXISTS reclada.object_id_seq CACHE 10;