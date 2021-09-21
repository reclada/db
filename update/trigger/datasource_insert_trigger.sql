DROP TRIGGER IF EXISTS datasource_insert_trigger ON reclada.object;
CREATE TRIGGER datasource_insert_trigger
  BEFORE INSERT
  ON reclada.object FOR EACH ROW
  EXECUTE PROCEDURE reclada.datasource_insert_trigger_fnc();