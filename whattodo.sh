#!/bin/sh
find -name '*.js' | grep -v node_modules | xargs grep TODO
