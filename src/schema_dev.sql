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
    ver_str text,
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

-- drop function dev.downgrade_version;
CREATE or replace function dev.downgrade_version()
returns void
LANGUAGE PLPGSQL VOLATILE
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
    into current_ver;
    
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

/*
set replication_role = 'replica';
set replication_role = DEFAULT;
*/