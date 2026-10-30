@echo off
setlocal
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo Se necesita Node.js 24 o superior. Instalalo desde https://nodejs.org/
  pause
  exit /b 1
)
node -e "if(Number(process.versions.node.split('.')[0])<24){console.error('Se necesita Node.js 24 o superior.');process.exit(1)}"
if errorlevel 1 (
  pause
  exit /b 1
)
node web/server.mjs --open %*
if errorlevel 1 (
  pause
  exit /b 1
)
endlocal
