# Tự chuyển tiền chạy nền — tự trả hoá đơn và trích mục tiêu khi app đóng

> Ngày 2026-10-10 · nhánh `TranQuangDat` · người dùng duyệt từng phần trong chat (brainstorm, AskUserQuestion).
> **Mở lại G22** (`docs/CLIENT_APP_KNOWN_GAPS.md`) — quyết định *"cố ý không làm WorkManager"* ngày 2026-09-05 là của
> chính người dùng; ngày 2026-10-10 họ chọn làm, sau khi được nêu rõ người dùng thấy khác ở đâu.

## 1. Vì sao, và người dùng thấy gì khác

Hôm nay hai bộ tự chuyển tiền — `BillAutoPayRunner` và `GoalAutoDepositRunner` — chỉ chạy trong
`NotificationScanner.scan()`, tức khi app mở. Cả hai **đã** ghi giao dịch theo mốc kỳ (`occurredAt: ky`,
`occurredAt = dueDate`), nên **sổ, số dư và thống kê đã đúng ngày** dù 21 giờ mới mở app. Chạy nền chỉ đổi hai thứ —
và người dùng chọn lấy **cả hai**:

1. **Thông báo đúng lúc:** *"Đã trích…"*, *"Netflix đã được tự trả"*, *"Ví không đủ…"* tới gần giờ hẹn thay vì lời nhắc
   *"Mở app để tiền được chuyển"*.
2. **Máy khác và server thấy ngay**, vì lượt nền **đồng bộ** lên server.

Phạm vi: **cả hai** bộ chạy (người dùng chọn), bật **cùng lúc** từ bản này (mục 5 giải bài toán hai máy mà không cần
backend).

## 2. Các quyết định đã chốt

| # | Quyết định | Chọn | Loại |
|---|---|---|---|
| 1 | Mục đích | Thông báo đúng lúc **+ đồng bộ nền** | chỉ trên máy |
| 2 | Phạm vi | Tự trả hoá đơn **và** trích mục tiêu | chỉ trích mục tiêu |
| 3 | Cơ chế đánh thức | **WorkManager Kotlin** (`work-runtime-ktx 2.11.0` sẵn có, khuôn `NhacGhiWorker`) | gói pub `workmanager` (phụ thuộc mới, chưa kiểm với Flutter 3.47.5) · báo thức chính xác (quyền *Báo thức & lời nhắc*, dự án cố ý dùng `inexactAllowWhileIdle`) |
| 4 | Giờ chạy nền của hoá đơn | Ngày đến hạn lúc **giờ nhắc chung** (`prefs.gioNhac:phutNhac`) | 00:00 (rơi vào giờ im lặng) |
| 5 | Hai máy cùng trích một kỳ mục tiêu | **Id tất định theo (mục tiêu, kỳ)** — không cần backend | đơn CAN-LAM + máy thua tự gỡ (chọn trước, đổi sau khi đọc `depositToGoal`) · cả hai |
| 6 | Trùng tên mục tiêu chỉ chặn ở client | **Giữ nguyên** (ghi ở `GOAL_FEATURE.md` mục 7) | — |
| 7 | Lời nhắc *"Đến kỳ trích tự động"* | **Bỏ** — lượt nền bắn thẳng kết quả cùng khoá | giữ, đổi câu |

## 3. Luồng và thành phần

### 3.1 Hẹn giờ (Dart)

Hàm thuần mới **`mocNenKeTiep(...)`** (đặt ở `core/notification/`, cạnh `ReminderScheduler`) trả mốc nền gần nhất hoặc
`null`:

- Hoá đơn: mọi hàng mà `denLuotTuTra` **sẽ** đúng — bật tự trả, `conPhaiTra`, có ví và danh mục, chưa xoá. Mốc =
  `DateTime(due.y, due.m, due.d, gioNhac, phutNhac)`; mốc đã qua → **ngay** (`now`).
