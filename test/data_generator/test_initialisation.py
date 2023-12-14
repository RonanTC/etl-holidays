from generator.initialisation import init_db, create_db, create_schema
from generator.oltp_schema import db_schema_str, seed_values_str
from moto import mock_secretsmanager
from unittest.mock import patch, Mock, call
import boto3
import pytest
import logging


@pytest.fixture
def dummy_env_vars(monkeypatch):
    monkeypatch.setenv("DB_USER", "usr")
    monkeypatch.setenv("DB_PASS", "pass")
    monkeypatch.setenv("DB_NAME", "name")
    monkeypatch.setenv("DB_HOST", "host")
    monkeypatch.setenv("DB_PORT", "5432")


@pytest.fixture
def mocked_secretsmanager():
    with mock_secretsmanager():
        sm = boto3.client("secretsmanager", "eu-west-2")
        sm.create_secret(
            Name="oltp_admin_user", SecretString="oltp_admin_user"
        )
        sm.create_secret(
            Name="oltp_admin_pass", SecretString="oltp_admin_pass"
        )
        yield sm


@pytest.fixture
def mocked_logger():
    """Return a default logger for testing. This exists so that custom_logger
    does not need to be used while the tests are executing, since its setup
    conflicts with pytest's caplog fixture.

    Yields:
        Logger: dummy logger to test error logging.
    """
    with patch("generator.initialisation.custom_logger") as logger:
        logger.return_value = logging.getLogger("test_logger")
        yield logger


# init_db
###############################################################################


@patch("generator.initialisation.create_schema")
@patch("generator.initialisation.create_db")
def test_init_db_calls_create_db_and_create_schema(
    patched_create_db, patched_create_schema, dummy_env_vars
):
    patched_create_db.return_value = "Created"
    patched_create_schema.return_value = "Created"
    response = init_db(None, None)

    patched_create_db.assert_called_once_with("usr", "pass", "etlhols_oltp")
    patched_create_schema.assert_called_once_with(
        "usr", "pass", "etlhols_oltp"
    )
    assert response == {
        "Result": "Success",
        "create_db": "Created",
        "create_schema": "Created",
    }


def test_init_db_logs_error_when_no_env_variables(mocked_logger, caplog):
    response = init_db(None, None)

    assert caplog.records[-1].levelname == "ERROR"
    assert caplog.records[-1].message == (
        "Required environment variables missing: "
        "['DB_USER', 'DB_PASS', 'DB_NAME', 'DB_HOST', 'DB_PORT']"
    )
    assert response == {
        "Result": "Error",
        "create_db": "Not attempted",
        "create_schema": "Not attempted",
    }


@patch("generator.initialisation.create_db")
def test_init_db_logs_error_on_exception(
    patched_create_db, dummy_env_vars, mocked_logger, caplog
):
    patched_create_db.side_effect = Exception("An error")

    response = init_db(None, None)

    assert caplog.records[-1].levelname == "ERROR"
    assert caplog.records[-1].message == "An error"
    assert response == {
        "Result": "Error",
        "create_db": "Not attempted",
        "create_schema": "Not attempted",
    }


# create_db
###############################################################################


@patch("generator.initialisation.connect")
def test_create_db_connects_using_admin_credentials_from_secretsmanager(
    patched_connect, mocked_secretsmanager, dummy_env_vars
):
    create_db(None, None, None)

    patched_connect.assert_called_once_with(
        user="oltp_admin_user",
        password="oltp_admin_pass",
        host="host",
        database="name",
        port=5432,
        ssl_context=True,
    )


@patch("generator.initialisation.connect")
def test_create_db_creates_db_user_and_if_they_dont_exists(
    patched_connect, mocked_secretsmanager, dummy_env_vars
):
    mock_conn = Mock()
    patched_connect.return_value = mock_conn
    mock_cursor = Mock()
    mock_cursor.fetchone.return_value = (0, 0)
    mock_conn.cursor.return_value = mock_cursor

    db_usr = "user123"
    db_pass = "pass123"
    db_name = "name123"

    expected_calls = [
        call(f"CREATE USER {db_usr} WITH PASSWORD '{db_pass}';"),
        call(f"GRANT {db_usr} TO oltp_admin_user;"),
        call(f"CREATE DATABASE {db_name} OWNER = {db_usr};"),
    ]

    create_db(db_usr, db_pass, db_name)

    mock_cursor.execute.assert_has_calls(expected_calls)


@patch("generator.initialisation.boto3.client")
def test_create_db_logs_error_on_exception(patched_sm, mocked_logger, caplog):
    patched_sm.side_effect = Exception("An error")
    create_db(None, None, None)

    assert caplog.records[-1].levelname == "ERROR"
    assert caplog.records[-1].message == "An error"


# create_schema
###############################################################################


@patch("generator.initialisation.connect")
def test_create_schema_connects_using_credentials_from_args(
    patched_connect, dummy_env_vars
):
    db_usr = "user123"
    db_pass = "pass123"
    db_name = "name123"

    create_schema(db_usr, db_pass, db_name)

    patched_connect.assert_called_once_with(
        user="user123",
        password="pass123",
        host="host",
        database="name123",
        port=5432,
        ssl_context=True,
    )


@patch("generator.initialisation.connect")
def test_create_schema_executes_schema_creation_and_seed_queries(
    patched_connect, dummy_env_vars
):
    mock_conn = Mock()
    patched_connect.return_value = mock_conn
    mock_cursor = Mock()
    mock_cursor.fetchall.return_value = []
    mock_conn.cursor.return_value = mock_cursor

    db_usr = "user123"
    db_pass = "pass123"
    db_name = "name123"

    create_schema(db_usr, db_pass, db_name)

    expected_calls = [call(db_schema_str), call(seed_values_str)]

    mock_cursor.execute.assert_has_calls(expected_calls)


@patch("generator.initialisation.connect")
def test_create_schema_does_nothing_if_db_exists(
    patched_connect, dummy_env_vars
):
    mock_conn = Mock()
    patched_connect.return_value = mock_conn
    mock_cursor = Mock()
    mock_cursor.fetchall.return_value = ["customers", "locations"]
    mock_conn.cursor.return_value = mock_cursor

    db_usr = "user123"
    db_pass = "pass123"
    db_name = "name123"

    create_schema(db_usr, db_pass, db_name)

    assert call(db_schema_str) not in mock_cursor.execute.mock_calls
    assert call(seed_values_str) not in mock_cursor.execute.mock_calls


@patch("generator.initialisation.connect")
def test_create_schema_logs_error_on_exception(
    patched_connect, dummy_env_vars, mocked_logger, caplog
):
    patched_connect.side_effect = Exception("An error")
    create_schema(None, None, None)

    assert caplog.records[-1].levelname == "ERROR"
    assert caplog.records[-1].message == "An error"
