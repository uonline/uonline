all:
	# No. Specify a target.


pull:
	git pull origin master

killcache:
	# we cannot delete templates_cache, so we just move it to /tmp
	mkdir -p /tmp/killme
	mv templates_cache /tmp/killme/`mcookie`

dirs:
	mkdir -p templates_cache
	chmod 777 -R templates_cache
	mkdir -p templates

diagnose:
	php composer.phar diagnose
	php composer.phar validate

lintverbose:
	find -name "*.js" | grep -v ./node_modules/ | grep -v ./bootstrap/ | grep -v ./code-coverage-report/ | grep -v ./vendor/ | grep -v ./browserified/ | xargs ./node_modules/jshint/bin/jshint --show-non-errors

coffeelint:
	find -name '*.coffee' | grep -v ./node_modules/ | xargs ./node_modules/coffeelint/bin/coffeelint -f .coffeelintrc

test:
	npm test
	php vendor/bin/phpunit --strict --verbose `if $$(which test) x$${TRAVIS} '==' x; then echo --colors; fi` --coverage-html ./code-coverage-report tests_php/

deploy: pull killcache dirs diagnose test

serve:
	php -S localhost:8080 -t .

nodemon:
	./node_modules/nodemon/nodemon.js -e '.js|.twig|.css' main.coffee

grunt:
	./node_modules/grunt-cli/bin/grunt
