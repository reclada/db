DROP FUNCTION IF EXISTS reclada_object.parse_filter;
CREATE OR REPLACE FUNCTION reclada_object.parse_filter( data JSONB )
RETURNS TABLE
(
    lvl	   INTEGER ,
    rn	   BIGINT  ,
    idx    BIGINT  ,
    op	   TEXT    ,
    prev   BIGINT  ,
    val	   JSONB   ,
    parsed JSONB
) 
AS $$
    WITH RECURSIVE f AS 
    (
        SELECT data AS v
    ),
    pr AS 
    (
        SELECT 	format(' %s ',f.v->>'operator') AS op, 
                val.v AS val,
                1 AS lvl,
                row_number() OVER(ORDER BY idx) AS rn,
                val.idx idx,
                0::BIGINT prev
            FROM f, jsonb_array_elements(f.v->'value') WITH ordinality AS val(v, idx)
    ),
    res AS
    (	
        SELECT 	pr.lvl	,
                pr.rn	,
                pr.idx  ,
                pr.op	,
                pr.prev ,
                pr.val	,
                CASE jsonb_typeof(pr.val) 
                    WHEN 'object'	
                        THEN NULL
                    ELSE pr.val
                END AS parsed
            FROM pr
            WHERE prev = 0 
                AND lvl = 1
        UNION ALL
        SELECT 	ttt.lvl	,
                ROW_NUMBER() OVER(ORDER BY ttt.idx) AS rn,
                ttt.idx,
                ttt.op	,
                ttt.prev,
                ttt.val ,
                CASE jsonb_typeof(ttt.val) 
                    WHEN 'object'	
                        THEN NULL
                    ELSE ttt.val
                end AS parsed
            FROM
            (
                SELECT 	res.lvl + 1 AS lvl,
                        format(' %s ',res.val->>'operator') AS op,
                        res.rn AS prev	,
                        val.v  AS val,
                        val.idx
                    FROM res, 
                         jsonb_array_elements(res.val->'value') WITH ordinality AS val(v, idx)
            ) ttt
    )
    SELECT 	r.lvl	,
            r.rn	,
            r.idx   ,
            case upper(r.op) 
                when ' XOR '
                    then ' OPERATOR(reclada.##) ' 
                else upper(r.op) 
            end,
            r.prev  ,
            r.val	,
            r.parsed
        FROM res r
$$ LANGUAGE SQL IMMUTABLE;
