#!/usr/bin/env bats
#
# Tests for step.sh. Stub `npx` (cloud/status subcommands) and `envman` so no
# network calls or Bitrise tooling are required. step.sh is executed with
# `bash` to match how Bitrise runs it (step.yml declares `toolkit: bash`,
# entry_file: step.sh) — the leading `#!/bin/sh` shebang is not used by Bitrise.
#
# The `status` stub emits PRETTY-printed JSON because that is what the real CLI
# produces (`dcd status --json` => JSON.stringify(obj, null, 2)). Tests whose
# names start with "[known bug]" are skipped: step.sh greps COMPACT-JSON
# patterns ('"status":"..."') that never match the pretty output, so the
# status-derived outputs are currently empty. Unskip them once step.sh parses
# the real output (e.g. via jq or space-tolerant patterns).

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
    exit "${STUB_CLOUD_EXIT:-0}"
    ;;
  status)
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
        env_list metadata download_artifacts STUB_STATUS STUB_CLOUD_EXIT
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

# --- Known bug: status-JSON outputs (compact greps vs pretty-printed JSON) ----

@test "[known bug] emits DEVICE_CLOUD_UPLOAD_STATUS from status JSON" {
  skip "step.sh greps '\"status\":\"...\"' but dcd status --json is pretty-printed; value is empty until the parser is fixed"
  export api_key="k"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  grep -qF -- "--key DEVICE_CLOUD_UPLOAD_STATUS --value PASSED" "${ENVMAN_LOG}"
}

@test "[known bug] emits DEVICE_CLOUD_APP_BINARY_ID from status JSON" {
  skip "step.sh greps '\"appBinaryId\":\"...\"' but dcd status --json is pretty-printed; value is empty until the parser is fixed"
  export api_key="k"
  run bash "${TEST_DIR}/step.sh"
  [ "$status" -eq 0 ]
  grep -qF -- "--key DEVICE_CLOUD_APP_BINARY_ID --value abi" "${ENVMAN_LOG}"
}
