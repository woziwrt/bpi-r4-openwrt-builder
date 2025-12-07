#!/bin/bash
echo "Add extra feed"
FEED_CONF="$BASE_DIR/$WORK_DIR/feeds.conf.default"
FEED_LINE="src-link my_feed $BASE_DIR/$FEED_DIR"
echo "$FEED_LINE"

# Check line if it exists
if ! grep -Fxq "$FEED_LINE" "$FEED_CONF"; then
    echo "$FEED_LINE" >> "$FEED_CONF"
fi
