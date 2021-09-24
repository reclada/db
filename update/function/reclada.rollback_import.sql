DROP FUNCTION IF EXISTS reclada.rollback_import;
CREATE OR REPLACE FUNCTION reclada.rollback_import(import_name text)
  RETURNS text
  LANGUAGE plpgsql VOLATILE
AS
$func$
DECLARE
    tran_id_     bigint;
    json_data   jsonb;
    tmp         jsonb;
    obj_id_     uuid;
    f_name      text;
    id_         bigint;
BEGIN
    f_name := 'reclada.rollback_import';
    select i.tran_id, data, guid, id
        from reclada.v_import_info i
            where i.name = import_name
        into tran_id_, json_data, obj_id_, id_;

    if tran_id_ is null then
        PERFORM reclada.raise_exception('"name": "'
                            ||import_name
                            ||'" not found for existing import',f_name);
    end if;

    delete from reclada.object where tran_id_ = transaction_id or id = id_;
    
    with t as (
        SELECT id 
            from reclada.v_object o
                where o.obj_id = obj_id_
                    ORDER BY ID DESC 
                        LIMIT 1
    ) 
    update reclada.object o
        set status = reclada_object.get_active_status_obj_id()
        from t
            where t.id = o.id;
        
    update reclada.object o
        set status = reclada_object.get_active_status_obj_id()
        from reclada.v_import_info i
            where i.guid = obj_id_
                and i.tran_id = o.transaction_id;
                    
    return 'OK';
END
$func$;