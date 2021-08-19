begin;
SET CLIENT_ENCODING TO 'utf8';
CREATE TEMP TABLE var_table
    (
        ver int,
		upgrade_script text,
		downgrade_script text
    );
	
insert into var_table(ver)	
	select max(ver) + 1
        from dev.VER;
		
select public.raise_exception('Can not apply this version!') 
	where not exists
	(
		select ver from var_table where ver = 1 --!!! write current version HERE !!!
	);

CREATE TEMP TABLE tmp
(
	id int GENERATED ALWAYS AS IDENTITY,
	str text
);
--{ logging upgrade script
\COPY tmp(str) FROM  'up.sql' delimiter E'\x01';
update var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');
delete from tmp;
--} logging upgrade script	

--{ create downgrade script
\COPY tmp(str) FROM  'down.sql' delimiter E'\x01';
update tmp set str = drp.v || scr.v
	from tmp ttt
	inner JOIN LATERAL
    (
        select substring(ttt.str from 4 for length(ttt.str)-4) as v
    )  obj_file_name ON TRUE
	inner JOIN LATERAL
    (
        select 	split_part(obj_file_name.v,'/',1) typ,
        		split_part(obj_file_name.v,'/',2) nam
    )  obj ON TRUE
		inner JOIN LATERAL
    (
        select 	'drop '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n' as v
    )  drp ON TRUE
	inner JOIN LATERAL
    (
        select case 
				when obj.typ in ('function', 'procedure')
					then
						case 
							when EXISTS
								(
									SELECT 1 a
										FROM pg_proc p 
										join pg_namespace n 
											on p.pronamespace = n.oid 
											where n.nspname||'.'||p.proname = obj.nam
										LIMIT 1
								) 
								then (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))
							else ''
						end
				when obj.typ = 'view'
					then
						case 
							when EXISTS
								(
									select 1 a 
										from pg_views v 
											where v.schemaname||'.'||v.viewname = obj.nam
										LIMIT 1
								) 
								then E'CREATE OR REPLACE VIEW '
                                        || obj.nam
                                        || E'\nAS\n'
                                        || (select pg_get_viewdef(obj.nam, true))
							else ''
						end
				else 
					ttt.str
			end as v
    )  scr ON TRUE
	where ttt.str = tmp.str 
		and tmp.str like '--{%/%}';
	
update var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');	
--} create downgrade script
drop table tmp;


--{!!! write upgrare script HERE !!!

--	you can use "\i 'function/reclada_object.get_schema.sql'"
--	to run text script of functions
 
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
    add tran_id      bigint ,
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
	ON reclada.object((attrs->'status'))
	WHERE class = 'Job';

DROP INDEX IF EXISTS reclada.runner_status_index;
CREATE INDEX runner_status_index
	ON reclada.object((attrs->'status'))
	WHERE class = 'Runner';

DROP INDEX IF EXISTS reclada.runner_type_index;
CREATE INDEX runner_type_index 
	ON reclada.object((attrs->'type'))
	WHERE class = 'Runner';
--} indexes

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



-- select * from reclada.v_object ORDER BY ID DESC;
-- select * from reclada.v_class;

-- select * from reclada.object ORDER BY id
-- insert into reclada.object(data,obj_id,revision,obj_id_int,revision_int,class,status,  
-- attrs    ,
-- time_when)
-- select data,obj_id,revision,obj_id_int,revision_int,class,status,  
-- attrs    ,
-- time_when from reclada.object where id = 7


--}!!! write upgrare script HERE !!!

insert into dev.ver(ver,upgrade_script,downgrade_script)
	select ver, upgrade_script, downgrade_script
		from var_table;

--{ testing downgrade script
SAVEPOINT sp;
    select dev.downgrade_version();
ROLLBACK TO sp;
--} testing downgrade script

select public.raise_notice('OK, curren version: ' 
							|| (select ver from var_table)::text
						  );
drop table var_table;

commit;