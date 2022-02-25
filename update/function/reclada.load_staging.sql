CREATE OR REPLACE FUNCTION reclada.load_staging() 
RETURNS TRIGGER 
AS $$
DECLARE
    _data_agg jsonb;
    _batch_size bigint := 1000;
BEGIN
    FOR _data_agg IN (select jsonb_agg(vrn.data)	  
                        from (
                            select data,
                                ROUND((ROW_NUMBER()OVER()-1)/_batch_size) AS rn
                                from NEW_TABLE
                        ) vrn
                        group by vrn.rn
                     ) 
    LOOP 
        PERFORM reclada_object.create(_data_agg);
    END LOOP;
    RETURN NEW;
    TRUNCATE TABLE NEW_TABLE;
END
$$ LANGUAGE PLPGSQL VOLATILE;