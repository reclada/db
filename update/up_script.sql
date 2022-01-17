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
\i 'function/reclada_object.get_schema.sql'
\i 'function/reclada.update_unique_object.sql'
\i 'function/reclada_object.get_active_status_obj_id.sql'
\i 'function/reclada_object.get_archive_status_obj_id.sql'
\i 'view/reclada.v_ui_active_object.sql'
\i 'view/reclada.get_children.sql'
\i 'view/reclada.v_filter_mapping.sql'
\i 'view/reclada.v_ui_active_object.sql'

select reclada.update_unique_object(null, true);

CREATE INDEX relationship_type_subject_object_index ON reclada.object USING btree ((attributes->>'type'), ((attributes->>'subject')::uuid), status, ((attributes->>'object')::uuid))
WHERE attributes->>'subject' IS NOT NULL AND attributes->>'object' IS NOT NULL  AND status=reclada_object.get_active_status_obj_id();

DROP INDEX parent_guid_index;
CREATE INDEX parent_guid_index ON reclada.object USING hash (parent_guid)
WHERE parent_guid IS NOT NULL;

DROP INDEX document_fileguid_index;
CREATE INDEX document_fileguid_index ON reclada.object USING btree ((attributes ->> 'fileGUID')) WHERE attributes ->> 'fileGUID' IS NOT NULL;

DROP INDEX file_uri_index;

DROP INDEX job_status_index;
CREATE INDEX job_status_index ON reclada.object USING btree (attributes ->> 'status')
WHERE attributes ->> 'status' IS NOT NULL;

DROP INDEX revision_index;
CREATE INDEX revision_index ON reclada.object USING btree (attributes ->> 'revision')
WHERE attributes ->> 'revision' IS NOT NULL;

DROP INDEX runner_type_index;
CREATE INDEX runner_type_index ON reclada.object USING btree (attributes ->> 'type')
WHERE attributes ->> 'type' IS NOT NULL;

DROP INDEX guid_index;
CREATE INDEX guid_index ON reclada.object USING hash (guid);


W