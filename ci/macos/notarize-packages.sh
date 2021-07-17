#!/bin/bash

set -e

script_dir=$(dirname "$0")

OSTYPE=$(uname)

if [ "${OSTYPE}" != "Darwin" ]; then
    echo "[Error] macOS package script can be run on Darwin-type OS only."
    exit 1
fi

mkdir release
cd release
for url in $URLs; do
	wget "$url"
done
cd -

if [[ "$RELEASE_MODE" == "True" ]]; then
	:> requests

	for FILENAME in release/*; do
		echo "=> Submitting package $FILENAME for notarization"
		UPLOAD_RESULT=$(xcrun altool \
			--notarize-app \
			--primary-bundle-id "$MACOS_BUNDLEID" \
			--username "$AC_USERNAME" \
			--password "$AC_PASSWORD" \
			--asc-provider "$AC_PROVIDER_SHORTNAME" \
			--file "$FILENAME")

		REQUEST_UUID=$(echo $UPLOAD_RESULT | awk -F ' = ' '/RequestUUID/ {print $2}')
		echo "Request UUID: $REQUEST_UUID"
		echo "$REQUEST_UUID $FILENAME" >> requests
	done

	t=10
	while read -u 3 REQUEST_UUID FILENAME; do
		echo "=> Wait for notarization result of $REQUEST_UUID $FILENAME"
		# Pieces of code borrowed from rednoah/notarized-app
		while sleep $t && date; do
			CHECK_RESULT=$(xcrun altool \
				--notarization-info "$REQUEST_UUID" \
				--username "$AC_USERNAME" \
				--password "$AC_PASSWORD" \
				--asc-provider "$AC_PROVIDER_SHORTNAME")
			echo $CHECK_RESULT

			if ! grep -q "Status: in progress" <<< "$CHECK_RESULT"; then
				echo "$CHECK_RESULT" >> release/${PLUGIN_NAME}-${GIT_TAG}-macos-codesign.log
				t=1
				break
			fi
			t=10
		done
	done 3< requests
else
	echo "=> Skipped installer codesigning and notarization"
fi
