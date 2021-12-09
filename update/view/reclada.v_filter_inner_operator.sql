drop VIEW if EXISTS reclada.v_filter_inner_operator;
CREATE OR REPLACE VIEW reclada.v_filter_inner_operator
AS
    SELECT       ' , ' AS operator, 'JSONB' AS input_type       , true as brackets  
    UNION SELECT ' AND '          , 'TIMESTAMP WITH TIME ZONE'  , false
;
    