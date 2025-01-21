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

# Refine variables
[[ "$async" == "true" ]] && is_async="true"
[[ "$google_play" == "true" ]] && is_google_play="true"
[[ "$x86_arch" == "true" ]] && is_x86_arch="true"
[[ "$ignore_sha_check" == "true" ]] && is_ignore_sha_check="true"
# Change to source directory
cd $BITRISE_SOURCE_DIR

EXIT_CODE=0

# Log all variables for debugging
echo "DCD variables:"
echo "additional_app_binary_ids: $additional_app_binary_ids"
echo "additional_app_files: $additional_app_files"
echo "android_api_level: $android_api_level"
echo "android_device: $android_device"
echo "api_key: $api_key"
echo "api_url: $api_url"
echo "app_binary_id: $app_binary_id"
echo "app_file: $app_file"
echo "async: $async"
echo "device_locale: $device_locale"
echo "download_artifacts: $download_artifacts"
echo "env_list: $env_list"
echo "exclude_flows: $exclude_flows"
echo "exclude_tags: $exclude_tags"
echo "google_play: $google_play"
echo "include_tags: $include_tags"
echo "ios_device: $ios_device"
echo "ios_version: $ios_version"
echo "is_async: $is_async"
echo "maestro_version: $maestro_version"
echo "name: $name"
echo "orientation: $orientation"
echo "retry: $retry"
echo "workspace: $workspace"
echo "report: $report"
echo "ignore_sha_check: $ignore_sha_check"


echo "Running command: npx --yes @devicecloud.dev/dcd cloud --quiet \
--apiKey \"$api_key\" \
${api_url:+--api-url \"$api_url\"} \
${app_binary_id:+--app-binary-id \"$app_binary_id\"} \
${additional_app_binary_ids:+--additional-app-binary-ids \"$additional_app_binary_ids\"} \
${additional_app_files:+--additional-app-files \"$additional_app_files\"} \
${android_api_level:+--android-api-level \"$android_api_level\"} \
${android_device:+--android-device \"$android_device\"} \
${is_async:+--async} \
${device_locale:+--device-locale \"$device_locale\"} \
${download_artifacts:+--download-artifacts} \
${exclude_flows:+--exclude-flows \"$exclude_flows\"} \
${exclude_tags:+--exclude-tags \"$exclude_tags\"} \
${is_google_play:+--google-play} \
${include_tags:+--include-tags \"$include_tags\"} \
${ios_version:+--ios-version \"$ios_version\"} \
${ios_device:+--ios-device \"$ios_device\"} \
${name:+--name \"$name\"} \
${orientation:+--orientation \"$orientation\"} \
${retry:+--retry \"$retry\"} \
${maestro_version:+--maestro-version \"$maestro_version\"} \
${env_list_parsed} \
${report:+--report "$report"} \
${is_ignore_sha_check:+--ignore-sha-check} \
\"$app_file\" \"$workspace\""

npx --yes @devicecloud.dev/dcd cloud --quiet \
--apiKey "$api_key" \
${api_url:+--api-url "$api_url"} \
${app_binary_id:+--app-binary-id "$app_binary_id"} \
${additional_app_binary_ids:+--additional-app-binary-ids "$additional_app_binary_ids"} \
${additional_app_files:+--additional-app-files "$additional_app_files"} \
${android_api_level:+--android-api-level "$android_api_level"} \
${android_device:+--android-device "$android_device"} \
${is_async:+--async} \
${is_x86_arch:+--x86-arch} \
${device_locale:+--device-locale "$device_locale"} \
${download_artifacts:+--download-artifacts "$download_artifacts"} \
${exclude_flows:+--exclude-flows "$exclude_flows"} \
${exclude_tags:+--exclude-tags "$exclude_tags"} \
${is_google_play:+--google-play} \
${include_tags:+--include-tags "$include_tags"} \
${ios_version:+--ios-version "$ios_version"} \
${ios_device:+--ios-device "$ios_device"} \
${name:+--name "$name"} \
${orientation:+--orientation "$orientation"} \
${retry:+--retry "$retry"} \
${maestro_version:+--maestro-version "$maestro_version"} \
${env_list_parsed} \
${report:+--report "$report"} \
${is_ignore_sha_check:+--ignore-sha-check} \
"$app_file" "$workspace" || EXIT_CODE=$?

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