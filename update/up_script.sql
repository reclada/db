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
            o.class in (select reclada_object.get_GUID_for_class('jsonschema'))
            and o.attributes->>'forClass' in (  'tag',
                                                'DataSource',
                                                'File',
                                                'S3Config',
                                                'DataSet',
                                                'Message',
                                                'Component',
                                                'Index'

                                                --'NLPattern',
                                                --'NLPatternAttribute',
                                                --'HeaderTerm',
                                                --'DataRow',
                                                --'Attribute',
                                                --'Data'
                                            );




