-- version = 27
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

DELETE FROM reclada.object
WHERE GUID IS NULL;

ALTER TABLE reclada.object
    ALTER COLUMN GUID SET NOT NULL;
ALTER TABLE reclada.object
    ALTER GUID SET DEFAULT public.uuid_generate_v4();
