#!/bin/bash
for i in `ls templates_raw/`; do
	echo "==>" htmlcompressor templates_raw/$i -o templates/$i --compress-css --compress-js
	htmlcompressor templates_raw/$i -o templates/$i --compress-css --compress-js
done
