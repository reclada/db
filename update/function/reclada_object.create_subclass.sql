/*
 * Function reclada_object.create_subclass creates subclass.
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  _class_list - the name of parent _class_list
 *  attributes - the attributes of objects of the _class_list. The field contains:
 *      forClass - the name of _class_list to create
 *      schema - the schema for the _class_list
 */

DROP FUNCTION IF EXISTS reclada_object.create_subclass;
CREATE OR REPLACE FUNCTION reclada_object.create_subclass(data jsonb)
RETURNS VOID AS $$
DECLARE
    _class_list     jsonb;
    _class          text;
    _properties     jsonb;
    _p_properties   jsonb;
    _required       jsonb;
    _p_required     jsonb;
    _parent_list    jsonb := '[]';
    _new_class      text;
    attrs           jsonb;
    class_schema    jsonb;
    _version        integer;
    class_guid      uuid;
    _uniFields      jsonb;
    _idx_name       text;
    _f_list         text;
    _field          text;
    _f_name         text = 'reclada_object.create_subclass';
    _partial_clause text;
    _field_name     text;
    _create_obj     jsonb;
BEGIN

    _class_list := data->'class';
    IF (_class_list IS NULL) THEN
        perform reclada.raise_exception('The reclada object class is not specified',_f_name);
    END IF;

    IF (jsonb_typeof(_class_list) != 'array') THEN
        _class_list := '[]'::jsonb || _class_list;
    END IF;

    attrs := data->'attributes';
    IF (attrs IS NULL) THEN
        perform reclada.raise_exception('The reclada object must have attributes',_f_name);
    END IF;

    

    FOR _class IN SELECT jsonb_array_elements_text(_class_list)
    LOOP

        SELECT reclada_object.get_schema(_class) 
            INTO class_schema;

        IF (class_schema IS NULL) THEN
            perform reclada.raise_exception('No json schema available for ' || _class, _f_name);
        END IF;
        
        SELECT class_schema->>'GUID'
            INTO class_guid;
        
        _parent_list := _parent_list || to_jsonb(class_guid);

    END LOOP;

    _new_class = attrs->>'newClass';
   
    SELECT max(version) + 1
    FROM reclada.v_class_lite v
    WHERE v.for_class = _new_class
        INTO _version;

    _version := coalesce(_version,1);
    _properties := coalesce(attrs -> 'properties','{}'::jsonb);
    _required   := coalesce(attrs -> 'required'  ,'[]'::jsonb);
    class_schema := class_schema->'attributes'->'schema';

    _create_obj := format('{
        "class": "jsonschema",
        "attributes": {
            "forClass": "%s",
            "version": "%s",
            "schema": {
                "type": "object",
                "properties": %s,
                "required": %s
            },
            "parentList":%s
        }
    }',
    _new_class,
    _version,
    _properties,
    _required,
    _parent_list
    )::jsonb;
    IF ( jsonb_typeof(attrs->'dupChecking') = 'array' ) THEN
        _create_obj := jsonb_set(_create_obj, '{attributes,dupChecking}',attrs->'dupChecking');
        IF ( jsonb_typeof(attrs->'dupBehavior') = 'string' ) THEN
            _create_obj := jsonb_set(_create_obj, '{attributes,dupBehavior}',attrs->'dupBehavior');
        END IF;
        IF ( jsonb_typeof(attrs->'isCascade') = 'boolean' ) THEN
            _create_obj := jsonb_set(_create_obj, '{attributes,isCascade}',attrs->'isCascade');
        END IF;
        IF ( jsonb_typeof(attrs->'copyField') = 'string' ) THEN
            _create_obj := jsonb_set(_create_obj, '{attributes,copyField}',attrs->'copyField');
        END IF;
    END IF;
    IF ( jsonb_typeof(attrs->'parentField') = 'string' ) THEN
        _create_obj := jsonb_set(_create_obj, '{attributes,parentField}',attrs->'parentField');
    END IF;
    PERFORM reclada_object.create(_create_obj);

    IF ( jsonb_typeof(attrs->'dupChecking') = 'array' ) THEN
        FOR _uniFields IN (
            SELECT jsonb_array_elements(attrs->'dupChecking')->'uniFields'
        ) LOOP
            IF ( jsonb_typeof(_uniFields) = 'array' ) THEN
                SELECT
                    reclada.get_unifield_index_name( array_agg(f ORDER BY f)) AS idx_name, 
                    string_agg('(attributes ->> ''' || f || ''')','||' ORDER BY f) AS fields_list,
                    string_agg('attributes ->> ''' || f || ''' IS NOT NULL',' AND ' ORDER BY f) AS partial_clause
                FROM (
                    SELECT jsonb_array_elements_text (_uniFields) f
                ) a
                    INTO _idx_name, _f_list, _partial_clause;
                IF NOT EXISTS (
                    SELECT 1
                    FROM pg_catalog.pg_indexes pi2 
                    WHERE schemaname ='reclada' AND tablename ='object' AND indexname =_idx_name
                ) THEN
                    EXECUTE E'CREATE INDEX ' || _idx_name || ' ON reclada.object USING HASH ((' || _f_list || ')) WHERE ' || _partial_clause;
                END IF;
            END IF;
        END LOOP;
        PERFORM reclada_object.refresh_mv('uniFields');
    END IF;

END;
$$ LANGUAGE PLPGSQL VOLATILE;

