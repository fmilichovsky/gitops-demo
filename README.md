# GitOps structural demo

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

## Repository Structure

The repository is trunk-based, i.e. `main` fully describes the state of every environment simultaneously.

The configuration follows a [kustomize](https://kustomize.io/)-compatible structure,
heavily relying on layering and merging manifests.

Environment separation is modelled through a hierarchy of [`profiles`](#profiles), [`groups`](#groups) and [`overlays`](#overlays).

### Profiles

The [`profiles`](./profiles/) directory holds different variants of [Flux Kustomizations](https://fluxcd.io/flux/components/kustomize/kustomization/)
(Flux-specific CRDs, do not confuse with the standard [kustomizations](https://kubectl.docs.kubernetes.io/references/kustomize/glossary/#kustomization)).

A profile is a high-level declaration of a class of environments. It can reference multiple `overlays` (inside multiple `groups`).

### Groups

Groups provide a logical separation of resources.

- They allow the gitops controller to reconcile smaller chunks independently
(e.g. `apps` doesn't need to wait for `observability` and vice-versa).
- They give more targeted feedback on failures (which group failed to reconcile).
- They allow enforcing dependency ordering (using Flux's `dependensOn` field in `profile` kustomizations) - e.g. `apps` might
have a dependency on `infrastructure` with databases, certificate configurations, networking, etc.

The directory structure inside each `group` follows the general kustomization ideas of layered composition:

```txt
apps
├── base
│   ├── app1
│   └── app2
└── components
│   ├── feature1
│   └── feature2
└── overlays
    ├── dev
    ├── production
    └── staging
```

This repo defines a single group (`apps`) for simplicity.

### Base

The `base` directories contain the main resource manifests, in an environment-agnostic form (only define values which
make sense on *any* environment).

Base resources are **NOT** implicitly included in each environment - they're just a pool of available base definitions,
each `overlay` can pick and choose from them.

### Components

Using kustomization's [component concept](https://github.com/kubernetes-sigs/kustomize/blob/master/examples/components.md),
components hold reusable pieces of configuration/"reusable patches".

They should be used for generalized, self-contained modifications (like "enable debug logging", "allow CORS", etc.).

### Overlays

Overlays are more concrete definitions of a subset of a `profile`. A `production` profile could be composed of a
`production` overlay inside the `apps` group, and another `production` overlay inside the `infrastructure` group.

Overlays are placed inside `<group>/overlays/` directories, with a separate subdirectory for each overlay.

An overlay **must** have a root [`Kustomization`](https://kubectl.docs.kubernetes.io/references/kustomize/glossary/#kustomization)
in `kustomization.yaml`. The root will reference all of the relevant `base` manifests, and any `patches` modifying
the base resources.

`patches` are organized into additional subdirectories to easily identify which resource they're meant to modify.

```txt
apps/overlays/dev
├── app1
│   ├── settings.yaml
│   └── version.yaml
├── app2
│   └── version.yaml
```

### Patches

[Patches](https://github.com/kubernetes-sigs/kustomize/blob/master/examples/inlinePatch.md)
are environment(`overlay`)-specific overrides.

They should generally:

- be small, ideally targeting a single field, or a small set of related fields
(more small patches are better than a single big one).
- be exclusive to a single `overlay`. No cross-references between overlays (reasonable amount of duplication is acceptable).
- have a name describing the *intent* behind what they modify (e.g. `replicas.yaml` rather than `deployment-patch.yaml`).

## Common Processes

General principles for systematically propagating changes across environments.

- Changes should generally propagate through stages (profiles) in a gradual manner.
- Changes should rarely be applied directly to `base` manifests. Common exceptions are:
  - A new `base` definition is being added.
  - All profiles share an identical overlay - ["lifting" it up](#unifying-changes-into-base) into `base`
  is effectively a transitional no-op.
  - The change is known to be trivial and **100% safe** - still consider a gradual rollout anyway.

## Environment promotions

This should effectively be a file-copy operation from one `overlay` to another, no explicit manual changes.

E.g. to make `production` adopt whatever version of a service is in `staging`:

```shell
cp apps/overlays/staging/<service>/version.yaml apps/overlays/production/<service>/version.yaml 
```

> Note that both environments have to be referencing the patch in their `kustomization.yaml` - if the promotion is
happening on a "new" patch, it has to be manually added to the target kustomization's patches to take effect.

## Including a new service

Including a new service/component in a profile has to be an explicit decision from an engineer. It involves:

- Referencing the `base` manifest of the service in the root `kustomization.yaml` of the given `overlay`
(e.g. `apps/overlays/development/kustomization.yaml` => `.resources` and `.patches`).
- Copying/defining any promotable patches in a subdirectory. E.g. adopting `podinfo` into `staging`, after it has been
verified to work in `dev`:

  ```shell
  cp -R apps/overlays/dev/podinfo apps/overlays/staging
  ```

## Persistent environment-specific override

To determine whether a patch should propagate across environments, we conventially prefix "static", i.e. non-promotable
patches inside any `overlay` with an underscore (`_`).

E.g. to override the number of replicas of a given service _only_ in `staging`, you would:

- Define a valid kustomization patch in `apps/overlays/staging/<service>/_replicas.yaml`.
- Reference it in `.patches` in `apps/overlays/staging/kustomization.yaml`.

## Unifying changes into base

In case a change has propagated through all environments via overlays and it should become a long-term part of the
`base` configuration, it can be "lifted-up":

- Include the equivalent change from the `patch`es in the `base`
(whatever the result of merging the `base` with the `patch` should be).
- Remove the individual `patch` files from all overlays.
- Remove all patch references in individual `kustomization.yaml`s.

> This should be a no-op - a transitive operation that results in no diff when rendering the kustomizations
(potential field reordering at most).
