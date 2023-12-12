###############################################################################

.ONESHELL:

.DEFAULT_GOAL := help # Show helpfile it makefile is run without any arguments

###############################################################################

SHELL := /bin/bash
ACTIVATE_VENV = source venv/bin/activate
INSTALL_REQUIREMENTS = $(ACTIVATE_VENV) && pip install -r requirements.txt -q
INSTALL_DEV_REQUIREMENTS = $(ACTIVATE_VENV) && pip install -r dev_requirements.txt -q
SET_PYTHONPATH = PYTHONPATH=$(shell pwd)/src

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
	${SET_PYTHONPATH} coverage run --omit 'venv/*' -m pytest --testdox && coverage report -m


# Check security for project code and dependencies
security: venv
	$(INSTALL_DEV_REQUIREMENTS)
	${SET_PYTHONPATH} safety check
	${SET_PYTHONPATH} bandit -lll src/**/*.py test/**/*.py


# Create custom layer packages for lambdas
createlayers:
	pip install -r requirements.txt --target layers/generator/python/lib/python3.11/site-packages
	mkdir tmp
	cd layers/generator
	zip -r9 ../../tmp/tmp_gen_layer.zip python


# Deploy the generator lambda
deploy-gen-dev: createlayers
	terraform -chdir=terraform plan -var-file=vars.tfvars -out=../tmp/gen.plan
	terraform -chdir=terraform apply -auto-approve ../tmp/gen.plan

# Delete any temporary files and folders
cleanup:
	rm -rf venv
	rm -rf **/*__pycache__
	rm -rf **/**/__pycache__
	rm -rf .pytest_cache
	rm -f .coverage
	rm -f tmp*.zip
	rm -rf layers
	rm -rf tmp

###############################################################################
