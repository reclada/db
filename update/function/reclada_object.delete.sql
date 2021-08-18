/*
 * Function reclada_object.delete to updates object with field "isDeleted": true.
 * A jsonb with the following parameters is required.
 * Required parameters:
 *  class - the class of object
 *  id - identifier of the object
 * Optional parameters:
 *  attrs - the attributes of object
 *  branch - object's branch
 *
*/

DROP FUNCTION IF EXISTS reclada_object.delete;
CREATE OR REPLACE FUNCTION reclada_object.delete(data jsonb, user_info jsonb default '{}'::jsonb)
RETURNS jsonb
LANGUAGE PLPGSQL VOLATILE
AS $$
DECLARE
    class         text;
    obj_id        uuid;
    old_obj       jsonb;
    branch        uuid;
    revid         uuid;

BEGIN

    obj_id := data->>'id';
    IF (obj_id IS NULL) THEN
        RAISE EXCEPTION 'Could not delete object with no id';
    END IF;

    
    with t as (    
        update reclada.object o
            set status = 2 -- archive
                WHERE o.obj_id = obj_id
                    RETURNING data
    ) 
        SELECT data 
            from t
            into data;
    
    IF (data IS NULL) THEN
        RAISE EXCEPTION 'Could not delete object, no such id';
    END IF;

    PERFORM reclada_notification.send_object_notification('delete', data);

    RETURN data;
END;
$$;