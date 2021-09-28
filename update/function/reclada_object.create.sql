/*
 * Function reclada_object.create creates one or bunch of objects with specified fields.
 * A jsonb with user_info and a jsonb or an array of jsonb objects are required.
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
                    RETURN res;
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