#!/bin/bash
for i in `ls templates_raw/`; do
	echo "==>" htmlcompressor templates_raw/$i -o templates/$i --compress-css
	htmlcompressor templates_raw/$i -o templates/$i --compress-css
done
