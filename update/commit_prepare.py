from json.decoder import JSONDecodeError
from update_db import run_file, db_user, server, db, psql_str,rmdir,run_test

import os
import datetime
import json

'''
    To use this script copy db_installer folder to reclada_db folder
    and run this file
'''

if __name__ == "__main__":

    t = str(datetime.datetime.now())

    os.system('python install_db.py')

    res = os.popen('python create_up.sql.py').read()

    if res != 'Done\n':
        raise Exception(f'create_up.sql.py error: {res}')

    run_file('up.sql')
    print('pg_dump...')
    os.system(f'pg_dump -U {db_user} -p 5432 -h {server} -d {db} -N public -f install_db.sql')

    with open('up_script.sql') as f:
        ver_str = f.readline()
        ver = int(ver_str.replace('-- version =',''))
    
    with open('update_config.json') as f:
        config_str = f.read()
    
    with open('install_db.sql',encoding='utf8') as f:
        scr_str = f.read()

    with open('install_db.sql','w',encoding='utf8') as f:
        f.write(ver_str)
        f.write(f'-- {t}')
        f.write(f'\n/*\nupdate_config.json:\n{config_str}\n*/\n')
        f.write(scr_str)


    print('loading jsonschemas..')
    sc = os.popen(f'{psql_str} -c "SELECT for_class,attrs FROM reclada.v_class;"').readlines()
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

    run_test()
