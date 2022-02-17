-- version = 49
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

\i 'function/reclada_object.list.sql'

--} REC-562


--{ REC-564
drop function reclada_object.datasource_insert;
\i 'function/reclada_object.object_insert.sql'
\i 'function/reclada_object.delete.sql'
\i 'function/dev.begin_install_component.sql'
\i 'function/dev.finish_install_component.sql'
\i 'view/reclada.v_ui_active_object.sql' 

--} REC-564 

\i 'function/reclada_object.update.sql'
\i 'function/reclada_object.create.sql'
\i 'function/reclada_object.merge.sql'
\i 'view/reclada.v_object_unifields.sql'