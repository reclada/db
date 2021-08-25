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

DROP FUNCTION IF EXISTS reclada_object.update;
CREATE OR REPLACE FUNCTION reclada_object.update
(
    data jsonb, 
    user_info jsonb default '{}'::jsonb
)
RETURNS jsonb
LANGUAGE PLPGSQL VOLATILE
AS $body$
DECLARE
    v_class         text;
    v_obj_id        uuid;
    v_attrs         jsonb;
    schema        jsonb;
    old_obj       jsonb;
    branch        uuid;
    revid         uuid;

BEGIN

    v_class := data->>'class';
    IF (v_class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

    v_obj_id := data->>'id';
    IF (v_obj_id IS NULL) THEN
        RAISE EXCEPTION 'Could not update object with no id';
    END IF;

    v_attrs := data->'attrs';
    IF (v_attrs IS NULL) THEN
        RAISE EXCEPTION 'The reclada object must have attrs';
    END IF;

    SELECT reclada_object.get_schema(v_class) 
        INTO schema;

    IF (schema IS NULL) THEN
        RAISE EXCEPTION 'No json schema available for %', v_class;
    END IF;

    IF (NOT(validate_json_schema(schema->'attrs'->'schema', v_attrs))) THEN
        RAISE EXCEPTION 'JSON invalid: %', v_attrs;
    END IF;

    SELECT 	v.data
        FROM reclada.v_active_object v
	        WHERE v.obj_id = v_obj_id
	    INTO old_obj;

    IF (old_obj IS NULL) THEN
        RAISE EXCEPTION 'Could not update object, no such id';
    END IF;

    branch := data->'branch';
    SELECT reclada_revision.create(user_info->>'sub', branch, v_obj_id) 
        INTO revid;
    
    with t as 
    (
        update reclada.object o
            set status = reclada_object.get_archive_status_obj_id()
                where o.obj_id = v_obj_id
                    and status != reclada_object.get_archive_status_obj_id()
                        RETURNING id
    )
    INSERT INTO reclada.object( obj_id,
                                class,
                                status,
                                attributes
                              )
        select  v.obj_id,
                v_class,
                reclada_object.get_active_status_obj_id(),--status 
                v_attrs || format('{"revision":"%s"}',revid)::jsonb
            FROM reclada.v_object v
            JOIN t 
                on t.id = v.id
	            WHERE v.obj_id = v_obj_id;
                    
    select v.data 
        FROM reclada.v_active_object v
            WHERE v.obj_id = v_obj_id
        into data;
    PERFORM reclada_notification.send_object_notification('update', data);
    RETURN data;
END;
$body$;
