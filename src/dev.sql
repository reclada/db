CREATE SCHEMA dev;
-- drop FUNCTION dev.raise_exception
CREATE FUNCTION public.raise_exception(msg text)
  RETURNS void
  LANGUAGE plpgsql VOLATILE
AS
$func$
BEGIN
    -- 
    RAISE EXCEPTION '%', msg;
END
$func$;

CREATE FUNCTION public.raise_notice(msg text)
  RETURNS void
  LANGUAGE plpgsql VOLATILE
AS
$func$
BEGIN
    -- 
    RAISE NOTICE '%', msg;
END
$func$;

-- drop table dev.ver
CREATE table dev.ver
(
    id INT GENERATED ALWAYS AS IDENTITY,
    ver int not null,
    ver_str text not null,
    upgrade_script text not null,
    downgrade_script text not null,
    run_at timestamp with time zone DEFAULT now()
);
insert into dev.ver(
                    ver,
                    ver_str,
                    upgrade_script,
                    downgrade_script)
    select  0,
            '0',
            'select public.raise_exception (''This is 0 version'');',
            'select public.raise_exception (''This is 0 version'');';

CREATE table dev.t_dbg
(
    id INT GENERATED ALWAYS AS IDENTITY,
    msg text not null,
    time_when timestamp with time zone DEFAULT now()
);



CREATE FUNCTION dev.reg_notice(msg   TEXT)
RETURNS void
LANGUAGE PLPGSQL VOLATILE
as
$do$
BEGIN
    insert into dev.t_dbg(msg)
		select msg;
    perform public.raise_notice(msg);
END
$do$;


-- DROP PROCEDURE dev.upgrade_version;
CREATE or replace PROCEDURE dev.upgrade_version(path_to_updates_folder text, p_ver_str text)
-- select dev.upgrade_version('/src/updates/')
LANGUAGE PLPGSQL 
as
$$
declare 
    current_ver int; 
    upgrade_script text;
    downgrade_script text;
    v_state   TEXT;
    v_msg     TEXT;
    v_detail  TEXT;
    v_hint    TEXT;
    v_context TEXT;
BEGIN
    
    if EXISTS 
    (
        select 1 a
            from dev.VER v
                where v.ver_str = p_ver_str
    ) then
        perform public.raise_exception('This version already applied!');
    end if;

    select max(ver) + 1
        from dev.VER
    into current_ver;

    select dev.create_script_from_file
        (
            path_to_updates_folder, 'up.sql'
        )
        into upgrade_script;
    
    select dev.create_script_from_file
        (
            path_to_updates_folder, 'down.sql'
        )
        into downgrade_script;
        
    EXECUTE upgrade_script;
    
    -- to validate downgrade_script
	--EXECUTE'
    --SAVEPOINT pp;
    --    EXECUTE downgrade_script;
    --ROLLBACK TO SAVEPOINT pp;';

    -- mark, that chanches applied
    insert into dev.ver(ver,upgrade_script,downgrade_script,ver_str)
        select current_ver, upgrade_script, downgrade_script,p_ver_str;

    v_msg = 'OK, curren version: ' || (current_ver)::text;
    perform public.raise_notice('OK');
EXCEPTION when OTHERS then 
	get stacked diagnostics
        v_state   = returned_sqlstate,
        v_msg     = message_text,
        v_detail  = pg_exception_detail,
        v_hint    = pg_exception_hint,
        v_context = pg_exception_context;

    v_state := format('Got exception:
state   : %s
message : %s
detail  : %s
hint    : %s
context : %s
SQLSTATE: %s
SQLERRM : %s', 
                v_state, 
                v_msg, 
                v_detail, 
                v_hint, 
                v_context,
                SQLSTATE,
                SQLERRM);
    perform dev.reg_notice(v_state);
END;
$$;


-- downgrade scrypt
-- drop procedure dev.downgrade_version;
CREATE procedure dev.downgrade_version()
LANGUAGE PLPGSQL 
as
$do$
declare 
    current_ver int; 
    downgrade_script text;
    v_state   TEXT;
    v_msg     TEXT;
    v_detail  TEXT;
    v_hint    TEXT;
    v_context TEXT;
BEGIN

    select max(ver) 
        from dev.VER
    into current_ver;-- !!!set version here!!! 
    
    select v.downgrade_script 
        from dev.VER v
            WHERE current_ver = v.ver
        into downgrade_script;

    if COALESCE(downgrade_script,'') = '' then
        RAISE EXCEPTION 'downgrade_script is empty! from dev.downgrade_version()';
    end if;

    EXECUTE downgrade_script;

    -- mark, that chanches applied
    delete 
        from dev.VER v
            where v.ver = current_ver;

    v_msg = 'OK, curren version: ' || (current_ver-1)::text;
    perform public.raise_notice(v_msg);
EXCEPTION when OTHERS then 
	get stacked diagnostics
        v_state   = returned_sqlstate,
        v_msg     = message_text,
        v_detail  = pg_exception_detail,
        v_hint    = pg_exception_hint,
        v_context = pg_exception_context;

    v_state := format('Got exception:
state   : %s
message : %s
detail  : %s
hint    : %s
context : %s
SQLSTATE: %s
SQLERRM : %s', 
                v_state, 
                v_msg, 
                v_detail, 
                v_hint, 
                v_context,
                SQLSTATE,
                SQLERRM);
    perform dev.reg_notice(v_state);
END
$do$;

