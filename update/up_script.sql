-- version = 47
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

\i 'function/reclada_object.get_query_condition_filter.sql'
\i 'function/reclada_object.create.sql'
\i 'function/reclada_object.create_subclass.sql'
\i 'function/reclada_object.update.sql'
\i 'function/reclada_object.list.sql'
\i 'function/reclada_object.get_schema.sql'
\i 'function/reclada_object.explode_jsonb.sql'
\i 'function/reclada.update_unique_object.sql'
\i 'function/reclada.random_string.sql'
\i 'function/api.reclada_object_list.sql'
\i 'view/reclada.v_ui_active_object.sql'
\i 'function/reclada.get_duplicates.sql'
\i 'function/reclada_object.refresh_mv.sql'
\i 'view/reclada.v_filter_mapping.sql'
\i 'view/reclada.v_get_duplicates_query.sql'
\i 'function/reclada.get_unifield_index_name.sql'


select reclada.update_unique_object(null, true);



UPDATE reclada.object
SET
attributes = '{
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
                  "type": "boolean"
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
SET attributes = (SELECT jsonb_set(attributes, '{schema, properties}', attributes #> '{schema, properties}' || '{"disable": {"type": "boolean", "default": false}}'::jsonb))
WHERE class IN (SELECT reclada_object.get_guid_for_class('jsonschema'))
AND attributes->>'forClass' != 'ObjectDisplay'
AND attributes->>'forClass' != 'jsonschema';

\i 'view/reclada.v_filter_available_operator.sql'

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

\i 'function/reclada_object.get_jsonschema_guid.sql'
\i 'view/reclada.v_class_lite.sql'
\i 'function/reclada_object.get_guid_for_class.sql'
\i 'view/reclada.v_object_status.sql'


\i 'function/reclada_object.delete.sql'
\i 'view/reclada.v_object_display.sql'
\i 'function/reclada_object.need_flat.sql'


\i 'view/reclada.v_user.sql'
\i 'view/reclada.v_object.sql'
\i 'view/reclada.v_active_object.sql'
\i 'view/reclada.v_dto_json_schema.sql'
\i 'view/reclada.v_ui_active_object.sql'
\i 'view/reclada.v_task.sql'
\i 'view/reclada.v_revision.sql'
\i 'view/reclada.v_import_info.sql'
\i 'view/reclada.v_class.sql'
\i 'view/reclada.v_parent_field.sql'
\i 'view/reclada.v_object_unifields.sql'

\i 'view/reclada.v_filter_mapping.sql'

CREATE INDEX relationship_type_subject_object_index ON reclada.object USING btree ((attributes->>'type'), ((attributes->>'subject')::uuid), status, ((attributes->>'object')::uuid))
WHERE attributes->>'subject' IS NOT NULL AND attributes->>'object' IS NOT NULL;

DROP INDEX parent_guid_index;
CREATE INDEX parent_guid_index ON reclada.object USING hash (parent_guid)
WHERE parent_guid IS NOT NULL;

DROP INDEX document_fileguid_index;
CREATE INDEX document_fileguid_index ON reclada.object USING btree ((attributes ->> 'fileGUID'))
WHERE attributes ->> 'fileGUID' IS NOT NULL;

DROP INDEX file_uri_index;

DROP INDEX job_status_index;
CREATE INDEX job_status_index ON reclada.object USING btree ((attributes ->> 'status'))
WHERE attributes ->> 'status' IS NOT NULL;

DROP INDEX revision_index;
CREATE INDEX revision_index ON reclada.object USING btree ((attributes ->> 'revision'))
WHERE attributes ->> 'revision' IS NOT NULL;

DROP INDEX runner_type_index;
CREATE INDEX runner_type_index ON reclada.object USING btree ((attributes ->> 'type'))
WHERE attributes ->> 'type' IS NOT NULL;

DROP INDEX guid_index;
CREATE INDEX guid_index ON reclada.object USING hash (guid);

DROP INDEX checksum_index_;
CREATE INDEX checksum_index_ ON reclada.object USING hash ((attributes ->> 'checksum'))
WHERE attributes ->> 'checksum' IS NOT NULL;

DROP INDEX uri_index_;
CREATE INDEX uri_index_ ON reclada.object USING hash ((attributes ->> 'uri'))
WHERE attributes ->> 'uri' IS NOT NULL;

DO $$
DECLARE
_field_name             text;
_btree_fields           text[];
_gin_fields             text[];
_hash_fields            text[];
BEGIN
    SELECT array_remove( array_agg(CASE WHEN c.type = 'number' THEN req_field END), NULL) AS btree_index,
        array_remove( array_agg(CASE WHEN c.type = 'array' THEN req_field END), NULL) AS gin_index,
        array_remove( array_agg(CASE WHEN c.type = 'string' AND (c.is_enum OR c.is_guid) THEN req_field END), NULL) AS hash_index
    FROM (
        SELECT DISTINCT a.req_field,
            b.TYPE,
            c.KEY IS NOT NULL AS is_enum,
            d.key IS NOT NULL AS is_guid
        FROM (
            SELECT lower(jsonb_array_elements_text(attrs->'schema'->'required')) AS req_field, vc.obj_id 
            FROM reclada.v_class vc
        ) a
        JOIN (
            SELECT lower(a.KEY) AS key, a.value->>'type' AS type, vc.obj_id 
            FROM reclada.v_class vc   
            CROSS JOIN jsonb_each(attrs->'schema'->'properties') a
            WHERE for_class NOT IN ('ObjectDisplay')
        ) b ON a.req_field = b.KEY AND a.obj_id=b.obj_id
        LEFT JOIN (
            SELECT lower(a.KEY) AS key, vc.obj_id
            FROM reclada.v_class vc   
            CROSS JOIN jsonb_each(attrs->'schema'->'properties') a
            WHERE for_class NOT IN ('ObjectDisplay')    AND a.value->>'enum' IS NOT null
        ) c ON a.req_field = c.KEY AND a.obj_id = c.obj_id
        LEFT JOIN (
            SELECT lower(a.KEY) AS key, vc.obj_id, a.value
            FROM reclada.v_class vc   
            CROSS JOIN jsonb_each(attrs->'schema'->'properties') a
            WHERE for_class NOT IN ('ObjectDisplay')    AND a.value->>'pattern' ='[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}'
        ) d  ON a.req_field = d.KEY AND a.obj_id = d.obj_id
        WHERE req_field NOT IN ( '{}')
            AND req_field NOT IN (       
                SELECT substring(ind_expr, cut_start+5, cut_end-cut_start-6)
                FROM (
                    SELECT relname,
                        ind_expr,
                        strpos(ind_expr,'->>') AS cut_start,
                        strpos(ind_expr,'::text') AS cut_end
                    FROM (
                        SELECT i.relname,
                            pg_catalog.pg_get_expr(ix.indexprs, ix.indrelid) AS ind_expr
                        FROM pg_catalog.pg_index ix
                        JOIN pg_catalog.pg_class i ON i.oid = ix.indexrelid 
                        JOIN pg_catalog.pg_class t ON t.oid = ix.indrelid 
                        JOIN pg_catalog.pg_namespace n ON t.relnamespace = n.oid
                        WHERE t.relname = 'object'
                            AND nspname = 'reclada'
                            AND ix.indexprs IS NOT NULL
                    ) a
                WHERE length(ind_expr) - length(REPLACE(ind_expr,'->>',''))= 3
                ) b
            )
        ORDER BY 1
    ) c
    INTO _btree_fields, _gin_fields, _hash_fields;
    
    IF _btree_fields IS NOT NULL THEN
        FOREACH _field_name IN ARRAY _btree_fields LOOP
            EXECUTE 'CREATE INDEX '|| _field_name || '_index_v47 ON reclada.object USING BTREE ( (attributes->'''||_field_name ||''')) WHERE attributes ->'''||_field_name ||''' IS NOT NULL';
        END LOOP;
    END IF;
    IF _gin_fields IS NOT NULL THEN
        FOREACH _field_name IN ARRAY _gin_fields LOOP
            EXECUTE 'CREATE INDEX '|| _field_name || '_index_v47 ON reclada.object USING GIN ( (attributes->'''||_field_name ||''')) WHERE attributes ->'''||_field_name ||''' IS NOT NULL';
        END LOOP;
    END IF;
    IF _hash_fields IS NOT NULL THEN
        FOREACH _field_name IN ARRAY _hash_fields LOOP
            EXECUTE 'CREATE INDEX '|| _field_name || '_index_v47 ON reclada.object USING HASH ( (attributes->'''||_field_name ||''')) WHERE attributes ->'''||_field_name ||''' IS NOT NULL';
        END LOOP;
    END IF;
END$$;