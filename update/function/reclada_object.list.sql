/*
 * Function reclada_object.list returns the list of objects with specified fields.
 * Also it is possible to get the number of objects. For that two arguments are required for input:
 * 1. the jsonb object with information about specified fields with the following parameters is required
 * 2. boolean argument is optional
 *    If it is true then output is jsonb like this {"objects": [<list of objects>], "number": <number of objects>}.
 *    If it is false (default value) then output is jsonb like this [<list of objects>].
 * Required parameters for the jsonb object:
 *  class - the class of objects
 * Optional parameters:
 *  attributes - the attributes of objects (can be empty)
 *  id - identifier of the objects. All ids are taken by default.
 *  revision - object's revision. returns object with max revision by default.
 *  orderBy - list of jsons in the form of {"field": "field_name", "order": <"ASC"/"DESC">}.
 *      field - required value with name of property to order by
 *      order - optional value of the order; default is "ASC". Sorted by id in ascending order by default
 *  limit - the number or string "ALL", no more than this many objects will be returned. Default limit value is 500.
 *  offset - the number to skip this many objects before beginning to return objects. Default offset value is 0.
 * It is possible to pass a certain operator and object for each field. Also it is possible to pass several conditions for one field.
 * Function reclada_object.list uses auxiliary functions get_query_condition, cast_jsonb_to_postgres, jsonb_to_text, get_condition_array.
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
 *   "attributes":
 *       {
 *       "name": {"operator": "LIKE", "object": "%test%"},
 *       "numericField": {"operator": "!=", "object": 123}
 *       },
 *   "orderBy": [{"field": "attributes, name", "order": "ASC"}],
 *   }::jsonb
 *   2. Input:
 *   {
 *   "class": "class_name",
 *   "id": {"operator": "<@", "object": ["id_1", "id_2", "id_3"]},
 *   "attributes":
 *       {
 *       "tags":{"operator": "@>", "object": ["value1", "value2"]},
 *       "numericField": [{"operator": ">", "object": num1}, {"operator": "<", "object": num2}]
 *       },
 *   "orderBy": [{"field": "id", "order": "DESC"}],
 *   "limit": 5,
 *   "offset": 2
 *   }::jsonb
 *
*/

DROP FUNCTION IF EXISTS reclada_object.list;
CREATE OR REPLACE FUNCTION reclada_object.list(data jsonb, with_number boolean default false)
RETURNS jsonb AS $$
DECLARE
    class               text;
    attrs               jsonb;
    order_by_jsonb      jsonb;
    order_by            text;
    limit_              text;
    offset_             text;
    query_conditions    text;
    number_of_objects   int;
    objects             jsonb;
    res                 jsonb;
    query               text;
    class_uuid          uuid;
