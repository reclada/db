DROP VIEW IF EXISTS reclada.v_get_duplicates_query;
CREATE OR REPLACE VIEW reclada.v_get_duplicates_query
AS
SELECT
'SELECT ''
    SELECT vao.obj_id, 
            '''''' || dup_behavior || ''''''::dp_bhvr,
            '' || is_cascade || '',
            '' || COALESCE (copy_field,'''''''''''') ||'' FROM reclada.v_active_object vao WHERE '' ||  string_agg(predicate, '' OR '') @#@#@exclude_uuid@#@#@
          FROM (SELECT string_agg(''(vao.attrs ->>'''''' || unifield || '''''')'', ''||'' ORDER BY field_number) || ''='''''' || string_agg(COALESCE((''@#@#@attrs@#@#@''::jsonb) ->> unifield,''''),''''  ORDER BY field_number) || '''''''' AS predicate,
          dup_behavior , is_cascade , copy_field
          FROM reclada.v_object_unifields vou 
          WHERE class_uuid = ''@#@#@class_uuid@#@#@''
            AND is_mandatory
          GROUP BY uni_number, dup_behavior , is_cascade , copy_field) a
         GROUP BY dup_behavior , is_cascade , copy_field
' AS val
;