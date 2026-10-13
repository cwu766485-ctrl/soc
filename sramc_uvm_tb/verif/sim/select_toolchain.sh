#!/usr/bin/env bash
# Source this file from the VNC/Linux terminal; executing it cannot change the
# parent shell environment. Example: source ./select_toolchain.sh 2023
# implementation method: 
# Using fixed VCS/URG/Verdi 2023
# source ./select_toolchain.sh 2023
# Recover outdated tools
# Use tools from the current WSL shell setup
# source ./select_toolchain.sh local
# Recover outdated course-server tools
# source ./select_toolchain.sh legacy

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Please source this script: source ./select_toolchain.sh {2023|local|legacy}" >&2
  exit 2
fi

if [[ -z "${SRAMC_ORIGINAL_PATH+x}" ]]; then
  export SRAMC_ORIGINAL_PATH="$PATH"
  export SRAMC_ORIGINAL_VCS_HOME="${VCS_HOME-}"
  export SRAMC_ORIGINAL_VERDI_HOME="${VERDI_HOME-}"
  export SRAMC_ORIGINAL_NOVAS_HOME="${NOVAS_HOME-}"
fi

restore_login_environment() {
  export PATH="$SRAMC_ORIGINAL_PATH"
  unset VCS_HOME VERDI_HOME NOVAS_HOME
  [[ -n "$SRAMC_ORIGINAL_VCS_HOME" ]] && export VCS_HOME="$SRAMC_ORIGINAL_VCS_HOME"
  [[ -n "$SRAMC_ORIGINAL_VERDI_HOME" ]] && export VERDI_HOME="$SRAMC_ORIGINAL_VERDI_HOME"
  [[ -n "$SRAMC_ORIGINAL_NOVAS_HOME" ]] && export NOVAS_HOME="$SRAMC_ORIGINAL_NOVAS_HOME"
}

case "${1:-}" in
  2023)
    export TOOLCHAIN=2023
    export VCS_HOME=/eda/synopsys_2021/vcs/V-2023.12-SP2
    export VERDI_HOME=/eda/synopsys_2021/verdi/V-2023.12-SP2
    unset NOVAS_HOME
    export PATH="$VCS_HOME/bin:$VERDI_HOME/bin:$PATH"
    ;;
  local|legacy)
    export TOOLCHAIN="$1"
    restore_login_environment
    ;;
  *)
    echo "Usage: source ./select_toolchain.sh {2023|local|legacy}" >&2
    return 2
    ;;
esac

echo "Selected TOOLCHAIN=$TOOLCHAIN"
echo "vcs   : $(command -v vcs)"
echo "verdi : $(command -v verdi)"
echo "Use 'vcs -ID', 'urg -version', and 'verdi -version' to verify the active tool versions."
