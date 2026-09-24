#!/usr/bin/env bats
#
# Tests for step.sh. Stub `npx` (cloud/status subcommands) and `envman` so no
# network calls or Bitrise tooling are required. step.sh is executed with
# `bash` to match how Bitrise runs it (step.yml declares `toolkit: bash`,
# entry_file: step.sh) — the leading `#!/bin/sh` shebang is not used by Bitrise.
#
# The `status` stub emits PRETTY-printed JSON because that is what the real CLI
# produces (`dcd status --json` => JSON.stringify(obj, null, 2)). Fixture-based
# tests replay whole documents from test/fixtures/ (STUB_STATUS_FIXTURE), and
# STUB_STATUS_RAW replays arbitrary text (npm noise, non-JSON errors).

setup() {
  TEST_DIR="$(mktemp -d)"
  cp "${BATS_TEST_DIRNAME}/../step.sh" "${TEST_DIR}/step.sh"
  chmod +x "${TEST_DIR}/step.sh"

  mkdir -p "${TEST_DIR}/bin"

  # Stub npx. STUB_CLOUD_EXIT controls the `cloud` exit code (the step's primary
  # pass/fail signal); STUB_STATUS controls the status the `status` call reports.
  cat > "${TEST_DIR}/bin/npx" <<'STUB'
#!/usr/bin/env bash
sub=""
for a in "$@"; do
  if [ "$a" = "cloud" ] || [ "$a" = "status" ]; then sub="$a"; break; fi
done
case "$sub" in
  cloud)
    echo "STUB_CLOUD_CALLED_WITH: $*"
    # One line per argv entry as well, so a test can tell "-m a=b c" (three
    # words, from an unquoted expansion) from "-m" plus "a=b c" (two args).
    for a in "$@"; do echo "STUB_CLOUD_ARG: $a"; done
    echo "View results: https://console.devicecloud.dev/results?upload=fake-upload-id"
    code="${STUB_CLOUD_EXIT:-0}"
    # Like the real CLI: --json-file keeps the exit code at 0 on a failed run.
    for a in "$@"; do
      if [ "$a" = "--json-file" ] && [ "$code" = "2" ]; then code=0; fi
    done
    exit "$code"
    ;;
  status)
    if [ -n "${STUB_STATUS_RAW:-}" ]; then
      printf '%s\n' "${STUB_STATUS_RAW}"
      exit 0
    fi
    if [ -n "${STUB_STATUS_FIXTURE:-}" ]; then
      cat "${STUB_STATUS_FIXTURE}"
      exit 0
    fi
    st="${STUB_STATUS:-PASSED}"
    cat <<JSON
{
  "status": "${st}",
  "appBinaryId": "abi",
  "tests": [
    {
      "name": "t1",
      "status": "${st}"
    }
  ]
}
JSON
    ;;
esac
exit 0
STUB
  chmod +x "${TEST_DIR}/bin/npx"

  # Stub envman: record every call so we can assert on the outputs the step sets.
  export ENVMAN_LOG="${TEST_DIR}/envman.log"
  : > "${ENVMAN_LOG}"
  cat > "${TEST_DIR}/bin/envman" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "${ENVMAN_LOG}"
exit 0
STUB
  chmod +x "${TEST_DIR}/bin/envman"

  export PATH="${TEST_DIR}/bin:${PATH}"
  export BITRISE_SOURCE_DIR="${TEST_DIR}"
  export BITRISE_DEPLOY_DIR="${TEST_DIR}"

  # step.sh reads Bitrise inputs from lowercase env vars; clear any the host
  # runner may have exported so each test specifies exactly what it wants.
  unset api_key app_file workspace android_device android_api_level ios_device \
        name check_name async google_play debug disable_animations use_beta \
        env_list metadata download_artifacts json_file cancel_previous \
        include_github_context \
        STUB_STATUS STUB_CLOUD_EXIT STUB_STATUS_FIXTURE STUB_STATUS_RAW
  # ...and the Bitrise env vars the GitHub context is derived from, in case
  # the suite itself runs on Bitrise.
  unset GIT_REPOSITORY_URL BITRISE_GIT_COMMIT GIT_CLONE_COMMIT_HASH \
        BITRISE_GIT_BRANCH BITRISE_PULL_REQUEST BITRISEIO_PIPELINE_ID \
        BITRISE_BUILD_SLUG
  FIXTURES="${BATS_TEST_DIRNAME}/fixtures"
}

