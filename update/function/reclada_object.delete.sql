/*
* Function reclada_object.delete updates object with field "isDeleted": true.
 * A jsonb with the following parameters is required.
 * Required parameters:
 *  class - the class of object
 *  id - identifier of the object
 * Optional parameters:
 *  attrs - the attributes of object
 *  branch - object's branch
 *
*/

DROP FUNCTION IF EXISTS reclada_object.delete(jsonb, jsonb);
CREATE OR REPLACE FUNCTION reclada_object.delete(data jsonb, user_info jsonb default '{}'::jsonb)
RETURNS jsonb
LANGUAGE PLPGSQL VOLATILE
AS $$
DECLARE
    class         text;
    obj_id        uuid;
    old_obj       jsonb;
    branch        uuid;
    revid         integer;

BEGIN

    class := data->>'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

    obj_id := data->>'id';
    IF (obj_id IS NULL) THEN
        RAISE EXCEPTION 'Could not delete object with no id';
    END IF;

	SELECT 	v.data
	FROM reclada.v_object v
	WHERE v.id = (obj_id::text)
	INTO old_obj;

    IF (old_obj IS NULL) THEN
        RAISE EXCEPTION 'Could not delete object, no such id';
    END IF;

    branch := data->'branch';

    SELECT reclada_revision.create(user_info->>'sub', branch) INTO revid;
    data := old_obj || format(
            '{"revision": %s, "isDeleted": true}',
            revid
        )::jsonb;

    INSERT INTO reclada.object VALUES(data);

    PERFORM reclada_notification.send_object_notification('delete', data);

    RETURN data;

END;
$$;