#!/bin/bash
for i in `ls | grep -v compress.sh`; do
	echo "==>" htmlcompressor $i -o ../templates/$i --compress-css
	htmlcompressor $i -o ../templates/$i --compress-css
done
