@echo off
cd /d "%~dp0"
start "Warehouse Scanner Tool Server" cmd /k python -m http.server 8002
timeout /t 2 /nobreak >nul
start http://localhost:8002/warehouse-scanner-tool.html
