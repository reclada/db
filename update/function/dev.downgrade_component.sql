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
    _rev_num  int;
BEGIN

    SELECT data, revision_num
        FROM reclada.v_component
            WHERE name = _component_name
        INTO _comp_obj, _rev_num;

    DELETE from reclada.object 
        WHERE transaction_id  = (_comp_obj->>'transactionID')::bigint;

    update reclada.object u
        SET status = reclada_object.get_active_status_obj_id()
        FROM (
            SELECT transaction_id
                from reclada.v_object o
                    WHERE o.obj_id = (_comp_obj->>'GUID')::uuid
                        AND coalesce(revision_num, 1) = coalesce(_rev_num, 1) - 1
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