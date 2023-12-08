import os
from pg8000 import Connection

def generate_data():
    print("data!")


def init_db(event, context):
    conn = Connection()
    return {"Status": "Dubious", "Env Value": os.environ["env_var"]}
