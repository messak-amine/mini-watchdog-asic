@echo off
setlocal
pushd "%~dp0" || exit /b 1
set "mode=%~1"
if "%mode%"=="" set "mode=sim"
if not "%~2"=="" goto usage
if /i "%mode%"=="clean" goto clean
if /i "%mode%"=="sim" goto prepare
if /i "%mode%"=="synth" goto prepare
if /i "%mode%"=="gate" goto prepare
if /i "%mode%"=="all" goto prepare
:usage
echo Usage: run.bat [sim^|synth^|gate^|all^|clean] 1>&2
popd
exit /b 2

:prepare
if not exist build\ mkdir build || goto failed
if /i "%mode%"=="synth" goto synth
call :require iverilog.exe || goto failed
call :require vvp.exe || goto failed
if /i "%mode%"=="gate" goto synth
iverilog.exe -g2001 -Wall -s watchdog_scan -tnull rtl\watchdog_scan.v || goto failed
iverilog.exe -g2012 -Wall -s tb_watchdog -o build\tb_watchdog.vvp rtl\watchdog_scan.v tb\tb_watchdog.sv || goto failed
vvp.exe build\tb_watchdog.vvp || goto failed
if /i "%mode%"=="sim" goto done

:synth
call :require yosys.exe || goto failed
yosys.exe -l build/synthesis.log -s synth/synth.ys || goto failed
if /i "%mode%"=="synth" goto done
iverilog.exe -g2012 -s tb_watchdog -o build\tb_gate.vvp build\watchdog_scan_netlist.v tb\tb_watchdog.sv || goto failed
vvp.exe build\tb_gate.vvp +gate || goto failed
goto done

:require
where.exe /q %1 && exit /b 0
echo Missing %1 on PATH. 1>&2
exit /b 1

:clean
if exist build\ rmdir /s /q build
if exist build\ goto failed
:done
popd
exit /b 0
:failed
popd
exit /b 1
