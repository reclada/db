-- version = 21
-- 2021-09-14 14:51:08.099548
/*
update_config.json:

{
    "branch_db" : "test",
    "branch_runtime" : "db_refactoring",
    "branch_SciNLP" : "main",
    "server" : "dev-reclada-k8s.c9lpgtggzz0d.eu-west-1.rds.amazonaws.com",  
    "db" : "dev3_reclada_k8s",
    "db_user" : "reclada",
    "quick_install" : false,
    "version": "latest"
}
*/
--
-- PostgreSQL database dump
--

-- Dumped from database version 13.3
-- Dumped by pg_dump version 13.3

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
-- Name: api; Type: SCHEMA; Schema: -; Owner: reclada
--

CREATE SCHEMA api;


ALTER SCHEMA api OWNER TO reclada;

--
-- Name: aws_commons; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS aws_commons WITH SCHEMA public;


--
-- Name: EXTENSION aws_commons; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION aws_commons IS 'Common data types across AWS services';


--
-- Name: aws_lambda; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS aws_lambda WITH SCHEMA public;


--
-- Name: EXTENSION aws_lambda; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION aws_lambda IS 'AWS Lambda integration';


--
-- Name: dev; Type: SCHEMA; Schema: -; Owner: reclada
--

CREATE SCHEMA dev;


ALTER SCHEMA dev OWNER TO reclada;

--
-- Name: reclada; Type: SCHEMA; Schema: -; Owner: reclada
--

CREATE SCHEMA reclada;


ALTER SCHEMA reclada OWNER TO reclada;

--
-- Name: reclada_notification; Type: SCHEMA; Schema: -; Owner: reclada
--

CREATE SCHEMA reclada_notification;


ALTER SCHEMA reclada_notification OWNER TO reclada;

--
-- Name: reclada_object; Type: SCHEMA; Schema: -; Owner: reclada
--

CREATE SCHEMA reclada_object;


ALTER SCHEMA reclada_object OWNER TO reclada;

--
-- Name: reclada_revision; Type: SCHEMA; Schema: -; Owner: reclada
--

CREATE SCHEMA reclada_revision;


ALTER SCHEMA reclada_revision OWNER TO reclada;

--
-- Name: reclada_storage; Type: SCHEMA; Schema: -; Owner: reclada
--

CREATE SCHEMA reclada_storage;


ALTER SCHEMA reclada_storage OWNER TO reclada;

--
-- Name: reclada_user; Type: SCHEMA; Schema: -; Owner: reclada
--

CREATE SCHEMA reclada_user;


ALTER SCHEMA reclada_user OWNER TO reclada;

--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: auth_get_login_url(jsonb); Type: FUNCTION; Schema: api; Owner: reclada
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


ALTER FUNCTION api.auth_get_login_url(data jsonb) OWNER TO reclada;

--
-- Name: hello_world(jsonb); Type: FUNCTION; Schema: api; Owner: reclada
--

CREATE FUNCTION api.hello_world(data jsonb) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$

SELECT 'Hello, world!';

$$;


ALTER FUNCTION api.hello_world(data jsonb) OWNER TO reclada;

--
-- Name: hello_world(text); Type: FUNCTION; Schema: api; Owner: reclada
--

