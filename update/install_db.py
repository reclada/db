from update_db import run_cmd_scalar
from update_db import clone_db
from update_db import get_commit_history
from update_db import install_components
from update_db import get_version_from_commit
from update_db import rmdir
from update_db import run_file
from update_db import recreate_db
from update_db import quick_install
from update_db import version
from update_db import config_version
from update_db import json_schema_install
from update_db import branch_db
from update_db import install_objects
from update_db import replace_component
from update_db import get_cmd_install_component_db


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
            run_cmd_scalar( get_cmd_install_component_db() )
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

    install_components()