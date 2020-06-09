
PKG_PATH = github.com/citadelium/iam
LINTER_IMAGE ?= citadel-linter
TESTER_IMAGE ?= citadel-tester
GOLANG_IMAGE ?= golang:1.14
POSTGRES_IMAGE ?= postgres:10.7-alpine

.PHONY: run fmt lint test deps-up \
	_init_iam_db

run:
	@docker-compose up --build

fmt:
	@echo "Formatting files..."
	@docker run --rm \
		-v $(CURDIR):/go \
		--entrypoint gofmt \
		$(GOLANG_IMAGE) -w -l -s \
		./pkg ./iam-server

lint:
	@echo "Preparing linter..."
	@docker build -t $(LINTER_IMAGE) -f ./tools/linter.dockerfile . > /dev/null
	@echo "Running lint..."
	@docker run --rm \
		-v $(CURDIR):/go/src/$(PKG_PATH) \
		--workdir /go/src/$(PKG_PATH) \
		$(LINTER_IMAGE) \
		./pkg/... ./iam-server/...

test:
	@echo "Preparing test runner..."
	@docker build -t $(TESTER_IMAGE) -f ./tools/tester.dockerfile . > /dev/null
	@echo "Executing unit tests..."
	@docker run --rm \
		-v $(CURDIR):/go/src/$(PKG_PATH) \
		--workdir /go/src/$(PKG_PATH) \
		$(TESTER_IMAGE) test -v ./...

deps-up:
	@echo "Updating all dependencies..."
	@docker run --rm \
		-v $(CURDIR):/$(PKG_PATH) \
		--workdir /$(PKG_PATH) \
		$(GOLANG_IMAGE) /bin/sh -c "go get -u all && go mod tidy"

# audit: https://github.com/securego/gosec

_init_iam_db:
	docker run --rm -v $(CURDIR)/iam/pkg/iamserver/migrations:/migrations \
		--entrypoint=psql --network=citadel_default \
		$(POSTGRES_IMAGE) \
		-f ./migrations/000.00-iam.sql \
		"postgres://iam:hdig8g4g49htuhe@iam-db/iam?sslmode=disable"