-- version = 46
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

--{ REC-564
    \i 'view/reclada.v_component.sql'
    \i 'view/reclada.v_relationship.sql'
    \i 'view/reclada.v_component_object.sql'
    \i 'function/reclada_object.get_parent_guid.sql'
    \i 'function/reclada_object.create_relationship.sql'
    \i 'function/reclada_object.create.sql'

    SELECT reclada_object.create_subclass('{
        "class": "RecladaObject",
        "attributes": {
            "newClass": "Component",
            "properties": {
                "name": {"type": "string"},
                "commitHash": {"type": "string"},
                "repository": {"type": "string"},
                "isInstalling": {"type": "boolean"}
            },
            "required": ["name","commitHash","repository","isInstalling"]
        }
    }'::jsonb);

    SELECT reclada_object.create(
        '{
            "GUID": "b17500cb-e998-4f55-979b-2ba1218a3b45",
            "class":"Component",
            "attributes": {
                "name":"reclada-runtime",
                "repository":"https://gitlab.reclada.com/developers/reclada-runtime.git",
                "commitHash":"00000",
                "isInstalling":false
            }
        }'::jsonb);

    SELECT reclada_object.create(
        '{
            "GUID": "38d35ba3-7910-4e6e-8632-13203269e4b9",
            "class":"Component",
            "attributes": {
                "name":"SciNLP",
                "repository":"https://gitlab.reclada.com/developers/SciNLP.git",
                "commitHash":"00000",
                "isInstalling":false
            }
        }'::jsonb);
    
    SELECT reclada_object.create(
        '{
            "GUID": "7534ae14-df31-47aa-9b46-2ad3e60b4b6e",
            "class":"Component",
            "attributes": {
                "name":"db",
                "repository":"https://gitlab.reclada.com/developers/db.git",
                "commitHash":"00000",
                "isInstalling":false
            }
        }'::jsonb);

    DO
    $do$
    DECLARE
        res text;

    BEGIN
        
        PERFORM reclada_object.create_relationship
                            (
                                'data of reclada-component',
                                'b17500cb-e998-4f55-979b-2ba1218a3b45',
                                o.guid,
                                '{}'::jsonb,
                                'b17500cb-e998-4f55-979b-2ba1218a3b45'
                            )
            from reclada.object o
                where o.class in (select reclada_object.get_GUID_for_class('jsonschema'))
                    and o.attributes->>'forClass' in (  'Connector',
                                                        'Environment',
                                                        'FileExtension',
                                                        'Job',
                                                        'Parameter',
                                                        'Pipeline',
                                                        'Runner',
                                                        'Task',
                                                        'Trigger',
                                                        'Value'
                                                    );

        PERFORM reclada_object.create_relationship
                            (
                                'data of reclada-component',
                                '38d35ba3-7910-4e6e-8632-13203269e4b9',
                                o.guid,
                                '{}'::jsonb,
                                '38d35ba3-7910-4e6e-8632-13203269e4b9'
                            )
            from reclada.object o
                where o.class in (select reclada_object.get_GUID_for_class('jsonschema'))
                    and o.attributes->>'forClass' in (  'Document',
                                                        'Page',
                                                        'BBox',
                                                        'TextBlock',
                                                        'Table',
                                                        'Cell',
                                                        'NLPattern',
                                                        'NLPatternAttribute',
                                                        'HeaderTerm',
                                                        'DataRow',
                                                        'Attribute',
                                                        'Data'
                                                    );

        PERFORM reclada_object.create_relationship
                            (
                                'data of reclada-component',
                                '7534ae14-df31-47aa-9b46-2ad3e60b4b6e',
                                o.guid,
                                '{}'::jsonb,
                                '7534ae14-df31-47aa-9b46-2ad3e60b4b6e'
                            )
            from reclada.object o
                where o.class in 
                (
                    select reclada_object.get_GUID_for_class('Runner')
                    UNION 
                    select reclada_object.get_GUID_for_class('Context')
                );

    END
    $do$;

--}
