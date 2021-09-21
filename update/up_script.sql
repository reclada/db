-- version = 23
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

DROP FUNCTION IF EXISTS public.raise_exception;
DROP FUNCTION IF EXISTS public.raise_notice;
DROP FUNCTION IF EXISTS public.try_cast_uuid;
DROP FUNCTION IF EXISTS public.try_cast_int;

\i 'function/reclada.raise_exception.sql'
\i 'function/reclada.raise_notice.sql'
\i 'function/reclada.try_cast_uuid.sql'
\i 'function/reclada.try_cast_int.sql'
\i 'function/dev.downgrade_version.sql'
\i 'function/reclada_object.create.sql'
\i 'function/reclada_object.list.sql'
\i 'function/reclada_object.update.sql'
