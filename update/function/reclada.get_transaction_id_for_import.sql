DROP FUNCTION IF EXISTS reclada.get_transaction_id_for_import;
CREATE OR REPLACE FUNCTION reclada.get_transaction_id_for_import(import_name text)
  RETURNS bigint 
  LANGUAGE plpgsql VOLATILE
AS
$func$
DECLARE
    tran_id     bigint;
    json_data   bigint;
BEGIN
    select i.transaction_id, data
        from reclada.v_import_info i
            where i.name = import_name
        into tran_id, json_data;

    if tran_id is not null then
        select reclada_object.delete(format('{"transactionID":%s}',tran_id)::jsonb);
    end if;

    select reclada.get_transaction_id() 
        into tran_id;

    json_data := json_data || format('{"attributes":{"transactionID":%s}}',tran_id)::jsonb;
    select reclada_object.update(json_data);
    return tran_id;
END
$func$;