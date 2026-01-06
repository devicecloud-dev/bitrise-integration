#!/bin/sh

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
DCD_VERSION="@devicecloud.dev/dcd@>=4.2.5"

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
[[ "$ignore_sha_check" == "true" ]] && is_ignore_sha_check="true"
[[ "$show_crosshairs" == "true" ]] && is_show_crosshairs="true"
[[ "$maestro_chrome_onboarding" == "true" ]] && is_maestro_chrome_onboarding="true"
[[ "$android_no_snapshot" == "true" ]] && is_android_no_snapshot="true"
[[ "$debug" == "true" ]] && is_debug="true"
[[ "$json" == "true" ]] && is_json="true"
[[ "$json_file" == "true" ]] && is_json_file="true"
[[ "$dry_run" == "true" ]] && is_dry_run="true"
# Change to source directory
cd $BITRISE_SOURCE_DIR

EXIT_CODE=0

# Log all variables for debugging
echo "DCD variables:"
echo "allure_path: $allure_path"
echo "android_api_level: $android_api_level"
echo "android_device: $android_device"
echo "android_no_snapshot: $android_no_snapshot"
echo "api_key: $api_key"
echo "api_url: $api_url"
echo "app_binary_id: $app_binary_id"
echo "app_file: $app_file"
echo "artifacts_path: $artifacts_path"
echo "async: $async"
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
echo "show_crosshairs: $show_crosshairs"
echo "workspace: $workspace"

echo "Running command: npx --yes \"$DCD_VERSION\" cloud --quiet \
--apiKey \"$api_key\" \
${allure_path:+--allure-path \"$allure_path\"} \
${is_android_no_snapshot:+--android-no-snapshot} \
${android_api_level:+--android-api-level \"$android_api_level\"} \
${android_device:+--android-device \"$android_device\"} \
${api_url:+--api-url \"$api_url\"} \
${app_binary_id:+--app-binary-id \"$app_binary_id\"} \
${artifacts_path:+--artifacts-path \"$artifacts_path\"} \
${is_async:+--async} \
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
${orientation:+--orientation \"$orientation\"} \
${report:+--report \"$report\"} \
${retry:+--retry \"$retry\"} \
${runner_type:+--runner-type \"$runner_type\"} \
${is_show_crosshairs:+--show-crosshairs} \
${env_list_parsed} \
${metadata_parsed} \
\"$app_file\" \"$workspace\""

# Capture the command output and display it
echo "Waiting for full test results so we can parse outputs... this may take a while for non-async tests"
echo "Check status at https://console.devicecloud.dev/results"
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
${orientation:+--orientation "$orientation"} \
${report:+--report "$report"} \
${retry:+--retry "$retry"} \
${runner_type:+--runner-type "$runner_type"} \
${is_show_crosshairs:+--show-crosshairs} \
${env_list_parsed} \
${metadata_parsed} \
"$app_file" "$workspace" 2>&1) || EXIT_CODE=$?
echo "$OUTPUT"

# Extract upload ID from console URL
UPLOAD_ID=$(echo "$OUTPUT" | grep -o 'upload=[a-zA-Z0-9-]*' | cut -d= -f2 | head -n1)

if [ -n "$UPLOAD_ID" ]; then
    # Get test status using the status command
    STATUS_OUTPUT=$(npx --yes "$DCD_VERSION" status --json --upload-id "$UPLOAD_ID" --api-key "$api_key" ${api_url:+--api-url "$api_url"})
    
    # Extract values from status JSON using grep and sed
    # Console URL
    CONSOLE_URL=$(echo "$OUTPUT" | grep -o 'https://console\.devicecloud\.dev/results?upload=[a-zA-Z0-9-]*')
    envman add --key DEVICE_CLOUD_CONSOLE_URL --value "$CONSOLE_URL"
    
    # Status
    TEST_STATUS=$(echo "$STATUS_OUTPUT" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    envman add --key DEVICE_CLOUD_UPLOAD_STATUS --value "$TEST_STATUS"
    
    # Flow Results
    FLOW_RESULTS=$(echo "$STATUS_OUTPUT" | grep -o '"tests":\[[^]]*\]')
    envman add --key DEVICE_CLOUD_FLOW_RESULTS --value "$FLOW_RESULTS"
    
    # App Binary ID
    APP_BINARY_ID=$(echo "$STATUS_OUTPUT" | grep -o '"appBinaryId":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$APP_BINARY_ID" ]; then
        envman add --key DEVICE_CLOUD_APP_BINARY_ID --value "$APP_BINARY_ID"
    fi
    
    # Set exit code based on status
    if [ "$TEST_STATUS" = "FAILED" ]; then
        EXIT_CODE=1
    elif [ "$TEST_STATUS" = "PASSED" ]; then
        EXIT_CODE=0
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