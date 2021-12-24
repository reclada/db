DROP FUNCTION IF EXISTS reclada.raise_exception;
CREATE or replace FUNCTION reclada.raise_exception(msg text, func_name text = '<unknown>')
  RETURNS bool
  LANGUAGE plpgsql VOLATILE
AS
$func$
BEGIN
    -- 
    RAISE EXCEPTION '% 
    from: %', msg, func_name;
END
$func$;