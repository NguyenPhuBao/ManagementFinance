# FlowMoney — Hướng dẫn cho AI assistant

Ứng dụng quản lý tài chính cá nhân (đồ án tốt nghiệp). Flutter client (`src/Client-app`, Drift/SQLite, BLoC) ↔ Node/Express/Prisma/PostgreSQL (`src/Backend`). Kiến trúc **offline-first**: ghi vào SQLite trước, đồng bộ nền hai chiều sau.

---

## Đọc gì trước khi làm

**Luôn luôn:** `docs/PROJECT_CONTEXT.md` — đọc có trọng tâm, không đọc tuần tự:

1. **Mục 12** — Quy tắc phát triển bắt buộc
2. **Mục 14** — Trạng thái hiện tại (cái gì xong, cái gì dang dở)
3. **Mục 11** — Các lỗi đã sửa, đọc để **không lặp lại**
4. Mục 6 & 7 — chỉ khi đụng tới đồng bộ hoặc CSDL cục bộ

**Rồi tuỳ việc:**

| Việc | Đọc thêm |
|---|---|
| Làm tiếp phía client | `docs/CLIENT_APP_KNOWN_GAPS.md` — các mục dang dở kèm **lý do hoãn** và **bán kính ảnh hưởng** |
| Việc thuộc backend | `docs/superpowers/backend/README.md` — **mục 0 là thứ tự thi công chín bước chia ba nhóm**, đọc trước; mục 2 là trạng thái từng tài liệu. Hiện **7 tài liệu còn việc**. Bước 1 là thứ đang gây hại ngay: **Socket.io không xác thực + `io.emit` toàn cục** (`2026-09-04-ocr-classify-review.md`). Sau đó là `2026-09-04-backend-idempotent-delete.md` (ba lỗ hổng của `/sync/push`, một trong đó chặn hẳn ngân sách "Ngày cụ thể") và `CATEGORY_KEYWORD_SYNC.md` (lỗ hổng phân quyền). Bảng trạng thái đầy đủ ở mục 14 `docs/PROJECT_CONTEXT.md` |
| Đụng vào đồng bộ | `src/Client-app/test/core/sync/sync_payload_contract_test.dart` — đọc **như tài liệu**, đây là nơi duy nhất ghi hợp đồng tên trường giữa hai phía |
| Đụng vào thông báo | `docs/NOTIFICATION_FEATURE.md` — **trạng thái bàn giao, phần việc còn lại, và bảy cái bẫy**. Mục 7 phải đọc trước khi đụng vào phần hệ điều hành. Bảng thông báo **cục bộ**, không nằm trong `SyncEntityType` |
| Đụng vào danh mục | `docs/CATEGORY_RATIONALE.md` — **lý do** của từng thay đổi, bằng chứng đo được, và các phương án đã loại bỏ. Đọc trước khi định "dọn dẹp" vùng này |
| Đụng vào mục tiêu tiết kiệm | `docs/GOAL_FEATURE.md` — **quyết định kèm lý do, và bảy cái bẫy**. Mục 4 phải đọc trước khi sửa gì. Ba cái đáng nhớ nhất: `walletTransfer` **không có khoá ngoại**; suy chiều nạp/rút từ vị trí ví là **diễn giải lại lịch sử**; và `_collectPendingOps` dựng payload **thô** — phép quy đổi `chi → Transaction` chạy ở bước POST, đọc dừng ở đó là kết luận nhầm |

> ⚠️ **Tài liệu là ảnh chụp, không phải nguồn sự thật.** Luôn đối chiếu với mã nguồn thật trước khi kết luận. Phiên 2026-09-02 có nhiều kết luận sai vì tin vào tài liệu/trí nhớ thay vì mở file ra đọc.

---

## Quy tắc chí mạng

1. **Chỉ sửa `src/Client-app`.** Không đụng `src/Backend` trừ khi được cho phép rõ ràng trong chính yêu cầu đó. Cần backend làm gì thì **viết tài liệu** vào `docs/superpowers/backend/`.
   - `docs/` gốc **không** bị `.gitignore` chặn, nhưng một số thư mục con thì có (`docs/category/`, `docs/bill/`, `docs/deploy_Cloud/`, `docs/superpowers/plans/`…). Tạo tài liệu ở chỗ mới thì kiểm trước bằng `git check-ignore -v <path>`, nếu không nó biến mất âm thầm.

