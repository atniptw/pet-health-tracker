#!/usr/bin/env bash
# Lists the ids in each spec that no line of a Dart test names and no
# untested.md line explains, then a count. Ids are NNN-US<n>-S<m> (the numbered
# acceptance scenarios under "### User Story <n>"), NNN-FR-NNN, NNN-EC-NN and
# NNN-SC-NNN, where NNN is the spec directory's number. The tests are the lines
# of the Dart files in test/ and integration_test/ under the current directory,
# except lines that start with //. untested.md, next to spec.md, holds lines
# "- <id>: <why>".
#
# Exits 1 when a test or a given spec's untested.md names an id that isn't in
# any spec (every spec.md in the directories holding the given specs), and with
# --strict also when any id is missing. Exits 2 on bad usage.
set -euo pipefail

usage() {
  echo 'usage: spec-coverage.sh [--strict] <spec dir>...' >&2
  exit 2
}

strict=0
dirs=()
for arg in "$@"; do
  case $arg in
    --strict) strict=1 ;;
    -*) usage ;;
    *) dirs+=("$arg") ;;
  esac
done
[ ${#dirs[@]} -gt 0 ] || usage

# Prints "<id><TAB><sentence>" for each id in spec.md $2, numbered $1.
spec_ids() {
  awk -v num="$1" '
    function emit(id, text) { gsub(/\*\*/, "", text); print num "-" id "\t" text }
    /^### User Story [0-9]+/ { split($0, words, " "); story = words[4]; next }
    /^#/ { story = "" }
    story != "" && /^[0-9]+\. / {
      n = substr($0, 1, index($0, ".") - 1)
      emit("US" story "-S" n, substr($0, index($0, ". ") + 2))
    }
    /^- \*\*(FR|EC|SC)-[0-9]+\*\*: / {
      rest = substr($0, 5)
      emit(substr(rest, 1, index(rest, "**") - 1), substr(rest, index(rest, ": ") + 2))
    }
  ' "$2"
}

# Prints "<id><TAB><file>:<line>" for each id in the input lines, which are
# "<file>:<line>:<text>".
named_ids() {
  awk '
    {
      split($0, parts, ":"); where = parts[1] ":" parts[2]
      text = substr($0, length(where) + 2)
      pattern = "(^|[^A-Za-z0-9])[0-9][0-9][0-9]-(US[0-9]+-S[0-9]+|(FR|EC|SC)-[0-9]+)"
      while (match(text, pattern)) {
        id = substr(text, RSTART, RLENGTH); sub(/^[^0-9]/, "", id)
        print id "\t" where
        text = substr(text, RSTART + RLENGTH)
      }
    }
  '
}

# Prints the Dart test lines that mention a spec id, except lines that start
# with //, as "<file>:<line>:<text>".
test_lines() {
  local roots=()
  for root in test integration_test; do [ -d "$root" ] && roots+=("$root"); done
  [ ${#roots[@]} -gt 0 ] || return 0
  grep -rnE --include='*.dart' '[0-9]{3}-(US|FR|EC|SC)' "${roots[@]}" |
    grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' || true
}

# Prints untested.md $1's "- <id>: <why>" lines as "<file>:<line>:<id>".
untested_lines() {
  [ -f "$1" ] || return 0
  awk -v file="$1" '/^- [^ :]+: [^ ]/ { print file ":" NR ":" substr($2, 1, length($2) - 1) }' "$1"
}

# Prints the lines of file $2 whose first field isn't a first field in file $1.
not_in() { awk -F '\t' 'FILENAME == ARGV[1] { seen[$1] = 1; next } !($1 in seen)' "$1" "$2"; }

# Prints the spec number $1 starts with, or exits 2.
spec_number() {
  basename "$1" | grep -oE '^[0-9]{3}' || {
    echo "spec-coverage.sh: $1 doesn't start with a spec number" >&2
    exit 2
  }
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
test_lines | named_ids >"$work/tests"

for i in "${!dirs[@]}"; do
  dirs[i]=${dirs[i]%/}
  spec_number "${dirs[i]}" >/dev/null
  [ -f "${dirs[i]}/spec.md" ] || {
    echo "spec-coverage.sh: no ${dirs[i]}/spec.md" >&2
    exit 2
  }
done

# Every id of every spec next to a given one, for finding unknown ids.
for dir in "${dirs[@]}"; do dirname "$dir"; done | sort -u >"$work/parents"
: >"$work/known"
while read -r parent; do
  for spec in "$parent"/[0-9][0-9][0-9]*/spec.md; do
    [ -f "$spec" ] || continue
    spec_ids "$(spec_number "$(dirname "$spec")")" "$spec" >>"$work/known"
  done
done <"$work/parents"

cp "$work/tests" "$work/named_anywhere"
for dir in "${dirs[@]}"; do untested_lines "$dir/untested.md" | named_ids >>"$work/named_anywhere"; done
not_in "$work/known" "$work/named_anywhere" >"$work/unknown"
awk -F '\t' '{ print "unknown id " $1 " in " $2 }' "$work/unknown"
status=0
[ -s "$work/unknown" ] && status=1

for dir in "${dirs[@]}"; do
  spec_ids "$(spec_number "$dir")" "$dir/spec.md" >"$work/spec"
  { cat "$work/tests"; untested_lines "$dir/untested.md" | named_ids; } >"$work/named"
  not_in "$work/named" "$work/spec" >"$work/missing"
  awk -F '\t' '{ print "missing " $1 ": " $2 }' "$work/missing"
  total=$(wc -l <"$work/spec" | tr -d ' ')
  missing=$(wc -l <"$work/missing" | tr -d ' ')
  echo "$(basename "$dir"): $((total - missing)) of $total ids covered, $missing missing"
  [ "$strict" = 0 ] || [ "$missing" = 0 ] || status=1
done
exit "$status"
