-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script


--{function/reclada_object.datasource_insert}
--{view/reclada.v_task}
--{view/reclada.v_pk_for_class}

delete from reclada.object 
    where class in (select reclada_object.get_GUID_for_class('PipelineLite'));

delete from reclada.object 
    where class in (select reclada_object.get_GUID_for_class('Task'))
        and attributes ->> 'type'    like 'PipelineLite stage %'
        and attributes ->> 'command' like './pipeline/%';

delete from reclada.object
    where class = reclada_object.get_jsonschema_GUID()
        and attributes ->> 'forClass' = 'PipelineLite';

DROP VIEW IF EXISTS reclada.v_revision;
DROP VIEW IF EXISTS reclada.v_dto_json_schema;
DROP VIEW IF EXISTS reclada.v_import_info;
DROP VIEW IF EXISTS reclada.v_pk_for_class;
DROP VIEW IF EXISTS reclada.v_class;
DROP VIEW IF EXISTS reclada.v_active_object;
DROP VIEW IF EXISTS reclada.v_object;

--{view/reclada.v_object}
--{view/reclada.v_active_object}
--{view/reclada.v_class}
--{view/reclada.v_pk_for_class}
--{view/reclada.v_import_info}
--{view/reclada.v_revision}
--{view/reclada.v_dto_json_schema}
