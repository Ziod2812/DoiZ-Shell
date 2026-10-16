#!/bin/sh

df -hPT -x tmpfs -x devtmpfs -x efivarfs -x squashfs -x overlay -x ramfs 2>/dev/null | tail -n +2
