all:
	# No. Specify a target.


compress:
	./compress-templates.sh

pull:
	git pull origin master

recache:
	mkdir -p templates_cache
	sudo rm -rf templates_cache/*

deploy: pull compress recache
