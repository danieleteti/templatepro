@echo off
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
msbuild "C:\DEV\templatepro\tests\templateprounittests.dproj" /t:Build /p:Config=Debug /p:Platform=Win32
