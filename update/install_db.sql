-- version = 45
-- 2021-12-30 08:47:13.080031--
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
-- Name: dp_bhvr; Type: TYPE; Schema: reclada; Owner: -
--

CREATE TYPE reclada.dp_bhvr AS ENUM (
    'Replace',
    'Update',
    'Reject',
    'Copy',
    'Insert',
    'Merge'
);


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
-- Name: reclada_object_create(jsonb, text, text); Type: FUNCTION; Schema: api; Owner: -
--

CREATE FUNCTION api.reclada_object_create(data jsonb, ver text DEFAULT '1'::text, draft text DEFAULT 'false'::text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    data_jsonb       jsonb;
    class            text;
    user_info        jsonb;
    attrs            jsonb;
    data_to_create   jsonb = '[]'::jsonb;
    result           jsonb;
    _need_flat       bool := false;
    _draft           bool;
    _guid            uuid;
    _f_name          text := 'api.reclada_object_create';
BEGIN

    _draft := draft != 'false';

    IF (jsonb_typeof(data) != 'array') THEN
        data := '[]'::jsonb || data;
    END IF;

    FOR data_jsonb IN SELECT jsonb_array_elements(data) LOOP

        _guid := CASE ver
                        when '1'
                            then data_jsonb->>'GUID'
                        when '2'
                            then data_jsonb->>'{GUID}'
                    end;
        if _draft then
            if _guid is null then
                perform reclada.raise_exception('GUID is required.',_f_name);
            end if;
            INSERT into reclada.draft(guid,data)
                values(_guid,data_jsonb);
        else

             class := CASE ver
                            when '1'
                                then data_jsonb->>'class'
                            when '2'
                                then data_jsonb->>'{class}'
                        end;

            IF (class IS NULL) THEN
                RAISE EXCEPTION 'The reclada object class is not specified (api)';
            END IF;

            SELECT reclada_user.auth_by_token(data_jsonb->>'accessToken') INTO user_info;
            data_jsonb := data_jsonb - 'accessToken';

            IF (NOT(reclada_user.is_allowed(user_info, 'create', class))) THEN
                RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'create', class;
            END IF;
            
            if ver = '2' then
                _need_flat := true;
                with recursive j as 
                (
                    select  row_number() over() as id,
                            key,
                            value 
                        from jsonb_each(data_jsonb)
                            where key like '{%}'
                ),
                inn as 
                (
                    SELECT  row_number() over(order by s.id,j.id) rn,
                            j.id,
                            s.id sid,
                            s.d,
                            ARRAY (
                                SELECT UNNEST(arr.v) 
                                LIMIT array_position(arr.v, s.d)
                            ) as k
                        FROM j
                        left join lateral
                        (
                            select id, d ,max(id) over() mid
                            from
                            (
                                SELECT  row_number() over() as id, 
                                        d
                                    from regexp_split_to_table(substring(j.key,2,char_length(j.key)-2),',') d 
                            ) t
                        ) s on s.mid != s.id
                        join lateral
                        (
                            select regexp_split_to_array(substring(j.key,2,char_length(j.key)-2),',') v
                        ) arr on true
                            where d is not null
                ),
                src as
                (
                    select  reclada.jsonb_deep_set('{}'::jsonb,('{'|| i.d ||'}')::text[],'{}'::jsonb) r,
                            i.rn
                        from inn i
                            where i.rn = 1
                    union
                    select  reclada.jsonb_deep_set(
                                s.r,
                                i.k,
                                '{}'::jsonb
                            ) r,
                            i.rn
                        from src s
                        join inn i
                            on s.rn + 1 = i.rn
                ),
                tmpl as 
                (
                    select r v
                        from src
                        ORDER BY rn DESC
                        limit 1
                ),
                res as
                (
                    SELECT jsonb_set(
                            (select v from tmpl),
                            j.key::text[],
                            j.value
                        ) v,
                        j.id
                        FROM j
                            where j.id = 1
                    union 
                    select jsonb_set(
                            res.v,
                            j.key::text[],
                            j.value
                        ) v,
                        j.id
                        FROM res
                        join j
                            on res.id + 1 =j.id
                )
                SELECT v 
                    FROM res
                    ORDER BY ID DESC
                    limit 1
                    into data_jsonb;
            end if;

            if data_jsonb is null then
                RAISE EXCEPTION 'JSON invalid';
            end if;
            data_to_create := data_to_create || data_jsonb;
        end if;
    END LOOP;

    if data_to_create is not  null then
        SELECT reclada_object.create(data_to_create, user_info) 
            INTO result;
    end if;
    if ver = '2' or _draft then
        RETURN '{"status":"OK"}'::jsonb;
    end if;
    RETURN result;

END;
$$;


--
-- Name: reclada_object_delete(jsonb, text, text); Type: FUNCTION; Schema: api; Owner: -
--

CREATE FUNCTION api.reclada_object_delete(data jsonb, ver text DEFAULT '1'::text, draft text DEFAULT 'false'::text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    class         text;
    obj_id        uuid;
    user_info     jsonb;
    result        jsonb;

BEGIN

    obj_id := CASE ver
                when '1'
                    then data->>'GUID'
                when '2'
                    then data->>'{GUID}'
            end;
    IF (obj_id IS NULL) THEN
        RAISE EXCEPTION 'Could not delete object with no id';
    END IF;

    if draft != 'false' then
        delete from reclada.draft 
            where guid = obj_id;
        
    else

        class := CASE ver
                        when '1'
                            then data->>'class'
                        when '2'
                            then data->>'{class}'
                    end;
        IF (class IS NULL) THEN
            RAISE EXCEPTION 'reclada object class not specified';
        END IF;

        data := data || ('{"GUID":"'|| obj_id ||'","class":"'|| class ||'"}')::jsonb;

        SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
        data := data - 'accessToken';

        IF (NOT(reclada_user.is_allowed(user_info, 'delete', class))) THEN
            RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'delete', class;
        END IF;

        SELECT reclada_object.delete(data, user_info) INTO result;

    end if;

    if ver = '2' or draft != 'false' then 
        RETURN '{"status":"OK"}'::jsonb;
    end if;

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
-- Name: reclada_object_list(jsonb, text, text); Type: FUNCTION; Schema: api; Owner: -
--

CREATE FUNCTION api.reclada_object_list(data jsonb DEFAULT NULL::jsonb, ver text DEFAULT '1'::text, draft text DEFAULT 'false'::text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    _class              text;
    user_info           jsonb;
    result              jsonb;
    _filter             jsonb;
    _guid               uuid;
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

    _class := CASE ver
                when '1'
                    then data->>'class'
                when '2'
                    then data->>'{class}'
            end;
    IF(_class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    _guid := CASE ver
        when '1'
            then data->>'GUID'
        when '2'
            then data->>'{GUID}'
    end;

    _filter = data->'filter';

    if _guid is not null then
        SELECT format(  '{
                            "operator":"AND",
                            "value":[
                                {
                                    "operator":"=",
                                    "value":["{class}","%s"]
                                },
                                {
                                    "operator":"=",
                                    "value":["{GUID}","%s"]
                                }
                            ]
                        }',
                    _class,
                    _guid
                )::jsonb 
            INTO _filter;

    ELSEIF _filter IS NOT NULL THEN
        SELECT format(  '{
                            "operator":"AND",
                            "value":[
                                {
                                    "operator":"=",
                                    "value":["{class}","%s"]
                                },
                                %s
                            ]
                        }',
                _class,
                _filter
            )::jsonb 
            INTO _filter;
    ELSEIF ver = '2' then
        SELECT format( '{
                            "operator":"=",
                            "value":["{class}","%s"]
                        }',
                _class
            )::jsonb 
            INTO _filter;
    END IF;
    
    data := Jsonb_set(data,'{filter}', _filter);

    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
    data := data - 'accessToken';

    IF (NOT(reclada_user.is_allowed(user_info, 'list', _class))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'list', _class;
    END IF;

    SELECT reclada_object.list(data, true, ver) 
        INTO result;
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
		RAISE EXCEPTION 'There is no GUID';
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
-- Name: reclada_object_update(jsonb, text); Type: FUNCTION; Schema: api; Owner: -
--

CREATE FUNCTION api.reclada_object_update(data jsonb, ver text DEFAULT '1'::text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    class         text;
    objid         uuid;
    attrs         jsonb;
    user_info     jsonb;
    result        jsonb;
    _need_flat    bool := false;

BEGIN

    class := CASE ver
            when '1'
                then data->>'class'
            when '2'
                then data->>'{class}'
        end;

    IF (class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    objid := CASE ver
            when '1'
                then data->>'GUID'
            when '2'
                then data->>'{GUID}'
        end;
    IF (objid IS NULL) THEN
        RAISE EXCEPTION 'Could not update object with no GUID';
    END IF;
    
    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
    data := data - 'accessToken';

    IF (NOT(reclada_user.is_allowed(user_info, 'update', class))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'update', class;
    END IF;

    if ver = '2' then

        with recursive j as 
        (
            select  row_number() over() as id,
                    key,
                    value 
                from jsonb_each(data)
                    where key like '{%}'
        ),
        t as
        (
            select  j.id    , 
                    j.key   , 
                    j.value , 
                    o.data
                from reclada.v_object o
                join j
                    on true
                    where o.obj_id = 
                        (
                            select (j.value#>>'{}')::uuid 
                                from j where j.key = '{GUID}'
                        )
        ),
        r as 
        (
            select id,key,value,jsonb_set(t.data,t.key::text[],t.value) as u, t.data
                from t
                    where id = 1
            union
            select t.id,t.key,t.value,jsonb_set(r.u   ,t.key::text[],t.value) as u, t.data
                from r
                JOIN t
                    on t.id-1 = r.id
        )
        select r.u
            from r
                where id = (select max(j.id) from j)
            INTO data;
    end if;
    -- raise notice '%', data#>>'{}';
    SELECT reclada_object.update(data, user_info) INTO result;

    if ver = '2' then
        RETURN '{"status":"OK"}'::jsonb;
    end if;
    return result;
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
    context      jsonb;

BEGIN
    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
    data := data - 'accessToken';

    IF (NOT(reclada_user.is_allowed(user_info, 'generate presigned get', ''))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned get';
    END IF;

    -- TODO: check user's permissions for reclada object access?
    object_id := data->>'objectId';
    SELECT reclada_object.list(format(
        '{"class": "File", "attributes": {}, "GUID": "%s"}',
        object_id
    )::jsonb) -> 0 INTO object_data;

    IF (object_data IS NULL) THEN
		RAISE EXCEPTION 'There is no object with such id';
	END IF;

    SELECT attrs
    FROM reclada.v_active_object
    WHERE class_name = 'Context'
    ORDER BY id DESC
    LIMIT 1
    INTO context;

    SELECT payload
    FROM aws_lambda.invoke(
        aws_commons.create_lambda_function_arn(
            context->>'Lambda',
            context->>'Region'
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
    user_info    jsonb;
    object_name  varchar;
    file_type    varchar;
    file_size    varchar;
    context      jsonb;
    bucket_name  varchar;
    url          varchar;
    result       jsonb;

BEGIN
    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
    data := data - 'accessToken';

    IF (NOT(reclada_user.is_allowed(user_info, 'generate presigned post', ''))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';
    END IF;

    object_name := data->>'objectName';
    file_type := data->>'fileType';
    file_size := data->>'fileSize';

    IF (object_name IS NULL) OR (file_type IS NULL) OR (file_size IS NULL) THEN
        RAISE EXCEPTION 'Parameters objectName, fileType and fileSize must be present';
    END IF;

    SELECT attrs
    FROM reclada.v_active_object
    WHERE class_name = 'Context'
    ORDER BY id DESC
    LIMIT 1
    INTO context;

    bucket_name := data->>'bucketName';

    SELECT payload::jsonb
    FROM aws_lambda.invoke(
        aws_commons.create_lambda_function_arn(
                context->>'Lambda',
                context->>'Region'
        ),
        format('{
            "type": "post",
            "fileName": "%s",
            "fileType": "%s",
            "fileSize": "%s",
            "bucketName": "%s",
            "expiration": 3600}',
            object_name,
            file_type,
            file_size,
            bucket_name
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
-- Name: get_children(uuid); Type: FUNCTION; Schema: reclada; Owner: -
--

CREATE FUNCTION reclada.get_children(_obj_id uuid) RETURNS SETOF uuid
    LANGUAGE sql STABLE
    AS $$
    WITH RECURSIVE temp1 (id,obj_id,parent,class_name,level) AS (
        SELECT
            id,
            obj_id,
            parent_guid,
            class_name,
            1
        FROM v_active_object vao 
        WHERE obj_id =_obj_id
            UNION 
        SELECT
            t2.id,
            t2.obj_id,
            t2.parent_guid,
            t2.class_name,
            level+1
        FROM v_active_object t2 JOIN temp1 t1 ON t1.obj_id=t2.parent_guid
    )
    SELECT obj_id FROM temp1
$$;


--
-- Name: get_duplicates(jsonb, uuid, uuid); Type: FUNCTION; Schema: reclada; Owner: -
--

CREATE FUNCTION reclada.get_duplicates(_attrs jsonb, _class_uuid uuid, exclude_uuid uuid DEFAULT NULL::uuid) RETURNS TABLE(obj_guid uuid, dup_behavior reclada.dp_bhvr, is_cascade boolean, dup_field text)
    LANGUAGE sql STABLE
    AS $$
    SELECT vao.obj_id, vup.dup_behavior, vup.is_cascade, vup.copy_field
        FROM reclada.v_active_object vao
        JOIN reclada.v_unifields_pivoted vup ON vao."class" = vup.class_uuid
        WHERE (vao.attrs ->> f1) 
                || COALESCE((vao.attrs ->> f2),'') 
                || COALESCE((vao.attrs ->> f3),'') 
                || COALESCE((vao.attrs ->> f4),'') 
                || COALESCE((vao.attrs ->> f5),'') 
                || COALESCE((vao.attrs ->> f6),'') 
                || COALESCE((vao.attrs ->> f7),'') 
                || COALESCE((vao.attrs ->> f8),'')
            = (_attrs ->> f1) 
                || COALESCE((_attrs ->> f2),'') 
                || COALESCE((_attrs ->> f3),'') 
                || COALESCE((_attrs ->> f4),'') 
                || COALESCE((_attrs ->> f5),'') 
                || COALESCE((_attrs ->> f6),'') 
                || COALESCE((_attrs ->> f7),'') 
                || COALESCE((_attrs ->> f8),'')
            AND vao."class" = _class_uuid
            AND (vao.obj_id != exclude_uuid OR exclude_uuid IS NULL)
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
-- Name: get_unifield_index_name(text[]); Type: FUNCTION; Schema: reclada; Owner: -
--

CREATE FUNCTION reclada.get_unifield_index_name(fields text[]) RETURNS text
    LANGUAGE sql STABLE
    AS $$
	SELECT array_to_string(fields,'_')||'_index_';
$$;


--
-- Name: jsonb_deep_set(jsonb, text[], jsonb); Type: FUNCTION; Schema: reclada; Owner: -
--

CREATE FUNCTION reclada.jsonb_deep_set(curjson jsonb, globalpath text[], newval jsonb) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
    IF curjson is null THEN
        curjson := '{}'::jsonb;
    END IF;
    FOR index IN 1..ARRAY_LENGTH(globalpath, 1) LOOP
        IF curjson #> globalpath[1:index] is null THEN
            curjson := jsonb_set(curjson, globalpath[1:index], '{}');
        END IF;
    END LOOP;
    curjson := jsonb_set(curjson, globalpath, newval);
    RETURN curjson;
END;
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

CREATE FUNCTION reclada.raise_exception(msg text, func_name text DEFAULT '<unknown>'::text) RETURNS boolean
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
-- Name: validate_json(jsonb, text); Type: FUNCTION; Schema: reclada; Owner: -
--

CREATE FUNCTION reclada.validate_json(_data jsonb, _function text) RETURNS void
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    _schema jsonb;
BEGIN

    -- select reclada.raise_exception('JSON invalid: ' || _data >> '{}')
    select schema 
        from reclada.v_DTO_json_schema
            where _function = function
        into _schema;
    
     IF (_schema is null ) then
        RAISE EXCEPTION 'DTOJsonSchema for function: % not found',
                        _function;
    END IF;

    IF (NOT(public.validate_json_schema(_schema, _data))) THEN
        RAISE EXCEPTION 'JSON invalid: %, schema: %, function: %', 
                        _data #>> '{}'   , 
                        _schema #>> '{}' ,
                        _function;
    END IF;
      

END;
$$;


--
-- Name: xor(boolean, boolean); Type: FUNCTION; Schema: reclada; Owner: -
--

CREATE FUNCTION reclada.xor(a boolean, b boolean) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT (a and not b) or (b and not a);
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
    _data         jsonb;
    new_data      jsonb;
    _class_name    text;
    _class_uuid   uuid;
    tran_id       bigint;
    _attrs        jsonb;
    schema        jsonb;
    _obj_guid     uuid;
    res           jsonb;
    affected      uuid[];
    inserted      uuid[];
    inserted_from_draft uuid[];
    _dup_behavior reclada.dp_bhvr;
    _is_cascade   boolean;
    _uni_field    text;
    _parent_guid  uuid;
    _parent_field   text;
    skip_insert     boolean;
    notify_res      jsonb;
    _cnt             int;
    _new_parent_guid       uuid;
    _rel_type       text := 'GUID changed for dupBehavior';
    _guid_list      text;
BEGIN

    IF (jsonb_typeof(data_jsonb) != 'array') THEN
        data_jsonb := '[]'::jsonb || data_jsonb;
    END IF;
    /*TODO: check if some objects have revision AND others do not */
    branch:= data_jsonb->0->'branch';

    CREATE TEMPORARY TABLE IF NOT EXISTS create_duplicate_tmp (
        obj_guid        uuid,
        dup_behavior    reclada.dp_bhvr,
        is_cascade      boolean,
        dup_field       text
    )
    ON COMMIT DROP;

    FOR _data IN SELECT jsonb_array_elements(data_jsonb) 
    LOOP
        skip_insert := false;
        _class_name := _data->>'class';

        IF (_class_name IS NULL) THEN
            RAISE EXCEPTION 'The reclada object class is not specified';
        END IF;
        _class_uuid := reclada.try_cast_uuid(_class_name);

        _attrs := _data->'attributes';
        IF (_attrs IS NULL) THEN
            RAISE EXCEPTION 'The reclada object must have attributes';
        END IF;

        tran_id := (_data->>'transactionID')::bigint;
        IF tran_id IS NULL THEN
            tran_id := reclada.get_transaction_id();
        END IF;

        IF _class_uuid IS NULL THEN
            SELECT reclada_object.get_schema(_class_name) 
            INTO schema;
            _class_uuid := (schema->>'GUID')::uuid;
        ELSE
            SELECT v.data, v.for_class
            FROM reclada.v_class v
            WHERE _class_uuid = v.obj_id
            INTO schema, _class_name;
        END IF;
        IF (schema IS NULL) THEN
            RAISE EXCEPTION 'No json schema available for %', _class_name;
        END IF;

        IF (NOT(public.validate_json_schema(schema->'attributes'->'schema', _attrs))) THEN
            RAISE EXCEPTION 'JSON invalid: %', _attrs;
        END IF;
        
        IF _data->>'id' IS NOT NULL THEN
            RAISE EXCEPTION '%','Field "id" not allow!!!';
        END IF;

        SELECT prnt_guid, prnt_field
        FROM reclada_object.get_parent_guid(_data,_class_name)
            INTO _parent_guid,
                _parent_field;
        _obj_guid := _data->>'GUID';

        IF (_parent_guid IS NOT NULL) THEN
            SELECT
                attrs->>'object',
                attrs->>'dupBehavior',
                attrs->>'isCascade'
            FROM reclada.v_active_object
            WHERE class_name = 'Relationship'
                AND attrs->>'type'                      = _rel_type
                AND NULLIF(attrs->>'subject','')::uuid  = _parent_guid
                    INTO _new_parent_guid, _dup_behavior, _is_cascade;

            IF _new_parent_guid IS NOT NULL THEN
                _parent_guid := _new_parent_guid;
            END IF;
        END IF;
        
        IF EXISTS (
            SELECT 1
            FROM reclada.v_object_unifields
            WHERE class_uuid = _class_uuid
        )
        THEN
            INSERT INTO create_duplicate_tmp
            SELECT obj_guid,
                dup_behavior,
                is_cascade,
                dup_field
            FROM reclada.get_duplicates(_attrs, _class_uuid);

            IF (_parent_guid IS NOT NULL) THEN
                IF (_dup_behavior = 'Update' AND _is_cascade) THEN
                    SELECT count(DISTINCT obj_guid), string_agg(DISTINCT obj_guid::text, ',')
                    FROM create_duplicate_tmp
                        INTO _cnt, _guid_list;
                    IF (_cnt >1) THEN
                        RAISE EXCEPTION 'Found more than one duplicates (GUIDs: %). Resolve conflict manually.', _guid_list;
                    ELSIF (_cnt = 1) THEN
                        SELECT DISTINCT obj_guid, is_cascade
                        FROM create_duplicate_tmp
                            INTO _obj_guid, _is_cascade;
                        new_data := _data;
                        PERFORM reclada_object.create_relationship(
                                _rel_type,
                                _obj_guid,
                                (new_data->>'GUID')::uuid,
                                format('{"dupBehavior": "Update", "isCascade": %s}', _is_cascade::text)::jsonb);
                        new_data := reclada_object.remove_parent_guid(new_data, _parent_field);
                        new_data = reclada_object.update_json_by_guid(_obj_guid, new_data);
                        SELECT reclada_object.update(new_data)
                            INTO res;
                        affected := array_append( affected, _obj_guid);
                        skip_insert := true;
                    END IF;
                END IF;
                IF NOT EXISTS (
                    SELECT 1
                    FROM reclada.v_active_object
                    WHERE obj_id = _parent_guid
                )
                    AND _new_parent_guid IS NULL
                THEN
                    IF (_obj_guid IS NULL) THEN
                        RAISE EXCEPTION 'GUID is required.';
                    END IF;
                    INSERT INTO reclada.draft(guid, parent_guid, data)
                        VALUES(_obj_guid, _parent_guid, _data);
                    skip_insert := true;
                END IF;
            END IF;

            IF (NOT skip_insert) THEN
                SELECT COUNT(DISTINCT obj_guid), dup_behavior, string_agg (DISTINCT obj_guid::text, ',')
                FROM create_duplicate_tmp
                GROUP BY dup_behavior
                    INTO _cnt, _dup_behavior, _guid_list;
                IF (_cnt>1 AND _dup_behavior IN ('Update','Merge')) THEN
                    RAISE EXCEPTION 'Found more than one duplicates (GUIDs: %). Resolve conflict manually.', _guid_list;
                END IF;
                FOR _obj_guid, _dup_behavior, _is_cascade, _uni_field IN
                    SELECT obj_guid, dup_behavior, is_cascade, dup_field
                    FROM create_duplicate_tmp
                LOOP
                    new_data := _data;
                    CASE _dup_behavior
                        WHEN 'Replace' THEN
                            IF (_is_cascade = true) THEN
                                PERFORM reclada_object.delete(format('{"GUID": "%s"}', a)::jsonb)
                                FROM reclada.get_children(_obj_guid) a;
                            ELSE
                                PERFORM reclada_object.delete(format('{"GUID": "%s"}', _obj_guid)::jsonb);
                            END IF;
                        WHEN 'Update' THEN
                            PERFORM reclada_object.create_relationship(
                                _rel_type,
                                _obj_guid,
                                (new_data->>'GUID')::uuid,
                                format('{"dupBehavior": "Update", "isCascade": %s}', _is_cascade::text)::jsonb);
                            new_data := reclada_object.remove_parent_guid(new_data, _parent_field);
                            new_data := reclada_object.update_json_by_guid(_obj_guid, new_data);
                            SELECT reclada_object.update(new_data)
                                INTO res;
                            affected := array_append( affected, _obj_guid);
                            skip_insert := true;
                        WHEN 'Reject' THEN
                            RAISE EXCEPTION 'The object was rejected.';
                        WHEN 'Copy'    THEN
                            _attrs := _attrs || format('{"%s": "%s_%s"}', _uni_field, _attrs->> _uni_field, nextval('reclada.object_id_seq'))::jsonb;
                        WHEN 'Insert' THEN
                            -- DO nothing
                        WHEN 'Merge' THEN
                            PERFORM reclada_object.create_relationship(
                                _rel_type,
                                _obj_guid,
                                (new_data->>'GUID')::uuid,
                                '{"dupBehavior": "Merge"}'::jsonb);
                            SELECT reclada_object.update(reclada_object.merge(new_data - 'class', data,schema->'attributes'->'schema') || format('{"GUID": "%s"}', _obj_guid)::jsonb || format('{"transactionID": %s}', tran_id)::jsonb)
                            FROM reclada.v_active_object
                            WHERE obj_id = _obj_guid
                                INTO res;
                            affected := array_append( affected, _obj_guid);
                            skip_insert := true;
                    END CASE;
                END LOOP;
            END IF;
            DELETE FROM create_duplicate_tmp;
        END IF;
        
        IF (NOT skip_insert) THEN
            _obj_guid := (_data->>'GUID')::uuid;
            IF EXISTS (
                SELECT 1
                FROM reclada.object 
                WHERE GUID = _obj_guid
            ) THEN
                RAISE EXCEPTION 'GUID: % is duplicate', _obj_guid;
            END IF;
            --raise notice 'schema: %',schema;

            INSERT INTO reclada.object(GUID,class,attributes,transaction_id, parent_guid)
                SELECT  CASE
                            WHEN _obj_guid IS NULL
                                THEN public.uuid_generate_v4()
                            ELSE _obj_guid
                        END AS GUID,
                        _class_uuid, 
                        _attrs,
                        tran_id,
                        _parent_guid
            RETURNING GUID INTO _obj_guid;
            affected := array_append( affected, _obj_guid);
            inserted := array_append( inserted, _obj_guid);
            PERFORM reclada_object.datasource_insert
                (
                    _class_name,
                    _obj_guid,
                    _attrs
                );

            PERFORM reclada_object.refresh_mv(_class_name);
        END IF;
    END LOOP;

    SELECT array_agg(_affected_objects->>'GUID')
    FROM (
        SELECT jsonb_array_elements(_affected_objects) AS _affected_objects
        FROM (
            SELECT reclada_object.create(data) AS _affected_objects
            FROM reclada.draft
            WHERE parent_guid = ANY (affected)
        ) a
    ) b
    WHERE _affected_objects->>'GUID' IS NOT NULL
        INTO inserted_from_draft;
    affected := affected || inserted_from_draft;    

    res := array_to_json
            (
                array
                (
                    SELECT o.data 
                    FROM reclada.v_active_object o
                    WHERE o.obj_id = ANY (affected)
                )
            )::jsonb;
    notify_res := array_to_json
            (
                array
                (
                    SELECT o.data 
                    FROM reclada.v_active_object o
                    WHERE o.obj_id = ANY (inserted)
                )
            )::jsonb; 
    
    DELETE FROM reclada.draft 
        WHERE guid = ANY (affected);

    PERFORM reclada_notification.send_object_notification
        (
            'create',
            notify_res
        );
    RETURN res;
END;
$$;


--
-- Name: create_job(text, uuid, uuid, text, text, uuid); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.create_job(_uri text, _obj_id uuid, _new_guid uuid DEFAULT NULL::uuid, _task_guid text DEFAULT NULL::text, _task_command text DEFAULT NULL::text, _pipeline_job_guid uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    func_name       text := 'reclada_object.create_job';
    _environment    text;
    _obj            jsonb;
BEGIN
    SELECT attrs->>'Environment'
        FROM reclada.v_active_object
        WHERE class_name = 'Context'
        ORDER BY created_time DESC
        LIMIT 1
        INTO _environment;

    IF COALESCE(_uri, '') = '' THEN
        PERFORM reclada.raise_exception('URI variable is blank.', func_name);
    END IF;
    IF _obj_id IS NULL THEN
        PERFORM reclada.raise_exception('Object ID is blank.', func_name);
    END IF;

    _obj := format('{
                "class": "Job",
                "attributes": {
                    "task": "%s",
                    "status": "new",
                    "command": "%s",
                    "inputParameters": [{"uri": "%s"}, {"dataSourceId": "%s"}]
                    }
                }',
                    COALESCE(reclada.try_cast_uuid(_task_guid), 'c94bff30-15fa-427f-9954-d5c3c151e652'::uuid),
                    COALESCE(_task_command,'./run_pipeline.sh'),
                    _uri,
                    _obj_id::text
            )::jsonb;
    IF _new_guid IS NOT NULL THEN
        _obj := jsonb_set(_obj,'{GUID}',format('"%s"',_new_guid)::jsonb);
    END IF;

    _obj := jsonb_set(_obj,'{attributes,type}',format('"%s"',_environment)::jsonb);

    IF _pipeline_job_guid IS NOT NULL THEN
        _obj := jsonb_set(_obj,'{attributes,inputParameters}',_obj#>'{attributes,inputParameters}' || format('{"PipelineLiteJobGUID" :"%s"}',_pipeline_job_guid)::jsonb);
    END IF;
    RETURN reclada_object.create(_obj);
END;
$$;


--
-- Name: create_relationship(text, uuid, uuid, jsonb); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.create_relationship(_rel_type text, _obj_guid uuid, _subj_guid uuid, _extra_attrs jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    _rel_cnt    int;
    _obj        jsonb;
BEGIN

    IF (_obj_GUID IS NULL OR _subj_GUID IS NULL) THEN
        RAISE EXCEPTION 'Object GUID or Subject GUID IS NULL';
    END IF;

    SELECT count(*)
    FROM reclada.v_active_object
    WHERE class_name = 'Relationship'
        AND NULLIF(attrs->>'object','')::uuid   = _obj_GUID
        AND NULLIF(attrs->>'subject','')::uuid  = _subj_GUID
        AND attrs->>'type'                      = _rel_type
            INTO _rel_cnt;
    IF (_rel_cnt = 0) THEN
        _obj := format('{
            "class": "Relationship",
            "attributes": {
                "type": "%s",
                "object": "%s",
                "subject": "%s"
                }
            }',
            _rel_type,
            _obj_GUID,
            _subj_GUID)::jsonb;
        _obj := jsonb_set (_obj, '{attributes}', _obj->'attributes' || _extra_attrs);   

        RETURN  reclada_object.create( _obj);
    ELSE
        RETURN '{}'::jsonb;
    END IF;
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
    version_        integer;
    class_guid      uuid;
    _uniFields      jsonb;
    _idx_name       text;
    _f_list         text;
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

    SELECT obj_id
    FROM reclada.v_class
    WHERE for_class = class
    ORDER BY version DESC
    LIMIT 1
    INTO class_guid;

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
        },
        "parent_guid" : "%s"
    }',
    new_class,
    version_,
    (class_schema->'properties') || coalesce((attrs->'properties'),'{}'::jsonb),
    (SELECT jsonb_agg(el) FROM (
        SELECT DISTINCT pg_catalog.jsonb_array_elements(
            (class_schema -> 'required') || coalesce((attrs -> 'required'),'{}'::jsonb)
        ) el) arr),
    class_guid
    )::jsonb);

    IF ( jsonb_typeof(attrs->'dupChecking') = 'array' ) THEN
        FOR _uniFields IN (
            SELECT jsonb_array_elements(attrs->'dupChecking')->'uniFields'
        ) LOOP
            IF ( jsonb_typeof(_uniFields) = 'array' ) THEN
                SELECT
                    reclada.get_unifield_index_name( array_agg(f ORDER BY f)) AS idx_name, 
                    string_agg('(attributes ->> ''' || f || ''')','||' ORDER BY f) AS fields_list
                FROM (
                    SELECT jsonb_array_elements_text (_uniFields::jsonb) f
                ) a
                    INTO _idx_name, _f_list;
                IF NOT EXISTS (
                    SELECT 1
                    FROM pg_catalog.pg_indexes pi2 
                    WHERE schemaname ='reclada' AND tablename ='object' AND indexname =_idx_name
                ) THEN
                    EXECUTE E'CREATE INDEX ' || _idx_name || ' ON reclada.object USING HASH ((' || _f_list || '))';
                END IF;
            END IF;
        END LOOP;
        PERFORM reclada_object.refresh_mv('uniFields');
    END IF;

END;
$$;


--
-- Name: datasource_insert(text, uuid, jsonb); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.datasource_insert(_class_name text, _obj_id uuid, attributes jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE

    _pipeline_lite jsonb;
    _task  jsonb;
    _dataset_guid  uuid;
    _new_guid  uuid;
    _pipeline_job_guid  uuid;
    _stage         text;
    _uri           text;
    _dataset2ds_type text = 'defaultDataSet to DataSource';
    _f_name text = 'reclada_object.datasource_insert';
BEGIN
    IF _class_name in ('DataSource','File') THEN

        _uri := attributes->>'uri';

        SELECT v.obj_id
            FROM reclada.v_active_object v
            WHERE v.class_name = 'DataSet'
                and v.attrs->>'name' = 'defaultDataSet'
            INTO _dataset_guid;

        IF (_dataset_guid IS NULL) THEN
            RAISE EXCEPTION 'Can''t found defaultDataSet';
        END IF;
        PERFORM reclada_object.create_relationship(_dataset2ds_type, _obj_id, _dataset_guid);
        IF _uri LIKE '%inbox/jobs/%' THEN
            PERFORM reclada_object.create_job(_uri, _obj_id);
        ELSE
            
            SELECT data 
                FROM reclada.v_active_object
                    WHERE class_name = 'PipelineLite'
                        LIMIT 1
                INTO _pipeline_lite;
            _new_guid := public.uuid_generate_v4();
            IF _uri LIKE '%inbox/pipelines/%/%' THEN
                
                _stage := SPLIT_PART(
                                SPLIT_PART(_uri,'inbox/pipelines/',2),
                                '/',
                                2
                            );
                _stage = replace(_stage,'.json','');
                SELECT data 
                    FROM reclada.v_active_object o
                        where o.class_name = 'Task'
                            and o.obj_id = (_pipeline_lite #>> ('{attributes,tasks,'||_stage||'}')::text[])::uuid
                    into _task;
                
                _pipeline_job_guid = reclada.try_cast_uuid(
                                        SPLIT_PART(
                                            SPLIT_PART(_uri,'inbox/pipelines/',2),
                                            '/',
                                            1
                                        )
                                    );
                IF _pipeline_job_guid IS NULL THEN
                    perform reclada.raise_exception('PIPELINE_JOB_GUID not found',_f_name);
                END IF;
                
                SELECT  data #>> '{attributes,inputParameters,0,uri}',
                        (data #>> '{attributes,inputParameters,1,dataSourceId}')::uuid
                    FROM reclada.v_active_object o
                        WHERE o.obj_id = _pipeline_job_guid
                    INTO _uri, _obj_id;

            ELSE
                SELECT data 
                    FROM reclada.v_active_object o
                        WHERE o.class_name = 'Task'
                            AND o.obj_id = (_pipeline_lite #>> '{attributes,tasks,0}')::uuid
                    INTO _task;
                IF _task IS NOT NULL THEN
                    _pipeline_job_guid := _new_guid;
                END IF;
            END IF;
            
            PERFORM reclada_object.create_job(
                _uri,
                _obj_id,
                _new_guid,
                _task->>'GUID',
                _task-> 'attributes' ->>'command',
                _pipeline_job_guid
            );
        END IF;
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
    _class_name         text;
    _class_name_from_uuid   text;
    _class_uuid          uuid;
    list_id             bigint[];
    _for_class           text;
    _uniFields_index_name          text;
BEGIN

    v_obj_id := data->>'GUID';
    tran_id := (data->>'transactionID')::bigint;
    _class_name := data->>'class';

    IF (v_obj_id IS NULL AND _class_name IS NULL AND tran_id IS NULl) THEN
        RAISE EXCEPTION 'Could not delete object with no GUID, class and transactionID';
    END IF;

    _class_uuid := reclada.try_cast_uuid(_class_name);
    IF _class_uuid IS NOT NULL THEN
        SELECT v.for_class 
        FROM reclada.v_class_lite v
        WHERE _class_uuid = v.obj_id
            INTO _class_name_from_uuid;
    END IF;

    WITH t AS
    (    
        UPDATE reclada.object u
            SET status = reclada_object.get_archive_status_obj_id()
            FROM reclada.object o
                LEFT JOIN
                (   SELECT obj_id FROM reclada_object.get_GUID_for_class(_class_name)
                    UNION SELECT _class_uuid WHERE _class_uuid IS NOT NULL
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

    IF (jsonb_array_length(data) <= 1) THEN
        data := data->0;
    END IF;
    
    IF (data IS NULL) THEN
        RAISE EXCEPTION 'Could not delete object, no such GUID';
    END IF;

    PERFORM reclada_object.refresh_mv(COALESCE(_class_name_from_uuid, _class_name));

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
        format(E'\'%s\'::jsonb', data->'object'#>>'{}')) || CASE WHEN data->>'operator'='<@' THEN ' AND ' || key_path || ' != ''[]''::jsonb' ELSE '' END
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
-- Name: get_parent_guid(jsonb, text); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.get_parent_guid(_data jsonb, _class_name text) RETURNS TABLE(prnt_guid uuid, prnt_field text)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    _parent_field   text;
    _parent_guid    uuid;
BEGIN
    SELECT parent_field
    FROM reclada.v_parent_field
    WHERE for_class = _class_name
        INTO _parent_field;

    _parent_guid = (_data->>'parent_guid')::uuid;
    IF (_parent_guid IS NULL AND _parent_field IS NOT NULL) THEN
        _parent_guid = _data->'attributes'->>_parent_field;
    END IF;
    RETURN QUERY
    SELECT _parent_guid,
        _parent_field;
END;
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
-- Name: get_query_condition_filter(jsonb); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.get_query_condition_filter(data jsonb) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE 
    _count   INT;
    _res     TEXT;
    _f_name TEXT = 'reclada_object.get_query_condition_filter';
BEGIN 
    
    perform reclada.validate_json(data, _f_name);
    -- TODO: to change VOLATILE -> IMMUTABLE, remove CREATE TEMP TABLE
    CREATE TEMP TABLE mytable AS
        SELECT  res.lvl              AS lvl         , 
                res.rn               AS rn          , 
                res.idx              AS idx         ,
                res.prev             AS prev        , 
                res.val              AS val         ,  
                res.parsed           AS parsed      , 
                coalesce(
                    po.inner_operator, 
                    op.operator
                )                   AS op           , 
                coalesce
                (
                    iop.input_type,
                    op.input_type
                )                   AS input_type   ,
                case 
                    when iop.input_type is not NULL 
                        then NULL 
                    else 
                        op.output_type
                end                 AS output_type  ,
                po.operator         AS po           ,
                po.input_type       AS po_input_type,
                iop.brackets        AS po_inner_brackets
            FROM reclada_object.parse_filter(data) res
            LEFT JOIN reclada.v_filter_available_operator op
                ON res.op = op.operator
            LEFT JOIN reclada_object.parse_filter(data) p
                on  p.lvl = res.lvl-1
                    and res.prev = p.rn
            LEFT JOIN reclada.v_filter_available_operator po
                on po.operator = p.op
            LEFT JOIN reclada.v_filter_inner_operator iop
                on iop.operator = po.inner_operator;

    PERFORM reclada.raise_exception('Operator does not allowed ', _f_name)
        FROM mytable t
            WHERE t.op IS NULL;


    UPDATE mytable u
        SET parsed = to_jsonb(p.v)
            FROM mytable t
            JOIN LATERAL 
            (
                SELECT  t.parsed #>> '{}' v
            ) as pt
                ON TRUE
            LEFT JOIN reclada.v_filter_mapping fm
                ON pt.v = fm.pattern
            JOIN LATERAL 
            (
                SELECT CASE 
                        WHEN t.op LIKE '%<@%' AND t.idx=1 AND jsonb_typeof(t.parsed)='string'
                            THEN format('data #> ''%s''!= ''[]''::jsonb AND data #> ''%s''!= ''{}''::jsonb AND data #> ''%s''', pt.v, pt.v, pt.v)
                        WHEN fm.repl is not NULL 
                            then 
                                case 
                                    when t.input_type in ('TEXT')
                                        then fm.repl || '::TEXT'
                                    else '(''"''||' ||fm.repl ||'||''"'')::jsonb' -- don't use FORMAT (concat null)
                                end
                        WHEN jsonb_typeof(t.parsed) in ('number', 'boolean')
                            then 
                                case 
                                    when t.input_type in ('NUMERIC','INT')
                                        then pt.v
                                    else '''' || pt.v || '''::jsonb'
                                end
                        WHEN jsonb_typeof(t.parsed) = 'string' 
                            then    
                                case
                                    WHEN pt.v LIKE '{%}'
                                        THEN
                                            case
                                                when t.input_type = 'TEXT'
                                                    then format('(data #>> ''%s'')', pt.v)
                                                when t.input_type = 'JSONB' or t.input_type is null
                                                    then format('data #> ''%s''', pt.v)
                                                else
                                                    format('(data #>> ''%s'')::', pt.v) || t.input_type
                                            end
                                    when t.input_type = 'TEXT'
                                        then ''''||REPLACE(pt.v,'''','''''')||''''
                                    when t.input_type = 'JSONB' or t.input_type is null
                                        then '''"'||REPLACE(pt.v,'''','''''')||'"''::jsonb'
                                    else ''''||REPLACE(pt.v,'''','''''')||'''::'||t.input_type
                                end
                        WHEN jsonb_typeof(t.parsed) = 'null'
                            then 'null'
                        WHEN jsonb_typeof(t.parsed) = 'array'
                            then ''''||REPLACE(pt.v,'''','''''')||'''::jsonb'
                        ELSE
                            pt.v
                    END AS v
            ) as p
                ON TRUE
            WHERE t.lvl = u.lvl
                AND t.rn = u.rn
                AND t.parsed IS NOT NULL;

    update mytable u
        set op = CASE 
                    when f.btwn
                        then ' BETWEEN '
                    else u.op -- f.inop
                end,
            parsed = format(vb.operand_format,u.parsed)::jsonb
        FROM mytable t
        join lateral
        (
            select  t.op like ' %/BETWEEN ' btwn, 
                    t.po_inner_brackets is not null inop
        ) f 
            on true
        join reclada.v_filter_between vb
            on t.op = vb.operator
            WHERE t.lvl = u.lvl
                AND t.rn = u.rn
                AND (f.btwn or f.inop);


    INSERT INTO mytable (lvl,rn)
        VALUES (0,0);

    _count := 1;

    WHILE (_count>0) LOOP
        WITH r AS 
        (
            UPDATE mytable
                SET parsed = to_json(t.converted)::JSONB 
                FROM 
                (
                    SELECT     
                            res.lvl-1 lvl,
                            res.prev rn,
                            res.op,
                            1 q,
                            case 
                                when not res.po_inner_brackets 
                                    then array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op) 
                                else
                                    CASE COUNT(1) 
                                        WHEN 1
                                            THEN 
                                                CASE res.output_type
                                                    when 'NUMERIC'
                                                        then format('(%s %s)::TEXT::JSONB', res.op, min(res.parsed #>> '{}') )
                                                    else 
                                                        format('(%s %s)', res.op, min(res.parsed #>> '{}') )
                                                end
                                        ELSE
                                            CASE 
                                                when res.output_type = 'TEXT'
                                                    then '(''"''||'||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op) ||'||''"'')::JSONB'
                                                when res.output_type in ('NUMERIC','INT')
                                                    then '('||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op) ||')::TEXT::JSONB'
                                                else
                                                    '('||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op) ||')'
                                            end
                                    end
                            end AS converted
                        FROM mytable res 
                            WHERE res.parsed IS NOT NULL
                                AND res.lvl = (SELECT max(lvl)+1 FROM mytable WHERE parsed IS NULL)
                            GROUP BY  res.prev, res.op, res.lvl, res.input_type, res.output_type, res.po_inner_brackets
                ) t
                WHERE
                    t.lvl = mytable.lvl
                        AND t.rn = mytable.rn
                RETURNING 1
        )
            SELECT COUNT(1) 
                FROM r
                INTO _count;
    END LOOP;
    
    SELECT parsed #>> '{}' 
        FROM mytable
            WHERE lvl = 0 AND rn = 0
        INTO _res;
    -- perform reclada.raise_notice( _res);
    DROP TABLE mytable;
    RETURN _res;
END 
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
-- Name: list(jsonb, boolean, text); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.list(data jsonb, gui boolean DEFAULT false, ver text DEFAULT '1'::text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    _f_name TEXT = 'reclada_object.list';
    _class              text;
    attrs               jsonb;
    order_by_jsonb      jsonb;
    order_by            text;
    limit_              text;
    offset_             text;
    query_conditions    text;
    number_of_objects   int;
    objects             jsonb;
    res                 jsonb;
    _exec_text           text;
    _pre_query           text;
    _from               text;
    class_uuid          uuid;
    last_change         text;
    tran_id             bigint;
    _filter             JSONB;
    _object_display     JSONB;
BEGIN

    perform reclada.validate_json(data, _f_name);

    if ver = '1' then
        tran_id := (data->>'transactionID')::bigint;
        _class := data->>'class';
    elseif ver = '2' then
        tran_id := (data->>'{transactionID}')::bigint;
        _class := data->>'{class}';
    end if;
    _filter = data->'filter';

    order_by_jsonb := data->'orderBy';
    IF ((order_by_jsonb IS NULL) OR
        (order_by_jsonb = 'null'::jsonb) OR
        (order_by_jsonb = '[]'::jsonb)) THEN
        order_by_jsonb := '[{"field": "GUID", "order": "ASC"}]'::jsonb;
    END IF;
    SELECT string_agg(
        format(
            E'obj.data#>''{%s}'' %s', 
            case ver
                when '2'
                    then REPLACE(REPLACE(T.value->>'field','{', '"{' ),'}', '}"' )
                else
                    T.value->>'field'
            end,
            COALESCE(T.value->>'order', 'ASC')),
        ' , ')
        FROM jsonb_array_elements(order_by_jsonb) T
        INTO order_by;

    limit_ := data->>'limit';
    IF (limit_ IS NULL) THEN
        limit_ := 500;
    END IF;

    offset_ := data->>'offset';
    IF (offset_ IS NULL) THEN
        offset_ := 0;
    END IF;
    
    IF (_filter IS NOT NULL) THEN
        query_conditions := reclada_object.get_query_condition_filter(_filter);
    ELSEIF ver = '1' then
        class_uuid := reclada.try_cast_uuid(_class);

        IF (class_uuid IS NULL) THEN
            SELECT v.obj_id
                FROM reclada.v_class v
                    WHERE _class = v.for_class
                    ORDER BY v.version DESC
                    limit 1 
            INTO class_uuid;
            IF (class_uuid IS NULL) THEN
                perform reclada.raise_exception(
                        format('Class not found: %s', _class),
                        _f_name
                    );
            END IF;
        end if;

        attrs := data->'attributes' || '{}'::jsonb;

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
                    format('obj.class_name = ''%s''', _class) AS condition
                        where _class is not null
                UNION
                    SELECT format('obj.class = ''%s''', class_uuid) AS condition
                        where class_uuid is not null
                            and _class is null
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
    END IF;
    -- TODO: add ELSE
    IF ver = '2' THEN
        _pre_query := (select val from reclada.v_ui_active_object);
        _from := 'res AS obj';
        _pre_query := REPLACE(_pre_query,'#@#@#where#@#@#', query_conditions  );

    ELSE
        _pre_query := '';
        _from := 'reclada.v_active_object AS obj
                            WHERE #@#@#where#@#@#';
        _from := REPLACE(_from, '#@#@#where#@#@#', query_conditions  );
    END IF;
    _exec_text := _pre_query ||
                'SELECT to_jsonb(array_agg(t.data))
                    FROM 
                    (
                        SELECT obj.data
                            FROM '
                            || _from
                            || ' 
                            ORDER BY #@#@#orderby#@#@#
                            OFFSET #@#@#offset#@#@#
                            LIMIT #@#@#limit#@#@#
                    ) AS t';
    _exec_text := REPLACE(_exec_text, '#@#@#orderby#@#@#'  , order_by          );
    _exec_text := REPLACE(_exec_text, '#@#@#offset#@#@#'   , offset_           );
    _exec_text := REPLACE(_exec_text, '#@#@#limit#@#@#'    , limit_            );
    -- RAISE NOTICE 'conds: %', _exec_text;
    EXECUTE _exec_text
        INTO objects;
    objects := coalesce(objects,'[]'::jsonb);
    IF gui THEN

        if ver = '2' then
            class_uuid := coalesce(class_uuid, (objects#>>'{0,"{class}"}')::uuid);
            if class_uuid is not null then
                _class :=   (
                                select cl.for_class 
                                    from reclada.v_class_lite cl
                                        where class_uuid = cl.obj_id
                                            limit 1
                            );

                _exec_text := _pre_query ||',
                dd as (
                    select distinct unnest(obj.display_key) v
                        FROM '|| _from ||'
                ),
                on_data as 
                (
                    select  jsonb_object_agg(
                                t.v, 
                                replace(dd.template,''#@#attrname#@#'',t.v)::jsonb 
                            ) t
                        from dd as t
                        JOIN reclada.v_default_display dd
                            on t.v like ''%'' || dd.json_type
                )
                select jsonb_set(templ.v,''{table}'', od.t || coalesce(d.table,coalesce(d.table,templ.v->''table'')))
                    from on_data od
                    join (
                        select replace(template,''#@#classname#@#'','''|| _class ||''')::jsonb v
                            from reclada.v_default_display 
                                where json_type = ''ObjectDisplay''
                                    limit 1
                    ) templ
                        on true
                    left join reclada.v_object_display d
                        on d.class_guid::text = '''|| coalesce( class_uuid::text, '' ) ||'''';

                -- raise notice '%',_exec_text;
                EXECUTE _exec_text
                    INTO _object_display;
            end if;
        end if;

        _exec_text := _pre_query || '
            SELECT  COUNT(1),
                    TO_CHAR(
                        MAX(
                            GREATEST(
                                obj.created_time, 
                                (
                                    SELECT  TO_TIMESTAMP(
                                                MAX(date_time),
                                                ''YYYY-MM-DD hh24:mi:ss.US TZH''
                                            )
                                        FROM reclada.v_revision vr
                                            WHERE vr.obj_id = UUID(obj.attrs ->>''revision'')
                                )
                            )
                        ),
                        ''YYYY-MM-DD hh24:mi:ss.MS TZH''
                    )
                    FROM '|| _from;
        EXECUTE _exec_text
            INTO number_of_objects, last_change;
        
        IF _object_display IS NOT NULL then
            res := jsonb_build_object(
                    'lastСhange', last_change,    
                    'number', number_of_objects,
                    'objects', objects,
                    'display', _object_display
                );
        ELSE
            res := jsonb_build_object(
                    'lastСhange', last_change,    
                    'number', number_of_objects,
                    'objects', objects
            );
        end if;
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
		RAISE EXCEPTION 'There is no GUID';
	END IF;

    SELECT v.data
    FROM reclada.v_active_object v
    WHERE v.obj_id = objid
    INTO obj;

	IF (obj IS NULL) THEN
		RAISE EXCEPTION 'There is no object with such id';
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
-- Name: merge(jsonb, jsonb, jsonb); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.merge(lobj jsonb, robj jsonb, schema jsonb DEFAULT NULL::jsonb) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    AS $$
    DECLARE
        res     jsonb;
        ltype    text;
        rtype    text;
    BEGIN
        ltype := jsonb_typeof(lobj);
        rtype := jsonb_typeof(robj);
        IF (lobj IS NULL AND robj IS NOT NULL) THEN
            RETURN robj;
        END IF;
        IF (lobj IS NOT NULL AND robj IS NULL) THEN
            RETURN lobj;
        END IF;
        IF (ltype = 'null') THEN
            RETURN robj;
        END IF;
        IF (ltype != rtype) THEN
            RETURN lobj || robj;
        END IF;
        IF reclada_object.is_equal(lobj,robj) THEN
            RETURN lobj;
        END IF;
        CASE ltype 
        WHEN 'object' THEN
            SELECT jsonb_object_agg(key,val)
            FROM (
                SELECT key, reclada_object.merge(lval,rval) as val
                    FROM (                     -- Using joining operators compatible with merge or hash join is obligatory
                    SELECT (a.rec).key as key,
                        (a.rec).value AS lval,
                        (b.rec).value AS rval                                        --    with FULL OUTER JOIN. merge is compatible only with NESTED LOOPS
                    FROM (SELECT jsonb_each(lobj) AS rec) a         --    so I use LEFT JOIN UNION ALL RIGHT JOIN insted of FULL OUTER JOIN.
                    LEFT JOIN
                        (SELECT jsonb_each(robj) AS rec) b
                    ON (a.rec).key = (b.rec).key
                UNION
                    SELECT (a.rec).key as key,
                        (b.rec).value AS lval,
                        (a.rec).value AS rval
                    FROM (SELECT jsonb_each(robj) AS rec) a
                    LEFT JOIN
                        (SELECT jsonb_each(lobj) AS rec) b
                    ON (a.rec).key = (b.rec).key
                ) a
            ) b
                INTO res;
            IF schema IS NOT NULL AND NOT validate_json_schema(schema, res) THEN
                RAISE EXCEPTION 'Objects aren''t mergeable. Solve duplicate conflicate manually.';
            END IF;
            RETURN res;
        WHEN 'array' THEN
            SELECT to_jsonb(array_agg(rec)) FROM (
                SELECT COALESCE(a.rec, b.rec) as rec
                FROM (SELECT jsonb_array_elements (lobj) AS rec) a
                LEFT JOIN
                    (SELECT jsonb_array_elements (robj) AS rec) b
                ON reclada_object.is_equal((a.rec), (b.rec))
                UNION
                SELECT COALESCE(a.rec, b.rec) as rec
                FROM (SELECT jsonb_array_elements (robj) AS rec) a
                LEFT JOIN
                    (SELECT jsonb_array_elements (lobj) AS rec) b
                ON reclada_object.is_equal((a.rec), (b.rec))
            ) a
                INTO res;
            RETURN res;
        WHEN 'string' THEN
            RETURN lobj || robj;
        WHEN 'number' THEN
            RETURN lobj || robj;
        WHEN 'boolean' THEN
            RETURN lobj || robj;
        WHEN 'null' THEN
            RETURN '{}'::jsonb;                                    -- It should be Null
        ELSE
            RETURN null;
        END CASE;
    END;
$$;


--
-- Name: need_flat(text); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.need_flat(_class_name text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
    select exists
        (
            select true as r
                from reclada.v_object_display d
                join reclada_object.get_GUID_for_class(_class_name) tf
                    on tf.obj_id = d.class_guid
                where d.table is not null
        )
$$;


--
-- Name: parse_filter(jsonb); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.parse_filter(data jsonb) RETURNS TABLE(lvl integer, rn bigint, idx bigint, op text, prev bigint, val jsonb, parsed jsonb)
    LANGUAGE sql IMMUTABLE
    AS $$
    WITH RECURSIVE f AS 
    (
        SELECT data AS v
    ),
    pr AS 
    (
        SELECT 	format(' %s ',f.v->>'operator') AS op, 
                val.v AS val,
                1 AS lvl,
                row_number() OVER(ORDER BY idx) AS rn,
                val.idx idx,
                0::BIGINT prev
            FROM f, jsonb_array_elements(f.v->'value') WITH ordinality AS val(v, idx)
    ),
    res AS
    (	
        SELECT 	pr.lvl	,
                pr.rn	,
                pr.idx  ,
                pr.op	,
                pr.prev ,
                pr.val	,
                CASE jsonb_typeof(pr.val) 
                    WHEN 'object'	
                        THEN NULL
                    ELSE pr.val
                END AS parsed
            FROM pr
            WHERE prev = 0 
                AND lvl = 1
        UNION ALL
        SELECT 	ttt.lvl	,
                ROW_NUMBER() OVER(ORDER BY ttt.idx) AS rn,
                ttt.idx,
                ttt.op	,
                ttt.prev,
                ttt.val ,
                CASE jsonb_typeof(ttt.val) 
                    WHEN 'object'	
                        THEN NULL
                    ELSE ttt.val
                end AS parsed
            FROM
            (
                SELECT 	res.lvl + 1 AS lvl,
                        format(' %s ',res.val->>'operator') AS op,
                        res.rn AS prev	,
                        val.v  AS val,
                        val.idx
                    FROM res, 
                         jsonb_array_elements(res.val->'value') WITH ordinality AS val(v, idx)
            ) ttt
    )
    SELECT 	r.lvl	,
            r.rn	,
            r.idx   ,
            case upper(r.op) 
                when ' XOR '
                    then ' OPERATOR(reclada.##) ' 
                else upper(r.op) 
            end,
            r.prev  ,
            r.val	,
            r.parsed
        FROM res r
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
        WHEN 'uniFields' THEN
            REFRESH MATERIALIZED VIEW reclada.v_class_lite;
            REFRESH MATERIALIZED VIEW reclada.v_object_unifields;
        ELSE
            NULL;
    END CASE;
END;
$$;


--
-- Name: remove_parent_guid(jsonb, text); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.remove_parent_guid(_data jsonb, parent_field text) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    AS $$
    BEGIN
        IF (parent_field IS NOT NULL) THEN
            _data := _data #- format('{attributes,%s}',parent_field)::text[];
        END IF;
        _data := _data - 'parent_guid';
        _data := _data - 'GUID';
        RETURN _data;
    END;
$$;


--
-- Name: update(jsonb, jsonb); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.update(_data jsonb, user_info jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    _f_name       TEXT = 'reclada_object.update';
    _class_name   text;
    _class_uuid   uuid;
    _obj_id       uuid;
    _attrs        jsonb;
    schema        jsonb;
    old_obj       jsonb;
    branch        uuid;
    revid         uuid;
    _parent_guid  uuid;
    _parent_field text;
    _obj_guid     uuid;
    _dup_behavior reclada.dp_bhvr;
    _uni_field    text;
    _cnt          int;
    _guid_list      text;
BEGIN

    _class_name := _data->>'class';
    IF (_class_name IS NULL) THEN
        perform reclada.raise_exception(
                        'The reclada object class is not specified',
                        _f_name
                    );
    END IF;
    _class_uuid := reclada.try_cast_uuid(_class_name);
    _obj_id := _data->>'GUID';
    IF (_obj_id IS NULL) THEN
        RAISE EXCEPTION 'Could not update object with no GUID';
    END IF;

    _attrs := _data->'attributes';
    IF (_attrs IS NULL) THEN
        RAISE EXCEPTION 'The reclada object must have attributes';
    END IF;

    if _class_uuid is null then
        SELECT reclada_object.get_schema(_class_name) 
            INTO schema;
    else
        select v.data, v.for_class 
            from reclada.v_class v
                where _class_uuid = v.obj_id
            INTO schema, _class_name;
    end if;
    -- TODO: don't allow update jsonschema
    IF (schema IS NULL) THEN
        RAISE EXCEPTION 'No json schema available for %', _class_name;
    END IF;

    IF (_class_uuid IS NULL) THEN
        _class_uuid := (schema->>'GUID')::uuid;
    END IF;
    schema := schema #> '{attributes,schema}';
    IF (NOT(public.validate_json_schema(schema, _attrs))) THEN
        RAISE EXCEPTION 'JSON invalid: %', _attrs;
    END IF;

    SELECT 	v.data
        FROM reclada.v_object v
	        WHERE v.obj_id = _obj_id
                AND v.class_name = _class_name 
	    INTO old_obj;

    IF (old_obj IS NULL) THEN
        RAISE EXCEPTION 'Could not update object, no such id';
    END IF;

    branch := _data->'branch';
    SELECT reclada_revision.create(user_info->>'sub', branch, _obj_id) 
        INTO revid;

    SELECT prnt_guid, prnt_field
    FROM reclada_object.get_parent_guid(_data,_class_name)
        INTO _parent_guid,
            _parent_field;

    IF (_parent_guid IS NULL) THEN
        _parent_guid := old_obj->>'parentGUID';
    END IF;
    
    IF EXISTS (
        SELECT 1
        FROM reclada.v_object_unifields
        WHERE class_uuid=_class_uuid
    )
    THEN
        SELECT COUNT(DISTINCT obj_guid), dup_behavior, string_agg(DISTINCT obj_guid::text, ',')
        FROM reclada.get_duplicates(_attrs, _class_uuid, _obj_id)
        GROUP BY dup_behavior
            INTO _cnt, _dup_behavior, _guid_list;
        IF (_cnt>1 AND _dup_behavior IN ('Update','Merge')) THEN
            RAISE EXCEPTION 'Found more than one duplicates (GUIDs: %). Resolve conflict manually.', _guid_list;
        END IF;
        FOR _obj_guid, _dup_behavior, _uni_field IN (
                SELECT obj_guid, dup_behavior, dup_field
                FROM reclada.get_duplicates(_attrs, _class_uuid, _obj_id)
            ) LOOP
            IF _dup_behavior IN ('Update','Merge') THEN
                UPDATE reclada.object o
                    SET status = reclada_object.get_archive_status_obj_id()
                WHERE o.GUID = _obj_guid
                    AND status != reclada_object.get_archive_status_obj_id();
            END IF;
            CASE _dup_behavior
                WHEN 'Replace' THEN
                    PERFORM reclada_object.delete(format('{"GUID": "%s"}', _obj_guid)::jsonb);
                WHEN 'Update' THEN                    
                    _data := reclada_object.remove_parent_guid(_data, _parent_field);
                    _data := reclada_object.update_json_by_guid(_obj_guid, _data);
                    RETURN reclada_object.update(_data);
                WHEN 'Reject' THEN
                    RAISE EXCEPTION 'Duplicate found (GUID: %). Object rejected.', _obj_guid;
                WHEN 'Copy'    THEN
                    _attrs = _attrs || format('{"%s": "%s_%s"}', _uni_field, _attrs->> _uni_field, nextval('reclada.object_id_seq'))::jsonb;
                    IF (NOT(public.validate_json_schema(schema, _attrs))) THEN
                        RAISE EXCEPTION 'JSON invalid: %', _attrs;
                    END IF;
                WHEN 'Insert' THEN
                    -- DO nothing
                WHEN 'Merge' THEN                    
                    RETURN reclada_object.update(
                        reclada_object.merge(
                            _data - 'class', 
                            vao.data, 
                            schema
                        ) || format('{"GUID": "%s"}', _obj_guid)::jsonb
                    )
                        FROM reclada.v_active_object vao
                            WHERE obj_id = _obj_guid;
            END CASE;
        END LOOP;
    END IF;

    with t as 
    (
        update reclada.object o
            set status = reclada_object.get_archive_status_obj_id()
                where o.GUID = _obj_id
                    and status != reclada_object.get_archive_status_obj_id()
                        RETURNING id
    )
    INSERT INTO reclada.object( GUID,
                                class,
                                status,
                                attributes,
                                transaction_id,
                                parent_guid
                              )
        select  v.obj_id,
                _class_uuid,
                reclada_object.get_active_status_obj_id(),--status 
                _attrs || format('{"revision":"%s"}',revid)::jsonb,
                transaction_id,
                _parent_guid
            FROM reclada.v_object v
            JOIN 
            (   
                select id 
                    FROM 
                    (
                        select id, 1 as q
                            from t
                        union 
                        select id, 2 as q
                            from reclada.object ro
                                where ro.guid = _obj_id
                                    ORDER BY ID DESC 
                                        LIMIT 1
                    ) ta
                    ORDER BY q ASC 
                        LIMIT 1
            ) as tt
                on tt.id = v.id
	            WHERE v.obj_id = _obj_id;
    PERFORM reclada_object.datasource_insert
            (
                _class_name,
                _obj_id,
                _attrs
            );
    PERFORM reclada_object.refresh_mv(_class_name);

    IF ( _class_name = 'jsonschema' AND jsonb_typeof(_attrs->'dupChecking') = 'array') THEN
        PERFORM reclada_object.refresh_mv('uniFields');
    END IF; 
                  
    select v.data 
        FROM reclada.v_active_object v
            WHERE v.obj_id = _obj_id
        into _data;
    PERFORM reclada_notification.send_object_notification('update', _data);
    RETURN _data;
END;
$$;


--
-- Name: update_json(jsonb, jsonb); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.update_json(lobj jsonb, robj jsonb) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE
    AS $$
    DECLARE
        res     jsonb;
        ltype    text;
        rtype    text;
    BEGIN
        ltype := jsonb_typeof(lobj);
        rtype := jsonb_typeof(robj);
        IF (robj IS NULL) THEN
            RETURN lobj;
        END IF;
        IF (lobj IS NULL) THEN
            RETURN robj;
        END IF;
        IF reclada_object.is_equal(lobj,robj) THEN
            RETURN lobj;
        END IF;
        IF (ltype = 'array' and rtype != 'array') THEN
            RETURN lobj || robj;
        END IF;
        IF (ltype != rtype) THEN
            RETURN robj;
        END IF;
        CASE ltype 
        WHEN 'object' THEN
            SELECT jsonb_object_agg(key,val)
            FROM (
                SELECT key, reclada_object.update_json(lval,rval) AS val
                FROM (                     -- Using joining operators compatible with update_json or hash join is obligatory
                    SELECT (a.rec).key as key,
                        (a.rec).value AS lval,
                        (b.rec).value AS rval                                        --    with FULL OUTER JOIN. update_json is compatible only with NESTED LOOPS
                    FROM (SELECT jsonb_each(lobj) AS rec) a         --    so I use LEFT JOIN UNION ALL RIGHT JOIN insted of FULL OUTER JOIN.
                    LEFT JOIN
                        (SELECT jsonb_each(robj) AS rec) b
                    ON (a.rec).key = (b.rec).key
                UNION
                    SELECT (a.rec).key as key,
                        (b.rec).value AS lval,
                        (a.rec).value AS rval
                    FROM (SELECT jsonb_each(robj) AS rec) a
                    LEFT JOIN
                        (SELECT jsonb_each(lobj) AS rec) b
                    ON (a.rec).key = (b.rec).key
                ) a
            ) b
                INTO res;
            RETURN res;
        WHEN 'array' THEN
            RETURN robj;
        WHEN 'string' THEN
            RETURN robj;
        WHEN 'number' THEN
            RETURN robj;
        WHEN 'boolean' THEN
            RETURN robj;
        WHEN 'null' THEN
            RETURN 'null'::jsonb;   
        ELSE
            RETURN null;
        END CASE;
    END;
$$;


--
-- Name: update_json_by_guid(uuid, jsonb); Type: FUNCTION; Schema: reclada_object; Owner: -
--

CREATE FUNCTION reclada_object.update_json_by_guid(lobj uuid, robj jsonb) RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
    SELECT reclada_object.update_json(data, robj)
    FROM reclada.v_active_object
    WHERE obj_id = lobj;
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


--
-- Name: ##; Type: OPERATOR; Schema: reclada; Owner: -
--

CREATE OPERATOR reclada.## (
    FUNCTION = reclada.xor,
    LEFTARG = boolean,
    RIGHTARG = boolean
);


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
-- Name: draft; Type: TABLE; Schema: reclada; Owner: -
--

CREATE TABLE reclada.draft (
    id bigint NOT NULL,
    guid uuid NOT NULL,
    user_guid uuid DEFAULT reclada_object.get_default_user_obj_id(),
    data jsonb NOT NULL,
    parent_guid uuid
);


--
-- Name: draft_id_seq; Type: SEQUENCE; Schema: reclada; Owner: -
--

ALTER TABLE reclada.draft ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME reclada.draft_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
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
    guid uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    parent_guid uuid
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
 SELECT t.id,
    t.guid AS obj_id,
    t.class,
    ( SELECT ((r.attributes ->> 'num'::text))::bigint AS num
           FROM reclada.object r
          WHERE ((r.class IN ( SELECT reclada_object.get_guid_for_class('revision'::text) AS get_guid_for_class)) AND (r.guid = (NULLIF((t.attributes ->> 'revision'::text), ''::text))::uuid))
         LIMIT 1) AS revision_num,
    os.caption AS status_caption,
    (NULLIF((t.attributes ->> 'revision'::text), ''::text))::uuid AS revision,
    t.created_time,
    t.attributes AS attrs,
    cl.for_class AS class_name,
    (( SELECT (json_agg(tmp.*) -> 0)
           FROM ( SELECT t.guid AS "GUID",
                    t.class,
                    os.caption AS status,
                    t.attributes,
                    t.transaction_id AS "transactionID",
                    t.parent_guid AS "parentGUID",
                    t.created_time AS "createdTime") tmp))::jsonb AS data,
    u.login AS login_created_by,
    t.created_by,
    t.status,
    t.transaction_id,
    t.parent_guid
   FROM (((reclada.object t
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
    t.transaction_id,
    t.parent_guid
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
    obj.data,
    obj.parent_guid
   FROM reclada.v_active_object obj
  WHERE (obj.class_name = 'jsonschema'::text);


--
-- Name: v_default_display; Type: VIEW; Schema: reclada; Owner: -
--

CREATE VIEW reclada.v_default_display AS
 SELECT 'string'::text AS json_type,
    '{"caption": "#@#attrname#@#","width": 250,"displayCSS": "#@#attrname#@#"}'::text AS template
UNION
 SELECT 'number'::text AS json_type,
    '{"caption": "#@#attrname#@#","width": 250,"displayCSS": "#@#attrname#@#"}'::text AS template
UNION
 SELECT 'boolean'::text AS json_type,
    '{"caption": "#@#attrname#@#","width": 250,"displayCSS": "#@#attrname#@#"}'::text AS template
UNION
 SELECT 'ObjectDisplay'::text AS json_type,
    '{
                        "classGUID": null,
                        "caption": "#@#classname#@#",
                        "table": {
                            "{status}:string":{
                                "caption": "Status",
                                "width": 250,
                                "displayCSS": "status"
                            },
                            "{createdTime}:string":{
                                "caption": "Created time",
                                "width": 250,
                                "displayCSS": "createdTime"
                            },
                            "{transactionID}:number":{
                                "caption": "Transaction",
                                "width": 250,
                                "displayCSS": "transactionID"
                            },
                            "{GUID}:string":{
                                "caption": "GUID",
                                "width": 250,
                                "displayCSS": "GUID"
                            },
                            "orderRow": [
                                {"{transactionID}:number":"DESC"}
                            ],
                            "orderColumn": []
                        },
                        "card":{
                            "{status}:string":{
                                "caption": "Status",
                                "width": 250,
                                "displayCSS": "status"
                            },
                            "{createdTime}:string":{
                                "caption": "Created time",
                                "width": 250,
                                "displayCSS": "createdTime"
                            },
                            "{transactionID}:number":{
                                "caption": "Transaction",
                                "width": 250,
                                "displayCSS": "transactionID"
                            },
                            "{GUID}:string":{
                                "caption": "GUID",
                                "width": 250,
                                "displayCSS": "GUID"
                            },
                            "orderRow": [
                                {"{transactionID}:number":"DESC"}
                            ],
                            "orderColumn": []
                        },
                        "preview":{
                            "{status}:string":{
                                "caption": "Status",
                                "width": 250,
                                "displayCSS": "status"
                            },
                            "{createdTime}:string":{
                                "caption": "Created time",
                                "width": 250,
                                "displayCSS": "createdTime"
                            },
                            "{transactionID}:number":{
                                "caption": "Transaction",
                                "width": 250,
                                "displayCSS": "transactionID"
                            },
                            "{GUID}:string":{
                                "caption": "GUID",
                                "width": 250,
                                "displayCSS": "GUID"
                            },
                            "orderRow": [
                                {"{transactionID}:number":"DESC"}
                            ],
                            "orderColumn": []
                        },
                        "list":{
                            "{status}:string":{
                                "caption": "Status",
                                "width": 250,
                                "displayCSS": "status"
                            },
                            "{createdTime}:string":{
                                "caption": "Created time",
                                "width": 250,
                                "displayCSS": "createdTime"
                            },
                            "{transactionID}:number":{
                                "caption": "Transaction",
                                "width": 250,
                                "displayCSS": "transactionID"
                            },
                            "{GUID}:string":{
                                "caption": "GUID",
                                "width": 250,
                                "displayCSS": "GUID"
                            },
                            "orderRow": [
                                {"{transactionID}:number":"DESC"}
                            ],
                            "orderColumn": []
                        }
                        
                    }'::text AS template;


--
-- Name: v_dto_json_schema; Type: VIEW; Schema: reclada; Owner: -
--

CREATE VIEW reclada.v_dto_json_schema AS
 SELECT obj.id,
    obj.obj_id,
    (obj.attrs ->> 'function'::text) AS function,
    (obj.attrs -> 'schema'::text) AS schema,
    obj.revision_num,
    obj.status_caption,
    obj.revision,
    obj.created_time,
    obj.attrs,
    obj.status,
    obj.data,
    obj.parent_guid
   FROM reclada.v_active_object obj
  WHERE (obj.class_name = 'DTOJsonSchema'::text);


--
-- Name: v_filter_available_operator; Type: VIEW; Schema: reclada; Owner: -
--

CREATE VIEW reclada.v_filter_available_operator AS
 SELECT ' = '::text AS operator,
    'JSONB'::text AS input_type,
    'BOOL'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' LIKE '::text AS operator,
    'TEXT'::text AS input_type,
    'BOOL'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' NOT LIKE '::text AS operator,
    'TEXT'::text AS input_type,
    'BOOL'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' || '::text AS operator,
    'TEXT'::text AS input_type,
    'TEXT'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' ~ '::text AS operator,
    'TEXT'::text AS input_type,
    'BOOL'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' !~ '::text AS operator,
    'TEXT'::text AS input_type,
    'BOOL'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' ~* '::text AS operator,
    'TEXT'::text AS input_type,
    'BOOL'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' !~* '::text AS operator,
    'TEXT'::text AS input_type,
    'BOOL'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' SIMILAR TO '::text AS operator,
    'TEXT'::text AS input_type,
    'BOOL'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' > '::text AS operator,
    'JSONB'::text AS input_type,
    'BOOL'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' < '::text AS operator,
    'JSONB'::text AS input_type,
    'BOOL'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' <= '::text AS operator,
    'JSONB'::text AS input_type,
    'BOOL'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' != '::text AS operator,
    'JSONB'::text AS input_type,
    'BOOL'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' >= '::text AS operator,
    'JSONB'::text AS input_type,
    'BOOL'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' AND '::text AS operator,
    'BOOL'::text AS input_type,
    'BOOL'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' OR '::text AS operator,
    'BOOL'::text AS input_type,
    'BOOL'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' NOT '::text AS operator,
    'BOOL'::text AS input_type,
    'BOOL'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' XOR '::text AS operator,
    'BOOL'::text AS input_type,
    'BOOL'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' OPERATOR(reclada.##) '::text AS operator,
    'BOOL'::text AS input_type,
    'BOOL'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' IS '::text AS operator,
    'JSONB'::text AS input_type,
    'BOOL'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' IS NOT '::text AS operator,
    'JSONB'::text AS input_type,
    'BOOL'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' IN '::text AS operator,
    'JSONB'::text AS input_type,
    'BOOL'::text AS output_type,
    ' , '::text AS inner_operator
UNION
 SELECT ' @> '::text AS operator,
    'JSONB'::text AS input_type,
    'BOOL'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' <@ '::text AS operator,
    'JSONB'::text AS input_type,
    'BOOL'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' + '::text AS operator,
    'NUMERIC'::text AS input_type,
    'NUMERIC'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' - '::text AS operator,
    'NUMERIC'::text AS input_type,
    'NUMERIC'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' * '::text AS operator,
    'NUMERIC'::text AS input_type,
    'NUMERIC'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' / '::text AS operator,
    'NUMERIC'::text AS input_type,
    'NUMERIC'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' % '::text AS operator,
    'NUMERIC'::text AS input_type,
    'NUMERIC'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' ^ '::text AS operator,
    'NUMERIC'::text AS input_type,
    'NUMERIC'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' |/ '::text AS operator,
    'NUMERIC'::text AS input_type,
    'NUMERIC'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' ||/ '::text AS operator,
    'NUMERIC'::text AS input_type,
    'NUMERIC'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' !! '::text AS operator,
    'INT'::text AS input_type,
    'NUMERIC'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' @ '::text AS operator,
    'NUMERIC'::text AS input_type,
    'NUMERIC'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' & '::text AS operator,
    'INT'::text AS input_type,
    'INT'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' | '::text AS operator,
    'INT'::text AS input_type,
    'INT'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' # '::text AS operator,
    'INT'::text AS input_type,
    'INT'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' << '::text AS operator,
    'INT'::text AS input_type,
    'INT'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' >> '::text AS operator,
    'INT'::text AS input_type,
    'INT'::text AS output_type,
    NULL::text AS inner_operator
UNION
 SELECT ' BETWEEN '::text AS operator,
    'TIMESTAMP WITH TIME ZONE'::text AS input_type,
    'BOOL'::text AS output_type,
    ' AND '::text AS inner_operator
UNION
 SELECT ' Y/BETWEEN '::text AS operator,
    NULL::text AS input_type,
    NULL::text AS output_type,
    ' AND '::text AS inner_operator
UNION
 SELECT ' MON/BETWEEN '::text AS operator,
    NULL::text AS input_type,
    NULL::text AS output_type,
    ' AND '::text AS inner_operator
UNION
 SELECT ' D/BETWEEN '::text AS operator,
    NULL::text AS input_type,
    NULL::text AS output_type,
    ' AND '::text AS inner_operator
UNION
 SELECT ' H/BETWEEN '::text AS operator,
    NULL::text AS input_type,
    NULL::text AS output_type,
    ' AND '::text AS inner_operator
UNION
 SELECT ' MIN/BETWEEN '::text AS operator,
    NULL::text AS input_type,
    NULL::text AS output_type,
    ' AND '::text AS inner_operator
UNION
 SELECT ' S/BETWEEN '::text AS operator,
    NULL::text AS input_type,
    NULL::text AS output_type,
    ' AND '::text AS inner_operator
UNION
 SELECT ' DOW/BETWEEN '::text AS operator,
    NULL::text AS input_type,
    NULL::text AS output_type,
    ' AND '::text AS inner_operator
UNION
 SELECT ' DOY/BETWEEN '::text AS operator,
    NULL::text AS input_type,
    NULL::text AS output_type,
    ' AND '::text AS inner_operator
UNION
 SELECT ' Q/BETWEEN '::text AS operator,
    NULL::text AS input_type,
    NULL::text AS output_type,
    ' AND '::text AS inner_operator
UNION
 SELECT ' W/BETWEEN '::text AS operator,
    NULL::text AS input_type,
    NULL::text AS output_type,
    ' AND '::text AS inner_operator;


--
-- Name: v_filter_between; Type: VIEW; Schema: reclada; Owner: -
--

CREATE VIEW reclada.v_filter_between AS
 SELECT ' Y/BETWEEN '::text AS operator,
    'date_part(''YEAR''   , TIMESTAMP WITH TIME ZONE %s)'::text AS operand_format
UNION
 SELECT ' MON/BETWEEN '::text AS operator,
    'date_part(''MONTH''  , TIMESTAMP WITH TIME ZONE %s)'::text AS operand_format
UNION
 SELECT ' D/BETWEEN '::text AS operator,
    'date_part(''DAY''    , TIMESTAMP WITH TIME ZONE %s)'::text AS operand_format
UNION
 SELECT ' H/BETWEEN '::text AS operator,
    'date_part(''HOUR''   , TIMESTAMP WITH TIME ZONE %s)'::text AS operand_format
UNION
 SELECT ' MIN/BETWEEN '::text AS operator,
    'date_part(''MINUTE'' , TIMESTAMP WITH TIME ZONE %s)'::text AS operand_format
UNION
 SELECT ' S/BETWEEN '::text AS operator,
    'date_part(''SECOND'' , TIMESTAMP WITH TIME ZONE %s)::int'::text AS operand_format
UNION
 SELECT ' DOW/BETWEEN '::text AS operator,
    'date_part(''DOW''    , TIMESTAMP WITH TIME ZONE %s)'::text AS operand_format
UNION
 SELECT ' DOY/BETWEEN '::text AS operator,
    'date_part(''DOY''    , TIMESTAMP WITH TIME ZONE %s)'::text AS operand_format
UNION
 SELECT ' Q/BETWEEN '::text AS operator,
    'date_part(''QUARTER'', TIMESTAMP WITH TIME ZONE %s)'::text AS operand_format
UNION
 SELECT ' W/BETWEEN '::text AS operator,
    'date_part(''WEEK''   , TIMESTAMP WITH TIME ZONE %s)'::text AS operand_format;


--
-- Name: v_filter_inner_operator; Type: VIEW; Schema: reclada; Owner: -
--

CREATE VIEW reclada.v_filter_inner_operator AS
 SELECT ' , '::text AS operator,
    'JSONB'::text AS input_type,
    true AS brackets
UNION
 SELECT ' AND '::text AS operator,
    'TIMESTAMP WITH TIME ZONE'::text AS input_type,
    false AS brackets;


--
-- Name: v_filter_mapping; Type: VIEW; Schema: reclada; Owner: -
--

CREATE VIEW reclada.v_filter_mapping AS
 SELECT '{class}'::text AS pattern,
    'class_name'::text AS repl;


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
-- Name: v_object_display; Type: VIEW; Schema: reclada; Owner: -
--

CREATE VIEW reclada.v_object_display AS
 SELECT obj.id,
    obj.guid,
    ((obj.attributes ->> 'classGUID'::text))::uuid AS class_guid,
    (obj.attributes ->> 'caption'::text) AS caption,
    (obj.attributes -> 'table'::text) AS "table",
    (obj.attributes -> 'card'::text) AS card,
    (obj.attributes -> 'preview'::text) AS preview,
    (obj.attributes -> 'list'::text) AS list,
    obj.created_time,
    obj.attributes,
    obj.status
   FROM reclada.object obj
  WHERE ((obj.class = ( SELECT reclada_object.get_guid_for_class('ObjectDisplay'::text) AS get_guid_for_class)) AND (obj.status = reclada_object.get_active_status_obj_id()));


--
-- Name: v_object_unifields; Type: MATERIALIZED VIEW; Schema: reclada; Owner: -
--

CREATE MATERIALIZED VIEW reclada.v_object_unifields AS
 SELECT b.for_class,
    b.class_uuid,
    (b.dup_behavior)::reclada.dp_bhvr AS dup_behavior,
    b.is_cascade,
    b.is_mandatory,
    b.uf AS unifield,
    b.uni_number,
    row_number() OVER (PARTITION BY b.for_class, b.uni_number ORDER BY b.uf) AS field_number,
    b.copy_field
   FROM ( SELECT a.for_class,
            a.obj_id AS class_uuid,
            a.dup_behavior,
            (a.is_cascade)::boolean AS is_cascade,
            ((a.dc ->> 'isMandatory'::text))::boolean AS is_mandatory,
            jsonb_array_elements_text((a.dc -> 'uniFields'::text)) AS uf,
            (a.dc -> 'uniFields'::text) AS field_list,
            row_number() OVER (PARTITION BY a.for_class ORDER BY (a.dc -> 'uniFields'::text)) AS uni_number,
            a.copy_field
           FROM ( SELECT vc.for_class,
                    (vc.attributes ->> 'dupBehavior'::text) AS dup_behavior,
                    (vc.attributes ->> 'isCascade'::text) AS is_cascade,
                    jsonb_array_elements((vc.attributes -> 'dupChecking'::text)) AS dc,
                    vc.obj_id,
                    (vc.attributes ->> 'copyField'::text) AS copy_field
                   FROM reclada.v_class_lite vc
                  WHERE ((vc.attributes -> 'dupChecking'::text) IS NOT NULL)) a) b
  WITH NO DATA;


--
-- Name: v_parent_field; Type: VIEW; Schema: reclada; Owner: -
--

CREATE VIEW reclada.v_parent_field AS
 SELECT v_class.for_class,
    v_class.obj_id AS class_uuid,
    (v_class.attributes ->> 'parentField'::text) AS parent_field
   FROM reclada.v_class_lite v_class
  WHERE ((v_class.attributes ->> 'parentField'::text) IS NOT NULL);


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
-- Name: v_task; Type: VIEW; Schema: reclada; Owner: -
--

CREATE VIEW reclada.v_task AS
 SELECT obj.id,
    obj.obj_id AS guid,
    (obj.attrs ->> 'type'::text) AS type,
    (obj.attrs ->> 'command'::text) AS command,
    obj.revision_num,
    obj.status_caption,
    obj.revision,
    obj.created_time,
    obj.attrs,
    obj.status,
    obj.data
   FROM reclada.v_active_object obj
  WHERE (obj.class_name = 'Task'::text);


--
-- Name: v_ui_active_object; Type: VIEW; Schema: reclada; Owner: -
--

CREATE VIEW reclada.v_ui_active_object AS
 SELECT 'with recursive 
d as ( 
    select  data, 
            obj_id
        FROM reclada.v_active_object obj 
            where #@#@#where#@#@#
),
t as
(
    SELECT  je.key,
            1 as q,
            jsonb_typeof(je.value) typ,
            d.obj_id,
            je.value
        from d 
        JOIN LATERAL jsonb_each(d.data) je
            on true
        where jsonb_typeof(je.value) != ''null''
    union
    SELECT 
            d.key ||'',''|| je.key as key ,
            d.q,
            jsonb_typeof(je.value) typ,
            d.obj_id,
            je.value
        from (
            select  d.data #> (''{''||t.key||''}'')::text[] as data, 
                    t.q+1 as q,
                    t.key,
                    d.obj_id
            from t 
            join d
                on t.typ = ''object''
        ) d
        JOIN LATERAL jsonb_each(d.data) je
            on true
        where jsonb_typeof(je.value) != ''null''
),
res as
(
    select  rr.obj_id,
            rr.data,
            rr.display_key,
            o.attrs,
            o.created_time
        from
        (
            select  t.obj_id,
                    jsonb_object_agg
                    (
                        ''{''||t.key||''}'',
                        t.value
                    ) as data,
                    array_agg(
                        ''{''||t.key||''}:''||t.typ 
                    ) as display_key
                from t 
                    where t.typ != ''object''
                    group by t.obj_id
        ) rr
        join reclada.v_active_object o
            on o.obj_id = rr.obj_id
)
'::text AS val;


--
-- Name: v_unifields_pivoted; Type: VIEW; Schema: reclada; Owner: -
--

CREATE VIEW reclada.v_unifields_pivoted AS
 SELECT vou.class_uuid,
    vou.uni_number,
    vou.dup_behavior,
    vou.is_cascade,
    vou.copy_field,
    max(
        CASE
            WHEN (vou.field_number = 1) THEN vou.unifield
            ELSE NULL::text
        END) AS f1,
    max(
        CASE
            WHEN (vou.field_number = 2) THEN vou.unifield
            ELSE NULL::text
        END) AS f2,
    max(
        CASE
            WHEN (vou.field_number = 3) THEN vou.unifield
            ELSE NULL::text
        END) AS f3,
    max(
        CASE
            WHEN (vou.field_number = 4) THEN vou.unifield
            ELSE NULL::text
        END) AS f4,
    max(
        CASE
            WHEN (vou.field_number = 5) THEN vou.unifield
            ELSE NULL::text
        END) AS f5,
    max(
        CASE
            WHEN (vou.field_number = 6) THEN vou.unifield
            ELSE NULL::text
        END) AS f6,
    max(
        CASE
            WHEN (vou.field_number = 7) THEN vou.unifield
            ELSE NULL::text
        END) AS f7,
    max(
        CASE
            WHEN (vou.field_number = 8) THEN vou.unifield
            ELSE NULL::text
        END) AS f8
   FROM reclada.v_object_unifields vou
  WHERE vou.is_mandatory
  GROUP BY vou.class_uuid, vou.uni_number, vou.dup_behavior, vou.is_cascade, vou.copy_field
  ORDER BY vou.class_uuid, vou.uni_number, vou.dup_behavior;


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
38	37	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect reclada.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 37 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/api.storage_generate_presigned_get.sql'\ni 'function/api.storage_generate_presigned_post.sql'\ni 'function/reclada_object.list_drop.sql'\ni 'api.reclada_object_list_drop.sql'\ni 'function/reclada_object.get_query_condition_filter.sql'\ni 'function/reclada_object.list.sql'\n\ni 'function/reclada_object.get_condition_array.sql'\ni 'function/reclada_object.get_query_condition.sql'\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\n\nDROP function IF EXISTS api.storage_generate_presigned_post ;\nCREATE OR REPLACE FUNCTION api.storage_generate_presigned_post(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    lambda_name  varchar;\r\n    file_type    varchar;\r\n    object       jsonb;\r\n    object_id    uuid;\r\n    object_name  varchar;\r\n    object_path  varchar;\r\n    result       jsonb;\r\n    user_info    jsonb;\r\n    uri          varchar;\r\n    url          varchar;\r\n\r\nBEGIN\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned post', ''))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';\r\n    END IF;\r\n\r\n    object_name := data->>'objectName';\r\n    file_type := data->>'fileType';\r\n\r\n    SELECT attrs->>'Lambda'\r\n    FROM reclada.v_active_object\r\n    WHERE class_name = 'Context'\r\n    ORDER BY created_time DESC\r\n    LIMIT 1\r\n    INTO lambda_name;\r\n\r\n    SELECT payload::jsonb\r\n    FROM aws_lambda.invoke(\r\n        aws_commons.create_lambda_function_arn(\r\n                format('%s', lambda_name),\r\n                'eu-west-1'\r\n        ),\r\n        format('{\r\n            "type": "post",\r\n            "fileName": "%s",\r\n            "fileType": "%s",\r\n            "fileSize": "%s",\r\n            "expiration": 3600}',\r\n            object_name,\r\n            file_type,\r\n            data->>'fileSize'\r\n            )::jsonb)\r\n    INTO url;\r\n\r\n    result = format(\r\n        '{"uploadUrl": %s}',\r\n        url\r\n    )::jsonb;\r\n\r\n    RETURN result;\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS api.storage_generate_presigned_get ;\nCREATE OR REPLACE FUNCTION api.storage_generate_presigned_get(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    object_data  jsonb;\r\n    object_id    uuid;\r\n    result       jsonb;\r\n    user_info    jsonb;\r\n    lambda_name  varchar;\r\n\r\nBEGIN\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned get', ''))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned get';\r\n    END IF;\r\n\r\n    -- TODO: check user's permissions for reclada object access?\r\n    object_id := data->>'objectId';\r\n    SELECT reclada_object.list(format(\r\n        '{"class": "File", "attributes": {}, "GUID": "%s"}',\r\n        object_id\r\n    )::jsonb) -> 0 INTO object_data;\r\n\r\n    SELECT attrs->>'Lambda'\r\n    FROM reclada.v_active_object\r\n    WHERE class_name = 'Context'\r\n    ORDER BY created_time DESC\r\n    LIMIT 1\r\n    INTO lambda_name;\r\n\r\n    SELECT payload\r\n    FROM aws_lambda.invoke(\r\n        aws_commons.create_lambda_function_arn(\r\n            format('%s', lambda_name),\r\n            'eu-west-1'\r\n            ),\r\n        format('{\r\n            "type": "get",\r\n            "uri": "%s",\r\n            "expiration": 3600}',\r\n            object_data->'attributes'->>'uri'\r\n            )::jsonb)\r\n    INTO result;\r\n\r\n    RETURN result;\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.list_drop ;\nCREATE OR REPLACE FUNCTION reclada_object.list_drop(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    class           text;\r\n    objid           uuid;\r\n    obj             jsonb;\r\n    values_to_drop  jsonb;\r\n    field           text;\r\n    field_value     jsonb;\r\n    json_path       text[];\r\n    new_value       jsonb;\r\n    new_obj         jsonb;\r\n    res             jsonb;\r\n\r\nBEGIN\r\n\r\n\tclass := data->>'class';\r\n\tIF (class IS NULL) THEN\r\n\t\tRAISE EXCEPTION 'The reclada object class is not specified';\r\n\tEND IF;\r\n\r\n\tobjid := (data->>'GUID')::uuid;\r\n\tIF (objid IS NULL) THEN\r\n\t\tRAISE EXCEPTION 'The is no GUID';\r\n\tEND IF;\r\n\r\n    SELECT v.data\r\n    FROM reclada.v_active_object v\r\n    WHERE v.obj_id = objid\r\n    INTO obj;\r\n\r\n\tIF (obj IS NULL) THEN\r\n\t\tRAISE EXCEPTION 'The is no object with such id';\r\n\tEND IF;\r\n\r\n\tvalues_to_drop := data->'value';\r\n\tIF (values_to_drop IS NULL OR values_to_drop = 'null'::jsonb) THEN\r\n\t\tRAISE EXCEPTION 'The value should not be null';\r\n\tEND IF;\r\n\r\n\tIF (jsonb_typeof(values_to_drop) != 'array') THEN\r\n\t\tvalues_to_drop := format('[%s]', values_to_drop)::jsonb;\r\n\tEND IF;\r\n\r\n\tfield := data->>'field';\r\n\tIF (field IS NULL) THEN\r\n\t\tRAISE EXCEPTION 'There is no field';\r\n\tEND IF;\r\n\tjson_path := format('{attributes, %s}', field);\r\n\tfield_value := obj#>json_path;\r\n\tIF (field_value IS NULL OR field_value = 'null'::jsonb) THEN\r\n\t\tRAISE EXCEPTION 'The object does not have this field';\r\n\tEND IF;\r\n\r\n\tSELECT jsonb_agg(elems)\r\n\tFROM\r\n\t\tjsonb_array_elements(field_value) elems\r\n\tWHERE\r\n\t\telems NOT IN (\r\n\t\t\tSELECT jsonb_array_elements(values_to_drop))\r\n\tINTO new_value;\r\n\r\n\tSELECT jsonb_set(obj, json_path, coalesce(new_value, '[]'::jsonb))\r\n\tINTO new_obj;\r\n\r\n\tSELECT reclada_object.update(new_obj) INTO res;\r\n\tRETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS api.reclada_object_list_drop ;\nCREATE OR REPLACE FUNCTION api.reclada_object_list_drop(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    class           text;\r\n    obj_id          uuid;\r\n    user_info       jsonb;\r\n    field_value     jsonb;\r\n    values_to_drop  jsonb;\r\n    result          jsonb;\r\n\r\nBEGIN\r\n\r\n\tclass := data->>'class';\r\n\tIF (class IS NULL) THEN\r\n\t\tRAISE EXCEPTION 'The reclada object class is not specified';\r\n\tEND IF;\r\n\r\n\tobj_id := (data->>'GUID')::uuid;\r\n\tIF (obj_id IS NULL) THEN\r\n\t\tRAISE EXCEPTION 'The is no GUID';\r\n\tEND IF;\r\n\r\n\tfield_value := data->'field';\r\n\tIF (field_value IS NULL OR field_value = 'null'::jsonb) THEN\r\n\t\tRAISE EXCEPTION 'There is no field';\r\n\tEND IF;\r\n\r\n\tvalues_to_drop := data->'value';\r\n\tIF (values_to_drop IS NULL OR values_to_drop = 'null'::jsonb) THEN\r\n\t\tRAISE EXCEPTION 'The value should not be null';\r\n\tEND IF;\r\n\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF (NOT(reclada_user.is_allowed(user_info, 'list_add', class))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'list_add', class;\r\n    END IF;\r\n\r\n    SELECT reclada_object.list_drop(data) INTO result;\r\n    RETURN result;\r\n\r\nEND;\r\n$function$\n;\n\nDROP function IF EXISTS reclada_object.list ;\nCREATE OR REPLACE FUNCTION reclada_object.list(data jsonb, gui boolean DEFAULT false)\n RETURNS jsonb\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    class               text;\r\n    attrs               jsonb;\r\n    order_by_jsonb      jsonb;\r\n    order_by            text;\r\n    limit_              text;\r\n    offset_             text;\r\n    query_conditions    text;\r\n    number_of_objects   int;\r\n    objects             jsonb;\r\n    res                 jsonb;\r\n    query               text;\r\n    class_uuid          uuid;\r\n    last_change         text;\r\n    tran_id             bigint;\r\nBEGIN\r\n\r\n    tran_id := (data->>'transactionID')::bigint;\r\n    class := data->>'class';\r\n    IF (class IS NULL and tran_id IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object class and transactionID are not specified';\r\n    END IF;\r\n    class_uuid := reclada.try_cast_uuid(class);\r\n\r\n    if class_uuid is not null then\r\n        select v.for_class \r\n            from reclada.v_class_lite v\r\n                where class_uuid = v.obj_id\r\n        into class;\r\n\r\n        IF (class IS NULL) THEN\r\n            RAISE EXCEPTION 'Class not found by GUID: %', class_uuid::text;\r\n        END IF;\r\n    end if;\r\n\r\n    attrs := data->'attributes' || '{}'::jsonb;\r\n\r\n    order_by_jsonb := data->'orderBy';\r\n    IF ((order_by_jsonb IS NULL) OR\r\n        (order_by_jsonb = 'null'::jsonb) OR\r\n        (order_by_jsonb = '[]'::jsonb)) THEN\r\n        order_by_jsonb := '[{"field": "GUID", "order": "ASC"}]'::jsonb;\r\n    END IF;\r\n    IF (jsonb_typeof(order_by_jsonb) != 'array') THEN\r\n    \t\torder_by_jsonb := format('[%s]', order_by_jsonb);\r\n    END IF;\r\n    SELECT string_agg(\r\n        format(E'obj.data#>''{%s}'' %s', T.value->>'field', COALESCE(T.value->>'order', 'ASC')),\r\n        ' , ')\r\n    FROM jsonb_array_elements(order_by_jsonb) T\r\n    INTO order_by;\r\n\r\n    limit_ := data->>'limit';\r\n    IF (limit_ IS NULL) THEN\r\n        limit_ := 500;\r\n    END IF;\r\n    IF ((limit_ ~ '(\\D+)') AND (limit_ != 'ALL')) THEN\r\n    \t\tRAISE EXCEPTION 'The limit must be an integer number or "ALL"';\r\n    END IF;\r\n\r\n    offset_ := data->>'offset';\r\n    IF (offset_ IS NULL) THEN\r\n        offset_ := 0;\r\n    END IF;\r\n    IF (offset_ ~ '(\\D+)') THEN\r\n    \t\tRAISE EXCEPTION 'The offset must be an integer number';\r\n    END IF;\r\n\r\n    SELECT\r\n        string_agg(\r\n            format(\r\n                E'(%s)',\r\n                condition\r\n            ),\r\n            ' AND '\r\n        )\r\n        FROM (\r\n            SELECT\r\n                format('obj.class_name = ''%s''', class) AS condition\r\n                    where class is not null \r\n                        and class_uuid is null\r\n            UNION\r\n                SELECT format('obj.class = ''%s''', class_uuid) AS condition\r\n                    where class_uuid is not null\r\n            UNION\r\n                SELECT format('obj.transaction_id = %s', tran_id) AS condition\r\n                    where tran_id is not null\r\n            UNION \r\n                SELECT CASE\r\n                        WHEN jsonb_typeof(data->'GUID') = 'array' THEN\r\n                        (\r\n                            SELECT string_agg\r\n                                (\r\n                                    format(\r\n                                        E'(%s)',\r\n                                        reclada_object.get_query_condition(cond, E'data->''GUID''') -- TODO: change data->'GUID' to obj_id(GUID)\r\n                                    ),\r\n                                    ' AND '\r\n                                )\r\n                                FROM jsonb_array_elements(data->'GUID') AS cond\r\n                        )\r\n                        ELSE reclada_object.get_query_condition(data->'GUID', E'data->''GUID''') -- TODO: change data->'GUID' to obj_id(GUID)\r\n                    END AS condition\r\n                WHERE coalesce(data->'GUID','null'::jsonb) != 'null'::jsonb\r\n            UNION\r\n            SELECT\r\n                CASE\r\n                    WHEN jsonb_typeof(value) = 'array'\r\n                        THEN\r\n                            (\r\n                                SELECT string_agg\r\n                                    (\r\n                                        format\r\n                                        (\r\n                                            E'(%s)',\r\n                                            reclada_object.get_query_condition(cond, format(E'attrs->%L', key))\r\n                                        ),\r\n                                        ' AND '\r\n                                    )\r\n                                    FROM jsonb_array_elements(value) AS cond\r\n                            )\r\n                    ELSE reclada_object.get_query_condition(value, format(E'attrs->%L', key))\r\n                END AS condition\r\n            FROM jsonb_each(attrs)\r\n            WHERE attrs != ('{}'::jsonb)\r\n        ) conds\r\n    INTO query_conditions;\r\n\r\n    -- RAISE NOTICE 'conds: %', '\r\n    --             SELECT obj.data\r\n    --             FROM reclada.v_object obj\r\n    --             WHERE ' || query_conditions ||\r\n    --             ' ORDER BY ' || order_by ||\r\n    --             ' OFFSET ' || offset_ || ' LIMIT ' || limit_ ;\r\n    query := 'FROM reclada.v_active_object obj WHERE ' || query_conditions;\r\n    --raise notice 'query: %', query;\r\n    EXECUTE E'SELECT to_jsonb(array_agg(T.data))\r\n        FROM (\r\n            SELECT obj.data\r\n            '\r\n            || query\r\n            ||\r\n            ' ORDER BY ' || order_by ||\r\n            ' OFFSET ' || offset_ || ' LIMIT ' || limit_ || ') T'\r\n    INTO objects;\r\n    IF gui THEN\r\n\r\n        EXECUTE E'SELECT count(1)\r\n        '|| query\r\n        INTO number_of_objects;\r\n\r\n        EXECUTE E'SELECT TO_CHAR(\r\n\tMAX(\r\n\t\tGREATEST(obj.created_time, (\r\n\t\t\tSELECT TO_TIMESTAMP(MAX(date_time),\\'YYYY-MM-DD hh24:mi:ss.US TZH\\')\r\n\t\t\tFROM reclada.v_revision vr\r\n\t\t\tWHERE vr.obj_id = UUID(obj.attrs ->>\\'revision\\'))\r\n\t\t)\r\n\t),\\'YYYY-MM-DD hh24:mi:ss.MS TZH\\')\r\n        '|| query\r\n        INTO last_change;\r\n\r\n        res := jsonb_build_object(\r\n        'last_change', last_change,    \r\n        'number', number_of_objects,\r\n        'objects', objects);\r\n    ELSE\r\n        res := objects;\r\n    END IF;\r\n\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.get_query_condition_filter ;\n\n\nDROP function IF EXISTS reclada_object.get_condition_array ;\nCREATE OR REPLACE FUNCTION reclada_object.get_condition_array(data jsonb, key_path text)\n RETURNS text\n LANGUAGE sql\n IMMUTABLE\nAS $function$\r\n    SELECT\r\n    CONCAT(\r\n        key_path,\r\n        ' ', COALESCE(data->>'operator', '='), ' ',\r\n        format(E'\\'%s\\'::jsonb', data->'object'#>>'{}'))\r\n$function$\n;\nDROP function IF EXISTS reclada_object.get_query_condition ;\nCREATE OR REPLACE FUNCTION reclada_object.get_query_condition(data jsonb, key_path text)\n RETURNS text\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    key          text;\r\n    operator     text;\r\n    value        text;\r\n    res          text;\r\n\r\nBEGIN\r\n    IF (data IS NULL OR data = 'null'::jsonb) THEN\r\n        RAISE EXCEPTION 'There is no condition';\r\n    END IF;\r\n\r\n    IF (jsonb_typeof(data) = 'object') THEN\r\n\r\n        IF (data->'object' IS NULL OR data->'object' = ('null'::jsonb)) THEN\r\n            RAISE EXCEPTION 'There is no object field';\r\n        END IF;\r\n\r\n        IF (jsonb_typeof(data->'object') = 'object') THEN\r\n            operator :=  data->>'operator';\r\n            IF operator = '=' then\r\n                key := reclada_object.cast_jsonb_to_postgres(key_path, 'string' );\r\n                RETURN (key || ' ' || operator || ' ''' || (data->'object')::text || '''');\r\n            ELSE\r\n                RAISE EXCEPTION 'The input_jsonb->''object'' can not contain jsonb object';\r\n            END If;\r\n        END IF;\r\n\r\n        IF (jsonb_typeof(data->'operator') != 'string' AND data->'operator' IS NOT NULL) THEN\r\n            RAISE EXCEPTION 'The input_jsonb->''operator'' must contain string';\r\n        END IF;\r\n\r\n        IF (jsonb_typeof(data->'object') = 'array') THEN\r\n            res := reclada_object.get_condition_array(data, key_path);\r\n        ELSE\r\n            key := reclada_object.cast_jsonb_to_postgres(key_path, jsonb_typeof(data->'object'));\r\n            operator :=  data->>'operator';\r\n            value := reclada_object.jsonb_to_text(data->'object');\r\n            res := key || ' ' || operator || ' ' || value;\r\n        END IF;\r\n    ELSE\r\n        key := reclada_object.cast_jsonb_to_postgres(key_path, jsonb_typeof(data));\r\n        operator := '=';\r\n        value := reclada_object.jsonb_to_text(data);\r\n        res := key || ' ' || operator || ' ' || value;\r\n    END IF;\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;	2021-10-13 15:06:36.060425+00
39	38	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n\t\tupgrade_script text,\n\t\tdowngrade_script text\n    );\n\t\ninsert into var_table(ver)\t\n\tselect max(ver) + 1\n        from dev.VER;\n\t\t\nselect reclada.raise_exception('Can not apply this version!') \n\twhere not exists\n\t(\n\t\tselect ver from var_table where ver = 38 --!!! write current version HERE !!!\n\t);\n\nCREATE TEMP TABLE tmp\n(\n\tid int GENERATED ALWAYS AS IDENTITY,\n\tstr text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n\tfrom tmp ttt\n\tinner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n\tinner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n        \t\tsplit_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n\t\tinner JOIN LATERAL\n    (\n        select case\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t    (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n\tinner JOIN LATERAL\n    (\n        select case \n\t\t\t\twhen obj.typ in ('function', 'procedure')\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tSELECT 1 a\n\t\t\t\t\t\t\t\t\t\tFROM pg_proc p \n\t\t\t\t\t\t\t\t\t\tjoin pg_namespace n \n\t\t\t\t\t\t\t\t\t\t\ton p.pronamespace = n.oid \n\t\t\t\t\t\t\t\t\t\t\twhere n.nspname||'.'||p.proname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'view'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase \n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a \n\t\t\t\t\t\t\t\t\t\tfrom pg_views v \n\t\t\t\t\t\t\t\t\t\t\twhere v.schemaname||'.'||v.viewname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t) \n\t\t\t\t\t\t\t\tthen E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\twhen obj.typ = 'trigger'\n\t\t\t\t\tthen\n\t\t\t\t\t\tcase\n\t\t\t\t\t\t\twhen EXISTS\n\t\t\t\t\t\t\t\t(\n\t\t\t\t\t\t\t\t\tselect 1 a\n\t\t\t\t\t\t\t\t\t\tfrom pg_trigger v\n                                            where v.tgname = obj.nam\n\t\t\t\t\t\t\t\t\t\tLIMIT 1\n\t\t\t\t\t\t\t\t)\n\t\t\t\t\t\t\t\tthen (select pg_catalog.pg_get_triggerdef(oid, true)\n\t\t\t\t\t\t\t\t        from pg_trigger\n\t\t\t\t\t\t\t\t        where tgname = obj.nam)||';'\n\t\t\t\t\t\t\telse ''\n\t\t\t\t\t\tend\n\t\t\t\telse \n\t\t\t\t\tttt.str\n\t\t\tend as v\n    )  scr ON TRUE\n\twhere ttt.id = tmp.id\n\t\tand tmp.str like '--{%/%}';\n\t\nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/api.reclada_object_list_drop.sql'\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n\tselect ver, upgrade_script, downgrade_script\n\t\tfrom var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, curren version: ' \n\t\t\t\t\t\t\t|| (select ver from var_table)::text\n\t\t\t\t\t\t  );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nDROP function IF EXISTS reclada_object.list_drop ;\nCREATE OR REPLACE FUNCTION reclada_object.list_drop(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    class           text;\r\n    objid           uuid;\r\n    obj             jsonb;\r\n    values_to_drop  jsonb;\r\n    field           text;\r\n    field_value     jsonb;\r\n    json_path       text[];\r\n    new_value       jsonb;\r\n    new_obj         jsonb;\r\n    res             jsonb;\r\n\r\nBEGIN\r\n\r\n\tclass := data->>'class';\r\n\tIF (class IS NULL) THEN\r\n\t\tRAISE EXCEPTION 'The reclada object class is not specified';\r\n\tEND IF;\r\n\r\n\tobjid := (data->>'GUID')::uuid;\r\n\tIF (objid IS NULL) THEN\r\n\t\tRAISE EXCEPTION 'There is no GUID';\r\n\tEND IF;\r\n\r\n    SELECT v.data\r\n    FROM reclada.v_active_object v\r\n    WHERE v.obj_id = objid\r\n    INTO obj;\r\n\r\n\tIF (obj IS NULL) THEN\r\n\t\tRAISE EXCEPTION 'There is no object with such id';\r\n\tEND IF;\r\n\r\n\tvalues_to_drop := data->'value';\r\n\tIF (values_to_drop IS NULL OR values_to_drop = 'null'::jsonb) THEN\r\n\t\tRAISE EXCEPTION 'The value should not be null';\r\n\tEND IF;\r\n\r\n\tIF (jsonb_typeof(values_to_drop) != 'array') THEN\r\n\t\tvalues_to_drop := format('[%s]', values_to_drop)::jsonb;\r\n\tEND IF;\r\n\r\n\tfield := data->>'field';\r\n\tIF (field IS NULL) THEN\r\n\t\tRAISE EXCEPTION 'There is no field';\r\n\tEND IF;\r\n\tjson_path := format('{attributes, %s}', field);\r\n\tfield_value := obj#>json_path;\r\n\tIF (field_value IS NULL OR field_value = 'null'::jsonb) THEN\r\n\t\tRAISE EXCEPTION 'The object does not have this field';\r\n\tEND IF;\r\n\r\n\tSELECT jsonb_agg(elems)\r\n\tFROM\r\n\t\tjsonb_array_elements(field_value) elems\r\n\tWHERE\r\n\t\telems NOT IN (\r\n\t\t\tSELECT jsonb_array_elements(values_to_drop))\r\n\tINTO new_value;\r\n\r\n\tSELECT jsonb_set(obj, json_path, coalesce(new_value, '[]'::jsonb))\r\n\tINTO new_obj;\r\n\r\n\tSELECT reclada_object.update(new_obj) INTO res;\r\n\tRETURN res;\r\n\r\nEND;\r\n$function$\n;	2021-10-18 08:58:38.02402+00
40	39	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n        upgrade_script text,\n        downgrade_script text\n    );\n    \ninsert into var_table(ver)\t\n    select max(ver) + 1\n        from dev.VER;\n        \nselect reclada.raise_exception('Can not apply this version!') \n    where not exists\n    (\n        select ver from var_table where ver = 39 --!!! write current version HERE !!!\n    );\n\nCREATE TEMP TABLE tmp\n(\n    id int GENERATED ALWAYS AS IDENTITY,\n    str text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n    from tmp ttt\n    inner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n    inner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n                split_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n        inner JOIN LATERAL\n    (\n        select case\n                when obj.typ = 'trigger'\n                    then\n                        (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n    inner JOIN LATERAL\n    (\n        select case \n                when obj.typ in ('function', 'procedure')\n                    then\n                        case \n                            when EXISTS\n                                (\n                                    SELECT 1 a\n                                        FROM pg_proc p \n                                        join pg_namespace n \n                                            on p.pronamespace = n.oid \n                                            where n.nspname||'.'||p.proname = obj.nam\n                                        LIMIT 1\n                                ) \n                                then (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n                            else ''\n                        end\n                when obj.typ = 'view'\n                    then\n                        case \n                            when EXISTS\n                                (\n                                    select 1 a \n                                        from pg_views v \n                                            where v.schemaname||'.'||v.viewname = obj.nam\n                                        LIMIT 1\n                                ) \n                                then E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n                            else ''\n                        end\n                when obj.typ = 'trigger'\n                    then\n                        case\n                            when EXISTS\n                                (\n                                    select 1 a\n                                        from pg_trigger v\n                                            where v.tgname = obj.nam\n                                        LIMIT 1\n                                )\n                                then (select pg_catalog.pg_get_triggerdef(oid, true)\n                                        from pg_trigger\n                                        where tgname = obj.nam)||';'\n                            else ''\n                        end\n                else \n                    ttt.str\n            end as v\n    )  scr ON TRUE\n    where ttt.id = tmp.id\n        and tmp.str like '--{%/%}';\n    \nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/api.reclada_object_list.sql'\ni 'function/reclada_object.parse_filter.sql'\ni 'function/reclada_object.get_query_condition_filter.sql'\ni 'function/reclada_object.list.sql'\ni 'view/reclada.v_filter_mapping.sql'\n\nALTER TABLE reclada.object ADD COLUMN IF NOT EXISTS parent_guid uuid;\nCREATE INDEX IF NOT EXISTS parent_guid_index ON reclada.object USING btree (parent_guid);\n\ni 'function/reclada_object.update.sql'\ni 'function/reclada_object.datasource_insert.sql'\ni 'function/reclada_object.create.sql'\ni 'function/reclada_object.create_subclass.sql'\ni 'view/reclada.v_object.sql'\ni 'view/reclada.v_active_object.sql'\ni 'view/reclada.v_class.sql'\ni 'function/reclada_object.get_condition_array.sql'\n\nCREATE INDEX IF NOT EXISTS class_lite_obj_idx ON reclada.v_class_lite USING btree (obj_id);\nCREATE INDEX IF NOT EXISTS class_lite_class_idx ON reclada.v_class_lite USING btree (for_class);\n\nDO $$\nDECLARE\n\tdsrc_uuid\tTEXT;\n\tdset_uuid\tTEXT;\n\ttrn_id\t\tINT;\n\tdset_data\tjsonb;\n\nBEGIN\n\tSELECT v.obj_id, v.data\n    FROM reclada.v_active_object v\n    WHERE v.attrs->>'name' = 'defaultDataSet'\n\t    INTO dset_uuid, dset_data;\n\tFOR dsrc_uuid IN (\tSELECT DISTINCT jsonb_array_elements_text(attrs->'dataSources') \n\t\t\t\t\t\tFROM v_active_object vao \n\t\t\t\t\t\tWHERE obj_id = dset_uuid::uuid) LOOP\n\t\tPERFORM reclada_object.create(\n            format('{\n                "class": "Relationship",\n                "attributes": {\n                    "type": "defaultDataSet to DataSource",\n                    "object": "%s",\n                    "subject": "%s"\n                    }\n                }', dsrc_uuid, dset_uuid)::jsonb);\n\tEND LOOP;\n\tIF (jsonb_array_length(dset_data->'attributes'->'dataSources') > 0 )  THEN\n\t\tdset_data := jsonb_set(dset_data, '{attributes, dataSources}', '[]'::jsonb);\n\t\tPERFORM reclada_object.update(dset_data);\n\tEND IF;\nEND\n$$;\n\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n    select ver, upgrade_script, downgrade_script\n        from var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, curren version: ' \n                            || (select ver from var_table)::text\n                          );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\nDROP VIEW IF EXISTS reclada.v_revision;\nDROP VIEW IF EXISTS reclada.v_import_info;\nDROP VIEW IF EXISTS reclada.v_pk_for_class;\nDROP VIEW IF EXISTS reclada.v_class;\nDROP VIEW IF EXISTS reclada.v_active_object;\nDROP VIEW IF EXISTS reclada.v_object;\n\n\nDROP function IF EXISTS reclada_object.get_query_condition_filter ;\nCREATE OR REPLACE FUNCTION reclada_object.get_query_condition_filter(data jsonb)\n RETURNS text\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE \r\n\t_count \tINT;\r\n    _res \tTEXT;\r\nBEGIN \r\n    -- TODO: to change VOLATILE -> IMMUTABLE, remove CREATE TEMP TABLE\r\n    CREATE TEMP TABLE mytable AS\r\n    WITH RECURSIVE f AS \r\n    (\r\n        SELECT data AS v\r\n    ),\r\n    pr AS \r\n    (\r\n        SELECT \tformat(' %s ',f.v->>'operator') AS op, \r\n                val.v AS val,\r\n                1 AS lvl,\r\n                row_number() OVER(ORDER BY idx) AS rn,\r\n                val.idx idx,\r\n                0::BIGINT prev\r\n            FROM f, jsonb_array_elements(f.v->'value') WITH ordinality AS val(v, idx)\r\n    ),\r\n    res AS\r\n    (\t\r\n        SELECT \tpr.lvl\t,\r\n                pr.rn\t,\r\n                pr.idx  ,\r\n                pr.op\t,\r\n                pr.prev ,\r\n                pr.val\t,\r\n                CASE jsonb_typeof(pr.val) \r\n                    WHEN 'object'\t\r\n                        THEN NULL\r\n                    ELSE pr.val\r\n                END AS parsed\r\n            FROM pr\r\n            WHERE prev = 0 \r\n                AND lvl = 1\r\n        UNION ALL\r\n        SELECT \tttt.lvl\t,\r\n                ROW_NUMBER() OVER(ORDER BY ttt.idx) AS rn,\r\n                ttt.idx,\r\n                ttt.op\t,\r\n                ttt.prev,\r\n                ttt.val ,\r\n                CASE jsonb_typeof(ttt.val) \r\n                    WHEN 'object'\t\r\n                        THEN NULL\r\n                    ELSE ttt.val\r\n                end AS parsed\r\n            FROM\r\n            (\r\n                SELECT \tres.lvl + 1 AS lvl,\r\n                        format(' %s ',res.val->>'operator') AS op,\r\n                        res.rn AS prev\t,\r\n                        val.v  AS val,\r\n                        val.idx\r\n                    FROM res, \r\n                         jsonb_array_elements(res.val->'value') WITH ordinality AS val(v, idx)\r\n            ) ttt\r\n    )\r\n    SELECT \tr.lvl\t,\r\n            r.rn\t,\r\n            r.idx   ,\r\n            r.op\t,\r\n            r.prev  ,\r\n            r.val\t,\r\n            r.parsed\r\n        FROM res r;\r\n\r\n    UPDATE mytable u\r\n        SET parsed = to_jsonb(p.v)\r\n            FROM mytable t\r\n            JOIN LATERAL \r\n            (\r\n                SELECT t.parsed #>> '{}' v\r\n            ) as pt\r\n                ON TRUE\r\n            JOIN LATERAL \r\n            (\r\n\t\t\t\tSELECT CASE \r\n\t\t\t\t\t\tWHEN pt.v LIKE '{class}'\r\n                            THEN 'class_name'\r\n\t\t\t\t\t\tWHEN pt.v LIKE '%{%}%'\r\n                            THEN REPLACE(\r\n\t\t\t\t\t\t\t\t\tREPLACE(pt.v,'{','data #>> ''{'),\r\n\t\t\t\t\t\t\t\t'}','}''')\r\n\t\t\t\t\t\tWHEN pt.v LIKE '(%)'\r\n                            THEN REPLACE(\r\n\t\t\t\t\t\t\t\t\tREPLACE(\r\n\t\t\t\t\t\t\t\t\t\tREPLACE(pt.v,'(','(''')\r\n\t\t\t\t\t\t\t\t\t,')',''')')\r\n\t\t\t\t\t\t\t\t,',',''',''')\r\n\t\t\t\t\t\tELSE\r\n                            ''''||pt.v||''''\r\n\t\t\t\t\tEND AS v\r\n\t\t\t\t/*\r\n                SELECT CASE \r\n                        WHEN pt.v LIKE '{attributes,%}'\r\n                            THEN format('attrs #>> ''''%s''''', REPLACE(pt.v,'{attributes,','{'))\r\n                        WHEN pt.v LIKE '{class}'\r\n                            THEN 'class_name'\r\n                        WHEN pt.v LIKE '{GUID}'\r\n                            THEN 'obj_id'\r\n                        WHEN pt.v LIKE '{status}'\r\n                            THEN 'status_caption'\r\n\t\t\t\t\t\tWHEN pt.v LIKE '(%)'\r\n                            THEN replace(\r\n\t\t\t\t\t\t\t\t\treplace(\r\n\t\t\t\t\t\t\t\t\t\treplace(pt.v,'(','(''')\r\n\t\t\t\t\t\t\t\t\t,')',''')')\r\n\t\t\t\t\t\t\t\t,',',''',''')\r\n                        WHEN pt.v LIKE '{transactionID}'\r\n                            THEN 'transaction_id'\r\n\t\t\t\t\t\tWHEN pt.v LIKE '{%}'\r\n                            THEN 'transaction_id'\r\n                        ELSE\r\n                            ''''||pt.v||''''\r\n                    END AS v\r\n\t\t\t\t*/\r\n            ) as p\r\n                ON TRUE\r\n            WHERE t.lvl = u.lvl\r\n                AND t.rn = u.rn\r\n                AND t.parsed IS NOT NULL;\r\n                \r\n\r\n\tINSERT INTO mytable (lvl,rn)\r\n\t\tVALUES (0,0);\r\n\t\r\n\t_count := 1;\r\n\t\r\n\tWHILE (_count>0) LOOP\r\n\t\tWITH r AS \r\n\t\t(\r\n\t\t\tUPDATE mytable\r\n\t\t\t\tSET parsed = to_json(t.converted)::JSONB \r\n\t\t\t\tFROM \r\n\t\t\t\t(\r\n\t\t\t\t\tSELECT \t\r\n\t\t\t\t\t\t\tres.lvl-1 lvl,\r\n\t\t\t\t\t\t\tres.prev rn,\r\n\t\t\t\t\t\t\tres.op,\r\n\t\t\t\t\t\t\t1 q,\r\n\t\t\t\t\t\t\tCASE COUNT(1) \r\n\t\t\t\t\t\t\t\tWHEN 1\r\n\t\t\t\t\t\t\t\t\tTHEN format('(%s %s)', res.op, min(res.parsed #>> '{}') )\r\n\t\t\t\t\t\t\t\tELSE\r\n\t\t\t\t\t\t\t\t\t'('||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op)||')'\r\n\t\t\t\t\t\t\tend AS converted\r\n\t\t\t\t\t\tFROM mytable res \r\n\t\t\t\t\t\t\tWHERE res.parsed IS NOT NULL\r\n\t\t\t\t\t\t\t\tAND res.lvl = (SELECT max(lvl)+1 FROM mytable WHERE parsed IS NULL)\r\n\t\t\t\t\t\t\tGROUP BY  res.prev, res.op, res.lvl\r\n\t\t\t\t) t\r\n\t\t\t\tWHERE\r\n\t\t\t\t\tt.lvl = mytable.lvl\r\n\t\t\t\t\t\tAND t.rn = mytable.rn\r\n\t\t\t\tRETURNING 1\r\n\t\t)\r\n\t\t\tSELECT COUNT(*) \r\n\t\t\t\tFROM r\r\n\t\t\t\tINTO _count;\r\n\tEND LOOP;\r\n\t\r\n\tSELECT parsed #>> '{}' \r\n\t\tFROM mytable\r\n\t\t\tWHERE lvl = 0 AND rn = 0\r\n\t\tINTO _res;\r\n\t\r\n\tDROP TABLE mytable;\r\n    RETURN _res;\r\nEND \r\n$function$\n;\nDROP function IF EXISTS reclada_object.parse_filter ;\n\nDROP function IF EXISTS api.reclada_object_list ;\nCREATE OR REPLACE FUNCTION api.reclada_object_list(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    class               text;\r\n    user_info           jsonb;\r\n    result              jsonb;\r\n\r\nBEGIN\r\n\r\n    class := data->>'class';\r\n    IF(class IS NULL) THEN\r\n        RAISE EXCEPTION 'reclada object class not specified';\r\n    END IF;\r\n\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF (NOT(reclada_user.is_allowed(user_info, 'list', class))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'list', class;\r\n    END IF;\r\n\r\n    SELECT reclada_object.list(data, true) INTO result;\r\n\r\n    RETURN result;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.list ;\nCREATE OR REPLACE FUNCTION reclada_object.list(data jsonb, gui boolean DEFAULT false)\n RETURNS jsonb\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    class               text;\r\n    attrs               jsonb;\r\n    order_by_jsonb      jsonb;\r\n    order_by            text;\r\n    limit_              text;\r\n    offset_             text;\r\n    query_conditions    text;\r\n    number_of_objects   int;\r\n    objects             jsonb;\r\n    res                 jsonb;\r\n    query               text;\r\n    class_uuid          uuid;\r\n    last_change         text;\r\n    tran_id             bigint;\r\n    _filter             JSONB;\r\nBEGIN\r\n\r\n    tran_id := (data->>'transactionID')::bigint;\r\n    class := data->>'class';\r\n    _filter = data->'filter';\r\n    IF (class IS NULL and tran_id IS NULL and _filter IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object class, transactionID and filter are not specified';\r\n    END IF;\r\n\r\n    order_by_jsonb := data->'orderBy';\r\n    IF ((order_by_jsonb IS NULL) OR\r\n        (order_by_jsonb = 'null'::jsonb) OR\r\n        (order_by_jsonb = '[]'::jsonb)) THEN\r\n        order_by_jsonb := '[{"field": "GUID", "order": "ASC"}]'::jsonb;\r\n    END IF;\r\n    IF (jsonb_typeof(order_by_jsonb) != 'array') THEN\r\n    \t\torder_by_jsonb := format('[%s]', order_by_jsonb);\r\n    END IF;\r\n    SELECT string_agg(\r\n        format(E'obj.data#>''{%s}'' %s', T.value->>'field', COALESCE(T.value->>'order', 'ASC')),\r\n        ' , ')\r\n    FROM jsonb_array_elements(order_by_jsonb) T\r\n    INTO order_by;\r\n\r\n    limit_ := data->>'limit';\r\n    IF (limit_ IS NULL) THEN\r\n        limit_ := 500;\r\n    END IF;\r\n    IF ((limit_ ~ '(\\D+)') AND (limit_ != 'ALL')) THEN\r\n    \t\tRAISE EXCEPTION 'The limit must be an integer number or "ALL"';\r\n    END IF;\r\n\r\n    offset_ := data->>'offset';\r\n    IF (offset_ IS NULL) THEN\r\n        offset_ := 0;\r\n    END IF;\r\n    IF (offset_ ~ '(\\D+)') THEN\r\n    \t\tRAISE EXCEPTION 'The offset must be an integer number';\r\n    END IF;\r\n\r\n    IF (_filter IS NOT NULL) THEN\r\n        query_conditions := reclada_object.get_query_condition_filter(_filter);\r\n    ELSE\r\n        class_uuid := reclada.try_cast_uuid(class);\r\n\r\n        if class_uuid is not null then\r\n            select v.for_class \r\n                from reclada.v_class_lite v\r\n                    where class_uuid = v.obj_id\r\n            into class;\r\n\r\n            IF (class IS NULL) THEN\r\n                RAISE EXCEPTION 'Class not found by GUID: %', class_uuid::text;\r\n            END IF;\r\n        end if;\r\n\r\n        attrs := data->'attributes' || '{}'::jsonb;\r\n\r\n        SELECT\r\n            string_agg(\r\n                format(\r\n                    E'(%s)',\r\n                    condition\r\n                ),\r\n                ' AND '\r\n            )\r\n            FROM (\r\n                SELECT\r\n                    format('obj.class_name = ''%s''', class) AS condition\r\n                        where class is not null\r\n                            and class_uuid is null\r\n                UNION\r\n                    SELECT format('obj.class = ''%s''', class_uuid) AS condition\r\n                        where class_uuid is not null\r\n                UNION\r\n                    SELECT format('obj.transaction_id = %s', tran_id) AS condition\r\n                        where tran_id is not null\r\n                UNION\r\n                    SELECT CASE\r\n                            WHEN jsonb_typeof(data->'GUID') = 'array' THEN\r\n                            (\r\n                                SELECT string_agg\r\n                                    (\r\n                                        format(\r\n                                            E'(%s)',\r\n                                            reclada_object.get_query_condition(cond, E'data->''GUID''') -- TODO: change data->'GUID' to obj_id(GUID)\r\n                                        ),\r\n                                        ' AND '\r\n                                    )\r\n                                    FROM jsonb_array_elements(data->'GUID') AS cond\r\n                            )\r\n                            ELSE reclada_object.get_query_condition(data->'GUID', E'data->''GUID''') -- TODO: change data->'GUID' to obj_id(GUID)\r\n                        END AS condition\r\n                    WHERE coalesce(data->'GUID','null'::jsonb) != 'null'::jsonb\r\n                UNION\r\n                SELECT\r\n                    CASE\r\n                        WHEN jsonb_typeof(value) = 'array'\r\n                            THEN\r\n                                (\r\n                                    SELECT string_agg\r\n                                        (\r\n                                            format\r\n                                            (\r\n                                                E'(%s)',\r\n                                                reclada_object.get_query_condition(cond, format(E'attrs->%L', key))\r\n                                            ),\r\n                                            ' AND '\r\n                                        )\r\n                                        FROM jsonb_array_elements(value) AS cond\r\n                                )\r\n                        ELSE reclada_object.get_query_condition(value, format(E'attrs->%L', key))\r\n                    END AS condition\r\n                FROM jsonb_each(attrs)\r\n                WHERE attrs != ('{}'::jsonb)\r\n            ) conds\r\n        INTO query_conditions;\r\n    END IF;\r\n    query := 'FROM reclada.v_active_object obj WHERE ' || query_conditions;\r\n\r\n    -- RAISE NOTICE 'conds: %', '\r\n    --             SELECT obj.data\r\n    --             '\r\n    --             || query\r\n    --             ||\r\n    --             ' ORDER BY ' || order_by ||\r\n    --             ' OFFSET ' || offset_ || ' LIMIT ' || limit_ ;\r\n    EXECUTE E'SELECT to_jsonb(array_agg(T.data))\r\n        FROM (\r\n            SELECT obj.data\r\n            '\r\n            || query\r\n            ||\r\n            ' ORDER BY ' || order_by ||\r\n            ' OFFSET ' || offset_ || ' LIMIT ' || limit_ || ') T'\r\n    INTO objects;\r\n    IF gui THEN\r\n\r\n        EXECUTE E'SELECT count(1)\r\n        '|| query\r\n        INTO number_of_objects;\r\n\r\n        EXECUTE E'SELECT TO_CHAR(\r\n\tMAX(\r\n\t\tGREATEST(obj.created_time, (\r\n\t\t\tSELECT TO_TIMESTAMP(MAX(date_time),\\'YYYY-MM-DD hh24:mi:ss.US TZH\\')\r\n\t\t\tFROM reclada.v_revision vr\r\n\t\t\tWHERE vr.obj_id = UUID(obj.attrs ->>\\'revision\\'))\r\n\t\t)\r\n\t),\\'YYYY-MM-DD hh24:mi:ss.MS TZH\\')\r\n        '|| query\r\n        INTO last_change;\r\n\r\n        res := jsonb_build_object(\r\n        'last_change', last_change,    \r\n        'number', number_of_objects,\r\n        'objects', objects);\r\n    ELSE\r\n        res := objects;\r\n    END IF;\r\n\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP view IF EXISTS reclada.v_filter_mapping ;\n\n\nDROP function IF EXISTS reclada_object.datasource_insert ;\nCREATE OR REPLACE FUNCTION reclada_object.datasource_insert(_class_name text, obj_id uuid, attributes jsonb)\n RETURNS void\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    dataset       jsonb;\r\n    uri           text;\r\n    environment   varchar;\r\nBEGIN\r\n    IF _class_name in \r\n            ('DataSource','File') THEN\r\n\r\n        SELECT v.data\r\n        FROM reclada.v_active_object v\r\n\t    WHERE v.attrs->>'name' = 'defaultDataSet'\r\n\t    INTO dataset;\r\n\r\n        dataset := jsonb_set(dataset, '{attributes, dataSources}', dataset->'attributes'->'dataSources' || format('["%s"]', obj_id)::jsonb);\r\n\r\n        PERFORM reclada_object.update(dataset);\r\n\r\n        uri := attributes->>'uri';\r\n\r\n        SELECT attrs->>'Environment'\r\n        FROM reclada.v_active_object\r\n        WHERE class_name = 'Context'\r\n        ORDER BY created_time DESC\r\n        LIMIT 1\r\n        INTO environment;\r\n\r\n        PERFORM reclada_object.create(\r\n            format('{\r\n                "class": "Job",\r\n                "attributes": {\r\n                    "task": "c94bff30-15fa-427f-9954-d5c3c151e652",\r\n                    "status": "new",\r\n                    "type": "%s",\r\n                    "command": "./run_pipeline.sh",\r\n                    "inputParameters": [{"uri": "%s"}, {"dataSourceId": "%s"}]\r\n                    }\r\n                }', environment, uri, obj_id)::jsonb);\r\n\r\n    END IF;\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.create ;\nCREATE OR REPLACE FUNCTION reclada_object."create"(data_jsonb jsonb, user_info jsonb DEFAULT '{}'::jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    branch        uuid;\r\n    data          jsonb;\r\n    class_name    text;\r\n    class_uuid    uuid;\r\n    tran_id       bigint;\r\n    _attrs         jsonb;\r\n    schema        jsonb;\r\n    obj_GUID      uuid;\r\n    res           jsonb;\r\n    affected      uuid[];\r\nBEGIN\r\n\r\n    IF (jsonb_typeof(data_jsonb) != 'array') THEN\r\n        data_jsonb := '[]'::jsonb || data_jsonb;\r\n    END IF;\r\n    /*TODO: check if some objects have revision and others do not */\r\n    branch:= data_jsonb->0->'branch';\r\n\r\n    FOR data IN SELECT jsonb_array_elements(data_jsonb) \r\n    LOOP\r\n\r\n        class_name := data->>'class';\r\n\r\n        IF (class_name IS NULL) THEN\r\n            RAISE EXCEPTION 'The reclada object class is not specified';\r\n        END IF;\r\n        class_uuid := reclada.try_cast_uuid(class_name);\r\n\r\n        _attrs := data->'attributes';\r\n        IF (_attrs IS NULL) THEN\r\n            RAISE EXCEPTION 'The reclada object must have attributes';\r\n        END IF;\r\n\r\n        tran_id := (data->>'transactionID')::bigint;\r\n        if tran_id is null then\r\n            tran_id := reclada.get_transaction_id();\r\n        end if;\r\n\r\n        IF class_uuid IS NULL THEN\r\n            SELECT reclada_object.get_schema(class_name) \r\n            INTO schema;\r\n            class_uuid := (schema->>'GUID')::uuid;\r\n        ELSE\r\n            SELECT v.data \r\n            FROM reclada.v_class v\r\n            WHERE class_uuid = v.obj_id\r\n            INTO schema;\r\n        END IF;\r\n        IF (schema IS NULL) THEN\r\n            RAISE EXCEPTION 'No json schema available for %', class_name;\r\n        END IF;\r\n\r\n        IF (NOT(public.validate_json_schema(schema->'attributes'->'schema', _attrs))) THEN\r\n            RAISE EXCEPTION 'JSON invalid: %', _attrs;\r\n        END IF;\r\n        \r\n        IF data->>'id' IS NOT NULL THEN\r\n            RAISE EXCEPTION '%','Field "id" not allow!!!';\r\n        END IF;\r\n\r\n        IF class_uuid IN (SELECT guid FROM reclada.v_PK_for_class)\r\n        THEN\r\n            SELECT o.obj_id\r\n                FROM reclada.v_object o\r\n                JOIN reclada.v_PK_for_class pk\r\n                    on pk.guid = o.class\r\n                        and class_uuid = o.class\r\n                where o.attrs->>pk.pk = _attrs ->> pk.pk\r\n                LIMIT 1\r\n            INTO obj_GUID;\r\n            IF obj_GUID IS NOT NULL THEN\r\n                SELECT reclada_object.update(data || format('{"GUID": "%s"}', obj_GUID)::jsonb)\r\n                    INTO res;\r\n                    RETURN '[]'::jsonb || res;\r\n            END IF;\r\n        END IF;\r\n\r\n        obj_GUID := (data->>'GUID')::uuid;\r\n        IF EXISTS (\r\n            SELECT 1\r\n            FROM reclada.object \r\n            WHERE GUID = obj_GUID\r\n        ) THEN\r\n            RAISE EXCEPTION 'GUID: % is duplicate', obj_GUID;\r\n        END IF;\r\n        --raise notice 'schema: %',schema;\r\n\r\n        INSERT INTO reclada.object(GUID,class,attributes,transaction_id)\r\n            SELECT  CASE\r\n                        WHEN obj_GUID IS NULL\r\n                            THEN public.uuid_generate_v4()\r\n                        ELSE obj_GUID\r\n                    END AS GUID,\r\n                    class_uuid, \r\n                    _attrs,\r\n                    tran_id\r\n        RETURNING GUID INTO obj_GUID;\r\n        affected := array_append( affected, obj_GUID);\r\n\r\n        PERFORM reclada_object.datasource_insert\r\n            (\r\n                class_name,\r\n                obj_GUID,\r\n                _attrs\r\n            );\r\n\r\n        PERFORM reclada_object.refresh_mv(class_name);\r\n    END LOOP;\r\n\r\n    res := array_to_json\r\n            (\r\n                array\r\n                (\r\n                    SELECT o.data \r\n                    FROM reclada.v_active_object o\r\n                    WHERE o.obj_id = ANY (affected)\r\n                )\r\n            )::jsonb; \r\n    PERFORM reclada_notification.send_object_notification\r\n        (\r\n            'create',\r\n            res\r\n        );\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.create_subclass ;\nCREATE OR REPLACE FUNCTION reclada_object.create_subclass(data jsonb)\n RETURNS void\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    class           text;\r\n    new_class       text;\r\n    attrs           jsonb;\r\n    class_schema    jsonb;\r\n    version_         integer;\r\n\r\nBEGIN\r\n\r\n    class := data->>'class';\r\n    IF (class IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object class is not specified';\r\n    END IF;\r\n\r\n    attrs := data->'attributes';\r\n    IF (attrs IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object must have attributes';\r\n    END IF;\r\n\r\n    new_class = attrs->>'newClass';\r\n\r\n    SELECT reclada_object.get_schema(class) INTO class_schema;\r\n\r\n    IF (class_schema IS NULL) THEN\r\n        RAISE EXCEPTION 'No json schema available for %', class;\r\n    END IF;\r\n\r\n    SELECT max(version) + 1\r\n    FROM reclada.v_class_lite v\r\n    WHERE v.for_class = new_class\r\n    INTO version_;\r\n\r\n    version_ := coalesce(version_,1);\r\n    class_schema := class_schema->'attributes'->'schema';\r\n\r\n    PERFORM reclada_object.create(format('{\r\n        "class": "jsonschema",\r\n        "attributes": {\r\n            "forClass": "%s",\r\n            "version": "%s",\r\n            "schema": {\r\n                "type": "object",\r\n                "properties": %s,\r\n                "required": %s\r\n            }\r\n        }\r\n    }',\r\n    new_class,\r\n    version_,\r\n    (class_schema->'properties') || (attrs->'properties'),\r\n    (SELECT jsonb_agg(el) FROM (\r\n        SELECT DISTINCT pg_catalog.jsonb_array_elements(\r\n            (class_schema -> 'required') || (attrs -> 'required')\r\n        ) el) arr)\r\n    )::jsonb);\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.get_condition_array ;\nCREATE OR REPLACE FUNCTION reclada_object.get_condition_array(data jsonb, key_path text)\n RETURNS text\n LANGUAGE sql\n IMMUTABLE\nAS $function$\r\n    SELECT\r\n    CONCAT(\r\n        key_path,\r\n        ' ', COALESCE(data->>'operator', '='), ' ',\r\n        format(E'\\'%s\\'::jsonb', data->'object'#>>'{}'))\r\n$function$\n;\nDROP function IF EXISTS reclada_object.update ;\nCREATE OR REPLACE FUNCTION reclada_object.update(data jsonb, user_info jsonb DEFAULT '{}'::jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    class_name     text;\r\n    class_uuid     uuid;\r\n    v_obj_id       uuid;\r\n    v_attrs        jsonb;\r\n    schema        jsonb;\r\n    old_obj       jsonb;\r\n    branch        uuid;\r\n    revid         uuid;\r\n\r\nBEGIN\r\n\r\n    class_name := data->>'class';\r\n    IF (class_name IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object class is not specified';\r\n    END IF;\r\n    class_uuid := reclada.try_cast_uuid(class_name);\r\n    v_obj_id := data->>'GUID';\r\n    IF (v_obj_id IS NULL) THEN\r\n        RAISE EXCEPTION 'Could not update object with no GUID';\r\n    END IF;\r\n\r\n    v_attrs := data->'attributes';\r\n    IF (v_attrs IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object must have attributes';\r\n    END IF;\r\n\r\n    SELECT reclada_object.get_schema(class_name) \r\n        INTO schema;\r\n\r\n    if class_uuid is null then\r\n        SELECT reclada_object.get_schema(class_name) \r\n            INTO schema;\r\n    else\r\n        select v.data \r\n            from reclada.v_class v\r\n                where class_uuid = v.obj_id\r\n            INTO schema;\r\n    end if;\r\n    -- TODO: don't allow update jsonschema\r\n    IF (schema IS NULL) THEN\r\n        RAISE EXCEPTION 'No json schema available for %', class_name;\r\n    END IF;\r\n\r\n    IF (NOT(public.validate_json_schema(schema->'attributes'->'schema', v_attrs))) THEN\r\n        RAISE EXCEPTION 'JSON invalid: %', v_attrs;\r\n    END IF;\r\n\r\n    SELECT \tv.data\r\n        FROM reclada.v_active_object v\r\n\t        WHERE v.obj_id = v_obj_id\r\n\t    INTO old_obj;\r\n\r\n    IF (old_obj IS NULL) THEN\r\n        RAISE EXCEPTION 'Could not update object, no such id';\r\n    END IF;\r\n\r\n    branch := data->'branch';\r\n    SELECT reclada_revision.create(user_info->>'sub', branch, v_obj_id) \r\n        INTO revid;\r\n    \r\n    with t as \r\n    (\r\n        update reclada.object o\r\n            set status = reclada_object.get_archive_status_obj_id()\r\n                where o.GUID = v_obj_id\r\n                    and status != reclada_object.get_archive_status_obj_id()\r\n                        RETURNING id\r\n    )\r\n    INSERT INTO reclada.object( GUID,\r\n                                class,\r\n                                status,\r\n                                attributes,\r\n                                transaction_id\r\n                              )\r\n        select  v.obj_id,\r\n                (schema->>'GUID')::uuid,\r\n                reclada_object.get_active_status_obj_id(),--status \r\n                v_attrs || format('{"revision":"%s"}',revid)::jsonb,\r\n                transaction_id\r\n            FROM reclada.v_object v\r\n            JOIN t \r\n                on t.id = v.id\r\n\t            WHERE v.obj_id = v_obj_id;\r\n    PERFORM reclada_object.datasource_insert\r\n            (\r\n                class_name,\r\n                (schema->>'GUID')::uuid,\r\n                v_attrs\r\n            );\r\n    PERFORM reclada_object.refresh_mv(class_name);  \r\n                  \r\n    select v.data \r\n        FROM reclada.v_active_object v\r\n            WHERE v.obj_id = v_obj_id\r\n        into data;\r\n    PERFORM reclada_notification.send_object_notification('update', data);\r\n    RETURN data;\r\nEND;\r\n$function$\n;\n\nDROP INDEX IF EXISTS reclada.parent_guid_index;\nALTER TABLE reclada.object DROP COLUMN IF EXISTS parent_guid;\n\nDROP view IF EXISTS reclada.v_object ;\nCREATE OR REPLACE VIEW reclada.v_object\nAS\n WITH t AS (\n         SELECT obj.id,\n            obj.guid,\n            obj.class,\n            r.num,\n            NULLIF(obj.attributes ->> 'revision'::text, ''::text)::uuid AS revision,\n            obj.attributes,\n            obj.status,\n            obj.created_time,\n            obj.created_by,\n            obj.transaction_id\n           FROM object obj\n             LEFT JOIN ( SELECT (r_1.attributes ->> 'num'::text)::bigint AS num,\n                    r_1.guid\n                   FROM object r_1\n                  WHERE (r_1.class IN ( SELECT reclada_object.get_guid_for_class('revision'::text) AS get_guid_for_class))) r ON r.guid = NULLIF(obj.attributes ->> 'revision'::text, ''::text)::uuid\n        )\n SELECT t.id,\n    t.guid AS obj_id,\n    t.class,\n    t.num AS revision_num,\n    os.caption AS status_caption,\n    t.revision,\n    t.created_time,\n    t.attributes AS attrs,\n    cl.for_class AS class_name,\n    (( SELECT json_agg(tmp.*) -> 0\n           FROM ( SELECT t.guid AS "GUID",\n                    t.class,\n                    os.caption AS status,\n                    t.attributes,\n                    t.transaction_id AS "transactionID") tmp))::jsonb AS data,\n    u.login AS login_created_by,\n    t.created_by,\n    t.status,\n    t.transaction_id\n   FROM t\n     LEFT JOIN v_object_status os ON t.status = os.obj_id\n     LEFT JOIN v_user u ON u.obj_id = t.created_by\n     LEFT JOIN v_class_lite cl ON cl.obj_id = t.class;\nDROP view IF EXISTS reclada.v_active_object ;\nCREATE OR REPLACE VIEW reclada.v_active_object\nAS\n SELECT t.id,\n    t.obj_id,\n    t.class,\n    t.revision_num,\n    t.status,\n    t.status_caption,\n    t.revision,\n    t.created_time,\n    t.class_name,\n    t.attrs,\n    t.data,\n    t.transaction_id\n   FROM v_object t\n  WHERE t.status = reclada_object.get_active_status_obj_id();\nDROP view IF EXISTS reclada.v_class ;\nCREATE OR REPLACE VIEW reclada.v_class\nAS\n SELECT obj.id,\n    obj.obj_id,\n    obj.attrs ->> 'forClass'::text AS for_class,\n    (obj.attrs ->> 'version'::text)::bigint AS version,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class_name = 'jsonschema'::text;\nDROP view IF EXISTS reclada.v_pk_for_class ;\nCREATE OR REPLACE VIEW reclada.v_pk_for_class\nAS\n SELECT obj.obj_id AS guid,\n    obj.for_class,\n    pk.pk\n   FROM v_class obj\n     JOIN ( SELECT 'File'::text AS class_name,\n            'uri'::text AS pk) pk ON pk.class_name = obj.for_class;\nDROP view IF EXISTS reclada.v_import_info ;\nCREATE OR REPLACE VIEW reclada.v_import_info\nAS\n SELECT obj.id,\n    obj.obj_id AS guid,\n    (obj.attrs ->> 'tranID'::text)::bigint AS tran_id,\n    obj.attrs ->> 'name'::text AS name,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class_name = 'ImportInfo'::text;\nDROP view IF EXISTS reclada.v_revision ;\nCREATE OR REPLACE VIEW reclada.v_revision\nAS\n SELECT obj.id,\n    obj.obj_id,\n    (obj.attrs ->> 'num'::text)::bigint AS num,\n    obj.attrs ->> 'branch'::text AS branch,\n    obj.attrs ->> 'user'::text AS "user",\n    obj.attrs ->> 'dateTime'::text AS date_time,\n    obj.attrs ->> 'old_num'::text AS old_num,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class_name = 'revision'::text;\n\nDROP INDEX IF EXISTS reclada.class_lite_obj_idx;\nDROP INDEX IF EXISTS reclada.class_lite_class_idx;\n\n\nDO $$\nDECLARE\n\trltshp_uuid TEXT;\n\tdds_uuid\tuuid;\n\tdds_rev\t\tuuid;\n\tdds_revn\tint;\n\trlt_cnt\t\tint;\nBEGIN\n\tSELECT obj_id,attrs->>'revision', revision_num\n\tFROM reclada.v_active_object vao \n\tWHERE attrs->>'name' = 'defaultDataSet'\n\t\tINTO dds_uuid, dds_rev, dds_revn;\n\n\tSELECT count(*)\n\tFROM reclada.v_active_object vao\n\tWHERE class_name ='Relationship' AND attrs ->>'type'= 'defaultDataSet to DataSource' and (attrs->>'subject')::uuid=dds_uuid\n\t\tINTO rlt_cnt;\n\t\n\tIF rlt_cnt>0 THEN\n\t\tDELETE FROM reclada.object\n\t\tWHERE guid = dds_uuid AND status = reclada_object.get_active_status_obj_id();\n\n\t\tDELETE FROM reclada.object\n\t\tWHERE guid = dds_rev;\n\n\t\tUPDATE reclada.object\n\t\tSET status = reclada_object.get_active_status_obj_id()\n\t\tWHERE status = reclada_object.get_archive_status_obj_id()\n\t\t\tAND id = (\n\t\t\t\tSELECT id\n\t\t\t\tFROM reclada.v_object\n\t\t\t\tWHERE obj_id = dds_uuid\n\t\t\t\t\tAND revision_num = dds_revn - 1\n\t\t\t);\n\n\t\tDELETE FROM reclada.OBJECT \n\t\tWHERE class=(\n\t\t\tSELECT obj_id \n\t\t\tFROM v_class  \n\t\t\tWHERE for_class ='Relationship'\n\t\t)\n\t\t\tAND ATTRIBUTES->>'type' = 'defaultDataSet to DataSource';\n\tEND IF;\nEND\n$$;	2021-10-25 09:26:50.97148+00
41	40	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n        upgrade_script text,\n        downgrade_script text\n    );\n    \ninsert into var_table(ver)\t\n    select max(ver) + 1\n        from dev.VER;\n        \nselect reclada.raise_exception('Can not apply this version!') \n    where not exists\n    (\n        select ver from var_table where ver = 40 --!!! write current version HERE !!!\n    );\n\nCREATE TEMP TABLE tmp\n(\n    id int GENERATED ALWAYS AS IDENTITY,\n    str text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n    from tmp ttt\n    inner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n    inner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n                split_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n        inner JOIN LATERAL\n    (\n        select case\n                when obj.typ = 'trigger'\n                    then\n                        (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n    inner JOIN LATERAL\n    (\n        select case \n                when obj.typ in ('function', 'procedure')\n                    then\n                        case \n                            when EXISTS\n                                (\n                                    SELECT 1 a\n                                        FROM pg_proc p \n                                        join pg_namespace n \n                                            on p.pronamespace = n.oid \n                                            where n.nspname||'.'||p.proname = obj.nam\n                                        LIMIT 1\n                                ) \n                                then (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n                            else ''\n                        end\n                when obj.typ = 'view'\n                    then\n                        case \n                            when EXISTS\n                                (\n                                    select 1 a \n                                        from pg_views v \n                                            where v.schemaname||'.'||v.viewname = obj.nam\n                                        LIMIT 1\n                                ) \n                                then E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n                            else ''\n                        end\n                when obj.typ = 'trigger'\n                    then\n                        case\n                            when EXISTS\n                                (\n                                    select 1 a\n                                        from pg_trigger v\n                                            where v.tgname = obj.nam\n                                        LIMIT 1\n                                )\n                                then (select pg_catalog.pg_get_triggerdef(oid, true)\n                                        from pg_trigger\n                                        where tgname = obj.nam)||';'\n                            else ''\n                        end\n                else \n                    ttt.str\n            end as v\n    )  scr ON TRUE\n    where ttt.id = tmp.id\n        and tmp.str like '--{%/%}';\n    \nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'view/reclada.v_filter_avaliable_operator.sql'\ni 'view/reclada.v_object.sql'\ni 'function/reclada_object.get_query_condition_filter.sql'\ni 'function/reclada_object.list.sql'\ni 'function/reclada.xor.sql'\n\nCREATE OPERATOR # \n(\n    PROCEDURE = reclada.xor, \n    LEFTARG = boolean, \n    RIGHTARG = boolean\n);\n\nupdate reclada.object\n    set attributes = '\n{\n    "schema": {\n        "type": "object",\n        "required": [\n            "command",\n            "status",\n            "type",\n            "task",\n            "environment"\n        ],\n        "properties": {\n            "tags": {\n                "type": "array",\n                "items": {\n                    "type": "string"\n                }\n            },\n            "platformRunnerID": {\n                "type": "string"\n            },\n            "task": {\n                "type": "string",\n                "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"\n            },\n            "type": {\n                "type": "string"\n            },\n            "runner": {\n                "type": "string",\n                "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"\n            },\n            "status": {\n                "type": "string",\n                "enum ": [\n                    "up",\n                    "down",\n                    "idle"\n                ]\n            },\n            "command": {\n                "type": "string"\n            },\n            "environment": {\n                "type": "string",\n                "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"\n            },\n            "inputParameters": {\n                "type": "array",\n                "items": {\n                    "type": "object"\n                }\n            },\n            "outputParameters": {\n                "type": "array",\n                "items": {\n                    "type": "object"\n                }\n            }\n        }\n    },\n    "version": "1",\n    "forClass": "Runner"\n}'::jsonb\n    where class = reclada_object.get_jsonschema_GUID() \n        and attributes->>'forClass' = 'Runner';\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n    select ver, upgrade_script, downgrade_script\n        from var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, curren version: ' \n                            || (select ver from var_table)::text\n                          );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\ndrop OPERATOR IF EXISTS #(boolean, boolean);\nDROP VIEW IF EXISTS reclada.v_revision;\nDROP VIEW IF EXISTS reclada.v_import_info;\nDROP VIEW IF EXISTS reclada.v_pk_for_class;\nDROP VIEW IF EXISTS reclada.v_class;\nDROP VIEW IF EXISTS reclada.v_active_object;\nDROP VIEW IF EXISTS reclada.v_object;\n\nDROP function IF EXISTS reclada_object.get_query_condition_filter ;\nCREATE OR REPLACE FUNCTION reclada_object.get_query_condition_filter(data jsonb)\n RETURNS text\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE \r\n    _count   INT;\r\n    _res     TEXT;\r\nBEGIN \r\n    -- TODO: to change VOLATILE -> IMMUTABLE, remove CREATE TEMP TABLE\r\n    CREATE TEMP TABLE mytable AS\r\n        SELECT  lvl             ,  rn   , idx  ,\r\n                upper(op) as op ,  prev , val  ,  \r\n                parsed\r\n            FROM reclada_object.parse_filter(data);\r\n\r\n    UPDATE mytable u\r\n        SET parsed = to_jsonb(p.v)\r\n            FROM mytable t\r\n            JOIN LATERAL \r\n            (\r\n                SELECT  t.parsed #>> '{}' v\r\n            ) as pt\r\n                ON TRUE\r\n            LEFT JOIN reclada.v_filter_mapping fm\r\n                ON pt.v = fm.pattern\r\n            JOIN LATERAL \r\n            (\r\n                SELECT CASE \r\n                        WHEN fm.repl is not NULL \r\n                            then '(''"''||' ||fm.repl ||'||''"'')::jsonb' -- don't use FORMAT (concat null)\r\n                        -- WHEN pt.v LIKE '{attributes,%}'\r\n                        --     THEN format('attrs #> ''%s''', REPLACE(pt.v,'{attributes,','{'))\r\n                        WHEN jsonb_typeof(t.parsed) in ('number', 'boolean')\r\n                            then \r\n                                case \r\n                                    when t.op IN (' + ')\r\n                                        then pt.v\r\n                                    else '''' || pt.v || '''::jsonb'\r\n                                end\r\n                        WHEN jsonb_typeof(t.parsed) = 'string' \r\n                            then    \r\n                                case\r\n                                    WHEN pt.v LIKE '{%}' \r\n                                        THEN\r\n                                            case\r\n                                                when t.op IN (' LIKE ', ' NOT LIKE ', ' || ', ' ~ ', ' !~ ', ' ~* ', ' !~* ', ' SIMILAR TO ')\r\n                                                    then format('(data #>> ''%s'')', pt.v)\r\n                                                when t.op IN (' + ')\r\n                                                    then format('(data #> ''%s'')::decimal', pt.v)\r\n                                                else\r\n                                                    format('data #> ''%s''', pt.v)\r\n                                            end\r\n                                    when t.op IN (' LIKE ', ' NOT LIKE ', ' || ', ' ~ ', ' !~ ', ' ~* ', ' !~* ', ' SIMILAR TO ')\r\n                                        then ''''||REPLACE(pt.v,'''','''''')||''''\r\n                                    else\r\n                                        '''"'||REPLACE(pt.v,'''','''''')||'"''::jsonb'\r\n                                end\r\n                        WHEN jsonb_typeof(t.parsed) = 'null'\r\n                            then 'null'\r\n                        WHEN jsonb_typeof(t.parsed) = 'array'\r\n                            then ''''||REPLACE(pt.v,'''','''''')||'''::jsonb'\r\n                        ELSE\r\n                            pt.v\r\n                    END AS v\r\n            ) as p\r\n                ON TRUE\r\n            WHERE t.lvl = u.lvl\r\n                AND t.rn = u.rn\r\n                AND t.parsed IS NOT NULL;\r\n                \r\n\r\n    INSERT INTO mytable (lvl,rn)\r\n        VALUES (0,0);\r\n    \r\n    _count := 1;\r\n    \r\n    WHILE (_count>0) LOOP\r\n        WITH r AS \r\n        (\r\n            UPDATE mytable\r\n                SET parsed = to_json(t.converted)::JSONB \r\n                FROM \r\n                (\r\n                    SELECT     \r\n                            res.lvl-1 lvl,\r\n                            res.prev rn,\r\n                            res.op,\r\n                            1 q,\r\n                            CASE COUNT(1) \r\n                                WHEN 1\r\n                                    THEN format('(%s %s)', res.op, min(res.parsed #>> '{}') )\r\n                                ELSE\r\n                                    CASE \r\n                                        when res.op in (' || ')\r\n                                            then '(''"''||'||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op)||'||''"'')::jsonb'\r\n                                        when res.op in (' + ')\r\n                                            then '('||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op)||')::text::jsonb'\r\n                                        else\r\n                                            '('||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op)||')'\r\n                                    end\r\n                            end AS converted\r\n                        FROM mytable res \r\n                            WHERE res.parsed IS NOT NULL\r\n                                AND res.lvl = (SELECT max(lvl)+1 FROM mytable WHERE parsed IS NULL)\r\n                            GROUP BY  res.prev, res.op, res.lvl\r\n                ) t\r\n                WHERE\r\n                    t.lvl = mytable.lvl\r\n                        AND t.rn = mytable.rn\r\n                RETURNING 1\r\n        )\r\n            SELECT COUNT(1) \r\n                FROM r\r\n                INTO _count;\r\n    END LOOP;\r\n    \r\n    SELECT parsed #>> '{}' \r\n        FROM mytable\r\n            WHERE lvl = 0 AND rn = 0\r\n        INTO _res;\r\n    perform reclada.raise_notice( _res);\r\n    DROP TABLE mytable;\r\n    RETURN _res;\r\nEND \r\n$function$\n;\nDROP function IF EXISTS reclada_object.list ;\nCREATE OR REPLACE FUNCTION reclada_object.list(data jsonb, gui boolean DEFAULT false)\n RETURNS jsonb\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    class               text;\r\n    attrs               jsonb;\r\n    order_by_jsonb      jsonb;\r\n    order_by            text;\r\n    limit_              text;\r\n    offset_             text;\r\n    query_conditions    text;\r\n    number_of_objects   int;\r\n    objects             jsonb;\r\n    res                 jsonb;\r\n    query               text;\r\n    class_uuid          uuid;\r\n    last_change         text;\r\n    tran_id             bigint;\r\n    _filter             JSONB;\r\nBEGIN\r\n\r\n    tran_id := (data->>'transactionID')::bigint;\r\n    class := data->>'class';\r\n    _filter = data->'filter';\r\n    IF (class IS NULL and tran_id IS NULL and _filter IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object class, transactionID and filter are not specified';\r\n    END IF;\r\n\r\n    order_by_jsonb := data->'orderBy';\r\n    IF ((order_by_jsonb IS NULL) OR\r\n        (order_by_jsonb = 'null'::jsonb) OR\r\n        (order_by_jsonb = '[]'::jsonb)) THEN\r\n        order_by_jsonb := '[{"field": "GUID", "order": "ASC"}]'::jsonb;\r\n    END IF;\r\n    IF (jsonb_typeof(order_by_jsonb) != 'array') THEN\r\n    \t\torder_by_jsonb := format('[%s]', order_by_jsonb);\r\n    END IF;\r\n    SELECT string_agg(\r\n        format(E'obj.data#>''{%s}'' %s', T.value->>'field', COALESCE(T.value->>'order', 'ASC')),\r\n        ' , ')\r\n    FROM jsonb_array_elements(order_by_jsonb) T\r\n    INTO order_by;\r\n\r\n    limit_ := data->>'limit';\r\n    IF (limit_ IS NULL) THEN\r\n        limit_ := 500;\r\n    END IF;\r\n    IF ((limit_ ~ '(\\D+)') AND (limit_ != 'ALL')) THEN\r\n    \t\tRAISE EXCEPTION 'The limit must be an integer number or "ALL"';\r\n    END IF;\r\n\r\n    offset_ := data->>'offset';\r\n    IF (offset_ IS NULL) THEN\r\n        offset_ := 0;\r\n    END IF;\r\n    IF (offset_ ~ '(\\D+)') THEN\r\n    \t\tRAISE EXCEPTION 'The offset must be an integer number';\r\n    END IF;\r\n\r\n    IF (_filter IS NOT NULL) THEN\r\n        query_conditions := reclada_object.get_query_condition_filter(_filter);\r\n    ELSE\r\n        class_uuid := reclada.try_cast_uuid(class);\r\n\r\n        if class_uuid is not null then\r\n            select v.for_class \r\n                from reclada.v_class_lite v\r\n                    where class_uuid = v.obj_id\r\n            into class;\r\n\r\n            IF (class IS NULL) THEN\r\n                RAISE EXCEPTION 'Class not found by GUID: %', class_uuid::text;\r\n            END IF;\r\n        end if;\r\n\r\n        attrs := data->'attributes' || '{}'::jsonb;\r\n\r\n        SELECT\r\n            string_agg(\r\n                format(\r\n                    E'(%s)',\r\n                    condition\r\n                ),\r\n                ' AND '\r\n            )\r\n            FROM (\r\n                SELECT\r\n                    format('obj.class_name = ''%s''', class) AS condition\r\n                        where class is not null\r\n                            and class_uuid is null\r\n                UNION\r\n                    SELECT format('obj.class = ''%s''', class_uuid) AS condition\r\n                        where class_uuid is not null\r\n                UNION\r\n                    SELECT format('obj.transaction_id = %s', tran_id) AS condition\r\n                        where tran_id is not null\r\n                UNION\r\n                    SELECT CASE\r\n                            WHEN jsonb_typeof(data->'GUID') = 'array' THEN\r\n                            (\r\n                                SELECT string_agg\r\n                                    (\r\n                                        format(\r\n                                            E'(%s)',\r\n                                            reclada_object.get_query_condition(cond, E'data->''GUID''') -- TODO: change data->'GUID' to obj_id(GUID)\r\n                                        ),\r\n                                        ' AND '\r\n                                    )\r\n                                    FROM jsonb_array_elements(data->'GUID') AS cond\r\n                            )\r\n                            ELSE reclada_object.get_query_condition(data->'GUID', E'data->''GUID''') -- TODO: change data->'GUID' to obj_id(GUID)\r\n                        END AS condition\r\n                    WHERE coalesce(data->'GUID','null'::jsonb) != 'null'::jsonb\r\n                UNION\r\n                SELECT\r\n                    CASE\r\n                        WHEN jsonb_typeof(value) = 'array'\r\n                            THEN\r\n                                (\r\n                                    SELECT string_agg\r\n                                        (\r\n                                            format\r\n                                            (\r\n                                                E'(%s)',\r\n                                                reclada_object.get_query_condition(cond, format(E'attrs->%L', key))\r\n                                            ),\r\n                                            ' AND '\r\n                                        )\r\n                                        FROM jsonb_array_elements(value) AS cond\r\n                                )\r\n                        ELSE reclada_object.get_query_condition(value, format(E'attrs->%L', key))\r\n                    END AS condition\r\n                FROM jsonb_each(attrs)\r\n                WHERE attrs != ('{}'::jsonb)\r\n            ) conds\r\n        INTO query_conditions;\r\n    END IF;\r\n    query := 'FROM reclada.v_active_object obj WHERE ' || query_conditions;\r\n\r\n    -- RAISE NOTICE 'conds: %', '\r\n    --             SELECT obj.data\r\n    --             '\r\n    --             || query\r\n    --             ||\r\n    --             ' ORDER BY ' || order_by ||\r\n    --             ' OFFSET ' || offset_ || ' LIMIT ' || limit_ ;\r\n    EXECUTE E'SELECT to_jsonb(array_agg(T.data))\r\n        FROM (\r\n            SELECT obj.data\r\n            '\r\n            || query\r\n            ||\r\n            ' ORDER BY ' || order_by ||\r\n            ' OFFSET ' || offset_ || ' LIMIT ' || limit_ || ') T'\r\n    INTO objects;\r\n    IF gui THEN\r\n\r\n        EXECUTE E'SELECT count(1)\r\n        '|| query\r\n        INTO number_of_objects;\r\n\r\n        EXECUTE E'SELECT TO_CHAR(\r\n\tMAX(\r\n\t\tGREATEST(obj.created_time, (\r\n\t\t\tSELECT TO_TIMESTAMP(MAX(date_time),\\'YYYY-MM-DD hh24:mi:ss.US TZH\\')\r\n\t\t\tFROM reclada.v_revision vr\r\n\t\t\tWHERE vr.obj_id = UUID(obj.attrs ->>\\'revision\\'))\r\n\t\t)\r\n\t),\\'YYYY-MM-DD hh24:mi:ss.MS TZH\\')\r\n        '|| query\r\n        INTO last_change;\r\n\r\n        res := jsonb_build_object(\r\n        'last_change', last_change,    \r\n        'number', number_of_objects,\r\n        'objects', objects);\r\n    ELSE\r\n        res := objects;\r\n    END IF;\r\n\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP view IF EXISTS reclada.v_filter_avaliable_operator ;\n\nDROP view IF EXISTS reclada.v_object ;\nCREATE OR REPLACE VIEW reclada.v_object\nAS\n WITH t AS (\n         SELECT obj.id,\n            obj.guid,\n            obj.class,\n            r.num,\n            NULLIF(obj.attributes ->> 'revision'::text, ''::text)::uuid AS revision,\n            obj.attributes,\n            obj.status,\n            obj.created_time,\n            obj.created_by,\n            obj.transaction_id,\n            obj.parent_guid\n           FROM object obj\n             LEFT JOIN ( SELECT (r_1.attributes ->> 'num'::text)::bigint AS num,\n                    r_1.guid\n                   FROM object r_1\n                  WHERE (r_1.class IN ( SELECT reclada_object.get_guid_for_class('revision'::text) AS get_guid_for_class))) r ON r.guid = NULLIF(obj.attributes ->> 'revision'::text, ''::text)::uuid\n        )\n SELECT t.id,\n    t.guid AS obj_id,\n    t.class,\n    t.num AS revision_num,\n    os.caption AS status_caption,\n    t.revision,\n    t.created_time,\n    t.attributes AS attrs,\n    cl.for_class AS class_name,\n    (( SELECT json_agg(tmp.*) -> 0\n           FROM ( SELECT t.guid AS "GUID",\n                    t.class,\n                    os.caption AS status,\n                    t.attributes,\n                    t.transaction_id AS "transactionID",\n                    t.parent_guid) tmp))::jsonb AS data,\n    u.login AS login_created_by,\n    t.created_by,\n    t.status,\n    t.transaction_id,\n    t.parent_guid\n   FROM t\n     LEFT JOIN v_object_status os ON t.status = os.obj_id\n     LEFT JOIN v_user u ON u.obj_id = t.created_by\n     LEFT JOIN v_class_lite cl ON cl.obj_id = t.class;\nDROP view IF EXISTS reclada.v_active_object ;\nCREATE OR REPLACE VIEW reclada.v_active_object\nAS\n SELECT t.id,\n    t.obj_id,\n    t.class,\n    t.revision_num,\n    t.status,\n    t.status_caption,\n    t.revision,\n    t.created_time,\n    t.class_name,\n    t.attrs,\n    t.data,\n    t.transaction_id,\n    t.parent_guid\n   FROM v_object t\n  WHERE t.status = reclada_object.get_active_status_obj_id();\nDROP view IF EXISTS reclada.v_class ;\nCREATE OR REPLACE VIEW reclada.v_class\nAS\n SELECT obj.id,\n    obj.obj_id,\n    obj.attrs ->> 'forClass'::text AS for_class,\n    (obj.attrs ->> 'version'::text)::bigint AS version,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data,\n    obj.parent_guid\n   FROM v_active_object obj\n  WHERE obj.class_name = 'jsonschema'::text;\nDROP view IF EXISTS reclada.v_pk_for_class ;\nCREATE OR REPLACE VIEW reclada.v_pk_for_class\nAS\n SELECT obj.obj_id AS guid,\n    obj.for_class,\n    pk.pk\n   FROM v_class obj\n     JOIN ( SELECT 'File'::text AS class_name,\n            'uri'::text AS pk) pk ON pk.class_name = obj.for_class;\nDROP view IF EXISTS reclada.v_import_info ;\nCREATE OR REPLACE VIEW reclada.v_import_info\nAS\n SELECT obj.id,\n    obj.obj_id AS guid,\n    (obj.attrs ->> 'tranID'::text)::bigint AS tran_id,\n    obj.attrs ->> 'name'::text AS name,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class_name = 'ImportInfo'::text;\nDROP view IF EXISTS reclada.v_revision ;\nCREATE OR REPLACE VIEW reclada.v_revision\nAS\n SELECT obj.id,\n    obj.obj_id,\n    (obj.attrs ->> 'num'::text)::bigint AS num,\n    obj.attrs ->> 'branch'::text AS branch,\n    obj.attrs ->> 'user'::text AS "user",\n    obj.attrs ->> 'dateTime'::text AS date_time,\n    obj.attrs ->> 'old_num'::text AS old_num,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class_name = 'revision'::text;\nDROP function IF EXISTS reclada.xor ;\n\n\nupdate reclada.object\n    set attributes = '\n{\n    "schema": {\n        "type": "object",\n        "required": [\n            "command",\n            "status",\n            "type",\n            "task",\n            "environment"\n        ],\n        "properties": {\n            "tags": {\n                "type": "array",\n                "items": {\n                    "type": "string"\n                }\n            },\n            "task": {\n                "type": "string",\n                "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"\n            },\n            "type": {\n                "type": "string"\n            },\n            "runner": {\n                "type": "string",\n                "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"\n            },\n            "status": {\n                "type": "string",\n                "enum ": [\n                    "up",\n                    "down",\n                    "idle"\n                ]\n            },\n            "command": {\n                "type": "string"\n            },\n            "environment": {\n                "type": "string",\n                "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"\n            },\n            "inputParameters": {\n                "type": "array",\n                "items": {\n                    "type": "object"\n                }\n            },\n            "outputParameters": {\n                "type": "array",\n                "items": {\n                    "type": "object"\n                }\n            }\n        }\n    },\n    "version": "1",\n    "forClass": "Runner"\n}'::jsonb\n    where class = reclada_object.get_jsonschema_GUID() \n        and attributes->>'forClass' = 'Runner';	2021-10-28 10:54:15.658385+00
42	41	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n        upgrade_script text,\n        downgrade_script text\n    );\n    \ninsert into var_table(ver)\t\n    select max(ver) + 1\n        from dev.VER;\n        \nselect reclada.raise_exception('Can not apply this version!') \n    where not exists\n    (\n        select ver from var_table where ver = 41 --!!! write current version HERE !!!\n    );\n\nCREATE TEMP TABLE tmp\n(\n    id int GENERATED ALWAYS AS IDENTITY,\n    str text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n    from tmp ttt\n    inner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n    inner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n                split_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n        inner JOIN LATERAL\n    (\n        select case\n                when obj.typ = 'trigger'\n                    then\n                        (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n    inner JOIN LATERAL\n    (\n        select case \n                when obj.typ in ('function', 'procedure')\n                    then\n                        case \n                            when EXISTS\n                                (\n                                    SELECT 1 a\n                                        FROM pg_proc p \n                                        join pg_namespace n \n                                            on p.pronamespace = n.oid \n                                            where n.nspname||'.'||p.proname = obj.nam\n                                        LIMIT 1\n                                ) \n                                then (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n                            else ''\n                        end\n                when obj.typ = 'view'\n                    then\n                        case \n                            when EXISTS\n                                (\n                                    select 1 a \n                                        from pg_views v \n                                            where v.schemaname||'.'||v.viewname = obj.nam\n                                        LIMIT 1\n                                ) \n                                then E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n                            else ''\n                        end\n                when obj.typ = 'trigger'\n                    then\n                        case\n                            when EXISTS\n                                (\n                                    select 1 a\n                                        from pg_trigger v\n                                            where v.tgname = obj.nam\n                                        LIMIT 1\n                                )\n                                then (select pg_catalog.pg_get_triggerdef(oid, true)\n                                        from pg_trigger\n                                        where tgname = obj.nam)||';'\n                            else ''\n                        end\n                else \n                    ttt.str\n            end as v\n    )  scr ON TRUE\n    where ttt.id = tmp.id\n        and tmp.str like '--{%/%}';\n    \nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\n\ni 'view/reclada.v_PK_for_class.sql'\ni 'view/reclada.v_DTO_json_schema.sql'\ni 'view/reclada.v_filter_between.sql'\n\nSELECT reclada_object.create_subclass('{\n    "class": "RecladaObject",\n    "attributes": {\n        "newClass": "DTOJsonSchema",\n        "properties": {\n            "function": {"type": "string"},\n            "schema":{"type": "object"}\n        },\n        "required": ["function","schema"]\n    }\n}'::jsonb);\n\nSELECT reclada_object.create(\n    '{\n        "class": "DTOJsonSchema",\n        "attributes": {\n            "function":"reclada_object.get_query_condition_filter",\n            "schema":{\n                "type": "object",\n                "id": "expr",\n                "properties": {\n                    "value": {\n                        "type": "array",\n                        "items": {\n                            "anyOf": [\n                                {\n                                    "type": "string"\n                                },\n                                {\n                                    "type": "null"\n                                },\n                                {\n                                    "type": "number"\n                                },\n                                {\n                                    "$ref": "expr"\n                                },\n                                {\n                                    "type": "array",\n                                    "items":{\n                                        "anyOf": [\n                                            {\n                                                "type": "string"\n                                            },\n                                            {\n                                                "type": "number"\n                                            }\n                                        ]\n                                    }\n                                }\n                            ]\n                        },\n                        "minItems": 1\n                    },\n                    "operator": {\n                        "type": "string"\n                    }\n                },\n                "required": ["value","operator"]\n            }\n        }\n    }'\n);\n\ni 'function/reclada.validate_json.sql'\ni 'function/reclada_object.get_query_condition_filter.sql'\ni 'function/api.reclada_object_list.sql'\n\nSELECT reclada_object.create(\n    '{\n        "class": "DTOJsonSchema",\n        "attributes": {\n            "function":"reclada_object.list",\n            "schema":{\n                "type": "object",\n                "properties": {\n                    "transactionID": {\n                        "type": "integer"\n                    },\n                    "class": {\n                        "type": "string"\n                    },\n                    "filter": {\n                        "type": "object"\n                    },\n                    "orderBy":{\n                        "type": "array",\n                        "items":{\n                            "type":"object",\n                            "properties": {\n                                "field":{\n                                    "type":"string"\n                                },\n                                "order":{\n                                    "type":"string",\n                                    "enum": ["ASC", "DESC"]\n                                }\n                            },\n                            "required": ["field"]\n                        }\n                    },\n                    "limit":{\n                        "anyOf": [\n                            {\n                                "type": "string",\n                                "enum": ["ALL"]\n                            },\n                            {\n                                "type": "integer"\n                            }\n                        ]\n                    },\n                    "offset":{\n                        "type": "integer"\n                    }\n                },\n                "anyOf": [\n                    {\n                        "required": [\n                            "transactionID"\n                        ]\n                    },\n                    {\n                        "required": [\n                            "class"\n                        ]\n                    },\n                    {\n                        "required": [\n                            "filter"\n                        ]\n                    }\n                ]\n            }\n        }\n    }'\n);\n\ni 'function/reclada_object.list.sql'\ni 'function/reclada_object.parse_filter.sql'\ni 'view/reclada.v_object.sql'\ni 'view/reclada.v_filter_avaliable_operator.sql'\ni 'view/reclada.v_filter_inner_operator.sql'\n\n\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n    select ver, upgrade_script, downgrade_script\n        from var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, curren version: ' \n                            || (select ver from var_table)::text\n                          );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\n\nDROP view IF EXISTS reclada.v_pk_for_class ;\nCREATE OR REPLACE VIEW reclada.v_pk_for_class\nAS\n SELECT obj.obj_id AS guid,\n    obj.for_class,\n    pk.pk\n   FROM v_class obj\n     JOIN ( SELECT 'File'::text AS class_name,\n            'uri'::text AS pk) pk ON pk.class_name = obj.for_class;\nDROP view IF EXISTS reclada.v_DTO_json_schema ;\n\n\ndelete from reclada.object \n    where class in (select reclada_object.get_GUID_for_class('DTOJsonSchema'));\n\ndelete from reclada.object \n    where guid in (select reclada_object.get_GUID_for_class('DTOJsonSchema'));\n\nDROP function IF EXISTS reclada.validate_json ;\n\nDROP function IF EXISTS reclada_object.get_query_condition_filter ;\nCREATE OR REPLACE FUNCTION reclada_object.get_query_condition_filter(data jsonb)\n RETURNS text\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE \r\n    _count   INT;\r\n    _res     TEXT;\r\nBEGIN \r\n    -- TODO: to change VOLATILE -> IMMUTABLE, remove CREATE TEMP TABLE\r\n    CREATE TEMP TABLE mytable AS\r\n        SELECT  lvl             ,  rn   , idx  ,\r\n                upper(op) as op ,  prev , val  ,  \r\n                parsed\r\n            FROM reclada_object.parse_filter(data);\r\n\r\n    PERFORM reclada.raise_exception('operator does not allowed ' || t.op,'reclada_object.get_query_condition_filter')\r\n        FROM mytable t\r\n        LEFT JOIN reclada.v_filter_avaliable_operator op\r\n            ON t.op = op.operator\r\n            WHERE op.operator IS NULL;\r\n\r\n    UPDATE mytable u\r\n        SET parsed = to_jsonb(p.v)\r\n            FROM mytable t\r\n            left join reclada.v_filter_avaliable_operator o\r\n                on o.operator = t.op\r\n            JOIN LATERAL \r\n            (\r\n                SELECT  t.parsed #>> '{}' v\r\n            ) as pt\r\n                ON TRUE\r\n            LEFT JOIN reclada.v_filter_mapping fm\r\n                ON pt.v = fm.pattern\r\n            JOIN LATERAL \r\n            (\r\n                SELECT CASE \r\n                        WHEN fm.repl is not NULL \r\n                            then '(''"''||' ||fm.repl ||'||''"'')::jsonb' -- don't use FORMAT (concat null)\r\n                        -- WHEN pt.v LIKE '{attributes,%}'\r\n                        --     THEN format('attrs #> ''%s''', REPLACE(pt.v,'{attributes,','{'))\r\n                        WHEN jsonb_typeof(t.parsed) in ('number', 'boolean')\r\n                            then \r\n                                case \r\n                                    when o.input_type in ('NUMERIC','INT')\r\n                                        then pt.v\r\n                                    else '''' || pt.v || '''::jsonb'\r\n                                end\r\n                        WHEN jsonb_typeof(t.parsed) = 'string' \r\n                            then    \r\n                                case\r\n                                    WHEN pt.v LIKE '{%}'\r\n                                        THEN\r\n                                            case\r\n                                                when o.input_type = 'TEXT'\r\n                                                    then format('(data #>> ''%s'')', pt.v)\r\n                                                when o.input_type = 'NUMERIC'\r\n                                                    then format('(data #>> ''%s'')::NUMERIC', pt.v)\r\n                                                when o.input_type = 'INT'\r\n                                                    then format('(data #>> ''%s'')::INT', pt.v)\r\n                                                else\r\n                                                    format('data #> ''%s''', pt.v)\r\n                                            end\r\n                                    when o.input_type = 'TEXT'\r\n                                        then ''''||REPLACE(pt.v,'''','''''')||''''\r\n                                    else\r\n                                        '''"'||REPLACE(pt.v,'''','''''')||'"''::jsonb'\r\n                                end\r\n                        WHEN jsonb_typeof(t.parsed) = 'null'\r\n                            then 'null'\r\n                        WHEN jsonb_typeof(t.parsed) = 'array'\r\n                            then ''''||REPLACE(pt.v,'''','''''')||'''::jsonb'\r\n                        ELSE\r\n                            pt.v\r\n                    END AS v\r\n            ) as p\r\n                ON TRUE\r\n            WHERE t.lvl = u.lvl\r\n                AND t.rn = u.rn\r\n                AND t.parsed IS NOT NULL;\r\n                \r\n\r\n    INSERT INTO mytable (lvl,rn)\r\n        VALUES (0,0);\r\n    \r\n    _count := 1;\r\n    \r\n    WHILE (_count>0) LOOP\r\n        WITH r AS \r\n        (\r\n            UPDATE mytable\r\n                SET parsed = to_json(t.converted)::JSONB \r\n                FROM \r\n                (\r\n                    SELECT     \r\n                            res.lvl-1 lvl,\r\n                            res.prev rn,\r\n                            res.op,\r\n                            1 q,\r\n                            CASE COUNT(1) \r\n                                WHEN 1\r\n                                    THEN \r\n                                        CASE o.output_type\r\n                                            when 'NUMERIC'\r\n                                                then format('(%s %s)::TEXT::JSONB', res.op, min(res.parsed #>> '{}') )\r\n                                            else \r\n                                                format('(%s %s)', res.op, min(res.parsed #>> '{}') )\r\n                                        end\r\n                                ELSE\r\n                                    CASE \r\n                                        when o.output_type = 'TEXT'\r\n                                            then '(''"''||'||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op)||'||''"'')::JSONB'\r\n                                        when o.output_type in ('NUMERIC','INT')\r\n                                            then '('||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op)||')::TEXT::JSONB'\r\n                                        else\r\n                                            '('||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op)||')'\r\n                                    end\r\n                            end AS converted\r\n                        FROM mytable res \r\n                        LEFT JOIN reclada.v_filter_avaliable_operator o\r\n                            ON o.operator = res.op\r\n                            WHERE res.parsed IS NOT NULL\r\n                                AND res.lvl = (SELECT max(lvl)+1 FROM mytable WHERE parsed IS NULL)\r\n                            GROUP BY  res.prev, res.op, res.lvl, o.input_type, o.output_type\r\n                ) t\r\n                WHERE\r\n                    t.lvl = mytable.lvl\r\n                        AND t.rn = mytable.rn\r\n                RETURNING 1\r\n        )\r\n            SELECT COUNT(1) \r\n                FROM r\r\n                INTO _count;\r\n    END LOOP;\r\n    \r\n    SELECT parsed #>> '{}' \r\n        FROM mytable\r\n            WHERE lvl = 0 AND rn = 0\r\n        INTO _res;\r\n    perform reclada.raise_notice( _res);\r\n    DROP TABLE mytable;\r\n    RETURN _res;\r\nEND \r\n$function$\n;\nDROP function IF EXISTS api.reclada_object_list ;\nCREATE OR REPLACE FUNCTION api.reclada_object_list(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    class               text;\r\n    user_info           jsonb;\r\n    result              jsonb;\r\n    _filter             jsonb;\r\nBEGIN\r\n\r\n    class := data->>'class';\r\n    IF(class IS NULL) THEN\r\n        RAISE EXCEPTION 'reclada object class not specified';\r\n    END IF;\r\n\r\n    _filter = data->'filter';\r\n\r\n    select format(  '{\r\n                        "filter":\r\n                        {\r\n                            "operator":"AND",\r\n                            "value":[\r\n                                {\r\n                                    "operator":"=",\r\n                                    "value":["{class}","%s"]\r\n                                },\r\n                                %s\r\n                            ]\r\n                        }\r\n                    }',\r\n            class,\r\n            _filter\r\n        )::jsonb \r\n        into _filter;\r\n    data := data || _filter;\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF (NOT(reclada_user.is_allowed(user_info, 'list', class))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'list', class;\r\n    END IF;\r\n\r\n    SELECT reclada_object.list(data, true) INTO result;\r\n\r\n    RETURN result;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.list ;\nCREATE OR REPLACE FUNCTION reclada_object.list(data jsonb, gui boolean DEFAULT false)\n RETURNS jsonb\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    class               text;\r\n    attrs               jsonb;\r\n    order_by_jsonb      jsonb;\r\n    order_by            text;\r\n    limit_              text;\r\n    offset_             text;\r\n    query_conditions    text;\r\n    number_of_objects   int;\r\n    objects             jsonb;\r\n    res                 jsonb;\r\n    query               text;\r\n    class_uuid          uuid;\r\n    last_change         text;\r\n    tran_id             bigint;\r\n    _filter             JSONB;\r\nBEGIN\r\n\r\n    tran_id := (data->>'transactionID')::bigint;\r\n    class := data->>'class';\r\n    _filter = data->'filter';\r\n    IF (class IS NULL and tran_id IS NULL and _filter IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object class, transactionID and filter are not specified';\r\n    END IF;\r\n\r\n    order_by_jsonb := data->'orderBy';\r\n    IF ((order_by_jsonb IS NULL) OR\r\n        (order_by_jsonb = 'null'::jsonb) OR\r\n        (order_by_jsonb = '[]'::jsonb)) THEN\r\n        order_by_jsonb := '[{"field": "GUID", "order": "ASC"}]'::jsonb;\r\n    END IF;\r\n    IF (jsonb_typeof(order_by_jsonb) != 'array') THEN\r\n    \t\torder_by_jsonb := format('[%s]', order_by_jsonb);\r\n    END IF;\r\n    SELECT string_agg(\r\n        format(E'obj.data#>''{%s}'' %s', T.value->>'field', COALESCE(ord.v, 'ASC')),\r\n        ' , ')\r\n    FROM jsonb_array_elements(order_by_jsonb) T\r\n    LEFT JOIN LATERAL\r\n    (\r\n        select upper(T.value->>'order') v\r\n    ) ord on true\r\n    LEFT JOIN LATERAL\r\n    (\r\n        SELECT reclada.raise_exception('order does not allowed '|| ord.v,'reclada_object.list')\r\n            where ord.v not in ('ASC', 'DESC')\r\n    ) V on true\r\n    INTO order_by;\r\n\r\n    limit_ := data->>'limit';\r\n    IF (limit_ IS NULL) THEN\r\n        limit_ := 500;\r\n    END IF;\r\n    IF ((limit_ ~ '(\\D+)') AND (limit_ != 'ALL')) THEN\r\n    \t\tRAISE EXCEPTION 'The limit must be an integer number or "ALL"';\r\n    END IF;\r\n\r\n    offset_ := data->>'offset';\r\n    IF (offset_ IS NULL) THEN\r\n        offset_ := 0;\r\n    END IF;\r\n    IF (offset_ ~ '(\\D+)') THEN\r\n    \t\tRAISE EXCEPTION 'The offset must be an integer number';\r\n    END IF;\r\n\r\n    IF (_filter IS NOT NULL) THEN\r\n        query_conditions := reclada_object.get_query_condition_filter(_filter);\r\n    ELSE\r\n        class_uuid := reclada.try_cast_uuid(class);\r\n\r\n        if class_uuid is not null then\r\n            select v.for_class \r\n                from reclada.v_class_lite v\r\n                    where class_uuid = v.obj_id\r\n            into class;\r\n\r\n            IF (class IS NULL) THEN\r\n                RAISE EXCEPTION 'Class not found by GUID: %', class_uuid::text;\r\n            END IF;\r\n        end if;\r\n\r\n        attrs := data->'attributes' || '{}'::jsonb;\r\n\r\n        SELECT\r\n            string_agg(\r\n                format(\r\n                    E'(%s)',\r\n                    condition\r\n                ),\r\n                ' AND '\r\n            )\r\n            FROM (\r\n                SELECT\r\n                    format('obj.class_name = ''%s''', class) AS condition\r\n                        where class is not null\r\n                            and class_uuid is null\r\n                UNION\r\n                    SELECT format('obj.class = ''%s''', class_uuid) AS condition\r\n                        where class_uuid is not null\r\n                UNION\r\n                    SELECT format('obj.transaction_id = %s', tran_id) AS condition\r\n                        where tran_id is not null\r\n                UNION\r\n                    SELECT CASE\r\n                            WHEN jsonb_typeof(data->'GUID') = 'array' THEN\r\n                            (\r\n                                SELECT string_agg\r\n                                    (\r\n                                        format(\r\n                                            E'(%s)',\r\n                                            reclada_object.get_query_condition(cond, E'data->''GUID''') -- TODO: change data->'GUID' to obj_id(GUID)\r\n                                        ),\r\n                                        ' AND '\r\n                                    )\r\n                                    FROM jsonb_array_elements(data->'GUID') AS cond\r\n                            )\r\n                            ELSE reclada_object.get_query_condition(data->'GUID', E'data->''GUID''') -- TODO: change data->'GUID' to obj_id(GUID)\r\n                        END AS condition\r\n                    WHERE coalesce(data->'GUID','null'::jsonb) != 'null'::jsonb\r\n                UNION\r\n                SELECT\r\n                    CASE\r\n                        WHEN jsonb_typeof(value) = 'array'\r\n                            THEN\r\n                                (\r\n                                    SELECT string_agg\r\n                                        (\r\n                                            format\r\n                                            (\r\n                                                E'(%s)',\r\n                                                reclada_object.get_query_condition(cond, format(E'attrs->%L', key))\r\n                                            ),\r\n                                            ' AND '\r\n                                        )\r\n                                        FROM jsonb_array_elements(value) AS cond\r\n                                )\r\n                        ELSE reclada_object.get_query_condition(value, format(E'attrs->%L', key))\r\n                    END AS condition\r\n                FROM jsonb_each(attrs)\r\n                WHERE attrs != ('{}'::jsonb)\r\n            ) conds\r\n        INTO query_conditions;\r\n    END IF;\r\n    query := 'FROM reclada.v_active_object obj WHERE ' || query_conditions;\r\n\r\n    -- RAISE NOTICE 'conds: %', '\r\n    --             SELECT obj.data\r\n    --             '\r\n    --             || query\r\n    --             ||\r\n    --             ' ORDER BY ' || order_by ||\r\n    --             ' OFFSET ' || offset_ || ' LIMIT ' || limit_ ;\r\n    EXECUTE E'SELECT to_jsonb(array_agg(T.data))\r\n        FROM (\r\n            SELECT obj.data\r\n            '\r\n            || query\r\n            ||\r\n            ' ORDER BY ' || order_by ||\r\n            ' OFFSET ' || offset_ || ' LIMIT ' || limit_ || ') T'\r\n    INTO objects;\r\n    IF gui THEN\r\n\r\n        EXECUTE E'SELECT count(1)\r\n        '|| query\r\n        INTO number_of_objects;\r\n\r\n        EXECUTE E'SELECT TO_CHAR(\r\n\tMAX(\r\n\t\tGREATEST(obj.created_time, (\r\n\t\t\tSELECT TO_TIMESTAMP(MAX(date_time),\\'YYYY-MM-DD hh24:mi:ss.US TZH\\')\r\n\t\t\tFROM reclada.v_revision vr\r\n\t\t\tWHERE vr.obj_id = UUID(obj.attrs ->>\\'revision\\'))\r\n\t\t)\r\n\t),\\'YYYY-MM-DD hh24:mi:ss.MS TZH\\')\r\n        '|| query\r\n        INTO last_change;\r\n\r\n        res := jsonb_build_object(\r\n        'last_change', last_change,    \r\n        'number', number_of_objects,\r\n        'objects', objects);\r\n    ELSE\r\n        res := objects;\r\n    END IF;\r\n\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.parse_filter ;\nCREATE OR REPLACE FUNCTION reclada_object.parse_filter(data jsonb)\n RETURNS TABLE(lvl integer, rn bigint, idx bigint, op text, prev bigint, val jsonb, parsed jsonb)\n LANGUAGE sql\n IMMUTABLE\nAS $function$\r\n    WITH RECURSIVE f AS \r\n    (\r\n        SELECT data AS v\r\n    ),\r\n    pr AS \r\n    (\r\n        SELECT \tformat(' %s ',f.v->>'operator') AS op, \r\n                val.v AS val,\r\n                1 AS lvl,\r\n                row_number() OVER(ORDER BY idx) AS rn,\r\n                val.idx idx,\r\n                0::BIGINT prev\r\n            FROM f, jsonb_array_elements(f.v->'value') WITH ordinality AS val(v, idx)\r\n    ),\r\n    res AS\r\n    (\t\r\n        SELECT \tpr.lvl\t,\r\n                pr.rn\t,\r\n                pr.idx  ,\r\n                pr.op\t,\r\n                pr.prev ,\r\n                pr.val\t,\r\n                CASE jsonb_typeof(pr.val) \r\n                    WHEN 'object'\t\r\n                        THEN NULL\r\n                    ELSE pr.val\r\n                END AS parsed\r\n            FROM pr\r\n            WHERE prev = 0 \r\n                AND lvl = 1\r\n        UNION ALL\r\n        SELECT \tttt.lvl\t,\r\n                ROW_NUMBER() OVER(ORDER BY ttt.idx) AS rn,\r\n                ttt.idx,\r\n                ttt.op\t,\r\n                ttt.prev,\r\n                ttt.val ,\r\n                CASE jsonb_typeof(ttt.val) \r\n                    WHEN 'object'\t\r\n                        THEN NULL\r\n                    ELSE ttt.val\r\n                end AS parsed\r\n            FROM\r\n            (\r\n                SELECT \tres.lvl + 1 AS lvl,\r\n                        format(' %s ',res.val->>'operator') AS op,\r\n                        res.rn AS prev\t,\r\n                        val.v  AS val,\r\n                        val.idx\r\n                    FROM res, \r\n                         jsonb_array_elements(res.val->'value') WITH ordinality AS val(v, idx)\r\n            ) ttt\r\n    )\r\n    SELECT \tr.lvl\t,\r\n            r.rn\t,\r\n            r.idx   ,\r\n            r.op\t,\r\n            r.prev  ,\r\n            r.val\t,\r\n            r.parsed\r\n        FROM res r\r\n$function$\n;\n\n\nDROP VIEW IF EXISTS reclada.v_revision;\nDROP VIEW IF EXISTS reclada.v_import_info;\nDROP VIEW IF EXISTS reclada.v_pk_for_class;\nDROP VIEW IF EXISTS reclada.v_class;\nDROP VIEW IF EXISTS reclada.v_active_object;\nDROP VIEW IF EXISTS reclada.v_object;\n\nDROP view IF EXISTS reclada.v_object ;\nCREATE OR REPLACE VIEW reclada.v_object\nAS\n WITH t AS (\n         SELECT obj.id,\n            obj.guid,\n            obj.class,\n            r.num,\n            NULLIF(obj.attributes ->> 'revision'::text, ''::text)::uuid AS revision,\n            obj.attributes,\n            obj.status,\n            obj.created_time,\n            obj.created_by,\n            obj.transaction_id,\n            obj.parent_guid\n           FROM object obj\n             LEFT JOIN ( SELECT (r_1.attributes ->> 'num'::text)::bigint AS num,\n                    r_1.guid\n                   FROM object r_1\n                  WHERE (r_1.class IN ( SELECT reclada_object.get_guid_for_class('revision'::text) AS get_guid_for_class))) r ON r.guid = NULLIF(obj.attributes ->> 'revision'::text, ''::text)::uuid\n        )\n SELECT t.id,\n    t.guid AS obj_id,\n    t.class,\n    t.num AS revision_num,\n    os.caption AS status_caption,\n    t.revision,\n    t.created_time,\n    t.attributes AS attrs,\n    cl.for_class AS class_name,\n    (( SELECT json_agg(tmp.*) -> 0\n           FROM ( SELECT t.guid AS "GUID",\n                    t.class,\n                    os.caption AS status,\n                    t.attributes,\n                    t.transaction_id AS "transactionID",\n                    t.parent_guid AS "parentGUID") tmp))::jsonb AS data,\n    u.login AS login_created_by,\n    t.created_by,\n    t.status,\n    t.transaction_id,\n    t.parent_guid\n   FROM t\n     LEFT JOIN v_object_status os ON t.status = os.obj_id\n     LEFT JOIN v_user u ON u.obj_id = t.created_by\n     LEFT JOIN v_class_lite cl ON cl.obj_id = t.class;\nDROP view IF EXISTS reclada.v_active_object ;\nCREATE OR REPLACE VIEW reclada.v_active_object\nAS\n SELECT t.id,\n    t.obj_id,\n    t.class,\n    t.revision_num,\n    t.status,\n    t.status_caption,\n    t.revision,\n    t.created_time,\n    t.class_name,\n    t.attrs,\n    t.data,\n    t.transaction_id,\n    t.parent_guid\n   FROM v_object t\n  WHERE t.status = reclada_object.get_active_status_obj_id();\nDROP view IF EXISTS reclada.v_class ;\nCREATE OR REPLACE VIEW reclada.v_class\nAS\n SELECT obj.id,\n    obj.obj_id,\n    obj.attrs ->> 'forClass'::text AS for_class,\n    (obj.attrs ->> 'version'::text)::bigint AS version,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data,\n    obj.parent_guid\n   FROM v_active_object obj\n  WHERE obj.class_name = 'jsonschema'::text;\nDROP view IF EXISTS reclada.v_pk_for_class ;\nCREATE OR REPLACE VIEW reclada.v_pk_for_class\nAS\n SELECT obj.obj_id AS guid,\n    obj.for_class,\n    pk.pk\n   FROM v_class obj\n     JOIN ( SELECT 'File'::text AS class_name,\n            'uri'::text AS pk) pk ON pk.class_name = obj.for_class;\nDROP view IF EXISTS reclada.v_import_info ;\nCREATE OR REPLACE VIEW reclada.v_import_info\nAS\n SELECT obj.id,\n    obj.obj_id AS guid,\n    (obj.attrs ->> 'tranID'::text)::bigint AS tran_id,\n    obj.attrs ->> 'name'::text AS name,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class_name = 'ImportInfo'::text;\nDROP view IF EXISTS reclada.v_revision ;\nCREATE OR REPLACE VIEW reclada.v_revision\nAS\n SELECT obj.id,\n    obj.obj_id,\n    (obj.attrs ->> 'num'::text)::bigint AS num,\n    obj.attrs ->> 'branch'::text AS branch,\n    obj.attrs ->> 'user'::text AS "user",\n    obj.attrs ->> 'dateTime'::text AS date_time,\n    obj.attrs ->> 'old_num'::text AS old_num,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class_name = 'revision'::text;\nDROP view IF EXISTS reclada.v_filter_between ;\n\n\nDROP view IF EXISTS reclada.v_filter_avaliable_operator ;\nCREATE OR REPLACE VIEW reclada.v_filter_avaliable_operator\nAS\n SELECT ' = '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type\nUNION\n SELECT ' LIKE '::text AS operator,\n    'TEXT'::text AS input_type,\n    'BOOL'::text AS output_type\nUNION\n SELECT ' NOT LIKE '::text AS operator,\n    'TEXT'::text AS input_type,\n    'BOOL'::text AS output_type\nUNION\n SELECT ' || '::text AS operator,\n    'TEXT'::text AS input_type,\n    'TEXT'::text AS output_type\nUNION\n SELECT ' ~ '::text AS operator,\n    'TEXT'::text AS input_type,\n    'BOOL'::text AS output_type\nUNION\n SELECT ' !~ '::text AS operator,\n    'TEXT'::text AS input_type,\n    'BOOL'::text AS output_type\nUNION\n SELECT ' ~* '::text AS operator,\n    'TEXT'::text AS input_type,\n    'BOOL'::text AS output_type\nUNION\n SELECT ' !~* '::text AS operator,\n    'TEXT'::text AS input_type,\n    'BOOL'::text AS output_type\nUNION\n SELECT ' SIMILAR TO '::text AS operator,\n    'TEXT'::text AS input_type,\n    'BOOL'::text AS output_type\nUNION\n SELECT ' > '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type\nUNION\n SELECT ' < '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type\nUNION\n SELECT ' <= '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type\nUNION\n SELECT ' != '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type\nUNION\n SELECT ' >= '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type\nUNION\n SELECT ' AND '::text AS operator,\n    'BOOL'::text AS input_type,\n    'BOOL'::text AS output_type\nUNION\n SELECT ' OR '::text AS operator,\n    'BOOL'::text AS input_type,\n    'BOOL'::text AS output_type\nUNION\n SELECT ' NOT '::text AS operator,\n    'BOOL'::text AS input_type,\n    'BOOL'::text AS output_type\nUNION\n SELECT ' # '::text AS operator,\n    'BOOL'::text AS input_type,\n    'BOOL'::text AS output_type\nUNION\n SELECT ' IS '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type\nUNION\n SELECT ' IS NOT '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type\nUNION\n SELECT ' IN '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type\nUNION\n SELECT ' , '::text AS operator,\n    'TEXT'::text AS input_type,\n    NULL::text AS output_type\nUNION\n SELECT ' @> '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type\nUNION\n SELECT ' <@ '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type\nUNION\n SELECT ' + '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type\nUNION\n SELECT ' - '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type\nUNION\n SELECT ' * '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type\nUNION\n SELECT ' / '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type\nUNION\n SELECT ' % '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type\nUNION\n SELECT ' ^ '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type\nUNION\n SELECT ' |/ '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type\nUNION\n SELECT ' ||/ '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type\nUNION\n SELECT ' !! '::text AS operator,\n    'INT'::text AS input_type,\n    'NUMERIC'::text AS output_type\nUNION\n SELECT ' @ '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type\nUNION\n SELECT ' & '::text AS operator,\n    'INT'::text AS input_type,\n    'INT'::text AS output_type\nUNION\n SELECT ' | '::text AS operator,\n    'INT'::text AS input_type,\n    'INT'::text AS output_type\nUNION\n SELECT ' << '::text AS operator,\n    'INT'::text AS input_type,\n    'INT'::text AS output_type\nUNION\n SELECT ' >> '::text AS operator,\n    'INT'::text AS input_type,\n    'INT'::text AS output_type;\nDROP view IF EXISTS reclada.v_filter_inner_operator ;\n	2021-11-08 11:01:49.274513+00
43	42	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n        upgrade_script text,\n        downgrade_script text\n    );\n    \ninsert into var_table(ver)\t\n    select max(ver) + 1\n        from dev.VER;\n        \nselect reclada.raise_exception('Can not apply this version!') \n    where not exists\n    (\n        select ver from var_table where ver = 42 --!!! write current version HERE !!!\n    );\n\nCREATE TEMP TABLE tmp\n(\n    id int GENERATED ALWAYS AS IDENTITY,\n    str text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n    from tmp ttt\n    inner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n    inner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n                split_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n        inner JOIN LATERAL\n    (\n        select case\n                when obj.typ = 'trigger'\n                    then\n                        (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n    inner JOIN LATERAL\n    (\n        select case \n                when obj.typ in ('function', 'procedure')\n                    then\n                        case \n                            when EXISTS\n                                (\n                                    SELECT 1 a\n                                        FROM pg_proc p \n                                        join pg_namespace n \n                                            on p.pronamespace = n.oid \n                                            where n.nspname||'.'||p.proname = obj.nam\n                                        LIMIT 1\n                                ) \n                                then (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n                            else ''\n                        end\n                when obj.typ = 'view'\n                    then\n                        case \n                            when EXISTS\n                                (\n                                    select 1 a \n                                        from pg_views v \n                                            where v.schemaname||'.'||v.viewname = obj.nam\n                                        LIMIT 1\n                                ) \n                                then E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n                            else ''\n                        end\n                when obj.typ = 'trigger'\n                    then\n                        case\n                            when EXISTS\n                                (\n                                    select 1 a\n                                        from pg_trigger v\n                                            where v.tgname = obj.nam\n                                        LIMIT 1\n                                )\n                                then (select pg_catalog.pg_get_triggerdef(oid, true)\n                                        from pg_trigger\n                                        where tgname = obj.nam)||';'\n                            else ''\n                        end\n                else \n                    ttt.str\n            end as v\n    )  scr ON TRUE\n    where ttt.id = tmp.id\n        and tmp.str like '--{%/%}';\n    \nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ni 'function/reclada_object.datasource_insert.sql'\ni 'view/reclada.v_task.sql'\ni 'view/reclada.v_pk_for_class.sql'\ni 'view/reclada.v_object.sql'\n\n\nSELECT reclada_object.create_subclass('{\n    "class": "Task",\n    "attributes": {\n        "newClass": "PipelineLite",\n        "properties": {\n            "tasks": {\n                "items": {\n                    "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}",\n                    "type": "string"\n                },\n                "type": "array",\n                "minItems": 1\n            }\n        },\n        "required": ["tasks"]\n    }\n}'::jsonb);\n\nselect reclada_object.create(('{\n    "GUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",\n    "class":"PipelineLite",\n    "attributes":{\n        "command":"",\n        "type":"pipelineLite",\n        "tasks":[\n                    "cc7b41e6-4d57-4e6f-9d10-6da0d5a4c39e",\n                    "618b967b-f2ff-4f3b-8889-b63eb6b73b6e",\n                    "678bbbcc-a6db-425b-b9cd-bdb302c8d290",\n                    "638c7f45-ad21-4b59-a89d-5853aa9ad859",\n                    "2d6b0afc-fdf0-4b54-8a67-704da585196e",\n                    "ff3d88e2-1dd9-43b3-873f-75e4dc3c0629",\n                    "83fbb176-adb7-4da0-bd1f-4ce4aba1b87a",\n                    "27de6e85-1749-4946-8a53-4316321fc1e8",\n                    "4478768c-0d01-4ad9-9a10-2bef4d4b8007"'/*,\n                    "35e5bce3-6578-41ae-a7e2-d20b9a19ba00",\n                    "b68040ff-2f37-42da-b865-8edf589acdaa"*/||'\n        ]\n    }\n}')::jsonb);\n/*\n{\n    "pipeline": [\n        {"stage": "0", "command": "./pipeline/create_pipeline.sh"},\n        {"stage": "1", "command": "./pipeline/copy_file_from_s3.sh"},\n        {"stage": "2", "command": "./pipeline/badgerdoc_run.sh"},\n        {"stage": "3", "command": "./pipeline/bd2reclada_run.sh"},\n        {"stage": "4", "command": "./pipeline/loading_data_to_db.sh"},\n        {"stage": "5", "command": "./pipeline/scinlp_run.sh"},\n        {"stage": "6", "command": "./pipeline/loading_results_to_db.sh"},\n        {"stage": "7", "command": "./pipeline/custom_task.sh"},\n        {"stage": "8", "command": "./pipeline/coping_results.sh"}\n    ]\n}\n*/\nselect reclada_object.create('{\n    "class":"Task",\n    "GUID":"cc7b41e6-4d57-4e6f-9d10-6da0d5a4c39e",\n    "parentGUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",\n    "attributes":{\n        "command":"./pipeline/create_pipeline.sh",\n        "type":"PipelineLite stage 0"\n    }\n}'::jsonb);\nselect reclada_object.create('{\n    "class":"Task",\n    "GUID":"618b967b-f2ff-4f3b-8889-b63eb6b73b6e",\n    "parentGUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",\n    "attributes":{\n        "command":"./pipeline/copy_file_from_s3.sh",\n        "type":"PipelineLite stage 1"\n    }\n}'::jsonb);\n\nselect reclada_object.create('{\n    "class":"Task",\n    "GUID":"678bbbcc-a6db-425b-b9cd-bdb302c8d290",\n    "parentGUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",\n    "attributes":{\n        "command":"./pipeline/badgerdoc_run.sh",\n        "type":"PipelineLite stage 2"\n    }\n}'::jsonb);\n\nselect reclada_object.create('{\n    "class":"Task",\n    "GUID":"638c7f45-ad21-4b59-a89d-5853aa9ad859",\n    "parentGUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",\n    "attributes":{\n        "command":"./pipeline/bd2reclada_run.sh",\n        "type":"PipelineLite stage 3"\n    }\n}'::jsonb);\n\nselect reclada_object.create('{\n    "class":"Task",\n    "GUID":"2d6b0afc-fdf0-4b54-8a67-704da585196e",\n    "parentGUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",\n    "attributes":{\n        "command":"./pipeline/loading_data_to_db.sh",\n        "type":"PipelineLite stage 4"\n    }\n}'::jsonb);\n\nselect reclada_object.create('{\n    "class":"Task",\n    "GUID":"ff3d88e2-1dd9-43b3-873f-75e4dc3c0629",\n    "parentGUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",\n    "attributes":{\n        "command":"./pipeline/scinlp_run.sh",\n        "type":"PipelineLite stage 5"\n    }\n}'::jsonb);\n\nselect reclada_object.create('{\n    "class":"Task",\n    "GUID":"83fbb176-adb7-4da0-bd1f-4ce4aba1b87a",\n    "parentGUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",\n    "attributes":{\n        "command":"./pipeline/loading_results_to_db.sh",\n        "type":"PipelineLite stage 6"\n    }\n}'::jsonb);\n\nselect reclada_object.create('{\n    "class":"Task",\n    "GUID":"27de6e85-1749-4946-8a53-4316321fc1e8",\n    "parentGUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",\n    "attributes":{\n        "command":"./pipeline/custom_task.sh",\n        "type":"PipelineLite stage 7"\n    }\n}'::jsonb);\n\nselect reclada_object.create('{\n    "class":"Task",\n    "GUID":"4478768c-0d01-4ad9-9a10-2bef4d4b8007",\n    "parentGUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",\n    "attributes":{\n        "command":"./pipeline/coping_results.sh",\n        "type":"PipelineLite stage 8"\n    }\n}'::jsonb);\n/*\nselect reclada_object.create('{\n    "class":"Task",\n    "GUID":"35e5bce3-6578-41ae-a7e2-d20b9a19ba00",\n    "parentGUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",\n    "attributes":{\n        "command":"",\n        "type":"PipelineLite step 10"\n    }\n}'::jsonb);\n\nselect reclada_object.create('{\n    "class":"Task",\n    "GUID":"b68040ff-2f37-42da-b865-8edf589acdaa",\n    "parentGUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",\n    "attributes":{\n        "command":"",\n        "type":"PipelineLite step 11"\n    }\n}'::jsonb);\n\n*/\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n    select ver, upgrade_script, downgrade_script\n        from var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, curren version: ' \n                            || (select ver from var_table)::text\n                          );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\n\nDROP function IF EXISTS reclada_object.datasource_insert ;\nCREATE OR REPLACE FUNCTION reclada_object.datasource_insert(_class_name text, _obj_id uuid, attributes jsonb)\n RETURNS void\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    dataset_guid  uuid;\r\n    uri           text;\r\n    environment   varchar;\r\n    rel_cnt       int;\r\n    dataset2ds_type text;\r\nBEGIN\r\n    IF _class_name in \r\n            ('DataSource','File') THEN\r\n\r\n        dataset2ds_type := 'defaultDataSet to DataSource';\r\n\r\n        SELECT v.obj_id\r\n        FROM reclada.v_active_object v\r\n\t    WHERE v.attrs->>'name' = 'defaultDataSet'\r\n\t    INTO dataset_guid;\r\n\r\n        SELECT count(*)\r\n        FROM reclada.v_active_object\r\n        WHERE class_name = 'Relationship'\r\n            AND (attrs->>'object')::uuid = _obj_id\r\n            AND (attrs->>'subject')::uuid = dataset_guid\r\n            AND attrs->>'type' = dataset2ds_type\r\n                INTO rel_cnt;\r\n\r\n        IF rel_cnt=0 THEN\r\n            PERFORM reclada_object.create(\r\n                format('{\r\n                    "class": "Relationship",\r\n                    "attributes": {\r\n                        "type": "%s",\r\n                        "object": "%s",\r\n                        "subject": "%s"\r\n                        }\r\n                    }', dataset2ds_type, _obj_id, dataset_guid)::jsonb);\r\n\r\n        END IF;\r\n\r\n        uri := attributes->>'uri';\r\n\r\n        SELECT attrs->>'Environment'\r\n        FROM reclada.v_active_object\r\n        WHERE class_name = 'Context'\r\n        ORDER BY created_time DESC\r\n        LIMIT 1\r\n        INTO environment;\r\n\r\n        PERFORM reclada_object.create(\r\n            format('{\r\n                "class": "Job",\r\n                "attributes": {\r\n                    "task": "c94bff30-15fa-427f-9954-d5c3c151e652",\r\n                    "status": "new",\r\n                    "type": "%s",\r\n                    "command": "./run_pipeline.sh",\r\n                    "inputParameters": [{"uri": "%s"}, {"dataSourceId": "%s"}]\r\n                    }\r\n                }', environment, uri, _obj_id)::jsonb);\r\n\r\n    END IF;\r\nEND;\r\n$function$\n;\nDROP view IF EXISTS reclada.v_task ;\n\nDROP view IF EXISTS reclada.v_pk_for_class ;\nCREATE OR REPLACE VIEW reclada.v_pk_for_class\nAS\n SELECT obj.obj_id AS guid,\n    obj.for_class,\n    pk.pk\n   FROM v_class obj\n     JOIN ( SELECT 'File'::text AS class_name,\n            'uri'::text AS pk\n        UNION\n         SELECT 'DTOJsonSchema'::text AS text,\n            'function'::text AS text) pk ON pk.class_name = obj.for_class;\n\ndelete from reclada.object \n    where class in (select reclada_object.get_GUID_for_class('PipelineLite'));\n\ndelete from reclada.object \n    where class in (select reclada_object.get_GUID_for_class('Task'))\n        and attributes ->> 'type'    like 'PipelineLite stage %'\n        and attributes ->> 'command' like './pipeline/%';\n\ndelete from reclada.object\n    where class = reclada_object.get_jsonschema_GUID()\n        and attributes ->> 'forClass' = 'PipelineLite';\n\nDROP VIEW IF EXISTS reclada.v_revision;\nDROP VIEW IF EXISTS reclada.v_dto_json_schema;\nDROP VIEW IF EXISTS reclada.v_import_info;\nDROP VIEW IF EXISTS reclada.v_pk_for_class;\nDROP VIEW IF EXISTS reclada.v_class;\nDROP VIEW IF EXISTS reclada.v_active_object;\nDROP VIEW IF EXISTS reclada.v_object;\n\nDROP view IF EXISTS reclada.v_object ;\nCREATE OR REPLACE VIEW reclada.v_object\nAS\n WITH t AS (\n         SELECT obj.id,\n            obj.guid,\n            obj.class,\n            r.num,\n            NULLIF(obj.attributes ->> 'revision'::text, ''::text)::uuid AS revision,\n            obj.attributes,\n            obj.status,\n            obj.created_time,\n            obj.created_by,\n            obj.transaction_id,\n            obj.parent_guid\n           FROM object obj\n             LEFT JOIN ( SELECT (r_1.attributes ->> 'num'::text)::bigint AS num,\n                    r_1.guid\n                   FROM object r_1\n                  WHERE (r_1.class IN ( SELECT reclada_object.get_guid_for_class('revision'::text) AS get_guid_for_class))) r ON r.guid = NULLIF(obj.attributes ->> 'revision'::text, ''::text)::uuid\n        )\n SELECT t.id,\n    t.guid AS obj_id,\n    t.class,\n    t.num AS revision_num,\n    os.caption AS status_caption,\n    t.revision,\n    t.created_time,\n    t.attributes AS attrs,\n    cl.for_class AS class_name,\n    (( SELECT json_agg(tmp.*) -> 0\n           FROM ( SELECT t.guid AS "GUID",\n                    t.class,\n                    os.caption AS status,\n                    t.attributes,\n                    t.transaction_id AS "transactionID",\n                    t.parent_guid AS "parentGUID",\n                    t.created_time AS "createdTime") tmp))::jsonb AS data,\n    u.login AS login_created_by,\n    t.created_by,\n    t.status,\n    t.transaction_id,\n    t.parent_guid\n   FROM t\n     LEFT JOIN v_object_status os ON t.status = os.obj_id\n     LEFT JOIN v_user u ON u.obj_id = t.created_by\n     LEFT JOIN v_class_lite cl ON cl.obj_id = t.class;\nDROP view IF EXISTS reclada.v_active_object ;\nCREATE OR REPLACE VIEW reclada.v_active_object\nAS\n SELECT t.id,\n    t.obj_id,\n    t.class,\n    t.revision_num,\n    t.status,\n    t.status_caption,\n    t.revision,\n    t.created_time,\n    t.class_name,\n    t.attrs,\n    t.data,\n    t.transaction_id,\n    t.parent_guid\n   FROM v_object t\n  WHERE t.status = reclada_object.get_active_status_obj_id();\nDROP view IF EXISTS reclada.v_class ;\nCREATE OR REPLACE VIEW reclada.v_class\nAS\n SELECT obj.id,\n    obj.obj_id,\n    obj.attrs ->> 'forClass'::text AS for_class,\n    (obj.attrs ->> 'version'::text)::bigint AS version,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data,\n    obj.parent_guid\n   FROM v_active_object obj\n  WHERE obj.class_name = 'jsonschema'::text;\nDROP view IF EXISTS reclada.v_pk_for_class ;\nCREATE OR REPLACE VIEW reclada.v_pk_for_class\nAS\n SELECT obj.obj_id AS guid,\n    obj.for_class,\n    pk.pk\n   FROM v_class obj\n     JOIN ( SELECT 'File'::text AS class_name,\n            'uri'::text AS pk\n        UNION\n         SELECT 'DTOJsonSchema'::text AS text,\n            'function'::text AS text) pk ON pk.class_name = obj.for_class;\nDROP view IF EXISTS reclada.v_import_info ;\nCREATE OR REPLACE VIEW reclada.v_import_info\nAS\n SELECT obj.id,\n    obj.obj_id AS guid,\n    (obj.attrs ->> 'tranID'::text)::bigint AS tran_id,\n    obj.attrs ->> 'name'::text AS name,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class_name = 'ImportInfo'::text;\nDROP view IF EXISTS reclada.v_revision ;\nCREATE OR REPLACE VIEW reclada.v_revision\nAS\n SELECT obj.id,\n    obj.obj_id,\n    (obj.attrs ->> 'num'::text)::bigint AS num,\n    obj.attrs ->> 'branch'::text AS branch,\n    obj.attrs ->> 'user'::text AS "user",\n    obj.attrs ->> 'dateTime'::text AS date_time,\n    obj.attrs ->> 'old_num'::text AS old_num,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class_name = 'revision'::text;\nDROP view IF EXISTS reclada.v_dto_json_schema ;\nCREATE OR REPLACE VIEW reclada.v_dto_json_schema\nAS\n SELECT obj.id,\n    obj.obj_id,\n    obj.attrs ->> 'function'::text AS function,\n    obj.attrs -> 'schema'::text AS schema,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data,\n    obj.parent_guid\n   FROM v_active_object obj\n  WHERE obj.class_name = 'DTOJsonSchema'::text;	2021-12-21 13:28:11.224553+00
44	43	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n        upgrade_script text,\n        downgrade_script text\n    );\n    \ninsert into var_table(ver)\t\n    select max(ver) + 1\n        from dev.VER;\n        \nselect reclada.raise_exception('Can not apply this version!') \n    where not exists\n    (\n        select ver from var_table where ver = 43 --!!! write current version HERE !!!\n    );\n\nCREATE TEMP TABLE tmp\n(\n    id int GENERATED ALWAYS AS IDENTITY,\n    str text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n    from tmp ttt\n    inner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n    inner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n                split_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n        inner JOIN LATERAL\n    (\n        select case\n                when obj.typ = 'trigger'\n                    then\n                        (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n    inner JOIN LATERAL\n    (\n        select case \n                when obj.typ in ('function', 'procedure')\n                    then\n                        case \n                            when EXISTS\n                                (\n                                    SELECT 1 a\n                                        FROM pg_proc p \n                                        join pg_namespace n \n                                            on p.pronamespace = n.oid \n                                            where n.nspname||'.'||p.proname = obj.nam\n                                        LIMIT 1\n                                ) \n                                then (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n                            else ''\n                        end\n                when obj.typ = 'view'\n                    then\n                        case \n                            when EXISTS\n                                (\n                                    select 1 a \n                                        from pg_views v \n                                            where v.schemaname||'.'||v.viewname = obj.nam\n                                        LIMIT 1\n                                ) \n                                then E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n                            else ''\n                        end\n                when obj.typ = 'trigger'\n                    then\n                        case\n                            when EXISTS\n                                (\n                                    select 1 a\n                                        from pg_trigger v\n                                            where v.tgname = obj.nam\n                                        LIMIT 1\n                                )\n                                then (select pg_catalog.pg_get_triggerdef(oid, true)\n                                        from pg_trigger\n                                        where tgname = obj.nam)||';'\n                            else ''\n                        end\n                else \n                    ttt.str\n            end as v\n    )  scr ON TRUE\n    where ttt.id = tmp.id\n        and tmp.str like '--{%/%}';\n    \nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\nSELECT reclada_object.create('{\n    "class": "jsonschema",\n    "attributes":{\n        "forClass":"ObjectDisplay",\n        "version": "1",\n        "schema":{\n            "$defs": {\n                "displayType":{\n                    "type": "object",\n                    "properties": {\n                        "orderColumn":{\n                            "type": "array",\n                            "items":{\n                                "type": "string"\n                            }\n                        },\n                        "orderRow":{\n                            "type": "array",\n                            "items":{\n                                "type": "object",\n                                "patternProperties": {\n                                    "^{.*}$": {\n                                        "type": "string",\n                                        "enum": ["ASC", "DESC"]\n                                    }\n                                }\n                            }\n                        }\n                    },\n                    "required":["orderColumn","orderRow"]\n                }\n            },\n            "properties": {\n                "classGUID": {"type": "string"},\n                "caption": {"type": "string"},\n                "flat": {"type": "bool"},\n                "table":{"$ref": "#/$defs/displayType"},\n                "card":{"$ref": "#/$defs/displayType"},\n                "preview":{"$ref": "#/$defs/displayType"},\n                "list":{"$ref": "#/$defs/displayType" }\n            },\n            "required": ["classGUID","caption"]\n        }\n    }\n}'::jsonb);\n\nSELECT reclada_object.create(('{\n    "class":"ObjectDisplay",\n    "attributes":{\n        "classGUID": "'|| reclada_object.get_GUID_for_class('ObjectDisplay') ||'",\n        "caption": "Object display"\n    }\n}')::jsonb);\n\nSELECT reclada_object.create(('{\n    "class":"ObjectDisplay",\n    "attributes":{\n        "classGUID": "'|| reclada_object.get_GUID_for_class('DataRow') ||'",\n        "caption": "Data row"\n    }\n}')::jsonb);\n\nSELECT reclada_object.create(('{\n    "class":"ObjectDisplay",\n    "attributes":{\n        "classGUID": "'|| reclada_object.get_GUID_for_class('TextBlock') ||'",\n        "caption": "Text block"\n    }\n}')::jsonb);\n\nSELECT reclada_object.create(('{\n    "class":"ObjectDisplay",\n    "attributes":{\n        "classGUID": "'|| reclada_object.get_GUID_for_class('Message') ||'",\n        "caption": "Message"\n    }\n}')::jsonb);\nSELECT reclada_object.create(('{\n    "class":"ObjectDisplay",\n    "attributes":{\n        "classGUID": "'|| reclada_object.get_GUID_for_class('Page') ||'",\n        "caption": "Page"\n    }\n}')::jsonb);\nSELECT reclada_object.create(('{\n    "class":"ObjectDisplay",\n    "attributes":{\n        "classGUID": "'|| reclada_object.get_GUID_for_class('Document') ||'",\n        "caption": "Document"\n    }\n}')::jsonb);\n\nSELECT reclada_object.create(('{\n    "class":"ObjectDisplay",\n    "attributes":{\n        "classGUID": "'|| reclada_object.get_GUID_for_class('jsonschema') ||'",\n        "caption": "Json schema"\n    }\n}')::jsonb);\n\nSELECT reclada_object.create(('{\n    "class":"ObjectDisplay",\n    "attributes":{\n        "classGUID": "'|| reclada_object.get_GUID_for_class('Job') ||'",\n        "caption": "Job"\n    }\n}')::jsonb);\n\nSELECT reclada_object.create(('{\n    "class":"ObjectDisplay",\n    "attributes":{\n        "classGUID": "'|| reclada_object.get_GUID_for_class('File') ||'",\n        "caption": "Files",\n        "table": {\n            "{attributes,name}": {\n                "caption": "File name",\n                "displayCSS": "name",\n                "width": 250,\n                "behavior":"preview"\n            },\n            "{attributes,tags}": {\n                "caption": "Tags",\n                "displayCSS": "arrayLink",\n                "width": 250,\n                "items": {\n                    "displayCSS": "link",\n                    "behavior": "preview",\n                    "class":"'|| reclada_object.get_GUID_for_class('tag') ||'"\n                }\n            },\n            "{attributes,mimeType}": {\n                "caption": "Mime type",\n                "width": 250,\n                "displayCSS": "mimeType"\n            },\n            "{attributes,checksum}": {\n                "caption": "Checksum",\n                "width": 250,\n                "displayCSS": "checksum"\n            },\n            "{status}":{\n                "caption": "Status",\n                "width": 250,\n                "displayCSS": "status"\n            },\n            "{createdTime}":{\n                "caption": "Created time",\n                "width": 250,\n                "displayCSS": "createdTime"\n            },\n            "{transactionID}":{\n                "caption": "Transaction",\n                "width": 250,\n                "displayCSS": "transactionID"\n            },\n            "orderRow": [\n                {"{attributes,name}":"ASC"},\n                {"{attributes,mimeType}":"DESC"}\n            ],\n            "orderColumn": [\n                "{attributes,name}",\n                "{attributes,mimeType}",\n                "{attributes,tags}",\n                "{status}",\n                "{createdTime}",\n                "{transactionID}"\n            ]\n        },\n        "card":{\n            "orderRow": [\n                {"{attributes,name}":"ASC"},\n                {"{attributes,mimeType}":"DESC"}\n            ],\n            "orderColumn": [\n                "{attributes,name}",\n                "{attributes,mimeType}",\n                "{attributes,tags}",\n                "{status}",\n                "{createdTime}",\n                "{transactionID}"\n            ]\n        },\n        "preview":{\n            "orderRow": [\n                {"{attributes,name}":"ASC"},\n                {"{attributes,mimeType}":"DESC"}\n            ],\n            "orderColumn": [\n                "{attributes,name}",\n                "{attributes,mimeType}",\n                "{attributes,tags}",\n                "{status}",\n                "{createdTime}",\n                "{transactionID}"\n            ]\n        },\n        "list":{\n            "orderRow": [\n                {"{attributes,name}":"ASC"},\n                {"{attributes,mimeType}":"DESC"}\n            ],\n            "orderColumn": [\n                "{attributes,name}",\n                "{attributes,mimeType}",\n                "{attributes,tags}",\n                "{status}",\n                "{createdTime}",\n                "{transactionID}"\n            ]\n        }\n    }\n}')::jsonb);\n\ni 'view/reclada.v_object_display.sql' \ni 'view/reclada.v_ui_active_object.sql' \ni 'function/reclada_object.need_flat.sql' \ni 'function/reclada_object.list.sql' \ni 'function/api.reclada_object_update.sql' \ni 'function/reclada_object.update.sql' \ni 'function/api.reclada_object_list.sql' \ni 'function/api.reclada_object_create.sql' \ni 'function/api.reclada_object_delete.sql' \n\ni 'function/api.storage_generate_presigned_get.sql'\ni 'function/api.storage_generate_presigned_post.sql'\n\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n    select ver, upgrade_script, downgrade_script\n        from var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, curren version: ' \n                            || (select ver from var_table)::text\n                          );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\n\nDROP view IF EXISTS reclada.v_ui_active_object ;\n\nDROP view IF EXISTS reclada.v_object_display ;\n\ndelete from reclada.object \n    where class in (select reclada_object.get_GUID_for_class('ObjectDisplay'));\n\ndelete from reclada.object \n    where guid in (select reclada_object.get_GUID_for_class('ObjectDisplay'));\n\nDROP function IF EXISTS reclada_object.list ;\nCREATE OR REPLACE FUNCTION reclada_object.list(data jsonb, gui boolean DEFAULT false)\n RETURNS jsonb\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    _f_name TEXT = 'reclada_object.list';\r\n    class               text;\r\n    attrs               jsonb;\r\n    order_by_jsonb      jsonb;\r\n    order_by            text;\r\n    limit_              text;\r\n    offset_             text;\r\n    query_conditions    text;\r\n    number_of_objects   int;\r\n    objects             jsonb;\r\n    res                 jsonb;\r\n    query               text;\r\n    class_uuid          uuid;\r\n    last_change         text;\r\n    tran_id             bigint;\r\n    _filter             JSONB;\r\nBEGIN\r\n\r\n    perform reclada.validate_json(data, _f_name);\r\n\r\n    tran_id := (data->>'transactionID')::bigint;\r\n    class := data->>'class';\r\n    _filter = data->'filter';\r\n    -- IF (class IS NULL and tran_id IS NULL and _filter IS NULL) THEN\r\n    --     RAISE EXCEPTION 'The reclada object class, transactionID and filter are not specified';\r\n    -- END IF;\r\n\r\n    order_by_jsonb := data->'orderBy';\r\n    IF ((order_by_jsonb IS NULL) OR\r\n        (order_by_jsonb = 'null'::jsonb) OR\r\n        (order_by_jsonb = '[]'::jsonb)) THEN\r\n        order_by_jsonb := '[{"field": "GUID", "order": "ASC"}]'::jsonb;\r\n    END IF;\r\n    -- IF (jsonb_typeof(order_by_jsonb) != 'array') THEN\r\n    -- \t\torder_by_jsonb := format('[%s]', order_by_jsonb);\r\n    -- END IF;\r\n    SELECT string_agg(\r\n        format(E'obj.data#>''{%s}'' %s', T.value->>'field', COALESCE(T.value->>'order', 'ASC')),\r\n        ' , ')\r\n        FROM jsonb_array_elements(order_by_jsonb) T\r\n        INTO order_by;\r\n\r\n    limit_ := data->>'limit';\r\n    IF (limit_ IS NULL) THEN\r\n        limit_ := 500;\r\n    END IF;\r\n    --IF ((limit_ ~ '(\\D+)') AND (limit_ != 'ALL')) THEN\r\n    --\t\tRAISE EXCEPTION 'The limit must be an integer number or "ALL"';\r\n    --END IF;\r\n\r\n    offset_ := data->>'offset';\r\n    IF (offset_ IS NULL) THEN\r\n        offset_ := 0;\r\n    END IF;\r\n    -- IF (offset_ ~ '(\\D+)') THEN\r\n    -- \t\tRAISE EXCEPTION 'The offset must be an integer number';\r\n    -- END IF;\r\n\r\n    IF (_filter IS NOT NULL) THEN\r\n        query_conditions := reclada_object.get_query_condition_filter(_filter);\r\n    ELSE\r\n        class_uuid := reclada.try_cast_uuid(class);\r\n\r\n        if class_uuid is not null then\r\n            select v.for_class \r\n                from reclada.v_class_lite v\r\n                    where class_uuid = v.obj_id\r\n            into class;\r\n\r\n            IF (class IS NULL) THEN\r\n                RAISE EXCEPTION 'Class not found by GUID: %', class_uuid::text;\r\n            END IF;\r\n        end if;\r\n\r\n        attrs := data->'attributes' || '{}'::jsonb;\r\n\r\n        SELECT\r\n            string_agg(\r\n                format(\r\n                    E'(%s)',\r\n                    condition\r\n                ),\r\n                ' AND '\r\n            )\r\n            FROM (\r\n                SELECT\r\n                    format('obj.class_name = ''%s''', class) AS condition\r\n                        where class is not null\r\n                            and class_uuid is null\r\n                UNION\r\n                    SELECT format('obj.class = ''%s''', class_uuid) AS condition\r\n                        where class_uuid is not null\r\n                UNION\r\n                    SELECT format('obj.transaction_id = %s', tran_id) AS condition\r\n                        where tran_id is not null\r\n                UNION\r\n                    SELECT CASE\r\n                            WHEN jsonb_typeof(data->'GUID') = 'array' THEN\r\n                            (\r\n                                SELECT string_agg\r\n                                    (\r\n                                        format(\r\n                                            E'(%s)',\r\n                                            reclada_object.get_query_condition(cond, E'data->''GUID''') -- TODO: change data->'GUID' to obj_id(GUID)\r\n                                        ),\r\n                                        ' AND '\r\n                                    )\r\n                                    FROM jsonb_array_elements(data->'GUID') AS cond\r\n                            )\r\n                            ELSE reclada_object.get_query_condition(data->'GUID', E'data->''GUID''') -- TODO: change data->'GUID' to obj_id(GUID)\r\n                        END AS condition\r\n                    WHERE coalesce(data->'GUID','null'::jsonb) != 'null'::jsonb\r\n                UNION\r\n                SELECT\r\n                    CASE\r\n                        WHEN jsonb_typeof(value) = 'array'\r\n                            THEN\r\n                                (\r\n                                    SELECT string_agg\r\n                                        (\r\n                                            format\r\n                                            (\r\n                                                E'(%s)',\r\n                                                reclada_object.get_query_condition(cond, format(E'attrs->%L', key))\r\n                                            ),\r\n                                            ' AND '\r\n                                        )\r\n                                        FROM jsonb_array_elements(value) AS cond\r\n                                )\r\n                        ELSE reclada_object.get_query_condition(value, format(E'attrs->%L', key))\r\n                    END AS condition\r\n                FROM jsonb_each(attrs)\r\n                WHERE attrs != ('{}'::jsonb)\r\n            ) conds\r\n        INTO query_conditions;\r\n    END IF;\r\n    query := 'FROM reclada.v_active_object obj WHERE ' || query_conditions;\r\n\r\n    -- RAISE NOTICE 'conds: %', '\r\n    --             SELECT obj.data\r\n    --             '\r\n    --             || query\r\n    --             ||\r\n    --             ' ORDER BY ' || order_by ||\r\n    --             ' OFFSET ' || offset_ || ' LIMIT ' || limit_ ;\r\n    EXECUTE E'SELECT to_jsonb(array_agg(T.data))\r\n        FROM (\r\n            SELECT obj.data\r\n            '\r\n            || query\r\n            ||\r\n            ' ORDER BY ' || order_by ||\r\n            ' OFFSET ' || offset_ || ' LIMIT ' || limit_ || ') T'\r\n    INTO objects;\r\n    IF gui THEN\r\n\r\n        EXECUTE E'SELECT count(1)\r\n        '|| query\r\n        INTO number_of_objects;\r\n\r\n        EXECUTE E'SELECT TO_CHAR(\r\n\tMAX(\r\n\t\tGREATEST(obj.created_time, (\r\n\t\t\tSELECT TO_TIMESTAMP(MAX(date_time),\\'YYYY-MM-DD hh24:mi:ss.US TZH\\')\r\n\t\t\tFROM reclada.v_revision vr\r\n\t\t\tWHERE vr.obj_id = UUID(obj.attrs ->>\\'revision\\'))\r\n\t\t)\r\n\t),\\'YYYY-MM-DD hh24:mi:ss.MS TZH\\')\r\n        '|| query\r\n        INTO last_change;\r\n\r\n        res := jsonb_build_object(\r\n        'last_change', last_change,    \r\n        'number', number_of_objects,\r\n        'objects', objects);\r\n    ELSE\r\n        res := objects;\r\n    END IF;\r\n\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.update ;\nCREATE OR REPLACE FUNCTION reclada_object.update(data jsonb, user_info jsonb DEFAULT '{}'::jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    class_name     text;\r\n    class_uuid     uuid;\r\n    v_obj_id       uuid;\r\n    v_attrs        jsonb;\r\n    schema        jsonb;\r\n    old_obj       jsonb;\r\n    branch        uuid;\r\n    revid         uuid;\r\n\r\nBEGIN\r\n\r\n    class_name := data->>'class';\r\n    IF (class_name IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object class is not specified';\r\n    END IF;\r\n    class_uuid := reclada.try_cast_uuid(class_name);\r\n    v_obj_id := data->>'GUID';\r\n    IF (v_obj_id IS NULL) THEN\r\n        RAISE EXCEPTION 'Could not update object with no GUID';\r\n    END IF;\r\n\r\n    v_attrs := data->'attributes';\r\n    IF (v_attrs IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object must have attributes';\r\n    END IF;\r\n\r\n    SELECT reclada_object.get_schema(class_name) \r\n        INTO schema;\r\n\r\n    if class_uuid is null then\r\n        SELECT reclada_object.get_schema(class_name) \r\n            INTO schema;\r\n    else\r\n        select v.data \r\n            from reclada.v_class v\r\n                where class_uuid = v.obj_id\r\n            INTO schema;\r\n    end if;\r\n    -- TODO: don't allow update jsonschema\r\n    IF (schema IS NULL) THEN\r\n        RAISE EXCEPTION 'No json schema available for %', class_name;\r\n    END IF;\r\n\r\n    IF (NOT(public.validate_json_schema(schema->'attributes'->'schema', v_attrs))) THEN\r\n        RAISE EXCEPTION 'JSON invalid: %', v_attrs;\r\n    END IF;\r\n\r\n    SELECT \tv.data\r\n        FROM reclada.v_active_object v\r\n\t        WHERE v.obj_id = v_obj_id\r\n\t    INTO old_obj;\r\n\r\n    IF (old_obj IS NULL) THEN\r\n        RAISE EXCEPTION 'Could not update object, no such id';\r\n    END IF;\r\n\r\n    branch := data->'branch';\r\n    SELECT reclada_revision.create(user_info->>'sub', branch, v_obj_id) \r\n        INTO revid;\r\n    \r\n    with t as \r\n    (\r\n        update reclada.object o\r\n            set status = reclada_object.get_archive_status_obj_id()\r\n                where o.GUID = v_obj_id\r\n                    and status != reclada_object.get_archive_status_obj_id()\r\n                        RETURNING id\r\n    )\r\n    INSERT INTO reclada.object( GUID,\r\n                                class,\r\n                                status,\r\n                                attributes,\r\n                                transaction_id\r\n                              )\r\n        select  v.obj_id,\r\n                (schema->>'GUID')::uuid,\r\n                reclada_object.get_active_status_obj_id(),--status \r\n                v_attrs || format('{"revision":"%s"}',revid)::jsonb,\r\n                transaction_id\r\n            FROM reclada.v_object v\r\n            JOIN t \r\n                on t.id = v.id\r\n\t            WHERE v.obj_id = v_obj_id;\r\n    PERFORM reclada_object.datasource_insert\r\n            (\r\n                class_name,\r\n                v_obj_id,\r\n                v_attrs\r\n            );\r\n    PERFORM reclada_object.refresh_mv(class_name);  \r\n                  \r\n    select v.data \r\n        FROM reclada.v_active_object v\r\n            WHERE v.obj_id = v_obj_id\r\n        into data;\r\n    PERFORM reclada_notification.send_object_notification('update', data);\r\n    RETURN data;\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS api.reclada_object_update ;\nCREATE OR REPLACE FUNCTION api.reclada_object_update(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    class         text;\r\n    objid         uuid;\r\n    attrs         jsonb;\r\n    user_info     jsonb;\r\n    result        jsonb;\r\n\r\nBEGIN\r\n\r\n    class := data->>'class';\r\n    IF (class IS NULL) THEN\r\n        RAISE EXCEPTION 'reclada object class not specified';\r\n    END IF;\r\n\r\n    objid := data->>'GUID';\r\n    IF (objid IS NULL) THEN\r\n        RAISE EXCEPTION 'Could not update object with no GUID';\r\n    END IF;\r\n\r\n    attrs := data->'attributes';\r\n    IF (attrs IS NULL) THEN\r\n        RAISE EXCEPTION 'reclada object must have attributes';\r\n    END IF;\r\n\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF (NOT(reclada_user.is_allowed(user_info, 'update', class))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'update', class;\r\n    END IF;\r\n\r\n    SELECT reclada_object.update(data, user_info) INTO result;\r\n    RETURN result;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS api.reclada_object_list ;\nCREATE OR REPLACE FUNCTION api.reclada_object_list(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\n STABLE\nAS $function$\r\nDECLARE\r\n    class               text;\r\n    user_info           jsonb;\r\n    result              jsonb;\r\n    _filter             jsonb;\r\nBEGIN\r\n\r\n    class := data->>'class';\r\n    IF(class IS NULL) THEN\r\n        RAISE EXCEPTION 'reclada object class not specified';\r\n    END IF;\r\n\r\n    _filter = data->'filter';\r\n    if _filter is not null then\r\n        select format(  '{\r\n                            "filter":\r\n                            {\r\n                                "operator":"AND",\r\n                                "value":[\r\n                                    {\r\n                                        "operator":"=",\r\n                                        "value":["{class}","%s"]\r\n                                    },\r\n                                    %s\r\n                                ]\r\n                            }\r\n                        }',\r\n                class,\r\n                _filter\r\n            )::jsonb \r\n            into _filter;\r\n        data := data || _filter;\r\n    end if;\r\n\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF (NOT(reclada_user.is_allowed(user_info, 'list', class))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'list', class;\r\n    END IF;\r\n\r\n    SELECT reclada_object.list(data, true) INTO result;\r\n\r\n    RETURN result;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS api.reclada_object_create ;\nCREATE OR REPLACE FUNCTION api.reclada_object_create(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    data_jsonb       jsonb;\r\n    class            text;\r\n    user_info        jsonb;\r\n    attrs            jsonb;\r\n    data_to_create   jsonb = '[]'::jsonb;\r\n    result           jsonb;\r\n\r\nBEGIN\r\n\r\n    IF (jsonb_typeof(data) != 'array') THEN\r\n        data := '[]'::jsonb || data;\r\n    END IF;\r\n\r\n    FOR data_jsonb IN SELECT jsonb_array_elements(data) LOOP\r\n\r\n        class := data_jsonb->>'class';\r\n        IF (class IS NULL) THEN\r\n            RAISE EXCEPTION 'The reclada object class is not specified';\r\n        END IF;\r\n\r\n        SELECT reclada_user.auth_by_token(data_jsonb->>'accessToken') INTO user_info;\r\n        data_jsonb := data_jsonb - 'accessToken';\r\n\r\n        IF (NOT(reclada_user.is_allowed(user_info, 'create', class))) THEN\r\n            RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'create', class;\r\n        END IF;\r\n\r\n        attrs := data_jsonb->'attributes';\r\n        IF (attrs IS NULL) THEN\r\n            RAISE EXCEPTION 'The reclada object must have attributes';\r\n        END IF;\r\n\r\n        data_to_create := data_to_create || data_jsonb;\r\n    END LOOP;\r\n\r\n    SELECT reclada_object.create(data_to_create, user_info) INTO result;\r\n    RETURN result;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS api.reclada_object_delete ;\nCREATE OR REPLACE FUNCTION api.reclada_object_delete(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    class         text;\r\n    obj_id        uuid;\r\n    user_info     jsonb;\r\n    result        jsonb;\r\n\r\nBEGIN\r\n\r\n    class := data->>'class';\r\n    IF (class IS NULL) THEN\r\n        RAISE EXCEPTION 'reclada object class not specified';\r\n    END IF;\r\n\r\n    obj_id := data->>'GUID';\r\n    IF (obj_id IS NULL) THEN\r\n        RAISE EXCEPTION 'Could not delete object with no id';\r\n    END IF;\r\n\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF (NOT(reclada_user.is_allowed(user_info, 'delete', class))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'delete', class;\r\n    END IF;\r\n\r\n    SELECT reclada_object.delete(data, user_info) INTO result;\r\n    RETURN result;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.need_flat ;\n\n\nDROP function IF EXISTS api.storage_generate_presigned_get ;\nCREATE OR REPLACE FUNCTION api.storage_generate_presigned_get(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    object_data  jsonb;\r\n    object_id    uuid;\r\n    result       jsonb;\r\n    user_info    jsonb;\r\n    lambda_name  varchar;\r\n\r\nBEGIN\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF (NOT(reclada_user.is_allowed(user_info, 'generate presigned get', ''))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned get';\r\n    END IF;\r\n\r\n    -- TODO: check user's permissions for reclada object access?\r\n    object_id := data->>'objectId';\r\n    SELECT reclada_object.list(format(\r\n        '{"class": "File", "attributes": {}, "GUID": "%s"}',\r\n        object_id\r\n    )::jsonb) -> 0 INTO object_data;\r\n\r\n    IF (object_data IS NULL) THEN\r\n\t\tRAISE EXCEPTION 'There is no object with such id';\r\n\tEND IF;\r\n\r\n    SELECT attrs->>'Lambda'\r\n    FROM reclada.v_active_object\r\n    WHERE class_name = 'Context'\r\n    ORDER BY created_time DESC\r\n    LIMIT 1\r\n    INTO lambda_name;\r\n\r\n    SELECT payload\r\n    FROM aws_lambda.invoke(\r\n        aws_commons.create_lambda_function_arn(\r\n            format('%s', lambda_name),\r\n            'eu-west-1'\r\n            ),\r\n        format('{\r\n            "type": "get",\r\n            "uri": "%s",\r\n            "expiration": 3600}',\r\n            object_data->'attributes'->>'uri'\r\n            )::jsonb)\r\n    INTO result;\r\n\r\n    RETURN result;\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS api.storage_generate_presigned_post ;\nCREATE OR REPLACE FUNCTION api.storage_generate_presigned_post(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    user_info    jsonb;\r\n    object_name  varchar;\r\n    file_type    varchar;\r\n    file_size    varchar;\r\n    lambda_name  varchar;\r\n    bucket_name  varchar;\r\n    url          varchar;\r\n    result       jsonb;\r\n\r\n\r\n    object       jsonb;\r\n    object_id    uuid;\r\n    object_path  varchar;\r\n    uri          varchar;\r\n\r\n\r\nBEGIN\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF (NOT(reclada_user.is_allowed(user_info, 'generate presigned post', ''))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';\r\n    END IF;\r\n\r\n    object_name := data->>'objectName';\r\n    file_type := data->>'fileType';\r\n    file_size := data->>'fileSize';\r\n\r\n    IF (object_name IS NULL) OR (file_type IS NULL) OR (file_size IS NULL) THEN\r\n        RAISE EXCEPTION 'Parameters objectName, fileType and fileSize must be present';\r\n    END IF;\r\n\r\n    SELECT attrs->>'Lambda'\r\n    FROM reclada.v_active_object\r\n    WHERE class_name = 'Context'\r\n    ORDER BY created_time DESC\r\n    LIMIT 1\r\n    INTO lambda_name;\r\n\r\n    bucket_name := data->>'bucketName';\r\n\r\n    SELECT payload::jsonb\r\n    FROM aws_lambda.invoke(\r\n        aws_commons.create_lambda_function_arn(\r\n                format('%s', lambda_name),\r\n                'eu-west-1'\r\n        ),\r\n        format('{\r\n            "type": "post",\r\n            "fileName": "%s",\r\n            "fileType": "%s",\r\n            "fileSize": "%s",\r\n            "bucketName": "%s",\r\n            "expiration": 3600}',\r\n            object_name,\r\n            file_type,\r\n            file_size,\r\n            bucket_name\r\n            )::jsonb)\r\n    INTO url;\r\n\r\n    result = format(\r\n        '{"uploadUrl": %s}',\r\n        url\r\n    )::jsonb;\r\n\r\n    RETURN result;\r\nEND;\r\n$function$\n;\n	2021-12-23 09:40:36.185045+00
45	44	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n        upgrade_script text,\n        downgrade_script text\n    );\n    \ninsert into var_table(ver)\t\n    select max(ver) + 1\n        from dev.VER;\n        \nselect reclada.raise_exception('Can not apply this version!') \n    where not exists\n    (\n        select ver from var_table where ver = 44 --!!! write current version HERE !!!\n    );\n\nCREATE TEMP TABLE tmp\n(\n    id int GENERATED ALWAYS AS IDENTITY,\n    str text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n    from tmp ttt\n    inner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n    inner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n                split_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n        inner JOIN LATERAL\n    (\n        select case\n                when obj.typ = 'trigger'\n                    then\n                        (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n    inner JOIN LATERAL\n    (\n        select case \n                when obj.typ in ('function', 'procedure')\n                    then\n                        case \n                            when EXISTS\n                                (\n                                    SELECT 1 a\n                                        FROM pg_proc p \n                                        join pg_namespace n \n                                            on p.pronamespace = n.oid \n                                            where n.nspname||'.'||p.proname = obj.nam\n                                        LIMIT 1\n                                ) \n                                then (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n                            else ''\n                        end\n                when obj.typ = 'view'\n                    then\n                        case \n                            when EXISTS\n                                (\n                                    select 1 a \n                                        from pg_views v \n                                            where v.schemaname||'.'||v.viewname = obj.nam\n                                        LIMIT 1\n                                ) \n                                then E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n                            else ''\n                        end\n                when obj.typ = 'trigger'\n                    then\n                        case\n                            when EXISTS\n                                (\n                                    select 1 a\n                                        from pg_trigger v\n                                            where v.tgname = obj.nam\n                                        LIMIT 1\n                                )\n                                then (select pg_catalog.pg_get_triggerdef(oid, true)\n                                        from pg_trigger\n                                        where tgname = obj.nam)||';'\n                            else ''\n                        end\n                else \n                    ttt.str\n            end as v\n    )  scr ON TRUE\n    where ttt.id = tmp.id\n        and tmp.str like '--{%/%}';\n    \nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\ncreate table reclada.draft(\n    id bigint NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1),\n    guid uuid,\n    user_guid uuid DEFAULT reclada_object.get_default_user_obj_id(),\n    data jsonb not null\n);\n\n\ni 'function/api.reclada_object_create.sql'\ni 'function/api.reclada_object_list.sql'\ni 'function/api.reclada_object_delete.sql'\ni 'function/api.reclada_object_update.sql'\n\ni 'function/reclada_object.create.sql'\ni 'function/reclada_object.datasource_insert.sql'\ni 'function/reclada_object.list.sql'\ni 'function/reclada_object.get_query_condition_filter.sql'\ni 'function/reclada_object.parse_filter.sql'\n\ni 'function/reclada.raise_exception.sql'\ni 'view/reclada.v_filter_avaliable_operator.sql'\ni 'view/reclada.v_default_display.sql'\ni 'function/reclada_object.create_subclass.sql'\ni 'view/reclada.v_ui_active_object.sql'\n\n\n\nSELECT reclada_object.create_subclass('{\n    "class": "DataSource",\n    "attributes": {\n        "newClass": "Asset"\n    }\n}'::jsonb);\n\nSELECT reclada_object.create_subclass('{\n    "class": "Asset",\n    "attributes": {\n        "newClass": "DBAsset"\n    }\n}'::jsonb);\n\n\nUPDATE reclada.OBJECT\nSET ATTRIBUTES = jsonb_set(ATTRIBUTES,'{schema,properties,object,pattern}','"[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"'::jsonb)\nWHERE guid IN(SELECT reclada_object.get_GUID_for_class('Relationship'));\n\nUPDATE reclada.OBJECT\nSET ATTRIBUTES = jsonb_set(ATTRIBUTES,'{schema,properties,subject,pattern}','"[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"'::jsonb)\nWHERE guid IN(SELECT reclada_object.get_GUID_for_class('Relationship'));\n\n\nDROP OPERATOR IF EXISTS reclada.#(boolean, boolean);\nCREATE OPERATOR reclada.## (\n    FUNCTION = reclada.xor,\n    LEFTARG = boolean,\n    RIGHTARG = boolean\n);\n\ndelete from reclada.v_object_display;\n\nSELECT reclada_object.create(('{\n    "class":"ObjectDisplay",\n    "attributes":{\n        "classGUID": "'|| reclada_object.get_GUID_for_class('File') ||'",\n        "caption": "Files",\n        "table": {\n            "{attributes,name}:string": {\n                "caption": "File name",\n                "displayCSS": "name",\n                "width": 250,\n                "behavior":"preview"\n            },\n            "{attributes,tags}:array": {\n                "caption": "Tags",\n                "displayCSS": "arrayLink",\n                "width": 250,\n                "items": {\n                    "displayCSS": "link",\n                    "behavior": "preview",\n                    "class":"'|| reclada_object.get_GUID_for_class('tag') ||'"\n                }\n            },\n            "{attributes,mimeType}:string": {\n                "caption": "Mime type",\n                "width": 250,\n                "displayCSS": "mimeType"\n            },\n            "{attributes,checksum}:string": {\n                "caption": "Checksum",\n                "width": 250,\n                "displayCSS": "checksum"\n            },\n            "{status}:string":{\n                "caption": "Status",\n                "width": 250,\n                "displayCSS": "status"\n            },\n            "{createdTime}:string":{\n                "caption": "Created time",\n                "width": 250,\n                "displayCSS": "createdTime"\n            },\n            "{transactionID}:number":{\n                "caption": "Transaction",\n                "width": 250,\n                "displayCSS": "transactionID"\n            },\n            "{GUID}:string":{\n                "caption": "GUID",\n                "width": 250,\n                "displayCSS": "GUID"\n            },\n            "orderRow": [\n                {"{attributes,name}:string":"ASC"},\n                {"{attributes,mimeType}:string":"DESC"}\n            ],\n            "orderColumn": [\n                "{attributes,name}:string",\n                "{attributes,mimeType}:string",\n                "{attributes,tags}:array",\n                "{status}:string",\n                "{createdTime}:string",\n                "{transactionID}:number"\n            ]\n        },\n        "card":{\n            "orderRow": [\n                {"{attributes,name}:string":"ASC"},\n                {"{attributes,mimeType}:string":"DESC"}\n            ],\n            "orderColumn": [\n                "{attributes,name}:string",\n                "{attributes,mimeType}:string",\n                "{attributes,tags}:array",\n                "{status}:string",\n                "{createdTime}:string",\n                "{transactionID}:number"\n            ]\n        },\n        "preview":{\n            "orderRow": [\n                {"{attributes,name}:string":"ASC"},\n                {"{attributes,mimeType}:string":"DESC"}\n            ],\n            "orderColumn": [\n                "{attributes,name}:string",\n                "{attributes,mimeType}:string",\n                "{attributes,tags}:array",\n                "{status}:string",\n                "{createdTime}:string",\n                "{transactionID}:number"\n            ]\n        },\n        "list":{\n             "orderRow": [\n                {"{attributes,name}:string":"ASC"},\n                {"{attributes,mimeType}:string":"DESC"}\n            ],\n            "orderColumn": [\n                "{attributes,name}:string",\n                "{attributes,mimeType}:string",\n                "{attributes,tags}:array",\n                "{status}:string",\n                "{createdTime}:string",\n                "{transactionID}:number"\n            ]\n        }\n    }\n}')::jsonb);\n\nDO\n$do12$\nDECLARE\n\t_guid uuid;\n    _json jsonb;\nBEGIN\n\tselect obj_id\n        from reclada.v_DTO_json_schema \n            where function = 'reclada_object.list'\n            into _guid;\n    _json := '{\n        "status": "active",\n        "attributes": {\n            "schema": {\n                "type": "object",\n                "anyOf": [\n                    {\n                        "required": [\n                            "transactionID","class"\n                        ]\n                    },\n                    {\n                        "required": [\n                            "class"\n                        ]\n                    },\n                    {\n                        "required": [\n                            "filter","class"\n                        ]\n                    }\n                ],\n                "properties": {\n                    "class": {\n                        "type": "string"\n                    },\n                    "limit": {\n                        "anyOf": [\n                            {\n                                "enum": [\n                                    "ALL"\n                                ],\n                                "type": "string"\n                            },\n                            {\n                                "type": "integer"\n                            }\n                        ]\n                    },\n                    "filter": {\n                        "type": "object"\n                    },\n                    "offset": {\n                        "type": "integer"\n                    },\n                    "orderBy": {\n                        "type": "array",\n                        "items": {\n                            "type": "object",\n                            "required": [\n                                "field"\n                            ],\n                            "properties": {\n                                "field": {\n                                    "type": "string"\n                                },\n                                "order": {\n                                    "enum": [\n                                        "ASC",\n                                        "DESC"\n                                    ],\n                                    "type": "string"\n                                }\n                            }\n                        }\n                    },\n                    "transactionID": {\n                        "type": "integer"\n                    }\n                }\n            },\n            "function": "reclada_object.list"\n        },\n        "parentGUID": null,\n        "createdTime": "2021-11-08T11:01:49.274513+00:00",\n        "transactionID": 61\n    }';\n    \n    _json := _json || ('{"GUID": "'||_guid::text||'"}')::jsonb;\n    select reclada_object.get_guid_for_class('DTOJsonSchema')\n        into _guid;\n    _json := _json || ('{"class": "' ||_guid::text|| '"}')::jsonb;\n    perform reclada_object.update(_json);\n    \nEND\n$do12$;\n\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n    select ver, upgrade_script, downgrade_script\n        from var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, curren version: ' \n                            || (select ver from var_table)::text\n                          );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\ndrop table reclada.draft;\n\nDROP function IF EXISTS api.reclada_object_create ;\nCREATE OR REPLACE FUNCTION api.reclada_object_create(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    data_jsonb       jsonb;\r\n    class            text;\r\n    user_info        jsonb;\r\n    attrs            jsonb;\r\n    data_to_create   jsonb = '[]'::jsonb;\r\n    result           jsonb;\r\n    _need_flat       bool := false;\r\nBEGIN\r\n\r\n    IF (jsonb_typeof(data) != 'array') THEN\r\n        data := '[]'::jsonb || data;\r\n    END IF;\r\n\r\n    FOR data_jsonb IN SELECT jsonb_array_elements(data) LOOP\r\n\r\n        class := coalesce(data_jsonb->>'{class}', data_jsonb->>'class');\r\n        IF (class IS NULL) THEN\r\n            RAISE EXCEPTION 'The reclada object class is not specified (api)';\r\n        END IF;\r\n\r\n        SELECT reclada_user.auth_by_token(data_jsonb->>'accessToken') INTO user_info;\r\n        data_jsonb := data_jsonb - 'accessToken';\r\n\r\n        -- raise notice '%',data_jsonb #> '{}';\r\n\r\n        IF (NOT(reclada_user.is_allowed(user_info, 'create', class))) THEN\r\n            RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'create', class;\r\n        END IF;\r\n        \r\n        if reclada_object.need_flat(class) then\r\n            _need_flat := true;\r\n            with recursive j as \r\n            (\r\n                select  row_number() over() as id,\r\n                        key,\r\n                        value \r\n                    from jsonb_each(data_jsonb)\r\n                        where key like '{%}'\r\n            ),\r\n            inn as \r\n            (\r\n                SELECT  row_number() over(order by s.id,j.id) rn,\r\n                        j.id,\r\n                        s.id sid,\r\n                        s.d,\r\n                        ARRAY (\r\n                            SELECT UNNEST(arr.v) \r\n                            LIMIT array_position(arr.v, s.d)\r\n                        ) as k\r\n                    FROM j\r\n                    left join lateral\r\n                    (\r\n                        select id, d ,max(id) over() mid\r\n                        from\r\n                        (\r\n                            SELECT  row_number() over() as id, \r\n                                    d\r\n                                from regexp_split_to_table(substring(j.key,2,char_length(j.key)-2),',') d \r\n                        ) t\r\n                    ) s on s.mid != s.id\r\n                    join lateral\r\n                    (\r\n                        select regexp_split_to_array(substring(j.key,2,char_length(j.key)-2),',') v\r\n                    ) arr on true\r\n                        where d is not null\r\n            ),\r\n            src as\r\n            (\r\n                select  jsonb_set('{}'::jsonb,('{'|| i.d ||'}')::text[],'{}'::jsonb) r,\r\n                        i.* \r\n                    from inn i\r\n                        where i.rn = 1\r\n                union\r\n                select  jsonb_set(\r\n                            s.r,\r\n                            i.k,\r\n                            '{}'::jsonb\r\n                        ) r,\r\n                        i.* \r\n                    from src s\r\n                    join inn i\r\n                        on s.rn + 1 = i.rn\r\n            ),\r\n            tmpl as (\r\n                select r v\r\n                    from src\r\n                    ORDER BY rn DESC\r\n                    limit 1\r\n            ),\r\n            res as\r\n            (\r\n                SELECT jsonb_set(\r\n                        (select v from tmpl),\r\n                        j.key::text[],\r\n                        j.value\r\n                    ) v,\r\n                    j.*\r\n                    FROM j\r\n                        where j.id = 1\r\n                union \r\n                select jsonb_set(\r\n                        res.v,\r\n                        j.key::text[],\r\n                        j.value\r\n                    ) v,\r\n                    j.*\r\n                    FROM res\r\n                    join j\r\n                        on res.id + 1 =j.id\r\n            )\r\n            SELECT v \r\n                FROM res\r\n                ORDER BY ID DESC\r\n                limit 1\r\n                into data_jsonb;\r\n        end if;\r\n        data_to_create := data_to_create || data_jsonb;\r\n    END LOOP;\r\n\r\n    if data_to_create is null then\r\n        RAISE EXCEPTION 'JSON invalid';\r\n    end if;\r\n\r\n    SELECT reclada_object.create(data_to_create, user_info) INTO result;\r\n    if _need_flat then\r\n        RETURN '{"status":"OK"}'::jsonb;\r\n    end if;\r\n    RETURN result;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS api.reclada_object_list ;\nCREATE OR REPLACE FUNCTION api.reclada_object_list(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    class               text;\r\n    user_info           jsonb;\r\n    result              jsonb;\r\n    _filter             jsonb;\r\nBEGIN\r\n\r\n    class := coalesce(data->>'{class}', data->>'class');\r\n    IF(class IS NULL) THEN\r\n        RAISE EXCEPTION 'reclada object class not specified';\r\n    END IF;\r\n\r\n    _filter = data->'filter';\r\n    IF _filter IS NOT NULL THEN\r\n        SELECT format(  '{\r\n                            "filter":\r\n                            {\r\n                                "operator":"AND",\r\n                                "value":[\r\n                                    {\r\n                                        "operator":"=",\r\n                                        "value":["{class}","%s"]\r\n                                    },\r\n                                    %s\r\n                                ]\r\n                            }\r\n                        }',\r\n                class,\r\n                _filter\r\n            )::jsonb \r\n            INTO _filter;\r\n        data := data || _filter;\r\n    ELSE\r\n        data := data || ('{"class":"'|| class ||'"}')::jsonb;\r\n    --     select format(  '{\r\n    --                         "filter":{\r\n    --                             "operator":"=",\r\n    --                             "value":["{class}","%s"]\r\n    --                         }\r\n    --                     }',\r\n    --             class,\r\n    --             _filter\r\n    --         )::jsonb \r\n    --         INTO _filter;\r\n    END IF;\r\n\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF (NOT(reclada_user.is_allowed(user_info, 'list', class))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'list', class;\r\n    END IF;\r\n\r\n    SELECT reclada_object.list(data, true) \r\n        INTO result;\r\n    RETURN result;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS api.reclada_object_delete ;\nCREATE OR REPLACE FUNCTION api.reclada_object_delete(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    class         text;\r\n    obj_id        uuid;\r\n    user_info     jsonb;\r\n    result        jsonb;\r\n\r\nBEGIN\r\n\r\n    class := coalesce(data ->> '{class}', data ->> 'class');\r\n    IF (class IS NULL) THEN\r\n        RAISE EXCEPTION 'reclada object class not specified';\r\n    END IF;\r\n\r\n    obj_id := coalesce(data ->> '{GUID}', data ->> 'GUID');\r\n    IF (obj_id IS NULL) THEN\r\n        RAISE EXCEPTION 'Could not delete object with no id';\r\n    END IF;\r\n\r\n    data := data || ('{"GUID":"'|| obj_id ||'","class":"'|| class ||'"}')::jsonb;\r\n\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF (NOT(reclada_user.is_allowed(user_info, 'delete', class))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'delete', class;\r\n    END IF;\r\n\r\n    SELECT reclada_object.delete(data, user_info) INTO result;\r\n\r\n    if reclada_object.need_flat(class) then \r\n        RETURN '{"status":"OK"}'::jsonb;\r\n    end if;\r\n\r\n    RETURN result;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS api.reclada_object_update ;\nCREATE OR REPLACE FUNCTION api.reclada_object_update(data jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    class         text;\r\n    objid         uuid;\r\n    attrs         jsonb;\r\n    user_info     jsonb;\r\n    result        jsonb;\r\n    _need_flat    bool := false;\r\n\r\nBEGIN\r\n\r\n    class := coalesce(data ->> '{class}', data ->> 'class');\r\n    IF (class IS NULL) THEN\r\n        RAISE EXCEPTION 'reclada object class not specified';\r\n    END IF;\r\n\r\n    objid := coalesce(data ->> '{GUID}', data ->> 'GUID');\r\n    IF (objid IS NULL) THEN\r\n        RAISE EXCEPTION 'Could not update object with no GUID';\r\n    END IF;\r\n    \r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF (NOT(reclada_user.is_allowed(user_info, 'update', class))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'update', class;\r\n    END IF;\r\n\r\n    if reclada_object.need_flat(class) then\r\n        _need_flat := true;\r\n        with recursive j as \r\n        (\r\n            select  row_number() over() as id,\r\n                    key,\r\n                    value \r\n                from jsonb_each(data)\r\n                    where key like '{%}'\r\n        ),\r\n        t as\r\n        (\r\n            select  j.id    , \r\n                    j.key   , \r\n                    j.value , \r\n                    o.data\r\n                from reclada.v_object o\r\n                join j\r\n                    on true\r\n                    where o.obj_id = \r\n                        (\r\n                            select (j.value#>>'{}')::uuid \r\n                                from j where j.key = '{GUID}'\r\n                        )\r\n        ),\r\n        r as \r\n        (\r\n            select id,key,value,jsonb_set(t.data,t.key::text[],t.value) as u, t.data\r\n                from t\r\n                    where id = 1\r\n            union\r\n            select t.id,t.key,t.value,jsonb_set(r.u   ,t.key::text[],t.value) as u, t.data\r\n                from r\r\n                JOIN t\r\n                    on t.id-1 = r.id\r\n        )\r\n        select r.u\r\n            from r\r\n                where id = (select max(j.id) from j)\r\n            INTO data;\r\n    end if;\r\n    raise notice '%', data#>>'{}';\r\n    SELECT reclada_object.update(data, user_info) INTO result;\r\n\r\n    if _need_flat then\r\n        RETURN '{"status":"OK"}'::jsonb;\r\n    end if;\r\n    return result;\r\nEND;\r\n$function$\n;\n\nDROP function IF EXISTS reclada_object.create ;\nCREATE OR REPLACE FUNCTION reclada_object."create"(data_jsonb jsonb, user_info jsonb DEFAULT '{}'::jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    branch        uuid;\r\n    data          jsonb;\r\n    class_name    text;\r\n    class_uuid    uuid;\r\n    tran_id       bigint;\r\n    _attrs         jsonb;\r\n    schema        jsonb;\r\n    obj_GUID      uuid;\r\n    res           jsonb;\r\n    affected      uuid[];\r\n    _parent_guid  uuid;\r\nBEGIN\r\n\r\n    IF (jsonb_typeof(data_jsonb) != 'array') THEN\r\n        data_jsonb := '[]'::jsonb || data_jsonb;\r\n    END IF;\r\n    /*TODO: check if some objects have revision and others do not */\r\n    branch:= data_jsonb->0->'branch';\r\n\r\n    FOR data IN SELECT jsonb_array_elements(data_jsonb) \r\n    LOOP\r\n\r\n        class_name := data->>'class';\r\n\r\n        IF (class_name IS NULL) THEN\r\n            RAISE EXCEPTION 'The reclada object class is not specified';\r\n        END IF;\r\n        class_uuid := reclada.try_cast_uuid(class_name);\r\n\r\n        _attrs := data->'attributes';\r\n        IF (_attrs IS NULL) THEN\r\n            RAISE EXCEPTION 'The reclada object must have attributes';\r\n        END IF;\r\n\r\n        tran_id := (data->>'transactionID')::bigint;\r\n        if tran_id is null then\r\n            tran_id := reclada.get_transaction_id();\r\n        end if;\r\n\r\n        IF class_uuid IS NULL THEN\r\n            SELECT reclada_object.get_schema(class_name) \r\n            INTO schema;\r\n            class_uuid := (schema->>'GUID')::uuid;\r\n        ELSE\r\n            SELECT v.data \r\n            FROM reclada.v_class v\r\n            WHERE class_uuid = v.obj_id\r\n            INTO schema;\r\n        END IF;\r\n        IF (schema IS NULL) THEN\r\n            RAISE EXCEPTION 'No json schema available for %', class_name;\r\n        END IF;\r\n\r\n        IF (NOT(public.validate_json_schema(schema->'attributes'->'schema', _attrs))) THEN\r\n            RAISE EXCEPTION 'JSON invalid: %', _attrs;\r\n        END IF;\r\n        \r\n        IF data->>'id' IS NOT NULL THEN\r\n            RAISE EXCEPTION '%','Field "id" not allow!!!';\r\n        END IF;\r\n\r\n        IF class_uuid IN (SELECT guid FROM reclada.v_PK_for_class)\r\n        THEN\r\n            SELECT o.obj_id\r\n                FROM reclada.v_object o\r\n                JOIN reclada.v_PK_for_class pk\r\n                    on pk.guid = o.class\r\n                        and class_uuid = o.class\r\n                where o.attrs->>pk.pk = _attrs ->> pk.pk\r\n                LIMIT 1\r\n            INTO obj_GUID;\r\n            IF obj_GUID IS NOT NULL THEN\r\n                SELECT reclada_object.update(data || format('{"GUID": "%s"}', obj_GUID)::jsonb)\r\n                    INTO res;\r\n                    RETURN '[]'::jsonb || res;\r\n            END IF;\r\n        END IF;\r\n\r\n        obj_GUID := (data->>'GUID')::uuid;\r\n        IF EXISTS (\r\n            SELECT 1\r\n            FROM reclada.object \r\n            WHERE GUID = obj_GUID\r\n        ) THEN\r\n            RAISE EXCEPTION 'GUID: % is duplicate', obj_GUID;\r\n        END IF;\r\n        --raise notice 'schema: %',schema;\r\n\r\n        _parent_guid = (data->>'parent_guid')::uuid;\r\n\r\n        INSERT INTO reclada.object(GUID,class,attributes,transaction_id, parent_guid)\r\n            SELECT  CASE\r\n                        WHEN obj_GUID IS NULL\r\n                            THEN public.uuid_generate_v4()\r\n                        ELSE obj_GUID\r\n                    END AS GUID,\r\n                    class_uuid, \r\n                    _attrs,\r\n                    tran_id,\r\n                    _parent_guid\r\n        RETURNING GUID INTO obj_GUID;\r\n        affected := array_append( affected, obj_GUID);\r\n\r\n        PERFORM reclada_object.datasource_insert\r\n            (\r\n                class_name,\r\n                obj_GUID,\r\n                _attrs\r\n            );\r\n\r\n        PERFORM reclada_object.refresh_mv(class_name);\r\n    END LOOP;\r\n\r\n    res := array_to_json\r\n            (\r\n                array\r\n                (\r\n                    SELECT o.data \r\n                    FROM reclada.v_active_object o\r\n                    WHERE o.obj_id = ANY (affected)\r\n                )\r\n            )::jsonb; \r\n    PERFORM reclada_notification.send_object_notification\r\n        (\r\n            'create',\r\n            res\r\n        );\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.datasource_insert ;\nCREATE OR REPLACE FUNCTION reclada_object.datasource_insert(_class_name text, _obj_id uuid, attributes jsonb)\n RETURNS void\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    _pipeline_lite jsonb;\r\n    _task  jsonb;\r\n    _dataset_guid  uuid;\r\n    _new_guid  uuid;\r\n    _pipeline_job_guid  uuid;\r\n    _stage         text;\r\n    _uri           text;\r\n    _environment   varchar;\r\n    _rel_cnt       int;\r\n    _dataset2ds_type text = 'defaultDataSet to DataSource';\r\n    _f_name text = 'reclada_object.datasource_insert';\r\nBEGIN\r\n    IF _class_name in ('DataSource','File') THEN\r\n\r\n        _uri := attributes->>'uri';\r\n\r\n\r\n        SELECT v.obj_id\r\n        FROM reclada.v_active_object v\r\n        WHERE v.class_name = 'DataSet'\r\n            and v.attrs->>'name' = 'defaultDataSet'\r\n        INTO _dataset_guid;\r\n\r\n        SELECT count(*)\r\n        FROM reclada.v_active_object\r\n        WHERE class_name = 'Relationship'\r\n            AND (attrs->>'object')::uuid = _obj_id\r\n            AND (attrs->>'subject')::uuid = _dataset_guid\r\n            AND attrs->>'type' = _dataset2ds_type\r\n                INTO _rel_cnt;\r\n\r\n        SELECT attrs->>'Environment'\r\n            FROM reclada.v_active_object\r\n                WHERE class_name = 'Context'\r\n                ORDER BY created_time DESC\r\n                LIMIT 1\r\n            INTO _environment;\r\n        IF _rel_cnt=0 THEN\r\n            PERFORM reclada_object.create(\r\n                    format('{\r\n                        "class": "Relationship",\r\n                        "attributes": {\r\n                            "type": "%s",\r\n                            "object": "%s",\r\n                            "subject": "%s"\r\n                            }\r\n                        }', _dataset2ds_type, _obj_id, _dataset_guid\r\n                    )::jsonb\r\n                );\r\n\r\n        END IF;\r\n        if _uri like '%inbox/jobs/%' then\r\n        \r\n            PERFORM reclada_object.create(\r\n                    format('{\r\n                        "class": "Job",\r\n                        "attributes": {\r\n                            "task": "c94bff30-15fa-427f-9954-d5c3c151e652",\r\n                            "status": "new",\r\n                            "type": "%s",\r\n                            "command": "./run_pipeline.sh",\r\n                            "inputParameters": [{"uri": "%s"}, {"dataSourceId": "%s"}]\r\n                            }\r\n                        }', _environment, _uri, _obj_id\r\n                    )::jsonb\r\n                );\r\n        \r\n        ELSE\r\n            \r\n            SELECT data \r\n                FROM reclada.v_active_object\r\n                    WHERE class_name = 'PipelineLite'\r\n                        LIMIT 1\r\n                INTO _pipeline_lite;\r\n            _new_guid := public.uuid_generate_v4();\r\n            IF _uri like '%inbox/pipelines/%/%' then\r\n                \r\n                _stage := SPLIT_PART(\r\n                                SPLIT_PART(_uri,'inbox/pipelines/',2),\r\n                                '/',\r\n                                2\r\n                            );\r\n                _stage = replace(_stage,'.json','');\r\n                SELECT data \r\n                    FROM reclada.v_active_object o\r\n                        where o.class_name = 'Task'\r\n                            and o.obj_id = (_pipeline_lite #>> ('{attributes,tasks,'||_stage||'}')::text[])::uuid\r\n                    into _task;\r\n                \r\n                _pipeline_job_guid = reclada.try_cast_uuid(\r\n                                        SPLIT_PART(\r\n                                            SPLIT_PART(_uri,'inbox/pipelines/',2),\r\n                                            '/',\r\n                                            1\r\n                                        )\r\n                                    );\r\n                if _pipeline_job_guid is null then \r\n                    perform reclada.raise_exception('PIPELINE_JOB_GUID not found',_f_name);\r\n                end if;\r\n                \r\n                SELECT  data #>> '{attributes,inputParameters,0,uri}',\r\n                        (data #>> '{attributes,inputParameters,1,dataSourceId}')::uuid\r\n                    from reclada.v_active_object o\r\n                        where o.obj_id = _pipeline_job_guid\r\n                    into _uri, _obj_id;\r\n\r\n            ELSE\r\n                SELECT data \r\n                    FROM reclada.v_active_object o\r\n                        where o.class_name = 'Task'\r\n                            and o.obj_id = (_pipeline_lite #>> '{attributes,tasks,0}')::uuid\r\n                    into _task;\r\n                _pipeline_job_guid := _new_guid;\r\n            END IF;\r\n            \r\n            PERFORM reclada_object.create(\r\n                format('{\r\n                    "GUID":"%s",\r\n                    "class": "Job",\r\n                    "attributes": {\r\n                        "task": "%s",\r\n                        "status": "new",\r\n                        "type": "%s",\r\n                        "command": "%s",\r\n                        "inputParameters": [\r\n                                { "uri"                 :"%s"   }, \r\n                                { "dataSourceId"        :"%s"   },\r\n                                { "PipelineLiteJobGUID" :"%s"   }\r\n                            ]\r\n                        }\r\n                    }',\r\n                        _new_guid::text,\r\n                        _task->>'GUID',\r\n                        _environment, \r\n                        _task-> 'attributes' ->>'command',\r\n                        _uri,\r\n                        _obj_id,\r\n                        _pipeline_job_guid::text\r\n                )::jsonb\r\n            );\r\n\r\n        END IF;\r\n    END IF;\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.list ;\nCREATE OR REPLACE FUNCTION reclada_object.list(data jsonb, gui boolean DEFAULT false)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    _f_name TEXT = 'reclada_object.list';\r\n    class               text;\r\n    attrs               jsonb;\r\n    order_by_jsonb      jsonb;\r\n    order_by            text;\r\n    limit_              text;\r\n    offset_             text;\r\n    query_conditions    text;\r\n    number_of_objects   int;\r\n    objects             jsonb;\r\n    res                 jsonb;\r\n    query               text;\r\n    class_uuid          uuid;\r\n    last_change         text;\r\n    tran_id             bigint;\r\n    _filter             JSONB;\r\nBEGIN\r\n\r\n    perform reclada.validate_json(data, _f_name);\r\n\r\n    tran_id := (data->>'transactionID')::bigint;\r\n    class := data->>'class';\r\n    _filter = data->'filter';\r\n\r\n    order_by_jsonb := data->'orderBy';\r\n    IF ((order_by_jsonb IS NULL) OR\r\n        (order_by_jsonb = 'null'::jsonb) OR\r\n        (order_by_jsonb = '[]'::jsonb)) THEN\r\n        order_by_jsonb := '[{"field": "GUID", "order": "ASC"}]'::jsonb;\r\n    END IF;\r\n    SELECT string_agg(\r\n        format(E'obj.data#>''{%s}'' %s', T.value->>'field', COALESCE(T.value->>'order', 'ASC')),\r\n        ' , ')\r\n        FROM jsonb_array_elements(order_by_jsonb) T\r\n        INTO order_by;\r\n\r\n    limit_ := data->>'limit';\r\n    IF (limit_ IS NULL) THEN\r\n        limit_ := 500;\r\n    END IF;\r\n\r\n    offset_ := data->>'offset';\r\n    IF (offset_ IS NULL) THEN\r\n        offset_ := 0;\r\n    END IF;\r\n \r\n    IF (_filter IS NOT NULL) THEN\r\n        query_conditions := reclada_object.get_query_condition_filter(_filter);\r\n        IF gui THEN\r\n            query_conditions := REPLACE(query_conditions,'#>','->');\r\n        end if;\r\n    ELSE\r\n        class_uuid := reclada.try_cast_uuid(class);\r\n\r\n        IF class_uuid IS NOT NULL THEN\r\n            SELECT v.for_class\r\n                FROM reclada.v_class_lite v\r\n                    WHERE class_uuid = v.obj_id\r\n            INTO class;\r\n\r\n            IF (class IS NULL) THEN\r\n                RAISE EXCEPTION 'Class not found by GUID: %', class_uuid::text;\r\n            END IF;\r\n        end if;\r\n\r\n        attrs := data->'attributes' || '{}'::jsonb;\r\n\r\n        SELECT\r\n            string_agg(\r\n                format(\r\n                    E'(%s)',\r\n                    condition\r\n                ),\r\n                ' AND '\r\n            )\r\n            FROM (\r\n                SELECT\r\n                    format('obj.class_name = ''%s''', class) AS condition\r\n                        where class is not null\r\n                            and class_uuid is null\r\n                UNION\r\n                    SELECT format('obj.class = ''%s''', class_uuid) AS condition\r\n                        where class_uuid is not null\r\n                UNION\r\n                    SELECT format('obj.transaction_id = %s', tran_id) AS condition\r\n                        where tran_id is not null\r\n                UNION\r\n                    SELECT CASE\r\n                            WHEN jsonb_typeof(data->'GUID') = 'array' THEN\r\n                            (\r\n                                SELECT string_agg\r\n                                    (\r\n                                        format(\r\n                                            E'(%s)',\r\n                                            reclada_object.get_query_condition(cond, E'data->''GUID''') -- TODO: change data->'GUID' to obj_id(GUID)\r\n                                        ),\r\n                                        ' AND '\r\n                                    )\r\n                                    FROM jsonb_array_elements(data->'GUID') AS cond\r\n                            )\r\n                            ELSE reclada_object.get_query_condition(data->'GUID', E'data->''GUID''') -- TODO: change data->'GUID' to obj_id(GUID)\r\n                        END AS condition\r\n                    WHERE coalesce(data->'GUID','null'::jsonb) != 'null'::jsonb\r\n                UNION\r\n                SELECT\r\n                    CASE\r\n                        WHEN jsonb_typeof(value) = 'array'\r\n                            THEN\r\n                                (\r\n                                    SELECT string_agg\r\n                                        (\r\n                                            format\r\n                                            (\r\n                                                E'(%s)',\r\n                                                reclada_object.get_query_condition(cond, format(E'attrs->%L', key))\r\n                                            ),\r\n                                            ' AND '\r\n                                        )\r\n                                        FROM jsonb_array_elements(value) AS cond\r\n                                )\r\n                        ELSE reclada_object.get_query_condition(value, format(E'attrs->%L', key))\r\n                    END AS condition\r\n                FROM jsonb_each(attrs)\r\n                WHERE attrs != ('{}'::jsonb)\r\n            ) conds\r\n        INTO query_conditions;\r\n    END IF;\r\n    IF gui AND reclada_object.need_flat(class) THEN\r\n        query := 'FROM reclada.v_ui_active_object obj WHERE ' || query_conditions;\r\n    ELSE\r\n        query := 'FROM reclada.v_active_object obj WHERE ' || query_conditions;\r\n    END IF;\r\n    RAISE NOTICE 'conds: %', '\r\n                SELECT obj.data\r\n                '\r\n                || query\r\n                ||\r\n                ' ORDER BY ' || order_by ||\r\n                ' OFFSET ' || offset_ || ' LIMIT ' || limit_ ;\r\n    EXECUTE E'SELECT to_jsonb(array_agg(T.data))\r\n        FROM (\r\n            SELECT obj.data\r\n            '\r\n            || query\r\n            ||\r\n            ' ORDER BY ' || order_by ||\r\n            ' OFFSET ' || offset_ || ' LIMIT ' || limit_ || ') T'\r\n    INTO objects;\r\n    IF gui THEN\r\n\r\n        EXECUTE E'SELECT count(1)\r\n        '|| query\r\n        INTO number_of_objects;\r\n\r\n        EXECUTE E'SELECT TO_CHAR(\r\n\tMAX(\r\n\t\tGREATEST(obj.created_time, (\r\n\t\t\tSELECT TO_TIMESTAMP(MAX(date_time),\\'YYYY-MM-DD hh24:mi:ss.US TZH\\')\r\n\t\t\tFROM reclada.v_revision vr\r\n\t\t\tWHERE vr.obj_id = UUID(obj.attrs ->>\\'revision\\'))\r\n\t\t)\r\n\t),\\'YYYY-MM-DD hh24:mi:ss.MS TZH\\')\r\n        '|| query\r\n        INTO last_change;\r\n\r\n        res := jsonb_build_object(\r\n        'last_change', last_change,    \r\n        'number', number_of_objects,\r\n        'objects', objects);\r\n    ELSE\r\n        res := objects;\r\n    END IF;\r\n\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.get_query_condition_filter ;\nCREATE OR REPLACE FUNCTION reclada_object.get_query_condition_filter(data jsonb)\n RETURNS text\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE \r\n    _count   INT;\r\n    _res     TEXT;\r\n    _f_name TEXT = 'reclada_object.get_query_condition_filter';\r\nBEGIN \r\n    \r\n    perform reclada.validate_json(data, _f_name);\r\n    -- TODO: to change VOLATILE -> IMMUTABLE, remove CREATE TEMP TABLE\r\n    CREATE TEMP TABLE mytable AS\r\n        SELECT  res.lvl              AS lvl         , \r\n                res.rn               AS rn          , \r\n                res.idx              AS idx         ,\r\n                res.prev             AS prev        , \r\n                res.val              AS val         ,  \r\n                res.parsed           AS parsed      , \r\n                coalesce(\r\n                    po.inner_operator, \r\n                    op.operator\r\n                )                   AS op           , \r\n                coalesce\r\n                (\r\n                    iop.input_type,\r\n                    op.input_type\r\n                )                   AS input_type   ,\r\n                case \r\n                    when iop.input_type is not NULL \r\n                        then NULL \r\n                    else \r\n                        op.output_type\r\n                end                 AS output_type  ,\r\n                po.operator         AS po           ,\r\n                po.input_type       AS po_input_type,\r\n                iop.brackets        AS po_inner_brackets\r\n            FROM reclada_object.parse_filter(data) res\r\n            LEFT JOIN reclada.v_filter_avaliable_operator op\r\n                ON res.op = op.operator\r\n            LEFT JOIN reclada_object.parse_filter(data) p\r\n                on  p.lvl = res.lvl-1\r\n                    and res.prev = p.rn\r\n            LEFT JOIN reclada.v_filter_avaliable_operator po\r\n                on po.operator = p.op\r\n            LEFT JOIN reclada.v_filter_inner_operator iop\r\n                on iop.operator = po.inner_operator;\r\n\r\n    PERFORM reclada.raise_exception('Operator does not allowed ' || t.op,'reclada_object.get_query_condition_filter')\r\n        FROM mytable t\r\n            WHERE t.op IS NULL;\r\n\r\n\r\n    UPDATE mytable u\r\n        SET parsed = to_jsonb(p.v)\r\n            FROM mytable t\r\n            JOIN LATERAL \r\n            (\r\n                SELECT  t.parsed #>> '{}' v\r\n            ) as pt\r\n                ON TRUE\r\n            LEFT JOIN reclada.v_filter_mapping fm\r\n                ON pt.v = fm.pattern\r\n            JOIN LATERAL \r\n            (\r\n                SELECT CASE \r\n                        WHEN fm.repl is not NULL \r\n                            then '(''"''||' ||fm.repl ||'||''"'')::jsonb' -- don't use FORMAT (concat null)\r\n                        -- WHEN pt.v LIKE '{attributes,%}'\r\n                        --     THEN format('attrs #> ''%s''', REPLACE(pt.v,'{attributes,','{'))\r\n                        WHEN jsonb_typeof(t.parsed) in ('number', 'boolean')\r\n                            then \r\n                                case \r\n                                    when t.input_type in ('NUMERIC','INT')\r\n                                        then pt.v\r\n                                    else '''' || pt.v || '''::jsonb'\r\n                                end\r\n                        WHEN jsonb_typeof(t.parsed) = 'string' \r\n                            then    \r\n                                case\r\n                                    WHEN pt.v LIKE '{%}'\r\n                                        THEN\r\n                                            case\r\n                                                when t.input_type = 'TEXT'\r\n                                                    then format('(data #>> ''%s'')', pt.v)\r\n                                                when t.input_type = 'JSONB' or t.input_type is null\r\n                                                    then format('data #> ''%s''', pt.v)\r\n                                                else\r\n                                                    format('(data #>> ''%s'')::', pt.v) || t.input_type\r\n                                            end\r\n                                    when t.input_type = 'TEXT'\r\n                                        then ''''||REPLACE(pt.v,'''','''''')||''''\r\n                                    when t.input_type = 'JSONB' or t.input_type is null\r\n                                        then '''"'||REPLACE(pt.v,'''','''''')||'"''::jsonb'\r\n                                    else ''''||REPLACE(pt.v,'''','''''')||'''::'||t.input_type\r\n                                end\r\n                        WHEN jsonb_typeof(t.parsed) = 'null'\r\n                            then 'null'\r\n                        WHEN jsonb_typeof(t.parsed) = 'array'\r\n                            then ''''||REPLACE(pt.v,'''','''''')||'''::jsonb'\r\n                        ELSE\r\n                            pt.v\r\n                    END AS v\r\n            ) as p\r\n                ON TRUE\r\n            WHERE t.lvl = u.lvl\r\n                AND t.rn = u.rn\r\n                AND t.parsed IS NOT NULL;\r\n\r\n    update mytable u\r\n        set op = CASE \r\n                    when f.btwn\r\n                        then ' BETWEEN '\r\n                    else u.op -- f.inop\r\n                end,\r\n            parsed = format(vb.operand_format,u.parsed)::jsonb\r\n        FROM mytable t\r\n        join lateral\r\n        (\r\n            select  t.op like ' %/BETWEEN ' btwn, \r\n                    t.po_inner_brackets is not null inop\r\n        ) f \r\n            on true\r\n        join reclada.v_filter_between vb\r\n            on t.op = vb.operator\r\n            WHERE t.lvl = u.lvl\r\n                AND t.rn = u.rn\r\n                AND (f.btwn or f.inop);\r\n\r\n    INSERT INTO mytable (lvl,rn)\r\n        VALUES (0,0);\r\n\r\n    _count := 1;\r\n\r\n    WHILE (_count>0) LOOP\r\n        WITH r AS \r\n        (\r\n            UPDATE mytable\r\n                SET parsed = to_json(t.converted)::JSONB \r\n                FROM \r\n                (\r\n                    SELECT     \r\n                            res.lvl-1 lvl,\r\n                            res.prev rn,\r\n                            res.op,\r\n                            1 q,\r\n                            case \r\n                                when not res.po_inner_brackets \r\n                                    then array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op) \r\n                                else\r\n                                    CASE COUNT(1) \r\n                                        WHEN 1\r\n                                            THEN \r\n                                                CASE res.output_type\r\n                                                    when 'NUMERIC'\r\n                                                        then format('(%s %s)::TEXT::JSONB', res.op, min(res.parsed #>> '{}') )\r\n                                                    else \r\n                                                        format('(%s %s)', res.op, min(res.parsed #>> '{}') )\r\n                                                end\r\n                                        ELSE\r\n                                            CASE \r\n                                                when res.output_type = 'TEXT'\r\n                                                    then '(''"''||'||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op) ||'||''"'')::JSONB'\r\n                                                when res.output_type in ('NUMERIC','INT')\r\n                                                    then '('||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op) ||')::TEXT::JSONB'\r\n                                                else\r\n                                                    '('||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op) ||')'\r\n                                            end\r\n                                    end\r\n                            end AS converted\r\n                        FROM mytable res \r\n                            WHERE res.parsed IS NOT NULL\r\n                                AND res.lvl = (SELECT max(lvl)+1 FROM mytable WHERE parsed IS NULL)\r\n                            GROUP BY  res.prev, res.op, res.lvl, res.input_type, res.output_type, res.po_inner_brackets\r\n                ) t\r\n                WHERE\r\n                    t.lvl = mytable.lvl\r\n                        AND t.rn = mytable.rn\r\n                RETURNING 1\r\n        )\r\n            SELECT COUNT(1) \r\n                FROM r\r\n                INTO _count;\r\n    END LOOP;\r\n    \r\n    SELECT parsed #>> '{}' \r\n        FROM mytable\r\n            WHERE lvl = 0 AND rn = 0\r\n        INTO _res;\r\n    perform reclada.raise_notice( _res);\r\n    DROP TABLE mytable;\r\n    RETURN _res;\r\nEND \r\n$function$\n;\nDROP function IF EXISTS reclada_object.parse_filter ;\nCREATE OR REPLACE FUNCTION reclada_object.parse_filter(data jsonb)\n RETURNS TABLE(lvl integer, rn bigint, idx bigint, op text, prev bigint, val jsonb, parsed jsonb)\n LANGUAGE sql\n IMMUTABLE\nAS $function$\r\n    WITH RECURSIVE f AS \r\n    (\r\n        SELECT data AS v\r\n    ),\r\n    pr AS \r\n    (\r\n        SELECT \tformat(' %s ',f.v->>'operator') AS op, \r\n                val.v AS val,\r\n                1 AS lvl,\r\n                row_number() OVER(ORDER BY idx) AS rn,\r\n                val.idx idx,\r\n                0::BIGINT prev\r\n            FROM f, jsonb_array_elements(f.v->'value') WITH ordinality AS val(v, idx)\r\n    ),\r\n    res AS\r\n    (\t\r\n        SELECT \tpr.lvl\t,\r\n                pr.rn\t,\r\n                pr.idx  ,\r\n                pr.op\t,\r\n                pr.prev ,\r\n                pr.val\t,\r\n                CASE jsonb_typeof(pr.val) \r\n                    WHEN 'object'\t\r\n                        THEN NULL\r\n                    ELSE pr.val\r\n                END AS parsed\r\n            FROM pr\r\n            WHERE prev = 0 \r\n                AND lvl = 1\r\n        UNION ALL\r\n        SELECT \tttt.lvl\t,\r\n                ROW_NUMBER() OVER(ORDER BY ttt.idx) AS rn,\r\n                ttt.idx,\r\n                ttt.op\t,\r\n                ttt.prev,\r\n                ttt.val ,\r\n                CASE jsonb_typeof(ttt.val) \r\n                    WHEN 'object'\t\r\n                        THEN NULL\r\n                    ELSE ttt.val\r\n                end AS parsed\r\n            FROM\r\n            (\r\n                SELECT \tres.lvl + 1 AS lvl,\r\n                        format(' %s ',res.val->>'operator') AS op,\r\n                        res.rn AS prev\t,\r\n                        val.v  AS val,\r\n                        val.idx\r\n                    FROM res, \r\n                         jsonb_array_elements(res.val->'value') WITH ordinality AS val(v, idx)\r\n            ) ttt\r\n    )\r\n    SELECT \tr.lvl\t,\r\n            r.rn\t,\r\n            r.idx   ,\r\n            upper(r.op) ,\r\n            r.prev  ,\r\n            r.val\t,\r\n            r.parsed\r\n        FROM res r\r\n$function$\n;\n\nDROP function IF EXISTS reclada.raise_exception ;\nCREATE OR REPLACE FUNCTION reclada.raise_exception(msg text, func_name text DEFAULT '<unknown>'::text)\n RETURNS void\n LANGUAGE plpgsql\nAS $function$\r\nBEGIN\r\n    -- \r\n    RAISE EXCEPTION '% \r\n    from: %', msg, func_name;\r\nEND\r\n$function$\n;\nDROP view IF EXISTS reclada.v_filter_avaliable_operator ;\nCREATE OR REPLACE VIEW reclada.v_filter_avaliable_operator\nAS\n SELECT ' = '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' LIKE '::text AS operator,\n    'TEXT'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' NOT LIKE '::text AS operator,\n    'TEXT'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' || '::text AS operator,\n    'TEXT'::text AS input_type,\n    'TEXT'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' ~ '::text AS operator,\n    'TEXT'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' !~ '::text AS operator,\n    'TEXT'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' ~* '::text AS operator,\n    'TEXT'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' !~* '::text AS operator,\n    'TEXT'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' SIMILAR TO '::text AS operator,\n    'TEXT'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' > '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' < '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' <= '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' != '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' >= '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' AND '::text AS operator,\n    'BOOL'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' OR '::text AS operator,\n    'BOOL'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' NOT '::text AS operator,\n    'BOOL'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' # '::text AS operator,\n    'BOOL'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' IS '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' IS NOT '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' IN '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type,\n    ' , '::text AS inner_operator\nUNION\n SELECT ' @> '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' <@ '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' + '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' - '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' * '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' / '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' % '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' ^ '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' |/ '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' ||/ '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' !! '::text AS operator,\n    'INT'::text AS input_type,\n    'NUMERIC'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' @ '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' & '::text AS operator,\n    'INT'::text AS input_type,\n    'INT'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' | '::text AS operator,\n    'INT'::text AS input_type,\n    'INT'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' << '::text AS operator,\n    'INT'::text AS input_type,\n    'INT'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' >> '::text AS operator,\n    'INT'::text AS input_type,\n    'INT'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' BETWEEN '::text AS operator,\n    'TIMESTAMP WITH TIME ZONE'::text AS input_type,\n    'BOOL'::text AS output_type,\n    ' AND '::text AS inner_operator\nUNION\n SELECT ' Y/BETWEEN '::text AS operator,\n    NULL::text AS input_type,\n    NULL::text AS output_type,\n    ' AND '::text AS inner_operator\nUNION\n SELECT ' MON/BETWEEN '::text AS operator,\n    NULL::text AS input_type,\n    NULL::text AS output_type,\n    ' AND '::text AS inner_operator\nUNION\n SELECT ' D/BETWEEN '::text AS operator,\n    NULL::text AS input_type,\n    NULL::text AS output_type,\n    ' AND '::text AS inner_operator\nUNION\n SELECT ' H/BETWEEN '::text AS operator,\n    NULL::text AS input_type,\n    NULL::text AS output_type,\n    ' AND '::text AS inner_operator\nUNION\n SELECT ' MIN/BETWEEN '::text AS operator,\n    NULL::text AS input_type,\n    NULL::text AS output_type,\n    ' AND '::text AS inner_operator\nUNION\n SELECT ' S/BETWEEN '::text AS operator,\n    NULL::text AS input_type,\n    NULL::text AS output_type,\n    ' AND '::text AS inner_operator\nUNION\n SELECT ' DOW/BETWEEN '::text AS operator,\n    NULL::text AS input_type,\n    NULL::text AS output_type,\n    ' AND '::text AS inner_operator\nUNION\n SELECT ' DOY/BETWEEN '::text AS operator,\n    NULL::text AS input_type,\n    NULL::text AS output_type,\n    ' AND '::text AS inner_operator\nUNION\n SELECT ' Q/BETWEEN '::text AS operator,\n    NULL::text AS input_type,\n    NULL::text AS output_type,\n    ' AND '::text AS inner_operator\nUNION\n SELECT ' W/BETWEEN '::text AS operator,\n    NULL::text AS input_type,\n    NULL::text AS output_type,\n    ' AND '::text AS inner_operator;\nDROP function IF EXISTS reclada_object.create_subclass ;\nCREATE OR REPLACE FUNCTION reclada_object.create_subclass(data jsonb)\n RETURNS void\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    class           text;\r\n    new_class       text;\r\n    attrs           jsonb;\r\n    class_schema    jsonb;\r\n    version_         integer;\r\n    class_guid    uuid;\r\nBEGIN\r\n\r\n    class := data->>'class';\r\n    IF (class IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object class is not specified';\r\n    END IF;\r\n\r\n    attrs := data->'attributes';\r\n    IF (attrs IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object must have attributes';\r\n    END IF;\r\n\r\n    new_class = attrs->>'newClass';\r\n\r\n    SELECT reclada_object.get_schema(class) INTO class_schema;\r\n\r\n    IF (class_schema IS NULL) THEN\r\n        RAISE EXCEPTION 'No json schema available for %', class;\r\n    END IF;\r\n\r\n    SELECT max(version) + 1\r\n    FROM reclada.v_class_lite v\r\n    WHERE v.for_class = new_class\r\n    INTO version_;\r\n\r\n    version_ := coalesce(version_,1);\r\n    class_schema := class_schema->'attributes'->'schema';\r\n\r\n    SELECT obj_id\r\n    FROM reclada.v_class\r\n    WHERE for_class = class\r\n    ORDER BY version DESC\r\n    LIMIT 1\r\n    INTO class_guid;\r\n\r\n    PERFORM reclada_object.create(format('{\r\n        "class": "jsonschema",\r\n        "attributes": {\r\n            "forClass": "%s",\r\n            "version": "%s",\r\n            "schema": {\r\n                "type": "object",\r\n                "properties": %s,\r\n                "required": %s\r\n            }\r\n        },\r\n        "parent_guid" : "%s"\r\n    }',\r\n    new_class,\r\n    version_,\r\n    (class_schema->'properties') || (attrs->'properties'),\r\n    (SELECT jsonb_agg(el) FROM (\r\n        SELECT DISTINCT pg_catalog.jsonb_array_elements(\r\n            (class_schema -> 'required') || (attrs -> 'required')\r\n        ) el) arr),\r\n    class_guid\r\n    )::jsonb);\r\n\r\nEND;\r\n$function$\n;\nDROP view IF EXISTS reclada.v_ui_active_object ;\nCREATE OR REPLACE VIEW reclada.v_ui_active_object\nAS\n SELECT t.id,\n    t.obj_id,\n    t.class,\n    t.revision_num,\n    t.status,\n    t.status_caption,\n    t.revision,\n    t.created_time,\n    t.class_name,\n    t.attrs,\n    j.data,\n    t.transaction_id,\n    t.parent_guid\n   FROM v_active_object t\n     JOIN ( SELECT t_1.id,\n            jsonb_object_agg(t_1.key, t_1.val) AS data\n           FROM ( SELECT t_2.id,\n                    j_1.key,\n                    t_2.data #>> j_1.key::text[] AS val\n                   FROM v_active_object t_2\n                     JOIN v_object_display od ON od.class_guid = t_2.class\n                     JOIN LATERAL ( SELECT jsonb_each.key\n                           FROM jsonb_each(od."table") jsonb_each(key, value)\n                        UNION\n                         SELECT '{GUID}'::text AS text) j_1 ON j_1.key ~~ '{%}'::text) t_1\n          GROUP BY t_1.id) j ON t.id = j.id;\nDROP view IF EXISTS reclada.v_default_display ;\n\n\ndelete from reclada.object \n    where guid in (select reclada_object.get_GUID_for_class('Asset'));\n\ndelete from reclada.object \n    where guid in (select reclada_object.get_GUID_for_class('DBAsset'));\n\nUPDATE reclada.OBJECT\nSET ATTRIBUTES = ATTRIBUTES #- '{schema,properties,object,minLength}'\nWHERE guid IN(SELECT reclada_object.get_GUID_for_class('Relationship'));\n\nUPDATE reclada.OBJECT\nSET ATTRIBUTES = ATTRIBUTES #- '{schema,properties,subject,minLength}'\nWHERE guid IN(SELECT reclada_object.get_GUID_for_class('Relationship'));\n\nDROP OPERATOR IF EXISTS reclada.##(boolean, boolean);\nCREATE OPERATOR reclada.# (\n    FUNCTION = reclada.xor,\n    LEFTARG = boolean,\n    RIGHTARG = boolean\n);\n\n    \nwith g as \n(\n    select g.obj_id\n    from\n    (\n        select s.obj_id, count(*) cnt\n            from reclada.v_DTO_json_schema s\n            join reclada.v_object o\n                on o.obj_id = s.obj_id\n                where s.function = 'reclada_object.list'\n                    group by s.obj_id\n    ) as g\n    left join lateral \n    (\n        select reclada.raise_exception('reclada_object.list has more 2 DTO schema')\n            where g.cnt > 2\n    ) ex  on true\n)\nupdate reclada.object o\n    set status = reclada_object.get_active_status_obj_id()\n    from g\n        where g.obj_id = o.guid;\n\ndelete from reclada.object \n    where id =\n    (\n        SELECT max(id)\n            FROM reclada.v_object \n                where class_name = 'DTOJsonSchema' \n                    and attrs->>'function' = 'reclada_object.list' \n    );	2021-12-28 14:18:07.480088+00
46	45	\N	begin;\nSET CLIENT_ENCODING TO 'utf8';\nCREATE TEMP TABLE var_table\n    (\n        ver int,\n        upgrade_script text,\n        downgrade_script text\n    );\n    \ninsert into var_table(ver)\t\n    select max(ver) + 1\n        from dev.VER;\n        \nselect reclada.raise_exception('Can not apply this version!') \n    where not exists\n    (\n        select ver from var_table where ver = 45 --!!! write current version HERE !!!\n    );\n\nCREATE TEMP TABLE tmp\n(\n    id int GENERATED ALWAYS AS IDENTITY,\n    str text\n);\n--{ logging upgrade script\nCOPY tmp(str) FROM  'up.sql' delimiter E'';\nupdate var_table set upgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\ndelete from tmp;\n--} logging upgrade script\t\n\n--{ create downgrade script\nCOPY tmp(str) FROM  'down.sql' delimiter E'';\nupdate tmp set str = drp.v || scr.v\n    from tmp ttt\n    inner JOIN LATERAL\n    (\n        select substring(ttt.str from 4 for length(ttt.str)-4) as v\n    )  obj_file_name ON TRUE\n    inner JOIN LATERAL\n    (\n        select \tsplit_part(obj_file_name.v,'/',1) typ,\n                split_part(obj_file_name.v,'/',2) nam\n    )  obj ON TRUE\n        inner JOIN LATERAL\n    (\n        select case\n                when obj.typ = 'trigger'\n                    then\n                        (select 'DROP '|| obj.typ || ' IF EXISTS '|| obj.nam ||' ON ' || schm||'.'||tbl ||';' || E'\n'\n                        from (\n                            select n.nspname as schm,\n                                   c.relname as tbl\n                            from pg_trigger t\n                                join pg_class c on c.oid = t.tgrelid\n                                join pg_namespace n on n.oid = c.relnamespace\n                            where t.tgname = 'datasource_insert_trigger') o)\n                else 'DROP '||obj.typ|| ' IF EXISTS '|| obj.nam || ' ;' || E'\n'\n                end as v\n    )  drp ON TRUE\n    inner JOIN LATERAL\n    (\n        select case \n                when obj.typ in ('function', 'procedure')\n                    then\n                        case \n                            when EXISTS\n                                (\n                                    SELECT 1 a\n                                        FROM pg_proc p \n                                        join pg_namespace n \n                                            on p.pronamespace = n.oid \n                                            where n.nspname||'.'||p.proname = obj.nam\n                                        LIMIT 1\n                                ) \n                                then (select pg_catalog.pg_get_functiondef(obj.nam::regproc::oid))||';'\n                            else ''\n                        end\n                when obj.typ = 'view'\n                    then\n                        case \n                            when EXISTS\n                                (\n                                    select 1 a \n                                        from pg_views v \n                                            where v.schemaname||'.'||v.viewname = obj.nam\n                                        LIMIT 1\n                                ) \n                                then E'CREATE OR REPLACE VIEW '\n                                        || obj.nam\n                                        || E'\nAS\n'\n                                        || (select pg_get_viewdef(obj.nam, true))\n                            else ''\n                        end\n                when obj.typ = 'trigger'\n                    then\n                        case\n                            when EXISTS\n                                (\n                                    select 1 a\n                                        from pg_trigger v\n                                            where v.tgname = obj.nam\n                                        LIMIT 1\n                                )\n                                then (select pg_catalog.pg_get_triggerdef(oid, true)\n                                        from pg_trigger\n                                        where tgname = obj.nam)||';'\n                            else ''\n                        end\n                else \n                    ttt.str\n            end as v\n    )  scr ON TRUE\n    where ttt.id = tmp.id\n        and tmp.str like '--{%/%}';\n    \nupdate var_table set downgrade_script = array_to_string(ARRAY((select str from tmp order by id asc)),chr(10),'');\t\n--} create downgrade script\ndrop table tmp;\n\n\n--{!!! write upgrare script HERE !!!\n\n--\tyou can use "i 'function/reclada_object.get_schema.sql'"\n--\tto run text script of functions\n \n/*\n    you can use "i 'function/reclada_object.get_schema.sql'"\n    to run text script of functions\n*/\n\nCREATE TYPE reclada.dp_bhvr AS ENUM ('Replace','Update','Reject','Copy','Insert','Merge');\n\nALTER TABLE reclada.draft ADD COLUMN IF NOT EXISTS parent_guid uuid;\nDELETE FROM reclada.draft WHERE guid IS NULL;\nALTER TABLE reclada.draft ALTER COLUMN guid SET NOT NULL;\nALTER VIEW reclada.v_filter_avaliable_operator RENAME TO v_filter_available_operator;\n\nDROP VIEW reclada.v_pk_for_class;\n\ni 'view/reclada.v_object_unifields.sql'\ni 'view/reclada.v_parent_field.sql'\ni 'function/reclada.get_unifield_index_name.sql'\ni 'view/reclada.v_unifields_pivoted.sql'\n\ni 'function/reclada_object.get_parent_guid.sql'\ni 'function/reclada_object.get_query_condition_filter.sql'\ni 'function/reclada_object.merge.sql'\ni 'function/reclada_object.update_json.sql'\ni 'function/reclada_object.update_json_by_guid.sql'\ni 'function/reclada_object.remove_parent_guid.sql'\ni 'function/reclada_object.create_relationship.sql'\ni 'function/reclada_object.create_job.sql'\ni 'function/reclada_object.create.sql'\ni 'function/reclada_object.create_subclass.sql'\ni 'function/reclada_object.delete.sql'\ni 'function/reclada_object.update.sql'\ni 'function/reclada_object.refresh_mv.sql'\ni 'function/reclada_object.update.sql'\ni 'function/reclada.get_children.sql'\ni 'function/reclada_object.datasource_insert.sql'\ni 'function/reclada.get_duplicates.sql'\ni 'function/reclada_object.parse_filter.sql'\n\ni 'function/reclada_object.list.sql'\ni 'function/api.reclada_object_list.sql'\ni 'function/reclada_object.get_query_condition_filter.sql'\ni 'function/api.reclada_object_create.sql'\ni 'function/reclada_object.delete.sql'\n\ni 'view/reclada.v_filter_available_operator.sql'\ni 'view/reclada.v_object.sql'\ni 'view/reclada.v_ui_active_object.sql'\ni 'view/reclada.v_default_display.sql'\n\nUPDATE reclada.object\nSET attributes = jsonb_set(attributes,'{parentField}','"table"'::jsonb)\nWHERE guid IN (SELECT reclada_object.get_guid_for_class('Cell')) and status = reclada_object.get_active_status_obj_id();\n\nUPDATE reclada.object\nSET attributes = jsonb_set(attributes,'{parentField}','"page"'::jsonb)\nWHERE guid IN (SELECT reclada_object.get_guid_for_class('Table')) and status = reclada_object.get_active_status_obj_id();\n\nUPDATE reclada.object\nSET attributes = jsonb_set(attributes,'{parentField}','"document"'::jsonb)\nWHERE guid IN (SELECT reclada_object.get_guid_for_class('Page')) and status = reclada_object.get_active_status_obj_id();\n\nUPDATE reclada.object\nSET attributes = jsonb_set(attributes,'{parentField}','"fileGUID"'::jsonb)\nWHERE guid IN (SELECT reclada_object.get_guid_for_class('Document')) and status = reclada_object.get_active_status_obj_id();\n\nUPDATE reclada.object\nSET attributes = jsonb_set(attributes,'{parentField}','"table"'::jsonb)\nWHERE guid IN (SELECT reclada_object.get_guid_for_class('DataRow')) and status = reclada_object.get_active_status_obj_id();\n\nUPDATE reclada.object\nSET attributes = jsonb_set(attributes,'{dupBehavior}','"Replace"'::jsonb)\nWHERE guid IN (SELECT reclada_object.get_guid_for_class('File')) and status = reclada_object.get_active_status_obj_id();\n\nUPDATE reclada.object\nSET attributes = jsonb_set(attributes,'{isCascade}','true'::jsonb)\nWHERE guid IN (SELECT reclada_object.get_guid_for_class('File')) and status = reclada_object.get_active_status_obj_id();\n\nUPDATE reclada.object\nSET attributes = jsonb_set(attributes,'{dupChecking}','[{"uniFields" : ["uri"], "isMandatory" : true}, {"uniFields" : ["checksum"], "isMandatory" : true}]'::jsonb)\nWHERE guid IN (SELECT reclada_object.get_guid_for_class('File')) and status = reclada_object.get_active_status_obj_id();\n\nSELECT reclada_object.refresh_mv('uniFields');\n\n\nCREATE INDEX uri_index_ ON reclada.object USING HASH (((attributes->>'uri')));\nCREATE INDEX checksum_index_ ON reclada.object USING HASH (((attributes->>'checksum')));\n\n\nDROP INDEX reclada.status_index;\n\nselect reclada.raise_exception('can''t find 2 DTOJsonSchema for reclada_object.list', 'up_script.sql')\n    where \n        (\n            select count(*)\n                from reclada.object\n                    where attributes->>'function' = 'reclada_object.list'\n                        and class in (select reclada_object.get_guid_for_class('DTOJsonSchema'))\n        ) != 2;\n\n--{ display\nwith t as\n( \n    update reclada.object\n        set status = reclada_object.get_active_status_obj_id()\n        where attributes->>'function' = 'reclada_object.list'\n            and class in (select reclada_object.get_guid_for_class('DTOJsonSchema'))\n            and status = reclada_object.get_archive_status_obj_id()\n        returning id\n)\n    update reclada.object\n        set status = reclada_object.get_archive_status_obj_id()\n        where attributes->>'function' = 'reclada_object.list'\n            and class in (select reclada_object.get_guid_for_class('DTOJsonSchema'))\n            and id not in (select id from t);\n\ni 'function/reclada.jsonb_deep_set.sql'\n--} display\n\n\n\n--}!!! write upgrare script HERE !!!\n\ninsert into dev.ver(ver,upgrade_script,downgrade_script)\n    select ver, upgrade_script, downgrade_script\n        from var_table;\n\n--{ testing downgrade script\nSAVEPOINT sp;\n    select dev.downgrade_version();\nROLLBACK TO sp;\n--} testing downgrade script\n\nselect reclada.raise_notice('OK, current version: ' \n                            || (select ver from var_table)::text\n                          );\ndrop table var_table;\n\ncommit;	-- you you can use "--{function/reclada_object.get_schema}"\n-- to add current version of object to downgrade script\n\n\nUPDATE reclada.object\nSET attributes = attributes - 'parentField'\nWHERE guid='7f56ece0-e780-4496-8573-1ad4d800a3b6' \n    and status = reclada_object.get_active_status_obj_id();\n\nUPDATE reclada.object\nSET attributes = attributes - 'parentField'\nWHERE guid='f5bcc7ad-1a9b-476d-985e-54cf01377530' \n    and status = reclada_object.get_active_status_obj_id();\n\nUPDATE reclada.object\nSET attributes = attributes - 'parentField'\nWHERE guid='3ed1c180-a508-4180-9281-2f9b9a9cd477' \n    and status = reclada_object.get_active_status_obj_id();\n\nUPDATE reclada.object\nSET attributes = attributes - 'parentField'\nWHERE guid='85d32073-4a00-4df7-9def-7de8d90b77e0' \n    and status = reclada_object.get_active_status_obj_id();\n\nUPDATE reclada.object\nSET attributes = attributes - 'parentField'\nWHERE guid='7643b601-43c2-4125-831a-539b9e7418ec' \n    and status = reclada_object.get_active_status_obj_id();\n\nUPDATE reclada.object\nSET attributes = attributes - 'dupBehavior'\nWHERE guid='c7fc0455-0572-40d7-987f-583cc2c9630c' \n    and status = reclada_object.get_active_status_obj_id();\n\nUPDATE reclada.object\nSET attributes = attributes - 'isCascade'\nWHERE guid='c7fc0455-0572-40d7-987f-583cc2c9630c' \n    and status = reclada_object.get_active_status_obj_id();\n\nUPDATE reclada.object\nSET attributes = attributes - 'dupChecking'\nWHERE guid='c7fc0455-0572-40d7-987f-583cc2c9630c' \n    and status = reclada_object.get_active_status_obj_id();\n\nDROP view IF EXISTS reclada.v_parent_field ;\n\nDROP view IF EXISTS reclada.v_unifields_pivoted ;\n\nDROP MATERIALIZED VIEW       reclada.v_object_unifields;\n\nDROP function IF EXISTS reclada.get_unifield_index_name ;\n\nDROP function IF EXISTS reclada_object.merge ;\n\nDROP function IF EXISTS reclada.get_children ;\n\nDROP function IF EXISTS reclada.get_duplicates ;\n\nDROP function IF EXISTS reclada_object.update_json_by_guid ;\n\nDROP function IF EXISTS reclada_object.update_json ;\n\nDROP function IF EXISTS reclada_object.remove_parent_guid ;\n\nDROP function IF EXISTS reclada_object.get_parent_guid ;\n\n\nDROP function IF EXISTS reclada_object.get_query_condition_filter ;\nCREATE OR REPLACE FUNCTION reclada_object.get_query_condition_filter(data jsonb)\n RETURNS text\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE \r\n    _count   INT;\r\n    _res     TEXT;\r\n    _f_name TEXT = 'reclada_object.get_query_condition_filter';\r\nBEGIN \r\n    \r\n    perform reclada.validate_json(data, _f_name);\r\n    -- TODO: to change VOLATILE -> IMMUTABLE, remove CREATE TEMP TABLE\r\n    CREATE TEMP TABLE mytable AS\r\n        SELECT  res.lvl              AS lvl         , \r\n                res.rn               AS rn          , \r\n                res.idx              AS idx         ,\r\n                res.prev             AS prev        , \r\n                res.val              AS val         ,  \r\n                res.parsed           AS parsed      , \r\n                coalesce(\r\n                    po.inner_operator, \r\n                    op.operator\r\n                )                   AS op           , \r\n                coalesce\r\n                (\r\n                    iop.input_type,\r\n                    op.input_type\r\n                )                   AS input_type   ,\r\n                case \r\n                    when iop.input_type is not NULL \r\n                        then NULL \r\n                    else \r\n                        op.output_type\r\n                end                 AS output_type  ,\r\n                po.operator         AS po           ,\r\n                po.input_type       AS po_input_type,\r\n                iop.brackets        AS po_inner_brackets\r\n            FROM reclada_object.parse_filter(data) res\r\n            LEFT JOIN reclada.v_filter_avaliable_operator op\r\n                ON res.op = op.operator\r\n            LEFT JOIN reclada_object.parse_filter(data) p\r\n                on  p.lvl = res.lvl-1\r\n                    and res.prev = p.rn\r\n            LEFT JOIN reclada.v_filter_avaliable_operator po\r\n                on po.operator = p.op\r\n            LEFT JOIN reclada.v_filter_inner_operator iop\r\n                on iop.operator = po.inner_operator;\r\n\r\n    PERFORM reclada.raise_exception('Operator does not allowed ' || t.op, _f_name)\r\n        FROM mytable t\r\n            WHERE t.op IS NULL;\r\n\r\n\r\n    UPDATE mytable u\r\n        SET parsed = to_jsonb(p.v)\r\n            FROM mytable t\r\n            JOIN LATERAL \r\n            (\r\n                SELECT  t.parsed #>> '{}' v\r\n            ) as pt\r\n                ON TRUE\r\n            LEFT JOIN reclada.v_filter_mapping fm\r\n                ON pt.v = fm.pattern\r\n            JOIN LATERAL \r\n            (\r\n                SELECT CASE \r\n                        WHEN fm.repl is not NULL \r\n                            then \r\n                                case \r\n                                    when t.input_type in ('TEXT')\r\n                                        then fm.repl || '::TEXT'\r\n                                    else '(''"''||' ||fm.repl ||'||''"'')::jsonb' -- don't use FORMAT (concat null)\r\n                                end\r\n                        WHEN jsonb_typeof(t.parsed) in ('number', 'boolean')\r\n                            then \r\n                                case \r\n                                    when t.input_type in ('NUMERIC','INT')\r\n                                        then pt.v\r\n                                    else '''' || pt.v || '''::jsonb'\r\n                                end\r\n                        WHEN jsonb_typeof(t.parsed) = 'string' \r\n                            then    \r\n                                case\r\n                                    WHEN pt.v LIKE '{%}'\r\n                                        THEN\r\n                                            case\r\n                                                when t.input_type = 'TEXT'\r\n                                                    then format('(data #>> ''%s'')', pt.v)\r\n                                                when t.input_type = 'JSONB' or t.input_type is null\r\n                                                    then format('data #> ''%s''', pt.v)\r\n                                                else\r\n                                                    format('(data #>> ''%s'')::', pt.v) || t.input_type\r\n                                            end\r\n                                    when t.input_type = 'TEXT'\r\n                                        then ''''||REPLACE(pt.v,'''','''''')||''''\r\n                                    when t.input_type = 'JSONB' or t.input_type is null\r\n                                        then '''"'||REPLACE(pt.v,'''','''''')||'"''::jsonb'\r\n                                    else ''''||REPLACE(pt.v,'''','''''')||'''::'||t.input_type\r\n                                end\r\n                        WHEN jsonb_typeof(t.parsed) = 'null'\r\n                            then 'null'\r\n                        WHEN jsonb_typeof(t.parsed) = 'array'\r\n                            then ''''||REPLACE(pt.v,'''','''''')||'''::jsonb'\r\n                        ELSE\r\n                            pt.v\r\n                    END AS v\r\n            ) as p\r\n                ON TRUE\r\n            WHERE t.lvl = u.lvl\r\n                AND t.rn = u.rn\r\n                AND t.parsed IS NOT NULL;\r\n\r\n    update mytable u\r\n        set op = CASE \r\n                    when f.btwn\r\n                        then ' BETWEEN '\r\n                    else u.op -- f.inop\r\n                end,\r\n            parsed = format(vb.operand_format,u.parsed)::jsonb\r\n        FROM mytable t\r\n        join lateral\r\n        (\r\n            select  t.op like ' %/BETWEEN ' btwn, \r\n                    t.po_inner_brackets is not null inop\r\n        ) f \r\n            on true\r\n        join reclada.v_filter_between vb\r\n            on t.op = vb.operator\r\n            WHERE t.lvl = u.lvl\r\n                AND t.rn = u.rn\r\n                AND (f.btwn or f.inop);\r\n\r\n    INSERT INTO mytable (lvl,rn)\r\n        VALUES (0,0);\r\n\r\n    _count := 1;\r\n\r\n    WHILE (_count>0) LOOP\r\n        WITH r AS \r\n        (\r\n            UPDATE mytable\r\n                SET parsed = to_json(t.converted)::JSONB \r\n                FROM \r\n                (\r\n                    SELECT     \r\n                            res.lvl-1 lvl,\r\n                            res.prev rn,\r\n                            res.op,\r\n                            1 q,\r\n                            case \r\n                                when not res.po_inner_brackets \r\n                                    then array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op) \r\n                                else\r\n                                    CASE COUNT(1) \r\n                                        WHEN 1\r\n                                            THEN \r\n                                                CASE res.output_type\r\n                                                    when 'NUMERIC'\r\n                                                        then format('(%s %s)::TEXT::JSONB', res.op, min(res.parsed #>> '{}') )\r\n                                                    else \r\n                                                        format('(%s %s)', res.op, min(res.parsed #>> '{}') )\r\n                                                end\r\n                                        ELSE\r\n                                            CASE \r\n                                                when res.output_type = 'TEXT'\r\n                                                    then '(''"''||'||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op) ||'||''"'')::JSONB'\r\n                                                when res.output_type in ('NUMERIC','INT')\r\n                                                    then '('||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op) ||')::TEXT::JSONB'\r\n                                                else\r\n                                                    '('||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op) ||')'\r\n                                            end\r\n                                    end\r\n                            end AS converted\r\n                        FROM mytable res \r\n                            WHERE res.parsed IS NOT NULL\r\n                                AND res.lvl = (SELECT max(lvl)+1 FROM mytable WHERE parsed IS NULL)\r\n                            GROUP BY  res.prev, res.op, res.lvl, res.input_type, res.output_type, res.po_inner_brackets\r\n                ) t\r\n                WHERE\r\n                    t.lvl = mytable.lvl\r\n                        AND t.rn = mytable.rn\r\n                RETURNING 1\r\n        )\r\n            SELECT COUNT(1) \r\n                FROM r\r\n                INTO _count;\r\n    END LOOP;\r\n    \r\n    SELECT parsed #>> '{}' \r\n        FROM mytable\r\n            WHERE lvl = 0 AND rn = 0\r\n        INTO _res;\r\n    -- perform reclada.raise_notice( _res);\r\n    DROP TABLE mytable;\r\n    RETURN _res;\r\nEND \r\n$function$\n;\nDROP function IF EXISTS reclada_object.create ;\nCREATE OR REPLACE FUNCTION reclada_object."create"(data_jsonb jsonb, user_info jsonb DEFAULT '{}'::jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    branch        uuid;\r\n    data          jsonb;\r\n    class_name    text;\r\n    class_uuid    uuid;\r\n    tran_id       bigint;\r\n    _attrs         jsonb;\r\n    schema        jsonb;\r\n    obj_GUID      uuid;\r\n    res           jsonb;\r\n    affected      uuid[];\r\n    _parent_guid  uuid;\r\nBEGIN\r\n\r\n    IF (jsonb_typeof(data_jsonb) != 'array') THEN\r\n        data_jsonb := '[]'::jsonb || data_jsonb;\r\n    END IF;\r\n    /*TODO: check if some objects have revision and others do not */\r\n    branch:= data_jsonb->0->'branch';\r\n\r\n    FOR data IN SELECT jsonb_array_elements(data_jsonb) \r\n    LOOP\r\n\r\n        class_name := data->>'class';\r\n\r\n        IF (class_name IS NULL) THEN\r\n            RAISE EXCEPTION 'The reclada object class is not specified';\r\n        END IF;\r\n        class_uuid := reclada.try_cast_uuid(class_name);\r\n\r\n        _attrs := data->'attributes';\r\n        IF (_attrs IS NULL) THEN\r\n            RAISE EXCEPTION 'The reclada object must have attributes';\r\n        END IF;\r\n\r\n        tran_id := (data->>'transactionID')::bigint;\r\n        if tran_id is null then\r\n            tran_id := reclada.get_transaction_id();\r\n        end if;\r\n\r\n        IF class_uuid IS NULL THEN\r\n            SELECT reclada_object.get_schema(class_name) \r\n            INTO schema;\r\n            class_uuid := (schema->>'GUID')::uuid;\r\n        ELSE\r\n            SELECT v.data \r\n            FROM reclada.v_class v\r\n            WHERE class_uuid = v.obj_id\r\n            INTO schema;\r\n        END IF;\r\n        IF (schema IS NULL) THEN\r\n            RAISE EXCEPTION 'No json schema available for %', class_name;\r\n        END IF;\r\n\r\n        IF (NOT(public.validate_json_schema(schema->'attributes'->'schema', _attrs))) THEN\r\n            RAISE EXCEPTION 'JSON invalid: %', _attrs;\r\n        END IF;\r\n        \r\n        IF data->>'id' IS NOT NULL THEN\r\n            RAISE EXCEPTION '%','Field "id" not allow!!!';\r\n        END IF;\r\n\r\n        IF class_uuid IN (SELECT guid FROM reclada.v_PK_for_class)\r\n        THEN\r\n            SELECT o.obj_id\r\n                FROM reclada.v_object o\r\n                JOIN reclada.v_PK_for_class pk\r\n                    on pk.guid = o.class\r\n                        and class_uuid = o.class\r\n                where o.attrs->>pk.pk = _attrs ->> pk.pk\r\n                LIMIT 1\r\n            INTO obj_GUID;\r\n            IF obj_GUID IS NOT NULL THEN\r\n                SELECT reclada_object.update(data || format('{"GUID": "%s"}', obj_GUID)::jsonb)\r\n                    INTO res;\r\n                    RETURN '[]'::jsonb || res;\r\n            END IF;\r\n        END IF;\r\n\r\n        obj_GUID := (data->>'GUID')::uuid;\r\n        IF EXISTS (\r\n            SELECT 1\r\n            FROM reclada.object \r\n            WHERE GUID = obj_GUID\r\n        ) THEN\r\n            RAISE EXCEPTION 'GUID: % is duplicate', obj_GUID;\r\n        END IF;\r\n        --raise notice 'schema: %',schema;\r\n\r\n        _parent_guid = (data->>'parent_guid')::uuid;\r\n\r\n        INSERT INTO reclada.object(GUID,class,attributes,transaction_id, parent_guid)\r\n            SELECT  CASE\r\n                        WHEN obj_GUID IS NULL\r\n                            THEN public.uuid_generate_v4()\r\n                        ELSE obj_GUID\r\n                    END AS GUID,\r\n                    class_uuid, \r\n                    _attrs,\r\n                    tran_id,\r\n                    _parent_guid\r\n        RETURNING GUID INTO obj_GUID;\r\n        affected := array_append( affected, obj_GUID);\r\n\r\n        PERFORM reclada_object.datasource_insert\r\n            (\r\n                class_name,\r\n                obj_GUID,\r\n                _attrs\r\n            );\r\n\r\n        PERFORM reclada_object.refresh_mv(class_name);\r\n    END LOOP;\r\n\r\n    res := array_to_json\r\n            (\r\n                array\r\n                (\r\n                    SELECT o.data \r\n                    FROM reclada.v_active_object o\r\n                    WHERE o.obj_id = ANY (affected)\r\n                )\r\n            )::jsonb; \r\n    \r\n    delete from reclada.draft \r\n        where guid = ANY (affected);\r\n\r\n    PERFORM reclada_notification.send_object_notification\r\n        (\r\n            'create',\r\n            res\r\n        );\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.create_subclass ;\nCREATE OR REPLACE FUNCTION reclada_object.create_subclass(data jsonb)\n RETURNS void\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    class           text;\r\n    new_class       text;\r\n    attrs           jsonb;\r\n    class_schema    jsonb;\r\n    version_         integer;\r\n    class_guid    uuid;\r\nBEGIN\r\n\r\n    class := data->>'class';\r\n    IF (class IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object class is not specified';\r\n    END IF;\r\n\r\n    attrs := data->'attributes';\r\n    IF (attrs IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object must have attributes';\r\n    END IF;\r\n\r\n    new_class = attrs->>'newClass';\r\n\r\n    SELECT reclada_object.get_schema(class) INTO class_schema;\r\n\r\n    IF (class_schema IS NULL) THEN\r\n        RAISE EXCEPTION 'No json schema available for %', class;\r\n    END IF;\r\n\r\n    SELECT max(version) + 1\r\n    FROM reclada.v_class_lite v\r\n    WHERE v.for_class = new_class\r\n    INTO version_;\r\n\r\n    version_ := coalesce(version_,1);\r\n    class_schema := class_schema->'attributes'->'schema';\r\n\r\n    SELECT obj_id\r\n    FROM reclada.v_class\r\n    WHERE for_class = class\r\n    ORDER BY version DESC\r\n    LIMIT 1\r\n    INTO class_guid;\r\n\r\n    PERFORM reclada_object.create(format('{\r\n        "class": "jsonschema",\r\n        "attributes": {\r\n            "forClass": "%s",\r\n            "version": "%s",\r\n            "schema": {\r\n                "type": "object",\r\n                "properties": %s,\r\n                "required": %s\r\n            }\r\n        },\r\n        "parent_guid" : "%s"\r\n    }',\r\n    new_class,\r\n    version_,\r\n    (class_schema->'properties') || coalesce((attrs->'properties'),'{}'::jsonb),\r\n    (SELECT jsonb_agg(el) FROM (\r\n        SELECT DISTINCT pg_catalog.jsonb_array_elements(\r\n            (class_schema -> 'required') || coalesce((attrs -> 'required'),'{}'::jsonb)\r\n        ) el) arr),\r\n    class_guid\r\n    )::jsonb);\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.refresh_mv ;\nCREATE OR REPLACE FUNCTION reclada_object.refresh_mv(class_name text)\n RETURNS void\n LANGUAGE plpgsql\nAS $function$\r\nBEGIN\r\n    CASE class_name\r\n        WHEN 'ObjectStatus' THEN\r\n            REFRESH MATERIALIZED VIEW reclada.v_object_status;\r\n        WHEN 'User' THEN\r\n            REFRESH MATERIALIZED VIEW reclada.v_user;\r\n        WHEN 'jsonschema' THEN\r\n            REFRESH MATERIALIZED VIEW reclada.v_class_lite;\r\n        ELSE\r\n            NULL;\r\n    END CASE;\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.update ;\nCREATE OR REPLACE FUNCTION reclada_object.update(data jsonb, user_info jsonb DEFAULT '{}'::jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    _class_name     text;\r\n    class_uuid     uuid;\r\n    v_obj_id       uuid;\r\n    v_attrs        jsonb;\r\n    schema        jsonb;\r\n    old_obj       jsonb;\r\n    branch        uuid;\r\n    revid         uuid;\r\n\r\nBEGIN\r\n\r\n    _class_name := data->>'class';\r\n    IF (_class_name IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object class is not specified';\r\n    END IF;\r\n    class_uuid := reclada.try_cast_uuid(_class_name);\r\n    v_obj_id := data->>'GUID';\r\n    IF (v_obj_id IS NULL) THEN\r\n        RAISE EXCEPTION 'Could not update object with no GUID';\r\n    END IF;\r\n\r\n    v_attrs := data->'attributes';\r\n    IF (v_attrs IS NULL) THEN\r\n        RAISE EXCEPTION 'The reclada object must have attributes';\r\n    END IF;\r\n\r\n    SELECT reclada_object.get_schema(_class_name) \r\n        INTO schema;\r\n\r\n    if class_uuid is null then\r\n        SELECT reclada_object.get_schema(_class_name) \r\n            INTO schema;\r\n    else\r\n        select v.data, v.for_class \r\n            from reclada.v_class v\r\n                where class_uuid = v.obj_id\r\n            INTO schema, _class_name;\r\n    end if;\r\n    -- TODO: don't allow update jsonschema\r\n    IF (schema IS NULL) THEN\r\n        RAISE EXCEPTION 'No json schema available for %', _class_name;\r\n    END IF;\r\n\r\n    IF (NOT(public.validate_json_schema(schema->'attributes'->'schema', v_attrs))) THEN\r\n        RAISE EXCEPTION 'JSON invalid: %', v_attrs;\r\n    END IF;\r\n\r\n    SELECT \tv.data\r\n        FROM reclada.v_object v\r\n\t        WHERE v.obj_id = v_obj_id\r\n                AND v.class_name = _class_name \r\n\t    INTO old_obj;\r\n\r\n    IF (old_obj IS NULL) THEN\r\n        RAISE EXCEPTION 'Could not update object, no such id';\r\n    END IF;\r\n\r\n    branch := data->'branch';\r\n    SELECT reclada_revision.create(user_info->>'sub', branch, v_obj_id) \r\n        INTO revid;\r\n    \r\n    with t as \r\n    (\r\n        update reclada.object o\r\n            set status = reclada_object.get_archive_status_obj_id()\r\n                where o.GUID = v_obj_id\r\n                    and status != reclada_object.get_archive_status_obj_id()\r\n                        RETURNING id\r\n    )\r\n    INSERT INTO reclada.object( GUID,\r\n                                class,\r\n                                status,\r\n                                attributes,\r\n                                transaction_id\r\n                              )\r\n        select  v.obj_id,\r\n                (schema->>'GUID')::uuid,\r\n                reclada_object.get_active_status_obj_id(),--status \r\n                v_attrs || format('{"revision":"%s"}',revid)::jsonb,\r\n                transaction_id\r\n            FROM reclada.v_object v\r\n            JOIN \r\n            (   \r\n                select id \r\n                    FROM \r\n                    (\r\n                        select id, 1 as q\r\n                            from t\r\n                        union \r\n                        select id, 2 as q\r\n                            from reclada.object ro\r\n                                where ro.guid = v_obj_id\r\n                                    ORDER BY ID DESC \r\n                                        LIMIT 1\r\n                    ) ta\r\n                    ORDER BY q ASC \r\n                        LIMIT 1\r\n            ) as tt\r\n                on tt.id = v.id\r\n\t            WHERE v.obj_id = v_obj_id;\r\n    PERFORM reclada_object.datasource_insert\r\n            (\r\n                _class_name,\r\n                v_obj_id,\r\n                v_attrs\r\n            );\r\n    PERFORM reclada_object.refresh_mv(_class_name);  \r\n                  \r\n    select v.data \r\n        FROM reclada.v_active_object v\r\n            WHERE v.obj_id = v_obj_id\r\n        into data;\r\n    PERFORM reclada_notification.send_object_notification('update', data);\r\n    RETURN data;\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.datasource_insert ;\nCREATE OR REPLACE FUNCTION reclada_object.datasource_insert(_class_name text, _obj_id uuid, attributes jsonb)\n RETURNS void\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    _pipeline_lite jsonb;\r\n    _task  jsonb;\r\n    _dataset_guid  uuid;\r\n    _new_guid  uuid;\r\n    _pipeline_job_guid  uuid;\r\n    _stage         text;\r\n    _uri           text;\r\n    _environment   varchar;\r\n    _rel_cnt       int;\r\n    _dataset2ds_type text = 'defaultDataSet to DataSource';\r\n    _f_name text = 'reclada_object.datasource_insert';\r\nBEGIN\r\n    IF _class_name in ('DataSource','File') THEN\r\n\r\n        _uri := attributes->>'uri';\r\n\r\n\r\n        SELECT v.obj_id\r\n        FROM reclada.v_active_object v\r\n        WHERE v.class_name = 'DataSet'\r\n            and v.attrs->>'name' = 'defaultDataSet'\r\n        INTO _dataset_guid;\r\n\r\n        SELECT count(*)\r\n        FROM reclada.v_active_object\r\n        WHERE class_name = 'Relationship'\r\n            AND (attrs->>'object')::uuid = _obj_id\r\n            AND (attrs->>'subject')::uuid = _dataset_guid\r\n            AND attrs->>'type' = _dataset2ds_type\r\n                INTO _rel_cnt;\r\n\r\n        SELECT attrs->>'Environment'\r\n            FROM reclada.v_active_object\r\n                WHERE class_name = 'Context'\r\n                ORDER BY created_time DESC\r\n                LIMIT 1\r\n            INTO _environment;\r\n        IF _rel_cnt=0 THEN\r\n            PERFORM reclada_object.create(\r\n                    format('{\r\n                        "class": "Relationship",\r\n                        "attributes": {\r\n                            "type": "%s",\r\n                            "object": "%s",\r\n                            "subject": "%s"\r\n                            }\r\n                        }', _dataset2ds_type, _obj_id, _dataset_guid\r\n                    )::jsonb\r\n                );\r\n\r\n        END IF;\r\n        if _uri like '%inbox/jobs/%' then\r\n        \r\n            PERFORM reclada_object.create(\r\n                    format('{\r\n                        "class": "Job",\r\n                        "attributes": {\r\n                            "task": "c94bff30-15fa-427f-9954-d5c3c151e652",\r\n                            "status": "new",\r\n                            "type": "%s",\r\n                            "command": "./run_pipeline.sh",\r\n                            "inputParameters": [{"uri": "%s"}, {"dataSourceId": "%s"}]\r\n                            }\r\n                        }', _environment, _uri, _obj_id\r\n                    )::jsonb\r\n                );\r\n        \r\n        ELSE\r\n            \r\n            SELECT data \r\n                FROM reclada.v_active_object\r\n                    WHERE class_name = 'PipelineLite'\r\n                        LIMIT 1\r\n                INTO _pipeline_lite;\r\n            _new_guid := public.uuid_generate_v4();\r\n            IF _uri like '%inbox/pipelines/%/%' then\r\n                \r\n                _stage := SPLIT_PART(\r\n                                SPLIT_PART(_uri,'inbox/pipelines/',2),\r\n                                '/',\r\n                                2\r\n                            );\r\n                _stage = replace(_stage,'.json','');\r\n                SELECT data \r\n                    FROM reclada.v_active_object o\r\n                        where o.class_name = 'Task'\r\n                            and o.obj_id = (_pipeline_lite #>> ('{attributes,tasks,'||_stage||'}')::text[])::uuid\r\n                    into _task;\r\n                \r\n                _pipeline_job_guid = reclada.try_cast_uuid(\r\n                                        SPLIT_PART(\r\n                                            SPLIT_PART(_uri,'inbox/pipelines/',2),\r\n                                            '/',\r\n                                            1\r\n                                        )\r\n                                    );\r\n                if _pipeline_job_guid is null then \r\n                    perform reclada.raise_exception('PIPELINE_JOB_GUID not found',_f_name);\r\n                end if;\r\n                \r\n                SELECT  data #>> '{attributes,inputParameters,0,uri}',\r\n                        (data #>> '{attributes,inputParameters,1,dataSourceId}')::uuid\r\n                    from reclada.v_active_object o\r\n                        where o.obj_id = _pipeline_job_guid\r\n                    into _uri, _obj_id;\r\n\r\n            ELSE\r\n                SELECT data \r\n                    FROM reclada.v_active_object o\r\n                        where o.class_name = 'Task'\r\n                            and o.obj_id = (_pipeline_lite #>> '{attributes,tasks,0}')::uuid\r\n                    into _task;\r\n                _pipeline_job_guid := _new_guid;\r\n            END IF;\r\n            \r\n            PERFORM reclada_object.create(\r\n                format('{\r\n                    "GUID":"%s",\r\n                    "class": "Job",\r\n                    "attributes": {\r\n                        "task": "%s",\r\n                        "status": "new",\r\n                        "type": "%s",\r\n                        "command": "%s",\r\n                        "inputParameters": [\r\n                                { "uri"                 :"%s"   }, \r\n                                { "dataSourceId"        :"%s"   },\r\n                                { "PipelineLiteJobGUID" :"%s"   }\r\n                            ]\r\n                        }\r\n                    }',\r\n                        _new_guid::text,\r\n                        _task->>'GUID',\r\n                        _environment, \r\n                        _task-> 'attributes' ->>'command',\r\n                        _uri,\r\n                        _obj_id,\r\n                        _pipeline_job_guid::text\r\n                )::jsonb\r\n            );\r\n\r\n        END IF;\r\n    END IF;\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.parse_filter ;\nCREATE OR REPLACE FUNCTION reclada_object.parse_filter(data jsonb)\n RETURNS TABLE(lvl integer, rn bigint, idx bigint, op text, prev bigint, val jsonb, parsed jsonb)\n LANGUAGE sql\n IMMUTABLE\nAS $function$\r\n    WITH RECURSIVE f AS \r\n    (\r\n        SELECT data AS v\r\n    ),\r\n    pr AS \r\n    (\r\n        SELECT \tformat(' %s ',f.v->>'operator') AS op, \r\n                val.v AS val,\r\n                1 AS lvl,\r\n                row_number() OVER(ORDER BY idx) AS rn,\r\n                val.idx idx,\r\n                0::BIGINT prev\r\n            FROM f, jsonb_array_elements(f.v->'value') WITH ordinality AS val(v, idx)\r\n    ),\r\n    res AS\r\n    (\t\r\n        SELECT \tpr.lvl\t,\r\n                pr.rn\t,\r\n                pr.idx  ,\r\n                pr.op\t,\r\n                pr.prev ,\r\n                pr.val\t,\r\n                CASE jsonb_typeof(pr.val) \r\n                    WHEN 'object'\t\r\n                        THEN NULL\r\n                    ELSE pr.val\r\n                END AS parsed\r\n            FROM pr\r\n            WHERE prev = 0 \r\n                AND lvl = 1\r\n        UNION ALL\r\n        SELECT \tttt.lvl\t,\r\n                ROW_NUMBER() OVER(ORDER BY ttt.idx) AS rn,\r\n                ttt.idx,\r\n                ttt.op\t,\r\n                ttt.prev,\r\n                ttt.val ,\r\n                CASE jsonb_typeof(ttt.val) \r\n                    WHEN 'object'\t\r\n                        THEN NULL\r\n                    ELSE ttt.val\r\n                end AS parsed\r\n            FROM\r\n            (\r\n                SELECT \tres.lvl + 1 AS lvl,\r\n                        format(' %s ',res.val->>'operator') AS op,\r\n                        res.rn AS prev\t,\r\n                        val.v  AS val,\r\n                        val.idx\r\n                    FROM res, \r\n                         jsonb_array_elements(res.val->'value') WITH ordinality AS val(v, idx)\r\n            ) ttt\r\n    )\r\n    SELECT \tr.lvl\t,\r\n            r.rn\t,\r\n            r.idx   ,\r\n            case upper(r.op) \r\n                when ' XOR '\r\n                    then ' OPERATOR(reclada.##) ' \r\n                else upper(r.op) \r\n            end,\r\n            r.prev  ,\r\n            r.val\t,\r\n            r.parsed\r\n        FROM res r\r\n$function$\n;\nDROP function IF EXISTS reclada_object.list ;\nCREATE OR REPLACE FUNCTION reclada_object.list(data jsonb, gui boolean DEFAULT false, ver text DEFAULT '1'::text)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    _f_name TEXT = 'reclada_object.list';\r\n    _class              text;\r\n    attrs               jsonb;\r\n    order_by_jsonb      jsonb;\r\n    order_by            text;\r\n    limit_              text;\r\n    offset_             text;\r\n    query_conditions    text;\r\n    number_of_objects   int;\r\n    objects             jsonb;\r\n    res                 jsonb;\r\n    query               text;\r\n    class_uuid          uuid;\r\n    last_change         text;\r\n    tran_id             bigint;\r\n    _filter             JSONB;\r\n    _object_display     JSONB;\r\nBEGIN\r\n\r\n    perform reclada.validate_json(data, _f_name);\r\n\r\n    tran_id := (data->>'transactionID')::bigint;\r\n    _class := data->>'class';\r\n    _filter = data->'filter';\r\n\r\n    order_by_jsonb := data->'orderBy';\r\n    IF ((order_by_jsonb IS NULL) OR\r\n        (order_by_jsonb = 'null'::jsonb) OR\r\n        (order_by_jsonb = '[]'::jsonb)) THEN\r\n        order_by_jsonb := '[{"field": "GUID", "order": "ASC"}]'::jsonb;\r\n    END IF;\r\n    SELECT string_agg(\r\n        format(E'obj.data#>''{%s}'' %s', T.value->>'field', COALESCE(T.value->>'order', 'ASC')),\r\n        ' , ')\r\n        FROM jsonb_array_elements(order_by_jsonb) T\r\n        INTO order_by;\r\n\r\n    limit_ := data->>'limit';\r\n    IF (limit_ IS NULL) THEN\r\n        limit_ := 500;\r\n    END IF;\r\n\r\n    offset_ := data->>'offset';\r\n    IF (offset_ IS NULL) THEN\r\n        offset_ := 0;\r\n    END IF;\r\n    \r\n    IF (_filter IS NOT NULL) THEN\r\n        query_conditions := reclada_object.get_query_condition_filter(_filter);\r\n        IF ver = '2' THEN\r\n            query_conditions := REPLACE(query_conditions,'#>','->');\r\n        end if;\r\n    ELSE\r\n        class_uuid := reclada.try_cast_uuid(_class);\r\n\r\n        IF (class_uuid IS NULL) THEN\r\n            SELECT v.obj_id\r\n                FROM reclada.v_class v\r\n                    WHERE _class = v.for_class\r\n                    ORDER BY v.version DESC\r\n                    limit 1 \r\n            INTO class_uuid;\r\n            IF (class_uuid IS NULL) THEN\r\n                RAISE EXCEPTION 'Class not found: %', _class;\r\n            END IF;\r\n        end if;\r\n\r\n        attrs := data->'attributes' || '{}'::jsonb;\r\n\r\n        SELECT\r\n            string_agg(\r\n                format(\r\n                    E'(%s)',\r\n                    condition\r\n                ),\r\n                ' AND '\r\n            )\r\n            FROM (\r\n                SELECT\r\n                    format('obj.class_name = ''%s''', _class) AS condition\r\n                        where _class is not null\r\n                            and class_uuid is null\r\n                UNION\r\n                    SELECT format('obj.class = ''%s''', class_uuid) AS condition\r\n                        where class_uuid is not null\r\n                UNION\r\n                    SELECT format('obj.transaction_id = %s', tran_id) AS condition\r\n                        where tran_id is not null\r\n                UNION\r\n                    SELECT CASE\r\n                            WHEN jsonb_typeof(data->'GUID') = 'array' THEN\r\n                            (\r\n                                SELECT string_agg\r\n                                    (\r\n                                        format(\r\n                                            E'(%s)',\r\n                                            reclada_object.get_query_condition(cond, E'data->''GUID''') -- TODO: change data->'GUID' to obj_id(GUID)\r\n                                        ),\r\n                                        ' AND '\r\n                                    )\r\n                                    FROM jsonb_array_elements(data->'GUID') AS cond\r\n                            )\r\n                            ELSE reclada_object.get_query_condition(data->'GUID', E'data->''GUID''') -- TODO: change data->'GUID' to obj_id(GUID)\r\n                        END AS condition\r\n                    WHERE coalesce(data->'GUID','null'::jsonb) != 'null'::jsonb\r\n                UNION\r\n                SELECT\r\n                    CASE\r\n                        WHEN jsonb_typeof(value) = 'array'\r\n                            THEN\r\n                                (\r\n                                    SELECT string_agg\r\n                                        (\r\n                                            format\r\n                                            (\r\n                                                E'(%s)',\r\n                                                reclada_object.get_query_condition(cond, format(E'attrs->%L', key))\r\n                                            ),\r\n                                            ' AND '\r\n                                        )\r\n                                        FROM jsonb_array_elements(value) AS cond\r\n                                )\r\n                        ELSE reclada_object.get_query_condition(value, format(E'attrs->%L', key))\r\n                    END AS condition\r\n                FROM jsonb_each(attrs)\r\n                WHERE attrs != ('{}'::jsonb)\r\n            ) conds\r\n        INTO query_conditions;\r\n    END IF;\r\n    IF ver = '2' THEN\r\n        query := 'FROM reclada.v_ui_active_object obj WHERE ' || query_conditions;\r\n    ELSE\r\n        query := 'FROM reclada.v_active_object obj WHERE ' || query_conditions;\r\n    END IF;\r\n\r\n    -- RAISE NOTICE 'conds: %', '\r\n    --             SELECT obj.data\r\n    --             '\r\n    --             || query\r\n    --             ||\r\n    --             ' ORDER BY ' || order_by ||\r\n    --             ' OFFSET ' || offset_ || ' LIMIT ' || limit_ ;\r\n\r\n    EXECUTE E'SELECT to_jsonb(array_agg(T.data))\r\n        FROM (\r\n            SELECT obj.data\r\n            '\r\n            || query\r\n            ||\r\n            ' ORDER BY ' || order_by ||\r\n            ' OFFSET ' || offset_ || ' LIMIT ' || limit_ || ') T'\r\n    INTO objects;\r\n    objects := coalesce(objects,'[]'::jsonb);\r\n    IF gui THEN\r\n\r\n        if ver = '2' then\r\n            -- raise notice 'od: %',_object_display;\r\n            EXECUTE '   with recursive \r\n                        d as ( \r\n                            select  obj_id, data\r\n                                '|| query ||'\r\n                        ),\r\n                        t as\r\n                        (\r\n                            select distinct je.key v\r\n                                from d\r\n                                JOIN LATERAL jsonb_each(d.data) je\r\n                                    on true \r\n                        ),\r\n                        on_data as \r\n                        (\r\n                            select  jsonb_object_agg(\r\n                                        t.v, \r\n                                        replace(dd.template,''#@#attrname#@#'',t.v)::jsonb \r\n                                    ) t\r\n                                from t\r\n                                JOIN reclada.v_default_display dd\r\n                                    on t.v like ''%'' || dd.json_type\r\n                        )\r\n                        select od.t || coalesce(d.table,''{}''::jsonb)\r\n                            from on_data od\r\n                            left join reclada.v_object_display d\r\n                                on d.class_guid = '''||class_uuid::text||''''\r\n            INTO _object_display;\r\n\r\n        end if;\r\n        EXECUTE E'SELECT COUNT(1),\r\n                         TO_CHAR(\r\n                            MAX(\r\n                                GREATEST(obj.created_time, (\r\n                                    SELECT TO_TIMESTAMP(MAX(date_time),\\'YYYY-MM-DD hh24:mi:ss.US TZH\\')\r\n                                    FROM reclada.v_revision vr\r\n                                    WHERE vr.obj_id = UUID(obj.attrs ->>\\'revision\\'))\r\n                                )\r\n                            ),\\'YYYY-MM-DD hh24:mi:ss.MS TZH\\')\r\n            '|| query\r\n            INTO number_of_objects, last_change;\r\n        \r\n        IF _object_display IS NOT NULL then\r\n            res := jsonb_build_object(\r\n                    'lastСhange', last_change,    \r\n                    'number', number_of_objects,\r\n                    'objects', objects,\r\n                    'display', _object_display\r\n                );\r\n        ELSE\r\n            res := jsonb_build_object(\r\n                    'lastСhange', last_change,    \r\n                    'number', number_of_objects,\r\n                    'objects', objects\r\n            );\r\n        end if;\r\n    ELSE\r\n        \r\n        res := objects;\r\n    END IF;\r\n\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.create_relationship ;\n\nDROP function IF EXISTS reclada_object.create_job ;\n\n\n\nDROP function IF EXISTS reclada_object.list ;\nCREATE OR REPLACE FUNCTION reclada_object.list(data jsonb, gui boolean DEFAULT false, ver text DEFAULT '1'::text)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    _f_name TEXT = 'reclada_object.list';\r\n    _class              text;\r\n    attrs               jsonb;\r\n    order_by_jsonb      jsonb;\r\n    order_by            text;\r\n    limit_              text;\r\n    offset_             text;\r\n    query_conditions    text;\r\n    number_of_objects   int;\r\n    objects             jsonb;\r\n    res                 jsonb;\r\n    query               text;\r\n    class_uuid          uuid;\r\n    last_change         text;\r\n    tran_id             bigint;\r\n    _filter             JSONB;\r\n    _object_display     JSONB;\r\nBEGIN\r\n\r\n    perform reclada.validate_json(data, _f_name);\r\n\r\n    tran_id := (data->>'transactionID')::bigint;\r\n    _class := data->>'class';\r\n    _filter = data->'filter';\r\n\r\n    order_by_jsonb := data->'orderBy';\r\n    IF ((order_by_jsonb IS NULL) OR\r\n        (order_by_jsonb = 'null'::jsonb) OR\r\n        (order_by_jsonb = '[]'::jsonb)) THEN\r\n        order_by_jsonb := '[{"field": "GUID", "order": "ASC"}]'::jsonb;\r\n    END IF;\r\n    SELECT string_agg(\r\n        format(E'obj.data#>''{%s}'' %s', T.value->>'field', COALESCE(T.value->>'order', 'ASC')),\r\n        ' , ')\r\n        FROM jsonb_array_elements(order_by_jsonb) T\r\n        INTO order_by;\r\n\r\n    limit_ := data->>'limit';\r\n    IF (limit_ IS NULL) THEN\r\n        limit_ := 500;\r\n    END IF;\r\n\r\n    offset_ := data->>'offset';\r\n    IF (offset_ IS NULL) THEN\r\n        offset_ := 0;\r\n    END IF;\r\n    \r\n    IF (_filter IS NOT NULL) THEN\r\n        query_conditions := reclada_object.get_query_condition_filter(_filter);\r\n        IF ver = '2' THEN\r\n            query_conditions := REPLACE(query_conditions,'#>','->');\r\n        end if;\r\n    ELSE\r\n        class_uuid := reclada.try_cast_uuid(_class);\r\n\r\n        IF (class_uuid IS NULL) THEN\r\n            SELECT v.obj_id\r\n                FROM reclada.v_class v\r\n                    WHERE _class = v.for_class\r\n                    ORDER BY v.version DESC\r\n                    limit 1 \r\n            INTO class_uuid;\r\n            IF (class_uuid IS NULL) THEN\r\n                RAISE EXCEPTION 'Class not found: %', _class;\r\n            END IF;\r\n        end if;\r\n\r\n        attrs := data->'attributes' || '{}'::jsonb;\r\n\r\n        SELECT\r\n            string_agg(\r\n                format(\r\n                    E'(%s)',\r\n                    condition\r\n                ),\r\n                ' AND '\r\n            )\r\n            FROM (\r\n                SELECT\r\n                    format('obj.class_name = ''%s''', _class) AS condition\r\n                        where _class is not null\r\n                            and class_uuid is null\r\n                UNION\r\n                    SELECT format('obj.class = ''%s''', class_uuid) AS condition\r\n                        where class_uuid is not null\r\n                UNION\r\n                    SELECT format('obj.transaction_id = %s', tran_id) AS condition\r\n                        where tran_id is not null\r\n                UNION\r\n                    SELECT CASE\r\n                            WHEN jsonb_typeof(data->'GUID') = 'array' THEN\r\n                            (\r\n                                SELECT string_agg\r\n                                    (\r\n                                        format(\r\n                                            E'(%s)',\r\n                                            reclada_object.get_query_condition(cond, E'data->''GUID''') -- TODO: change data->'GUID' to obj_id(GUID)\r\n                                        ),\r\n                                        ' AND '\r\n                                    )\r\n                                    FROM jsonb_array_elements(data->'GUID') AS cond\r\n                            )\r\n                            ELSE reclada_object.get_query_condition(data->'GUID', E'data->''GUID''') -- TODO: change data->'GUID' to obj_id(GUID)\r\n                        END AS condition\r\n                    WHERE coalesce(data->'GUID','null'::jsonb) != 'null'::jsonb\r\n                UNION\r\n                SELECT\r\n                    CASE\r\n                        WHEN jsonb_typeof(value) = 'array'\r\n                            THEN\r\n                                (\r\n                                    SELECT string_agg\r\n                                        (\r\n                                            format\r\n                                            (\r\n                                                E'(%s)',\r\n                                                reclada_object.get_query_condition(cond, format(E'attrs->%L', key))\r\n                                            ),\r\n                                            ' AND '\r\n                                        )\r\n                                        FROM jsonb_array_elements(value) AS cond\r\n                                )\r\n                        ELSE reclada_object.get_query_condition(value, format(E'attrs->%L', key))\r\n                    END AS condition\r\n                FROM jsonb_each(attrs)\r\n                WHERE attrs != ('{}'::jsonb)\r\n            ) conds\r\n        INTO query_conditions;\r\n    END IF;\r\n    IF ver = '2' THEN\r\n        query := 'FROM reclada.v_ui_active_object obj WHERE ' || query_conditions;\r\n    ELSE\r\n        query := 'FROM reclada.v_active_object obj WHERE ' || query_conditions;\r\n    END IF;\r\n\r\n    -- RAISE NOTICE 'conds: %', '\r\n    --             SELECT obj.data\r\n    --             '\r\n    --             || query\r\n    --             ||\r\n    --             ' ORDER BY ' || order_by ||\r\n    --             ' OFFSET ' || offset_ || ' LIMIT ' || limit_ ;\r\n\r\n    EXECUTE E'SELECT to_jsonb(array_agg(T.data))\r\n        FROM (\r\n            SELECT obj.data\r\n            '\r\n            || query\r\n            ||\r\n            ' ORDER BY ' || order_by ||\r\n            ' OFFSET ' || offset_ || ' LIMIT ' || limit_ || ') T'\r\n    INTO objects;\r\n    objects := coalesce(objects,'[]'::jsonb);\r\n    IF gui THEN\r\n\r\n        if ver = '2' then\r\n            -- raise notice 'od: %',_object_display;\r\n            EXECUTE '   with recursive \r\n                        d as ( \r\n                            select  obj_id, data\r\n                                '|| query ||'\r\n                        ),\r\n                        t as\r\n                        (\r\n                            select distinct je.key v\r\n                                from d\r\n                                JOIN LATERAL jsonb_each(d.data) je\r\n                                    on true \r\n                        ),\r\n                        on_data as \r\n                        (\r\n                            select  jsonb_object_agg(\r\n                                        t.v, \r\n                                        replace(dd.template,''#@#attrname#@#'',t.v)::jsonb \r\n                                    ) t\r\n                                from t\r\n                                JOIN reclada.v_default_display dd\r\n                                    on t.v like ''%'' || dd.json_type\r\n                        )\r\n                        select od.t || coalesce(d.table,''{}''::jsonb)\r\n                            from on_data od\r\n                            left join reclada.v_object_display d\r\n                                on d.class_guid = '''||class_uuid::text||''''\r\n            INTO _object_display;\r\n\r\n        end if;\r\n        EXECUTE E'SELECT COUNT(1),\r\n                         TO_CHAR(\r\n                            MAX(\r\n                                GREATEST(obj.created_time, (\r\n                                    SELECT TO_TIMESTAMP(MAX(date_time),\\'YYYY-MM-DD hh24:mi:ss.US TZH\\')\r\n                                    FROM reclada.v_revision vr\r\n                                    WHERE vr.obj_id = UUID(obj.attrs ->>\\'revision\\'))\r\n                                )\r\n                            ),\\'YYYY-MM-DD hh24:mi:ss.MS TZH\\')\r\n            '|| query\r\n            INTO number_of_objects, last_change;\r\n        \r\n        IF _object_display IS NOT NULL then\r\n            res := jsonb_build_object(\r\n                    'lastСhange', last_change,    \r\n                    'number', number_of_objects,\r\n                    'objects', objects,\r\n                    'display', _object_display\r\n                );\r\n        ELSE\r\n            res := jsonb_build_object(\r\n                    'lastСhange', last_change,    \r\n                    'number', number_of_objects,\r\n                    'objects', objects\r\n            );\r\n        end if;\r\n    ELSE\r\n        \r\n        res := objects;\r\n    END IF;\r\n\r\n    RETURN res;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS api.reclada_object_list ;\nCREATE OR REPLACE FUNCTION api.reclada_object_list(data jsonb DEFAULT NULL::jsonb, ver text DEFAULT '1'::text, draft text DEFAULT 'false'::text)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    _class              text;\r\n    user_info           jsonb;\r\n    result              jsonb;\r\n    _filter             jsonb;\r\nBEGIN\r\n\r\n    if draft != 'false' then\r\n        return array_to_json\r\n            (\r\n                array\r\n                (\r\n                    SELECT o.data \r\n                        FROM reclada.draft o\r\n                            where id = \r\n                                (\r\n                                    select max(id) \r\n                                        FROM reclada.draft d\r\n                                            where o.guid = d.guid\r\n                                )\r\n                            -- and o.user = user_info->>'guid'\r\n                )\r\n            )::jsonb;\r\n    end if;\r\n\r\n    _class := CASE ver\r\n                when '1'\r\n                    then data->>'class'\r\n                when '2'\r\n                    then data->>'{class}'\r\n            end;\r\n    IF(_class IS NULL) THEN\r\n        RAISE EXCEPTION 'reclada object class not specified';\r\n    END IF;\r\n\r\n    _filter = data->'filter';\r\n    IF _filter IS NOT NULL THEN\r\n        SELECT format(  '{\r\n                            "filter":\r\n                            {\r\n                                "operator":"AND",\r\n                                "value":[\r\n                                    {\r\n                                        "operator":"=",\r\n                                        "value":["{class}","%s"]\r\n                                    },\r\n                                    %s\r\n                                ]\r\n                            }\r\n                        }',\r\n                _class,\r\n                _filter\r\n            )::jsonb \r\n            INTO _filter;\r\n        data := data || _filter;\r\n    ELSE\r\n        data := data || ('{"class":"'|| _class ||'"}')::jsonb;\r\n    --     select format(  '{\r\n    --                         "filter":{\r\n    --                             "operator":"=",\r\n    --                             "value":["{class}","%s"]\r\n    --                         }\r\n    --                     }',\r\n    --             class,\r\n    --             _filter\r\n    --         )::jsonb \r\n    --         INTO _filter;\r\n    END IF;\r\n\r\n    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;\r\n    data := data - 'accessToken';\r\n\r\n    IF (NOT(reclada_user.is_allowed(user_info, 'list', _class))) THEN\r\n        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'list', _class;\r\n    END IF;\r\n\r\n    SELECT reclada_object.list(data, true, ver) \r\n        INTO result;\r\n    RETURN result;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.get_query_condition_filter ;\nCREATE OR REPLACE FUNCTION reclada_object.get_query_condition_filter(data jsonb)\n RETURNS text\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE \r\n    _count   INT;\r\n    _res     TEXT;\r\n    _f_name TEXT = 'reclada_object.get_query_condition_filter';\r\nBEGIN \r\n    \r\n    perform reclada.validate_json(data, _f_name);\r\n    -- TODO: to change VOLATILE -> IMMUTABLE, remove CREATE TEMP TABLE\r\n    CREATE TEMP TABLE mytable AS\r\n        SELECT  res.lvl              AS lvl         , \r\n                res.rn               AS rn          , \r\n                res.idx              AS idx         ,\r\n                res.prev             AS prev        , \r\n                res.val              AS val         ,  \r\n                res.parsed           AS parsed      , \r\n                coalesce(\r\n                    po.inner_operator, \r\n                    op.operator\r\n                )                   AS op           , \r\n                coalesce\r\n                (\r\n                    iop.input_type,\r\n                    op.input_type\r\n                )                   AS input_type   ,\r\n                case \r\n                    when iop.input_type is not NULL \r\n                        then NULL \r\n                    else \r\n                        op.output_type\r\n                end                 AS output_type  ,\r\n                po.operator         AS po           ,\r\n                po.input_type       AS po_input_type,\r\n                iop.brackets        AS po_inner_brackets\r\n            FROM reclada_object.parse_filter(data) res\r\n            LEFT JOIN reclada.v_filter_avaliable_operator op\r\n                ON res.op = op.operator\r\n            LEFT JOIN reclada_object.parse_filter(data) p\r\n                on  p.lvl = res.lvl-1\r\n                    and res.prev = p.rn\r\n            LEFT JOIN reclada.v_filter_avaliable_operator po\r\n                on po.operator = p.op\r\n            LEFT JOIN reclada.v_filter_inner_operator iop\r\n                on iop.operator = po.inner_operator;\r\n\r\n    PERFORM reclada.raise_exception('Operator does not allowed ' || t.op, _f_name)\r\n        FROM mytable t\r\n            WHERE t.op IS NULL;\r\n\r\n\r\n    UPDATE mytable u\r\n        SET parsed = to_jsonb(p.v)\r\n            FROM mytable t\r\n            JOIN LATERAL \r\n            (\r\n                SELECT  t.parsed #>> '{}' v\r\n            ) as pt\r\n                ON TRUE\r\n            LEFT JOIN reclada.v_filter_mapping fm\r\n                ON pt.v = fm.pattern\r\n            JOIN LATERAL \r\n            (\r\n                SELECT CASE \r\n                        WHEN fm.repl is not NULL \r\n                            then \r\n                                case \r\n                                    when t.input_type in ('TEXT')\r\n                                        then fm.repl || '::TEXT'\r\n                                    else '(''"''||' ||fm.repl ||'||''"'')::jsonb' -- don't use FORMAT (concat null)\r\n                                end\r\n                        WHEN jsonb_typeof(t.parsed) in ('number', 'boolean')\r\n                            then \r\n                                case \r\n                                    when t.input_type in ('NUMERIC','INT')\r\n                                        then pt.v\r\n                                    else '''' || pt.v || '''::jsonb'\r\n                                end\r\n                        WHEN jsonb_typeof(t.parsed) = 'string' \r\n                            then    \r\n                                case\r\n                                    WHEN pt.v LIKE '{%}'\r\n                                        THEN\r\n                                            case\r\n                                                when t.input_type = 'TEXT'\r\n                                                    then format('(data #>> ''%s'')', pt.v)\r\n                                                when t.input_type = 'JSONB' or t.input_type is null\r\n                                                    then format('data #> ''%s''', pt.v)\r\n                                                else\r\n                                                    format('(data #>> ''%s'')::', pt.v) || t.input_type\r\n                                            end\r\n                                    when t.input_type = 'TEXT'\r\n                                        then ''''||REPLACE(pt.v,'''','''''')||''''\r\n                                    when t.input_type = 'JSONB' or t.input_type is null\r\n                                        then '''"'||REPLACE(pt.v,'''','''''')||'"''::jsonb'\r\n                                    else ''''||REPLACE(pt.v,'''','''''')||'''::'||t.input_type\r\n                                end\r\n                        WHEN jsonb_typeof(t.parsed) = 'null'\r\n                            then 'null'\r\n                        WHEN jsonb_typeof(t.parsed) = 'array'\r\n                            then ''''||REPLACE(pt.v,'''','''''')||'''::jsonb'\r\n                        ELSE\r\n                            pt.v\r\n                    END AS v\r\n            ) as p\r\n                ON TRUE\r\n            WHERE t.lvl = u.lvl\r\n                AND t.rn = u.rn\r\n                AND t.parsed IS NOT NULL;\r\n\r\n    update mytable u\r\n        set op = CASE \r\n                    when f.btwn\r\n                        then ' BETWEEN '\r\n                    else u.op -- f.inop\r\n                end,\r\n            parsed = format(vb.operand_format,u.parsed)::jsonb\r\n        FROM mytable t\r\n        join lateral\r\n        (\r\n            select  t.op like ' %/BETWEEN ' btwn, \r\n                    t.po_inner_brackets is not null inop\r\n        ) f \r\n            on true\r\n        join reclada.v_filter_between vb\r\n            on t.op = vb.operator\r\n            WHERE t.lvl = u.lvl\r\n                AND t.rn = u.rn\r\n                AND (f.btwn or f.inop);\r\n\r\n    INSERT INTO mytable (lvl,rn)\r\n        VALUES (0,0);\r\n\r\n    _count := 1;\r\n\r\n    WHILE (_count>0) LOOP\r\n        WITH r AS \r\n        (\r\n            UPDATE mytable\r\n                SET parsed = to_json(t.converted)::JSONB \r\n                FROM \r\n                (\r\n                    SELECT     \r\n                            res.lvl-1 lvl,\r\n                            res.prev rn,\r\n                            res.op,\r\n                            1 q,\r\n                            case \r\n                                when not res.po_inner_brackets \r\n                                    then array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op) \r\n                                else\r\n                                    CASE COUNT(1) \r\n                                        WHEN 1\r\n                                            THEN \r\n                                                CASE res.output_type\r\n                                                    when 'NUMERIC'\r\n                                                        then format('(%s %s)::TEXT::JSONB', res.op, min(res.parsed #>> '{}') )\r\n                                                    else \r\n                                                        format('(%s %s)', res.op, min(res.parsed #>> '{}') )\r\n                                                end\r\n                                        ELSE\r\n                                            CASE \r\n                                                when res.output_type = 'TEXT'\r\n                                                    then '(''"''||'||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op) ||'||''"'')::JSONB'\r\n                                                when res.output_type in ('NUMERIC','INT')\r\n                                                    then '('||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op) ||')::TEXT::JSONB'\r\n                                                else\r\n                                                    '('||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op) ||')'\r\n                                            end\r\n                                    end\r\n                            end AS converted\r\n                        FROM mytable res \r\n                            WHERE res.parsed IS NOT NULL\r\n                                AND res.lvl = (SELECT max(lvl)+1 FROM mytable WHERE parsed IS NULL)\r\n                            GROUP BY  res.prev, res.op, res.lvl, res.input_type, res.output_type, res.po_inner_brackets\r\n                ) t\r\n                WHERE\r\n                    t.lvl = mytable.lvl\r\n                        AND t.rn = mytable.rn\r\n                RETURNING 1\r\n        )\r\n            SELECT COUNT(1) \r\n                FROM r\r\n                INTO _count;\r\n    END LOOP;\r\n    \r\n    SELECT parsed #>> '{}' \r\n        FROM mytable\r\n            WHERE lvl = 0 AND rn = 0\r\n        INTO _res;\r\n    -- perform reclada.raise_notice( _res);\r\n    DROP TABLE mytable;\r\n    RETURN _res;\r\nEND \r\n$function$\n;\nDROP function IF EXISTS api.reclada_object_create ;\nCREATE OR REPLACE FUNCTION api.reclada_object_create(data jsonb, ver text DEFAULT '1'::text, draft text DEFAULT 'false'::text)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    data_jsonb       jsonb;\r\n    class            text;\r\n    user_info        jsonb;\r\n    attrs            jsonb;\r\n    data_to_create   jsonb = '[]'::jsonb;\r\n    result           jsonb;\r\n    _need_flat       bool := false;\r\n    _draft           bool;\r\n    _guid            uuid;\r\nBEGIN\r\n\r\n    _draft := draft != 'false';\r\n\r\n    IF (jsonb_typeof(data) != 'array') THEN\r\n        data := '[]'::jsonb || data;\r\n    END IF;\r\n\r\n    FOR data_jsonb IN SELECT jsonb_array_elements(data) LOOP\r\n\r\n        _guid := CASE ver\r\n                        when '1'\r\n                            then data_jsonb->>'GUID'\r\n                        when '2'\r\n                            then data_jsonb->>'{GUID}'\r\n                    end;\r\n        if _draft then\r\n            INSERT into reclada.draft(guid,data)\r\n                values(_guid,data_jsonb);\r\n        else\r\n\r\n             class := CASE ver\r\n                            when '1'\r\n                                then data_jsonb->>'class'\r\n                            when '2'\r\n                                then data_jsonb->>'{class}'\r\n                        end;\r\n\r\n            IF (class IS NULL) THEN\r\n                RAISE EXCEPTION 'The reclada object class is not specified (api)';\r\n            END IF;\r\n\r\n            SELECT reclada_user.auth_by_token(data_jsonb->>'accessToken') INTO user_info;\r\n            data_jsonb := data_jsonb - 'accessToken';\r\n\r\n            IF (NOT(reclada_user.is_allowed(user_info, 'create', class))) THEN\r\n                RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'create', class;\r\n            END IF;\r\n            \r\n            if ver = '2' then\r\n                _need_flat := true;\r\n                with recursive j as \r\n                (\r\n                    select  row_number() over() as id,\r\n                            key,\r\n                            value \r\n                        from jsonb_each(data_jsonb)\r\n                            where key like '{%}'\r\n                ),\r\n                inn as \r\n                (\r\n                    SELECT  row_number() over(order by s.id,j.id) rn,\r\n                            j.id,\r\n                            s.id sid,\r\n                            s.d,\r\n                            ARRAY (\r\n                                SELECT UNNEST(arr.v) \r\n                                LIMIT array_position(arr.v, s.d)\r\n                            ) as k\r\n                        FROM j\r\n                        left join lateral\r\n                        (\r\n                            select id, d ,max(id) over() mid\r\n                            from\r\n                            (\r\n                                SELECT  row_number() over() as id, \r\n                                        d\r\n                                    from regexp_split_to_table(substring(j.key,2,char_length(j.key)-2),',') d \r\n                            ) t\r\n                        ) s on s.mid != s.id\r\n                        join lateral\r\n                        (\r\n                            select regexp_split_to_array(substring(j.key,2,char_length(j.key)-2),',') v\r\n                        ) arr on true\r\n                            where d is not null\r\n                ),\r\n                src as\r\n                (\r\n                    select  jsonb_set('{}'::jsonb,('{'|| i.d ||'}')::text[],'{}'::jsonb) r,\r\n                            i.rn\r\n                        from inn i\r\n                            where i.rn = 1\r\n                    union\r\n                    select  jsonb_set(\r\n                                s.r,\r\n                                i.k,\r\n                                '{}'::jsonb\r\n                            ) r,\r\n                            i.rn\r\n                        from src s\r\n                        join inn i\r\n                            on s.rn + 1 = i.rn\r\n                ),\r\n                tmpl as \r\n                (\r\n                    select r v\r\n                        from src\r\n                        ORDER BY rn DESC\r\n                        limit 1\r\n                ),\r\n                res as\r\n                (\r\n                    SELECT jsonb_set(\r\n                            (select v from tmpl),\r\n                            j.key::text[],\r\n                            j.value\r\n                        ) v,\r\n                        j.id\r\n                        FROM j\r\n                            where j.id = 1\r\n                    union \r\n                    select jsonb_set(\r\n                            res.v,\r\n                            j.key::text[],\r\n                            j.value\r\n                        ) v,\r\n                        j.id\r\n                        FROM res\r\n                        join j\r\n                            on res.id + 1 =j.id\r\n                )\r\n                SELECT v \r\n                    FROM res\r\n                    ORDER BY ID DESC\r\n                    limit 1\r\n                    into data_jsonb;\r\n            end if;\r\n\r\n            if data_jsonb is null then\r\n                RAISE EXCEPTION 'JSON invalid';\r\n            end if;\r\n            data_to_create := data_to_create || data_jsonb;\r\n        end if;\r\n    END LOOP;\r\n\r\n    if data_to_create is not  null then\r\n        SELECT reclada_object.create(data_to_create, user_info) \r\n            INTO result;\r\n    end if;\r\n    if ver = '2' or _draft then\r\n        RETURN '{"status":"OK"}'::jsonb;\r\n    end if;\r\n    RETURN result;\r\n\r\nEND;\r\n$function$\n;\nDROP function IF EXISTS reclada_object.delete ;\nCREATE OR REPLACE FUNCTION reclada_object.delete(data jsonb, user_info jsonb DEFAULT '{}'::jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    v_obj_id            uuid;\r\n    tran_id             bigint;\r\n    class               text;\r\n    class_uuid          uuid;\r\n    list_id             bigint[];\r\n\r\nBEGIN\r\n\r\n    v_obj_id := data->>'GUID';\r\n    tran_id := (data->>'transactionID')::bigint;\r\n    class := data->>'class';\r\n\r\n    IF (v_obj_id IS NULL AND class IS NULL AND tran_id IS NULl) THEN\r\n        RAISE EXCEPTION 'Could not delete object with no GUID, class and transactionID';\r\n    END IF;\r\n\r\n    class_uuid := reclada.try_cast_uuid(class);\r\n\r\n    WITH t AS\r\n    (    \r\n        UPDATE reclada.object u\r\n            SET status = reclada_object.get_archive_status_obj_id()\r\n            FROM reclada.object o\r\n                LEFT JOIN\r\n                (   SELECT obj_id FROM reclada_object.get_GUID_for_class(class)\r\n                    UNION SELECT class_uuid WHERE class_uuid IS NOT NULL\r\n                ) c ON o.class = c.obj_id\r\n                WHERE u.id = o.id AND\r\n                (\r\n                    (v_obj_id = o.GUID AND c.obj_id = o.class AND tran_id = o.transaction_id)\r\n\r\n                    OR (v_obj_id = o.GUID AND c.obj_id = o.class AND tran_id IS NULL)\r\n                    OR (v_obj_id = o.GUID AND c.obj_id IS NULL AND tran_id = o.transaction_id)\r\n                    OR (v_obj_id IS NULL AND c.obj_id = o.class AND tran_id = o.transaction_id)\r\n\r\n                    OR (v_obj_id = o.GUID AND c.obj_id IS NULL AND tran_id IS NULL)\r\n                    OR (v_obj_id IS NULL AND c.obj_id = o.class AND tran_id IS NULL)\r\n                    OR (v_obj_id IS NULL AND c.obj_id IS NULL AND tran_id = o.transaction_id)\r\n                )\r\n                    AND o.status != reclada_object.get_archive_status_obj_id()\r\n                    RETURNING o.id\r\n    ) \r\n        SELECT\r\n            array\r\n            (\r\n                SELECT t.id FROM t\r\n            )\r\n        INTO list_id;\r\n\r\n    SELECT array_to_json\r\n    (\r\n        array\r\n        (\r\n            SELECT o.data\r\n            FROM reclada.v_object o\r\n            WHERE o.id IN (SELECT unnest(list_id))\r\n        )\r\n    )::jsonb\r\n    INTO data;\r\n\r\n    IF (jsonb_array_length(data) = 1) THEN\r\n        data := data->0;\r\n    END IF;\r\n    \r\n    IF (data IS NULL) THEN\r\n        RAISE EXCEPTION 'Could not delete object, no such GUID';\r\n    END IF;\r\n\r\n    PERFORM reclada_object.refresh_mv(class);\r\n\r\n    PERFORM reclada_notification.send_object_notification('delete', data);\r\n\r\n    RETURN data;\r\nEND;\r\n$function$\n;\n\nDROP VIEW reclada.v_ui_active_object;\nDROP VIEW reclada.v_revision;\nDROP VIEW reclada.v_import_info;\nDROP VIEW reclada.v_dto_json_schema;\nDROP VIEW reclada.v_class;\nDROP VIEW reclada.v_default_display;\nDROP VIEW reclada.v_filter_available_operator;\nDROP VIEW reclada.v_task;\nDROP VIEW reclada.v_active_object;\nDROP view IF EXISTS reclada.v_object ;\nCREATE OR REPLACE VIEW reclada.v_object\nAS\n SELECT t.id,\n    t.guid AS obj_id,\n    t.class,\n    ( SELECT (r.attributes ->> 'num'::text)::bigint AS num\n           FROM object r\n          WHERE (r.class IN ( SELECT reclada_object.get_guid_for_class('revision'::text) AS get_guid_for_class)) AND r.guid = NULLIF(t.attributes ->> 'revision'::text, ''::text)::uuid\n         LIMIT 1) AS revision_num,\n    os.caption AS status_caption,\n    NULLIF(t.attributes ->> 'revision'::text, ''::text)::uuid AS revision,\n    t.created_time,\n    t.attributes AS attrs,\n    cl.for_class AS class_name,\n    (( SELECT json_agg(tmp.*) -> 0\n           FROM ( SELECT t.guid AS "GUID",\n                    t.class,\n                    os.caption AS status,\n                    t.attributes,\n                    t.transaction_id AS "transactionID",\n                    t.parent_guid AS "parentGUID",\n                    t.created_time AS "createdTime") tmp))::jsonb AS data,\n    u.login AS login_created_by,\n    t.created_by,\n    t.status,\n    t.transaction_id,\n    t.parent_guid\n   FROM object t\n     LEFT JOIN v_object_status os ON t.status = os.obj_id\n     LEFT JOIN v_user u ON u.obj_id = t.created_by\n     LEFT JOIN v_class_lite cl ON cl.obj_id = t.class;\nDROP view IF EXISTS reclada.v_active_object ;\nCREATE OR REPLACE VIEW reclada.v_active_object\nAS\n SELECT t.id,\n    t.obj_id,\n    t.class,\n    t.revision_num,\n    t.status,\n    t.status_caption,\n    t.revision,\n    t.created_time,\n    t.class_name,\n    t.attrs,\n    t.data,\n    t.transaction_id,\n    t.parent_guid\n   FROM v_object t\n  WHERE t.status = reclada_object.get_active_status_obj_id();\nDROP view IF EXISTS reclada.v_task ;\nCREATE OR REPLACE VIEW reclada.v_task\nAS\n SELECT obj.id,\n    obj.obj_id AS guid,\n    obj.attrs ->> 'type'::text AS type,\n    obj.attrs ->> 'command'::text AS command,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class_name = 'Task'::text;\nDROP view IF EXISTS reclada.v_default_display ;\nCREATE OR REPLACE VIEW reclada.v_default_display\nAS\n SELECT 'string'::text AS json_type,\n    '{"caption": "#@#attrname#@#","width": 250,"displayCSS": "#@#attrname#@#"}'::text AS template\nUNION\n SELECT 'number'::text AS json_type,\n    '{"caption": "#@#attrname#@#","width": 250,"displayCSS": "#@#attrname#@#"}'::text AS template\nUNION\n SELECT 'boolean'::text AS json_type,\n    '{"caption": "#@#attrname#@#","width": 250,"displayCSS": "#@#attrname#@#"}'::text AS template;\nDROP view IF EXISTS reclada.v_filter_avaliable_operator ;\nCREATE OR REPLACE VIEW reclada.v_filter_avaliable_operator\nAS\n SELECT ' = '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' LIKE '::text AS operator,\n    'TEXT'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' NOT LIKE '::text AS operator,\n    'TEXT'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' || '::text AS operator,\n    'TEXT'::text AS input_type,\n    'TEXT'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' ~ '::text AS operator,\n    'TEXT'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' !~ '::text AS operator,\n    'TEXT'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' ~* '::text AS operator,\n    'TEXT'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' !~* '::text AS operator,\n    'TEXT'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' SIMILAR TO '::text AS operator,\n    'TEXT'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' > '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' < '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' <= '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' != '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' >= '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' AND '::text AS operator,\n    'BOOL'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' OR '::text AS operator,\n    'BOOL'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' NOT '::text AS operator,\n    'BOOL'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' XOR '::text AS operator,\n    'BOOL'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' IS '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' IS NOT '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' IN '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type,\n    ' , '::text AS inner_operator\nUNION\n SELECT ' @> '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' <@ '::text AS operator,\n    'JSONB'::text AS input_type,\n    'BOOL'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' + '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' - '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' * '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' / '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' % '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' ^ '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' |/ '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' ||/ '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' !! '::text AS operator,\n    'INT'::text AS input_type,\n    'NUMERIC'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' @ '::text AS operator,\n    'NUMERIC'::text AS input_type,\n    'NUMERIC'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' & '::text AS operator,\n    'INT'::text AS input_type,\n    'INT'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' | '::text AS operator,\n    'INT'::text AS input_type,\n    'INT'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' # '::text AS operator,\n    'INT'::text AS input_type,\n    'INT'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' << '::text AS operator,\n    'INT'::text AS input_type,\n    'INT'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' >> '::text AS operator,\n    'INT'::text AS input_type,\n    'INT'::text AS output_type,\n    NULL::text AS inner_operator\nUNION\n SELECT ' BETWEEN '::text AS operator,\n    'TIMESTAMP WITH TIME ZONE'::text AS input_type,\n    'BOOL'::text AS output_type,\n    ' AND '::text AS inner_operator\nUNION\n SELECT ' Y/BETWEEN '::text AS operator,\n    NULL::text AS input_type,\n    NULL::text AS output_type,\n    ' AND '::text AS inner_operator\nUNION\n SELECT ' MON/BETWEEN '::text AS operator,\n    NULL::text AS input_type,\n    NULL::text AS output_type,\n    ' AND '::text AS inner_operator\nUNION\n SELECT ' D/BETWEEN '::text AS operator,\n    NULL::text AS input_type,\n    NULL::text AS output_type,\n    ' AND '::text AS inner_operator\nUNION\n SELECT ' H/BETWEEN '::text AS operator,\n    NULL::text AS input_type,\n    NULL::text AS output_type,\n    ' AND '::text AS inner_operator\nUNION\n SELECT ' MIN/BETWEEN '::text AS operator,\n    NULL::text AS input_type,\n    NULL::text AS output_type,\n    ' AND '::text AS inner_operator\nUNION\n SELECT ' S/BETWEEN '::text AS operator,\n    NULL::text AS input_type,\n    NULL::text AS output_type,\n    ' AND '::text AS inner_operator\nUNION\n SELECT ' DOW/BETWEEN '::text AS operator,\n    NULL::text AS input_type,\n    NULL::text AS output_type,\n    ' AND '::text AS inner_operator\nUNION\n SELECT ' DOY/BETWEEN '::text AS operator,\n    NULL::text AS input_type,\n    NULL::text AS output_type,\n    ' AND '::text AS inner_operator\nUNION\n SELECT ' Q/BETWEEN '::text AS operator,\n    NULL::text AS input_type,\n    NULL::text AS output_type,\n    ' AND '::text AS inner_operator\nUNION\n SELECT ' W/BETWEEN '::text AS operator,\n    NULL::text AS input_type,\n    NULL::text AS output_type,\n    ' AND '::text AS inner_operator;\nDROP view IF EXISTS reclada.v_class ;\nCREATE OR REPLACE VIEW reclada.v_class\nAS\n SELECT obj.id,\n    obj.obj_id,\n    obj.attrs ->> 'forClass'::text AS for_class,\n    (obj.attrs ->> 'version'::text)::bigint AS version,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data,\n    obj.parent_guid\n   FROM v_active_object obj\n  WHERE obj.class_name = 'jsonschema'::text;\nDROP view IF EXISTS reclada.v_pk_for_class ;\nCREATE OR REPLACE VIEW reclada.v_pk_for_class\nAS\n SELECT obj.obj_id AS guid,\n    obj.for_class,\n    pk.pk\n   FROM v_class_lite obj\n     JOIN ( SELECT 'File'::text AS class_name,\n            'uri'::text AS pk\n        UNION\n         SELECT 'DTOJsonSchema'::text AS text,\n            'function'::text AS text) pk ON pk.class_name = obj.for_class;\nDROP view IF EXISTS reclada.v_dto_json_schema ;\nCREATE OR REPLACE VIEW reclada.v_dto_json_schema\nAS\n SELECT obj.id,\n    obj.obj_id,\n    obj.attrs ->> 'function'::text AS function,\n    obj.attrs -> 'schema'::text AS schema,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data,\n    obj.parent_guid\n   FROM v_active_object obj\n  WHERE obj.class_name = 'DTOJsonSchema'::text;\nDROP view IF EXISTS reclada.v_import_info ;\nCREATE OR REPLACE VIEW reclada.v_import_info\nAS\n SELECT obj.id,\n    obj.obj_id AS guid,\n    (obj.attrs ->> 'tranID'::text)::bigint AS tran_id,\n    obj.attrs ->> 'name'::text AS name,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class_name = 'ImportInfo'::text;\nDROP view IF EXISTS reclada.v_revision ;\nCREATE OR REPLACE VIEW reclada.v_revision\nAS\n SELECT obj.id,\n    obj.obj_id,\n    (obj.attrs ->> 'num'::text)::bigint AS num,\n    obj.attrs ->> 'branch'::text AS branch,\n    obj.attrs ->> 'user'::text AS "user",\n    obj.attrs ->> 'dateTime'::text AS date_time,\n    obj.attrs ->> 'old_num'::text AS old_num,\n    obj.revision_num,\n    obj.status_caption,\n    obj.revision,\n    obj.created_time,\n    obj.attrs,\n    obj.status,\n    obj.data\n   FROM v_active_object obj\n  WHERE obj.class_name = 'revision'::text;\nDROP view IF EXISTS reclada.v_ui_active_object ;\nCREATE OR REPLACE VIEW reclada.v_ui_active_object\nAS\n WITH RECURSIVE d AS (\n         SELECT obj.data,\n            obj.obj_id\n           FROM v_active_object obj\n        ), t AS (\n         SELECT je.key,\n            jsonb_typeof(je.value) AS typ,\n            d.obj_id,\n            je.value\n           FROM d\n             JOIN LATERAL jsonb_each(d.data) je(key, value) ON true\n          WHERE jsonb_typeof(je.value) <> 'null'::text\n        UNION\n         SELECT (d.key || ','::text) || je.key AS key,\n            jsonb_typeof(je.value) AS typ,\n            d.obj_id,\n            je.value\n           FROM ( SELECT d_1.data -> t_1.key AS data,\n                    t_1.key,\n                    d_1.obj_id\n                   FROM d d_1\n                     JOIN t t_1 ON t_1.typ = 'object'::text) d\n             JOIN LATERAL jsonb_each(d.data) je(key, value) ON true\n          WHERE jsonb_typeof(je.value) <> 'null'::text\n        ), res AS (\n         SELECT t_1.obj_id,\n            jsonb_object_agg((('{'::text || t_1.key) || '}:'::text) || t_1.typ, t_1.value) AS data\n           FROM t t_1\n          WHERE t_1.typ <> 'object'::text\n          GROUP BY t_1.obj_id\n        )\n SELECT res.obj_id,\n    res.data,\n    t.id,\n    t.class,\n    t.revision_num,\n    t.status,\n    t.status_caption,\n    t.revision,\n    t.created_time,\n    t.class_name,\n    t.attrs,\n    t.transaction_id,\n    t.parent_guid\n   FROM res\n     JOIN v_active_object t ON t.obj_id = res.obj_id;\n\nDROP view IF EXISTS reclada.v_ui_active_object ;\nCREATE OR REPLACE VIEW reclada.v_ui_active_object\nAS\n WITH RECURSIVE d AS (\n         SELECT obj.data,\n            obj.obj_id\n           FROM v_active_object obj\n        ), t AS (\n         SELECT je.key,\n            jsonb_typeof(je.value) AS typ,\n            d.obj_id,\n            je.value\n           FROM d\n             JOIN LATERAL jsonb_each(d.data) je(key, value) ON true\n          WHERE jsonb_typeof(je.value) <> 'null'::text\n        UNION\n         SELECT (d.key || ','::text) || je.key AS key,\n            jsonb_typeof(je.value) AS typ,\n            d.obj_id,\n            je.value\n           FROM ( SELECT d_1.data -> t_1.key AS data,\n                    t_1.key,\n                    d_1.obj_id\n                   FROM d d_1\n                     JOIN t t_1 ON t_1.typ = 'object'::text) d\n             JOIN LATERAL jsonb_each(d.data) je(key, value) ON true\n          WHERE jsonb_typeof(je.value) <> 'null'::text\n        ), res AS (\n         SELECT t_1.obj_id,\n            jsonb_object_agg((('{'::text || t_1.key) || '}:'::text) || t_1.typ, t_1.value) AS data\n           FROM t t_1\n          WHERE t_1.typ <> 'object'::text\n          GROUP BY t_1.obj_id\n        )\n SELECT res.obj_id,\n    res.data,\n    t.id,\n    t.class,\n    t.revision_num,\n    t.status,\n    t.status_caption,\n    t.revision,\n    t.created_time,\n    t.class_name,\n    t.attrs,\n    t.transaction_id,\n    t.parent_guid\n   FROM res\n     JOIN v_active_object t ON t.obj_id = res.obj_id;\nDROP view IF EXISTS reclada.v_default_display ;\nCREATE OR REPLACE VIEW reclada.v_default_display\nAS\n SELECT 'string'::text AS json_type,\n    '{"caption": "#@#attrname#@#","width": 250,"displayCSS": "#@#attrname#@#"}'::text AS template\nUNION\n SELECT 'number'::text AS json_type,\n    '{"caption": "#@#attrname#@#","width": 250,"displayCSS": "#@#attrname#@#"}'::text AS template\nUNION\n SELECT 'boolean'::text AS json_type,\n    '{"caption": "#@#attrname#@#","width": 250,"displayCSS": "#@#attrname#@#"}'::text AS template;\n\nDROP TYPE reclada.dp_bhvr;\n\nDROP INDEX reclada.uri_index_;\nDROP INDEX reclada.checksum_index_;\n\nCREATE INDEX status_index ON reclada.object USING btree (status);\n\nDELETE FROM reclada.draft\nWHERE parent_guid IS NOT NULL;\n\nALTER TABLE reclada.draft DROP COLUMN IF EXISTS parent_guid;\nALTER TABLE reclada.draft ALTER COLUMN guid DROP NOT NULL;\n\nselect reclada.raise_exception('can''t find 2 DTOJsonSchema for reclada_object.list', 'up_script.sql')\n    where \n        (\n            select count(*)\n                from reclada.object\n                    where attributes->>'function' = 'reclada_object.list'\n                        and class in (select reclada_object.get_guid_for_class('DTOJsonSchema'))\n        ) != 2;\n--{ display\nwith t as\n( \n    update reclada.object\n        set status = reclada_object.get_active_status_obj_id()\n        where attributes->>'function' = 'reclada_object.list'\n            and class in (select reclada_object.get_guid_for_class('DTOJsonSchema'))\n            and status = reclada_object.get_archive_status_obj_id()\n        returning id\n)\n    update reclada.object\n        set status = reclada_object.get_archive_status_obj_id()\n        where attributes->>'function' = 'reclada_object.list'\n            and class in (select reclada_object.get_guid_for_class('DTOJsonSchema'))\n            and id not in (select id from t);\n\nDROP function IF EXISTS reclada.jsonb_deep_set ;\n\n--} display	2021-12-30 05:48:13.490606+00
\.


--
-- Data for Name: auth_setting; Type: TABLE DATA; Schema: reclada; Owner: -
--

COPY reclada.auth_setting (oidc_url, oidc_client_id, oidc_redirect_url, jwk) FROM stdin;
\.


--
-- Data for Name: draft; Type: TABLE DATA; Schema: reclada; Owner: -
--

COPY reclada.draft (id, guid, user_guid, data, parent_guid) FROM stdin;
\.


--
-- Data for Name: object; Type: TABLE DATA; Schema: reclada; Owner: -
--

COPY reclada.object (id, status, attributes, transaction_id, created_time, created_by, class, guid, parent_guid) FROM stdin;
22	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"caption": "active", "revision": "090c2cee-db0f-4637-9524-fb15e9c7362b"}	9	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	14af3113-18b5-4da8-af57-bdf37a6693aa	3748b1f7-b674-47ca-9ded-d011b16bbf7b	\N
34	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["top", "left", "height", "width"], "properties": {"top": {"type": "number"}, "left": {"type": "number"}, "tags": {"type": "array", "items": {"type": "string"}}, "width": {"type": "number"}, "height": {"type": "number"}}}, "version": "1", "forClass": "BBox"}	3	2021-09-22 14:52:57.133151+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	c835c5b4-3b4f-49d7-b9b2-05a911234682	\N
29	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["dateTime"], "properties": {"num": {"type": "number"}, "tags": {"type": "array", "items": {"type": "string"}}, "user": {"type": "string"}, "branch": {"type": "string"}, "dateTime": {"type": "string"}}}, "version": 1, "forClass": "revision"}	4	2021-09-22 14:51:54.773219+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	0f317fbd-8861-4d68-82ce-de7241d7db0f	\N
35	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["text", "bbox", "page"], "properties": {"bbox": {"type": "string"}, "page": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "text": {"type": "string"}}}, "version": "1", "forClass": "TextBlock"}	5	2021-09-22 14:52:57.258646+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	9ed31858-a681-49fb-9e64-250b1afaf691	\N
18	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"name": "defaultDataSet", "revision": "a04d127e-5ea0-4683-8eff-2ea8d1ba5f24", "dataSources": []}	10	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	be193cf5-3156-4df4-8c9b-58b09524ce2f	10c400ff-a328-450d-ae07-ce7d427d961c	\N
20	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["caption"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "caption": {"type": "string"}}}, "version": 1, "forClass": "ObjectStatus", "revision": "0b3c19cb-85f6-4481-bd91-30d004197cac"}	11	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	14af3113-18b5-4da8-af57-bdf37a6693aa	\N
8	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["name"], "properties": {"uri": {"type": "string"}, "name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}}}, "version": 1, "forClass": "DataSource", "revision": "559af2a2-371c-432f-92a7-e567da60565d"}	13	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	92a95f66-e28e-4ebc-9f33-3568fc5a281e	\N
6	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["name"], "properties": {"name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}}}, "version": 1, "forClass": "tag", "revision": "195b2a06-4b6e-4e7c-a610-58fc09f646c8"}	14	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	e12e729b-ac44-45bc-8271-9f0c6d4fa27b	\N
12	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["accessKeyId", "secretAccessKey", "bucketName"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "bucketName": {"type": "string"}, "regionName": {"type": "string"}, "accessKeyId": {"type": "string"}, "endpointURL": {"type": "string"}, "secretAccessKey": {"type": "string"}}}, "version": 1, "forClass": "S3Config", "revision": "fcb96cad-9879-4668-8da0-cd705175dc90"}	15	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	67f37293-2dd6-469c-bc2d-923533991f77	\N
39	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["command", "type"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "type": {"type": "string"}, "command": {"type": "string"}, "inputParameters": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "outputParameters": {"type": "array", "items": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}}}}, "version": "1", "forClass": "Task"}	16	2021-09-22 14:53:02.985704+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	ba7211ce-92e5-4cbb-aa1b-a3259a9a4f54	\N
40	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"attrs": ["status", "type"], "class": "Task", "event": "create", "channelName": "task_created"}	17	2021-09-22 14:53:03.155494+00	16d789c1-1b4e-4815-b70c-4ef060e90884	54f657db-bc6a-4a37-8fb6-8566aee49b33	4e79a0e3-6cf6-42b0-bc0e-f4222530d316	\N
41	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"attrs": ["status", "type"], "class": "Task", "event": "update", "channelName": "task_updated"}	18	2021-09-22 14:53:03.155494+00	16d789c1-1b4e-4815-b70c-4ef060e90884	54f657db-bc6a-4a37-8fb6-8566aee49b33	8a4f92ef-0e48-4387-9e93-688525ba8697	\N
42	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"attrs": ["type"], "class": "Task", "event": "delete", "channelName": "task_deleted"}	19	2021-09-22 14:53:03.155494+00	16d789c1-1b4e-4815-b70c-4ef060e90884	54f657db-bc6a-4a37-8fb6-8566aee49b33	5f1b0908-8ea2-44f8-a380-7d9aee07ea99	\N
43	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["name", "type"], "properties": {"file": {"type": "string"}, "name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "type": {"enum": ["code", "stdout", "stderr", "file"], "type": "string"}}}, "version": "1", "forClass": "Parameter"}	20	2021-09-22 14:53:03.359018+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	07533caf-3a5f-47ba-998c-494b69a9cc29	\N
13	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 7, "dateTime": "2021-09-22 14:50:30.246626+00"}	38	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	23a3251b-6269-456f-a5b7-09ce1b0df3e3	\N
44	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["nextTask", "previousJobCode"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "nextTask": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "previousJobCode": {"type": "integer"}, "paramsRelationships": {"type": "array", "items": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}}}}, "version": "1", "forClass": "Trigger"}	21	2021-09-22 14:53:03.507583+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	a000a736-f147-4527-8849-e36efea8061e	\N
45	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["command", "triggers", "type"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "type": {"type": "string"}, "command": {"type": "string"}, "triggers": {"type": "array", "items": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}}, "inputParameters": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "outputParameters": {"type": "array", "items": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}}}}, "version": "1", "forClass": "Pipeline"}	22	2021-09-22 14:53:03.657134+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	dc9eaa02-dd42-4336-bcd6-4eefe147efea	\N
46	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["command", "status", "type", "task"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "task": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "type": {"type": "string"}, "runner": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "status": {"type": "string", "enum ": ["new", "pending", "running", "failed", "success"]}, "command": {"type": "string"}, "inputParameters": {"type": "array", "items": {"type": "object"}}, "outputParameters": {"type": "array", "items": {"type": "object"}}}}, "version": "1", "forClass": "Job"}	23	2021-09-22 14:53:03.806643+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	75a8fd8b-f709-445c-a551-e8454c0ef179	\N
47	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"attrs": ["status", "type"], "class": "Job", "event": "create", "channelName": "job_created"}	24	2021-09-22 14:53:03.95338+00	16d789c1-1b4e-4815-b70c-4ef060e90884	54f657db-bc6a-4a37-8fb6-8566aee49b33	45f586df-e867-4024-a92c-81d26ada1a16	\N
48	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"attrs": ["status", "type"], "class": "Job", "event": "update", "channelName": "job_updated"}	25	2021-09-22 14:53:03.95338+00	16d789c1-1b4e-4815-b70c-4ef060e90884	54f657db-bc6a-4a37-8fb6-8566aee49b33	cca09dc6-2eb4-4d41-99c6-063d8763f789	\N
49	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"attrs": ["type"], "class": "Job", "event": "delete", "channelName": "job_deleted"}	26	2021-09-22 14:53:03.95338+00	16d789c1-1b4e-4815-b70c-4ef060e90884	54f657db-bc6a-4a37-8fb6-8566aee49b33	b58aa7bb-c002-4c55-85a3-8ba8b167c92b	\N
51	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["name"], "properties": {"name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "value": {"type": "string"}}}, "version": "1", "forClass": "Value"}	28	2021-09-22 14:53:04.310403+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	9ac7a8c3-8d7c-4443-b5fd-c1a8f31ee13e	\N
53	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["name"], "properties": {"name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "description": {"type": "string"}}}, "version": "1", "forClass": "Environment"}	30	2021-09-22 14:53:04.621778+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	7983c3aa-75f5-4d91-a0af-519a122893f6	\N
4	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": [], "properties": {"tags": {"type": "array", "items": {"type": "string"}}}}, "version": 1, "forClass": "RecladaObject", "revision": "6035277c-e142-4a27-ae34-4800cee8c89c"}	31	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	ab9ab26c-8902-43dd-9f1a-743b14a89825	\N
2	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["forClass", "schema"], "properties": {"schema": {"type": "object"}, "forClass": {"type": "string"}}}, "version": 1, "forClass": "jsonschema", "revision": "aacd64a4-7585-456f-8546-37da218b5481"}	32	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	5362d59b-82a1-4c7c-8ec3-07c256009fb0	\N
16	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["channelName", "event", "class"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "attrs": {"type": "array", "items": {"type": "string"}}, "class": {"type": "string"}, "event": {"enum": ["create", "update", "list", "delete"], "type": "string"}, "channelName": {"type": "string"}}}, "version": 1, "forClass": "Message", "revision": "cc1ced42-1354-49ea-ba65-5a6562547618"}	33	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	54f657db-bc6a-4a37-8fb6-8566aee49b33	\N
54	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["extension", "mimeType"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "mimeType": {"type": "string"}, "extension": {"type": "string"}}}, "version": "1", "forClass": "FileExtension"}	34	2021-09-22 14:53:04.773268+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	e291db3a-4942-441f-a320-079c9eb5e3bb	\N
55	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"mimeType": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "extension": ".xlsx"}	35	2021-09-22 14:53:04.924895+00	16d789c1-1b4e-4815-b70c-4ef060e90884	e291db3a-4942-441f-a320-079c9eb5e3bb	8831f967-a71b-4721-ab78-caefab138d37	\N
56	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["command", "name", "type", "environment"], "properties": {"name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "type": {"type": "string"}, "command": {"type": "string"}, "environment": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "inputParameters": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "outputParameters": {"type": "array", "items": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}}, "connectionDetails": {"type": "string"}}}, "version": "1", "forClass": "Connector"}	36	2021-09-22 14:53:05.114361+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	6e474d14-04bb-4a82-87db-1c495664172f	\N
31	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["Environment"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "Lambda": {"type": "string"}, "Environment": {"type": "string"}}}, "version": "1", "forClass": "Context"}	37	2021-09-22 14:52:29.56296+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	ea01e538-fa4d-49de-ad05-dad73a5dbaca	\N
11	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 6, "dateTime": "2021-09-22 14:50:30.154503+00"}	39	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	fcb96cad-9879-4668-8da0-cd705175dc90	\N
9	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 5, "dateTime": "2021-09-22 14:50:30.063341+00"}	40	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	49a01e01-8663-437e-b261-d77800518497	\N
7	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 4, "dateTime": "2021-09-22 14:50:29.958841+00"}	41	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	559af2a2-371c-432f-92a7-e567da60565d	\N
5	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 3, "dateTime": "2021-09-22 14:50:29.866858+00"}	42	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	195b2a06-4b6e-4e7c-a610-58fc09f646c8	\N
3	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 2, "dateTime": "2021-09-22 14:50:29.712093+00"}	43	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	6035277c-e142-4a27-ae34-4800cee8c89c	\N
1	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 1, "dateTime": "2021-09-22 14:50:29.624416+00"}	44	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	aacd64a4-7585-456f-8546-37da218b5481	\N
21	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 11, "dateTime": "2021-09-22 14:50:50.411942+00"}	45	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	090c2cee-db0f-4637-9524-fb15e9c7362b	\N
25	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 13, "dateTime": "2021-09-22 14:50:50.411942+00"}	46	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	de7cfae5-c8c3-4ecc-b147-1427eb792f82	\N
23	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 12, "dateTime": "2021-09-22 14:50:50.411942+00"}	47	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	b77c3f09-59eb-4aa0-bc83-208d32d9855d	\N
19	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 10, "dateTime": "2021-09-22 14:50:50.411942+00"}	48	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	0b3c19cb-85f6-4481-bd91-30d004197cac	\N
17	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 9, "dateTime": "2021-09-22 14:50:30.427941+00"}	49	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	a04d127e-5ea0-4683-8eff-2ea8d1ba5f24	\N
15	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 8, "dateTime": "2021-09-22 14:50:30.338803+00"}	50	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	cc1ced42-1354-49ea-ba65-5a6562547618	\N
27	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 1, "user": "", "branch": "", "old_num": 14, "dateTime": "2021-09-22 14:50:50.411942+00"}	51	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	92d414ce-56aa-4c4a-87f1-5027b0156ba9	\N
28	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"login": "dev", "revision": "92d414ce-56aa-4c4a-87f1-5027b0156ba9"}	52	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	77f7d007-960f-4236-84fa-feadf3267bcf	16d789c1-1b4e-4815-b70c-4ef060e90884	\N
24	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"caption": "archive", "revision": "b77c3f09-59eb-4aa0-bc83-208d32d9855d"}	53	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	14af3113-18b5-4da8-af57-bdf37a6693aa	9dc0a032-90d6-4638-956e-9cd64cd2900c	\N
26	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["login"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "login": {"type": "string"}}}, "version": 1, "forClass": "User", "revision": "de7cfae5-c8c3-4ecc-b147-1427eb792f82"}	54	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	77f7d007-960f-4236-84fa-feadf3267bcf	\N
14	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["name"], "properties": {"name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "dataSources": {"type": "array", "items": {"type": "string"}}}}, "version": 1, "forClass": "DataSet", "revision": "23a3251b-6269-456f-a5b7-09ce1b0df3e3"}	55	2021-09-22 14:50:50.411942+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	be193cf5-3156-4df4-8c9b-58b09524ce2f	\N
57	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["tranID", "name"], "properties": {"name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "tranID": {"type": "number"}}}, "version": "1", "forClass": "ImportInfo"}	56	2021-09-24 09:46:22.790044+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	6f5245bd-1eec-4be0-8a28-681758155e33	\N
52	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["command", "status", "type", "task", "environment"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "task": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "type": {"type": "string"}, "runner": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "status": {"type": "string", "enum ": ["up", "down", "idle"]}, "command": {"type": "string"}, "environment": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "inputParameters": {"type": "array", "items": {"type": "object"}}, "outputParameters": {"type": "array", "items": {"type": "object"}}, "platformRunnerID": {"type": "string"}}}, "version": "1", "forClass": "Runner"}	29	2021-09-22 14:53:04.461972+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	b6e879da-731f-48c3-99b5-e48d73a74930	\N
60	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["schema", "function"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "schema": {"type": "object"}, "function": {"type": "string"}}}, "version": "1", "forClass": "DTOJsonSchema"}	59	2021-11-08 11:01:49.274513+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	d90dd69c-fc00-4573-b747-c04f39c20b25	ab9ab26c-8902-43dd-9f1a-743b14a89825
61	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"id": "expr", "type": "object", "required": ["value", "operator"], "properties": {"value": {"type": "array", "items": {"anyOf": [{"type": "string"}, {"type": "null"}, {"type": "number"}, {"$ref": "expr"}, {"type": "array", "items": {"anyOf": [{"type": "string"}, {"type": "number"}]}}]}, "minItems": 1}, "operator": {"type": "string"}}}, "function": "reclada_object.get_query_condition_filter"}	60	2021-11-08 11:01:49.274513+00	16d789c1-1b4e-4815-b70c-4ef060e90884	d90dd69c-fc00-4573-b747-c04f39c20b25	4ecbf6f5-7eea-4dbd-9f46-e0535f7fb299	\N
58	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["name"], "properties": {"name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "fileGUID": {"type": "string"}}}, "version": "1", "forClass": "Document", "parentField": "fileGUID"}	57	2021-10-04 08:06:30.979167+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	85d32073-4a00-4df7-9def-7de8d90b77e0	\N
63	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["tasks", "command", "type"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "type": {"type": "string"}, "tasks": {"type": "array", "items": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "minItems": 1}, "command": {"type": "string"}, "inputParameters": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "outputParameters": {"type": "array", "items": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}}}}, "version": "1", "forClass": "PipelineLite"}	62	2021-12-21 13:28:11.224553+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	5d3c213f-d915-456e-a10c-22d391e994d1	ba7211ce-92e5-4cbb-aa1b-a3259a9a4f54
64	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"type": "pipelineLite", "tasks": ["cc7b41e6-4d57-4e6f-9d10-6da0d5a4c39e", "618b967b-f2ff-4f3b-8889-b63eb6b73b6e", "678bbbcc-a6db-425b-b9cd-bdb302c8d290", "638c7f45-ad21-4b59-a89d-5853aa9ad859", "2d6b0afc-fdf0-4b54-8a67-704da585196e", "ff3d88e2-1dd9-43b3-873f-75e4dc3c0629", "83fbb176-adb7-4da0-bd1f-4ce4aba1b87a", "27de6e85-1749-4946-8a53-4316321fc1e8", "4478768c-0d01-4ad9-9a10-2bef4d4b8007"], "command": ""}	63	2021-12-21 13:28:11.224553+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5d3c213f-d915-456e-a10c-22d391e994d1	57ca1d46-146b-4bbb-8f4d-b620c4e62d93	\N
65	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"type": "PipelineLite stage 0", "command": "./pipeline/create_pipeline.sh"}	64	2021-12-21 13:28:11.224553+00	16d789c1-1b4e-4815-b70c-4ef060e90884	ba7211ce-92e5-4cbb-aa1b-a3259a9a4f54	cc7b41e6-4d57-4e6f-9d10-6da0d5a4c39e	\N
66	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"type": "PipelineLite stage 1", "command": "./pipeline/copy_file_from_s3.sh"}	65	2021-12-21 13:28:11.224553+00	16d789c1-1b4e-4815-b70c-4ef060e90884	ba7211ce-92e5-4cbb-aa1b-a3259a9a4f54	618b967b-f2ff-4f3b-8889-b63eb6b73b6e	\N
67	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"type": "PipelineLite stage 2", "command": "./pipeline/badgerdoc_run.sh"}	66	2021-12-21 13:28:11.224553+00	16d789c1-1b4e-4815-b70c-4ef060e90884	ba7211ce-92e5-4cbb-aa1b-a3259a9a4f54	678bbbcc-a6db-425b-b9cd-bdb302c8d290	\N
68	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"type": "PipelineLite stage 3", "command": "./pipeline/bd2reclada_run.sh"}	67	2021-12-21 13:28:11.224553+00	16d789c1-1b4e-4815-b70c-4ef060e90884	ba7211ce-92e5-4cbb-aa1b-a3259a9a4f54	638c7f45-ad21-4b59-a89d-5853aa9ad859	\N
69	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"type": "PipelineLite stage 4", "command": "./pipeline/loading_data_to_db.sh"}	68	2021-12-21 13:28:11.224553+00	16d789c1-1b4e-4815-b70c-4ef060e90884	ba7211ce-92e5-4cbb-aa1b-a3259a9a4f54	2d6b0afc-fdf0-4b54-8a67-704da585196e	\N
70	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"type": "PipelineLite stage 5", "command": "./pipeline/scinlp_run.sh"}	69	2021-12-21 13:28:11.224553+00	16d789c1-1b4e-4815-b70c-4ef060e90884	ba7211ce-92e5-4cbb-aa1b-a3259a9a4f54	ff3d88e2-1dd9-43b3-873f-75e4dc3c0629	\N
71	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"type": "PipelineLite stage 6", "command": "./pipeline/loading_results_to_db.sh"}	70	2021-12-21 13:28:11.224553+00	16d789c1-1b4e-4815-b70c-4ef060e90884	ba7211ce-92e5-4cbb-aa1b-a3259a9a4f54	83fbb176-adb7-4da0-bd1f-4ce4aba1b87a	\N
72	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"type": "PipelineLite stage 7", "command": "./pipeline/custom_task.sh"}	71	2021-12-21 13:28:11.224553+00	16d789c1-1b4e-4815-b70c-4ef060e90884	ba7211ce-92e5-4cbb-aa1b-a3259a9a4f54	27de6e85-1749-4946-8a53-4316321fc1e8	\N
73	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"type": "PipelineLite stage 8", "command": "./pipeline/coping_results.sh"}	72	2021-12-21 13:28:11.224553+00	16d789c1-1b4e-4815-b70c-4ef060e90884	ba7211ce-92e5-4cbb-aa1b-a3259a9a4f54	4478768c-0d01-4ad9-9a10-2bef4d4b8007	\N
74	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"$defs": {"displayType": {"type": "object", "required": ["orderColumn", "orderRow"], "properties": {"orderRow": {"type": "array", "items": {"type": "object", "patternProperties": {"^{.*}$": {"enum": ["ASC", "DESC"], "type": "string"}}}}, "orderColumn": {"type": "array", "items": {"type": "string"}}}}}, "required": ["classGUID", "caption"], "properties": {"card": {"$ref": "#/$defs/displayType"}, "flat": {"type": "bool"}, "list": {"$ref": "#/$defs/displayType"}, "table": {"$ref": "#/$defs/displayType"}, "caption": {"type": "string"}, "preview": {"$ref": "#/$defs/displayType"}, "classGUID": {"type": "string"}}}, "version": "1", "forClass": "ObjectDisplay"}	73	2021-12-23 09:40:36.185045+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	0ed53027-e432-4ef8-a669-b90dab42353a	\N
84	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": [{}, "name"], "properties": {"uri": {"type": "string"}, "name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}}}, "version": "1", "forClass": "Asset"}	83	2021-12-28 14:18:07.480088+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	83cc2a18-ee18-44b8-ab73-689dadb7c0d0	92a95f66-e28e-4ebc-9f33-3568fc5a281e
85	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": [{}, "name"], "properties": {"uri": {"type": "string"}, "name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}}}, "version": "1", "forClass": "DBAsset"}	84	2021-12-28 14:18:07.480088+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	c72ad73a-9e85-4277-9a3a-1d2d28d7a84f	83cc2a18-ee18-44b8-ab73-689dadb7c0d0
50	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["subject", "type", "object"], "properties": {"tags": {"type": "array", "items": {"type": "string"}}, "type": {"type": "string", "enum ": ["params"]}, "object": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}, "subject": {"type": "string", "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"}}}, "version": "1", "forClass": "Relationship"}	27	2021-09-22 14:53:04.158111+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	2d054574-8f7a-4a9a-a3b3-0400ad9d0489	\N
86	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"card": {"orderRow": [{"{attributes,name}:string": "ASC"}, {"{attributes,mimeType}:string": "DESC"}], "orderColumn": ["{attributes,name}:string", "{attributes,mimeType}:string", "{attributes,tags}:array", "{status}:string", "{createdTime}:string", "{transactionID}:number"]}, "list": {"orderRow": [{"{attributes,name}:string": "ASC"}, {"{attributes,mimeType}:string": "DESC"}], "orderColumn": ["{attributes,name}:string", "{attributes,mimeType}:string", "{attributes,tags}:array", "{status}:string", "{createdTime}:string", "{transactionID}:number"]}, "table": {"orderRow": [{"{attributes,name}:string": "ASC"}, {"{attributes,mimeType}:string": "DESC"}], "orderColumn": ["{attributes,name}:string", "{attributes,mimeType}:string", "{attributes,tags}:array", "{status}:string", "{createdTime}:string", "{transactionID}:number"], "{GUID}:string": {"width": 250, "caption": "GUID", "displayCSS": "GUID"}, "{status}:string": {"width": 250, "caption": "Status", "displayCSS": "status"}, "{createdTime}:string": {"width": 250, "caption": "Created time", "displayCSS": "createdTime"}, "{transactionID}:number": {"width": 250, "caption": "Transaction", "displayCSS": "transactionID"}, "{attributes,tags}:array": {"items": {"class": "e12e729b-ac44-45bc-8271-9f0c6d4fa27b", "behavior": "preview", "displayCSS": "link"}, "width": 250, "caption": "Tags", "displayCSS": "arrayLink"}, "{attributes,name}:string": {"width": 250, "caption": "File name", "behavior": "preview", "displayCSS": "name"}, "{attributes,checksum}:string": {"width": 250, "caption": "Checksum", "displayCSS": "checksum"}, "{attributes,mimeType}:string": {"width": 250, "caption": "Mime type", "displayCSS": "mimeType"}}, "caption": "Files", "preview": {"orderRow": [{"{attributes,name}:string": "ASC"}, {"{attributes,mimeType}:string": "DESC"}], "orderColumn": ["{attributes,name}:string", "{attributes,mimeType}:string", "{attributes,tags}:array", "{status}:string", "{createdTime}:string", "{transactionID}:number"]}, "classGUID": "c7fc0455-0572-40d7-987f-583cc2c9630c"}	85	2021-12-28 14:18:07.480088+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0ed53027-e432-4ef8-a669-b90dab42353a	fb19dd42-f2a2-4e34-90ea-a6e5f5ea6dff	\N
87	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"num": 2, "user": "", "branch": "", "dateTime": "2021-12-28 14:18:07.480088+00"}	86	2021-12-28 14:18:07.480088+00	16d789c1-1b4e-4815-b70c-4ef060e90884	0f317fbd-8861-4d68-82ce-de7241d7db0f	1da6ba10-b175-4e1d-8cdd-668d52387c08	\N
37	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["colspan", "row", "text", "bbox", "table", "cellType", "rowspan", "column"], "properties": {"row": {"type": "number"}, "bbox": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "text": {"type": "string"}, "table": {"type": "string"}, "column": {"type": "number"}, "colspan": {"type": "number"}, "rowspan": {"type": "number"}, "cellType": {"type": "string"}}}, "version": "1", "forClass": "Cell", "parentField": "table"}	7	2021-09-22 14:52:57.502377+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	7f56ece0-e780-4496-8573-1ad4d800a3b6	\N
36	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["bbox", "page"], "properties": {"bbox": {"type": "string"}, "page": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}}}, "version": "1", "forClass": "Table", "parentField": "page"}	6	2021-09-22 14:52:57.379526+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	f5bcc7ad-1a9b-476d-985e-54cf01377530	\N
33	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["number", "bbox", "document"], "properties": {"bbox": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "number": {"type": "number"}, "document": {"type": "string"}}}, "version": "1", "forClass": "Page", "parentField": "document"}	2	2021-09-22 14:52:57.011935+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	3ed1c180-a508-4180-9281-2f9b9a9cd477	\N
38	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["row", "table"], "properties": {"row": {"type": "number"}, "tags": {"type": "array", "items": {"type": "string"}}, "table": {"type": "string"}}}, "version": "1", "forClass": "DataRow", "parentField": "table"}	8	2021-09-22 14:52:58.301966+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	7643b601-43c2-4125-831a-539b9e7418ec	\N
59	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "required": ["checksum", "name", "mimeType"], "properties": {"uri": {"type": "string"}, "name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "checksum": {"type": "string"}, "mimeType": {"type": "string"}}}, "version": "1", "forClass": "File", "isCascade": true, "dupBehavior": "Replace", "dupChecking": [{"uniFields": ["uri"], "isMandatory": true}, {"uniFields": ["checksum"], "isMandatory": true}]}	58	2021-10-04 08:06:30.979167+00	16d789c1-1b4e-4815-b70c-4ef060e90884	5362d59b-82a1-4c7c-8ec3-07c256009fb0	c7fc0455-0572-40d7-987f-583cc2c9630c	\N
62	3748b1f7-b674-47ca-9ded-d011b16bbf7b	{"schema": {"type": "object", "anyOf": [{"required": ["transactionID"]}, {"required": ["class"]}, {"required": ["filter"]}], "properties": {"class": {"type": "string"}, "limit": {"anyOf": [{"enum": ["ALL"], "type": "string"}, {"type": "integer"}]}, "filter": {"type": "object"}, "offset": {"type": "integer"}, "orderBy": {"type": "array", "items": {"type": "object", "required": ["field"], "properties": {"field": {"type": "string"}, "order": {"enum": ["ASC", "DESC"], "type": "string"}}}}, "transactionID": {"type": "integer"}}}, "function": "reclada_object.list"}	61	2021-11-08 11:01:49.274513+00	16d789c1-1b4e-4815-b70c-4ef060e90884	d90dd69c-fc00-4573-b747-c04f39c20b25	d87ad26e-a522-4907-a41a-a82a916fdcf9	\N
88	9dc0a032-90d6-4638-956e-9cd64cd2900c	{"schema": {"type": "object", "anyOf": [{"required": ["transactionID", "class"]}, {"required": ["class"]}, {"required": ["filter", "class"]}], "properties": {"class": {"type": "string"}, "limit": {"anyOf": [{"enum": ["ALL"], "type": "string"}, {"type": "integer"}]}, "filter": {"type": "object"}, "offset": {"type": "integer"}, "orderBy": {"type": "array", "items": {"type": "object", "required": ["field"], "properties": {"field": {"type": "string"}, "order": {"enum": ["ASC", "DESC"], "type": "string"}}}}, "transactionID": {"type": "integer"}}}, "function": "reclada_object.list", "revision": "1da6ba10-b175-4e1d-8cdd-668d52387c08"}	61	2021-12-28 14:18:07.480088+00	16d789c1-1b4e-4815-b70c-4ef060e90884	d90dd69c-fc00-4573-b747-c04f39c20b25	d87ad26e-a522-4907-a41a-a82a916fdcf9	\N
\.


--
-- Name: t_dbg_id_seq; Type: SEQUENCE SET; Schema: dev; Owner: -
--

SELECT pg_catalog.setval('dev.t_dbg_id_seq', 23, true);


--
-- Name: ver_id_seq; Type: SEQUENCE SET; Schema: dev; Owner: -
--

SELECT pg_catalog.setval('dev.ver_id_seq', 46, true);


--
-- Name: draft_id_seq; Type: SEQUENCE SET; Schema: reclada; Owner: -
--

SELECT pg_catalog.setval('reclada.draft_id_seq', 1, false);


--
-- Name: object_id_seq; Type: SEQUENCE SET; Schema: reclada; Owner: -
--

SELECT pg_catalog.setval('reclada.object_id_seq', 88, true);


--
-- Name: transaction_id; Type: SEQUENCE SET; Schema: reclada; Owner: -
--

SELECT pg_catalog.setval('reclada.transaction_id', 86, true);


--
-- Name: object object_pkey; Type: CONSTRAINT; Schema: reclada; Owner: -
--

ALTER TABLE ONLY reclada.object
    ADD CONSTRAINT object_pkey PRIMARY KEY (id);


--
-- Name: checksum_index_; Type: INDEX; Schema: reclada; Owner: -
--

CREATE INDEX checksum_index_ ON reclada.object USING hash (((attributes ->> 'checksum'::text)));


--
-- Name: class_index; Type: INDEX; Schema: reclada; Owner: -
--

CREATE INDEX class_index ON reclada.object USING btree (class);


--
-- Name: class_lite_class_idx; Type: INDEX; Schema: reclada; Owner: -
--

CREATE INDEX class_lite_class_idx ON reclada.v_class_lite USING btree (for_class);


--
-- Name: class_lite_obj_idx; Type: INDEX; Schema: reclada; Owner: -
--

CREATE INDEX class_lite_obj_idx ON reclada.v_class_lite USING btree (obj_id);


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
-- Name: parent_guid_index; Type: INDEX; Schema: reclada; Owner: -
--

CREATE INDEX parent_guid_index ON reclada.object USING btree (parent_guid);


--
-- Name: revision_index; Type: INDEX; Schema: reclada; Owner: -
--

CREATE INDEX revision_index ON reclada.object USING btree (((attributes ->> 'revision'::text)));


--
-- Name: runner_type_index; Type: INDEX; Schema: reclada; Owner: -
--

CREATE INDEX runner_type_index ON reclada.object USING btree (((attributes ->> 'type'::text)));


--
-- Name: transaction_id_index; Type: INDEX; Schema: reclada; Owner: -
--

CREATE INDEX transaction_id_index ON reclada.object USING btree (transaction_id);


--
-- Name: uri_index_; Type: INDEX; Schema: reclada; Owner: -
--

CREATE INDEX uri_index_ ON reclada.object USING hash (((attributes ->> 'uri'::text)));


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
-- Name: v_object_unifields; Type: MATERIALIZED VIEW DATA; Schema: reclada; Owner: -
--

REFRESH MATERIALIZED VIEW reclada.v_object_unifields;


--
-- Name: v_user; Type: MATERIALIZED VIEW DATA; Schema: reclada; Owner: -
--

REFRESH MATERIALIZED VIEW reclada.v_user;


--
-- PostgreSQL database dump complete
--

