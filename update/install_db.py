from update_db import clone_db, get_commit_history,run_object_create,install_objects, get_version_from_commit, rmdir, run_file,run_cmd_scalar, recreate_db, branch_runtime, branch_SciNLP,quick_install,version,config_version,db_user, json_schema_install


import os
import os.path

reclada_user_name = 'reclada'


def db_install():

    json_schema_install()
    rmdir('db')
    clone_db()
    
    if db_user != reclada_user_name:
        if run_cmd_scalar(f"SELECT rolname FROM pg_roles WHERE rolname=\'{reclada_user_name}\'") != reclada_user_name:
            run_cmd_scalar(f"CREATE ROLE {reclada_user_name} NOINHERIT")
        if run_cmd_scalar(f"SELECT CASE WHEN pg_has_role(\'{db_user}\',\'{reclada_user_name}\',\'member\') THEN 1 ELSE 0 END") == '0':
            run_cmd_scalar(f"GRANT {reclada_user_name} TO {db_user}")

    short_install = os.path.isfile(os.path.join('update','install_db.sql')) and quick_install
    use_dump = False
    if short_install:
        h = get_commit_history()
        max_dump_commit = min(config_version,len(h))-1
        while(max_dump_commit > 0):
            c = h[max_dump_commit]
            commit_ver = get_version_from_commit(c)
            installer_ver = get_version_from_commit(c,'install_db.sql')
            if commit_ver == installer_ver:
                break
            else:
                max_dump_commit -= 1
        
        if max_dump_commit > 0:
            use_dump = True
            os.chdir('update')
            run_file('install_db.sql')
            os.chdir('..')

        need_update = not((max_dump_commit == config_version - 1) 
            or (version == 'latest' and max_dump_commit == len(h)-1))

    else:
        os.chdir('..')
        os.chdir('db/src')
        run_file('scheme.sql')
        run_file('functions.sql')
        run_file('data.sql')
        os.chdir('..')
        need_update = True
    
    os.chdir('..')
    rmdir('db')
    return need_update, use_dump

def runtime_install():
    rmdir('reclada.runtime')
    os.system(f'git clone https://github.com/reclada/reclada.runtime')
    os.chdir('reclada.runtime/db/objects')
    os.system(f'git checkout {branch_runtime}')
    run_file('install_objects.sql')
    os.chdir('..')
    os.chdir('..')
    os.chdir('..')
    rmdir('reclada.runtime')

def scinlp_install():
    rmdir('SciNLP')
    os.system(f'git clone https://github.com/reclada/SciNLP')
    os.chdir('SciNLP/src/db')
    os.system(f'git checkout {branch_SciNLP}')
    run_file('bdobjects.sql')
    run_file('nlpobjects.sql')
    os.chdir('..')
    os.chdir('..')
    os.chdir('..')
    rmdir('SciNLP')

if __name__ == "__main__":
    
    recreate_db()
    need_update, use_dump = db_install()
    if need_update:
        os.system('python update_db.py')
        if not use_dump:
            scinlp_install()
            runtime_install()
    if run_object_create:
        install_objects()