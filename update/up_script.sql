-- version = 49
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

\i 'function/dev.begin_install_component.sql'
\i 'function/dev.finish_install_component.sql'
\i 'function/dev.downgrade_version.sql'
\i 'function/reclada_object.create_subclass.sql'
\i 'function/reclada_object.create_relationship.sql'
\i 'function/dev.downgrade_component.sql'

\i 'view/reclada.v_object_display.sql'
drop VIEW reclada.v_component_object;
\i 'view/reclada.v_component.sql'
\i 'view/reclada.v_component_object.sql'


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
                                                'revision', -- 15
                                                'ObjectDisplay' -- 16
                                            )
                                            
        ) or (
            o.class in (select reclada_object.get_GUID_for_class('DataSet'))
            and o.attributes->>'name' = 'defaultDataSet'
        ) or (
            o.class in (select reclada_object.get_GUID_for_class('User'))
            and o.attributes->>'login' = 'dev'
        ) or (
            o.class in (select reclada_object.get_GUID_for_class('DTOJsonSchema'))
            and o.attributes->>'function' in ('reclada_object.list','reclada_object.get_query_condition_filter')
        ) or (
            o.class in (select reclada_object.get_GUID_for_class('ObjectDisplay'))
        ) or (
            o.class in (select reclada_object.get_GUID_for_class('Message'))
        );


DO
$do$
DECLARE
	_tran_id bigint = reclada.get_transaction_id();
BEGIN

    update reclada.object u
        set transaction_id = _tran_id
        from reclada.v_component_object o
            where u.id = o.id
                and componen_name = 'db';
    
    _tran_id = reclada.get_transaction_id();

    update reclada.object u
        set transaction_id = _tran_id
        from reclada.v_component_object o
            where u.id = o.id
                and componen_name = 'SciNLP';

    _tran_id = reclada.get_transaction_id();

    update reclada.object u
        set transaction_id = _tran_id
        from reclada.v_component_object o
            where u.id = o.id
                and componen_name = 'reclada-runtime';
END
$do$;

