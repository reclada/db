-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script


--{function/reclada_object.datasource_insert}
--{view/reclada.v_task}
--{view/reclada.v_pk_for_class}

delete from reclada.object 
    where class in (select reclada_object.get_GUID_for_class('PipelineLite'));

delete from reclada.object
    where class = reclada_object.get_jsonschema_GUID()
        and attributes ->> 'forClass' = 'PipelineLite';