--DROP FUNCTION IF EXISTS reclada.get_validation_schema;
CREATE OR REPLACE FUNCTION reclada.get_validation_schema
(
    class_guid uuid
)
RETURNS jsonb
AS $$
DECLARE
    _schema_obj     jsonb;
    _properties     jsonb = '{}'::jsonb;
    _required       jsonb = '[]'::jsonb;
    _defs           jsonb = '{}'::jsonb;
    _parent_schema  jsonb ;
    _parent_list    jsonb ;
    _parent         uuid ;
    _res            jsonb = '{}'::jsonb;
    _f_name         text = 'reclada.get_validation_schema';
BEGIN

    SELECT reclada_object.get_schema(class_guid::text) 
        INTO _schema_obj;

    IF (_schema_obj IS NULL) THEN
        perform reclada.raise_exception('No json schema available for ' || class_guid, _f_name);
    END IF;

    _parent_list = _schema_obj#>'{attributes,parentList}';

    FOR _parent IN SELECT jsonb_array_elements_text(_parent_list ) 
    LOOP
        _parent_schema := reclada.get_validation_schema(_parent);
        _properties := _properties || coalesce((_parent_schema->'properties'),'{}'::jsonb);
        _defs       := _defs       || coalesce((_parent_schema->'$defs'     ),'{}'::jsonb);
        _required   := _required   || coalesce((_parent_schema->'required'  ),'[]'::jsonb);
        _res := _res || _parent_schema ;  
    END LOOP;
    
    _parent_schema := _schema_obj#>'{attributes,schema}';
    _properties := _properties || coalesce((_parent_schema->'properties'),'{}'::jsonb);
    _defs       := _defs       || coalesce((_parent_schema->'$defs'     ),'{}'::jsonb);
    _required   := _required   || coalesce((_parent_schema->'required'  ),'[]'::jsonb);
    _res := _res || _parent_schema ;  
    _res := _res || jsonb_build_object( 'required'  , _required,
                                        '$defs'     , _defs    ,
                                        'properties', _properties);
    return _res;
END;
$$ LANGUAGE PLPGSQL STABLE;