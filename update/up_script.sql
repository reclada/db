-- version = 49
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

\i 'function/dev.finish_install_component.sql'

select reclada_object.create_relationship
                    (
                        'data of reclada-component',
                        db.guid,
                        o.guid,
                        '{}'::jsonb,
                        db.guid
                    )
    from reclada.object o
    cross join (
        select guid 
            from reclada.v_component 
                where name = 'db' 
                limit 1
    ) db
        where 
        (
            o.class in (select reclada_object.get_GUID_for_class('jsonschema'))
            and o.attributes->>'forClass' in (  'tag', -- 1
                                                'DataSource', -- 2
                                                'S3Config', -- 3
                                                'DataSet', -- 4
                                                'Message', -- 5
                                                'Index', -- 6
                                                'Component', -- 7
                                                'Context', -- 8
                                                'DTOJsonSchema', -- 9
                                                'File', -- 10
                                                'User', -- 11
                                                'ImportInfo', -- 12
                                                'Asset', -- 13
                                                'DBAsset', -- 14
                                                'revision' -- 15
                                            )
                                            
        )
        or (
            o.class in (select reclada_object.get_GUID_for_class('DataSet'))
            and o.attributes->>'name' = 'defaultDataSet'
        );




