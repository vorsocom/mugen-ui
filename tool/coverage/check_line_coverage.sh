#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  check_line_coverage.sh [--lcov <lcov_path>] [--minimum <percent>]

Checks aggregate line coverage from an LCOV report (default: coverage/lcov.info)
and fails when coverage is below the minimum threshold (default: 100).
USAGE
}

fail() {
  echo "Coverage check failed: $1" >&2
  exit 1
}

main() {
  local lcov_path="coverage/lcov.info"
  local minimum="100"

  while (($# > 0)); do
    case "$1" in
      --lcov)
        shift
        (($# > 0)) || { usage >&2; exit 2; }
        lcov_path="$1"
        ;;
      --minimum)
        shift
        (($# > 0)) || { usage >&2; exit 2; }
        minimum="$1"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage >&2
        exit 2
        ;;
    esac
    shift
  done

  [[ -f "${lcov_path}" ]] \
    || fail "lcov file not found at '${lcov_path}'. Run 'flutter test --coverage' first."

  [[ "${minimum}" =~ ^[0-9]+(\.[0-9]+)?$ ]] || {
    usage >&2
    exit 2
  }

  if ! awk -v min="${minimum}" 'BEGIN { exit (min >= 0 && min <= 100) ? 0 : 1 }'; then
    usage >&2
    exit 2
  fi

  local totals
  totals="$(
    awk -F: '
      /^LF:/ { lf += $2 }
      /^LH:/ { lh += $2 }
      END { printf "%d %d\n", lh, lf }
    ' "${lcov_path}"
  )"

  local lh lf
  read -r lh lf <<<"${totals}"

  ((lf > 0)) || fail "no lines found in '${lcov_path}'."

  local percent
  percent="$(awk -v lh="${lh}" -v lf="${lf}" 'BEGIN { printf "%.2f", (100 * lh) / lf }')"

  if ! awk -v lh="${lh}" -v lf="${lf}" -v min="${minimum}" \
    'BEGIN { pct = (100 * lh) / lf; exit (pct + 1e-12 >= min) ? 0 : 1 }'; then
    fail "line coverage ${percent}% (${lh}/${lf}) is below required ${minimum}%."
  fi

  echo "Coverage check passed: ${percent}% (${lh}/${lf}) meets required ${minimum}%."
}

main "$@"
