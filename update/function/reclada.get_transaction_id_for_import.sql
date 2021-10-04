DROP FUNCTION IF EXISTS reclada.get_transaction_id_for_import;
CREATE OR REPLACE FUNCTION reclada.get_transaction_id_for_import(fileGUID text)
  RETURNS bigint 
  LANGUAGE plpgsql VOLATILE
AS
$func$
DECLARE
    tran_id_    bigint;
BEGIN

    select o.transaction_id
        from reclada.v_active_object o
            where o.class_name = 'Document'
                and attrs->>'fileGUID' = fileGUID
        ORDER BY ID DESC 
        limit 1
        into tran_id_;

    if tran_id_ is not null then
        PERFORM reclada_object.delete(format('{"transactionID":%s}',tran_id_)::jsonb);
    end if;
    tran_id_ := reclada.get_transaction_id();

    return tran_id_;
END
$func$;