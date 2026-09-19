# P0 — Nâng Flutter 3.41.5 → 3.47 — kế hoạch thi công

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (người dùng chốt
> thi công **inline trong phiên**, không giao mỗi task cho agent con — memory
> `thuc-thi-ke-hoach-inline-khong-dung-agent-con`). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Đưa toolchain của `src/Client-app` lên Flutter stable mới nhất (3.47, Dart ≥ 3.12) mà
**không đổi hành vi nào** của app, để P3 dùng được `flutter_gemma` 1.8.3.

**Architecture:** Không có mã tính năng nào trong P0. Nâng SDK máy dev (`C:\Users\tadd1\flutter`,
kênh stable, cài bằng git) → giải phụ thuộc → sinh lại mã Drift → chạy đủ bốn phép kiểm của dự án
(analyze, test, build APK, máy ảo) → ghi tài liệu. Mỗi bước có lệnh hoàn tác.

**Tech Stack:** Flutter 3.47 stable, Dart 3.12+, Gradle 8.14 / AGP 8.11.1 / Kotlin 2.2.20 (giữ
nguyên trừ khi flutter tool đòi), drift 2.x + build_runner, máy ảo `FlowMoney_16G`.

**Spec:** `docs/superpowers/specs/2026-09-19-ai-edge-slm-design.md` — mục 1, hàng **P0**.

## Global Constraints

- Chỉ sửa `src/Client-app` (và tài liệu ở `docs/`, `CLAUDE.md`). Không đụng `src/Backend`.
- **Một commit riêng cho việc nâng, chưa đụng gì tới AI** (spec mục 1). Không thêm `flutter_gemma`
  ở P0.
- Mốc phải giữ: `flutter test` **2960 pass, 1 skip**; `flutter analyze` **25 issue, 0 error**;
  `flutter build apk --debug` xanh; máy ảo mở app và đăng nhập được.
- Không sửa deprecation không liên quan chỉ vì bản mới cảnh báo nhiều hơn — ghi con số mới vào
  `CLAUDE.md`, trừ khi nó là **error**.
- `fl_chart: 1.2.0` **giữ ghim cứng** (mục 3.11 `ANALYTICS_FEATURE.md`).
- Đừng ngắt `flutter test` giữa chừng, đừng chạy hai lần cùng lúc (Ghi chú vận hành `CLAUDE.md`).
- Lệnh chạy từ `src/Client-app` trừ khi ghi khác. Bash tool là Git Bash.
- `adb` không có trong PATH: dùng `"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"`.

---

### Task 1: Ghi mốc trước khi nâng và chốt lệnh hoàn tác

**Files:**
- Không sửa tệp nào. Kết quả ghi vào phần ghi chú của chính kế hoạch này (mục "Nhật ký" cuối tệp).

**Interfaces:**
- Produces: mốc SDK cũ (`2c9eb20739`, tag `3.41.5`) và lệnh hoàn tác dùng ở mọi task sau.

- [ ] **Step 1: Xác nhận cây làm việc sạch và SDK đang ở 3.41.5**

Run (từ gốc repo):
```bash
git status --short && flutter --version 2>&1 | head -2 && git -C "$HOME/flutter" log -1 --format='%H %d'
```
Expected: `git status` không in gì; `Flutter 3.41.5 • channel stable`; SDK ở
`2c9eb20739dfec95e2c74bd3dfa4601b0a8a36aa (HEAD -> stable, tag: 3.41.5)`.

Nếu cây làm việc không sạch: dừng, hỏi người dùng — P0 phải là một commit riêng.

- [ ] **Step 2: Ghi lệnh hoàn tác vào Nhật ký cuối tệp này**

Lệnh hoàn tác SDK (dùng khi bất kỳ task nào sau thất bại không sửa được):
```bash
git -C "$HOME/flutter" checkout 3.41.5 && cd src/Client-app && flutter --version && flutter pub get
```
`flutter --version` sau checkout tự dựng lại tool cho đúng bản (mất 1–3 phút). `pubspec.lock` hoàn
tác bằng `git checkout -- pubspec.lock pubspec.yaml`.

