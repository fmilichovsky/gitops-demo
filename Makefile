.PHONY: validate-kustomizations render-kustomizations

validate-kustomizations:
	./hack/kustomize.sh

render-kustomizations:
	./hack/kustomize.sh -r
