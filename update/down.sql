-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script



drop table reclada.draft;

--{function/api.reclada_object_create}
--{function/reclada_object.create}
--{function/api.reclada_object_list}
--{function/api.reclada_object_delete}