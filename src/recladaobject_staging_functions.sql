CREATE OR REPLACE FUNCTION reclada.load_staging() RETURNS TRIGGER AS $$
DECLARE
    revision    jsonb;
BEGIN
    SELECT format('{"revision": %s}', reclada_revision.create(NULL, NULL))::jsonb INTO revision;
    PERFORM reclada_object.create(data || revision) FROM NEW_TABLE;
    RETURN NEW;
END
$$ LANGUAGE PLPGSQL VOLATILE;

DROP TRIGGER IF EXISTS load_staging ON reclada.staging;

CREATE TRIGGER load_staging
    AFTER INSERT ON reclada.staging
    REFERENCING NEW TABLE AS NEW_TABLE
    FOR EACH STATEMENT EXECUTE FUNCTION load_staging();
