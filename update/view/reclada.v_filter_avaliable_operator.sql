drop VIEW if EXISTS reclada.v_filter_avaliable_operator;
CREATE OR REPLACE VIEW reclada.v_filter_avaliable_operator
AS
    SELECT       ' = ' AS operator  , 'JSONB' AS input_type , 'BOOL' AS output_type
    UNION SELECT ' LIKE '           , 'TEXT'    , 'BOOL'
    UNION SELECT ' NOT LIKE '       , 'TEXT'    , 'BOOL'
    UNION SELECT ' || '             , 'TEXT'    , 'TEXT'
    UNION SELECT ' ~ '              , 'TEXT'    , 'BOOL'
    UNION SELECT ' !~ '             , 'TEXT'    , 'BOOL'
    UNION SELECT ' ~* '             , 'TEXT'    , 'BOOL'
    UNION SELECT ' !~* '            , 'TEXT'    , 'BOOL'
    UNION SELECT ' SIMILAR TO '     , 'TEXT'    , 'BOOL'
    UNION SELECT ' > '              , 'JSONB'   , 'BOOL'
    UNION SELECT ' < '              , 'JSONB'   , 'BOOL'
    UNION SELECT ' <= '             , 'JSONB'   , 'BOOL'  
    UNION SELECT ' != '             , 'JSONB'   , 'BOOL'
    UNION SELECT ' >= '             , 'JSONB'   , 'BOOL'
    UNION SELECT ' AND '            , 'BOOL'    , 'BOOL'     
    UNION SELECT ' OR '             , 'BOOL'    , 'BOOL'
    UNION SELECT ' NOT '            , 'BOOL'    , 'BOOL'        
    UNION SELECT ' # '              , 'BOOL'    , 'BOOL'    -- XOR 
    UNION SELECT ' IS '             , 'JSONB'   , 'BOOL'
    UNION SELECT ' IS NOT '         , 'JSONB'   , 'BOOL'     
    UNION SELECT ' IN '             , 'JSONB'   , 'BOOL'
    UNION SELECT ' , '              , 'TEXT'    , NULL   
    UNION SELECT ' @> '             , 'JSONB'   , 'BOOL'
    UNION SELECT ' <@ '             , 'JSONB'   , 'BOOL'
    UNION SELECT ' + '              , 'NUMERIC' , 'NUMERIC' -- addition   
    UNION SELECT ' - '              , 'NUMERIC' , 'NUMERIC' -- subtraction
    UNION SELECT ' * '              , 'NUMERIC' , 'NUMERIC' -- multiplication
    UNION SELECT ' / '              , 'NUMERIC' , 'NUMERIC' -- division 
    UNION SELECT ' % '              , 'NUMERIC' , 'NUMERIC' -- modulo (remainder)    
    UNION SELECT ' ^ '              , 'NUMERIC' , 'NUMERIC' -- exponentiation 
    UNION SELECT ' |/ '             , 'NUMERIC' , 'NUMERIC' -- square root    
    UNION SELECT ' ||/ '            , 'NUMERIC' , 'NUMERIC' -- cube root    
    UNION SELECT ' !! '             , 'INT'     , 'NUMERIC' -- factorial !! 5    120
    UNION SELECT ' @ '              , 'NUMERIC' , 'NUMERIC' -- absolute value    @ -5.0    5
    UNION SELECT ' & '              , 'INT'     , 'INT'     -- bitwise AND    91 & 15    11
    UNION SELECT ' | '              , 'INT'     , 'INT'     -- bitwise OR    32 | 3    35
    UNION SELECT ' << '             , 'INT'     , 'INT'     -- bitwise shift left    1 << 4    16
    UNION SELECT ' >> '             , 'INT'     , 'INT'     -- bitwise shift right    8 >> 2    2