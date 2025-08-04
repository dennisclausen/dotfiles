SHELL := bash

.PHONY: all
all: dotfiles 
	sudo apt install python3-pip python3-argcomplete shellcheck

.PHONY: dotfiles
dotfiles: ## Installs the dotfiles.
	# add aliases for dotfiles
	for file in $(shell find $(CURDIR) -name ".*" -not -name ".gitignore" -not -name ".git" -not -name ".config" -not -name ".github" -not -name ".*.swp" -not -name ".gnupg"); do \
		f=$$(basename $$file); \
		ln -sfn $$file $(HOME)/$$f; \
	done; \

	# add global gitignore
	ln -s -f $(CURDIR)/gitignore $(HOME)/.gitignore;

	# add global gitconf
	ln -s -f $(CURDIR)/gitconfig $(HOME)/.gitconfig;

	# make .config dir
	mkdir -p $(HOME)/.config;
	for file in $(shell find $(CURDIR)/.config -name "*" -type f); do \
		f=$$(echo $$file | sed -e 's|$(CURDIR)||'); \
		mkdir -p $(HOME)/$$(dirname $$f); \
		ln -s -f $$file $(HOME)/$$f; \
	done; \

	# symlink bash_profile
	ln -sf $(CURDIR)/.bash_profile $(HOME)/.profile;


.PHONY: etc
etc: ## Installs the etc directory files.
	# sudo mkdir -p /etc/docker/seccomp
	for file in $(shell find $(CURDIR)/etc -type f -not -name ".*.swp"); do \
		f=$$(echo $$file | sed -e 's|$(CURDIR)||'); \
		sudo mkdir -p $$(dirname $$f); \
		sudo ln -s -f $$file $$f; \
	done

.PHONY: usr
usr: ## Installs the usr directory files.
	for file in $(shell find $(CURDIR)/usr -type f -not -name ".*.swp"); do \
		f=$$(echo $$file | sed -e 's|$(CURDIR)||'); \
		sudo mkdir -p $$(dirname $$f); \
		sudo ln -s -f $$file $$f; \
	done

.PHONY: test
test: shellcheck ## Runs all the tests on the files in the repository.

.PHONY: check
check: # run the make script in a new ubuntu container
	docker run --rm -it \
		--name df-test \
		-v $(CURDIR):/usr/src \
		--workdir /usr/src \
		m0r13n/dftest:1.1 ./test.sh


# if this session isn't interactive, then we don't want to allocate a
# TTY, which would fail, but if it is interactive, we do want to attach
# so that the user can send e.g. ^C through.
INTERACTIVE := $(shell [ -t 0 ] && echo 1 || echo 0)
ifeq ($(INTERACTIVE), 1)
	DOCKER_FLAGS += -t
endif

.PHONY: shellcheck
shellcheck: ## Runs the shellcheck tests on the scripts.
	./shellcheck.sh

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
