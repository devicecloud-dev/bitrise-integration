#!/bin/sh

# Print one field of the `dcd status --json` document read from stdin: a string
# as-is, anything else as compact JSON, nothing when the field is absent or
# null. "flowResults" is the tests array cut down to name, status and failReason.
# Exits 1 when stdin holds no JSON object.
#
# The CLI pretty-prints that document (JSON.stringify(obj, null, 2)), so the
# compact-JSON greps this replaces ('"status":"...') never matched and every
# status-derived output came out empty. node is always available here: the
# step runs the CLI through npx.
status_field() {
    node -e '
const text = require("fs").readFileSync(0, "utf8");
const start = text.search(/^[ \t]*\{/m);
let doc = null;
if (start !== -1) {
  try {
    doc = JSON.parse(text.slice(start, text.lastIndexOf("}") + 1));
  } catch (e) {
    doc = null;
  }
}
if (!doc || typeof doc !== "object" || Array.isArray(doc)) process.exit(1);
const field = process.argv[1];
const value =
  field === "flowResults"
    ? (Array.isArray(doc.tests) ? doc.tests : []).map((t) => {
        const r = { name: t && t.name, status: t && t.status };
        if (t && t.failReason) r.failReason = t.failReason;
        return r;
      })
    : doc[field];
if (value !== undefined && value !== null) {
  process.stdout.write(typeof value === "string" ? value : JSON.stringify(value));
}
' "$1"
}

# Parse env variables
env_list_parsed=""
if [ -n "$env_list" ]; then
    # Convert newline-separated key-value pairs to -e KEY=VALUE format
    while IFS='=' read -r key value; do
        if [ -n "$key" ]; then
            # Append each env var with -e prefix
            env_list_parsed="$env_list_parsed -e $key=$value"
        fi
    done <<< "$env_list"
fi

# Define minimum DCD version
if [ "$use_beta" = "true" ]; then
    DCD_VERSION="@devicecloud.dev/dcd@beta"
else
    DCD_VERSION="@devicecloud.dev/dcd@>=4.4.0"
fi

# Parse metadata list (similar to env_list)
metadata_parsed=""
if [ -n "$metadata" ]; then
    while IFS='=' read -r key value; do
        if [ -n "$key" ]; then
            metadata_parsed="$metadata_parsed -m $key=$value"
        fi
    done <<< "$metadata"
fi

# Refine variables
[[ "$async" == "true" ]] && is_async="true"
[[ "$google_play" == "true" ]] && is_google_play="true"
[[ "$cancel_previous" == "true" ]] && is_cancel_previous="true"
[[ "$ignore_sha_check" == "true" ]] && is_ignore_sha_check="true"
[[ "$show_crosshairs" == "true" ]] && is_show_crosshairs="true"
[[ "$maestro_chrome_onboarding" == "true" ]] && is_maestro_chrome_onboarding="true"
[[ "$android_no_snapshot" == "true" ]] && is_android_no_snapshot="true"
[[ "$debug" == "true" ]] && is_debug="true"
[[ "$json" == "true" ]] && is_json="true"
[[ "$json_file" == "true" ]] && is_json_file="true"
[[ "$dry_run" == "true" ]] && is_dry_run="true"
[[ "$disable_animations" == "true" ]] && is_disable_animations="true"
[[ "$quiet" == "true" ]] && is_quiet="true"
# Change to source directory
cd $BITRISE_SOURCE_DIR

EXIT_CODE=0

# Log all variables for debugging, except the API key itself: don't rely on
# Bitrise's log redaction to catch a secret the step prints on purpose.
echo "DCD variables:"
echo "allure_path: $allure_path"
echo "android_api_level: $android_api_level"
echo "android_device: $android_device"
echo "android_no_snapshot: $android_no_snapshot"
echo "api_key: ${api_key:+[REDACTED]}"
echo "api_url: $api_url"
echo "app_binary_id: $app_binary_id"
echo "app_file: $app_file"
echo "artifacts_path: $artifacts_path"
echo "async: $async"
echo "cancel_previous: $cancel_previous"
echo "config: $config"
echo "device_locale: $device_locale"
echo "download_artifacts: $download_artifacts"
echo "dry_run: $dry_run"
echo "env_list: $env_list"
echo "exclude_flows: $exclude_flows"
echo "exclude_tags: $exclude_tags"
echo "google_play: $google_play"
echo "html_path: $html_path"
echo "ignore_sha_check: $ignore_sha_check"
echo "include_tags: $include_tags"
echo "ios_device: $ios_device"
echo "ios_version: $ios_version"
echo "json: $json"
echo "json_file: $json_file"
echo "json_file_name: $json_file_name"
echo "junit_path: $junit_path"
echo "maestro_chrome_onboarding: $maestro_chrome_onboarding"
echo "maestro_version: $maestro_version"
echo "metadata: $metadata"
echo "name: $name"
echo "orientation: $orientation"
echo "report: $report"
echo "retry: $retry"
echo "runner_type: $runner_type"
echo "render_engine: $render_engine"
echo "show_crosshairs: $show_crosshairs"
echo "workspace: $workspace"
echo "app_url: $app_url"
echo "disable_animations: $disable_animations"
echo "quiet: $quiet"
echo "use_beta: $use_beta"
echo "check_name: $check_name"

# check_name is passed as its own quoted `-m` pair rather than folded into
# metadata_parsed, which expands unquoted: a check name containing a space would
# split into two argv entries and the stray word would land as a positional (app
# file / workspace).
echo "Running command: npx --yes \"$DCD_VERSION\" cloud --quiet \
--apiKey \"${api_key:+[REDACTED]}\" \
${allure_path:+--allure-path \"$allure_path\"} \
${is_android_no_snapshot:+--android-no-snapshot} \
${android_api_level:+--android-api-level \"$android_api_level\"} \
${android_device:+--android-device \"$android_device\"} \
${api_url:+--api-url \"$api_url\"} \
${app_binary_id:+--app-binary-id \"$app_binary_id\"} \
${artifacts_path:+--artifacts-path \"$artifacts_path\"} \
${is_async:+--async} \
${is_cancel_previous:+--cancel-previous} \
${config:+--config \"$config\"} \
${is_debug:+--debug} \
${device_locale:+--device-locale \"$device_locale\"} \
${download_artifacts:+--download-artifacts \"$download_artifacts\"} \
${is_dry_run:+--dry-run} \
${exclude_flows:+--exclude-flows \"$exclude_flows\"} \
${exclude_tags:+--exclude-tags \"$exclude_tags\"} \
${is_google_play:+--google-play} \
${html_path:+--html-path \"$html_path\"} \
${is_ignore_sha_check:+--ignore-sha-check} \
${include_tags:+--include-tags \"$include_tags\"} \
${ios_device:+--ios-device \"$ios_device\"} \
${ios_version:+--ios-version \"$ios_version\"} \
${is_json:+--json} \
${is_json_file:+--json-file} \
${json_file_name:+--json-file-name \"$json_file_name\"} \
${junit_path:+--junit-path \"$junit_path\"} \
${is_maestro_chrome_onboarding:+--maestro-chrome-onboarding} \
${maestro_version:+--maestro-version \"$maestro_version\"} \
${name:+--name \"$name\"} \
${check_name:+-m \"gh_check_name=$check_name\"} \
${orientation:+--orientation \"$orientation\"} \
${report:+--report \"$report\"} \
${retry:+--retry \"$retry\"} \
${runner_type:+--runner-type \"$runner_type\"} \
${render_engine:+--render-engine \"$render_engine\"} \
${is_show_crosshairs:+--show-crosshairs} \
${app_url:+--app-url \"$app_url\"} \
${is_disable_animations:+--disable-animations} \
${is_quiet:+--quiet} \
${env_list_parsed} \
${metadata_parsed} \
\"$app_file\" \"$workspace\""

# Capture the command output and display it
echo "Waiting for full test results so we can parse outputs... this may take a while for non-async tests"
echo "Check status at https://console.devicecloud.dev/results"
# Forward CI identity so DCD notices can target this Bitrise step. DCD_STEP_VERSION
# can be set to forward the step version; provider alone enables CI-surface notices.
export DCD_CI_PROVIDER="bitrise"
export DCD_CI_WRAPPER_VERSION="${DCD_STEP_VERSION:-}"
OUTPUT=$(npx --yes "$DCD_VERSION" cloud --quiet \
--apiKey "$api_key" \
${allure_path:+--allure-path "$allure_path"} \
${is_android_no_snapshot:+--android-no-snapshot} \
${android_api_level:+--android-api-level "$android_api_level"} \
${android_device:+--android-device "$android_device"} \
${api_url:+--api-url "$api_url"} \
${app_binary_id:+--app-binary-id "$app_binary_id"} \
${artifacts_path:+--artifacts-path "$artifacts_path"} \
${is_async:+--async} \
${is_cancel_previous:+--cancel-previous} \
${config:+--config "$config"} \
${is_debug:+--debug} \
${device_locale:+--device-locale "$device_locale"} \
${download_artifacts:+--download-artifacts "$download_artifacts"} \
${is_dry_run:+--dry-run} \
${exclude_flows:+--exclude-flows "$exclude_flows"} \
${exclude_tags:+--exclude-tags "$exclude_tags"} \
${is_google_play:+--google-play} \
${html_path:+--html-path "$html_path"} \
${is_ignore_sha_check:+--ignore-sha-check} \
${include_tags:+--include-tags "$include_tags"} \
${ios_device:+--ios-device "$ios_device"} \
${ios_version:+--ios-version "$ios_version"} \
${is_json:+--json} \
${is_json_file:+--json-file} \
${json_file_name:+--json-file-name "$json_file_name"} \
${junit_path:+--junit-path "$junit_path"} \
${is_maestro_chrome_onboarding:+--maestro-chrome-onboarding} \
${maestro_version:+--maestro-version "$maestro_version"} \
${name:+--name "$name"} \
${check_name:+-m "gh_check_name=$check_name"} \
${orientation:+--orientation "$orientation"} \
${report:+--report "$report"} \
${retry:+--retry "$retry"} \
${runner_type:+--runner-type "$runner_type"} \
${render_engine:+--render-engine "$render_engine"} \
${is_show_crosshairs:+--show-crosshairs} \
${app_url:+--app-url "$app_url"} \
${is_disable_animations:+--disable-animations} \
${is_quiet:+--quiet} \
${env_list_parsed} \
${metadata_parsed} \
"$app_file" "$workspace" 2>&1) || EXIT_CODE=$?
echo "$OUTPUT"

# The CLI's exit code is the primary verdict: it is computed by the process that
# actually watched the run. 0 = every test passed, 1 = CLI/infra error, 2 = the
# run itself failed (a failed test, or a cancelled one). Keep it: the status
# block below may only add failures, never clear this one.
CLI_EXIT_CODE=$EXIT_CODE

# Extract upload ID from console URL
UPLOAD_ID=$(echo "$OUTPUT" | grep -o 'upload=[a-zA-Z0-9-]*' | cut -d= -f2 | head -n1)

if [ -n "$UPLOAD_ID" ]; then
    # Get test status using the status command
    STATUS_OUTPUT=$(npx --yes "$DCD_VERSION" status --json --upload-id "$UPLOAD_ID" --api-key "$api_key" ${api_url:+--api-url "$api_url"})

    # Console URL
    CONSOLE_URL=$(echo "$OUTPUT" | grep -o 'https://console\.devicecloud\.dev/results?upload=[a-zA-Z0-9-]*')
    envman add --key DEVICE_CLOUD_CONSOLE_URL --value "$CONSOLE_URL"

    # Status, flow results and binary id, read from the status JSON. ERROR marks
    # a status call that returned no JSON at all; the verdict below then rests
    # on the CLI's exit code alone, as it did while these outputs were empty.
    if TEST_STATUS=$(printf '%s' "$STATUS_OUTPUT" | status_field status); then
        FLOW_RESULTS=$(printf '%s' "$STATUS_OUTPUT" | status_field flowResults)
        APP_BINARY_ID=$(printf '%s' "$STATUS_OUTPUT" | status_field appBinaryId)
        SUPERSEDED_BY=$(printf '%s' "$STATUS_OUTPUT" | status_field supersededBy)
    else
        echo "Could not read the upload status from 'dcd status --json'; reporting ERROR. Output was:"
        echo "$STATUS_OUTPUT"
        TEST_STATUS="ERROR"
        FLOW_RESULTS=""
        APP_BINARY_ID=""
        SUPERSEDED_BY=""
    fi

    # supersededBy: a newer run from the same CI context replaced this one
    # (cancel_previous) and cancelled its queued tests. The API rolls those up
    # to FAILED, but the run no longer speaks for the commit, so, like
    # `dcd cloud` itself, the step does not fail for it. Absent on every other
    # run, and on APIs that predate the field.
    if [ -n "$SUPERSEDED_BY" ]; then
        echo "Superseded by $SUPERSEDED_BY: a newer run from the same CI context replaced this one, so this step passes."
        if [ -n "$CONSOLE_URL" ]; then
            echo "Newer run: ${CONSOLE_URL/$UPLOAD_ID/$SUPERSEDED_BY}"
        fi
        TEST_STATUS="SUPERSEDED"
    fi

    envman add --key DEVICE_CLOUD_UPLOAD_STATUS --value "$TEST_STATUS"
    envman add --key DEVICE_CLOUD_FLOW_RESULTS --value "${FLOW_RESULTS:-[]}"
    if [ -n "$APP_BINARY_ID" ]; then
        envman add --key DEVICE_CLOUD_APP_BINARY_ID --value "$APP_BINARY_ID"
    fi

    # Set exit code based on status. A bad status fails the step; a good one
    # only clears the step if the CLI agreed. Clearing it unconditionally is
    # what let a cancelled run (CLI exit 2) report green when the status
    # rollup wrongly said PASSED. A superseded run passes whatever dcd exited
    # with: an older CLI that doesn't know the state exits 2 for it.
    if [ "$TEST_STATUS" = "SUPERSEDED" ]; then
        if [ "$CLI_EXIT_CODE" -ne 0 ]; then
            echo "dcd exited $CLI_EXIT_CODE, but the run was superseded; not failing the step."
        fi
        EXIT_CODE=0
    elif [ "$TEST_STATUS" = "FAILED" ] || [ "$TEST_STATUS" = "CANCELLED" ]; then
        EXIT_CODE=1
    elif [ "$TEST_STATUS" = "PASSED" ] && [ "$CLI_EXIT_CODE" -eq 0 ]; then
        EXIT_CODE=0
    elif [ "$CLI_EXIT_CODE" -ne 0 ]; then
        echo "dcd exited $CLI_EXIT_CODE; failing the step despite upload status '$TEST_STATUS'."
        EXIT_CODE=1
    elif [ "$TEST_STATUS" = "ERROR" ] && [ "$is_json_file" = "true" ] && [ "$is_async" != "true" ]; then
        # json_file keeps dcd's exit code at 0 on a failed run, so without a
        # status nothing is left to tell a pass from a failure.
        echo "The upload status is unknown and json_file keeps dcd's exit code at 0; failing the step."
        EXIT_CODE=1
    fi
fi

# Handle artifacts download
if [ -n "$download_artifacts" ] && [ -f "artifacts.zip" ]; then
    case "$download_artifacts" in
        "ALL"|"FAILED")
            echo "Extracting artifacts.zip (mode: $download_artifacts)..."
            unzip -o artifacts.zip -d "$BITRISE_DEPLOY_DIR"
            if [ $? -eq 0 ]; then
                echo "Artifacts successfully extracted to $BITRISE_DEPLOY_DIR"
            else
                echo "Warning: Failed to extract artifacts.zip"
                EXIT_CODE=1
            fi
            ;;
        *)
            echo "Warning: Invalid download_artifacts value: $download_artifacts. Expected 'ALL' or 'FAILED'"
            ;;
    esac
fi

exit $EXIT_CODE