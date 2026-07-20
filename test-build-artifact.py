#!/usr/bin/env python3
"""exec" "python3" "$0" "$@" #"""  # sh/zsh guard so `./test-build-artifact.py` uses python3

# =============================================================================
# test-build-artifact.py  -  maintainer helper (NOT part of the package build)
# =============================================================================
#
# PURPOSE
#   Download the conda package that the feedstock's CI pipeline built for THIS
#   machine's platform and install it into a fresh test environment - in a
#   single command - so a maintainer can smoke-test exactly what the pipeline
#   produced BEFORE publishing it to conda-forge (i.e. before merging the PR).
#
#   It fetches the real CI build output; it does not rebuild anything locally.
#
# USAGE  (run from anywhere inside a checkout of this feedstock)
#   python test-build-artifact.py               # latest successful CI build -> install
#   python test-build-artifact.py --no-install  # just download + unpack the .conda
#   python test-build-artifact.py --keep        # keep the temp download dir
#   python test-build-artifact.py --env my-test # env name (default: sirius-rc)
#   python test-build-artifact.py --build-id N  # Azure: pin a specific build (osx/win)
#   python test-build-artifact.py --run-id N    # GitHub Actions: pin a specific run (linux)
#
# HOW IT FINDS THE ARTIFACT  (nothing hard-coded per release - all derived)
#   * package name + version   <- recipe/meta.yaml
#   * platform subdir/config   <- this machine (linux-64 / osx-64 / osx-arm64 / win-64)
#   * the built .conda         <- the newest SUCCESSFUL CI run's stored build artifact:
#         - linux   -> GitHub Actions  (needs the `gh` CLI, authenticated)
#         - osx/win -> conda-forge Azure  (public REST API, no auth needed)
#
# REQUIREMENTS / NOTES
#   * `store_build_artifacts` must be enabled in conda-forge.yml (it is); the
#     artifact only exists on CI builds that ran AFTER that was turned on.
#   * This file lives at the repo root (kept out of recipe/ on purpose so it is
#     NOT bundled into the built package). Because conda-smithy's .gitignore
#     treats the root as smithy-managed, it is force-added (`git add -f`); this
#     is harmless - conda-smithy rerender does not touch it. It is not part of
#     the recipe and has no effect on the built package.
# =============================================================================

import argparse
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

AZURE_ORG = "conda-forge"
AZURE_PROJECT = "feedstock-builds"
GHA_WORKFLOW = "conda-build.yml"
HERE = Path(__file__).resolve().parent


def fail(msg):
    print(f"\nERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def info(msg):
    print(f"==> {msg}")


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, **kw)


# --- inputs derived from the repo -------------------------------------------------

def meta_yaml_path():
    """Locate recipe/meta.yaml whether this script sits in recipe/ or at the repo root."""
    candidates = [HERE / "meta.yaml", HERE / "recipe" / "meta.yaml"]
    try:
        root = Path(run(["git", "-C", str(HERE), "rev-parse", "--show-toplevel"],
                        capture_output=True, text=True).stdout.strip())
        candidates.insert(0, root / "recipe" / "meta.yaml")
    except Exception:
        pass
    for c in candidates:
        if c.is_file():
            return c
    fail("could not locate recipe/meta.yaml")


def read_recipe():
    """Return (package_name, version) parsed from recipe/meta.yaml."""
    text = meta_yaml_path().read_text(encoding="utf-8")
    m = re.search(r'{%\s*set\s+version\s*=\s*"([^"]+)"', text)
    if not m:
        fail("could not find the version in recipe/meta.yaml")
    version = m.group(1)
    # package.name: the first `name:` after the `package:` key.
    pkg = re.search(r"(?ms)^package:\s*\n(.*?)(?=^\S)", text)
    name = None
    if pkg:
        nm = re.search(r"^\s+name:\s*([^\s#]+)", pkg.group(1), re.M)
        if nm:
            name = nm.group(1).strip().strip('"').strip("'")
    if not name:
        fail("could not find package.name in recipe/meta.yaml")
    return name, version


def detect_platform():
    """Return (subdir, provider, config) for this machine."""
    sysname = platform.system()
    mach = platform.machine().lower()
    is_arm = mach in ("arm64", "aarch64")
    if sysname == "Linux":
        if is_arm:
            return "linux-aarch64", "gha", "linux_aarch64_"
        return "linux-64", "gha", "linux_64_"
    if sysname == "Darwin":
        if is_arm:
            return "osx-arm64", "azure", "osx_arm64_"
        return "osx-64", "azure", "osx_64_"
    if sysname == "Windows":
        return "win-64", "azure", "win_64_"
    fail(f"unsupported platform: {sysname}/{mach}")


