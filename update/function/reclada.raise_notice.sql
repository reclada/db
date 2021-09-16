DROP FUNCTION IF EXISTS reclada.raise_notice;
CREATE FUNCTION reclada.raise_notice(msg text)
  RETURNS void
  LANGUAGE plpgsql VOLATILE
AS
$func$
BEGIN
    -- 
    RAISE NOTICE '%', msg;
END
$func$;