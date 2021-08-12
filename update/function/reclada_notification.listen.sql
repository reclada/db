CREATE OR REPLACE FUNCTION reclada_notification.listen(channel varchar)
RETURNS void
LANGUAGE PLpgSQL STABLE AS 
$body$
BEGIN
    EXECUTE 'LISTEN ' || lower(channel);
END
$body$;