def feedstock_repo():
    """owner/repo of the feedstock, from the git remotes (prefers conda-forge)."""
    try:
        out = run(["git", "-C", str(HERE), "remote", "-v"],
                  capture_output=True, text=True).stdout
    except Exception:
        out = ""
    repos = re.findall(r"github\.com[:/]([^/\s]+/[^/\s.]+)", out)
    for r in repos:
        if r.startswith("conda-forge/"):
            return r
    return repos[0] if repos else "conda-forge/sirius-ms-feedstock"


# --- GitHub Actions (linux) -------------------------------------------------------

def gh_available():
    return shutil.which("gh") is not None


def latest_gha_run(repo, branch):
    args = ["gh", "run", "list", "-R", repo, "--workflow", GHA_WORKFLOW,
            "--status", "success", "-L", "1", "--json", "databaseId,headBranch,createdAt"]
    if branch:
        args += ["--branch", branch]
    out = run(args, capture_output=True, text=True).stdout
    runs = json.loads(out)
    if not runs:
        fail("no successful GitHub Actions run found"
             + (f" for branch {branch}" if branch else "")
             + ". Push the build first, or pass --run-id.")
    return runs[0]["databaseId"]


def download_gha(repo, run_id, dest, config):
    info(f"downloading GitHub Actions artifacts from run {run_id} ...")
    # Only THIS platform's package artifact: conda_pkgs_*<config> (success) or
    # conda_artifacts_*<config> (failure). Excludes conda_envs_* and other arches
    # (e.g. *linux_64_ does not match *linux_aarch64_).
    try:
        run(["gh", "run", "download", str(run_id), "-R", repo,
             "--pattern", f"conda_pkgs_*{config}", "--pattern", f"conda_artifacts_*{config}",
             "-D", str(dest)])
    except subprocess.CalledProcessError:
        # fall back to downloading everything if the pattern matched nothing
        run(["gh", "run", "download", str(run_id), "-R", repo, "-D", str(dest)])


# --- Azure (osx / win) ------------------------------------------------------------

def azure_get(path, params):
    q = "&".join(f"{k}={v}" for k, v in params.items())
    url = f"https://dev.azure.com/{AZURE_ORG}/{AZURE_PROJECT}/_apis/{path}?{q}"
    with urllib.request.urlopen(url, timeout=60) as r:
        return json.loads(r.read().decode())


def azure_definition_id(feedstock_name):
    data = azure_get("build/definitions", {"name": feedstock_name, "api-version": "6.0"})
    if data.get("count"):
        return data["value"][0]["id"]
    fail(f"could not find an Azure build definition named {feedstock_name}")


def latest_azure_build(def_id, branch):
    params = {"definitions": def_id, "statusFilter": "completed",
              "resultFilter": "succeeded,partiallySucceeded", "$top": "1", "api-version": "6.0"}
    if branch:
        params["branchName"] = f"refs/heads/{branch}"
    data = azure_get(f"build/builds", params)
    if not data.get("count"):
        fail("no successful Azure build found"
             + (f" for branch {branch}" if branch else "")
             + ". Push the build first, or pass --build-id.")
    return data["value"][0]["id"]


def download_azure(build_id, config, dest):
    info(f"looking up Azure artifacts for build {build_id} ...")
    data = azure_get(f"build/builds/{build_id}/artifacts", {"api-version": "6.0"})
    arts = data.get("value", [])
    # Built packages are stored as conda_pkgs_* (GitHub Actions on success) or conda_artifacts_*
    # (Azure, and any failed build); conda_envs_* holds only debug environments (no .conda), so
    # exclude it. Prefer the artifact matching our platform config.
    cand = [a for a in arts if a["name"].startswith(("conda_pkgs", "conda_artifacts"))]
    match = [a for a in cand if config.rstrip("_") in a["name"]] or cand
    if not match:
        fail(f"build {build_id} has no package artifact "
             f"(available: {[a['name'] for a in arts]}). Is store_build_artifacts enabled?")
    art = match[0]
    url = art["resource"]["downloadUrl"]
    zpath = dest / f"{art['name']}.zip"
    info(f"downloading Azure artifact {art['name']} ...")
    download_url(url, zpath)


def download_url(url, dest):
    with urllib.request.urlopen(url, timeout=300) as r, open(dest, "wb") as f:
        shutil.copyfileobj(r, f)


