# `docs/Functional-Mobile/01_XAC_THUC_VA_BAO_MAT.md` tả hai tính năng client KHÔNG có — đăng nhập offline bằng băm mật khẩu và đăng nhập vân tay (mục 51)

**Ngày:** 2026-10-24 · **Phía gửi:** Client-app · **Nhánh:** `TranQuangDat`
**Loại:** đơn xin — **sửa chữ**, mức **thấp**. Không đổi mã, không đổi lược đồ, không đổi API. Tệp do backend tạo (`9d8b5675`,
2026-10-19, NPBao) nên client **chỉ đọc**, không sửa thẳng (quy tắc 1 `CLAUDE.md`). Mọi khẳng định dưới đây đo bằng **đọc mã**
client trên HEAD `TranQuangDat` ngày 2026-10-24.

## Vì sao client gửi đơn này

Lượt soát bảo mật toàn client-app ngày 2026-10-24 (khối 🔒 mục 14 `docs/PROJECT_CONTEXT.md`) đối chiếu tài liệu với mã. Hai
mục của tệp trên tả những gì client **không làm** — người (hoặc AI) đọc tệp để hiểu cơ chế xác thực sẽ suy ra sai: tưởng có
một đường mở khoá dữ liệu bằng mật khẩu khi mất mạng, tưởng mật khẩu băm nằm trong SharedPreferences, tưởng app khoá được bằng
vân tay. Đây là tài liệu bảo mật, nên sai ở đây là sai đúng chỗ người ta tìm để đánh giá rủi ro.

## Chỗ lệch

| Vị trí | Tài liệu viết | Mã client thật (2026-10-24) |
|---|---|---|
| §2.2 ý 1, gạch cuối | *"Lưu băm mật khẩu `offline_password_hash` và thông tin `offline_user_data` vào SharedPreferences."* | Không có SharedPreferences (`pubspec.yaml` không có `shared_preferences`). Token và `offline_user_data` nằm trong **`FlutterSecureStorage`** (`features/auth/data/datasources/auth_local_data_source.dart`, `auth_repository_impl.dart`). Băm mật khẩu: bản cũ có ghi (SHA-256 **không salt**) nhưng **không chỗ nào đọc**; từ 2026-10-24 client **thôi ghi** và còn chủ động **xoá** khoá ấy khi đăng nhập / đăng xuất. |
| §2.2 ý 2 (*"Đăng nhập Ngoại tuyến (Offline Fallback Login)"*) | Mất mạng thì client *"kiểm tra thông tin đăng nhập với `offline_password_hash`"*, khớp thì mở phiên offline. | **Không tồn tại** màn / luồng nhập mật khẩu khi mất mạng. Mở app không mạng: client đọc **token đã lưu + người dùng đã lưu** và vào thẳng dữ liệu SQLite (offline-first, `AuthBloc` `_onAuthCheckRequested`); phiên được hỏi lại server (`GET /auth/profile`) khi có mạng. Đăng nhập mới (đã đăng xuất) **luôn** cần mạng. |
| §2.3 (*"Luồng Bảo mật Sinh trắc học"*) | Vân tay / Face ID qua thư viện `local_auth`, bật trong Cài đặt. | **Không có**: `pubspec.yaml` không có `local_auth`, `lib/` không có mã sinh trắc, Cài đặt không có công tắc ấy. App cũng **chưa** có khoá ứng dụng bằng PIN. |

## Xin làm

1. Sửa §2.2 theo cột phải: lưu trữ là `FlutterSecureStorage`; bỏ ý *"Đăng nhập Ngoại tuyến"* bằng mật khẩu, thay bằng mô tả thật
   (mở app không mạng = dùng token + người dùng đã lưu; đăng nhập mới cần mạng); bỏ câu lưu băm mật khẩu.
2. Sửa §2.3: hoặc **bỏ**, hoặc ghi rõ **"chưa làm — định hướng"** (đừng để ở thì hiện tại).
3. Phần còn lại của tệp client **chưa soát** — nếu backend muốn, gửi lại để client đối chiếu tiếp.

## Kiểm lại

- `grep -n "SharedPreferences\|offline_password_hash\|local_auth" docs/Functional-Mobile/01_XAC_THUC_VA_BAO_MAT.md` → không còn
  câu nào nói các thứ ấy **đang có**.
- Đối chiếu nhanh phía client: `grep -n "shared_preferences\|local_auth" src/Client-app/pubspec.yaml` → **0** dòng.
