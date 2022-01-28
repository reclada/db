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

-- \i 'function/reclada_object.update.sql'
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
    -- \i 'function/reclada_object.create.sql'

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
                where (
                    o.class in (select reclada_object.get_GUID_for_class('jsonschema'))
                    and o.attributes->>'forClass' in (  'Connector',
                                                        'Environment',
                                                        'FileExtension',
                                                        'Job',
                                                        'Parameter',
                                                        'Pipeline',
                                                        'Runner',
                                                        'Task',
                                                        'Trigger',
                                                        'Value',
                                                        'PipelineLite'
                                                    )
                    )
                    /*or o.guid in (  
                                    'cc7b41e6-4d57-4e6f-9d10-6da0d5a4c39e', --stage0
                                    '618b967b-f2ff-4f3b-8889-b63eb6b73b6e', --stage1
                                    '678bbbcc-a6db-425b-b9cd-bdb302c8d290', --stage2
                                    '638c7f45-ad21-4b59-a89d-5853aa9ad859', --stage3
                                    '2d6b0afc-fdf0-4b54-8a67-704da585196e', --stage4
                                    'ff3d88e2-1dd9-43b3-873f-75e4dc3c0629', --stage5
                                    '83fbb176-adb7-4da0-bd1f-4ce4aba1b87a', --stage6
                                    '27de6e85-1749-4946-8a53-4316321fc1e8', --stage7
                                    '4478768c-0d01-4ad9-9a10-2bef4d4b8007', --stage8
                                    '57ca1d46-146b-4bbb-8f4d-b620c4e62d93'  --pipelineLite
                                ) */
                    or o.class in 
                    (
                        select reclada_object.get_GUID_for_class('Runner')
                        UNION 
                        select reclada_object.get_GUID_for_class('Task')
                        UNION 
                        select reclada_object.get_GUID_for_class('PipelineLite')
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

--} REC-564

--{ REC-594
\i 'view/reclada.v_filter_mapping.sql'
\i 'view/reclada.v_object.sql' 
\i 'function/reclada_object.get_query_condition_filter.sql'

--} REC-594

--{ REC-562
\i 'function/reclada_object.get_schema.sql'
\i 'function/reclada.get_validation_schema.sql'

\i 'view/reclada.v_class.sql'

\i 'function/reclada.validate_json_schema.sql'
\i 'function/reclada_object.list.sql'
\i 'function/reclada_object.create.sql'
\i 'function/reclada_object.update.sql'
\i 'function/reclada_object.create_subclass.sql'

--} REC-562