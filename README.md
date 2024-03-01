# api.rocket.rs

Builds the docs for [api.rocket.rs](https://api.rocket.rs).

## How it works (`build.sh`)

Everytime a commit gets pushed to any branch in the [Rocket] repository, a
webhook fires, triggering `./build.sh` in a cloud worker that:

  - Clones the `Rocket` repository.
  - Creates a worktree for each branch.
  - Builds the docs in parallel in each worktree.
  - Moves each `$branch/target/doc` to `output/${branch}`.
  - Copies `static/*` to `output/*`.
  - Uploads `output` to `api.rocket.rs`.

[Rocket]: https://github.com/rwf2/Rocket