- [ ] **Step 3: Xác nhận máy ảo và máy thật không cắm (P0 chỉ cần máy ảo)**

Run:
```bash
"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" devices
```
Expected: danh sách rỗng hoặc chỉ `emulator-5554`. Không cần máy thật ở P0.

---

### Task 2: Nâng SDK Flutter lên stable mới nhất

**Files:**
- Không sửa tệp trong repo. Thay đổi nằm ở `C:\Users\tadd1\flutter` (ngoài repo).

**Interfaces:**
- Produces: `flutter --version` ≥ 3.44 (kỳ vọng 3.47.x), Dart ≥ 3.12.

- [ ] **Step 1: Nâng kênh stable**

Run (timeout 600000 ms — tải engine và dựng lại tool):
```bash
flutter upgrade 2>&1 | tail -15
```
Expected: kết thúc bằng dòng `Flutter 3.47.x • channel stable` (hoặc bản stable mới hơn) và
`Dart 3.1x.x`. Nếu in `Upgrading Flutter to ... requires a newer version of git` hoặc lỗi mạng:
chạy lại một lần; vẫn lỗi thì dừng và báo.

- [ ] **Step 2: Xác nhận bản mới đủ điều kiện của `flutter_gemma` 1.8.3**

Run:
```bash
flutter --version 2>&1 | head -3; dart --version 2>&1
```
Expected: Flutter **≥ 3.44.0**, Dart **≥ 3.12.0**. Nếu stable mới nhất < 3.44 (không thể theo
lịch phát hành, nhưng phải kiểm): dừng, báo người dùng, hoàn tác theo Task 1 Step 2.

- [ ] **Step 3: Kiểm `flutter doctor` không có lỗi mới ở Android toolchain**

Run:
```bash
flutter doctor 2>&1 | grep -E "^\[|•" | head -30
```
Expected: `[√] Flutter`, `[√] Android toolchain`; các dòng `[!]` (nếu có) phải **giống** trước khi
nâng — không xuất hiện dòng mới về Android SDK / cmdline-tools / license. Nếu doctor đòi
`flutter doctor --android-licenses`: chạy nó và trả lời `y`.

Ghi vào Nhật ký: bản Flutter/Dart thật sự nhận được, và mã git của SDK
(`git -C "$HOME/flutter" log -1 --format='%H %d'`).

---

### Task 3: Giải phụ thuộc — `flutter pub get`

**Files:**
- Modify (có thể): `src/Client-app/pubspec.yaml` (chỉ dòng `intl`), `src/Client-app/pubspec.lock`.

**Interfaces:**
- Produces: `pubspec.lock` giải được với SDK mới; `fl_chart` vẫn `1.2.0`.

- [ ] **Step 1: Chạy pub get**

Run (từ `src/Client-app`):
```bash
flutter pub get 2>&1 | tail -25
```
Expected: `Got dependencies!` (hoặc `Changed N dependencies!`).

- [ ] **Step 2: Nếu lỗi xung đột `intl`** (và chỉ khi ấy)

Lỗi có dạng: `Because flowmoney depends on flutter_localizations from sdk which depends on intl
0.2X.Y, intl 0.2X.Y is required.` Sửa **đúng một dòng** trong `pubspec.yaml`:

```yaml
  intl: ^0.2X.Y   # bản mà flutter_localizations của Flutter 3.47 ghim — lấy từ thông báo lỗi
```
Rồi chạy lại Step 1. **Không** đổi dòng nào khác của `pubspec.yaml`. Nếu lỗi nói về gói khác
(`drift`, `flutter_local_notifications`, `share_plus`…): ghi nguyên văn vào Nhật ký, thử
`flutter pub upgrade <tên gói>` **cho riêng gói ấy**; vẫn lỗi thì dừng và báo người dùng — không
tự nới ràng buộc hàng loạt.

- [ ] **Step 3: Soát diff của pubspec.lock**

