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
    UNION SELECT ' XOR '            , 'BOOL'                        , 'BOOL'    , NULL      -- XOR
    UNION SELECT ' IS '             , 'JSONB'                       , 'BOOL'    , NULL    
    UNION SELECT ' IS NOT '         , 'JSONB'                       , 'BOOL'    , NULL     
    UNION SELECT ' IN '             , 'JSONB'                       , 'BOOL'    , ' , '   
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
    UNION SELECT ' # '              , 'INT'                         , 'INT'     , NULL    -- bitwise XOR    17 # 5    20
    UNION SELECT ' << '             , 'INT'                         , 'INT'     , NULL    -- bitwise shift left    1 << 4    16
    UNION SELECT ' >> '             , 'INT'                         , 'INT'     , NULL    -- bitwise shift right    8 >> 2    2
    UNION SELECT ' BETWEEN '        , 'TIMESTAMP WITH TIME ZONE'    , 'BOOL'    , ' AND ' 
    UNION SELECT ' Y/BETWEEN '      , NULL                          , NULL      , ' AND ' -- year
    UNION SELECT ' MON/BETWEEN '    , NULL                          , NULL      , ' AND ' -- month
    UNION SELECT ' D/BETWEEN '      , NULL                          , NULL      , ' AND ' -- day
    UNION SELECT ' H/BETWEEN '      , NULL                          , NULL      , ' AND ' -- hour
    UNION SELECT ' MIN/BETWEEN '    , NULL                          , NULL      , ' AND ' -- minute
    UNION SELECT ' S/BETWEEN '      , NULL                          , NULL      , ' AND ' -- second
    UNION SELECT ' DOW/BETWEEN '    , NULL                          , NULL      , ' AND ' -- The day of the week as Sunday (0) to Saturday (6)
    UNION SELECT ' DOY/BETWEEN '    , NULL                          , NULL      , ' AND ' -- The day of the year (1 - 365/366)
    UNION SELECT ' Q/BETWEEN '      , NULL                          , NULL      , ' AND ' -- The quarter of the year (1 - 4) that the date is in
    UNION SELECT ' W/BETWEEN '      , NULL                          , NULL      , ' AND ' -- week


;
    