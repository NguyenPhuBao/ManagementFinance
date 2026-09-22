@echo off
chcp 65001 > nul
echo ======================================================================
echo    Chay bo kiem thu trang thai Request va Audit Log Reason
echo ======================================================================
echo.

node "%~dp0test_req_statuses.js"

echo.
pause
