-- version = 40
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

\i 'view/reclada.v_filter_avaliable_operator.sql'
\i 'view/reclada.v_object.sql'
\i 'function/reclada_object.get_query_condition_filter.sql'
\i 'function/reclada_object.list.sql'
\i 'function/reclada.xor.sql'

CREATE OPERATOR # 
(
    PROCEDURE = reclada.xor, 
    LEFTARG = boolean, 
    RIGHTARG = boolean
);

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
            "platformRunnerID": {
                "type": "string"
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