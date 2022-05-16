REPO=guiddeco
IMAGE=letsencrypt-gcloud-balancer
TAG=latest

.PHONY: release
release: build push

.PHONY: build
build:
	docker build . -t ${REPO}/${IMAGE}:${TAG}

.PHONY: build
push:
	docker push ${REPO}/${IMAGE}:${TAG}
