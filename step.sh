#!/bin/sh

# Parse env variables
env_list=""
if [ -n "$env" ]; then
    # Replace '\n' with ' -e '
    envs="${env//\\n/ -e }"
    # Prefix the whole string with '-e '
    env_list="-e $envs"
fi

# Refine variables
[[ "$async" == "true" ]] && is_async="true"

set -ex

# Change to source directory
cd $BITRISE_SOURCE_DIR

EXIT_CODE=0

# Log all variables for debugging
echo "Environment variables:"
# echo "api_key: [MASKED]"
echo "api_key: $api_key"
echo "api_url: $api_url"
echo "app_binary_id: $app_binary_id" 
echo "additional_app_binary_ids: $additional_app_binary_ids"
echo "additional_app_files: $additional_app_files"
echo "android_api_level: $android_api_level"
echo "android_device: $android_device"
echo "async: $async"
echo "device_locale: $device_locale"
echo "download_artifacts: $download_artifacts"
echo "exclude_flows: $exclude_flows"
echo "exclude_tags: $exclude_tags"
echo "google_play: $google_play"
echo "include_tags: $include_tags"
echo "ios_version: $ios_version"
echo "ios_device: $ios_device"
echo "name: $name"
echo "orientation: $orientation"
echo "retry: $retry"
echo "env: $env"
echo "app_file: $app_file"
echo "workspace: $workspace"
echo "env_list: $env_list"
echo "is_async: $is_async"


npx --yes @devicecloud.dev/dcd cloud --quiet \
--apiKey "$api_key" \
${api_url:+--api-url "$api_url"} \
${app_binary_id:+--app-binary-id "$app_binary_id"} \
${additional_app_binary_ids:+--additional-app-binary-ids "$additional_app_binary_ids"} \
${additional_app_files:+--additional-app-files "$additional_app_files"} \
${android_api_level:+--android-api-level "$android_api_level"} \
${android_device:+--android-device "$android_device"} \
${is_async:+--async} \
${device_locale:+--device-locale "$device_locale"} \
${download_artifacts:+--download-artifacts} \
${exclude_flows:+--exclude-flows "$exclude_flows"} \
${exclude_tags:+--exclude-tags "$exclude_tags"} \
${google_play:+--google-play} \
${include_tags:+--include-tags "$include_tags"} \
${ios_version:+--ios-version "$ios_version"} \
${ios_device:+--ios-device "$ios_device"} \
${name:+--name "$name"} \
${orientation:+--orientation "$orientation"} \
${retry:+--retry "$retry"} \
${env:+ $env} \
"$app_file" "$workspace" || EXIT_CODE=$?

# to do: handle download artifacts

exit $EXIT_CODE