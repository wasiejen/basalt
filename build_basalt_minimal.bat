@echo off
setlocal EnableExtensions

rem === Basalt rebuild script ===
set "ROOT=%~dpf1"
set "BUILD_DIR=%ROOT%\build"
set "BIN_DIR=%ROOT%\bin"


cd /d "%ROOT%" || goto :fail

echo.
echo === Initializing Visual Studio x64 environment ===
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
if errorlevel 1 goto :fail

where cl >nul 2>&1 || goto :fail_no_cl
where nvcc >nul 2>&1 || goto :fail_no_nvcc
where ninja >nul 2>&1 || goto :fail_no_ninja
where cmake >nul 2>&1 || goto :fail_no_cmake

echo.
echo === Removing previous build directory ===
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
if exist "%BUILD_DIR%" goto :fail

echo.
echo === Configuring Basalt ===
cmake -S . -B build -G Ninja ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DBUILD_TESTING=ON ^
  -DCMAKE_CUDA_COMPILER="C:/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v13.5/bin/nvcc.exe" ^
  -DCUDAToolkit_ROOT="C:/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v13.5" ^
  -DBASALT_MODELS="qwen4exp"
if errorlevel 1 goto :fail

echo.
echo === Building Basalt ===
cmake --build build -j
if errorlevel 1 goto :fail

echo.
echo === Build completed successfully ===
if exist "%BIN_DIR%" dir "%BIN_DIR%"
goto :done

:fail_no_cl
echo ERROR: MSVC compiler cl.exe was not found.
goto :fail

:fail_no_nvcc
echo ERROR: CUDA compiler nvcc.exe was not found.
goto :fail

:fail_no_ninja
echo ERROR: Ninja was not found.
goto :fail

:fail_no_cmake
echo ERROR: CMake was not found.
goto :fail

:fail
echo.
echo === BUILD FAILED ===
exit /b 1

:done
exit /b 0
