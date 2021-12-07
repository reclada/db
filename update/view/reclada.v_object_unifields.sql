DROP MATERIALIZED VIEW IF EXISTS reclada.v_object_unifields;
CREATE MATERIALIZED VIEW reclada.v_object_unifields
AS
    SELECT
        for_class,
        class_uuid,
        CAST (dup_behavior AS reclada.dp_bhvr) AS dup_behavior,
        is_cascade,
        is_mandatory,
        uf as unifield,
        uni_number,
        row_number() OVER (PARTITION BY for_class,uni_number ORDER BY uf) AS field_number
    FROM
        (
        SELECT
            for_class,
            obj_id                                      AS class_uuid,
            dup_behavior,
            is_cascade::boolean                         AS is_cascade,
            (dc->>'isMandatory')::boolean               AS is_mandatory,
            jsonb_array_elements_text(dc->'uniFields')  AS uf,
            dc->'uniFields'::text                       AS field_list,
            row_number() OVER ( PARTITION BY for_class ORDER BY dc->'uniFields'::text) AS uni_number
        FROM
            (
            SELECT
                for_class,
                attrs->>'dupBehavior'           AS dup_behavior,
                (attrs->>'isCascade')           AS is_cascade,
                jsonb_array_elements( attrs ->'dupChecking') AS dc,
                obj_id
            FROM
                reclada.v_class vc
            WHERE
                attrs ->'dupChecking' is not null
            ) a
        ORDER BY
            uf
        ) b
;
ANALYZE reclada.v_object_unifields;