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

    _new_class = attrs->>'newClass';
    _properties := coalesce(attrs -> 'properties','{}'::jsonb);
    _required   := coalesce(attrs -> 'required'  ,'[]'::jsonb);
    FOR _class IN SELECT jsonb_array_elements_text(_class_list)
    LOOP

        SELECT reclada_object.get_schema(_class) 
            INTO class_schema;

        IF (class_schema IS NULL) THEN
            perform reclada.raise_exception('No json schema available for ' || _class, _f_name);
        END IF;
        
        _p_properties := coalesce(class_schema#>'{attributes,schema,properties}','{}'::jsonb);
        SELECT key
            FROM 
            (
                SELECT  je.key, 1 id
                    FROM jsonb_each(_p_properties) je
                UNION -- TODO: INTERSECT
                SELECT  je.key, 2 id
                    FROM jsonb_each(  _properties) je
            ) t
                GROUP BY key
                HAVING COUNT(*) > 1
                limit 1
            into _field;
        if _field is not null THEN
            perform reclada.raise_exception('Field "'|| _field ||'" conflicts with class: ' || _class, _f_name);
        END IF;
        _properties :=  _p_properties || _properties;

        _p_required := coalesce(class_schema#> '{attributes,schema,required}','[]'::jsonb );
        SELECT t.value
            FROM 
            (
                SELECT  je.value, 1 id
                    FROM jsonb_array_elements(_p_required) je
                UNION -- TODO: INTERSECT
                SELECT  je.value, 2 id
                    FROM jsonb_array_elements(  _required) je
            ) t
                GROUP BY t.value
                HAVING COUNT(*) > 1
                limit 1
            into _field;
        if _field is not null THEN
            perform reclada.raise_exception('Required "'|| _field ||'" conflicts with class: ' || _class, _f_name);
        END IF;
        _required :=  _p_required || _required;

        SELECT class_schema->>'GUID'
            INTO class_guid;
        
        _parent_list := _parent_list || to_jsonb(class_guid);

    END LOOP;
    SELECT max(version) + 1
    FROM reclada.v_class_lite v
    WHERE v.for_class = _new_class
    INTO _version;

    _version := coalesce(_version,1);
    _properties := coalesce(attrs -> 'properties','{}'::jsonb);
    _required   := coalesce(attrs -> 'required'  ,'[]'::jsonb);
    class_schema := class_schema->'attributes'->'schema';

    PERFORM reclada_object.create(format('{
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
    )::jsonb);

    IF ( jsonb_typeof(attrs->'dupChecking') = 'array' ) THEN
        FOR _uniFields IN (
            SELECT jsonb_array_elements(attrs->'dupChecking')->'uniFields'
        ) LOOP
            IF ( jsonb_typeof(_uniFields) = 'array' ) THEN
                SELECT
                    reclada.get_unifield_index_name( array_agg(f ORDER BY f)) AS idx_name, 
                    string_agg('(attributes ->> ''' || f || ''')','||' ORDER BY f) AS fields_list
                FROM (
                    SELECT jsonb_array_elements_text (_uniFields::jsonb) f
                ) a
                    INTO _idx_name, _f_list;
                IF NOT EXISTS (
                    SELECT 1
                    FROM pg_catalog.pg_indexes pi2 
                    WHERE schemaname ='reclada' AND tablename ='object' AND indexname =_idx_name
                ) THEN
                    EXECUTE E'CREATE INDEX ' || _idx_name || ' ON reclada.object USING HASH ((' || _f_list || '))';
                END IF;
            END IF;
        END LOOP;
        PERFORM reclada_object.refresh_mv('uniFields');
    END IF;

END;
$$ LANGUAGE PLPGSQL VOLATILE;

