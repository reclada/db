from update_db import DBHelper
import sys


if __name__ == "__main__":
    path = ''
    if len(sys.argv) > 1:
        path = sys.argv[1]
        db_helper = DBHelper(path = path)
    else:
        db_helper = DBHelper() # read update_config.json

    db_helper.install_components()