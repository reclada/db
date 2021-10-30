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
                },
                "required": ["value","operator"]
            }
        }
    }'
);

\i 'function/reclada.validate_json.sql'
\i 'function/reclada_object.get_query_condition_filter.sql'
\i 'function/api.reclada_object_list.sql'

SELECT reclada_object.create(
    '{
        "class": "DTOJsonSchema",
        "attributes": {
            "function":"reclada_object.list",
            "schema":{
                "type": "object",
                "properties": {
                    "transactionID": {
                        "type": "integer"
                    },
                    "class": {
                        "type": "string"
                    },
                    "filter": {
                        "type": "object"
                    },
                    "orderBy":{
                        "type": "array",
                        "items":{
                            "type":"object",
                            "properties": {
                                "field":{
                                    "type":"string"
                                },
                                "order":{
                                    "type":"string",
                                    "enum": ["ASC", "DESC"]
                                }
                            },
                            "required": ["field"]
                        }
                    },
                    "limit":{
                        "anyOf": [
                            {
                                "type": "string",
                                "enum": ["ALL"]
                            },
                            {
                                "type": "integer"
                            }
                        ]
                    },
                    "offset":{
                        "type": "integer"
                    }
                },
                "anyOf": [
                    {
                        "required": [
                            "transactionID"
                        ]
                    },
                    {
                        "required": [
                            "class"
                        ]
                    },
                    {
                        "required": [
                            "filter"
                        ]
                    }
                ]
            }
        }
    }'
);

\i 'function/reclada_object.list.sql'
