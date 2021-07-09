/*
 * Function api.reclada_object_create checks valid data and uses reclada_object.create to create one or bunch of objects with specified fields.
 * A jsonb object with the following parameters is required to create one object.
 * An array of jsonb objects with the following parameters is required to create a bunch of objects.
 * Required parameters:
 *  class - the class of objects
 *  attrs - the attributes of objects
 *  accessToken - jwt token to authorize
 * Optional parameters:
 *  revision - object's revision. If a revision already exists, new revision will not be created. One revision is used to create a bunch of objects.
 *  branch - object's branch
 */

DROP FUNCTION IF EXISTS api.reclada_object_create(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_create(data_jsonb jsonb)
RETURNS jsonb AS $$
DECLARE
    data             jsonb;
    class            jsonb;
    user_info        jsonb;
    attrs            jsonb;
    data_to_create   jsonb = '[]'::jsonb;
    result           jsonb;

BEGIN

    IF (jsonb_typeof(data_jsonb) != 'array') THEN
        data_jsonb := '[]'::jsonb || data_jsonb;
    END IF;

    FOR data IN SELECT jsonb_array_elements(data_jsonb) LOOP

        class := data->'class';
        IF (class IS NULL) THEN
            RAISE EXCEPTION 'The reclada object class is not specified';
        END IF;

        SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
        data := data - 'accessToken';

        IF (NOT(reclada_user.is_allowed(user_info, 'create', class))) THEN
            RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'create', class;
        END IF;

        attrs := data->'attrs';
        IF (attrs IS NULL) THEN
            RAISE EXCEPTION 'The reclada object must have attrs';
        END IF;

        data_to_create := data_to_create || data;
    END LOOP;

    SELECT reclada_object.create(data_to_create, user_info) INTO result;
    RETURN result;

END;
$$ LANGUAGE PLPGSQL VOLATILE;


/*
 * Function api.reclada_object_list checks valid data and uses reclada_object.list to return the list of objects with specified fields.
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  class - the class of objects
 *  accessToken - jwt token to authorize
 * Optional parameters:
 *  attrs - the attributes of objects (can be empty)
 *  id - identifier of the objects. All ids are taken by default.
 *  revision - object's revision. returns object with max revision by default.
 *  orderBy - list of jsons in the form of {"field": "field_name", "order": <"ASC"/"DESC">}.
 *      field - required value with name of property to order by
 *      order - optional value of the order; default is "ASC". Sorted by id in ascending order by default
 *  limit - the number or string "ALL", no more than this many objects will be returned. Default limit value is "ALL".
 *  offset - the number to skip this many objects before beginning to return objects. Default offset value is 0.
 * It is possible to pass a certain operator and object for each field. Also it is possible to pass several conditions for one field.
 * Function reclada_object.list uses auxiliary functions get_query_condition, cast_jsonb_to_postgres, jsonb_to_text, get_condition_array.
 * Examples:
 *   1. Input:
 *   {
 *   "class": "class_name",
 *   "id": "id_1",
 *   "revision": {"operator": "!=", "object": 123},
 *   "isDeleted": false,
 *   "attrs":
 *      {
 *       "name": {"operator": "LIKE", "object": "%test%"}
 *       },
 *   "accessToken":".."
 *   }::jsonb
 *   2. Input:
 *   {
 *   "class": "class_name",
 *   "revision": [{"operator": ">", "object": num1}, {"operator": "<", "object": num2}],
 *   "id": {"operator": "inList", "object": ["id_1", "id_2", "id_3"]},
 *   "attrs":
 *       {
 *       "tags":{"operator": "@>", "object": ["value1", "value2"]},
 *       },
 *   "orderBy": [{"field": "revision", "order": "DESC"}],
 *   "limit": 5,
 *   "offset": 2,
 *   "accessToken":"..."
 *   }::jsonb
 *
*/

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


/*
 * Function api.reclada_object_update checks valid data and uses reclada_object.update to update object with new revision.
 * A jsonb with the following parameters is required.
 * Required parameters:
 *  class - the class of object
 *  id - identifier of the object
 *  attrs - the attributes of object
 *  accessToken - jwt token to authorize
 * Optional parameters:
 *  branch - object's branch
 *
*/

DROP FUNCTION IF EXISTS api.reclada_object_update(jsonb);
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

    attrs := data->'attrs';
    IF (attrs IS NULL) THEN
        RAISE EXCEPTION 'reclada object must have attrs';
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
    objid         uuid;
    user_info     jsonb;
    result        jsonb;

BEGIN

    class := data->'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    objid := data->>'id';
    IF (objid IS NULL) THEN
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
    data := data - 'accessToken';

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
        SELECT jsonb_set(obj, json_path, values_to_add)
        INTO new_obj;
    ELSE
        SELECT jsonb_set(obj, json_path, field_value || values_to_add)
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
	data := data - 'accessToken';

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

	SELECT jsonb_set(obj, json_path, coalesce(new_value, '[]'::jsonb))
	INTO new_obj;

	PERFORM api.reclada_object_update(new_obj);

END;
$$ LANGUAGE PLPGSQL VOLATILE;


/*
 * Function api.reclada_object_list_related checks valid data and uses reclada_object.list_related to return the list of objects from the field of the specified object.
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  class - the class of the object
 *  id - identifier of the object
 *  field - the name of the field containing the related object references
 *  relatedClass - the class of the related objects
 *  accessToken - jwt token to authorize
 * Optional parameters:
 *  orderBy - list of jsons in the form of {"field": "field_name", "order": <"ASC"/"DESC">}.
 *      field - required value with name of property to order by
 *      order - optional value of the order; default is "ASC". Sorted by id in ascending order by default
 *  limit - the number or string "ALL", no more than this many objects will be returned. Default limit value is "ALL".
 *  offset - the number to skip this many objects before beginning to return objects. Default offset value is 0.
 *
*/

DROP FUNCTION IF EXISTS api.reclada_object_list_related(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_list_related(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class          jsonb;
    obj_id         uuid;
    field          jsonb;
    related_class  jsonb;
    user_info      jsonb;
    result         jsonb;

BEGIN
    class := data->'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

    obj_id := (data->>'id')::uuid;
    IF (obj_id IS NULL) THEN
        RAISE EXCEPTION 'The object id is not specified';
    END IF;

    field := data->'field';
    IF (field IS NULL) THEN
        RAISE EXCEPTION 'The object field is not specified';
    END IF;

    related_class := data->'relatedClass';
    IF (related_class IS NULL) THEN
        RAISE EXCEPTION 'The related class is not specified';
    END IF;

    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
    data := data - 'accessToken';

    IF (NOT(reclada_user.is_allowed(user_info, 'list_related', class))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'list_related', class;
    END IF;

    SELECT reclada_object.list_related(data) INTO result;
    RETURN result;

END;
$$ LANGUAGE PLPGSQL VOLATILE;
