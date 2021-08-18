-- version = 1
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

\i 'function/public.try_cast_int.sql'


create table reclada.object_status
(
    id      bigint GENERATED ALWAYS AS IDENTITY primary KEY,
    caption text not null
);
insert into reclada.object_status(caption)
    select 'active';
insert into reclada.object_status(caption)
    select 'archive';

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
    add name         text   ,
    add class        text   ,
    add status       int    DEFAULT 1,--active
    add attrs        jsonb  ,
    add created_time timestamp with time zone DEFAULT now(),
    add created_by   text,
    add CONSTRAINT fk_status
      FOREIGN KEY(status) 
      REFERENCES reclada.object_status(id);

update reclada.object 
    set obj_id_int = public.try_cast_int(data->>'id'),
        class  = data->>'class'                      ,
        revision_int  = (data->'revision')::bigint   ,
        status  = (data->'isDeleted')::boolean::int+1,
        attrs  = data->'attrs';

update reclada.object 
    set obj_id = (data->>'id')::uuid
        WHERE obj_id_int is null;
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
    set status = 1 
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
    set attrs = o.attrs 
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
    alter column attrs set not null,
    alter column class set not null,
    alter column status set not null,
    alter column obj_id set not null;

-- delete from reclada.object where attrs is null

drop VIEW if EXISTS reclada.v_class;

\i 'view/reclada.v_object.sql'
\i 'view/reclada.v_active_object.sql'
\i 'view/reclada.v_class.sql'
\i 'view/reclada.v_revision.sql'
\i 'function/reclada_revision.create.sql'
\i 'function/reclada.datasource_insert_trigger_fnc.sql'
\i 'function/reclada_object.get_schema.sql'
\i 'function/reclada.load_staging.sql'
\i 'function/reclada_object.create.sql'
\i 'function/reclada_object.delete.sql'
\i 'function/reclada_object.update.sql'
\i 'function/reclada_object.list.sql'

-- удалим вспомагательные столбцы
alter table reclada.object
    drop column revision_int,
    drop column data,
    drop column obj_id_int;



-- test 1
-- select reclada_revision.create('123', null,'e2bdd471-cf23-46a9-84cf-f9e15db7887d')
-- select reclada_revision.create(NULL, NULL)
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


--select count(1)+1 
--                        from reclada.object o
--                            where o.obj_id = 'e2bdd471-cf23-46a9-84cf-f9e15db7887d'
--
--SELECT * FROM reclada.v_revision ORDER BY ID DESC -- 77
--    LIMIT 300

-- "reclada_object.list"
-- + "reclada_object.update"
-- + "reclada_object.delete"
-- + "reclada_object.create"
-- + "reclada.load_staging"
-- + "reclada_object.get_schema"
-- + "reclada_revision.create"




-- select * from reclada.v_object ORDER BY ID DESC;
-- select * from reclada.v_class;

-- select * from reclada.object ORDER BY id
-- insert into reclada.object(data,obj_id,revision,obj_id_int,revision_int,class,status,  
-- attrs    ,
-- time_when)
-- select data,obj_id,revision,obj_id_int,revision_int,class,status,  
-- attrs    ,
-- time_when from reclada.object where id = 7
