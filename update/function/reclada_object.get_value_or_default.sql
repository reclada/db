DROP FUNCTION IF EXISTS reclada_object.get_value_or_default;
CREATE OR REPLACE FUNCTION reclada_object.get_value_or_default(data jsonb, field text[], schema jsonb, text_type boolean default false)
RETURNS jsonb AS $$
    SELECT
        COALESCE(
        data #> field,
        schema #> (
            field[:array_position(field, 'attributes')] -- attributes
            ||
            '{schema,properties}'
            ||
            field[array_position(field, 'attributes') + 1:]
            ||
            '{default}'));
$$ LANGUAGE SQL IMMUTABLE;

UPDATE reclada.object
SET attributes = (SELECT jsonb_set(attributes, '{schema, properties}', attributes#>'{schema, properties}' || '{"disable": {"type": "boolean", "default": false}}'::jsonb))
WHERE class IN (SELECT reclada_object.get_GUID_for_class('jsonschema'))
AND attributes->>'forClass' != 'ObjectDisplay'
AND attributes->>'forClass' != 'jsonschema';


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
                },{
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
WHERE attributes->>'function' = 'reclada_object.get_query_condition_filter';