2. **`idaccount` CHỈ đến từ phiên đăng nhập.** Không bao giờ suy ra từ dữ liệu trong SQLite, không bao giờ mặc định về `1` — đó là tài khoản **admin thật**, không phải giá trị "chưa biết".

3. **Pull dùng `insertAllOnConflictUpdate`, KHÔNG dùng `insertOrReplace`.** `insertOrReplace` thay **cả hàng**, mọi cột không gán bị đưa về mặc định — từng xoá sạch cấu trúc nhóm danh mục sau mỗi lần pull.

4. **Tên trường sai thì im lặng, không báo lỗi.** Payload đi qua ba nơi định nghĩa độc lập (client dựng tay → `SyncPayloadNormalizer` → `mapEntityFields` phía backend). Thêm trường mới cho sync thì **phải** cập nhật `sync_payload_contract_test.dart` cùng lúc.
   - ⚠️ **`provider`, `bank_tran_id`, `status`, `images` KHÔNG nằm trong hợp đồng đồng bộ theo chiều nào cả** — payload đẩy có đúng 11 trường và nhánh kéo về cũng không đọc chúng. Cột tồn tại ở cả hai đầu nên nhìn qua rất dễ tưởng là có.
   - **Đừng thêm `provider`/`bank_tran_id` vào payload đẩy** cho tới khi backend đưa `Idaccount` vào `uq_transaction_external`. Ràng buộc đó là **toàn cục**, và hiện chỉ trơ vì client gửi lên toàn NULL. Lý do đầy đủ: mục 7 của `docs/superpowers/backend/2026-09-04-ocr-classify-review.md`. Lưu ý `docs/progress/Client-app.md` mục 6.4 **hướng dẫn làm đúng điều này** — làm theo mà backend chưa sửa là tự tạo vòng lặp đẩy vô hạn.

5. **Không xoá vật lý dữ liệu người dùng** — dùng soft delete (`delete_at` / `isDeleted`).
   - ⚠️ Điều này áp dụng cho **cả PostgreSQL**, kể cả với bản ghi thử của chính mình. Một hàng đã từng đồng bộ thì client vẫn giữ bản sao; xoá cứng ở server khiến client đẩy lên và nhận `Record not found` **ở mọi chu kỳ**, kẹt vòng lặp vô hạn và kéo chậm cả hàng đợi. Đã vấp ngày 2026-09-04. Muốn dọn thì đặt `delete_at`, hoặc xoá qua giao diện để cờ xoá đi đúng đường đồng bộ.
   - ⚠️ Backend **không nhất quán tên cột**, ít nhất ba kiểu: `category` dùng `Delete_at`, `transaction` dùng `Deleted_at`, và cột ngày của giao dịch là `DateTransaction` (không gạch dưới) chứ không phải `Date_transaction`. Đừng suy tên từ bảng này sang bảng kia — mở `schema.prisma` ra đọc. Truy vấn sai tên cột ở PostgreSQL thì báo lỗi ngay, nhưng viết sai trong payload đồng bộ thì **im lặng** (quy tắc 4).

6. **`.gitignore` dòng 77 có `test/`** → mọi file test tạo mới đều bị git bỏ qua **âm thầm**. Nhớ `git add -f`, nếu không công sức viết test sẽ biến mất khỏi repo.
   - ⚠️ **`git add src/Client-app/test` (cả thư mục) thất bại kể cả khi mọi file bên trong đã được theo dõi.** Git từ chối nguyên lệnh và không stage gì cả. Phải liệt kê từng đường dẫn kèm `-f`.
   - ⚠️ **Công cụ Grep tôn trọng `.gitignore` nên KHÔNG nhìn thấy thư mục `test/`.** Dò xem còn ai gọi một hàm sắp xoá thì phải dùng `grep` qua shell, nếu không sẽ thấy thiếu file và xoá nhầm.

