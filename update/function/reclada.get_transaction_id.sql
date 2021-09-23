DROP FUNCTION IF EXISTS reclada.get_transaction_id;
CREATE OR REPLACE FUNCTION reclada.get_transaction_id()
  RETURNS bigint 
  LANGUAGE plpgsql VOLATILE
AS
$func$
BEGIN
    return nextval('reclada.transaction_id');
END
$func$;