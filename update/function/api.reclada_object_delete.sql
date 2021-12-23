
/*
 * Function api.reclada_object_delete checks valid data and uses reclada_object.delete to update object with field "isDeleted": true.
 * A jsonb with the following parameters is required.
 * Required parameters:
 *  class - the class of object and
 *  GUID - the identifier of the object or transactionID - object's transaction number. One transactionID is used for a bunch of objects.
 *  accessToken - jwt token to authorize
 * Optional parameters:
 *  attributes - the attributes of object
 *  branch - object's branch
 *
*/

DROP FUNCTION IF EXISTS api.reclada_object_delete(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_delete(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class         text;
    obj_id        uuid;
    user_info     jsonb;
    result        jsonb;

BEGIN

    class := coalesce(data ->> '{class}', data ->> 'class');
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    obj_id := coalesce(data ->> '{GUID}', data ->> 'GUID');
    IF (obj_id IS NULL) THEN
        RAISE EXCEPTION 'Could not delete object with no id';
    END IF;

    data := data || ('{"GUID":"'|| obj_id ||'","class":"'|| class ||'"}')::jsonb;

    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
    data := data - 'accessToken';

    IF (NOT(reclada_user.is_allowed(user_info, 'delete', class))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'delete', class;
    END IF;

    SELECT reclada_object.delete(data, user_info) INTO result;

    if reclada_object.need_flat(class) then 
        RETURN '{"status":"OK"}'::jsonb;
    end if;

    RETURN result;

END;
$$ LANGUAGE PLPGSQL VOLATILE;

