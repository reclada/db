-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

--{function/reclada_object.create}

CREATE TABLE reclada.staging(
    data    jsonb   NOT NULL
);
\i 'function/reclada.load_staging'
\i 'view/reclada.staging'
\i 'trigger/load_staging'