Run:
```bash
git diff --stat pubspec.yaml pubspec.lock; git diff pubspec.lock | grep -E "^[-+]\s+version:" | head -40
```
Expected: `fl_chart` **không** xuất hiện trong diff (vẫn 1.2.0). Các gói đổi bản chỉ ở mức
minor/patch trong dải `^` đã khai. Nếu một gói nhảy **major** (ví dụ `drift 2.x → 3.x`,
`go_router 14 → 15`): hoàn tác `git checkout -- pubspec.lock`, chạy `flutter pub get` lại — nếu
vẫn nhảy thì đó là do gói cũ không hợp SDK mới; ghi Nhật ký và báo người dùng trước khi tiếp.

- [ ] **Step 4: Commit tạm (sẽ gộp ở Task 9)**

Không commit ở bước này — P0 là **một** commit. Chỉ xác nhận `git status --short` liệt kê đúng
`pubspec.lock` (và `pubspec.yaml` nếu có sửa `intl`).

---

### Task 4: Sinh lại mã Drift

**Files:**
- Modify (có thể): `src/Client-app/lib/core/database/app_database.g.dart` và mọi `*.g.dart` khác.

**Interfaces:**
- Produces: mã sinh khớp `drift_dev` đã giải ở Task 3.

- [ ] **Step 1: Chạy build_runner**

Run (timeout 600000 ms):
```bash
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -8
```
Expected: `Succeeded after Xs with N outputs`. Không có dòng `[SEVERE]`.

- [ ] **Step 2: Soát diff mã sinh**

Run:
```bash
git diff --stat -- '*.g.dart' | tail -5
```
Expected: rỗng, hoặc chỉ đổi header/format do `drift_dev` bản mới. Nếu diff đổi **tên cột, kiểu,
hay số lượng bảng**: dừng — đó không phải việc của P0. Ghi Nhật ký.

---

### Task 5: `flutter analyze` về mức nền

**Files:**
- Không sửa mã trừ khi có **error**.

**Interfaces:**
- Produces: con số issue mới cho `CLAUDE.md` (Task 9).

- [ ] **Step 1: Chạy analyze và đếm**

Run:
```bash
flutter analyze 2>&1 | tail -3; flutter analyze 2>&1 | grep -cE "^\s*(error|warning|info) •"
```
Expected: `25 issues found` hoặc nhiều hơn **chỉ vì cảnh báo deprecation mới**; dòng nào
`error •` là **0**.

- [ ] **Step 2: Nếu có `error •`**

Run:
```bash
flutter analyze 2>&1 | grep -E "^\s*error •"
```
Sửa **đúng chỗ báo**, tối thiểu (thường là API bị gỡ: ví dụ `MaterialStateProperty` → `WidgetStateProperty`,
`Color.value` → `toARGB32()`). Mỗi chỗ sửa ghi vào Nhật ký kèm tên API cũ/mới. Chạy lại Step 1.

- [ ] **Step 3: Nếu số issue tăng chỉ vì `info • ... deprecated`**

**Không sửa.** Ghi con số mới và nhóm cảnh báo (ví dụ "+12 `withOpacity` deprecated") vào Nhật ký để
Task 9 cập nhật mức nền trong `CLAUDE.md`. Sửa deprecation là hạng mục riêng, không phải P0.

---

### Task 6: `flutter test` trọn bộ

**Files:**
- Không sửa mã trừ khi test đỏ vì hành vi framework đổi.

**Interfaces:**
- Produces: mốc test mới cho `CLAUDE.md`.

- [ ] **Step 1: Chạy nền, ghi log, timeout mỗi test**

Run (từ `src/Client-app`, `run_in_background: true`; log ở scratchpad phiên):
```bash
flutter test --timeout 60s > "$SCRATCH/p0_flutter_test.log" 2>&1; echo "EXIT=$?" >> "$SCRATCH/p0_flutter_test.log"
```
(`$SCRATCH` = thư mục scratchpad của phiên.) Chờ thông báo hoàn tất — **không** chạy lệnh test thứ
hai trong lúc chờ.

- [ ] **Step 2: Đọc kết quả**

