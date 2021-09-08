/*
 * Function reclada_object.create creates one or bunch of objects with specified fields.
 * A jsonb with user_info and a jsonb or an array of jsonb objects are required.
 * A jsonb object with the following parameters is required to create one object.
 * An array of jsonb objects with the following parameters is required to create a bunch of objects.
 * Required parameters:
 *  class - the class of objects
 *  attributes - the attributes of objects
 * Optional parameters:
 *  revision - object's revision. If a revision already exists, new revision will not be created. One revision is used to create a bunch of objects.
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
    branch     uuid;
    data       jsonb;
    class      text;
    attrs      jsonb;
    schema     jsonb;
    objid      uuid;
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

        class := data->>'class';
        IF (class IS NULL) THEN
            RAISE EXCEPTION 'The reclada object class is not specified';
        END IF;

        attrs := data->'attributes';
        IF (attrs IS NULL) THEN
            RAISE EXCEPTION 'The reclada object must have attributes';
        END IF;

        SELECT reclada_object.get_schema(class) 
            INTO schema;

        IF (schema IS NULL) THEN
            RAISE EXCEPTION 'No json schema available for %', class;
        END IF;

        IF (NOT(validate_json_schema(schema->'attributes'->'schema', attrs))) THEN
            RAISE EXCEPTION 'JSON invalid: %', attrs;
        END IF;
        
        objid := (data->>'id')::uuid;
        IF EXISTS (
            select 1 from reclada.object 
                where obj_id = objid
        ) then
            RAISE EXCEPTION 'id: % is duplicate', objid;
        end if;
        with inserted as 
        (
            INSERT INTO reclada.object(obj_id,class,attributes)
                select public.uuid_generate_v4(), class, attrs
                    where objid IS NULL
                union
                select objid, class, attrs
                    where objid IS not NULL
                RETURNING obj_id
        ) 
        insert into tmp(id)
            select obj_id 
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
$$ LANGUAGE PLPGSQL VOLATILE;