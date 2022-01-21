-- version = 46
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

\i 'function/reclada_object.create_subclass.sql'
\i 'function/reclada_object.create.sql'

update reclada.object
    set attributes = attributes || jsonb_build_object('parentList', case 
                                                                        when parent_guid is not null 
                                                                            then jsonb_build_array(parent_guid)
                                                                        else jsonb_build_array()
                                                                    end)
    where class = reclada_object.get_jsonschema_GUID();

update reclada.object
    set attributes = jsonb_set(attributes,'{schema,properties}',
            attributes#>'{schema,properties}'
                || jsonb_build_object('parentList','{
                    "items": {
                        "type": "string"
                    },
                    "type": "array"
                }'::jsonb)
        )
    where guid = reclada_object.get_jsonschema_GUID();