# The value the step handed to `envman add` for a given output key.
envman_value() {
  sed -n "s/^add --key $1 --value //p" "${ENVMAN_LOG}"
}

teardown() {
  rm -rf "${TEST_DIR}"
}

# --- Command composition -----------------------------------------------------

@test "invokes npx cloud with --apiKey and positional app_file/workspace" {
  export api_key="test-key"
  export app_file="app.apk"
  export workspace=".maestro"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STUB_CLOUD_CALLED_WITH:"* ]]
  [[ "$output" == *"--apiKey test-key"* ]]
  [[ "$output" == *"app.apk"* ]]
  [[ "$output" == *".maestro"* ]]
}

@test "never prints the API key itself" {
  export api_key="sk-live-do-not-print"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  # The key still reaches the CLI...
  [[ "$output" == *"STUB_CLOUD_ARG: sk-live-do-not-print"* ]]
  # ...but none of the step's own lines (everything the stub didn't print) shows it.
  own_output="$(printf '%s\n' "$output" | grep -v '^STUB_CLOUD_')"
  [[ "$own_output" != *"sk-live-do-not-print"* ]]
  [[ "$own_output" == *"api_key: [REDACTED]"* ]]
  [[ "$own_output" == *'--apiKey "[REDACTED]"'* ]]
}

@test "default package is the >=4.4.0 version range" {
  export api_key="k"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"@devicecloud.dev/dcd@>=4.4.0"* ]]
}

@test "use_beta=true selects the @beta package" {
  export api_key="k"
  export use_beta="true"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"@devicecloud.dev/dcd@beta"* ]]
}

@test "passes --android-device when android_device is set" {
  export api_key="k"
  export android_device="pixel-6"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--android-device pixel-6"* ]]
}

@test "maps assorted value flags (android-api-level, ios-device, name)" {
  export api_key="k"
  export android_api_level="34"
  export ios_device="iphone-15"
  export name="My Run"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--android-api-level 34"* ]]
  [[ "$output" == *"--ios-device iphone-15"* ]]
  [[ "$output" == *"--name My Run"* ]]
}

@test "sends check_name as a single gh_check_name metadata pair" {
  # A space in the value must survive as one argument: it reaches the backend as
  # the GitHub check's name, and a split would leave a stray positional where the
  # app file / workspace go.
  export api_key="k"
  export check_name="iOS smoke"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STUB_CLOUD_ARG: gh_check_name=iOS smoke"* ]]
}

@test "sends no gh_check_name when check_name is unset" {
  export api_key="k"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"gh_check_name"* ]]
}

@test "passes --async only when async=true" {
  export api_key="k"

  export async="true"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--async"* ]]

  export async="false"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"--async"* ]]
}

@test "passes --cancel-previous only when cancel_previous=true" {
  export api_key="k"

  export cancel_previous="true"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--cancel-previous"* ]]

  export cancel_previous="false"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"--cancel-previous"* ]]
}

@test "boolean flags appear only when their inputs are true" {
  export api_key="k"
  export google_play="true"
  export debug="true"
  export disable_animations="true"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--google-play"* ]]
  [[ "$output" == *"--debug"* ]]
  [[ "$output" == *"--disable-animations"* ]]
}

@test "env_list becomes repeated -e flags, skipping blank lines" {
  export api_key="k"
  export env_list=$'FOO=1\n\nBAR=2\n'
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"-e FOO=1"* ]]
  [[ "$output" == *"-e BAR=2"* ]]
}

@test "metadata becomes repeated -m flags" {
  export api_key="k"
  export metadata=$'branch=main\nsha=abc'
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"-m branch=main"* ]]
  [[ "$output" == *"-m sha=abc"* ]]
}

# --- GitHub context from Bitrise env vars ------------------------------------

