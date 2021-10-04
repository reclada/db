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
    data jsonb, 
    user_info jsonb default '{}'::jsonb
)
RETURNS jsonb
LANGUAGE PLPGSQL VOLATILE
AS $body$
DECLARE
    class_name     text;
    class_uuid     uuid;
    v_obj_id       uuid;
    v_attrs        jsonb;
    schema        jsonb;
    error         text;
    old_obj       jsonb;
    branch        uuid;
    revid         uuid;
BEGIN

    select  f1.v,
            f2.v,
            data->>'GUID' f3,
            data->'attributes' f4,
            f5.v
        from (select 1 a) as t
        LEFT JOIN LATERAL
        (
            select data->>'class' v
        )  f1 ON TRUE
        LEFT JOIN LATERAL
        (
            select reclada.try_cast_uuid(f1.v) v
        )  f2 ON TRUE
        LEFT JOIN LATERAL
        (
            SELECT reclada_object.get_schema(class_name) as v
                where f2.v is NULL 
            UNION 
            select v.data as v
                from reclada.v_class v
                    where f2.v is NOT NULL 
                        and f2.v = v.obj_id 
        )  f5 ON TRUE
    into    class_name,
            class_uuid,
            v_obj_id,
            v_attrs,
            schema;
   
    select a 
        from
        (
            select 0 as ID, 'The reclada object class is not specified' a
                where class_name IS NULL
            UNION 
            select 1 as ID, 'Could not update object with no GUID' a
                where v_obj_id IS NULL
            UNION 
            select 2, 'The reclada object must have attributes'
                where v_attrs IS NULL
            UNION 
            -- TODO: don't allow update jsonschema
            select 3, 'No json schema available for '||class_name
                where schema IS NULL
            UNION 
            select 4, 'JSON invalid: ' || v_attrs::text
                where NOT(public.validate_json_schema(schema->'attributes'->'schema', v_attrs))
            UNION 
            select 5, 'Could not update object, no such id'
                where not EXISTS
                (
                    SELECT 
                        FROM reclada.v_active_object v
                            WHERE v.obj_id = v_obj_id
                )
        ) t
        ORDER BY ID 
            limit 1
    into error;
    if (error is not null) then
        perform reclada.raise_exception(error, 'reclada_object.update');
    end if;

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
                                attributes,
                                transaction_id
                              )
        select  v.obj_id,
                (schema->>'GUID')::uuid,
                reclada_object.get_active_status_obj_id(),--status 
                v_attrs || format('{"revision":"%s"}',revid)::jsonb,
                transaction_id
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
$body$;
