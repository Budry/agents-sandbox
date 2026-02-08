IMAGE_NAME := docker-registry.zaruba-ondrej.dev/codex-sandbox

.PHONY: build
build:
	docker build -t $(IMAGE_NAME) -f Dockerfile .
	docker push $(IMAGE_NAME)
