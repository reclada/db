/*
 * Function reclada_object.update updates object with new revision.
 * A jsonb with the following parameters is required.
 * Required parameters:
 *  class - the class of object
 *  GUID - the identifier of the object
 *  attributes - the attributes of object
 * Optional parameters:
 *  branch - object's branch
 *
*/

DROP FUNCTION IF EXISTS reclada_object.update;
CREATE OR REPLACE FUNCTION reclada_object.update
(
    _data jsonb, 
    user_info jsonb default '{}'::jsonb
)
RETURNS jsonb
LANGUAGE PLPGSQL VOLATILE
AS $body$
DECLARE
    _class_name     text;
    _class_uuid     uuid;
    v_obj_id       uuid;
    v_attrs        jsonb;
    schema        jsonb;
    old_obj       jsonb;
    branch        uuid;
    revid         uuid;
    _parent_guid  uuid;
    _parent_field   text;
    _obj_GUID       uuid;
    _dupBehavior    dp_bhvr;
    _uniField       text;
    _cnt            int;
BEGIN

    _class_name := data->>'class';
    IF (_class_name IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;
    _class_uuid := reclada.try_cast_uuid(_class_name);
    v_obj_id := data->>'GUID';
    IF (v_obj_id IS NULL) THEN
        RAISE EXCEPTION 'Could not update object with no GUID';
    END IF;

    v_attrs := _data->'attributes';
    IF (v_attrs IS NULL) THEN
        RAISE EXCEPTION 'The reclada object must have attributes';
    END IF;

    if _class_uuid is null then
        SELECT reclada_object.get_schema(class_name) 
            INTO schema;
    else
        select v.data, v.for_class 
            from reclada.v_class v
                where _class_uuid = v.obj_id
            INTO schema;
    end if;
    -- TODO: don't allow update jsonschema
    IF (schema IS NULL) THEN
        RAISE EXCEPTION 'No json schema available for %', _class_name;
    END IF;

    IF (NOT(public.validate_json_schema(schema->'attributes'->'schema', v_attrs))) THEN
        RAISE EXCEPTION 'JSON invalid: %', v_attrs;
    END IF;

    SELECT 	v.data
        FROM reclada.v_object v
	        WHERE v.obj_id = v_obj_id
                AND v.class_name = _class_name 
	    INTO old_obj;

    IF (old_obj IS NULL) THEN
        RAISE EXCEPTION 'Could not update object, no such id';
    END IF;

    branch := _data->'branch';
    SELECT reclada_revision.create(user_info->>'sub', branch, v_obj_id) 
        INTO revid;

    SELECT parent_field
        FROM reclada.v_parent_field
        WHERE for_class = class_name
            INTO _parent_field;

    _parent_guid = (_data->>'parent_guid')::uuid;
    IF (_parent_guid IS NULL AND _parent_field IS NOT NULL) THEN
        _parent_guid = v_attrs->>_parent_field;
    END IF;

    IF (_parent_guid IS NULL) THEN
        _parent_guid := old_obj->>'parentGUID';
    END IF;

    IF (_class_uuid IS NULL) THEN
        _class_uuid := (SCHEMA->>'GUID')::uuid;
    END IF;
    
    IF EXISTS (SELECT 1 FROM reclada.v_unifields_idx_cnt WHERE class_uuid=_class_uuid)
    THEN
        SELECT COUNT(DISTINCT obj_guid), MAX(dup_behavior)
        FROM reclada.get_duplicates(v_attrs, _class_uuid, v_obj_id)
            INTO _cnt, _dupBehavior;
        IF (_cnt>1 AND _dupBehavior IN ('Update','Merge')) THEN
            RAISE EXCEPTION 'Found more than one duplicates. Resolve conflict manually.';
        END IF;
        FOR _obj_GUID, _dupBehavior, _uniField IN (
            SELECT obj_guid, dup_behavior, dup_field
            FROM reclada.get_duplicates(v_attrs, _class_uuid, v_obj_id)) LOOP
            IF _dupBehavior IN ('Update','Merge') THEN
                UPDATE reclada.object o
                    SET status = reclada_object.get_archive_status_obj_id()
                WHERE o.GUID = v_obj_id
                    AND status != reclada_object.get_archive_status_obj_id();
            END IF;
            CASE _dupBehavior
                WHEN 'Replace' THEN
                    PERFORM reclada_object.delete(format('{"GUID": "%s"}', _obj_GUID)::jsonb);
                WHEN 'Update' THEN                    
                    _data := reclada_object.remove_parent_guid(_data, _parent_field);
                    _data = reclada_object.update_json_by_guid(_obj_GUID, _data);
                    RETURN reclada_object.update(_data);
                WHEN 'Reject' THEN
                    RAISE EXCEPTION 'Duplicate found (GUID: %). Object rejected.', _obj_GUID;
                WHEN 'Copy'    THEN
                    v_attrs = v_attrs || format('{"%s": "%s_%s"}', _uniField, v_attrs->> _uniField, nextval('reclada.object_id_seq'))::jsonb;
                WHEN 'Insert' THEN
                    -- DO nothing
                WHEN 'Merge' THEN                    
                    RETURN reclada_object.update(reclada_object.merge(_data - 'class', vao.data, schema->'attributes'->'schema') || format('{"GUID": "%s"}', _obj_GUID)::jsonb)
                    FROM reclada.v_active_object vao
                    WHERE obj_id = _obj_GUID;
            END CASE;
        END LOOP;
    END IF;

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
                                transaction_id,
                                parent_guid
                              )
        select  v.obj_id,
                (schema->>'GUID')::uuid,
                reclada_object.get_active_status_obj_id(),--status 
                v_attrs || format('{"revision":"%s"}',revid)::jsonb,
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
                                where ro.guid = v_obj_id
                                    ORDER BY ID DESC 
                                        LIMIT 1
                    ) ta
                    ORDER BY q ASC 
                        LIMIT 1
            ) as tt
                on tt.id = v.id
	            WHERE v.obj_id = v_obj_id;
    PERFORM reclada_object.datasource_insert
            (
                _class_name,
                v_obj_id,
                v_attrs
            );
    PERFORM reclada_object.refresh_mv(class_name);

    IF ( _class_name = 'jsonschema' AND jsonb_typeof(v_attrs->'dupChecking') = 'array') THEN
        PERFORM reclada_object.refresh_mv('unifields');
    END IF; 
                  
    select v.data 
        FROM reclada.v_active_object v
            WHERE v.obj_id = v_obj_id
        into _data;
    PERFORM reclada_notification.send_object_notification('update', _data);
    RETURN _data;
END;
$body$;
