-- version = 48
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

-- \i 'function/reclada_object.update.sql'


--{ REC-564
create table dev.component(
    name        text not null,
    repository  text not null,
    commit_hash text not null,
    guid        uuid not null
);

create table dev.component_object(
    id     BIGINT   NOT NULL
                    GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1)
                    PRIMARY KEY,
    status text  not null DEFAULT 'need to check',-- ok, update, create, delete, create_subclass 
    data   jsonb not null 
);

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
                "repository": {"type": "string"}
            },
            "required": ["name","commitHash","repository"]
        }
    }'::jsonb);

    SELECT reclada_object.create(
        '{
            "GUID": "b17500cb-e998-4f55-979b-2ba1218a3b45",
            "class":"Component",
            "attributes": {
                "name":"reclada-runtime",
                "repository":"https://gitlab.reclada.com/developers/reclada-runtime.git",
                "commitHash":"00000"
            }
        }'::jsonb);

    SELECT reclada_object.create(
        '{
            "GUID": "38d35ba3-7910-4e6e-8632-13203269e4b9",
            "class":"Component",
            "attributes": {
                "name":"SciNLP",
                "repository":"https://gitlab.reclada.com/developers/SciNLP.git",
                "commitHash":"00000"
            }
        }'::jsonb);
    
    SELECT reclada_object.create(
        '{
            "GUID": "7534ae14-df31-47aa-9b46-2ad3e60b4b6e",
            "class":"Component",
            "attributes": {
                "name":"db",
                "repository":"https://gitlab.reclada.com/developers/db.git",
                "commitHash":"00000"
            }
        }'::jsonb);

    SELECT reclada_object.create_subclass('{
            "class": "RecladaObject",
            "attributes": {
                "newClass": "Index",
                "properties": {
                    "name": {"type": "string"},
                    "method": {
                        "type": "string",
                        "enum ": [
                            "btree", 
                            "hash" , 
                            "gist" , 
                            "gin"
                        ]
                    },
                    "wherePredicate": {
                        "type": "string"
                    },
                    "fields": {
                        "items": {
                            "type": "string"
                        },
                        "type": "array",
                        "minContains": 1
                    }
                },
                "required": ["name","fields"]
            }
        }'::jsonb);

    select reclada_object.create(
            jsonb_build_object( 'class'  ,   'Index',
                                'attributes', jsonb_build_object(
                                    'name'  ,         t.name,
                                    'method',         t.method,
                                    'fields',         t.fields,
                                    'wherePredicate', t.wherePredicate
                                )
            )
        )
        FROM
        (
            SELECT  distinct 
                    ns.nspname as schema, 
                    i.relname  as name  , 
                    am.amname  as method,
                    t.relname  as table ,
                    to_jsonb(
                        regexp_split_to_array(
                            pg_catalog.pg_get_expr(ix.indexprs, ix.indrelid),
                            ','
                        )
                    ) AS fields,
                    split_part(dml.dml,'WHERE ',2) as wherePredicate
                FROM pg_catalog.pg_index ix
                JOIN pg_catalog.pg_class i 
                    ON i.oid = ix.indexrelid 
                JOIN pg_catalog.pg_class t 
                    ON t.oid = ix.indrelid 
                JOIN pg_catalog.pg_namespace ns 
                    ON ns.oid = i.relnamespace
                join pg_catalog.pg_opclass cl 
                    on cl.oid = any(ix.indclass)
                join pg_catalog.pg_am am 
                    on am.oid = cl.opcmethod
                cross join lateral pg_get_indexdef(
                                        (ns.nspname||'.'||i.relname)::regclass
                                    ) dml
                WHERE t.relname = 'object'
                    AND ns.nspname = 'reclada'
                    AND ix.indexprs IS NOT NULL
        ) t;
    -- reclada-runtime
    select reclada_object.create_relationship
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
                or o.class in 
                (
                    select reclada_object.get_GUID_for_class('Runner')
                    UNION 
                    select reclada_object.get_GUID_for_class('Task')
                    UNION 
                    select reclada_object.get_GUID_for_class('PipelineLite')
                );
    -- SciNLP
    select reclada_object.create_relationship
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

    select reclada_object.create_relationship
                        (
                            'data of reclada-component',
                            '7534ae14-df31-47aa-9b46-2ad3e60b4b6e',
                            o.guid,
                            '{}'::jsonb,
                            '7534ae14-df31-47aa-9b46-2ad3e60b4b6e'
                        )
        from reclada.object o
            where (
                o.class in (select reclada_object.get_GUID_for_class('jsonschema'))
                and o.attributes->>'forClass' in (  'tag',
                                                    'DataSource',
                                                    'File',
                                                    'S3Config',
                                                    'DataSet',
                                                    'Message',
                                                    'Component',
                                                    'Index',

                                                    --'NLPattern',
                                                    --'NLPatternAttribute',
                                                    --'HeaderTerm',
                                                    --'DataRow',
                                                    --'Attribute',
                                                    --'Data'
                                                )
            )
            or o.class in 
            (
                select reclada_object.get_GUID_for_class('Context')
                UNION
                select reclada_object.get_GUID_for_class('Index')
            );

--} REC-564

--{ REC-594
\i 'view/reclada.v_filter_mapping.sql'
\i 'view/reclada.v_object.sql' 
\i 'view/reclada.v_class.sql'
--} REC-594

--{ REC-562
\i 'function/reclada_object.get_schema.sql'
\i 'function/reclada.get_validation_schema.sql'

\i 'function/reclada.validate_json_schema.sql'
\i 'function/reclada_object.list.sql'
\i 'function/reclada_object.create.sql'
\i 'function/reclada_object.update.sql'
\i 'function/reclada_object.create_subclass.sql'

--} REC-562


--{ REC-564
drop function reclada_object.datasource_insert;
\i 'function/reclada_object.object_insert.sql'
\i 'function/reclada_object.delete.sql'
\i 'function/dev.begin_install_component.sql'
\i 'function/dev.finish_install_component.sql'
\i 'view/reclada.v_ui_active_object.sql' 

--} REC-564
