CREATE OR REPLACE FUNCTION load_staging() RETURNS TRIGGER AS $$
DECLARE
    revision    jsonb;
BEGIN
    SELECT format('{"revision": %s}', reclada_revision.create(NULL, NULL))::jsonb INTO revision;
    PERFORM reclada_object.create(data || revision) FROM NEW_TABLE;
    TRUNCATE reclada.staging;
END
$$ LANGUAGE PLPGSQL VOLATILE;

CREATE TRIGGER load_staging
    AFTER INSERT ON reclada.staging
    REFERENCING NEW TABLE AS NEW_TABLE
    FOR EACH STATEMENT EXECUTE FUNCTION load_staging();
