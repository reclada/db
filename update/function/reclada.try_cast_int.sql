DROP FUNCTION IF EXISTS reclada.try_cast_int;
CREATE OR REPLACE FUNCTION reclada.try_cast_int(p_in text, p_default int default null)
   returns int
as
$$
begin
    return p_in::int;
    exception when others then
        return p_default;
end;
$$
language plpgsql IMMUTABLE;