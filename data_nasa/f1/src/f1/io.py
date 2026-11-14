"""Shared I/O for the NASA pipelines."""

from pathlib import Path
import subprocess
import tempfile
import time


def require(ok, message):
    if not ok:
        raise ValueError(message)


def download(url):
    content = subprocess.run(
        ["curl", "--fail", "--silent", "--show-error", "--location", "--retry", "2",
         "--retry-delay", "3", "--connect-timeout", "20", "--max-time", "150", url],
        stdout=subprocess.PIPE, check=True,
    ).stdout
    time.sleep(1)
    return content


def save_raw(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as temporary:
        staged = Path(temporary.name)
    try:
        staged.write_bytes(content)
        staged.replace(path)
    finally:
        staged.unlink(missing_ok=True)
