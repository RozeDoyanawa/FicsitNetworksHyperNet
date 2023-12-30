@echo off
echo "Copying..."

rem This file is un-tested!
rem Do note that i use Program.lua in the target. That is because I use the same bootstrapper for all my code.

rem space-separated list of floppy-drive id's
set floppies = 39E832674F406C533F9788B2FA4BF17A

(for %%a in (%list%) do (
	copy /Y "Common.lua" 										"%localappdata%\FactoryGame\Saved\SaveGames\Computers\%%a\Common.lua"
	copy /Y "HyperNet\HyperNet.lua" 							"%localappdata%\FactoryGame\Saved\SaveGames\Computers\%%a\Program.lua"
	copy /Y "json.lua" 											"%localappdata%\FactoryGame\Saved\SaveGames\Computers\%%a\json.lua"
	copy /Y "sort.lua" 											"%localappdata%\FactoryGame\Saved\SaveGames\Computers\%%a\sort.lua"
))

echo "Done"

rem TIMEOUT 4

rem exit