@echo off
setlocal EnableExtensions EnableDelayedExpansion
rem === basalt greedy compare: base checks, build-if-changed, llama-swap-coordinated harness ===
rem usage: build_greedy_compare.bat          -> build changed trees + control + harness
rem        build_greedy_compare.bat build    -> base checks + builds only
rem        build_greedy_compare.bat compare  -> base checks + control + harness (builds skipped)
set "RT=D:\AI\runtimes"
set "MAIN=%RT%\basalt-main"
set "FEAT=%RT%\basalt-squash"
set "FEAT_BRANCH=feat/slot-pin-integrated"
set "MODEL=D:\AI\models\basalt\Qwen3.8-FN-UD-IQ3_XXS.basalt"
set "LSWAP=http://192.168.178.20:8033"
rem If llama-swap has an api key: uncomment and set:
rem set "LAUTH=-H "Authorization: Bearer YOUR_KEY""
set "MODE=%~1"
pushd "%RT%"

rem ---- 1) feature tree on the expected branch ----------------------------
for /f "delims=" %%b in ('git -C "%FEAT%" rev-parse --abbrev-ref HEAD') do set "FB=%%b"
if not "%FB%"=="%FEAT_BRANCH%" (
  echo [greedy] ABORT: %FEAT% is on '%FB%', expected '%FEAT_BRANCH%'
  popd & exit /b 1
)

rem ---- 2) main tree tip must BE the branch's base (ancestor of the branch) --
rem        (upstream state is irrelevant here: what matters is that the two
rem         builds share this exact base commit - that is what gets diffed)
for /f "delims=" %%h in ('git -C "%MAIN%" rev-parse HEAD') do set "MH=%%h"
git -C "%FEAT%" merge-base --is-ancestor "%MH%" HEAD >nul 2>&1
if errorlevel 1 (
  echo [greedy] ABORT: main tip !MH:~0,8! is not in %FEAT_BRANCH%'s history - the builds share no base.
  echo [greedy]   fix: check out in %MAIN% the commit %FEAT_BRANCH% grew from,
  echo [greedy]   or rebase %FEAT_BRANCH% onto main's tip; then re-run the suites.
  popd & exit /b 1
)
echo [greedy] base OK: main tip !MH:~0,8! is the merge-base of %FEAT_BRANCH%

rem ---- 3) builds (skipped in compare-only mode) ---------------------------
if /i not "%MODE%"=="compare" (
  call :build "%MAIN%" || (popd & exit /b 1)
  call :build "%FEAT%" || (popd & exit /b 1)
)
if /i "%MODE%"=="build" (echo [greedy] build phase done, harness not run. & popd & exit /b 0)

rem ---- 4) llama-swap handshake: pause, unload, verify drained -------------
curl.exe -s -m 5 %LAUTH% -X POST "%LSWAP%/api/models/pause" >nul 2>&1
if errorlevel 1 (
  echo [greedy] ABORT: llama-swap unreachable at %LSWAP% - refusing to start a second engine.
  popd & exit /b 1
)
echo [greedy] llama-swap paused (incoming requests held)
curl.exe -s -m 10 %LAUTH% -X POST "%LSWAP%/api/models/unload" >nul 2>&1
set "WAITED=0"
:poll
curl.exe -s -m 5 "%LSWAP%/running" > "%TEMP%\lswap_running.json" 2>&1
findstr /c:"state" "%TEMP%\lswap_running.json" >nul
if errorlevel 1 goto :drained
set /a WAITED+=3
if !WAITED! geq 180 goto :stuck
timeout /t 3 /nobreak >nul
goto :poll
:stuck
curl.exe -s -m 5 %LAUTH% -X POST "%LSWAP%/api/models/resume" >nul 2>&1
echo [greedy] ABORT: a model is STILL running after 180s - llama-swap resumed, harness NOT started.
echo [greedy] (check %TEMP%\lswap_running.json and who keeps reloading)
popd & exit /b 1
:drained
echo [greedy] VRAM free - running harness

rem ---- 5a) CONTROL: main exe vs itself - host determinism gate ------------
echo [greedy] control run (main vs main):
python "%MAIN%\tools\greedy_identity.py" "%MAIN%\bin\basalt.exe" "%MAIN%\bin\basalt.exe" --model "%MODEL%" -- --expert-cache 4000 --vram-reserve-mib 1024 --gpu 1
if not errorlevel 1 goto :ctrl_ok
curl.exe -s -m 5 %LAUTH% -X POST "%LSWAP%/api/models/resume" >nul 2>&1
popd
echo [greedy] ABORT: CONTROL diverged - this host is not reproducing greedy output; a comparison now would be meaningless.
echo [greedy] llama-swap resumed. Tighten tier pinning / check GPU-0 desktop load, then rerun.
exit /b 3
:ctrl_ok

rem ---- 5b) the real comparison -------------------------------------------
echo [greedy] control green - running main vs branch:
python "%MAIN%\tools\greedy_identity.py" "%MAIN%\bin\basalt.exe" "%FEAT%\bin\basalt.exe" --model "%MODEL%" -- --expert-cache 4000 --vram-reserve-mib 1024 --gpu 1
set "RC=%ERRORLEVEL%"

rem ---- 6) always resume the host ------------------------------------------
curl.exe -s -m 5 %LAUTH% -X POST "%LSWAP%/api/models/resume" >nul 2>&1
popd
echo [greedy] llama-swap resumed. exit=%RC%  (0 = GREEDY IDENTICAL)
pause
exit /b %RC%

:build
setlocal EnableExtensions EnableDelayedExpansion
set "T=%~1"
for /f "delims=" %%h in ('git -C "%T%" rev-parse HEAD') do set "H=%%h"
set "STAMP=%T%\build\built.hash"
set "DIRTY="
for /f "delims=" %%l in ('git -C "%T%" status --porcelain') do set "DIRTY=1"
set "OLD=none"
if exist "%STAMP%" set /p "OLD="<"%STAMP%"
if defined DIRTY (
  echo [greedy] %T%: DIRTY tree - building without stamp, fix before claiming results
  call "%RT%\build_basalt_minimal.bat" "%T%" || (endlocal & exit /b 1)
  endlocal & exit /b 0
)
if "%OLD%"=="%H%" (
  echo [greedy] %T%: built at !H:~0,8! already - build skipped ^(delete build\built.hash to force^)
  endlocal & exit /b 0
)
echo [greedy] %T%: building at !H:~0,8! ...
call "%RT%\build_basalt_minimal.bat" "%T%" || (endlocal & exit /b 1)
> "%STAMP%" echo %H%
endlocal & exit /b 0
