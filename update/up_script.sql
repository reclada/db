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

\i 'function/reclada_object.create.sql'
\i 'function/reclada_object.update.sql'
\i 'function/reclada_object.list.sql'
\i 'function/reclada_object.get_schema.sql'
\i 'function/reclada.update_unique_object.sql'
\i 'function/reclada.random_string.sql'
\i 'function/api.reclada_object_list.sql'
\i 'view/reclada.v_ui_active_object.sql'
\i 'view/reclada.v_filter_mapping.sql'
\i 'view/reclada.v_ui_active_object.sql'


select reclada.update_unique_object(null, true);

--------------default----------------


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


\i 'function/reclada_object.get_query_condition_filter.sql'
\i 'function/reclada_object.create_subclass.sql'
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
\i 'function/reclada_object.delete.sql'
\i 'view/reclada.v_object_display.sql'
\i 'function/reclada_object.need_flat.sql'

\i 'view/reclada.v_object_status.sql'
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
\i 'view/reclada.v_unifields_pivoted.sql'