CREATE FUNCTION api.hello_world(data text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$

SELECT 'Hello, world!';

$$;


ALTER FUNCTION api.hello_world(data text) OWNER TO reclada;

--
-- Name: reclada_object_create(jsonb); Type: FUNCTION; Schema: api; Owner: reclada
--

CREATE FUNCTION api.reclada_object_create(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE

    data_jsonb       jsonb;

    class            jsonb;

    user_info        jsonb;

    attrs            jsonb;

    data_to_create   jsonb = '[]'::jsonb;

    result           jsonb;



BEGIN



    IF (jsonb_typeof(data) != 'array') THEN

        data := '[]'::jsonb || data;

    END IF;



    FOR data_jsonb IN SELECT jsonb_array_elements(data) LOOP



        class := data_jsonb->'class';

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


ALTER FUNCTION api.reclada_object_create(data jsonb) OWNER TO reclada;

--
-- Name: reclada_object_delete(jsonb); Type: FUNCTION; Schema: api; Owner: reclada
--

CREATE FUNCTION api.reclada_object_delete(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE

    class         jsonb;

    obj_id         uuid;

    user_info     jsonb;

    result        jsonb;



BEGIN



    class := data->'class';

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


ALTER FUNCTION api.reclada_object_delete(data jsonb) OWNER TO reclada;

--
-- Name: reclada_object_list(jsonb); Type: FUNCTION; Schema: api; Owner: reclada
--

CREATE FUNCTION api.reclada_object_list(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    AS $$

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



    SELECT reclada_object.list(data, true) INTO result;



    RETURN result;



END;

$$;


ALTER FUNCTION api.reclada_object_list(data jsonb) OWNER TO reclada;

--
-- Name: reclada_object_list_add(jsonb); Type: FUNCTION; Schema: api; Owner: reclada
--

CREATE FUNCTION api.reclada_object_list_add(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE

    class          jsonb;

    obj_id         uuid;

    user_info      jsonb;

    field_value    jsonb;

    values_to_add  jsonb;

    result         jsonb;



BEGIN



    class := data->'class';

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


ALTER FUNCTION api.reclada_object_list_add(data jsonb) OWNER TO reclada;

--
-- Name: reclada_object_list_drop(jsonb); Type: FUNCTION; Schema: api; Owner: reclada
--

CREATE FUNCTION api.reclada_object_list_drop(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE

    class           jsonb;

    obj_id          uuid;

    user_info       jsonb;

    field_value     jsonb;

    values_to_drop  jsonb;

    result          jsonb;



BEGIN



	class := data->'class';

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


ALTER FUNCTION api.reclada_object_list_drop(data jsonb) OWNER TO reclada;

--
-- Name: reclada_object_list_related(jsonb); Type: FUNCTION; Schema: api; Owner: reclada
--

CREATE FUNCTION api.reclada_object_list_related(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE

    class          jsonb;

    obj_id         uuid;

    field          jsonb;

    related_class  jsonb;

    user_info      jsonb;

    result         jsonb;



BEGIN

    class := data->'class';

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


ALTER FUNCTION api.reclada_object_list_related(data jsonb) OWNER TO reclada;

--
-- Name: reclada_object_update(jsonb); Type: FUNCTION; Schema: api; Owner: reclada
--

CREATE FUNCTION api.reclada_object_update(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE

    class         jsonb;

    objid         uuid;

    attrs         jsonb;

    user_info     jsonb;

    result        jsonb;



BEGIN



    class := data->'class';

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


ALTER FUNCTION api.reclada_object_update(data jsonb) OWNER TO reclada;

--
-- Name: storage_generate_presigned_get(jsonb); Type: FUNCTION; Schema: api; Owner: reclada
--

CREATE FUNCTION api.storage_generate_presigned_get(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE

    object_data  jsonb;

    object_id    uuid;

    result       jsonb;

    user_info    jsonb;



BEGIN

    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;

    data := data - 'accessToken';



    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned post', '{}'))) THEN

        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';

    END IF;



    -- TODO: check user's permissions for reclada object access?

    object_id := data->>'objectId';

    SELECT reclada_object.list(format(

        '{"class": "File", "attributes": {}, "GUID": "%s"}',

        object_id

    )::jsonb) -> 0 INTO object_data;



    SELECT payload

    FROM aws_lambda.invoke(

        aws_commons.create_lambda_function_arn(

            's3_get_presigned_url_dev2',

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


ALTER FUNCTION api.storage_generate_presigned_get(data jsonb) OWNER TO reclada;

--
-- Name: storage_generate_presigned_post(jsonb); Type: FUNCTION; Schema: api; Owner: reclada
--

CREATE FUNCTION api.storage_generate_presigned_post(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE

    --bucket_name  varchar;

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



    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned post', '{}'))) THEN

        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';

    END IF;



    object_name := data->>'objectName';

    file_type := data->>'fileType';

    --bucket_name := data->>'bucketName';

    /*

    SELECT uuid_generate_v4() INTO object_id;

    object_path := object_id;

    uri := 's3://' || bucket_name || '/' || object_path;



    -- TODO: remove checksum from required attrs for File class?

    SELECT reclada_object.create(format(

        '{"class": "File", "attributes": {"name": "%s", "mimeType": "%s", "uri": "%s", "checksum": "tempChecksum"}}',

        object_name,

        file_type,

        uri

    )::jsonb)->0 INTO object;

    */

    SELECT payload::jsonb

    FROM aws_lambda.invoke(

        aws_commons.create_lambda_function_arn(

            's3_get_presigned_url_dev2',

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

        --'{"object": %s, "uploadUrl": %s}',

        --object,

        '{"uploadUrl": %s}',

        url

    )::jsonb;



    RETURN result;

END;

$$;


ALTER FUNCTION api.storage_generate_presigned_post(data jsonb) OWNER TO reclada;

--
-- Name: downgrade_version(); Type: FUNCTION; Schema: dev; Owner: reclada
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

    perform public.raise_notice(v_msg);

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


ALTER FUNCTION dev.downgrade_version() OWNER TO reclada;

--
-- Name: reg_notice(text); Type: FUNCTION; Schema: dev; Owner: reclada
--

CREATE FUNCTION dev.reg_notice(msg text) RETURNS void
    LANGUAGE plpgsql
    AS $$

BEGIN

    insert into dev.t_dbg(msg)

		select msg;

    perform public.raise_notice(msg);

END

$$;


ALTER FUNCTION dev.reg_notice(msg text) OWNER TO reclada;

--
-- Name: _validate_json_schema_type(text, jsonb); Type: FUNCTION; Schema: public; Owner: reclada
--

CREATE FUNCTION public._validate_json_schema_type(type text, data jsonb) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$

BEGIN

  IF type = 'integer' THEN

    IF jsonb_typeof(data) != 'number' THEN

      RETURN false;

    END IF;

    IF trunc(data::text::numeric) != data::text::numeric THEN

      RETURN false;

    END IF;

  ELSE

    IF type != jsonb_typeof(data) THEN

      RETURN false;

    END IF;

  END IF;

  RETURN true;

END;

$$;


ALTER FUNCTION public._validate_json_schema_type(type text, data jsonb) OWNER TO reclada;

--
-- Name: raise_exception(text); Type: FUNCTION; Schema: public; Owner: reclada
--

CREATE FUNCTION public.raise_exception(msg text) RETURNS void
    LANGUAGE plpgsql
    AS $$

BEGIN

    -- 

    RAISE EXCEPTION '%', msg;

END

$$;


ALTER FUNCTION public.raise_exception(msg text) OWNER TO reclada;

--
-- Name: raise_notice(text); Type: FUNCTION; Schema: public; Owner: reclada
--

CREATE FUNCTION public.raise_notice(msg text) RETURNS void
    LANGUAGE plpgsql
    AS $$

BEGIN

    -- 

    RAISE NOTICE '%', msg;

END

$$;


ALTER FUNCTION public.raise_notice(msg text) OWNER TO reclada;

--
-- Name: try_cast_int(text, integer); Type: FUNCTION; Schema: public; Owner: reclada
--

CREATE FUNCTION public.try_cast_int(p_in text, p_default integer DEFAULT NULL::integer) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE
    AS $$

begin

    return p_in::int;

    exception when others then

        return p_default;

end;

$$;


ALTER FUNCTION public.try_cast_int(p_in text, p_default integer) OWNER TO reclada;

--
-- Name: try_cast_uuid(text, integer); Type: FUNCTION; Schema: public; Owner: reclada
--

CREATE FUNCTION public.try_cast_uuid(p_in text, p_default integer DEFAULT NULL::integer) RETURNS uuid
    LANGUAGE plpgsql IMMUTABLE
    AS $$

begin

    return p_in::uuid;

    exception when others then

        return p_default;

end;

$$;


ALTER FUNCTION public.try_cast_uuid(p_in text, p_default integer) OWNER TO reclada;

--
-- Name: validate_json_schema(jsonb, jsonb, jsonb); Type: FUNCTION; Schema: public; Owner: reclada
--

CREATE FUNCTION public.validate_json_schema(schema jsonb, data jsonb, root_schema jsonb DEFAULT NULL::jsonb) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $_$

DECLARE

  prop text;

  item jsonb;

  path text[];

  types text[];

  pattern text;

  props text[];

BEGIN

  IF root_schema IS NULL THEN

    root_schema = schema;

  END IF;



  IF schema ? 'type' THEN

    IF jsonb_typeof(schema->'type') = 'array' THEN

      types = ARRAY(SELECT jsonb_array_elements_text(schema->'type'));

    ELSE

      types = ARRAY[schema->>'type'];

    END IF;

    IF (SELECT NOT bool_or(public._validate_json_schema_type(type, data)) FROM unnest(types) type) THEN

      RETURN false;

    END IF;

  END IF;



  IF schema ? 'properties' THEN

    FOR prop IN SELECT jsonb_object_keys(schema->'properties') LOOP

      IF data ? prop AND NOT public.validate_json_schema(schema->'properties'->prop, data->prop, root_schema) THEN

        RETURN false;

      END IF;

    END LOOP;

  END IF;



  IF schema ? 'required' AND jsonb_typeof(data) = 'object' THEN

    IF NOT ARRAY(SELECT jsonb_object_keys(data)) @>

           ARRAY(SELECT jsonb_array_elements_text(schema->'required')) THEN

      RETURN false;

    END IF;

  END IF;



  IF schema ? 'items' AND jsonb_typeof(data) = 'array' THEN

    IF jsonb_typeof(schema->'items') = 'object' THEN

      FOR item IN SELECT jsonb_array_elements(data) LOOP

        IF NOT public.validate_json_schema(schema->'items', item, root_schema) THEN

          RETURN false;

        END IF;

      END LOOP;

    ELSE

      IF NOT (

        SELECT bool_and(i > jsonb_array_length(schema->'items') OR public.validate_json_schema(schema->'items'->(i::int - 1), elem, root_schema))

        FROM jsonb_array_elements(data) WITH ORDINALITY AS t(elem, i)

      ) THEN

        RETURN false;

      END IF;

    END IF;

  END IF;



  IF jsonb_typeof(schema->'additionalItems') = 'boolean' and NOT (schema->'additionalItems')::text::boolean AND jsonb_typeof(schema->'items') = 'array' THEN

    IF jsonb_array_length(data) > jsonb_array_length(schema->'items') THEN

      RETURN false;

    END IF;

  END IF;



  IF jsonb_typeof(schema->'additionalItems') = 'object' THEN

    IF NOT (

        SELECT bool_and(public.validate_json_schema(schema->'additionalItems', elem, root_schema))

        FROM jsonb_array_elements(data) WITH ORDINALITY AS t(elem, i)

        WHERE i > jsonb_array_length(schema->'items')

      ) THEN

      RETURN false;

    END IF;

  END IF;



  IF schema ? 'minimum' AND jsonb_typeof(data) = 'number' THEN

    IF data::text::numeric < (schema->>'minimum')::numeric THEN

      RETURN false;

    END IF;

  END IF;



  IF schema ? 'maximum' AND jsonb_typeof(data) = 'number' THEN

    IF data::text::numeric > (schema->>'maximum')::numeric THEN

      RETURN false;

    END IF;

  END IF;



  IF COALESCE((schema->'exclusiveMinimum')::text::bool, FALSE) THEN

    IF data::text::numeric = (schema->>'minimum')::numeric THEN

      RETURN false;

    END IF;

  END IF;



  IF COALESCE((schema->'exclusiveMaximum')::text::bool, FALSE) THEN

    IF data::text::numeric = (schema->>'maximum')::numeric THEN

      RETURN false;

    END IF;

  END IF;



  IF schema ? 'anyOf' THEN

    IF NOT (SELECT bool_or(public.validate_json_schema(sub_schema, data, root_schema)) FROM jsonb_array_elements(schema->'anyOf') sub_schema) THEN

      RETURN false;

    END IF;

  END IF;



  IF schema ? 'allOf' THEN

    IF NOT (SELECT bool_and(public.validate_json_schema(sub_schema, data, root_schema)) FROM jsonb_array_elements(schema->'allOf') sub_schema) THEN

      RETURN false;

    END IF;

  END IF;



  IF schema ? 'oneOf' THEN

    IF 1 != (SELECT COUNT(*) FROM jsonb_array_elements(schema->'oneOf') sub_schema WHERE public.validate_json_schema(sub_schema, data, root_schema)) THEN

      RETURN false;

    END IF;

  END IF;



  IF COALESCE((schema->'uniqueItems')::text::boolean, false) THEN

    IF (SELECT COUNT(*) FROM jsonb_array_elements(data)) != (SELECT count(DISTINCT val) FROM jsonb_array_elements(data) val) THEN

      RETURN false;

    END IF;

  END IF;



  IF schema ? 'additionalProperties' AND jsonb_typeof(data) = 'object' THEN

    props := ARRAY(

      SELECT key

      FROM jsonb_object_keys(data) key

      WHERE key NOT IN (SELECT jsonb_object_keys(schema->'properties'))

        AND NOT EXISTS (SELECT * FROM jsonb_object_keys(schema->'patternProperties') pat WHERE key ~ pat)

    );

    IF jsonb_typeof(schema->'additionalProperties') = 'boolean' THEN

      IF NOT (schema->'additionalProperties')::text::boolean AND jsonb_typeof(data) = 'object' AND NOT props <@ ARRAY(SELECT jsonb_object_keys(schema->'properties')) THEN

        RETURN false;

      END IF;

    ELSEIF NOT (

      SELECT bool_and(public.validate_json_schema(schema->'additionalProperties', data->key, root_schema))

      FROM unnest(props) key

    ) THEN

      RETURN false;

    END IF;

  END IF;



  IF schema ? '$ref' THEN

    path := ARRAY(

      SELECT regexp_replace(regexp_replace(path_part, '~1', '/'), '~0', '~')

      FROM UNNEST(regexp_split_to_array(schema->>'$ref', '/')) path_part

    );

    -- ASSERT path[1] = '#', 'only refs anchored at the root are supported';

    IF NOT public.validate_json_schema(root_schema #> path[2:array_length(path, 1)], data, root_schema) THEN

      RETURN false;

    END IF;

  END IF;



  IF schema ? 'enum' THEN

    IF NOT EXISTS (SELECT * FROM jsonb_array_elements(schema->'enum') val WHERE val = data) THEN

      RETURN false;

    END IF;

  END IF;



  IF schema ? 'minLength' AND jsonb_typeof(data) = 'string' THEN

    IF char_length(data #>> '{}') < (schema->>'minLength')::numeric THEN

      RETURN false;

    END IF;

  END IF;



  IF schema ? 'maxLength' AND jsonb_typeof(data) = 'string' THEN

    IF char_length(data #>> '{}') > (schema->>'maxLength')::numeric THEN

      RETURN false;

    END IF;

  END IF;



  IF schema ? 'not' THEN

    IF public.validate_json_schema(schema->'not', data, root_schema) THEN

      RETURN false;

    END IF;

  END IF;



  IF schema ? 'maxProperties' AND jsonb_typeof(data) = 'object' THEN

    IF (SELECT count(*) FROM jsonb_object_keys(data)) > (schema->>'maxProperties')::numeric THEN

      RETURN false;

    END IF;

  END IF;



  IF schema ? 'minProperties' AND jsonb_typeof(data) = 'object' THEN

    IF (SELECT count(*) FROM jsonb_object_keys(data)) < (schema->>'minProperties')::numeric THEN

      RETURN false;

    END IF;

  END IF;



  IF schema ? 'maxItems' AND jsonb_typeof(data) = 'array' THEN

    IF (SELECT count(*) FROM jsonb_array_elements(data)) > (schema->>'maxItems')::numeric THEN

      RETURN false;

    END IF;

  END IF;



  IF schema ? 'minItems' AND jsonb_typeof(data) = 'array' THEN

    IF (SELECT count(*) FROM jsonb_array_elements(data)) < (schema->>'minItems')::numeric THEN

      RETURN false;

    END IF;

  END IF;



  IF schema ? 'dependencies' THEN

    FOR prop IN SELECT jsonb_object_keys(schema->'dependencies') LOOP

      IF data ? prop THEN

        IF jsonb_typeof(schema->'dependencies'->prop) = 'array' THEN

          IF NOT (SELECT bool_and(data ? dep) FROM jsonb_array_elements_text(schema->'dependencies'->prop) dep) THEN

            RETURN false;

          END IF;

        ELSE

          IF NOT public.validate_json_schema(schema->'dependencies'->prop, data, root_schema) THEN

            RETURN false;

          END IF;

        END IF;

      END IF;

    END LOOP;

  END IF;



  IF schema ? 'pattern' AND jsonb_typeof(data) = 'string' THEN

    IF (data #>> '{}') !~ (schema->>'pattern') THEN

      RETURN false;

    END IF;

  END IF;



  IF schema ? 'patternProperties' AND jsonb_typeof(data) = 'object' THEN

    FOR prop IN SELECT jsonb_object_keys(data) LOOP

      FOR pattern IN SELECT jsonb_object_keys(schema->'patternProperties') LOOP

        RAISE NOTICE 'prop %s, pattern %, schema %', prop, pattern, schema->'patternProperties'->pattern;

        IF prop ~ pattern AND NOT public.validate_json_schema(schema->'patternProperties'->pattern, data->prop, root_schema) THEN

          RETURN false;

        END IF;

      END LOOP;

    END LOOP;

  END IF;



  IF schema ? 'multipleOf' AND jsonb_typeof(data) = 'number' THEN

    IF data::text::numeric % (schema->>'multipleOf')::numeric != 0 THEN

      RETURN false;

    END IF;

  END IF;



  RETURN true;

END;

$_$;


ALTER FUNCTION public.validate_json_schema(schema jsonb, data jsonb, root_schema jsonb) OWNER TO reclada;

--
-- Name: datasource_insert_trigger_fnc(); Type: FUNCTION; Schema: reclada; Owner: reclada
--

CREATE FUNCTION reclada.datasource_insert_trigger_fnc() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

DECLARE

    obj_id         uuid;

    dataset       jsonb;

    uri           text;



BEGIN

    IF NEW.class in 

            (select reclada_object.get_GUID_for_class('DataSource'))

        OR NEW.class in (select reclada_object.get_GUID_for_class('File')) THEN



        obj_id := NEW.GUID;



        SELECT v.data

        FROM reclada.v_active_object v

	    WHERE v.attrs->>'name' = 'defaultDataSet'

	    INTO dataset;



        dataset := jsonb_set(dataset, '{attributes, dataSources}', dataset->'attributes'->'dataSources' || format('["%s"]', obj_id)::jsonb);



        PERFORM reclada_object.update(dataset);



        uri := NEW.attributes->>'uri';



        PERFORM reclada_object.create(

            format('{

                "class": "Job",

                "attributes": {

                    "task": "c94bff30-15fa-427f-9954-d5c3c151e652",

                    "status": "new",

                    "type": "K8S",

                    "command": "./run_pipeline.sh",

                    "inputParameters": [{"uri": "%s"}, {"dataSourceId": "%s"}]

                    }

                }', uri, obj_id)::jsonb);



    END IF;



RETURN NEW;

END;

$$;


ALTER FUNCTION reclada.datasource_insert_trigger_fnc() OWNER TO reclada;

--
-- Name: load_staging(); Type: FUNCTION; Schema: reclada; Owner: reclada
--

CREATE FUNCTION reclada.load_staging() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

BEGIN

    PERFORM reclada_object.create(NEW.data);

    RETURN NEW;

END

$$;


ALTER FUNCTION reclada.load_staging() OWNER TO reclada;

--
-- Name: listen(character varying); Type: FUNCTION; Schema: reclada_notification; Owner: reclada
--

CREATE FUNCTION reclada_notification.listen(channel character varying) RETURNS void
    LANGUAGE plpgsql STABLE
    AS $$

BEGIN

    EXECUTE 'LISTEN ' || lower(channel);

END

$$;


ALTER FUNCTION reclada_notification.listen(channel character varying) OWNER TO reclada;

--
-- Name: send(character varying, jsonb); Type: FUNCTION; Schema: reclada_notification; Owner: reclada
--

CREATE FUNCTION reclada_notification.send(channel character varying, payload jsonb DEFAULT NULL::jsonb) RETURNS void
    LANGUAGE plpgsql STABLE
    AS $$

BEGIN

    PERFORM pg_notify(lower(channel), payload::text); 

END

$$;


ALTER FUNCTION reclada_notification.send(channel character varying, payload jsonb) OWNER TO reclada;

--
-- Name: send_object_notification(character varying, jsonb); Type: FUNCTION; Schema: reclada_notification; Owner: reclada
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


ALTER FUNCTION reclada_notification.send_object_notification(event character varying, object_data jsonb) OWNER TO reclada;

--
-- Name: cast_jsonb_to_postgres(text, text, text); Type: FUNCTION; Schema: reclada_object; Owner: reclada
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


ALTER FUNCTION reclada_object.cast_jsonb_to_postgres(key_path text, type text, type_of_array text) OWNER TO reclada;

--
-- Name: create(jsonb, jsonb); Type: FUNCTION; Schema: reclada_object; Owner: reclada
--

CREATE FUNCTION reclada_object."create"(data_jsonb jsonb, user_info jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE

    branch     uuid;

    data       jsonb;

    class_name text;

    class_uuid uuid;

    attrs      jsonb;

    schema     jsonb;

    obj_GUID   uuid;

    res        jsonb;



BEGIN



    IF (jsonb_typeof(data_jsonb) != 'array') THEN

        data_jsonb := '[]'::jsonb || data_jsonb;

    END IF;

    /*TODO: check if some objects have revision and others do not */

    branch:= data_jsonb->0->'branch';

    create temp table IF NOT EXISTS tmp(id uuid)

        ON COMMIT drop;

    delete from tmp;

    FOR data IN SELECT jsonb_array_elements(data_jsonb) 

    LOOP



        class_name := data->>'class';



        IF (class_name IS NULL) THEN

            RAISE EXCEPTION 'The reclada object class is not specified';

        END IF;

        class_uuid := public.try_cast_uuid(class_name);



        attrs := data->'attributes';

        IF (attrs IS NULL) THEN

            RAISE EXCEPTION 'The reclada object must have attributes';

        END IF;



        if class_uuid is null then

            SELECT reclada_object.get_schema(class_name) 

                INTO schema;

        else

            select v.data 

                from reclada.v_class v

                    where class_uuid = v.obj_id

                INTO schema;

        end if;

        IF (schema IS NULL) THEN

            RAISE EXCEPTION 'No json schema available for %', class_name;

        END IF;



        IF (NOT(validate_json_schema(schema->'attributes'->'schema', attrs))) THEN

            RAISE EXCEPTION 'JSON invalid: %', attrs;

        END IF;

        

        if data->>'id' is not null then

            RAISE EXCEPTION '%','Field "id" not allow!!!';

        end if;

        obj_GUID := (data->>'GUID')::uuid;

        IF EXISTS (

            select 1 from reclada.object 

                where GUID = obj_GUID

        ) then

            RAISE EXCEPTION 'GUID: % is duplicate', obj_GUID;

        end if;

        --raise notice 'schema: %',schema;

        with inserted as 

        (

            INSERT INTO reclada.object(GUID,class,attributes)

                select  case

                            when obj_GUID IS NULL

                                then public.uuid_generate_v4()

                            else obj_GUID

                        end as GUID,

                        (schema->>'GUID')::uuid, 

                        attrs                

                RETURNING GUID

        ) 

        insert into tmp(id)

            select GUID 

                from inserted;



    END LOOP;



    res := array_to_json

            (

                array

                (

                    select o.data 

                        from reclada.v_active_object o

                        join tmp t

                            on t.id = o.obj_id

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


ALTER FUNCTION reclada_object."create"(data_jsonb jsonb, user_info jsonb) OWNER TO reclada;

--
-- Name: create_subclass(jsonb); Type: FUNCTION; Schema: reclada_object; Owner: reclada
--

CREATE FUNCTION reclada_object.create_subclass(data jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$

DECLARE

    class           text;

    new_class       text;

    attrs           jsonb;

    class_schema    jsonb;

    version         integer;



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

    INTO version;



    version := coalesce(version,1);

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

    version,

    (class_schema->'properties') || (attrs->'properties'),

    (SELECT jsonb_agg(el) FROM (

        SELECT DISTINCT pg_catalog.jsonb_array_elements(

            (class_schema -> 'required') || (attrs -> 'required')

        ) el) arr)

    )::jsonb);



END;

$$;


ALTER FUNCTION reclada_object.create_subclass(data jsonb) OWNER TO reclada;

--
-- Name: delete(jsonb, jsonb); Type: FUNCTION; Schema: reclada_object; Owner: reclada
--

CREATE FUNCTION reclada_object.delete(data jsonb, user_info jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE

    v_obj_id        uuid;

BEGIN



    v_obj_id := data->>'GUID';

    IF (v_obj_id IS NULL) THEN

        RAISE EXCEPTION 'Could not delete object with no GUID';

    END IF;



    

    with t as (    

        update reclada.object o

            set status = reclada_object.get_archive_status_obj_id() 

                WHERE o.GUID = v_obj_id

                    and status != reclada_object.get_archive_status_obj_id()

                    RETURNING id

    ) 

        SELECT o.data

            from t

            join reclada.v_object o

                on o.id = t.id

            into data;

    

    IF (data IS NULL) THEN

        RAISE EXCEPTION 'Could not delete object, no such GUID';

    END IF;



    PERFORM reclada_notification.send_object_notification('delete', data);



    RETURN data;

END;

$$;


ALTER FUNCTION reclada_object.delete(data jsonb, user_info jsonb) OWNER TO reclada;

--
-- Name: get_active_status_obj_id(); Type: FUNCTION; Schema: reclada_object; Owner: reclada
--

CREATE FUNCTION reclada_object.get_active_status_obj_id() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$

    select obj_id 

        from reclada.v_object_status 

            where caption = 'active'

$$;


ALTER FUNCTION reclada_object.get_active_status_obj_id() OWNER TO reclada;

--
-- Name: get_archive_status_obj_id(); Type: FUNCTION; Schema: reclada_object; Owner: reclada
--

CREATE FUNCTION reclada_object.get_archive_status_obj_id() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$

    select obj_id 

        from reclada.v_object_status 

            where caption = 'archive'

$$;


ALTER FUNCTION reclada_object.get_archive_status_obj_id() OWNER TO reclada;

--
-- Name: get_condition_array(jsonb, text); Type: FUNCTION; Schema: reclada_object; Owner: reclada
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


ALTER FUNCTION reclada_object.get_condition_array(data jsonb, key_path text) OWNER TO reclada;

--
-- Name: get_default_user_obj_id(); Type: FUNCTION; Schema: reclada_object; Owner: reclada
--

CREATE FUNCTION reclada_object.get_default_user_obj_id() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$

    select obj_id 

        from reclada.v_user 

            where login = 'dev'

$$;


ALTER FUNCTION reclada_object.get_default_user_obj_id() OWNER TO reclada;

--
-- Name: get_guid_for_class(text); Type: FUNCTION; Schema: reclada_object; Owner: reclada
--

CREATE FUNCTION reclada_object.get_guid_for_class(class text) RETURNS TABLE(obj_id uuid)
    LANGUAGE sql STABLE
    AS $$

    SELECT obj_id

        from reclada.v_class_lite

            where for_class = class

$$;


ALTER FUNCTION reclada_object.get_guid_for_class(class text) OWNER TO reclada;

--
-- Name: get_jsonschema_guid(); Type: FUNCTION; Schema: reclada_object; Owner: reclada
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


ALTER FUNCTION reclada_object.get_jsonschema_guid() OWNER TO reclada;

--
-- Name: get_query_condition(jsonb, text); Type: FUNCTION; Schema: reclada_object; Owner: reclada
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


ALTER FUNCTION reclada_object.get_query_condition(data jsonb, key_path text) OWNER TO reclada;

--
-- Name: get_schema(text); Type: FUNCTION; Schema: reclada_object; Owner: reclada
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


ALTER FUNCTION reclada_object.get_schema(class text) OWNER TO reclada;

--
-- Name: jsonb_to_text(jsonb); Type: FUNCTION; Schema: reclada_object; Owner: reclada
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


ALTER FUNCTION reclada_object.jsonb_to_text(data jsonb) OWNER TO reclada;

--
-- Name: list(jsonb, boolean); Type: FUNCTION; Schema: reclada_object; Owner: reclada
--

CREATE FUNCTION reclada_object.list(data jsonb, with_number boolean DEFAULT false) RETURNS jsonb
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

                -- ((('"'||class||'"')::jsonb#>>'{}')::text = 'Job')

                --reclada_object.get_query_condition(class, E'data->''class''') AS condition

                --'class = data->>''class''' AS condition

                -- TODO: replace for using GUID

                format('obj.class_name = ''%s''', class) AS condition

            UNION

            SELECT  CASE

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

            -- UNION

            -- SELECT 'obj.data->>''status''=''active'''-- TODO: change working with revision

            -- UNION SELECT

            --     CASE WHEN data->'revision' IS NULL THEN

            --         E'(data->>''revision''):: numeric = (SELECT max((objrev.data -> ''revision'')::numeric)

            --         FROM reclada.v_object objrev WHERE

            --         objrev.data -> ''GUID'' = obj.data -> ''GUID'')'

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

$$;


ALTER FUNCTION reclada_object.list(data jsonb, with_number boolean) OWNER TO reclada;

--
-- Name: list_add(jsonb); Type: FUNCTION; Schema: reclada_object; Owner: reclada
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


ALTER FUNCTION reclada_object.list_add(data jsonb) OWNER TO reclada;

--
-- Name: list_drop(jsonb); Type: FUNCTION; Schema: reclada_object; Owner: reclada
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


ALTER FUNCTION reclada_object.list_drop(data jsonb) OWNER TO reclada;

--
-- Name: list_related(jsonb); Type: FUNCTION; Schema: reclada_object; Owner: reclada
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


ALTER FUNCTION reclada_object.list_related(data jsonb) OWNER TO reclada;

--
-- Name: update(jsonb, jsonb); Type: FUNCTION; Schema: reclada_object; Owner: reclada
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

    class_uuid := public.try_cast_uuid(class_name);

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



    IF (NOT(validate_json_schema(schema->'attributes'->'schema', v_attrs))) THEN

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

                                attributes

                              )

        select  v.obj_id,

                (schema->>'GUID')::uuid,

                reclada_object.get_active_status_obj_id(),--status 

                v_attrs || format('{"revision":"%s"}',revid)::jsonb

            FROM reclada.v_object v

            JOIN t 

                on t.id = v.id

	            WHERE v.obj_id = v_obj_id;

                    

    select v.data 

        FROM reclada.v_active_object v

            WHERE v.obj_id = v_obj_id

        into data;

    PERFORM reclada_notification.send_object_notification('update', data);

    RETURN data;

END;

$$;


ALTER FUNCTION reclada_object.update(data jsonb, user_info jsonb) OWNER TO reclada;

--
-- Name: create(character varying, uuid, uuid); Type: FUNCTION; Schema: reclada_revision; Owner: reclada
--

CREATE FUNCTION reclada_revision."create"(userid character varying, branch uuid, obj uuid) RETURNS uuid
    LANGUAGE sql
    AS $$

    INSERT INTO reclada.object

        (

            class,

            attributes

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

            )::jsonb

        ) RETURNING (GUID)::uuid;

    --nextval('reclada.reclada_revisions'),

$$;


ALTER FUNCTION reclada_revision."create"(userid character varying, branch uuid, obj uuid) OWNER TO reclada;

--
-- Name: auth_by_token(character varying); Type: FUNCTION; Schema: reclada_user; Owner: reclada
--

CREATE FUNCTION reclada_user.auth_by_token(token character varying) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    AS $$

    SELECT '{}'::jsonb

$$;


ALTER FUNCTION reclada_user.auth_by_token(token character varying) OWNER TO reclada;

--
-- Name: disable_auth(jsonb); Type: FUNCTION; Schema: reclada_user; Owner: reclada
--

CREATE FUNCTION reclada_user.disable_auth(data jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$

BEGIN

    DELETE FROM reclada.auth_setting;

END;

$$;


ALTER FUNCTION reclada_user.disable_auth(data jsonb) OWNER TO reclada;

--
-- Name: is_allowed(jsonb, text, jsonb); Type: FUNCTION; Schema: reclada_user; Owner: reclada
--

CREATE FUNCTION reclada_user.is_allowed(jsonb, text, jsonb) RETURNS boolean
    LANGUAGE plpgsql STABLE
    AS $$

BEGIN

    RETURN TRUE;

END;

$$;


ALTER FUNCTION reclada_user.is_allowed(jsonb, text, jsonb) OWNER TO reclada;

--
-- Name: refresh_jwk(jsonb); Type: FUNCTION; Schema: reclada_user; Owner: reclada
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


ALTER FUNCTION reclada_user.refresh_jwk(data jsonb) OWNER TO reclada;

--
-- Name: setup_keycloak(jsonb); Type: FUNCTION; Schema: reclada_user; Owner: reclada
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


ALTER FUNCTION reclada_user.setup_keycloak(data jsonb) OWNER TO reclada;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: t_dbg; Type: TABLE; Schema: dev; Owner: reclada
--

CREATE TABLE dev.t_dbg (
    id integer NOT NULL,
    msg text NOT NULL,
    time_when timestamp with time zone DEFAULT now()
);


ALTER TABLE dev.t_dbg OWNER TO reclada;

--
-- Name: t_dbg_id_seq; Type: SEQUENCE; Schema: dev; Owner: reclada
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
-- Name: ver; Type: TABLE; Schema: dev; Owner: reclada
--

CREATE TABLE dev.ver (
    id integer NOT NULL,
    ver integer NOT NULL,
    ver_str text,
    upgrade_script text NOT NULL,
    downgrade_script text NOT NULL,
    run_at timestamp with time zone DEFAULT now()
);


ALTER TABLE dev.ver OWNER TO reclada;

--
-- Name: ver_id_seq; Type: SEQUENCE; Schema: dev; Owner: reclada
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
-- Name: auth_setting; Type: TABLE; Schema: reclada; Owner: reclada
--

CREATE TABLE reclada.auth_setting (
    oidc_url character varying,
    oidc_client_id character varying,
    oidc_redirect_url character varying,
    jwk jsonb
);


ALTER TABLE reclada.auth_setting OWNER TO reclada;

--
-- Name: object; Type: TABLE; Schema: reclada; Owner: reclada
--

CREATE TABLE reclada.object (
    id bigint NOT NULL,
    status uuid DEFAULT reclada_object.get_active_status_obj_id() NOT NULL,
    attributes jsonb NOT NULL,
    transaction_id bigint,
    created_time timestamp with time zone DEFAULT now(),
    created_by uuid DEFAULT reclada_object.get_default_user_obj_id(),
    class uuid NOT NULL,
    guid uuid
);


ALTER TABLE reclada.object OWNER TO reclada;

--
-- Name: object_id_seq; Type: SEQUENCE; Schema: reclada; Owner: reclada
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
-- Name: reclada_revisions; Type: SEQUENCE; Schema: reclada; Owner: reclada
--

CREATE SEQUENCE reclada.reclada_revisions
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE reclada.reclada_revisions OWNER TO reclada;

--
-- Name: staging; Type: VIEW; Schema: reclada; Owner: reclada
--

CREATE VIEW reclada.staging AS
 SELECT '{}'::jsonb AS data
  WHERE false;


ALTER TABLE reclada.staging OWNER TO reclada;

--
-- Name: v_class_lite; Type: VIEW; Schema: reclada; Owner: reclada
--

CREATE VIEW reclada.v_class_lite AS
 SELECT obj.id,
    obj.guid AS obj_id,
    (obj.attributes ->> 'forClass'::text) AS for_class,
    ((obj.attributes ->> 'version'::text))::bigint AS version,
    obj.created_time,
    obj.attributes,
    obj.status
   FROM reclada.object obj
  WHERE (obj.class = reclada_object.get_jsonschema_guid());


ALTER TABLE reclada.v_class_lite OWNER TO reclada;

--
-- Name: v_object_status; Type: VIEW; Schema: reclada; Owner: reclada
--

CREATE VIEW reclada.v_object_status AS
 SELECT obj.id,
    obj.guid AS obj_id,
    (obj.attributes ->> 'caption'::text) AS caption,
    obj.created_time,
    obj.attributes AS attrs
   FROM reclada.object obj
  WHERE (obj.class IN ( SELECT reclada_object.get_guid_for_class('ObjectStatus'::text) AS get_guid_for_class));


ALTER TABLE reclada.v_object_status OWNER TO reclada;

--
-- Name: v_user; Type: VIEW; Schema: reclada; Owner: reclada
--

CREATE VIEW reclada.v_user AS
 SELECT obj.id,
    obj.guid AS obj_id,
    (obj.attributes ->> 'login'::text) AS login,
    obj.created_time,
    obj.attributes AS attrs
   FROM reclada.object obj
  WHERE ((obj.class IN ( SELECT reclada_object.get_guid_for_class('User'::text) AS get_guid_for_class)) AND (obj.status = reclada_object.get_active_status_obj_id()));


ALTER TABLE reclada.v_user OWNER TO reclada;

--
-- Name: v_object; Type: VIEW; Schema: reclada; Owner: reclada
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
            obj.created_by
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
                    t.revision,
                    os.caption AS status,
                    t.attributes) tmp))::jsonb AS data,
    u.login AS login_created_by,
    t.created_by,
    t.status
   FROM (((t
     LEFT JOIN reclada.v_object_status os ON ((t.status = os.obj_id)))
     LEFT JOIN reclada.v_user u ON ((u.obj_id = t.created_by)))
     LEFT JOIN reclada.v_class_lite cl ON ((cl.obj_id = t.class)));


ALTER TABLE reclada.v_object OWNER TO reclada;

--
-- Name: v_active_object; Type: VIEW; Schema: reclada; Owner: reclada
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
    t.data
   FROM reclada.v_object t
  WHERE (t.status = reclada_object.get_active_status_obj_id());


ALTER TABLE reclada.v_active_object OWNER TO reclada;

--
-- Name: v_class; Type: VIEW; Schema: reclada; Owner: reclada
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


ALTER TABLE reclada.v_class OWNER TO reclada;

--
-- Name: v_revision; Type: VIEW; Schema: reclada; Owner: reclada
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


ALTER TABLE reclada.v_revision OWNER TO reclada;

--
-- Data for Name: t_dbg; Type: TABLE DATA; Schema: dev; Owner: reclada
--

COPY dev.t_dbg (id, msg, time_when) FROM stdin;
\.


--
-- Data for Name: ver; Type: TABLE DATA; Schema: dev; Owner: reclada
--

COPY dev.ver (id, ver, ver_str, upgrade_script, downgrade_script, run_at) FROM stdin;
1	0	0	select public.raise_exception ('This is 0 version');	select public.raise_exception ('This is 0 version');	2021-09-14 11:51:16.710537+00
2	1	\N	begin;\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 1 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select \t'drop '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n' as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.str = tmp.str \n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n\tyou can use "i 'function/reclada_object.get_schema.sql'"\n\tto run text script of functions\n*/\nCREATE EXTENSION IF NOT EXISTS aws_lambda CASCADE;\ni 'function/api.storage_generate_presigned_get.sql'\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\nDROP EXTENSION IF EXISTS aws_lambda CASCADE;\ndrop function IF EXISTS api.storage_generate_presigned_get ;\nCREATE OR REPLACE FUNCTION api.storage_generate_presigned_get(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    credentials  jsonb;\r\n    object_data  jsonb;\r\n    object_id    uuid;\r\n    result       jsonb;\r\n    user_info    jsonb;\r\nBEGIN\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned post', '{}'))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';\r\n    END IF;\r\n\r\n    SELECT reclada_object.list('{"class": "S3Config", "attrs": {}}')::jsonb -> 0 INTO credentials;\r\n\r\n    -- TODO: check user's permissions for reclada object access?\r\n    object_id := data->>'objectId';\r\n    SELECT reclada_object.list(format(\r\n        '{"class": "File", "attrs": {}, "id": "%s"}',\r\n        object_id\r\n    )::jsonb) -> 0 INTO object_data;\r\n\r\n    SELECT reclada_storage.s3_generate_presigned_get(credentials, object_data) INTO result;\r\n    RETURN result;\r\nEND;\r\n$function$\n	2021-09-14 11:51:46.564672+00
3	2	\N	begin;\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 2 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select \t'drop '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n' as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.str = tmp.str \n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n\tyou can use "i 'function/reclada_object.get_schema.sql'"\n\tto run text script of functions\n*/\nCREATE EXTENSION IF NOT EXISTS aws_lambda CASCADE;\ni 'function/api.storage_generate_presigned_get.sql'\ni 'function/api.storage_generate_presigned_post.sql'\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\nDROP EXTENSION IF EXISTS aws_lambda CASCADE;\ndrop function IF EXISTS api.storage_generate_presigned_get ;\nCREATE OR REPLACE FUNCTION api.storage_generate_presigned_get(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    credentials  jsonb;\r\n    object_data  jsonb;\r\n    object_id    uuid;\r\n    result       jsonb;\r\n    user_info    jsonb;\r\nBEGIN\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned post', '{}'))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';\r\n    END IF;\r\n\r\n    SELECT reclada_object.list('{"class": "S3Config", "attrs": {}}')::jsonb -> 0 INTO credentials;\r\n\r\n    -- TODO: check user's permissions for reclada object access?\r\n    object_id := data->>'objectId';\r\n    SELECT reclada_object.list(format(\r\n        '{"class": "File", "attrs": {}, "id": "%s"}',\r\n        object_id\r\n    )::jsonb) -> 0 INTO object_data;\r\n\r\n    SELECT payload\r\n    FROM aws_lambda.invoke(\r\n        aws_commons.create_lambda_function_arn(\r\n            's3_get_presigned_url_dev1',\r\n            'eu-west-1'\r\n            ),\r\n        format('{"uri": "%s", "expiration": 3600}', object_data->'attrs'->> 'uri')::jsonb)\r\n    INTO result;\r\n    RETURN result;\r\nEND;\r\n$function$\n	2021-09-14 11:51:51.951095+00
4	3	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 3 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select \t'drop '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n' as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.str = tmp.str \n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/public.try_cast_int.sql'\n\n\n-- create table reclada.object_status\n-- (\n--     id      bigint GENERATED ALWAYS AS IDENTITY primary KEY,\n--     caption text not null\n-- );\nSELECT reclada_object.create_subclass('{\n    "class": "RecladaObject",\n    "attrs": {\n        "newClass": "ObjectStatus",\n        "properties": {\n            "caption": {"type": "string"}\n        },\n        "required": ["caption"]\n    }\n}'::jsonb);\n-- insert into reclada.object_status(caption)\n--     select 'active';\nSELECT reclada_object.create('{\n    "class": "ObjectStatus",\n    "attrs": {\n        "caption": "active"\n    }\n}'::jsonb);\n-- insert into reclada.object_status(caption)\n--     select 'archive';\nSELECT reclada_object.create('{\n    "class": "ObjectStatus",\n    "attrs": {\n        "caption": "archive"\n    }\n}'::jsonb);\n\nSELECT reclada_object.create_subclass('{\n    "class": "RecladaObject",\n    "attrs": {\n        "newClass": "User",\n        "properties": {\n            "login": {"type": "string"}\n        },\n        "required": ["login"]\n    }\n}'::jsonb);\nSELECT reclada_object.create('{\n    "class": "User",\n    "attrs": {\n        "login": "dev"\n    }\n}'::jsonb);\n\n\n\n--SHOW search_path;        \nSET search_path TO public;\nDROP EXTENSION IF EXISTS "uuid-ossp";\nCREATE EXTENSION "uuid-ossp" SCHEMA public;\n\nalter table reclada.object\n    add id bigint GENERATED ALWAYS AS IDENTITY primary KEY,\n    add obj_id       uuid   default public.uuid_generate_v4(),\n    add revision     uuid   ,\n    add obj_id_int   int    ,\n    add revision_int bigint ,\n    add class        text   ,\n    add status       uuid   ,--DEFAULT reclada_object.get_active_status_obj_id(),\n    add attributes   jsonb  ,\n    add transaction_id bigint ,\n    add created_time timestamp with time zone DEFAULT now(),\n    add created_by   uuid  ;--DEFAULT reclada_object.get_default_user_obj_id();\n\ndrop VIEW if EXISTS reclada.v_class;\ndrop VIEW if EXISTS reclada.v_object_status;\n\ni 'view/reclada.v_object_status.sql'\ni 'function/reclada_object.get_active_status_obj_id.sql'\ni 'function/reclada_object.get_archive_status_obj_id.sql'\n\nupdate reclada.object \n    set class      = data->>'class',\n        attributes = data->'attrs' ;\nupdate reclada.object \n    set obj_id_int = public.try_cast_int(data->>'id'),\n        revision_int  = (data->'revision')::bigint   \n        -- status  = (data->'isDeleted')::boolean::int+1,\n        ;\nupdate reclada.object \n    set obj_id = (data->>'id')::uuid\n        WHERE obj_id_int is null;\n\nupdate reclada.object \n    set status  = \n        case coalesce((data->'isDeleted')::boolean::int+1,1)\n            when 1 \n                then reclada_object.get_active_status_obj_id()\n            else reclada_object.get_archive_status_obj_id()\n        end;\n\ni 'view/reclada.v_user.sql'\ni 'view/reclada.v_object.sql'\ni 'view/reclada.v_active_object.sql'\ni 'function/reclada_object.get_default_user_obj_id.sql'\n\nalter table reclada.object\n    alter COLUMN status \n        set DEFAULT reclada_object.get_active_status_obj_id(),\n    alter COLUMN created_by \n        set DEFAULT reclada_object.get_default_user_obj_id();\n\nupdate reclada.object set created_by = reclada_object.get_default_user_obj_id();\n\n-- проверим, что числовой id только для ревизий\nselect public.raise_exception('exist numeric id for other class!!!')\n    where exists\n    (\n        select 1 \n            from reclada.object \n                where obj_id_int is not null \n                    and class != 'revision'\n    );\n\nupdate reclada.object -- проставим статус, тем у кого он отсутствует\n    set status = reclada_object.get_active_status_obj_id()\n        WHERE status is null;\n\n\n-- генерируем obj_id для объектов ревизий \nupdate reclada.object as o\n    set obj_id = g.obj_id\n    from \n    (\n        select  g.obj_id_int ,\n                public.uuid_generate_v4() as obj_id\n            from reclada.object g\n            GROUP BY g.obj_id_int\n            HAVING g.obj_id_int is not NULL\n    ) g\n        where g.obj_id_int = o.obj_id_int;\n\n-- заносим номер ревизии в attrs\nupdate reclada.object o\n    set attributes = o.attributes \n                || jsonb ('{"num":'|| \n                    (\n                        select count(1)+1 \n                            from reclada.object c\n                                where c.obj_id = o.obj_id \n                                    and c.obj_id_int< o.obj_id_int\n                    )::text ||'}')\n                -- запомним старый номер ревизии на всякий случай\n                || jsonb ('{"old_num":'|| o.obj_id_int::text ||'}')\n        where o.obj_id_int is not null;\n\n-- обновляем ссылки на ревизию \nupdate reclada.object as o\n    set revision = g.obj_id\n    from \n    (\n        select  g.obj_id_int ,\n                g.obj_id\n            from reclada.object g\n            GROUP BY    g.obj_id_int ,\n                        g.obj_id\n            HAVING g.obj_id_int is not NULL\n    ) g\n        where o.revision_int = g.obj_id_int;\nalter table reclada.object alter column data drop not null;\n\nalter table reclada.object \n    alter column attributes set not null,\n    alter column class set not null,\n    alter column status set not null,\n    alter column obj_id set not null;\n\n-- delete from reclada.object where attrs is null\n\ni 'view/reclada.v_class.sql'\ni 'view/reclada.v_revision.sql'\ni 'function/reclada.datasource_insert_trigger_fnc.sql'\ni 'function/reclada_object.get_schema.sql'\ni 'function/reclada.load_staging.sql'\ni 'function/reclada_object.create.sql'\ni 'function/reclada_object.delete.sql'\ni 'function/reclada_object.update.sql'\ni 'function/reclada_object.list.sql'\ni 'function/reclada_revision.create.sql'\n\n\n-- удалим вспомагательные столбцы\nalter table reclada.object\n    drop column revision_int,\n    drop column data,\n    drop column obj_id_int;\n\n\n--{ indexes\nDROP INDEX IF EXISTS reclada.class_index;\nCREATE INDEX class_index \n\tON reclada.object(class);\n\nDROP INDEX IF EXISTS reclada.obj_id_index;\nCREATE INDEX obj_id_index \n\tON reclada.object(obj_id);\n\nDROP INDEX IF EXISTS reclada.revision_index;\nCREATE INDEX revision_index \n\tON reclada.object(revision);\n\nDROP INDEX IF EXISTS reclada.status_index;\nCREATE INDEX status_index \n\tON reclada.object(status);\n\nDROP INDEX IF EXISTS reclada.job_status_index;\nCREATE INDEX job_status_index \n\tON reclada.object((attributes->'status'))\n\tWHERE class = 'Job';\n\nDROP INDEX IF EXISTS reclada.runner_status_index;\nCREATE INDEX runner_status_index\n\tON reclada.object((attributes->'status'))\n\tWHERE class = 'Runner';\n\nDROP INDEX IF EXISTS reclada.runner_type_index;\nCREATE INDEX runner_type_index \n\tON reclada.object((attributes->'type'))\n\tWHERE class = 'Runner';\n--} indexes\n\nupdate reclada.object o \n    set attributes = o.attributes || format('{"revision":"%s"}',o.revision)::jsonb\n        where o.revision is not null;\n\nalter table reclada.object\n    drop COLUMN revision;\n\n\ni 'function/reclada_notification.send_object_notification.sql'\ni 'function/reclada_object.list_add.sql'\ni 'function/reclada_object.list_drop.sql'\ni 'function/reclada_object.list_related.sql'\ni 'function/api.reclada_object_create.sql'\ni 'function/api.reclada_object_delete.sql'\ni 'function/api.reclada_object_list.sql'\ni 'function/api.reclada_object_list_add.sql'\ni 'function/api.reclada_object_list_drop.sql'\ni 'function/api.reclada_object_list_related.sql'\ni 'function/api.storage_generate_presigned_get.sql'\n\n\n--select dlkfmdlknfal();\n\n-- test 1\n-- select reclada_revision.create('123', null,'e2bdd471-cf23-46a9-84cf-f9e15db7887d')\n-- SELECT reclada_object.create('\n--   {\n--        "class": "Job",\n--        "revision": 10,\n--        "attrs": {\n--            "task": "c94bff30-15fa-427f-9954-d5c3c151e652",\n--            "status": "new",\n--            "type": "K8S",\n--            "command": "./run_pipeline.sh",\n--            "inputParameters": [{"uri": "%s"}, {"dataSourceId": "%s"}]\n--            }\n--        }'::jsonb);\n--\n-- SELECT reclada_object.update('\n--   {\n--      "id": "f47596e6-3117-419e-ab6d-2174f0ebf471",\n-- \t \t"class": "Job",\n--        "attrs": {\n--            "task": "c94bff30-15fa-427f-9954-d5c3c151e652",\n--            "status": "new",\n--            "type": "K8S",\n--            "command": "./run_pipeline.sh",\n--            "inputParameters": [{"uri": "%s"}, {"dataSourceId": "%s"}]\n--            }\n--        }'::jsonb);\n\n-- SELECT reclada_object.delete( '{\n--       "id": "6cff152e-8391-4997-8134-8257e2717ac4"}')\n\n\n--select count(1)+1 \n--                        from reclada.object o\n--                            where o.obj_id = 'e2bdd471-cf23-46a9-84cf-f9e15db7887d'\n--\n--SELECT * FROM reclada.v_revision ORDER BY ID DESC -- 77\n--    LIMIT 300\n-- insert into staging\n--\tselect '{"id": "feb80c85-b0a7-40f8-864a-c874ff919bd1", "attrs": {"name": "Tmtagg tes2t f1ile.xlsx"}, "class": "Document", "fileId": "25ca0de7-e5b5-45f3-a368-788fe7eaecf8"}'\n\n-- select reclada_object.get_schema('Job')\n--update\n-- +"reclada_object.list"\n-- + "reclada_object.update"\n-- + "reclada_object.delete"\n-- + "reclada_object.create"\n-- + "reclada.load_staging"\n-- + "reclada_object.get_schema"\n-- + "reclada_revision.create"\n\n-- test\n-- + reclada.datasource_insert_trigger_fnc\n-- + reclada.load_staging\n-- + reclada_object.list\n-- + reclada_object.get_schema\n-- + reclada_object.delete\n-- + reclada_object.create\n-- + reclada_object.update\n-- + reclada_revision.create\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect public.raise_exception('Downgrade script not support');\n	2021-09-14 11:51:56.618874+00
5	4	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 4 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select \t'drop '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n' as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.str = tmp.str \n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/reclada.datasource_insert_trigger_fnc.sql'\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect public.raise_exception('Downgrade script not support');\n	2021-09-14 11:52:08.9847+00
6	5	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 5 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select \t'drop '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n' as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.str = tmp.str \n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/reclada_object.delete.sql'\ni 'function/reclada_object.list_add.sql'\ni 'function/reclada_object.list_drop.sql'\ni 'function/reclada_object.list_related.sql'\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect public.raise_exception('Downgrade script not support');\n	2021-09-14 11:52:11.898255+00
7	6	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 6 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select \t'drop '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n' as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.str = tmp.str \n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/reclada_object.list.sql'\ni 'function/reclada_object.list_related.sql'\ni 'function/api.reclada_object_list.sql'\ni 'function/api.reclada_object_list_related.sql'\ni 'reclada.datasource_insert_trigger_fnc.sql'\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect public.raise_exception('Downgrade script not support');\n	2021-09-14 11:52:15.564951+00
8	7	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 7 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select \t'drop '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n' as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.str = tmp.str \n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/reclada_object.list.sql'\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect public.raise_exception('Downgrade script not support');\n	2021-09-14 11:52:19.091634+00
9	8	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 8 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\nDROP TRIGGER IF EXISTS datasource_insert_trigger ON reclada.object;\nCREATE TRIGGER datasource_insert_trigger\n  BEFORE INSERT\n  ON reclada.object FOR EACH ROW\n  EXECUTE PROCEDURE reclada.datasource_insert_trigger_fnc();\n\n/*\n    if we use AFTER trigger \n    code from reclada_object.create:\n        with inserted as \n        (\n            INSERT INTO reclada.object(class,attributes)\n                select class, attrs\n                    RETURNING obj_id\n        ) \n        insert into tmp(id)\n            select obj_id \n                from inserted;\n    twice returns obj_id for object which created from trigger (Job).\n    \n    As result query:\n        SELECT reclada_object.create('{"id": "", "class": "File", \n\t\t\t\t\t\t\t \t"attrs":{\n\t\t\t\t\t\t\t \t\t"name": "SCkyqZSNmCFlWxPNSHWl", \n\t\t\t\t\t\t\t\t \t"checksum": "", \n\t\t\t\t\t\t\t\t \t"mimeType": "application/pdf", \n\t\t\t\t\t\t\t \t\t"uri": "s3://test-reclada-bucket/inbox/SCkyqZSNmCFlWxPNSHWl"\n\t\t\t\t\t\t\t }\n\t\t\t\t\t\t\t }', null);\n    selects only Job object.\n*/\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\n--select public.raise_exception('Downgrade script not support');\nDROP function IF EXISTS dev.downgrade_version ;\nCREATE OR REPLACE FUNCTION dev.downgrade_version()\n RETURNS void\n LANGUAGE plpgsql\nAS $function$\r\ndeclare \r\n    current_ver int; \r\n    downgrade_script text;\r\n    v_state   TEXT;\r\n    v_msg     TEXT;\r\n    v_detail  TEXT;\r\n    v_hint    TEXT;\r\n    v_context TEXT;\r\nBEGIN\r\n\r\n    select max(ver) \r\n        from dev.VER\r\n    into current_ver;\r\n    \r\n    select v.downgrade_script \r\n        from dev.VER v\r\n            WHERE current_ver = v.ver\r\n        into downgrade_script;\r\n\r\n    if COALESCE(downgrade_script,'') = '' then\r\n        RAISE EXCEPTION 'downgrade_script is empty! from dev.downgrade_version()';\r\n    end if;\r\n\r\n    EXECUTE downgrade_script;\r\n\r\n    -- mark, that chanches applied\r\n    delete \r\n        from dev.VER v\r\n            where v.ver = current_ver;\r\n\r\n    v_msg = 'OK, curren version: ' || (current_ver-1)::text;\r\n    perform public.raise_notice(v_msg);\r\nEXCEPTION when OTHERS then \r\n\tget stacked diagnostics\r\n        v_state   = returned_sqlstate,\r\n        v_msg     = message_text,\r\n        v_detail  = pg_exception_detail,\r\n        v_hint    = pg_exception_hint,\r\n        v_context = pg_exception_context;\r\n\r\n    v_state := format('Got exception:\r\nstate   : %s\r\nmessage : %s\r\ndetail  : %s\r\nhint    : %s\r\ncontext : %s\r\nSQLSTATE: %s\r\nSQLERRM : %s', \r\n                v_state, \r\n                v_msg, \r\n                v_detail, \r\n                v_hint, \r\n                v_context,\r\n                SQLSTATE,\r\n                SQLERRM);\r\n    perform dev.reg_notice(v_state);\r\nEND\r\n$function$\n;\n\n	2021-09-14 11:52:22.130023+00
10	9	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 9 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\ni 'function/dev.downgrade_version.sql'\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nDROP function IF EXISTS dev.downgrade_version ;\nCREATE OR REPLACE FUNCTION dev.downgrade_version()\n RETURNS void\n LANGUAGE plpgsql\nAS $function$\r\ndeclare \r\n    current_ver int; \r\n    downgrade_script text;\r\n    v_state   TEXT;\r\n    v_msg     TEXT;\r\n    v_detail  TEXT;\r\n    v_hint    TEXT;\r\n    v_context TEXT;\r\nBEGIN\r\n\r\n    select max(ver) \r\n        from dev.VER\r\n    into current_ver;\r\n    \r\n    select v.downgrade_script \r\n        from dev.VER v\r\n            WHERE current_ver = v.ver\r\n        into downgrade_script;\r\n\r\n    if COALESCE(downgrade_script,'') = '' then\r\n        RAISE EXCEPTION 'downgrade_script is empty! from dev.downgrade_version()';\r\n    end if;\r\n\r\n    EXECUTE downgrade_script;\r\n\r\n    -- mark, that chanches applied\r\n    delete \r\n        from dev.VER v\r\n            where v.ver = current_ver;\r\n\r\n    v_msg = 'OK, curren version: ' || (current_ver-1)::text;\r\n    perform public.raise_notice(v_msg);\r\nEXCEPTION when OTHERS then \r\n\tget stacked diagnostics\r\n        v_state   = returned_sqlstate,\r\n        v_msg     = message_text,\r\n        v_detail  = pg_exception_detail,\r\n        v_hint    = pg_exception_hint,\r\n        v_context = pg_exception_context;\r\n\r\n    v_state := format('Got exception:\r\nstate   : %s\r\nmessage : %s\r\ndetail  : %s\r\nhint    : %s\r\ncontext : %s\r\nSQLSTATE: %s\r\nSQLERRM : %s', \r\n                v_state, \r\n                v_msg, \r\n                v_detail, \r\n                v_hint, \r\n                v_context,\r\n                SQLSTATE,\r\n                SQLERRM);\r\n    perform dev.reg_notice(v_state);\r\nEND\r\n$function$\n;\n\n	2021-09-14 11:52:25.121659+00
11	10	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 10 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\ni 'function/api.storage_generate_presigned_get.sql'\ni 'function/api.storage_generate_presigned_post.sql'\ni 'function/reclada_object.get_condition_array.sql'\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nDROP function IF EXISTS api.storage_generate_presigned_get ;\nCREATE OR REPLACE FUNCTION api.storage_generate_presigned_get(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    credentials  jsonb;\r\n    object_data  jsonb;\r\n    object_id    uuid;\r\n    result       jsonb;\r\n    user_info    jsonb;\r\n\r\nBEGIN\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned post', '{}'))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';\r\n    END IF;\r\n\r\n    SELECT reclada_object.list('{"class": "S3Config", "attrs": {}}')::jsonb -> 0 INTO credentials;\r\n\r\n    -- TODO: check user's permissions for reclada object access?\r\n    object_id := data->>'objectId';\r\n    SELECT reclada_object.list(format(\r\n        '{"class": "File", "attrs": {}, "id": "%s"}',\r\n        object_id\r\n    )::jsonb) -> 0 INTO object_data;\r\n\r\n    SELECT payload\r\n    FROM aws_lambda.invoke(\r\n        aws_commons.create_lambda_function_arn(\r\n            's3_get_presigned_url_dev1',\r\n            'eu-west-1'\r\n            ),\r\n        format('{\r\n            "type": "get",\r\n            "uri": "%s",\r\n            "expiration": 3600}',\r\n            object_data->'attrs'->>'uri'\r\n            )::jsonb)\r\n    INTO result;\r\n\r\n    RETURN result;\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS api.storage_generate_presigned_post ;\nCREATE OR REPLACE FUNCTION api.storage_generate_presigned_post(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    bucket_name  varchar;\r\n    credentials  jsonb;\r\n    file_type    varchar;\r\n    object       jsonb;\r\n    object_id    uuid;\r\n    object_name  varchar;\r\n    object_path  varchar;\r\n    result       jsonb;\r\n    user_info    jsonb;\r\n    uri          varchar;\r\n    url          varchar;\r\n\r\nBEGIN\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned post', '{}'))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';\r\n    END IF;\r\n\r\n    SELECT reclada_object.list('{"class": "S3Config", "attrs": {}}')::jsonb -> 0 INTO credentials;\r\n\r\n    object_name := data->>'objectName';\r\n    file_type := data->>'fileType';\r\n    bucket_name := credentials->'attrs'->>'bucketName';\r\n    SELECT uuid_generate_v4() INTO object_id;\r\n    object_path := object_id;\r\n    uri := 's3://' || bucket_name || '/' || object_path;\r\n\r\n    -- TODO: remove checksum from required attrs for File class?\r\n    SELECT reclada_object.create(format(\r\n        '{"class": "File", "attrs": {"name": "%s", "mimeType": "%s", "uri": "%s", "checksum": "tempChecksum"}}',\r\n        object_name,\r\n        file_type,\r\n        uri\r\n    )::jsonb)->0 INTO object;\r\n\r\n    --data := data || format('{"objectPath": "%s"}', object_path)::jsonb;\r\n    --SELECT reclada_storage.s3_generate_presigned_post(data, credentials)::jsonb INTO url;\r\n    SELECT payload::jsonb\r\n    FROM aws_lambda.invoke(\r\n        aws_commons.create_lambda_function_arn(\r\n            's3_get_presigned_url_dev1',\r\n            'eu-west-1'\r\n            ),\r\n        format('{\r\n            "type": "post",\r\n            "bucketName": "%s",\r\n            "fileName": "%s",\r\n            "fileType": "%s",\r\n            "fileSize": "%s",\r\n            "expiration": 3600}',\r\n            bucket_name,\r\n            object_name,\r\n            file_type,\r\n            data->>'fileSize'\r\n            )::jsonb)\r\n    INTO url;\r\n\r\n    result = format(\r\n        '{"object": %s, "uploadUrl": %s}',\r\n        object,\r\n        url\r\n    )::jsonb;\r\n\r\n    RETURN result;\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.get_condition_array ;\nCREATE OR REPLACE FUNCTION reclada_object.get_condition_array(data jsonb, key_path text)\n RETURNS text\n LANGUAGE sql\n IMMUTABLE\nAS $function$\r\n    SELECT\r\n    CONCAT(\r\n        key_path,\r\n        ' ', data->>'operator', ' ',\r\n        format(E'\\'%s\\'::jsonb', data->'object'#>>'{}'))\r\n$function$\n;\n	2021-09-14 11:52:28.121112+00
12	11	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 11 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ndrop VIEW if EXISTS reclada.v_revision;\ndrop VIEW if EXISTS reclada.v_class;\ndrop VIEW if EXISTS v_active_object;\ni 'view/reclada.v_object.sql'\ni 'view/reclada.v_active_object.sql'\ni 'view/reclada.v_class.sql'\ni 'view/reclada.v_revision.sql'\n\ni 'function/api.reclada_object_create.sql'\ni 'function/api.reclada_object_list.sql'\ni 'function/api.reclada_object_update.sql'\ni 'function/api.storage_generate_presigned_post.sql'\ni 'function/api.storage_generate_presigned_get.sql'\ni 'function/reclada_notification.send_object_notification.sql'\ni 'function/reclada_object.cast_jsonb_to_postgres.sql'\ni 'function/reclada_object.create_subclass.sql'\ni 'function/reclada_object.create.sql'\ni 'function/reclada_object.get_query_condition.sql'\ni 'function/reclada_object.list_add.sql'\ni 'function/reclada_object.list_drop.sql'\ni 'function/reclada_object.list_related.sql'\ni 'function/reclada_object.list.sql'\ni 'function/reclada_object.update.sql'\ni 'function/reclada_revision.create.sql'\ni 'function/reclada.datasource_insert_trigger_fnc.sql'\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\ndrop VIEW if EXISTS reclada.v_revision;\ndrop VIEW if EXISTS reclada.v_class;\ndrop VIEW if EXISTS v_active_object;\nDROP view IF EXISTS reclada.v_object ;\nCREATE OR REPLACE VIEW reclada.v_object\nAS\n WITH t AS (\n         SELECT obj.id,\n            obj.obj_id,\n            obj.class,\n            r.num,\n            NULLIF(obj.attributes ->> 'revision'::text, ''::text)::uuid AS revision,\n            obj.attributes AS attrs,\n            obj.status,\n            obj.created_time,\n            obj.created_by\n           FROM object obj\n             LEFT JOIN ( SELECT (r_1.attributes -> 'num'::text)::bigint AS num,\n                    r_1.obj_id\n                   FROM object r_1\n                  WHERE r_1.class = 'revision'::text) r ON r.obj_id = NULLIF(obj.attributes ->> 'revision'::text, ''::text)::uuid\n        )\n SELECT t.id,\n    t.obj_id,\n    t.class,\n    t.num AS revision_num,\n    os.caption AS status_caption,\n    t.revision,\n    t.created_time,\n    t.attrs,\n    format('{\r\n                    "id": "%s",\r\n                    "class": "%s",\r\n                    "revision": %s, \r\n                    "status": "%s",\r\n                    "attrs": %s\r\n                }'::text, t.obj_id, t.class, COALESCE(('"'::text || t.revision::text) || '"'::text, 'null'::text), os.caption, t.attrs)::jsonb AS data,\n    u.login AS login_created_by,\n    t.created_by,\n    t.status\n   FROM t\n     LEFT JOIN v_object_status os ON t.status = os.obj_id\n     LEFT JOIN v_user u ON u.obj_id = t.created_by;\nDROP view IF EXISTS reclada.v_active_object ;\nCREATE OR REPLACE VIEW reclada.v_active_object\nAS\n SELECT t.id,\n    t.obj_id,\n    t.class,\n    t.revision_num,\n    t.status,\n    t.status_caption,\n    t.revision,\n    t.created_time,\n    t.attrs,\n    t.data\n   FROM v_object t\n  WHERE t.status = reclada_object.get_active_status_obj_id();\nDROP view IF EXISTS reclada.v_class ;\nCREATE OR REPLACE VIEW reclada.v_class\nAS\n SELECT obj.id,\n    obj.obj_id,\n    obj.attrs ->> 'forClass'::text AS for_class,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class = 'jsonschema'::text;\nDROP view IF EXISTS reclada.v_revision ;\nCREATE OR REPLACE VIEW reclada.v_revision\nAS\n SELECT obj.id,\n    obj.obj_id,\n    (obj.attrs ->> 'num'::text)::bigint AS num,\n    obj.attrs ->> 'branch'::text AS branch,\n    obj.attrs ->> 'user'::text AS "user",\n    obj.attrs ->> 'dateTime'::text AS date_time,\n    obj.attrs ->> 'old_num'::text AS old_num,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class = 'revision'::text;\nDROP function IF EXISTS api.reclada_object_create ;\nCREATE OR REPLACE FUNCTION api.reclada_object_create(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    data_jsonb       jsonb;\r\n    class            jsonb;\r\n    user_info        jsonb;\r\n    attrs            jsonb;\r\n    data_to_create   jsonb = '[]'::jsonb;\r\n    result           jsonb;\r\n\r\nBEGIN\r\n\r\n    IF (jsonb_typeof(data) != 'array') THEN\r\n        data := '[]'::jsonb || data;\r\n    END IF;\r\n\r\n    FOR data_jsonb IN SELECT jsonb_array_elements(data) LOOP\r\n\r\n        class := data_jsonb->'class';\r\n        IF (class IS NULL) THEN\r\n            RAISE EXCEPTION 'The reclada object class is not specified';\r\n        END IF;\r\n\r\n        SELECT reclada_user.auth_by_token(data_jsonb->>'accessToken') INTO user_info;\r\n        data_jsonb := data_jsonb - 'accessToken';\r\n\r\n        IF (NOT(reclada_user.is_allowed(user_info, 'create', class))) THEN\r\n            RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'create', class;\r\n        END IF;\r\n\r\n        attrs := data_jsonb->'attrs';\r\n        IF (attrs IS NULL) THEN\r\n            RAISE EXCEPTION 'The reclada object must have attrs';\r\n        END IF;\r\n\r\n        data_to_create := data_to_create || data_jsonb;\r\n    END LOOP;\r\n\r\n    SELECT reclada_object.create(data_to_create, user_info) INTO result;\r\n    RETURN result;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS api.reclada_object_list ;\nCREATE OR REPLACE FUNCTION api.reclada_object_list(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    class               jsonb;\r\n    user_info           jsonb;\r\n    result              jsonb;\r\n\r\nBEGIN\r\n\r\n    class := data->'class';\r\n    IF(class IS NULL) THEN\r\n        RAISE EXCEPTION 'reclada object class not specified';\r\n    END IF;\r\n\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF (NOT(reclada_user.is_allowed(user_info, 'list', class))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'list', class;\r\n    END IF;\r\n\r\n    SELECT reclada_object.list(data, true) INTO result;\r\n\r\n    RETURN result;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS api.reclada_object_update ;\nCREATE OR REPLACE FUNCTION api.reclada_object_update(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    class         jsonb;\r\n    objid         uuid;\r\n    attrs         jsonb;\r\n    user_info     jsonb;\r\n    result        jsonb;\r\n\r\nBEGIN\r\n\r\n    class := data->'class';\r\n    IF (class IS NULL) THEN\r\n        RAISE EXCEPTION 'reclada object class not specified';\r\n    END IF;\r\n\r\n    objid := data->>'id';\r\n    IF (objid IS NULL) THEN\r\n        RAISE EXCEPTION 'Could not update object with no id';\r\n    END IF;\r\n\r\n    attrs := data->'attrs';\r\n    IF (attrs IS NULL) THEN\r\n        RAISE EXCEPTION 'reclada object must have attrs';\r\n    END IF;\r\n\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF (NOT(reclada_user.is_allowed(user_info, 'update', class))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'update', class;\r\n    END IF;\r\n\r\n    SELECT reclada_object.update(data, user_info) INTO result;\r\n    RETURN result;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS api.storage_generate_presigned_post ;\nCREATE OR REPLACE FUNCTION api.storage_generate_presigned_post(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    bucket_name  varchar;\r\n    file_type    varchar;\r\n    object       jsonb;\r\n    object_id    uuid;\r\n    object_name  varchar;\r\n    object_path  varchar;\r\n    result       jsonb;\r\n    user_info    jsonb;\r\n    uri          varchar;\r\n    url          varchar;\r\n\r\nBEGIN\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned post', '{}'))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';\r\n    END IF;\r\n\r\n    object_name := data->>'objectName';\r\n    file_type := data->>'fileType';\r\n    bucket_name := data->>'bucketName';\r\n    SELECT uuid_generate_v4() INTO object_id;\r\n    object_path := object_id;\r\n    uri := 's3://' || bucket_name || '/' || object_path;\r\n\r\n    -- TODO: remove checksum from required attrs for File class?\r\n    SELECT reclada_object.create(format(\r\n        '{"class": "File", "attrs": {"name": "%s", "mimeType": "%s", "uri": "%s", "checksum": "tempChecksum"}}',\r\n        object_name,\r\n        file_type,\r\n        uri\r\n    )::jsonb)->0 INTO object;\r\n\r\n    SELECT payload::jsonb\r\n    FROM aws_lambda.invoke(\r\n        aws_commons.create_lambda_function_arn(\r\n            's3_get_presigned_url_test',\r\n            'eu-west-1'\r\n            ),\r\n        format('{\r\n            "type": "post",\r\n            "bucketName": "%s",\r\n            "fileName": "%s",\r\n            "fileType": "%s",\r\n            "fileSize": "%s",\r\n            "expiration": 3600}',\r\n            bucket_name,\r\n            object_name,\r\n            file_type,\r\n            data->>'fileSize'\r\n            )::jsonb)\r\n    INTO url;\r\n\r\n    result = format(\r\n        '{"object": %s, "uploadUrl": %s}',\r\n        object,\r\n        url\r\n    )::jsonb;\r\n\r\n    RETURN result;\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS api.storage_generate_presigned_get ;\nCREATE OR REPLACE FUNCTION api.storage_generate_presigned_get(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    object_data  jsonb;\r\n    object_id    uuid;\r\n    result       jsonb;\r\n    user_info    jsonb;\r\n\r\nBEGIN\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned post', '{}'))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';\r\n    END IF;\r\n\r\n    -- TODO: check user's permissions for reclada object access?\r\n    object_id := data->>'objectId';\r\n    SELECT reclada_object.list(format(\r\n        '{"class": "File", "attrs": {}, "id": "%s"}',\r\n        object_id\r\n    )::jsonb) -> 0 INTO object_data;\r\n\r\n    SELECT payload\r\n    FROM aws_lambda.invoke(\r\n        aws_commons.create_lambda_function_arn(\r\n            's3_get_presigned_url_test',\r\n            'eu-west-1'\r\n            ),\r\n        format('{\r\n            "type": "get",\r\n            "uri": "%s",\r\n            "expiration": 3600}',\r\n            object_data->'attrs'->>'uri'\r\n            )::jsonb)\r\n    INTO result;\r\n\r\n    RETURN result;\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_notification.send_object_notification ;\nCREATE OR REPLACE FUNCTION reclada_notification.send_object_notification(event character varying, object_data jsonb)\n RETURNS void\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    data            jsonb;\r\n    message         jsonb;\r\n    msg             jsonb;\r\n    object_class    varchar;\r\n    attrs           jsonb;\r\n    query           text;\r\n\r\nBEGIN\r\n\r\n    IF (jsonb_typeof(object_data) != 'array') THEN\r\n        object_data := '[]'::jsonb || object_data;\r\n    END IF;\r\n\r\n    FOR data IN SELECT jsonb_array_elements(object_data) LOOP\r\n        object_class := data ->> 'class';\r\n\r\n        if event is null or object_class is null then\r\n            return;\r\n        end if;\r\n        \r\n        SELECT v.data \r\n            FROM reclada.v_active_object v\r\n                WHERE v.class = 'Message'\r\n                    AND v.attrs->>'event' = event\r\n                    AND v.attrs->>'class' = object_class\r\n        INTO message;\r\n\r\n        IF message IS NULL THEN\r\n            RETURN;\r\n        END IF;\r\n\r\n        query := format(E'select to_json(x) from jsonb_to_record($1) as x(%s)',\r\n            (select string_agg(s::text || ' jsonb', ',') from jsonb_array_elements(message -> 'attrs' -> 'attrs') s));\r\n        execute query into attrs using data -> 'attrs';\r\n\r\n        msg := jsonb_build_object(\r\n            'objectId', data -> 'id',\r\n            'class', object_class,\r\n            'event', event,\r\n            'attrs', attrs\r\n        );\r\n\r\n        perform reclada_notification.send(message #>> '{attrs, channelName}', msg);\r\n\r\n    END LOOP;\r\nEND\r\n$function$\n;\nDROP function IF EXISTS reclada_object.cast_jsonb_to_postgres ;\nCREATE OR REPLACE FUNCTION reclada_object.cast_jsonb_to_postgres(key_path text, type text, type_of_array text DEFAULT 'text'::text)\n RETURNS text\n LANGUAGE sql\n IMMUTABLE\nAS $function$\r\nSELECT\r\n        CASE\r\n            WHEN type = 'string' THEN\r\n                format(E'(%s#>>\\'{}\\')::text', key_path)\r\n            WHEN type = 'number' THEN\r\n                format(E'(%s)::numeric', key_path)\r\n            WHEN type = 'boolean' THEN\r\n                format(E'(%s)::boolean', key_path)\r\n            WHEN type = 'array' THEN\r\n                format(\r\n                    E'ARRAY(SELECT jsonb_array_elements_text(%s)::%s)',\r\n                    key_path,\r\n                     CASE\r\n                        WHEN type_of_array = 'string' THEN 'text'\r\n                        WHEN type_of_array = 'number' THEN 'numeric'\r\n                        WHEN type_of_array = 'boolean' THEN 'boolean'\r\n                     END\r\n                    )\r\n        END\r\n$function$\n;\nDROP function IF EXISTS reclada_object.create_subclass ;\nCREATE OR REPLACE FUNCTION reclada_object.create_subclass(data jsonb)\n RETURNS void\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    class           text;\r\n    attrs           jsonb;\r\n    class_schema    jsonb;\r\n\r\nBEGIN\r\n\r\n    class := data->>'class';\r\n    IF (class IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object class is not specified';\r\n    END IF;\r\n\r\n    attrs := data->'attrs';\r\n    IF (attrs IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object must have attrs';\r\n    END IF;\r\n\r\n    SELECT reclada_object.get_schema(class) INTO class_schema;\r\n    IF (class_schema IS NULL) THEN\r\n        RAISE EXCEPTION 'No json schema available for %', class;\r\n    END IF;\r\n\r\n    class_schema := class_schema->'attrs'->'schema';\r\n\r\n    PERFORM reclada_object.create(format('{\r\n        "class": "jsonschema",\r\n        "attrs": {\r\n            "forClass": "%s",\r\n            "schema": {\r\n                "type": "object",\r\n                "properties": %s,\r\n                "required": %s\r\n                }\r\n            }\r\n        }',\r\n        attrs->>'newClass',\r\n        (class_schema->'properties') || (attrs->'properties'),\r\n        (SELECT jsonb_agg(el) FROM (SELECT DISTINCT pg_catalog.jsonb_array_elements((class_schema -> 'required') || (attrs -> 'required')) el) arr)\r\n    )::jsonb);\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.create ;\nCREATE OR REPLACE FUNCTION reclada_object."create"(data_jsonb jsonb, user_info jsonb DEFAULT '{}'::jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    branch     uuid;\r\n    data       jsonb;\r\n    class      text;\r\n    attrs      jsonb;\r\n    schema     jsonb;\r\n    res        jsonb;\r\n\r\nBEGIN\r\n\r\n    IF (jsonb_typeof(data_jsonb) != 'array') THEN\r\n        data_jsonb := '[]'::jsonb || data_jsonb;\r\n    END IF;\r\n    /*TODO: check if some objects have revision and others do not */\r\n    branch:= data_jsonb->0->'branch';\r\n    create temp table IF NOT EXISTS tmp(id uuid)\r\n    ON COMMIT drop;\r\n    delete from tmp;\r\n    FOR data IN SELECT jsonb_array_elements(data_jsonb) \r\n    LOOP\r\n\r\n        class := data->>'class';\r\n        IF (class IS NULL) THEN\r\n            RAISE EXCEPTION 'The reclada object class is not specified';\r\n        END IF;\r\n\r\n        attrs := data->'attrs';\r\n        IF (attrs IS NULL) THEN\r\n            RAISE EXCEPTION 'The reclada object must have attrs';\r\n        END IF;\r\n\r\n        SELECT reclada_object.get_schema(class) \r\n            INTO schema;\r\n\r\n        IF (schema IS NULL) THEN\r\n            RAISE EXCEPTION 'No json schema available for %', class;\r\n        END IF;\r\n\r\n        IF (NOT(validate_json_schema(schema->'attrs'->'schema', attrs))) THEN\r\n            RAISE EXCEPTION 'JSON invalid: %', attrs;\r\n        END IF;\r\n\r\n        with inserted as \r\n        (\r\n            INSERT INTO reclada.object(class,attributes)\r\n                select class, attrs\r\n                    RETURNING obj_id\r\n        ) \r\n        insert into tmp(id)\r\n            select obj_id \r\n                from inserted;\r\n\r\n    END LOOP;\r\n\r\n    res := array_to_json\r\n            (\r\n                array\r\n                (\r\n                    select o.data \r\n                        from reclada.v_active_object o\r\n                        join tmp t\r\n                            on t.id = o.obj_id\r\n                )\r\n            )::jsonb; \r\n    PERFORM reclada_notification.send_object_notification\r\n        (\r\n            'create',\r\n            res\r\n        );\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.get_query_condition ;\nCREATE OR REPLACE FUNCTION reclada_object.get_query_condition(data jsonb, key_path text)\n RETURNS text\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    key          text;\r\n    operator     text;\r\n    value        text;\r\n    res          text;\r\n\r\nBEGIN\r\n    IF (data IS NULL OR data = 'null'::jsonb) THEN\r\n        RAISE EXCEPTION 'There is no condition';\r\n    END IF;\r\n\r\n    IF (jsonb_typeof(data) = 'object') THEN\r\n\r\n        IF (data->'object' IS NULL OR data->'object' = ('null'::jsonb)) THEN\r\n            RAISE EXCEPTION 'There is no object field';\r\n        END IF;\r\n\r\n        IF (jsonb_typeof(data->'object') = 'object') THEN\r\n            RAISE EXCEPTION 'The input_jsonb->''object'' can not contain jsonb object';\r\n        END IF;\r\n\r\n        IF (jsonb_typeof(data->'operator') != 'string' AND data->'operator' IS NOT NULL) THEN\r\n            RAISE EXCEPTION 'The input_jsonb->''operator'' must contain string';\r\n        END IF;\r\n\r\n        IF (jsonb_typeof(data->'object') = 'array') THEN\r\n            res := reclada_object.get_condition_array(data, key_path);\r\n        ELSE\r\n            key := reclada_object.cast_jsonb_to_postgres(key_path, jsonb_typeof(data->'object'));\r\n            operator :=  data->>'operator';\r\n            value := reclada_object.jsonb_to_text(data->'object');\r\n            res := key || ' ' || operator || ' ' || value;\r\n        END IF;\r\n    ELSE\r\n        key := reclada_object.cast_jsonb_to_postgres(key_path, jsonb_typeof(data));\r\n        operator := '=';\r\n        value := reclada_object.jsonb_to_text(data);\r\n        res := key || ' ' || operator || ' ' || value;\r\n    END IF;\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.list_add ;\nCREATE OR REPLACE FUNCTION reclada_object.list_add(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    class          text;\r\n    objid          uuid;\r\n    obj            jsonb;\r\n    values_to_add  jsonb;\r\n    field          text;\r\n    field_value    jsonb;\r\n    json_path      text[];\r\n    new_obj        jsonb;\r\n    res            jsonb;\r\n\r\nBEGIN\r\n\r\n    class := data->>'class';\r\n    IF (class IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object class is not specified';\r\n    END IF;\r\n\r\n    objid := (data->>'id')::uuid;\r\n    IF (objid IS NULL) THEN\r\n        RAISE EXCEPTION 'There is no id';\r\n    END IF;\r\n\r\n    SELECT v.data\r\n\tFROM reclada.v_active_object v\r\n\tWHERE v.obj_id = objid\r\n\tINTO obj;\r\n\r\n    IF (obj IS NULL) THEN\r\n        RAISE EXCEPTION 'There is no object with such id';\r\n    END IF;\r\n\r\n    values_to_add := data->'value';\r\n    IF (values_to_add IS NULL OR values_to_add = 'null'::jsonb) THEN\r\n        RAISE EXCEPTION 'The value should not be null';\r\n    END IF;\r\n\r\n    IF (jsonb_typeof(values_to_add) != 'array') THEN\r\n        values_to_add := format('[%s]', values_to_add)::jsonb;\r\n    END IF;\r\n\r\n    field := data->>'field';\r\n    IF (field IS NULL) THEN\r\n        RAISE EXCEPTION 'There is no field';\r\n    END IF;\r\n    json_path := format('{attrs, %s}', field);\r\n    field_value := obj#>json_path;\r\n\r\n    IF ((field_value = 'null'::jsonb) OR (field_value IS NULL)) THEN\r\n        SELECT jsonb_set(obj, json_path, values_to_add)\r\n        INTO new_obj;\r\n    ELSE\r\n        SELECT jsonb_set(obj, json_path, field_value || values_to_add)\r\n        INTO new_obj;\r\n    END IF;\r\n\r\n    SELECT reclada_object.update(new_obj) INTO res;\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.list_drop ;\nCREATE OR REPLACE FUNCTION reclada_object.list_drop(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    class           text;\r\n    objid           uuid;\r\n    obj             jsonb;\r\n    values_to_drop  jsonb;\r\n    field           text;\r\n    field_value     jsonb;\r\n    json_path       text[];\r\n    new_value       jsonb;\r\n    new_obj         jsonb;\r\n    res             jsonb;\r\n\r\nBEGIN\r\n\r\n\tclass := data->>'class';\r\n\tIF (class IS NULL) THEN\r\n\t\tRAISE EXCEPTION 'The reclada object class is not specified';\r\n\tEND IF;\r\n\r\n\tobjid := (data->>'id')::uuid;\r\n\tIF (objid IS NULL) THEN\r\n\t\tRAISE EXCEPTION 'The is no id';\r\n\tEND IF;\r\n\r\n    SELECT v.data\r\n    FROM reclada.v_active_object v\r\n    WHERE v.obj_id = objid\r\n    INTO obj;\r\n\r\n\tIF (obj IS NULL) THEN\r\n\t\tRAISE EXCEPTION 'The is no object with such id';\r\n\tEND IF;\r\n\r\n\tvalues_to_drop := data->'value';\r\n\tIF (values_to_drop IS NULL OR values_to_drop = 'null'::jsonb) THEN\r\n\t\tRAISE EXCEPTION 'The value should not be null';\r\n\tEND IF;\r\n\r\n\tIF (jsonb_typeof(values_to_drop) != 'array') THEN\r\n\t\tvalues_to_drop := format('[%s]', values_to_drop)::jsonb;\r\n\tEND IF;\r\n\r\n\tfield := data->>'field';\r\n\tIF (field IS NULL) THEN\r\n\t\tRAISE EXCEPTION 'There is no field';\r\n\tEND IF;\r\n\tjson_path := format('{attrs, %s}', field);\r\n\tfield_value := obj#>json_path;\r\n\tIF (field_value IS NULL OR field_value = 'null'::jsonb) THEN\r\n\t\tRAISE EXCEPTION 'The object does not have this field';\r\n\tEND IF;\r\n\r\n\tSELECT jsonb_agg(elems)\r\n\tFROM\r\n\t\tjsonb_array_elements(field_value) elems\r\n\tWHERE\r\n\t\telems NOT IN (\r\n\t\t\tSELECT jsonb_array_elements(values_to_drop))\r\n\tINTO new_value;\r\n\r\n\tSELECT jsonb_set(obj, json_path, coalesce(new_value, '[]'::jsonb))\r\n\tINTO new_obj;\r\n\r\n\tSELECT reclada_object.update(new_obj) INTO res;\r\n\tRETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.list_related ;\nCREATE OR REPLACE FUNCTION reclada_object.list_related(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    class          text;\r\n    objid          uuid;\r\n    field          text;\r\n    related_class  text;\r\n    obj            jsonb;\r\n    list_of_ids    jsonb;\r\n    cond           jsonb = '{}'::jsonb;\r\n    order_by       jsonb;\r\n    limit_         text;\r\n    offset_        text;\r\n    res            jsonb;\r\n\r\nBEGIN\r\n    class := data->>'class';\r\n    IF (class IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object class is not specified';\r\n    END IF;\r\n\r\n    objid := (data->>'id')::uuid;\r\n    IF (objid IS NULL) THEN\r\n        RAISE EXCEPTION 'The object id is not specified';\r\n    END IF;\r\n\r\n    field := data->>'field';\r\n    IF (field IS NULL) THEN\r\n        RAISE EXCEPTION 'The object field is not specified';\r\n    END IF;\r\n\r\n    related_class := data->>'relatedClass';\r\n    IF (related_class IS NULL) THEN\r\n        RAISE EXCEPTION 'The related class is not specified';\r\n    END IF;\r\n\r\n\tSELECT v.data\r\n\tFROM reclada.v_active_object v\r\n\tWHERE v.obj_id = objid\r\n\tINTO obj;\r\n\r\n    IF (obj IS NULL) THEN\r\n        RAISE EXCEPTION 'There is no object with such id';\r\n    END IF;\r\n\r\n    list_of_ids := obj#>(format('{attrs, %s}', field)::text[]);\r\n    IF (list_of_ids IS NULL) THEN\r\n        RAISE EXCEPTION 'The object does not have this field';\r\n    END IF;\r\n\r\n    order_by := data->'orderBy';\r\n    IF (order_by IS NOT NULL) THEN\r\n        cond := cond || (format('{"orderBy": %s}', order_by)::jsonb);\r\n    END IF;\r\n\r\n    limit_ := data->>'limit';\r\n    IF (limit_ IS NOT NULL) THEN\r\n        cond := cond || (format('{"limit": "%s"}', limit_)::jsonb);\r\n    END IF;\r\n\r\n    offset_ := data->>'offset';\r\n    IF (offset_ IS NOT NULL) THEN\r\n        cond := cond || (format('{"offset": "%s"}', offset_)::jsonb);\r\n    END IF;\r\n\r\n    SELECT reclada_object.list(format(\r\n        '{"class": "%s", "attrs": {}, "id": {"operator": "<@", "object": %s}}',\r\n        related_class,\r\n        list_of_ids\r\n        )::jsonb || cond,\r\n        true)\r\n    INTO res;\r\n\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.list ;\nCREATE OR REPLACE FUNCTION reclada_object.list(data jsonb, with_number boolean DEFAULT false)\n RETURNS jsonb\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    class               text;\r\n    attrs               jsonb;\r\n    order_by_jsonb      jsonb;\r\n    order_by            text;\r\n    limit_              text;\r\n    offset_             text;\r\n    query_conditions    text;\r\n    number_of_objects   int;\r\n    objects             jsonb;\r\n    res                 jsonb;\r\n    query               text;\r\nBEGIN\r\n\r\n    class := data->>'class';\r\n    IF (class IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object class is not specified';\r\n    END IF;\r\n\r\n    attrs := data->'attrs' || '{}'::jsonb;\r\n\r\n    order_by_jsonb := data->'orderBy';\r\n    IF ((order_by_jsonb IS NULL) OR\r\n        (order_by_jsonb = 'null'::jsonb) OR\r\n        (order_by_jsonb = '[]'::jsonb)) THEN\r\n        order_by_jsonb := '[{"field": "id", "order": "ASC"}]'::jsonb;\r\n    END IF;\r\n    IF (jsonb_typeof(order_by_jsonb) != 'array') THEN\r\n    \t\torder_by_jsonb := format('[%s]', order_by_jsonb);\r\n    END IF;\r\n    SELECT string_agg(\r\n        format(E'obj.data#>''{%s}'' %s', T.value->>'field', COALESCE(T.value->>'order', 'ASC')),\r\n        ' , ')\r\n    FROM jsonb_array_elements(order_by_jsonb) T\r\n    INTO order_by;\r\n\r\n    limit_ := data->>'limit';\r\n    IF (limit_ IS NULL) THEN\r\n        limit_ := 500;\r\n    END IF;\r\n    IF ((limit_ ~ '(\\D+)') AND (limit_ != 'ALL')) THEN\r\n    \t\tRAISE EXCEPTION 'The limit must be an integer number or "ALL"';\r\n    END IF;\r\n\r\n    offset_ := data->>'offset';\r\n    IF (offset_ IS NULL) THEN\r\n        offset_ := 0;\r\n    END IF;\r\n    IF (offset_ ~ '(\\D+)') THEN\r\n    \t\tRAISE EXCEPTION 'The offset must be an integer number';\r\n    END IF;\r\n\r\n    SELECT\r\n        string_agg(\r\n            format(\r\n                E'(%s)',\r\n                condition\r\n            ),\r\n            ' AND '\r\n        )\r\n        FROM (\r\n            SELECT\r\n                -- ((('"'||class||'"')::jsonb#>>'{}')::text = 'Job')\r\n                --reclada_object.get_query_condition(class, E'data->''class''') AS condition\r\n                --'class = data->>''class''' AS condition\r\n                format('obj.class = ''%s''', class) AS condition\r\n            UNION\r\n            SELECT  CASE\r\n                        WHEN jsonb_typeof(data->'id') = 'array' THEN\r\n                        (\r\n                            SELECT string_agg\r\n                                (\r\n                                    format(\r\n                                        E'(%s)',\r\n                                        reclada_object.get_query_condition(cond, E'data->''id''')\r\n                                    ),\r\n                                    ' AND '\r\n                                )\r\n                                FROM jsonb_array_elements(data->'id') AS cond\r\n                        )\r\n                        ELSE reclada_object.get_query_condition(data->'id', E'data->''id''')\r\n                    END AS condition\r\n                WHERE coalesce(data->'id','null'::jsonb) != 'null'::jsonb\r\n            -- UNION\r\n            -- SELECT 'obj.data->>''status''=''active'''-- TODO: change working with revision\r\n            -- UNION SELECT\r\n            --     CASE WHEN data->'revision' IS NULL THEN\r\n            --         E'(data->>''revision''):: numeric = (SELECT max((objrev.data -> ''revision'')::numeric)\r\n            --         FROM reclada.v_object objrev WHERE\r\n            --         objrev.data -> ''id'' = obj.data -> ''id'')'\r\n            --     WHEN jsonb_typeof(data->'revision') = 'array' THEN\r\n            --         (SELECT string_agg(\r\n            --             format(\r\n            --                 E'(%s)',\r\n            --                 reclada_object.get_query_condition(cond, E'data->''revision''')\r\n            --             ),\r\n            --             ' AND '\r\n            --         )\r\n            --         FROM jsonb_array_elements(data->'revision') AS cond)\r\n            --     ELSE reclada_object.get_query_condition(data->'revision', E'data->''revision''') END AS condition\r\n            UNION\r\n            SELECT\r\n                CASE\r\n                    WHEN jsonb_typeof(value) = 'array'\r\n                        THEN\r\n                            (\r\n                                SELECT string_agg\r\n                                    (\r\n                                        format\r\n                                        (\r\n                                            E'(%s)',\r\n                                            reclada_object.get_query_condition(cond, format(E'data->''attrs''->%L', key))\r\n                                        ),\r\n                                        ' AND '\r\n                                    )\r\n                                    FROM jsonb_array_elements(value) AS cond\r\n                            )\r\n                    ELSE reclada_object.get_query_condition(value, format(E'data->''attrs''->%L', key))\r\n                END AS condition\r\n            FROM jsonb_each(attrs)\r\n            WHERE data->'attrs' != ('{}'::jsonb)\r\n        ) conds\r\n    INTO query_conditions;\r\n\r\n    -- RAISE NOTICE 'conds: %', '\r\n    --             SELECT obj.data\r\n    --             FROM reclada.v_object obj\r\n    --             WHERE ' || query_conditions ||\r\n    --             ' ORDER BY ' || order_by ||\r\n    --             ' OFFSET ' || offset_ || ' LIMIT ' || limit_ ;\r\n    query := 'FROM reclada.v_active_object obj WHERE ' || query_conditions;\r\n    raise notice 'query: %', query;\r\n    EXECUTE E'SELECT to_jsonb(array_agg(T.data))\r\n        FROM (\r\n            SELECT obj.data\r\n            '\r\n            || query\r\n            ||\r\n            ' ORDER BY ' || order_by ||\r\n            ' OFFSET ' || offset_ || ' LIMIT ' || limit_ || ') T'\r\n    INTO objects;\r\n    IF with_number THEN\r\n\r\n        EXECUTE E'SELECT count(1)\r\n        '|| query\r\n        INTO number_of_objects;\r\n\r\n        res := jsonb_build_object(\r\n        'number', number_of_objects,\r\n        'objects', objects);\r\n    ELSE\r\n        res := objects;\r\n    END IF;\r\n\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.update ;\nCREATE OR REPLACE FUNCTION reclada_object.update(data jsonb, user_info jsonb DEFAULT '{}'::jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    v_class         text;\r\n    v_obj_id        uuid;\r\n    v_attrs         jsonb;\r\n    schema        jsonb;\r\n    old_obj       jsonb;\r\n    branch        uuid;\r\n    revid         uuid;\r\n\r\nBEGIN\r\n\r\n    v_class := data->>'class';\r\n    IF (v_class IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object class is not specified';\r\n    END IF;\r\n\r\n    v_obj_id := data->>'id';\r\n    IF (v_obj_id IS NULL) THEN\r\n        RAISE EXCEPTION 'Could not update object with no id';\r\n    END IF;\r\n\r\n    v_attrs := data->'attrs';\r\n    IF (v_attrs IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object must have attrs';\r\n    END IF;\r\n\r\n    SELECT reclada_object.get_schema(v_class) \r\n        INTO schema;\r\n\r\n    IF (schema IS NULL) THEN\r\n        RAISE EXCEPTION 'No json schema available for %', v_class;\r\n    END IF;\r\n\r\n    IF (NOT(validate_json_schema(schema->'attrs'->'schema', v_attrs))) THEN\r\n        RAISE EXCEPTION 'JSON invalid: %', v_attrs;\r\n    END IF;\r\n\r\n    SELECT \tv.data\r\n        FROM reclada.v_active_object v\r\n\t        WHERE v.obj_id = v_obj_id\r\n\t    INTO old_obj;\r\n\r\n    IF (old_obj IS NULL) THEN\r\n        RAISE EXCEPTION 'Could not update object, no such id';\r\n    END IF;\r\n\r\n    branch := data->'branch';\r\n    SELECT reclada_revision.create(user_info->>'sub', branch, v_obj_id) \r\n        INTO revid;\r\n    \r\n    with t as \r\n    (\r\n        update reclada.object o\r\n            set status = reclada_object.get_archive_status_obj_id()\r\n                where o.obj_id = v_obj_id\r\n                    and status != reclada_object.get_archive_status_obj_id()\r\n                        RETURNING id\r\n    )\r\n    INSERT INTO reclada.object( obj_id,\r\n                                class,\r\n                                status,\r\n                                attributes\r\n                              )\r\n        select  v.obj_id,\r\n                v_class,\r\n                reclada_object.get_active_status_obj_id(),--status \r\n                v_attrs || format('{"revision":"%s"}',revid)::jsonb\r\n            FROM reclada.v_object v\r\n            JOIN t \r\n                on t.id = v.id\r\n\t            WHERE v.obj_id = v_obj_id;\r\n                    \r\n    select v.data \r\n        FROM reclada.v_active_object v\r\n            WHERE v.obj_id = v_obj_id\r\n        into data;\r\n    PERFORM reclada_notification.send_object_notification('update', data);\r\n    RETURN data;\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_revision.create ;\nCREATE OR REPLACE FUNCTION reclada_revision."create"(userid character varying, branch uuid, obj uuid)\n RETURNS uuid\n LANGUAGE sql\nAS $function$\r\n    INSERT INTO reclada.object\r\n        (\r\n            class,\r\n            attributes\r\n        )\r\n               \r\n        VALUES\r\n        (\r\n            'revision'               ,-- class,\r\n            format                    -- attrs\r\n            (                         \r\n                '{\r\n                    "num": %s,\r\n                    "user": "%s",\r\n                    "dateTime": "%s",\r\n                    "branch": "%s"\r\n                }',\r\n                (\r\n                    select count(*)\r\n                        from reclada.object o\r\n                            where o.obj_id = obj\r\n                ),\r\n                userid,\r\n                now(),\r\n                branch\r\n            )::jsonb\r\n        ) RETURNING (obj_id)::uuid;\r\n    --nextval('reclada.reclada_revisions'),\r\n$function$\n;\nDROP TRIGGER IF EXISTS datasource_insert_trigger ON reclada.object;\nDROP function IF EXISTS reclada.datasource_insert_trigger_fnc ;\nCREATE OR REPLACE FUNCTION reclada.datasource_insert_trigger_fnc()\n RETURNS trigger\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    obj_id         uuid;\r\n    dataset       jsonb;\r\n    uri           text;\r\n\r\nBEGIN\r\n    IF (NEW.class = 'DataSource') OR (NEW.class = 'File') THEN\r\n\r\n        obj_id := NEW.obj_id;\r\n\r\n        SELECT v.data\r\n        FROM reclada.v_active_object v\r\n\t    WHERE v.attrs->>'name' = 'defaultDataSet'\r\n\t    INTO dataset;\r\n\r\n        dataset := jsonb_set(dataset, '{attrs, dataSources}', dataset->'attrs'->'dataSources' || format('["%s"]', obj_id)::jsonb);\r\n\r\n        PERFORM reclada_object.update(dataset);\r\n\r\n        uri := NEW.attributes->>'uri';\r\n\r\n        PERFORM reclada_object.create(\r\n            format('{\r\n                "class": "Job",\r\n                "attrs": {\r\n                    "task": "c94bff30-15fa-427f-9954-d5c3c151e652",\r\n                    "status": "new",\r\n                    "type": "K8S",\r\n                    "command": "./run_pipeline.sh",\r\n                    "inputParameters": [{"uri": "%s"}, {"dataSourceId": "%s"}]\r\n                    }\r\n                }', uri, obj_id)::jsonb);\r\n\r\n    END IF;\r\n\r\nRETURN NEW;\r\nEND;\r\n$function$\n;\nCREATE TRIGGER datasource_insert_trigger\n  BEFORE INSERT\n  ON reclada.object FOR EACH ROW\n  EXECUTE PROCEDURE reclada.datasource_insert_trigger_fnc();	2021-09-14 11:52:31.433117+00
13	12	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 12 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\n\ni 'function/reclada_revision.create.sql'\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nDROP function IF EXISTS reclada_revision.create ;\nCREATE OR REPLACE FUNCTION reclada_revision."create"(userid character varying, branch uuid, obj uuid)\n RETURNS uuid\n LANGUAGE sql\nAS $function$\r\n    INSERT INTO reclada.object\r\n        (\r\n            class,\r\n            attributes\r\n        )\r\n               \r\n        VALUES\r\n        (\r\n            'revision'               ,-- class,\r\n            format                    -- attributes\r\n            (                         \r\n                '{\r\n                    "num": %s,\r\n                    "user": "%s",\r\n                    "dateTime": "%s",\r\n                    "branch": "%s"\r\n                }',\r\n                (\r\n                    select count(*)\r\n                        from reclada.object o\r\n                            where o.obj_id = obj\r\n                ),\r\n                userid,\r\n                now(),\r\n                branch\r\n            )::jsonb\r\n        ) RETURNING (obj_id)::uuid;\r\n    --nextval('reclada.reclada_revisions'),\r\n$function$\n;	2021-09-14 11:52:37.982344+00
14	13	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 13 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ndrop VIEW if EXISTS reclada.v_class;\ndrop VIEW if EXISTS reclada.v_revision ;\ndrop VIEW if EXISTS reclada.v_active_object;\n\ni 'view/reclada.v_object.sql'\ni 'view/reclada.v_active_object.sql'\ni 'view/reclada.v_revision.sql'\ni 'view/reclada.v_class.sql'\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\ndrop VIEW if EXISTS reclada.v_class;\ndrop VIEW if EXISTS reclada.v_revision;\ndrop VIEW if EXISTS reclada.v_active_object;\nDROP view IF EXISTS reclada.v_object ;\nCREATE OR REPLACE VIEW reclada.v_object\nAS\n WITH t AS (\n         SELECT obj.id,\n            obj.obj_id,\n            obj.class,\n            r.num,\n            NULLIF(obj.attributes ->> 'revision'::text, ''::text)::uuid AS revision,\n            obj.attributes AS attrs,\n            obj.status,\n            obj.created_time,\n            obj.created_by\n           FROM object obj\n             LEFT JOIN ( SELECT (r_1.attributes -> 'num'::text)::bigint AS num,\n                    r_1.obj_id\n                   FROM object r_1\n                  WHERE r_1.class = 'revision'::text) r ON r.obj_id = NULLIF(obj.attributes ->> 'revision'::text, ''::text)::uuid\n        )\n SELECT t.id,\n    t.obj_id,\n    t.class,\n    t.num AS revision_num,\n    os.caption AS status_caption,\n    t.revision,\n    t.created_time,\n    t.attrs,\n    format('{\r\n                    "id": "%s",\r\n                    "class": "%s",\r\n                    "revision": %s, \r\n                    "status": "%s",\r\n                    "attributes": %s\r\n                }'::text, t.obj_id, t.class, COALESCE(('"'::text || t.revision::text) || '"'::text, 'null'::text), os.caption, t.attrs)::jsonb AS data,\n    u.login AS login_created_by,\n    t.created_by,\n    t.status\n   FROM t\n     LEFT JOIN v_object_status os ON t.status = os.obj_id\n     LEFT JOIN v_user u ON u.obj_id = t.created_by;\nDROP view IF EXISTS reclada.v_active_object ;\nCREATE OR REPLACE VIEW reclada.v_active_object\nAS\n SELECT t.id,\n    t.obj_id,\n    t.class,\n    t.revision_num,\n    t.status,\n    t.status_caption,\n    t.revision,\n    t.created_time,\n    t.attrs,\n    t.data\n   FROM v_object t\n  WHERE t.status = reclada_object.get_active_status_obj_id();\nDROP view IF EXISTS reclada.v_revision ;\nCREATE OR REPLACE VIEW reclada.v_revision\nAS\n SELECT obj.id,\n    obj.obj_id,\n    (obj.attrs ->> 'num'::text)::bigint AS num,\n    obj.attrs ->> 'branch'::text AS branch,\n    obj.attrs ->> 'user'::text AS "user",\n    obj.attrs ->> 'dateTime'::text AS date_time,\n    obj.attrs ->> 'old_num'::text AS old_num,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class = 'revision'::text;\nDROP view IF EXISTS reclada.v_class ;\nCREATE OR REPLACE VIEW reclada.v_class\nAS\n SELECT obj.id,\n    obj.obj_id,\n    obj.attrs ->> 'forClass'::text AS for_class,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class = 'jsonschema'::text;	2021-09-14 11:52:40.857246+00
15	14	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 14 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/reclada_object.get_query_condition.sql'\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nDROP function IF EXISTS reclada_object.get_query_condition ;\nCREATE OR REPLACE FUNCTION reclada_object.get_query_condition(data jsonb, key_path text)\n RETURNS text\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    key          text;\r\n    operator     text;\r\n    value        text;\r\n    res          text;\r\n\r\nBEGIN\r\n    IF (data IS NULL OR data = 'null'::jsonb) THEN\r\n        RAISE EXCEPTION 'There is no condition';\r\n    END IF;\r\n\r\n    IF (jsonb_typeof(data) = 'object') THEN\r\n\r\n        IF (data->'object' IS NULL OR data->'object' = ('null'::jsonb)) THEN\r\n            RAISE EXCEPTION 'There is no object field';\r\n        END IF;\r\n\r\n        IF (jsonb_typeof(data->'object') = 'object') THEN\r\n            RAISE EXCEPTION 'The input_jsonb->''object'' can not contain jsonb object';\r\n        END IF;\r\n\r\n        IF (jsonb_typeof(data->'operator') != 'string' AND data->'operator' IS NOT NULL) THEN\r\n            RAISE EXCEPTION 'The input_jsonb->''operator'' must contain string';\r\n        END IF;\r\n\r\n        IF (jsonb_typeof(data->'object') = 'array') THEN\r\n            res := reclada_object.get_condition_array(data, key_path);\r\n        ELSE\r\n            key := reclada_object.cast_jsonb_to_postgres(key_path, jsonb_typeof(data->'object'));\r\n            operator :=  data->>'operator';\r\n            value := reclada_object.jsonb_to_text(data->'object');\r\n            res := key || ' ' || operator || ' ' || value;\r\n        END IF;\r\n    ELSE\r\n        key := reclada_object.cast_jsonb_to_postgres(key_path, jsonb_typeof(data));\r\n        operator := '=';\r\n        value := reclada_object.jsonb_to_text(data);\r\n        res := key || ' ' || operator || ' ' || value;\r\n    END IF;\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;	2021-09-14 11:52:44.697425+00
16	15	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 15 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/reclada_object.list.sql'\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nDROP function IF EXISTS reclada_object.list ;\nCREATE OR REPLACE FUNCTION reclada_object.list(data jsonb, with_number boolean DEFAULT false)\n RETURNS jsonb\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    class               text;\r\n    attrs               jsonb;\r\n    order_by_jsonb      jsonb;\r\n    order_by            text;\r\n    limit_              text;\r\n    offset_             text;\r\n    query_conditions    text;\r\n    number_of_objects   int;\r\n    objects             jsonb;\r\n    res                 jsonb;\r\n    query               text;\r\nBEGIN\r\n\r\n    class := data->>'class';\r\n    IF (class IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object class is not specified';\r\n    END IF;\r\n\r\n    attrs := data->'attributes' || '{}'::jsonb;\r\n\r\n    order_by_jsonb := data->'orderBy';\r\n    IF ((order_by_jsonb IS NULL) OR\r\n        (order_by_jsonb = 'null'::jsonb) OR\r\n        (order_by_jsonb = '[]'::jsonb)) THEN\r\n        order_by_jsonb := '[{"field": "id", "order": "ASC"}]'::jsonb;\r\n    END IF;\r\n    IF (jsonb_typeof(order_by_jsonb) != 'array') THEN\r\n    \t\torder_by_jsonb := format('[%s]', order_by_jsonb);\r\n    END IF;\r\n    SELECT string_agg(\r\n        format(E'obj.data#>''{%s}'' %s', T.value->>'field', COALESCE(T.value->>'order', 'ASC')),\r\n        ' , ')\r\n    FROM jsonb_array_elements(order_by_jsonb) T\r\n    INTO order_by;\r\n\r\n    limit_ := data->>'limit';\r\n    IF (limit_ IS NULL) THEN\r\n        limit_ := 500;\r\n    END IF;\r\n    IF ((limit_ ~ '(\\D+)') AND (limit_ != 'ALL')) THEN\r\n    \t\tRAISE EXCEPTION 'The limit must be an integer number or "ALL"';\r\n    END IF;\r\n\r\n    offset_ := data->>'offset';\r\n    IF (offset_ IS NULL) THEN\r\n        offset_ := 0;\r\n    END IF;\r\n    IF (offset_ ~ '(\\D+)') THEN\r\n    \t\tRAISE EXCEPTION 'The offset must be an integer number';\r\n    END IF;\r\n\r\n    SELECT\r\n        string_agg(\r\n            format(\r\n                E'(%s)',\r\n                condition\r\n            ),\r\n            ' AND '\r\n        )\r\n        FROM (\r\n            SELECT\r\n                -- ((('"'||class||'"')::jsonb#>>'{}')::text = 'Job')\r\n                --reclada_object.get_query_condition(class, E'data->''class''') AS condition\r\n                --'class = data->>''class''' AS condition\r\n                format('obj.class = ''%s''', class) AS condition\r\n            UNION\r\n            SELECT  CASE\r\n                        WHEN jsonb_typeof(data->'id') = 'array' THEN\r\n                        (\r\n                            SELECT string_agg\r\n                                (\r\n                                    format(\r\n                                        E'(%s)',\r\n                                        reclada_object.get_query_condition(cond, E'data->''id''')\r\n                                    ),\r\n                                    ' AND '\r\n                                )\r\n                                FROM jsonb_array_elements(data->'id') AS cond\r\n                        )\r\n                        ELSE reclada_object.get_query_condition(data->'id', E'data->''id''')\r\n                    END AS condition\r\n                WHERE coalesce(data->'id','null'::jsonb) != 'null'::jsonb\r\n            -- UNION\r\n            -- SELECT 'obj.data->>''status''=''active'''-- TODO: change working with revision\r\n            -- UNION SELECT\r\n            --     CASE WHEN data->'revision' IS NULL THEN\r\n            --         E'(data->>''revision''):: numeric = (SELECT max((objrev.data -> ''revision'')::numeric)\r\n            --         FROM reclada.v_object objrev WHERE\r\n            --         objrev.data -> ''id'' = obj.data -> ''id'')'\r\n            --     WHEN jsonb_typeof(data->'revision') = 'array' THEN\r\n            --         (SELECT string_agg(\r\n            --             format(\r\n            --                 E'(%s)',\r\n            --                 reclada_object.get_query_condition(cond, E'data->''revision''')\r\n            --             ),\r\n            --             ' AND '\r\n            --         )\r\n            --         FROM jsonb_array_elements(data->'revision') AS cond)\r\n            --     ELSE reclada_object.get_query_condition(data->'revision', E'data->''revision''') END AS condition\r\n            UNION\r\n            SELECT\r\n                CASE\r\n                    WHEN jsonb_typeof(value) = 'array'\r\n                        THEN\r\n                            (\r\n                                SELECT string_agg\r\n                                    (\r\n                                        format\r\n                                        (\r\n                                            E'(%s)',\r\n                                            reclada_object.get_query_condition(cond, format(E'data->''attributes''->%L', key))\r\n                                        ),\r\n                                        ' AND '\r\n                                    )\r\n                                    FROM jsonb_array_elements(value) AS cond\r\n                            )\r\n                    ELSE reclada_object.get_query_condition(value, format(E'data->''attributes''->%L', key))\r\n                END AS condition\r\n            FROM jsonb_each(attrs)\r\n            WHERE data->'attributes' != ('{}'::jsonb)\r\n        ) conds\r\n    INTO query_conditions;\r\n\r\n    -- RAISE NOTICE 'conds: %', '\r\n    --             SELECT obj.data\r\n    --             FROM reclada.v_object obj\r\n    --             WHERE ' || query_conditions ||\r\n    --             ' ORDER BY ' || order_by ||\r\n    --             ' OFFSET ' || offset_ || ' LIMIT ' || limit_ ;\r\n    query := 'FROM reclada.v_active_object obj WHERE ' || query_conditions;\r\n    raise notice 'query: %', query;\r\n    EXECUTE E'SELECT to_jsonb(array_agg(T.data))\r\n        FROM (\r\n            SELECT obj.data\r\n            '\r\n            || query\r\n            ||\r\n            ' ORDER BY ' || order_by ||\r\n            ' OFFSET ' || offset_ || ' LIMIT ' || limit_ || ') T'\r\n    INTO objects;\r\n    IF with_number THEN\r\n\r\n        EXECUTE E'SELECT count(1)\r\n        '|| query\r\n        INTO number_of_objects;\r\n\r\n        res := jsonb_build_object(\r\n        'number', number_of_objects,\r\n        'objects', objects);\r\n    ELSE\r\n        res := objects;\r\n    END IF;\r\n\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;	2021-09-14 11:52:47.654927+00
17	16	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 16 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/reclada_object.create.sql'\n\n\nCREATE UNIQUE INDEX unique_guid_revision \n    ON reclada.object((attributes->>'revision'),obj_id);\n\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nDROP function IF EXISTS reclada_object.create ;\nCREATE OR REPLACE FUNCTION reclada_object."create"(data_jsonb jsonb, user_info jsonb DEFAULT '{}'::jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    branch     uuid;\r\n    data       jsonb;\r\n    class      text;\r\n    attrs      jsonb;\r\n    schema     jsonb;\r\n    res        jsonb;\r\n\r\nBEGIN\r\n\r\n    IF (jsonb_typeof(data_jsonb) != 'array') THEN\r\n        data_jsonb := '[]'::jsonb || data_jsonb;\r\n    END IF;\r\n    /*TODO: check if some objects have revision and others do not */\r\n    branch:= data_jsonb->0->'branch';\r\n    create temp table IF NOT EXISTS tmp(id uuid)\r\n    ON COMMIT drop;\r\n    delete from tmp;\r\n    FOR data IN SELECT jsonb_array_elements(data_jsonb) \r\n    LOOP\r\n\r\n        class := data->>'class';\r\n        IF (class IS NULL) THEN\r\n            RAISE EXCEPTION 'The reclada object class is not specified';\r\n        END IF;\r\n\r\n        attrs := data->'attributes';\r\n        IF (attrs IS NULL) THEN\r\n            RAISE EXCEPTION 'The reclada object must have attributes';\r\n        END IF;\r\n\r\n        SELECT reclada_object.get_schema(class) \r\n            INTO schema;\r\n\r\n        IF (schema IS NULL) THEN\r\n            RAISE EXCEPTION 'No json schema available for %', class;\r\n        END IF;\r\n\r\n        IF (NOT(validate_json_schema(schema->'attributes'->'schema', attrs))) THEN\r\n            RAISE EXCEPTION 'JSON invalid: %', attrs;\r\n        END IF;\r\n\r\n        with inserted as \r\n        (\r\n            INSERT INTO reclada.object(class,attributes)\r\n                select class, attrs\r\n                    RETURNING obj_id\r\n        ) \r\n        insert into tmp(id)\r\n            select obj_id \r\n                from inserted;\r\n\r\n    END LOOP;\r\n\r\n    res := array_to_json\r\n            (\r\n                array\r\n                (\r\n                    select o.data \r\n                        from reclada.v_active_object o\r\n                        join tmp t\r\n                            on t.id = o.obj_id\r\n                )\r\n            )::jsonb; \r\n    PERFORM reclada_notification.send_object_notification\r\n        (\r\n            'create',\r\n            res\r\n        );\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\n\ndrop index unique_guid_revision;	2021-09-14 11:52:50.795745+00
18	17	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 17 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n\n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\nDROP TABLE IF EXISTS reclada.staging;\ni 'function/reclada.load_staging.sql'\ni 'view/reclada.staging.sql'\ni 'trigger/load_staging.sql'\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\n\nSELECT public.raise_notice('Downscript is not supported');	2021-09-14 11:52:53.80704+00
19	18	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 18 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\nSELECT reclada_object.create_subclass('{\n    "class": "RecladaObject",\n    "attributes": {\n        "newClass": "revision",\n        "properties": {\n            "num": {"type": "number"},\n            "user": {"type": "string"},\n            "branch": {"type": "string"},\n            "dateTime": {"type": "string"}  \n        },\n        "required": ["dateTime"]\n    }\n}'::jsonb);\n\n\nalter table reclada.object\n    add column class_guid uuid;\n\n\nupdate reclada.object o\n    set class_guid = c.obj_id\n        from v_class c\n            where c.for_class = o.class;\n\ndrop VIEW reclada.v_class;\ndrop VIEW reclada.v_revision;\ndrop VIEW reclada.v_active_object;\ndrop VIEW reclada.v_object;\ndrop VIEW reclada.v_object_status;\ndrop VIEW reclada.v_user;\nalter table reclada.object\n    drop column class;\n\nalter table reclada.object\n    add column class uuid;\n\nupdate reclada.object o\n    set class = c.class_guid\n        from reclada.object c\n            where c.id = o.id;\n\nalter table reclada.object\n    drop column class_guid;\n\ncreate index class_index \n    ON reclada.object(class);\n\ni 'function/public.try_cast_uuid.sql'\ni 'function/reclada_object.get_jsonschema_GUID.sql'\ni 'view/reclada.v_class_lite.sql'\ni 'function/reclada_object.get_GUID_for_class.sql'\n\ndelete \n--select *\n    from reclada.v_class_lite c\n    where c.id = \n        (\n            SELECT min(id) min_id\n                FROM reclada.v_class_lite\n                GROUP BY for_class\n                HAVING count(*)>1\n        );\n\nselect public.raise_exception('find more then 1 version for some class')\n    where exists(\n        select for_class\n            from reclada.v_class_lite\n            GROUP BY for_class\n            HAVING count(*)>1\n    );\n\nUPDATE reclada.object o\n    set attributes = c.attributes || '{"version":1}'::jsonb\n        from v_class_lite c\n            where c.id = o.id;\n\ni 'view/reclada.v_object_status.sql'\ni 'view/reclada.v_user.sql'\ni 'view/reclada.v_object.sql'\ni 'view/reclada.v_active_object.sql'\ni 'view/reclada.v_revision.sql'\ni 'view/reclada.v_class.sql'\n\ni 'function/reclada_object.get_schema.sql'\ni 'function/reclada_object.create.sql'\ni 'function/reclada_object.update.sql'\ni 'function/reclada_object.list.sql'\ni 'function/reclada.datasource_insert_trigger_fnc.sql'\ni 'function/reclada_notification.send_object_notification.sql'\ni 'function/reclada_revision.create.sql'\n\n\n\n\n-- проверить, что вернет reclada_object.get_GUID_for_class если есть несколько классов\n\n-- SELECT * FROM reclada.object where class is null;\n\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect public.raise_exception('Downgrade script not support');	2021-09-14 11:52:57.242728+00
20	19	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 19 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\nalter table reclada.object\n    add column GUID uuid;\n\nupdate reclada.object o\n    set GUID = c.obj_id\n        from reclada.object c\n            where c.id = o.id;\n\n\ndrop VIEW reclada.v_class;\ndrop VIEW reclada.v_revision;\ndrop VIEW reclada.v_active_object;\ndrop VIEW reclada.v_object;\ndrop VIEW reclada.v_class_lite;\ndrop VIEW reclada.v_object_status;\ndrop VIEW reclada.v_user;\nalter table reclada.object\n    drop column obj_id;\n\ncreate index GUID_index \n    ON reclada.object(GUID);\n\n-- delete from reclada.object where class is null;\nalter table reclada.object \n    alter column class set not null;\n\ni 'function/reclada_object.get_jsonschema_GUID.sql'\ni 'view/reclada.v_class_lite.sql'\ni 'view/reclada.v_object_status.sql'\ni 'view/reclada.v_user.sql'\ni 'view/reclada.v_object.sql'\ni 'view/reclada.v_active_object.sql'\ni 'view/reclada.v_class.sql'\ni 'view/reclada.v_revision.sql'\ni 'function/reclada.datasource_insert_trigger_fnc.sql'\ni 'function/reclada_object.update.sql'\ni 'function/reclada_object.create.sql'\ni 'function/reclada_object.delete.sql'\ni 'function/reclada_object.list.sql'\n\ni 'function/reclada_object.list_add.sql'\ni 'function/reclada_object.list_drop.sql'\ni 'function/reclada_object.list_related.sql'\n\ni 'function/api.reclada_object_delete.sql'\ni 'function/api.reclada_object_list_add.sql'\ni 'function/api.reclada_object_list_drop.sql'\ni 'function/api.reclada_object_list_related.sql'\ni 'function/api.reclada_object_update.sql'\ni 'function/reclada_revision.create.sql'\ni 'function/reclada_notification.send_object_notification.sql'\n\n\n\n\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect public.raise_exception('Downgrade script not support');	2021-09-14 11:53:05.035396+00
21	20	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 20 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\nDROP VIEW IF EXISTS reclada.v_class;\nDROP VIEW IF EXISTS reclada.v_revision;\nDROP VIEW IF EXISTS reclada.v_active_object;\nDROP VIEW IF EXISTS reclada.v_object;\n\ni 'view/reclada.v_object.sql'\ni 'view/reclada.v_active_object.sql'\ni 'view/reclada.v_class.sql'\ni 'view/reclada.v_revision.sql'\ni 'function/reclada_object.create.sql'\ni 'function/reclada_object.list.sql'\ni 'function/reclada_object.list_related.sql'\n\ni 'function/api.storage_generate_presigned_get.sql'\ni 'function/api.storage_generate_presigned_post.sql'\ni 'function/api.reclada_object_list_drop.sql'\ni 'function/api.reclada_object_list_related.sql'\n\n\n\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect public.raise_exception('Downgrade script not support');	2021-09-14 11:53:12.917099+00
22	21	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect public.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 21 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\n\ni 'function/reclada_object.create_subclass.sql'\ni 'function/reclada_object.list_related.sql'\ni 'function/api.storage_generate_presigned_post.sql'\n\nupdate v_class_lite\n\tset attributes = attributes || '{"version":1}'\n\t\twhere attributes->>'version' is null;\n\n\n\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect public.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nselect public.raise_exception('Downgrade script not support');	2021-09-14 11:53:25.207213+00
\.


--
-- Data for Name: auth_setting; Type: TABLE DATA; Schema: reclada; Owner: reclada
--

COPY reclada.auth_setting (oidc_url, oidc_client_id, oidc_redirect_url, jwk) FROM stdin;
\.


--
-- Data for Name: object; Type: TABLE DATA; Schema: reclada; Owner: reclada
--

COPY reclada.object (id, status, attributes, transaction_id, created_time, created_by, class, guid) FROM stdin;
45	c073261b-9319-49a9-bd9b-6f9327f92a44	{"attrs": ["status", "type"], "class": "Task", "event": "create", "channelName": "task_created"}	\N	2021-09-14 11:53:22.11083+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	cb4944ac-2ab7-4723-b7fd-5b9f67304122	f813a108-517b-4eea-8667-5c6b9505c527
46	c073261b-9319-49a9-bd9b-6f9327f92a44	{"attrs": ["status", "type"], "class": "Task", "event": "update", "channelName": "task_updated"}	\N	2021-09-14 11:53:22.11083+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	cb4944ac-2ab7-4723-b7fd-5b9f67304122	90c77502-9e97-462b-b687-de34035f0984
43	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["dateTime"], "properties": {"num": {"type": "number"}, "tags": {"type": "array", "items": {"type": "string"}}, "user": {"type": "string"}, "branch": {"type": "string"}, "dateTime": {"type": "string"}}}, "version": 1, "forClass": "revision"}	\N	2021-09-14 11:52:57.242728+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	327e0c1f-fb80-4212-85de-7de535ba9ba7
47	c073261b-9319-49a9-bd9b-6f9327f92a44	{"attrs": ["type"], "class": "Task", "event": "delete", "channelName": "task_deleted"}	\N	2021-09-14 11:53:22.11083+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	cb4944ac-2ab7-4723-b7fd-5b9f67304122	d77eabe6-185a-40bf-850c-9d93531d4c67
52	c073261b-9319-49a9-bd9b-6f9327f92a44	{"attrs": ["status", "type"], "class": "Job", "event": "create", "channelName": "job_created"}	\N	2021-09-14 11:53:22.943241+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	cb4944ac-2ab7-4723-b7fd-5b9f67304122	8faa32db-46eb-4222-a58a-36b8aff53dcb
53	c073261b-9319-49a9-bd9b-6f9327f92a44	{"attrs": ["status", "type"], "class": "Job", "event": "update", "channelName": "job_updated"}	\N	2021-09-14 11:53:22.943241+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	cb4944ac-2ab7-4723-b7fd-5b9f67304122	8d385945-2035-4695-9547-24ea70b99d03
54	c073261b-9319-49a9-bd9b-6f9327f92a44	{"attrs": ["type"], "class": "Job", "event": "delete", "channelName": "job_deleted"}	\N	2021-09-14 11:53:22.943241+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	cb4944ac-2ab7-4723-b7fd-5b9f67304122	a93fee39-166d-40a3-984c-41d0b3d8519c
58	c073261b-9319-49a9-bd9b-6f9327f92a44	{"task": "512a3dde-23c7-4771-b180-20f8781ac084", "type": "K8S", "status": "down", "command": "", "environment": "7b196912-d973-40a9-b0e2-15ecbd921b2f"}	\N	2021-09-14 11:53:23.617303+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	41f1b7b5-be68-4a06-b073-a6d34843463e	d65bd590-ee08-4a39-a7fd-f29527faec9e
61	c073261b-9319-49a9-bd9b-6f9327f92a44	{"mimeType": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "extension": ".xlsx"}	\N	2021-09-14 11:53:24.108629+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	4261d98b-7d73-4f65-84cf-fb28b22a7eff	aec46ec6-b1cf-4697-b7f5-58e63fd30fd9
60	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["extension", "mimeType"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "mimeType": {"type": "string"}, "extension": {"type": "string"}}}, "version": 1, "forClass": "FileExtension"}	\N	2021-09-14 11:53:23.940606+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	4261d98b-7d73-4f65-84cf-fb28b22a7eff
62	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["command", "name", "type", "environment"], "properties": {"name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "type": {"type": "string"}, "command": {"type": "string"}, "environment": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "inputParameters": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "outputParameters": {"type": "array", "items": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}}, "connectionDetails": {"type": "string"}}}, "version": 1, "forClass": "Connector"}	\N	2021-09-14 11:53:24.281592+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	bdd3d868-effb-48ed-b40f-eb574cbc7caa
44	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["command", "type"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "type": {"type": "string"}, "command": {"type": "string"}, "inputParameters": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "outputParameters": {"type": "array", "items": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}}}}, "version": 1, "forClass": "Task"}	\N	2021-09-14 11:53:21.947166+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	a5600f4c-fa08-43b5-bf27-a274b7cd9fcf
48	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["name", "type"], "properties": {"file": {"type": "string"}, "name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "type": {"enum": ["code", "stdout", "stderr", "file"], "type": "string"}}}, "version": 1, "forClass": "Parameter"}	\N	2021-09-14 11:53:22.297332+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	bcf73673-c95b-4d43-ba8e-8937ea9993d5
49	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["nextTask", "previousJobCode"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "nextTask": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "previousJobCode": {"type": "integer"}, "paramsRelationships": {"type": "array", "items": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}}}}, "version": 1, "forClass": "Trigger"}	\N	2021-09-14 11:53:22.456866+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	3fadda5c-0c33-4d07-a10a-d5ac1011d240
50	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["command", "triggers", "type"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "type": {"type": "string"}, "command": {"type": "string"}, "triggers": {"type": "array", "items": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}}, "inputParameters": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "outputParameters": {"type": "array", "items": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}}}}, "version": 1, "forClass": "Pipeline"}	\N	2021-09-14 11:53:22.622704+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	7549034b-8688-41a7-b911-3610dbed096f
51	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["command", "status", "type", "task"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "task": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "type": {"type": "string"}, "runner": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "status": {"type": "string", "enum ": ["new", "pending", "running", "failed", "success"]}, "command": {"type": "string"}, "inputParameters": {"type": "array", "items": {"type": "object"}}, "outputParameters": {"type": "array", "items": {"type": "object"}}}}, "version": 1, "forClass": "Job"}	\N	2021-09-14 11:53:22.778432+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	96793015-f0a4-42f8-9f96-8a2ce3c4bbd0
55	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["subject", "type", "object"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "type": {"type": "string", "enum ": ["params"]}, "object": {"type": "string"}, "subject": {"type": "string"}}}, "version": 1, "forClass": "Relationship"}	\N	2021-09-14 11:53:23.133639+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	225b4add-96d2-4610-b49b-e77fcb6566a7
56	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["name"], "properties": {"name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "value": {"type": "string"}}}, "version": 1, "forClass": "Value"}	\N	2021-09-14 11:53:23.293474+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	d2ef7106-7328-46bc-974a-621ad69cbcf9
36	c073261b-9319-49a9-bd9b-6f9327f92a44	{"caption": "active", "revision": "407496be-062c-49a7-84fe-a1b4a820f047"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	e097176a-e526-4bbd-8a01-c0ea31cb1e80	c073261b-9319-49a9-bd9b-6f9327f92a44
38	c073261b-9319-49a9-bd9b-6f9327f92a44	{"caption": "archive", "revision": "d6964d16-6775-4817-ae9c-f6a6b98d4fbd"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	e097176a-e526-4bbd-8a01-c0ea31cb1e80	04afdbd2-d641-42ef-832e-ff00e1db8d88
33	c073261b-9319-49a9-bd9b-6f9327f92a44	{"num": 1, "user": "", "branch": "", "old_num": 17, "dateTime": "2021-09-14 11:51:56.618874+00"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	327e0c1f-fb80-4212-85de-7de535ba9ba7	ed671059-ad02-489c-92d5-ec7676ace6c4
21	c073261b-9319-49a9-bd9b-6f9327f92a44	{"num": 1, "user": "", "branch": "", "old_num": 11, "dateTime": "2021-09-14 11:51:30.81554+00"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	327e0c1f-fb80-4212-85de-7de535ba9ba7	24015eb8-cc6b-40bb-add9-3c66567172b2
25	c073261b-9319-49a9-bd9b-6f9327f92a44	{"num": 1, "user": "", "branch": "", "old_num": 13, "dateTime": "2021-09-14 11:51:31.069468+00"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	327e0c1f-fb80-4212-85de-7de535ba9ba7	1a1b8b8b-ce1a-4ee6-a0a8-986ef75dd82f
27	c073261b-9319-49a9-bd9b-6f9327f92a44	{"num": 1, "user": "", "branch": "", "old_num": 14, "dateTime": "2021-09-14 11:51:31.198495+00"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	327e0c1f-fb80-4212-85de-7de535ba9ba7	5c2686f9-fa64-49cb-8083-889406a777e1
29	c073261b-9319-49a9-bd9b-6f9327f92a44	{"num": 1, "user": "", "branch": "", "old_num": 15, "dateTime": "2021-09-14 11:51:31.319288+00"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	327e0c1f-fb80-4212-85de-7de535ba9ba7	9102ccda-b695-4c8a-be8a-7affed9998d7
31	c073261b-9319-49a9-bd9b-6f9327f92a44	{"num": 1, "user": "", "branch": "", "old_num": 16, "dateTime": "2021-09-14 11:51:32.061294+00"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	327e0c1f-fb80-4212-85de-7de535ba9ba7	b3df2934-5d6e-4ec1-a52d-a4031513e769
37	c073261b-9319-49a9-bd9b-6f9327f92a44	{"num": 1, "user": "", "branch": "", "old_num": 19, "dateTime": "2021-09-14 11:51:56.618874+00"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	327e0c1f-fb80-4212-85de-7de535ba9ba7	d6964d16-6775-4817-ae9c-f6a6b98d4fbd
39	c073261b-9319-49a9-bd9b-6f9327f92a44	{"num": 1, "user": "", "branch": "", "old_num": 20, "dateTime": "2021-09-14 11:51:56.618874+00"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	327e0c1f-fb80-4212-85de-7de535ba9ba7	cb8414ac-f0bd-49a6-8200-d737327b1df0
41	c073261b-9319-49a9-bd9b-6f9327f92a44	{"num": 1, "user": "", "branch": "", "old_num": 21, "dateTime": "2021-09-14 11:51:56.618874+00"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	327e0c1f-fb80-4212-85de-7de535ba9ba7	54f0b0cc-09f3-40fd-a56e-fcf2d9e5698f
40	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["login"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "login": {"type": "string"}}}, "version": 1, "forClass": "User", "revision": "cb8414ac-f0bd-49a6-8200-d737327b1df0"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	dd22c1b8-dd61-446e-a2e8-bc414a72ef64
57	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["command", "status", "type", "task", "environment"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "task": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "type": {"type": "string"}, "runner": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "status": {"type": "string", "enum ": ["up", "down", "idle"]}, "command": {"type": "string"}, "environment": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "inputParameters": {"type": "array", "items": {"type": "object"}}, "outputParameters": {"type": "array", "items": {"type": "object"}}}}, "version": 1, "forClass": "Runner"}	\N	2021-09-14 11:53:23.4593+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	41f1b7b5-be68-4a06-b073-a6d34843463e
59	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["name"], "properties": {"name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "description": {"type": "string"}}}, "version": 1, "forClass": "Environment"}	\N	2021-09-14 11:53:23.772697+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	5f703898-a8aa-44f4-b4f1-d2d14ca8a77d
20	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["name"], "properties": {"name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}}}, "version": 1, "forClass": "Document", "revision": "7512273e-1467-4aff-88e6-93f91606fb9b"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	ec112ee7-d03d-4341-9c30-3d266ecc2b4d
22	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["number", "bbox", "document"], "properties": {"bbox": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "number": {"type": "number"}, "document": {"type": "string"}}}, "version": 1, "forClass": "Page", "revision": "24015eb8-cc6b-40bb-add9-3c66567172b2"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	a03171ff-7b01-4376-b4b2-6292fb913551
24	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["top", "left", "height", "width"], "properties": {"top": {"type": "number"}, "left": {"type": "number"}, "tags": {"type": "array", "items": {"type": "string"}}, "width": {"type": "number"}, "height": {"type": "number"}}}, "version": 1, "forClass": "BBox", "revision": "277acac0-1429-4d8b-9c8e-652c49df9851"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	ea571767-2dfb-4fac-b7c3-a370ac1454e0
10	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["checksum", "name", "mimeType"], "properties": {"uri": {"type": "string"}, "name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "checksum": {"type": "string"}, "mimeType": {"type": "string"}}}, "version": 1, "forClass": "File", "revision": "ca99bb25-045f-4997-9eb0-0ae6a2a49d17"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	b7cf42ae-b614-4d57-b58c-061b3c2b584d
34	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["caption"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "caption": {"type": "string"}}}, "version": 1, "forClass": "ObjectStatus", "revision": "ed671059-ad02-489c-92d5-ec7676ace6c4"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	e097176a-e526-4bbd-8a01-c0ea31cb1e80
12	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["accessKeyId", "secretAccessKey", "bucketName"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "bucketName": {"type": "string"}, "regionName": {"type": "string"}, "accessKeyId": {"type": "string"}, "endpointURL": {"type": "string"}, "secretAccessKey": {"type": "string"}}}, "version": 1, "forClass": "S3Config", "revision": "1177fed9-bd5f-47c9-871f-11ed7a497b83"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	6ef33066-e612-4214-ab16-313de13efe5d
26	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["text", "bbox", "page"], "properties": {"bbox": {"type": "string"}, "page": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "text": {"type": "string"}}}, "version": 1, "forClass": "TextBlock", "revision": "1a1b8b8b-ce1a-4ee6-a0a8-986ef75dd82f"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	c4e8e62f-17ae-4fb5-a1d1-77f2cd04c03f
28	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["bbox", "page"], "properties": {"bbox": {"type": "string"}, "page": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}}}, "version": 1, "forClass": "Table", "revision": "5c2686f9-fa64-49cb-8083-889406a777e1"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	b59df5c8-9977-4293-8c0e-ced128a130ab
30	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["colspan", "row", "text", "bbox", "table", "cellType", "rowspan", "column"], "properties": {"row": {"type": "number"}, "bbox": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "text": {"type": "string"}, "table": {"type": "string"}, "column": {"type": "number"}, "colspan": {"type": "number"}, "rowspan": {"type": "number"}, "cellType": {"type": "string"}}}, "version": 1, "forClass": "Cell", "revision": "9102ccda-b695-4c8a-be8a-7affed9998d7"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	ecef02d2-b583-458f-9954-2fe23ad12c4b
32	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["row", "table"], "properties": {"row": {"type": "number"}, "tags": {"type": "array", "items": {"type": "string"}}, "table": {"type": "string"}}}, "version": 1, "forClass": "DataRow", "revision": "b3df2934-5d6e-4ec1-a52d-a4031513e769"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	c0cc118e-3564-4617-8785-d413949057ed
14	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["name"], "properties": {"name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "dataSources": {"type": "array", "items": {"type": "string"}}}}, "version": 1, "forClass": "DataSet", "revision": "6807b202-814f-4b9f-9cb5-ad9f88e2a648"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	27cad63b-0611-4d3b-a296-1ad9a909493b
16	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["channelName", "event", "class"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "attrs": {"type": "array", "items": {"type": "string"}}, "class": {"type": "string"}, "event": {"enum": ["create", "update", "list", "delete"], "type": "string"}, "channelName": {"type": "string"}}}, "version": 1, "forClass": "Message", "revision": "f810dedd-2eee-4f72-9af1-03fa034d3d81"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	cb4944ac-2ab7-4723-b7fd-5b9f67304122
2	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["forClass", "schema"], "properties": {"schema": {"type": "object"}, "forClass": {"type": "string"}}}, "version": 1, "forClass": "jsonschema", "revision": "7e485fa4-493b-450e-8bf9-d620db894c83"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	bcff1a5f-b30d-4499-9311-6a66fe7866b8
4	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": [], "properties": {"tags": {"type": "array", "items": {"type": "string"}}}}, "version": 1, "forClass": "RecladaObject", "revision": "dd334d66-e8be-4ebc-a3a5-27f8b6c66276"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	49db8720-d548-4271-876c-f6a8cb1ad96e
6	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["name"], "properties": {"name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}}}, "version": 1, "forClass": "tag", "revision": "1e56d65a-ea99-4ca9-9431-20f137ba9191"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	74048251-f13d-49ef-9cfa-222e267c2e12
8	c073261b-9319-49a9-bd9b-6f9327f92a44	{"schema": {"type": "object", "required": ["name"], "properties": {"uri": {"type": "string"}, "name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}}}, "version": 1, "forClass": "DataSource", "revision": "1b36d956-a9f2-470b-9392-66b1371bcb78"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	bcff1a5f-b30d-4499-9311-6a66fe7866b8	ae8713d6-c64f-4067-9fa8-586581c784f0
35	c073261b-9319-49a9-bd9b-6f9327f92a44	{"num": 1, "user": "", "branch": "", "old_num": 18, "dateTime": "2021-09-14 11:51:56.618874+00"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	327e0c1f-fb80-4212-85de-7de535ba9ba7	407496be-062c-49a7-84fe-a1b4a820f047
7	c073261b-9319-49a9-bd9b-6f9327f92a44	{"num": 1, "user": "", "branch": "", "old_num": 4, "dateTime": "2021-09-14 11:51:27.807895+00"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	327e0c1f-fb80-4212-85de-7de535ba9ba7	1b36d956-a9f2-470b-9392-66b1371bcb78
1	c073261b-9319-49a9-bd9b-6f9327f92a44	{"num": 1, "user": "", "branch": "", "old_num": 1, "dateTime": "2021-09-14 11:51:27.435203+00"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	327e0c1f-fb80-4212-85de-7de535ba9ba7	7e485fa4-493b-450e-8bf9-d620db894c83
3	c073261b-9319-49a9-bd9b-6f9327f92a44	{"num": 1, "user": "", "branch": "", "old_num": 2, "dateTime": "2021-09-14 11:51:27.531455+00"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	327e0c1f-fb80-4212-85de-7de535ba9ba7	dd334d66-e8be-4ebc-a3a5-27f8b6c66276
5	c073261b-9319-49a9-bd9b-6f9327f92a44	{"num": 1, "user": "", "branch": "", "old_num": 3, "dateTime": "2021-09-14 11:51:27.670715+00"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	327e0c1f-fb80-4212-85de-7de535ba9ba7	1e56d65a-ea99-4ca9-9431-20f137ba9191
9	c073261b-9319-49a9-bd9b-6f9327f92a44	{"num": 1, "user": "", "branch": "", "old_num": 5, "dateTime": "2021-09-14 11:51:27.944389+00"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	327e0c1f-fb80-4212-85de-7de535ba9ba7	ca99bb25-045f-4997-9eb0-0ae6a2a49d17
23	c073261b-9319-49a9-bd9b-6f9327f92a44	{"num": 1, "user": "", "branch": "", "old_num": 12, "dateTime": "2021-09-14 11:51:30.939492+00"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	327e0c1f-fb80-4212-85de-7de535ba9ba7	277acac0-1429-4d8b-9c8e-652c49df9851
11	c073261b-9319-49a9-bd9b-6f9327f92a44	{"num": 1, "user": "", "branch": "", "old_num": 6, "dateTime": "2021-09-14 11:51:28.087497+00"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	327e0c1f-fb80-4212-85de-7de535ba9ba7	1177fed9-bd5f-47c9-871f-11ed7a497b83
13	c073261b-9319-49a9-bd9b-6f9327f92a44	{"num": 1, "user": "", "branch": "", "old_num": 7, "dateTime": "2021-09-14 11:51:28.220579+00"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	327e0c1f-fb80-4212-85de-7de535ba9ba7	6807b202-814f-4b9f-9cb5-ad9f88e2a648
15	c073261b-9319-49a9-bd9b-6f9327f92a44	{"num": 1, "user": "", "branch": "", "old_num": 8, "dateTime": "2021-09-14 11:51:28.355752+00"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	327e0c1f-fb80-4212-85de-7de535ba9ba7	f810dedd-2eee-4f72-9af1-03fa034d3d81
17	c073261b-9319-49a9-bd9b-6f9327f92a44	{"num": 1, "user": "", "branch": "", "old_num": 9, "dateTime": "2021-09-14 11:51:28.492984+00"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	327e0c1f-fb80-4212-85de-7de535ba9ba7	29b24cf3-24e6-4396-b85e-ecca153017b3
19	c073261b-9319-49a9-bd9b-6f9327f92a44	{"num": 1, "user": "", "branch": "", "old_num": 10, "dateTime": "2021-09-14 11:51:30.689518+00"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	327e0c1f-fb80-4212-85de-7de535ba9ba7	7512273e-1467-4aff-88e6-93f91606fb9b
42	c073261b-9319-49a9-bd9b-6f9327f92a44	{"login": "dev", "revision": "54f0b0cc-09f3-40fd-a56e-fcf2d9e5698f"}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	dd22c1b8-dd61-446e-a2e8-bc414a72ef64	5c68f57c-a103-4b89-ae52-fb49b4d2b35f
18	c073261b-9319-49a9-bd9b-6f9327f92a44	{"name": "defaultDataSet", "revision": "29b24cf3-24e6-4396-b85e-ecca153017b3", "dataSources": []}	\N	2021-09-14 11:51:56.618874+00	5c68f57c-a103-4b89-ae52-fb49b4d2b35f	27cad63b-0611-4d3b-a296-1ad9a909493b	83db90e6-f3ab-4b4a-8dba-eaa8d9867768
\.


--
-- Name: t_dbg_id_seq; Type: SEQUENCE SET; Schema: dev; Owner: reclada
--

SELECT pg_catalog.setval('dev.t_dbg_id_seq', 9, true);


--
-- Name: ver_id_seq; Type: SEQUENCE SET; Schema: dev; Owner: reclada
--

SELECT pg_catalog.setval('dev.ver_id_seq', 22, true);


--
-- Name: object_id_seq; Type: SEQUENCE SET; Schema: reclada; Owner: reclada
--

SELECT pg_catalog.setval('reclada.object_id_seq', 62, true);


--
-- Name: reclada_revisions; Type: SEQUENCE SET; Schema: reclada; Owner: reclada
--

SELECT pg_catalog.setval('reclada.reclada_revisions', 21, true);


--
-- Name: object object_pkey; Type: CONSTRAINT; Schema: reclada; Owner: reclada
--

ALTER TABLE ONLY reclada.object
    ADD CONSTRAINT object_pkey PRIMARY KEY (id);


--
-- Name: class_index; Type: INDEX; Schema: reclada; Owner: reclada
--

CREATE INDEX class_index ON reclada.object USING btree (class);


--
-- Name: guid_index; Type: INDEX; Schema: reclada; Owner: reclada
--

CREATE INDEX guid_index ON reclada.object USING btree (guid);


--
-- Name: status_index; Type: INDEX; Schema: reclada; Owner: reclada
--

CREATE INDEX status_index ON reclada.object USING btree (status);


--
-- Name: object datasource_insert_trigger; Type: TRIGGER; Schema: reclada; Owner: reclada
--

CREATE TRIGGER datasource_insert_trigger BEFORE INSERT ON reclada.object FOR EACH ROW EXECUTE FUNCTION reclada.datasource_insert_trigger_fnc();


--
-- Name: staging load_staging; Type: TRIGGER; Schema: reclada; Owner: reclada
--

CREATE TRIGGER load_staging INSTEAD OF INSERT ON reclada.staging FOR EACH ROW EXECUTE FUNCTION reclada.load_staging();


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: reclada
--

REVOKE ALL ON SCHEMA public FROM rdsadmin;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO reclada;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: FUNCTION invoke(function_name aws_commons._lambda_function_arn_1, payload json, invocation_type text, log_type text, context json, qualifier character varying, OUT status_code integer, OUT payload json, OUT executed_version text, OUT log_result text); Type: ACL; Schema: aws_lambda; Owner: rds_superuser
--

REVOKE ALL ON FUNCTION aws_lambda.invoke(function_name aws_commons._lambda_function_arn_1, payload json, invocation_type text, log_type text, context json, qualifier character varying, OUT status_code integer, OUT payload json, OUT executed_version text, OUT log_result text) FROM rdsadmin;
GRANT ALL ON FUNCTION aws_lambda.invoke(function_name aws_commons._lambda_function_arn_1, payload json, invocation_type text, log_type text, context json, qualifier character varying, OUT status_code integer, OUT payload json, OUT executed_version text, OUT log_result text) TO rds_superuser;


--
-- Name: FUNCTION invoke(function_name aws_commons._lambda_function_arn_1, payload jsonb, invocation_type text, log_type text, context jsonb, qualifier character varying, OUT status_code integer, OUT payload jsonb, OUT executed_version text, OUT log_result text); Type: ACL; Schema: aws_lambda; Owner: rds_superuser
--

REVOKE ALL ON FUNCTION aws_lambda.invoke(function_name aws_commons._lambda_function_arn_1, payload jsonb, invocation_type text, log_type text, context jsonb, qualifier character varying, OUT status_code integer, OUT payload jsonb, OUT executed_version text, OUT log_result text) FROM rdsadmin;
GRANT ALL ON FUNCTION aws_lambda.invoke(function_name aws_commons._lambda_function_arn_1, payload jsonb, invocation_type text, log_type text, context jsonb, qualifier character varying, OUT status_code integer, OUT payload jsonb, OUT executed_version text, OUT log_result text) TO rds_superuser;


--
-- Name: FUNCTION invoke(function_name text, payload json, region text, invocation_type text, log_type text, context json, qualifier character varying, OUT status_code integer, OUT payload json, OUT executed_version text, OUT log_result text); Type: ACL; Schema: aws_lambda; Owner: rds_superuser
--

REVOKE ALL ON FUNCTION aws_lambda.invoke(function_name text, payload json, region text, invocation_type text, log_type text, context json, qualifier character varying, OUT status_code integer, OUT payload json, OUT executed_version text, OUT log_result text) FROM rdsadmin;
GRANT ALL ON FUNCTION aws_lambda.invoke(function_name text, payload json, region text, invocation_type text, log_type text, context json, qualifier character varying, OUT status_code integer, OUT payload json, OUT executed_version text, OUT log_result text) TO rds_superuser;


--
-- Name: FUNCTION invoke(function_name text, payload jsonb, region text, invocation_type text, log_type text, context jsonb, qualifier character varying, OUT status_code integer, OUT payload jsonb, OUT executed_version text, OUT log_result text); Type: ACL; Schema: aws_lambda; Owner: rds_superuser
--

REVOKE ALL ON FUNCTION aws_lambda.invoke(function_name text, payload jsonb, region text, invocation_type text, log_type text, context jsonb, qualifier character varying, OUT status_code integer, OUT payload jsonb, OUT executed_version text, OUT log_result text) FROM rdsadmin;
GRANT ALL ON FUNCTION aws_lambda.invoke(function_name text, payload jsonb, region text, invocation_type text, log_type text, context jsonb, qualifier character varying, OUT status_code integer, OUT payload jsonb, OUT executed_version text, OUT log_result text) TO rds_superuser;


--
-- PostgreSQL database dump complete
--

