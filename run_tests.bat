@echo off
cls
php vendor\phpunit\phpunit\composer\bin\phpunit --strict --verbose --coverage-html code-coverage-report tests
node node_modules\nodeunit\bin\nodeunit tests_node\ --reporter verbose