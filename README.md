# [api.rocket.rs]

Builds the docs for [api.rocket.rs].

## How it works (`build.sh`)

When a commit gets pushed to any branch in [Rocket], a webhook fires, triggering
`./build.sh` that:

  - Clones [Rocket] to `_rocket`.
  - Creates a worktree for each branch `_build`.
  - Builds the docs in parallel in each worktree, if cache is stale.
  - Copies each `$worktree/target/doc` to `_output/$branch`.
  - Copies `static/*` to `_output/`.
  - Uploads `_output` to [api.rocket.rs].

[Rocket]: https://github.com/rwf2/Rocket
[api.rocket.rs]: https://api.rocket.rs
