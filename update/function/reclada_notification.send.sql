CREATE OR REPLACE FUNCTION reclada_notification.send(channel varchar, payload jsonb DEFAULT NULL)
RETURNS void
LANGUAGE PLpgSQL STABLE AS 
$body$
BEGIN
    PERFORM pg_notify(lower(channel), payload::text); 
END
$body$;