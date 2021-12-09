drop VIEW if EXISTS reclada.v_filter_between;
CREATE OR REPLACE VIEW reclada.v_filter_between
AS
    SELECT ' Y/BETWEEN ' AS operator, 'date_part(''YEAR''   , TIMESTAMP WITH TIME ZONE %s)' AS operand_format
    UNION SELECT ' MON/BETWEEN '    , 'date_part(''MONTH''  , TIMESTAMP WITH TIME ZONE %s)' 
    UNION SELECT ' D/BETWEEN '      , 'date_part(''DAY''    , TIMESTAMP WITH TIME ZONE %s)' 
    UNION SELECT ' H/BETWEEN '      , 'date_part(''HOUR''   , TIMESTAMP WITH TIME ZONE %s)'
    UNION SELECT ' MIN/BETWEEN '    , 'date_part(''MINUTE'' , TIMESTAMP WITH TIME ZONE %s)'
    UNION SELECT ' S/BETWEEN '      , 'date_part(''SECOND'' , TIMESTAMP WITH TIME ZONE %s)::int'
    UNION SELECT ' DOW/BETWEEN '    , 'date_part(''DOW''    , TIMESTAMP WITH TIME ZONE %s)'
    UNION SELECT ' DOY/BETWEEN '    , 'date_part(''DOY''    , TIMESTAMP WITH TIME ZONE %s)'
    UNION SELECT ' Q/BETWEEN '      , 'date_part(''QUARTER'', TIMESTAMP WITH TIME ZONE %s)'
    UNION SELECT ' W/BETWEEN '      , 'date_part(''WEEK''   , TIMESTAMP WITH TIME ZONE %s)'
   
;
