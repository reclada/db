-- version = 40
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

\i 'view/reclada.v_filter_avaliable_operator.sql'
\i 'view/reclada.v_object.sql'
\i 'function/reclada_object.get_query_condition_filter.sql'
\i 'function/reclada_object.list.sql'
\i 'function/reclada.xor.sql'

CREATE OPERATOR # 
(
    PROCEDURE = reclada.xor, 
    LEFTARG = boolean, 
    RIGHTARG = boolean
);