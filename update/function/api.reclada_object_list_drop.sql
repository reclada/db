/*
 * Function api.reclada_object_list_drop checks valid data and uses reclada_object.list_drop to drop one element or several elements from the object.
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  class - the class of the object
 *  GUID - the identifier of the object
 *  field - the name of the field to drop the value from
 *  value - one scalar value or array of values
 *  accessToken - jwt token to authorize
 *
*/

DROP FUNCTION IF EXISTS api.reclada_object_list_drop;
CREATE OR REPLACE FUNCTION api.reclada_object_list_drop(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class           text;
    obj_id          uuid;
    user_info       jsonb;
    field_value     jsonb;
    values_to_drop  jsonb;
    result          jsonb;

BEGIN

	class := data->>'class';
	IF (class IS NULL) THEN
		RAISE EXCEPTION 'The reclada object class is not specified';
	END IF;

	obj_id := (data->>'GUID')::uuid;
	IF (obj_id IS NULL) THEN
		RAISE EXCEPTION 'The is no GUID';
	END IF;

	field_value := data->'field';
	IF (field_value IS NULL OR field_value = 'null'::jsonb) THEN
		RAISE EXCEPTION 'There is no field';
	END IF;

	values_to_drop := data->'value';
	IF (values_to_drop IS NULL OR values_to_drop = 'null'::jsonb) THEN
		RAISE EXCEPTION 'The value should not be null';
	END IF;

    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
    data := data - 'accessToken';

    IF (NOT(reclada_user.is_allowed(user_info, 'list_add', class))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'list_add', class;
    END IF;

    SELECT reclada_object.list_drop(data) INTO result;
    RETURN result;

END;
$$ LANGUAGE PLPGSQL VOLATILE;

