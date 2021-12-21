DROP VIEW IF EXISTS reclada.v_unifields_idx_cnt;
CREATE OR REPLACE VIEW reclada.v_unifields_idx_cnt
AS
    SELECT
        uni_code as unifields_index_name,
        for_class,
        class_uuid,
        count(*) OVER (PARTITION BY uni_code) AS cnt
    FROM
        (
        SELECT
            for_class,
            class_uuid,
            reclada.get_unifield_index_name(array_agg(unifield ORDER BY field_number)) AS uni_code,
            uni_number
        FROM
            reclada.v_object_unifields
        GROUP BY
            for_class,
            class_uuid,
            uni_number
        ) a
;
