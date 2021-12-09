DROP FUNCTION IF EXISTS reclada.validate_json;
CREATE OR REPLACE FUNCTION reclada.validate_json
(
    _data       jsonb, 
    _function   text
)
RETURNS void AS $$
DECLARE
    _schema jsonb;
BEGIN

    -- select reclada.raise_exception('JSON invalid: ' || _data >> '{}')
    select schema 
        from reclada.v_DTO_json_schema
            where _function = function
        into _schema;
    
     IF (_schema is null ) then
        RAISE EXCEPTION 'DTOJsonSchema for function: % not found',
                        _function;
    END IF;

    IF (NOT(public.validate_json_schema(_schema, _data))) THEN
        RAISE EXCEPTION 'JSON invalid: %, schema: %, function: %', 
                        _data #>> '{}'   , 
                        _schema #>> '{}' ,
                        _function;
    END IF;
      

END;
$$ LANGUAGE PLPGSQL STABLE;