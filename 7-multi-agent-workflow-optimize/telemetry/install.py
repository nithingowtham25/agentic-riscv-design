"""Download the official pinned collector once; no root or Docker needed."""

import hashlib
from pathlib import Path
import platform
import tarfile
import tempfile
from urllib.request import urlretrieve

VERSION = "0.165.0"


def main():
    system = {"Linux": "linux", "Darwin": "darwin"}.get(platform.system())
    machine = {
        "x86_64": "amd64",
        "AMD64": "amd64",
        "arm64": "arm64",
        "aarch64": "arm64",
    }.get(platform.machine())
    if not system or not machine:
        raise SystemExit(
            "Use the official collector release for this platform and set OTELCOL."
        )
    name = f"otelcol-contrib_{VERSION}_{system}_{machine}.tar.gz"
    base = f"https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v{VERSION}/{name}"
    destination = Path(__file__).parent / ".bin/otelcol-contrib"
    destination.parent.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory() as temp:
        archive = Path(temp) / name
        checksum = Path(temp) / "sha256"
        urlretrieve(base, archive)
        urlretrieve(base + ".sha256", checksum)
        if (
            hashlib.sha256(archive.read_bytes()).hexdigest()
            != checksum.read_text().split()[0]
        ):
            raise SystemExit("Collector checksum mismatch")
        with tarfile.open(archive) as package:
            data = package.extractfile("otelcol-contrib").read()
        destination.write_bytes(data)
        destination.chmod(0o755)
    print(f"Installed official collector {VERSION}: {destination}")


if __name__ == "__main__":
    main()