- Mục tiêu: bật trích, chưa hoàn thành, còn thiếu > 0 → `kyKeTiep(mocNeo:, lanChayGanNhat:, chuKy:, now:)` (hàm sẵn có
  mà `ReminderScheduler` đang dùng — **không** chép lại phép tính kỳ).
- Không còn gì → `null`.

`ReminderScheduler.resync` (chạy cuối mỗi lượt quét) tính mốc. **Chỉ engine của app** gửi nó qua kênh Kotlin sẵn có
(`MainActivity`) — lệnh **`henNen(mocMs)`** — và **chỉ khi mốc đổi** so với mốc đã hẹn lần trước (nhớ trong bộ nhớ;
`resync` chạy sau mọi chu kỳ đồng bộ 15 phút). Lượt **nền** không gọi `henNen`: nó trả mốc kế trong payload của
`nenXong`, và worker hẹn lượt mới **sau khi `doWork` trả về** — gọi `REPLACE` lên chính công việc đang chạy là
WorkManager huỷ nó giữa chừng (luồng `doWork` bị ngắt, engine bị huỷ khi Dart còn đang đồng bộ):

- WorkManager **một-lần**, tên duy nhất `tu_chuyen_tien_mot_lan`, `ExistingWorkPolicy.REPLACE`,
  `setInitialDelay(moc − now)` (âm → 0).
- WorkManager **định kỳ 6 giờ**, tên `tu_chuyen_tien_dinh_ky`, `ExistingPeriodicWorkPolicy.KEEP` — dự phòng khi lượt
  một-lần bị Android lùi hay bỏ.
- `mocMs == null` (không hoá đơn / mục tiêu nào bật tự động) → huỷ cả hai. Còn bất cứ thứ gì bật thì mốc luôn khác
  `null` (kỳ kế nằm ở tương lai), nên không có trạng thái *"giữ định kỳ mà bỏ một-lần"*.

`NotificationScanner.stop()` (đăng xuất, phiên chết) gọi **`huyNen()`** — huỷ cả hai, cùng khuôn `huyNhac` của nhắc ghi.
Không ai đăng nhập thì không ai đã uỷ quyền chuyển tiền.

WorkManager tự sống qua khởi động lại máy. ⚠️ Realme/ColorOS force-stop khi vuốt Recents **huỷ** cả WorkManager — giới
hạn của hãng (CLAUDE.md, mục "Chạy trên MÁY THẬT"), ghi vào tài liệu, không phải lỗi.

### 3.2 Worker (Kotlin)

`TuChuyenTienWorker : Worker` — hai nhánh:

- **App đang mở** — `MainActivity` giữ một tham chiếu tĩnh tới engine của nó (gán ở `configureFlutterEngine`, xoá ở
  `cleanUpFlutterEngine`). Còn engine → gửi **`quetNgay`** qua kênh tới engine ấy và **chờ `quetXong`** (cùng
  `CountDownLatch` + trần 3 phút như nhánh dưới) rồi mới trả `Result.success()` — trả ngay là WorkManager thả tiến
  trình và Android có thể đóng băng app đang ở nền **giữa lượt quét**. Không khởi engine thứ hai, nên SQLite chỉ có
  **một** kết nối và stream Drift của màn hình tự cập nhật.
- **App đóng** — dựng `FlutterEngine` headless, `GeneratedPluginRegistrant.registerWith(engine)` (secure storage, local
  notifications, connectivity, path_provider…), chạy entrypoint Dart **`chayNenTuChuyenTien`**, chờ Dart báo
  **`nenXong(mocKeTiepMs)`** qua kênh riêng của engine ấy (`CountDownLatch`, trần **3 phút**), `engine.destroy()`,
  hẹn lượt một-lần theo `mocKeTiepMs` (mục 3.1), trả `Result.success()`. Hết trần → vẫn `success` (lượt định kỳ sẽ thử
  lại; `retry` dễ thành vòng lặp tốn pin).

### 3.3 Lượt nền (Dart)

`@pragma('vm:entry-point') Future<void> chayNenTuChuyenTien()` ở tệp mới `lib/core/nen/chay_nen.dart`:

