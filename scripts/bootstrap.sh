#!/usr/bin/env bash
set -euo pipefail

missing=()
for tool in git curl tar gzip unzip node npm python3 rg; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
if ! command -v fd >/dev/null 2>&1 && ! command -v fdfind >/dev/null 2>&1; then missing+=(fd); fi
if ! command -v gcc >/dev/null 2>&1 && ! command -v clang >/dev/null 2>&1; then missing+=(gcc); fi
if ! command -v g++ >/dev/null 2>&1 && ! command -v clang++ >/dev/null 2>&1; then missing+=(g++); fi
if command -v python3 >/dev/null 2>&1 && ! python3 -c 'import venv, ensurepip' >/dev/null 2>&1; then
    missing+=(python3-venv)
fi
if ((${#missing[@]} == 0)); then echo 'All system dependencies are available.'; exit 0; fi
printf 'Missing dependencies: %s\n' "${missing[*]}"
if [[ "${1:-}" == '--check' ]]; then exit 0; fi

elevate=()
if ((EUID != 0)); then
    command -v sudo >/dev/null 2>&1 || { echo 'sudo is required to install system packages.' >&2; exit 1; }
    elevate=(sudo)
fi
if command -v apt-get >/dev/null 2>&1; then
    "${elevate[@]}" apt-get update
    "${elevate[@]}" apt-get install -y git curl tar gzip unzip build-essential ripgrep fd-find nodejs npm python3 python3-venv python3-pip
elif command -v dnf >/dev/null 2>&1; then
    "${elevate[@]}" dnf install -y git curl tar gzip unzip gcc gcc-c++ ripgrep fd-find nodejs npm python3 python3-pip
elif command -v pacman >/dev/null 2>&1; then
    "${elevate[@]}" pacman -S --needed --noconfirm git curl tar gzip unzip base-devel ripgrep fd nodejs npm python python-pip
else
    echo 'Supported Linux package managers: apt-get, dnf, pacman. Install the missing dependencies listed above manually.' >&2
    exit 1
fi
echo 'System dependencies installed. Restart Neovim to install language tools and parsers.'
