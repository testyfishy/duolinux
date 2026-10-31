"""Small, dependency-free helpers used by the whole toolkit."""

from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
import sys
import tarfile
import time
import urllib.request
from pathlib import Path

_COLOR = sys.stdout.isatty() and os.environ.get("NO_COLOR") is None


def _c(code: str, text: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _COLOR else text


def banner(text: str) -> None:
    print()
    print(_c("1;36", f"── {text} " + "─" * max(0, 68 - len(text))))


def info(msg: str) -> None:
    print(f"  {msg}")


def ok(msg: str) -> None:
    print(f"  {_c('32', '✓')} {msg}")


def warn(msg: str) -> None:
    print(f"  {_c('33', '!')} {msg}")


def err(msg: str) -> None:
    print(f"  {_c('31', '✗')} {msg}", file=sys.stderr)


def die(msg: str, code: int = 1) -> "NoReturn":
    err(msg)
    raise SystemExit(code)


def which(name: str) -> str | None:
    return shutil.which(name)


def run(
    cmd: list[str] | str,
    *,
    cwd: Path | str | None = None,
    env: dict[str, str] | None = None,
    check: bool = True,
    quiet: bool = False,
    timeout: int | None = None,
    input_text: str | None = None,
) -> subprocess.CompletedProcess:
    shell = isinstance(cmd, str)
    if not quiet:
        shown = cmd if shell else " ".join(str(c) for c in cmd)
        print(_c("90", f"  $ {shown}"), flush=True)
    e = dict(os.environ)
    if env:
        e.update(env)
    try:
        p = subprocess.run(
            cmd,
            cwd=str(cwd) if cwd else None,
            env=e,
            shell=shell,
            text=True,
            input=input_text,
            stdout=subprocess.PIPE if quiet else None,
            stderr=subprocess.STDOUT if quiet else None,
            timeout=timeout,
        )
    except FileNotFoundError as ex:
        if check:
            die(f"command not found: {ex.filename}")
        return subprocess.CompletedProcess(cmd, 127, "", str(ex))
    except subprocess.TimeoutExpired:
        if check:
            die(f"timed out: {cmd}")
        return subprocess.CompletedProcess(cmd, 124, "", "timeout")
    if check and p.returncode != 0:
        if quiet and p.stdout:
            print(p.stdout)
        die(f"command failed ({p.returncode})")
    return p


def capture(cmd: list[str] | str, **kw) -> str:
    kw.setdefault("check", False)
    p = run(cmd, quiet=True, **kw)
    return (p.stdout or "").strip()


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def human(n: int | float) -> str:
    for unit in ("B", "KiB", "MiB", "GiB"):
        if abs(n) < 1024:
            return f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} TiB"


def download(url: str, dest: Path, *, quiet: bool = False) -> Path:
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".part")
    if dest.exists() and dest.stat().st_size > 0:
        return dest
    req = urllib.request.Request(url, headers={"User-Agent": "duolinux/0.1"})
    with urllib.request.urlopen(req) as r, tmp.open("wb") as f:
        total = int(r.headers.get("Content-Length") or 0)
        done = 0
        while True:
            chunk = r.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)
            done += len(chunk)
            if not quiet and total:
                pct = done * 100 // total
                print(f"\r  {dest.name}: {pct:3d}%  {human(done)} / {human(total)}", end="")
    if not quiet:
        print()
    tmp.replace(dest)
    return dest


def extract_tar(archive: Path, dest: Path, *, strip: int = 0) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    with tarfile.open(archive) as t:
        members = t.getmembers()
        for m in members:
            parts = Path(m.name).parts
            if strip and len(parts) <= strip:
                continue
            m.name = str(Path(*parts[strip:])) if strip else m.name
            if m.name:
                t.extract(m, dest)


def confirm(prompt: str, *, default: bool = False) -> bool:
    suffix = " [Y/n] " if default else " [y/N] "
    try:
        ans = input(prompt + suffix).strip().lower()
    except EOFError:
        return False
    if not ans:
        return default
    return ans in ("y", "yes")


def require(commands: list[str]) -> None:
    missing = [c for c in commands if not which(c)]
    if missing:
        die("missing required tools: " + ", ".join(missing) + "\n  run: duo setup")


def retry(fn, attempts: int = 3, delay: float = 2.0):
    last = None
    for i in range(attempts):
        try:
            return fn()
        except Exception as ex:  # noqa: BLE001
            last = ex
            if i + 1 < attempts:
                time.sleep(delay * (i + 1))
    raise last  # type: ignore[misc]
