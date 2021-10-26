-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

drop OPERATOR IF EXISTS ^(boolean, boolean);

--{function/reclada_object.get_query_condition_filter}
--{function/reclada_object.list}
--{view/reclada.v_filter_avaliable_operator}
--{function/reclada.xor}

