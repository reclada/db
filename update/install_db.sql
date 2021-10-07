-- version = 36
-- 2021-10-07 14:22:10.181781--
-- PostgreSQL database dump
--

-- Dumped from database version 13.3
-- Dumped by pg_dump version 13.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: api; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA api;


--
-- Name: aws_commons; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS aws_commons WITH SCHEMA public;


--
-- Name: EXTENSION aws_commons; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION aws_commons IS 'Common data types across AWS services';


--
-- Name: aws_lambda; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS aws_lambda WITH SCHEMA public;


--
-- Name: EXTENSION aws_lambda; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION aws_lambda IS 'AWS Lambda integration';


--
-- Name: dev; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA dev;


--
-- Name: reclada; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA reclada;


--
-- Name: reclada_notification; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA reclada_notification;


--
-- Name: reclada_object; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA reclada_object;


--
-- Name: reclada_revision; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA reclada_revision;


--
-- Name: reclada_storage; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA reclada_storage;


--
-- Name: reclada_user; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA reclada_user;


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: auth_get_login_url(jsonb); Type: FUNCTION; Schema: api; Owner: -
--

CREATE FUNCTION api.auth_get_login_url(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    base_url VARCHAR;
    client_id VARCHAR;
BEGIN
    SELECT oidc_url, oidc_client_id INTO base_url, client_id
        FROM reclada.auth_setting;
    IF base_url IS NULL THEN
        RETURN jsonb_build_object('login_url', NULL);
    ELSE
        RETURN jsonb_build_object('login_url', format(
            '%s/auth?client_id=%s&response_type=code',
            base_url, client_id
        ));
    END IF;
END;
$$;


--
-- Name: hello_world(jsonb); Type: FUNCTION; Schema: api; Owner: -
--

CREATE FUNCTION api.hello_world(data jsonb) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
SELECT 'Hello, world!';
$$;


--
-- Name: hello_world(text); Type: FUNCTION; Schema: api; Owner: -
--

CREATE FUNCTION api.hello_world(data text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
SELECT 'Hello, world!';
$$;


--
-- Name: reclada_object_create(jsonb); Type: FUNCTION; Schema: api; Owner: -
--

CREATE FUNCTION api.reclada_object_create(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    data_jsonb       jsonb;
    class            text;
    user_info        jsonb;
    attrs            jsonb;
    data_to_create   jsonb = '[]'::jsonb;
    result           jsonb;

BEGIN

    IF (jsonb_typeof(data) != 'array') THEN
        data := '[]'::jsonb || data;
    END IF;

    FOR data_jsonb IN SELECT jsonb_array_elements(data) LOOP

        class := data_jsonb->>'class';
        IF (class IS NULL) THEN
            RAISE EXCEPTION 'The reclada object class is not specified';
        END IF;

        SELECT reclada_user.auth_by_token(data_jsonb->>'accessToken') INTO user_info;
        data_jsonb := data_jsonb - 'accessToken';

        IF (NOT(reclada_user.is_allowed(user_info, 'create', class))) THEN
            RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'create', class;
        END IF;

        attrs := data_jsonb->'attributes';
        IF (attrs IS NULL) THEN
            RAISE EXCEPTION 'The reclada object must have attributes';
        END IF;

        data_to_create := data_to_create || data_jsonb;
    END LOOP;

    SELECT reclada_object.create(data_to_create, user_info) INTO result;
    RETURN result;

END;
$$;


--
-- Name: reclada_object_delete(jsonb); Type: FUNCTION; Schema: api; Owner: -
--

CREATE FUNCTION api.reclada_object_delete(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    class         text;
    obj_id        uuid;
    user_info     jsonb;
    result        jsonb;

BEGIN

    class := data->>'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    obj_id := data->>'GUID';
    IF (obj_id IS NULL) THEN
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
$$;


--
-- Name: reclada_object_get_transaction_id(jsonb); Type: FUNCTION; Schema: api; Owner: -
--

CREATE FUNCTION api.reclada_object_get_transaction_id(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
BEGIN
    return reclada_object.get_transaction_id(data);
END;
$$;


--
-- Name: reclada_object_list(jsonb); Type: FUNCTION; Schema: api; Owner: -
--

CREATE FUNCTION api.reclada_object_list(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    class               text;
    user_info           jsonb;
    result              jsonb;

BEGIN

    class := data->>'class';
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
$$;


--
-- Name: reclada_object_list_add(jsonb); Type: FUNCTION; Schema: api; Owner: -
--

CREATE FUNCTION api.reclada_object_list_add(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    class          text;
    obj_id         uuid;
    user_info      jsonb;
    field_value    jsonb;
    values_to_add  jsonb;
    result         jsonb;

BEGIN

    class := data->>'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

    obj_id := (data->>'GUID')::uuid;
    IF (obj_id IS NULL) THEN
        RAISE EXCEPTION 'There is no GUID';
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
$$;


--
-- Name: reclada_object_list_drop(jsonb); Type: FUNCTION; Schema: api; Owner: -
--

CREATE FUNCTION api.reclada_object_list_drop(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    class           text;
    obj_id          uuid;
    user_info       jsonb;
    field_value     jsonb;
    values_to_drop  jsonb;
    result          jsonb;

BEGIN

	class := data->>'class';
	IF (class IS NULL) THEN
		RAISE EXCEPTION 'The reclada object class is not specified';
	END IF;

	obj_id := (data->>'GUID')::uuid;
	IF (obj_id IS NULL) THEN
		RAISE EXCEPTION 'The is no GUID';
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
$$;


--
-- Name: reclada_object_list_related(jsonb); Type: FUNCTION; Schema: api; Owner: -
--

CREATE FUNCTION api.reclada_object_list_related(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    class          text;
    obj_id         uuid;
    field          jsonb;
    related_class  jsonb;
    user_info      jsonb;
    result         jsonb;

BEGIN
    class := data->>'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

    obj_id := (data->>'GUID')::uuid;
    IF (obj_id IS NULL) THEN
        RAISE EXCEPTION 'The object GUID is not specified';
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
$$;


--
-- Name: reclada_object_update(jsonb); Type: FUNCTION; Schema: api; Owner: -
--

CREATE FUNCTION api.reclada_object_update(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    class         text;
    objid         uuid;
    attrs         jsonb;
    user_info     jsonb;
    result        jsonb;

BEGIN

    class := data->>'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    objid := data->>'GUID';
    IF (objid IS NULL) THEN
        RAISE EXCEPTION 'Could not update object with no GUID';
    END IF;

    attrs := data->'attributes';
    IF (attrs IS NULL) THEN
        RAISE EXCEPTION 'reclada object must have attributes';
    END IF;

    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
    data := data - 'accessToken';

    IF (NOT(reclada_user.is_allowed(user_info, 'update', class))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'update', class;
    END IF;

    SELECT reclada_object.update(data, user_info) INTO result;
    RETURN result;

END;
$$;


--
-- Name: storage_generate_presigned_get(jsonb); Type: FUNCTION; Schema: api; Owner: -
--

CREATE FUNCTION api.storage_generate_presigned_get(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    object_data  jsonb;
    object_id    uuid;
    result       jsonb;
    user_info    jsonb;
    lambda_name  varchar;

BEGIN
    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
    data := data - 'accessToken';

    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned get', ''))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned get';
    END IF;

    -- TODO: check user's permissions for reclada object access?
    object_id := data->>'objectId';
    SELECT reclada_object.list(format(
        '{"class": "File", "attributes": {}, "GUID": "%s"}',
        object_id
    )::jsonb) -> 0 INTO object_data;

    SELECT attrs->>'Lambda'
    FROM reclada.v_active_object
    WHERE class_name = 'Context'
    ORDER BY created_time DESC
    LIMIT 1
    INTO lambda_name;

    SELECT payload
    FROM aws_lambda.invoke(
        aws_commons.create_lambda_function_arn(
            format('%s', lambda_name),
            'eu-west-1'
            ),
        format('{
            "type": "get",
            "uri": "%s",
            "expiration": 3600}',
            object_data->'attributes'->>'uri'
            )::jsonb)
    INTO result;

    RETURN result;
END;
$$;


--
-- Name: storage_generate_presigned_post(jsonb); Type: FUNCTION; Schema: api; Owner: -
--

CREATE FUNCTION api.storage_generate_presigned_post(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    lambda_name  varchar;
    file_type    varchar;
    object       jsonb;
    object_id    uuid;
    object_name  varchar;
    object_path  varchar;
    result       jsonb;
    user_info    jsonb;
    uri          varchar;
    url          varchar;

BEGIN
    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
    data := data - 'accessToken';

    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned post', ''))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';
    END IF;

    object_name := data->>'objectName';
    file_type := data->>'fileType';

    SELECT attrs->>'Lambda'
    FROM reclada.v_active_object
    WHERE class_name = 'Context'
    ORDER BY created_time DESC
    LIMIT 1
    INTO lambda_name;

    SELECT payload::jsonb
    FROM aws_lambda.invoke(
        aws_commons.create_lambda_function_arn(
                format('%s', lambda_name),
                'eu-west-1'
        ),
        format('{
            "type": "post",
            "fileName": "%s",
            "fileType": "%s",
            "fileSize": "%s",
            "expiration": 3600}',
            object_name,
            file_type,
            data->>'fileSize'
            )::jsonb)
    INTO url;

    result = format(
        '{"uploadUrl": %s}',
        url
    )::jsonb;

    RETURN result;
END;
$$;


--
-- Name: downgrade_version(); Type: FUNCTION; Schema: dev; Owner: -
--

CREATE FUNCTION dev.downgrade_version() RETURNS text
    LANGUAGE plpgsql
    AS $$
declare 
    current_ver int; 
    downgrade_script text;
    v_state   TEXT;
    v_msg     TEXT;
    v_detail  TEXT;
    v_hint    TEXT;
    v_context TEXT;
BEGIN

    select max(ver) 
        from dev.VER
    into current_ver;
    
    select v.downgrade_script 
        from dev.VER v
            WHERE current_ver = v.ver
        into downgrade_script;

    if COALESCE(downgrade_script,'') = '' then
        RAISE EXCEPTION 'downgrade_script is empty! from dev.downgrade_version()';
    end if;

    EXECUTE downgrade_script;

    -- mark, that chanches applied
    delete 
        from dev.VER v
            where v.ver = current_ver;

    v_msg = 'OK, curren version: ' || (current_ver-1)::text;
    perform reclada.raise_notice(v_msg);
    return v_msg;
EXCEPTION when OTHERS then 
	get stacked diagnostics
        v_state   = returned_sqlstate,
        v_msg     = message_text,
        v_detail  = pg_exception_detail,
        v_hint    = pg_exception_hint,
        v_context = pg_exception_context;

    v_state := format('Got exception:
state   : %s
message : %s
detail  : %s
hint    : %s
context : %s
SQLSTATE: %s
SQLERRM : %s', 
                v_state, 
                v_msg, 
                v_detail, 
                v_hint, 
                v_context,
                SQLSTATE,
                SQLERRM);
    perform dev.reg_notice(v_state);
    return v_state;
END
$$;


--
-- Name: reg_notice(text); Type: FUNCTION; Schema: dev; Owner: -
--

CREATE FUNCTION dev.reg_notice(msg text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    insert into dev.t_dbg(msg)
		select msg;
    perform reclada.raise_notice(msg);
END
$$;


--
-- Name: get_transaction_id(); Type: FUNCTION; Schema: reclada; Owner: -
--

CREATE FUNCTION reclada.get_transaction_id() RETURNS bigint
    LANGUAGE plpgsql
    AS $$
BEGIN
    return nextval('reclada.transaction_id');
END
$$;


--
-- Name: get_transaction_id_for_import(text); Type: FUNCTION; Schema: reclada; Owner: -
--

CREATE FUNCTION reclada.get_transaction_id_for_import(fileguid text) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
    tran_id_    bigint;
BEGIN

    select o.transaction_id
        from reclada.v_active_object o
            where o.class_name = 'Document'
                and attrs->>'fileGUID' = fileGUID
        ORDER BY ID DESC 
        limit 1
        into tran_id_;

    if tran_id_ is not null then
        PERFORM reclada_object.delete(format('{"transactionID":%s}',tran_id_)::jsonb);
    end if;
    tran_id_ := reclada.get_transaction_id();

    return tran_id_;
END
$$;


--
-- Name: load_staging(); Type: FUNCTION; Schema: reclada; Owner: -
--

CREATE FUNCTION reclada.load_staging() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM reclada_object.create(NEW.data);
    RETURN NEW;
END
$$;


--
-- Name: raise_exception(text, text); Type: FUNCTION; Schema: reclada; Owner: -
--

CREATE FUNCTION reclada.raise_exception(msg text, func_name text DEFAULT '<unknown>'::text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- 
    RAISE EXCEPTION '% 
    from: %', msg, func_name;
END
$$;


--
-- Name: raise_notice(text); Type: FUNCTION; Schema: reclada; Owner: -
--

CREATE FUNCTION reclada.raise_notice(msg text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- 
    RAISE NOTICE '%', msg;
END
$$;


--
-- Name: rollback_import(text); Type: FUNCTION; Schema: reclada; Owner: -
--

CREATE FUNCTION reclada.rollback_import(fileguid text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    tran_id_     bigint;
    json_data   jsonb;
    tmp         jsonb;
    obj_id_     uuid;
    f_name      text;
    id_         bigint;
BEGIN
    f_name := 'reclada.rollback_import';
    select o.transaction_id
        from reclada.v_active_object o
            where o.class_name = 'Document'
                and attrs->>'fileGUID' = fileGUID
        ORDER BY ID DESC 
        limit 1
        into tran_id_;

    if tran_id_ is null then
        PERFORM reclada.raise_exception('"fileGUID": "'
                            ||fileGUID
                            ||'" not found for existing Documents',f_name);
    end if;

    delete from reclada.object where tran_id_ = transaction_id;
    
    with t as (
        select o.transaction_id
            from reclada.v_object o
                where o.class_name = 'Document'
                    and attrs->>'fileGUID' = fileGUID
            ORDER BY ID DESC 
            limit 1
    ) 
    update reclada.object o
        set status = reclada_object.get_active_status_obj_id()
        from t
            where t.transaction_id = o.transaction_id;
                    
    return 'OK';
END
$$;


--
-- Name: try_cast_int(text, integer); Type: FUNCTION; Schema: reclada; Owner: -
--

CREATE FUNCTION reclada.try_cast_int(p_in text, p_default integer DEFAULT NULL::integer) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE
    AS $$
begin
    return p_in::int;
    exception when others then
        return p_default;
end;
$$;


--
-- Name: try_cast_uuid(text, integer); Type: FUNCTION; Schema: reclada; Owner: -
--

CREATE FUNCTION reclada.try_cast_uuid(p_in text, p_default integer DEFAULT NULL::integer) RETURNS uuid
    LANGUAGE plpgsql IMMUTABLE
    AS $$
begin
    return p_in::uuid;
    exception when others then
        return p_default;
end;
$$;


--
-- Name: listen(character varying); Type: FUNCTION; Schema: reclada_notification; Owner: -
--

CREATE FUNCTION reclada_notification.listen(channel character varying) RETURNS void
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    EXECUTE 'LISTEN ' || lower(channel);
END
$$;


--
-- Name: send(character varying, jsonb); Type: FUNCTION; Schema: reclada_notification; Owner: -
--

CREATE FUNCTION reclada_notification.send(channel character varying, payload jsonb DEFAULT NULL::jsonb) RETURNS void
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    PERFORM pg_notify(lower(channel), payload::text); 
END
$$;


--
-- Name: send_object_notification(character varying, jsonb); Type: FUNCTION; Schema: reclada_notification; Owner: -
--

CREATE FUNCTION reclada_notification.send_object_notification(event character varying, object_data jsonb) RETURNS void
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    data            jsonb;
    message         jsonb;
    msg             jsonb;
    object_class    uuid;
    class__name     varchar;
    attrs           jsonb;
    query           text;

BEGIN
    IF (jsonb_typeof(object_data) != 'array') THEN
        object_data := '[]'::jsonb || object_data;
    END IF;

    FOR data IN SELECT jsonb_array_elements(object_data) LOOP
        object_class := (data ->> 'class')::uuid;
        select for_class
            from reclada.v_class_lite cl
                where cl.obj_id = object_class
            into class__name;

        if event is null or object_class is null then
            return;
        end if;
        
        SELECT v.data
            FROM reclada.v_active_object v
                WHERE v.class_name = 'Message'
                    AND v.attrs->>'event' = event
                    AND v.attrs->>'class' = class__name
        INTO message;

        -- raise notice '%', event || ' ' || class__name;

        IF message IS NULL THEN
            RETURN;
        END IF;

        query := format(E'select to_json(x) from jsonb_to_record($1) as x(%s)',
            (
                select string_agg(s::text || ' jsonb', ',') 
                    from jsonb_array_elements(message -> 'attributes' -> 'attrs') s
            ));
        execute query into attrs using data -> 'attributes';

        msg := jsonb_build_object(
            'objectId', data -> 'GUID',
            'class', object_class,
            'event', event,
            'attributes', attrs
        );

        perform reclada_notification.send(message #>> '{attributes, channelName}', msg);

    END LOOP;
END
$_$;


--
-- Name: cast_jsonb_to_postgres(text, text, text); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.cast_jsonb_to_postgres(key_path text, type text, type_of_array text DEFAULT 'text'::text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
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
$$;


--
-- Name: create(jsonb, jsonb); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object."create"(data_jsonb jsonb, user_info jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    branch        uuid;
    data          jsonb;
    class_name    text;
    class_uuid    uuid;
    tran_id       bigint;
    _attrs         jsonb;
    schema        jsonb;
    obj_GUID      uuid;
    res           jsonb;
    affected      uuid[];
BEGIN

    IF (jsonb_typeof(data_jsonb) != 'array') THEN
        data_jsonb := '[]'::jsonb || data_jsonb;
    END IF;
    /*TODO: check if some objects have revision and others do not */
    branch:= data_jsonb->0->'branch';

    FOR data IN SELECT jsonb_array_elements(data_jsonb) 
    LOOP

        class_name := data->>'class';

        IF (class_name IS NULL) THEN
            RAISE EXCEPTION 'The reclada object class is not specified';
        END IF;
        class_uuid := reclada.try_cast_uuid(class_name);

        _attrs := data->'attributes';
        IF (_attrs IS NULL) THEN
            RAISE EXCEPTION 'The reclada object must have attributes';
        END IF;

        tran_id := (data->>'transactionID')::bigint;
        if tran_id is null then
            tran_id := reclada.get_transaction_id();
        end if;

        IF class_uuid IS NULL THEN
            SELECT reclada_object.get_schema(class_name) 
            INTO schema;
            class_uuid := (schema->>'GUID')::uuid;
        ELSE
            SELECT v.data 
            FROM reclada.v_class v
            WHERE class_uuid = v.obj_id
            INTO schema;
        END IF;
        IF (schema IS NULL) THEN
            RAISE EXCEPTION 'No json schema available for %', class_name;
        END IF;

        IF (NOT(public.validate_json_schema(schema->'attributes'->'schema', _attrs))) THEN
            RAISE EXCEPTION 'JSON invalid: %', _attrs;
        END IF;
        
        IF data->>'id' IS NOT NULL THEN
            RAISE EXCEPTION '%','Field "id" not allow!!!';
        END IF;

        IF class_uuid IN (SELECT guid FROM reclada.v_PK_for_class)
        THEN
            SELECT o.obj_id
                FROM reclada.v_object o
                JOIN reclada.v_PK_for_class pk
                    on pk.guid = o.class
                        and class_uuid = o.class
                where o.attrs->>pk.pk = _attrs ->> pk.pk
                LIMIT 1
            INTO obj_GUID;
            IF obj_GUID IS NOT NULL THEN
                SELECT reclada_object.update(data || format('{"GUID": "%s"}', obj_GUID)::jsonb)
                    INTO res;
                    RETURN '[]'::jsonb || res;
            END IF;
        END IF;

        obj_GUID := (data->>'GUID')::uuid;
        IF EXISTS (
            SELECT 1
            FROM reclada.object 
            WHERE GUID = obj_GUID
        ) THEN
            RAISE EXCEPTION 'GUID: % is duplicate', obj_GUID;
        END IF;
        --raise notice 'schema: %',schema;

        INSERT INTO reclada.object(GUID,class,attributes,transaction_id)
            SELECT  CASE
                        WHEN obj_GUID IS NULL
                            THEN public.uuid_generate_v4()
                        ELSE obj_GUID
                    END AS GUID,
                    class_uuid, 
                    _attrs,
                    tran_id
        RETURNING GUID INTO obj_GUID;
        affected := array_append( affected, obj_GUID);

        PERFORM reclada_object.datasource_insert
            (
                class_name,
                obj_GUID,
                _attrs
            );

        PERFORM reclada_object.refresh_mv(class_name);
    END LOOP;

    res := array_to_json
            (
                array
                (
                    SELECT o.data 
                    FROM reclada.v_active_object o
                    WHERE o.obj_id = ANY (affected)
                )
            )::jsonb; 
    PERFORM reclada_notification.send_object_notification
        (
            'create',
            res
        );
    RETURN res;

END;
$$;


--
-- Name: create_subclass(jsonb); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.create_subclass(data jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    class           text;
    new_class       text;
    attrs           jsonb;
    class_schema    jsonb;
    version_         integer;

BEGIN

    class := data->>'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

    attrs := data->'attributes';
    IF (attrs IS NULL) THEN
        RAISE EXCEPTION 'The reclada object must have attributes';
    END IF;

    new_class = attrs->>'newClass';

    SELECT reclada_object.get_schema(class) INTO class_schema;

    IF (class_schema IS NULL) THEN
        RAISE EXCEPTION 'No json schema available for %', class;
    END IF;

    SELECT max(version) + 1
    FROM reclada.v_class_lite v
    WHERE v.for_class = new_class
    INTO version_;

    version_ := coalesce(version_,1);
    class_schema := class_schema->'attributes'->'schema';

    PERFORM reclada_object.create(format('{
        "class": "jsonschema",
        "attributes": {
            "forClass": "%s",
            "version": "%s",
            "schema": {
                "type": "object",
                "properties": %s,
                "required": %s
            }
        }
    }',
    new_class,
    version_,
    (class_schema->'properties') || (attrs->'properties'),
    (SELECT jsonb_agg(el) FROM (
        SELECT DISTINCT pg_catalog.jsonb_array_elements(
            (class_schema -> 'required') || (attrs -> 'required')
        ) el) arr)
    )::jsonb);

END;
$$;


--
-- Name: datasource_insert(text, uuid, jsonb); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.datasource_insert(_class_name text, obj_id uuid, attributes jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    dataset       jsonb;
    uri           text;
    environment   varchar;
BEGIN
    IF _class_name in 
            ('DataSource','File') THEN

        SELECT v.data
        FROM reclada.v_active_object v
	    WHERE v.attrs->>'name' = 'defaultDataSet'
	    INTO dataset;

        dataset := jsonb_set(dataset, '{attributes, dataSources}', dataset->'attributes'->'dataSources' || format('["%s"]', obj_id)::jsonb);

        PERFORM reclada_object.update(dataset);

        uri := attributes->>'uri';

        SELECT attrs->>'Environment'
        FROM reclada.v_active_object
        WHERE class_name = 'Context'
        ORDER BY created_time DESC
        LIMIT 1
        INTO environment;

        PERFORM reclada_object.create(
            format('{
                "class": "Job",
                "attributes": {
                    "task": "c94bff30-15fa-427f-9954-d5c3c151e652",
                    "status": "new",
                    "type": "%s",
                    "command": "./run_pipeline.sh",
                    "inputParameters": [{"uri": "%s"}, {"dataSourceId": "%s"}]
                    }
                }', environment, uri, obj_id)::jsonb);

    END IF;
END;
$$;


--
-- Name: delete(jsonb, jsonb); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.delete(data jsonb, user_info jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_obj_id            uuid;
    tran_id             bigint;
    class               text;
    class_uuid          uuid;
    list_id             bigint[];

BEGIN

    v_obj_id := data->>'GUID';
    tran_id := (data->>'transactionID')::bigint;
    class := data->>'class';

    IF (v_obj_id IS NULL AND class IS NULL AND tran_id IS NULl) THEN
        RAISE EXCEPTION 'Could not delete object with no GUID, class and transactionID';
    END IF;

    class_uuid := reclada.try_cast_uuid(class);

    WITH t AS
    (    
        UPDATE reclada.object u
            SET status = reclada_object.get_archive_status_obj_id()
            FROM reclada.object o
                LEFT JOIN
                (   SELECT obj_id FROM reclada_object.get_GUID_for_class(class)
                    UNION SELECT class_uuid WHERE class_uuid IS NOT NULL
                ) c ON o.class = c.obj_id
                WHERE u.id = o.id AND
                (
                    (v_obj_id = o.GUID AND c.obj_id = o.class AND tran_id = o.transaction_id)

                    OR (v_obj_id = o.GUID AND c.obj_id = o.class AND tran_id IS NULL)
                    OR (v_obj_id = o.GUID AND c.obj_id IS NULL AND tran_id = o.transaction_id)
                    OR (v_obj_id IS NULL AND c.obj_id = o.class AND tran_id = o.transaction_id)

                    OR (v_obj_id = o.GUID AND c.obj_id IS NULL AND tran_id IS NULL)
                    OR (v_obj_id IS NULL AND c.obj_id = o.class AND tran_id IS NULL)
                    OR (v_obj_id IS NULL AND c.obj_id IS NULL AND tran_id = o.transaction_id)
                )
                    AND o.status != reclada_object.get_archive_status_obj_id()
                    RETURNING o.id
    ) 
        SELECT
            array
            (
                SELECT t.id FROM t
            )
        INTO list_id;

    SELECT array_to_json
    (
        array
        (
            SELECT o.data
            FROM reclada.v_object o
            WHERE o.id IN (SELECT unnest(list_id))
        )
    )::jsonb
    INTO data;

    IF (jsonb_array_length(data) = 1) THEN
        data := data->0;
    END IF;
    
    IF (data IS NULL) THEN
        RAISE EXCEPTION 'Could not delete object, no such GUID';
    END IF;

    PERFORM reclada_object.refresh_mv(class);

    PERFORM reclada_notification.send_object_notification('delete', data);

    RETURN data;
END;
$$;


--
-- Name: get_active_status_obj_id(); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.get_active_status_obj_id() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
    select obj_id 
        from reclada.v_object_status 
            where caption = 'active'
$$;


--
-- Name: get_archive_status_obj_id(); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.get_archive_status_obj_id() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
    select obj_id 
        from reclada.v_object_status 
            where caption = 'archive'
$$;


--
-- Name: get_condition_array(jsonb, text); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.get_condition_array(data jsonb, key_path text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT
    CONCAT(
        key_path,
        ' ', COALESCE(data->>'operator', '='), ' ',
        format(E'\'%s\'::jsonb', data->'object'#>>'{}'))
$$;


--
-- Name: get_default_user_obj_id(); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.get_default_user_obj_id() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
    select obj_id 
        from reclada.v_user 
            where login = 'dev'
$$;


--
-- Name: get_guid_for_class(text); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.get_guid_for_class(class text) RETURNS TABLE(obj_id uuid)
    LANGUAGE sql STABLE
    AS $$
    SELECT obj_id
        from reclada.v_class_lite
            where for_class = class
$$;


--
-- Name: get_jsonschema_guid(); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.get_jsonschema_guid() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
    SELECT class
        FROM reclada.object o
            where o.GUID = 
                (
                    select class 
                        from reclada.object 
                            where class is not null 
                    limit 1
                )
$$;


--
-- Name: get_query_condition(jsonb, text); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.get_query_condition(data jsonb, key_path text) RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
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
            operator :=  data->>'operator';
            IF operator = '=' then
                key := reclada_object.cast_jsonb_to_postgres(key_path, 'string' );
                RETURN (key || ' ' || operator || ' ''' || (data->'object')::text || '''');
            ELSE
                RAISE EXCEPTION 'The input_jsonb->''object'' can not contain jsonb object';
            END If;
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
$$;


--
-- Name: get_schema(text); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.get_schema(class text) RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
    SELECT data
    FROM reclada.v_class v
    WHERE v.for_class = class
    ORDER BY v.version DESC
    LIMIT 1
$$;


--
-- Name: get_transaction_id(jsonb); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.get_transaction_id(_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    _action text;
    _res jsonb;
    _tran_id bigint;
    _guid uuid;
    _func_name text;
BEGIN
    _func_name := 'reclada_object.get_transaction_id';
    _action := _data ->> 'action';
    _guid := _data ->> 'GUID';

    if    _action = 'new' and _guid is null    
    then
        _tran_id := reclada.get_transaction_id();
    ELSIF _action is null  and _guid is not null 
    then
        select o.transaction_id 
            from reclada.v_object o
                where _guid = o.obj_id
        into _tran_id;
        if _tran_id is null 
        then
            perform reclada.raise_exception('GUID not found.',_func_name);
        end if;
    else 
        perform reclada.raise_exception('Parameter has to contain GUID or action.',_func_name);
    end if;

    RETURN format('{"transactionID":%s}',_tran_id):: jsonb;
END;
$$;


--
-- Name: is_equal(jsonb, jsonb); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.is_equal(lobj jsonb, robj jsonb) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
	DECLARE
		cnt 	int;
		ltype	text;
		rtype	text;
	BEGIN
		ltype := jsonb_typeof(lobj);
		rtype := jsonb_typeof(robj);
		IF ltype != rtype THEN
			RETURN False;
		END IF;
		CASE ltype 
		WHEN 'object' THEN
			SELECT count(*) INTO cnt FROM (                     -- Using joining operators compatible with merge or hash join is obligatory
				SELECT 1                                        --    with FULL OUTER JOIN. is_equal is compatible only with NESTED LOOPS
				FROM (SELECT jsonb_each(lobj) AS rec) a         --    so I use LEFT JOIN UNION ALL RIGHT JOIN insted of FULL OUTER JOIN.
				LEFT JOIN
					(SELECT jsonb_each(robj) AS rec) b
				ON (a.rec).key = (b.rec).key AND reclada_object.is_equal((a.rec).value, (b.rec).value)  
				WHERE b.rec IS NULL
            UNION ALL 
				SELECT 1
				FROM (SELECT jsonb_each(robj) AS rec) a
				LEFT JOIN
					(SELECT jsonb_each(lobj) AS rec) b
				ON (a.rec).key = (b.rec).key AND reclada_object.is_equal((a.rec).value, (b.rec).value)  
				WHERE b.rec IS NULL
			) a;
			RETURN cnt=0;
		WHEN 'array' THEN
			SELECT count(*) INTO cnt FROM (
				SELECT 1
				FROM (SELECT jsonb_array_elements (lobj) AS rec) a
				LEFT JOIN
					(SELECT jsonb_array_elements (robj) AS rec) b
				ON reclada_object.is_equal((a.rec), (b.rec))  
				WHERE b.rec IS NULL
				UNION ALL
				SELECT 1
				FROM (SELECT jsonb_array_elements (robj) AS rec) a
				LEFT JOIN
					(SELECT jsonb_array_elements (lobj) AS rec) b
				ON reclada_object.is_equal((a.rec), (b.rec))  
				WHERE b.rec IS NULL
			) a;
			RETURN cnt=0;
		WHEN 'string' THEN
			RETURN text(lobj) = text(robj);
		WHEN 'number' THEN
			RETURN lobj::numeric = robj::numeric;
		WHEN 'boolean' THEN
			RETURN lobj::boolean = robj::boolean;
		WHEN 'null' THEN
			RETURN True;                                    -- It should be Null
		ELSE
			RETURN null;
		END CASE;
	END;
$$;


--
-- Name: jsonb_to_text(jsonb); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.jsonb_to_text(data jsonb) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
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
$$;


--
-- Name: list(jsonb, boolean); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.list(data jsonb, gui boolean DEFAULT false) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    AS $$
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
    last_change         text;
    tran_id             bigint;
BEGIN

    tran_id := (data->>'transactionID')::bigint;
    class := data->>'class';
    IF (class IS NULL and tran_id IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class and transactionID are not specified';
    END IF;
    class_uuid := reclada.try_cast_uuid(class);

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
        order_by_jsonb := '[{"field": "GUID", "order": "ASC"}]'::jsonb;
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
                format('obj.class_name = ''%s''', class) AS condition
                    where class is not null 
                        and class_uuid is null
            UNION
                SELECT format('obj.class = ''%s''', class_uuid) AS condition
                    where class_uuid is not null
            UNION
                SELECT format('obj.transaction_id = %s', tran_id) AS condition
                    where tran_id is not null
            UNION 
                SELECT CASE
                        WHEN jsonb_typeof(data->'GUID') = 'array' THEN
                        (
                            SELECT string_agg
                                (
                                    format(
                                        E'(%s)',
                                        reclada_object.get_query_condition(cond, E'data->''GUID''') -- TODO: change data->'GUID' to obj_id(GUID)
                                    ),
                                    ' AND '
                                )
                                FROM jsonb_array_elements(data->'GUID') AS cond
                        )
                        ELSE reclada_object.get_query_condition(data->'GUID', E'data->''GUID''') -- TODO: change data->'GUID' to obj_id(GUID)
                    END AS condition
                WHERE coalesce(data->'GUID','null'::jsonb) != 'null'::jsonb
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
    --raise notice 'query: %', query;
    EXECUTE E'SELECT to_jsonb(array_agg(T.data))
        FROM (
            SELECT obj.data
            '
            || query
            ||
            ' ORDER BY ' || order_by ||
            ' OFFSET ' || offset_ || ' LIMIT ' || limit_ || ') T'
    INTO objects;
    IF gui THEN

        EXECUTE E'SELECT count(1)
        '|| query
        INTO number_of_objects;

        EXECUTE E'SELECT TO_CHAR(
	MAX(
		GREATEST(obj.created_time, (
			SELECT TO_TIMESTAMP(MAX(date_time),\'YYYY-MM-DD hh24:mi:ss.US TZH\')
			FROM reclada.v_revision vr
			WHERE vr.obj_id = UUID(obj.attrs ->>\'revision\'))
		)
	),\'YYYY-MM-DD hh24:mi:ss.MS TZH\')
        '|| query
        INTO last_change;

        res := jsonb_build_object(
        'last_change', last_change,    
        'number', number_of_objects,
        'objects', objects);
    ELSE
        res := objects;
    END IF;

    RETURN res;

END;
$$;


--
-- Name: list_add(jsonb); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.list_add(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    class          text;
    objid          uuid;
    obj            jsonb;
    values_to_add  jsonb;
    field          text;
    field_value    jsonb;
    json_path      text[];
    new_obj        jsonb;
    res            jsonb;

BEGIN

    class := data->>'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

    objid := (data->>'GUID')::uuid;
    IF (objid IS NULL) THEN
        RAISE EXCEPTION 'There is no GUID';
    END IF;

    SELECT v.data
	FROM reclada.v_active_object v
	WHERE v.obj_id = objid
	INTO obj;

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

    field := data->>'field';
    IF (field IS NULL) THEN
        RAISE EXCEPTION 'There is no field';
    END IF;
    json_path := format('{attributes, %s}', field);
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
$$;


--
-- Name: list_drop(jsonb); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.list_drop(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    class           text;
    objid           uuid;
    obj             jsonb;
    values_to_drop  jsonb;
    field           text;
    field_value     jsonb;
    json_path       text[];
    new_value       jsonb;
    new_obj         jsonb;
    res             jsonb;

BEGIN

	class := data->>'class';
	IF (class IS NULL) THEN
		RAISE EXCEPTION 'The reclada object class is not specified';
	END IF;

	objid := (data->>'GUID')::uuid;
	IF (objid IS NULL) THEN
		RAISE EXCEPTION 'The is no GUID';
	END IF;

    SELECT v.data
    FROM reclada.v_active_object v
    WHERE v.obj_id = objid
    INTO obj;

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

	field := data->>'field';
	IF (field IS NULL) THEN
		RAISE EXCEPTION 'There is no field';
	END IF;
	json_path := format('{attributes, %s}', field);
	field_value := obj#>json_path;
	IF (field_value IS NULL OR field_value = 'null'::jsonb) THEN
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
$$;


--
-- Name: list_related(jsonb); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.list_related(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    class          text;
    objid          uuid;
    field          text;
    related_class  text;
    obj            jsonb;
    list_of_ids    jsonb;
    cond           jsonb = '{}'::jsonb;
    order_by       jsonb;
    limit_         text;
    offset_        text;
    res            jsonb;

BEGIN
    class := data->>'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

    objid := (data->>'GUID')::uuid;
    IF (objid IS NULL) THEN
        RAISE EXCEPTION 'The object GUID is not specified';
    END IF;

    field := data->>'field';
    IF (field IS NULL) THEN
        RAISE EXCEPTION 'The object field is not specified';
    END IF;

    related_class := data->>'relatedClass';
    IF (related_class IS NULL) THEN
        RAISE EXCEPTION 'The related class is not specified';
    END IF;

	SELECT v.data
	FROM reclada.v_active_object v
	WHERE v.obj_id = objid
	INTO obj;

    IF (obj IS NULL) THEN
        RAISE EXCEPTION 'There is no object with such id';
    END IF;

    list_of_ids := obj#>(format('{attributes, %s}', field)::text[]);
    IF (list_of_ids IS NULL) THEN
        RAISE EXCEPTION 'The object does not have this field';
    END IF;
    IF (jsonb_typeof(list_of_ids) != 'array') THEN
        list_of_ids := '[]'::jsonb || list_of_ids;
    END IF;

    order_by := data->'orderBy';
    IF (order_by IS NOT NULL) THEN
        cond := cond || (format('{"orderBy": %s}', order_by)::jsonb);
    END IF;

    limit_ := data->>'limit';
    IF (limit_ IS NOT NULL) THEN
        cond := cond || (format('{"limit": "%s"}', limit_)::jsonb);
    END IF;

    offset_ := data->>'offset';
    IF (offset_ IS NOT NULL) THEN
        cond := cond || (format('{"offset": "%s"}', offset_)::jsonb);
    END IF;
    
    IF (list_of_ids = '[]'::jsonb) THEN
        res := '{"number": 0, "objects": []}'::jsonb;
    ELSE
        SELECT reclada_object.list(format(
            '{"class": "%s", "attributes": {}, "GUID": {"operator": "<@", "object": %s}}',
            related_class,
            list_of_ids
            )::jsonb || cond,
            true)
        INTO res;
    END IF;

    RETURN res;

END;
$$;


--
-- Name: refresh_mv(text); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.refresh_mv(class_name text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    CASE class_name
        WHEN 'ObjectStatus' THEN
            REFRESH MATERIALIZED VIEW reclada.v_object_status;
        WHEN 'User' THEN
            REFRESH MATERIALIZED VIEW reclada.v_user;
        WHEN 'jsonschema' THEN
            REFRESH MATERIALIZED VIEW reclada.v_class_lite;
        ELSE
            NULL;
    END CASE;
END;
$$;


--
-- Name: update(jsonb, jsonb); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.update(data jsonb, user_info jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    class_name     text;
    class_uuid     uuid;
    v_obj_id       uuid;
    v_attrs        jsonb;
    schema        jsonb;
    old_obj       jsonb;
    branch        uuid;
    revid         uuid;

BEGIN

    class_name := data->>'class';
    IF (class_name IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;
    class_uuid := reclada.try_cast_uuid(class_name);
    v_obj_id := data->>'GUID';
    IF (v_obj_id IS NULL) THEN
        RAISE EXCEPTION 'Could not update object with no GUID';
    END IF;

    v_attrs := data->'attributes';
    IF (v_attrs IS NULL) THEN
        RAISE EXCEPTION 'The reclada object must have attributes';
    END IF;

    SELECT reclada_object.get_schema(class_name) 
        INTO schema;

    if class_uuid is null then
        SELECT reclada_object.get_schema(class_name) 
            INTO schema;
    else
        select v.data 
            from reclada.v_class v
                where class_uuid = v.obj_id
            INTO schema;
    end if;
    -- TODO: don't allow update jsonschema
    IF (schema IS NULL) THEN
        RAISE EXCEPTION 'No json schema available for %', class_name;
    END IF;

    IF (NOT(public.validate_json_schema(schema->'attributes'->'schema', v_attrs))) THEN
        RAISE EXCEPTION 'JSON invalid: %', v_attrs;
    END IF;

    SELECT 	v.data
        FROM reclada.v_active_object v
	        WHERE v.obj_id = v_obj_id
	    INTO old_obj;

    IF (old_obj IS NULL) THEN
        RAISE EXCEPTION 'Could not update object, no such id';
    END IF;

    branch := data->'branch';
    SELECT reclada_revision.create(user_info->>'sub', branch, v_obj_id) 
        INTO revid;
    
    with t as 
    (
        update reclada.object o
            set status = reclada_object.get_archive_status_obj_id()
                where o.GUID = v_obj_id
                    and status != reclada_object.get_archive_status_obj_id()
                        RETURNING id
    )
    INSERT INTO reclada.object( GUID,
                                class,
                                status,
                                attributes,
                                transaction_id
                              )
        select  v.obj_id,
                (schema->>'GUID')::uuid,
                reclada_object.get_active_status_obj_id(),--status 
                v_attrs || format('{"revision":"%s"}',revid)::jsonb,
                transaction_id
            FROM reclada.v_object v
            JOIN t 
                on t.id = v.id
	            WHERE v.obj_id = v_obj_id;
    PERFORM reclada_object.datasource_insert
            (
                class_name,
                (schema->>'GUID')::uuid,
                v_attrs
            );
    PERFORM reclada_object.refresh_mv(class_name);  
                  
    select v.data 
        FROM reclada.v_active_object v
            WHERE v.obj_id = v_obj_id
        into data;
    PERFORM reclada_notification.send_object_notification('update', data);
    RETURN data;
END;
$$;


--
-- Name: create(character varying, uuid, uuid, bigint); Type: FUNCTION; Schema: reclada_revision; Owner: -
--

CREATE FUNCTION reclada_revision."create"(userid character varying, branch uuid, obj uuid, tran_id bigint DEFAULT reclada.get_transaction_id()) RETURNS uuid
    LANGUAGE sql
    AS $$
    INSERT INTO reclada.object
        (
            class,
            attributes,
            transaction_id
        )
               
        VALUES
        (
            (reclada_object.get_schema('revision')->>'GUID')::uuid,-- class,
            format                    -- attributes
            (                         
                '{
                    "num": %s,
                    "user": "%s",
                    "dateTime": "%s",
                    "branch": "%s"
                }',
                (
                    select count(*) + 1
                        from reclada.object o
                            where o.GUID = obj
                ),
                userid,
                now(),
                branch
            )::jsonb,
            tran_id
        ) RETURNING (GUID)::uuid;
    --nextval('reclada.reclada_revisions'),
$$;


--
-- Name: auth_by_token(character varying); Type: FUNCTION; Schema: reclada_user; Owner: -
--

CREATE FUNCTION reclada_user.auth_by_token(token character varying) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT '{}'::jsonb
$$;


--
-- Name: disable_auth(jsonb); Type: FUNCTION; Schema: reclada_user; Owner: -
--

CREATE FUNCTION reclada_user.disable_auth(data jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM reclada.auth_setting;
END;
$$;


--
-- Name: is_allowed(jsonb, text, text); Type: FUNCTION; Schema: reclada_user; Owner: -
--

CREATE FUNCTION reclada_user.is_allowed(jsonb, text, text) RETURNS boolean
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN TRUE;
END;
$$;


--
-- Name: refresh_jwk(jsonb); Type: FUNCTION; Schema: reclada_user; Owner: -
--

CREATE FUNCTION reclada_user.refresh_jwk(data jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    current_oidc_url VARCHAR;
    new_jwk JSONB;
BEGIN
    SELECT oidc_url INTO current_oidc_url FROM reclada.auth_setting FOR UPDATE;
    new_jwk := reclada_user.get_jwk(current_oidc_url);
    UPDATE reclada.auth_setting SET jwk=new_jwk WHERE oidc_url=current_oidc_url;
END;
$$;


--
-- Name: setup_keycloak(jsonb); Type: FUNCTION; Schema: reclada_user; Owner: -
--

CREATE FUNCTION reclada_user.setup_keycloak(data jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    oidc_url VARCHAR;
    jwk JSONB;
BEGIN
    -- check if allowed?
    oidc_url := format(
        '%s/auth/realms/%s/protocol/openid-connect',
        data->>'baseUrl', data->>'realm'
    );
    jwk := reclada_user.get_jwk(oidc_url);

    DELETE FROM reclada.auth_setting;
    INSERT INTO reclada.auth_setting
        (oidc_url, oidc_client_id, oidc_redirect_url, jwk)
    VALUES
        (oidc_url, data->>'clientId', data->>'redirectUrl', jwk);
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: t_dbg; Type: TABLE; Schema: dev; Owner: -
--

CREATE TABLE dev.t_dbg (
    id integer NOT NULL,
    msg text NOT NULL,
    time_when timestamp with time zone DEFAULT now()
);


--
-- Name: t_dbg_id_seq; Type: SEQUENCE; Schema: dev; Owner: -
--

ALTER TABLE dev.t_dbg ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME dev.t_dbg_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: ver; Type: TABLE; Schema: dev; Owner: -
--

CREATE TABLE dev.ver (
    id integer NOT NULL,
    ver integer NOT NULL,
    ver_str text,
    upgrade_script text NOT NULL,
    downgrade_script text NOT NULL,
    run_at timestamp with time zone DEFAULT now()
);


--
-- Name: ver_id_seq; Type: SEQUENCE; Schema: dev; Owner: -
--

ALTER TABLE dev.ver ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME dev.ver_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: auth_setting; Type: TABLE; Schema: reclada; Owner: -
--

CREATE TABLE reclada.auth_setting (
    oidc_url character varying,
    oidc_client_id character varying,
    oidc_redirect_url character varying,
    jwk jsonb
);


--
-- Name: object; Type: TABLE; Schema: reclada; Owner: -
--

CREATE TABLE reclada.object (
    id bigint NOT NULL,
    status uuid DEFAULT reclada_object.get_active_status_obj_id() NOT NULL,
    attributes jsonb NOT NULL,
    transaction_id bigint NOT NULL,
    created_time timestamp with time zone DEFAULT now(),
    created_by uuid DEFAULT reclada_object.get_default_user_obj_id(),
    class uuid NOT NULL,
    guid uuid DEFAULT public.uuid_generate_v4() NOT NULL
);


--
-- Name: object_id_seq; Type: SEQUENCE; Schema: reclada; Owner: -
--

ALTER TABLE reclada.object ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME reclada.object_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: staging; Type: VIEW; Schema: reclada; Owner: -
--

CREATE VIEW reclada.staging AS
 SELECT '{}'::jsonb AS data
  WHERE false;


--
-- Name: transaction_id; Type: SEQUENCE; Schema: reclada; Owner: -
--

CREATE SEQUENCE reclada.transaction_id
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: v_class_lite; Type: MATERIALIZED VIEW; Schema: reclada; Owner: -
--

CREATE MATERIALIZED VIEW reclada.v_class_lite AS
 SELECT obj.id,
    obj.guid AS obj_id,
    (obj.attributes ->> 'forClass'::text) AS for_class,
    ((obj.attributes ->> 'version'::text))::bigint AS version,
    obj.created_time,
    obj.attributes,
    obj.status
   FROM reclada.object obj
  WHERE (obj.class = reclada_object.get_jsonschema_guid())
  WITH NO DATA;


--
-- Name: v_object_status; Type: MATERIALIZED VIEW; Schema: reclada; Owner: -
--

CREATE MATERIALIZED VIEW reclada.v_object_status AS
 SELECT obj.id,
    obj.guid AS obj_id,
    (obj.attributes ->> 'caption'::text) AS caption,
    obj.created_time,
    obj.attributes AS attrs
   FROM reclada.object obj
  WHERE (obj.class IN ( SELECT reclada_object.get_guid_for_class('ObjectStatus'::text) AS get_guid_for_class))
  WITH NO DATA;


--
-- Name: v_user; Type: MATERIALIZED VIEW; Schema: reclada; Owner: -
--

CREATE MATERIALIZED VIEW reclada.v_user AS
 SELECT obj.id,
    obj.guid AS obj_id,
    (obj.attributes ->> 'login'::text) AS login,
    obj.created_time,
    obj.attributes AS attrs
   FROM reclada.object obj
  WHERE ((obj.class IN ( SELECT reclada_object.get_guid_for_class('User'::text) AS get_guid_for_class)) AND (obj.status = reclada_object.get_active_status_obj_id()))
  WITH NO DATA;


--
-- Name: v_object; Type: VIEW; Schema: reclada; Owner: -
--

CREATE VIEW reclada.v_object AS
 WITH t AS (
         SELECT obj.id,
            obj.guid,
            obj.class,
            r.num,
            (NULLIF((obj.attributes ->> 'revision'::text), ''::text))::uuid AS revision,
            obj.attributes,
            obj.status,
            obj.created_time,
            obj.created_by,
            obj.transaction_id
           FROM (reclada.object obj
             LEFT JOIN ( SELECT ((r_1.attributes ->> 'num'::text))::bigint AS num,
                    r_1.guid
                   FROM reclada.object r_1
                  WHERE (r_1.class IN ( SELECT reclada_object.get_guid_for_class('revision'::text) AS get_guid_for_class))) r ON ((r.guid = (NULLIF((obj.attributes ->> 'revision'::text), ''::text))::uuid)))
        )
 SELECT t.id,
    t.guid AS obj_id,
    t.class,
    t.num AS revision_num,
    os.caption AS status_caption,
    t.revision,
    t.created_time,
    t.attributes AS attrs,
    cl.for_class AS class_name,
    (( SELECT (json_agg(tmp.*) -> 0)
           FROM ( SELECT t.guid AS "GUID",
                    t.class,
                    os.caption AS status,
                    t.attributes,
                    t.transaction_id AS "transactionID") tmp))::jsonb AS data,
    u.login AS login_created_by,
    t.created_by,
    t.status,
    t.transaction_id
   FROM (((t
     LEFT JOIN reclada.v_object_status os ON ((t.status = os.obj_id)))
     LEFT JOIN reclada.v_user u ON ((u.obj_id = t.created_by)))
     LEFT JOIN reclada.v_class_lite cl ON ((cl.obj_id = t.class)));


--
-- Name: v_active_object; Type: VIEW; Schema: reclada; Owner: -
--

CREATE VIEW reclada.v_active_object AS
 SELECT t.id,
    t.obj_id,
    t.class,
    t.revision_num,
    t.status,
    t.status_caption,
    t.revision,
    t.created_time,
    t.class_name,
    t.attrs,
    t.data,
    t.transaction_id
   FROM reclada.v_object t
  WHERE (t.status = reclada_object.get_active_status_obj_id());


--
-- Name: v_class; Type: VIEW; Schema: reclada; Owner: -
--

CREATE VIEW reclada.v_class AS
 SELECT obj.id,
    obj.obj_id,
    (obj.attrs ->> 'forClass'::text) AS for_class,
    ((obj.attrs ->> 'version'::text))::bigint AS version,
    obj.revision_num,
    obj.status_caption,
    obj.revision,
    obj.created_time,
    obj.attrs,
    obj.status,
    obj.data
   FROM reclada.v_active_object obj
  WHERE (obj.class_name = 'jsonschema'::text);


--
-- Name: v_import_info; Type: VIEW; Schema: reclada; Owner: -
--

CREATE VIEW reclada.v_import_info AS
 SELECT obj.id,
    obj.obj_id AS guid,
    ((obj.attrs ->> 'tranID'::text))::bigint AS tran_id,
    (obj.attrs ->> 'name'::text) AS name,
    obj.revision_num,
    obj.status_caption,
    obj.revision,
    obj.created_time,
    obj.attrs,
    obj.status,
    obj.data
   FROM reclada.v_active_object obj
  WHERE (obj.class_name = 'ImportInfo'::text);


--
-- Name: v_pk_for_class; Type: VIEW; Schema: reclada; Owner: -
--

CREATE VIEW reclada.v_pk_for_class AS
 SELECT obj.obj_id AS guid,
    obj.for_class,
    pk.pk
   FROM (reclada.v_class obj
     JOIN ( SELECT 'File'::text AS class_name,
            'uri'::text AS pk) pk ON ((pk.class_name = obj.for_class)));


--
-- Name: v_revision; Type: VIEW; Schema: reclada; Owner: -
--

CREATE VIEW reclada.v_revision AS
 SELECT obj.id,
    obj.obj_id,
    ((obj.attrs ->> 'num'::text))::bigint AS num,
    (obj.attrs ->> 'branch'::text) AS branch,
    (obj.attrs ->> 'user'::text) AS "user",
    (obj.attrs ->> 'dateTime'::text) AS date_time,
    (obj.attrs ->> 'old_num'::text) AS old_num,
    obj.revision_num,
    obj.status_caption,
    obj.revision,
    obj.created_time,
    obj.attrs,
    obj.status,
    obj.data
   FROM reclada.v_active_object obj
  WHERE (obj.class_name = 'revision'::text);


--
-- Data for Name: t_dbg; Type: TABLE DATA; Schema: dev; Owner: -
--

COPY dev.t_dbg (id, msg, time_when) FROM stdin;
\.


--
-- Data for Name: ver; Type: TABLE DATA; Schema: dev; Owner: -
--

COPY dev.ver (id, ver, ver_str, upgrade_script, downgrade_script, run_at) FROM stdin;
1	0	0	select public.raise_exception ('This is 0 version');	select public.raise_exception ('This is 0 version');	2021-09-22 14:50:17.832813+00
2	1	\N	begin;\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 1 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select \t'drop '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n' as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.str = tmp.str \n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n\tyou can use "i 'function/reclada_object.get_schema.sql'"\n\tto run text script of functions\n*/\nCREATE EXTENSION IF NOT EXISTS aws_lambda CASCADE;\ni 'function/api.storage_generate_presigned_get.sql'\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\nDROP EXTENSION IF EXISTS aws_lambda CASCADE;\ndrop function IF EXISTS api.storage_generate_presigned_get ;\nCREATE OR REPLACE FUNCTION api.storage_generate_presigned_get(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    credentials  jsonb;\r\n    object_data  jsonb;\r\n    object_id    uuid;\r\n    result       jsonb;\r\n    user_info    jsonb;\r\nBEGIN\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned post', '{}'))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';\r\n    END IF;\r\n\r\n    SELECT reclada_object.list('{"class": "S3Config", "attrs": {}}')::jsonb -> 0 INTO credentials;\r\n\r\n    -- TODO: check user's permissions for reclada object access?\r\n    object_id := data->>'objectId';\r\n    SELECT reclada_object.list(format(\r\n        '{"class": "File", "attrs": {}, "id": "%s"}',\r\n        object_id\r\n    )::jsonb) -> 0 INTO object_data;\r\n\r\n    SELECT reclada_storage.s3_generate_presigned_get(credentials, object_data) INTO result;\r\n    RETURN result;\r\nEND;\r\n$function$\n	2021-09-22 14:50:40.276561+00
3	2	\N	begin;\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 2 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select \t'drop '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n' as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.str = tmp.str \n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n\tyou can use "i 'function/reclada_object.get_schema.sql'"\n\tto run text script of functions\n*/\nCREATE EXTENSION IF NOT EXISTS aws_lambda CASCADE;\ni 'function/api.storage_generate_presigned_get.sql'\ni 'function/api.storage_generate_presigned_post.sql'\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\nDROP EXTENSION IF EXISTS aws_lambda CASCADE;\ndrop function IF EXISTS api.storage_generate_presigned_get ;\nCREATE OR REPLACE FUNCTION api.storage_generate_presigned_get(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    credentials  jsonb;\r\n    object_data  jsonb;\r\n    object_id    uuid;\r\n    result       jsonb;\r\n    user_info    jsonb;\r\nBEGIN\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned post', '{}'))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';\r\n    END IF;\r\n\r\n    SELECT reclada_object.list('{"class": "S3Config", "attrs": {}}')::jsonb -> 0 INTO credentials;\r\n\r\n    -- TODO: check user's permissions for reclada object access?\r\n    object_id := data->>'objectId';\r\n    SELECT reclada_object.list(format(\r\n        '{"class": "File", "attrs": {}, "id": "%s"}',\r\n        object_id\r\n    )::jsonb) -> 0 INTO object_data;\r\n\r\n    SELECT payload\r\n    FROM aws_lambda.invoke(\r\n        aws_commons.create_lambda_function_arn(\r\n            's3_get_presigned_url_dev1',\r\n            'eu-west-1'\r\n            ),\r\n        format('{"uri": "%s", "expiration": 3600}', object_data->'attrs'->> 'uri')::jsonb)\r\n    INTO result;\r\n    RETURN result;\r\nEND;\r\n$function$\n	2021-09-22 14:50:43.856449+00
4	3	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 3 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select \t'drop '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n' as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.str = tmp.str \n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/public.try_cast_int.sql'\n\n\n-- create table reclada.object_status\n-- (\n--     id      bigint GENERATED ALWAYS AS IDENTITY primary KEY,\n--     caption text not null\n-- );\nSELECT reclada_object.create_subclass('{\n    "class": "RecladaObject",\n    "attrs": {\n        "newClass": "ObjectStatus",\n        "properties": {\n            "caption": {"type": "string"}\n        },\n        "required": ["caption"]\n    }\n}'::jsonb);\n-- insert into reclada.object_status(caption)\n--     select 'active';\nSELECT reclada_object.create('{\n    "class": "ObjectStatus",\n    "attrs": {\n        "caption": "active"\n    }\n}'::jsonb);\n-- insert into reclada.object_status(caption)\n--     select 'archive';\nSELECT reclada_object.create('{\n    "class": "ObjectStatus",\n    "attrs": {\n        "caption": "archive"\n    }\n}'::jsonb);\n\nSELECT reclada_object.create_subclass('{\n    "class": "RecladaObject",\n    "attrs": {\n        "newClass": "User",\n        "properties": {\n            "login": {"type": "string"}\n        },\n        "required": ["login"]\n    }\n}'::jsonb);\nSELECT reclada_object.create('{\n    "class": "User",\n    "attrs": {\n        "login": "dev"\n    }\n}'::jsonb);\n\n\n\n--SHOW search_path;        \nSET search_path TO public;\nDROP EXTENSION IF EXISTS "uuid-ossp";\nCREATE EXTENSION "uuid-ossp" SCHEMA public;\n\nalter table reclada.object\n    add id bigint GENERATED ALWAYS AS IDENTITY primary KEY,\n    add obj_id       uuid   default public.uuid_generate_v4(),\n    add revision     uuid   ,\n    add obj_id_int   int    ,\n    add revision_int bigint ,\n    add class        text   ,\n    add status       uuid   ,--DEFAULT reclada_object.get_active_status_obj_id(),\n    add attributes   jsonb  ,\n    add transaction_id bigint ,\n    add created_time timestamp with time zone DEFAULT now(),\n    add created_by   uuid  ;--DEFAULT reclada_object.get_default_user_obj_id();\n\ndrop VIEW if EXISTS reclada.v_class;\ndrop VIEW if EXISTS reclada.v_object_status;\n\ni 'view/reclada.v_object_status.sql'\ni 'function/reclada_object.get_active_status_obj_id.sql'\ni 'function/reclada_object.get_archive_status_obj_id.sql'\n\nupdate reclada.object \n    set class      = data->>'class',\n        attributes = data->'attrs' ;\nupdate reclada.object \n    set obj_id_int = public.try_cast_int(data->>'id'),\n        revision_int  = (data->'revision')::bigint   \n        -- status  = (data->'isDeleted')::boolean::int+1,\n        ;\nupdate reclada.object \n    set obj_id = (data->>'id')::uuid\n        WHERE obj_id_int is null;\n\nupdate reclada.object \n    set status  = \n        case coalesce((data->'isDeleted')::boolean::int+1,1)\n            when 1 \n                then reclada_object.get_active_status_obj_id()\n            else reclada_object.get_archive_status_obj_id()\n        end;\n\ni 'view/reclada.v_user.sql'\ni 'view/reclada.v_object.sql'\ni 'view/reclada.v_active_object.sql'\ni 'function/reclada_object.get_default_user_obj_id.sql'\n\nalter table reclada.object\n    alter COLUMN status \n        set DEFAULT reclada_object.get_active_status_obj_id(),\n    alter COLUMN created_by \n        set DEFAULT reclada_object.get_default_user_obj_id();\n\nupdate reclada.object set created_by = reclada_object.get_default_user_obj_id();\n\n-- проверим, что числовой id только для ревизий\nselect public.raise_exception('exist numeric id for other class!!!')\n    where exists\n    (\n        select 1 \n            from reclada.object \n                where obj_id_int is not null \n                    and class != 'revision'\n    );\n\nupdate reclada.object -- проставим статус, тем у кого он отсутствует\n    set status = reclada_object.get_active_status_obj_id()\n        WHERE status is null;\n\n\n-- генерируем obj_id для объектов ревизий \nupdate reclada.object as o\n    set obj_id = g.obj_id\n    from \n    (\n        select  g.obj_id_int ,\n                public.uuid_generate_v4() as obj_id\n            from reclada.object g\n            GROUP BY g.obj_id_int\n            HAVING g.obj_id_int is not NULL\n    ) g\n        where g.obj_id_int = o.obj_id_int;\n\n-- заносим номер ревизии в attrs\nupdate reclada.object o\n    set attributes = o.attributes \n                || jsonb ('{"num":'|| \n                    (\n                        select count(1)+1 \n                            from reclada.object c\n                                where c.obj_id = o.obj_id \n                                    and c.obj_id_int< o.obj_id_int\n                    )::text ||'}')\n                -- запомним старый номер ревизии на всякий случай\n                || jsonb ('{"old_num":'|| o.obj_id_int::text ||'}')\n        where o.obj_id_int is not null;\n\n-- обновляем ссылки на ревизию \nupdate reclada.object as o\n    set revision = g.obj_id\n    from \n    (\n        select  g.obj_id_int ,\n                g.obj_id\n            from reclada.object g\n            GROUP BY    g.obj_id_int ,\n                        g.obj_id\n            HAVING g.obj_id_int is not NULL\n    ) g\n        where o.revision_int = g.obj_id_int;\nalter table reclada.object alter column data drop not null;\n\nalter table reclada.object \n    alter column attributes set not null,\n    alter column class set not null,\n    alter column status set not null,\n    alter column obj_id set not null;\n\n-- delete from reclada.object where attrs is null\n\ni 'view/reclada.v_class.sql'\ni 'view/reclada.v_revision.sql'\ni 'function/reclada.datasource_insert_trigger_fnc.sql'\ni 'function/reclada_object.get_schema.sql'\ni 'function/reclada.load_staging.sql'\ni 'function/reclada_object.create.sql'\ni 'function/reclada_object.delete.sql'\ni 'function/reclada_object.update.sql'\ni 'function/reclada_object.list.sql'\ni 'function/reclada_revision.create.sql'\n\n\n-- удалим вспомагательные столбцы\nalter table reclada.object\n    drop column revision_int,\n    drop column data,\n    drop column obj_id_int;\n\n\n--{ indexes\nDROP INDEX IF EXISTS reclada.class_index;\nCREATE INDEX class_index \n\tON reclada.object(class);\n\nDROP INDEX IF EXISTS reclada.obj_id_index;\nCREATE INDEX obj_id_index \n\tON reclada.object(obj_id);\n\nDROP INDEX IF EXISTS reclada.revision_index;\nCREATE INDEX revision_index \n\tON reclada.object(revision);\n\nDROP INDEX IF EXISTS reclada.status_index;\nCREATE INDEX status_index \n\tON reclada.object(status);\n\nDROP INDEX IF EXISTS reclada.job_status_index;\nCREATE INDEX job_status_index \n\tON reclada.object((attributes->'status'))\n\tWHERE class = 'Job';\n\nDROP INDEX IF EXISTS reclada.runner_status_index;\nCREATE INDEX runner_status_index\n\tON reclada.object((attributes->'status'))\n\tWHERE class = 'Runner';\n\nDROP INDEX IF EXISTS reclada.runner_type_index;\nCREATE INDEX runner_type_index \n\tON reclada.object((attributes->'type'))\n\tWHERE class = 'Runner';\n--} indexes\n\nupdate reclada.object o \n    set attributes = o.attributes || format('{"revision":"%s"}',o.revision)::jsonb\n        where o.revision is not null;\n\nalter table reclada.object\n    drop COLUMN revision;\n\n\ni 'function/reclada_notification.send_object_notification.sql'\ni 'function/reclada_object.list_add.sql'\ni 'function/reclada_object.list_drop.sql'\ni 'function/reclada_object.list_related.sql'\ni 'function/api.reclada_object_create.sql'\ni 'function/api.reclada_object_delete.sql'\ni 'function/api.reclada_object_list.sql'\ni 'function/api.reclada_object_list_add.sql'\ni 'function/api.reclada_object_list_drop.sql'\ni 'function/api.reclada_object_list_related.sql'\ni 'function/api.storage_generate_presigned_get.sql'\n\n\n--select dlkfmdlknfal();\n\n-- test 1\n-- select reclada_revision.create('123', null,'e2bdd471-cf23-46a9-84cf-f9e15db7887d')\n-- SELECT reclada_object.create('\n--   {\n--        "class": "Job",\n--        "revision": 10,\n--        "attrs": {\n--            "task": "c94bff30-15fa-427f-9954-d5c3c151e652",\n--            "status": "new",\n--            "type": "K8S",\n--            "command": "./run_pipeline.sh",\n--            "inputParameters": [{"uri": "%s"}, {"dataSourceId": "%s"}]\n--            }\n--        }'::jsonb);\n--\n-- SELECT reclada_object.update('\n--   {\n--      "id": "f47596e6-3117-419e-ab6d-2174f0ebf471",\n-- \t \t"class": "Job",\n--        "attrs": {\n--            "task": "c94bff30-15fa-427f-9954-d5c3c151e652",\n--            "status": "new",\n--            "type": "K8S",\n--            "command": "./run_pipeline.sh",\n--            "inputParameters": [{"uri": "%s"}, {"dataSourceId": "%s"}]\n--            }\n--        }'::jsonb);\n\n-- SELECT reclada_object.delete( '{\n--       "id": "6cff152e-8391-4997-8134-8257e2717ac4"}')\n\n\n--select count(1)+1 \n--                        from reclada.object o\n--                            where o.obj_id = 'e2bdd471-cf23-46a9-84cf-f9e15db7887d'\n--\n--SELECT * FROM reclada.v_revision ORDER BY ID DESC -- 77\n--    LIMIT 300\n-- insert into staging\n--\tselect '{"id": "feb80c85-b0a7-40f8-864a-c874ff919bd1", "attrs": {"name": "Tmtagg tes2t f1ile.xlsx"}, "class": "Document", "fileId": "25ca0de7-e5b5-45f3-a368-788fe7eaecf8"}'\n\n-- select reclada_object.get_schema('Job')\n--update\n-- +"reclada_object.list"\n-- + "reclada_object.update"\n-- + "reclada_object.delete"\n-- + "reclada_object.create"\n-- + "reclada.load_staging"\n-- + "reclada_object.get_schema"\n-- + "reclada_revision.create"\n\n-- test\n-- + reclada.datasource_insert_trigger_fnc\n-- + reclada.load_staging\n-- + reclada_object.list\n-- + reclada_object.get_schema\n-- + reclada_object.delete\n-- + reclada_object.create\n-- + reclada_object.update\n-- + reclada_revision.create\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect public.raise_exception('Downgrade script not support');\n	2021-09-22 14:50:50.411942+00
5	4	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 4 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select \t'drop '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n' as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.str = tmp.str \n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/reclada.datasource_insert_trigger_fnc.sql'\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect public.raise_exception('Downgrade script not support');\n	2021-09-22 14:51:02.230956+00
6	5	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 5 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select \t'drop '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n' as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.str = tmp.str \n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/reclada_object.delete.sql'\ni 'function/reclada_object.list_add.sql'\ni 'function/reclada_object.list_drop.sql'\ni 'function/reclada_object.list_related.sql'\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect public.raise_exception('Downgrade script not support');\n	2021-09-22 14:51:05.402513+00
7	6	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 6 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select \t'drop '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n' as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.str = tmp.str \n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/reclada_object.list.sql'\ni 'function/reclada_object.list_related.sql'\ni 'function/api.reclada_object_list.sql'\ni 'function/api.reclada_object_list_related.sql'\ni 'reclada.datasource_insert_trigger_fnc.sql'\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect public.raise_exception('Downgrade script not support');\n	2021-09-22 14:51:09.193017+00
28	27	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect reclada.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 27 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\nDELETE FROM reclada.object\nWHERE GUID IS NULL;\n\nALTER TABLE reclada.object\n    ALTER COLUMN GUID SET NOT NULL;\nALTER TABLE reclada.object\n    ALTER GUID SET DEFAULT public.uuid_generate_v4();\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect reclada.raise_exception('Downgrade script not support');	2021-09-22 14:52:40.006303+00
8	7	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 7 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select \t'drop '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n' as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.str = tmp.str \n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/reclada_object.list.sql'\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect public.raise_exception('Downgrade script not support');\n	2021-09-22 14:51:12.92018+00
9	8	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 8 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\nDROP TRIGGER IF EXISTS datasource_insert_trigger ON reclada.object;\nCREATE TRIGGER datasource_insert_trigger\n  BEFORE INSERT\n  ON reclada.object FOR EACH ROW\n  EXECUTE PROCEDURE reclada.datasource_insert_trigger_fnc();\n\n/*\n    if we use AFTER trigger \n    code from reclada_object.create:\n        with inserted as \n        (\n            INSERT INTO reclada.object(class,attributes)\n                select class, attrs\n                    RETURNING obj_id\n        ) \n        insert into tmp(id)\n            select obj_id \n                from inserted;\n    twice returns obj_id for object which created from trigger (Job).\n    \n    As result query:\n        SELECT reclada_object.create('{"id": "", "class": "File", \n\t\t\t\t\t\t\t \t"attrs":{\n\t\t\t\t\t\t\t \t\t"name": "SCkyqZSNmCFlWxPNSHWl", \n\t\t\t\t\t\t\t\t \t"checksum": "", \n\t\t\t\t\t\t\t\t \t"mimeType": "application/pdf", \n\t\t\t\t\t\t\t \t\t"uri": "s3://test-reclada-bucket/inbox/SCkyqZSNmCFlWxPNSHWl"\n\t\t\t\t\t\t\t }\n\t\t\t\t\t\t\t }', null);\n    selects only Job object.\n*/\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\n--select public.raise_exception('Downgrade script not support');\nDROP function IF EXISTS dev.downgrade_version ;\nCREATE OR REPLACE FUNCTION dev.downgrade_version()\n RETURNS void\n LANGUAGE plpgsql\nAS $function$\r\ndeclare \r\n    current_ver int; \r\n    downgrade_script text;\r\n    v_state   TEXT;\r\n    v_msg     TEXT;\r\n    v_detail  TEXT;\r\n    v_hint    TEXT;\r\n    v_context TEXT;\r\nBEGIN\r\n\r\n    select max(ver) \r\n        from dev.VER\r\n    into current_ver;\r\n    \r\n    select v.downgrade_script \r\n        from dev.VER v\r\n            WHERE current_ver = v.ver\r\n        into downgrade_script;\r\n\r\n    if COALESCE(downgrade_script,'') = '' then\r\n        RAISE EXCEPTION 'downgrade_script is empty! from dev.downgrade_version()';\r\n    end if;\r\n\r\n    EXECUTE downgrade_script;\r\n\r\n    -- mark, that chanches applied\r\n    delete \r\n        from dev.VER v\r\n            where v.ver = current_ver;\r\n\r\n    v_msg = 'OK, curren version: ' || (current_ver-1)::text;\r\n    perform public.raise_notice(v_msg);\r\nEXCEPTION when OTHERS then \r\n\tget stacked diagnostics\r\n        v_state   = returned_sqlstate,\r\n        v_msg     = message_text,\r\n        v_detail  = pg_exception_detail,\r\n        v_hint    = pg_exception_hint,\r\n        v_context = pg_exception_context;\r\n\r\n    v_state := format('Got exception:\r\nstate   : %s\r\nmessage : %s\r\ndetail  : %s\r\nhint    : %s\r\ncontext : %s\r\nSQLSTATE: %s\r\nSQLERRM : %s', \r\n                v_state, \r\n                v_msg, \r\n                v_detail, \r\n                v_hint, \r\n                v_context,\r\n                SQLSTATE,\r\n                SQLERRM);\r\n    perform dev.reg_notice(v_state);\r\nEND\r\n$function$\n;\n\n	2021-09-22 14:51:16.142437+00
10	9	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 9 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\ni 'function/dev.downgrade_version.sql'\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nDROP function IF EXISTS dev.downgrade_version ;\nCREATE OR REPLACE FUNCTION dev.downgrade_version()\n RETURNS void\n LANGUAGE plpgsql\nAS $function$\r\ndeclare \r\n    current_ver int; \r\n    downgrade_script text;\r\n    v_state   TEXT;\r\n    v_msg     TEXT;\r\n    v_detail  TEXT;\r\n    v_hint    TEXT;\r\n    v_context TEXT;\r\nBEGIN\r\n\r\n    select max(ver) \r\n        from dev.VER\r\n    into current_ver;\r\n    \r\n    select v.downgrade_script \r\n        from dev.VER v\r\n            WHERE current_ver = v.ver\r\n        into downgrade_script;\r\n\r\n    if COALESCE(downgrade_script,'') = '' then\r\n        RAISE EXCEPTION 'downgrade_script is empty! from dev.downgrade_version()';\r\n    end if;\r\n\r\n    EXECUTE downgrade_script;\r\n\r\n    -- mark, that chanches applied\r\n    delete \r\n        from dev.VER v\r\n            where v.ver = current_ver;\r\n\r\n    v_msg = 'OK, curren version: ' || (current_ver-1)::text;\r\n    perform public.raise_notice(v_msg);\r\nEXCEPTION when OTHERS then \r\n\tget stacked diagnostics\r\n        v_state   = returned_sqlstate,\r\n        v_msg     = message_text,\r\n        v_detail  = pg_exception_detail,\r\n        v_hint    = pg_exception_hint,\r\n        v_context = pg_exception_context;\r\n\r\n    v_state := format('Got exception:\r\nstate   : %s\r\nmessage : %s\r\ndetail  : %s\r\nhint    : %s\r\ncontext : %s\r\nSQLSTATE: %s\r\nSQLERRM : %s', \r\n                v_state, \r\n                v_msg, \r\n                v_detail, \r\n                v_hint, \r\n                v_context,\r\n                SQLSTATE,\r\n                SQLERRM);\r\n    perform dev.reg_notice(v_state);\r\nEND\r\n$function$\n;\n\n	2021-09-22 14:51:19.308047+00
11	10	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 10 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\ni 'function/api.storage_generate_presigned_get.sql'\ni 'function/api.storage_generate_presigned_post.sql'\ni 'function/reclada_object.get_condition_array.sql'\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nDROP function IF EXISTS api.storage_generate_presigned_get ;\nCREATE OR REPLACE FUNCTION api.storage_generate_presigned_get(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    credentials  jsonb;\r\n    object_data  jsonb;\r\n    object_id    uuid;\r\n    result       jsonb;\r\n    user_info    jsonb;\r\n\r\nBEGIN\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned post', '{}'))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';\r\n    END IF;\r\n\r\n    SELECT reclada_object.list('{"class": "S3Config", "attrs": {}}')::jsonb -> 0 INTO credentials;\r\n\r\n    -- TODO: check user's permissions for reclada object access?\r\n    object_id := data->>'objectId';\r\n    SELECT reclada_object.list(format(\r\n        '{"class": "File", "attrs": {}, "id": "%s"}',\r\n        object_id\r\n    )::jsonb) -> 0 INTO object_data;\r\n\r\n    SELECT payload\r\n    FROM aws_lambda.invoke(\r\n        aws_commons.create_lambda_function_arn(\r\n            's3_get_presigned_url_dev1',\r\n            'eu-west-1'\r\n            ),\r\n        format('{\r\n            "type": "get",\r\n            "uri": "%s",\r\n            "expiration": 3600}',\r\n            object_data->'attrs'->>'uri'\r\n            )::jsonb)\r\n    INTO result;\r\n\r\n    RETURN result;\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS api.storage_generate_presigned_post ;\nCREATE OR REPLACE FUNCTION api.storage_generate_presigned_post(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    bucket_name  varchar;\r\n    credentials  jsonb;\r\n    file_type    varchar;\r\n    object       jsonb;\r\n    object_id    uuid;\r\n    object_name  varchar;\r\n    object_path  varchar;\r\n    result       jsonb;\r\n    user_info    jsonb;\r\n    uri          varchar;\r\n    url          varchar;\r\n\r\nBEGIN\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned post', '{}'))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';\r\n    END IF;\r\n\r\n    SELECT reclada_object.list('{"class": "S3Config", "attrs": {}}')::jsonb -> 0 INTO credentials;\r\n\r\n    object_name := data->>'objectName';\r\n    file_type := data->>'fileType';\r\n    bucket_name := credentials->'attrs'->>'bucketName';\r\n    SELECT uuid_generate_v4() INTO object_id;\r\n    object_path := object_id;\r\n    uri := 's3://' || bucket_name || '/' || object_path;\r\n\r\n    -- TODO: remove checksum from required attrs for File class?\r\n    SELECT reclada_object.create(format(\r\n        '{"class": "File", "attrs": {"name": "%s", "mimeType": "%s", "uri": "%s", "checksum": "tempChecksum"}}',\r\n        object_name,\r\n        file_type,\r\n        uri\r\n    )::jsonb)->0 INTO object;\r\n\r\n    --data := data || format('{"objectPath": "%s"}', object_path)::jsonb;\r\n    --SELECT reclada_storage.s3_generate_presigned_post(data, credentials)::jsonb INTO url;\r\n    SELECT payload::jsonb\r\n    FROM aws_lambda.invoke(\r\n        aws_commons.create_lambda_function_arn(\r\n            's3_get_presigned_url_dev1',\r\n            'eu-west-1'\r\n            ),\r\n        format('{\r\n            "type": "post",\r\n            "bucketName": "%s",\r\n            "fileName": "%s",\r\n            "fileType": "%s",\r\n            "fileSize": "%s",\r\n            "expiration": 3600}',\r\n            bucket_name,\r\n            object_name,\r\n            file_type,\r\n            data->>'fileSize'\r\n            )::jsonb)\r\n    INTO url;\r\n\r\n    result = format(\r\n        '{"object": %s, "uploadUrl": %s}',\r\n        object,\r\n        url\r\n    )::jsonb;\r\n\r\n    RETURN result;\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.get_condition_array ;\nCREATE OR REPLACE FUNCTION reclada_object.get_condition_array(data jsonb, key_path text)\n RETURNS text\n LANGUAGE sql\n IMMUTABLE\nAS $function$\r\n    SELECT\r\n    CONCAT(\r\n        key_path,\r\n        ' ', data->>'operator', ' ',\r\n        format(E'\\'%s\\'::jsonb', data->'object'#>>'{}'))\r\n$function$\n;\n	2021-09-22 14:51:22.336077+00
12	11	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 11 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ndrop VIEW if EXISTS reclada.v_revision;\ndrop VIEW if EXISTS reclada.v_class;\ndrop VIEW if EXISTS v_active_object;\ni 'view/reclada.v_object.sql'\ni 'view/reclada.v_active_object.sql'\ni 'view/reclada.v_class.sql'\ni 'view/reclada.v_revision.sql'\n\ni 'function/api.reclada_object_create.sql'\ni 'function/api.reclada_object_list.sql'\ni 'function/api.reclada_object_update.sql'\ni 'function/api.storage_generate_presigned_post.sql'\ni 'function/api.storage_generate_presigned_get.sql'\ni 'function/reclada_notification.send_object_notification.sql'\ni 'function/reclada_object.cast_jsonb_to_postgres.sql'\ni 'function/reclada_object.create_subclass.sql'\ni 'function/reclada_object.create.sql'\ni 'function/reclada_object.get_query_condition.sql'\ni 'function/reclada_object.list_add.sql'\ni 'function/reclada_object.list_drop.sql'\ni 'function/reclada_object.list_related.sql'\ni 'function/reclada_object.list.sql'\ni 'function/reclada_object.update.sql'\ni 'function/reclada_revision.create.sql'\ni 'function/reclada.datasource_insert_trigger_fnc.sql'\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\ndrop VIEW if EXISTS reclada.v_revision;\ndrop VIEW if EXISTS reclada.v_class;\ndrop VIEW if EXISTS v_active_object;\nDROP view IF EXISTS reclada.v_object ;\nCREATE OR REPLACE VIEW reclada.v_object\nAS\n WITH t AS (\n         SELECT obj.id,\n            obj.obj_id,\n            obj.class,\n            r.num,\n            NULLIF(obj.attributes ->> 'revision'::text, ''::text)::uuid AS revision,\n            obj.attributes AS attrs,\n            obj.status,\n            obj.created_time,\n            obj.created_by\n           FROM object obj\n             LEFT JOIN ( SELECT (r_1.attributes -> 'num'::text)::bigint AS num,\n                    r_1.obj_id\n                   FROM object r_1\n                  WHERE r_1.class = 'revision'::text) r ON r.obj_id = NULLIF(obj.attributes ->> 'revision'::text, ''::text)::uuid\n        )\n SELECT t.id,\n    t.obj_id,\n    t.class,\n    t.num AS revision_num,\n    os.caption AS status_caption,\n    t.revision,\n    t.created_time,\n    t.attrs,\n    format('{\r\n                    "id": "%s",\r\n                    "class": "%s",\r\n                    "revision": %s, \r\n                    "status": "%s",\r\n                    "attrs": %s\r\n                }'::text, t.obj_id, t.class, COALESCE(('"'::text || t.revision::text) || '"'::text, 'null'::text), os.caption, t.attrs)::jsonb AS data,\n    u.login AS login_created_by,\n    t.created_by,\n    t.status\n   FROM t\n     LEFT JOIN v_object_status os ON t.status = os.obj_id\n     LEFT JOIN v_user u ON u.obj_id = t.created_by;\nDROP view IF EXISTS reclada.v_active_object ;\nCREATE OR REPLACE VIEW reclada.v_active_object\nAS\n SELECT t.id,\n    t.obj_id,\n    t.class,\n    t.revision_num,\n    t.status,\n    t.status_caption,\n    t.revision,\n    t.created_time,\n    t.attrs,\n    t.data\n   FROM v_object t\n  WHERE t.status = reclada_object.get_active_status_obj_id();\nDROP view IF EXISTS reclada.v_class ;\nCREATE OR REPLACE VIEW reclada.v_class\nAS\n SELECT obj.id,\n    obj.obj_id,\n    obj.attrs ->> 'forClass'::text AS for_class,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class = 'jsonschema'::text;\nDROP view IF EXISTS reclada.v_revision ;\nCREATE OR REPLACE VIEW reclada.v_revision\nAS\n SELECT obj.id,\n    obj.obj_id,\n    (obj.attrs ->> 'num'::text)::bigint AS num,\n    obj.attrs ->> 'branch'::text AS branch,\n    obj.attrs ->> 'user'::text AS "user",\n    obj.attrs ->> 'dateTime'::text AS date_time,\n    obj.attrs ->> 'old_num'::text AS old_num,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class = 'revision'::text;\nDROP function IF EXISTS api.reclada_object_create ;\nCREATE OR REPLACE FUNCTION api.reclada_object_create(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    data_jsonb       jsonb;\r\n    class            jsonb;\r\n    user_info        jsonb;\r\n    attrs            jsonb;\r\n    data_to_create   jsonb = '[]'::jsonb;\r\n    result           jsonb;\r\n\r\nBEGIN\r\n\r\n    IF (jsonb_typeof(data) != 'array') THEN\r\n        data := '[]'::jsonb || data;\r\n    END IF;\r\n\r\n    FOR data_jsonb IN SELECT jsonb_array_elements(data) LOOP\r\n\r\n        class := data_jsonb->'class';\r\n        IF (class IS NULL) THEN\r\n            RAISE EXCEPTION 'The reclada object class is not specified';\r\n        END IF;\r\n\r\n        SELECT reclada_user.auth_by_token(data_jsonb->>'accessToken') INTO user_info;\r\n        data_jsonb := data_jsonb - 'accessToken';\r\n\r\n        IF (NOT(reclada_user.is_allowed(user_info, 'create', class))) THEN\r\n            RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'create', class;\r\n        END IF;\r\n\r\n        attrs := data_jsonb->'attrs';\r\n        IF (attrs IS NULL) THEN\r\n            RAISE EXCEPTION 'The reclada object must have attrs';\r\n        END IF;\r\n\r\n        data_to_create := data_to_create || data_jsonb;\r\n    END LOOP;\r\n\r\n    SELECT reclada_object.create(data_to_create, user_info) INTO result;\r\n    RETURN result;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS api.reclada_object_list ;\nCREATE OR REPLACE FUNCTION api.reclada_object_list(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    class               jsonb;\r\n    user_info           jsonb;\r\n    result              jsonb;\r\n\r\nBEGIN\r\n\r\n    class := data->'class';\r\n    IF(class IS NULL) THEN\r\n        RAISE EXCEPTION 'reclada object class not specified';\r\n    END IF;\r\n\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF (NOT(reclada_user.is_allowed(user_info, 'list', class))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'list', class;\r\n    END IF;\r\n\r\n    SELECT reclada_object.list(data, true) INTO result;\r\n\r\n    RETURN result;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS api.reclada_object_update ;\nCREATE OR REPLACE FUNCTION api.reclada_object_update(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    class         jsonb;\r\n    objid         uuid;\r\n    attrs         jsonb;\r\n    user_info     jsonb;\r\n    result        jsonb;\r\n\r\nBEGIN\r\n\r\n    class := data->'class';\r\n    IF (class IS NULL) THEN\r\n        RAISE EXCEPTION 'reclada object class not specified';\r\n    END IF;\r\n\r\n    objid := data->>'id';\r\n    IF (objid IS NULL) THEN\r\n        RAISE EXCEPTION 'Could not update object with no id';\r\n    END IF;\r\n\r\n    attrs := data->'attrs';\r\n    IF (attrs IS NULL) THEN\r\n        RAISE EXCEPTION 'reclada object must have attrs';\r\n    END IF;\r\n\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF (NOT(reclada_user.is_allowed(user_info, 'update', class))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'update', class;\r\n    END IF;\r\n\r\n    SELECT reclada_object.update(data, user_info) INTO result;\r\n    RETURN result;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS api.storage_generate_presigned_post ;\nCREATE OR REPLACE FUNCTION api.storage_generate_presigned_post(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    bucket_name  varchar;\r\n    file_type    varchar;\r\n    object       jsonb;\r\n    object_id    uuid;\r\n    object_name  varchar;\r\n    object_path  varchar;\r\n    result       jsonb;\r\n    user_info    jsonb;\r\n    uri          varchar;\r\n    url          varchar;\r\n\r\nBEGIN\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned post', '{}'))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';\r\n    END IF;\r\n\r\n    object_name := data->>'objectName';\r\n    file_type := data->>'fileType';\r\n    bucket_name := data->>'bucketName';\r\n    SELECT uuid_generate_v4() INTO object_id;\r\n    object_path := object_id;\r\n    uri := 's3://' || bucket_name || '/' || object_path;\r\n\r\n    -- TODO: remove checksum from required attrs for File class?\r\n    SELECT reclada_object.create(format(\r\n        '{"class": "File", "attrs": {"name": "%s", "mimeType": "%s", "uri": "%s", "checksum": "tempChecksum"}}',\r\n        object_name,\r\n        file_type,\r\n        uri\r\n    )::jsonb)->0 INTO object;\r\n\r\n    SELECT payload::jsonb\r\n    FROM aws_lambda.invoke(\r\n        aws_commons.create_lambda_function_arn(\r\n            's3_get_presigned_url_test',\r\n            'eu-west-1'\r\n            ),\r\n        format('{\r\n            "type": "post",\r\n            "bucketName": "%s",\r\n            "fileName": "%s",\r\n            "fileType": "%s",\r\n            "fileSize": "%s",\r\n            "expiration": 3600}',\r\n            bucket_name,\r\n            object_name,\r\n            file_type,\r\n            data->>'fileSize'\r\n            )::jsonb)\r\n    INTO url;\r\n\r\n    result = format(\r\n        '{"object": %s, "uploadUrl": %s}',\r\n        object,\r\n        url\r\n    )::jsonb;\r\n\r\n    RETURN result;\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS api.storage_generate_presigned_get ;\nCREATE OR REPLACE FUNCTION api.storage_generate_presigned_get(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    object_data  jsonb;\r\n    object_id    uuid;\r\n    result       jsonb;\r\n    user_info    jsonb;\r\n\r\nBEGIN\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned post', '{}'))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';\r\n    END IF;\r\n\r\n    -- TODO: check user's permissions for reclada object access?\r\n    object_id := data->>'objectId';\r\n    SELECT reclada_object.list(format(\r\n        '{"class": "File", "attrs": {}, "id": "%s"}',\r\n        object_id\r\n    )::jsonb) -> 0 INTO object_data;\r\n\r\n    SELECT payload\r\n    FROM aws_lambda.invoke(\r\n        aws_commons.create_lambda_function_arn(\r\n            's3_get_presigned_url_test',\r\n            'eu-west-1'\r\n            ),\r\n        format('{\r\n            "type": "get",\r\n            "uri": "%s",\r\n            "expiration": 3600}',\r\n            object_data->'attrs'->>'uri'\r\n            )::jsonb)\r\n    INTO result;\r\n\r\n    RETURN result;\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_notification.send_object_notification ;\nCREATE OR REPLACE FUNCTION reclada_notification.send_object_notification(event character varying, object_data jsonb)\n RETURNS void\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    data            jsonb;\r\n    message         jsonb;\r\n    msg             jsonb;\r\n    object_class    varchar;\r\n    attrs           jsonb;\r\n    query           text;\r\n\r\nBEGIN\r\n\r\n    IF (jsonb_typeof(object_data) != 'array') THEN\r\n        object_data := '[]'::jsonb || object_data;\r\n    END IF;\r\n\r\n    FOR data IN SELECT jsonb_array_elements(object_data) LOOP\r\n        object_class := data ->> 'class';\r\n\r\n        if event is null or object_class is null then\r\n            return;\r\n        end if;\r\n        \r\n        SELECT v.data \r\n            FROM reclada.v_active_object v\r\n                WHERE v.class = 'Message'\r\n                    AND v.attrs->>'event' = event\r\n                    AND v.attrs->>'class' = object_class\r\n        INTO message;\r\n\r\n        IF message IS NULL THEN\r\n            RETURN;\r\n        END IF;\r\n\r\n        query := format(E'select to_json(x) from jsonb_to_record($1) as x(%s)',\r\n            (select string_agg(s::text || ' jsonb', ',') from jsonb_array_elements(message -> 'attrs' -> 'attrs') s));\r\n        execute query into attrs using data -> 'attrs';\r\n\r\n        msg := jsonb_build_object(\r\n            'objectId', data -> 'id',\r\n            'class', object_class,\r\n            'event', event,\r\n            'attrs', attrs\r\n        );\r\n\r\n        perform reclada_notification.send(message #>> '{attrs, channelName}', msg);\r\n\r\n    END LOOP;\r\nEND\r\n$function$\n;\nDROP function IF EXISTS reclada_object.cast_jsonb_to_postgres ;\nCREATE OR REPLACE FUNCTION reclada_object.cast_jsonb_to_postgres(key_path text, type text, type_of_array text DEFAULT 'text'::text)\n RETURNS text\n LANGUAGE sql\n IMMUTABLE\nAS $function$\r\nSELECT\r\n        CASE\r\n            WHEN type = 'string' THEN\r\n                format(E'(%s#>>\\'{}\\')::text', key_path)\r\n            WHEN type = 'number' THEN\r\n                format(E'(%s)::numeric', key_path)\r\n            WHEN type = 'boolean' THEN\r\n                format(E'(%s)::boolean', key_path)\r\n            WHEN type = 'array' THEN\r\n                format(\r\n                    E'ARRAY(SELECT jsonb_array_elements_text(%s)::%s)',\r\n                    key_path,\r\n                     CASE\r\n                        WHEN type_of_array = 'string' THEN 'text'\r\n                        WHEN type_of_array = 'number' THEN 'numeric'\r\n                        WHEN type_of_array = 'boolean' THEN 'boolean'\r\n                     END\r\n                    )\r\n        END\r\n$function$\n;\nDROP function IF EXISTS reclada_object.create_subclass ;\nCREATE OR REPLACE FUNCTION reclada_object.create_subclass(data jsonb)\n RETURNS void\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    class           text;\r\n    attrs           jsonb;\r\n    class_schema    jsonb;\r\n\r\nBEGIN\r\n\r\n    class := data->>'class';\r\n    IF (class IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object class is not specified';\r\n    END IF;\r\n\r\n    attrs := data->'attrs';\r\n    IF (attrs IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object must have attrs';\r\n    END IF;\r\n\r\n    SELECT reclada_object.get_schema(class) INTO class_schema;\r\n    IF (class_schema IS NULL) THEN\r\n        RAISE EXCEPTION 'No json schema available for %', class;\r\n    END IF;\r\n\r\n    class_schema := class_schema->'attrs'->'schema';\r\n\r\n    PERFORM reclada_object.create(format('{\r\n        "class": "jsonschema",\r\n        "attrs": {\r\n            "forClass": "%s",\r\n            "schema": {\r\n                "type": "object",\r\n                "properties": %s,\r\n                "required": %s\r\n                }\r\n            }\r\n        }',\r\n        attrs->>'newClass',\r\n        (class_schema->'properties') || (attrs->'properties'),\r\n        (SELECT jsonb_agg(el) FROM (SELECT DISTINCT pg_catalog.jsonb_array_elements((class_schema -> 'required') || (attrs -> 'required')) el) arr)\r\n    )::jsonb);\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.create ;\nCREATE OR REPLACE FUNCTION reclada_object."create"(data_jsonb jsonb, user_info jsonb DEFAULT '{}'::jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    branch     uuid;\r\n    data       jsonb;\r\n    class      text;\r\n    attrs      jsonb;\r\n    schema     jsonb;\r\n    res        jsonb;\r\n\r\nBEGIN\r\n\r\n    IF (jsonb_typeof(data_jsonb) != 'array') THEN\r\n        data_jsonb := '[]'::jsonb || data_jsonb;\r\n    END IF;\r\n    /*TODO: check if some objects have revision and others do not */\r\n    branch:= data_jsonb->0->'branch';\r\n    create temp table IF NOT EXISTS tmp(id uuid)\r\n    ON COMMIT drop;\r\n    delete from tmp;\r\n    FOR data IN SELECT jsonb_array_elements(data_jsonb) \r\n    LOOP\r\n\r\n        class := data->>'class';\r\n        IF (class IS NULL) THEN\r\n            RAISE EXCEPTION 'The reclada object class is not specified';\r\n        END IF;\r\n\r\n        attrs := data->'attrs';\r\n        IF (attrs IS NULL) THEN\r\n            RAISE EXCEPTION 'The reclada object must have attrs';\r\n        END IF;\r\n\r\n        SELECT reclada_object.get_schema(class) \r\n            INTO schema;\r\n\r\n        IF (schema IS NULL) THEN\r\n            RAISE EXCEPTION 'No json schema available for %', class;\r\n        END IF;\r\n\r\n        IF (NOT(validate_json_schema(schema->'attrs'->'schema', attrs))) THEN\r\n            RAISE EXCEPTION 'JSON invalid: %', attrs;\r\n        END IF;\r\n\r\n        with inserted as \r\n        (\r\n            INSERT INTO reclada.object(class,attributes)\r\n                select class, attrs\r\n                    RETURNING obj_id\r\n        ) \r\n        insert into tmp(id)\r\n            select obj_id \r\n                from inserted;\r\n\r\n    END LOOP;\r\n\r\n    res := array_to_json\r\n            (\r\n                array\r\n                (\r\n                    select o.data \r\n                        from reclada.v_active_object o\r\n                        join tmp t\r\n                            on t.id = o.obj_id\r\n                )\r\n            )::jsonb; \r\n    PERFORM reclada_notification.send_object_notification\r\n        (\r\n            'create',\r\n            res\r\n        );\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.get_query_condition ;\nCREATE OR REPLACE FUNCTION reclada_object.get_query_condition(data jsonb, key_path text)\n RETURNS text\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    key          text;\r\n    operator     text;\r\n    value        text;\r\n    res          text;\r\n\r\nBEGIN\r\n    IF (data IS NULL OR data = 'null'::jsonb) THEN\r\n        RAISE EXCEPTION 'There is no condition';\r\n    END IF;\r\n\r\n    IF (jsonb_typeof(data) = 'object') THEN\r\n\r\n        IF (data->'object' IS NULL OR data->'object' = ('null'::jsonb)) THEN\r\n            RAISE EXCEPTION 'There is no object field';\r\n        END IF;\r\n\r\n        IF (jsonb_typeof(data->'object') = 'object') THEN\r\n            RAISE EXCEPTION 'The input_jsonb->''object'' can not contain jsonb object';\r\n        END IF;\r\n\r\n        IF (jsonb_typeof(data->'operator') != 'string' AND data->'operator' IS NOT NULL) THEN\r\n            RAISE EXCEPTION 'The input_jsonb->''operator'' must contain string';\r\n        END IF;\r\n\r\n        IF (jsonb_typeof(data->'object') = 'array') THEN\r\n            res := reclada_object.get_condition_array(data, key_path);\r\n        ELSE\r\n            key := reclada_object.cast_jsonb_to_postgres(key_path, jsonb_typeof(data->'object'));\r\n            operator :=  data->>'operator';\r\n            value := reclada_object.jsonb_to_text(data->'object');\r\n            res := key || ' ' || operator || ' ' || value;\r\n        END IF;\r\n    ELSE\r\n        key := reclada_object.cast_jsonb_to_postgres(key_path, jsonb_typeof(data));\r\n        operator := '=';\r\n        value := reclada_object.jsonb_to_text(data);\r\n        res := key || ' ' || operator || ' ' || value;\r\n    END IF;\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.list_add ;\nCREATE OR REPLACE FUNCTION reclada_object.list_add(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    class          text;\r\n    objid          uuid;\r\n    obj            jsonb;\r\n    values_to_add  jsonb;\r\n    field          text;\r\n    field_value    jsonb;\r\n    json_path      text[];\r\n    new_obj        jsonb;\r\n    res            jsonb;\r\n\r\nBEGIN\r\n\r\n    class := data->>'class';\r\n    IF (class IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object class is not specified';\r\n    END IF;\r\n\r\n    objid := (data->>'id')::uuid;\r\n    IF (objid IS NULL) THEN\r\n        RAISE EXCEPTION 'There is no id';\r\n    END IF;\r\n\r\n    SELECT v.data\r\n\tFROM reclada.v_active_object v\r\n\tWHERE v.obj_id = objid\r\n\tINTO obj;\r\n\r\n    IF (obj IS NULL) THEN\r\n        RAISE EXCEPTION 'There is no object with such id';\r\n    END IF;\r\n\r\n    values_to_add := data->'value';\r\n    IF (values_to_add IS NULL OR values_to_add = 'null'::jsonb) THEN\r\n        RAISE EXCEPTION 'The value should not be null';\r\n    END IF;\r\n\r\n    IF (jsonb_typeof(values_to_add) != 'array') THEN\r\n        values_to_add := format('[%s]', values_to_add)::jsonb;\r\n    END IF;\r\n\r\n    field := data->>'field';\r\n    IF (field IS NULL) THEN\r\n        RAISE EXCEPTION 'There is no field';\r\n    END IF;\r\n    json_path := format('{attrs, %s}', field);\r\n    field_value := obj#>json_path;\r\n\r\n    IF ((field_value = 'null'::jsonb) OR (field_value IS NULL)) THEN\r\n        SELECT jsonb_set(obj, json_path, values_to_add)\r\n        INTO new_obj;\r\n    ELSE\r\n        SELECT jsonb_set(obj, json_path, field_value || values_to_add)\r\n        INTO new_obj;\r\n    END IF;\r\n\r\n    SELECT reclada_object.update(new_obj) INTO res;\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.list_drop ;\nCREATE OR REPLACE FUNCTION reclada_object.list_drop(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    class           text;\r\n    objid           uuid;\r\n    obj             jsonb;\r\n    values_to_drop  jsonb;\r\n    field           text;\r\n    field_value     jsonb;\r\n    json_path       text[];\r\n    new_value       jsonb;\r\n    new_obj         jsonb;\r\n    res             jsonb;\r\n\r\nBEGIN\r\n\r\n\tclass := data->>'class';\r\n\tIF (class IS NULL) THEN\r\n\t\tRAISE EXCEPTION 'The reclada object class is not specified';\r\n\tEND IF;\r\n\r\n\tobjid := (data->>'id')::uuid;\r\n\tIF (objid IS NULL) THEN\r\n\t\tRAISE EXCEPTION 'The is no id';\r\n\tEND IF;\r\n\r\n    SELECT v.data\r\n    FROM reclada.v_active_object v\r\n    WHERE v.obj_id = objid\r\n    INTO obj;\r\n\r\n\tIF (obj IS NULL) THEN\r\n\t\tRAISE EXCEPTION 'The is no object with such id';\r\n\tEND IF;\r\n\r\n\tvalues_to_drop := data->'value';\r\n\tIF (values_to_drop IS NULL OR values_to_drop = 'null'::jsonb) THEN\r\n\t\tRAISE EXCEPTION 'The value should not be null';\r\n\tEND IF;\r\n\r\n\tIF (jsonb_typeof(values_to_drop) != 'array') THEN\r\n\t\tvalues_to_drop := format('[%s]', values_to_drop)::jsonb;\r\n\tEND IF;\r\n\r\n\tfield := data->>'field';\r\n\tIF (field IS NULL) THEN\r\n\t\tRAISE EXCEPTION 'There is no field';\r\n\tEND IF;\r\n\tjson_path := format('{attrs, %s}', field);\r\n\tfield_value := obj#>json_path;\r\n\tIF (field_value IS NULL OR field_value = 'null'::jsonb) THEN\r\n\t\tRAISE EXCEPTION 'The object does not have this field';\r\n\tEND IF;\r\n\r\n\tSELECT jsonb_agg(elems)\r\n\tFROM\r\n\t\tjsonb_array_elements(field_value) elems\r\n\tWHERE\r\n\t\telems NOT IN (\r\n\t\t\tSELECT jsonb_array_elements(values_to_drop))\r\n\tINTO new_value;\r\n\r\n\tSELECT jsonb_set(obj, json_path, coalesce(new_value, '[]'::jsonb))\r\n\tINTO new_obj;\r\n\r\n\tSELECT reclada_object.update(new_obj) INTO res;\r\n\tRETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.list_related ;\nCREATE OR REPLACE FUNCTION reclada_object.list_related(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    class          text;\r\n    objid          uuid;\r\n    field          text;\r\n    related_class  text;\r\n    obj            jsonb;\r\n    list_of_ids    jsonb;\r\n    cond           jsonb = '{}'::jsonb;\r\n    order_by       jsonb;\r\n    limit_         text;\r\n    offset_        text;\r\n    res            jsonb;\r\n\r\nBEGIN\r\n    class := data->>'class';\r\n    IF (class IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object class is not specified';\r\n    END IF;\r\n\r\n    objid := (data->>'id')::uuid;\r\n    IF (objid IS NULL) THEN\r\n        RAISE EXCEPTION 'The object id is not specified';\r\n    END IF;\r\n\r\n    field := data->>'field';\r\n    IF (field IS NULL) THEN\r\n        RAISE EXCEPTION 'The object field is not specified';\r\n    END IF;\r\n\r\n    related_class := data->>'relatedClass';\r\n    IF (related_class IS NULL) THEN\r\n        RAISE EXCEPTION 'The related class is not specified';\r\n    END IF;\r\n\r\n\tSELECT v.data\r\n\tFROM reclada.v_active_object v\r\n\tWHERE v.obj_id = objid\r\n\tINTO obj;\r\n\r\n    IF (obj IS NULL) THEN\r\n        RAISE EXCEPTION 'There is no object with such id';\r\n    END IF;\r\n\r\n    list_of_ids := obj#>(format('{attrs, %s}', field)::text[]);\r\n    IF (list_of_ids IS NULL) THEN\r\n        RAISE EXCEPTION 'The object does not have this field';\r\n    END IF;\r\n\r\n    order_by := data->'orderBy';\r\n    IF (order_by IS NOT NULL) THEN\r\n        cond := cond || (format('{"orderBy": %s}', order_by)::jsonb);\r\n    END IF;\r\n\r\n    limit_ := data->>'limit';\r\n    IF (limit_ IS NOT NULL) THEN\r\n        cond := cond || (format('{"limit": "%s"}', limit_)::jsonb);\r\n    END IF;\r\n\r\n    offset_ := data->>'offset';\r\n    IF (offset_ IS NOT NULL) THEN\r\n        cond := cond || (format('{"offset": "%s"}', offset_)::jsonb);\r\n    END IF;\r\n\r\n    SELECT reclada_object.list(format(\r\n        '{"class": "%s", "attrs": {}, "id": {"operator": "<@", "object": %s}}',\r\n        related_class,\r\n        list_of_ids\r\n        )::jsonb || cond,\r\n        true)\r\n    INTO res;\r\n\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.list ;\nCREATE OR REPLACE FUNCTION reclada_object.list(data jsonb, with_number boolean DEFAULT false)\n RETURNS jsonb\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    class               text;\r\n    attrs               jsonb;\r\n    order_by_jsonb      jsonb;\r\n    order_by            text;\r\n    limit_              text;\r\n    offset_             text;\r\n    query_conditions    text;\r\n    number_of_objects   int;\r\n    objects             jsonb;\r\n    res                 jsonb;\r\n    query               text;\r\nBEGIN\r\n\r\n    class := data->>'class';\r\n    IF (class IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object class is not specified';\r\n    END IF;\r\n\r\n    attrs := data->'attrs' || '{}'::jsonb;\r\n\r\n    order_by_jsonb := data->'orderBy';\r\n    IF ((order_by_jsonb IS NULL) OR\r\n        (order_by_jsonb = 'null'::jsonb) OR\r\n        (order_by_jsonb = '[]'::jsonb)) THEN\r\n        order_by_jsonb := '[{"field": "id", "order": "ASC"}]'::jsonb;\r\n    END IF;\r\n    IF (jsonb_typeof(order_by_jsonb) != 'array') THEN\r\n    \t\torder_by_jsonb := format('[%s]', order_by_jsonb);\r\n    END IF;\r\n    SELECT string_agg(\r\n        format(E'obj.data#>''{%s}'' %s', T.value->>'field', COALESCE(T.value->>'order', 'ASC')),\r\n        ' , ')\r\n    FROM jsonb_array_elements(order_by_jsonb) T\r\n    INTO order_by;\r\n\r\n    limit_ := data->>'limit';\r\n    IF (limit_ IS NULL) THEN\r\n        limit_ := 500;\r\n    END IF;\r\n    IF ((limit_ ~ '(\\D+)') AND (limit_ != 'ALL')) THEN\r\n    \t\tRAISE EXCEPTION 'The limit must be an integer number or "ALL"';\r\n    END IF;\r\n\r\n    offset_ := data->>'offset';\r\n    IF (offset_ IS NULL) THEN\r\n        offset_ := 0;\r\n    END IF;\r\n    IF (offset_ ~ '(\\D+)') THEN\r\n    \t\tRAISE EXCEPTION 'The offset must be an integer number';\r\n    END IF;\r\n\r\n    SELECT\r\n        string_agg(\r\n            format(\r\n                E'(%s)',\r\n                condition\r\n            ),\r\n            ' AND '\r\n        )\r\n        FROM (\r\n            SELECT\r\n                -- ((('"'||class||'"')::jsonb#>>'{}')::text = 'Job')\r\n                --reclada_object.get_query_condition(class, E'data->''class''') AS condition\r\n                --'class = data->>''class''' AS condition\r\n                format('obj.class = ''%s''', class) AS condition\r\n            UNION\r\n            SELECT  CASE\r\n                        WHEN jsonb_typeof(data->'id') = 'array' THEN\r\n                        (\r\n                            SELECT string_agg\r\n                                (\r\n                                    format(\r\n                                        E'(%s)',\r\n                                        reclada_object.get_query_condition(cond, E'data->''id''')\r\n                                    ),\r\n                                    ' AND '\r\n                                )\r\n                                FROM jsonb_array_elements(data->'id') AS cond\r\n                        )\r\n                        ELSE reclada_object.get_query_condition(data->'id', E'data->''id''')\r\n                    END AS condition\r\n                WHERE coalesce(data->'id','null'::jsonb) != 'null'::jsonb\r\n            -- UNION\r\n            -- SELECT 'obj.data->>''status''=''active'''-- TODO: change working with revision\r\n            -- UNION SELECT\r\n            --     CASE WHEN data->'revision' IS NULL THEN\r\n            --         E'(data->>''revision''):: numeric = (SELECT max((objrev.data -> ''revision'')::numeric)\r\n            --         FROM reclada.v_object objrev WHERE\r\n            --         objrev.data -> ''id'' = obj.data -> ''id'')'\r\n            --     WHEN jsonb_typeof(data->'revision') = 'array' THEN\r\n            --         (SELECT string_agg(\r\n            --             format(\r\n            --                 E'(%s)',\r\n            --                 reclada_object.get_query_condition(cond, E'data->''revision''')\r\n            --             ),\r\n            --             ' AND '\r\n            --         )\r\n            --         FROM jsonb_array_elements(data->'revision') AS cond)\r\n            --     ELSE reclada_object.get_query_condition(data->'revision', E'data->''revision''') END AS condition\r\n            UNION\r\n            SELECT\r\n                CASE\r\n                    WHEN jsonb_typeof(value) = 'array'\r\n                        THEN\r\n                            (\r\n                                SELECT string_agg\r\n                                    (\r\n                                        format\r\n                                        (\r\n                                            E'(%s)',\r\n                                            reclada_object.get_query_condition(cond, format(E'data->''attrs''->%L', key))\r\n                                        ),\r\n                                        ' AND '\r\n                                    )\r\n                                    FROM jsonb_array_elements(value) AS cond\r\n                            )\r\n                    ELSE reclada_object.get_query_condition(value, format(E'data->''attrs''->%L', key))\r\n                END AS condition\r\n            FROM jsonb_each(attrs)\r\n            WHERE data->'attrs' != ('{}'::jsonb)\r\n        ) conds\r\n    INTO query_conditions;\r\n\r\n    -- RAISE NOTICE 'conds: %', '\r\n    --             SELECT obj.data\r\n    --             FROM reclada.v_object obj\r\n    --             WHERE ' || query_conditions ||\r\n    --             ' ORDER BY ' || order_by ||\r\n    --             ' OFFSET ' || offset_ || ' LIMIT ' || limit_ ;\r\n    query := 'FROM reclada.v_active_object obj WHERE ' || query_conditions;\r\n    raise notice 'query: %', query;\r\n    EXECUTE E'SELECT to_jsonb(array_agg(T.data))\r\n        FROM (\r\n            SELECT obj.data\r\n            '\r\n            || query\r\n            ||\r\n            ' ORDER BY ' || order_by ||\r\n            ' OFFSET ' || offset_ || ' LIMIT ' || limit_ || ') T'\r\n    INTO objects;\r\n    IF with_number THEN\r\n\r\n        EXECUTE E'SELECT count(1)\r\n        '|| query\r\n        INTO number_of_objects;\r\n\r\n        res := jsonb_build_object(\r\n        'number', number_of_objects,\r\n        'objects', objects);\r\n    ELSE\r\n        res := objects;\r\n    END IF;\r\n\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.update ;\nCREATE OR REPLACE FUNCTION reclada_object.update(data jsonb, user_info jsonb DEFAULT '{}'::jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    v_class         text;\r\n    v_obj_id        uuid;\r\n    v_attrs         jsonb;\r\n    schema        jsonb;\r\n    old_obj       jsonb;\r\n    branch        uuid;\r\n    revid         uuid;\r\n\r\nBEGIN\r\n\r\n    v_class := data->>'class';\r\n    IF (v_class IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object class is not specified';\r\n    END IF;\r\n\r\n    v_obj_id := data->>'id';\r\n    IF (v_obj_id IS NULL) THEN\r\n        RAISE EXCEPTION 'Could not update object with no id';\r\n    END IF;\r\n\r\n    v_attrs := data->'attrs';\r\n    IF (v_attrs IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object must have attrs';\r\n    END IF;\r\n\r\n    SELECT reclada_object.get_schema(v_class) \r\n        INTO schema;\r\n\r\n    IF (schema IS NULL) THEN\r\n        RAISE EXCEPTION 'No json schema available for %', v_class;\r\n    END IF;\r\n\r\n    IF (NOT(validate_json_schema(schema->'attrs'->'schema', v_attrs))) THEN\r\n        RAISE EXCEPTION 'JSON invalid: %', v_attrs;\r\n    END IF;\r\n\r\n    SELECT \tv.data\r\n        FROM reclada.v_active_object v\r\n\t        WHERE v.obj_id = v_obj_id\r\n\t    INTO old_obj;\r\n\r\n    IF (old_obj IS NULL) THEN\r\n        RAISE EXCEPTION 'Could not update object, no such id';\r\n    END IF;\r\n\r\n    branch := data->'branch';\r\n    SELECT reclada_revision.create(user_info->>'sub', branch, v_obj_id) \r\n        INTO revid;\r\n    \r\n    with t as \r\n    (\r\n        update reclada.object o\r\n            set status = reclada_object.get_archive_status_obj_id()\r\n                where o.obj_id = v_obj_id\r\n                    and status != reclada_object.get_archive_status_obj_id()\r\n                        RETURNING id\r\n    )\r\n    INSERT INTO reclada.object( obj_id,\r\n                                class,\r\n                                status,\r\n                                attributes\r\n                              )\r\n        select  v.obj_id,\r\n                v_class,\r\n                reclada_object.get_active_status_obj_id(),--status \r\n                v_attrs || format('{"revision":"%s"}',revid)::jsonb\r\n            FROM reclada.v_object v\r\n            JOIN t \r\n                on t.id = v.id\r\n\t            WHERE v.obj_id = v_obj_id;\r\n                    \r\n    select v.data \r\n        FROM reclada.v_active_object v\r\n            WHERE v.obj_id = v_obj_id\r\n        into data;\r\n    PERFORM reclada_notification.send_object_notification('update', data);\r\n    RETURN data;\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_revision.create ;\nCREATE OR REPLACE FUNCTION reclada_revision."create"(userid character varying, branch uuid, obj uuid)\n RETURNS uuid\n LANGUAGE sql\nAS $function$\r\n    INSERT INTO reclada.object\r\n        (\r\n            class,\r\n            attributes\r\n        )\r\n               \r\n        VALUES\r\n        (\r\n            'revision'               ,-- class,\r\n            format                    -- attrs\r\n            (                         \r\n                '{\r\n                    "num": %s,\r\n                    "user": "%s",\r\n                    "dateTime": "%s",\r\n                    "branch": "%s"\r\n                }',\r\n                (\r\n                    select count(*)\r\n                        from reclada.object o\r\n                            where o.obj_id = obj\r\n                ),\r\n                userid,\r\n                now(),\r\n                branch\r\n            )::jsonb\r\n        ) RETURNING (obj_id)::uuid;\r\n    --nextval('reclada.reclada_revisions'),\r\n$function$\n;\nDROP TRIGGER IF EXISTS datasource_insert_trigger ON reclada.object;\nDROP function IF EXISTS reclada.datasource_insert_trigger_fnc ;\nCREATE OR REPLACE FUNCTION reclada.datasource_insert_trigger_fnc()\n RETURNS trigger\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    obj_id         uuid;\r\n    dataset       jsonb;\r\n    uri           text;\r\n\r\nBEGIN\r\n    IF (NEW.class = 'DataSource') OR (NEW.class = 'File') THEN\r\n\r\n        obj_id := NEW.obj_id;\r\n\r\n        SELECT v.data\r\n        FROM reclada.v_active_object v\r\n\t    WHERE v.attrs->>'name' = 'defaultDataSet'\r\n\t    INTO dataset;\r\n\r\n        dataset := jsonb_set(dataset, '{attrs, dataSources}', dataset->'attrs'->'dataSources' || format('["%s"]', obj_id)::jsonb);\r\n\r\n        PERFORM reclada_object.update(dataset);\r\n\r\n        uri := NEW.attributes->>'uri';\r\n\r\n        PERFORM reclada_object.create(\r\n            format('{\r\n                "class": "Job",\r\n                "attrs": {\r\n                    "task": "c94bff30-15fa-427f-9954-d5c3c151e652",\r\n                    "status": "new",\r\n                    "type": "K8S",\r\n                    "command": "./run_pipeline.sh",\r\n                    "inputParameters": [{"uri": "%s"}, {"dataSourceId": "%s"}]\r\n                    }\r\n                }', uri, obj_id)::jsonb);\r\n\r\n    END IF;\r\n\r\nRETURN NEW;\r\nEND;\r\n$function$\n;\nCREATE TRIGGER datasource_insert_trigger\n  BEFORE INSERT\n  ON reclada.object FOR EACH ROW\n  EXECUTE PROCEDURE reclada.datasource_insert_trigger_fnc();	2021-09-22 14:51:25.925445+00
13	12	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 12 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\n\ni 'function/reclada_revision.create.sql'\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nDROP function IF EXISTS reclada_revision.create ;\nCREATE OR REPLACE FUNCTION reclada_revision."create"(userid character varying, branch uuid, obj uuid)\n RETURNS uuid\n LANGUAGE sql\nAS $function$\r\n    INSERT INTO reclada.object\r\n        (\r\n            class,\r\n            attributes\r\n        )\r\n               \r\n        VALUES\r\n        (\r\n            'revision'               ,-- class,\r\n            format                    -- attributes\r\n            (                         \r\n                '{\r\n                    "num": %s,\r\n                    "user": "%s",\r\n                    "dateTime": "%s",\r\n                    "branch": "%s"\r\n                }',\r\n                (\r\n                    select count(*)\r\n                        from reclada.object o\r\n                            where o.obj_id = obj\r\n                ),\r\n                userid,\r\n                now(),\r\n                branch\r\n            )::jsonb\r\n        ) RETURNING (obj_id)::uuid;\r\n    --nextval('reclada.reclada_revisions'),\r\n$function$\n;	2021-09-22 14:51:33.946132+00
14	13	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 13 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ndrop VIEW if EXISTS reclada.v_class;\ndrop VIEW if EXISTS reclada.v_revision ;\ndrop VIEW if EXISTS reclada.v_active_object;\n\ni 'view/reclada.v_object.sql'\ni 'view/reclada.v_active_object.sql'\ni 'view/reclada.v_revision.sql'\ni 'view/reclada.v_class.sql'\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\ndrop VIEW if EXISTS reclada.v_class;\ndrop VIEW if EXISTS reclada.v_revision;\ndrop VIEW if EXISTS reclada.v_active_object;\nDROP view IF EXISTS reclada.v_object ;\nCREATE OR REPLACE VIEW reclada.v_object\nAS\n WITH t AS (\n         SELECT obj.id,\n            obj.obj_id,\n            obj.class,\n            r.num,\n            NULLIF(obj.attributes ->> 'revision'::text, ''::text)::uuid AS revision,\n            obj.attributes AS attrs,\n            obj.status,\n            obj.created_time,\n            obj.created_by\n           FROM object obj\n             LEFT JOIN ( SELECT (r_1.attributes -> 'num'::text)::bigint AS num,\n                    r_1.obj_id\n                   FROM object r_1\n                  WHERE r_1.class = 'revision'::text) r ON r.obj_id = NULLIF(obj.attributes ->> 'revision'::text, ''::text)::uuid\n        )\n SELECT t.id,\n    t.obj_id,\n    t.class,\n    t.num AS revision_num,\n    os.caption AS status_caption,\n    t.revision,\n    t.created_time,\n    t.attrs,\n    format('{\r\n                    "id": "%s",\r\n                    "class": "%s",\r\n                    "revision": %s, \r\n                    "status": "%s",\r\n                    "attributes": %s\r\n                }'::text, t.obj_id, t.class, COALESCE(('"'::text || t.revision::text) || '"'::text, 'null'::text), os.caption, t.attrs)::jsonb AS data,\n    u.login AS login_created_by,\n    t.created_by,\n    t.status\n   FROM t\n     LEFT JOIN v_object_status os ON t.status = os.obj_id\n     LEFT JOIN v_user u ON u.obj_id = t.created_by;\nDROP view IF EXISTS reclada.v_active_object ;\nCREATE OR REPLACE VIEW reclada.v_active_object\nAS\n SELECT t.id,\n    t.obj_id,\n    t.class,\n    t.revision_num,\n    t.status,\n    t.status_caption,\n    t.revision,\n    t.created_time,\n    t.attrs,\n    t.data\n   FROM v_object t\n  WHERE t.status = reclada_object.get_active_status_obj_id();\nDROP view IF EXISTS reclada.v_revision ;\nCREATE OR REPLACE VIEW reclada.v_revision\nAS\n SELECT obj.id,\n    obj.obj_id,\n    (obj.attrs ->> 'num'::text)::bigint AS num,\n    obj.attrs ->> 'branch'::text AS branch,\n    obj.attrs ->> 'user'::text AS "user",\n    obj.attrs ->> 'dateTime'::text AS date_time,\n    obj.attrs ->> 'old_num'::text AS old_num,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class = 'revision'::text;\nDROP view IF EXISTS reclada.v_class ;\nCREATE OR REPLACE VIEW reclada.v_class\nAS\n SELECT obj.id,\n    obj.obj_id,\n    obj.attrs ->> 'forClass'::text AS for_class,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class = 'jsonschema'::text;	2021-09-22 14:51:37.1906+00
29	28	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect reclada.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 28 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/reclada_object.list.sql'\n\n\ni 'function/api.auth_get_login_url copy.sql'\ni 'function/api.auth_get_login_url.sql'\ni 'function/api.hello_world.sql'\ni 'function/api.reclada_object_create.sql'\ni 'function/api.reclada_object_delete.sql'\ni 'function/api.reclada_object_list.sql'\ni 'function/api.reclada_object_list_add.sql'\ni 'function/api.reclada_object_list_drop.sql'\ni 'function/api.reclada_object_list_related.sql'\ni 'function/api.reclada_object_update.sql'\ni 'function/api.storage_generate_presigned_get.sql'\ni 'function/api.storage_generate_presigned_post.sql'\ni 'function/dev.downgrade_version.sql'\ni 'function/dev.reg_notice.sql'\ni 'function/reclada.datasource_insert_trigger_fnc.sql'\ni 'function/reclada.load_staging.sql'\ni 'function/reclada.raise_exception.sql'\ni 'function/reclada.raise_notice.sql'\ni 'function/reclada.try_cast_int.sql'\ni 'function/reclada.try_cast_uuid.sql'\ni 'function/reclada_notification.listen.sql'\ni 'function/reclada_notification.send.sql'\ni 'function/reclada_notification.send_object_notification.sql'\ni 'function/reclada_object.cast_jsonb_to_postgres.sql'\ni 'function/reclada_object.create.sql'\ni 'function/reclada_object.create_subclass.sql'\ni 'function/reclada_object.delete.sql'\ni 'function/reclada_object.get_archive_status_obj_id.sql'\ni 'function/reclada_object.get_condition_array.sql'\ni 'function/reclada_object.get_query_condition.sql'\ni 'function/reclada_object.get_schema.sql'\ni 'function/reclada_object.jsonb_to_text.sql'\ni 'function/reclada_object.list.sql'\ni 'function/reclada_object.list_add.sql'\ni 'function/reclada_object.list_drop.sql'\ni 'function/reclada_object.list_related.sql'\ni 'function/reclada_object.update.sql'\ni 'function/reclada_revision.create.sql'\ni 'function/reclada_user.auth_by_token.sql'\ni 'function/reclada_user.disable_auth.sql'\ni 'function/reclada_user.is_allowed.sql'\ni 'function/reclada_user.setup_keycloak.sql'\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect reclada.raise_exception('Downgrade script not support');	2021-09-22 14:52:44.849474+00
15	14	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 14 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/reclada_object.get_query_condition.sql'\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nDROP function IF EXISTS reclada_object.get_query_condition ;\nCREATE OR REPLACE FUNCTION reclada_object.get_query_condition(data jsonb, key_path text)\n RETURNS text\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    key          text;\r\n    operator     text;\r\n    value        text;\r\n    res          text;\r\n\r\nBEGIN\r\n    IF (data IS NULL OR data = 'null'::jsonb) THEN\r\n        RAISE EXCEPTION 'There is no condition';\r\n    END IF;\r\n\r\n    IF (jsonb_typeof(data) = 'object') THEN\r\n\r\n        IF (data->'object' IS NULL OR data->'object' = ('null'::jsonb)) THEN\r\n            RAISE EXCEPTION 'There is no object field';\r\n        END IF;\r\n\r\n        IF (jsonb_typeof(data->'object') = 'object') THEN\r\n            RAISE EXCEPTION 'The input_jsonb->''object'' can not contain jsonb object';\r\n        END IF;\r\n\r\n        IF (jsonb_typeof(data->'operator') != 'string' AND data->'operator' IS NOT NULL) THEN\r\n            RAISE EXCEPTION 'The input_jsonb->''operator'' must contain string';\r\n        END IF;\r\n\r\n        IF (jsonb_typeof(data->'object') = 'array') THEN\r\n            res := reclada_object.get_condition_array(data, key_path);\r\n        ELSE\r\n            key := reclada_object.cast_jsonb_to_postgres(key_path, jsonb_typeof(data->'object'));\r\n            operator :=  data->>'operator';\r\n            value := reclada_object.jsonb_to_text(data->'object');\r\n            res := key || ' ' || operator || ' ' || value;\r\n        END IF;\r\n    ELSE\r\n        key := reclada_object.cast_jsonb_to_postgres(key_path, jsonb_typeof(data));\r\n        operator := '=';\r\n        value := reclada_object.jsonb_to_text(data);\r\n        res := key || ' ' || operator || ' ' || value;\r\n    END IF;\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;	2021-09-22 14:51:41.568627+00
16	15	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 15 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/reclada_object.list.sql'\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nDROP function IF EXISTS reclada_object.list ;\nCREATE OR REPLACE FUNCTION reclada_object.list(data jsonb, with_number boolean DEFAULT false)\n RETURNS jsonb\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    class               text;\r\n    attrs               jsonb;\r\n    order_by_jsonb      jsonb;\r\n    order_by            text;\r\n    limit_              text;\r\n    offset_             text;\r\n    query_conditions    text;\r\n    number_of_objects   int;\r\n    objects             jsonb;\r\n    res                 jsonb;\r\n    query               text;\r\nBEGIN\r\n\r\n    class := data->>'class';\r\n    IF (class IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object class is not specified';\r\n    END IF;\r\n\r\n    attrs := data->'attributes' || '{}'::jsonb;\r\n\r\n    order_by_jsonb := data->'orderBy';\r\n    IF ((order_by_jsonb IS NULL) OR\r\n        (order_by_jsonb = 'null'::jsonb) OR\r\n        (order_by_jsonb = '[]'::jsonb)) THEN\r\n        order_by_jsonb := '[{"field": "id", "order": "ASC"}]'::jsonb;\r\n    END IF;\r\n    IF (jsonb_typeof(order_by_jsonb) != 'array') THEN\r\n    \t\torder_by_jsonb := format('[%s]', order_by_jsonb);\r\n    END IF;\r\n    SELECT string_agg(\r\n        format(E'obj.data#>''{%s}'' %s', T.value->>'field', COALESCE(T.value->>'order', 'ASC')),\r\n        ' , ')\r\n    FROM jsonb_array_elements(order_by_jsonb) T\r\n    INTO order_by;\r\n\r\n    limit_ := data->>'limit';\r\n    IF (limit_ IS NULL) THEN\r\n        limit_ := 500;\r\n    END IF;\r\n    IF ((limit_ ~ '(\\D+)') AND (limit_ != 'ALL')) THEN\r\n    \t\tRAISE EXCEPTION 'The limit must be an integer number or "ALL"';\r\n    END IF;\r\n\r\n    offset_ := data->>'offset';\r\n    IF (offset_ IS NULL) THEN\r\n        offset_ := 0;\r\n    END IF;\r\n    IF (offset_ ~ '(\\D+)') THEN\r\n    \t\tRAISE EXCEPTION 'The offset must be an integer number';\r\n    END IF;\r\n\r\n    SELECT\r\n        string_agg(\r\n            format(\r\n                E'(%s)',\r\n                condition\r\n            ),\r\n            ' AND '\r\n        )\r\n        FROM (\r\n            SELECT\r\n                -- ((('"'||class||'"')::jsonb#>>'{}')::text = 'Job')\r\n                --reclada_object.get_query_condition(class, E'data->''class''') AS condition\r\n                --'class = data->>''class''' AS condition\r\n                format('obj.class = ''%s''', class) AS condition\r\n            UNION\r\n            SELECT  CASE\r\n                        WHEN jsonb_typeof(data->'id') = 'array' THEN\r\n                        (\r\n                            SELECT string_agg\r\n                                (\r\n                                    format(\r\n                                        E'(%s)',\r\n                                        reclada_object.get_query_condition(cond, E'data->''id''')\r\n                                    ),\r\n                                    ' AND '\r\n                                )\r\n                                FROM jsonb_array_elements(data->'id') AS cond\r\n                        )\r\n                        ELSE reclada_object.get_query_condition(data->'id', E'data->''id''')\r\n                    END AS condition\r\n                WHERE coalesce(data->'id','null'::jsonb) != 'null'::jsonb\r\n            -- UNION\r\n            -- SELECT 'obj.data->>''status''=''active'''-- TODO: change working with revision\r\n            -- UNION SELECT\r\n            --     CASE WHEN data->'revision' IS NULL THEN\r\n            --         E'(data->>''revision''):: numeric = (SELECT max((objrev.data -> ''revision'')::numeric)\r\n            --         FROM reclada.v_object objrev WHERE\r\n            --         objrev.data -> ''id'' = obj.data -> ''id'')'\r\n            --     WHEN jsonb_typeof(data->'revision') = 'array' THEN\r\n            --         (SELECT string_agg(\r\n            --             format(\r\n            --                 E'(%s)',\r\n            --                 reclada_object.get_query_condition(cond, E'data->''revision''')\r\n            --             ),\r\n            --             ' AND '\r\n            --         )\r\n            --         FROM jsonb_array_elements(data->'revision') AS cond)\r\n            --     ELSE reclada_object.get_query_condition(data->'revision', E'data->''revision''') END AS condition\r\n            UNION\r\n            SELECT\r\n                CASE\r\n                    WHEN jsonb_typeof(value) = 'array'\r\n                        THEN\r\n                            (\r\n                                SELECT string_agg\r\n                                    (\r\n                                        format\r\n                                        (\r\n                                            E'(%s)',\r\n                                            reclada_object.get_query_condition(cond, format(E'data->''attributes''->%L', key))\r\n                                        ),\r\n                                        ' AND '\r\n                                    )\r\n                                    FROM jsonb_array_elements(value) AS cond\r\n                            )\r\n                    ELSE reclada_object.get_query_condition(value, format(E'data->''attributes''->%L', key))\r\n                END AS condition\r\n            FROM jsonb_each(attrs)\r\n            WHERE data->'attributes' != ('{}'::jsonb)\r\n        ) conds\r\n    INTO query_conditions;\r\n\r\n    -- RAISE NOTICE 'conds: %', '\r\n    --             SELECT obj.data\r\n    --             FROM reclada.v_object obj\r\n    --             WHERE ' || query_conditions ||\r\n    --             ' ORDER BY ' || order_by ||\r\n    --             ' OFFSET ' || offset_ || ' LIMIT ' || limit_ ;\r\n    query := 'FROM reclada.v_active_object obj WHERE ' || query_conditions;\r\n    raise notice 'query: %', query;\r\n    EXECUTE E'SELECT to_jsonb(array_agg(T.data))\r\n        FROM (\r\n            SELECT obj.data\r\n            '\r\n            || query\r\n            ||\r\n            ' ORDER BY ' || order_by ||\r\n            ' OFFSET ' || offset_ || ' LIMIT ' || limit_ || ') T'\r\n    INTO objects;\r\n    IF with_number THEN\r\n\r\n        EXECUTE E'SELECT count(1)\r\n        '|| query\r\n        INTO number_of_objects;\r\n\r\n        res := jsonb_build_object(\r\n        'number', number_of_objects,\r\n        'objects', objects);\r\n    ELSE\r\n        res := objects;\r\n    END IF;\r\n\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;	2021-09-22 14:51:44.777124+00
17	16	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 16 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/reclada_object.create.sql'\n\n\nCREATE UNIQUE INDEX unique_guid_revision \n    ON reclada.object((attributes->>'revision'),obj_id);\n\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nDROP function IF EXISTS reclada_object.create ;\nCREATE OR REPLACE FUNCTION reclada_object."create"(data_jsonb jsonb, user_info jsonb DEFAULT '{}'::jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    branch     uuid;\r\n    data       jsonb;\r\n    class      text;\r\n    attrs      jsonb;\r\n    schema     jsonb;\r\n    res        jsonb;\r\n\r\nBEGIN\r\n\r\n    IF (jsonb_typeof(data_jsonb) != 'array') THEN\r\n        data_jsonb := '[]'::jsonb || data_jsonb;\r\n    END IF;\r\n    /*TODO: check if some objects have revision and others do not */\r\n    branch:= data_jsonb->0->'branch';\r\n    create temp table IF NOT EXISTS tmp(id uuid)\r\n    ON COMMIT drop;\r\n    delete from tmp;\r\n    FOR data IN SELECT jsonb_array_elements(data_jsonb) \r\n    LOOP\r\n\r\n        class := data->>'class';\r\n        IF (class IS NULL) THEN\r\n            RAISE EXCEPTION 'The reclada object class is not specified';\r\n        END IF;\r\n\r\n        attrs := data->'attributes';\r\n        IF (attrs IS NULL) THEN\r\n            RAISE EXCEPTION 'The reclada object must have attributes';\r\n        END IF;\r\n\r\n        SELECT reclada_object.get_schema(class) \r\n            INTO schema;\r\n\r\n        IF (schema IS NULL) THEN\r\n            RAISE EXCEPTION 'No json schema available for %', class;\r\n        END IF;\r\n\r\n        IF (NOT(validate_json_schema(schema->'attributes'->'schema', attrs))) THEN\r\n            RAISE EXCEPTION 'JSON invalid: %', attrs;\r\n        END IF;\r\n\r\n        with inserted as \r\n        (\r\n            INSERT INTO reclada.object(class,attributes)\r\n                select class, attrs\r\n                    RETURNING obj_id\r\n        ) \r\n        insert into tmp(id)\r\n            select obj_id \r\n                from inserted;\r\n\r\n    END LOOP;\r\n\r\n    res := array_to_json\r\n            (\r\n                array\r\n                (\r\n                    select o.data \r\n                        from reclada.v_active_object o\r\n                        join tmp t\r\n                            on t.id = o.obj_id\r\n                )\r\n            )::jsonb; \r\n    PERFORM reclada_notification.send_object_notification\r\n        (\r\n            'create',\r\n            res\r\n        );\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\n\ndrop index unique_guid_revision;	2021-09-22 14:51:47.856222+00
18	17	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 17 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n\n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\nDROP TABLE IF EXISTS reclada.staging;\ni 'function/reclada.load_staging.sql'\ni 'view/reclada.staging.sql'\ni 'trigger/load_staging.sql'\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\n\nSELECT public.raise_notice('Downscript is not supported');	2021-09-22 14:51:51.217026+00
19	18	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 18 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\nSELECT reclada_object.create_subclass('{\n    "class": "RecladaObject",\n    "attributes": {\n        "newClass": "revision",\n        "properties": {\n            "num": {"type": "number"},\n            "user": {"type": "string"},\n            "branch": {"type": "string"},\n            "dateTime": {"type": "string"}  \n        },\n        "required": ["dateTime"]\n    }\n}'::jsonb);\n\n\nalter table reclada.object\n    add column class_guid uuid;\n\n\nupdate reclada.object o\n    set class_guid = c.obj_id\n        from v_class c\n            where c.for_class = o.class;\n\ndrop VIEW reclada.v_class;\ndrop VIEW reclada.v_revision;\ndrop VIEW reclada.v_active_object;\ndrop VIEW reclada.v_object;\ndrop VIEW reclada.v_object_status;\ndrop VIEW reclada.v_user;\nalter table reclada.object\n    drop column class;\n\nalter table reclada.object\n    add column class uuid;\n\nupdate reclada.object o\n    set class = c.class_guid\n        from reclada.object c\n            where c.id = o.id;\n\nalter table reclada.object\n    drop column class_guid;\n\ncreate index class_index \n    ON reclada.object(class);\n\ni 'function/public.try_cast_uuid.sql'\ni 'function/reclada_object.get_jsonschema_GUID.sql'\ni 'view/reclada.v_class_lite.sql'\ni 'function/reclada_object.get_GUID_for_class.sql'\n\ndelete \n--select *\n    from reclada.v_class_lite c\n    where c.id = \n        (\n            SELECT min(id) min_id\n                FROM reclada.v_class_lite\n                GROUP BY for_class\n                HAVING count(*)>1\n        );\n\nselect public.raise_exception('find more then 1 version for some class')\n    where exists(\n        select for_class\n            from reclada.v_class_lite\n            GROUP BY for_class\n            HAVING count(*)>1\n    );\n\nUPDATE reclada.object o\n    set attributes = c.attributes || '{"version":1}'::jsonb\n        from v_class_lite c\n            where c.id = o.id;\n\ni 'view/reclada.v_object_status.sql'\ni 'view/reclada.v_user.sql'\ni 'view/reclada.v_object.sql'\ni 'view/reclada.v_active_object.sql'\ni 'view/reclada.v_revision.sql'\ni 'view/reclada.v_class.sql'\n\ni 'function/reclada_object.get_schema.sql'\ni 'function/reclada_object.create.sql'\ni 'function/reclada_object.update.sql'\ni 'function/reclada_object.list.sql'\ni 'function/reclada.datasource_insert_trigger_fnc.sql'\ni 'function/reclada_notification.send_object_notification.sql'\ni 'function/reclada_revision.create.sql'\n\n\n\n\n-- проверить, что вернет reclada_object.get_GUID_for_class если есть несколько классов\n\n-- SELECT * FROM reclada.object where class is null;\n\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect public.raise_exception('Downgrade script not support');	2021-09-22 14:51:54.773219+00
20	19	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 19 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\nalter table reclada.object\n    add column GUID uuid;\n\nupdate reclada.object o\n    set GUID = c.obj_id\n        from reclada.object c\n            where c.id = o.id;\n\n\ndrop VIEW reclada.v_class;\ndrop VIEW reclada.v_revision;\ndrop VIEW reclada.v_active_object;\ndrop VIEW reclada.v_object;\ndrop VIEW reclada.v_class_lite;\ndrop VIEW reclada.v_object_status;\ndrop VIEW reclada.v_user;\nalter table reclada.object\n    drop column obj_id;\n\ncreate index GUID_index \n    ON reclada.object(GUID);\n\n-- delete from reclada.object where class is null;\nalter table reclada.object \n    alter column class set not null;\n\ni 'function/reclada_object.get_jsonschema_GUID.sql'\ni 'view/reclada.v_class_lite.sql'\ni 'view/reclada.v_object_status.sql'\ni 'view/reclada.v_user.sql'\ni 'view/reclada.v_object.sql'\ni 'view/reclada.v_active_object.sql'\ni 'view/reclada.v_class.sql'\ni 'view/reclada.v_revision.sql'\ni 'function/reclada.datasource_insert_trigger_fnc.sql'\ni 'function/reclada_object.update.sql'\ni 'function/reclada_object.create.sql'\ni 'function/reclada_object.delete.sql'\ni 'function/reclada_object.list.sql'\n\ni 'function/reclada_object.list_add.sql'\ni 'function/reclada_object.list_drop.sql'\ni 'function/reclada_object.list_related.sql'\n\ni 'function/api.reclada_object_delete.sql'\ni 'function/api.reclada_object_list_add.sql'\ni 'function/api.reclada_object_list_drop.sql'\ni 'function/api.reclada_object_list_related.sql'\ni 'function/api.reclada_object_update.sql'\ni 'function/reclada_revision.create.sql'\ni 'function/reclada_notification.send_object_notification.sql'\n\n\n\n\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect public.raise_exception('Downgrade script not support');	2021-09-22 14:52:02.849993+00
21	20	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 20 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\nDROP VIEW IF EXISTS reclada.v_class;\nDROP VIEW IF EXISTS reclada.v_revision;\nDROP VIEW IF EXISTS reclada.v_active_object;\nDROP VIEW IF EXISTS reclada.v_object;\n\ni 'view/reclada.v_object.sql'\ni 'view/reclada.v_active_object.sql'\ni 'view/reclada.v_class.sql'\ni 'view/reclada.v_revision.sql'\ni 'function/reclada_object.create.sql'\ni 'function/reclada_object.list.sql'\ni 'function/reclada_object.list_related.sql'\n\ni 'function/api.storage_generate_presigned_get.sql'\ni 'function/api.storage_generate_presigned_post.sql'\ni 'function/api.reclada_object_list_drop.sql'\ni 'function/api.reclada_object_list_related.sql'\n\n\n\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect public.raise_exception('Downgrade script not support');	2021-09-22 14:52:11.560797+00
22	21	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 21 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\n\ni 'function/reclada_object.create_subclass.sql'\ni 'function/reclada_object.list_related.sql'\ni 'function/api.storage_generate_presigned_post.sql'\n\nupdate v_class_lite\n\tset attributes = attributes || '{"version":1}'\n\t\twhere attributes->>'version' is null;\n\n\n\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect public.raise_exception('Downgrade script not support');	2021-09-22 14:52:17.117935+00
23	22	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 22 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/reclada_object.create_subclass.sql'\n\nSELECT reclada_object.create_subclass('{\n    "class": "RecladaObject",\n    "attributes": {\n        "newClass": "Lambda",\n        "properties": {\n            "name": {"type": "string"}\n        },\n        "required": ["name"]\n    }\n}'::jsonb);\ni 'function/api.storage_generate_presigned_post.sql'\ni 'function/reclada.datasource_insert_trigger_fnc.sql'\n\n\n\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect public.raise_exception('Downgrade script not support');	2021-09-22 14:52:20.777627+00
24	23	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 23 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\nDROP FUNCTION IF EXISTS public.raise_exception;\nDROP FUNCTION IF EXISTS public.raise_notice;\nDROP FUNCTION IF EXISTS public.try_cast_uuid;\nDROP FUNCTION IF EXISTS public.try_cast_int;\n\ni 'function/reclada.raise_exception.sql'\ni 'function/reclada.raise_notice.sql'\ni 'function/reclada.try_cast_uuid.sql'\ni 'function/reclada.try_cast_int.sql'\ni 'function/dev.downgrade_version.sql'\ni 'function/reclada_object.create.sql'\ni 'function/reclada_object.list.sql'\ni 'function/reclada_object.update.sql'\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect reclada.raise_exception('Downgrade script not support');	2021-09-22 14:52:24.586095+00
25	24	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect reclada.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 24 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/dev.reg_notice.sql'\n\nSELECT reclada_object.create_subclass('{\n    "class": "RecladaObject",\n    "attributes": {\n        "newClass": "Context",\n        "properties": {\n            "Lambda": {"type": "string"}\n\t\t\t,"Environment": {"type": "string"}\n        },\n        "required": ["Environment"]\n    }\n}'::jsonb);\n\n\nDELETE\nFROM reclada.object\nWHERE class = reclada_object.get_jsonschema_GUID() and attributes->>'forClass'='Lambda';\n\ni 'function/api.storage_generate_presigned_get.sql'\ni 'function/api.storage_generate_presigned_post.sql'\ni 'function/reclada.datasource_insert_trigger_fnc.sql'\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect reclada.raise_exception('Downgrade script not support');	2021-09-22 14:52:29.56296+00
26	25	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect reclada.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 25 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect reclada.raise_exception('Downgrade script not support');	2021-09-22 14:52:33.297062+00
27	26	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect reclada.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 26 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\ni 'function/api.storage_generate_presigned_get.sql'\ni 'function/reclada_object.create.sql'\ni 'function/reclada_object.update.sql'\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect reclada.raise_exception('Downgrade script not support');	2021-09-22 14:52:36.392408+00
30	29	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect reclada.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 29 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/reclada_object.list.sql'\ni 'function/reclada_object.create.sql'\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect reclada.raise_exception('Downgrade script not support');	2021-09-22 14:53:19.718582+00
31	30	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect reclada.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 30 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ndrop SEQUENCE IF EXISTS reclada.reclada_revisions;\n\nCREATE SEQUENCE IF not EXISTS reclada.transaction_id\n    START WITH 1\n    INCREMENT BY 1\n    NO MINVALUE\n    NO MAXVALUE\n    CACHE 1;\n\ni 'function/reclada.get_transaction_id.sql' \ni 'function/reclada_object.create.sql' \ni 'function/reclada_object.delete.sql'\ni 'view/reclada.v_object.sql'\ni 'view/reclada.v_active_object.sql'\ni 'function/reclada_object.list.sql'\n\n\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect reclada.raise_exception('Downgrade script not support');	2021-09-23 08:01:33.105744+00
32	31	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect reclada.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 31 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\nSELECT reclada_object.create_subclass('{\n    "class": "RecladaObject",\n    "attributes": {\n        "newClass": "ImportInfo",\n        "properties": {\n            "name": {\n                "type": "string"\n            },\n            "tranID": {\n                "type": "number"\n            }\n        },\n        "required": ["name","tranID"]\n    }\n}'::jsonb);\n\n\ni 'function/reclada.raise_exception.sql'\ni 'function/reclada_object.create.sql' \ni 'view/reclada.v_import_info.sql'\ni 'view/reclada.v_object.sql'\ni 'function/reclada.get_transaction_id_for_import.sql'\ni 'function/reclada_object.delete.sql'\ni 'function/reclada_object.is_equal.sql'\ni 'function/reclada.rollback_import.sql'\n\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect reclada.raise_exception('Downgrade script not support');	2021-09-24 09:46:22.790044+00
33	32	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect reclada.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 32 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\n-- remove revision from object\ni 'view/reclada.v_object.sql'\n\nupdate reclada.object\nset transaction_id = reclada.get_transaction_id()\n\twhere transaction_id is null;\n\nalter table reclada.object\n    alter COLUMN transaction_id set not null;\n\n-- improve for {"class": "609ed4a4-f73a-4c05-9057-57bd212ef8ff"} \ni 'function/reclada_object.list.sql'\n\ni 'function/reclada_object.get_transaction_id.sql'\ni 'function/api.reclada_object_get_transaction_id.sql'\ni 'function/reclada_revision.create.sql'\ni 'function/reclada_object.update.sql'\n\nCREATE INDEX transaction_id_index ON reclada.object (transaction_id);\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect reclada.raise_exception('Downgrade script not support');	2021-09-27 11:09:01.274324+00
34	33	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect reclada.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 33 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'view/reclada.v_PK_for_class.sql'\ni 'function/reclada_object.create.sql'\n\n/*\n    tests:\n        SELECT  guid,\n                for_class,\n                pk \n            FROM reclada.v_pk_for_class;\n    --x3\n    select reclada_object.create('\n    {\n        "class":"File",\n        "attributes":{\n            "uri": "123",\n            "name": "123",\n            "tags": [],\n            "checksum": "123",\n            "mimeType": "pdf"\n        }\n    }');\n    select reclada_object.create('\n    {\n        "class":"File",\n        "attributes":{\n            "uri": "1234",\n            "name": "123",\n            "tags": [],\n            "checksum": "123",\n            "mimeType": "pdf"\n        }\n    }');\n\n*/\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect reclada.raise_exception('Downgrade script not support');	2021-09-28 12:35:37.837433+00
35	34	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect reclada.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 34 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/reclada_object.create.sql'\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect reclada.raise_exception('Downgrade script not support');	2021-09-29 16:57:53.636568+00
36	35	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect reclada.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 35 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'view/reclada.v_PK_for_class.sql'\ni 'function/reclada.get_transaction_id_for_import.sql'\ni 'function/reclada.rollback_import.sql'\n\ni 'function/reclada_user.is_allowed.sql'\ni 'function/api.reclada_object_create.sql'\ni 'function/api.reclada_object_delete.sql'\ni 'function/api.reclada_object_get_transaction_id.sql'\ni 'function/api.reclada_object_list.sql'\ni 'function/api.reclada_object_list_add.sql'\ni 'function/api.reclada_object_list_drop.sql'\ni 'function/api.reclada_object_list_related.sql'\ni 'function/api.reclada_object_update.sql'\ni 'function/api.storage_generate_presigned_get.sql'\ni 'function/api.storage_generate_presigned_post.sql'\ni 'function/reclada_object.list.sql'\n\n\n\nupdate reclada.object \n    set class = '00000000-0000-0000-0000-000000000d0c'\n    WHERE class = \n    (\n        select guid \n            from reclada.object \n                where class = reclada_object.get_jsonschema_GUID()\n                    and attributes->>'forClass' = 'Document'\n    ); \nupdate reclada.object \n    set class = '00000000-0000-0000-0000-000000000f1e'\n    WHERE class = \n    (\n        select guid \n            from reclada.object \n                where class = reclada_object.get_jsonschema_GUID()\n                    and attributes->>'forClass' = 'File'\n    ); \n\nDELETE FROM reclada.object\n    WHERE class = reclada_object.get_jsonschema_GUID()\n        and attributes->>'forClass' = 'Document';\nDELETE FROM reclada.object\n    WHERE class = reclada_object.get_jsonschema_GUID()\n        and attributes->>'forClass' = 'File';\n\nSELECT reclada_object.create_subclass('{\n    "class": "RecladaObject",\n    "attributes": {\n        "newClass": "Document",\n        "properties": {\n            "name": {"type": "string"},\n            "fileGUID": {"type": "string"}\n        },\n        "required": ["name"]\n    }\n}'::jsonb);\n\nSELECT reclada_object.create_subclass('{\n    "class": "DataSource",\n    "attributes": {\n        "newClass": "File",\n        "properties": {\n            "checksum": {"type": "string"},\n            "mimeType": {"type": "string"},\n            "uri": {"type": "string"}\n        },\n        "required": ["checksum", "mimeType"]\n    }\n}'::jsonb);\n\nupdate reclada.object \n    set class = \n    (\n        select guid \n            from reclada.object \n                where class = reclada_object.get_jsonschema_GUID()\n                    and attributes->>'forClass' = 'Document'\n    )\n    WHERE class = '00000000-0000-0000-0000-000000000d0c'; \n\nupdate reclada.object \n    set class = \n    (\n        select guid \n            from reclada.object \n                where class = reclada_object.get_jsonschema_GUID()\n                    and attributes->>'forClass' = 'File'\n    )\n    WHERE class = '00000000-0000-0000-0000-000000000f1e'; \n\nCREATE INDEX IF NOT EXISTS revision_index ON reclada.object ((attributes->>'revision'));\nCREATE INDEX IF NOT EXISTS job_status_index ON reclada.object ((attributes->>'status'));\nCREATE INDEX IF NOT EXISTS runner_type_index  ON reclada.object ((attributes->>'type'));\nCREATE INDEX IF NOT EXISTS file_uri_index  ON reclada.object ((attributes->>'uri'));\nCREATE INDEX IF NOT EXISTS document_fileGUID_index  ON reclada.object ((attributes->>'fileGUID'));\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect reclada.raise_exception('Downgrade script not support');	2021-10-04 08:06:30.979167+00
37	36	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect reclada.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 36 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\nDROP VIEW IF EXISTS reclada.v_revision;\nDROP VIEW IF EXISTS reclada.v_import_info;\nDROP VIEW IF EXISTS reclada.v_pk_for_class;\nDROP VIEW IF EXISTS reclada.v_class;\nDROP VIEW IF EXISTS reclada.v_active_object;\nDROP VIEW IF EXISTS reclada.v_object;\n\nDROP VIEW IF EXISTS reclada.v_object_status;\nDROP VIEW IF EXISTS reclada.v_user;\nDROP VIEW IF EXISTS reclada.v_class_lite;\n\ni 'view/reclada.v_class_lite.sql'\ni 'view/reclada.v_object_status.sql'\ni 'view/reclada.v_user.sql'\n\n\ni 'view/reclada.v_object.sql'\ni 'view/reclada.v_active_object.sql'\ni 'view/reclada.v_class.sql'\ni 'view/reclada.v_pk_for_class.sql'\ni 'view/reclada.v_import_info.sql'\ni 'view/reclada.v_revision.sql'\n\ni 'function/reclada_object.refresh_mv.sql'\ni 'function/reclada_object.datasource_insert.sql'\n\ni 'function/reclada_object.create.sql'\ni 'function/reclada_object.create_subclass.sql'\ni 'function/reclada_object.update.sql'\ni 'function/reclada_object.delete.sql'\n\nDROP TRIGGER IF EXISTS datasource_insert_trigger ON reclada.object;\nDROP FUNCTION IF EXISTS reclada.datasource_insert_trigger_fnc;\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\n\nDROP function IF EXISTS reclada.datasource_insert_trigger_fnc ;\nCREATE OR REPLACE FUNCTION reclada.datasource_insert_trigger_fnc()\n RETURNS trigger\n LANGUAGE plpgsql\nAS $function$\nDECLARE\n    obj_id         uuid;\n    dataset       jsonb;\n    uri           text;\n    environment   varchar;\nBEGIN\n    IF NEW.class in \n            (select reclada_object.get_GUID_for_class('DataSource'))\n        OR NEW.class in (select reclada_object.get_GUID_for_class('File')) THEN\n\n        obj_id := NEW.GUID;\n\n        SELECT v.data\n        FROM reclada.v_active_object v\n\t    WHERE v.attrs->>'name' = 'defaultDataSet'\n\t    INTO dataset;\n\n        dataset := jsonb_set(dataset, '{attributes, dataSources}', dataset->'attributes'->'dataSources' || format('["%s"]', obj_id)::jsonb);\n\n        PERFORM reclada_object.update(dataset);\n\n        uri := NEW.attributes->>'uri';\n\n        SELECT attrs->>'Environment'\n        FROM reclada.v_active_object\n        WHERE class_name = 'Context'\n        ORDER BY created_time DESC\n        LIMIT 1\n        INTO environment;\n\n        PERFORM reclada_object.create(\n            format('{\n                "class": "Job",\n                "attributes": {\n                    "task": "c94bff30-15fa-427f-9954-d5c3c151e652",\n                    "status": "new",\n                    "type": "%s",\n                    "command": "./run_pipeline.sh",\n                    "inputParameters": [{"uri": "%s"}, {"dataSourceId": "%s"}]\n                    }\n                }', environment, uri, obj_id)::jsonb);\n\n    END IF;\n\nRETURN NEW;\nEND;\n$function$\n;\n\ncreate trigger datasource_insert_trigger before\ninsert\n    on\n    reclada.object for each row execute function datasource_insert_trigger_fnc();\n\nDROP VIEW IF EXISTS reclada.v_revision;\nDROP VIEW IF EXISTS reclada.v_import_info;\nDROP VIEW IF EXISTS reclada.v_pk_for_class;\nDROP VIEW IF EXISTS reclada.v_class;\nDROP VIEW IF EXISTS reclada.v_active_object;\nDROP VIEW IF EXISTS reclada.v_object;\n\nDROP MATERIALIZED VIEW IF EXISTS reclada.v_object_status;\nDROP MATERIALIZED VIEW IF EXISTS reclada.v_user;\nDROP MATERIALIZED VIEW IF EXISTS reclada.v_class_lite;\n\nDROP view IF EXISTS reclada.v_class_lite ;\nCREATE OR REPLACE VIEW reclada.v_class_lite\nAS\n SELECT obj.id,\n    obj.guid AS obj_id,\n    obj.attributes ->> 'forClass'::text AS for_class,\n    (obj.attributes ->> 'version'::text)::bigint AS version,\n    obj.created_time,\n    obj.attributes,\n    obj.status\n   FROM object obj\n  WHERE obj.class = reclada_object.get_jsonschema_guid();\nDROP view IF EXISTS reclada.v_object_status ;\nCREATE OR REPLACE VIEW reclada.v_object_status\nAS\n SELECT obj.id,\n    obj.guid AS obj_id,\n    obj.attributes ->> 'caption'::text AS caption,\n    obj.created_time,\n    obj.attributes AS attrs\n   FROM object obj\n  WHERE (obj.class IN ( SELECT reclada_object.get_guid_for_class('ObjectStatus'::text) AS get_guid_for_class));\nDROP view IF EXISTS reclada.v_user ;\nCREATE OR REPLACE VIEW reclada.v_user\nAS\n SELECT obj.id,\n    obj.guid AS obj_id,\n    obj.attributes ->> 'login'::text AS login,\n    obj.created_time,\n    obj.attributes AS attrs\n   FROM object obj\n  WHERE (obj.class IN ( SELECT reclada_object.get_guid_for_class('User'::text) AS get_guid_for_class)) AND obj.status = reclada_object.get_active_status_obj_id();\n\nDROP view IF EXISTS reclada.v_object ;\nCREATE OR REPLACE VIEW reclada.v_object\nAS\n WITH t AS (\n         SELECT obj.id,\n            obj.guid,\n            obj.class,\n            r.num,\n            NULLIF(obj.attributes ->> 'revision'::text, ''::text)::uuid AS revision,\n            obj.attributes,\n            obj.status,\n            obj.created_time,\n            obj.created_by,\n            obj.transaction_id\n           FROM object obj\n             LEFT JOIN ( SELECT (r_1.attributes ->> 'num'::text)::bigint AS num,\n                    r_1.guid\n                   FROM object r_1\n                  WHERE (r_1.class IN ( SELECT reclada_object.get_guid_for_class('revision'::text) AS get_guid_for_class))) r ON r.guid = NULLIF(obj.attributes ->> 'revision'::text, ''::text)::uuid\n        )\n SELECT t.id,\n    t.guid AS obj_id,\n    t.class,\n    t.num AS revision_num,\n    os.caption AS status_caption,\n    t.revision,\n    t.created_time,\n    t.attributes AS attrs,\n    cl.for_class AS class_name,\n    (( SELECT json_agg(tmp.*) -> 0\n           FROM ( SELECT t.guid AS "GUID",\n                    t.class,\n                    os.caption AS status,\n                    t.attributes,\n                    t.transaction_id AS "transactionID") tmp))::jsonb AS data,\n    u.login AS login_created_by,\n    t.created_by,\n    t.status,\n    t.transaction_id\n   FROM t\n     LEFT JOIN v_object_status os ON t.status = os.obj_id\n     LEFT JOIN v_user u ON u.obj_id = t.created_by\n     LEFT JOIN v_class_lite cl ON cl.obj_id = t.class;\nDROP view IF EXISTS reclada.v_active_object ;\nCREATE OR REPLACE VIEW reclada.v_active_object\nAS\n SELECT t.id,\n    t.obj_id,\n    t.class,\n    t.revision_num,\n    t.status,\n    t.status_caption,\n    t.revision,\n    t.created_time,\n    t.class_name,\n    t.attrs,\n    t.data,\n    t.transaction_id\n   FROM v_object t\n  WHERE t.status = reclada_object.get_active_status_obj_id();\nDROP view IF EXISTS reclada.v_class ;\nCREATE OR REPLACE VIEW reclada.v_class\nAS\n SELECT obj.id,\n    obj.obj_id,\n    obj.attrs ->> 'forClass'::text AS for_class,\n    (obj.attrs ->> 'version'::text)::bigint AS version,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class_name = 'jsonschema'::text;\nDROP view IF EXISTS reclada.v_pk_for_class ;\nCREATE OR REPLACE VIEW reclada.v_pk_for_class\nAS\n SELECT obj.obj_id AS guid,\n    obj.for_class,\n    pk.pk\n   FROM v_class obj\n     JOIN ( SELECT 'File'::text AS class_name,\n            'uri'::text AS pk) pk ON pk.class_name = obj.for_class;\nDROP view IF EXISTS reclada.v_import_info ;\nCREATE OR REPLACE VIEW reclada.v_import_info\nAS\n SELECT obj.id,\n    obj.obj_id AS guid,\n    (obj.attrs ->> 'tranID'::text)::bigint AS tran_id,\n    obj.attrs ->> 'name'::text AS name,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class_name = 'ImportInfo'::text;\nDROP view IF EXISTS reclada.v_revision ;\nCREATE OR REPLACE VIEW reclada.v_revision\nAS\n SELECT obj.id,\n    obj.obj_id,\n    (obj.attrs ->> 'num'::text)::bigint AS num,\n    obj.attrs ->> 'branch'::text AS branch,\n    obj.attrs ->> 'user'::text AS "user",\n    obj.attrs ->> 'dateTime'::text AS date_time,\n    obj.attrs ->> 'old_num'::text AS old_num,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class_name = 'revision'::text;\n\nDROP FUNCTION reclada_object.refresh_mv;\nDROP FUNCTION reclada_object.datasource_insert;\n\nDROP function IF EXISTS reclada_object.create_subclass ;\nCREATE OR REPLACE FUNCTION reclada_object.create_subclass(data jsonb)\n RETURNS void\n LANGUAGE plpgsql\nAS $function$\nDECLARE\n    class           text;\n    new_class       text;\n    attrs           jsonb;\n    class_schema    jsonb;\n    version_         integer;\n\nBEGIN\n\n    class := data->>'class';\n    IF (class IS NULL) THEN\n        RAISE EXCEPTION 'The reclada object class is not specified';\n    END IF;\n\n    attrs := data->'attributes';\n    IF (attrs IS NULL) THEN\n        RAISE EXCEPTION 'The reclada object must have attributes';\n    END IF;\n\n    new_class = attrs->>'newClass';\n\n    SELECT reclada_object.get_schema(class) INTO class_schema;\n\n    IF (class_schema IS NULL) THEN\n        RAISE EXCEPTION 'No json schema available for %', class;\n    END IF;\n\n    SELECT max(version) + 1\n    FROM reclada.v_class_lite v\n    WHERE v.for_class = new_class\n    INTO version_;\n\n    version_ := coalesce(version_,1);\n    class_schema := class_schema->'attributes'->'schema';\n\n    PERFORM reclada_object.create(format('{\n        "class": "jsonschema",\n        "attributes": {\n            "forClass": "%s",\n            "version": "%s",\n            "schema": {\n                "type": "object",\n                "properties": %s,\n                "required": %s\n            }\n        }\n    }',\n    new_class,\n    version_,\n    (class_schema->'properties') || (attrs->'properties'),\n    (SELECT jsonb_agg(el) FROM (\n        SELECT DISTINCT pg_catalog.jsonb_array_elements(\n            (class_schema -> 'required') || (attrs -> 'required')\n        ) el) arr)\n    )::jsonb);\n\nEND;\n$function$\n;\nDROP function IF EXISTS reclada_object.create ;\nCREATE OR REPLACE FUNCTION reclada_object."create"(data_jsonb jsonb, user_info jsonb DEFAULT '{}'::jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\nDECLARE\n    branch        uuid;\n    data          jsonb;\n    class_name    text;\n    class_uuid    uuid;\n    tran_id       bigint;\n    _attrs         jsonb;\n    schema        jsonb;\n    obj_GUID      uuid;\n    res           jsonb;\n    affected      uuid[];\nBEGIN\n\n    IF (jsonb_typeof(data_jsonb) != 'array') THEN\n        data_jsonb := '[]'::jsonb || data_jsonb;\n    END IF;\n    /*TODO: check if some objects have revision and others do not */\n    branch:= data_jsonb->0->'branch';\n\n    FOR data IN SELECT jsonb_array_elements(data_jsonb) \n    LOOP\n\n        class_name := data->>'class';\n\n        IF (class_name IS NULL) THEN\n            RAISE EXCEPTION 'The reclada object class is not specified';\n        END IF;\n        class_uuid := reclada.try_cast_uuid(class_name);\n\n        _attrs := data->'attributes';\n        IF (_attrs IS NULL) THEN\n            RAISE EXCEPTION 'The reclada object must have attributes';\n        END IF;\n\n        tran_id := (data->>'transactionID')::bigint;\n        if tran_id is null then\n            tran_id := reclada.get_transaction_id();\n        end if;\n\n        IF class_uuid IS NULL THEN\n            SELECT reclada_object.get_schema(class_name) \n            INTO schema;\n            class_uuid := (schema->>'GUID')::uuid;\n        ELSE\n            SELECT v.data \n            FROM reclada.v_class v\n            WHERE class_uuid = v.obj_id\n            INTO schema;\n        END IF;\n        IF (schema IS NULL) THEN\n            RAISE EXCEPTION 'No json schema available for %', class_name;\n        END IF;\n\n        IF (NOT(public.validate_json_schema(schema->'attributes'->'schema', _attrs))) THEN\n            RAISE EXCEPTION 'JSON invalid: %', _attrs;\n        END IF;\n        \n        IF data->>'id' IS NOT NULL THEN\n            RAISE EXCEPTION '%','Field "id" not allow!!!';\n        END IF;\n\n        IF class_uuid IN (SELECT guid FROM reclada.v_PK_for_class)\n        THEN\n            SELECT o.obj_id\n                FROM reclada.v_object o\n                JOIN reclada.v_PK_for_class pk\n                    on pk.guid = o.class\n                        and class_uuid = o.class\n                where o.attrs->>pk.pk = _attrs ->> pk.pk\n                LIMIT 1\n            INTO obj_GUID;\n            IF obj_GUID IS NOT NULL THEN\n                SELECT reclada_object.update(data || format('{"GUID": "%s"}', obj_GUID)::jsonb)\n                    INTO res;\n                    RETURN '[]'::jsonb || res;\n            END IF;\n        END IF;\n\n        obj_GUID := (data->>'GUID')::uuid;\n        IF EXISTS (\n            SELECT 1\n            FROM reclada.object \n            WHERE GUID = obj_GUID\n        ) THEN\n            RAISE EXCEPTION 'GUID: % is duplicate', obj_GUID;\n        END IF;\n        --raise notice 'schema: %',schema;\n\n        INSERT INTO reclada.object(GUID,class,attributes,transaction_id)\n            SELECT  CASE\n                        WHEN obj_GUID IS NULL\n                            THEN public.uuid_generate_v4()\n                        ELSE obj_GUID\n                    END AS GUID,\n                    class_uuid, \n                    _attrs,\n                    tran_id\n        RETURNING GUID INTO obj_GUID;\n        affected := array_append( affected, obj_GUID);\n\n    END LOOP;\n\n    res := array_to_json\n            (\n                array\n                (\n                    SELECT o.data \n                    FROM reclada.v_active_object o\n                    WHERE o.obj_id = ANY (affected)\n                )\n            )::jsonb; \n    PERFORM reclada_notification.send_object_notification\n        (\n            'create',\n            res\n        );\n    RETURN res;\n\nEND;\n$function$\n;\nDROP function IF EXISTS reclada_object.update ;\nCREATE OR REPLACE FUNCTION reclada_object.update(data jsonb, user_info jsonb DEFAULT '{}'::jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\nDECLARE\n    class_name     text;\n    class_uuid     uuid;\n    v_obj_id       uuid;\n    v_attrs        jsonb;\n    schema        jsonb;\n    old_obj       jsonb;\n    branch        uuid;\n    revid         uuid;\n\nBEGIN\n\n    class_name := data->>'class';\n    IF (class_name IS NULL) THEN\n        RAISE EXCEPTION 'The reclada object class is not specified';\n    END IF;\n    class_uuid := reclada.try_cast_uuid(class_name);\n    v_obj_id := data->>'GUID';\n    IF (v_obj_id IS NULL) THEN\n        RAISE EXCEPTION 'Could not update object with no GUID';\n    END IF;\n\n    v_attrs := data->'attributes';\n    IF (v_attrs IS NULL) THEN\n        RAISE EXCEPTION 'The reclada object must have attributes';\n    END IF;\n\n    SELECT reclada_object.get_schema(class_name) \n        INTO schema;\n\n    if class_uuid is null then\n        SELECT reclada_object.get_schema(class_name) \n            INTO schema;\n    else\n        select v.data \n            from reclada.v_class v\n                where class_uuid = v.obj_id\n            INTO schema;\n    end if;\n    -- TODO: don't allow update jsonschema\n    IF (schema IS NULL) THEN\n        RAISE EXCEPTION 'No json schema available for %', class_name;\n    END IF;\n\n    IF (NOT(public.validate_json_schema(schema->'attributes'->'schema', v_attrs))) THEN\n        RAISE EXCEPTION 'JSON invalid: %', v_attrs;\n    END IF;\n\n    SELECT \tv.data\n        FROM reclada.v_active_object v\n\t        WHERE v.obj_id = v_obj_id\n\t    INTO old_obj;\n\n    IF (old_obj IS NULL) THEN\n        RAISE EXCEPTION 'Could not update object, no such id';\n    END IF;\n\n    branch := data->'branch';\n    SELECT reclada_revision.create(user_info->>'sub', branch, v_obj_id) \n        INTO revid;\n    \n    with t as \n    (\n        update reclada.object o\n            set status = reclada_object.get_archive_status_obj_id()\n                where o.GUID = v_obj_id\n                    and status != reclada_object.get_archive_status_obj_id()\n                        RETURNING id\n    )\n    INSERT INTO reclada.object( GUID,\n                                class,\n                                status,\n                                attributes,\n                                transaction_id\n                              )\n        select  v.obj_id,\n                (schema->>'GUID')::uuid,\n                reclada_object.get_active_status_obj_id(),--status \n                v_attrs || format('{"revision":"%s"}',revid)::jsonb,\n                transaction_id\n            FROM reclada.v_object v\n            JOIN t \n                on t.id = v.id\n\t            WHERE v.obj_id = v_obj_id;\n                    \n    select v.data \n        FROM reclada.v_active_object v\n            WHERE v.obj_id = v_obj_id\n        into data;\n    PERFORM reclada_notification.send_object_notification('update', data);\n    RETURN data;\nEND;\n$function$\n;\nDROP function IF EXISTS reclada_object.delete ;\nCREATE OR REPLACE FUNCTION reclada_object.delete(data jsonb, user_info jsonb DEFAULT '{}'::jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\nDECLARE\n    v_obj_id            uuid;\n    tran_id             bigint;\n    class               text;\n    class_uuid          uuid;\n    list_id             bigint[];\n\nBEGIN\n\n    v_obj_id := data->>'GUID';\n    tran_id := (data->>'transactionID')::bigint;\n    class := data->>'class';\n\n    IF (v_obj_id IS NULL AND class IS NULL AND tran_id IS NULl) THEN\n        RAISE EXCEPTION 'Could not delete object with no GUID, class and transactionID';\n    END IF;\n\n    class_uuid := reclada.try_cast_uuid(class);\n\n    WITH t AS\n    (    \n        UPDATE reclada.object u\n            SET status = reclada_object.get_archive_status_obj_id()\n            FROM reclada.object o\n                LEFT JOIN\n                (   SELECT obj_id FROM reclada_object.get_GUID_for_class(class)\n                    UNION SELECT class_uuid WHERE class_uuid IS NOT NULL\n                ) c ON o.class = c.obj_id\n                WHERE u.id = o.id AND\n                (\n                    (v_obj_id = o.GUID AND c.obj_id = o.class AND tran_id = o.transaction_id)\n\n                    OR (v_obj_id = o.GUID AND c.obj_id = o.class AND tran_id IS NULL)\n                    OR (v_obj_id = o.GUID AND c.obj_id IS NULL AND tran_id = o.transaction_id)\n                    OR (v_obj_id IS NULL AND c.obj_id = o.class AND tran_id = o.transaction_id)\n\n                    OR (v_obj_id = o.GUID AND c.obj_id IS NULL AND tran_id IS NULL)\n                    OR (v_obj_id IS NULL AND c.obj_id = o.class AND tran_id IS NULL)\n                    OR (v_obj_id IS NULL AND c.obj_id IS NULL AND tran_id = o.transaction_id)\n                )\n                    AND o.status != reclada_object.get_archive_status_obj_id()\n                    RETURNING o.id\n    ) \n        SELECT\n            array\n            (\n                SELECT t.id FROM t\n            )\n        INTO list_id;\n\n    SELECT array_to_json\n    (\n        array\n        (\n            SELECT o.data\n            FROM reclada.v_object o\n            WHERE o.id IN (SELECT unnest(list_id))\n        )\n    )::jsonb\n    INTO data;\n\n    IF (jsonb_array_length(data) = 1) THEN\n        data := data->0;\n    END IF;\n    \n    IF (data IS NULL) THEN\n        RAISE EXCEPTION 'Could not delete object, no such GUID';\n    END IF;\n\n    PERFORM reclada_notification.send_object_notification('delete', data);\n\n    RETURN data;\nEND;\n$function$\n;	2021-10-07 11:23:22.77559+00
\.


--
-- Data for Name: auth_setting; Type: TABLE DATA; Schema: reclada; Owner: -
--

COPY reclada.auth_setting (oidc_url, oidc_client_id, oidc_redirect_url, jwk) FROM stdin;
\.


--
-- Data for Name: object; Type: TABLE DATA; Schema: reclada; Owner: -
--

COPY reclada.object (id, status, attributes, transaction_id, created_time, created_by, class, guid) FROM stdin;
22	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"caption": "active", "revision": "090c2cee-db0f-4637-9524-fb15e9c7362b"}	9	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	14af3113-18b5-4da8-af57-bdf37a6693aa	3748b1f7-b674-47ca-9ded-d011b16bbf7b
33	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["number", "bbox", "document"], "properties": {"bbox": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "number": {"type": "number"}, "document": {"type": "string"}}}, "version": "1", "forClass": "Page"}	2	2021-09-22 14:52:57.011935+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	3ed1c180-a508-4180-9281-2f9b9a9cd477
34	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["top", "left", "height", "width"], "properties": {"top": {"type": "number"}, "left": {"type": "number"}, "tags": {"type": "array", "items": {"type": "string"}}, "width": {"type": "number"}, "height": {"type": "number"}}}, "version": "1", "forClass": "BBox"}	3	2021-09-22 14:52:57.133151+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	c835c5b4-3b4f-49d7-b9b2-05a911234682
29	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["dateTime"], "properties": {"num": {"type": "number"}, "tags": {"type": "array", "items": {"type": "string"}}, "user": {"type": "string"}, "branch": {"type": "string"}, "dateTime": {"type": "string"}}}, "version": 1, "forClass": "revision"}	4	2021-09-22 14:51:54.773219+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	0f317fbd-8861-4d68-82ce-de7241d7db0f
35	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["text", "bbox", "page"], "properties": {"bbox": {"type": "string"}, "page": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "text": {"type": "string"}}}, "version": "1", "forClass": "TextBlock"}	5	2021-09-22 14:52:57.258646+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	9ed31858-a681-49fb-9e64-250b1afaf691
36	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["bbox", "page"], "properties": {"bbox": {"type": "string"}, "page": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}}}, "version": "1", "forClass": "Table"}	6	2021-09-22 14:52:57.379526+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	f5bcc7ad-1a9b-476d-985e-54cf01377530
37	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["colspan", "row", "text", "bbox", "table", "cellType", "rowspan", "column"], "properties": {"row": {"type": "number"}, "bbox": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "text": {"type": "string"}, "table": {"type": "string"}, "column": {"type": "number"}, "colspan": {"type": "number"}, "rowspan": {"type": "number"}, "cellType": {"type": "string"}}}, "version": "1", "forClass": "Cell"}	7	2021-09-22 14:52:57.502377+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	7f56ece0-e780-4496-8573-1ad4d800a3b6
38	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["row", "table"], "properties": {"row": {"type": "number"}, "tags": {"type": "array", "items": {"type": "string"}}, "table": {"type": "string"}}}, "version": "1", "forClass": "DataRow"}	8	2021-09-22 14:52:58.301966+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	7643b601-43c2-4125-831a-539b9e7418ec
18	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"name": "defaultDataSet", "revision": "a04d127e-5ea0-4683-8eff-2ea8d1ba5f24", "dataSources": []}	10	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	be193cf5-3156-4df4-8c9b-58b09524ce2f	10c400ff-a328-450d-ae07-ce7d427d961c
20	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["caption"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "caption": {"type": "string"}}}, "version": 1, "forClass": "ObjectStatus", "revision": "0b3c19cb-85f6-4481-bd91-30d004197cac"}	11	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	14af3113-18b5-4da8-af57-bdf37a6693aa
8	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["name"], "properties": {"uri": {"type": "string"}, "name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}}}, "version": 1, "forClass": "DataSource", "revision": "559af2a2-371c-432f-92a7-e567da60565d"}	13	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	92a95f66-e28e-4ebc-9f33-3568fc5a281e
6	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["name"], "properties": {"name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}}}, "version": 1, "forClass": "tag", "revision": "195b2a06-4b6e-4e7c-a610-58fc09f646c8"}	14	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	e12e729b-ac44-45bc-8271-9f0c6d4fa27b
12	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["accessKeyId", "secretAccessKey", "bucketName"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "bucketName": {"type": "string"}, "regionName": {"type": "string"}, "accessKeyId": {"type": "string"}, "endpointURL": {"type": "string"}, "secretAccessKey": {"type": "string"}}}, "version": 1, "forClass": "S3Config", "revision": "fcb96cad-9879-4668-8da0-cd705175dc90"}	15	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	67f37293-2dd6-469c-bc2d-923533991f77
39	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["command", "type"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "type": {"type": "string"}, "command": {"type": "string"}, "inputParameters": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "outputParameters": {"type": "array", "items": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}}}}, "version": "1", "forClass": "Task"}	16	2021-09-22 14:53:02.985704+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	ba7211ce-92e5-4cbb-aa1b-a3259a9a4f54
40	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"attrs": ["status", "type"], "class": "Task", "event": "create", "channelName": "task_created"}	17	2021-09-22 14:53:03.155494+00	16d789c1-1b4e-4815-b70c-4ef060e90884	54f657db-bc6a-4a37-8fb6-8566aee49b33	4e79a0e3-6cf6-42b0-bc0e-f4222530d316
41	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"attrs": ["status", "type"], "class": "Task", "event": "update", "channelName": "task_updated"}	18	2021-09-22 14:53:03.155494+00	16d789c1-1b4e-4815-b70c-4ef060e90884	54f657db-bc6a-4a37-8fb6-8566aee49b33	8a4f92ef-0e48-4387-9e93-688525ba8697
42	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"attrs": ["type"], "class": "Task", "event": "delete", "channelName": "task_deleted"}	19	2021-09-22 14:53:03.155494+00	16d789c1-1b4e-4815-b70c-4ef060e90884	54f657db-bc6a-4a37-8fb6-8566aee49b33	5f1b0908-8ea2-44f8-a380-7d9aee07ea99
43	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["name", "type"], "properties": {"file": {"type": "string"}, "name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "type": {"enum": ["code", "stdout", "stderr", "file"], "type": "string"}}}, "version": "1", "forClass": "Parameter"}	20	2021-09-22 14:53:03.359018+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	07533caf-3a5f-47ba-998c-494b69a9cc29
44	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["nextTask", "previousJobCode"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "nextTask": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "previousJobCode": {"type": "integer"}, "paramsRelationships": {"type": "array", "items": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}}}}, "version": "1", "forClass": "Trigger"}	21	2021-09-22 14:53:03.507583+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	a000a736-f147-4527-8849-e36efea8061e
45	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["command", "triggers", "type"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "type": {"type": "string"}, "command": {"type": "string"}, "triggers": {"type": "array", "items": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}}, "inputParameters": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "outputParameters": {"type": "array", "items": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}}}}, "version": "1", "forClass": "Pipeline"}	22	2021-09-22 14:53:03.657134+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	dc9eaa02-dd42-4336-bcd6-4eefe147efea
46	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["command", "status", "type", "task"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "task": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "type": {"type": "string"}, "runner": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "status": {"type": "string", "enum ": ["new", "pending", "running", "failed", "success"]}, "command": {"type": "string"}, "inputParameters": {"type": "array", "items": {"type": "object"}}, "outputParameters": {"type": "array", "items": {"type": "object"}}}}, "version": "1", "forClass": "Job"}	23	2021-09-22 14:53:03.806643+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	75a8fd8b-f709-445c-a551-e8454c0ef179
47	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"attrs": ["status", "type"], "class": "Job", "event": "create", "channelName": "job_created"}	24	2021-09-22 14:53:03.95338+00	16d789c1-1b4e-4815-b70c-4ef060e90884	54f657db-bc6a-4a37-8fb6-8566aee49b33	45f586df-e867-4024-a92c-81d26ada1a16
48	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"attrs": ["status", "type"], "class": "Job", "event": "update", "channelName": "job_updated"}	25	2021-09-22 14:53:03.95338+00	16d789c1-1b4e-4815-b70c-4ef060e90884	54f657db-bc6a-4a37-8fb6-8566aee49b33	cca09dc6-2eb4-4d41-99c6-063d8763f789
49	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"attrs": ["type"], "class": "Job", "event": "delete", "channelName": "job_deleted"}	26	2021-09-22 14:53:03.95338+00	16d789c1-1b4e-4815-b70c-4ef060e90884	54f657db-bc6a-4a37-8fb6-8566aee49b33	b58aa7bb-c002-4c55-85a3-8ba8b167c92b
50	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["subject", "type", "object"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "type": {"type": "string", "enum ": ["params"]}, "object": {"type": "string"}, "subject": {"type": "string"}}}, "version": "1", "forClass": "Relationship"}	27	2021-09-22 14:53:04.158111+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	2d054574-8f7a-4a9a-a3b3-0400ad9d0489
51	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["name"], "properties": {"name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "value": {"type": "string"}}}, "version": "1", "forClass": "Value"}	28	2021-09-22 14:53:04.310403+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	9ac7a8c3-8d7c-4443-b5fd-c1a8f31ee13e
52	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["command", "status", "type", "task", "environment"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "task": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "type": {"type": "string"}, "runner": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "status": {"type": "string", "enum ": ["up", "down", "idle"]}, "command": {"type": "string"}, "environment": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "inputParameters": {"type": "array", "items": {"type": "object"}}, "outputParameters": {"type": "array", "items": {"type": "object"}}}}, "version": "1", "forClass": "Runner"}	29	2021-09-22 14:53:04.461972+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	b6e879da-731f-48c3-99b5-e48d73a74930
53	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["name"], "properties": {"name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "description": {"type": "string"}}}, "version": "1", "forClass": "Environment"}	30	2021-09-22 14:53:04.621778+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	7983c3aa-75f5-4d91-a0af-519a122893f6
4	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": [], "properties": {"tags": {"type": "array", "items": {"type": "string"}}}}, "version": 1, "forClass": "RecladaObject", "revision": "6035277c-e142-4a27-ae34-4800cee8c89c"}	31	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	ab9ab26c-8902-43dd-9f1a-743b14a89825
2	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["forClass", "schema"], "properties": {"schema": {"type": "object"}, "forClass": {"type": "string"}}}, "version": 1, "forClass": "jsonschema", "revision": "aacd64a4-7585-456f-8546-37da218b5481"}	32	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	5362d59b-82a1-4c7c-8ec3-07c256009fb0
16	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["channelName", "event", "class"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "attrs": {"type": "array", "items": {"type": "string"}}, "class": {"type": "string"}, "event": {"enum": ["create", "update", "list", "delete"], "type": "string"}, "channelName": {"type": "string"}}}, "version": 1, "forClass": "Message", "revision": "cc1ced42-1354-49ea-ba65-5a6562547618"}	33	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	54f657db-bc6a-4a37-8fb6-8566aee49b33
54	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["extension", "mimeType"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "mimeType": {"type": "string"}, "extension": {"type": "string"}}}, "version": "1", "forClass": "FileExtension"}	34	2021-09-22 14:53:04.773268+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	e291db3a-4942-441f-a320-079c9eb5e3bb
55	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"mimeType": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "extension": ".xlsx"}	35	2021-09-22 14:53:04.924895+00	16d789c1-1b4e-4815-b70c-4ef060e90884	e291db3a-4942-441f-a320-079c9eb5e3bb	8831f967-a71b-4721-ab78-caefab138d37
56	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["command", "name", "type", "environment"], "properties": {"name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "type": {"type": "string"}, "command": {"type": "string"}, "environment": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "inputParameters": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "outputParameters": {"type": "array", "items": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}}, "connectionDetails": {"type": "string"}}}, "version": "1", "forClass": "Connector"}	36	2021-09-22 14:53:05.114361+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	6e474d14-04bb-4a82-87db-1c495664172f
31	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["Environment"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "Lambda": {"type": "string"}, "Environment": {"type": "string"}}}, "version": "1", "forClass": "Context"}	37	2021-09-22 14:52:29.56296+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	ea01e538-fa4d-49de-ad05-dad73a5dbaca
13	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 7, "dateTime": "2021-09-22 14:50:30.246626+00"}	38	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	23a3251b-6269-456f-a5b7-09ce1b0df3e3
11	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 6, "dateTime": "2021-09-22 14:50:30.154503+00"}	39	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	fcb96cad-9879-4668-8da0-cd705175dc90
9	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 5, "dateTime": "2021-09-22 14:50:30.063341+00"}	40	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	49a01e01-8663-437e-b261-d77800518497
7	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 4, "dateTime": "2021-09-22 14:50:29.958841+00"}	41	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	559af2a2-371c-432f-92a7-e567da60565d
5	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 3, "dateTime": "2021-09-22 14:50:29.866858+00"}	42	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	195b2a06-4b6e-4e7c-a610-58fc09f646c8
3	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 2, "dateTime": "2021-09-22 14:50:29.712093+00"}	43	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	6035277c-e142-4a27-ae34-4800cee8c89c
1	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 1, "dateTime": "2021-09-22 14:50:29.624416+00"}	44	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	aacd64a4-7585-456f-8546-37da218b5481
21	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 11, "dateTime": "2021-09-22 14:50:50.411942+00"}	45	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	090c2cee-db0f-4637-9524-fb15e9c7362b
25	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 13, "dateTime": "2021-09-22 14:50:50.411942+00"}	46	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	de7cfae5-c8c3-4ecc-b147-1427eb792f82
23	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 12, "dateTime": "2021-09-22 14:50:50.411942+00"}	47	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	b77c3f09-59eb-4aa0-bc83-208d32d9855d
19	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 10, "dateTime": "2021-09-22 14:50:50.411942+00"}	48	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	0b3c19cb-85f6-4481-bd91-30d004197cac
17	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 9, "dateTime": "2021-09-22 14:50:30.427941+00"}	49	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	a04d127e-5ea0-4683-8eff-2ea8d1ba5f24
15	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 8, "dateTime": "2021-09-22 14:50:30.338803+00"}	50	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	cc1ced42-1354-49ea-ba65-5a6562547618
27	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 14, "dateTime": "2021-09-22 14:50:50.411942+00"}	51	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	92d414ce-56aa-4c4a-87f1-5027b0156ba9
28	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"login": "dev", "revision": "92d414ce-56aa-4c4a-87f1-5027b0156ba9"}	52	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	77f7d007-960f-4236-84fa-feadf3267bcf	16d789c1-1b4e-4815-b70c-4ef060e90884
24	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"caption": "archive", "revision": "b77c3f09-59eb-4aa0-bc83-208d32d9855d"}	53	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	14af3113-18b5-4da8-af57-bdf37a6693aa	9dc0a032-90d6-4638-956e-9cd64cd2900c
26	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["login"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "login": {"type": "string"}}}, "version": 1, "forClass": "User", "revision": "de7cfae5-c8c3-4ecc-b147-1427eb792f82"}	54	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	77f7d007-960f-4236-84fa-feadf3267bcf
14	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["name"], "properties": {"name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "dataSources": {"type": "array", "items": {"type": "string"}}}}, "version": 1, "forClass": "DataSet", "revision": "23a3251b-6269-456f-a5b7-09ce1b0df3e3"}	55	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	be193cf5-3156-4df4-8c9b-58b09524ce2f
57	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["tranID", "name"], "properties": {"name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "tranID": {"type": "number"}}}, "version": "1", "forClass": "ImportInfo"}	56	2021-09-24 09:46:22.790044+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	6f5245bd-1eec-4be0-8a28-681758155e33
58	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["name"], "properties": {"name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "fileGUID": {"type": "string"}}}, "version": "1", "forClass": "Document"}	57	2021-10-04 08:06:30.979167+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	85d32073-4a00-4df7-9def-7de8d90b77e0
59	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["checksum", "name", "mimeType"], "properties": {"uri": {"type": "string"}, "name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "checksum": {"type": "string"}, "mimeType": {"type": "string"}}}, "version": "1", "forClass": "File"}	58	2021-10-04 08:06:30.979167+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	c7fc0455-0572-40d7-987f-583cc2c9630c
\.


--
-- Name: t_dbg_id_seq; Type: SEQUENCE SET; Schema: dev; Owner: -
--

SELECT pg_catalog.setval('dev.t_dbg_id_seq', 23, true);


--
-- Name: ver_id_seq; Type: SEQUENCE SET; Schema: dev; Owner: -
--

SELECT pg_catalog.setval('dev.ver_id_seq', 37, true);


--
-- Name: object_id_seq; Type: SEQUENCE SET; Schema: reclada; Owner: -
--

SELECT pg_catalog.setval('reclada.object_id_seq', 59, true);


--
-- Name: transaction_id; Type: SEQUENCE SET; Schema: reclada; Owner: -
--

SELECT pg_catalog.setval('reclada.transaction_id', 58, true);


--
-- Name: object object_pkey; Type: CONSTRAINT; Schema: reclada; Owner: -
--

ALTER TABLE ONLY reclada.object
    ADD CONSTRAINT object_pkey PRIMARY KEY (id);


--
-- Name: class_index; Type: INDEX; Schema: reclada; Owner: -
--

CREATE INDEX class_index ON reclada.object USING btree (class);


--
-- Name: document_fileguid_index; Type: INDEX; Schema: reclada; Owner: -
--

CREATE INDEX document_fileguid_index ON reclada.object USING btree (((attributes ->> 'fileGUID'::text)));


--
-- Name: file_uri_index; Type: INDEX; Schema: reclada; Owner: -
--

CREATE INDEX file_uri_index ON reclada.object USING btree (((attributes ->> 'uri'::text)));


--
-- Name: guid_index; Type: INDEX; Schema: reclada; Owner: -
--

CREATE INDEX guid_index ON reclada.object USING btree (guid);


--
-- Name: job_status_index; Type: INDEX; Schema: reclada; Owner: -
--

CREATE INDEX job_status_index ON reclada.object USING btree (((attributes ->> 'status'::text)));


--
-- Name: revision_index; Type: INDEX; Schema: reclada; Owner: -
--

CREATE INDEX revision_index ON reclada.object USING btree (((attributes ->> 'revision'::text)));


--
-- Name: runner_type_index; Type: INDEX; Schema: reclada; Owner: -
--

CREATE INDEX runner_type_index ON reclada.object USING btree (((attributes ->> 'type'::text)));


--
-- Name: status_index; Type: INDEX; Schema: reclada; Owner: -
--

CREATE INDEX status_index ON reclada.object USING btree (status);


--
-- Name: transaction_id_index; Type: INDEX; Schema: reclada; Owner: -
--

CREATE INDEX transaction_id_index ON reclada.object USING btree (transaction_id);


--
-- Name: staging load_staging; Type: TRIGGER; Schema: reclada; Owner: -
--

CREATE TRIGGER load_staging INSTEAD OF INSERT ON reclada.staging FOR EACH ROW EXECUTE FUNCTION reclada.load_staging();


--
-- Name: FUNCTION invoke(function_name aws_commons._lambda_function_arn_1, payload json, invocation_type text, log_type text, context json, qualifier character varying, OUT status_code integer, OUT payload json, OUT executed_version text, OUT log_result text); Type: ACL; Schema: aws_lambda; Owner: -
--



--
-- Name: FUNCTION invoke(function_name aws_commons._lambda_function_arn_1, payload jsonb, invocation_type text, log_type text, context jsonb, qualifier character varying, OUT status_code integer, OUT payload jsonb, OUT executed_version text, OUT log_result text); Type: ACL; Schema: aws_lambda; Owner: -
--



--
-- Name: FUNCTION invoke(function_name text, payload json, region text, invocation_type text, log_type text, context json, qualifier character varying, OUT status_code integer, OUT payload json, OUT executed_version text, OUT log_result text); Type: ACL; Schema: aws_lambda; Owner: -
--



--
-- Name: FUNCTION invoke(function_name text, payload jsonb, region text, invocation_type text, log_type text, context jsonb, qualifier character varying, OUT status_code integer, OUT payload jsonb, OUT executed_version text, OUT log_result text); Type: ACL; Schema: aws_lambda; Owner: -
--



--
-- Name: v_class_lite; Type: MATERIALIZED VIEW DATA; Schema: reclada; Owner: -
--

REFRESH MATERIALIZED VIEW reclada.v_class_lite;


--
-- Name: v_object_status; Type: MATERIALIZED VIEW DATA; Schema: reclada; Owner: -
--

REFRESH MATERIALIZED VIEW reclada.v_object_status;


--
-- Name: v_user; Type: MATERIALIZED VIEW DATA; Schema: reclada; Owner: -
--

REFRESH MATERIALIZED VIEW reclada.v_user;


--
-- PostgreSQL database dump complete
--

