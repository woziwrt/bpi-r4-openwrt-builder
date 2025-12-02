#!/bin/bash
echo "Apply qmi patches"
\cp -r $BASE_DIR/my_files/qmi.sh $BASE_DIR/$WORK_DIR/package/network/utils/uqmi/files/lib/netifd/proto/
chmod -R 755 $BASE_DIR/$WORK_DIR/package/network/utils/uqmi/files/lib/netifd/proto
