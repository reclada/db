try:
    upgrade_script = ''
    version = -1
    with open("up_script.sql",encoding = 'utf-8') as f:
        t = f.readline()
        version = int(t.replace("-- version =",''))
        upgrade_script = f.read()

    if version == -1:
        print("version not found")
        print('add first line "-- version = <number>" in "up_script.sql"')
        
    else:
        tamplate = ''
        with open("upgrade_script_tamplate.sql",encoding = 'utf-8') as f:
            tamplate = f.read()

        up = tamplate.replace('/*#@#@#upgrade_script#@#@#*/',upgrade_script)
        up = up.replace('/*#@#@#version#@#@#*/',str(version))


        with open("up.sql",'w', encoding = "utf-8") as f:
            f.write(up)

        input('Done')

except Exception as e:
    input(str(e))
