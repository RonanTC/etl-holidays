import logging


def custom_logger():
    log = logging.getLogger("etl-holidays")
    log.setLevel(logging.INFO)
    log.handlers = []  # remove handler provided by AWS
    log.propagate = False

    handler = logging.StreamHandler()
    handler.setLevel(logging.INFO)
    log_fmt = logging.Formatter(
        "[%(levelname)s] :: %(module)s/%(funcName)s :: %(message)s"
    )
    handler.setFormatter(log_fmt)

    log.addHandler(handler)
    return log
