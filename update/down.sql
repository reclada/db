-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

drop table reclada.unique_object_reclada_object;
drop table reclada.unique_object;
drop table reclada.field;

--{function/reclada_object.create}
--{function/reclada_object.create_subclass}
--{function/reclada_object.get_schema}
--{function/reclada_object.update}
--{function/reclada_object.list}
--{function/reclada.update_unique_object}
--{function/reclada_object.explode_jsonb}
--{function/reclada_object.refresh_mv}
--{view/reclada.get_duplicates}
--{view/reclada.v_filter_mapping}
--{view/reclada.v_unifields_pivoted}
--{view/reclada.v_get_duplicates_query}

DROP INDEX relationship_type_subject_object_index;

DROP INDEX parent_guid_index;
CREATE INDEX parent_guid_index ON reclada.object USING btree ((parent_guid));

DROP INDEX document_fileguid_index;
CREATE INDEX document_fileguid_index ON reclada.object USING btree ((attributes ->> 'fileGUID'));

CREATE INDEX file_uri_index ON reclada.object USING btree ((attributes ->> 'uri'));

DROP INDEX job_status_index;
CREATE INDEX job_status_index ON reclada.object USING btree ((attributes ->> 'status'));

DROP INDEX revision_index;
CREATE INDEX revision_index ON reclada.object USING btree ((attributes ->> 'revision'));

DROP INDEX runner_type_index;
CREATE INDEX runner_type_index ON reclada.object USING btree ((attributes ->> 'type'));

DROP INDEX guid_index;
CREATE INDEX guid_index ON reclada.object USING btree ((guid));

DROP INDEX checksum_index_;
CREATE INDEX checksum_index_ ON reclada.object USING hash ((attributes ->> 'checksum'));

DROP INDEX uri_index_;
CREATE INDEX uri_index_ ON reclada.object USING hash ((attributes ->> 'uri'));

DO $$
DECLARE
_index_name text;
_indexes        TEXT[];
BEGIN
    SELECT array_agg(indexname)
    FROM pg_catalog.pg_indexes
    WHERE indexname LIKE '%_v47'
        AND schemaname ='reclada'
        AND tablename ='object'
    INTO _indexes;
    
    IF _indexes IS NOT NULL THEN
        FOREACH _index_name IN ARRAY _indexes LOOP
            EXECUTE 'DROP INDEX '|| _index_name;
        END LOOP;
    END IF;
END$$;

ALTER TABLE reclada.object ALTER COLUMN status DROP DEFAULT;
DROP VIEW reclada.v_ui_active_object;
DROP VIEW reclada.v_revision;
DROP VIEW reclada.v_import_info;
DROP VIEW reclada.v_dto_json_schema;
DROP VIEW reclada.v_class;
DROP VIEW reclada.v_task;
DROP VIEW reclada.v_active_object;
DROP VIEW reclada.v_object_display;
DROP VIEW reclada.v_object;
DROP MATERIALIZED VIEW reclada.v_user;

--{function/reclada_object.get_active_status_obj_id}
--{function/reclada_object.get_archive_status_obj_id}

ALTER TABLE reclada.object ALTER COLUMN status SET DEFAULT reclada_object.get_active_status_obj_id();
CREATE MATERIALIZED VIEW reclada.v_user
AS
    SELECT  obj.id            ,
            obj.GUID as obj_id,
            obj.attributes->>'login' as login,
            obj.created_time  ,
            obj.attributes as attrs
    FROM reclada.object obj
       WHERE class in (select reclada_object.get_GUID_for_class('User')) 
        and status = reclada_object.get_active_status_obj_id();
ANALYZE reclada.v_user;
--{view/reclada.v_object}
--{view/reclada.v_object_display}
--{view/reclada.v_active_object}
--{view/reclada.v_task}
--{view/reclada.v_class}
--{view/reclada.v_dto_json_schema}
--{view/reclada.v_import_info}
--{view/reclada.v_revision}
--{view/reclada.v_ui_active_object}
--{view/reclada.v_filter_mapping}
--{function/reclada_object.get_query_condition_filter}