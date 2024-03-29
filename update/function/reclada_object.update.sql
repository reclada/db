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
    _tran_id      bigint;
    _guid_list    text;
BEGIN

    SELECT  valid_schema, 
            attributes,
            class_name,
            class_guid 
        FROM reclada.validate_json_schema(_data)
        INTO    schema      , 
                _attrs      ,
                _class_name ,
                _class_uuid ;

    _obj_id := _data->>'GUID';
    IF (_obj_id IS NULL) THEN
        perform reclada.raise_exception('Could not update object with no GUID',_f_name);
    END IF;

    _tran_id = coalesce(    
                    (_data->>'transactionID')::bigint, 
                    (
                        select transaction_id 
                            from reclada.v_active_object 
                                where obj_id = _obj_id
                    )
                );

    -- don't allow update jsonschema
    if _class_name = 'jsonschema' then
        perform reclada.raise_exception('Can''t update jsonschema',_f_name);
    end if;

    SELECT 	v.data
        FROM reclada.v_object v
	        WHERE v.obj_id = _obj_id
                AND v.class_name = _class_name 
	    INTO old_obj;

    IF (old_obj IS NULL) THEN
        perform reclada.raise_exception('Could not update object, no such id');
    END IF;

    branch := _data->'branch';
    SELECT reclada_revision.create(user_info->>'sub', branch, _obj_id, _tran_id) 
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
                    _data := reclada_object.remove_parent_guid(_data, _parent_field);               
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
                _tran_id,
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

    --PERFORM reclada.update_unique_object(ARRAY[_obj_id]);

    PERFORM reclada_object.object_insert
            (
                _class_name,
                _obj_id,
                _attrs
            );
    PERFORM reclada_object.refresh_mv(_class_name);

    IF ( _class_name = 'jsonschema' AND jsonb_typeof(_attrs->'dupChecking') = 'array') THEN
        PERFORM reclada_object.refresh_mv('uniFields');
    END IF; 

    SELECT reclada.jsonb_merge(v.data, v.default_value) AS data
        FROM reclada.v_active_object v
            WHERE v.obj_id = _obj_id
        INTO _data;
    PERFORM reclada_notification.send_object_notification('update', _data);
    RETURN _data;
END;
$body$;
