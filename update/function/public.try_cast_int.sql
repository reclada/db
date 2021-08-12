DROP FUNCTION public.try_cast_int;
create or replace function public.try_cast_int(p_in varchar(32), p_default int default null)
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
