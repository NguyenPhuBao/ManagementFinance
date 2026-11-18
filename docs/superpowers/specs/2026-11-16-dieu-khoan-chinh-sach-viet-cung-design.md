# Điều khoản sử dụng + Chính sách bảo mật viết cứng trong app — thiết kế

Ngày 2026-11-16 (phiên 49). Đơn `docs/superpowers/client-app/CAN-LAM/CHINH_SACH_BAO_MAT.md` (README mục 12 = đơn 51), **đổi hướng
2026-11-16** (gộp `origin/main` `437af2df`, commit `d6a17999` của NPBao): chính sách viết cứng phía Client-app; app KHÔNG gọi
`/api/policy/*`, KHÔNG nghe `system.policy_updated`; Backend không bật `403 POLICY_NOT_ACCEPTED`. Văn bản đã duyệt:
`docs/superpowers/specs/2026-11-16-van-ban-dieu-khoan-chinh-sach.md`.

## 0. Quyết định người dùng
1. Hướng kết hợp (phiên 48), rút gọn theo đổi hướng: ô tick bắt buộc ở Đăng ký, đọc được cả hai văn bản, mục đọc lại ở Cài đặt.
2. Tài khoản đã đăng ký trước đây **không bị hỏi** — không màn chặn, không lưu trạng thái đồng ý ở đâu cả.
3. Hai văn bản: Chính sách bảo mật (dựng lại từ `Chinh_sach_bao_mat_v1.md` của NPBao, tệp ấy chỉ đọc) + Điều khoản sử dụng (Claude soạn
   theo khuôn YNAB, người dùng duyệt). Cả hai "Phiên bản 1.0 · Có hiệu lực từ ngày 16/11/2026".
4. Không gửi gì lên máy chủ khi đồng ý.

## 1. Luồng
- **Đăng ký** (`register_page.dart`): câu cũ *"Bằng cách đăng ký, bạn đồng ý với Điều khoản dịch vụ và Chính sách bảo mật"* (hai chữ
  xanh không bấm được) thay bằng ô tick *"Tôi đã đọc và đồng ý với **Điều khoản sử dụng** và **Chính sách bảo mật**"*; hai cụm đậm bấm
  được → trang đọc. Bấm "Đăng ký" khi chưa tick → dòng lỗi đỏ *"Bạn cần đồng ý với Điều khoản sử dụng và Chính sách bảo mật"* dưới ô
  tick, KHÔNG gửi sự kiện đăng ký; nút không khoá. Tick xong lỗi tự ẩn.
- **Trang đọc** `/chinh-sach/:ma` (`dieu-khoan` / `bao-mat`): AppBar + Back, tiêu đề, dòng *"Phiên bản 1.0 · Có hiệu lực từ ngày
  16/11/2026"*, phần mở đầu, các mục (tiêu đề mục, mục con, đoạn, gạch đầu dòng), cuộn được. Mã lạ → *"Không tìm thấy văn bản"* + Back.
- **Danh sách** `/chinh-sach`: hai dòng (Điều khoản sử dụng · Chính sách bảo mật), mỗi dòng kèm dòng phụ phiên bản.
- **Cài đặt**: thẻ CÀI ĐẶT tab Cá nhân (`profile_page.dart`), dưới "Cài đặt thông báo": dòng **"Điều khoản & chính sách"** → `/chinh-sach`.

## 2. Router — loại route thứ ba
`authRedirect` hiện có hai loại: route công khai (người ĐÃ đăng nhập bị đẩy về `/home`) và route thường (người CHƯA đăng nhập bị đẩy về
`/login`). Trang chính sách phải mở được ở cả hai phía → thêm tập `_routesMoChoCaHai` (`/chinh-sach` và `/chinh-sach/…`) và
`laRouteMoChoCaHai(String)`; `authRedirect` trả `null` cho loại này ở mọi trạng thái. `laRouteCongKhai` KHÔNG đổi → lớp khoá ứng dụng
coi trang này như route thường (đã đăng nhập + đang khoá vẫn che; chưa đăng nhập không có khoá). Ba route là route gốc (ngoài shell):
từ Đăng ký (ngoài shell) và từ tab Cá nhân đều mở bằng `push`, Back về đúng chỗ.

## 3. Cấu trúc mã — mảng mới `features/chinh_sach/`
| Tầng | Tệp | Việc |
|---|---|---|
| `domain/` | `van_ban.dart` | kiểu `VanBan { ma, tieuDe, phienBan, ngayHieuLuc, moDau, List<MucVanBan> }`, `MucVanBan { tieuDe, List<KhoiVanBan> }`, `KhoiVanBan` = đoạn / gạch đầu dòng / tiêu đề mục con; `vanBanTheoMa(String) → VanBan?`; `kDanhSachVanBan` |
| `domain/` | `dieu_khoan_su_dung.dart`, `chinh_sach_bao_mat.dart` | hai hằng, chép nguyên văn tệp văn bản đã duyệt |
| `presentation/pages/` | `van_ban_page.dart`, `danh_sach_van_ban_page.dart` | hai trang |
| `presentation/widgets/` | `o_dong_y_dieu_khoan.dart` | ô tick + hai liên kết + dòng lỗi; trạng thái tick do `register_page` giữ |

