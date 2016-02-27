all:
	# No. Specify a target.


monitor:
	./node_modules/nodemon/bin/nodemon.js ./main.coffee -V

codo:
	./node_modules/codo/bin/codo --output ./docs --name 'uonline' --title 'uonline documentation' ./lib
	./node_modules/codo/bin/codo --output ./docs --name 'uonline' --title 'uonline documentation' --undocumented ./lib

david:
	./node_modules/david/bin/david.js

david-update:
	./node_modules/david/bin/david.js update

whattodo:
	( find -name '*.js' -or -name '*.coffee' -or -name '*.jade' ) | grep -v node_modules | xargs grep TODO -n --color
