/*
 * Function reclada_object.create creates one or bunch of objects with specified fields.
 * A jsonb with user_info and jsonb with the following parameters are required.
 * Required parameters:
 *  class - the class of objects
 *  attrs - the attributes of objects
 * Optional parameters:
 *  revision - object's revision. If a revision already exists, no new revision will be created. One revision is used to create a bunch of objects.
 *  branch - object's branch
 */

DROP FUNCTION IF EXISTS reclada_object.create(jsonb, jsonb);
CREATE OR REPLACE FUNCTION reclada_object.create(data_jsonb jsonb, user_info jsonb default '{}'::jsonb)
RETURNS jsonb AS $$
DECLARE
    class      jsonb;
    attrs      jsonb;
    schema     jsonb;
    branch     uuid;
    revid      integer;
    objid      uuid;
    data       jsonb;
    res        jsonb[];

BEGIN

    /*TODO: check if some objects have revision and others do not */
    branch:= data_jsonb->0->'branch';

    IF (data_jsonb->0->'revision' IS NULL) THEN
        SELECT reclada_revision.create(user_info->>'sub', branch) INTO revid;
    END IF;

    FOREACH data IN ARRAY (SELECT ARRAY(SELECT jsonb_array_elements_text(data_jsonb))) LOOP

        class := data->'class';

        IF (class IS NULL) THEN
            RAISE EXCEPTION 'The reclada object class is not specified';
        END IF;

        attrs := data->'attrs';
        IF (attrs IS NULL) THEN
            RAISE EXCEPTION 'The reclada object must have attrs';
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

    INSERT INTO reclada.object  SELECT * FROM unnest(res);
    /* PERFORM reclada_notification.send_object_notification('create', data_jsonb); */
    RETURN array_to_json(res)::jsonb;

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
    (SELECT jsonb_agg(el) FROM (SELECT DISTINCT pg_catalog.jsonb_array_elements((class_schema -> 'required') || (attrs -> 'required')) el) arr)
    )::jsonb);
END;
$$ LANGUAGE PLPGSQL VOLATILE;


/*
 * Function reclada_object.list returns the list of objects with specified fields.
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
        RAISE EXCEPTION 'The reclada object class not specified';
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

/*
 * Function reclada_object.update creates new revision of an object.
 * A jsonb with user_info and jsonb with the following parameters are required.
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

DROP FUNCTION IF EXISTS reclada_object.update(jsonb, jsonb);
CREATE OR REPLACE FUNCTION reclada_object.update(data jsonb, user_info jsonb default '{}'::jsonb)
RETURNS jsonb 
LANGUAGE PLPGSQL VOLATILE
AS $body$
DECLARE
    class         jsonb;
    attrs         jsonb;
    schema        jsonb;
    user_info     jsonb;
    branch        uuid;
    revid         integer;
    objid         uuid;
    oldobj        jsonb;

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

    objid := data->>'id';
    IF (objid IS NULL) THEN
        RAISE EXCEPTION 'Could not update object with no id';
    END IF;

    SELECT reclada_object.list(format(
        '{"class": %s, "id": "%s"}',
        class,
        objid
        )::jsonb) -> 0 INTO oldobj;

    IF (oldobj IS NULL) THEN
        RAISE EXCEPTION 'Could not update object, no such id';
    END IF;

    SELECT reclada_revision.create(user_info->>'sub', branch) INTO revid;
    data := data || format(
        '{"revision": %s, "isDeleted": false}',
        revid
        )::jsonb; --TODO replace isDeleted with status attr
    --TODO compare old and data to avoid unnecessery inserts 
    INSERT INTO reclada.object VALUES(data);
    /* PERFORM reclada_notification.send_object_notification('update', data); */
    RETURN data; 
END;
$body$;


DROP FUNCTION IF EXISTS reclada_object.delete(jsonb, jsonb);
CREATE OR REPLACE FUNCTION reclada_object.delete(data jsonb, user_info jsonb default '{}'::jsonb)
RETURNS jsonb 
LANGUAGE PLPGSQL VOLATILE 
AS $$
DECLARE
    class         jsonb;
    user_info     jsonb;
    branch        uuid;
    revid         integer;
    objid         uuid;
    oldobj        jsonb;
BEGIN
    class := data->'class';

    IF (class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    branch := data->'branch';

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

    SELECT reclada_revision.create(user_info->>'sub', branch) INTO revid;
    data := data || format(
            '{"revision": %s, "isDeleted": true}',
            revid
        )::jsonb;
    INSERT INTO reclada.object VALUES(data);
    /* PERFORM reclada_notification.send_object_notification('delete', data); */
    RETURN data;
END;
$$;