# --- unpack + install -------------------------------------------------------------

def extract_all_zips(root):
    """Recursively extract every .zip under root (artifacts are zip, sometimes zip-in-zip)."""
    seen = set()
    changed = True
    while changed:
        changed = False
        for z in list(root.rglob("*.zip")):
            if z in seen:
                continue
            seen.add(z)
            try:
                with zipfile.ZipFile(z) as zf:
                    zf.extractall(z.parent)
                changed = True
            except zipfile.BadZipFile:
                pass


def find_conda(root, name, version, subdir):
    pat = re.compile(rf"^{re.escape(name)}-{re.escape(version)}-.*\.conda$")
    # prefer a hit under the matching platform subdir
    hits = [p for p in root.rglob("*.conda") if pat.match(p.name)]
    if not hits:
        fail(f"no {name}-{version}-*.conda found in the downloaded artifact")
    pref = [p for p in hits if p.parent.name == subdir]
    return (pref or hits)[0]


def detect_pm(explicit):
    if explicit:
        return explicit
    for pm in ("micromamba", "mamba", "conda"):
        if shutil.which(pm):
            return pm
    fail("no conda package manager found (looked for micromamba/mamba/conda); pass --pm")


def install(pm, env, conda_file, name, version, force):
    # The extracted artifact is a full local conda channel (<build_artifacts>/<subdir>/*.conda
    # plus repodata.json), so install FROM that channel and pull dependencies (openjdk, cbc, ...)
    # from conda-forge. Passing the bare .conda file path to `create` does NOT solve reliably.
    channel = conda_file.parent.parent
    info(f"installing {name}={version} into env '{env}' with {pm} "
         f"(local channel: .../{channel.name}/{conda_file.parent.name}) ...")
    if force:
        # remove a pre-existing env first so re-runs are clean
        subprocess.run([pm, "env", "remove", "-y", "-n", env],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    run([pm, "create", "-y", "-n", env,
         "-c", channel.as_uri(), "-c", "conda-forge", f"{name}={version}"])
    print()
    info(f"done. Activate and test with:\n"
         f"    {pm} activate {env}\n"
         f"    sirius --version && sirius selftest")


# --- main -------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description="Download + install this feedstock's CI-built "
                                             "package for the current OS, in one command.")
    ap.add_argument("--branch", default=None,
                    help="filter CI to this branch (default: newest successful run, any branch)")
    ap.add_argument("--build-id", type=int, help="Azure build id to use (osx/win)")
    ap.add_argument("--run-id", type=int, help="GitHub Actions run id to use (linux)")
    ap.add_argument("--env", default="sirius-rc", help="target env name (default: sirius-rc)")
    ap.add_argument("--pm", choices=["micromamba", "mamba", "conda"],
                    help="package manager (default: autodetect)")
    ap.add_argument("--download-dir", help="where to download (default: a temp dir)")
    ap.add_argument("--no-install", action="store_true", help="download + unpack only")
    ap.add_argument("--keep", action="store_true", help="keep the download dir")
    ap.add_argument("--force", action="store_true", help="replace the target env if it exists")
    ns = ap.parse_args()

    name, version = read_recipe()
    subdir, provider, config = detect_platform()
    repo = feedstock_repo()
    feedstock = repo.split("/")[-1]
    info(f"{name} {version}  |  platform {subdir}  |  {provider}  |  feedstock {repo}")

    dest = Path(ns.download_dir).resolve() if ns.download_dir else \
        Path(tempfile.mkdtemp(prefix="sirius-artifact-"))
    dest.mkdir(parents=True, exist_ok=True)

    try:
        if provider == "gha":
            if not gh_available():
                fail("the GitHub CLI `gh` is required to fetch the linux artifact "
                     "(osx/win use the anonymous Azure API). Install gh and `gh auth login`.")
            run_id = ns.run_id or latest_gha_run(repo, ns.branch)
            download_gha(repo, run_id, dest, config)
        else:
            build_id = ns.build_id or latest_azure_build(azure_definition_id(feedstock), ns.branch)
            download_azure(build_id, config, dest)

        extract_all_zips(dest)
        conda_file = find_conda(dest, name, version, subdir)
        info(f"found package: {conda_file}")

        if ns.no_install:
            print(f"\n{conda_file}")
            return
        install(detect_pm(ns.pm), ns.env, conda_file, name, version, ns.force)
    finally:
        if not ns.keep and not ns.download_dir:
            shutil.rmtree(dest, ignore_errors=True)


if __name__ == "__main__":
    main()
