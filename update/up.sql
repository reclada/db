begin;
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
        select 	'drop '||obj.typ|| ' '|| obj.nam || ' ;' || E'\n' as v
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
create table dev.test1(d text);

\i function/public.try_cast_int.sql

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