Ngày hiệu lực là `DateTime`, hiển thị qua `DateFormatter` (quét 32). Chữ đậm trong văn bản (dấu `**` của tệp nháp) bỏ — văn bản viết
cứng là chữ thường, tiêu đề mục in đậm bằng kiểu chữ.

Chạm mã sẵn có: `core/router/app_router.dart` (ba route + loại thứ ba), `features/auth/presentation/pages/register_page.dart`,
`features/profile/presentation/pages/profile_page.dart`.

Không đổi: không bảng SQLite, không đồng bộ, không API, không đụng `PhienDieuPhoi` / `AuthBloc` / `LopKhoaApp`.

## 4. Kiểm thử (ca đỏ trước)
- Domain: hai văn bản có tiêu đề, phiên bản "1.0", ≥ 10 mục, không mục rỗng; `vanBanTheoMa` đúng / mã lạ `null`; không văn bản nào chứa
  "đồng ý lại" (app không hỏi lại); email liên hệ có mặt ở cả hai.
- Router: `authRedirect` với `/chinh-sach/bao-mat` trả `null` khi `AuthUnauthenticated` lẫn `AuthSuccess`; `laRouteCongKhai` false cho
  route ấy; `/login` và `/home` giữ hành vi cũ.
- Đăng ký: chưa tick + bấm Đăng ký → có dòng lỗi, `AuthBloc` không nhận sự kiện đăng ký; tick → đi tiếp; bấm "Chính sách bảo mật" →
  trang đọc đúng văn bản (router thật); 320 dp không tràn.
- Trang đọc: đủ tiêu đề mục; mã lạ không đỏ màn; 320 dp không tràn. Danh sách: hai dòng, bấm tới đúng trang.
- Cài đặt: có dòng "Điều khoản & chính sách", bấm → `/chinh-sach`.
- Test quét sẵn có tự canh (12 tooltip, 19 `SnackBar`, 25 vị trí tệp, 32 `DateFormat`).

## 5. Giao diện
Stitch (dự án `5106367939423432838`) ba màn, mỗi màn gọi `generate_screen_from_text` một lần, timeout không gọi lại — làm trước khi viết
trang: "Đăng ký - Ô đồng ý điều khoản", "Văn bản pháp lý - Chính sách bảo mật", "Cá nhân - Điều khoản & chính sách". Chỗ app khác Stitch
ghi mục 7.

## 6. Đo máy
Máy ảo `FlowMoney_16G`, APK `--dart-define=API_BASE_URL=http://10.0.2.2:3000/api`: Đăng ký — chưa tick bị chặn, đọc hai văn bản rồi Back
về Đăng ký giữ nguyên chữ đã gõ, tick rồi bấm Đăng ký tới bước gửi OTP thì DỪNG (không tạo tài khoản thật); Cá nhân → Điều khoản & chính
sách → hai văn bản; Back. Đăng xuất để thử Đăng ký → phải đăng nhập lại `dat` (backend local).

## 7. Chỗ mã khác spec
Thi công 2026-11-16 (phiên 49, inline, `0f838a05..fe20fea4`):
1. Tên tệp domain: `van_ban.dart` + `dieu_khoan_su_dung.dart` + `chinh_sach_bao_mat.dart` (spec ghi đúng); hai hằng là `final`
   (không `const` — `DateTime` không hằng), danh sách mục `const`. Hai tệp nội dung **sinh bằng script** từ tệp văn bản đã duyệt và
   đối chiếu từng từ (1.380 / 1.271 từ khớp).
2. Ô tick đặt **trên** nút Đăng ký; câu cũ *"Bằng cách đăng ký…"* dưới nút bị xoá.
3. Liên kết trong ô tick màu `AppColors.primary` (gần đen trong theme hiện tại) + gạch chân, không phải xanh.
4. Stitch: chỉ màn "Cá nhân - Điều khoản & chính sách" có (`8b53d373e03540a288da1d4224ee0afb`, app khớp); hai màn "Đăng ký - Ô đồng ý
   điều khoản" và "Văn bản pháp lý - Chính sách bảo mật" trả `timeout`, không gọi lại; `list_screens` dừng ở 170 màn (không thấy cả màn
   `8b53d373` đã có) nên không kiểm được — cần người dùng nhìn Stitch.
5. Test 320 dp trang đọc cuộn từng bước 200 px và đòi đếm được gạch đầu dòng (kéo 20.000 px một lần không dựng gạch nào — ca xanh cả
   với bản sai). Test Đăng ký nạp font thật (`napFontThat`): với Ahem trang Đăng ký GỐC đã báo tràn 162 px ở 320 dp — tràn giả.
6. Đo máy ảo `FlowMoney_16G` + backend local (2026-11-16): Cá nhân → dòng mới → danh sách → Điều khoản (khớp Stitch); đăng xuất →
   Đăng ký: chưa tick bấm Đăng ký → dòng lỗi đỏ, backend không nhận gì; bấm "Chính sách bảo mật" → trang đọc, Back → form giữ nguyên;
   tick → lỗi ẩn → bấm Đăng ký → `POST /auth/register/send-otp` tới backend (409 *Email đã được sử dụng* vì dùng email của tài khoản 10 —
   không gửi OTP, không tạo tài khoản); đăng nhập lại `dat`, dữ liệu còn. Màn OTP không tới trên máy (ca test tự động phủ).
