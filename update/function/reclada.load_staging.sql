-- не грохаю, чтобы не поломать триггер
CREATE OR REPLACE FUNCTION reclada.load_staging() 
RETURNS TRIGGER 
AS $$
-- DECLARE
--     revision    jsonb;
BEGIN
    -- reclada_object.create создаст ревизию одну для всех объектов
    -- SELECT  format('{"revision": %s}', 
    --         reclada_revision.create(NULL, NULL))::jsonb 
    --     INTO revision;
    PERFORM reclada_object.create(data /*|| revision*/) 
        FROM NEW_TABLE;
    RETURN NEW;
END
$$ LANGUAGE PLPGSQL VOLATILE;