@echo off
FOR %%i IN (.\templates_raw\*) DO (
echo compressing %%~nxi ...
java -jar htmlcompressor.jar ".\templates_raw\%%~nxi" -o ".\templates\%%~nxi" --compress-css --compress-js
)