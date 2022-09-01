SHELL := /bin/bash

ligo_compiler=docker run --rm -v "$(PWD)":"$(PWD)" -w "$(PWD)" ligolang/ligo:stable
PROTOCOL_OPT=

# ^ use LIGO en var bin if configured, otherwise use docker

project_root=--project-root .
# ^ required when using packages

help:
	@grep -E '^[ a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
	awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

compile = $(ligo_compiler) compile contract $(project_root) ./src/$(1) -o ./compiled/$(2) $(3) $(PROTOCOL_OPT)
# ^ compile contract to michelson or micheline

test = $(ligo_compiler) run test $(project_root) ./test/$(1) $(PROTOCOL_OPT)
# ^ run given test file

compile: ## compile contracts
	@if [ ! -d ./compiled ]; then mkdir ./compiled ; fi
	@$(call compile,main.jsligo,dao.tz)
	@$(call compile,main.jsligo,dao.json,--michelson-format json)

clean: ## clean up
	@rm -rf compiled

deploy: ## deploy
	@if [ ! -f ./scripts/metadata.json ]; then cp scripts/metadata.json.dist \
        scripts/metadata.json ; fi
	@npx ts-node ./scripts/deploy.ts

install: ## install dependencies
	@if [ ! -f ./.env ]; then cp .env.dist .env ; fi
	@$(ligo_compiler) install
	@npm i

compile-lambda: ## compile a lambda (F=./lambdas/empty_operation_list.mligo make compile-lambda)
# ^ helper to compile lambda from a file, used during development of lambdas
ifndef F
	@echo 'please provide an init file (F=)'
else
	@$(ligo_compiler) compile expression $(project_root) jsligo lambda_ --init-file $(F) $(PROTOCOL_OPT)
	# ^ the lambda is expected to be bound to the name 'lambda_'
endif

pack-lambda: ## pack lambda expression (F=./lambdas/empty_operation_list.mligo make pack-lambda)
# ^ helper to get packed lambda and hash
ifndef F
	@echo 'please provide an init file (F=)'
else
	@echo 'Packed:'
	@$(ligo_compiler) run interpret $(project_root) 'Bytes.pack(lambda_)' --init-file $(F) $(PROTOCOL_OPT)
	@echo "Hash (sha256):"
	@$(ligo_compiler) run interpret $(project_root) 'Crypto.sha256(Bytes.pack(lambda_))' --init-file $(F) $(PROTOCOL_OPT)
endif

.PHONY: test
test: ## run tests (SUITE=propose make test)
ifndef SUITE
	@$(call test,cancel.test.jsligo)
	@$(call test,end_vote.test.jsligo)
	@$(call test,execute.test.jsligo)
	@$(call test,lock.test.jsligo)
	@$(call test,propose.test.jsligo)
	@$(call test,release.test.jsligo)
	@$(call test,vote.test.jsligo)
else
	@$(call test,$(SUITE).test.jsligo)
endif

lint: ## lint code
	@npx eslint ./scripts --ext .ts

sandbox-start: ## start sandbox
	@./scripts/run-sandbox

sandbox-stop: ## stop sandbox
	@docker stop sandbox
