/*
 * Function api.reclada_object_create checks valid data and uses reclada_object.create to create one or bunch of objects with specified fields.
 * A jsonb object with the following parameters is required to create one object.
 * An array of jsonb objects with the following parameters is required to create a bunch of objects.
 * Required parameters:
 *  class - the class of objects
 *  attributes - the attributes of objects
 *  accessToken - jwt token to authorize
 * Optional parameters:
 *  revision - object's revision. If a revision already exists, new revision will not be created. One revision is used to create a bunch of objects.
 *  branch - object's branch
 */

DROP FUNCTION IF EXISTS api.reclada_object_create;
CREATE OR REPLACE FUNCTION api.reclada_object_create(data jsonb)
RETURNS jsonb AS $$
DECLARE
    data_jsonb       jsonb;
    class            jsonb;
    user_info        jsonb;
    attrs            jsonb;
    data_to_create   jsonb = '[]'::jsonb;
    result           jsonb;

BEGIN

    IF (jsonb_typeof(data) != 'array') THEN
        data := '[]'::jsonb || data;
    END IF;

    FOR data_jsonb IN SELECT jsonb_array_elements(data) LOOP

        class := data_jsonb->'class';
        IF (class IS NULL) THEN
            RAISE EXCEPTION 'The reclada object class is not specified';
        END IF;

        SELECT reclada_user.auth_by_token(data_jsonb->>'accessToken') INTO user_info;
        data_jsonb := data_jsonb - 'accessToken';

        IF (NOT(reclada_user.is_allowed(user_info, 'create', class))) THEN
            RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'create', class;
        END IF;

        attrs := data_jsonb->'attributes';
        IF (attrs IS NULL) THEN
            RAISE EXCEPTION 'The reclada object must have attributes';
        END IF;

        data_to_create := data_to_create || data_jsonb;
    END LOOP;

    SELECT reclada_object.create(data_to_create, user_info) INTO result;
    RETURN result;

END;
$$ LANGUAGE PLPGSQL VOLATILE;
