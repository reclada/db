/*
 * Function reclada_object.create creates one or bunch of objects with specified fields.
 * A jsonb with user_info and a jsonb or an array of jsonb objects are required.
 * A jsonb object with the following parameters is required to create one object.
 * An array of jsonb objects with the following parameters is required to create a bunch of objects.
 * Required parameters:
 *  class - the class of objects
 *  attrs - the attributes of objects
 * Optional parameters:
 *  revision - object's revision. If a revision already exists, new revision will not be created. One revision is used to create a bunch of objects.
 *  branch - object's branch
 */

DROP FUNCTION IF EXISTS reclada_object.create(jsonb, jsonb);
CREATE OR REPLACE FUNCTION reclada_object.create(data_jsonb jsonb, user_info jsonb default '{}'::jsonb)
RETURNS jsonb AS $$
DECLARE
    branch     uuid;
    revid      integer;
    data       jsonb;
    class      jsonb;
    attrs      jsonb;
    schema     jsonb;
    objid      uuid;
    res        jsonb[];

BEGIN

    IF (jsonb_typeof(data_jsonb) != 'array') THEN
        data_jsonb := '[]'::jsonb || data_jsonb;
    END IF;
    /*TODO: check if some objects have revision and others do not */
    branch:= data_jsonb->0->'branch';

    IF (data_jsonb->0->'revision' IS NULL) THEN
        SELECT reclada_revision.create(user_info->>'sub', branch) INTO revid;
    END IF;

    FOR data IN SELECT jsonb_array_elements(data_jsonb) LOOP

        class := data->'class';

        IF (class IS NULL) THEN
            RAISE EXCEPTION 'The reclada object class is not specified';
        END IF;

        attrs := data->'attrs';
        IF (attrs IS NULL) THEN
            RAISE EXCEPTION 'The reclada object must have attrs';
        END IF;

        SELECT reclada_object.get_schema(class) INTO schema;

        IF (schema IS NULL) THEN
            RAISE EXCEPTION 'No json schema available for %', class;
        END IF;

        IF (NOT(validate_json_schema(schema->'attrs'->'schema', attrs))) THEN
            RAISE EXCEPTION 'JSON invalid: %', attrs;
        END IF;

        SELECT uuid_generate_v4() INTO objid;

        IF (data->'revision' IS NULL) THEN
            data := data || format(
                '{"id": "%s", "revision": %s, "isDeleted": false}',
                objid, revid
            )::jsonb;
        ELSE
            data := data || format(
                '{"id": "%s", "isDeleted": false}',
                objid
            )::jsonb;
        END IF;

        res := res || data;

    END LOOP;

    INSERT INTO reclada.object SELECT * FROM unnest(res);
    PERFORM reclada_notification.send_object_notification('create', array_to_json(res)::jsonb);
    RETURN array_to_json(res)::jsonb;

END;
$$ LANGUAGE PLPGSQL VOLATILE;


/*
 * Function reclada_object.create_subclass creates subclass.
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  class - the name of class to create
 *  attrs - the attributes of objects of the class
 */

DROP FUNCTION IF EXISTS reclada_object.create_subclass(jsonb);
CREATE OR REPLACE FUNCTION reclada_object.create_subclass(data jsonb)
RETURNS VOID AS $$
DECLARE
    class           jsonb;
    attrs           jsonb;
    class_schema    jsonb;

BEGIN

    class := data->'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

    attrs := data->'attrs';
    IF (attrs IS NULL) THEN
        RAISE EXCEPTION 'The reclada object must have attrs';
    END IF;

    SELECT reclada_object.get_schema(class) INTO class_schema;

    IF (class_schema IS NULL) THEN
        RAISE EXCEPTION 'No json schema available for %', class;
    END IF;

    class_schema := class_schema -> 'attrs' -> 'schema';

    PERFORM reclada_object.create(format('{
        "class": "jsonschema",
        "attrs": {
            "forClass": %s,
            "schema": {
                "type": "object",
                "properties": %s,
                "required": %s
            }
        }
    }',
    attrs -> 'newClass',
    (class_schema -> 'properties') || (attrs -> 'properties'),
    (SELECT jsonb_agg(el) FROM (SELECT DISTINCT pg_catalog.jsonb_array_elements((class_schema -> 'required') || (attrs -> 'required')) el) arr)
    )::jsonb);

END;
$$ LANGUAGE PLPGSQL VOLATILE;



/*
 * Function reclada_object.list returns the list of objects with specified fields.
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  class - the class of objects
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
 *       {
 *       "name": {"operator": "LIKE", "object": "%test%"}
 *       }
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
 *   "offset": 2
 *   }::jsonb
 *
*/

