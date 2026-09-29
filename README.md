# bitrise-integration

The **Device Cloud for Maestro** Bitrise step: runs your Maestro flows on
[devicecloud.dev](https://devicecloud.dev) from a Bitrise workflow. Every input
is described in [`step.yml`](step.yml); the user guide is at
[docs.devicecloud.dev](https://docs.devicecloud.dev/ci-cd-integration/bitrise-steps).

## Outputs

| Output | Value |
|---|---|
| `DEVICE_CLOUD_CONSOLE_URL` | The run in the DeviceCloud console. |
| `DEVICE_CLOUD_UPLOAD_STATUS` | `PASSED`, `FAILED`, `PENDING`, `QUEUED` or `RUNNING`; `SUPERSEDED` when a newer run replaced this one through `cancel_previous`; `ERROR` when the status could not be read. |
| `DEVICE_CLOUD_FLOW_RESULTS` | JSON array, one entry per flow: `[{"name": "...", "status": "PASSED"}]`, plus `failReason` for a failed flow. |
| `DEVICE_CLOUD_APP_BINARY_ID` | The uploaded binary, to reuse through `app_binary_id`. |

The step fails when the run fails, whether or not `json` or `json_file` is set.
A run that a newer one superseded (`cancel_previous`) passes.

## GitHub context

For a repository on github.com, the step attaches the build's GitHub context to
the run as metadata, read from Bitrise's env vars:

| Metadata key | From |
|---|---|
| `gh_repo` | `GIT_REPOSITORY_URL` |
| `gh_sha` | `BITRISE_GIT_COMMIT`, else `GIT_CLONE_COMMIT_HASH` |
| `gh_branch` | `BITRISE_GIT_BRANCH` |
| `gh_pr_number`, `gh_pr_url` | `BITRISE_PULL_REQUEST` (PR builds) |
| `gh_run_id` | `BITRISEIO_PIPELINE_ID`, else `BITRISE_BUILD_SLUG` (any repository) |

With the DeviceCloud GitHub App connected, `gh_repo` + `gh_sha` make DeviceCloud
post a GitHub check for the run, and `cancel_previous` matches runs on `gh_repo`
plus the PR or branch (and `check_name`). Runs sharing a `gh_run_id` (the
workflows of one pipeline build) never cancel each other. A key you set in the
`metadata` input wins over the derived one; set `include_github_context` to
`false` to attach none of them.

## Tests

```bash
npm install -g bats
bats test/test.bats
```

Run the suite under bash 4.1 or later: bash 3.2 (macOS's `/bin/bash`) does not
fail a test on a `[[ ]]` assertion that isn't its last command.

## Releasing

Releases are cut by [release-please](https://github.com/googleapis/release-please).

1. PR titles must follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, ...). The `PR Title` check enforces this. PRs are squash-merged, so the title becomes the commit that release-please reads. `feat` cuts a minor release; `fix`, `perf`, `deps`, `revert` and `refactor` cut a patch; `docs`, `chore`, `test`, `ci`, `build` and `style` cut nothing.
2. release-please keeps a `chore(main): release X.Y.Z` PR open. It updates `CHANGELOG.md` and the two lines marked `x-release-please-version`: `BITRISE_STEP_VERSION` in `bitrise.yml` and the default `DCD_CI_WRAPPER_VERSION` in `step.sh`. A test checks that they match. Don't bump them by hand.
3. Merging it creates the bare `X.Y.Z` tag (the StepLib requires no `v`) and the GitHub Release.
4. Publishing to the [Bitrise StepLib](https://github.com/bitrise-io/bitrise-steplib) is still manual. Check out the new tag, run `bitrise run share-this-step` (it shares into our fork, `devicecloud-dev/bitrise-steplib`), then open the PR from the fork to `bitrise-io/bitrise-steplib`.

Never move or delete a tag once it's been shared: the StepLib pins each version to its tag's commit.
