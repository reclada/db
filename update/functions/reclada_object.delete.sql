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

DROP FUNCTION IF EXISTS reclada_object.delete(jsonb, jsonb);
CREATE OR REPLACE FUNCTION reclada_object.delete(data jsonb, user_info jsonb default '{}'::jsonb)
RETURNS jsonb
LANGUAGE PLPGSQL VOLATILE
AS $$
DECLARE
    class         jsonb;
    obj_id        jsonb;
    oldobj        jsonb;
    branch        uuid;
    revid         integer;

BEGIN

    class := data->'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

	-- validate obj_id as uuid
	PERFORM (data->>'id')::uuid;

    obj_id := data->'id';
    IF (obj_id IS NULL) THEN
        RAISE EXCEPTION 'Could not delete object with no id';
    END IF;
	

	/*
    SELECT reclada_object.list(format(
        '{"class": %s, "id": "%s"}',
        class,
        obj_id
        )::jsonb) -> 0 INTO oldobj;
	*/
	SELECT 	v.data
		FROM reclada.v_object v
			WHERE v.id = obj_id
		INTO oldobj;
		
    IF (oldobj IS NULL) THEN
        RAISE EXCEPTION 'Could not delete object, no such id';
    END IF;

    branch := data->'branch';

    SELECT reclada_revision.create(user_info->>'sub', branch) INTO revid;
    data := oldobj || format(
            '{"revision": %s, "isDeleted": true}',
            revid
        )::jsonb;

    INSERT INTO reclada.object VALUES(data);

    PERFORM reclada_notification.send_object_notification('delete', data);

    RETURN data;

END;
$$;
