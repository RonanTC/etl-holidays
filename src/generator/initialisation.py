import os
import boto3
from pg8000.dbapi import connect, Connection
from generator.oltp_schema import db_schema_str, seed_values_str
from utils.logger import custom_logger


def init_db(event, context):
    response = {
        "Result": "Failed",
        "create_db": "Not attempted",
        "create_schema": "Not attempted",
    }
    logger = custom_logger()

    try:
        if missing_list := check_env_variables():
            raise ValueError(
                f"Required environment variables missing: {str(missing_list)}"
            )

        db_usr = os.environ["DB_USER"]
        db_pass = os.environ["DB_PASS"]
        db_name = "etlhols_oltp"

        response["create_db"] = create_db(db_usr, db_pass, db_name)
        response["create_schema"] = create_schema(db_usr, db_pass, db_name)
        response["Result"] = "Success"
    except Exception as e:
        response["Result"] = "Error"
        logger.error(e)

    return response


def create_db(db_usr, db_pass, db_name):
    """Create user and empty db. If user already exists, does nothing.
    All statements are executed as oltp_admin_user.

    Args:
        db_usr (str): username for new user
        db_pass (str): password for new user
        db_name (str): name for new database

    Returns:
        str: One of the following values, indicating the outcome:
        "Not executed", "Created", "Already Exists", "Error"
    """
    logger = custom_logger()
    conn = None
    response = "Not executed"

    try:
        sm_client = boto3.client("secretsmanager")

        admin_user = sm_client.get_secret_value(SecretId="oltp_admin_user")
        admin_pass = sm_client.get_secret_value(SecretId="oltp_admin_pass")

        conn = connect(
            user=admin_user["SecretString"],
            password=admin_pass["SecretString"],
            host=os.environ["DB_HOST"],
            database=os.environ["DB_NAME"],
            port=int(os.environ["DB_PORT"]),
            ssl_context=True,
        )

        conn.autocommit = True
        cursor = conn.cursor()

        cursor.execute(
            f"SELECT Count(*) FROM pg_user where usename = '{db_usr}';"
        )
        usr_records = cursor.fetchone()

        if usr_records[0] == 0:
            logger.info("creating db & user...")
            cursor.execute(f"CREATE USER {db_usr} WITH PASSWORD '{db_pass}';")
            cursor.execute(f"GRANT {db_usr} TO {admin_user['SecretString']};")
            cursor.execute(f"CREATE DATABASE {db_name} OWNER = {db_usr};")
            logger.info("database & user created")
            response = "Created"
        else:
            logger.info("database already exists")
            response = "Already exists"
    except Exception as e:
        logger.error(e)
        response = "Error"
    finally:
        if isinstance(conn, Connection):
            conn.close()

    return response


def create_schema(db_usr, db_pass, db_name):
    """Create database tables as defined in oltp_schema.py and seed with
    initial values.

    Args:
        db_usr (str): username to connect as
        db_pass (str): password for user
        db_name (str): name of database

    Returns:
        str: One of the following values, indicating the outcome:
        "Not executed", "Created", "Already Exists", "Error"
    """
    logger = custom_logger()
    conn = None
    response = "Not executed"

    try:
        conn = connect(
            user=db_usr,
            password=db_pass,
            host=os.environ["DB_HOST"],
            database=db_name,
            port=int(os.environ["DB_PORT"]),
            ssl_context=True,
        )
        conn.autocommit = True
        cursor = conn.cursor()
        cursor.execute(
            "SELECT * FROM pg_catalog.pg_tables "
            "WHERE schemaname != 'pg_catalog' "
            "AND schemaname != 'information_schema';"
        )
        tables_list = cursor.fetchall()

        if len(tables_list) == 0:
            logger.info("creating tables...")
            cursor.execute(db_schema_str)
            logger.info("inserting values...")
            cursor.execute(seed_values_str)
            response = "Created"
        else:
            logger.info("tables already exist.")
            response = "Already exists"
    except Exception as e:
        logger.error(e)
        response = "Error"
    finally:
        if isinstance(conn, Connection):
            conn.close()

    return response


def check_env_variables():
    missing_list = []

    for item in ["DB_USER", "DB_PASS", "DB_NAME", "DB_HOST", "DB_PORT"]:
        if item not in os.environ:
            missing_list.append(item)

    return missing_list
