all:
	# No. Specify a target.


compress:
	./compress-templates.sh

pull:
	git pull origin master

recache:
	# we cannot delete templates_cache, so we just move it to /tmp
	mkdir -p /tmp/killme
	mv templates_cache /tmp/killme/`mcookie`

dirs:
	mkdir -p templates_cache
	chmod 777 -R templates_cache
	mkdir -p templates

deploy: pull compress recache dirs