7. **Tên danh mục là duy nhất trong phạm vi một tài khoản** — **không** tính `classify`, **không** tính nhóm cha, và tính **cả danh mục mặc định** (chúng dùng chung không gian tên với danh mục người dùng). Hàng đã xoá mềm không giữ chỗ. Hai tài khoản khác nhau thì được trùng tên.
   - Phép so tên có **một định nghĩa duy nhất**: `normalizeCategoryName()` ở `lib/core/category/category_name.dart` — NFC → chữ thường → trim → gom khoảng trắng. **Đừng tự viết lại biến thể khác**; trước đây mỗi nơi một kiểu và chúng đã lệch nhau.
   - ⚠️ **Cùng file đó còn `removeVietnameseTones()` — TUYỆT ĐỐI không dùng nó cho quy tắc trùng tên.** Bỏ dấu là phép so *mất thông tin*: "đá" với "da", "sắn" với "săn" thành một. Nó chỉ dành cho **gợi ý**, nơi đoán sai chỉ tốn một cú chạm để sửa. Siết quy tắc trùng tên bằng nó sẽ từ chối những cặp tên hợp lệ mà người dùng phân biệt được bằng mắt.
   - Thi hành ở `CategoryManagementRepositoryImpl._hasDuplicateName()`. **Đừng** thay nó bằng `getCategoryRows` — hàm đó lọc theo `classify` và khử trùng lặp theo tên, tức loại đi đúng những hàng cần đối chiếu.
   - Phép kiểm tra **chỉ chạy khi tên thật sự đổi**, để người dùng còn sửa được danh mục cũ do bản client trước tạo ra. Đây là chủ ý, không phải lỗ hổng.
   - **Nơi thi hành:** client và Admin-web đã làm; đường `/sync/push` **chưa kiểm gì cả**. CSDL thì **có hai unique index nhưng chúng thi hành một quy tắc KHÁC** — lệch theo cả hai chiều, đừng đọc thành "CSDL chưa có ràng buộc gì". Trạng thái chi tiết ở mục 14 `docs/PROJECT_CONTEXT.md`.
   - ⚠️ Vế "**chặt hơn**" của CSDL (hàng đã xoá mềm vẫn giữ chỗ tên) có một đường kích hoạt **tự lặp ở mỗi lần mở app** — xem **G16** trong `docs/CLIENT_APP_KNOWN_GAPS.md` trước khi đụng vào `PersonalDefaultCategories` hay `getNamesInUse`.

8. **Bảng `AppNotifications` là CỤC BỘ — đừng kéo nó vào đường đồng bộ.** Nó cố ý không có `syncStatus`/`syncError`/`updatedAt`/`isDeleted`; việc vắng mặt những cột đó chính là tài liệu sống. Thêm vào `SyncEntityType` là phải chạm bảy bảng ánh xạ song song phía backend mà **không được gì** — thông báo suy lại được từ ngân sách/hoá đơn/mục tiêu trên từng máy.
   - Tên bảng có tiền tố `App` vì Drift sinh data class **số ít** và `Notification` là lớp có thật trong `package:flutter/widgets.dart`. Cùng loại va chạm đã gặp với `Category` — xem dòng đầu `sync_engine.dart`.
   - ⚠️ Khi làm phần thông báo cấp hệ điều hành: `NotificationScanner.stop()` **phải** gọi `cancelAll()`. Lịch nằm trong AlarmManager/UNUserNotificationCenter chứ không trong SQLite, nên `purgeDataForOtherAccounts` không cứu được — nhắc hoá đơn của người đăng nhập trước sẽ nổ trên màn hình khoá của người sau.

---

## Lệnh hay dùng

```bash
# Test (chạy từ src/Client-app) — hiện 804/804 pass, ~25 giây
flutter test
flutter analyze          # mức nền: 25 issue, KHÔNG có error

# Sau khi sửa Drift tables/DAOs
dart run build_runner build --delete-conflicting-outputs

# Chạy app
cd src/Backend && npm run dev                          # localhost:3000
cd src/Client-app && flutter run -d chrome --web-port 9090
```

**Trước khi báo là xong:** chạy `flutter test` và `flutter analyze`, đối chiếu với mức nền ở trên. Có lỗi mới phát sinh thì nói thẳng, đừng bỏ qua.

---

## Ghi chú vận hành

Bốn thứ dưới đây **đã từng gây thiệt hại thật**. Chúng vốn chỉ nằm trong file
bàn giao tạm giữa các phiên nên chết đi sống lại nhiều lần — nay ghi ở đây.

- **Bash tool ở đây là Git Bash, không phải PowerShell.** Commit message nhiều
  dòng thì dùng `git commit -F -` với heredoc `<<'EOF'`. Here-string
  `@'...'@` của PowerShell **làm lọt ký tự `@` vào message mà không báo lỗi** —
  đã phải `reset --soft HEAD~3` và commit lại cả ba lần.