@test "derives the gh_* context for a GitHub PR build" {
  export api_key="k"
  export GIT_REPOSITORY_URL="https://github.com/acme/widgets.git"
  export BITRISE_GIT_COMMIT="deadbeef"
  export GIT_CLONE_COMMIT_HASH="mergecommit"
  export BITRISE_GIT_BRANCH="feature/login"
  export BITRISE_PULL_REQUEST="7"
  export BITRISEIO_PIPELINE_ID="pipeline-123"
  export BITRISE_BUILD_SLUG="build-9"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STUB_CLOUD_ARG: gh_repo=acme/widgets"* ]]
  [[ "$output" == *"STUB_CLOUD_ARG: gh_sha=deadbeef"* ]]
  [[ "$output" == *"STUB_CLOUD_ARG: gh_branch=feature/login"* ]]
  [[ "$output" == *"STUB_CLOUD_ARG: gh_pr_number=7"* ]]
  [[ "$output" == *"STUB_CLOUD_ARG: gh_pr_url=https://github.com/acme/widgets/pull/7"* ]]
  # The pipeline build, shared by every workflow in it, not this build.
  [[ "$output" == *"STUB_CLOUD_ARG: gh_run_id=pipeline-123"* ]]
  [[ "$output" != *"build-9"* ]]
  [[ "$output" != *"mergecommit"* ]]
}

@test "outside a pipeline gh_run_id is the build, and a branch build has no PR keys" {
  export api_key="k"
  export GIT_REPOSITORY_URL="https://github.com/acme/widgets"
  export BITRISE_GIT_COMMIT="deadbeef"
  export BITRISE_GIT_BRANCH="main"
  export BITRISE_BUILD_SLUG="build-9"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STUB_CLOUD_ARG: gh_repo=acme/widgets"* ]]
  [[ "$output" == *"STUB_CLOUD_ARG: gh_branch=main"* ]]
  [[ "$output" == *"STUB_CLOUD_ARG: gh_run_id=build-9"* ]]
  [[ "$output" != *"gh_pr_number"* ]]
  [[ "$output" != *"gh_pr_url"* ]]
}

@test "falls back to the cloned commit when no commit triggered the build" {
  export api_key="k"
  export GIT_REPOSITORY_URL="https://github.com/acme/widgets.git"
  export GIT_CLONE_COMMIT_HASH="cafef00d"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STUB_CLOUD_ARG: gh_sha=cafef00d"* ]]
}

@test "reads ssh, scp-style, credentialed and mixed-case GitHub remotes" {
  export api_key="k"
  for url in "git@github.com:acme/widgets.git" \
             "ssh://git@github.com/acme/widgets.git" \
             "https://x-access-token:secret@github.com/acme/widgets.git" \
             "https://GitHub.com/acme/widgets/"; do
    export GIT_REPOSITORY_URL="$url"
    run bash "${TEST_DIR}/step.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"STUB_CLOUD_ARG: gh_repo=acme/widgets"* ]]
    [[ "$output" != *"secret@"* ]]
  done
}

@test "attaches no GitHub repo context for other hosts, only the run id" {
  export api_key="k"
  export BITRISE_GIT_COMMIT="deadbeef"
  export BITRISE_GIT_BRANCH="main"
  export BITRISE_PULL_REQUEST="7"
  export BITRISE_BUILD_SLUG="build-9"
  for url in "https://gitlab.com/acme/widgets.git" \
             "git@bitbucket.org:acme/widgets.git" \
             "https://github.example.com/acme/widgets.git" \
             "https://notgithub.com/acme/widgets.git"; do
    export GIT_REPOSITORY_URL="$url"
    run bash "${TEST_DIR}/step.sh"
    [ "$status" -eq 0 ]
    [[ "$output" != *"gh_repo="* ]]
    [[ "$output" != *"gh_sha="* ]]
    [[ "$output" != *"gh_branch="* ]]
    [[ "$output" != *"gh_pr_number="* ]]
    [[ "$output" == *"STUB_CLOUD_ARG: gh_run_id=build-9"* ]]
  done
}

@test "a key set in the metadata input wins over the derived one" {
  export api_key="k"
  export metadata=$'gh_repo=acme/mirror\ngh_branch=release'
  export GIT_REPOSITORY_URL="https://github.com/acme/widgets.git"
  export BITRISE_GIT_COMMIT="deadbeef"
  export BITRISE_GIT_BRANCH="feature/login"
  export BITRISE_PULL_REQUEST="7"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STUB_CLOUD_ARG: gh_repo=acme/mirror"* ]]
  [[ "$output" == *"STUB_CLOUD_ARG: gh_branch=release"* ]]
  [[ "$output" != *"gh_repo=acme/widgets"* ]]
  [[ "$output" != *"gh_branch=feature/login"* ]]
  # A PR URL built from the Bitrise repo would point at the wrong repository.
  [[ "$output" != *"gh_pr_url"* ]]
  [[ "$output" == *"STUB_CLOUD_ARG: gh_sha=deadbeef"* ]]
}

