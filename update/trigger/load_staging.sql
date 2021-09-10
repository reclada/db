DROP TRIGGER IF EXISTS load_staging ON reclada.staging;
CREATE TRIGGER load_staging
    INSTEAD OF INSERT ON reclada.staging
    FOR EACH ROW EXECUTE FUNCTION reclada.load_staging();
