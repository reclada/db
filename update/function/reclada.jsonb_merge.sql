/*
 * Auxiliary function reclada.jsonb_merge merges two jsonb.
 * If two jsonb have the same key the value from the first jsonb will be returned.
*/
DROP FUNCTION IF EXISTS reclada.jsonb_merge;
CREATE OR REPLACE FUNCTION reclada.jsonb_merge(current_data jsonb,new_data jsonb default null)
RETURNS jsonb AS $$
    SELECT CASE jsonb_typeof(current_data)
        WHEN 'object' THEN
            CASE jsonb_typeof(new_data)
                WHEN 'object' THEN (
                    SELECT jsonb_object_agg(k,
                        CASE
                            WHEN e2.v IS NULL THEN e1.v
                            WHEN e1.v IS NULL THEN e2.v
                            WHEN e1.v = e2.v THEN e1.v
                            ELSE reclada.jsonb_merge(e1.v, e2.v)
                        END)
                    FROM jsonb_each(current_data) e1(k, v)
                        FULL JOIN jsonb_each(new_data) e2(k, v) USING (k)
                )
                ELSE current_data
            END
        WHEN 'array' THEN current_data || new_data
        ELSE current_data
    END
$$ LANGUAGE SQL IMMUTABLE;