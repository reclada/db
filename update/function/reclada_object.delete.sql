/*
* Function reclada_object.delete updates object with field "isDeleted": true.
 * A jsonb with the following parameters is required.
 * At least one of the following parameters is required:
 *  GUID - the identifier of the object
 *  class - the class of objects
 *  transactionID - object's transaction number. One transactionID is used for a bunch of objects.
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
    v_obj_id            uuid;
    tran_id             bigint;
    class               text;
    class_uuid          uuid;

BEGIN

    v_obj_id := data->>'GUID';
    tran_id := (data->>'transactionID')::bigint;
    class := data->>'class';

    IF (v_obj_id IS NULL AND class IS NULL AND tran_id IS NULl) THEN
        RAISE EXCEPTION 'Could not delete object with no GUID, class and transactionID';
    END IF;

    class_uuid := reclada.try_cast_uuid(class);
    IF class_uuid IS NULL AND class IS NOT NULL THEN
        class_uuid:= reclada_object.get_GUID_for_class(class);
    END IF;

    WITH t AS
    (    
        UPDATE reclada.object o
            SET status = reclada_object.get_archive_status_obj_id()
                WHERE 
                (
                    (v_obj_id = o.GUID AND class_uuid = o.class AND tran_id = o.transaction_id)

                    OR (v_obj_id = o.GUID AND class_uuid = o.class AND tran_id IS NULL)
                    OR (v_obj_id = o.GUID AND class_uuid IS NULL AND tran_id = o.transaction_id)
                    OR (v_obj_id IS NULL AND class_uuid = o.class AND tran_id = o.transaction_id)

                    OR (v_obj_id = o.GUID AND class_uuid IS NULL AND tran_id IS NULL)
                    OR (v_obj_id IS NULL AND class_uuid = o.class AND tran_id IS NULL)
                    OR (v_obj_id IS NULL AND class_uuid IS NULL AND tran_id = o.transaction_id)
                )
                    AND status != reclada_object.get_archive_status_obj_id()
                    RETURNING id
    ) 
        SELECT array_to_json
            (
                array
                (
                    SELECT o.data
                        FROM t
                        join reclada.v_object o
                            on o.id = t.id
                )
            )::jsonb
            INTO data;
    
    IF (jsonb_array_length(data) = 1) THEN
        data := data->0;
    END IF;
    
    IF (data IS NULL) THEN
        RAISE EXCEPTION 'Could not delete object, no such GUID';
    END IF;

    PERFORM reclada_notification.send_object_notification('delete', data);

    RETURN data;
END;
$$;