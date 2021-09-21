drop FUNCTION IF EXISTS reclada_notification.send_object_notification;
CREATE OR REPLACE FUNCTION reclada_notification.send_object_notification(event varchar, object_data jsonb)
RETURNS void
LANGUAGE PLpgSQL STABLE AS
$body$
DECLARE
    data            jsonb;
    message         jsonb;
    msg             jsonb;
    object_class    uuid;
    class__name     varchar;
    attrs           jsonb;
    query           text;

BEGIN
    IF (jsonb_typeof(object_data) != 'array') THEN
        object_data := '[]'::jsonb || object_data;
    END IF;

    FOR data IN SELECT jsonb_array_elements(object_data) LOOP
        object_class := (data ->> 'class')::uuid;
        select for_class
            from reclada.v_class_lite cl
                where cl.obj_id = object_class
            into class__name;

        if event is null or object_class is null then
            return;
        end if;
        
        SELECT v.data
            FROM reclada.v_active_object v
                WHERE v.class_name = 'Message'
                    AND v.attrs->>'event' = event
                    AND v.attrs->>'class' = class__name
        INTO message;

        -- raise notice '%', event || ' ' || class__name;

        IF message IS NULL THEN
            RETURN;
        END IF;

        query := format(E'select to_json(x) from jsonb_to_record($1) as x(%s)',
            (
                select string_agg(s::text || ' jsonb', ',') 
                    from jsonb_array_elements(message -> 'attributes' -> 'attrs') s
            ));
        execute query into attrs using data -> 'attributes';

        msg := jsonb_build_object(
            'objectId', data -> 'id',
            'class', object_class,
            'event', event,
            'attributes', attrs
        );

        perform reclada_notification.send(message #>> '{attributes, channelName}', msg);

    END LOOP;
END
$body$;
