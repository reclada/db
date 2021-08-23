DROP FUNCTION IF EXISTS public.try_cast_int;
CREATE OR REPLACE FUNCTION public.try_cast_int(p_in text, p_default int default null)
   returns int
as
$$
begin
  begin
    return p_in::int;
  exception 
    when others then
       return p_default;
  end;
end;
$$
language plpgsql IMMUTABLE;