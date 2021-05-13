DROP FUNCTION IF EXISTS api.reclada_object_create(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_create(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class      jsonb;
    attrs      jsonb;
    user_info  jsonb;
    result     jsonb;
BEGIN
    class := data->'class';

    IF(class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    SELECT reclada_user.auth_by_token(data->>'access_token') INTO user_info;
    data := data - 'access_token';

    IF(NOT(reclada_user.is_allowed(user_info, 'create', class))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'create', class;
    END IF;

    attrs := data->'attrs';
    IF(attrs IS NULL) THEN
        RAISE EXCEPTION 'reclada object must have attrs';
    END IF;

    SELECT reclada_object.create(data) INTO result;
    RETURN result;
END;
$$ LANGUAGE PLPGSQL VOLATILE;


DROP FUNCTION IF EXISTS api.reclada_object_list(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_list(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class               jsonb;
    user_info           jsonb;
    result              jsonb;
BEGIN
    SELECT reclada_user.auth_by_token(data->>'access_token') INTO user_info;
    data := data - 'access_token';

    IF(NOT(reclada_user.is_allowed(user_info, 'list', class))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'list', class;
    END IF;

    SELECT reclada_object.list(data) INTO result;
    RETURN result;
END;
$$ LANGUAGE PLPGSQL STABLE;

DROP FUNCTION IF EXISTS api.reclada_object_update(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_update(data jsonb)
RETURNS VOID AS $$
DECLARE
    class         jsonb;
    attrs         jsonb;
    schema        jsonb;
    user_info     jsonb;
    branch        uuid;
    revid         integer;
    objid         uuid;
    oldobj        jsonb;
    access_token  text;
BEGIN
    class := data->'class';

    IF(class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    access_token := data->>'access_token';
    SELECT reclada_user.auth_by_token(access_token) INTO user_info;
    data := data - 'access_token';

    IF(NOT(reclada_user.is_allowed(user_info, 'update', class))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'update', class;
    END IF;

    attrs := data->'attrs';
    IF(attrs IS NULL) THEN
        RAISE EXCEPTION 'reclada object must have attrs';
    END IF;

    SELECT (api.reclada_object_list(format(
        '{"class": "jsonschema", "attrs": {"forClass": %s}, "access_token": "%s"}',
        class,
        access_token
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
        '{"class": %s, "attrs": {}, "id": "%s", "access_token": "%s"}',
        class,
        objid,
        access_token
    )::jsonb) -> 0 INTO oldobj;

    IF(oldobj IS NULL) THEN
        RAISE EXCEPTION 'Could not update object, no such id';
    END IF;

    data := oldobj || data || format(
        '{"id": "%s", "revision": %s, "isDeleted": false}',
        objid,
        revid
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
    data := data - 'access_token';

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
