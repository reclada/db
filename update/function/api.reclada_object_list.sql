/*
 * Function api.reclada_object_list checks valid data and uses reclada_object.list to return the list of objects with specified fields and the number of these objects.
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  class - the class of objects
 *  accessToken - jwt token to authorize
 * Optional parameters:
 *  attributes - the attributes of objects (can be empty)
 *  GUID - the identifier of the object. All object's GUID of the class are taken by default.
 *  transactionID - object's transaction number
 *  orderBy - list of jsons in the form of {"field": "field_name", "order": <"ASC"/"DESC">}.
 *      field - required value with name of property to order by
 *      order - optional value of the order; default is "ASC". Sorted by id in ascending order by default
 *  limit - the number or string "ALL", no more than this many objects will be returned. Default limit value is 500.
 *  offset - the number to skip this many objects before beginning to return objects. Default offset value is 0.
 * It is possible to pass a certain operator and object for each field. Also it is possible to pass several conditions for one field.
 * Output is jsonb like this {"objects": [<list of objects>], "number": <number of objects>, "last_change": <greatest timestamp of selection>}.
 * Function supports:
 * 1. Comparison Operators
 * elem1   >, <, <=, >=, =, !=   elem2
 * elem1 < x < elem2 -- like two conditions
 * 2. Pattern Matching
 * str1   LIKE / NOT LIKE    str2
 * str    SIMILAR TO         exp
 * str    ~ ~* !~ !~*        exp
 * 3. Array Operators
 * elem   <@   list
 * list1   =, !=, <, >, <=, >=, @>, <@  list2
 * Examples:
 *   1. Input:
 *   {
 *   "class": "class_name",
 *   "GUID": "id_1",
 *   "attributes":
 *       {
 *       "name": {"operator": "LIKE", "object": "%test%"},
 *       "numericField": {"operator": "!=", "object": 123}
 *       },
 *   "orderBy": [{"field": "attributes, name", "order": "ASC"}],
 *   "accessToken":"..."
 *   }::jsonb
 *   2. Input:
 *   {
 *   "class": "class_name",
 *   "GUID": {"operator": "<@", "object": ["id_1", "id_2", "id_3"]},
 *   "attributes":
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

DROP FUNCTION IF EXISTS api.reclada_object_list;
CREATE OR REPLACE FUNCTION api.reclada_object_list(
    data jsonb default null, 
    ver text default '1', 
    draft text default 'false'
    )
RETURNS jsonb AS $$
DECLARE
    class               text;
    user_info           jsonb;
    result              jsonb;
    _filter             jsonb;
BEGIN

    if draft != 'false' then
        return array_to_json
            (
                array
                (
                    SELECT o.data 
                        FROM reclada.draft o
                            where id = 
                                (
                                    select max(id) 
                                        FROM reclada.draft d
                                            where o.guid = d.guid
                                )
                            -- and o.user = user_info->>'guid'
                )
            )::jsonb;
    end if;

    class := CASE ver
                when '1'
                    then data->>'class'
                when '2'
                    then data->>'{class}'
            end;
    IF(class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    _filter = data->'filter';
    IF _filter IS NOT NULL THEN
        SELECT format(  '{
                            "filter":
                            {
                                "operator":"AND",
                                "value":[
                                    {
                                        "operator":"=",
                                        "value":["{class}","%s"]
                                    },
                                    %s
                                ]
                            }
                        }',
                class,
                _filter
            )::jsonb 
            INTO _filter;
        data := data || _filter;
    ELSE
        data := data || ('{"class":"'|| class ||'"}')::jsonb;
    --     select format(  '{
    --                         "filter":{
    --                             "operator":"=",
    --                             "value":["{class}","%s"]
    --                         }
    --                     }',
    --             class,
    --             _filter
    --         )::jsonb 
    --         INTO _filter;
    END IF;

    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
    data := data - 'accessToken';

    IF (NOT(reclada_user.is_allowed(user_info, 'list', class))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'list', class;
    END IF;

    SELECT reclada_object.list(data, true) 
        INTO result;
    RETURN result;

END;
$$ LANGUAGE PLPGSQL VOLATILE;