DROP FUNCTION IF EXISTS reclada_object.list(jsonb);
CREATE OR REPLACE FUNCTION reclada_object.list(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class               jsonb;
    attrs               jsonb;
    query_conditions    text;
    res                 jsonb;
    order_by_jsonb      jsonb;
    order_by            text;
    limit_              text;
    offset_             text;

BEGIN
    class := data->'class';

    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

    attrs := data->'attrs' || '{}'::jsonb;

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
        format(E'obj.data->\'%s\' %s', T.value->>'field', COALESCE(T.value->>'order', 'ASC')),
        ' , ')
    FROM jsonb_array_elements(order_by_jsonb) T
    INTO order_by;

    limit_ := data->>'limit';
    IF (limit_ IS NULL) THEN
        limit_ := 'ALL';
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
                reclada_object.get_query_condition(class, E'data->\'class\'') AS condition
            UNION SELECT
                CASE WHEN jsonb_typeof(data->'id') = 'array' THEN
                    (SELECT string_agg(
                        format(
                            E'(%s)',
                            reclada_object.get_query_condition(cond, E'data->\'id\'')
                        ),
                        ' AND '
                    )
                    FROM jsonb_array_elements(data->'id') AS cond)
                ELSE reclada_object.get_query_condition(data->'id', E'data->\'id\'') END AS condition
            WHERE data->'id' IS NOT NULL
            UNION SELECT
                CASE WHEN data->'revision' IS NULL THEN
                    E'(data->>\'revision\'):: numeric = (SELECT max((objrev.data -> \'revision\')::numeric)
                    FROM reclada.object objrev WHERE
                    objrev.data -> \'id\' = obj.data -> \'id\')'
                WHEN jsonb_typeof(data->'revision') = 'array' THEN
                    (SELECT string_agg(
                        format(
                            E'(%s)',
                            reclada_object.get_query_condition(cond, E'data->\'revision\'')
                        ),
                        ' AND '
                    )
                    FROM jsonb_array_elements(data->'revision') AS cond)
                ELSE reclada_object.get_query_condition(data->'revision', E'data->\'revision\'') END AS condition
            UNION SELECT
                CASE WHEN jsonb_typeof(value) = 'array' THEN
                    (SELECT string_agg(
                        format(
                            E'(%s)',
                            reclada_object.get_query_condition(cond, format(E'data->\'attrs\'->%L', key))
                        ),
                        ' AND '
                    )
                    FROM jsonb_array_elements(value) AS cond)
                ELSE reclada_object.get_query_condition(value, format(E'data->\'attrs\'->%L', key)) END AS condition
           FROM jsonb_each(attrs)
           WHERE data->'attrs' != ('{}'::jsonb)
        ) conds
    INTO query_conditions;

   /* RAISE NOTICE 'conds: %', query_conditions; */
   EXECUTE E'SELECT to_jsonb(array_agg(T.data))
   FROM (
        SELECT obj.data
        FROM reclada.object obj
        WHERE ' || query_conditions ||
        ' ORDER BY ' || order_by ||
        ' OFFSET ' || offset_ || ' LIMIT ' || limit_ || ') T'
   INTO res;
   RETURN res;

END;
$$ LANGUAGE PLPGSQL STABLE;


/*
 * Function reclada_object.update updates object with new revision.
 * A jsonb with the following parameters is required.
 * Required parameters:
 *  class - the class of object
 *  id - identifier of the object
 *  attrs - the attributes of object
 * Optional parameters:
 *  branch - object's branch
 *
*/

DROP FUNCTION IF EXISTS reclada_object.update(jsonb, jsonb);
CREATE OR REPLACE FUNCTION reclada_object.update(data jsonb, user_info jsonb default '{}'::jsonb)
RETURNS jsonb
LANGUAGE PLPGSQL VOLATILE
AS $body$
DECLARE
    class         jsonb;
    objid         uuid;
    attrs         jsonb;
    schema        jsonb;
    oldobj        jsonb;
    branch        uuid;
    revid         integer;

BEGIN

    class := data->'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

    objid := data->>'id';
    IF (objid IS NULL) THEN
        RAISE EXCEPTION 'Could not update object with no id';
    END IF;

    attrs := data->'attrs';
    IF (attrs IS NULL) THEN
        RAISE EXCEPTION 'The reclada object must have attrs';
    END IF;

    SELECT reclada_object.get_schema(class) INTO schema;

    IF (schema IS NULL) THEN
        RAISE EXCEPTION 'No json schema available for %', class;
    END IF;

    IF (NOT(validate_json_schema(schema->'attrs'->'schema', attrs))) THEN
        RAISE EXCEPTION 'JSON invalid: %', attrs;
    END IF;

    SELECT reclada_object.list(format(
        '{"class": %s, "id": "%s"}',
        class,
        objid
        )::jsonb) -> 0 INTO oldobj;

    IF (oldobj IS NULL) THEN
        RAISE EXCEPTION 'Could not update object, no such id';
    END IF;

    branch := data->'branch';
    SELECT reclada_revision.create(user_info->>'sub', branch) INTO revid;

    data := data || format(
        '{"revision": %s, "isDeleted": false}',
        revid
        )::jsonb; --TODO replace isDeleted with status attr
    --TODO compare old and data to avoid unnecessery inserts

    INSERT INTO reclada.object VALUES(data);
    PERFORM reclada_notification.send_object_notification('update', data);
    RETURN data;

END;
$body$;


/*
 * Function reclada_object.delete to updates object with field "isDeleted": true.
 * A jsonb with the following parameters is required.
 * Required parameters:
 *  class - the class of object
 *  id - identifier of the object
 * Optional parameters:
 *  attrs - the attributes of object
 *  branch - object's branch
 *
*/

DROP FUNCTION IF EXISTS reclada_object.delete(jsonb, jsonb);
CREATE OR REPLACE FUNCTION reclada_object.delete(data jsonb, user_info jsonb default '{}'::jsonb)
RETURNS jsonb
LANGUAGE PLPGSQL VOLATILE
AS $$
DECLARE
    class         jsonb;
    objid         uuid;
    oldobj        jsonb;
    branch        uuid;
    revid         integer;

BEGIN

    class := data->'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

    objid := data->>'id';
    IF (objid IS NULL) THEN
        RAISE EXCEPTION 'Could not delete object with no id';
    END IF;

    SELECT reclada_object.list(format(
        '{"class": %s, "id": "%s"}',
        class,
        objid
        )::jsonb) -> 0 INTO oldobj;

    IF (oldobj IS NULL) THEN
        RAISE EXCEPTION 'Could not delete object, no such id';
    END IF;

    branch := data->'branch';

    SELECT reclada_revision.create(user_info->>'sub', branch) INTO revid;
    data := oldobj || format(
            '{"revision": %s, "isDeleted": true}',
            revid
        )::jsonb;

    INSERT INTO reclada.object VALUES(data);

    PERFORM reclada_notification.send_object_notification('delete', data);

    RETURN data;

END;
$$;


/*
 * Function reclada_object.list_add adds one element or several elements to the object.
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  class - the class of the object
 *  id - id of the object
 *  field - the name of the field to add the value to
 *  value - one scalar value or array of values
 *
*/

DROP FUNCTION IF EXISTS reclada_object.list_add(jsonb);
CREATE OR REPLACE FUNCTION reclada_object.list_add(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class          jsonb;
    obj_id         uuid;
    obj            jsonb;
    values_to_add  jsonb;
    field_value    jsonb;
    json_path      text[];
    new_obj        jsonb;
    res            jsonb;

BEGIN

    class := data->'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

    obj_id := (data->>'id')::uuid;
    IF (obj_id IS NULL) THEN
        RAISE EXCEPTION 'There is no id';
    END IF;

    SELECT reclada_object.list(format(
        '{"class": %s, "attrs": {}, "id": "%s"}',
        class,
        obj_id
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

    SELECT reclada_object.update(new_obj) INTO res;
    RETURN res;

END;
$$ LANGUAGE PLPGSQL VOLATILE;



/*
 * Function reclada_object.list_drop drops one element or several elements from the object.
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  class - the class of the object
 *  id - id of the object
 *  field - the name of the field to drop the value from
 *  value - one scalar value or array of values
 *
*/

DROP FUNCTION IF EXISTS reclada_object.list_drop(jsonb);
CREATE OR REPLACE FUNCTION reclada_object.list_drop(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class           jsonb;
    obj_id          uuid;
    obj             jsonb;
    values_to_drop  jsonb;
    field_value     jsonb;
    json_path       text[];
    new_value       jsonb;
    new_obj         jsonb;
    res             jsonb;

BEGIN

	class := data->'class';
	IF (class IS NULL) THEN
		RAISE EXCEPTION 'The reclada object class is not specified';
	END IF;

	obj_id := (data->>'id')::uuid;
	IF (obj_id IS NULL) THEN
		RAISE EXCEPTION 'The is no id';
	END IF;

    SELECT reclada_object.list(format(
        '{"class": %s, "attrs": {}, "id": "%s"}',
        class,
        obj_id
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

	SELECT reclada_object.update(new_obj) INTO res;
	RETURN res;

END;
$$ LANGUAGE PLPGSQL VOLATILE;


/*
 * Function reclada_object.list_related returns the list of objects from the field of the specified object.
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  class - the class of the object
 *  id - identifier of the object
 *  field - the name of the field containing the related object references
 *  relatedClass - the class of the related objects
 * Optional parameters:
 *  orderBy - list of jsons in the form of {"field": "field_name", "order": <"ASC"/"DESC">}.
 *      field - required value with name of property to order by
 *      order - optional value of the order; default is "ASC". Sorted by id in ascending order by default
 *  limit - the number or string "ALL", no more than this many objects will be returned. Default limit value is "ALL".
 *  offset - the number to skip this many objects before beginning to return objects. Default offset value is 0.
 *
*/

DROP FUNCTION IF EXISTS reclada_object.list_related(jsonb);
CREATE OR REPLACE FUNCTION reclada_object.list_related(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class          jsonb;
    obj_id         uuid;
    field          jsonb;
    related_class  jsonb;
    obj            jsonb;
    list_of_ids    jsonb;
    cond           jsonb = '{}'::jsonb;
    order_by       jsonb;
    limit_         jsonb;
    offset_        jsonb;
    res            jsonb;

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

    SELECT (reclada_object.list(format(
        '{"class": %s, "attrs": {}, "id": "%s"}',
        class,
        obj_id
        )::jsonb)) -> 0 INTO obj;

    IF (obj IS NULL) THEN
        RAISE EXCEPTION 'There is no object with such id';
    END IF;

    list_of_ids := obj#>(format('{attrs, %s}', field)::text[]);
    IF (list_of_ids IS NULL) THEN
        RAISE EXCEPTION 'The object does not have this field';
    END IF;

    order_by := data->'orderBy';
    IF (order_by IS NOT NULL) THEN
        cond := cond || (format('{"orderBy": %s}', order_by)::jsonb);
    END IF;

    limit_ := data->'limit';
    IF (limit_ IS NOT NULL) THEN
        cond := cond || (format('{"limit": %s}', limit_)::jsonb);
    END IF;

    offset_ := data->'offset';
    IF (offset_ IS NOT NULL) THEN
        cond := cond || (format('{"offset": %s}', offset_)::jsonb);
    END IF;

    SELECT reclada_object.list(format(
        '{"class": %s, "attrs": {}, "id": {"operator": "<@", "object": %s}}',
        related_class,
        list_of_ids
        )::jsonb || cond)
    INTO res;

    RETURN res;

END;
$$ LANGUAGE PLPGSQL VOLATILE;


/*
 * Auxiliary function cast_jsonb_to_postgres generates a string to get the jsonb field with a cast to postgres primitive types.
 * Required parameters:
 *  key_path - the path to jsonb object field
 *  type - a primitive json type
 * Optional parameters:
 *  type_of_array - the type to which it needed to cast elements of array. It is used just for type = array. By default, type_of_array = text.
 * Examples:
 * 1. Input: key_path = data->'revision', type = number
 *    Output: (data->'revision')::numeric
 * 2. Input: key_path = data->'attrs'->'tags', type = array, type_of_array = string
 *    Output: (ARRAY(SELECT jsonb_array_elements_text(data->'attrs'->'tags')::text)
 * Only valid input is expected.
*/

DROP FUNCTION IF EXISTS reclada_object.cast_jsonb_to_postgres(text, text, text);
CREATE OR REPLACE FUNCTION reclada_object.cast_jsonb_to_postgres(key_path text, type text, type_of_array text default 'text')
RETURNS text AS $$
SELECT
        CASE
            WHEN type = 'string' THEN
                format(E'(%s#>>\'{}\')::text', key_path)
            WHEN type = 'number' THEN
                format(E'(%s)::numeric', key_path)
            WHEN type = 'boolean' THEN
                format(E'(%s)::boolean', key_path)
            WHEN type = 'array' THEN
                format(
                    E'ARRAY(SELECT jsonb_array_elements_text(%s)::%s)',
                    key_path,
                     CASE
                        WHEN type_of_array = 'string' THEN 'text'
                        WHEN type_of_array = 'number' THEN 'numeric'
                        WHEN type_of_array = 'boolean' THEN 'boolean'
                     END
                    )
        END
$$ LANGUAGE SQL IMMUTABLE;


/*
 * Auxiliary function jsonb_to_text converts a jsonb field to string.
 * Required parameters:
 *  data - the jsonb field
 * Only valid input is expected.
*/

DROP FUNCTION IF EXISTS reclada_object.jsonb_to_text(jsonb);
CREATE OR REPLACE FUNCTION reclada_object.jsonb_to_text(data jsonb)
RETURNS text AS $$
    SELECT
        CASE
            WHEN jsonb_typeof(data) = 'string' THEN
                format(E'\'%s\'', data#>>'{}')
            WHEN jsonb_typeof(data) = 'array' THEN
                format('ARRAY[%s]',
                    (SELECT string_agg(
                        reclada_object.jsonb_to_text(elem),
                        ', ')
                    FROM jsonb_array_elements(data) elem))
            ELSE
                data#>>'{}'
        END
$$ LANGUAGE SQL IMMUTABLE;


/*
 * Auxiliary function get_condition_array generates a query string to get the jsonb field which contains array with a cast to postgres primitive types.
 * Required parameters:
 *  data - the jsonb field which contains array
 *  key_path - the path to jsonb object field
 * Examples:
 * 1. Input: data = {"operator": "inList", "object": [60, 64, 65]}::jsonb,
             key_path = data->'revision'
 *    Output: ((data->'revision')::numeric = ANY(ARRAY[60, 64, 65]))
 * 2. Input: data = {"object": ["value1", "value2", "value3"]}::jsonb,
             key_path = data->'attrs'->'tags'
 *    Output: ((ARRAY(SELECT jsonb_array_elements_text(data->'attrs'->'tags')::text) = ARRAY['value1', 'value2', 'value3'])
 * Only valid input is expected.
*/

DROP FUNCTION IF EXISTS reclada_object.get_condition_array(jsonb, text);
CREATE OR REPLACE FUNCTION reclada_object.get_condition_array(data jsonb, key_path text)
RETURNS text AS $$
    SELECT
    CONCAT(
        key_path,
        ' ', data->>'operator', ' ',
        format(E'\'%s\'::jsonb', data->'object'#>>'{}'))
$$ LANGUAGE SQL IMMUTABLE;


/*
 * Auxiliary function get_query_condition generates a query string.
 * Required parameters:
 *  data - the jsonb field which contains query information
 *  key_path - the path to jsonb object field
 * Examples:
 * 1. Input: data = [{"operator": ">=", "object": 100}, {"operator": "<", "object": 124}]::jsonb,
 *            key_path = data->'revision'
 *    Output: (((data->'revision')::numeric >= 100) AND ((data->'revision')::numeric < 124))
 * 2. Input: data = {"operator": "LIKE", "object": "%test%"}::jsonb,
 *            key_path = data->'name'
 *    Output: ((data->'attrs'->'name'#>>'{}')::text LIKE '%test%')
*/

DROP FUNCTION IF EXISTS reclada_object.get_query_condition(jsonb, text);
CREATE OR REPLACE FUNCTION reclada_object.get_query_condition(data jsonb, key_path text)
RETURNS text AS $$
DECLARE
    key          text;
    operator     text;
    value        text;
    res          text;

BEGIN
    IF (data IS NULL OR data = 'null'::jsonb) THEN
        RAISE EXCEPTION 'There is no condition';
    END IF;

    IF (jsonb_typeof(data) = 'object') THEN

        IF (data->'object' IS NULL OR data->'object' = ('null'::jsonb)) THEN
            RAISE EXCEPTION 'There is no object field';
        END IF;

        IF (jsonb_typeof(data->'object') = 'object') THEN
            RAISE EXCEPTION 'The input_jsonb->''object'' can not contain jsonb object';
        END IF;

        IF (jsonb_typeof(data->'operator') != 'string' AND data->'operator' IS NOT NULL) THEN
            RAISE EXCEPTION 'The input_jsonb->''operator'' must contain string';
        END IF;

        IF (jsonb_typeof(data->'object') = 'array') THEN
            res := reclada_object.get_condition_array(data, key_path);
        ELSE
            key := reclada_object.cast_jsonb_to_postgres(key_path, jsonb_typeof(data->'object'));
            operator :=  data->>'operator';
            value := reclada_object.jsonb_to_text(data->'object');
            res := key || ' ' || operator || ' ' || value;
        END IF;
    ELSE
        key := reclada_object.cast_jsonb_to_postgres(key_path, jsonb_typeof(data));
        operator := '=';
        value := reclada_object.jsonb_to_text(data);
        res := key || ' ' || operator || ' ' || value;
    END IF;
    RETURN res;

END;
$$ LANGUAGE PLPGSQL STABLE;

