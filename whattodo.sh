#!/bin/sh
( find -name '*.js'; find -name '*.coffee' ) | grep -v node_modules | grep -v server.js | xargs grep TODO -n
