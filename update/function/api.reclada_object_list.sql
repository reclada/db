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

