DROP VIEW IF EXISTS reclada.v_parent_field;
CREATE OR REPLACE VIEW reclada.v_parent_field AS
    SELECT
        for_class,
        obj_id as class_uuid,
        attributes->>'parentField' AS parent_field
    FROM reclada.v_class_lite v_class
    WHERE attributes->>'parentField' IS NOT NULL;