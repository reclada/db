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
    new_data       jsonb;
    _dupBehavior    dp_bhvr;
    _uniField       text;
BEGIN

    class_name := data->>'class';
    IF (class_name IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;
    _class_uuid := reclada.try_cast_uuid(class_name);
    v_obj_id := data->>'GUID';
    IF (v_obj_id IS NULL) THEN
        RAISE EXCEPTION 'Could not update object with no GUID';
    END IF;

    v_attrs := data->'attributes';
    IF (v_attrs IS NULL) THEN
        RAISE EXCEPTION 'The reclada object must have attributes';
    END IF;

    SELECT reclada_object.get_schema(class_name) 
        INTO schema;

    if _class_uuid is null then
        SELECT reclada_object.get_schema(class_name) 
            INTO schema;
    else
        select v.data 
            from reclada.v_class v
                where class_uuid = v.obj_id
            INTO schema;
    end if;
    -- TODO: don't allow update jsonschema
    IF (schema IS NULL) THEN
        RAISE EXCEPTION 'No json schema available for %', class_name;
    END IF;

    IF (NOT(public.validate_json_schema(schema->'attributes'->'schema', v_attrs))) THEN
        RAISE EXCEPTION 'JSON invalid: %', v_attrs;
    END IF;

    SELECT 	v.data
        FROM reclada.v_active_object v
	        WHERE v.obj_id = v_obj_id
	    INTO old_obj;

    IF (old_obj IS NULL) THEN
        RAISE EXCEPTION 'Could not update object, no such id';
    END IF;

    branch := data->'branch';
    SELECT reclada_revision.create(user_info->>'sub', branch, v_obj_id) 
        INTO revid;

    SELECT parent_field
        FROM reclada.v_parent_field
        WHERE for_class = class_name
            INTO _parent_field;

    _parent_guid = (data->>'parent_guid')::uuid;
    IF (_parent_guid IS NULL AND _parent_field IS NOT NULL) THEN
        _parent_guid = v_attrs->>_parent_field;
    END IF;
    
    IF _class_uuid IN (SELECT class_uuid FROM reclada.v_unifields_idx_cnt)
    THEN
        FOR _obj_GUID, _dupBehavior, _uniField IN (
            SELECT obj_guid, dup_behavior, dup_field
            FROM reclada.get_duplicates(v_attrs, _class_uuid, v_obj_id)) LOOP
            new_data := data;
            CASE _dupBehavior
                WHEN 'Replace' THEN
                    PERFORM reclada_object.delete(format('{"GUID": "%s"}', _obj_GUID)::jsonb);
                WHEN 'Update' THEN
                    new_data := reclada_object.remove_parent_guid(new_data, parent_field);
                    new_data = reclada_object.update_json_by_guid(_obj_GUID, new_data);
                    PERFORM reclada_object.update(new_data);   --TODO add affected data to response
                WHEN 'Reject' THEN
                    --TODO reject duplicates
                WHEN 'Copy'    THEN
                    v_attrs = v_attrs || format('{"%s": "%s_%s"}', _uniField, _attrs->> _uniField, nextval('reclada.object_id_seq'))::jsonb;
                WHEN 'Insert' THEN
                    -- DO nothing
                WHEN 'Merge' THEN
                    PERFORM reclada_object.update(reclada_object.merge(new_data - 'class', vao.data) || format('{"GUID": "%s"}', _obj_GUID)::jsonb || format('{"transactionID": %s}', tran_id)::jsonb)
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
    PERFORM reclada_object.datasource_insert
            (
                class_name,
                v_obj_id,
                v_attrs
            );
    PERFORM reclada_object.refresh_mv(class_name);

    IF ( class_name = 'jsonschema' AND jsonb_typeof(v_attrs->'dupChecking') = 'array') THEN
        PERFORM reclada_object.refresh_mv('unifields');
    END IF; 
                  
    select v.data 
        FROM reclada.v_active_object v
            WHERE v.obj_id = v_obj_id
        into data;
    PERFORM reclada_notification.send_object_notification('update', data);
    RETURN data;
END;
$body$;
