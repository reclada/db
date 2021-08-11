CREATE or replace FUNCTION public.raise_exception(msg text)
  RETURNS void
  LANGUAGE plpgsql VOLATILE
AS
$func$
BEGIN
    -- 
    RAISE EXCEPTION '%', msg;
END
$func$;