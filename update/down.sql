-- you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script


--{function/reclada_object.list}

DROP TRIGGER load_staging on reclada.staging;

--{function/reclada.load_staging}
DROP TABLE reclada.staging;

--{view/reclada.staging}
--{trigger/load_staging}

