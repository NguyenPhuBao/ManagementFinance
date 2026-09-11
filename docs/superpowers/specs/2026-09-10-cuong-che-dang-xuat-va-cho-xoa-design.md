# Cưỡng chế đăng xuất và tài khoản chờ xoá — thiết kế

> **Trạng thái: G33 — Phần 2–3 (trừ §5.1) ĐÃ XONG (2026-09-11). Mục 6 (việc cho backend):
> tài liệu xin ĐÃ VIẾT (CAN-LAM 19), backend CHƯA LÀM — `getProfile` chưa trả `countdown`.
> Phần 1 (mục 3, kể cả §3.8) và §5.1 CHƯA LÀM.** Mọi quyết định sản phẩm ở mục 2
> đã chốt qua hỏi–đáp ngày 2026-09-10; Phần 1 (mục 3) được duyệt riêng trong phiên
> ấy. Phần 2–4 viết thẳng vào đây theo yêu cầu "làm đi" của người dùng. Ngày
> 2026-09-11 người dùng duyệt nốt: §3.3 và §3.6b (hai điểm soát lại theo `main`),
> Phần 2–4 cùng ba màn Stitch ở mục 5 (dựng theo chữ và màu ghi ở đây), đưa **hai
> lỗi làm mới token có sẵn** từ mục 8 vào phạm vi (§3.8), và chọn tài khoản thử
> (§7.3).
>
> **Soát lại 2026-09-11 theo `origin/main` @ `7675b35`** (lúc soát chưa gộp; ✅ gộp
> về nhánh này cùng ngày, `main` @ `cc65f4f` — CSDL dev áp `database/12` cùng ngày):
> sửa §1.3, §2 (Q5), §3.1, §3.3, §3.4, §3.5, §6, §7.2, §7.3, §8, §9; thêm **§3.6b —
> đề xuất mới** (✅ duyệt 2026-09-11). Việc cho backend phát sinh từ lượt soát ấy nằm ở
> `CAN-LAM/FIX_BACKEND_3_REGRESSIONS.md` (mục 17). Số dòng phía backend trong spec
> là của nhánh `TranQuangDat` @ `d352809`, trừ chỗ ghi rõ `main` — sau khi gộp, số
> dòng ghi `main` mới là số dòng đúng trên nhánh.
>
> Yêu cầu gốc: `docs/progress/Client-app.md` mục 10–12. Hạng mục 5 của kế hoạch
> cá nhân `docs/superpowers/plans/2026-09-10-ra-soat-csdl-moi.md` (gitignore).

---

## 1. Vì sao làm — một lỗi đang chạy, không chỉ tính năng còn thiếu

### 1.1. Client đang hứa một điều backend không làm — G33

Có **hai** đặc tả nói ngược nhau về giai đoạn chờ xoá:

| | Bản cũ (`docs/superpowers/auth/2026-08-17-auth-account-design.md`) | Bản mới (`docs/progress/Client-app.md` mục 12) |
|---|---|---|
| Đăng nhập lại trong 30 ngày | **tự khôi phục**, trả `pendingDeleteCancelled: true` | vẫn `PendingDelete`, dùng app bình thường |
| Gửi yêu cầu xoá | thu hồi mọi token | không thu hồi |
| Huỷ xoá | đăng nhập lại | bấm nút → `POST /auth/cancel-delete` |

**Backend đang chạy theo bản mới** (đọc mã 2026-09-10):
`auth.service.js:309` khai `let pendingDeleteCancelled = false` và **không chỗ
nào gán lại**; nhánh `PendingDelete` của `login` (`:311-322`) chỉ ghi log rồi cấp
token; `deleteAccount` (`:494-511`) không gọi `revokeAllTokens`.

**Client đang chạy theo bản cũ**:
- `delete_account_page.dart:80-119` — gửi yêu cầu xong thì `LogoutRequested`
  và nói *"hãy đăng nhập lại trong vòng 30 ngày — hệ thống sẽ tự động khôi
  phục tài khoản cho bạn"*; dòng thời gian của trang ghi *"Ngay lập tức: bạn sẽ
  bị đăng xuất khỏi tất cả thiết bị"*.
- `auth_repository_impl.dart:137-140` — `deleteAccount` xoá sạch token.
- `login_page.dart:36-71` — hộp thoại "Tài khoản đã được khôi phục" chờ một cờ
  không bao giờ bật.

**Hậu quả:** người dùng tin lời hứa, đăng nhập lại, thấy app chạy bình thường.
Tài khoản vẫn `PendingDelete`; 30 ngày sau `scheduler.service.js:processFullSoftDelete`
ẩn danh hoá dữ liệu và xoá mềm tài khoản. Không một chữ nào báo trước.

### 1.2. Phần còn thiếu

- `realtime_event.dart` chỉ nhận ba sự kiện; `account.force_logout` rơi vào
  nhánh "sự kiện lạ" (`realtime_channel.dart:193-195`).
- `auth_interceptor.dart:53-85` gặp mọi 401 là đi làm mới token, không đọc `code`.
- `UserModel.fromJson` bỏ `status` và `countdown` mà `/auth/login` trả về
  (`auth.service.js:362-363`).
- Không có chỗ nào hiện số ngày còn lại, không có nút huỷ xoá ngoài trang Xoá
  tài khoản (và nút ấy hiện cả khi tài khoản đang `Active`).

### 1.3. Vì sao chưa kiểm được đầu-cuối trên CSDL dev

CSDL dev chưa áp `database/8`, `9` (`DA-XONG/DEV_DB_MIGRATIONS_7_11.md`), Prisma
Client cũ không biết `reason_inactive`/`countdown`. Nên hôm nay **mọi** đường
backend dẫn tới sự kiện này đều vỡ: `DELETE /auth/account`, `POST
/auth/cancel-delete`, admin khoá (`admin.service.js:134`), admin xoá
(`softDeleteUser`), và bộ đếm ngược hằng ngày. Không có `account.force_logout`
nào được phát ra; `middleware/auth.js:47-50` cho mọi request đi qua. Cách kiểm
chứng thay thế: mục 7.3.

