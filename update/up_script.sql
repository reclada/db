-- version = 16
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

\i 'reclada_object.create.sql'


CREATE UNIQUE INDEX unique_guid_revision 
    ON reclada.object((attributes->>'revision'),obj_id);

