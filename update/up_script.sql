-- version = 46
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

create table reclada.field
(
    id      bigint 
        NOT NULL 
        GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1) 
        UNIQUE ,
    path      text  
        NOT NULL,
    json_type text  
        NOT NULL,
    PRIMARY KEY (path, json_type)
);

create table reclada.unique_object
(
    id bigint 
        NOT NULL 
        GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1)
        UNIQUE,
    id_field bigint[]
        NOT NULL,
    PRIMARY KEY (id_field)
);

create table reclada.unique_object_reclada_object
(
    id bigint 
        NOT NULL 
        GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1),
    id_unique_object    bigint 
        NOT NULL 
        REFERENCES reclada.unique_object(id),
    id_reclada_object    bigint 
        NOT NULL 
        REFERENCES reclada.object(id) ON DELETE CASCADE,
    PRIMARY KEY(id_unique_object,id_reclada_object)
);

\i 'function/reclada_object.create.sql'
\i 'function/reclada_object.update.sql'
\i 'function/reclada_object.list.sql'
\i 'function/reclada.update_unique_object.sql'
\i 'view/reclada.v_ui_active_object.sql'
\i 'view/reclada.get_children.sql'
\i 'view/reclada.v_filter_mapping.sql'
\i 'view/reclada.v_ui_active_object.sql'
