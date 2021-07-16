#!/usr/bin/env bash
#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------
#
# Docs: https://github.com/microsoft/vscode-dev-containers/blob/main/script-library/docs/github.md
# Maintainer: The VS Code and Codespaces Teams
#
# Syntax: ./github-debian.sh [version]

CLI_VERSION=${1:-"latest"}

GITHUB_CLI_ARCHIVE_GPG_KEY=C99B11DEB97541F0

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

function getCommonSetting() {
    if [ "${COMMON_SETTINGS_LOADED}" != "true" ]; then
        curl -sL --fail-with-body "https://aka.ms/vscode-dev-containers/script-library/settings.env" 2>/dev/null -o /tmp/vsdc-settings.env || echo "Could not download settings file. Skipping."
        COMMON_SETTINGS_LOADED=true
    fi
    local multi_line=""
    if [ "$2" = "true" ]; then multi_line="-z"; fi
    if [ -f "/tmp/vsdc-settings.env" ]; then
        if [ ! -z "$1" ]; then declare -g $1="$(grep ${multi_line} -oP "${$1}=\"?\K[^\"]+" /tmp/vsdc-settings.env | tr -d '\0')"; fi
    fi
}

export DEBIAN_FRONTEND=noninteractive

# Install curl, apt-transport-https, curl, gpg, or dirmngr if missing
if ! dpkg -s curl ca-certificates apt-transport-https dirmngr gnupg2 > /dev/null 2>&1; then
    if [ ! -d "/var/lib/apt/lists" ] || [ "$(ls /var/lib/apt/lists/ | wc -l)" = "0" ]; then
        apt-get update
    fi
    apt-get -y install --no-install-recommends curl ca-certificates apt-transport-https dirmngr gnupg2
fi

if [ "${CLI_VERSION}" != "latest" ] && [ "${CLI_VERSION}" != "lts" ] && [ "${CLI_VERSION}" != "stable" ]; then
    VERSION_SUFFIX="=${CLI_VERSION}"
else
    VERSION_SUFFIX=""
fi

# Install the GitHub CLI
echo "Downloading github CLI..."
# Use different home to ensure nothing pollutes user directories
export GNUPGHOME="/tmp/gh/gnupg"
mkdir -p "${GNUPGHOME}"
chmod 700 ${GNUPGHOME}
# Import key safely (new method rather than deprecated apt-key approach) and install
. /etc/os-release
getCommonSetting GITHUB_CLI_ARCHIVE_GPG_KEY
gpg -q --no-default-keyring --keyring /usr/share/keyrings/githubcli-archive-keyring.gpg --keyserver keyserver.ubuntu.com --receive-keys ${GITHUB_CLI_ARCHIVE_GPG_KEY}
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages ${VERSION_CODENAME} main" > /etc/apt/sources.list.d/github-cli.list
apt-get update
apt-get -y install "gh${VERSION_SUFFIX}"
rm -rf "/tmp/gh/gnupg"
echo "Done!"
