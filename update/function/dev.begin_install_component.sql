
DROP FUNCTION IF EXISTS dev.begin_install_component;
CREATE OR REPLACE FUNCTION dev.begin_install_component
(
    _name        text,
    _repository  text,
    _commit_hash text
)
RETURNS text AS $$
DECLARE
    _guid        uuid;
    _f_name      text = 'dev.begin_install_component';
BEGIN
    perform reclada.raise_exception( '"'|| name ||'" component has is already begun installing.',_f_name)
        from dev.component;

    select guid 
        from reclada.v_component 
            where name = _name
        into _guid;

    _guid = coalesce(_guid,public.uuid_generate_v4());

    insert into dev.component( name,  repository,  commit_hash,  guid)
                       select _name, _repository, _commit_hash, _guid;

    delete from dev.component_object;
    insert into dev.component_object(data)
        select obj_data 
            from reclada.v_component_object
                where component_name = _name;
    return 'OK';
END;
$$ LANGUAGE PLPGSQL VOLATILE;