from update_db import clone_db, get_commit_history,run_object_create,install_components, get_version_from_commit, rmdir, run_file, recreate_db 
from update_db import quick_install,version,config_version, json_schema_install


import os
import os.path

reclada_user_name = 'reclada'


def db_install():

    json_schema_install()
    clone_db()
    
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


if __name__ == "__main__":
    
    recreate_db()
    need_update, use_dump = db_install()

    if need_update:
        os.system('python update_db.py')

    if run_object_create:
        install_components()