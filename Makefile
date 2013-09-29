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

check: checkstrict checklicense lint

checkstrict:
	RESULT='Everything is OK.'; echo ""; for i in `find -name "*.js" | grep -v ./node_modules/ | grep -v ./bootstrap/ | grep -v ./code-coverage-report/ | grep -v ./vendor/`; do if `which test` 'y' "==" 'y'"`cat $$i | egrep "^['\\"]use strict['\\"];"`"; then echo 'Non-strict:' $$i; RESULT='There are some non-strict files.'; else echo 'Strict:' $$i; fi; done; echo $$RESULT; echo "";

checklicense:
	RESULT='Everything is OK.'; echo ""; for i in `find -name "*.js" | grep -v ./node_modules/ | grep -v ./bootstrap/ | grep -v ./code-coverage-report/ | grep -v ./vendor/`; do if `which test` 'y' "==" 'y'"`cat $$i | grep "WARRANTY"`"; then echo 'No license:' $$i; RESULT='There are some files without a license.'; else echo 'With license:' $$i; fi; done; echo $$RESULT; echo "";

lint:
	find -name "*.js" | grep -v ./node_modules/ | grep -v ./bootstrap/ | grep -v ./code-coverage-report/ | grep -v ./vendor/ | xargs ./node_modules/jshint/bin/jshint

lintverbose:
	find -name "*.js" | grep -v ./node_modules/ | grep -v ./bootstrap/ | grep -v ./code-coverage-report/ | grep -v ./vendor/ | xargs ./node_modules/jshint/bin/jshint --show-non-errors

test:
	npm test
	php vendor/bin/phpunit --strict --verbose `if $$(which test) x$${TRAVIS} '==' x; then echo --colors; fi` --coverage-html ./code-coverage-report tests_php/

deploy: pull killcache dirs diagnose test

serve:
	php -S localhost:8080 -t .
