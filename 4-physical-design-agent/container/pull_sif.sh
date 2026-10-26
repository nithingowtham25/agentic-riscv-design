#!/usr/bin/env bash
set -euo pipefail

CONTAINER_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
LAB_ROOT=$(CDPATH= cd -- "${CONTAINER_DIR}/.." && pwd -P)

# Singularity caches image layers under $HOME by default. On HPRC Grace the home
# quota is only 10 GB, so the ~1.5 GB pull fails with "disk quota exceeded".
# Keep the cache (and the final SIF) on the package dir (scratch), unless preset.
export SINGULARITY_CACHEDIR="${SINGULARITY_CACHEDIR:-${LAB_ROOT}/.sing_cache}"
mkdir -p "${SINGULARITY_CACHEDIR}"

# IMPORTANT: build the SIF on fast LOCAL disk, not on Lustre/NFS scratch.
# Unpacking the image on a parallel filesystem that does not support xattrs
# (Grace $SCRATCH is Lustre) makes the Docker->SIF conversion take HOURS. Prefer
# a node-local tmp ($TMPDIR on Slurm = /tmp/job.<id>, local NVMe) when available.
if [[ -z "${SINGULARITY_TMPDIR:-}" ]]; then
    if [[ -n "${TMPDIR:-}" && -d "${TMPDIR}" ]]; then
        SINGULARITY_TMPDIR="${TMPDIR}/sing_build.$$"
    elif [[ -d /tmp ]]; then
        SINGULARITY_TMPDIR="/tmp/sing_build.${USER:-u}.$$"
    else
        SINGULARITY_TMPDIR="${LAB_ROOT}/.sing_tmp"
    fi
fi
export SINGULARITY_TMPDIR
mkdir -p "${SINGULARITY_TMPDIR}"

# shellcheck source=stack.env
source "${CONTAINER_DIR}/stack.env"
# shellcheck source=runtime_checks.sh
source "${CONTAINER_DIR}/runtime_checks.sh"

require_singularity

SIF_PATH="${LAB_ROOT}/${COURSE_SIF_FILE}"
LOCAL_CHECKSUM_FILE="${CONTAINER_DIR}/local_sif.sha256"

verify_source_labels() {
    local source_label arch_label
    source_label=$(singularity inspect "${SIF_PATH}" | sed -n \
        's/^org.label-schema.usage.singularity.deffile.from: //p')
    arch_label=$(singularity inspect "${SIF_PATH}" | sed -n \
        's/^org.label-schema.build-arch: //p')
    [[ "${source_label}" == "${OCI_IMAGE}@${OCI_IMAGE_DIGEST}" ]] && \
        [[ "${arch_label}" == "amd64" ]]
}

if [[ -e "${SIF_PATH}" ]]; then
    actual=$(sha256sum "${SIF_PATH}" | awk '{print $1}')
    if [[ "${actual}" == "${SIF_SHA256}" ]]; then
        echo "Course SIF already present and verified: ${SIF_PATH}"
        exit 0
    fi
    if [[ -r "${LOCAL_CHECKSUM_FILE}" ]] && \
        [[ "$(awk 'NR == 1 {print $1}' "${LOCAL_CHECKSUM_FILE}")" == "${actual}" ]] && \
        verify_source_labels; then
        echo "Locally converted SIF already present and verified: ${SIF_PATH}"
        exit 0
    fi
    echo "ERROR: Existing SIF has checksum ${actual}; expected ${SIF_SHA256}." >&2
    echo "It also lacks a matching verified local-conversion record." >&2
    echo "Move the unexpected file aside, then run this script again." >&2
    exit 1
fi

singularity pull --arch amd64 "${SIF_PATH}" \
    "docker://${OCI_IMAGE}@${OCI_IMAGE_DIGEST}"

actual=$(sha256sum "${SIF_PATH}" | awk '{print $1}')
if ! verify_source_labels; then
    echo "ERROR: Pulled SIF does not identify the pinned OCI source/architecture." >&2
    exit 1
fi

if [[ "${actual}" == "${SIF_SHA256}" ]]; then
    echo "Pulled and verified staff-identical SIF: ${SIF_PATH}"
else
    printf '%s  %s\n' "${actual}" "${COURSE_SIF_FILE}" > "${LOCAL_CHECKSUM_FILE}"
    echo "Pulled and verified an exact-digest local SIF conversion: ${SIF_PATH}"
    echo "Local SIF SHA-256: ${actual}"
fi
