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
        
        SELECT v.data FROM reclada.v_active_object v
        WHERE (v.data->>'class' = 'Message')
            AND (v.data->'attrs'->>'event' = event)
            AND (v.data->'attrs'->>'class' = object_class)
        INTO message;

        IF message IS NULL THEN
            RETURN;
        END IF;

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