Run:
```bash
tail -5 "$SCRATCH/p0_flutter_test.log"; grep -cE "^\s*✗|\[E\]" "$SCRATCH/p0_flutter_test.log"
```
Expected: dòng cuối dạng `+2960 ~1: All tests passed!`, `EXIT=0`.

- [ ] **Step 3: Nếu có ca đỏ**

Run:
```bash
grep -nE "^\s*(✗|\[E\])|Expected:|Actual:|The following" "$SCRATCH/p0_flutter_test.log" | head -40
```
Phân loại từng ca:
- **Framework đổi hành vi** (ví dụ `find.text` đổi cách so, `pumpAndSettle` thời gian, default
  padding của `ListTile`, `TextField` đo khác ở font Ahem): sửa **test hoặc mã** tối thiểu để giữ
  hành vi người dùng thấy; ghi Nhật ký kèm tên ca và nguyên nhân.
- **Test lịch ghi cứng mốc đã qua** (bẫy `os_notifier_native_test`): sửa mốc sang tương đối.
- **Lỗi thật của app** lộ ra do bản mới: dừng, báo người dùng — không giấu bằng cách sửa test.

Sau khi sửa, chạy lại **chỉ tệp ấy** (`flutter test test/<đường dẫn>`) rồi mới chạy lại trọn bộ Step 1.

---

### Task 7: Build APK debug

**Files:**
- Modify (có thể): `src/Client-app/android/settings.gradle.kts` (chỉ version AGP/Kotlin nếu tool đòi),
  `src/Client-app/android/gradle/wrapper/gradle-wrapper.properties` (chỉ nếu tool đòi).

**Interfaces:**
- Produces: `build/app/outputs/flutter-apk/app-debug.apk` cho Task 8.

- [ ] **Step 1: Build**

Run (timeout 600000 ms):
```bash
flutter build apk --debug 2>&1 | tail -12
```
Expected: `√ Built build/app/outputs/flutter-apk/app-debug.apk`. Lần đầu sau nâng có thể tải NDK/
Gradle — chờ.

- [ ] **Step 2: Nếu tool đòi nâng Gradle/AGP/Kotlin**

Thông báo có dạng `Your project's Gradle version is incompatible...` hoặc `requires Android Gradle
Plugin ≥ X.Y`. Sửa **đúng con số tool nêu**, ở đúng tệp:
- AGP: `id("com.android.application") version "8.11.1"` trong `android/settings.gradle.kts`
- Kotlin: `id("org.jetbrains.kotlin.android") version "2.2.20"` cùng tệp
- Gradle: `distributionUrl=...gradle-8.14-all.zip` trong `android/gradle/wrapper/gradle-wrapper.properties`

Ghi Nhật ký. Chạy lại Step 1. Cảnh báo (warning) về Gradle **không** bắt buộc sửa ở P0.

- [ ] **Step 3: Xác nhận `AndroidManifest.xml` không bị tool ghi đè**

Run:
```bash
git status --short android/ ; git diff android/app/src/main/AndroidManifest.xml | head
```
Expected: manifest **không đổi** — nó giữ `android:enableOnBackInvokedCallback="false"` (E3) và
các khai báo thông báo (7.11 `NOTIFICATION_FEATURE.md`). Nếu đổi: hoàn tác `git checkout -- <tệp>`.

---

### Task 8: Nghiệm thu máy ảo

**Files:**
- Không sửa tệp. Ảnh chụp vào scratchpad.

**Interfaces:**
- Consumes: `app-debug.apk` từ Task 7.

- [ ] **Step 1: Khởi động máy ảo nếu chưa chạy**

Run (`run_in_background: true`):
```bash
"$LOCALAPPDATA/Android/Sdk/emulator/emulator.exe" -avd FlowMoney_16G -gpu swangle > "$SCRATCH/emu.log" 2>&1
```
Rồi chờ tới khi:
```bash
"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" wait-for-device shell getprop sys.boot_completed
```
in `1` (thường 60–90 giây). Cờ `-gpu swangle` bắt buộc (máy ảo chết SIGSEGV với cờ khác khi
người dùng bấm vào cửa sổ — `CLAUDE.md` "Chạy máy ảo").

