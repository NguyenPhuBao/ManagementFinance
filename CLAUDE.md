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
| Việc thuộc backend | 4 tài liệu **còn việc** trong `docs/superpowers/backend/`: `CATEGORY_KEYWORD_SYNC.md` (có lỗ hổng phân quyền), `CATEGORY_NAME_UNIQUENESS.md`, `CATEGORY_STABLE_IDS.md`, `CATEGORY_GROUP_MEMBERSHIP_SYNC.md`. Bảng trạng thái đầy đủ ở mục 14 `docs/PROJECT_CONTEXT.md` |
| Đụng vào đồng bộ | `src/Client-app/test/core/sync/sync_payload_contract_test.dart` — đọc **như tài liệu**, đây là nơi duy nhất ghi hợp đồng tên trường giữa hai phía |
| Đụng vào danh mục | `docs/CATEGORY_RATIONALE.md` — **lý do** của từng thay đổi, bằng chứng đo được, và các phương án đã loại bỏ. Đọc trước khi định "dọn dẹp" vùng này |

> ⚠️ **Tài liệu là ảnh chụp, không phải nguồn sự thật.** Luôn đối chiếu với mã nguồn thật trước khi kết luận. Phiên 2026-09-02 có nhiều kết luận sai vì tin vào tài liệu/trí nhớ thay vì mở file ra đọc.

---

## Quy tắc chí mạng

1. **Chỉ sửa `src/Client-app`.** Không đụng `src/Backend` trừ khi được cho phép rõ ràng trong chính yêu cầu đó. Cần backend làm gì thì **viết tài liệu** vào `docs/superpowers/backend/`.
   - `docs/` gốc **không** bị `.gitignore` chặn, nhưng một số thư mục con thì có (`docs/category/`, `docs/bill/`, `docs/deploy_Cloud/`, `docs/superpowers/plans/`…). Tạo tài liệu ở chỗ mới thì kiểm trước bằng `git check-ignore -v <path>`, nếu không nó biến mất âm thầm.

2. **`idaccount` CHỈ đến từ phiên đăng nhập.** Không bao giờ suy ra từ dữ liệu trong SQLite, không bao giờ mặc định về `1` — đó là tài khoản **admin thật**, không phải giá trị "chưa biết".

3. **Pull dùng `insertAllOnConflictUpdate`, KHÔNG dùng `insertOrReplace`.** `insertOrReplace` thay **cả hàng**, mọi cột không gán bị đưa về mặc định — từng xoá sạch cấu trúc nhóm danh mục sau mỗi lần pull.

4. **Tên trường sai thì im lặng, không báo lỗi.** Payload đi qua ba nơi định nghĩa độc lập (client dựng tay → `SyncPayloadNormalizer` → `mapEntityFields` phía backend). Thêm trường mới cho sync thì **phải** cập nhật `sync_payload_contract_test.dart` cùng lúc.

5. **Không xoá vật lý dữ liệu người dùng** — dùng soft delete (`delete_at` / `isDeleted`).
   - ⚠️ Backend **không nhất quán tên cột**, ít nhất ba kiểu: `category` dùng `Delete_at`, `transaction` dùng `Deleted_at`, và cột ngày của giao dịch là `DateTransaction` (không gạch dưới) chứ không phải `Date_transaction`. Đừng suy tên từ bảng này sang bảng kia — mở `schema.prisma` ra đọc. Truy vấn sai tên cột ở PostgreSQL thì báo lỗi ngay, nhưng viết sai trong payload đồng bộ thì **im lặng** (quy tắc 4).

6. **`.gitignore` dòng 77 có `test/`** → mọi file test tạo mới đều bị git bỏ qua **âm thầm**. Nhớ `git add -f`, nếu không công sức viết test sẽ biến mất khỏi repo.

7. **Tên danh mục là duy nhất trong phạm vi một tài khoản** — **không** tính `classify`, **không** tính nhóm cha, và tính **cả danh mục mặc định** (chúng dùng chung không gian tên với danh mục người dùng). Hàng đã xoá mềm không giữ chỗ. Hai tài khoản khác nhau thì được trùng tên.
   - Phép so tên có **một định nghĩa duy nhất**: `normalizeCategoryName()` ở `lib/core/category/category_name.dart` — NFC → chữ thường → trim → gom khoảng trắng. **Đừng tự viết lại biến thể khác**; trước đây mỗi nơi một kiểu và chúng đã lệch nhau.
   - Thi hành ở `CategoryManagementRepositoryImpl._hasDuplicateName()`. **Đừng** thay nó bằng `getCategoryRows` — hàm đó lọc theo `classify` và khử trùng lặp theo tên, tức loại đi đúng những hàng cần đối chiếu.
   - Phép kiểm tra **chỉ chạy khi tên thật sự đổi**, để người dùng còn sửa được danh mục cũ do bản client trước tạo ra. Đây là chủ ý, không phải lỗ hổng.
   - **Nơi thi hành:** client và Admin-web đã làm; **CSDL và đường `/sync/push` thì chưa** → vi phạm lọt qua hai đường đó sẽ hỏng **âm thầm** khi đẩy dữ liệu. Trạng thái chi tiết ở mục 14 `docs/PROJECT_CONTEXT.md`.

---

## Lệnh hay dùng

```bash
# Test (chạy từ src/Client-app) — hiện 246/246 pass, ~15 giây
flutter test
flutter analyze          # mức nền: 29 issue, KHÔNG có error

# Sau khi sửa Drift tables/DAOs
dart run build_runner build --delete-conflicting-outputs

# Chạy app
cd src/Backend && npm run dev                          # localhost:3000
cd src/Client-app && flutter run -d chrome --web-port 9090
```

**Trước khi báo là xong:** chạy `flutter test` và `flutter analyze`, đối chiếu với mức nền ở trên. Có lỗi mới phát sinh thì nói thẳng, đừng bỏ qua.

---

## Ghi chú về kiểm thử

Bộ test là lưới an toàn chính của dự án này — nhiều lỗi trong quá khứ hỏng **âm thầm** (không exception, không log). Khi sửa lỗi, viết test tái hiện **trước**, và ghi rõ trong `reason:` của assertion là nó canh chừng điều gì.

Vùng chưa có test nào: các feature `analytics`, `home`, `profile`, `ai_chat`. (`auth_interceptor.dart` có test từ 2026-09-03; `budget` có test từ 2026-09-04.)
