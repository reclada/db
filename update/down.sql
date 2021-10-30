-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script


--{view/reclada.v_pk_for_class}
--{view/reclada.v_DTO_json_schema}

delete from reclada.object 
    where class in (select reclada_object.get_GUID_for_class('DTOJsonSchema'));

delete from reclada.object 
    where guid in (select reclada_object.get_GUID_for_class('DTOJsonSchema'));

--{function/reclada.validate_json}
--{function/reclada_object.get_query_condition_filter}
--{function/api.reclada_object_list}
