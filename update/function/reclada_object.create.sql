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
    data          jsonb;
    class_name    text;
    _class_uuid    uuid;
    tran_id       bigint;
    _attrs         jsonb;
    schema        jsonb;
    obj_GUID      uuid;
    res           jsonb;
    affected      uuid[];
    _dupBehavior  text;
    _uniField     text;
    _parent_guid  uuid;
BEGIN

    IF (jsonb_typeof(data_jsonb) != 'array') THEN
        data_jsonb := '[]'::jsonb || data_jsonb;
    END IF;
    /*TODO: check if some objects have revision AND others do not */
    branch:= data_jsonb->0->'branch';

    FOR data IN SELECT jsonb_array_elements(data_jsonb) 
    LOOP

        class_name := data->>'class';

        IF (class_name IS NULL) THEN
            RAISE EXCEPTION 'The reclada object class is not specified';
        END IF;
        _class_uuid := reclada.try_cast_uuid(class_name);

        _attrs := data->'attributes';
        IF (_attrs IS NULL) THEN
            RAISE EXCEPTION 'The reclada object must have attributes';
        END IF;

        tran_id := (data->>'transactionID')::bigint;
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
        
        IF data->>'id' IS NOT NULL THEN
            RAISE EXCEPTION '%','Field "id" not allow!!!';
        END IF;

        IF _class_uuid IN (SELECT class_uuid FROM reclada.v_unifields_idx_cnt)
        THEN
            FOR obj_GUID, _dupBehavior, _uniField IN (
            SELECT obj_id, dup_behavior, f1
            FROM reclada.v_active_object vao
            JOIN reclada.v_unifields_pivoted vup ON vao."class" = vup.class_uuid
            WHERE vao.attrs ->> f1||vao.attrs ->> f2||vao.attrs ->> f3||vao.attrs ->> f4||vao.attrs ->> f5||vao.attrs ->> f6||vao.attrs ->> f7||vao.attrs ->> f8
                = _attrs ->> f1||_attrs ->> f2||_attrs ->> f3||_attrs ->> f4||_attrs ->> f5||_attrs ->> f6||_attrs ->> f7||_attrs ->> f8
                AND vao."class" = _class_uuid) LOOP
                CASE _dupBehavior
                    WHEN 'Replace' THEN
                        SELECT reclada_object.delete(format('{"GUID": "%s"}', get_сhilds)::jsonb)
                        FROM reclada.get_сhilds(obj_GUID);
                    WHEN 'Update' THEN
                        -- TODO cascade update
                    WHEN 'Reject' THEN
                        RETURN '{}'::jsonb;
                    WHEN 'Copy'    THEN
                        _attrs = _attrs || format('{"%s": "%s"}', _uniField, (_attrs->> _uniField) || nextval('reclada.object_id_seq'))::jsonb;
                    WHEN 'Insert' THEN
                        -- DO nothing
                    WHEN 'Merge' THEN
                        -- TODO merge
                END CASE;
            END LOOP;
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

        CASE class_name
            WHEN 'jsonschema'
            THEN
                _parent_guid = (data->>'parent_guid')::uuid;
            ELSE
                SELECT _attrs->>parent_field
                FROM reclada.v_parent_field
                WHERE for_class = class_name
                    INTO _parent_guid;

        INSERT INTO reclada.object(GUID,class,attributes,transaction_id, parent_guid)
            SELECT  CASE
                        WHEN obj_GUID IS NULL
                            THEN public.uuid_generate_v4()
                        ELSE obj_GUID
                    END AS GUID,
                    _class_uuid, 
                    _attrs,
                    tran_id,
                    _parent_guid
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
$$ LANGUAGE PLPGSQL VOLATILE;