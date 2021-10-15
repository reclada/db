from json.decoder import JSONDecodeError
from update_db import get_version_from_commit, get_version_from_db
from update_db import run_file, db_URI, psql_str,rmdir,run_test,run_cmd_scalar

import os
import datetime
import json
import filecmp

'''
    To use this script copy db_installer folder to reclada_db folder
    and run this file
'''

if __name__ == "__main__":

    t = str(datetime.datetime.now())
    
    downgrade_test = True
    downgrade_dump = 'downgrade_dump.sql'
    current_dump = 'current_dump.sql'

    commit_ver = get_version_from_commit()
    db_ver = get_version_from_db()
    install_db = commit_ver != db_ver + 1
    if install_db:
        os.system('python install_db.py')
        if downgrade_test:
            print('pg_dump for current version . . .')
            os.system(f'pg_dump -f {current_dump} {db_URI}')
    else:
        print('install_db.py skipped, database has actual version')
    
    input("Press Enter to apply new version . . .")

    res = os.popen('python create_up.sql.py').read()

    if res != 'Done\n':
        raise Exception(f'create_up.sql.py error: {res}')

    run_file('up.sql')

    if downgrade_test:
        run_cmd_scalar('select dev.downgrade_version();')
        print('pg_dump after downgrade version . . .')
        os.system(f'pg_dump -f {downgrade_dump} {db_URI}')
        if not filecmp.cmp(current_dump, downgrade_dump):
            input("down.sql invalid !!! Press Enter to continue. . .")
        os.remove(downgrade_dump)
        os.remove(current_dump)
        run_file('up.sql')

    input("Press Enter to update jsonschemas and install_db.sql . . .")

    if install_db:
        print('pg_dump...')
        os.system(f'pg_dump -N public -f install_db.sql -O {db_URI}')

        with open('up_script.sql') as f:
            ver_str = f.readline()
            ver = int(ver_str.replace('-- version =',''))
        
        with open('update_config.json') as f:
            config_str = f.read()
        
        with open('install_db.sql',encoding='utf8') as f:
            scr_str = f.readlines()

        with open('install_db.sql','w',encoding='utf8') as f:
            f.write(ver_str)
            f.write(f'-- {t}')
            #f.write(f'\n/*\nupdate_config.json:\n{config_str}\n*/\n')
            for line in scr_str:
                if line.find('GRANT') != 0 and line.find('REVOKE') != 0:
                    f.write(line)


        print('loading jsonschemas..')
        sc = os.popen(psql_str('-c "SELECT for_class,attrs FROM reclada.v_class;"')).readlines()
        rmdir('jsonschema')
        os.makedirs('jsonschema')
        os.chdir('jsonschema')
        for s in sc:
            try:
                for_class, attrs = s.replace('\n',' ').split(' | ')
                attrs = json.dumps(json.loads(attrs),sort_keys=True,indent=4)
                for_class = for_class.strip()
            except Exception as e:
                if type(e) in [JSONDecodeError,ValueError]:
                    continue
                else:
                    raise e
            with open(f'{for_class}.json','a') as f:
                f.write(attrs)
        os.chdir('..')
    else:
        print('skipped . . .')
        print('If evrything okay - run this script again before commit to update jsonschemas and install_db.sql')

    
    input("Press Enter to run testing . . .")

    run_test()

    input("Press Enter to finish . . .")