@test "include_github_context=false attaches none of it" {
  export api_key="k"
  export include_github_context="false"
  export GIT_REPOSITORY_URL="https://github.com/acme/widgets.git"
  export BITRISE_GIT_COMMIT="deadbeef"
  export BITRISE_GIT_BRANCH="main"
  export BITRISEIO_PIPELINE_ID="pipeline-123"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"gh_"* ]]
}

# --- Outputs & exit code -----------------------------------------------------

@test "emits DEVICE_CLOUD_CONSOLE_URL via envman (parsed from cloud output)" {
  export api_key="k"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  grep -qF -- "--key DEVICE_CLOUD_CONSOLE_URL --value https://console.devicecloud.dev/results?upload=fake-upload-id" "${ENVMAN_LOG}"
}

@test "a failing cloud run propagates a non-zero exit code" {
  export api_key="k"
  export STUB_CLOUD_EXIT=1
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -ne 0 ]
}

@test "a passing cloud run exits 0" {
  export api_key="k"
  export STUB_CLOUD_EXIT=0
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
}

# --- Status JSON outputs (pretty-printed, as the real CLI prints them) --------

@test "emits DEVICE_CLOUD_UPLOAD_STATUS from status JSON" {
  export api_key="k"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  grep -qF -- "--key DEVICE_CLOUD_UPLOAD_STATUS --value PASSED" "${ENVMAN_LOG}"
}

@test "emits DEVICE_CLOUD_APP_BINARY_ID from status JSON" {
  export api_key="k"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  grep -qF -- "--key DEVICE_CLOUD_APP_BINARY_ID --value abi" "${ENVMAN_LOG}"
}

@test "fixture: a passing run sets every status output and exits 0" {
  export api_key="k"
  export STUB_STATUS_FIXTURE="${FIXTURES}/status-passed.json"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [ "$(envman_value DEVICE_CLOUD_UPLOAD_STATUS)" = "PASSED" ]
  [ "$(envman_value DEVICE_CLOUD_APP_BINARY_ID)" = "abi" ]
  [ "$(envman_value DEVICE_CLOUD_FLOW_RESULTS)" = '[{"name":"./flows/login.yaml","status":"PASSED"},{"name":"./flows/search.yaml","status":"PASSED"}]' ]
}

@test "fixture: a failed run reports FAILED with the fail reason and fails the step" {
  export api_key="k"
  export STUB_STATUS_FIXTURE="${FIXTURES}/status-failed.json"
  export STUB_CLOUD_EXIT=2
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 1 ]
  [ "$(envman_value DEVICE_CLOUD_UPLOAD_STATUS)" = "FAILED" ]
  [ "$(envman_value DEVICE_CLOUD_FLOW_RESULTS)" = '[{"name":"./flows/login.yaml","status":"PASSED"},{"name":"./flows/search.yaml","status":"FAILED","failReason":"Assertion is false: \"Results\" is visible"}]' ]
}

@test "json_file: a FAILED run fails the step although dcd exits 0" {
  # --json-file keeps the CLI's exit code at 0 on a failed run (the stub does
  # the same), so the status is the only failure signal the step gets. Before
  # the status JSON was parsed, these runs passed the step.
  export api_key="k"
  export json_file="true"
  export STUB_STATUS_FIXTURE="${FIXTURES}/status-failed.json"
  export STUB_CLOUD_EXIT=2
  run bash "${TEST_DIR}/step.sh"
  [[ "$output" == *"STUB_CLOUD_ARG: --json-file"* ]]
  [ "$status" -eq 1 ]
  [ "$(envman_value DEVICE_CLOUD_UPLOAD_STATUS)" = "FAILED" ]
}

@test "json_file: a PASSED run passes the step" {
  export api_key="k"
  export json_file="true"
  export STUB_STATUS_FIXTURE="${FIXTURES}/status-passed.json"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [ "$(envman_value DEVICE_CLOUD_UPLOAD_STATUS)" = "PASSED" ]
}

