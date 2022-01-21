/*
 * Function reclada_object.create_subclass creates subclass.
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  class - the name of parent class
 *  attributes - the attributes of objects of the class. The field contains:
 *      forClass - the name of class to create
 *      schema - the schema for the class
 */

DROP FUNCTION IF EXISTS reclada_object.create_subclass;
CREATE OR REPLACE FUNCTION reclada_object.create_subclass(data jsonb)
RETURNS VOID AS $$
DECLARE
    class           jsonb;
    _class          text;
    _properties     jsonb;
    _required       jsonb;
    _parent_list    jsonb := '[]';
    new_class       text;
    attrs           jsonb;
    class_schema    jsonb;
    version_        integer;
    class_guid      uuid;
    _uniFields      jsonb;
    _idx_name       text;
    _f_list         text;
BEGIN

    class := data->'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

    IF (jsonb_typeof(class) != 'array') THEN
        class := '[]'::jsonb || class;
    END IF;

    attrs := data->'attributes';
    IF (attrs IS NULL) THEN
        RAISE EXCEPTION 'The reclada object must have attributes';
    END IF;

    new_class = attrs->>'newClass';
    _properties := coalesce((attrs->'properties'),'{}'::jsonb);
    _required   := coalesce((attrs -> 'required'),'[]'::jsonb);
    FOR _class IN SELECT jsonb_array_elements(class)#>>'{}'
    LOOP

        SELECT reclada_object.get_schema(_class) 
            INTO class_schema;

        IF (class_schema IS NULL) THEN
            RAISE EXCEPTION 'No json schema available for %', _class;
        END IF;

        _properties :=  coalesce((class_schema#>'{attributes,schema,properties}'),'{}'::jsonb) || _properties;

        SELECT jsonb_agg(el) 
            FROM 
            (
                SELECT DISTINCT 
                        pg_catalog.jsonb_array_elements(
                            coalesce(   class_schema#> '{attributes,schema,required}',
                                        'null'::jsonb
                                    ) || _required
                        ) as el
            ) arr
                WHERE jsonb_typeof(el) != 'null'
            INTO _required;

        SELECT class_schema->>'GUID'
            INTO class_guid;
        
        _parent_list := _parent_list || to_jsonb(class_guid);

    END LOOP;
    SELECT max(version) + 1
    FROM reclada.v_class_lite v
    WHERE v.for_class = new_class
    INTO version_;

    version_ := coalesce(version_,1);
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
    new_class,
    version_,
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

