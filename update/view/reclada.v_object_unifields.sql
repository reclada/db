DROP MATERIALIZED VIEW IF EXISTS reclada.v_object_unifields;
CREATE MATERIALIZED VIEW reclada.v_object_unifields
AS
    SELECT
        for_class,
        class_uuid,
        dup_behavior,
        CASE ismandatory 
            WHEN 'true' THEN true
            WHEN 'false' THEN false
            ELSE null
        END AS is_mandatory,
        uf as unifield,
        uni_number,
        row_number() OVER (PARTITION BY for_class,uni_number ORDER BY uf) AS field_number
    FROM
        (
        SELECT
            for_class,
            obj_id as class_uuid,
            dup_behavior,
            dc->>'isMandatory' AS isMandatory,
            jsonb_array_elements_text(dc->'uniFields') AS uf,
            dc->'uniFields'::text AS field_list,
            row_number() OVER ( PARTITION BY for_class ORDER BY dc->'uniFields'::text) AS uni_number
        FROM
            (
            SELECT
                for_class,
                attrs->'schema'->'properties'->'dupBehavior' AS dup_behavior,
                jsonb_array_elements( attrs -> 'schema'->'properties'->'dupChecking') AS dc,
                obj_id
            FROM
                reclada.v_class vc
            WHERE
                attrs -> 'schema'->'properties'->'dupChecking' is not null
            ) a
        ORDER BY
            uf
        ) b
;
CREATE INDEX object_unifields_class_index ON reclada.v_object_unifields USING btree (for_class);
CREATE INDEX object_unifields_uuid_index ON reclada.v_object_unifields USING btree (class_uuid);
ANALYZE reclada.v_object_unifields;