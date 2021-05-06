DROP FUNCTION IF EXISTS reclada_object.create(jsonb);
CREATE OR REPLACE FUNCTION reclada_object.create(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class      jsonb;
    attrs      jsonb;
    schema     jsonb;
    user_info  jsonb;
    branch     uuid;
    revid      integer;
    objid      uuid;
BEGIN
    class := data->'class';

    IF (class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    attrs := data->'attrs';
    IF (attrs IS NULL) THEN
        RAISE EXCEPTION 'reclada object must have attrs';
    END IF;

    SELECT (reclada_object.list(format(
        '{"class": "jsonschema", "attrs": {"forClass": %s}}',
        class
    )::jsonb)) -> 0 INTO schema;

    IF (schema IS NULL) THEN
        RAISE EXCEPTION 'No json schema available for %', class;
    END IF;

    IF (NOT(validate_json_schema(schema->'attrs'->'schema', attrs))) THEN
        RAISE EXCEPTION 'JSON invalid: %', attrs;
    END IF;

    branch := data->'branch';

    SELECT reclada_revision.create(user_info->>'sub', branch) INTO revid;
    SELECT uuid_generate_v4() INTO objid;

    data := data || format(
        '{"id": "%s", "revision": %s, "isDeleted": false}',
        objid, revid
    )::jsonb;
    INSERT INTO reclada.object VALUES(data);
    RETURN data;
END;
$$ LANGUAGE PLPGSQL VOLATILE;

DROP FUNCTION IF EXISTS reclada_object.create_subclass(jsonb);
CREATE OR REPLACE FUNCTION reclada_object.create_subclass(data jsonb)
RETURNS VOID AS $$
DECLARE
    class_schema    jsonb;
    class           jsonb;
    attrs           jsonb;
BEGIN
    class := data->'class';

    IF (class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    attrs := data->'attrs';
    IF (attrs IS NULL) THEN
        RAISE EXCEPTION 'reclada object must have attrs';
    END IF;

    SELECT (reclada_object.list(format(
        '{"class": "jsonschema", "attrs": {"forClass": %s}}',
        class
    )::jsonb)) -> 0 INTO class_schema;

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
    (class_schema -> 'required') || (attrs -> 'required')
    )::jsonb);
END;
$$ LANGUAGE PLPGSQL VOLATILE;


/*
 * Function reclada_object.list returns the list of objects with specified fields.
 * Required parameters:
 *  class - the class of objects
 *  attrs - the attributes of objects (can be empty)
 * Optional parameters:
 *  id - identifier of the objects. All ids are taken by default.
 *  revision - object's revision. returns object with max revision by default.
 *  orderBy - list of jsons in the form of {"field": "field_name", "order": <"ASC"/"DESC">}.
 *      field - required value with name of property to order by
 *      order - optional value of the order; default is "ASC". Sorted by id in ascending order by default
 *  limit - the number or string "ALL", no more than this many objects will be returned. Default limit value is "ALL".
 *  offset - the number to skip this many objects before beginning to return objects. Default offset value is 0.
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
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    attrs := data->'attrs';
    IF (attrs IS NULL) THEN
        RAISE EXCEPTION 'reclada object must have attrs';
    END IF;

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
                E'(%s = %s)',
                key,
                value
            ),
            ' AND '
        )
        FROM (
            SELECT E'data -> \'id\'' AS key, (format(E'\'%s\'', data->'id')::text) AS value WHERE data->'id' IS NOT NULL
            UNION SELECT
                E'data -> \'class\'' AS key,
                format(E'\'%s\'', class :: text) AS value
            UNION SELECT E'data -> \'revision\'' AS key, 
                CASE WHEN data->'revision' IS NULL THEN
                    E'(SELECT max((objrev.data -> \'revision\') :: integer) :: text :: jsonb
                    FROM reclada.object objrev WHERE
                    objrev.data -> \'id\' = obj.data -> \'id\')'
                ELSE (data->'revision') :: integer :: text END
            UNION SELECT
                format(E'data->\'attrs\'->%L', key) as key,
                format(E'\'%s\'::jsonb', value) as value
            FROM jsonb_each(attrs)
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
