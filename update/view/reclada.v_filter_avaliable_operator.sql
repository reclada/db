drop VIEW if EXISTS reclada.v_filter_avaliable_operator;
CREATE OR REPLACE VIEW reclada.v_filter_avaliable_operator
AS
    SELECT       ' = ' AS operator  , NULL AS data_type
    UNION SELECT ' LIKE '           , 'TEXT'  
    UNION SELECT ' NOT LIKE '       , 'TEXT'  
    UNION SELECT ' || '             , 'TEXT'  
    UNION SELECT ' ~ '              , 'TEXT'  
    UNION SELECT ' !~ '             , 'TEXT'  
    UNION SELECT ' ~* '             , 'TEXT'  
    UNION SELECT ' !~* '            , 'TEXT'  
    UNION SELECT ' SIMILAR TO '     , 'TEXT'  
    UNION SELECT ' > '              , null
    UNION SELECT ' < '              , null
    UNION SELECT ' <= '             , null
    UNION SELECT ' != '             , null
    UNION SELECT ' >= '             , null
    UNION SELECT ' AND '            , null        
    UNION SELECT ' OR '             , null
    UNION SELECT ' NOT '            , null        
    UNION SELECT ' ^ '              , null
    UNION SELECT ' IS '             , null
    UNION SELECT ' IS NOT '         , null        
    UNION SELECT ' IN '             , null
    UNION SELECT ' , '              , null
    UNION SELECT ' @> '             , null
    UNION SELECT ' <@ '             , null
    UNION SELECT ' + '              , 'NUMERIC'     -- addition   
    UNION SELECT ' - '	            , 'NUMERIC'     -- subtraction
    UNION SELECT ' * '	            , 'NUMERIC'     -- multiplication
    UNION SELECT ' / '	            , 'NUMERIC'     -- division 
    UNION SELECT ' % '	            , 'NUMERIC'     -- modulo (remainder)	
    UNION SELECT ' ^ '	            , 'NUMERIC'     -- exponentiation 
    UNION SELECT ' |/ '	            , 'NUMERIC'     -- square root	
    UNION SELECT ' ||/ '	        , 'NUMERIC'     -- cube root	
    UNION SELECT ' !! '	            , 'INT'         -- factorial !! 5	120
    UNION SELECT ' @ '	            , 'NUMERIC'     -- absolute value	@ -5.0	5
    UNION SELECT ' & '	            , 'INT'         -- bitwise AND	91 & 15	11
    UNION SELECT ' | '	            , 'INT'         -- bitwise OR	32 | 3	35
    UNION SELECT ' # '	            , 'INT'         -- bitwise XOR	17 # 5	20
    UNION SELECT ' ~ '	            , 'INT'         -- bitwise NOT	~1	-2
    UNION SELECT ' << '	            , 'INT'         -- bitwise shift left	1 << 4	16
    UNION SELECT ' >> '	            , 'INT'         -- bitwise shift right	8 >> 2	2