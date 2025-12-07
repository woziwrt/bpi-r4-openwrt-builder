#!/bin/bash
clone_repo() {
    local repo_url="$1"
    local dest_dir="$2"
    local branch="$3"
    local clean_branch=$(echo "$branch" | sed 's/^['"'"'"]*//; s/['"'"'"]*$//')
    local ref="$4"

    if [[ -z "$repo_url" || -z "$dest_dir" ]]; then
        echo "Usage: clone_repo <repo_url> <dest_dir> [branch] [ref]"
        return 1
    fi

    if [[ -d "$dest_dir/.git" ]]; then
        echo "Folder '$dest_dir' already exists. Updating repo..."
        cd "$dest_dir" || return 1
        git fetch --all
        if [[ -n "$clean_branch" ]]; then
            git reset --hard "origin/$clean_branch"
        else
            git reset --hard
            git pull
        fi
    else
        echo "Cloning repo '$repo_url' to '$dest_dir'..."
        if [[ -n "$clean_branch" ]]; then
            git clone --branch "$clean_branch" "$repo_url" "$dest_dir" || return 1
        else
            git clone "$repo_url" "$dest_dir" || return 1
        fi
        cd "$dest_dir" || return 1
    fi

    if [[ -n "$ref" ]]; then
        echo "Switching to '$ref'..."
        git checkout "$ref" || return 1
    fi

    cd - >/dev/null || return 1
    chmod -R 755 "$dest_dir"
}

copy_dir() {
    local src="$1"
    local dst="$2"

    echo "Copying '$src/' to '$dst'..."
    rsync -av --progress --delete --exclude='.git' "$src/" "$dst"
}