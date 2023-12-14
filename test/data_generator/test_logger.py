from logging import Logger
from utils.logger import custom_logger


def test_custom_logger_returns_logger():
    logger = custom_logger()

    assert isinstance(logger, Logger)


def test_custom_logger_has_correct_formatter_setup():
    logger = custom_logger()

    assert (
        logger.handlers[0].formatter._fmt
        == "[%(levelname)s] :: %(module)s/%(funcName)s :: %(message)s"
    )
