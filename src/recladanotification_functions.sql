DROP FUNCTION IF EXISTS reclada_notification.send(varchar, jsonb);
CREATE OR REPLACE FUNCTION reclada_notification.send(channel varchar, payload jsonb DEFAULT NULL)
STABLE
RETURNS Void
LANGUAGE PLpgSQL AS 
$body$
BEGIN
    PERFORM pg_notify(lower(channel), payload::text); 
END
$body$;

DROP FUNCTION IF EXISTS reclada_notification.listen(varchar);
CREATE OR REPLACE FUNCTION reclada_notification.listen(channel varchar)
STABLE
RETURNS Void
LANGUAGE PLpgSQL AS 
$body$
BEGIN
    EXECUTE 'LISTEN ' || lower(channel);
END
$body$;

DROP FUNCTION IF EXISTS reclada_notification.send_object_notification(varchar, jsonb);
CREATE OR REPLACE FUNCTION reclada_notification.send_object_notification(event varchar, object_data jsonb)
RETURNS Void
STABLE
LANGUAGE PLpgSQL AS
$body$
DECLARE 
    message         jsonb;
    msg             jsonb;
    object_class    varchar;
    attrs           jsonb;
    query           text;
BEGIN 
    object_class := object_data ->> 'class';

    if event is null or object_class is null then
        return;
    end if;

    message := reclada_object.list(format('{"class": "Message", "attrs": {"event": "%s", "class": "%s"}}', 
        event, 
        object_class)::jsonb);
    if message is not null then
        message := message -> 0;
    else
        -- no template defined for this (object,event). 
        return;
    end if;

    
    query := format(E'select to_json(x) from jsonb_to_record($1) as x(%s)',
        (select string_agg(s::text || ' jsonb', ',') from jsonb_array_elements(message -> 'attrs' -> 'attrs') s));
    execute query into attrs using object_data -> 'attrs';
    
    msg := jsonb_build_object(
        'objectId', object_data -> 'id',
        'class', object_class,
        'event', event,
        'attrs', attrs
    );

    perform reclada_notification.send(message #>> '{attrs, channelName}', msg);
END
$body$;

