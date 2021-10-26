-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

drop OPERATOR IF EXISTS ^(boolean, boolean);
DROP VIEW IF EXISTS reclada.v_revision;
DROP VIEW IF EXISTS reclada.v_import_info;
DROP VIEW IF EXISTS reclada.v_pk_for_class;
DROP VIEW IF EXISTS reclada.v_class;
DROP VIEW IF EXISTS reclada.v_active_object;
DROP VIEW IF EXISTS reclada.v_object;

--{function/reclada_object.get_query_condition_filter}
--{function/reclada_object.list}
--{view/reclada.v_filter_avaliable_operator}
--{view/reclada.v_object}
--{view/reclada.v_active_object}
--{view/reclada.v_class}
--{view/reclada.v_pk_for_class}
--{view/reclada.v_import_info}
--{view/reclada.v_revision}
--{function/reclada.xor}

