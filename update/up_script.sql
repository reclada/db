-- version = 2
/*
	you can use "\i 'function/reclada_object.get_schema.sql'"
	to run text script of functions
*/
alter table dev.test1 add id int;

\i function/public.try_cast_int.sql