-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script



drop table reclada.draft;

--{function/api.reclada_object_create}
--{function/reclada_object.create}
--{function/api.reclada_object_list}
--{function/api.reclada_object_delete}
--{function/reclada_object.datasource_insert}
--{function/reclada.raise_exception}
--{function/reclada_object.get_query_condition_filter}

delete from reclada.object 
    where guid in (select reclada_object.get_GUID_for_class('Asset'));

delete from reclada.object 
    where guid in (select reclada_object.get_GUID_for_class('DBAsset'));

UPDATE reclada.OBJECT
SET ATTRIBUTES = ATTRIBUTES #- '{schema,properties,object,minLength}'
WHERE guid IN(SELECT reclada_object.get_GUID_for_class('Relationship'));

UPDATE reclada.OBJECT
SET ATTRIBUTES = ATTRIBUTES #- '{schema,properties,subject,minLength}'
WHERE guid IN(SELECT reclada_object.get_GUID_for_class('Relationship'));
