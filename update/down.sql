-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script


--{function/reclada.datasource_insert_trigger_fnc}

create trigger datasource_insert_trigger before
insert
    on
    reclada.object for each row execute function datasource_insert_trigger_fnc();

DROP VIEW IF EXISTS reclada.v_revision;
DROP VIEW IF EXISTS reclada.v_import_info;
DROP VIEW IF EXISTS reclada.v_pk_for_class;
DROP VIEW IF EXISTS reclada.v_class;
DROP VIEW IF EXISTS reclada.v_active_object;
DROP VIEW IF EXISTS reclada.v_object;

DROP MATERIALIZED VIEW IF EXISTS reclada.v_object_status;
DROP MATERIALIZED VIEW IF EXISTS reclada.v_user;
DROP MATERIALIZED VIEW IF EXISTS reclada.v_class_lite;

--{view/reclada.v_class_lite}
--{view/reclada.v_object_status}
--{view/reclada.v_user}

--{view/reclada.v_object}
--{view/reclada.v_active_object}
--{view/reclada.v_class}
--{view/reclada.v_pk_for_class}
--{view/reclada.v_import_info}
--{view/reclada.v_revision}

DROP FUNCTION reclada_object.refresh_mv;
DROP FUNCTION reclada_object.datasource_insert;

--{function/reclada_object.create_subclass}
--{function/reclada_object.create}
--{function/reclada_object.update}
--{function/reclada_object.delete}