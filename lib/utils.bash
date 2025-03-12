#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/arttor/helmify"
TOOL_NAME="helmify"
TOOL_TEST="helmify -version"

fail() {
	echo -e "asdf-$TOOL_NAME: $*"
	exit 1
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if helmify is not hosted on GitHub releases.
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

get_machine_os() {
	local OS
	OS=$(uname -s | tr '[:upper:]' '[:lower:]')

	case "${OS}" in
	darwin*) echo "Darwin" ;;
	linux*) echo "Linux" ;;
	*) fail "OS not supported: ${OS}" ;;
	esac
}

get_machine_arch() {
	local ARCH
	ARCH=$(uname -m | tr '[:upper:]' '[:lower:]')

	case "${ARCH}" in
	x86_64) echo "x86_64" ;;
	aarch64) echo "arm64" ;;
	armv8l) echo "arm64" ;;
	armv7l) arch="arm" ;;
	arm64) echo "arm64" ;;
	*) fail "Architecture not supported: $ARCH" ;;
	esac
}

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
	git ls-remote --tags --refs "$GH_REPO" |
		grep -o 'refs/tags/.*' | cut -d/ -f3- |
		sed 's/^v//' # NOTE: You might want to adapt this sed to remove non-version strings from tags
}

list_all_versions() {
	# TODO: Adapt this. By default we simply list the tag names from GitHub releases.
	# Change this function if helmify has other means of determining installable versions.
	list_github_tags
}

download_release() {
	local version filename url
	version="$1"
	filename="$2"

	if ! os=$(get_machine_os); then
		fail "$os"
	fi
	if ! arch=$(get_machine_arch); then
		fail "$arch"
	fi
	local platform="${os}_${arch}"
	# TODO: Adapt the release URL convention for helmify
	url="$GH_REPO/releases/download/v${version}/helmify_$platform.tar.gz"

	echo "$url"
	echo "* Downloading $TOOL_NAME release $version..."
	curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="${3%/bin}/bin"

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	(
		mkdir -p "$install_path"
		cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"

		# TODO: Assert helmify executable exists.
		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}
