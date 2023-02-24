#!/bin/bash
export ORIGINAL_PWD=$(pwd)
BASE_BASE=$(cd $(dirname $0); pwd)
BASE_URL="http://packages.linuxmint.com/"
RELEASES="victoria"
COMPONENTS="main backport import upstream"
ARCHITECTURES="source"

onExit() {
    cd "${ORIGINAL_PWD}" 2>/dev/null || exit
}

trap "onExit" INT EXIT ERR

REPO=${1:?You must specify a repository}
BASE_DIR="${BASE_BASE}/${REPO}"
if [[ ! -d "${BASE_DIR}" ]]; then
    echo "${BASE_DIR} does not exist. Do you want to create it?"
    read -n1 -r -p "[Y|n]" REPLY
    if [[ $REPLY =~ n|N ]]; then
        exit 1
    else
        mkdir -p "${BASE_DIR}"
    fi
fi

pushd "${BASE_DIR}" >/dev/null || exit
ARIA_LIST="${BASE_DIR}/aria.txt"
[[ -f "${ARIA_LIST}" ]] && rm "${ARIA_LIST}"


parseSources() {
    local SOURCES=${1}
    cat "$SOURCES" | while read line; do 
        [[ $line =~ Directory ]] && export _D="${line##* }";
        [[ $line =~ Checksum ]] && export _F=0;
        if [[ "$_F" == "1" ]]; then
            if [[ $line =~ \.tar|\.dsc ]]; then
                file=$(echo "$line" | cut -d' ' -f3);
                echo -e "$BASE_URL/$_D/$file\n    dir=${BASE_DIR}/${_D}\n    out=$file";
            fi
        fi
        [[ $line =~ Files ]] && export _F=1;
    done
}

parseAriaList() {
    local LIST="${1}"
    while read line; do
        if [[ $line =~ dir= ]]; then
            if [[ ! -d "${BASE_DIR}/${line##*=}" ]]; then
                mkdir -p "${BASE_DIR}/${line##*=}"
            fi
        fi
    done < "${LIST}"
}

downloadUsingAria() {
    local LIST="${1}"
    aria2c -i "${LIST}" \
        --continue=true \
        --allow-overwrite=false \
        --always-resume=false \
        --auto-file-renaming=false
}

for release in $RELEASES; do
    for component in $COMPONENTS; do
        for architecture in $ARCHITECTURES; do
            export SOURCE_DIR="${BASE_DIR}/${release}/${component}/${architecture}"
            mkdir -p "${SOURCE_DIR}"
            curl -o "${SOURCE_DIR}/Sources.gz" "${BASE_URL}/dists/${release}/${component}/${architecture}/Sources.gz"
            gzip -dc "${SOURCE_DIR}/Sources.gz" > "${SOURCE_DIR}/Sources"

            parseSources "${SOURCE_DIR}/Sources" >> "${ARIA_LIST}"
        done
    done
done
read -p "Ready to download"
if [[ $REPLY =~ n|N ]]; then 
    exit
fi
parseAriaList "${ARIA_LIST}"
downloadUsingAria "${ARIA_LIST}"