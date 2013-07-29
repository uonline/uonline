all:
	# No. Specify a target.


compress:
	./compress-templates.sh

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
	
test:
	php vendor/bin/phpunit --strict --verbose --colors --coverage-html ./code-coverage-report tests/

deploy: pull killcache dirs compress test
