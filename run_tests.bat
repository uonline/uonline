@echo off
cls
php vendor\phpunit\phpunit\composer\bin\phpunit --strict --verbose --coverage-html code-coverage-report tests_php
npm test
