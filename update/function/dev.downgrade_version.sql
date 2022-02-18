DROP FUNCTION IF EXISTS dev.downgrade_version;
CREATE or replace function dev.downgrade_version()
returns text
LANGUAGE PLPGSQL VOLATILE
as
$do$
declare 
    _comp_obj jsonb;
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

    select data from reclada.v_component
        where name = 'db'
        into _comp_obj;
    
    DELETE from reclada.object 
        where id in (
            select value::bigint 
                from jsonb_array_elements(_comp_obj#>'{attributes,created}')
            union 
            select id 
                from reclada.v_component 
                    where name = 'db'
        );

    DELETE from reclada.object 
        where id in (select id 
                from reclada.v_relationship r
                    WHERE subject in (
                            select guid from reclada.object 
                                where id in (
                                    select value::bigint 
                                        from jsonb_array_elements(_comp_obj#>'{attributes,created}')
                                )
                        )
                        and not exists (select from reclada.object o where r.subject = o.guid)
        );

    UPDATE reclada.object 
        SET status = reclada_object.get_active_status_obj_id()
        WHERE id in (
            SELECT value::bigint 
                FROM jsonb_array_elements(_comp_obj#>'{attributes,deleted}')
            UNION 
            SELECT max(id)
                FROM reclada.v_object obj
   	                WHERE obj.class_name = 'Component'
                        and obj.attrs->>'name' = 'db'
        );

    EXECUTE downgrade_script;

    -- mark, that chanches applied
    delete 
        from dev.VER v
            where v.ver = current_ver;

    v_msg = 'OK, curren version: ' || (current_ver-1)::text;
    perform reclada.raise_notice(v_msg);
    return v_msg;
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
    return v_state;
END
$do$;