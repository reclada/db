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
    _new_guid       uuid;
    _rel_type       text := 'GUID changed for Update dupBehavior';
    _guid_list      text;
BEGIN

    IF (jsonb_typeof(data_jsonb) != 'array') THEN
        data_jsonb := '[]'::jsonb || data_jsonb;
    END IF;
    /*TODO: check if some objects have revision AND others do not */
    branch:= data_jsonb->0->'branch';

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
            SELECT v.data 
            FROM reclada.v_class v
            WHERE _class_uuid = v.obj_id
            INTO schema;
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
        
        IF EXISTS (
            SELECT 1
            FROM reclada.v_unifields_idx_cnt
            WHERE class_uuid = _class_uuid
        )
        THEN
            IF (_parent_guid IS NOT NULL) THEN
                IF NOT EXISTS (
                    SELECT 1
                    FROM reclada.v_active_object
                    WHERE obj_id = _parent_guid
                )
                THEN
                    IF (_obj_guid IS NULL) THEN
                        RAISE EXCEPTION 'GUID is required.';
                    END IF;
                    INSERT INTO reclada.draft(guid, parent_guid, data)
                        VALUES(_obj_guid, _parent_guid, _data);
                    skip_insert := true;
                ELSE
                    SELECT attrs->>'object'                    
                    FROM reclada.v_active_object
                    WHERE class_name = 'Relationship'
                        AND attrs->>'type'                      = _rel_type
                        AND NULLIF(attrs->>'subject','')::uuid  = _parent_guid
                            INTO _new_guid;

                    IF (_new_guid IS NOT NULL) THEN
                        SELECT count(DISTINCT obj_guid), string_agg(DISTINCT obj_guid::text, ',')
                        FROM reclada.get_duplicates(_attrs, _class_uuid)
                            INTO _cnt, _guid_list;
                        IF (_cnt >1) THEN
                            RAISE EXCEPTION 'Found more than one duplicates (GUIDs: %). Resolve conflict manually.', _guid_list;
                        ELSIF (_cnt = 1) THEN
                            SELECT DISTINCT obj_guid, is_cascade
                            FROM reclada.get_duplicates(_attrs, _class_uuid)
                                INTO _obj_guid, _is_cascade;
                            new_data := _data;
                            IF (_is_cascade) THEN
                                PERFORM reclada_object.create_relationship(
                                        _rel_type,
                                        _obj_guid,
                                        new_data->>'GUID'::uuid);
                            END IF;
                            new_data := reclada_object.remove_parent_guid(new_data, _parent_field);
                            new_data = reclada_object.update_json_by_guid(_obj_guid, new_data);
                            SELECT reclada_object.update(new_data)
                                INTO res;
                            affected := array_append( affected, _obj_guid);
                            skip_insert := true;
                        ELSE
                            _parent_guid := _new_guid;
                        END IF;
                    END IF;
                END IF;
            END IF;

            IF (NOT skip_insert) THEN
                SELECT COUNT(DISTINCT obj_guid), dup_behavior, string_agg (DISTINCT obj_guid::text, ',')
                FROM reclada.get_duplicates(_attrs, _class_uuid)
                GROUP BY dup_behavior
                    INTO _cnt, _dup_behavior, _guid_list;
                IF (_cnt>1 AND _dup_behavior IN ('Update','Merge')) THEN
                    RAISE EXCEPTION 'Found more than one duplicates (GUIDs: %). Resolve conflict manually.', _guid_list;
                END IF;
                FOR _obj_guid, _dup_behavior, _is_cascade, _uni_field IN
                    SELECT obj_guid, dup_behavior, is_cascade, dup_field
                    FROM reclada.get_duplicates(_attrs, _class_uuid)
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
                            IF _is_cascade THEN
                                PERFORM reclada_object.create_relationship(
                                    _rel_type,
                                    _obj_guid,
                                    new_data->>'GUID'::uuid);
                            END IF;
                            new_data := reclada_object.remove_parent_guid(new_data, _parent_field);
                            new_data := reclada_object.update_json_by_guid(_obj_guid, new_data);
                            SELECT reclada_object.update(new_data)
                                INTO res;
                            affected := array_append( affected, _obj_guid);
                            skip_insert := true;
                        WHEN 'Reject' THEN
                            INSERT INTO reclada.draft(guid,  data)
                                VALUES(new_data->>'GUID'::uuid, _data);
                            skip_insert := true;
                        WHEN 'Copy'    THEN
                            _attrs := _attrs || format('{"%s": "%s_%s"}', _uni_field, _attrs->> _uni_field, nextval('reclada.object_id_seq'))::jsonb;
                        WHEN 'Insert' THEN
                            -- DO nothing
                        WHEN 'Merge' THEN
                            SELECT reclada_object.update(reclada_object.merge(new_data - 'class', data,schema->'attributes'->'schema') || format('{"GUID": "%s"}', _obj_guid)::jsonb || format('{"transactionID": %s}', tran_id)::jsonb)
                            FROM reclada.v_active_object
                            WHERE obj_id = _obj_guid
                                INTO res;
                            affected := array_append( affected, _obj_guid);
                            skip_insert := true;
                    END CASE;
                END LOOP;
            END IF;
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
$$ LANGUAGE PLPGSQL VOLATILE;