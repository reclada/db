DROP FUNCTION IF EXISTS dev.downgrade_component;
CREATE or replace function dev.downgrade_component( 
    _component_name text
)
returns text
LANGUAGE PLPGSQL VOLATILE
as
$$
declare 
    _comp_obj jsonb;
BEGIN

    SELECT data 
        FROM reclada.v_component
            WHERE name = _component_name
        INTO _comp_obj;

    DELETE from reclada.object 
        WHERE transaction_id  = (_comp_obj->>'transactionID')::bigint;

    update reclada.object u
        SET status = reclada_object.get_active_status_obj_id()
        FROM (
            SELECT transaction_id
                from reclada.object 
                    WHERE guid = (_comp_obj->>'GUID')::uuid
                ORDER BY id DESC 
                LIMIT 1
        ) c
            WHERE u.transaction_id = c.transaction_id
                and NOT EXISTS (
                        SELECT from reclada.object o
                            WHERE o.status != reclada_object.get_archive_status_obj_id()
                                and o.guid = u.guid
                    );
    return 'OK';
END
$$;