/*
 * Function reclada_object.create creates one or bunch of objects with specified fields.
 * A jsonb with user_info AND a jsonb or an array of jsonb objects are required.
 * A jsonb object with the following parameters is required to create one object.
 * An array of jsonb objects with the following parameters is required to create a bunch of objects.
 * Required parameters:
 *  class - the class of objects
 *  attributes - the attributes of objects
 * Optional parameters:
 *  GUID - the identifier of the object
 *  transactionID - object's transaction number. One transactionID is used to create a bunch of objects.
 *  branch - object's branch
 */

DROP FUNCTION IF EXISTS reclada_object.create;
CREATE OR REPLACE FUNCTION reclada_object.create
(
    data_jsonb jsonb, 
    user_info jsonb default '{}'::jsonb
)
RETURNS jsonb AS $$
DECLARE
    branch        uuid;
    _data          jsonb;
    new_data        jsonb;
    class_name    text;
    _class_uuid    uuid;
    tran_id       bigint;
    _attrs         jsonb;
    schema        jsonb;
    _obj_GUID      uuid;
    res           jsonb;
    affected      uuid[];
    inserted        uuid[];
    _dupBehavior  dp_bhvr;
    _isCascade      boolean;
    _uniField     text;
    _parent_guid  uuid;
    _last_use       timestamp;
    _parent_field   text;
    skip_insert     boolean;
    notify_res      jsonb;
    _cnt             int;