✅ **Cập nhật tối 2026-09-10:** người dùng yêu cầu áp `database/7`–`11`; đã áp,
sinh lại Prisma Client và chạy lại backend (banner đầu
`DA-XONG/DEV_DB_MIGRATIONS_7_11.md`). Mọi đường kể trên nay **chạy được** trên
backend thật — trừ body 401 vẫn thiếu mã (CAN-LAM 13). Mục 7.3 đã sửa theo.

⚠️ **2026-09-11:** `origin/main` có thêm `7675b35` (gộp về nhánh này cùng ngày): body 401 nay mang
mã và nhánh cho qua khi lỗi lược đồ đã thành 503 — nhưng bắt tay socket và
`/auth/refresh` từ chối **mọi** tài khoản (CAN-LAM 17 mục A). Ảnh hưởng tới spec
nằm ở các đoạn gắn ngày 2026-09-11 bên dưới.

---

## 2. Quyết định đã chốt với người dùng (2026-09-10)

| # | Câu hỏi | Chốt | Lý do chính |
|---|---|---|---|
| Q1 | Đăng nhập lại khi đang chờ xoá | **Dùng tiếp 30 ngày + lời nhắc** — theo bản mới | Khớp backend đang chạy, không cần backend sửa. Loại "đăng nhập là khôi phục" (người chỉ vào xem lại dữ liệu sẽ vô tình huỷ yêu cầu) và "hỏi ngay khi đăng nhập" (ngược mục 12.3) |
| Q2 | Dữ liệu SQLite khi bị đẩy ra | **Bị khoá thì giữ, bị xoá thì dọn** | Admin có thể mở khoá, thay đổi chưa đồng bộ còn đẩy lên được. Tài khoản đã xoá thì server đã ẩn danh hoá (xoá `note`, `images`) mà máy vẫn giữ bản rõ. Loại mục 12.5 "đánh dấu ví Inactive, ngân hàng Disconnected": người dùng đã bị đăng xuất nên không ai thấy cờ ấy, `wallet.status` là cột cục bộ (G28), và client **không có** bảng ngân hàng cục bộ |
| Q3 | Hình thức báo lý do | **Hộp thoại phải bấm "Đã hiểu"** | Theo mục 11.2/11.3. Người dùng chọn thay cho thẻ cảnh báo trên form mà tôi đề xuất |
| Q4 | Chỗ đặt lời nhắc chờ xoá | **Thẻ trên Trang chủ, đóng được** (+ trạng thái cố định ở Cài đặt) | Hành động không hoàn tác nên lời nhắc phải tới được Trang chủ; đóng được vì người dùng đã gỡ khối thông báo khỏi Trang chủ ngày 2026-09-08 (`home_page.dart:53-55`) |
| Q5 | Kiến trúc | **Hướng A — một kiểu thông báo chung, một cửa vào `AuthBloc`** | Loại B (dùng lại `SessionInvalidated`: lý do mất giữa đường, và bước hỏi lại `/auth/profile` phụ thuộc vào việc middleware không cho qua — lúc chốt thì CSDL dev đang cho qua ở mọi request; nay đã áp mục 11 nhưng nhánh cho qua khi lỗi lược đồ vẫn còn trong mã, CAN-LAM 11 mục 4.3; trên `main` @ `7675b35` nhánh ấy đã thành 503 — lý do *mất giữa đường* vẫn đứng). Loại C (cubit riêng: hai bloc phải phối hợp thứ tự dừng — loại lỗi `flutter test` không bắt được) |

