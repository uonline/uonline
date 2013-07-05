#!/bin/bash
for i in `ls templates_raw/`; do
	echo -n "${i}... "
	htmlcompressor templates_raw/$i -o templates/$i --compress-css --compress-js
	if [ $? == 0 ]
	then
		echo OK
	else
		htmlcompressor templates_raw/$i -o templates/$i --compress-css
		if [ $? == 0 ]
		then
			echo OK, but failed to compress JS
		else
			echo FAIL
			exit
		fi
	fi
done
