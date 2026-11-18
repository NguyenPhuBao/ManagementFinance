# Mục 53 — Danh mục mặc định chỉ áp cho tài khoản mới (Backend + Admin-web, 2026-11-17)

Người đặt: NPBao (Backend + Admin-web). Chủ dự án chốt nghiệp vụ ngày 2026-11-17.
Kế hoạch phía Backend: `docs/superpowers/plans/2026-11-17-danh-muc-mac-dinh-chi-ap-cho-tai-khoan-moi.md` (thư mục bị `.gitignore`, chỉ có trên máy NPBao).

## 1. Nghiệp vụ mới

- Mỗi tài khoản (người dùng đăng ký và quản trị do Admin tạo) nhận **bản danh mục riêng** ngay lúc tạo tài khoản, do **Backend** chép từ bộ danh mục mặc định (khuôn) đang hoạt động: `Create_by` = id tài khoản, `Is_default = false`, `Idcategory` là UUID mới.
- Admin-web thêm / sửa / xoá danh mục mặc định chỉ đổi khuôn trong CSDL. Thay đổi chỉ áp cho tài khoản tạo **sau** lúc đổi. Danh mục của tài khoản đã có là danh mục cá nhân, **không bị tác động** (không đổi tên, không đổi biểu tượng / từ khoá, không thêm danh mục mới, không ẩn).

Nghiệp vụ này **thay** thiết kế client `2026-10-27-danh-muc-mac-dinh-theo-thao-tac-admin-design.md` (lan truyền khuôn, ẩn theo khuôn).

## 2. Backend đã đổi (đã có hiệu lực khi deploy)

| Thay đổi | Ảnh hưởng tới Client-app |
|---|---|
| `/sync/pull` **không còn trả** hàng `is_default = true` trong `categories` | Máy cài mới / dữ liệu trống không nhận khuôn. `DefaultCategorySeeder` gặp `khuon.isEmpty` nên trả 0 (đúng thiết kế hiện có). Máy cũ giữ khuôn cũ trong SQLite, không còn thay đổi nào về. |
| Đăng ký / tạo tài khoản quản trị: Backend tạo bản riêng trong cùng giao tác | Lượt kéo đầu tiên của tài khoản mới đã có đủ danh mục riêng. Bộ tạo bản sao so theo tên (kể cả hàng xoá mềm) nên không sinh bản trùng. |
| Admin sửa danh mục **không còn phát** `sync.completed` tới mọi socket | Máy người dùng không tự kéo về khi Admin sửa danh mục. Các nguồn `sync.completed` khác (đẩy từ máy khác…) giữ nguyên. |
| Script bù `scripts/bu_danh_muc_ca_nhan.js` | Tạo bản riêng cho tài khoản chưa từng có; dời `transaction` / `budget` / `bill` (không thuộc nhà) đang trỏ vào khuôn sang bản riêng cùng tên, nâng `Server_update_at` ⇒ máy kéo về bản đã dời. |

Không đổi: `/sync/push` vẫn chặn sửa / xoá khuôn (`FORBIDDEN_SYSTEM_DEFAULT`); danh mục của nhà; `/sync/default-categories`.

## 3. Việc Client-app cần làm

1. **Gỡ lan truyền khuôn**: `features/category/application/lan_truyen_khuon.dart` (`LanTruyenKhuon`, `viecSauKeoVeDanhMuc`) và chỗ nối ở `core/di/injection_container.dart` (cổng `sauKeoVe`). Không còn khuôn về thì nó không chạy, nhưng mã chết dễ bị bật lại nhầm.
2. **Gỡ luật ẩn theo khuôn** `dangAnTheoKhuon` (`features/category/domain/ban_sao_mac_dinh.dart`), mục *"Đang tạm ngừng (N)"* ở màn Danh mục, dải nhắc form Sửa và câu `cauTrungBanSaoDangAn`. Hiện máy cũ còn khuôn đã xoá trong SQLite nên các bản sao đang ẩn vẫn ẩn; máy cài mới không có khuôn nên chúng hiện lại ⇒ hai máy của cùng tài khoản hiển thị khác nhau cho tới khi gỡ.
3. **Bộ tạo bản sao** (`DefaultCategorySeeder`): Backend đã tạo bản riêng lúc đăng ký nên có thể bỏ, hoặc giữ làm lưới an toàn (vô hại khi không có khuôn). Đề xuất: bỏ khỏi `sauKeoVe`.
4. **Dọn khuôn cũ trong SQLite** (hàng `isDefault = true`) để luật đếm trần Premium (`laBanSaoMacDinh`, `premium/data/dem_dang_hoat_dong.dart`) không còn dựa vào khuôn đứng yên. Soát lại cách đếm *danh mục riêng*: bản riêng do Backend tạo mang `Is_default = false` giống danh mục người dùng tự tạo.
5. Cập nhật `test/core/sync/sync_payload_contract_test.dart` nếu có ca kỳ vọng khuôn trong `/sync/pull`.

## 4. Nghiệm thu (2 tầng)

- Tầng 1: màn Danh mục không còn mục "Đang tạm ngừng"; không lỗi khi danh sách khuôn rỗng.
- Tầng 2: Admin đổi tên / xoá / thêm danh mục mặc định ⇒ trên máy của tài khoản đã có, sau lượt kéo, danh mục giữ nguyên tên, biểu tượng, số lượng. Tài khoản đăng ký sau thay đổi ⇒ nhận bộ danh mục theo khuôn mới.

## 5. Trả lời của Client-app

*(ghi ngày, tên, trạng thái từng việc ở dưới)*
