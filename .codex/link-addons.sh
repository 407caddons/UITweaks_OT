#!/usr/bin/env bash
# Usage: bash .codex/link-addons.sh "/other/install/Interface/AddOns"
# Example (WoW Forever):
#   bash .codex/link-addons.sh ".../World of Warcraft/_forever_/Interface/AddOns"
set -euo pipefail

if [[ $# -ne 1 || "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: bash .codex/link-addons.sh /path/to/other/Interface/AddOns"
    echo "Close WoW first. Existing files and conflicting links are never overwritten."
    [[ $# -eq 1 && ( "$1" == "--help" || "$1" == "-h" ) ]] && exit 0
    exit 1
fi

SOURCE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
if [[ ! -d "$1" ]]; then
    echo "Error: destination directory does not exist: $1" >&2
    exit 1
fi
DEST=$(cd -- "$1" && pwd -P)
name=LunaUITweaks_ObjectiveTracker
target="$DEST/$name"

# The client needs the Retail TOC or the Forever (_Camelot) TOC; require both so
# one link serves either installation.
for toc in "$name.toc" "${name}_Camelot.toc"; do
    if [[ ! -f "$SOURCE/$toc" ]]; then
        echo "Error: source addon is missing: $SOURCE/$toc" >&2
        exit 1
    fi
done

if [[ "$target" -ef "$SOURCE" && ! -L "$target" ]]; then
    echo "Error: destination is the source folder itself: $target" >&2
    exit 1
fi
if [[ -e "$target" || -L "$target" ]]; then
    if [[ -L "$target" && "$target" -ef "$SOURCE" ]]; then
        echo "Already linked: $target"
        exit 0
    fi
    echo "Error: destination already exists: $target" >&2
    echo "Move it somewhere safe first; nothing has been changed." >&2
    exit 1
fi

ln -sT -- "$SOURCE" "$target"
echo "Created: $target -> $SOURCE"
echo "Done. Both installations now use the same addon source; WTF settings remain separate."
echo "Avoid addon-manager updates to this link: they may overwrite your shared source."
echo "Optional: the main LunaUITweaks addon should be linked too (see its .codex/link-addons.sh)."
