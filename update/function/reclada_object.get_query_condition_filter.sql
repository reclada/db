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
        or (status_caption in (1,2,5,4))
    )
)
*/

DROP FUNCTION IF EXISTS reclada_object.get_query_condition_filter;
CREATE OR REPLACE FUNCTION reclada_object.get_query_condition_filter( data JSONB )
RETURNS TEXT AS $$
DECLARE 
    _count   INT;
    _res     TEXT;
    _f_name TEXT = 'reclada_object.get_query_condition_filter';
BEGIN 
    
    perform reclada.validate_json(data, _f_name);

    -- TODO: to change VOLATILE -> IMMUTABLE, remove CREATE TEMP TABLE
    CREATE TEMP TABLE mytable AS
        SELECT  lvl             ,  rn   , idx  ,
                upper(op) as op ,  prev , val  ,  
                parsed
            FROM reclada_object.parse_filter(data);

    UPDATE mytable u
        SET parsed = to_jsonb(p.v)
            FROM mytable t
            left join reclada.v_filter_avaliable_operator o
                on o.operator = t.op
            JOIN LATERAL 
            (
                SELECT  t.parsed #>> '{}' v
            ) as pt
                ON TRUE
            LEFT JOIN reclada.v_filter_mapping fm
                ON pt.v = fm.pattern
            JOIN LATERAL 
            (
                SELECT CASE 
                        WHEN fm.repl is not NULL 
                            then '(''"''||' ||fm.repl ||'||''"'')::jsonb' -- don't use FORMAT (concat null)
                        -- WHEN pt.v LIKE '{attributes,%}'
                        --     THEN format('attrs #> ''%s''', REPLACE(pt.v,'{attributes,','{'))
                        WHEN jsonb_typeof(t.parsed) in ('number', 'boolean')
                            then 
                                case 
                                    when o.input_type in ('NUMERIC','INT')
                                        then pt.v
                                    else '''' || pt.v || '''::jsonb'
                                end
                        WHEN jsonb_typeof(t.parsed) = 'string' 
                            then    
                                case
                                    WHEN pt.v LIKE '{%}'
                                        THEN
                                            case
                                                when o.input_type = 'TEXT'
                                                    then format('(data #>> ''%s'')', pt.v)
                                                when o.input_type = 'NUMERIC'
                                                    then format('(data #>> ''%s'')::NUMERIC', pt.v)
                                                when o.input_type = 'INT'
                                                    then format('(data #>> ''%s'')::INT', pt.v)
                                                else
                                                    format('data #> ''%s''', pt.v)
                                            end
                                    when o.input_type = 'TEXT'
                                        then ''''||REPLACE(pt.v,'''','''''')||''''
                                    else
                                        '''"'||REPLACE(pt.v,'''','''''')||'"''::jsonb'
                                end
                        WHEN jsonb_typeof(t.parsed) = 'null'
                            then 'null'
                        WHEN jsonb_typeof(t.parsed) = 'array'
                            then ''''||REPLACE(pt.v,'''','''''')||'''::jsonb'
                        ELSE
                            pt.v
                    END AS v
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
                                    THEN 
                                        CASE o.output_type
                                            when 'NUMERIC'
                                                then format('(%s %s)::TEXT::JSONB', res.op, min(res.parsed #>> '{}') )
                                            else 
                                                format('(%s %s)', res.op, min(res.parsed #>> '{}') )
                                        end
                                ELSE
                                    CASE 
                                        when o.output_type = 'TEXT'
                                            then '(''"''||'||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op)||'||''"'')::JSONB'
                                        when o.output_type in ('NUMERIC','INT')
                                            then '('||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op)||')::TEXT::JSONB'
                                        else
                                            '('||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op)||')'
                                    end
                            end AS converted
                        FROM mytable res 
                        LEFT JOIN reclada.v_filter_avaliable_operator o
                            ON o.operator = res.op
                            WHERE res.parsed IS NOT NULL
                                AND res.lvl = (SELECT max(lvl)+1 FROM mytable WHERE parsed IS NULL)
                            GROUP BY  res.prev, res.op, res.lvl, o.input_type, o.output_type
                ) t
                WHERE
                    t.lvl = mytable.lvl
                        AND t.rn = mytable.rn
                RETURNING 1
        )
            SELECT COUNT(1) 
                FROM r
                INTO _count;
    END LOOP;
    
    SELECT parsed #>> '{}' 
        FROM mytable
            WHERE lvl = 0 AND rn = 0
        INTO _res;
    perform reclada.raise_notice( _res);
    DROP TABLE mytable;
    RETURN _res;
END 
$$ LANGUAGE PLPGSQL VOLATILE;