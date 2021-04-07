DROP FUNCTION IF EXISTS api.reclada_object_create(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_create(data jsonb)
RETURNS VOID AS $$
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

    IF(class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    SELECT reclada_user.auth_by_token(data->>'access_token') INTO user_info;

    IF(NOT(reclada_user.is_allowed(user_info, 'create', class))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'create', class;
    END IF;

    attrs := data->'attrs';
    IF(attrs IS NULL) THEN
        RAISE EXCEPTION 'reclada object must have attrs';
    END IF;

    SELECT (api.reclada_object_list(format(
        '{"class": "jsonschema", "attrs": {"forClass": %s}}',
        class
    )::jsonb)) -> 0 INTO schema;

    IF(schema IS NULL) THEN
        RAISE EXCEPTION 'No json schema available for %', class;
    END IF;

    IF(NOT(validate_json_schema(schema->'attrs'->'schema', attrs))) THEN
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
END;
$$ LANGUAGE PLPGSQL VOLATILE;

DROP FUNCTION IF EXISTS api.reclada_object_create_subclass(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_create_subclass(data jsonb)
RETURNS VOID AS $$
DECLARE
    class_schema    jsonb;
    class           jsonb;
    attrs           jsonb;
    user_info       jsonb;
BEGIN
    class := data->'class';

    IF(class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    SELECT reclada_user.auth_by_token(data->>'access_token') INTO user_info;

    IF(NOT(reclada_user.is_allowed(user_info, 'create', '"jsonschema"'))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'create', 'jsonschema';
    END IF;

    attrs := data->'attrs';
    IF(attrs IS NULL) THEN
        RAISE EXCEPTION 'reclada object must have attrs';
    END IF;

    SELECT (api.reclada_object_list(format(
        '{"class": "jsonschema", "attrs": {"forClass": %s}}',
        class
    )::jsonb)) -> 0 INTO class_schema;

    IF(class_schema IS NULL) THEN
        RAISE EXCEPTION 'No json schema available for %', class;
    END IF;
    
    class_schema := class_schema -> 'attrs' -> 'schema';

    PERFORM api.reclada_object_create(format('{
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


DROP FUNCTION IF EXISTS api.reclada_object_list(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_list(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class               jsonb;
    attrs               jsonb;
    schema              jsonb;
    user_info           jsonb;
    branch              uuid;
    revid               integer;
    query_conditions    text;
    res                 jsonb;
BEGIN
    class := data->'class';

    IF(class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    SELECT reclada_user.auth_by_token(data->>'access_token') INTO user_info;

    IF(NOT(reclada_user.is_allowed(user_info, 'list', class))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'list', class;
    END IF;

    attrs := data->'attrs';
    IF(attrs IS NULL) THEN
        RAISE EXCEPTION 'reclada object must have attrs';
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
    EXECUTE E'SELECT to_jsonb(array_agg(obj.data))
        FROM reclada.object obj
        WHERE
    ' || query_conditions
        INTO res;

    RETURN res;
END;
$$ LANGUAGE PLPGSQL STABLE;

DROP FUNCTION IF EXISTS api.reclada_object_update(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_update(data jsonb)
RETURNS VOID AS $$
DECLARE
    class       jsonb;
    attrs       jsonb;
    schema      jsonb;
    user_info   jsonb;
    branch      uuid;
    revid       integer;
    objid       uuid;
    oldobj      jsonb;
BEGIN
    class := data->'class';

    IF(class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    SELECT reclada_user.auth_by_token(data->>'access_token') INTO user_info;

    IF(NOT(reclada_user.is_allowed(user_info, 'update', class))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'update', class;
    END IF;

    attrs := data->'attrs';
    IF(attrs IS NULL) THEN
        RAISE EXCEPTION 'reclada object must have attrs';
    END IF;

    SELECT (api.reclada_object_list(format(
        '{"class": "jsonschema", "attrs": {"forClass": %s}}',
        class
    )::jsonb)) -> 0 INTO schema;

    IF(schema IS NULL) THEN
        RAISE EXCEPTION 'No json schema available for %', class;
    END IF;

    IF(NOT(validate_json_schema(schema->'attrs'->'schema', attrs))) THEN
        RAISE EXCEPTION 'JSON invalid: %', attrs;
    END IF;

    branch := data->'branch';

    SELECT reclada_revision.create(user_info->>'sub', branch) INTO revid;
    objid := data->>'id';
    IF(objid IS NULL) THEN
        RAISE EXCEPTION 'Could not update object with no id';
    END IF;

    SELECT api.reclada_object_list(format(
        '{"class": %s, "attrs": {}, "id": "%s"}',
        class,
        objid
    )::jsonb) -> 0 INTO oldobj;

    IF(oldobj IS NULL) THEN
        RAISE EXCEPTION 'Could not update object, no such id';
    END IF;

    data := oldobj || data || format(
        '{"id": "%s", "revision": %s, "isDeleted": false}',
        objid, revid
    )::jsonb;
    INSERT INTO reclada.object VALUES(data);
END;
$$ LANGUAGE PLPGSQL VOLATILE;

DROP FUNCTION IF EXISTS api.reclada_object_delete(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_delete(data jsonb)
RETURNS VOID AS $$
DECLARE
    class       jsonb;
    attrs       jsonb;
    schema      jsonb;
    user_info   jsonb;
    branch      uuid;
    revid       integer;
    objid       uuid;
    oldobj      jsonb;
BEGIN
    class := data->'class';

    IF(class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    SELECT reclada_user.auth_by_token(data->>'access_token') INTO user_info;

    IF(NOT(reclada_user.is_allowed(user_info, 'delete', class))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'delete', class;
    END IF;

    branch := data->'branch';

    SELECT reclada_revision.create(user_info->>'sub', branch) INTO revid;
    objid := data->>'id';
    IF(objid IS NULL) THEN
        RAISE EXCEPTION 'Could not delete object with no id';
    END IF;

    SELECT api.reclada_object_list(format(
        '{"class": %s, "attrs": {}, "id": "%s"}',
        class,
        objid
    )::jsonb) -> 0 INTO oldobj;

    IF(oldobj IS NULL) THEN
        RAISE EXCEPTION 'Could not delete object, no such id';
    END IF;

    data := oldobj || data || format(
        '{"id": "%s", "revision": %s, "isDeleted": true}',
        objid, revid
    )::jsonb;
    INSERT INTO reclada.object VALUES(data);
END;
$$ LANGUAGE PLPGSQL VOLATILE;

