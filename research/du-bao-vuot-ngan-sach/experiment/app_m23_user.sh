#!/bin/sh
# Trial build with M1/M2/M3 (2026-11-10): log user N back in on the NCKH emulator (data already on PersonFinance from
# app_run_user.sh), open the total-budget detail page, save the screenshot and the app's [DuBaoVuot] log line.
# Starts from any page of a logged-in user. Usage (from experiment/): sh app_m23_user.sh N
#   -> ../app_test/uN_detail_m23.png, uN_m23_log.txt
export MSYS_NO_PATHCONV=1
ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
D=../app_test
N=$1
"$ADB" shell am force-stop com.flowmoney.flowmoney
"$ADB" shell am start -n com.flowmoney.flowmoney/.MainActivity > /dev/null
sleep 25
"$ADB" shell input tap 125 170; sleep 2      # drawer
"$ADB" shell input tap 275 2104; sleep 2     # Đăng xuất
"$ADB" shell input tap 540 1436; sleep 8     # confirm, wait for the login screen
"$ADB" shell input tap 700 975; sleep 1
"$ADB" shell input text "nckh_u$N"; sleep 1
"$ADB" shell input keyevent KEYCODE_TAB; sleep 1
"$ADB" shell input text 'Nckh@2026'; sleep 1
"$ADB" shell input keyevent KEYCODE_BACK; sleep 1
"$ADB" shell input tap 540 1413
sleep 45                                     # pull of ~600 transactions
"$ADB" exec-out screencap -p > $D/u${N}_home_m23.png
"$ADB" logcat -c
"$ADB" shell input tap 125 170; sleep 2      # drawer
"$ADB" shell input tap 280 722; sleep 4      # Ngân sách
"$ADB" shell input swipe 540 1900 540 700 600; sleep 2
"$ADB" shell input tap 450 1560; sleep 5     # total-budget card -> detail
"$ADB" exec-out screencap -p > $D/u${N}_detail_m23.png
"$ADB" logcat -d | grep -a "DuBaoVuot" | tail -1 | tee $D/u${N}_m23_log.txt
