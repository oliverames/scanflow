#!/usr/bin/env bash
set -euo pipefail

SCHEME="${SCHEME:-ScanFlow App}"
PROJECT_FILE="${PROJECT_FILE:-ScanFlow.xcodeproj}"
APP_NAME="${APP_NAME:-ScanFlow}"
VERSION="${VERSION:-dev}"
RELEASE_ROOT="${RELEASE_ROOT:-dist/release/${VERSION}}"
ARCHIVE_PATH="${ARCHIVE_PATH:-${RELEASE_ROOT}/${APP_NAME}.xcarchive}"
UNNOTARIZED_ZIP="${UNNOTARIZED_ZIP:-${RELEASE_ROOT}/${APP_NAME}-${VERSION}-unsigned.zip}"
NOTARIZED_ZIP="${NOTARIZED_ZIP:-${RELEASE_ROOT}/${APP_NAME}-${VERSION}.zip}"
APPCAST_PATH="${APPCAST_PATH:-${RELEASE_ROOT}/appcast.xml}"

APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APPLE_APP_SPECIFIC_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-}"
SPARKLE_APPCAST_COMMAND="${SPARKLE_APPCAST_COMMAND:-}"

if [[ -z "${APPLE_ID}" || -z "${APPLE_TEAM_ID}" || -z "${APPLE_APP_SPECIFIC_PASSWORD}" ]]; then
  echo "Missing notarization credentials. Set APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_SPECIFIC_PASSWORD."
  exit 1
fi

mkdir -p "${RELEASE_ROOT}"

echo "Archiving ${APP_NAME} (${VERSION})..."
xcodebuild \
  -project "${PROJECT_FILE}" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "${ARCHIVE_PATH}" \
  archive

APP_PATH="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "Expected app bundle not found at ${APP_PATH}"
  exit 1
fi

echo "Creating notarization upload zip..."
ditto -c -k --keepParent "${APP_PATH}" "${UNNOTARIZED_ZIP}"

echo "Submitting zip for notarization..."
xcrun notarytool submit "${UNNOTARIZED_ZIP}" \
  --apple-id "${APPLE_ID}" \
  --team-id "${APPLE_TEAM_ID}" \
  --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
  --wait

echo "Stapling notarization ticket..."
xcrun stapler staple "${APP_PATH}"
xcrun stapler validate "${APP_PATH}"

echo "Creating final distributable zip..."
ditto -c -k --keepParent "${APP_PATH}" "${NOTARIZED_ZIP}"

if [[ -n "${SPARKLE_APPCAST_COMMAND}" ]]; then
  echo "Generating appcast via SPARKLE_APPCAST_COMMAND..."
  # Example:
  # SPARKLE_APPCAST_COMMAND='generate_appcast dist/release/1.2.3 --download-url-prefix https://example.com/downloads --output-path dist/release/1.2.3/appcast.xml'
  eval "${SPARKLE_APPCAST_COMMAND}"
else
  echo "SPARKLE_APPCAST_COMMAND not set; skipping appcast generation."
fi

echo "Release artifacts written to ${RELEASE_ROOT}"