1. `WidgetsFlutterBinding.ensureInitialized()`, `initializeDateFormatting`, `_khoiTaoMuiGio()` (tách khỏi `main.dart`
   thành hàm dùng chung).
2. `setupDependencies(cheDoNen: true)` — chế độ nền: `AuthInterceptor` không làm mới token (mục 4.2), không dựng
   `ConnectionMonitor`/socket.
3. **`noiBoNgheKetQuaDay()`** — hàm mới tách từ `main.dart`, nối `BillPaymentConflictResolver` và
   `ViTrungTenResolver` vào `SyncEngine.pushResultStream`. `main.dart` gọi **cùng** hàm này. Không nối ở nền thì
   `BILL_ALREADY_PAID` về mà không ai gỡ khoản trả — khoản chi lỗi vĩnh viễn.
4. Đọc phiên từ bộ nhớ đệm (đường G86 — `AuthLocalDataSource`). Không có phiên → báo `nenXong`, dừng. **Quy tắc 2:**
   `idaccount` chỉ từ phiên, không bao giờ suy từ SQLite. Gắn luôn `sl<NhatKyThongBao>().datNguonPhien(() => id)` —
   `main.dart` gắn nó từ `AuthBloc`; ở nền không có bloc, thiếu bước này thì nhật ký B5a ghi lịch/bắn với tài khoản
   rỗng. *(Đã kiểm: `OsNotifierNative.show` tự gọi `init()`, nên engine headless bắn được thông báo mà không cần bước
   khởi tạo riêng.)*
5. **`await sl<GoiRepository>().datTaiKhoan(idaccount, loaiPhien: …)`** — bắt buộc, TRƯỚC khi quét. Hai bộ chạy xét
   quyền qua `coQuyenNen` (`injection_container.dart`), mà hàm ấy **trả `true` khi `GoiRepository.idaccount == null`**
   (*"không phiên → mở"*, dành cho cửa nhập). Ở nền không ai gọi `noiPhien`, nên thiếu bước này thì tài khoản **Basic**
   được tự trả / tự trích ở nền — lọt cửa quyền, im lặng. Không gọi `lamMoi()` (mạng); bảng gói đã lưu là đủ.
6. Lấy **khoá thuê** (mục 3.4). Không lấy được → bỏ hai bộ chạy (vẫn đồng bộ).
7. Đồng bộ (mục 4.1) → `NotificationScanner.scan(idaccount)` → đẩy.
8. Nhả khoá, báo `nenXong(mocNenKeTiep(...))`. Mọi bước bọc `try/finally`: Dart ném lỗi vẫn phải báo xong, nếu không
   worker chờ hết 3 phút.

Lệnh **`quetNgay`** ở engine của app: gọi `sl<NotificationScanner>().scan(id)` với phiên hiện tại rồi
`sl<SyncEngine>().syncNow()`, cuối cùng báo `quetXong`; không có phiên thì báo `quetXong` ngay.

**Đồng bộ ở nền không đi qua `start()`/`syncNow()`.** `syncNow()` dựa vào `_currentIdaccount` do `start()` đặt, mà
`start()` còn dựng hẹn giờ 15 phút và bộ nghe mạng — thứ lượt nền không được để lại; và test quét thứ tư
(`sync_engine_start_owner_test`) chỉ cho `auth_bloc.dart` gọi `.start(idaccount:)`. Nên `SyncEngine` thêm
**`syncMotLuot(int idaccount)`**: đọc mốc kéo về đã lưu của tài khoản (như `start()`), chạy `_runSync` một lần, không
hẹn giờ, không nghe mạng, không đụng `_currentIdaccount`. Test quét thứ tư giữ nguyên.

### 3.4 Chặn chạy chồng

Khe còn lại: người dùng mở app **đúng lúc** engine headless đang chạy → hai kết nối SQLite cùng tiến trình. `_dangQuet`
chỉ chặn trong một isolate; khoá tệp (`RandomAccessFile.lock`, fcntl) **không** chặn được hai isolate cùng tiến trình.

