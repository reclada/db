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


\i 'view/reclada.v_ui_active_object.sql'



--{REC 624

CREATE AGGREGATE jsonb_object_agg(jsonb) (
  SFUNC = 'jsonb_concat',
  STYPE = jsonb,
  INITCOND = '{}'
);


\i 'reclada.jsonb_merge.sql'
\i 'function/reclada_object.list.sql'


DROP VIEW IF EXISTS reclada.v_unifields_pivoted;
DROP MATERIALIZED VIEW IF EXISTS reclada.v_object_unifields;
DROP VIEW IF EXISTS reclada.v_parent_field;
DROP VIEW IF EXISTS reclada.v_class;
DROP VIEW IF EXISTS reclada.v_import_info;
DROP VIEW IF EXISTS reclada.v_revision;
DROP VIEW IF EXISTS reclada.v_task;
DROP VIEW IF EXISTS reclada.v_ui_active_object;
DROP VIEW IF EXISTS reclada.v_dto_json_schema;
DROP VIEW IF EXISTS reclada.v_active_object;
DROP VIEW IF EXISTS reclada.v_object;
DROP MATERIALIZED VIEW IF EXISTS reclada.v_class_lite;
DROP MATERIALIZED VIEW IF EXISTS reclada.v_user;
DROP MATERIALIZED VIEW IF EXISTS reclada.v_object_status;
DROP VIEW IF EXISTS reclada.v_object_display;

\i 'function/reclada_object.get_jsonschema_guid.sql'
\i 'view/reclada.v_class_lite.sql'
\i 'function/reclada_object.get_guid_for_class.sql'
\i 'view/reclada.v_object_status.sql'

\i 'function/reclada_object.delete.sql'
\i 'view/reclada.v_object_display.sql'
\i 'function/reclada_object.need_flat.sql'

\i 'view/reclada.v_user.sql'
\i 'view/reclada.v_object.sql'
\i 'view/reclada.v_active_object.sql'
\i 'view/reclada.v_dto_json_schema.sql'
\i 'view/reclada.v_ui_active_object.sql'
\i 'view/reclada.v_task.sql'
\i 'view/reclada.v_revision.sql'
\i 'view/reclada.v_import_info.sql'
\i 'view/reclada.v_class.sql'
\i 'view/reclada.v_parent_field.sql'
\i 'view/reclada.v_object_unifields.sql'
--REC 624}
