-- you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script


drop table reclada.unique_object_reclada_object;
drop table reclada.unique_object;
drop table reclada.field;

--{view/reclada.v_unifields_pivoted}
--{function/reclada_object.create}
--{function/reclada_object.create_subclass}
--{function/reclada_object.get_schema}
--{function/reclada_object.update}
--{function/reclada_object.list}
--{function/reclada.update_unique_object}
--{function/reclada.random_string}
--{function/api.reclada_object_list}
--{function/reclada_object.explode_jsonb}
--{function/reclada_object.refresh_mv}
--{function/reclada.get_duplicates}
--{view/reclada.v_filter_mapping}
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


UPDATE reclada.object
SET attributes = '{
    "schema": {
        "id": "expr",
        "type": "object",
        "required": [
          "value",
          "operator"
        ],
        "properties": {
          "value": {
            "type": "array",
            "items": {
              "anyOf": [
                {
                  "type": "string"
                },
                {
                  "type": "null"
                },
                {
                  "type": "number"
                },
                {
                  "$ref": "expr"
                },
                {
                  "type": "array",
                  "items": {
                    "anyOf": [
                      {
                        "type": "string"
                      },
                      {
                        "type": "number"
                      }
                    ]
                  }
                }
              ]
            },
            "minItems": 1
          },
          "operator": {
            "type": "string"
          }
        }
      },
    "function": "reclada_object.get_query_condition_filter"
}'::jsonb
WHERE attributes->>'function' = 'reclada_object.get_query_condition_filter'
AND class IN (SELECT reclada_object.get_guid_for_class('DTOJsonSchema'));


UPDATE reclada.object
SET attributes = attributes #- '{schema, properties, disable}'
WHERE class IN (SELECT reclada_object.get_guid_for_class('jsonschema'))
AND attributes->>'forClass' != 'ObjectDisplay'
AND attributes->>'forClass' != 'jsonschema';


--{function/reclada_object.get_query_condition_filter}
--{function/reclada_object.create_subclass}
--{view/reclada.v_filter_available_operator}



ALTER TABLE reclada.object ALTER COLUMN status DROP DEFAULT;
DROP VIEW IF EXISTS reclada.v_unifields_pivoted;
DROP MATERIALIZED VIEW IF EXISTS reclada.v_object_unifields;
DROP VIEW IF EXISTS reclada.v_parent_field;
DROP VIEW IF EXISTS reclada.v_class;
DROP VIEW IF EXISTS reclada.v_import_info;
DROP VIEW IF EXISTS reclada.v_revision;
DROP VIEW IF EXISTS reclada.v_task;
DROP VIEW IF EXISTS reclada.v_ui_active_object;
DROP VIEW IF EXISTS reclada.v_dto_json_schema;
DROP VIEW IF EXISTS reclada.v_active_object;
DROP VIEW IF EXISTS reclada.v_object;
DROP MATERIALIZED VIEW IF EXISTS reclada.v_class_lite;
DROP MATERIALIZED VIEW IF EXISTS reclada.v_user;
DROP MATERIALIZED VIEW IF EXISTS reclada.v_object_status;
DROP VIEW IF EXISTS reclada.v_object_display;

--{function/reclada_object.get_jsonschema_guid}


CREATE MATERIALIZED VIEW reclada.v_class_lite
AS
    SELECT  obj.id,
            obj.GUID as obj_id,
            obj.attributes->>'forClass' as for_class,
            (attributes->>'version')::bigint as version,
            obj.created_time,
            obj.attributes,
            obj.status
	FROM reclada.object obj
   	WHERE obj.class = reclada_object.get_jsonschema_GUID();

--{function/reclada_object.get_guid_for_class}

CREATE MATERIALIZED VIEW reclada.v_object_status
AS
    SELECT  obj.id            ,
            obj.GUID as obj_id,
            obj.attributes->>'caption' as caption,
            obj.created_time  ,
            obj.attributes as attrs
	FROM reclada.object obj
   	WHERE class in (select reclada_object.get_guid_for_class('ObjectStatus'));
     
--{function/reclada_object.get_active_status_obj_id}
--{function/reclada_object.get_archive_status_obj_id}

CREATE MATERIALIZED VIEW reclada.v_user
AS
    SELECT  obj.id            ,
            obj.GUID as obj_id,
            obj.attributes->>'login' as login,
            obj.created_time  ,
            obj.attributes as attrs
	FROM reclada.object obj
   	WHERE class in (select reclada_object.get_guid_for_class('User'))
        and status = reclada_object.get_active_status_obj_id();
ANALYZE reclada.v_user;



ALTER TABLE reclada.object ALTER COLUMN status SET DEFAULT reclada_object.get_active_status_obj_id();


--{function/reclada_object.delete}
--{view/reclada.v_object_display}
--{function/reclada_object.need_flat}

--{view/reclada.v_object}
--{view/reclada.v_object_display}
--{view/reclada.v_active_object}
--{view/reclada.v_dto_json_schema}
--{view/reclada.v_ui_active_object}
--{view/reclada.v_task}
--{view/reclada.v_revision}
--{view/reclada.v_import_info}
--{view/reclada.v_class}
--{view/reclada.v_parent_field}
--{view/reclada.v_filter_mapping}


CREATE MATERIALIZED VIEW reclada.v_object_unifields
AS
    SELECT
        for_class,
        class_uuid,
        CAST (dup_behavior AS reclada.dp_bhvr) AS dup_behavior,
        is_cascade,
        is_mandatory,
        uf as unifield,
        uni_number,
        row_number() OVER (PARTITION BY for_class,uni_number ORDER BY uf) AS field_number,
        copy_field
    FROM
        (
        SELECT
            for_class,
            obj_id                                      AS class_uuid,
            dup_behavior,
            is_cascade::boolean                         AS is_cascade,
            (dc->>'isMandatory')::boolean               AS is_mandatory,
            jsonb_array_elements_text(dc->'uniFields')  AS uf,
            dc->'uniFields'::text                       AS field_list,
            row_number() OVER ( PARTITION BY for_class ORDER BY dc->'uniFields'::text) AS uni_number,
            copy_field
        FROM
            (
            SELECT
                for_class,
                attributes->>'dupBehavior'           AS dup_behavior,
                (attributes->>'isCascade')           AS is_cascade,
                jsonb_array_elements( attributes ->'dupChecking') AS dc,
                obj_id,
                attributes->>'copyField' as copy_field
            FROM
                reclada.v_class_lite vc
            WHERE
                attributes ->'dupChecking' is not null
            ) a
        ) b
;

--{view/reclada.v_unifields_pivoted}

CREATE INDEX class_lite_class_idx ON reclada.v_class_lite USING btree (for_class);
CREATE INDEX class_lite_obj_idx ON reclada.v_class_lite USING btree (obj_id);




