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

    SELECT reclada_object.list(data) INTO objects;

    result := jsonb_build_object(
        'number', jsonb_array_length(objects),
        'objects', objects);
    RETURN result;

END;
$$ LANGUAGE PLPGSQL STABLE;