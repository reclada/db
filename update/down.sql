-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

--{function/reclada_object.create_subclass}
--{function/reclada_object.create}

update reclada.object
    set attributes = attributes - 'parentList'
    where class = reclada_object.get_jsonschema_GUID();

update reclada.object
    set attributes = jsonb_set(
            attributes,
            '{schema,properties}',
            (attributes#>'{schema,properties}') - 'parentList'
        )
    where guid = reclada_object.get_jsonschema_GUID();
