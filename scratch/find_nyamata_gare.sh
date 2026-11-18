#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-https://api.gocavgo.com}"
SEARCH_NAME="${SEARCH_NAME:-Nyamata Gare}"
LIMIT="${LIMIT:-100}"
HASH="${HASH:-}"

API_URL="${BASE_URL%/}/navig/locations/hash"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 2
fi

page=1
found=0
page_total=0

while :; do
  url="${API_URL}?page=${page}&limit=${LIMIT}"
  if [[ -n "${HASH}" ]]; then
    url+="&hash=${HASH}"
  fi

  echo "--- page ${page} ---" >&2
  response="$(curl -fsS -H 'Accept: application/json' "$url")"

  current_page="$(jq -r '.page // 1' <<<"$response")"
  current_limit="$(jq -r '.limit // 0' <<<"$response")"
  total="$(jq -r '.total // 0' <<<"$response")"
  hash_value="$(jq -r '.hash // ""' <<<"$response")"
  page_total=$(( current_limit > 0 ? (total + current_limit - 1) / current_limit : 1 ))

  echo "page=${current_page} limit=${current_limit} total=${total} hash=${hash_value}" >&2

  matches="$(jq -r --arg name "$SEARCH_NAME" '
    (.locations // [])
    | map(select((.custom_name // "") == $name))
    | .[]
    | "MATCH id=" + (.id|tostring) + " custom_name=" + (.custom_name // "") + " code=" + (.code // "") + " province=" + (.province // "") + " district=" + (.district // "")
  ' <<<"$response")"
  if [[ -n "$matches" ]]; then
    printf '%s\n' "$matches"
    found=1
  fi

  done_by_total=0
  if [[ "$current_limit" -le 0 ]]; then
    done_by_total=1
  elif [[ "$current_page" -ge "$page_total" ]]; then
    done_by_total=1
  fi

  if [[ "$done_by_total" -eq 1 ]]; then
    break
  fi

  page=$((page + 1))
done

if [[ "$found" -eq 1 ]]; then
  echo "FOUND: ${SEARCH_NAME}" >&2
  exit 0
fi

echo "NOT FOUND: ${SEARCH_NAME}" >&2
exit 1