BEGIN

    class := data->>'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;
    class_uuid := public.try_cast_uuid(class);

    if class_uuid is not null then
        select v.for_class 
            from reclada.v_class_lite v
                where class_uuid = v.obj_id
        into class;

        IF (class IS NULL) THEN
            RAISE EXCEPTION 'Class not found by GUID: %', class_uuid::text;
        END IF;
    end if;

    attrs := data->'attributes' || '{}'::jsonb;

    order_by_jsonb := data->'orderBy';
    IF ((order_by_jsonb IS NULL) OR
        (order_by_jsonb = 'null'::jsonb) OR
        (order_by_jsonb = '[]'::jsonb)) THEN
        order_by_jsonb := '[{"field": "id", "order": "ASC"}]'::jsonb;
    END IF;
    IF (jsonb_typeof(order_by_jsonb) != 'array') THEN
    		order_by_jsonb := format('[%s]', order_by_jsonb);
    END IF;
    SELECT string_agg(
        format(E'obj.data#>''{%s}'' %s', T.value->>'field', COALESCE(T.value->>'order', 'ASC')),
        ' , ')
    FROM jsonb_array_elements(order_by_jsonb) T
    INTO order_by;

    limit_ := data->>'limit';
    IF (limit_ IS NULL) THEN
        limit_ := 500;
    END IF;
    IF ((limit_ ~ '(\D+)') AND (limit_ != 'ALL')) THEN
    		RAISE EXCEPTION 'The limit must be an integer number or "ALL"';
    END IF;

    offset_ := data->>'offset';
    IF (offset_ IS NULL) THEN
        offset_ := 0;
    END IF;
    IF (offset_ ~ '(\D+)') THEN
    		RAISE EXCEPTION 'The offset must be an integer number';
    END IF;

    SELECT
        string_agg(
            format(
                E'(%s)',
                condition
            ),
            ' AND '
        )
        FROM (
            SELECT
                -- ((('"'||class||'"')::jsonb#>>'{}')::text = 'Job')
                --reclada_object.get_query_condition(class, E'data->''class''') AS condition
                --'class = data->>''class''' AS condition
                -- TODO: replace for using GUID
                format('obj.class_name = ''%s''', class) AS condition
            UNION
            SELECT  CASE
                        WHEN jsonb_typeof(data->'id') = 'array' THEN
                        (
                            SELECT string_agg
                                (
                                    format(
                                        E'(%s)',
                                        reclada_object.get_query_condition(cond, E'data->''id''')
                                    ),
                                    ' AND '
                                )
                                FROM jsonb_array_elements(data->'id') AS cond
                        )
                        ELSE reclada_object.get_query_condition(data->'id', E'data->''id''')
                    END AS condition
                WHERE coalesce(data->'id','null'::jsonb) != 'null'::jsonb
            -- UNION
            -- SELECT 'obj.data->>''status''=''active'''-- TODO: change working with revision
            -- UNION SELECT
            --     CASE WHEN data->'revision' IS NULL THEN
            --         E'(data->>''revision''):: numeric = (SELECT max((objrev.data -> ''revision'')::numeric)
            --         FROM reclada.v_object objrev WHERE
            --         objrev.data -> ''id'' = obj.data -> ''id'')'
            --     WHEN jsonb_typeof(data->'revision') = 'array' THEN
            --         (SELECT string_agg(
            --             format(
            --                 E'(%s)',
            --                 reclada_object.get_query_condition(cond, E'data->''revision''')
            --             ),
            --             ' AND '
            --         )
            --         FROM jsonb_array_elements(data->'revision') AS cond)
            --     ELSE reclada_object.get_query_condition(data->'revision', E'data->''revision''') END AS condition
            UNION
            SELECT
                CASE
                    WHEN jsonb_typeof(value) = 'array'
                        THEN
                            (
                                SELECT string_agg
                                    (
                                        format
                                        (
                                            E'(%s)',
                                            reclada_object.get_query_condition(cond, format(E'attrs->%L', key))
                                        ),
                                        ' AND '
                                    )
                                    FROM jsonb_array_elements(value) AS cond
                            )
                    ELSE reclada_object.get_query_condition(value, format(E'attrs->%L', key))
                END AS condition
            FROM jsonb_each(attrs)
            WHERE attrs != ('{}'::jsonb)
        ) conds
    INTO query_conditions;

    -- RAISE NOTICE 'conds: %', '
    --             SELECT obj.data
    --             FROM reclada.v_object obj
    --             WHERE ' || query_conditions ||
    --             ' ORDER BY ' || order_by ||
    --             ' OFFSET ' || offset_ || ' LIMIT ' || limit_ ;
    query := 'FROM reclada.v_active_object obj WHERE ' || query_conditions;
    raise notice 'query: %', query;
    EXECUTE E'SELECT to_jsonb(array_agg(T.data))
        FROM (
            SELECT obj.data
            '
            || query
            ||
            ' ORDER BY ' || order_by ||
            ' OFFSET ' || offset_ || ' LIMIT ' || limit_ || ') T'
    INTO objects;
    IF with_number THEN

        EXECUTE E'SELECT count(1)
        '|| query
        INTO number_of_objects;

        res := jsonb_build_object(
        'number', number_of_objects,
        'objects', objects);
    ELSE
        res := objects;
    END IF;

    RETURN res;

END;
$$ LANGUAGE PLPGSQL STABLE;