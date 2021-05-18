DROP FUNCTION IF EXISTS api.reclada_object_create(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_create(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class      jsonb;
    attrs      jsonb;
    user_info  jsonb;
    result     jsonb;

BEGIN
    class := data->'class';

    IF (class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
    data := data - 'accessToken';

    IF (NOT(reclada_user.is_allowed(user_info, 'create', class))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'create', class;
    END IF;

    attrs := data->'attrs';
    IF (attrs IS NULL) THEN
        RAISE EXCEPTION 'reclada object must have attrs';
    END IF;

    SELECT reclada_object.create(data) INTO result;
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
    schema        jsonb;
    user_info     jsonb;
    branch        uuid;
    revid         integer;
    objid         uuid;
    oldobj        jsonb;
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

    SELECT (api.reclada_object_list(format(
        '{"class": "jsonschema", "attrs": {"forClass": %s}, 'accessToken': "%s"}',
        class,
        access_token
        )::jsonb)) -> 0 INTO schema;

    IF (schema IS NULL) THEN
        RAISE EXCEPTION 'No json schema available for %', class;
    END IF;

    IF (NOT(validate_json_schema(schema->'attrs'->'schema', attrs))) THEN
        RAISE EXCEPTION 'JSON invalid: %', attrs;
    END IF;

    branch := data->'branch';

    SELECT reclada_revision.create(user_info->>'sub', branch) INTO revid;
    objid := data->>'id';
    IF (objid IS NULL) THEN
        RAISE EXCEPTION 'Could not update object with no id';
    END IF;

    SELECT api.reclada_object_list(format(
        '{"class": %s, "attrs": {}, "id": "%s", 'accessToken': "%s"}',
        class,
        objid,
        access_token
        )::jsonb) -> 0 INTO oldobj;

    IF (oldobj IS NULL) THEN
        RAISE EXCEPTION 'Could not update object, no such id';
    END IF;

    data := oldobj || data || format(
        '{"id": "%s", "revision": %s, "isDeleted": false}',
        objid,
        revid
        )::jsonb;
    INSERT INTO reclada.object VALUES(data);
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
    branch        uuid;
    revid         integer;
    objid         uuid;
    oldobj        jsonb;
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

    branch := data->'branch';

    SELECT reclada_revision.create(user_info->>'sub', branch) INTO revid;
    objid := data->>'id';
    IF (objid IS NULL) THEN
        RAISE EXCEPTION 'Could not delete object with no id';
    END IF;

    SELECT api.reclada_object_list(format(
        '{"class": %s, "attrs": {}, "id": "%s", 'accessToken': "%s"}',
        class,
        objid,
        access_token
        )::jsonb) -> 0 INTO oldobj;

    IF (oldobj IS NULL) THEN
        RAISE EXCEPTION 'Could not delete object, no such id';
    END IF;

    data := oldobj || data || format(
        '{"id": "%s", "revision": %s, "isDeleted": true}',
        objid, revid
        )::jsonb;
    INSERT INTO reclada.object VALUES(data);

END;
$$ LANGUAGE PLPGSQL VOLATILE;


/*
 * Function api.list_add adds one element or several elements to the list.
 * Input required parameter is jsonb with:
 * class - the class of the object
 * id - id of the object
 * field - the name of the field to add the value to
 * value - one scalar value or array of values
 * accessToken - jwt token to authorize
*/

DROP FUNCTION IF EXISTS api.list_add(jsonb);
CREATE OR REPLACE FUNCTION api.list_add(data jsonb)
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
        '{"class": %s, "attrs": {}, "id": "%s", 'accessToken': "%s"}',
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
        SELECT jsonb_set(obj, json_path, values_to_add) || format('{'accessToken': "%s"}', access_token)::jsonb
        INTO new_obj;
    ELSE
        SELECT jsonb_set(obj, json_path, field_value || values_to_add) || format('{'accessToken': "%s"}', access_token)::jsonb
        INTO new_obj;
    END IF;

    PERFORM api.reclada_object_update(new_obj);

END;
$$ LANGUAGE PLPGSQL VOLATILE;


/*
 * Function api.list_drop drops one element or several elements from the list.
 * Input required parameter is jsonb with:
 * class - the class of the object
 * id - id of the object
 * field - the name of the field to drop the value from
 * value - one scalar value or array of values
 * accessToken - jwt token to authorize
*/

DROP FUNCTION IF EXISTS api.list_drop(jsonb);
CREATE OR REPLACE FUNCTION api.list_drop(data jsonb)
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
		'{"class": %s, "attrs": {}, "id": "%s", 'accessToken': "%s"}',
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

	SELECT jsonb_set(obj, json_path, coalesce(new_value, '[]'::jsonb)) || format('{'accessToken': "%s"}', access_token)::jsonb
	INTO new_obj;

	PERFORM api.reclada_object_update(new_obj);

END;
$$ LANGUAGE PLPGSQL VOLATILE;


/*
 * Function api.reclada_object_list_related returns the list of elements from the field of the specified object.
 * Required parameters:
 *  class - the class of the object
 *  id - identifier of the object
 * field - the name of the field
 * accessToken - jwt token to authorize
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
    access_token   text;

BEGIN
    class := data->'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

    obj_id := (data->>'id')::uuid;
    IF (obj_id IS NULL) THEN
        RAISE EXCEPTION 'There is no object id';
    END IF;

    access_token := data->>'accessToken';
    SELECT (api.reclada_object_list(format(
        '{"class": %s, "attrs": {}, "id": "%s", 'accessToken': "%s"}',
        class,
        obj_id,
        access_token
        )::jsonb)) -> 0 INTO obj;

    IF (obj IS NULL) THEN
        RAISE EXCEPTION 'There is no object with such id';
    END IF;

    field := data->'field';
    IF (field IS NULL) THEN
        RAISE EXCEPTION 'There is no field';
    END IF;

    res := obj#>(format('{attrs, %s}', field)::text[]);
    IF (res IS NULL) THEN
        RAISE EXCEPTION 'The object does not have this field';
    END IF;
    RETURN res;

END;
$$ LANGUAGE PLPGSQL VOLATILE;