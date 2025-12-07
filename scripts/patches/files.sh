#!/bin/bash
echo "Apply base files"
rm -rf $BASE_DIR/$WORK_DIR/files
mkdir -p $BASE_DIR/$WORK_DIR/files
\cp -r $BASE_DIR/my_files/files/* $BASE_DIR/$WORK_DIR/files/
