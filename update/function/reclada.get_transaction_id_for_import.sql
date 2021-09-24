DROP FUNCTION IF EXISTS reclada.get_transaction_id_for_import;
CREATE OR REPLACE FUNCTION reclada.get_transaction_id_for_import(import_name text)
  RETURNS bigint 
  LANGUAGE plpgsql VOLATILE
AS
$func$
DECLARE
    tran_id_    bigint;
    json_data   jsonb;
    tmp         jsonb;
BEGIN
    select i.tran_id, data
        from reclada.v_import_info i
            where i.name = import_name
        into tran_id_, json_data;

    if tran_id_ is not null then
        PERFORM reclada_object.delete(format('{"transactionID":%s}',tran_id_)::jsonb);
    end if;
    tran_id_ := reclada.get_transaction_id();


    tmp := format(
                '{"class":"ImportInfo","attributes":{"tranID":%s,"name":"%s"}}',
                tran_id_,
                import_name
            )::jsonb;
    if json_data is null then
        json_data := reclada_object.create(tmp);
    else
        json_data = json_data || tmp;
        PERFORM reclada_object.update(json_data);
    end if;
    
    return tran_id_;
END
$func$;