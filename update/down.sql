-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script


--------------default----------------
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
--{function/reclada_object.built_nested_jsonb}
--{view/reclada.v_class_lite}
--{function/reclada_object.get_guid_for_class}
--{function/reclada_object.delete}
--{view/reclada.v_object_display}
--{function/reclada_object.need_flat}

--{view/reclada.v_object_status}
--{view/reclada.v_user}
--{view/reclada.v_object}
--{view/reclada.v_active_object}
--{view/reclada.v_dto_json_schema}
--{view/reclada.v_ui_active_object}
--{view/reclada.v_task.sql}
--{view/reclada.v_revision}
--{view/reclada.v_import_info}
--{view/reclada.v_class}
--{view/reclada.v_parent_field}
--{view/reclada.v_object_unifields}
--{view/reclada.v_unifields_pivoted}

--{function/reclada_object.get_query_condition_filter}
--{function/reclada_object.create_subclass}





