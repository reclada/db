-- не грохаю, чтобы не поломать триггер
CREATE OR REPLACE FUNCTION reclada.load_staging() 
RETURNS TRIGGER 
AS $$
BEGIN
    PERFORM reclada_object.create(data) 
        FROM NEW_TABLE;
    RETURN NEW;
END
$$ LANGUAGE PLPGSQL VOLATILE;