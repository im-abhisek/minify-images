#!/usr/bin/env bash
# Double-click on a Mac to pick images, or drop this file into Terminal.
export COMPRESS_FOR_BLOG_MAC_PICKER=1
exec "$(cd "$(dirname "$0")" && pwd)/compress-for-blog" "$@"
