-- version = 21
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

\i 'function/reclada_object.create_subclass.sql'

update v_class_lite
	set attributes = attributes || '{"version":1}'
		where attributes->>'version' is null;




