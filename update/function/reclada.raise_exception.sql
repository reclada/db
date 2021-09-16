DROP FUNCTION IF EXISTS reclada.raise_exception;
CREATE or replace FUNCTION reclada.raise_exception(msg text)
  RETURNS void
  LANGUAGE plpgsql VOLATILE
AS
$func$
BEGIN
    -- 
    RAISE EXCEPTION '%', msg;
END
$func$;