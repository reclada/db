DROP FUNCTION IF EXISTS reclada.validate_json_schema;
CREATE OR REPLACE FUNCTION reclada.validate_json_schema
(
    _data       jsonb
)
RETURNS void AS $$
DECLARE
    _schema_obj         jsonb;
    _new_data       jsonb;
    _parents        jsonb;
    _attrs          jsonb;
    _class          text ;
    _class_name     text ;
    _class_guid     uuid ;
    _parent         text ;
    _f_name         text = 'reclada.validate_json_schema';
BEGIN

    _class := _data->>'class';

    IF (_class IS NULL) THEN
        perform reclada.raise_exception('The reclada object class is not specified',_f_name);
    END IF;

    _class_guid := reclada.try_cast_uuid(_class);
    
    IF _class_guid IS NULL THEN
        _class_name := _class;
        SELECT reclada_object.get_schema(_class_name) 
            INTO _schema_obj;
        _class_guid := (_schema_obj->>'GUID')::uuid;
    ELSE
        SELECT v.data, v.for_class
            FROM reclada.v_class v
                WHERE _class_guid = v.obj_id
            INTO _schema_obj, _class_name;
    END IF;

    _attrs := _data->'attributes';
    IF (_attrs IS NULL) THEN
        perform reclada.raise_exception('The reclada object must have attributes',_f_name);
    END IF;

    _parents := _schema_obj#>'{attributes,parentList}';

    FOR _parent IN SELECT jsonb_array_elements_text(_parents) 
    LOOP
        _new_data := jsonb_set(_data,'{class}',_parent);
        perform reclada.validate_json_schema(_new_data);
    END LOOP;

    IF (NOT(public.validate_json_schema(_schema_obj #> '{attributes,schema}' , _attrs))) THEN
        perform reclada.raise_exception(format('JSON invalid: %s, schema: %s', 
                                                _attrs #>> '{}'   , 
                                                _schema_obj #>> '{attributes,schema}' 
                                            ),
                                        _f_name);
    END IF;

END;
$$ LANGUAGE PLPGSQL STABLE;