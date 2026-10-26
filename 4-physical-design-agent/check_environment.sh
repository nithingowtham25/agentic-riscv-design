#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

# shellcheck source=container/stack.env
source "${LAB_ROOT}/container/stack.env"
# shellcheck source=container/runtime_checks.sh
source "${LAB_ROOT}/container/runtime_checks.sh"

require_singularity

SIF_PATH=${LAB4_SIF:-"${LAB_ROOT}/${COURSE_SIF_FILE}"}
LOCAL_CHECKSUM_FILE="${LAB_ROOT}/container/local_sif.sha256"
verify_course_sif "${SIF_PATH}" "${LOCAL_CHECKSUM_FILE}"

# Load the key from a package-root .env if present (export in the shell also works).
load_dotenv "${LAB_ROOT}"

if [[ -z "${TAMUS_AI_CHAT_API_KEY:-}" ]]; then
    echo "ERROR: TAMUS_AI_CHAT_API_KEY is not set (put it in .env or export it)." >&2
    exit 1
fi

# On TAMU HPRC Grace, compute nodes reach the internet only via the WebProxy
# module. Load it if present (a no-op on Olympus). Then forward the proxy into
# the container so the TAMU reachability probe below can connect.
if command -v module >/dev/null 2>&1; then
    module load WebProxy 2>/dev/null || true
fi

export SINGULARITYENV_TAMUS_AI_CHAT_API_KEY="${TAMUS_AI_CHAT_API_KEY}"
if [[ -n "${TAMUS_AI_CHAT_API_ENDPOINT:-}" ]]; then
    export SINGULARITYENV_TAMUS_AI_CHAT_API_ENDPOINT="${TAMUS_AI_CHAT_API_ENDPOINT}"
fi
for _pv in http_proxy https_proxy ftp_proxy no_proxy \
           HTTP_PROXY HTTPS_PROXY FTP_PROXY NO_PROXY; do
    if [[ -n "${!_pv:-}" ]]; then
        export "SINGULARITYENV_${_pv}=${!_pv}"
    fi
done
export SINGULARITYENV_ORFS_FLOW_DIR="${ORFS_FLOW_DIR}"
export SINGULARITYENV_ASAP7_PLATFORM_VERSION="${ASAP7_PLATFORM_VERSION}"
export SINGULARITYENV_PYTHONDONTWRITEBYTECODE=1
export SINGULARITYENV_EXPECTED_PYTHON_VERSION="${PYTHON_VERSION}"
export SINGULARITYENV_EXPECTED_YOSYS_VERSION="${YOSYS_VERSION}"
export SINGULARITYENV_EXPECTED_OPENROAD_VERSION="${OPENROAD_VERSION}"
export SINGULARITYENV_EXPECTED_KLAYOUT_VERSION="${KLAYOUT_VERSION}"
export SINGULARITYENV_EXPECTED_MAKE_VERSION="${MAKE_VERSION}"
export SINGULARITYENV_EXPECTED_TCL_VERSION="${TCL_VERSION}"

echo "Runtime:          ${SINGULARITY_VERSION_TEXT}"
echo "Image:            ${COURSE_SIF_FILE}"
echo "Image SHA-256:    ${ACTUAL_SIF_SHA}"
echo "SIF provenance:   ${SIF_PROVENANCE}"
echo "OCI digest:       ${OCI_IMAGE_DIGEST}"
echo "ORFS release:     ${ORFS_RELEASE}"
echo "ORFS commit:      ${ORFS_COMMIT}"
echo "Container arch:   ${CONTAINER_ARCH}"

singularity exec \
    --cleanenv \
    --bind "${LAB_ROOT}:/workspace/Assignment4" \
    --cwd /workspace/Assignment4 \
    "${SIF_PATH}" \
    bash -lc '
        set -euo pipefail
        source /OpenROAD-flow-scripts/env.sh >/dev/null

        python3 -c "import sys; assert sys.version_info >= (3, 10)"
        command -v yosys >/dev/null
        command -v openroad >/dev/null
        command -v klayout >/dev/null
        command -v make >/dev/null
        command -v tclsh >/dev/null
        test -d "${ORFS_FLOW_DIR}"
        test -f "${ORFS_FLOW_DIR}/Makefile"
        test -d "${ORFS_FLOW_DIR}/platforms/asap7"

        require_equal() {
            if [[ "$2" != "$3" ]]; then
                echo "ERROR: $1 version mismatch: expected $3, found $2" >&2
                exit 1
            fi
        }

        python_version=$(python3 -c "import platform; print(platform.python_version())")
        yosys_line=$(yosys -V 2>&1 | head -1)
        openroad_version=$(openroad -version 2>&1 | head -1 | xargs)
        klayout_version=$(klayout -v 2>&1 | head -1 | awk "{print \$2}")
        make_version=$(make --version 2>&1 | head -1 | awk "{print \$3}")
        tcl_version=$(printf "puts [info patchlevel]\n" | tclsh)

        require_equal Python "${python_version}" "${EXPECTED_PYTHON_VERSION}"
        [[ "${yosys_line}" == "Yosys ${EXPECTED_YOSYS_VERSION}"* ]] || {
            echo "ERROR: Yosys version mismatch: ${yosys_line}" >&2
            exit 1
        }
        require_equal OpenROAD "${openroad_version}" "${EXPECTED_OPENROAD_VERSION}"
        require_equal KLayout "${klayout_version}" "${EXPECTED_KLAYOUT_VERSION}"
        require_equal Make "${make_version}" "${EXPECTED_MAKE_VERSION}"
        require_equal Tcl "${tcl_version}" "${EXPECTED_TCL_VERSION}"

        write_test=$(mktemp /workspace/Assignment4/.lab4-write-test.XXXXXX)
        printf "writable\n" > "${write_test}"
        rm -f "${write_test}"

        echo "Python:           ${python_version}"
        echo "Yosys:            ${yosys_line}"
        echo "OpenROAD:         ${openroad_version}"
        echo "KLayout:          ${klayout_version}"
        echo "Make:             ${make_version}"
        echo "Tcl:              ${tcl_version}"
        echo "ORFS flow:        ${ORFS_FLOW_DIR}"
        echo "ASAP7 platform:   ${ASAP7_PLATFORM_VERSION}"
        echo "Writable bind:    PASS"

        python3 -m unittest discover -s tests -q
        echo "Infrastructure:   PASS"

        # Self-contained TAMU reachability probe. It does NOT use any student
        # code (you write your own LLM client) -- it only confirms your key and
        # the gateway work, by listing available models.
        python3 - <<"PY"
import json, os, sys, urllib.request
base = (os.getenv("TAMUS_AI_CHAT_API_ENDPOINT") or "https://chat-api.tamu.ai").rstrip("/")
key = os.environ["TAMUS_AI_CHAT_API_KEY"]
# A browser-like User-Agent is REQUIRED: the gateway sits behind Cloudflare,
# which returns 403 "error code: 1010" to requests with no User-Agent. Your own
# LLM client must send a User-Agent header for the same reason.
req = urllib.request.Request(
    base + "/openai/models",
    headers={
        "Authorization": "Bearer " + key,
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
    },
)
try:
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.load(r)
except Exception as exc:  # noqa: BLE001
    raise SystemExit(f"TAMU API probe failed: {exc}")
if not isinstance(data, dict) or "data" not in data:
    raise SystemExit(f"Unexpected TAMU API response shape: {data!r}")
print("TAMU API access:  PASS")
PY
    '

echo "Environment check: PASS"
