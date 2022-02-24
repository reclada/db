CREATE OR REPLACE FUNCTION reclada.load_staging() 
RETURNS TRIGGER 
AS $$
DECLARE
    _data_agg jsonb;
    _batch_size bigint;
    _length_data bigint;
BEGIN
    _batch_size := 1000;
    SELECT COUNT(data)
        FROM NEW_TABLE
        INTO _length_data;
    --add row_number() over(order by data) as id
    FOR i IN 1..ceiling(_length_data / _batch_size) LOOP -- refact
        SELECT jsonb_agg(data)
            FROM NEW_TABLE
            WHERE ((i - 1)  * 1000) < id <= (i * 1000)
            INTO _data_agg;
        PERFORM reclada_object.create(_data_agg);
    END LOOP;
    RETURN NEW;
    TRUNCATE TABLE NEW_TABLE;
END
$$ LANGUAGE PLPGSQL VOLATILE;