**Đối chiếu thị trường** (2026-09-10): Facebook đăng nhập lại trong 30 ngày thì
hiện nút *Cancel deletion*
([Facebook Help](https://www.facebook.com/help/224562897555674)); TikTok đăng
nhập lại là tự kích hoạt lại
([ForestVPN](https://forestvpn.com/en/blog/social-media/tiktok-account-deletion-30-day-grace-period-explained/)).
Money Lover không có tài liệu công khai. Các app lớn nhắc **đúng lúc đăng nhập**;
"dùng tiếp 30 ngày" thì không ai có — nên lời nhắc phải đủ mạnh (Q4).

---

## 3. Phần 1 — Cưỡng chế đăng xuất (đã duyệt riêng)

### 3.1. Một kiểu dữ liệu, hai hàm đọc

Tệp Dart **thuần** `lib/core/auth/buoc_dang_xuat.dart`:

```dart
enum LyDoBuocDangXuat { biKhoa, daXoa }
enum NguonBuocDangXuat { socket, http, lamMoi }   // §3.6b

class ThongBaoBuocDangXuat {
  final LyDoBuocDangXuat lyDo;
  final NguonBuocDangXuat nguon;
  final String loiNhan;   // câu server gửi; rỗng thì câu mặc định của client
  final int? idaccount;
}

ThongBaoBuocDangXuat? tuSuKienSocket(Object? payload);   // account.force_logout
ThongBaoBuocDangXuat? tuBody401(Object? body,            // body HTTP 401
    {required NguonBuocDangXuat nguon});                  // http | lamMoi (§3.3)
```

- `reason`/`code` bằng `ACCOUNT_DELETED` → `daXoa`. **Mọi giá trị khác**, kể cả
  giá trị lạ hoặc thiếu, → `biKhoa`. Đọc nhầm thành "bị khoá" chỉ giữ lại dữ
  liệu; đọc nhầm thành "đã xoá" là xoá mất dữ liệu.
- `idaccount` đọc được cả `int` lẫn chuỗi số.
- `nguon` do nơi gọi đặt: `tuSuKienSocket` luôn là `socket`; interceptor truyền
  `http` cho 401 của request thường và `lamMoi` cho 401 của `/auth/refresh` (§3.3).
  Chỉ §3.5 bước 3 đọc nó (§3.6b).
- `tuBody401` chỉ nhận `code` ở **cấp gốc** (hình dạng mục 4.1
  `DA-XONG/AUTH_401_BODY_CODE.md`). `code` nằm dưới `errors` thì **không** nhận:
  đó là hình dạng của lối tắt `ResponseHandler.error(...)` mà tài liệu ấy đã bác.
  Body không có `code` → `null` → interceptor đi đường làm mới token như cũ.
  ✅ 2026-09-11: hình dạng ấy có thật trên `main` @ `7675b35`
  (`core/response-handler.js`) — `{ success, message, code, idaccount,
  reason_inactive, errors: null, timestamp }` — cho cả 401 của `authenticate` lẫn
  401 của `/auth/refresh`.

### 3.2. Nguồn socket

`RealtimeChannel` có thêm `Stream<ThongBaoBuocDangXuat> buocDangXuat`, **tách
riêng** khỏi `events`:

- `events` giữ nguyên cam kết "không đọc payload" của `realtime_event.dart` —
  lý do cam kết ấy là `bank_transaction.incoming` phát từ **hai** chỗ với hai
  hình dạng. `account.force_logout` thì chỉ phát qua **một** hàm
  (`core/socket.js:170-191`, gọi từ `admin.service.js:140`, `:199` và
  `scheduler.service.js:116`), nên đọc payload ở đây là an toàn.
- `_khiCoSuKien` bắt tên `account.force_logout` **trước** `realtimeEventFromName`.
- Bỏ qua khi `idaccount` trong payload khác `_idaccount` của phiên đang chạy.
- Server phát xong thì `disconnectSockets(true)` — kênh sẽ hẹn nối lại; `AuthBloc`
  gọi `stop()` là huỷ hẹn ấy (đã có ở `realtime_channel.dart:121-122`).

### 3.3. Nguồn HTTP

Hai chỗ trong `AuthInterceptor` có thể nhận body 401 mang mã:

1. **401 của một request thường.** `tuBody401` khác `null` thì **không** gọi
   `/auth/refresh`.
2. **401 của chính `/auth/refresh`** (thêm 2026-09-11). Trên `main` @ `7675b35`,
   `/auth/refresh` kiểm trạng thái tài khoản và trả 401 cùng hình dạng body
   (`auth.controller.js:79-85`). Ca xảy ra thật: token truy cập hết hạn — 401
   *"Token expired"*, không mã — đúng lúc tài khoản đã bị khoá hoặc xoá, nên
   interceptor làm mới và nhận 401 **có** mã. `_tryRefreshToken` hiện nuốt mọi lỗi
   thành `null` (`auth_interceptor.dart:88-119`), nên phải đổi để trả được body lỗi
   về cho `onError`.

Cả hai chỗ làm cùng một việc: phát `Stream<ThongBaoBuocDangXuat> taiKhoanBiTuChoi`,
xoá token **không phát** `sessionExpiredStream`, rồi `handler.next(err)`.

⚠️ **Đổi so với bản 2026-09-10**, bản ấy ghi *"interceptor không tự xoá token —
việc ấy của `AuthBloc`"*. Lý do đổi nằm ở chỗ 2: server **thu hồi** refresh token
trước khi trả 401 có mã (`auth.service.js:411` trên `main`). Token cũ còn nằm trên
máy thì request kế tiếp lại làm mới bằng nó, vấp *Token Reuse Detection*
(`auth.service.js:380-389`) và nhận 401 **không** mã — tức một lượt
`sessionExpiredStream` chạy đua với hộp thoại. Xoá mà không phát tín hiệu thì mọi
request sau thấy kho rỗng, và `_clearTokens` sẵn có tự im vì `hadSession` là
`false`. `AuthBloc` vẫn gọi `xoaPhienTrenMay()` ở §3.5 — gọi lần hai vô hại.

Trước khi gộp `main`, cả hai chỗ **nằm im**: body 401 chưa mang mã (CAN-LAM 13), và
`/auth/refresh` chưa kiểm trạng thái tài khoản. Nhánh đã gộp `main` @ `cc65f4f`
(2026-09-11), nên mã backend cho chỗ 1 đã có trên nhánh. Chỗ 2 chạy khi backend sửa CAN-LAM 17 mục A — hôm nay nó trả 401 kèm
`idaccount` nhưng **không** `code`, nên `tuBody401` trả `null` và rơi về đường cũ.
Không cần đổi gì phía client khi backend sửa.

### 3.4. Cố ý bỏ qua lỗi bắt tay socket

`core/socket.js:39-44` luôn gắn `code: 'ACCOUNT_DELETED'` cho handshake bị từ
chối, **kể cả** tài khoản chỉ bị khoá. Tin mã ấy thì một người bị khoá tạm bị
**xoá sạch dữ liệu trên máy**. Người mở app sau khi đã bị khoá vẫn bị đăng xuất
qua nhánh HTTP (khi backend sửa) hoặc qua `verifySession` như hôm nay.

⚠️ **2026-09-11 — trên `main` @ `7675b35` lý do này đổi dạng, quyết định giữ
nguyên.** Bắt tay nay tách `ACCOUNT_INACTIVE` / `ACCOUNT_DELETED`, nhưng hàm dựng
mã đang từ chối **mọi** tài khoản (CAN-LAM 17 mục A), và nếu sửa nửa vời thì lỗi
lược đồ đi ra thành `ACCOUNT_DELETED` (CAN-LAM 17 mục 2.5). Bắt tay bị từ chối chỉ
khiến kênh hẹn nối lại; người bị khoá hoặc xoá vẫn bị đẩy ra ở request HTTP kế
tiếp, qua `authenticate` — chỗ duy nhất trên `main` đã tách riêng ca lỗi lược đồ
(503).

### 3.5. `AuthBloc`

Event mới `TaiKhoanBiBuocDangXuat(ThongBaoBuocDangXuat)`, nguồn là cả hai luồng
trên (nối trong constructor, cùng khuôn với `sessionExpiredStream`).

1. Chỉ xử lý khi state là `AuthSuccess` hoặc `AuthChecking`. Khác thì bỏ qua —
   lần nhận thứ hai (socket rồi HTTP) tới **sau** khi lần đầu xong thì không làm
   gì; tới **trong lúc** lần đầu còn chạy thì state vẫn là `AuthSuccess`, nên phải
   chặn bằng cờ (§9, thêm 2026-09-11).
2. Dừng `SyncEngine`, `NotificationScanner` (đã `cancelAll`), `RealtimeChannel`
   qua **một** hàm `_dungMoiThuCuaPhien()` — chuỗi này đang chép ở
   `_onSessionInvalidated` và `_onLogoutRequested`; lần này là lần thứ ba.
3. `daXoa` **và** `nguon` khác `lamMoi` → `AppDatabase.purgeDataForAccount(idaccount)`
   (mục 3.6, §3.6b). `daXoa` từ nguồn `lamMoi` bỏ qua bước này, vẫn làm bước 4–5.
4. `AuthRepository.xoaPhienTrenMay()` — xoá token và bộ nhớ đệm người dùng,
   **không** gọi `/auth/logout`: route ấy đi qua `authenticate`
   (`auth.routes.js:33`), sẽ 401 rồi quay vòng qua interceptor. Với nguồn HTTP,
   interceptor đã xoá token trước (§3.3) — gọi lại vô hại, vì bộ nhớ đệm người dùng
   vẫn phải xoá ở đây.
5. Phát `AuthUnauthenticated(thongBao: …)`. Router sẵn có đưa về `/login`.

⚠️ Bloc chạy các handler **đồng thời**. Lúc mở app, `_onAuthCheckRequested` có
thể phát `AuthUnauthenticated()` trơn trước khi event này chạy xong. Vì vậy
`thongBao` **phải** nằm trong `props`: lần phát sau vẫn là state mới, hộp thoại
vẫn hiện.

`idaccount` để dọn lấy từ thông báo; thiếu thì từ `getCurrentUser()`. Không suy
từ SQLite, không mặc định (quy tắc 2 `CLAUDE.md`). Không có id hợp lệ → **không
dọn**, vẫn đăng xuất.

### 3.6. `purgeDataForAccount`

Hàm mới ở `app_database.dart`, **ngược chiều** `purgeDataForOtherAccounts`: xoá
hàng **thuộc** `idaccount` trong đúng chín bảng ấy, cùng thứ tự con → cha, giữ
`idaccount = 0`. `id <= 0` → không làm gì. Đây là xoá bản sao cục bộ của một tài
khoản server đã ẩn danh hoá — cùng loại với hàm sẵn có, không phải xoá dữ liệu
người dùng trên server (quy tắc 5).

### 3.6b. `daXoa` từ nhánh làm mới thì không dọn (đề xuất 2026-09-11, ✅ duyệt cùng ngày)

§3.5 bước 3 dọn SQLite cho **mọi** `daXoa`. Trong các nguồn, **401 của
`/auth/refresh`** là chỗ **đã biết** một sự cố phía server đội lốt được
`ACCOUNT_DELETED`: trên `main` @ `7675b35`, `authenticate` tách lỗi lược đồ thành
503, còn `/auth/refresh` thì chưa (CAN-LAM 17 mục 2.5). Client không tự phân biệt
được.

`ThongBaoBuocDangXuat` mang thêm nguồn — `socket`, `http` hoặc `lamMoi` (trường
`nguon` ở §3.1) — và bước 3 của §3.5 chỉ dọn khi nguồn **khác** `lamMoi`.
Nguồn `lamMoi` vẫn đăng xuất và vẫn hiện hộp thoại "Tài khoản đã bị xoá".

- **Mất gì:** máy không gọi API nào từ lúc tài khoản bị xoá tới lúc token truy cập
  hết hạn — tức chỉ biết tin qua nhánh làm mới — giữ bản rõ trên máy cho tới khi
  một tài khoản khác đăng nhập vào máy ấy (`purgeDataForOtherAccounts` dọn lúc
  đó). Đó đúng là ca Q2 muốn dọn.
- **Được gì:** nếu là báo động giả, người dùng đăng nhập lại và dữ liệu còn nguyên
  — cùng tinh thần *"đọc nhầm thành bị khoá chỉ giữ lại dữ liệu"* ở §3.1.
- Khi CAN-LAM 17 mục 2.5 xong thì bỏ được ngoại lệ này; chú thích trong mã trỏ về
  đây.

### 3.7. Màn Đăng nhập

`BlocListener` thấy `AuthUnauthenticated` có `thongBao` → `showDialog`, thiết kế
ở mục 5. Tiêu đề theo lý do ("Tài khoản đã bị vô hiệu hoá" / "Tài khoản đã bị
xoá"), thân là `loiNhan` (lý do nằm sẵn trong câu server gửi,
`admin.service.js:140`), một nút **Đã hiểu**.

### 3.8. Hai lỗi làm mới token có sẵn — đưa vào phạm vi (duyệt 2026-09-11)

Trước ngày 2026-09-11 hai lỗi này nằm ở mục 8 ("Ngoài phạm vi"). Người dùng chọn sửa
cả hai, **trước** Phần 1, vì §3.3 sửa đúng `onError` và `_tryRefreshToken` của
`auth_interceptor.dart`. Cả hai là lỗi có sẵn, không do hạng mục này sinh ra.

1. **Làm mới hỏng vì mất mạng hoặc lỗi 5xx thì không đăng xuất.** Hôm nay
   `_tryRefreshToken` trả `null` cho mọi phản hồi khác 200 và mọi `DioException`
   (`auth_interceptor.dart:88-119`), rồi `onError` xoá token (`:65-69`, `:80-84`) — mạng
   chập chờn đúng lúc token truy cập hết hạn là bị đăng xuất, trái cam kết offline-first
   mà `auth_interceptor_test.dart` ghi cho request thường. Sửa: chỉ coi là **phiên chết**
   khi server **trả lời** `/auth/refresh` bằng **400 hoặc 401** — đúng hai mã `refresh`
   tự ném (`auth.service.js:372-418`; lỗi không mang `statusCode` thành 500 ở
   `auth.controller.js:77`) — hoặc máy không còn refresh token. Không có phản hồi (hết
   giờ, lỗi kết nối) hoặc 5xx thì **giữ** hai token, **không** phát
   `sessionExpiredStream`, và trả lỗi gốc cho nơi gọi; lần gọi API sau tự làm mới lại.
2. **Nhiều 401 cùng lúc chỉ làm mới một lần.** `AuthInterceptor` kế thừa `Interceptor`
   chứ không phải `QueuedInterceptor`, nên hai request cùng nhận 401 cùng đọc một refresh
   token và cùng gọi `/auth/refresh`. Lượt đầu thu hồi token cũ (`auth.service.js:421`);
   lượt sau gửi đúng token đã thu hồi nên vấp *Token Reuse Detection* (`:380-389`) —
   server thu hồi **mọi** token của tài khoản, kể cả cặp vừa cấp cho lượt đầu — rồi trả
   401, và app đăng xuất. Có thể gặp khi mở app, lúc kiểm phiên (`/auth/profile`) và đồng
   bộ cùng gọi API; **chưa đo** tần suất. Sửa: trong lúc một lượt làm mới đang chạy, mọi
   401 tới sau **chờ chung** lượt ấy — `/auth/refresh` được gọi **đúng một lần** — rồi
   thử lại request bằng token mới; lượt ấy thất bại thì mọi request đang chờ nhận cùng
   kết quả, theo luật ở điểm 1. Cơ chế cụ thể chốt ở kế hoạch.

Điểm 1 **không** cứu được ca đang xảy ra trên nhánh đã gộp `main`: `/auth/refresh` trả
401 cho mọi tài khoản (CAN-LAM 17 mục A), mà 401 là phiên chết. Ca ấy chờ backend sửa.

---

## 4. Phần 2 — Trạng thái chờ xoá

### 4.1. Trạng thái nằm trong `UserModel`

Thêm ba trường, lưu cùng JSON người dùng sẵn có (`offlineUserDataKey`):

| Trường | Khoá JSON | Nguồn |
|---|---|---|
| `status` | `status` | server; thiếu → `'Active'` |
| `countdown` | `countdown` | server; có thể `null` |
| `countdownNhanLuc` | `countdown_nhan_luc` (ISO 8601) | **cục bộ** — lúc client nhận `countdown` |

`_cacheOfflineCredentials` hiện ghi nguyên `userJson` của server; đổi sang ghi
`user.toJson()` để giữ `countdown_nhan_luc`. JSON cũ thiếu cả ba trường vẫn đọc
được (→ `Active`).

`bool get dangChoXoa` so `status` **không phân biệt hoa thường** với
`pendingdelete` — cùng cách `middleware/auth.js:26-29`.

### 4.2. Số ngày còn lại — hàm thuần

Không endpoint nào trả `countdown` mới: `/auth/profile` không có trường này
(`auth.service.js:537-547`), còn JWT mang `countdown` **lúc cấp** và `refresh`
cấp lại đúng payload cũ (`auth.service.js:396-406`). Nên client tự tính:

```
soNgayConLai = max(0, countdown − (ngàyVN(now) − ngàyVN(countdownNhanLuc)))
ngayXoa      = ngàyVN(countdownNhanLuc) + countdown ngày
```

- `ngàyVN` = ngày lịch ở UTC+7 cố định (Việt Nam không đổi giờ), khớp
  `scheduler.service.js:8-21` chạy lúc 00:00 giờ Việt Nam và trừ 1 mỗi lần.
- Trừ ngày bằng `DateTime.utc(y, m, d)` để khỏi lệch do múi giờ của máy.
- `countdown == null` → không có số, chỉ hiện câu chung (mục 5.2, 5.3).
- Đặt ở `lib/core/auth/dem_nguoc_xoa.dart`.

### 4.3. Trạng thái đến từ đâu

| Lúc | Việc |
|---|---|
| Đăng nhập | lấy `status`, `countdown` từ response; `countdownNhanLuc = now` |
| Mở app (`verifySession` gọi `/auth/profile`) | repository cập nhật `status` vào bộ nhớ đệm khi profile thành công: server `Active` mà máy đang chờ xoá → về `Active` (đã huỷ ở máy khác); server `PendingDelete` mà máy không biết → `PendingDelete`, `countdown = null` (yêu cầu gửi từ máy khác). `_onAuthCheckRequested` đọc lại `getCurrentUser()` **sau** `verifySession` |
| Gửi yêu cầu xoá thành công | ghi `PendingDelete`, `countdown` từ response (30), `countdownNhanLuc = now`; **không** xoá token, **không** đăng xuất |
| Huỷ xoá thành công | ghi `Active`, `countdown = null` |
| Huỷ xoá thất bại vì bất kỳ lý do gì | gọi lại `verifySession` (tức `/auth/profile`, cập nhật `status` như dòng hai). Server đã `Active` → thẻ tự biến mất, **không** báo lỗi (đã huỷ ở máy khác). Còn chờ xoá → báo lỗi. **Không** nhận diện bằng mã 400 hay câu chữ: `cancelDelete` ném `Exception(msg)` làm mất mã HTTP, và backend dùng 400 cả cho lỗi kiểm tra đầu vào |

Sau mỗi lần ghi, trang gọi `AuthBloc.add(ThongTinTaiKhoanThayDoi())`; handler
đọc lại `getCurrentUser()` và phát `AuthSuccess(user)` mới. Trang vẫn tự giữ
trạng thái đang tải và lỗi của nó, như hiện nay.

`AuthRemoteDataSource.deleteAccount` và `cancelDelete` đổi sang **trả về**
`data` thay vì `void`.

### 4.4. Gỡ mã chết của đặc tả cũ

- `UserModel.pendingDeleteCancelled`, nhánh gắn cờ ở `auth_repository_impl.dart:42-45`,
  chú thích ở `auth_remote_data_source.dart:67`.
- Hộp thoại "Tài khoản đã được khôi phục" ở `login_page.dart:36-71`.
- Đầu `docs/superpowers/auth/2026-08-17-auth-account-design.md` thêm dòng báo
  đã bị thay bởi tài liệu này (kiểm `git check-ignore` trước).

---

## 5. Phần 3 — Giao diện

Mọi khối mới đã (hoặc sẽ) thiết kế vào dự án Stitch `FlowMoney`
(`projects/5106367939423432838`) trước khi dựng.

### 5.1. Hộp thoại bị đẩy ra — màn Đăng nhập

Stitch: `97dd48e7154446168767cf80480bff85` — *"Đăng nhập - Tài khoản bị vô hiệu
hoá - FlowMoney"* (vẽ ca bị khoá; ca đã xoá chỉ khác biểu tượng và tiêu đề).
⚠️ Stitch dựng màn này ở khung **máy tính** (`deviceType: DESKTOP`, rộng 2560)
dù yêu cầu là mobile. Chỉ lấy **hộp thoại** làm chuẩn — nó là lớp nổi nên không
phụ thuộc khung; chiều rộng thật trên máy là `AlertDialog` mặc định trong 411dp.

Nền mờ phủ màn Đăng nhập; hộp thoại trắng bo 16px: biểu tượng tròn nền
`#FFDAD6` (icon `block` cho bị khoá, `delete_forever` cho đã xoá), tiêu đề theo
lý do, thân là `loiNhan`, dòng phụ *"Bạn đã được đăng xuất khỏi thiết bị này.
Liên hệ hỗ trợ nếu bạn cho rằng đây là nhầm lẫn."*, một nút **Đã hiểu**.

### 5.2. Thẻ nhắc trên Trang chủ

Stitch: `657d29a8f89e4750ae6f878d096aa94e` — *"Trang chủ - Tài khoản đang chờ
xoá"* (dựng từ `6c692ef11f2d4f40aee3666449b4988d` với ngăn kéo đóng).

- Vị trí: ngay dưới `_buildHeader`, trên `_buildHeroSection`.
- Thẻ thu gọn theo nội dung (không phải dải kín ngang): nền `#FFDAD6`, bo 8px,
  đệm 16px; viền `error` 20% và bóng nhẹ (có trên Stitch). Tiêu đề "Tài khoản đang chờ xoá" kèm biểu tượng đồng hồ màu `error` trong vòng tròn nền trắng mờ (có trên Stitch); thân *"Còn **N ngày** nữa tài
  khoản và toàn bộ dữ liệu sẽ bị xoá vĩnh viễn."*; `countdown == null` thì
  *"Tài khoản và toàn bộ dữ liệu sẽ bị xoá vĩnh viễn khi hết thời hạn chờ."*
- Nút **Để sau** (ghost) và **Huỷ xoá** (chính, có trạng thái đang tải).
- "Để sau" ẩn thẻ tới lần mở app kế tiếp: cờ **trong bộ nhớ** (một
  `ValueNotifier<bool>` đăng ký ở `sl`), đặt lại khi đăng nhập thành công. Cố ý
  không lưu xuống đĩa.
- Huỷ xoá thành công thì thẻ tự biến mất — chính việc biến mất là phản hồi,
  không thêm toast. Lỗi → `SnackBar` như các trang khác.
- Chỉ hiện khi `AuthSuccess.user.dangChoXoa`.

### 5.3. Thẻ "Vùng nguy hiểm" ở Cài đặt

Stitch: `13a6c1f6adac41ce8ed89e6f248f511f` — *"Cài đặt - Tài khoản đang chờ xoá"*
(bản gốc `05fc2d46c5544f1d95fec14421e1d467` giữ nguyên cho trạng thái `Active`).

- `Active`: như hiện nay.
- Chờ xoá: giữ khung, viền, tiêu đề; hộp đếm nền `#FFDAD6` với số lớn **N** +
  "ngày còn lại" và dòng *"Tài khoản và toàn bộ dữ liệu sẽ bị xoá vĩnh viễn vào
  dd/MM/yyyy."*; dòng *"Trong thời gian này bạn vẫn dùng app bình thường. Huỷ
  yêu cầu để giữ lại tài khoản."*; nút chính **Huỷ yêu cầu xoá** thay nút viền đỏ.
  `soNgay`/`ngayXoa` null (tức `countdown` hoặc mốc nhận null) thì bỏ **cả** hộp
  đếm lẫn dòng có ngày, thay bằng câu chung *"Tài khoản và toàn bộ dữ liệu sẽ bị
  xoá vĩnh viễn khi hết thời hạn chờ."* — cùng câu với thẻ Trang chủ (mục 5.2);
  dòng *"Trong thời gian này…"* giữ nguyên.

⚠️ Stitch tự áp design system "Kinetic Clarity" (`assets/1f1ef0da…`) cho màn
sửa này, khác "Kinetic Finance" (`assets/e8b7d56e…`) của dự án. Khi dựng, lấy
**màu và cỡ chữ đã ghi ở trên**, không lấy token của hệ kia.

### 5.4. Trang Xoá tài khoản — chỉ sửa chữ và luồng

- Banner đầu trang: *"Tài khoản sẽ không bị xóa ngay lập tức. Bạn có 30 ngày để
  đổi ý và khôi phục tài khoản bằng cách đăng nhập lại."* → *"Tài khoản sẽ
  không bị xoá ngay lập tức. Bạn có 30 ngày để đổi ý — huỷ yêu cầu ở Trang chủ
  hoặc Cài đặt."*
- Hộp thoại xác nhận: bỏ câu *"bạn có thể đăng nhập lại để hủy yêu cầu"*.
- Thành công: hộp thoại *"Yêu cầu đã được ghi nhận. Bạn vẫn dùng app bình thường
  trong 30 ngày, và huỷ được bất cứ lúc nào ở Trang chủ hoặc Cài đặt."* → về
  `/home`. **Không** đăng xuất.
- Dòng thời gian: "Ngay lập tức — tài khoản chuyển sang chờ xoá, bạn vẫn dùng
  app bình thường"; "Trong 30 ngày — huỷ yêu cầu ở Trang chủ hoặc Cài đặt";
  "Sau 30 ngày" giữ nguyên.
- Bỏ nút "Hủy yêu cầu xóa tài khoản" ở cuối trang: khi đang chờ xoá, Cài đặt
  không còn dẫn vào trang này nữa (mục 5.3).

---

## 6. Phần 4 — Việc cho backend

Viết **`CAN-LAM/AUTH_PROFILE_COUNTDOWN.md`** (mục **19** của `README.md` — mục 17 và 18
đã dùng ngày 2026-09-11 cho `FIX_BACKEND_3_REGRESSIONS.md` và `VERIFY_7675B35_REMAINING.md`), không đụng
`src/Backend`:

1. `getProfile` (`auth.service.js:552-565` — nhánh đã gộp `main`) trả thêm
   `countdown` — một dòng. Để hai ca hôm nay chỉ hiện câu chung cũng có số ngày: máy
   **đã giữ phiên** từ trước khi máy khác gửi yêu cầu xoá (mục 4.3 dòng hai), và bộ nhớ
   đệm do bản client cũ ghi, thiếu `countdown_nhan_luc` — ca này còn cần client ghi số cả
   khi trạng thái khớp. Đăng nhập máy khác hay cài lại app thì đã có số: response đăng
   nhập mang `countdown` (mục 4.3 dòng một). Đo 2026-09-11: `main` @ `7675b35` **chưa** làm.
2. `pendingDeleteCancelled` luôn `false` (`auth.service.js:309`, cả nhánh lẫn
   `main`): xin gỡ trường khỏi response hoặc ghi rõ là đã bỏ. ⚠️ Lý do bản trước
   ghi — *"vì `Rule_project.md`/đặc tả 2026-08-18 còn mô tả nó"* — sai một nửa: đo
   2026-09-11, `Rule_project.md` (cả nhánh lẫn `main`) **không** nhắc trường này;
   chỉ hai tài liệu cũ ở `docs/superpowers/auth/` (gitignore, đã gắn dòng "bị thay
   một phần") còn nhắc. Lý do còn lại là trường chết trong response đăng nhập.
3. ~~Ghi nhận client đã theo đặc tả mục 12~~ — **không cần xin nữa**:
   `Rule_project.md` trên `main` (dòng 650) đã ghi *"Gửi yêu cầu xoá **không** thu
   hồi token — người dùng dùng tiếp trong 30 ngày (mục 11.6)"*. Tài liệu 18 chỉ
   trích câu ấy làm căn cứ.

**CAN-LAM 17 (đã viết) là điều kiện** để nhánh socket (bắt tay) và nhánh làm mới
(§3.3 chỗ 2) chạy được trên `main`.

Kèm cập nhật `README.md` mục 2 và mọi con số đếm mục CAN-LAM trong
`CLAUDE.md`/`PROJECT_CONTEXT.md` (đếm bằng script).

---

## 7. Kiểm thử và kiểm chứng

### 7.1. Test thuần (viết đỏ trước)

- `buoc_dang_xuat_test`: payload socket đủ/thiếu trường; `idaccount` là chuỗi;
  `reason` lạ → `biKhoa`; `message` rỗng → câu mặc định; body 401 có `code` ở
  gốc / dưới `errors` (→ `null`) / không phải `Map` / không có `code`.
- `dem_nguoc_xoa_test`: cùng ngày; qua 00:00 giờ VN (23:59 → 00:01 VN, tức
  16:59Z → 17:01Z); cuối tháng 30/31 ngày; **28/02 → 01/03 năm 2026 và năm
  nhuận 2028**; qua năm; `now` trước `nhanLuc` (đồng hồ máy lùi) → không vượt
  `countdown`; kết quả âm → 0; `ngayXoa` rơi sang tháng/năm sau.
- `user_model_test`: JSON cũ không có ba trường → `Active`; vòng
  `toJson`/`fromJson` giữ `countdown_nhan_luc`; `dangChoXoa` với
  `PendingDelete`/`pendingdelete`/`Active`/thiếu.

### 7.2. Test tích hợp và widget

- `AuthInterceptor`: 401 có `code` → **không** gọi refresh (Dio làm mới giả đếm
  0), phát `taiKhoanBiTuChoi`, xoá token **không** phát `sessionExpiredStream`;
  làm mới trả 401 **có** `code` → phát `taiKhoanBiTuChoi`, xoá token không phát tín
  hiệu, và request kế tiếp **không** gọi làm mới lần hai; làm mới trả 401 **không**
  `code` (hình dạng `main` hôm nay) → đường cũ; 401 không `code` → đường cũ (test
  sẵn có vẫn xanh).
- `AuthInterceptor`, §3.8: làm mới gặp lỗi kết nối hoặc hết giờ → giữ hai token,
  **không** phát `sessionExpiredStream`, request gốc nhận lại lỗi gốc; làm mới trả 503 →
  như vậy; làm mới trả 400 hoặc 401 không mã → xoá token và phát tín hiệu như cũ; hai
  request cùng nhận 401 → Dio làm mới giả đếm **1** và cả hai được thử lại bằng token
  mới; lượt làm mới chung ấy trả 401 → cả hai nhận lỗi, tín hiệu phát **một** lần.
- `RealtimeChannel` (socket giả sẵn có): `account.force_logout` khớp id → phát
  `buocDangXuat`, **không** phát vào `events`; lệch id → im; sau `stop()` → im.
- `AuthBloc` (khuôn `session_validation_test.dart`): `biKhoa` → dừng ba thành
  phần, **không** gọi `logout()` từ xa, không dọn SQLite, state có `thongBao`;
  `daXoa` → dọn đúng tài khoản; không có phiên → bỏ qua; hai lần liên tiếp →
  lần hai không làm gì; `AuthUnauthenticated()` trơn rồi tới `thongBao` → hai
  state khác nhau; hai thông báo có mã tới dồn dập khi handler đầu còn chạy → chỉ
  một lần dừng và dọn; `daXoa` từ nguồn làm mới → **không** dọn (§3.6b).
- `purgeDataForAccount` trên Drift trong RAM: đủ chín bảng, giữ `idaccount = 0`
  và tài khoản khác, `id <= 0` → không xoá gì.
- Widget, dựng bằng `AppTheme.lightTheme` trong `SizedBox(width: 411)` và bắt
  `tester.takeException()` (bẫy tràn bố cục): hộp thoại Đăng nhập theo hai lý
  do; thẻ Trang chủ có số / không số / "Để sau" / "Huỷ xoá" thành công và lỗi;
  thẻ Cài đặt hai trạng thái; trang Xoá tài khoản thành công **không** phát
  `LogoutRequested`.

### 7.3. Kiểm chứng ngoài bộ test

Sau khi áp `database/7`–`11` (tối 2026-09-10, mục 1.3), backend **của chính nhánh
này** dựng được mọi tình huống **trừ** body 401 có mã (CAN-LAM 13) — kể cả nhánh
socket, vì bắt tay ở đó còn dùng `isAccountValid`. ⚠️ Câu vừa rồi nói về backend
**trước khi gộp**. Nhánh đã gộp `main` @ `cc65f4f` ngày 2026-09-11 theo yêu cầu người
dùng, trong khi CAN-LAM 17 mục A chưa sửa — nên hệ quả mà đoạn này từng cảnh báo nay
là thật: bắt tay socket trên backend của nhánh từ chối mọi tài khoản, và nhánh
socket **không kiểm đầu-cuối được** cho tới khi backend sửa mục A. CSDL dev đã áp
`database/12` cùng ngày. Đề xuất, theo thứ tự:

- **Backend thật, tài khoản thử riêng.** Lúc duyệt, máy ảo được ghi là giữ phiên tài
  khoản **10** — cưỡng chế đăng xuất trên đó là mất phiên ấy. ⚠️ Chiều cùng ngày, lúc kiểm
  nhãn loại ví, log của app cho thấy máy ảo **đã ở phiên tài khoản 11** (Claude không đăng
  nhập) — trước khi kiểm, xem máy ảo đang ở phiên nào rồi mới chọn nơi kiểm. (Bản trước ghi tài khoản 10 "không có
  mật khẩu" — sai: đo bảng `account` chỉ đọc ngày 2026-09-11, cả ba tài khoản của CSDL
  dev đều `Active` và có mật khẩu.) **Tài khoản thử: tài khoản 11**, người dùng cho
  dùng ngày 2026-09-11 — thông tin đăng nhập đưa trong phiên, **không** ghi vào repo.
  Máy ảo đang ở phiên tài khoản khác thì kiểm trên **Chrome**: đăng nhập tài khoản 11 trên
  máy ảo sẽ chạy `purgeDataForOtherAccounts` và dọn dữ liệu cục bộ của phiên ấy. Rồi: gửi yêu cầu
  xoá → thẻ Trang chủ và Cài đặt hiện đúng số; huỷ → thẻ biến mất; khoá qua Admin-web
  → về Đăng nhập, hộp thoại đúng câu, SQLite còn dữ liệu; mở khoá rồi đăng nhập lại
  được.
- **Ca *đã xoá* không làm trên backend thật** — admin xoá mềm tài khoản là không
  hoàn tác được bằng giao diện. Ca này kiểm bằng test (mục 7.2); nếu cần nhìn tận
  mắt thì dùng một backend giả trong scratchpad phát `account.force_logout` với
  `ACCOUNT_DELETED` — cần tạm dừng backend thật, **hỏi người dùng trước**.
- **Nhánh HTTP 401** kiểm được trên backend của nhánh — đã gộp `main` và áp
  `database/12` ngày 2026-09-11 — theo mục 5
  `AUTH_401_BODY_CODE.md`. **Nhánh làm mới** (§3.3 chỗ 2) chờ thêm CAN-LAM 17 mục A,
  theo mục 2.7 `FIX_BACKEND_3_REGRESSIONS.md`.
- Không sọc vàng tràn bố cục ở 411dp.

`flutter test` và `flutter analyze` đối chiếu mức nền ghi trong `CLAUDE.md` — 2029/2029
và 25 issue tính tới 2026-09-11.

---

## 8. Ngoài phạm vi

- Đăng nhập bị từ chối 403 vẫn dùng `SnackBar` hiện có — đã hiện đủ câu có lý do.
- Bố cục trang Xoá tài khoản lệch màn Stitch `8a2c9ba…` (Stitch gọn hơn nhiều).
  Chỉ sửa chữ và luồng; dựng lại theo Stitch là việc riêng nếu người dùng muốn.
- Mã lỗi của handshake socket, `/auth/refresh` không kiểm trạng thái tài khoản,
  403 đăng nhập không có `code` — đã xin ở `AUTH_401_BODY_CODE.md` 4.2, 4.3. ✅ Cả
  ba **đã làm trên `main` @ `7675b35`** (gộp về nhánh 2026-09-11): 403 đăng nhập nay mang `code`
  nhưng màn Đăng nhập vẫn dùng `SnackBar` như dòng đầu mục này; `/auth/refresh` có
  mã được xử lý ở §3.3; mã bắt tay vẫn bị bỏ qua (§3.4).
- ~~Hai lỗi làm mới token có sẵn~~ (làm mới hỏng vì 5xx hoặc mất mạng cũng đăng xuất;
  hai lần làm mới đồng thời vấp *Token Reuse Detection*) — **đưa vào phạm vi ngày
  2026-09-11**, nay ở §3.8.
- Thông báo cấp hệ điều hành khi sắp hết hạn chờ xoá.

## 9. Bẫy đã thấy trước

- **Handler đồng thời của Bloc** — mục 3.5. Test phải dựng đúng thứ tự
  `AuthUnauthenticated()` trơn rồi mới tới thông báo.
- **`disconnectSockets(true)` ngay sau `emit`** (`core/socket.js:184-187`): nếu
  gói tin rơi trước khi tới client thì nhánh socket không nổ. Engine.io chờ
  `drain` trước khi đóng nên lý thuyết là tới được; chỉ kiểm được bằng backend
  giả làm đúng thứ tự ấy.
- **`purgeDataForAccount` đọc nhầm lý do là xoá dữ liệu** — vì thế mặc định mọi
  thứ không rõ về `biKhoa` (mục 3.1) và bỏ qua mã handshake (mục 3.4).
- **Hai chỗ sửa `status` đồng thời**: người dùng bấm Huỷ xoá trong lúc
  `verifySession` đang chạy. Bộ nhớ đệm là "ai ghi sau thắng"; chấp nhận, vì lần
  mở app kế tiếp tự lành theo server.
- **Làm mới trả 401 có mã thì token đã bị thu hồi** (`auth.service.js:411` trên
  `main`). Để token trên máy thì lần làm mới sau vấp Token Reuse Detection → 401
  **không** mã → `sessionExpiredStream` → một lượt đăng xuất trơn chạy đua với hộp
  thoại. Vì thế §3.3 xoá token không phát tín hiệu ngay khi thấy mã.
- **Nhiều request cùng nhận 401 có mã.** State chỉ đổi ở bước 5 của §3.5, nên lần
  nhận thứ hai tới khi lần đầu còn chạy vẫn thấy `AuthSuccess`. Chặn bằng cờ đặt
  ngay đầu handler (hoặc transformer `droppable`), đừng dựa vào state.
- **Lỗi lược đồ đội lốt `ACCOUNT_DELETED` ở nhánh làm mới** — CAN-LAM 17 mục 2.5;
  phía client xem §3.6b.
