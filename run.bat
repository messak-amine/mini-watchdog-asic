@echo off
setlocal
pushd "%~dp0" || exit /b 1
if not exist build mkdir build
iverilog -g2012 -Wall -s tb_watchdog -o build\tb_watchdog.vvp rtl\watchdog_scan.v tb\tb_watchdog.sv && vvp build\tb_watchdog.vvp
set "result=%errorlevel%"
popd
exit /b %result%
