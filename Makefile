SHELL := bash
# Pass HOME via the environment, never interpolate paths into shell code.
export HOME

.PHONY: all
all: dotfiles
	sudo apt install python3-pip python3-argcomplete shellcheck eza

.PHONY: dotfiles
dotfiles: ## Installs the explicit manifest, backing up conflicting files.
	bash ./install.sh

.PHONY: etc usr
etc usr: ## Unavailable: this checkout contains no etc/ or usr/ installation resources.
	@echo 'This checkout has no supported $@ installation manifest; no system files were changed.' >&2
	@exit 1

.PHONY: test
test: shellcheck ## Runs offline regression checks and configuration syntax checks.
	bash ./tests/run.sh

.PHONY: check
check: ## Legacy Docker check (requires the missing test.sh; use make test).
	@test -f ./test.sh || { echo 'Legacy check requires missing test.sh; use make test for local validation.' >&2; exit 1; }
	docker run --rm -it \
		--name df-test \
		-v "$$PWD:/usr/src" \
		--workdir /usr/src \
		m0r13n/dftest:1.1 ./test.sh

.PHONY: shellcheck
shellcheck: ## Lints the explicit list of Bash sources and scripts.
	bash ./shellcheck.sh

.PHONY: help
help:
	@grep -E '^[a-zA-Z_ -]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
