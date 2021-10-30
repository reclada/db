-- version = 41
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/


\i 'view/reclada.v_PK_for_class.sql'
\i 'view/reclada.v_DTO_json_schema.sql'

SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attributes": {
        "newClass": "DTOJsonSchema",
        "properties": {
            "function": {"type": "string"},
            "schema":{"type": "object"}
        },
        "required": ["function","schema"]
    }
}'::jsonb);

SELECT reclada_object.create(
    '{
        "class": "DTOJsonSchema",
        "attributes": {
            "function":"reclada_object.get_query_condition_filter",
            "schema":{
                "type": "object",
                "id": "expr",
                "properties": {
                    "value": {
                        "type": "array",
                        "items": {
                            "anyOf": [
                                {
                                    "type": "string"
                                },
                                {
                                    "type": "number"
                                },
                                {
                                    "$ref": "expr"
                                },
                                {
                                    "type": "array",
                                    "items":{
                                        "type": "string"
                                    }
                                }
                            ]
                        },
                        "minItems": 1
                    },
                    "operator": {
                        "enum": [
                            "=",
                            "LIKE",
                            "NOT LIKE",
                            "||",
                            "~",
                            "!~",
                            "~*",
                            "!~*",
                            "SIMILAR TO",
                            ">",
                            "<",
                            "<=",
                            "!=",
                            ">=",
                            "AND",
                            "OR",
                            "NOT",
                            "#",
                            "IS",
                            "IS NOT",
                            "IN",
                            ",",
                            "@>",
                            "<@",
                            "+",
                            "-",
                            "*",
                            "/",
                            "%",
                            "^",
                            "|/",
                            "||/",
                            "!!",
                            "@",
                            "&",
                            "|",
                            "<<",
                            ">>"
                        ],
                        "type": "string"
                    }
                }
            }
        }
    }'
);

\i 'function/reclada.validate_json.sql'
\i 'function/reclada_object.get_query_condition_filter.sql'
\i 'function/api.reclada_object_list.sql'

