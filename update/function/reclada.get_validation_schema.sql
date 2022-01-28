--DROP FUNCTION IF EXISTS reclada.get_validation_schema;
CREATE OR REPLACE FUNCTION reclada.get_validation_schema
(
    class_guid uuid
)
RETURNS jsonb
AS $$
DECLARE
    _schema_obj     jsonb;
    _parent         uuid ;
    _res            jsonb = '{}'::jsonb;
    _f_name         text = 'reclada.get_validation_schema';
BEGIN

    SELECT reclada_object.get_schema(class_guid::text) 
        INTO _schema_obj;

    IF (_schema_obj IS NULL) THEN
        perform reclada.raise_exception('No json schema available for ' || class_guid, _f_name);
    END IF;

    FOR _parent IN SELECT jsonb_array_elements_text(_schema_obj#>'{attributes,parentList}') 
    LOOP
        _res := reclada_object.merge(_res, reclada.get_validation_schema(_parent));
    END LOOP;
    
    _res := reclada_object.merge(_res, _schema_obj#>'{attributes,schema}');

    return _res;
END;
$$ LANGUAGE PLPGSQL STABLE;