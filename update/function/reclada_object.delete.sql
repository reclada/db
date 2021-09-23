/*
* Function reclada_object.delete updates object with field "isDeleted": true.
 * A jsonb with the following parameters is required.
 * Required parameters:
 *  class - the class of object
 *  id - identifier of the object
 * Optional parameters:
 *  attributes - the attributes of object
 *  branch - object's branch
 *
*/

DROP FUNCTION IF EXISTS reclada_object.delete;
CREATE OR REPLACE FUNCTION reclada_object.delete(data jsonb, user_info jsonb default '{}'::jsonb)
RETURNS jsonb
LANGUAGE PLPGSQL VOLATILE
AS $$
DECLARE
    v_obj_id   uuid;
    tran_id    bigint;
BEGIN

    tran_id := (data->>'transactionID')::bigint;

    v_obj_id := data->>'GUID';
    IF (v_obj_id IS NULL and tran_id IS NULl) THEN
        RAISE EXCEPTION 'Could not delete object with no GUID and transactionID';
    END IF;

    
    with t as 
    (    
        update reclada.object o
            set status = reclada_object.get_archive_status_obj_id() 
                WHERE 
                (
                       (o.GUID = v_obj_id and tran_id is null           )
                    OR (o.GUID = v_obj_id and tran_id = o.transaction_id)
                    OR (v_obj_id is null  and tran_id = o.transaction_id)
                )
                    and status != reclada_object.get_archive_status_obj_id()
                    RETURNING id
    ) 
        select array_to_json
            (
                array
                (
                    SELECT o.data
                        from t
                        join reclada.v_object o
                            on o.id = t.id
                )
            )::jsonb
            into data;
    
    if (jsonb_array_length(data) = 1) then
        data := data->0;
    end if;
    
    IF (data IS NULL) THEN
        RAISE EXCEPTION 'Could not delete object, no such GUID';
    END IF;

    PERFORM reclada_notification.send_object_notification('delete', data);

    RETURN data;
END;
$$;