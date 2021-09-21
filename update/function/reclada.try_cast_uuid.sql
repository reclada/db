DROP FUNCTION IF EXISTS reclada.try_cast_uuid;
CREATE OR REPLACE FUNCTION reclada.try_cast_uuid(p_in text, p_default int default null)
   returns uuid
as
$$
begin
    return p_in::uuid;
    exception when others then
        return p_default;
end;
$$
language plpgsql IMMUTABLE;