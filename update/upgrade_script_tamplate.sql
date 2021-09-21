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
		
select reclada.raise_exception('Can not apply this version!') 
	where not exists
	(
		select ver from var_table where ver = /*#@#@#version#@#@#*/ --!!! write current version HERE !!!
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
        select case
				when obj.typ = 'trigger'
					then
					    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'
                        from (
                            select n.nspname as schm,
                                   c.relname as tbl
                            from pg_trigger t
                                join pg_class c on c.oid = t.tgrelid
                                join pg_namespace n on n.oid = c.relnamespace
                            where t.tgname = 'datasource_insert_trigger') o)
                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'
                end as v
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
								then (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'
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
				when obj.typ = 'trigger'
					then
						case
							when EXISTS
								(
									select 1 a
										from pg_trigger v
                                            where v.tgname = obj.nam
										LIMIT 1
								)
								then (select pg_catalog.pg_get_triggerdef(oid, true)
								        from pg_trigger
								        where tgname = obj.nam)||';'
							else ''
						end
				else 
					ttt.str
			end as v
    )  scr ON TRUE
	where ttt.id = tmp.id
		and tmp.str like '--{%/%}';
	
update var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');	
--} create downgrade script
drop table tmp;


--{!!! write upgrare script HERE !!!

--	you can use "\i 'function/reclada_object.get_schema.sql'"
--	to run text script of functions
 
/*#@#@#upgrade_script#@#@#*/

--}!!! write upgrare script HERE !!!

insert into dev.ver(ver,upgrade_script,downgrade_script)
	select ver, upgrade_script, downgrade_script
		from var_table;

--{ testing downgrade script
SAVEPOINT sp;
    select dev.downgrade_version();
ROLLBACK TO sp;
--} testing downgrade script

select reclada.raise_notice('OK, curren version: ' 
							|| (select ver from var_table)::text
						  );
drop table var_table;

commit;
