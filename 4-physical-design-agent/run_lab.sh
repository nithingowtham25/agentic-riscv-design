#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

# shellcheck source=container/stack.env
source "${LAB_ROOT}/container/stack.env"
# shellcheck source=container/runtime_checks.sh
source "${LAB_ROOT}/container/runtime_checks.sh"

require_singularity

# Keep Singularity's cache/tmp off the small HPRC home quota (see pull_sif.sh).
export SINGULARITY_CACHEDIR="${SINGULARITY_CACHEDIR:-${LAB_ROOT}/.sing_cache}"
export SINGULARITY_TMPDIR="${SINGULARITY_TMPDIR:-${LAB_ROOT}/.sing_tmp}"
mkdir -p "${SINGULARITY_CACHEDIR}" "${SINGULARITY_TMPDIR}"

SIF_PATH=${LAB4_SIF:-"${LAB_ROOT}/${COURSE_SIF_FILE}"}
verify_course_sif "${SIF_PATH}" "${LAB_ROOT}/container/local_sif.sha256"

# Load the key from a package-root .env if present (export in the shell also works).
load_dotenv "${LAB_ROOT}"

if [[ -z "${TAMUS_AI_CHAT_API_KEY:-}" ]]; then
    echo "ERROR: TAMUS_AI_CHAT_API_KEY is not set (put it in .env or export it)." >&2
    exit 1
fi

# On TAMU HPRC Grace, compute nodes reach the internet only through a proxy that
# the WebProxy module configures. Load it if present (a no-op on Olympus, which
# has no module command / no WebProxy). Harmless where not needed.
if command -v module >/dev/null 2>&1; then
    module load WebProxy 2>/dev/null || true
fi

# Singularity --cleanenv accepts host variables with this prefix. Passing the
# key via the environment avoids placing it in the command line or repository.
export SINGULARITYENV_TAMUS_AI_CHAT_API_KEY="${TAMUS_AI_CHAT_API_KEY}"
if [[ -n "${TAMUS_AI_CHAT_API_ENDPOINT:-}" ]]; then
    export SINGULARITYENV_TAMUS_AI_CHAT_API_ENDPOINT="${TAMUS_AI_CHAT_API_ENDPOINT}"
fi
# Forward the proxy into the container (needed on Grace; empty/unset on Olympus,
# where these simply pass through as empty and are ignored).
for _pv in http_proxy https_proxy ftp_proxy no_proxy \
           HTTP_PROXY HTTPS_PROXY FTP_PROXY NO_PROXY; do
    if [[ -n "${!_pv:-}" ]]; then
        export "SINGULARITYENV_${_pv}=${!_pv}"
    fi
done
export SINGULARITYENV_ORFS_FLOW_DIR="${ORFS_FLOW_DIR}"
export SINGULARITYENV_LAB4_RUNTIME="singularity"
export SINGULARITYENV_LAB4_IMAGE_VERSION="${COURSE_IMAGE_VERSION}"
export SINGULARITYENV_PYTHONDONTWRITEBYTECODE=1

exec singularity exec \
    --cleanenv \
    --bind "${LAB_ROOT}:/workspace/Assignment4" \
    --cwd /workspace/Assignment4 \
    "${SIF_PATH}" \
    bash -lc '
        set -euo pipefail
        source /OpenROAD-flow-scripts/env.sh >/dev/null
        exec python3 /workspace/Assignment4/student_code/run_agent.py "$@"
    ' run_agent "$@"