**Khoá thuê trong SQLite**: bảng cục bộ mới `KhoaTuChuyenTiens` (schema **v30**, một hàng: `ten` PK, `chuSoHuu`
nullable, `hetHan`). Hàng được gieo sẵn lúc di trú. Lấy khoá là **một câu** `UPDATE … SET chuSoHuu = ?, hetHan = now + 2
phút WHERE ten = ? AND (chuSoHuu IS NULL OR hetHan < now)` rồi đọc **số hàng bị ảnh hưởng** (1 = lấy được) — một câu
ghi là nguyên tử giữa các kết nối; **không** viết dạng đọc-rồi-ghi (trong WAL hai giao tác trì hoãn cùng đọc "chưa có
khoá"). Nhả: `UPDATE … SET chuSoHuu = NULL WHERE chuSoHuu = <id lượt>`.

**`PRAGMA busy_timeout = 5000`** ở `core/database/connection/native.dart` (`NativeDatabase.createInBackground(…,
setup:)`). Đây là lần đầu dự án **cố ý** cho hai kết nối cùng sống; mặc định 0 là mọi lần ghi trùng nhịp — kể cả UI
ghi thông báo đúng lúc headless commit — ném `SQLITE_BUSY` **ngay**. **Cả** `scan()` của app
lẫn lượt nền đi qua khoá này cho đoạn chạy hai bộ chuyển tiền; lượt không lấy được khoá **bỏ qua hai bộ chạy**, vẫn
làm phần thông báo. Bảng cục bộ: **không** vào `SyncEntityType` (test quét 15).

Kèm sửa một lỗi có sẵn: `autoDepositLastRun` được ghi **trong cùng giao tác** với `depositToGoal` (nay ghi rời sau cả
vòng — app sập giữa vòng thì kỳ đã trích bị trích lại).

## 4. Đồng bộ trong lượt nền

### 4.1 Thứ tự

`syncMotLuot(id)` (đẩy + kéo về) → `scan()` → `syncMotLuot(id)` (đẩy những gì vừa ghi; lượt kéo về đi kèm là rẻ).

- Lượt **trước** kéo về khoản của máy kia → bộ chạy thấy kỳ đã trả/đã trích, tránh phần lớn cuộc đua; `gopKyTrung`
  (G87) chỉ chạy khi `soLanKeoVeXong` vừa tăng, nên cũng được dữ liệu mới.
- Lượt **sau** đưa khoản vừa ghi lên server.
- Mất mạng → bỏ hai lượt đồng bộ, **vẫn** chạy `scan()`. Hàng đợi chờ app hoặc lượt nền kế.

### 4.2 Token ở chế độ nền

`AuthInterceptor` thêm cờ `cheDoNen`:

- **Không** gọi `/auth/refresh` khi gặp 401 — trả lỗi lên, `SyncEngine` coi là lượt hỏng, hàng đợi giữ nguyên. App và
  nền cùng làm mới **một** refresh token là backend đếm *dùng lại token* (heuristic AIOps, đơn 33) → cách ly hoặc
  cưỡng chế đăng xuất.
- **Không** xoá token, **không** phát `sessionExpiredStream`. Một lượt nền gặp sự cố không được đăng xuất người dùng
  trong im lặng.

### 4.3 Không làm ở nền

Socket thời gian thực · nhập biến động số dư / biên lai / phiên ngân hàng (vẫn chờ app — `NotificationScanner.start`) ·
mô hình AI · `ConnectionMonitor`.

## 5. Khoản trích có id tất định

Hàm thuần **`idKhoanTrichTuDong(goalId, ky)`** = UUID **v5** (namespace riêng) của
`'$goalId|${ky.toUtc().millisecondsSinceEpoch}'` — băm **mốc tuyệt đối**, không băm chuỗi giờ địa phương (hai máy khác
múi giờ ra hai id). Cùng khuôn `idKhoanMoSo` (`wallet/domain/so_du_mo_so.dart`). `depositToGoal` nhận tham số
`transactionId` (nạp tay vẫn v4). Trong **cùng** giao tác, trước khi ghi:

- Đã có hàng mang id ấy — **kể cả xoá mềm** → kỳ coi như đã trích: không trừ tiền, chỉ đẩy `autoDepositLastRun`. Hàng
  xoá mềm là người dùng đã chủ động xoá khoản ấy; trích lại là đi ngược ý họ.
- Kỳ ấy **không sinh `GoalAutoDepositEvent`** (`depositToGoal` báo lại *"đã có"* cho bộ trích). Phát sự kiện thường là
  máy B báo *"Đã trích 500 nghìn từ ví X"* cho việc máy A làm.

Hệ quả khi hai máy cùng trích kỳ 08:00: **cùng id** → server nhận hàng thứ hai là sửa cùng hàng (LWW), sổ chỉ **một**
khoản; số dư ví suy từ sổ (G37) nên chỉ trừ một lần; tiến độ mục tiêu hai máy cùng là *cũ + số tiền kỳ*.

**Giới hạn ghi vào tài liệu:** hai máy có số liệu khác nhau trước kỳ (khoản nạp tay chưa đồng bộ) rồi cùng rơi vào ca
*trích phần còn thiếu* với hai số tiền khác → server giữ một số tiền theo LWW, tiến độ một máy lệch tới lượt kéo về sau.
Khoản trích có từ trước (id v4) không đổi gì; id tất định áp cho kỳ trích từ bản này.

Hoá đơn **không** cần id tất định: đã có `chanTraHaiLan` (server) + `BillPaymentConflictResolver` (client); ca kỳ trùng
là đơn 41.

## 6. Chữ người dùng thấy

| Chỗ | Hiện nay | Sau |
|---|---|---|
| Lời nhắc kỳ trích (`ReminderScheduler`) | *"Đến kỳ trích tự động — … Mở app để tiền được chuyển."* | **Bỏ.** Lượt nền bắn *"Đã trích…"* / *"Ví không đủ…"* bằng **cùng khoá** `goalAuto:…` |
| Nhắc hoá đơn tự trả, còn N ngày | *"Netflix còn 3 ngày tới hạn. Mở app vào ngày đó để hoá đơn được tự trả."* | *"Netflix còn 3 ngày tới hạn, sẽ được tự trả vào ngày đó."* |
| Nhắc hoá đơn tự trả, hôm nay | *"Netflix đến hạn hôm nay. Mở app để hoá đơn được tự trả."* | *"Netflix đến hạn hôm nay, sẽ được tự trả."* |
| `kBillAutoPayHint` (form hoá đơn) | *"Khi bạn mở app vào ngày đến hạn, hoá đơn được trả…"* | *"Vào ngày đến hạn, hoá đơn được trả…"* (phần còn lại giữ) |
| Ô giờ trích (form mục tiêu) | *"Không trích trước giờ này. App chưa mở thì trích ở lần mở kế tiếp"* | *"Tiền được chuyển gần giờ này; máy đang ngủ sâu thì có thể muộn hơn"* |

**Chỉ Android.** Dự án có thư mục `ios/` nhưng phần chạy nền là Kotlin + WorkManager. Trên iOS mọi chữ ở bảng trên
**giữ như cũ** và lời nhắc kỳ trích **vẫn đặt** — gác bằng `Platform.isAndroid` ở `ReminderScheduler` và ở hai hằng câu
chữ; iOS không có gì thay thế, bỏ lời nhắc ở đó là mất hẳn thông tin.

Không có màn mới → không cần Stitch. Câu ở ô giờ trích có thể dài hơn câu cũ — kiểm 360 dp (font thật).

## 7. Kiểm thử

TDD, viết trước:

- `mocNenKeTiep`: hoá đơn → giờ nhắc chung ngày đến hạn · đến hạn đã qua → `now` · mục tiêu dùng `kyKeTiep` · lấy
  **sớm nhất** · không gì → `null` · hoá đơn ngày 31 tháng ngắn (anchorDay) · tắt tự trả / đã trả / thiếu ví → bỏ.
- `idKhoanTrichTuDong`: cùng (mục tiêu, kỳ) cùng id · khác kỳ khác id · cùng mốc tuyệt đối ở hai múi giờ cùng id ·
  không trùng `idKhoanMoSo`.
- Bộ trích: id đã có → không trừ tiền, đẩy mốc, **không sinh sự kiện** · id đã xoá mềm → như trên · `depositToGoal` ném
  giữa vòng → kỳ trước đó đã ghi mốc (cùng giao tác).
- Khoá thuê: lượt hai bị từ chối khi còn hạn · lấy được khi đã hết hạn · nhả đúng chủ · **hai kết nối thật** tới cùng
  tệp SQLite tạm (không chỉ hai lời gọi một kết nối).
- `SyncEngine.syncMotLuot`: chạy một lượt, không đặt `_currentIdaccount`, không hẹn giờ.
- `henNen` chỉ gọi khi mốc đổi · lượt nền không gọi `henNen`.
- iOS (`Platform.isAndroid == false` qua khe tiêm): lời nhắc kỳ trích vẫn đặt, câu cũ giữ nguyên.
- `AuthInterceptor` `cheDoNen`: 401 → không gọi `/auth/refresh`, token còn nguyên, không phát phiên chết.
- `chayNenTuChuyenTien`: không phiên → không gọi `scan` · có phiên → thứ tự đồng bộ → quét → đồng bộ · lỗi giữa chừng
  vẫn báo xong · ⭐ **tài khoản Basic (gói đã lưu) → hai bộ chạy không chạy** — ca này đỏ nếu quên `datTaiKhoan`.
- Test quét: `noiBoNgheKetQuaDay` được gọi ở **cả** `main.dart` và `chay_nen.dart` (khuôn
  `bill_conflict_resolver_wiring_test`) · đọc `TuChuyenTienWorker.kt`, `MainActivity.kt`: tên kênh, tên lệnh, tên
  entrypoint khớp hằng Dart (khuôn `phien_ngan_hang_noi_day_test`).
- `ReminderScheduler`: không còn lịch `goalAuto:` · câu nhắc tự trả mới · gọi `henNen` với mốc đúng.

## 8. Nghiệm thu máy thật (OnePlus)

`flutter test` không thấy Kotlin, engine headless hay WorkManager.

1. Hoá đơn tự trả hạn hôm nay, giờ nhắc = vài phút sau. **Vuốt app khỏi Recents.** Thông báo *"đã tự trả"* hiện; mở app
   — số dư đúng; PostgreSQL có khoản chi (đã đẩy ở nền).
2. Như trên với một kỳ trích mục tiêu.
3. App đang mở khi tới giờ → log `quetNgay`, không có engine thứ hai.
4. Hai máy (OnePlus + máy ảo) cùng tài khoản, cùng kỳ trích → PostgreSQL **một** khoản (id v5).
5. Ép chạy ngay: `adb shell cmd jobscheduler run -f com.flowmoney.flowmoney <jobId>` (đọc jobId bằng
   `dumpsys jobscheduler`).
6. Bản **release** một lượt (R8 — khuôn `proguard-rules.pro`; entrypoint phải có `@pragma('vm:entry-point')`).

## 9. Tài liệu phải sửa

G22 (`CLIENT_APP_KNOWN_GAPS.md`, cả bảng tóm tắt) → *mở lại và làm 2026-10-10* · `GOAL_FEATURE.md` 3.12, 3.13, 4.x ·
`bill/BILL_DOCUMENTATION.md` 6.5 · docstring `GoalAutoDepositRunner`, `BillAutoPayRunner`, `kBillAutoPayHint`,
chú thích `ReminderScheduler` · `NOTIFICATION_FEATURE.md` (lời nhắc kỳ trích bỏ) · `CLAUDE.md` hàng *"Đụng vào trích
tiền tự động"* · mục 14 `PROJECT_CONTEXT.md` · số schema **v30** ở mọi nơi ghi *"schema hiện tại"*.
