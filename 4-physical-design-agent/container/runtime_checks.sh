#!/usr/bin/env bash

# Shared read-only checks. Source stack.env before calling these functions.

# load_dotenv <dir>: read KEY=VALUE lines from <dir>/.env into the environment,
# without overwriting variables already set in the shell. The file is parsed, not
# executed (no code runs from it). Lines that are blank or start with # are skipped.
load_dotenv() {
    local env_file="$1/.env"
    [[ -f "${env_file}" ]] || return 0
    local k v
    while IFS='=' read -r k v; do
        k="${k#"${k%%[![:space:]]*}"}"       # trim leading whitespace
        k="${k%"${k##*[![:space:]]}"}"        # trim trailing whitespace
        [[ -z "${k}" || "${k}" == \#* ]] && continue
        v="${v%$'\r'}"                        # strip CR (Windows line endings)
        v="${v#"${v%%[![:space:]]*}"}"        # trim leading whitespace
        v="${v%\"}"; v="${v#\"}"; v="${v%\'}"; v="${v#\'}"   # strip quotes
        [[ -z "${!k:-}" ]] && export "${k}=${v}"
    done < "${env_file}"
}

require_singularity() {
    if ! command -v singularity >/dev/null 2>&1; then
        echo "ERROR: SingularityCE is not available." >&2
        return 1
    fi

    SINGULARITY_VERSION_TEXT=$(singularity --version)
    if [[ ! "${SINGULARITY_VERSION_TEXT}" =~ ([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        echo "ERROR: Could not parse SingularityCE version: ${SINGULARITY_VERSION_TEXT}" >&2
        return 1
    fi
    local major=${BASH_REMATCH[1]}
    local minor=${BASH_REMATCH[2]}
    # 4.3+ is sufficient (Grace ships 4.3.7; Olympus 4.5). Everything this flow
    # uses -- OCI digest pull, exec, --cleanenv -- works on 4.3.
    if (( major < 4 || (major == 4 && minor < 3) )); then
        echo "ERROR: SingularityCE 4.3 or later is required." >&2
        echo "Found: ${SINGULARITY_VERSION_TEXT}" >&2
        return 1
    fi
    export SINGULARITY_VERSION_TEXT
}

verify_course_sif() {
    local sif_path=$1
    local local_checksum_file=$2
    if [[ ! -r "${sif_path}" ]]; then
        echo "ERROR: Course image not found: ${sif_path}" >&2
        echo "Run ./container/pull_sif.sh or contact the teaching staff." >&2
        return 1
    fi

    ACTUAL_SIF_SHA=$(sha256sum "${sif_path}" | awk '{print $1}')
    if [[ "${ACTUAL_SIF_SHA}" == "${SIF_SHA256}" ]]; then
        SIF_PROVENANCE="staff-provided checksum"
        export ACTUAL_SIF_SHA SIF_PROVENANCE
        return 0
    fi

    local source_label arch_label local_record=""
    source_label=$(singularity inspect "${sif_path}" | sed -n \
        's/^org.label-schema.usage.singularity.deffile.from: //p')
    arch_label=$(singularity inspect "${sif_path}" | sed -n \
        's/^org.label-schema.build-arch: //p')
    if [[ -r "${local_checksum_file}" ]]; then
        local_record=$(awk 'NR == 1 {print $1}' "${local_checksum_file}")
    fi

    if [[ "${local_record}" != "${ACTUAL_SIF_SHA}" ]] || \
        [[ "${source_label}" != "${OCI_IMAGE}@${OCI_IMAGE_DIGEST}" ]] || \
        [[ "${arch_label}" != "amd64" ]]; then
        echo "ERROR: SIF checksum/provenance verification failed." >&2
        echo "Expected staff checksum: ${SIF_SHA256}" >&2
        echo "Actual checksum:         ${ACTUAL_SIF_SHA}" >&2
        return 1
    fi

    SIF_PROVENANCE="verified local exact-digest conversion"
    export ACTUAL_SIF_SHA SIF_PROVENANCE
}
