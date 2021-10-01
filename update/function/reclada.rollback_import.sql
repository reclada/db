DROP FUNCTION IF EXISTS reclada.rollback_import;
CREATE OR REPLACE FUNCTION reclada.rollback_import(fileGUID text)
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
    select max(o.transaction_id)
        from reclada.v_active_object o
            where o.class_name = 'Document'
                and attrs->>'fileGUID' = fileGUID
        into tran_id_;

    if tran_id_ is null then
        PERFORM reclada.raise_exception('"fileGUID": "'
                            ||fileGUID
                            ||'" not found for existing Documents',f_name);
    end if;

    delete from reclada.object where tran_id_ = transaction_id;
    
    with t as (
        select max(o.transaction_id) as transaction_id
            from reclada.v_object o
                where o.class_name = 'Document'
                    and attrs->>'fileGUID' = fileGUID
    ) 
    update reclada.object o
        set status = reclada_object.get_active_status_obj_id()
        from t
            where t.transaction_id = o.transaction_id;
                    
    return 'OK';
END
$func$;