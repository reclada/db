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
CREATE OR REPLACE FUNCTION reclada_object.get_query_condition_filter(data JSONB, schema JSONB default null)
RETURNS TEXT AS $$
DECLARE 
    _count   INT;
    _res     TEXT;
    _f_name TEXT = 'reclada_object.get_query_condition_filter';
BEGIN 
    
    perform reclada.validate_json(data, _f_name);
    schema := '{"GUID": "c7fc0455-0572-40d7-987f-583cc2c9630c", "class": "5362d59b-82a1-4c7c-8ec3-07c256009fb0", "status": "active", "attributes": {"schema": {"type": "object", "required": ["checksum", "name", "mimeType"], "properties": {"uri": {"type": "string"}, "name": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "disable": {"type": "boolean", "default": false}, "checksum": {"type": "string"}, "mimeType": {"type": "string"}}}, "version": "1", "forClass": "File"}, "parentGUID": null, "createdTime": "2021-10-04T11:06:30.979167+03:00", "transactionID": 58}'::jsonb;
    -- TODO: to change VOLATILE -> IMMUTABLE, remove CREATE TEMP TABLE
    CREATE TEMP TABLE mytable AS
        SELECT  res.lvl              AS lvl         , 
                res.rn               AS rn          , 
                res.idx              AS idx         ,
                res.prev             AS prev        , 
                res.val              AS val         ,  
                res.parsed           AS parsed      , 
                coalesce(
                    po.inner_operator, 
                    op.operator
                )                   AS op           , 
                coalesce
                (
                    iop.input_type,
                    op.input_type
                )                   AS input_type   ,
                case 
                    when iop.input_type is not NULL 
                        then NULL 
                    else 
                        op.output_type
                end                 AS output_type  ,
                po.operator         AS po           ,
                po.input_type       AS po_input_type,
                iop.brackets        AS po_inner_brackets
            FROM reclada_object.parse_filter(data) res
            LEFT JOIN reclada.v_filter_avaliable_operator op
                ON res.op = op.operator
            LEFT JOIN reclada_object.parse_filter(data) p
                on  p.lvl = res.lvl-1
                    and res.prev = p.rn
            LEFT JOIN reclada.v_filter_avaliable_operator po
                on po.operator = p.op
            LEFT JOIN reclada.v_filter_inner_operator iop
                on iop.operator = po.inner_operator;

    PERFORM reclada.raise_exception('Operator is not allowed ' || t.op, _f_name)
        FROM mytable t
            WHERE t.op IS NULL;


    UPDATE mytable u
        SET parsed = to_jsonb(p.v)
            FROM mytable t
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
                            then 
                                case 
                                    when t.input_type in ('TEXT')
                                        then fm.repl || '::TEXT'
                                    else '(''"''||' ||fm.repl ||'||''"'')::jsonb' -- don't use FORMAT (concat null)
                                end
                        WHEN jsonb_typeof(t.parsed) in ('number', 'boolean')
                            then 
                                case 
                                    when t.input_type in ('NUMERIC','INT')
                                        then pt.v
                                    else '''' || pt.v || '''::jsonb'
                                end
                        WHEN jsonb_typeof(t.parsed) = 'string' 
                            then    
                                case
                                    WHEN pt.v LIKE '{%}'
                                        THEN
                                            case
                                                when t.input_type = 'TEXT'
                                                    then
                                                        case
                                                            when schema is null
                                                                then format('(data #>> ''%s'')', pt.v)
                                                            else format('reclada_object.get_value_or_default(data,''%s'',', pt.v)
                                                                 --   || format('''%s''::jsonb)', schema)
                                                                 --replace(
                                                                 --   format('reclada_object.get_value_or_default(data,''%s'',', pt.v)
                                                                 --   || format('''%s''::jsonb)', schema),
                                                                 --   '>', '>>')
                                                        end
                                                when t.input_type = 'JSONB' or t.input_type is null
                                                    then
                                                        case
                                                            when schema is null
                                                                then format('data #> ''%s''', pt.v)
                                                            else format('reclada_object.get_value_or_default(data,''%s'',''%s''::jsonb)', pt.v, schema)
                                                        end
                                                    else
                                                        case
                                                            when schema is null
                                                                then format('(data #>> ''%s'')::', pt.v) || t.input_type
                                                            else replace(
                                                                    format('reclada_object.get_value_or_default(data,''%s'',', pt.v)
                                                                    || format('''%s''::jsonb)::', schema) || t.input_type,
                                                                    '>', '>>')
                                                        end
                                            end
                                    when t.input_type = 'TEXT'
                                        then ''''||REPLACE(pt.v,'''','''''')||''''
                                    when t.input_type = 'JSONB' or t.input_type is null
                                        then '''"'||REPLACE(pt.v,'''','''''')||'"''::jsonb'
                                    else ''''||REPLACE(pt.v,'''','''''')||'''::'||t.input_type
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

    update mytable u
        set op = CASE 
                    when f.btwn
                        then ' BETWEEN '
                    else u.op -- f.inop
                end,
            parsed = format(vb.operand_format,u.parsed)::jsonb
        FROM mytable t
        join lateral
        (
            select  t.op like ' %/BETWEEN ' btwn, 
                    t.po_inner_brackets is not null inop
        ) f 
            on true
        join reclada.v_filter_between vb
            on t.op = vb.operator
            WHERE t.lvl = u.lvl
                AND t.rn = u.rn
                AND (f.btwn or f.inop);

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
                            case 
                                when not res.po_inner_brackets 
                                    then array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op) 
                                else
                                    CASE COUNT(1) 
                                        WHEN 1
                                            THEN 
                                                CASE res.output_type
                                                    when 'NUMERIC'
                                                        then format('(%s %s)::TEXT::JSONB', res.op, min(res.parsed #>> '{}') )
                                                    else 
                                                        format('(%s %s)', res.op, min(res.parsed #>> '{}') )
                                                end
                                        ELSE
                                            CASE 
                                                when res.output_type = 'TEXT'
                                                    then '(''"''||'||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op) ||'||''"'')::JSONB'
                                                when res.output_type in ('NUMERIC','INT')
                                                    then '('||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op) ||')::TEXT::JSONB'
                                                else
                                                    '('||array_to_string(array_agg(res.parsed #>> '{}' ORDER BY res.rn), res.op) ||')'
                                            end
                                    end
                            end AS converted
                        FROM mytable res 
                            WHERE res.parsed IS NOT NULL
                                AND res.lvl = (SELECT max(lvl)+1 FROM mytable WHERE parsed IS NULL)
                            GROUP BY  res.prev, res.op, res.lvl, res.input_type, res.output_type, res.po_inner_brackets
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
    -- perform reclada.raise_notice( _res);
    DROP TABLE mytable;
    RETURN _res;
END 
$$ LANGUAGE PLPGSQL VOLATILE;