--drop FUNCTION dev.test_version()
--CREATE FUNCTION dev.test_version()
--RETURNS void
--LANGUAGE PLPGSQL VOLATILE
--as
--$do$
--declare downgrade_script text;
--BEGIN
--    SELECT reclada_object.create_subclass('{
--        "class": "RecladaObject",
--        "attrs": {
--            "newClass": "Message",
--            "properties": {
--                "channelName": {"type": "string"},
--                "class": {"type": "string"},
--                "event": {
--                    "type": "string",
--                    "enum": [
--                        "create",
--                        "update",
--                        "list",
--                        "delete"
--                    ]
--                },
--                "attrs": {"type": "array", "items": {"type": "string"}}
--            },
--            "required": ["class", "channelName", "event"]
--        }
--    }'::jsonb);
--END
--$do$;

-- drop FUNCTION dev.base_name;
CREATE FUNCTION dev.base_name(text) RETURNS text
    AS $basename$
declare
    FILE_PATH alias for $1;
    ret         text;
begin
    -- get file name from full file name (path)
    ret := regexp_replace(FILE_PATH,'^.+[/\\]', '');
    return ret;
end;
$basename$ LANGUAGE plpgsql;

-- drop FUNCTION dev.create_script_from_file;
CREATE FUNCTION dev.create_script_from_file(folder text, file_name text)
RETURNS text 
LANGUAGE plpgsql VOLATILE
AS $$
DECLARE
    tmprow record ;
    objrow record ;
    res text;
    obj_scr text;
    obj_path text;
    obj_file_name text;
    obj_name text;
    obj_type text;
    delimit text;
BEGIN
    res := '';
	-- select chr(1)
    delimit := ''' delimiter '''||chr(1)||'''';
    CREATE TEMP TABLE tmp
    (
        id int GENERATED ALWAYS AS IDENTITY,
        str text
    );
    EXECUTE 'COPY tmp(str) FROM '''|| folder || file_name ||delimit ;
    FOR tmprow IN
    SELECT str FROM tmp ORDER BY id asc
    LOOP
		
		--raise notice 'res: %', res;
		--raise notice 'str: %', tmprow.str;
        if tmprow.str not like '--{%}' then
            res := res || E'\n'|| tmprow.str;
        ELSE
            obj_file_name := substring(tmprow.str from 4 for length(tmprow.str)-4);
            obj_scr := '';
            if file_name = 'up.sql' then
            -- parse line type --{functions/api.hello_world.sql}
            -- and insert code from file in current script
                CREATE TEMP TABLE obj
                (
                    id int GENERATED ALWAYS AS IDENTITY,
                    str text
                );
                    obj_path := folder;
                    -- убрали слэш
                    -- obj_path := substring(obj_path from 1 for length(obj_path)-1);-- [4:-1]
                    -- убрали номер версии
                    --obj_path := substring(obj_path from 1 for length(dev.base_name(obj_path))-2);-- [4:-1]
                    --obj_path := replace(obj_path,dev.base_name(obj_path),'');
                    -- убрали слэш
                    -- obj_path := substring(obj_path from 1 for length(obj_path)-1);-- [4:-1]
                    -- вышли из папки versions
                    -- obj_path := substring(obj_path from 1 for length(dev.base_name(obj_path))-1);-- [4:-1]
                    --obj_path := replace(obj_path,dev.base_name(obj_path),'');
                    obj_path := obj_path || obj_file_name;-- [4:-1]

                    raise notice '%',obj_path;

                    obj_scr  := '';
                    EXECUTE 'COPY obj(str) FROM '''|| obj_path || delimit;
                    FOR objrow IN
                        SELECT str FROM obj ORDER BY id asc
                    LOOP
                        obj_scr := obj_scr || E'\n'|| objrow.str;
                    END LOOP;
                drop table obj;
            ELSIF file_name = 'down.sql' then
                obj_type := split_part(obj_file_name,'/',1);
                obj_name := split_part(obj_file_name,'/',2);
                obj_name := substring(obj_name from 1 for length(obj_name)-4);-- to del ".sql" 
                if obj_type in ('functions', 'procedures') then
                    if EXISTS
                    (
                        SELECT 1 a
                            FROM pg_proc p 
                            join pg_namespace n 
                                on p.pronamespace = n.oid 
                                where n.nspname||'.'||p.proname = obj_name
                            LIMIT 1
                    ) then
                        select pg_catalog.pg_get_functiondef(obj_name::regproc::oid)
                            into obj_scr;
                    else 
                        obj_scr := 'drop FUNCTION ' || obj_name || ';';
                    end if;
                ELSIF obj_type = 'views' then
                    if EXISTS
                    (
                        select 1 a 
                            from pg_views v 
                                where v.schemaname||'.'||v.viewname = obj_name
                        

                    ) then
                        select pg_get_viewdef(obj_name, true)
                            into obj_scr;
                        obj_scr  := 'CREATE OR REPLACE VIEW '
                                        || obj_name
                                        || E'\nAS\n'
                                        || obj_scr;
                    else 
                        obj_scr := 'drop view ' || obj_name || ';';
                    end if;                   
                end if; 
            else
                res := res || E'\n'|| tmprow.str;
            end if;
            res := res || E'\n'|| obj_scr;
        end if;
    END LOOP;
    --EXECUTE 'SELECT content FROM ' || tmp INTO content;
    drop table tmp;
    
    RETURN res;
END;
$$;

/*
set replication_role = 'replica';
set replication_role = DEFAULT;
*/