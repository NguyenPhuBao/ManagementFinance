#!/bin/sh
# One test user end to end on the NCKH emulator (1080x2400), starting from the Budget-detail page of the
# previous user: log out, register + log in nckh_uN, push the user's data, open Budget and its detail page,
# then run the app's own pacing code offline at the same clock time.
# Usage (from experiment/): sh app_run_user.sh N   -> ../app_test/uN_{home,budget,detail}.png, uN_dart.txt
export MSYS_NO_PATHCONV=1
ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
D=../app_test
N=$1
"$ADB" shell input keyevent KEYCODE_BACK; sleep 1
"$ADB" shell input keyevent KEYCODE_BACK; sleep 2
"$ADB" shell input tap 125 170; sleep 2      # drawer
"$ADB" shell input tap 275 2104; sleep 2     # Đăng xuất
"$ADB" shell input tap 540 1436; sleep 8     # confirm, wait for the login screen
python -u app_load.py register $N | cut -c1-60
"$ADB" shell input tap 700 975; sleep 1
"$ADB" shell input text "nckh_u$N"; sleep 1
"$ADB" shell input keyevent KEYCODE_TAB; sleep 1
"$ADB" shell input text 'Nckh@2026'; sleep 1
"$ADB" shell input keyevent KEYCODE_BACK; sleep 1
"$ADB" shell input tap 540 1413
sleep 25                                     # first sync: the app pushes its wallets and category copies
python -u app_load.py push $N | grep -E "wallets|ops"
"$ADB" shell am force-stop com.flowmoney.flowmoney
"$ADB" shell am start -n com.flowmoney.flowmoney/.MainActivity > /dev/null
sleep 30                                     # pull of ~600 transactions
"$ADB" exec-out screencap -p > $D/u${N}_home.png
"$ADB" shell input tap 125 170; sleep 2      # drawer
"$ADB" shell input tap 280 722; sleep 4      # Ngân sách
"$ADB" exec-out screencap -p > $D/u${N}_budget.png
"$ADB" shell input swipe 540 1900 540 700 600; sleep 2
"$ADB" shell input tap 450 1560; sleep 4     # total-budget card -> detail
T=$("$ADB" shell date +%Y-%m-%dT%H:%M:%S | tr -d '\r')
"$ADB" exec-out screencap -p > $D/u${N}_detail.png
dart run dart_check/app_check.dart $N "$T" 2>&1 | grep ROW | tee $D/u${N}_dart.txt
