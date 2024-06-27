DUNE = opam exec -- dune

.DEFAULT_GOAL := help

.PHONY: help
help: ## Print this help message
	@echo "List of available make commands";
	@echo "";
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}';
	@echo "";

.PHONY: init
init: ## Create opam switch
	opam switch create . 5.1.1 -y
	eval $(opam env)
	opam install dune

build: install ## build
	$(DUNE) build

.PHONY: watch
watch: ## build in watch mode
	$(DUNE) build -w

.PHONY: install
install: ## Install opam development dependencies
	opam install . --deps-only --with-test --yes

.PHONY: test
test: ## Run tests
	$(DUNE) build @gen --auto-promote
	$(DUNE) runtest

.PHONY: format
fmt: ## Run format
	$(DUNE) build @fmt --auto-promote
# end
