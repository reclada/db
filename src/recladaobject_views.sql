DROP FUNCTION IF EXISTS reclada_object.get_schema(jsonb);
DROP VIEW IF EXISTS reclada.v_class;
DROP VIEW IF EXISTS reclada.v_object;
CREATE OR REPLACE VIEW reclada.v_object
AS
    SELECT data FROM reclada.object obj
    WHERE ((data->'revision')::numeric = (SELECT max((objrev.data->'revision')::numeric)
            FROM reclada.object objrev
            WHERE (objrev.data->'id' = obj.data->'id')
                AND (objrev.data->'isDeleted' = 'false')));
                

CREATE OR REPLACE VIEW reclada.v_class
AS
    SELECT data FROM reclada.v_object obj
    WHERE (data->'class' = '"jsonschema"');

CREATE OR REPLACE FUNCTION reclada_object.get_schema(class jsonb)
RETURNS jsonb AS $$
    SELECT data FROM reclada.v_class
    WHERE (data->'attrs'->'forClass' = class)
    LIMIT 1
$$ LANGUAGE SQL IMMUTABLE;