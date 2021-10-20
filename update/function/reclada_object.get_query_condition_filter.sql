/*
select reclada_object.get_query_condition_filter('
{
    "operator":"not",
    "value":
        [
        {
            "operator":"and",
            "value":[
                {
                    "operator":"like",
                    "value":["class","dcdc%"]
                },
                {
                    "operator":"or",
                    "value":[
                        {
                            "operator":"=",
                            "value":["guid","dfdf"]
                        }, 
                        {
                            "operator":"in",
                            "value":["''attributes''->''revision''","(1,2,3,4)"]
                        },
                        {
                            "operator":"in",
                            "value":["''attributes''->''revision''","(1,2,5,4)"]
                        }
                    ]
                }
            ]
        }
    ]
    
}'::jsonb)

result: 
( not  ((class like dcdc%) and ((guid = dfdf) or ('attributes'->'revision' in (1,2,3,4)) or ('attributes'->'revision' in (1,2,5,4)))))

select reclada_object.get_query_condition_filter('
{

    "operator":"and",
    "value":[
        {
            "operator":"like",
            "value":["{class}","dcdc%"]
        },
        {
            "operator":"or",
            "value":[
                {
                    "operator":"=",
                    "value":["{GUID}","dfdf"]
                }, 
                {
                    "operator":"in",
                    "value":["{attributes,revision}","(''1'',2,3,4)"]
                },
                {
                    "operator":"in",
                    "value":["{status}","(1,2,5,4)"]
                }
            ]
        }
    ]

}'::jsonb)
result:
(
    (class_name like dcdc%) 
    and 
    (
        (obj_id = dfdf) 
        or (attrs #>> ''{revision}'' in (''1'',2,3,4)) 
        or (status_caption in (1,2,5,4))))
*/

DROP FUNCTION IF EXISTS reclada_object.get_query_condition_filter;
CREATE OR REPLACE FUNCTION reclada_object.get_query_condition_filter( data JSONB )
RETURNS TEXT AS $$
DECLARE 
    _count   INT;
    _res     TEXT;
BEGIN 
    -- TODO: to change VOLATILE -> IMMUTABLE, remove CREATE TEMP TABLE
    CREATE TEMP TABLE mytable AS
        SELECT  lvl  ,  rn   , idx  ,
                op   ,  prev , val  ,  
                parsed
            FROM reclada_object.parse_filter(data);

    UPDATE mytable u
        SET parsed = to_jsonb(p.v)
            FROM mytable t
            JOIN LATERAL 
            (
                SELECT t.parsed #>> '{}' v
            ) as pt
                ON TRUE
            JOIN LATERAL 
            (
                SELECT CASE 
                        WHEN pt.v LIKE '{class}'
                            THEN 'class_name'
                        WHEN pt.v LIKE '%{%}%'
                            THEN REPLACE(
                                    REPLACE(pt.v,'{','data #>> ''{'),
                                '}','}''')
                        WHEN pt.v LIKE '(%)'
                            THEN REPLACE(
                                    REPLACE(
                                        REPLACE(pt.v,'(','(''')
                                    ,')',''')')
                                ,',',''',''')
                        ELSE
                            ''''||pt.v||''''
                    END AS v
                /*
                SELECT CASE 
                        WHEN pt.v LIKE '{attributes,%}'
                            THEN format('attrs #>> ''''%s''''', REPLACE(pt.v,'{attributes,','{'))
                        WHEN pt.v LIKE '{class}'
                            THEN 'class_name'
                        WHEN pt.v LIKE '{GUID}'
                            THEN 'obj_id'
                        WHEN pt.v LIKE '{status}'
                            THEN 'status_caption'
                        WHEN pt.v LIKE '(%)'
                            THEN replace(
                                    replace(
                                        replace(pt.v,'(','(''')
                                    ,')',''')')
                                ,',',''',''')
                        WHEN pt.v LIKE '{transactionID}'
                            THEN 'transaction_id'
                        WHEN pt.v LIKE '{%}'
                            THEN 'transaction_id'
                        ELSE
                            ''''||pt.v||''''
                    END AS v
                */
            ) as p
                ON TRUE
            WHERE t.lvl = u.lvl
                AND t.rn = u.rn
                AND t.parsed IS NOT NULL;
                

    INSERT INTO mytable (lvl,rn)
        VALUES (0,0);
    
    _count := 1;
    
    WHILE (_count>0) LOOP
        WITH r AS 
        (
            UPDATE mytable
                SET parsed = to_json(t.converted)::JSONB 
                FROM 
                (
                    SELECT     
                            res.lvl-1 lvl,
                            res.prev rn,
                            res.op,
                            1 q,
                            CASE COUNT(1) 
                                WHEN 1
                                    THEN format('(%s %s)', res.op, min(res.parsed #>> '{}') )
                                ELSE
                                    '('||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op)||')'
                            end AS converted
                        FROM mytable res 
                            WHERE res.parsed IS NOT NULL
                                AND res.lvl = (SELECT max(lvl)+1 FROM mytable WHERE parsed IS NULL)
                            GROUP BY  res.prev, res.op, res.lvl
                ) t
                WHERE
                    t.lvl = mytable.lvl
                        AND t.rn = mytable.rn
                RETURNING 1
        )
            SELECT COUNT(*) 
                FROM r
                INTO _count;
    END LOOP;
    
    SELECT parsed #>> '{}' 
        FROM mytable
            WHERE lvl = 0 AND rn = 0
        INTO _res;
    
    DROP TABLE mytable;
    RETURN _res;
END 
$$ LANGUAGE PLPGSQL VOLATILE;