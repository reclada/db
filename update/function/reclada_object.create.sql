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
    _new_parent_guid       uuid;
    _rel_type       text := 'GUID changed for dupBehavior';
    _guid_list      text;
    _component_guid uuid;
    _c              int;
    _f_name         text = 'reclada_object.create';
BEGIN

    IF (jsonb_typeof(data_jsonb) != 'array') THEN
        data_jsonb := '[]'::jsonb || data_jsonb;
    END IF;

    SELECT guid 
        FROM dev.component 
            WHERE is_installing
        into _component_guid;

    /*TODO: check if some objects have revision AND others do not */
    branch:= data_jsonb->0->'branch';

    FOR _data IN SELECT jsonb_array_elements(data_jsonb) 
    LOOP

        SELECT  schema_obj, 
                attributes,
                class_name,
                class_guid 
            FROM reclada.validate_json_schema(_data)
            INTO    schema      , 
                    _attrs      ,
                    _class_name ,
                    _class_uuid ;

        skip_insert := false;

        tran_id := (_data->>'transactionID')::bigint;
        IF tran_id IS NULL THEN
            tran_id := reclada.get_transaction_id();
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
                AND (attrs->>'subject')::uuid  = _parent_guid
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
            IF (_parent_guid IS NOT NULL) THEN
                IF (_dup_behavior = 'Update' AND _is_cascade) THEN
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
                        IF new_data->>'GUID' IS NOT NULL THEN
                            PERFORM reclada_object.create_relationship(
                                    _rel_type,
                                    _obj_guid,
                                    (new_data->>'GUID')::uuid,
                                    format('{"dupBehavior": "Update", "isCascade": %s}', _is_cascade::text)::jsonb);
                        END IF;
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
                            IF new_data->>'GUID' IS NOT NULL THEN
                                PERFORM reclada_object.create_relationship(
                                    _rel_type,
                                    _obj_guid,
                                    (new_data->>'GUID')::uuid,
                                    format('{"dupBehavior": "Update", "isCascade": %s}', _is_cascade::text)::jsonb);
                            END IF;
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
                                    '{"dupBehavior": "Merge"}'::jsonb
                                );
                            SELECT reclada_object.update(
                                    reclada_object.merge(
                                            new_data - 'class', 
                                            data,
                                            schema#>'{attributes,schema}'
                                        ) 
                                        || format('{"GUID": "%s"}', _obj_guid)::jsonb 
                                        || format('{"transactionID": %s}', tran_id)::jsonb
                                )
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
            if _component_guid is not null then

                with u as (
                    update dev.component_object
                        set status = 'ok'
                        where data->'attributes' = _attrs
                            and status = 'need to check'
                            ------
                            and _class_name = 'jsonschema'
                            ------
                        RETURNING 1 as v
                )
                    select count(v)
                        from u
                        into _c;
                if _c > 1 then
                    perform reclada.raise_exception('can''t mach component objects',_f_name);
                elsif _c = 1 then
                    continue;
                end if;

                -- upgrade jsonschema
                with u as (
                    update dev.component_object
                        set status = 'delete'
                        where data->'attributes' != _attrs
                            and data #>'{attributes,forClass}' = _attrs #> '{attributes,forClass}'
                            and status = 'need to check'
                            ------
                            and _class_name = 'jsonschema'
                            ------
                        RETURNING 1 as v
                ),
                with i1 as (
                    insert into dev.component_object( data, status  )
                        select _data, 'create'
                            from u
                        RETURNING 2 as v
                )
                    select count(v)
                        from u
                        into _c;
                if _c > 1 then
                    perform reclada.raise_exception('can''t mach component objects',_f_name);
                elsif _c = 1 then
                    continue;
                end if;
                
                with u as (
                    update dev.component_object
                        set status = 'ok'
                            where status = 'need to check'
                                and _obj_guid::text      = data->>'GUID'
                                and _attrs               = data-> 'attributes'
                                and _class_uuid::text    = data->>'class'
                                and _data->>'parentGUID' = data->>'parentGUID' 
                                ------
                                and _class_name != 'jsonschema'
                                and _obj_guid is not null
                                ------
                        RETURNING 1 as v
                )
                    select count(v)
                        from u
                        into _c;
                if _c > 1 then
                    perform reclada.raise_exception('can''t mach component objects',_f_name);
                elsif _c = 1 then
                    continue;
                end if;

                with u as (
                    update dev.component_object
                        set status = 'update',
                            data   = _data
                            where status = 'need to check' 
                                and _obj_guid::text = data->>'GUID'
                                ------
                                and _class_name != 'jsonschema'
                                and _obj_guid is not null
                                ------
                        RETURNING 1 as v
                )
                select count(v)
                        from u
                        into _c;
                if _c > 1 then
                    perform reclada.raise_exception('can''t mach component objects',_f_name);
                elsif _c = 1 then
                    continue;
                end if;
                
                with t as
                (
                    select min(id) as id
                        from dev.component_object
                            where status = 'need to check'
                                and _attrs               = data-> 'attributes'
                                and _class_uuid::text    = data->>'class'
                                and _data->>'parentGUID' = data->>'parentGUID' 
                                ------
                                and _class_name != 'jsonschema'
                                and _obj_guid is null
                                ------
                ),   
                with u as (
                    update dev.component_object u
                        set status = 'ok'
                            from t
                                where u.id = t.id
                        RETURNING 1 as v
                )
                    select count(v)
                        from u
                        into _c;
                if _c > 1 then
                    perform reclada.raise_exception('can''t mach component objects',_f_name);
                elsif _c = 1 then
                    continue;
                end if;
                
                insert into dev.component_object( data, status  )
                    select _data, 'create';
                continue;
            else
                IF EXISTS (
                    SELECT FROM reclada.object 
                        WHERE guid = _obj_guid
                ) THEN
                    perform reclada.raise_exception ('GUID: '||_obj_guid::text||' is duplicate',_f_name);
                END IF;

            end if;

            _obj_guid := coalesce(_obj_guid, public.uuid_generate_v4());

            INSERT INTO reclada.object(GUID,class,attributes,transaction_id, parent_guid)
                SELECT  _obj_guid AS GUID,
                        _class_uuid, 
                        _attrs,
                        tran_id,
                        _parent_guid;

            affected := array_append( affected, _obj_guid);
            inserted := array_append( inserted, _obj_guid);
            PERFORM reclada_object.object_insert
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

    PERFORM reclada.update_unique_object(affected);
        
    PERFORM reclada_notification.send_object_notification
        (
            'create',
            notify_res
        );
    RETURN res;
END;
$$ LANGUAGE PLPGSQL VOLATILE;