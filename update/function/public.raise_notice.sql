CREATE FUNCTION public.raise_notice(msg text)
  RETURNS void
  LANGUAGE plpgsql VOLATILE
AS
$func$
BEGIN
    -- 
    RAISE NOTICE '%', msg;
END
$func$;