- **Ghi file dài thì dùng công cụ Write, đừng qua `cat > file <<'EOF'`.** Nội
  dung nhiều backtick hoặc dấu nháy làm shell hiểu sai và chết với
  `unexpected EOF`, dù heredoc đã được trích dẫn.

- **Truy vấn PostgreSQL: máy này không có `psql`,** nhưng chạy được qua Prisma.
  Phải chạy **từ `src/Backend`** thì Node mới phân giải được `@prisma/client` —
  đặt script ở `/tmp` sẽ báo `MODULE_NOT_FOUND`:
  ```bash
  cd src/Backend && node -e "const {PrismaClient}=require('@prisma/client');
  const p=new PrismaClient();(async()=>{console.log(await p.\$queryRawUnsafe('SELECT 1'));
  await p.\$disconnect();})();"
  ```
  ⚠️ Chỉ dùng truy vấn **đọc**. Xoá cứng ở PostgreSQL vi phạm quy tắc 5.

- **Repo đặt `core.autocrlf=true` và không có `.gitattributes`.** Sửa file bằng
  script Python (ghi ra LF) sẽ khiến git cảnh báo `LF will be replaced by CRLF`.
  Vô hại, nhưng nhớ kiểm `git diff --stat` để chắc không bị nhiễu toàn file.

---

## Ghi chú về kiểm thử

Bộ test là lưới an toàn chính của dự án này — nhiều lỗi trong quá khứ hỏng **âm thầm** (không exception, không log). Khi sửa lỗi, viết test tái hiện **trước**, và ghi rõ trong `reason:` của assertion là nó canh chừng điều gì.

Vùng chưa có test nào: các feature `analytics`, `home`, `profile`, `ai_chat`. (`notification` có test từ 2026-09-04.) (`auth_interceptor.dart` có test từ 2026-09-03; `budget` có test từ 2026-09-03.)

### ⚠️ Ba loại lỗi mà `flutter test` KHÔNG bắt được

Phát hiện ngày 2026-09-04 khi chạy app trên máy ảo Android. Cả ba đều để bộ test xanh, nên **đụng vào giao diện hoặc điều hướng thì phải chạy trên máy ảo trước khi báo xong** — `flutter test` và `flutter build web` không thay thế được.

1. **Tràn bố cục.** Bộ test và skill `chay-app` chạy Chrome ở **1280px**, còn điện thoại thật là **411dp** — rộng gấp ba. Tìm được ba chỗ tràn (21px, 3,9px, 0,315px) đã nằm sẵn trong mã từ lâu. Muốn test được thì phải **trích widget ra** rồi dựng trong `SizedBox` hẹp có chủ ý, và bắt bằng `tester.takeException()`: Flutter báo lỗi tràn qua `FlutterError.reportError` chứ **không ném ra chỗ gọi**, nên test chỉ `pumpWidget` + `expect(find...)` sẽ xanh ngay cả khi màn hình đầy sọc cảnh báo.

2. **Điều hướng qua `StatefulShellRoute`.** `push` một route nằm trong shell từ một trang ngoài shell làm app **chết màn đỏ** (`!keyReservation.contains(key)`). Chỉ nổ khi có cây route thật. Xem bẫy 7.8 `docs/NOTIFICATION_FEATURE.md`.

3. **Thứ tự thực tế giữa hai luồng bất đồng bộ.** Hai stream có thể đều đúng khi test riêng, nhưng trên máy thật cái này ghi đè cái kia. Ví dụ đã gặp: `SyncEngine` đẩy xong sau 0,4 giây còn bộ theo dõi kết nối báo ở giây thứ 3, nên dải "đã đồng bộ" bị dải "đã kết nối lại" nuốt mất.

**Chạy máy ảo:** `flutter build apk --debug`, rồi `adb install -r build/app/outputs/flutter-apk/app-debug.apk` và `adb shell am start -n com.flowmoney.flowmoney/.MainActivity`. ⚠️ `adb` **không có trong PATH** — dùng `%LOCALAPPDATA%/Android/Sdk/platform-tools/adb.exe`.

**Mẹo dò tràn hàng loạt:** sọc cảnh báo của Flutter là **vàng thuần** và không màn nào của app dùng màu ấy, nên đếm pixel vàng trong ảnh `adb exec-out screencap` rẻ hơn hẳn việc mở từng ảnh ra nhìn. Cẩn thận dương tính giả với màn hình launcher của Android.
