-- version = 49
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

alter table dev.component add parent_component_name text;

create table dev.meta_data(
    id bigint
        NOT NULL
        GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1)
        UNIQUE ,
    ver bigint,
    data jsonb
);

\i 'function/reclada_object.list.sql'
\i 'function/reclada.load_staging.sql'


DROP VIEW reclada.staging;

CREATE TABLE reclada.staging(
    data    jsonb   NOT NULL  
);

\i 'trigger/load_staging.sql'
