###############################################################################

.ONESHELL:

.DEFAULT_GOAL := help # Show helpfile it makefile is run without any arguments

###############################################################################

SHELL := /bin/bash
ACTIVATE_VENV = source venv/bin/activate
INSTALL_REQUIREMENTS = $(ACTIVATE_VENV) && pip install -r requirements.txt -q
INSTALL_DEV_REQUIREMENTS = $(ACTIVATE_VENV) && pip install -r dev_requirements.txt -q
SET_PYTHONPATH = PYTHONPATH=$(shell pwd)
COVERAGE_TARGET = 95

###############################################################################


# Show help text
help:
	@echo "USAGE:"
	@echo "make pytest : run all tests through pytest"
	@echo "make standards : run flake8 and coverage"
	@echo "make security : run safefy and bandit"
	@echo "make cleanup : delete temporary files and venv"


# Create virtual environment and install project requirements
venv: requirements.txt
	python -m venv venv
	$(INSTALL_REQUIREMENTS)


# Run tests
pytest: venv
	$(INSTALL_DEV_REQUIREMENTS)
	${SET_PYTHONPATH} pytest -v --testdox


# Check code standards and test coverage
standards: venv
	$(INSTALL_DEV_REQUIREMENTS)
	${SET_PYTHONPATH} flake8 -v src/**/*.py test/**/*.py
	${SET_PYTHONPATH} coverage run --omit 'venv/*' -m pytest --testdox && coverage report -m --fail-under=${COVERAGE_TARGET}


# Check security for project code and dependencies
security: venv
	$(INSTALL_DEV_REQUIREMENTS)
	${SET_PYTHONPATH} safety check
	${SET_PYTHONPATH} bandit -lll src/**/*.py test/**/*.py


# Delete any temporary files and folders
cleanup:
	rm -rf venv
	rm -rf **/*__pycache__
	rm -rf **/**/__pycache__
	rm -rf .pytest_cache
	rm -f .coverage

###############################################################################