- [ ] **Step 2: Cài và mở app**

Run:
```bash
ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
"$ADB" install -r build/app/outputs/flutter-apk/app-debug.apk && "$ADB" shell am start -n com.flowmoney.flowmoney/.MainActivity
```
Expected: `Success` và `Starting: Intent {...}`. **Chờ 25 giây** (bàn giao: 10 giây còn ở splash).

- [ ] **Step 3: Chụp màn hình và kiểm**

Run:
```bash
"$ADB" exec-out screencap -p > "$SCRATCH/p0_home.png"
python -c "
from PIL import Image; im=Image.open(r'$SCRATCH/p0_home.png').convert('RGB'); px=im.getdata()
print('vang', sum(1 for p in px if p==(255,255,0)))" 2>/dev/null || echo "không có PIL — mở ảnh bằng Read"
```
Rồi mở `p0_home.png` bằng công cụ Read. Expected: Trang chủ (hoặc màn Đăng nhập nếu phiên đã hết —
đăng nhập bằng tài khoản thử người dùng cung cấp) hiện đúng như trước nâng; **0** pixel vàng thuần
(sọc tràn). Nếu app dừng ở splash quá 40 giây hay màn đỏ:
```bash
"$ADB" logcat -d | grep -E "flutter|FATAL|AndroidRuntime" | tail -40
```
và xử lý như Task 6 Step 3 (lỗi framework → sửa tối thiểu; lỗi lạ → báo người dùng).

- [ ] **Step 4: Đi ba màn dễ vỡ nhất**

Chạm lần lượt tab **Phân tích** (nhiều `fl_chart`), tab **Giao dịch**, rồi mở drawer → **Ngân sách**
(route ngoài shell, nút Back). Mỗi màn chụp một ảnh, đếm pixel vàng, mở xem. Expected: không tràn,
không màn đỏ, nút Back ở Ngân sách quay về Trang chủ. Ghi Nhật ký ba tên ảnh.

---

### Task 9: Tài liệu và commit duy nhất của P0

**Files:**
- Modify: `CLAUDE.md` — khối "Lệnh hay dùng" (dòng bắt đầu `# Test (chạy từ src/Client-app) — hiện **2960/2960** pass`) và dòng `flutter analyze          # mức nền: 25 issue, KHÔNG có error`.
- Modify: `docs/PROJECT_CONTEXT.md` — thêm khối mới ngay sau dòng `## 14. Trạng thái hiện tại (cập nhật cuối 2026-09-19)` (dòng 597), **trước** khối `### 🎨 Lượt sửa UX/UI theo đánh giá 2026-09-19`.
- Modify: kế hoạch này — đánh dấu xong, điền Nhật ký.

**Interfaces:**
- Produces: mốc mới cho mọi phiên sau.

- [ ] **Step 1: Cập nhật `CLAUDE.md`**

Ở đầu khối "Lệnh hay dùng", thêm một đoạn trước dòng `# Test (chạy từ src/Client-app)`:

```markdown
# ⬆️ Toolchain: Flutter **3.47.x** / Dart **3.1x.x** từ 2026-09-19 (P0 của AI Edge-SLM — nâng
# từ 3.41.5 vì `flutter_gemma` 1.8.3 đòi Flutter ≥ 3.44; spec
# `docs/superpowers/specs/2026-09-19-ai-edge-slm-design.md` mục 1). SDK cài bằng git ở
# `C:\Users\tadd1\flutter`; hoàn tác: `git -C ~/flutter checkout 3.41.5 && flutter --version`.
# ⚠️ Máy khác dựng dự án phải ở ≥ 3.44, nếu không `flutter pub get` từ chối ngay khi P3 thêm gói.
```
(thay `3.47.x`/`3.1x.x` bằng con số thật từ Task 2). Nếu Task 5/6 đổi mốc: sửa `**2960/2960**`,
`25 issue` thành con số mới kèm cụm "(đo 2026-09-19 sau nâng Flutter 3.47; +N cảnh báo deprecation
`<tên API>`)".

