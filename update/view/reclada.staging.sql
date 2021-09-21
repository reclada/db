DROP VIEW IF EXISTS reclada.staging;
CREATE OR REPLACE VIEW reclada.staging
AS
    SELECT  '{}'::jsonb as data
   	WHERE false;
-- SELECT * from reclada.staging
