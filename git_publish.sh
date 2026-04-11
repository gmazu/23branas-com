#!/usr/bin/env bash

set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: run this script inside a git repository." >&2
  exit 1
fi

branch="$(git rev-parse --abbrev-ref HEAD)"
status="$(git status --short)"
status_branch="$(git status -sb)"
push_changes=true
auto_yes=false
message=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-push)
      push_changes=false
      shift
      ;;
    -y|--yes)
      auto_yes=true
      shift
      ;;
    *)
      if [[ -z "${message}" ]]; then
        message="$1"
      else
        message="${message} $1"
      fi
      shift
      ;;
  esac
done

has_uncommitted=false
has_unpushed=false

if [[ -n "${status}" ]]; then
  has_uncommitted=true
fi

if [[ "${status_branch}" == *"ahead "* ]]; then
  has_unpushed=true
fi

if [[ "${has_uncommitted}" == false && "${has_unpushed}" == false ]]; then
  echo "Nothing to commit or push."
  exit 0
fi

if [[ "${has_uncommitted}" == true && -z "${message}" ]]; then
  timestamp="$(date +"%Y-%m-%d %H:%M:%S")"
  message="update: ${timestamp}"
fi

echo "Repository: $(basename "$(git rev-parse --show-toplevel)")"
echo "Branch: ${branch}"
if [[ "${has_uncommitted}" == true ]]; then
  echo "Commit message: ${message}"
else
  echo "Commit message: <skipped; no local changes>"
fi
echo
echo "${status_branch}"
if [[ -n "${status}" ]]; then
  git status --short
fi
echo

if [[ "${auto_yes}" != true ]]; then
  printf "Continue? [y/N] "
  read -r confirm
  if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
fi

if [[ "${has_uncommitted}" == true ]]; then
  git add -A
  git commit -m "${message}"
  echo
fi

if [[ "${push_changes}" == true ]]; then
  push_log="$(mktemp)"
  if git push -u origin "${branch}" >"${push_log}" 2>&1; then
    cat "${push_log}"
    rm -f "${push_log}"
    echo
    echo "Published to origin/${branch}"
  else
    push_output="$(cat "${push_log}")"
    rm -f "${push_log}"
    echo "${push_output}" >&2
    echo >&2

    if [[ "${push_output}" == *"fetch first"* || "${push_output}" == *"non-fast-forward"* ]]; then
      git fetch origin "${branch}" >/dev/null 2>&1 || true
      echo "Push rechazado: la rama remota avanzo y tu copia local no la ha integrado todavia." >&2
      echo "Cambiar GitHub Pages o el dominio no crea commits de codigo por si solo." >&2
      echo "Si no tocaste codigo en GitHub, lo mas probable es que el remoto haya recibido un commit desde otra carpeta, otro repo local o una referencia desactualizada." >&2
      echo >&2
      echo "Opciones:" >&2
      echo "1. Integrar lo remoto y volver a publicar:" >&2
      echo "   git pull --rebase origin ${branch}" >&2
      echo "   ./git_publish.sh --yes \"${message:-update}\"" >&2
      echo >&2
      echo "2. Revisar primero que cambio en el remoto:" >&2
      echo "   git status -sb" >&2
      echo "   git log --oneline --left-right --graph HEAD...origin/${branch}" >&2
      echo >&2
      echo "3. Si no hay cambios locales nuevos y solo faltaba subir commits ya hechos:" >&2
      echo "   git push origin ${branch}" >&2
    else
      echo "Push fallido. Revisa el mensaje de git de arriba." >&2
    fi

    exit 1
  fi
else
  echo "Committed locally on ${branch}"
fi