- [ ] **Step 2: Thêm khối vào mục 14 `PROJECT_CONTEXT.md`**

Chèn ngay sau dòng 597:

```markdown
### ⬆️ Nâng Flutter 3.41.5 → 3.47 — P0 của AI Edge-SLM (2026-09-19)

Người dùng gỡ lệnh hoãn mảng Edge-SLM ngày 2026-09-19 và chốt **nâng Flutter** để
dùng `flutter_gemma` 1.8.3 (đòi Flutter ≥ 3.44, Dart ≥ 3.12; bản 0.13.6 hợp 3.41
thì thiếu API mới và Gemma 4). Thiết kế đã duyệt:
`docs/superpowers/specs/2026-09-19-ai-edge-slm-design.md`; bản đánh giá 18/09 có
banner đính chính (gói không chạy Gemma 3 4B — bậc thang mới là Gemma 4 E4B/E2B).

P0 là **một commit, không mã tính năng**. Kết quả đo sau nâng: Flutter `3.47.x`,
Dart `3.1x.x`, SDK git `<mã>`; `pubspec.lock` đổi <N> gói (không gói nào nhảy
major; `fl_chart` vẫn 1.2.0; `intl` <giữ/đổi thành ...>); mã Drift sinh lại
<không đổi / đổi header>; `flutter analyze` <25 / N issue, 0 error>;
`flutter test` <2960/2960 pass, 1 skip> trong <thời gian>; `flutter build apk
--debug` xanh <có/không nâng Gradle/AGP>; máy ảo `FlowMoney_16G` mở Trang chủ,
Phân tích, Giao dịch, Ngân sách — 0 pixel vàng. <Các ca test/API phải sửa, nếu
có, liệt kê ở đây kèm nguyên nhân.>

Bước tiếp: **P1 spike** khi người dùng cắm máy Snapdragon 8 Gen 3; **P2** (tầng
Edge + mẫu câu) không chờ P1 — kế hoạch riêng ở `docs/superpowers/plans/`.
```
Điền mọi `<...>` bằng con số thật từ Nhật ký. **Không để lại dấu `<>`** nào.

- [ ] **Step 3: Kiểm lại toàn bộ diff trước khi commit**

Run (từ gốc repo):
```bash
git status --short; git diff --stat
```
Expected: chỉ `pubspec.lock` (± `pubspec.yaml`, `*.g.dart`, tệp Gradle nếu tool đòi, test/mã đã
sửa ở Task 5–6), `CLAUDE.md`, `docs/PROJECT_CONTEXT.md`, và tệp kế hoạch này. Không có tệp lạ
(`build/`, `.dart_tool/` đã gitignore).

- [ ] **Step 4: Commit**

```bash
git add src/Client-app/pubspec.yaml src/Client-app/pubspec.lock CLAUDE.md docs/PROJECT_CONTEXT.md
git add -f docs/superpowers/plans/2026-09-19-ai-edge-p0-nang-flutter.md
# cộng từng tệp khác đã sửa ở Task 4–7, liệt kê đích danh (test/ phải -f)
git commit -F - <<'EOF'
chore(client): nâng Flutter 3.41.5 → 3.47 — P0 của AI Edge-SLM

Vì flutter_gemma 1.8.3 đòi Flutter ≥ 3.44 / Dart ≥ 3.12. Không mã tính năng.
Kiểm: pub get, build_runner, analyze <N>, test <N>/<N>, build apk, máy ảo bốn màn.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```
(điền `<N>` bằng con số thật). Không push — người dùng không bảo.

---

## Nhật ký thi công (điền khi làm)

| Mục | Giá trị |
|---|---|
| SDK trước | `2c9eb20739` · 3.41.5 · Dart 3.11.3 |
| SDK sau | |
| `pubspec` đổi | |
| Mã Drift | |
| analyze | |
| test | |
| build apk | |
| máy ảo | |
| Ca/API phải sửa | |
