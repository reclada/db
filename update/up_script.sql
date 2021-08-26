-- version = 3
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

\i 'function/public.try_cast_int.sql'


-- create table reclada.object_status
-- (
--     id      bigint GENERATED ALWAYS AS IDENTITY primary KEY,
--     caption text not null
-- );
SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attrs": {
        "newClass": "ObjectStatus",
        "properties": {
            "caption": {"type": "string"}
        },
        "required": ["caption"]
    }
}'::jsonb);
-- insert into reclada.object_status(caption)
--     select 'active';
SELECT reclada_object.create('{
    "class": "ObjectStatus",
    "attrs": {
        "caption": "active"
    }
}'::jsonb);
-- insert into reclada.object_status(caption)
--     select 'archive';
SELECT reclada_object.create('{
    "class": "ObjectStatus",
    "attrs": {
        "caption": "archive"
    }
}'::jsonb);

SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attrs": {
        "newClass": "User",
        "properties": {
            "login": {"type": "string"}
        },
        "required": ["login"]
    }
}'::jsonb);
SELECT reclada_object.create('{
    "class": "User",
    "attrs": {
        "login": "dev"
    }
}'::jsonb);



--SHOW search_path;        
SET search_path TO public;
DROP EXTENSION IF EXISTS "uuid-ossp";
CREATE EXTENSION "uuid-ossp" SCHEMA public;

alter table reclada.object
    add id bigint GENERATED ALWAYS AS IDENTITY primary KEY,
    add obj_id       uuid   default public.uuid_generate_v4(),
    add revision     uuid   ,
    add obj_id_int   int    ,
    add revision_int bigint ,
    add class        text   ,
    add status       uuid   ,--DEFAULT reclada_object.get_active_status_obj_id(),
    add attributes   jsonb  ,
    add transaction_id bigint ,
    add created_time timestamp with time zone DEFAULT now(),
    add created_by   uuid  ;--DEFAULT reclada_object.get_default_user_obj_id();

drop VIEW if EXISTS reclada.v_class;
drop VIEW if EXISTS reclada.v_object_status;

\i 'view/reclada.v_object_status.sql'
\i 'function/reclada_object.get_active_status_obj_id.sql'
\i 'function/reclada_object.get_archive_status_obj_id.sql'

update reclada.object 
    set class      = data->>'class',
        attributes = data->'attrs' ;
update reclada.object 
    set obj_id_int = public.try_cast_int(data->>'id'),
        revision_int  = (data->'revision')::bigint   
        -- status  = (data->'isDeleted')::boolean::int+1,
        ;
update reclada.object 
    set obj_id = (data->>'id')::uuid
        WHERE obj_id_int is null;

update reclada.object 
    set status  = 
        case coalesce((data->'isDeleted')::boolean::int+1,1)
            when 1 
                then reclada_object.get_active_status_obj_id()
            else reclada_object.get_archive_status_obj_id()
        end;

\i 'view/reclada.v_user.sql'
\i 'view/reclada.v_object.sql'
\i 'view/reclada.v_active_object.sql'
\i 'function/reclada_object.get_default_user_obj_id.sql'

alter table reclada.object
    alter COLUMN status 
        set DEFAULT reclada_object.get_active_status_obj_id(),
    alter COLUMN created_by 
        set DEFAULT reclada_object.get_default_user_obj_id();

update reclada.object set created_by = reclada_object.get_default_user_obj_id();

-- проверим, что числовой id только для ревизий
select public.raise_exception('exist numeric id for other class!!!')
    where exists
    (
        select 1 
            from reclada.object 
                where obj_id_int is not null 
                    and class != 'revision'
    );

update reclada.object -- проставим статус, тем у кого он отсутствует
    set status = reclada_object.get_active_status_obj_id()
        WHERE status is null;


-- генерируем obj_id для объектов ревизий 
update reclada.object as o
    set obj_id = g.obj_id
    from 
    (
        select  g.obj_id_int ,
                public.uuid_generate_v4() as obj_id
            from reclada.object g
            GROUP BY g.obj_id_int
            HAVING g.obj_id_int is not NULL
    ) g
        where g.obj_id_int = o.obj_id_int;

-- заносим номер ревизии в attrs
update reclada.object o
    set attributes = o.attributes 
                || jsonb ('{"num":'|| 
                    (
                        select count(1)+1 
                            from reclada.object c
                                where c.obj_id = o.obj_id 
                                    and c.obj_id_int< o.obj_id_int
                    )::text ||'}')
                -- запомним старый номер ревизии на всякий случай
                || jsonb ('{"old_num":'|| o.obj_id_int::text ||'}')
        where o.obj_id_int is not null;

-- обновляем ссылки на ревизию 
update reclada.object as o
    set revision = g.obj_id
    from 
    (
        select  g.obj_id_int ,
                g.obj_id
            from reclada.object g
            GROUP BY    g.obj_id_int ,
                        g.obj_id
            HAVING g.obj_id_int is not NULL
    ) g
        where o.revision_int = g.obj_id_int;
alter table reclada.object alter column data drop not null;

