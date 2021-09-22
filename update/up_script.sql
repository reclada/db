-- version = 29
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

drop SEQUENCE IF EXISTS reclada.reclada_revisions;

CREATE SEQUENCE IF not EXISTS reclada.transaction_id
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

\i 'function/reclada.get_transaction_id.sql' 
\i 'function/reclada_object.create.sql' 
\i 'function/reclada_object.delete.sql'
