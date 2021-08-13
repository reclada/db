
/*
 * Function api.reclada_object_delete checks valid data and uses reclada_object.delete to update object with field "isDeleted": true.
 * A jsonb with the following parameters is required.
 * Required parameters:
 *  class - the class of object
 *  id - identifier of the object
 *  accessToken - jwt token to authorize
 * Optional parameters:
 *  attrs - the attributes of object
 *  branch - object's branch
 *
*/

DROP FUNCTION IF EXISTS api.reclada_object_delete(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_delete(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class         jsonb;
    obj_id         uuid;
    user_info     jsonb;
    result        jsonb;

BEGIN

    class := data->'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    obj_id := data->>'id';
    IF (obj_id IS NULL) THEN
        RAISE EXCEPTION 'Could not delete object with no id';
    END IF;

    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
    data := data - 'accessToken';

    IF (NOT(reclada_user.is_allowed(user_info, 'delete', class))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'delete', class;
    END IF;

    SELECT reclada_object.delete(data, user_info) INTO result;
    RETURN result;

END;
$$ LANGUAGE PLPGSQL VOLATILE;