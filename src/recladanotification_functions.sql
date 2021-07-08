DROP FUNCTION IF EXISTS reclada_notification.send(varchar, jsonb);
CREATE OR REPLACE FUNCTION reclada_notification.send(channel varchar, payload jsonb DEFAULT NULL)
RETURNS void
LANGUAGE PLpgSQL STABLE AS 
$body$
BEGIN
    PERFORM pg_notify(lower(channel), payload::text); 
END
$body$;

DROP FUNCTION IF EXISTS reclada_notification.listen(varchar);
CREATE OR REPLACE FUNCTION reclada_notification.listen(channel varchar)
RETURNS void
LANGUAGE PLpgSQL STABLE AS 
$body$
BEGIN
    EXECUTE 'LISTEN ' || lower(channel);
END
$body$;

DROP FUNCTION IF EXISTS reclada_notification.send_object_notification(varchar, jsonb);
CREATE OR REPLACE FUNCTION reclada_notification.send_object_notification(event varchar, object_data jsonb)
RETURNS void
LANGUAGE PLpgSQL STABLE AS
$body$
DECLARE
    data            jsonb;
    message         jsonb;
    msg             jsonb;
    object_class    varchar;
    attrs           jsonb;
    query           text;

BEGIN

    IF (jsonb_typeof(object_data) != 'array') THEN
        object_data := '[]'::jsonb || object_data;
    END IF;

    FOR data IN SELECT jsonb_array_elements(object_data) LOOP
        object_class := data ->> 'class';

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
        execute query into attrs using data -> 'attrs';

        msg := jsonb_build_object(
            'objectId', data -> 'id',
            'class', object_class,
            'event', event,
            'attrs', attrs
        );

        perform reclada_notification.send(message #>> '{attrs, channelName}', msg);

    END LOOP;
END
$body$;

insert into reclada.staging
values (
    '{"id": "cbae8457-7c85-4d03-9fd4-bb9e3722974e",
    "attrs":
    {"task": "c94bff30-15fa-427f-9954-d5c3c151e652",
    "type": "K8S",
    "status": "new",
     "command": "  ",
    "inputParameters": [
        {"uri": "  "},
        {"dataSourceId": "b640d98d-f82a-4f25-ae33-8c0cc0ee1b81"}
        ]},
    "class": "Job",
    "revision": 500,
    "isDeleted": false}'::jsonb);

select * from reclada.object
where (data->>'revision')= '500'

select * from reclada.staging
where (data->>'revision')= '500'