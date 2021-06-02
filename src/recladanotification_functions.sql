DROP PROCEDURE IF EXISTS reclada_notification.send(varchar, jsonb);
CREATE OR REPLACE PROCEDURE reclada_notification.send(channel varchar, payload jsonb DEFAULT NULL)
LANGUAGE PLpgSQL AS 
$body$
BEGIN
    PERFORM pg_notify(channel, payload::text); 
END
$body$;

CREATE OR REPLACE PROCEDURE reclada_notification.listen(channel varchar)
LANGUAGE PLpgSQL AS 
$body$
BEGIN
    EXECUTE 'LISTEN ' || channel;
END
$body$