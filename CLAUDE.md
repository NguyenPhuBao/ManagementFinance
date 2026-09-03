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
| Việc thuộc backend | `docs/superpowers/backend/SESSION_VALIDITY_FINDINGS.md` và `CATEGORY_CLASSIFY_ALIGNMENT.md` |
| Đụng vào đồng bộ | `src/Client-app/test/core/sync/sync_payload_contract_test.dart` — đọc **như tài liệu**, đây là nơi duy nhất ghi hợp đồng tên trường giữa hai phía |

> ⚠️ **Tài liệu là ảnh chụp, không phải nguồn sự thật.** Luôn đối chiếu với mã nguồn thật trước khi kết luận. Phiên 2026-09-02 có nhiều kết luận sai vì tin vào tài liệu/trí nhớ thay vì mở file ra đọc.

---

## Quy tắc chí mạng

1. **Chỉ sửa `src/Client-app`.** Không đụng `src/Backend` trừ khi được cho phép rõ ràng trong chính yêu cầu đó. Cần backend làm gì thì **viết tài liệu** vào `docs/superpowers/backend/` (đây là thư mục duy nhất được `.gitignore` cho phép push).

2. **`idaccount` CHỈ đến từ phiên đăng nhập.** Không bao giờ suy ra từ dữ liệu trong SQLite, không bao giờ mặc định về `1` — đó là tài khoản **admin thật**, không phải giá trị "chưa biết".

3. **Pull dùng `insertAllOnConflictUpdate`, KHÔNG dùng `insertOrReplace`.** `insertOrReplace` thay **cả hàng**, mọi cột không gán bị đưa về mặc định — từng xoá sạch cấu trúc nhóm danh mục sau mỗi lần pull.

4. **Tên trường sai thì im lặng, không báo lỗi.** Payload đi qua ba nơi định nghĩa độc lập (client dựng tay → `SyncPayloadNormalizer` → `mapEntityFields` phía backend). Thêm trường mới cho sync thì **phải** cập nhật `sync_payload_contract_test.dart` cùng lúc.

5. **Không xoá vật lý dữ liệu người dùng** — dùng soft delete (`delete_at` / `isDeleted`).

6. **`.gitignore` dòng 77 có `test/`** → mọi file test tạo mới đều bị git bỏ qua **âm thầm**. Nhớ `git add -f`, nếu không công sức viết test sẽ biến mất khỏi repo.

---

## Lệnh hay dùng

```bash
# Test (chạy từ src/Client-app) — hiện 139/139 pass, ~8 giây
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

Vùng chưa có test nào: các feature `budget`, `analytics`, `home`, `profile`, `ai_chat`. (`auth_interceptor.dart` đã có test từ 2026-09-03.)
