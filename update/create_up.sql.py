from update_db import create_up

if __name__ == "__main__":
    try:
        create_up()
    except Exception as e:
        input(str(e))
