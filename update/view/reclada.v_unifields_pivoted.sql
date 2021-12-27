DROP VIEW IF EXISTS reclada.v_unifields_pivoted;
CREATE OR REPLACE VIEW reclada.v_unifields_pivoted AS
SELECT
    class_uuid,
    uni_number,
    dup_behavior,
    is_cascade,
    MAX(CASE WHEN field_number = 1 THEN unifield END) AS f1,
    MAX(CASE WHEN field_number = 2 THEN unifield END) AS f2,
    MAX(CASE WHEN field_number = 3 THEN unifield END) AS f3,
    MAX(CASE WHEN field_number = 4 THEN unifield END) AS f4,
    MAX(CASE WHEN field_number = 5 THEN unifield END) AS f5,
    MAX(CASE WHEN field_number = 6 THEN unifield END) AS f6,
    MAX(CASE WHEN field_number = 7 THEN unifield END) AS f7,
    MAX(CASE WHEN field_number = 8 THEN unifield END) AS f8
FROM v_object_unifields vou
WHERE is_mandatory
GROUP BY class_uuid, uni_number, dup_behavior,is_cascade
ORDER BY class_uuid, uni_number, dup_behavior;