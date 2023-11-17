# gitops-demo
An example structure for a GitOps configuration backed by kustomize and flux.

## Bootstrapping

Bootstrapping a cluster requires admin privileges to the repo to generate deploy keys and write sync manifests back.

Generate a classic repo-scoped [Personal Access Token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
and set it:

```shell
export GITHUB_TOKEN=<personal-access-token>
```

While pointed at a k8s cluster, run:

```shell
flux bootstrap github --owner=fmilichovsky --repository=gitops-demo --path=profiles/$CLUSTER_PROFILE --branch=$BOOTSTRAP_BRANCH
```

This sets up Flux components on the cluster, generates key-pairs as secrets on the cluster, and uses the public key
to create a GitHub deploy key in the repo, tied to the PAT.
