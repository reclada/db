--DROP FUNCTION IF EXISTS reclada_object.built_nested_jsonb;
CREATE OR REPLACE FUNCTION reclada_object.built_nested_jsonb
(
    _path text[],
    _value jsonb
)
RETURNS jsonb AS $$
DECLARE
    n        integer;
    i        integer;
    res      jsonb;
BEGIN
res := _value;
--res := to_jsonb(_value); --!? unnecessary quotes
--res := _value::jsonb;
n := array_length(_path, 1);
FOR i IN reverse n..1 LOOP
    res := format('{"%s":%s}', _path[i], res)::jsonb;
END LOOP;
RETURN res;
END;
$$ LANGUAGE PLPGSQL IMMUTABLE;