# Dump the casks of a Homebrew tap to stdout as a cask.json in brew-api's format,
# so the result can be passed to mkCasks as `source`. Requires brew on PATH.
if [ $# -ne 1 ]; then
  echo "usage: gen-tap <user/repo>" >&2
  exit 1
fi
tap="$1"

brew tap "$tap" >&2
mapfile -t tokens < <(brew tap-info --json "$tap" | jq -r '.[0].cask_tokens[]')

if [ ${#tokens[@]} -eq 0 ]; then
  printf '[\n]\n'
  exit 0
fi

# --variations keeps every os/arch url instead of resolving them for this host.
# The output mirrors brew-api: volatile fields dropped, one cask per line.
brew info --json=v2 --variations --cask "${tokens[@]}" | jq -r '
  .casks
  | sort_by(.token)
  | map(del(.tap_git_head, .tap, .installed_time, .installed, .ruby_source_path, .ruby_source_checksum))
  | "[\n" + (map("\t" + tojson) | join(",\n")) + "\n]"
'
