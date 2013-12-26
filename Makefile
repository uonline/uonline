all:
	# No. Specify a target.


diagnose:
	php composer.phar diagnose
	php composer.phar validate

phptest:
	php vendor/bin/phpunit --strict --verbose `if $$(which test) x$${TRAVIS} '==' x; then echo --colors; fi` --coverage-html ./code-coverage-report tests_php/

serve:
	php -S localhost:8080 -t .

monitor:
	./node_modules/nodemon/nodemon.js -e '.coffee|.js|.twig|.css' -x coffee main.coffee

grunt:
	./node_modules/grunt-cli/bin/grunt
