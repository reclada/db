DROP FUNCTION IF EXISTS dev.reg_notice;
CREATE OR REPLACE FUNCTION dev.reg_notice(msg   TEXT)
RETURNS void
LANGUAGE PLPGSQL VOLATILE
as
$do$
BEGIN
    insert into dev.t_dbg(msg)
		select msg;
    perform reclada.raise_notice(msg);
END
$do$;