@echo off
REM FlockKeeper Windows Launcher
REM Copies required Flutter SDK engine headers and cpp_client_wrapper before building.
REM This is required because tool_backend.bat does not copy these for this SDK version.

set FLUTTER_ENGINE_CACHE=D:\HerdLinkSystem\flutter\bin\cache\artifacts\engine\windows-x64
set EPHEMERAL=windows\flutter\ephemeral

echo -----------------------------------------------
echo FlockKeeper Windows Launcher
echo -----------------------------------------------

echo Syncing Flutter engine headers...
xcopy /E /Y /Q "%FLUTTER_ENGINE_CACHE%\cpp_client_wrapper" "%EPHEMERAL%\cpp_client_wrapper\" > nul
copy /Y "%FLUTTER_ENGINE_CACHE%\flutter_windows.h"           "%EPHEMERAL%\" > nul
copy /Y "%FLUTTER_ENGINE_CACHE%\flutter_messenger.h"         "%EPHEMERAL%\" > nul
copy /Y "%FLUTTER_ENGINE_CACHE%\flutter_plugin_registrar.h"  "%EPHEMERAL%\" > nul
copy /Y "%FLUTTER_ENGINE_CACHE%\flutter_texture_registrar.h" "%EPHEMERAL%\" > nul
copy /Y "%FLUTTER_ENGINE_CACHE%\flutter_export.h"            "%EPHEMERAL%\" > nul
copy /Y "%FLUTTER_ENGINE_CACHE%\flutter_windows.dll"         "%EPHEMERAL%\" > nul
copy /Y "%FLUTTER_ENGINE_CACHE%\flutter_windows.dll.lib"     "%EPHEMERAL%\" > nul
copy /Y "%FLUTTER_ENGINE_CACHE%\icudtl.dat"                  "%EPHEMERAL%\" > nul
echo Engine headers ready.

flutter run -d windows --release %*

