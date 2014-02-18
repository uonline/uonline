all:
	# No. Specify a target.


phptest:
	php vendor/bin/phpunit --strict --verbose `if $$(which test) x$${TRAVIS} '==' x; then echo --colors; fi` --coverage-html ./code-coverage-report tests_php/

serve:
	php -S localhost:8080 -t .

monitor:
	./node_modules/nodemon/bin/nodemon.js -e 'coffee,js,twig,css' -x coffee main.coffee

grunt:
	./node_modules/grunt-cli/bin/grunt

david:
	./node_modules/david/bin/david.js

david-update:
	./node_modules/david/bin/david.js update

whattodo:
	( find -name '*.js'; find -name '*.coffee' ) | grep -v node_modules | grep -v server.js | xargs grep TODO -n
