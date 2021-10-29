-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

drop OPERATOR IF EXISTS #(boolean, boolean);
DROP VIEW IF EXISTS reclada.v_revision;
DROP VIEW IF EXISTS reclada.v_import_info;
DROP VIEW IF EXISTS reclada.v_pk_for_class;
DROP VIEW IF EXISTS reclada.v_class;
DROP VIEW IF EXISTS reclada.v_active_object;
DROP VIEW IF EXISTS reclada.v_object;

--{function/reclada_object.get_query_condition_filter}
--{function/reclada_object.list}
--{view/reclada.v_filter_avaliable_operator}
--{view/reclada.v_object}
--{view/reclada.v_active_object}
--{view/reclada.v_class}
--{view/reclada.v_pk_for_class}
--{view/reclada.v_import_info}
--{view/reclada.v_revision}
--{function/reclada.xor}

update reclada.object
    set attributes = '
{
    "schema": {
        "type": "object",
        "required": [
            "command",
            "status",
            "type",
            "task",
            "environment"
        ],
        "properties": {
            "tags": {
                "type": "array",
                "items": {
                    "type": "string"
                }
            },
            "task": {
                "type": "string",
                "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"
            },
            "type": {
                "type": "string"
            },
            "runner": {
                "type": "string",
                "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"
            },
            "status": {
                "type": "string",
                "enum ": [
                    "up",
                    "down",
                    "idle"
                ]
            },
            "command": {
                "type": "string"
            },
            "environment": {
                "type": "string",
                "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"
            },
            "inputParameters": {
                "type": "array",
                "items": {
                    "type": "object"
                }
            },
            "outputParameters": {
                "type": "array",
                "items": {
                    "type": "object"
                }
            }
        }
    },
    "version": "1",
    "forClass": "Runner"
}'::jsonb
    where class = reclada_object.get_jsonschema_GUID() 
        and attributes->>'forClass' = 'Runner';
REFRESH MATERIALIZED VIEW reclada.v_class_lite;