alter table reclada.object 
    alter column attributes set not null,
    alter column class set not null,
    alter column status set not null,
    alter column obj_id set not null;

-- delete from reclada.object where attrs is null

\i 'view/reclada.v_class.sql'
\i 'view/reclada.v_revision.sql'
\i 'function/reclada.datasource_insert_trigger_fnc.sql'
\i 'function/reclada_object.get_schema.sql'
\i 'function/reclada.load_staging.sql'
\i 'function/reclada_object.create.sql'
\i 'function/reclada_object.delete.sql'
\i 'function/reclada_object.update.sql'
\i 'function/reclada_object.list.sql'
\i 'function/reclada_revision.create.sql'


-- удалим вспомагательные столбцы
alter table reclada.object
    drop column revision_int,
    drop column data,
    drop column obj_id_int;


--{ indexes
DROP INDEX IF EXISTS reclada.class_index;
CREATE INDEX class_index 
	ON reclada.object(class);

DROP INDEX IF EXISTS reclada.obj_id_index;
CREATE INDEX obj_id_index 
	ON reclada.object(obj_id);

DROP INDEX IF EXISTS reclada.revision_index;
CREATE INDEX revision_index 
	ON reclada.object(revision);

DROP INDEX IF EXISTS reclada.status_index;
CREATE INDEX status_index 
	ON reclada.object(status);

DROP INDEX IF EXISTS reclada.job_status_index;
CREATE INDEX job_status_index 
	ON reclada.object((attributes->'status'))
	WHERE class = 'Job';

DROP INDEX IF EXISTS reclada.runner_status_index;
CREATE INDEX runner_status_index
	ON reclada.object((attributes->'status'))
	WHERE class = 'Runner';

DROP INDEX IF EXISTS reclada.runner_type_index;
CREATE INDEX runner_type_index 
	ON reclada.object((attributes->'type'))
	WHERE class = 'Runner';
--} indexes

update reclada.object o 
    set attributes = o.attributes || format('{"revision":"%s"}',o.revision)::jsonb
        where o.revision is not null;

alter table reclada.object
    drop COLUMN revision;


\i 'function/reclada_notification.send_object_notification.sql'
\i 'function/reclada_object.list_add.sql'
\i 'function/reclada_object.list_drop.sql'
\i 'function/reclada_object.list_related.sql'
\i 'function/api.reclada_object_create.sql'
\i 'function/api.reclada_object_delete.sql'
\i 'function/api.reclada_object_list.sql'
\i 'function/api.reclada_object_list_add.sql'
\i 'function/api.reclada_object_list_drop.sql'
\i 'function/api.reclada_object_list_related.sql'
\i 'function/api.storage_generate_presigned_get.sql'


--select dlkfmdlknfal();

-- test 1
-- select reclada_revision.create('123', null,'e2bdd471-cf23-46a9-84cf-f9e15db7887d')
-- SELECT reclada_object.create('
--   {
--        "class": "Job",
--        "revision": 10,
--        "attrs": {
--            "task": "c94bff30-15fa-427f-9954-d5c3c151e652",
--            "status": "new",
--            "type": "K8S",
--            "command": "./run_pipeline.sh",
--            "inputParameters": [{"uri": "%s"}, {"dataSourceId": "%s"}]
--            }
--        }'::jsonb);
--
-- SELECT reclada_object.update('
--   {
--      "id": "f47596e6-3117-419e-ab6d-2174f0ebf471",
-- 	 	"class": "Job",
--        "attrs": {
--            "task": "c94bff30-15fa-427f-9954-d5c3c151e652",
--            "status": "new",
--            "type": "K8S",
--            "command": "./run_pipeline.sh",
--            "inputParameters": [{"uri": "%s"}, {"dataSourceId": "%s"}]
--            }
--        }'::jsonb);

-- SELECT reclada_object.delete( '{
--       "id": "6cff152e-8391-4997-8134-8257e2717ac4"}')


--select count(1)+1 
--                        from reclada.object o
--                            where o.obj_id = 'e2bdd471-cf23-46a9-84cf-f9e15db7887d'
--
--SELECT * FROM reclada.v_revision ORDER BY ID DESC -- 77
--    LIMIT 300
-- insert into staging
--	select '{"id": "feb80c85-b0a7-40f8-864a-c874ff919bd1", "attrs": {"name": "Tmtagg tes2t f1ile.xlsx"}, "class": "Document", "fileId": "25ca0de7-e5b5-45f3-a368-788fe7eaecf8"}'

-- select reclada_object.get_schema('Job')
--update
-- +"reclada_object.list"
-- + "reclada_object.update"
-- + "reclada_object.delete"
-- + "reclada_object.create"
-- + "reclada.load_staging"
-- + "reclada_object.get_schema"
-- + "reclada_revision.create"

-- test
-- + reclada.datasource_insert_trigger_fnc
-- + reclada.load_staging
-- + reclada_object.list
-- + reclada_object.get_schema
-- + reclada_object.delete
-- + reclada_object.create
-- + reclada_object.update
-- + reclada_revision.create