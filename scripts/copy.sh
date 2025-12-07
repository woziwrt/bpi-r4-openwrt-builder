#!/bin/bash

# Copy packages
echo "Copy packages"
for rule in "${copy_rules[@]}"; do
    set -- $rule
    copy_dir "$BASE_DIR/$GIT_DIR/$1" "$BASE_DIR/$FEED_DIR/$2"
done

rm -rf "$BASE_DIR/$WORK_DIR"
rm -rf "$BASE_DIR/$MTK_WORK_DIR"
\cp -r "$BASE_DIR/$GIT_DIR/$WORK_DIR" "$BASE_DIR/$WORK_DIR"
\cp -r "$BASE_DIR/$GIT_DIR/$MTK_WORK_DIR" "$BASE_DIR/$MTK_WORK_DIR"

# Prevents to redownload packages
if [ -d "$BASE_DIR/$WORK_DIR/dl" ]; then
    rm -rf $BASE_DIR/$WORK_DIR/dl
	echo "rm -rf $BASE_DIR/$WORK_DIR/dl"
fi

ln -s $BASE_DIR/$SOURCES_DIR/downloads $BASE_DIR/$WORK_DIR/dl
echo "ln -s $BASE_DIR/$SOURCES_DIR/downloads $BASE_DIR/$WORK_DIR/dl"