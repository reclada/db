from json.decoder import JSONDecodeError
from update_db import get_version_from_commit, get_version_from_db
from update_db import run_file, db_URI, psql_str,rmdir,run_test,run_cmd_scalar,downgrade_test

import os
import datetime
import json
import filecmp

'''
    To use this script copy db_installer folder to reclada_db folder
    and run this file
'''

def upgrade():
    res = os.popen('python create_up.sql.py').read()

    if res != 'Done\n':
        raise Exception(f'create_up.sql.py error: {res}')

    run_file('up.sql')

if __name__ == "__main__":

    t = str(datetime.datetime.now())
    
    down_test = downgrade_test

    downgrade_dump = 'downgrade_dump.sql'
    current_dump = 'current_dump.sql'

    commit_ver = get_version_from_commit()
    db_ver = get_version_from_db()
    install_db = commit_ver != db_ver + 1
    if install_db:
        os.system('python install_db.py')
        if down_test:
            print('pg_dump for current version...')
            os.system(f'pg_dump -f {current_dump} {db_URI}')   
    else:
        print('install_db.py skipped, database has actual version')
        down_test = False
    
    input("Press Enter to apply new version . . .")

    upgrade()

    if down_test:
        run_cmd_scalar('select dev.downgrade_version();')
        print('pg_dump after downgrade version...')
        os.system(f'pg_dump -f {downgrade_dump} {db_URI}')
        with open(downgrade_dump, encoding='utf8') as dd, open(current_dump, encoding='utf8') as cd:
            ldd = dd.readlines()
            lcd = cd.readlines()

        if len(ldd) == len(lcd):
            d = []
            copy = False
            for i in range(len(ldd)):
                if not copy:
                    copy = ldd[i].startswith('COPY ')
                    if copy:
                        sc = set()
                        sd = set()
                    suffix = ", true);\n"
                    for prefix in ["SELECT pg_catalog.setval('dev.ver_id_seq',","SELECT pg_catalog.setval('reclada."]:
                        if (ldd[i].startswith(prefix)
                            and lcd[i].startswith(prefix)
                            and ldd[i].endswith(suffix)
                            and lcd[i].endswith(suffix)):
                            break
                    else:
                        if (ldd[i] != lcd[i]):
                            d.append(lcd[i])
                            d.append(ldd[i])
                else:
                    if ldd[i] == '\n':
                        copy = False
                        if sc != sd:
                            input("!!! down.sql invalid !!! table data has changed . . .")
                            break
                    else:
                        sd.add(ldd[i])
                        sc.add(lcd[i])
            if len(d)>0:
                print("down.sql invalid:")
                for i in range(0,len(d),2):
                    print(d[i] + d[i+1])
                input("!!! down.sql invalid !!! Enter to continue . . .")
            else:
                print("\n\nOK: down.sql valid\n\n")
        else:
            input("!!! down.sql invalid !!! Dumps have different length! Press Enter to continue . . .")
            
        os.remove(downgrade_dump)
        os.remove(current_dump)
        os.system('python install_db.py')
        upgrade()
    else:
        print("skipped downgrade test...")

    input("Press Enter to update jsonschemas and install_db.sql . . .")

    if install_db:
        print('pg_dump...')
        os.system(f'pg_dump -N public -f install_db.sql -O {db_URI}')

        with open('up_script.sql') as f:
            ver_str = f.readline()
            ver = int(ver_str.replace('-- version =',''))
               
        with open('install_db.sql',encoding='utf8') as f:
            scr_str = f.readlines()

        with open('install_db.sql','w',encoding='utf8') as f:
            f.write(ver_str)
            f.write(f'-- {t}')
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
