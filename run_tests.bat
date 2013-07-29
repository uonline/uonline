@echo off
cls
php vendor\phpunit\phpunit\composer\bin\phpunit --strict --verbose --colors --coverage-html code-coverage-report tests
