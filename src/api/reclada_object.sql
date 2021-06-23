/*
 * Function api.reclada_object_create checks valid data and uses reclada_object.create to create one or bunch of objects with specified fields.
 * A jsonb object with the following parameters is required to create one object. An array of jsonb objects with the following parameters is required to create a bunch of objects.
 * Required parameters:
 *  class - the class of objects
 *  attrs - the attributes of objects
 *  accessToken - jwt token to authorize
 * Optional parameters:
 *  revision - object's revision. If a revision already exists, no new revision will be created. One revision is used to create a bunch of objects.
 *  branch - object's branch
 */

DROP FUNCTION IF EXISTS api.reclada_object_create(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_create(data_jsonb jsonb)
RETURNS jsonb AS $$
DECLARE
    class      jsonb;
    attrs      jsonb;
    user_info  jsonb;
    result     jsonb;
    data       jsonb;

BEGIN

    IF (jsonb_typeof(data_jsonb) != 'array') THEN
        data_jsonb := format('[%s]', data_jsonb)::jsonb;
    END IF;

    FOREACH data IN ARRAY (SELECT ARRAY(SELECT jsonb_array_elements_text(data_jsonb))) LOOP

        class := data->'class';
        IF (class IS NULL) THEN
            RAISE EXCEPTION 'The reclada object class is not specified';
        END IF;

        SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;

        IF (NOT(reclada_user.is_allowed(user_info, 'create', class))) THEN
            RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'create', class;
        END IF;

        attrs := data->'attrs';
        IF (attrs IS NULL) THEN
            RAISE EXCEPTION 'The reclada object must have attrs';
        END IF;
    END LOOP;

    SELECT reclada_object.create(data_jsonb, user_info) INTO result;

    RETURN result;

END;
$$ LANGUAGE PLPGSQL VOLATILE;


DROP FUNCTION IF EXISTS api.reclada_object_list(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_list(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class               jsonb;
    user_info           jsonb;
    result              jsonb;

BEGIN
    class := data->'class';

    IF(class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
    data := data - 'accessToken';

    IF (NOT(reclada_user.is_allowed(user_info, 'list', class))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'list', class;
    END IF;

    SELECT reclada_object.list(data) INTO result;
    RETURN result;

END;
$$ LANGUAGE PLPGSQL STABLE;


DROP FUNCTION IF EXISTS api.reclada_object_update(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_update(data jsonb)
RETURNS VOID AS $$
DECLARE
    class         jsonb;
    attrs         jsonb;
    user_info     jsonb;
    access_token  text;

BEGIN
    class := data->'class';

    IF (class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    access_token := data->>'accessToken';
    SELECT reclada_user.auth_by_token(access_token) INTO user_info;
    data := data - 'accessToken';

    IF (NOT(reclada_user.is_allowed(user_info, 'update', class))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'update', class;
    END IF;

    attrs := data->'attrs';
    IF (attrs IS NULL) THEN
        RAISE EXCEPTION 'reclada object must have attrs';
    END IF;

    PERFORM reclada_object.update(data, user_info);
END;
$$ LANGUAGE PLPGSQL VOLATILE;


DROP FUNCTION IF EXISTS api.reclada_object_delete(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_delete(data jsonb)
RETURNS VOID AS $$
DECLARE
    class         jsonb;
    attrs         jsonb;
    schema        jsonb;
    user_info     jsonb;
    access_token  text;

BEGIN
    class := data->'class';

    IF (class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    access_token := data->>'accessToken';
    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
    data := data - 'accessToken';

    IF (NOT(reclada_user.is_allowed(user_info, 'delete', class))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'delete', class;
    END IF;

    PERFORM reclada_object.delete(data, user_info);
END;
$$ LANGUAGE PLPGSQL VOLATILE;


/*
 * Function api.reclada_object_list_add adds one element or several elements to the list.
 * Input required parameter is jsonb with:
 * class - the class of the object
 * id - id of the object
 * field - the name of the field to add the value to
 * value - one scalar value or array of values
 * accessToken - jwt token to authorize
*/

DROP FUNCTION IF EXISTS api.reclada_object_list_add(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_list_add(data jsonb)
RETURNS void AS $$
DECLARE
    class          jsonb;
    obj_id         uuid;
    values_to_add  jsonb;
    json_path      text[];
    obj            jsonb;
    new_obj        jsonb;
    field_value    jsonb;
    access_token   text;

BEGIN
    class := data->'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

    obj_id := (data->>'id')::uuid;
    IF (obj_id IS NULL) THEN
        RAISE EXCEPTION 'There is no id';
    END IF;

    access_token := data->>'accessToken';

    SELECT api.reclada_object_list(format(
        '{"class": %s, "attrs": {}, "id": "%s", "accessToken": "%s"}',
        class,
        obj_id,
        access_token
        )::jsonb) -> 0 INTO obj;

    IF (obj IS NULL) THEN
        RAISE EXCEPTION 'There is no object with such id';
    END IF;

    values_to_add := data->'value';
    IF (values_to_add IS NULL OR values_to_add = 'null'::jsonb) THEN
        RAISE EXCEPTION 'The value should not be null';
    END IF;

    IF (jsonb_typeof(values_to_add) != 'array') THEN
        values_to_add := format('[%s]', values_to_add)::jsonb;
    END IF;

    field_value := data->'field';
    IF (field_value IS NULL) THEN
        RAISE EXCEPTION 'There is no field';
    END IF;
    json_path := format('{attrs, %s}', field_value);
    field_value := obj#>json_path;

    IF ((field_value = 'null'::jsonb) OR (field_value IS NULL)) THEN
        SELECT jsonb_set(obj, json_path, values_to_add) || format('{"accessToken": "%s"}', access_token)::jsonb
        INTO new_obj;
    ELSE
        SELECT jsonb_set(obj, json_path, field_value || values_to_add) || format('{"accessToken": "%s"}', access_token)::jsonb
        INTO new_obj;
    END IF;

    PERFORM api.reclada_object_update(new_obj);

END;
$$ LANGUAGE PLPGSQL VOLATILE;


/*
 * Function api.reclada_object_list_drop drops one element or several elements from the list.
 * Input required parameter is jsonb with:
 * class - the class of the object
 * id - id of the object
 * field - the name of the field to drop the value from
 * value - one scalar value or array of values
 * accessToken - jwt token to authorize
*/

DROP FUNCTION IF EXISTS api.reclada_object_list_drop(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_list_drop(data jsonb)
RETURNS void AS $$
DECLARE
    class           jsonb;
    obj_id          uuid;
    values_to_drop  jsonb;
    new_value       jsonb;
    json_path       text[];
    obj             jsonb;
    new_obj         jsonb;
    field_value     jsonb;
    access_token    text;

BEGIN
	class := data->'class';
	IF (class IS NULL) THEN
		RAISE EXCEPTION 'The reclada object class is not specified';
	END IF;

	obj_id := (data->>'id')::uuid;
	IF (obj_id IS NULL) THEN
		RAISE EXCEPTION 'The is no id';
	END IF;

	access_token := data->>'accessToken';
	SELECT api.reclada_object_list(format(
		'{"class": %s, "attrs": {}, "id": "%s", "accessToken": "%s"}',
		class,
		obj_id,
		access_token
		)::jsonb) -> 0 INTO obj;

	IF (obj IS NULL) THEN
		RAISE EXCEPTION 'The is no object with such id';
	END IF;

	values_to_drop := data->'value';
	IF (values_to_drop IS NULL OR values_to_drop = 'null'::jsonb) THEN
		RAISE EXCEPTION 'The value should not be null';
	END IF;

	IF (jsonb_typeof(values_to_drop) != 'array') THEN
		values_to_drop := format('[%s]', values_to_drop)::jsonb;
	END IF;

	field_value := data->'field';
	IF (field_value IS NULL OR field_value = 'null'::jsonb) THEN
		RAISE EXCEPTION 'There is no field';
	END IF;
	json_path := format('{attrs, %s}', field_value);
	field_value := obj#>json_path;
	IF (field_value IS NULL) THEN
		RAISE EXCEPTION 'The object does not have this field';
	END IF;

	SELECT jsonb_agg(elems)
	FROM
		jsonb_array_elements(field_value) elems
	WHERE
		elems NOT IN (
			SELECT jsonb_array_elements(values_to_drop))
	INTO new_value;

	SELECT jsonb_set(obj, json_path, coalesce(new_value, '[]'::jsonb)) || format('{"accessToken": "%s"}', access_token)::jsonb
	INTO new_obj;

	PERFORM api.reclada_object_update(new_obj);

END;
$$ LANGUAGE PLPGSQL VOLATILE;


/*
 * Function api.reclada_object_list_related returns the list of objects from the field of the specified object.
 * Required parameters:
 *  class - the class of the object
 *  id - identifier of the object
 *  field - the name of the field containing the related object references
 *  relatedClass - the class of the related objects
 *  accessToken - jwt token to authorize
 *
*/

DROP FUNCTION IF EXISTS api.reclada_object_list_related(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_list_related(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class          jsonb;
    field          jsonb;
    obj_id         uuid;
    obj            jsonb;
    res            jsonb;
    list_of_ids    jsonb;
    related_class  jsonb;
    access_token   text;

BEGIN
    class := data->'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

    obj_id := (data->>'id')::uuid;
    IF (obj_id IS NULL) THEN
        RAISE EXCEPTION 'The object id is not specified';
    END IF;

    access_token := data->>'accessToken';
    SELECT (api.reclada_object_list(format(
        '{"class": %s, "attrs": {}, "id": "%s", "accessToken": "%s"}',
        class,
        obj_id,
        access_token
        )::jsonb)) -> 0 INTO obj;

    IF (obj IS NULL) THEN
        RAISE EXCEPTION 'There is no object with such id';
    END IF;

    field := data->'field';
    IF (field IS NULL) THEN
        RAISE EXCEPTION 'The object field is not specified';
    END IF;

    list_of_ids := obj#>(format('{attrs, %s}', field)::text[]);
    IF (list_of_ids IS NULL) THEN
        RAISE EXCEPTION 'The object does not have this field';
    END IF;

    related_class := data->'relatedClass';
    IF (related_class IS NULL) THEN
        RAISE EXCEPTION 'The related class is not specified';
    END IF;

    SELECT jsonb_agg(T.related_obj)
    FROM (
        SELECT (api.reclada_object_list(format(
            '{"class": %s, "attrs": {}, "id": %s, "accessToken": "%s"}',
            related_class,
            related_ids,
            access_token
            )::jsonb)) -> 0 AS related_obj
        FROM
            jsonb_array_elements(list_of_ids) related_ids ) T
    INTO res;

    RETURN res;

END;
$$ LANGUAGE PLPGSQL VOLATILE;
