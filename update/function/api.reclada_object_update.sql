
/*
 * Function api.reclada_object_update checks valid data and uses reclada_object.update to update object with new revision.
 * A jsonb with the following parameters is required.
 * Required parameters:
 *  class - the class of object
 *  id - identifier of the object
 *  attributes - the attributes of object
 *  accessToken - jwt token to authorize
 * Optional parameters:
 *  branch - object's branch
 *
*/

DROP FUNCTION IF EXISTS api.reclada_object_update;
CREATE OR REPLACE FUNCTION api.reclada_object_update(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class         jsonb;
    objid         uuid;
    attrs         jsonb;
    user_info     jsonb;
    result        jsonb;

BEGIN

    class := data->'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    objid := data->>'id';
    IF (objid IS NULL) THEN
        RAISE EXCEPTION 'Could not update object with no id';
    END IF;

    attrs := data->'attributes';
    IF (attrs IS NULL) THEN
        RAISE EXCEPTION 'reclada object must have attributes';
    END IF;

    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
    data := data - 'accessToken';

    IF (NOT(reclada_user.is_allowed(user_info, 'update', class))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'update', class;
    END IF;

    SELECT reclada_object.update(data, user_info) INTO result;
    RETURN result;

END;
$$ LANGUAGE PLPGSQL VOLATILE;

