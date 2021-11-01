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
--{function/reclada_object.list}


DROP VIEW IF EXISTS reclada.v_revision;
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

--{view/reclada.v_filter_avaliable_operator}
--{view/reclada.v_filter_inner_operator}
