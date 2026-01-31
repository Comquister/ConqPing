@echo off
if not exist bin mkdir bin
javac --release 8 -d bin src/ConqPing.java
if %errorlevel% neq 0 (
    echo Compilation failed!
    exit /b %errorlevel%
)
echo Compilation successful. Creating JAR...
jar cfe ConqPing.jar ConqPing -C bin .
echo Running ConqPing from JAR...
echo.
java -jar ConqPing.jar %*
