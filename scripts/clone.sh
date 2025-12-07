#!/bin/bash
echo "Clone\update from sources"
rm -rf "$BASE_DIR/$FEED_DIR"
mkdir -p "$BASE_DIR/$FEED_DIR"

# Clone or check repos
for repo in "${repos[@]}"; do
    set -- $repo
    clone_repo "$1" "$GIT_DIR/$2" "$3" "$4"
done