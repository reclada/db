CREATE FUNCTION dev.reg_notice(msg   TEXT)
RETURNS void
LANGUAGE PLPGSQL VOLATILE
as
$do$
BEGIN
    insert into dev.t_dbg(msg)
		select msg;
    perform public.raise_notice(msg);
END
$do$;