-- version = 13
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

drop VIEW if EXISTS reclada.v_class;
drop VIEW if EXISTS reclada.v_revision ;
drop VIEW if EXISTS reclada.v_active_object;

\i 'view/reclada.v_object.sql'
\i 'view/reclada.v_active_object.sql'
\i 'view/reclada.v_revision.sql'
\i 'view/reclada.v_class.sql'
