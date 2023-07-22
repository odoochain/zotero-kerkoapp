# Change NAME if you wish to build your own image.
NAME := whiskyechobravo/kerkoapp

MAKEFILE_DIR := $(dir $(CURDIR)/$(lastword $(MAKEFILE_LIST)))
HOST_PORT := 8080
HOST_INSTANCE_PATH := $(MAKEFILE_DIR)instance
HOST_DEV_LOG := /tmp/kerkoapp-dev-log

SECRETS := $(HOST_INSTANCE_PATH)/.secrets.toml
CONFIG := $(HOST_INSTANCE_PATH)/config.toml
DATA := $(HOST_INSTANCE_PATH)/kerko/index

#
# Running targets.
#
# These work if the image exists, either pulled or built locally.
#

run: | $(DATA) $(SECRETS) $(CONFIG)
	docker run --rm -p $(HOST_PORT):80 -v $(HOST_INSTANCE_PATH):/kerkoapp/instance -v $(HOST_DEV_LOG):/dev/log $(NAME)

shell:
	docker run -it --rm -p $(HOST_PORT):80 -v $(HOST_INSTANCE_PATH):/kerkoapp/instance -v $(HOST_DEV_LOG):/dev/log $(NAME) bash

clean_kerko: | $(SECRETS) $(CONFIG)
	docker run --rm -p $(HOST_PORT):80 -v $(HOST_INSTANCE_PATH):/kerkoapp/instance -v $(HOST_DEV_LOG):/dev/log $(NAME) flask kerko clean everything

$(DATA): | $(SECRETS) $(CONFIG)
	@echo "[WARNING] It looks like you have not run the kerko sync command. Trying it for you now!"
	docker run --rm -p $(HOST_PORT):80 -v $(HOST_INSTANCE_PATH):/kerkoapp/instance -v $(HOST_DEV_LOG):/dev/log $(NAME) flask kerko sync

$(SECRETS):
	@echo "[ERROR] You must create '$(SECRETS)'."
	@exit 1

$(CONFIG):
	@echo "[ERROR] You must create '$(CONFIG)'."
	@exit 1

#
# Building and publishing targets.
#
# These work from a clone of the KerkoApp Git repository.
#

HASH = $(shell git rev-parse HEAD 2>/dev/null)
VERSION = $(shell git describe --exact-match --tags HEAD 2>/dev/null)

publish: | .git build
ifneq ($(shell git status --porcelain 2> /dev/null),)
	@echo "[ERROR] The Git working directory has uncommitted changes."
	@exit 1
endif
ifeq ($(findstring .,$(VERSION)),.)
	docker tag $(NAME) $(NAME):$(VERSION)
	docker push $(NAME):$(VERSION)
	docker tag $(NAME) $(NAME):latest
	docker push $(NAME):latest
else
	@echo "[ERROR] A proper version tag on the Git HEAD is required to publish."
	@exit 1
endif

build: | .git
ifeq ($(findstring .,$(VERSION)),.)
	docker build -t $(NAME) --no-cache --label "org.opencontainers.NAME.version=$(VERSION)" --label "org.opencontainers.NAME.created=$(shell date --rfc-3339=seconds)" $(MAKEFILE_DIR)
else
	docker build -t $(NAME) --no-cache --label "org.opencontainers.NAME.version=$(HASH)" --label "org.opencontainers.NAME.created=$(shell date --rfc-3339=seconds)" $(MAKEFILE_DIR)
endif

show_version: | .git
ifeq ($(findstring .,$(VERSION)),.)
	@echo "$(VERSION)"
else
	@echo "$(HASH)"
endif

clean_image: | .git
ifeq ($(findstring .,$(VERSION)),.)
	docker rmi $(NAME):$(VERSION)
else
	docker rmi $(NAME)
endif

.git:
	@echo "[ERROR] This target must run from a clone of the KerkoApp Git repository."
	@exit 1

.PHONY: run shell clean_kerko publish build show_version clean_image