@test "json_file: an unreadable status fails the step, since dcd's exit code is no verdict" {
  export api_key="k"
  export json_file="true"
  export STUB_STATUS_RAW="npm error code ETIMEDOUT"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 1 ]
  [ "$(envman_value DEVICE_CLOUD_UPLOAD_STATUS)" = "ERROR" ]

  # An async submission has no verdict to lose, so it still passes.
  : > "${ENVMAN_LOG}"
  export async="true"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
}

@test "fixture: a superseded run reports SUPERSEDED and passes the step" {
  # The API rolls the superseded run's cancelled tests up to FAILED; the
  # supersededBy field is what says a newer run replaced it.
  export api_key="k"
  export STUB_STATUS_FIXTURE="${FIXTURES}/status-superseded.json"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [ "$(envman_value DEVICE_CLOUD_UPLOAD_STATUS)" = "SUPERSEDED" ]
  [[ "$output" == *"Superseded by newer-upload-id"* ]]
  [[ "$output" == *"Newer run: https://console.devicecloud.dev/results?upload=newer-upload-id"* ]]
  [ "$(envman_value DEVICE_CLOUD_FLOW_RESULTS)" = '[{"name":"./flows/login.yaml","status":"PASSED"},{"name":"./flows/search.yaml","status":"CANCELLED"}]' ]
}

@test "fixture: a superseded run passes even when an older CLI exits 2 for it" {
  export api_key="k"
  export STUB_STATUS_FIXTURE="${FIXTURES}/status-superseded.json"
  export STUB_CLOUD_EXIT=2
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [ "$(envman_value DEVICE_CLOUD_UPLOAD_STATUS)" = "SUPERSEDED" ]
}

@test "json_file: a superseded run passes the step" {
  export api_key="k"
  export json_file="true"
  export cancel_previous="true"
  export STUB_STATUS_FIXTURE="${FIXTURES}/status-superseded.json"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [ "$(envman_value DEVICE_CLOUD_UPLOAD_STATUS)" = "SUPERSEDED" ]
}

@test "without supersededBy (older APIs, every other run) nothing is superseded" {
  export api_key="k"
  export STUB_STATUS_FIXTURE="${FIXTURES}/status-failed.json"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 1 ]
  [[ "$output" != *"Superseded"* ]]
  [ "$(envman_value DEVICE_CLOUD_UPLOAD_STATUS)" = "FAILED" ]
}

@test "a PASSED status does not clear a failing CLI exit code" {
  export api_key="k"
  export STUB_STATUS_FIXTURE="${FIXTURES}/status-passed.json"
  export STUB_CLOUD_EXIT=2
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"dcd exited 2"* ]]
}

@test "still reads compact status JSON" {
  export api_key="k"
  export STUB_STATUS_RAW='{"status":"FAILED","appBinaryId":"abc","tests":[{"name":"t1","status":"FAILED"}]}'
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 1 ]
  [ "$(envman_value DEVICE_CLOUD_UPLOAD_STATUS)" = "FAILED" ]
  [ "$(envman_value DEVICE_CLOUD_APP_BINARY_ID)" = "abc" ]
}

@test "skips npm noise printed ahead of the status JSON" {
  export api_key="k"
  STUB_STATUS_RAW="npm warn exec The following package was not found and will be installed: @devicecloud.dev/dcd@5.6.0
$(cat "${FIXTURES}/status-passed.json")"
  export STUB_STATUS_RAW
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [ "$(envman_value DEVICE_CLOUD_UPLOAD_STATUS)" = "PASSED" ]
}

@test "status output with no JSON reports ERROR and leaves the verdict to the CLI" {
  export api_key="k"
  export STUB_STATUS_RAW="npm error code ETIMEDOUT"

  export STUB_CLOUD_EXIT=0
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  [ "$(envman_value DEVICE_CLOUD_UPLOAD_STATUS)" = "ERROR" ]
  [ "$(envman_value DEVICE_CLOUD_FLOW_RESULTS)" = "[]" ]

  : > "${ENVMAN_LOG}"
  export STUB_CLOUD_EXIT=2
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 1 ]
  [ "$(envman_value DEVICE_CLOUD_UPLOAD_STATUS)" = "ERROR" ]
}
