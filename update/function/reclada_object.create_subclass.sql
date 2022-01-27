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
        RAISE EXCEPTION 'The reclada object must have attributes';
    END IF;

    IF attrs #>'{properties, default}' IS NOT NULL THEN
        RAISE EXCEPTION 'Cannot use reserved words for field name';
    END IF;

    new_class = attrs->>'newClass';
    _properties := coalesce((attrs->'properties'),'{}'::jsonb);
    _required   := coalesce((attrs -> 'required'),'[]'::jsonb);
    FOR _class IN SELECT jsonb_array_elements_text(_class_list)
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
    new_class,
    version_,
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

    FOR _field_name IN 
        SELECT DISTINCT el
        FROM pg_catalog.jsonb_array_elements_text(
                (class_schema -> 'required') || coalesce((attrs -> 'required'),'[]'::jsonb)
            ) el
        WHERE NOT EXISTS (
            SELECT relname, ind_expr
            FROM (
                SELECT i.relname, pg_get_expr(ix.indexprs, ix.indrelid) AS ind_expr
                FROM pg_index ix
                JOIN pg_class i ON i.oid = ix.indexrelid 
                JOIN pg_class t ON t.oid = ix.indrelid 
                WHERE t.relname = 'object'
                AND ix.indexprs IS NOT NULL
            ) a
            WHERE
                length(ind_expr) - length(REPLACE(ind_expr,'->>',''))= 3
                AND strpos(ind_expr,el) > 0
        )
    LOOP
        EXECUTE E'CREATE INDEX ' || _field_name || '_index_ ON reclada.object USING BTREE (( attributes ->>''' || _field_name || ''')) WHERE attributes ->>''' || _field_name || ''' IS NOT NULL';
    END LOOP;

END;
$$ LANGUAGE PLPGSQL VOLATILE;

