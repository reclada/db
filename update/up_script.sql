-- version = 49
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

create table dev.meta_data(
    id bigint
        NOT NULL
        GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1)
        UNIQUE ,
    ver bigint,
    data jsonb
);

\i 'function/reclada_object.list.sql'


\i 'function/dev.begin_install_component.sql'
\i 'function/dev.finish_install_component.sql'
\i 'function/dev.downgrade_version.sql'
\i 'function/reclada_object.create_subclass.sql'
\i 'function/reclada_object.create_relationship.sql'
\i 'function/dev.downgrade_component.sql'
\i 'function/reclada_object.update.sql'

\i 'view/reclada.v_object_display.sql'
drop VIEW reclada.v_component_object;
drop VIEW reclada.v_component;
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


insert into dev.meta_data(ver,data)
    select  49, 
            jsonb_build_object( 'id'     , o.id ,
                                'tran_id', u.transaction_id
                            ) as v
        from reclada.v_component_object o
        join reclada.object u
            on u.id = o.id
        join 
        (
            SELECT transaction_id ,attrs->>'name' component_name
                FROM reclada.v_object 
                    where class_name = 'Component' 
        ) t
            on t.component_name = o.component_name;


update reclada.object u
    set transaction_id = t.transaction_id
    from reclada.v_component_object o
    join 
    (
        SELECT transaction_id ,attrs->>'name' component_name
            FROM reclada.v_object 
                where class_name = 'Component' 
    ) t
        on t.component_name = o.component_name
        where u.id = o.id;
    



\i 'function/reclada_object.update.sql'
\i 'function/reclada_object.create.sql'
\i 'function/reclada_object.merge.sql'
\i 'view/reclada.v_object_unifields.sql'

ALTER SEQUENCE IF EXISTS reclada.object_id_seq CACHE 10;

-----------
\i 'view/reclada.v_ui_active_object.sql'

\i 'function/reclada_object.create_job.sql'
\i 'function/api.storage_generate_presigned_post.sql'
