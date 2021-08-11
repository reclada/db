/*
 * Function reclada_object.create creates one or bunch of objects with specified fields.
 * A jsonb with user_info and a jsonb or an array of jsonb objects are required.
 * A jsonb object with the following parameters is required to create one object.
 * An array of jsonb objects with the following parameters is required to create a bunch of objects.
 * Required parameters:
 *  class - the class of objects
 *  attrs - the attributes of objects
 * Optional parameters:
 *  revision - object's revision. If a revision already exists, new revision will not be created. One revision is used to create a bunch of objects.
 *  branch - object's branch
 */

DROP FUNCTION IF EXISTS reclada_object.create(jsonb, jsonb);
CREATE OR REPLACE FUNCTION reclada_object.create(data_jsonb jsonb, user_info jsonb default '{}'::jsonb)
RETURNS jsonb AS $$
DECLARE
    branch     uuid;
    revid      integer;
    data       jsonb;
    class      text;
    attrs      jsonb;
    schema     jsonb;
    obj_id     uuid;
    res        jsonb[];

BEGIN

    IF (jsonb_typeof(data_jsonb) != 'array') THEN
        data_jsonb := '[]'::jsonb || data_jsonb;
    END IF;
    /*TODO: check if some objects have revision and others do not */
    branch:= data_jsonb->0->'branch';

    IF (data_jsonb->0->'revision' IS NULL) THEN
        SELECT reclada_revision.create(user_info->>'sub', branch) INTO revid;
    END IF;

    FOR data IN SELECT jsonb_array_elements(data_jsonb) LOOP

        class := data->>'class';
        IF (class IS NULL) THEN
            RAISE EXCEPTION 'The reclada object class is not specified';
        END IF;

        attrs := data->'attrs';
        IF (attrs IS NULL) THEN
            RAISE EXCEPTION 'The reclada object must have attrs';
        END IF;

        SELECT reclada_object.get_schema(class) INTO schema;

        IF (schema IS NULL) THEN
            RAISE EXCEPTION 'No json schema available for %', class;
        END IF;

        IF (NOT(validate_json_schema(schema->'attrs'->'schema', attrs))) THEN
            RAISE EXCEPTION 'JSON invalid: %', attrs;
        END IF;

        SELECT uuid_generate_v4() INTO obj_id;

        IF (data->'revision' IS NULL) THEN
            data := data || format(
                '{"id": "%s", "revision": %s, "isDeleted": false}',
                obj_id, revid
            )::jsonb;
        ELSE
            data := data || format(
                '{"id": "%s", "isDeleted": false}',
                obj_id
            )::jsonb;
        END IF;

        res := res || data;

    END LOOP;

    INSERT INTO reclada.object SELECT * FROM unnest(res);
    PERFORM reclada_notification.send_object_notification('create', array_to_json(res)::jsonb);
    RETURN array_to_json(res)::jsonb;

END;
$$ LANGUAGE PLPGSQL VOLATILE;