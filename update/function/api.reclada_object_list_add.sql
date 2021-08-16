

/*
 * Function api.reclada_object_list_add checks valid data and uses reclada_object.list_add to add one element or several elements to the object.
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  class - the class of the object
 *  id - id of the object
 *  field - the name of the field to add the value to
 *  value - one scalar value or array of values
 *  accessToken - jwt token to authorize
 *
*/

DROP FUNCTION IF EXISTS api.reclada_object_list_add(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_list_add(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class          jsonb;
    obj_id         uuid;
    user_info      jsonb;
    field_value    jsonb;
    values_to_add  jsonb;
    result         jsonb;

BEGIN

    class := data->'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

    obj_id := (data->>'id')::uuid;
    IF (obj_id IS NULL) THEN
        RAISE EXCEPTION 'There is no id';
    END IF;

    field_value := data->'field';
    IF (field_value IS NULL) THEN
        RAISE EXCEPTION 'There is no field';
    END IF;

    values_to_add := data->'value';
    IF (values_to_add IS NULL OR values_to_add = 'null'::jsonb) THEN
        RAISE EXCEPTION 'The value should not be null';
    END IF;

    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
    data := data - 'accessToken';

    IF (NOT(reclada_user.is_allowed(user_info, 'list_add', class))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'list_add', class;
    END IF;

    SELECT reclada_object.list_add(data) INTO result;
    RETURN result;

END;
$$ LANGUAGE PLPGSQL VOLATILE;

