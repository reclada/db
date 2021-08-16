/*
 * Function reclada_object.update updates object with new revision.
 * A jsonb with the following parameters is required.
 * Required parameters:
 *  class - the class of object
 *  id - identifier of the object
 *  attrs - the attributes of object
 * Optional parameters:
 *  branch - object's branch
 *
*/

DROP FUNCTION IF EXISTS reclada_object.update(jsonb, jsonb);
CREATE OR REPLACE FUNCTION reclada_object.update
(
    data jsonb, 
    user_info jsonb default '{}'::jsonb
)
RETURNS jsonb
LANGUAGE PLPGSQL VOLATILE
AS $body$
DECLARE
    class         text;
    obj_id        uuid;
    attrs         jsonb;
    schema        jsonb;
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
        RAISE EXCEPTION 'Could not update object with no id';
    END IF;

    attrs := data->'attrs';
    IF (attrs IS NULL) THEN
        RAISE EXCEPTION 'The reclada object must have attrs';
    END IF;

    SELECT reclada_object.get_schema(class) 
        INTO schema;

    IF (schema IS NULL) THEN
        RAISE EXCEPTION 'No json schema available for %', class;
    END IF;

    IF (NOT(validate_json_schema(schema->'attrs'->'schema', attrs))) THEN
        RAISE EXCEPTION 'JSON invalid: %', attrs;
    END IF;

    SELECT 	v.data
        FROM reclada.v_active_object v
	        WHERE v.id = obj_id
	    INTO old_obj;

    IF (old_obj IS NULL) THEN
        RAISE EXCEPTION 'Could not update object, no such id';
    END IF;

    branch := data->'branch';
    SELECT reclada_revision.create(user_info->>'sub', branch, obj_id) 
        INTO revid;
    
    INSERT INTO reclada.object(status;

    data := data || format(
        '{"revision": %s, "isDeleted": false}',
        revid
        )::jsonb; --TODO replace isDeleted with status attr
    --TODO compare old and data to avoid unnecessery inserts

    PERFORM reclada_notification.send_object_notification('update', data);
    RETURN data;

END;
$body$;
