/* Just for demo */
DROP FUNCTION IF EXISTS api.hello_world(jsonb);
CREATE OR REPLACE FUNCTION api.hello_world(data jsonb)
RETURNS text AS $$
SELECT 'Hello, world!';
$$ LANGUAGE SQL IMMUTABLE;

DROP FUNCTION IF EXISTS api.hello_world(text);
CREATE OR REPLACE FUNCTION api.hello_world(data text)
RETURNS text AS $$
SELECT 'Hello, world!';
$$ LANGUAGE SQL IMMUTABLE;

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

        attrs := data_jsonb->'attrs';
        IF (attrs IS NULL) THEN
            RAISE EXCEPTION 'The reclada object must have attrs';
        END IF;

        data_to_create := data_to_create || data_jsonb;
    END LOOP;

    SELECT reclada_object.create(data_to_create, user_info) INTO result;
    RETURN result;

END;
$$ LANGUAGE PLPGSQL VOLATILE;


/*
 * Function api.reclada_object_list checks valid data and uses reclada_object.list to return the list of objects with specified fields and the number of these objects.
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
 * Output is jsonb like this {"objects": [<list of objects>], "number": <number of objects> }
 * Function supports:
 * 1. Comparison Operators
 * elem1   >, <, <=, >=, =, !=   elem2
 * elem1 < x < elem2 -- like two conditions
 * 2. Pattern Matching
 * str1   LIKE / NOT LIKE   str2
 * str   SIMILAR TO   exp
 * str   ~ ~* !~ !~*   exp
 * 3. Array Operators
 * elem   <@   list
 * list1   =, !=, <, >, <=, >=, @>, <@  list2
 * Examples:
 *   1. Input:
 *   {
 *   "class": "class_name",
 *   "id": "id_1",
 *   "attrs":
 *       {
 *       "name": {"operator": "LIKE", "object": "%test%"},
 *       "numericField": {"operator": "!=", "object": 123}
 *       },
 *   "orderBy": [{"field": "attrs, name", "order": "ASC"}],
 *   "accessToken":"..."
 *   }::jsonb
 *   2. Input:
 *   {
 *   "class": "class_name",
 *   "id": {"operator": "<@", "object": ["id_1", "id_2", "id_3"]},
 *   "attrs":
 *       {
 *       "tags":{"operator": "@>", "object": ["value1", "value2"]},
 *       "numericField": [{"operator": ">", "object": num1}, {"operator": "<", "object": num2}]
 *       },
 *   "orderBy": [{"field": "id", "order": "DESC"}],
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
    objects             jsonb;
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

    SELECT reclada_object.list(data, true) INTO result;

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


/*
 * Function api.reclada_object_list_drop checks valid data and uses reclada_object.list_drop to drop one element or several elements from the object.
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  class - the class of the object
 *  id - id of the object
 *  field - the name of the field to drop the value from
 *  value - one scalar value or array of values
 *  accessToken - jwt token to authorize
 *
*/

DROP FUNCTION IF EXISTS api.reclada_object_list_drop(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_list_drop(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class           jsonb;
    obj_id          uuid;
    user_info       jsonb;
    field_value     jsonb;
    values_to_drop  jsonb;
    result          jsonb;

BEGIN

	class := data->'class';
	IF (class IS NULL) THEN
		RAISE EXCEPTION 'The reclada object class is not specified';
	END IF;

	obj_id := (data->>'id')::uuid;
	IF (obj_id IS NULL) THEN
		RAISE EXCEPTION 'The is no id';
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
$$ LANGUAGE PLPGSQL STABLE;
