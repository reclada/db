drop VIEW if EXISTS reclada.v_filter_avaliable_operator;
CREATE OR REPLACE VIEW reclada.v_filter_avaliable_operator
AS
    SELECT       ' = ' AS operator  , 'JSONB' AS input_type         , 'BOOL' AS output_type, NULL as inner_operator
    UNION SELECT ' LIKE '           , 'TEXT'                        , 'BOOL'    , NULL    
    UNION SELECT ' NOT LIKE '       , 'TEXT'                        , 'BOOL'    , NULL    
    UNION SELECT ' || '             , 'TEXT'                        , 'TEXT'    , NULL    
    UNION SELECT ' ~ '              , 'TEXT'                        , 'BOOL'    , NULL    
    UNION SELECT ' !~ '             , 'TEXT'                        , 'BOOL'    , NULL    
    UNION SELECT ' ~* '             , 'TEXT'                        , 'BOOL'    , NULL    
    UNION SELECT ' !~* '            , 'TEXT'                        , 'BOOL'    , NULL    
    UNION SELECT ' SIMILAR TO '     , 'TEXT'                        , 'BOOL'    , NULL    
    UNION SELECT ' > '              , 'JSONB'                       , 'BOOL'    , NULL    
    UNION SELECT ' < '              , 'JSONB'                       , 'BOOL'    , NULL    
    UNION SELECT ' <= '             , 'JSONB'                       , 'BOOL'    , NULL    
    UNION SELECT ' != '             , 'JSONB'                       , 'BOOL'    , NULL    
    UNION SELECT ' >= '             , 'JSONB'                       , 'BOOL'    , NULL    
    UNION SELECT ' AND '            , 'BOOL'                        , 'BOOL'    , NULL    
    UNION SELECT ' OR '             , 'BOOL'                        , 'BOOL'    , NULL    
    UNION SELECT ' NOT '            , 'BOOL'                        , 'BOOL'    , NULL          
    UNION SELECT ' # '              , 'BOOL'                        , 'BOOL'    , NULL      -- XOR 
    UNION SELECT ' IS '             , 'JSONB'                       , 'BOOL'    , NULL    
    UNION SELECT ' IS NOT '         , 'JSONB'                       , 'BOOL'    , NULL     
    UNION SELECT ' IN '             , 'JSONB'                       , 'BOOL'    , ' , '   
    UNION SELECT ' , '              , 'JSONB'                       , NULL      , NULL    
    UNION SELECT ' @> '             , 'JSONB'                       , 'BOOL'    , NULL    
    UNION SELECT ' <@ '             , 'JSONB'                       , 'BOOL'    , NULL    
    UNION SELECT ' + '              , 'NUMERIC'                     , 'NUMERIC' , NULL    -- addition   
    UNION SELECT ' - '              , 'NUMERIC'                     , 'NUMERIC' , NULL    -- subtraction
    UNION SELECT ' * '              , 'NUMERIC'                     , 'NUMERIC' , NULL    -- multiplication
    UNION SELECT ' / '              , 'NUMERIC'                     , 'NUMERIC' , NULL    -- division 
    UNION SELECT ' % '              , 'NUMERIC'                     , 'NUMERIC' , NULL    -- modulo (remainder)    
    UNION SELECT ' ^ '              , 'NUMERIC'                     , 'NUMERIC' , NULL    -- exponentiation 
    UNION SELECT ' |/ '             , 'NUMERIC'                     , 'NUMERIC' , NULL    -- square root    
    UNION SELECT ' ||/ '            , 'NUMERIC'                     , 'NUMERIC' , NULL    -- cube root    
    UNION SELECT ' !! '             , 'INT'                         , 'NUMERIC' , NULL    -- factorial !! 5    120
    UNION SELECT ' @ '              , 'NUMERIC'                     , 'NUMERIC' , NULL    -- absolute value    @ -5.0    5
    UNION SELECT ' & '              , 'INT'                         , 'INT'     , NULL    -- bitwise AND    91 & 15    11
    UNION SELECT ' | '              , 'INT'                         , 'INT'     , NULL    -- bitwise OR    32 | 3    35
    UNION SELECT ' << '             , 'INT'                         , 'INT'     , NULL    -- bitwise shift left    1 << 4    16
    UNION SELECT ' >> '             , 'INT'                         , 'INT'     , NULL    -- bitwise shift right    8 >> 2    2
    UNION SELECT ' BETWEEN '        , 'TIMESTAMP WITH TIME ZONE'    , 'BOOL'    , ' AND ' ;
    