BEGIN

    IF (jsonb_typeof(data_jsonb) != 'array') THEN
        data_jsonb := '[]'::jsonb || data_jsonb;
    END IF;
    /*TODO: check if some objects have revision AND others do not */
    branch:= data_jsonb->0->'branch';

    FOR _data IN SELECT jsonb_array_elements(data_jsonb) 
    LOOP
        skip_insert := false;
        class_name := _data->>'class';

        IF (class_name IS NULL) THEN
            RAISE EXCEPTION 'The reclada object class is not specified';
        END IF;
        _class_uuid := reclada.try_cast_uuid(class_name);

        _attrs := _data->'attributes';
        IF (_attrs IS NULL) THEN
            RAISE EXCEPTION 'The reclada object must have attributes';
        END IF;

        tran_id := (_data->>'transactionID')::bigint;
        if tran_id is null then
            tran_id := reclada.get_transaction_id();
        end if;

        IF _class_uuid IS NULL THEN
            SELECT reclada_object.get_schema(class_name) 
            INTO schema;
            _class_uuid := (schema->>'GUID')::uuid;
        ELSE
            SELECT v.data 
            FROM reclada.v_class v
            WHERE _class_uuid = v.obj_id
            INTO schema;
        END IF;
        IF (schema IS NULL) THEN
            RAISE EXCEPTION 'No json schema available for %', class_name;
        END IF;

        IF (NOT(public.validate_json_schema(schema->'attributes'->'schema', _attrs))) THEN
            RAISE EXCEPTION 'JSON invalid: %', _attrs;
        END IF;
        
        IF _data->>'id' IS NOT NULL THEN
            RAISE EXCEPTION '%','Field "id" not allow!!!';
        END IF;

        SELECT parent_field
        FROM reclada.v_parent_field
        WHERE for_class = class_name
            INTO _parent_field;

        _parent_guid = (_data->>'parent_guid')::uuid;
        IF (_parent_guid IS NULL AND _parent_field IS NOT NULL) THEN
            _parent_guid = _attrs->>_parent_field;
        END IF;

        IF _class_uuid IN (SELECT class_uuid FROM reclada.v_unifields_idx_cnt)
        THEN
            SELECT dup_behavior, last_use                      
            FROM reclada_object.cr_dup_behavior         
            WHERE parent_guid       = _parent_guid
                AND transaction_id  = tran_id
                INTO _dupBehavior,  _last_use;

            IF (_dupBehavior = 'Update') THEN
                IF (_last_use < current_timestamp - interval '1 hour') THEN
                    UPDATE reclada_object.cr_dup_behavior
                    SET last_use = current_timestamp
                    WHERE parent_guid       = _parent_guid
                        AND transaction_id  = tran_id;
                END IF;
                SELECT count(*)
                FROM reclada.get_duplicates(_attrs, _class_uuid)
                    INTO _cnt;
                IF (_cnt >1) THEN
                    RAISE EXCEPTION 'Found more than one duplicates. Resolve conflict manually.';
                END IF;
                FOR _obj_GUID, _isCascade IN (
                    SELECT obj_guid, is_cascade
                    FROM reclada.get_duplicates(_attrs, _class_uuid)) LOOP
                        new_data := _data;
                        IF (_isCascade) THEN
                            PERFORM reclada_object.add_cr_dup_mark(
                                (_data->>'GUID')::uuid,
                                tran_id,
                                'Update');
                        END IF;
                        new_data := reclada_object.remove_parent_guid(new_data, _parent_field);
                        new_data = reclada_object.update_json_by_guid(_obj_GUID, new_data);
                        SELECT reclada_object.update(new_data)
                            INTO res;
                        affected := array_append( affected, _obj_GUID);
                        skip_insert := true;
                END LOOP;
            END IF;
            IF (NOT skip_insert) THEN
                SELECT COUNT(DISTINCT obj_guid), MAX(dup_behavior)
                FROM reclada.get_duplicates(_attrs, _class_uuid)
                    INTO _cnt, _dupBehavior;
                IF (_cnt>1 AND _dupBehavior IN ('Update','Merge')) THEN
                    RAISE EXCEPTION 'Found more than one duplicates. Resolve conflict manually.';
                END IF;
                FOR _obj_GUID, _dupBehavior, _isCascade, _uniField IN (
                    SELECT obj_guid, dup_behavior, is_cascade, dup_field
                    FROM reclada.get_duplicates(_attrs, _class_uuid)) LOOP
                    new_data := _data;
                    CASE _dupBehavior
                        WHEN 'Replace' THEN
                            CASE _isCascade
                                WHEN true
                                THEN
                                    PERFORM reclada_object.delete(format('{"GUID": "%s"}', a)::jsonb)
                                    FROM reclada.get_childs(_obj_GUID) a;
                                WHEN false
                                THEN
                                    PERFORM reclada_object.delete(format('{"GUID": "%s"}', _obj_GUID)::jsonb);
                            END CASE;
                        WHEN 'Update' THEN
                            IF _isCascade THEN
                                PERFORM reclada_object.add_cr_dup_mark(
                                    (new_data->>'GUID')::uuid,
                                    tran_id,
                                    'Update');
                            END IF;
                            new_data := reclada_object.remove_parent_guid(new_data, _parent_field);
                            new_data = reclada_object.update_json_by_guid(_obj_GUID, new_data);
                            SELECT reclada_object.update(new_data)
                                INTO res;
                            affected := array_append( affected, _obj_GUID);
                            skip_insert := true;
                        WHEN 'Reject' THEN
                            RAISE EXCEPTION 'Duplicate found (GUID: %). Object rejected.', _obj_GUID;
                        WHEN 'Copy'    THEN
                            _attrs = _attrs || format('{"%s": "%s_%s"}', _uniField, _attrs->> _uniField, nextval('reclada.object_id_seq'))::jsonb;
                        WHEN 'Insert' THEN
                            -- DO nothing
                        WHEN 'Merge' THEN
                            SELECT reclada_object.update(reclada_object.merge(new_data - 'class', data,schema->'attributes'->'schema') || format('{"GUID": "%s"}', _obj_GUID)::jsonb || format('{"transactionID": %s}', tran_id)::jsonb)
                            FROM reclada.v_active_object
                            WHERE obj_id = _obj_GUID
                                INTO res;
                            affected := array_append( affected, _obj_GUID);
                            skip_insert := true;
                    END CASE;
                END LOOP;
            END IF;
        END IF;

        IF (NOT skip_insert) THEN
            _obj_GUID := (_data->>'GUID')::uuid;
            IF EXISTS (
                SELECT 1
                FROM reclada.object 
                WHERE GUID = _obj_GUID
            ) THEN
                RAISE EXCEPTION 'GUID: % is duplicate', _obj_GUID;
            END IF;
            --raise notice 'schema: %',schema;

            INSERT INTO reclada.object(GUID,class,attributes,transaction_id, parent_guid)
                SELECT  CASE
                            WHEN _obj_GUID IS NULL
                                THEN public.uuid_generate_v4()
                            ELSE _obj_GUID
                        END AS GUID,
                        _class_uuid, 
                        _attrs,
                        tran_id,
                        _parent_guid
            RETURNING GUID INTO _obj_GUID;
            affected := array_append( affected, _obj_GUID);
            inserted := array_append( inserted, _obj_GUID);
            PERFORM reclada_object.datasource_insert
                (
                    class_name,
                    _obj_GUID,
                    _attrs
                );

            PERFORM reclada_object.refresh_mv(class_name);
        END IF;
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
    notify_res := array_to_json
            (
                array
                (
                    SELECT o.data 
                    FROM reclada.v_active_object o
                    WHERE o.obj_id = ANY (inserted)
                )
            )::jsonb; 
    PERFORM reclada_notification.send_object_notification
        (
            'create',
            notify_res
        );
    RETURN res;

END;
$$ LANGUAGE PLPGSQL VOLATILE;