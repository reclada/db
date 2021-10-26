CREATE OR REPLACE FUNCTION reclada.xor (a boolean, b boolean) returns boolean immutable language sql AS
$$
    SELECT (a and not b) or (b and not a);
$$;