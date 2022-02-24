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

CREATE TABLE reclada.staging(
    data    jsonb   NOT NULL,
    id      bigint
);

ALTER TABLE reclada.staging ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME reclada.staging_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

