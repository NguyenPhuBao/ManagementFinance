# Client-app — Việc còn dang dở & rủi ro đã biết

**Cập nhật:** **2026-10-30, phiên 24** (G113: nợ lát 2 số 12 ✅ phía client — giãn cách `household.changed` 30 s, `1227d8a2`; nợ 4 thêm cảnh báo thứ tự với đơn 57.4; lỗ hổng (5) nay đạt theo mã sau gộp `e3248955` — chưa đo trên máy); trước đó **2026-10-28, phiên 23** (**G113 🚧 mở** — gia đình lát 1: dữ liệu nhà có thể thiếu / kẹt trên máy, nợ lát 2; trước đó phiên 22: **G112 ✅ mở và đóng** — vuốt để cuộn trang Mục tiêu từ một thẻ là kéo đổi thứ tự ưu tiên (thẻ bọc `ReorderableDragStartListener`, bắt kéo ngay); nay chỉ kéo sau khi nhấn giữ; **G105 ✅ đóng** — phần hai: khối ≥ 2 dòng chữ Latin ở đầu nhường dòng viết hoa có dấu ngay sau (tờ `N01c`); **G110 + G111 nhìn trên Realme — đạt**) · **2026-10-28, phiên 21** (**G110 ✅ đóng** — mục *"Đang tạm ngừng (N)"* cuối màn Danh mục + dải nhắc ở form Sửa, Stitch `2dd819da…`; **G111 ✅ mở và đóng** — công tắc khoá theo quyền vẽ y hệt công tắc mở: màu đặt cứng thắng màu khoá mặc định của Material 3; nay qua `CongTacTheoQuyen` — mờ 50 %, ổ khoá trong núm, test quét 41) · **2026-10-28** (**G109 ✅** — mở 2026-10-27 phiên 17 khi thiết kế B1, đóng 2026-10-28 phiên 18 — Basic sau khi Premium hết hạn offline đọc trần của Premium; B1 Task 3 + 6, mã + test; đợt sửa cuối: `dacQuyenPremium` cũng đọc trần qua `tranHieuLuc`) · **2026-10-27, lần ba** (**G110 ⏸ MỞ** — danh mục người dùng TỰ TẠO trùng (tên, loại) một khuôn bị ẩn y như bản sao khi admin xoá khuôn, màn Danh mục không có lối đổi tên nó; đề xuất mục *"Đang tạm ngừng"*, cần màn Stitch trước) · **2026-10-27, lần hai** (**G108 ✅ mở và đóng** — bộ tạo bản sao danh mục so tên + loại trong khi chỉ mục server `uq_category_owner_name` chỉ có tên: khuôn cùng tên khác loại sinh bản sao bị `CATEGORY_NAME_DUPLICATE`, vòng đẩy hỏng; nay so theo tên) · **2026-10-27** (**G107 ✅ mở và đóng** — ảnh Quét mất khi tiến trình chết lúc máy ảnh mở; `NhanAnhQuetBoDo` gọi `retrieveLostData`, nghiệm thu Realme bằng `am crash`) · **2026-10-24 tối** (**G106 ✅ mở và đóng** — lịch nhắc đặt trước mất im lặng sau force-stop; lượt `resync` đầu mỗi tiến trình đặt lại, đo Realme 0 → 3) · **2026-10-23** (**G104 ✅ ĐÓNG** — câu *"một triệu hai tiền sách"* thôi để Gemma điền bản cụt: luật đưa hai chip 1.000.000 · 1.200.000, Gemma không lấp ô số tiền; cùng lượt, phép đọc *"X bậc Y"* viết chữ có một định nghĩa `_docXBacY` với X 1–99 — *"trả hai trăm nghìn tám"* thôi điền 200.800. Mã + test, **chưa đo trên máy**). Trước đó **2026-10-22 tối** (đo Quét ảnh trên Realme sau lối A *gộp lời dừng trùng*; **G105 ◐ sửa một phần** — mẩu rác *"card n"* ở mép ảnh thắng tên cửa hàng *ỦA TEA*; nay dòng toàn chữ thường xếp sau; đo lại khuya: chữ rác lẫn hoa thường (tấm thẻ tiếng Anh) vẫn lọt). Trước đó **2026-10-22** (kiểm chéo số tiền C4 thu hẹp — Gemma chỉ kiểm khi câu còn số tiền khác, người dùng chốt; mở **G104 ⏸ hoãn**: đường luật bỏ trống *"một triệu hai tiền sách"* còn có thể điền bản cụt 1.000.000 của Gemma, chưa đo). Trước đó **2026-10-21, lần năm** (nghiệm thu C4 giọng nói trên Realme — cả hai lối chạy, mỗi lối 4 câu. **G102 ✅ MỞ VÀ ĐÓNG**: lối Android tự dừng sau ~2 giây vì `pauseFor` tính từ lúc bắt đầu nghe; lối Gemma đem bản ghi im lặng đi chép và điền câu lệnh vào ô. **G103 ✅ MỞ VÀ ĐÓNG**: Google viết *"mbbank"* dính và *"500.000₫"* — ví nguồn trượt, ghi chú sót. Cả hai: mã + test + kiểm lại trên máy). Trước đó **2026-10-21, lần bốn** (**G100 ✅ ĐÓNG** — gỡ task khỏi Đa nhiệm khi tiến trình đang giữ mô hình thì `MainActivity` giết tiến trình, dịch vụ D1 được hệ điều hành dựng lại ~1 s sau; nghiệm thu Realme CPU: mở lại chỉ nạp một bản, Native 1,90 GB thay vì 3,71 GB. **G101** nghiệm thu Realme Premium đạt — R08, R13 nay hỏi hai chip; đường Basic chưa nhìn trên máy). Trước đó **2026-10-21, lần ba** (**G101 ✅ ĐÓNG** — Quét ảnh thôi điền sẵn số sai: ba lưới A + B + C ở `chotTongQuet`, Basic cũng qua phép chốt; 0 / 34 tờ chữ điền sai; mã + test, chưa chạy lại trên máy). Trước đó **2026-10-21, lần hai** (**G100 ◐ sửa một phần** — Back hai lần ở Trang chủ đưa app xuống nền thay vì đóng activity; nghiệm thu OnePlus GPU trước / sau đạt; đường gỡ task còn mở). Trước đó **2026-10-21** (nghiệm thu A5 trên Realme mở **G100** — Back thoát app rồi mở lại thì mô hình Gemma nạp thêm một bản, Native Heap 1,89 → 3,72 GB; và **G101** — Quét ảnh điền sẵn số sai không hỏi khi OCR mất / đổi chữ số dòng tổng, R13 2.127 thay 72.127). Trước đó **2026-10-20, lần bảy** (**G99 ✅ ĐÓNG** — cụm mốc bắt đầu bị gạt trước khi xét chữ thời gian; đo lại Realme đạt). Trước đó **2026-10-20, lần sáu** (G95 **đo Realme đạt** — câu xin viết chữ không mở cổng, lệnh *"kể từ…"* vẫn ra thẻ; mở **G99** — hạn mô hình bịa lọt lưới khi câu chỉ nêu mốc bắt đầu). Trước đó **2026-10-20, lần năm** (**G95 ✅ ĐÓNG** — cổng lệnh tạo C3 thôi bắt câu xin viết chữ; mã + test, chưa đo lại trên máy). Trước đó **2026-10-20, lần bốn** (**G98 ⏳ chờ backend — đơn 48**: nguồn là ca 11 của script test backend `Test/test_data_security_encryption_and_masking.js`; người dùng chốt hướng dọn dữ liệu + sửa script, client không đổi mã). Trước đó **2026-10-20, lần ba** (**G89 ✅ ĐÓNG** — nghiệm thu OnePlus 13R đạt bốn kịch bản, bảng ở mục 12 spec G89; **G98 ⏳ mở** — ví test id không phải UUID kẹt hàng đợi đẩy và kéo giãn cách đồng bộ lên 15 phút). Trước đó **2026-10-20, lần hai** (**G97 ✅ mở và ĐÓNG** — body lỗi không phải JSON làm màn Đăng nhập in câu `TypeError`; `_cauLoi` / `_thanhCong` ở `auth_remote_data_source.dart`). Trước đó **2026-10-20** (**G89 🚧 MÃ XONG 2026-10-20, CHỜ NGHIỆM THU OnePlus (Task 12)** — máy chủ chặn bảo trì / phong toả, `connect_error` bị từ chối vì tài khoản, `account.downgraded`, `ACCOUNT_DELETED` không xoá SQLite ở mọi nguồn; 12 commit `b7ca4512..98d58c64`; số mục G còn mở: đếm lại bằng bảng, không chép). Trước đó **2026-10-18 tối, lần ba** (G94 lát 2: mã tính năng xong — màn Chi tiết đơn `/premium/don/:orderCode`, màn Chờ thanh toán đủ thông tin và không tự mở trang PayOS, mọi dòng Lịch sử mua bấm được, thẻ đơn cần xử lý + khoá *Thanh toán* ở màn Nâng cấp, tín hiệu `payment.*`; việc 2, 4–10 của khối 🔀 đã làm; G94 còn mở chờ nghiệm thu sandbox PayOS — khối ✅ cuối thân G94). Trước đó **2026-10-18 tối, lần hai** (G94 lát 1: dọn kiến trúc cả mảng Premium cho khớp `KIEN_TRUC_CLIENT_APP.md`, không đổi hành vi — khối 🧱 ở thân G94; G94 vẫn mở). Trước đó **2026-10-18 tối** (mở lượt G89 + G94 bằng đợt sửa hai lỗi đang chạy ở màn Chờ thanh toán: đồng hồ trên máy về 0 thôi tự đưa màn sang *"Đơn đã hết hạn"* — server quyết, nên người chuyển thừa quay lại sau hạn thấy hộp xác nhận; lỗi khi xác nhận chuyển thừa nay có câu báo. G94 vẫn mở — khối ✅ cuối khối 🔀 ở thân G94). Trước đó **2026-10-18 chiều** (gộp `main` @ `e7570e16`; backend sửa thẳng 26 tệp client-app (6 `lib/`, 20 test) cùng tệp CI, và phủ **một phần G94** — ba trạng thái đơn, nút xác nhận chuyển thừa, nhãn lịch sử — nhưng ca chính vẫn hở; khối 🔀 ở thân G94. Backend báo đóng đơn 41–44: client soát bằng mã + CSDL, 41 và 42 đạt trọn, 43 đạt vế chặn xoá SQLite còn sáu việc (kể cả 12 chỗ tài liệu hợp đồng chưa sửa), 44 còn mục B; người dùng chốt đơn 43 **đã đủ**, lượt G89 + G94 bắt đầu từ phiên sau. Không mục G nào mở hay đóng). Trước đó **2026-10-18 khuya** (nghiệm thu Trợ lý online hỗn hợp trên OnePlus 13R với backend dev chạy thật; mở **G96** — ba giới hạn thuộc backend của đường online: Dừng không tới server, server im > 45 s khi Gemini suy nghĩ, `maxOutputTokens` gồm token suy nghĩ → câu cụt, chờ đơn 47 việc 5–7 — và **G95** — cổng C3 bắt nhầm câu hỏi dạng *"hãy viết 15 lời khuyên…"*). Trước đó **2026-10-16 chiều** (gộp `main` @ `d72ccd45`, Payment premium đối soát thừa / thiếu; client đặt **đơn 44**; mở **G94** — client không biết ba trạng thái đơn mới, màn Chờ thanh toán báo *"hết hạn"* với người vừa chuyển thừa / thiếu; người dùng chốt **làm cùng lượt G89**, sau khi backend đóng đơn 43). Trước đó **2026-10-16** (**G88 ĐÓNG — gạch 4 + quét 28**: `core` → `features` 184 → 178 (điểm ghép 170 + hạ tầng 8, cả tám trỏ vào năm tệp domain thuần — danh sách cố định thay ratchet), `SyncEngine` nhận hai cổng bắt buộc, `noiBoNgheKetQuaDay` về DI, `lichNenKeTiep` → `gopLichNen`, `KhoAnhQuet` → `transaction/data`; quét 28 cấm `domain` → `presentation` / `data/` ngoài `data/models/`; `flutter test` 7.075 → **7.085** (10 skip), `flutter analyze` **20**; nghiệm thu máy ảo ✅ đạt). Trước đó **2026-10-15 khuya** (gộp `main` @ `cd2ee572`, client đặt **đơn 43**: **G89** ⏸️ để nguyên → ⏳ **hoãn tới khi backend đóng đơn 43**, rồi làm một lượt cùng ba việc phía client của hợp đồng sự kiện mới). Trước đó **2026-10-15** (**G88 gạch 3 — đợt 4/4 Thông báo + gạch 5 + gạch 6 ĐÓNG**: `NotificationEntity` + `ThongBaoRepository` thay `ThongBaoNguon`; `core/notification` dời hết (34 tệp: 31 về `features/notification/` — domain · data · data/datasources · application — và 3 về `core/nen` · `core/ocr` · `core/utils`) — `core` còn 15 chủ đề; `data/services/` → `features/<x>/application/` (17 tệp, quét 25 luật 7); Entity **7/14**, quét 27 **bốn** luật, `conChoKieu` rỗng; ratchet quét 25 **43 → 18** (gạch 4 còn 18 dòng / 7 tệp); `flutter test` 7.069 → **7.075** (10 skip), `flutter analyze` **20**; nghiệm thu máy ảo ✅ đạt, 11/18 cặp ảnh 0 px, 7 cặp lệch đều giải thích được; G88 còn gạch 4). Trước đó **2026-10-15** (**G88 gạch 3 — đợt 3/4 Danh mục + hai nợ Mục tiêu + `ghiPhanHoi` đóng**: `CategoryEntity` thành kiểu duy nhất từ repository trở lên; `goal_auto_deposit_runner` dời `goal/data/services/`; `watchGoalTransactions` trả `Stream<List<TransactionEntity>>`; `ghiPhanHoi` nhận `PhanHoiTaiPhanBo`; lối chuyển tiếp trả hàng Drift 4 → **0**, `conChoDomain` và `conChoDynamic` rỗng, Entity **6/14**, quét 27 ba luật, ratchet quét 25 **43** giữ; `flutter test` 7.065 → **7.069** (10 skip), `flutter analyze` **20**; nghiệm thu máy ảo ✅ đạt, 27/29 cặp ảnh 0 px, hai cặp lệch 1 px cuộn; G88 vẫn mở — còn đợt Thông báo + gạch 4–6). Trước đó **2026-10-14** (**G88 gạch 3 — đợt 2/4 Giao dịch + Ví đóng**: `WalletEntity` / `TransactionEntity` thành kiểu duy nhất từ repository trở lên (trừ `goal/domain/goal_auto_deposit_runner.dart`, nằm nhầm tầng — cầm hàng Drift qua DAO, spec mục 11; và `GoalRepository.watchGoalTransactions` — `Stream<dynamic>` chở hàng Drift `Transaction` lên trang Chi tiết mục tiêu, nợ có tên, G88 gạch 3), lối chuyển tiếp trả hàng Drift 10 → **4**, `bill/domain` hết import Drift, ratchet quét 25 hạ tầng 40 → **43**, quét 27 mở rộng sang `lib/core`; `flutter test` 7.057 → **7.065** (9 skip, 0 fail ở `3252db88`; **10** skip từ `692c7091` — tệp đo chạy tay), `flutter analyze` **20**; nghiệm thu máy ảo ✅ đạt 2026-10-14 (22/24 cặp ảnh 0 px, hai cặp lệch do thời gian / nhiễu vẽ; vàng 0; Nhập nhanh từ MoMo → Tiền mặt; `fromDrift` 0,028 ms / 92 hàng); G88 vẫn mở — còn hai đợt Entity (Danh mục → Thông báo) + gạch 4–6). Cùng ngày trước đó (**G88 gạch 3 — đợt 1/4 Hoá đơn đóng**: `BillEntity` thành kiểu duy nhất từ repository trở lên, test quét 27, `flutter test` 7.057; G88 vẫn mở — còn ba đợt Entity + gạch 4–6. Cùng ngày: **G91, G92, G93 đóng** — G91: `d1DangHienPin` của khối nhắc sau ngân hàng xét thêm quyền gói `bank_notification_parser`, khớp điều kiện dựng hàng pin của thẻ D1; một ca widget test Basic, đỏ trên mã cũ. G92: hai cửa chặn route chờ `GoiRepository.choNapKho()` rồi mới đọc gói; 5 ca test, nghiệm thu máy ảo mở lạnh. G93 (tìm ra khi điều tra G92, cùng gốc): lượt quét đầu mỗi phiên chạy trước khi gói có tài khoản → `coQuyenNen` mở cửa cho Basic; sửa bằng hook `datGoi` trong `moPhienCucBo` + `noiPhien` so với phiên đã nối; bốn ca test, không đo được trên máy. Đếm: **93** mục G, **89** đã xử lý, còn **bốn** (G18, G23, G88, G89)). Trước đó **2026-10-13** (**G88 gạch 2 đóng** — bốn trang lớn còn lại tách widget theo khối, dời nguyên văn: `goal_add_page` 1.570 → **791** · `goal_detail_page` 1.480 → **664** · `notification_settings_page` 1.615 → **866** · `report_preview_page` 1.270 → **243** dòng, 30 tệp widget mới + 2 tệp `domain/`; `mienTru` của quét 23 **rỗng**; `flutter test` 7.037 → **7.039**; spec `specs/2026-10-13-tach-bon-trang-lon-design.md`. G88 vẫn mở — còn gạch 3–6. Lượt soát toàn nhánh ghi thêm **hai** lỗi có từ trước, chưa sửa: **G91** (hàng gợi ý pin biến mất cả hai nơi với người dùng Basic còn `docBienDong` bật) và **G92** (deeplink `/goals/add` lúc khởi động nguội bị chuyển sang `/premium`). Đếm: **92** mục G, **86** đã xử lý, còn **sáu** (G18, G23, G88, G89, G91, G92)). Trước đó **2026-10-12** (**G90 đóng** — `bocDongHo24Gio` ép đồng hồ 24 giờ ở `MaterialApp.builder`; gốc lỗi: bảng chọn giờ hiển thị theo ngôn ngữ `vi` nhưng đọc giờ gõ vào theo cài đặt máy; ngoài lời từ chối còn hai ca sai im lặng (20:00 gõ 8 → 20:00, 08:00 gõ 12 → 00:00); nghiệm thu máy ảo đặt 12 giờ **ba trong năm** chỗ gọi (giờ Tổng kết tuần và giờ im lặng cùng cơ chế, chưa chạm) + đối chứng bản chưa sửa. Đếm: **90** mục G, **86** đã xử lý, còn **bốn** (G18, G23, G88, G89)). Trước đó **2026-10-11** tối muộn (**G90 mở** — bảng chọn giờ, chế độ gõ chữ, từ chối mọi giờ > 12 khi máy đặt định dạng 12 giờ; năm chỗ `showTimePicker`; lộ ở lượt nghiệm thu chạy nền trên máy ảo, chưa sửa. Đếm: **90** mục G, **85** đã xử lý, còn **năm** (G18, G23, G88, G89, G90)). Trước đó **2026-10-11** tối (**G88 gạch 1 đóng** — trang Thêm giao dịch tách ra `ThemGiaoDichCubit` + `ThemGiaoDichNguon`: trang 2.007 → **779** dòng, +64 ca test, `flutter test` 6.617 → **6.681**; `mienTru` của quét 23 còn **4** tệp; G88 vẫn mở — còn gạch 2–6. Đếm: **89** mục G, **85** đã xử lý, còn **bốn** (G18, G23, G88, G89)). Trước đó **2026-10-11** trưa (**G89 mở, để nguyên có chủ ý** — thao tác admin vô hình trên client: 503 `MAINTENANCE_MODE` / 403 `AIOPS_QUARANTINED` không nhánh đọc; cùng lượt gộp `main` @ `79e46225`, `.gitignore` neo `/Test/`). Trước đó **2026-10-10** khuya (**G88 gạch 7 đóng** — đợt dọn vị trí tệp: 19 tệp dời + 2 tách + 11 test dời, `spike_sql` gỡ, **test quét 25** canh luật mục 8; spec `specs/2026-10-10-don-vi-tri-tep-theo-luat-design.md`; G88 còn gạch 1–6, gạch 4 nay có ratchet. Đếm: **88** mục G, **85** đã xử lý, còn **ba** (G18, G23, G88)) · trước đó **2026-10-10** (mở **G88** — nợ kiến trúc còn lại sau đợt *bịt điểm rò kiến trúc Client-app*, bảy gạch có số đo, cộng một câu chờ người dùng quyết về form hoá đơn cho chọn **nhóm** danh mục. Đếm: **88** mục G, **85** đã xử lý, còn **ba** (G18, G23, G88)) · trước đó **2026-10-09** (mở rồi **đóng G87** — kỳ hoá đơn trùng sống lại sau xung đột hai máy, bộ tự trả trừ tiền từng kỳ trùng; mở rồi **đóng G86** — mở app thôi đợi `/auth/profile` mới hiện dữ liệu; **đóng G52** — dòng *danh mục • ví • Tự trả* của thẻ hoá đơn thôi bị cắt ở 360 dp; nửa *"Hạn…" gãy hai dòng* đã hết từ G74. Nghiệm thu Realme 360 dp. Đếm: **87** mục G, **85** đã xử lý, còn **hai** (G18, G23)) · trước đó **2026-10-08** tối (**đóng G67** — mốc kéo về theo giờ-server `maxSince`, nghiệm thu hai máy ảo tài khoản 27 đạt hai lượt; lượt một **mở rồi đóng G85** — ví chưa có neo (ví seed) nhận giao dịch máy khác thì neo nuốt giao dịch ấy, có từ G37. Đếm: **85** mục G, **82** đã xử lý, còn **ba** (G18, G23, G52)) · trước đó **2026-10-07** tối (mở rồi **đóng G83** — chữ gợi ý ô ghi chú màn Thêm giao dịch cắt ở 320 dp, nay *"Thêm ghi chú…"* — và **G84** — chữ gợi ý ô Nhập nhanh cắt mất phần ví dụ, ô ghi chú mang khung của theme; cả hai nghiệm thu Realme. Đếm: **84** mục G, **80** đã xử lý, còn **bốn** (G18, G23, G52, G67)) · trước đó **2026-10-06** khuya (mở **G68–G72** từ nghiệm thu Realme; **đóng G68** — thanh dưới thôi tràn ở màn 320 dp; **đóng G69** — header Phân tích thôi nhảy hàng lúc tải xong; cả hai nghiệm thu Realme; **đóng G70** — form Thêm ví thôi bật sẵn mặc định; **đóng G71** — thông báo số dư của ví đã xoá tự gỡ, chưa đo máy thật). **2026-10-07**: mở và **đóng G73** — hàng chọn biểu tượng ví tràn ở 320 dp, cùng họ G68; quét cả app ở 320 dp — không còn sọc tràn nhưng mở **G74–G78**: chữ bị cắt mất thông tin; cùng ngày **đóng G74** — thẻ hoá đơn xếp chồng khi đo thấy chật — **G75** — thẻ ngân sách Trang chủ thôi mất hạn mức — **G76** — tab Ngân sách, thẻ mục tiêu — **G77** — ô kỳ Sổ giao dịch, form Thêm hoá đơn — **G72** — ba thẻ thu/chi Trang chủ cùng cỡ, cùng cao — và **G78** — chữ phụ xuống hai dòng; cả sáu ✅ nghiệm thu Realme 320 dp tối 2026-10-07, cùng **E6 ◐**; lượt nghiệm thu ấy mở rồi **đóng G79** — chấm mép biểu đồ đường vẫn mất nửa, G55 chưa từng có tác dụng — **G80** — tiêu đề Thêm giao dịch cắt khi ✓ lên thanh tiêu đề — và **G81** — hàng "sắp cạn" treo khi ví đã âm; cả ba ✅ nghiệm thu lại trên Realme 320 dp cùng tối, bản debug `fea682cb…`. rồi mở và **đóng G82** — chip Nhận xét bỏ tên đối tượng (ba *"Tỉ lệ 0,0%"* y hệt). Đếm lại bằng máy: **82** mục G, **78** đã xử lý, còn **bốn** (G18, G23, G52, G67)). Trước đó **2026-10-05** tối (**đóng G63** — giao diện Gộp / Đổi tên / dòng nhắc xong (Task 9–12, `de2b133` → `614634f`) và nghiệm thu trên **hai máy ảo cùng tài khoản thử 27**; lượt nghiệm thu bắt **hai lỗi** 5820 ca test mù: vòng đồng bộ nóng ở bước 1b (sửa `2274a1f` — sửa trong cùng lượt nên **không** mở mục G) và máy kia kéo thiếu sau Đổi tên (phần G63 sửa `3544cc4`); **mở G67** — ca chung của lỗi thứ hai, kéo về bỏ sót bản ghi lên server muộn hơn giờ ghi, **chờ backend** (đơn CAN-LAM 37). Đếm lại bằng máy: **67** mục G, **63** đã xử lý, còn **bốn** (G18, G23, G52, G67)) · trước đó **2026-10-05** (**G63 hết hoãn** — người dùng chọn làm; thiết kế duyệt trong chat, spec `docs/superpowers/specs/2026-10-05-g63-vi-trung-ten-hai-may-design.md`; chiều cùng ngày **phần lõi xong** (Task 1–8, `f2a2f52` → `6a68d86`), **chưa có giao diện, chưa nghiệm thu** — G63 vẫn mở. Không mục nào mở hay đóng thêm — số đếm giữ nguyên như dòng ngay sau) · trước đó **2026-10-04** phiên sau (**đóng G66** — `BudgetEntity.mocKy` là định nghĩa duy nhất của lưới kỳ, nhảy từ ngày bắt đầu chứ không từ mốc đã kẹp (`02d46ca`); người dùng chọn sửa **trước** việc nhịp chi; dữ liệu thật không có ngân sách nào dính. Đếm lại bằng máy: **66** mục G, **62** đã xử lý, còn **bốn** (G18, G23, G52, G63)) · trước đó **2026-10-04** (**mở G66** — ngân sách bắt đầu ngày 29–31 trôi hẳn về ngày đã kẹp từ kỳ thứ hai (31/01 → 28/02 → 28/03 → 28/04…), đi được qua form; lộ khi lập kế hoạch dự án C việc hai (nhịp chi ngân sách), **chưa sửa** — người dùng dặn dừng sau kế hoạch. Đếm lại bằng máy: **66** mục G, **61** đã xử lý, còn **năm** (G18, G23, G52, G63, G66)) · trước đó **2026-10-03** tối (**mở rồi đóng G64 và G65** — hai lỗi có sẵn lộ ra khi nghiệm thu *nhắc ghi sau khi dùng app ngân hàng* trên Realme: *Đăng xuất* ở drawer không làm gì (từ 19/09), và dải *"Đã xoá thông báo · Hoàn tác"* không tự ẩn (từ khi nâng Flutter 3.47). Hai lỗi của chính tính năng nhắc ghi sửa trong cùng lượt nên **không** mở mục G — ghi ở mục 8 `BIEN_DONG_SO_DU_FEATURE.md`. Đếm lại bằng máy: **65** mục G, **61** đóng, còn **bốn** (G18, G23, G52, G63)) · trước đó **2026-10-03** (**mở G63 và hoãn** — ví trùng tên giữa hai máy cùng tài khoản: máy đẩy sau kẹt `WALLET_NAME_DUPLICATE` mãi và có hai ví trùng tên; chỉ xảy ra khi một tài khoản dùng trên hai máy, người dùng chốt không làm tính năng, dữ liệu kẹt trên Realme dọn qua giao diện. Đếm lại bằng máy: **63** mục G, **59** đóng, còn **bốn** (G18, G23, G52, G63)) · trước đó **2026-10-02** (**mở rồi đóng G62** — hàng sáu ô OTP tràn 6,9 px ở máy 360 dp, người dùng báo khi đăng ký trên OnePlus; widget chung `HangOOtp`, mục G62 ở thân). Trước đó **2026-10-01** (**mở rồi đóng G61** — người dùng **không còn chỗ nào để tự gõ từ khoá** cho danh mục: trang *Từ khóa của tôi* chỉ mở được từ mục *Danh mục mặc định*, mà `watchTree` trả `defaultChildren: const []` từ khi mỗi tài khoản dùng bản sao riêng (2026-09-07), còn form sửa danh mục không có ô từ khoá. Người dùng hỏi giữa lượt nghiệm thu *đề xuất thêm từ khoá* trên Realme; xác nhận bằng mã và trên máy. **Sửa ở mã cùng ngày** (người dùng chọn: ô từ khoá trong form Thêm / Chỉnh sửa danh mục, đúng màn Stitch `a5a6ecb3…`); nghiệm thu Realme cùng ngày (thêm · gõ dở rồi Lưu · gỡ, kiểm SQLite). Cùng lượt, ca *chuyển grab* của đề xuất từ khoá hỏng trên dữ liệu thật (`grabcar`) và được sửa ngay — ghi ở mục 5f `CATEGORY_RATIONALE.md`, không mở mục G. Đếm lại bằng máy: **61** mục G, **58** đóng, còn **ba** (G18, G23, G52)) · trước đó **2026-09-29** tối (⚠️ phép đếm *"57 mục G, 54 đóng"* trong ngoặc này là ảnh chụp trước G58–G60; đếm bằng máy 2026-10-01 trước khi mở G61: **60** mục, **57** đóng. **mở và đóng G59** — đổi giờ nhắc không dời lịch đang chờ, nay `resync(datLai: true)`; **mở rồi đóng G60** — bảng chọn thứ tổng kết tràn ở màn thấp, nay cao theo nội dung và cuộn được; trước đó **mở và đóng G58** — màn Thêm giao dịch tràn và che ô ghi chú khi bàn phím hệ thống mở ở 360 dp; nay ẩn 16 phím số lúc gõ chữ, người dùng chọn; trước đó cùng tối **đóng G53** — nhãn trục tung thác nước in đè khi số dư âm; `daiTrucCot` đặt sàn và trần là bội của bước tròn, nghiệm thu trên Realme; cùng lượt khối *Dòng tiền tự do* chuyển sang `daiTrucCot` vì mang cùng cơ chế ở dạng tiềm ẩn; rồi **mở và đóng G54** — nhãn trục hoành thác nước dính nhau ở 360 dp, nay xoay −35° theo màn Stitch; rồi **mở và đóng G55, G56, G57** — ba chỗ nhỏ có từ trước mà người dùng chọn sửa trước B4: chấm kỳ đầu/cuối của biểu đồ đường bị cắt nửa, *"chi vượt thu nhập 26360,0%"* nay là *"chi gấp 265 lần thu nhập"*, nút tạo hoá đơn lên thanh tiêu đề. Đếm lại bằng máy: **57** mục G, **54** đóng, còn **ba** (G18, G23, G52)) · trước đó **2026-09-29** chiều muộn (**mở rồi đóng G51** — số tiền trên thẻ hoá đơn bị cắt ở 360 dp, có từ trước, lộ khi nghiệm thu B2 trên Realme; sửa `77521f2`, nghiệm thu lại trên Realme. Đếm lại bằng máy: **51** mục G, **49** đã đóng, còn **hai** (G18, G23)); cùng lượt **mở G52** (đầu thẻ hoá đơn chật ở 360 dp, có từ trước) và **hoãn** theo người dùng — nay **52** mục, **49** đóng, còn **ba** (G18, G23, G52); rồi **mở G53** khi nghiệm thu B3 (nhãn trục thác nước in đè khi số dư âm, có từ trước) — nay **53** mục, **49** đóng, còn **bốn** (G18, G23, G52, G53) · trước đó **2026-09-29** (**mở rồi đóng G49 và G50** — thẻ tổng và tiêu đề ngày của Sổ giao dịch cộng thô theo `type`, đếm cả khoản điều chỉnh số dư nên lệch Trang chủ 10.000 đ; và cặp nạp mục tiêu dạng cũ được mọi màn tính là thu **và** chi (500.000 mỗi chiều). Thấy trên Realme giữa lượt nghiệm thu B1. Đếm lại bằng máy: **50** mục G, **48** đã đóng, còn **hai** (G18, G23)) · trước đó **2026-09-21** (**lát "cửa sổ nhìn lại"** — **trọn sáu Task xong**, kể cả thẻ "Chưa đặt ngân sách"; mục **14** `PROJECT_CONTEXT.md`. Lượt này **không mở mục G nào**, nhưng nó đóng **hai lỗi đang chạy mà chưa ai ghi thành lỗ hổng**, cả hai cùng một gốc: mọi cửa sổ "ba tháng lịch đã đóng" đều **rỗng trên dữ liệu thật** (giao dịch sớm nhất trong toàn bộ CSDL là **02/09/2026**), nên *gợi ý hạn mức trong form tạo ngân sách* chưa từng hiện một con số nào kể từ 2026-09-06, và *phép neo ba ngưỡng theo thu nhập* — làm cùng ngày ở chặng 1.1 — luôn rơi về sàn. **Mã đúng, đầu vào chết**; bộ test mù vì nó dựng sẵn ba tháng dữ liệu. ⚠️ Cả hai **không** được mở thành mục G vì chúng đã được sửa trong cùng lượt phát hiện; ghi ở đây để người sau biết chúng từng tồn tại và vì sao) · trước đó **2026-09-21** (**nghiệm thu máy ảo 411dp** cho lát "sổ giao dịch: phạm vi kỳ + lọc tiền" — Task 5 Step 1, việc dở dang cuối cùng của kế hoạch ấy. Sáu việc phải thấy tận mắt thì **năm đạt**; kèm một xác nhận ngoài danh sách là **G43 đóng thật trên máy** (nút "Tuỳ chọn" mở được cả khi kỳ đang xem **vượt quá hôm nay** — khoảng khởi tạo bị kẹp đúng luật). Lượt này **mở rồi đóng G48 trong cùng ngày** (đường tắt "Xem giao dịch" thôi lọc sẵn ví khi tab Giao dịch đã mở trước — sửa bằng `didUpdateWidget`, nghiệm thu lại trên máy ảo đúng kịch bản từng hỏng) và **sửa hai chỗ nhỏ của chính lát ấy**: câu trạng thái rỗng còn nói *"trong tháng này"* dù trang nay xem được năm đơn vị, và thẻ tổng in `+0 đ` / `-0 đ` trong khi cột *Thu net* ngay cạnh đã theo luật *số 0 không mang dấu* — tức một thẻ hiện **hai quy ước**. Cả hai có ca canh ở `test/features/transaction/presentation/so_giao_dich_ky_rong_test.dart`; **schema không đổi**, vẫn v24; **payload không đổi**) · trước đó **2026-09-20** (**AI Edge-SLM P1 + P2 XONG**, và **kế hoạch P3 đã viết** — `docs/superpowers/plans/2026-09-20-ai-edge-p3-cam-slm.md`, 10 task. **P1 spike** đo Gemma 4 trên máy thật (OnePlus 13R / Snapdragon 8 Gen 3) và **lật bậc thang của spec**: người dùng chốt **E2B cho mọi máy, bỏ hẳn E4B**, vì trên GPU hai mô hình tốn RAM bằng nhau (0,96 vs 0,97 GB) trong khi E2B nhanh gấp đôi và nhẹ hơn 1 GB — bảng đo ở **mục 8** `AI_EDGE_FEATURE.md`, spec mục 4.1 nay có banner 🛑. **P2 XONG** toàn bộ 17 task; tài liệu tính năng `docs/AI_EDGE_FEATURE.md`, tường thuật ở mục 14 `PROJECT_CONTEXT.md`. Task 16 cuối cùng thêm thông báo `budgetRebalance` — loại thứ **19** của enum, mục **5g** `NOTIFICATION_FEATURE.md`. **Không mở lỗ hổng nào trong cả P2**; schema lên **v24** với hai thứ **cục bộ** (cột `categories.ai_co_dinh`, bảng `AiRebalancingFeedbacks`), **payload không đổi**. Hai việc UX gắn với mảng này: **A6** thẻ "Insight AI" chữ tĩnh — ✅ **đóng 2026-09-19** (Task 14: khối Nhận xét gắn vào **bốn** màn Ngân sách · Phân tích · Mục tiêu · Trang chủ, thẻ cũ xoá hẳn); **A11** năm handler rỗng của `ai_chat_page` — ✅ **đóng 2026-09-22** (P3 Task 8): một nút thành thật (bánh răng → `/ai-settings`), bốn nút **gỡ hẳn** cùng khối mockup bịa số, và `ai_chat_page.dart` rút khỏi danh sách miễn trừ của **hai** test quét. Bước tiếp là **thi công P3** theo kế hoạch ấy. ⭐ **Việc AI đã chốt nhưng chưa làm KHÔNG mở mục G** — chúng nằm ở **mục 11.3 và 11.4** `docs/AI_EDGE_FEATURE.md`, vì chúng là *tính năng chưa làm* chứ không phải *lỗ hổng của thứ đang chạy*: bốn việc cá nhân hoá ở tầng số người dùng chốt 2026-09-20 (học mức thiết yếu · tự đề xuất cờ Cố định · nhịp chi theo ngày · bất thường theo danh mục), cộng năm hướng xếp hạng ở 11.3. ⚠️ Luật chung cho cả bốn: **mỗi luật có ngưỡng mẫu tối thiểu, dưới ngưỡng thì im lặng hoàn toàn** — không có ngưỡng thì luật sẽ "im hàng tháng rồi nổ bừa ngay khi vừa đủ mẫu", đúng sai lầm mục 5f `NOTIFICATION_FEATURE.md` đã loại một lần) · trước đó **2026-09-19 tối** (**bắt đầu mảng AI Edge-SLM** — P0 nâng Flutter 3.47.5 xong `03fe03a`) · trước đó **2026-09-19** (**mở rồi đóng G47** — thẻ hoá đơn và bảng tra tên của ngân sách mất tên danh mục mặc định toàn cục / đã xoá mềm, cùng họ G41 ở ba bản chép tay khác của cùng truy vấn; lộ ra ở mục E8 của lượt đánh giá UX cùng ngày. Đếm lại bằng máy: **47** mục G, **45** đã đóng, còn **hai** (G18, G23). Bảng tóm tắt **thiếu G45, G46** từ 2026-09-18 — bổ sung cùng lượt. Lượt UX ấy còn để lại **A12** và **E6** trong `docs/superpowers/plans/2026-09-19-ux-ui-danh-sach-viec.md`, **chưa** mở mục G vì chưa chốt lối sửa — ✅ **A12 đã chốt và sửa 2026-09-19**: phím `.` bỏ khỏi lưới, nhưng chốt thật nằm ở `_saveTransaction` (nay `ThemGiaoDichCubit.chuanBiLuu`) vì lỗi có **hai cửa** và chế độ sửa vẫn nạp được chuỗi có dấu chấm từ `editing.amount.toString()`; xem khối "A12" mục 14 `PROJECT_CONTEXT.md`. **E6** vẫn chờ chốt. ✅ **Nhóm D — cấu trúc menu — cũng xong cùng ngày và KHÔNG mở mục G nào**: sáu chỗ hỏng tìm được đều đóng ngay trong ngày. Hai trong số ấy lộ ra lúc **thiết kế** (push-từ-ngoài-shell, hằng `nhanhThanhTab`), ba lúc **nghiệm thu máy ảo** (hai FAB chồng nhau, trang Ngân sách thành ngõ cụt, "Vùng nguy hiểm" rơi vào giữa trang Cá nhân), và **một do người dùng báo** — trang Quản lý danh mục **mất hẳn lối vào qua menu** vì nhóm module rời tab Cá nhân mà drawer chưa bao giờ có mục ấy. Lần theo báo cáo ấy còn ra hai lỗi nữa: nút bút chì trên avatar **chưa bao giờ bấm được** (không `InkWell`, tức nút **không có handler** — lưới quét nút chết chỉ tìm *handler rỗng*), và avatar **vòng đen trống** ở hai chỗ A9 bỏ sót. Tường thuật đầy đủ ở mục 14 `PROJECT_CONTEXT.md`) · trước đó **2026-09-18** (**đóng G26 bằng một quyết định sản phẩm** — nhóm **bỏ hẳn** liên kết ngân hàng, nên màn duyệt giao dịch ngân hàng thôi là việc còn thiếu. Phần client gỡ cùng ngày: màn mockup `bank_link_page.dart` — **chưa bao giờ gọi một endpoint nào**, số điện thoại và sáu ô OTP điền sẵn ghi cứng trong `initState` — cùng thẻ "LIÊN KẾT NGÂN HÀNG" ở màn Quản lý ví, hai route, và `RealtimeEvent.giaoDichNganHang`. Backend **vẫn phát** `bank_transaction.incoming`, nên client phải bỏ qua nó êm thấm, đúng nhánh `null` sẵn có cho mọi tên lạ. ⚠️ **Ba thứ giữ nguyên, cố ý**: enum `WalletType.banking`, ba cột SQLite `provider`/`bank_tran_id`/`bank_casso_id`, và phép loại ví `banking` khỏi `tinhLaiSoDu` — cả ba bảo vệ **hàng cũ kéo về**, không bảo vệ một tính năng. ⚠️ **Đừng viện G26 để mở `status`/`provider` vào hợp đồng đồng bộ** — đoạn "Bán kính nếu làm" của mục ấy nay là ảnh chụp lịch sử. **Schema không đổi**, vẫn v23; **payload không đổi**. Đếm lại bằng máy: **46** mục G, **44** đã xử lý, còn **hai** (G18, G23) — con số giữ nguyên vì G26 vốn đã mang dấu ✅. Cùng ngày, trước đó: **mở rồi đóng G46** — lượt soát nối tiếp G45, lần này quét **cả app**: lỗ hổng trần số chữ số **không phải chuyện riêng của ví**. Tám cột tiền đều là numeric(15,2), và **bốn mảng còn lại** (giao dịch, hoá đơn, mục tiêu, ngân sách) đều không giới hạn số chữ số. Nặng nhất là **giao dịch** — người dùng ghi hàng ngày, bàn phím **tự vẽ** nên inputFormatters không với tới, lại có phím **000**. Nay phép gõ tách thành hàm thuần themPhimSoTien, và có **test quét lib/ thứ tám** để ô tiền mới không mở lại lỗ hổng. ⚠️ **Lần thứ BA trong cùng ngày** một trần số chữ số biến giá trị lớn nhất thành **hợp lệ đạt tới được** rồi lộ ra bố cục chưa từng thử với giá trị ấy: ở cỡ 48, con số dài nhất **ngắt thành hai dòng** — không sọc vàng, không exception, `Text` chỉ lặng lẽ ngắt dòng, nên ca test phải đo **chiều cao thật**. Mọi ràng buộc khác đã kiểm và an toàn. Đếm lại: **46** mục G, **44** đã đóng, còn **hai** (G18, G23). Cùng ngày, trước đó: **mở rồi đóng G45** — **sáu lỗ hổng của mảng ví**, tìm được bằng một lượt soát đối chiếu **từng ràng buộc PostgreSQL với chốt tương ứng phía client**, không đến từ báo lỗi nào. Nặng nhất: ô nhập số dư không giới hạn chữ số, mà `Balance` là `numeric(15,2)` — tràn cho SQLSTATE `22003`, backend không có nhánh cho mã ấy nên trả `DB_ERROR`, và danh sách lỗi vĩnh viễn của client là **danh sách trắng** nên ví bị **gửi lại ở mọi chu kỳ đồng bộ**. Cùng vòng lặp mà G31 và G14 sinh ra để chặn. Kế đó: `softDelete` không chặn ví gắn **hoá đơn** (server để `ON DELETE RESTRICT`, và đo được **một ví xoá được ngay** trên dữ liệu thật), phép đếm giao dịch bỏ sót **khoản chuyển đến**, thông báo "điều chuyển số dư về 0đ" dẫn tới ngõ cụt từ sau G37, `currency` là cột CHECK duy nhất chưa được `walletForPush` che, và thiếu chốt cấm đặt ví **đã lưu trữ** làm mặc định. ⚠️ Lượt vá sinh ra **hai lỗi nữa, cả hai chỉ máy ảo thấy** — tràn bố cục 70px vì giới hạn mới biến một trạng thái vô nghĩa thành **hợp lệ đạt tới được**, và cỡ chữ không co vì widget mới đọc controller một lần. ⚠️ Một bản sai lật kết luận: thứ chặn tràn là **`Flexible`**, không phải bậc thang cỡ chữ — ép cỡ chữ cố định mà hai ca bố cục **vẫn xanh**. Đếm lại bằng máy: **45** mục G, **43** đã đóng, còn **hai** (G18, G23). Cùng ngày, trước đó: **đóng G44** — kỳ rỗng thì tệp xuất thôi in khối Ngân sách, theo đúng màn Xem trước. Người dùng chốt chiều *"tệp theo màn"*: người cầm tờ PDF không có chỗ hỏi lại rằng con số ấy thuộc kỳ nào. Luật nay là một vị từ thuần **`inKhoiTheoKy`** mà **cả ba** chỗ cùng đọc — CSV, PDF, và màn Xem trước. ⚠️ Lượt sửa **đính chính chính tiêu đề cũ của G44**: màn Xem trước **không** giấu "mọi khối" khi kỳ rỗng, nó vẫn hiện đầu báo cáo, khối Dòng tiền và ba thẻ tổng — hai bên lệch **đúng một khối**. ⚠️ Ca test cho nhánh **PDF** phải so **độ dài tệp** chứ không tìm chuỗi, vì PDF nén luồng nội dung; bản sai có chủ ý làm nó đỏ với chênh lệch **2 847 byte**. Đếm lại bằng máy cùng ngày: **44** mục G, **42** đã đóng, còn **hai** (G18, G23), cả hai hoãn có chủ ý. Cùng lượt, **ngoài phạm vi G44**: ba ca của `os_notifier_native_test.dart` ghi cứng mốc `DateTime(2026, 9, 17, 21, 30)` và `DateTime(2026, 9, 20, 8)` — `flutter_local_notifications` gọi `validateDateIsInTheFuture` và **ném** với mốc đã qua, nên hai ca **đỏ từ sáng 18/09** ở một vùng chẳng ai vừa đụng vào. Nay dùng mốc tương đối; giờ **21:30 giữ nguyên** vì nó là thứ bắt lỗi neo vào UTC) · trước đó **2026-09-17** (**ba khối cuối vào tệp xuất báo cáo** — mục **3.31** `ANALYTICS_FEATURE.md`: PDF/CSV nay có so-với-kỳ-trước, số liệu nhanh, top 5 khoản chi. Lượt này **đóng một lỗi đã chạy từ 2026-09-09** mà không phép đo nào trước đây bắt được — Roboto nhúng cho PDF không có khối Mũi tên lẫn khối Hình học, nên `→` ở dòng dòng tiền bị gói `pdf` bỏ đi **im lặng** trong mọi tệp app từng xuất; nó lộ ra vì bản thiết kế đầu định dùng `▲`/`▼` và **một ca test đỏ đã lật chính bản thiết kế vừa được duyệt**. Và nó **mở G44** — kỳ rỗng thì màn Xem trước giấu mọi khối còn tệp vẫn in khối Ngân sách, chưa rõ bên nào đúng nên hoãn có chủ ý. Đếm lại bằng máy cùng ngày: **44** mục G, **41** đã đóng, còn **ba** (G18, G23, G44), cả ba hoãn có chủ ý. Cùng ngày, trước đó: **đóng G27** — cờ `wallets.allow_negative`, schema **v23**: ví thẻ tín dụng / theo dõi nợ thôi bị nhắc "ví âm" mỗi ngày. ⚠️ Hai bản sai có chủ ý đi lọt ở vòng đầu, **cả hai là lỗ hổng trong chính bộ test vừa viết** — chi tiết ở mục G27. ⚠️ Phép đếm ghi ở đây khi ấy — **43** mục G, **41** đã đóng, còn **hai** (G18, G23) — là **ảnh chụp trước G44** cùng ngày; con số đang đúng nằm ở đầu banner. Cùng ngày, trước đó: **khoản chi lớn** — loại thông báo thứ **18**, mục #7 khảo sát lần hai, mục 5f `NOTIFICATION_FEATURE.md` — **không mở lỗ hổng nào**; khảo sát lần hai nay **đóng**. Cùng ngày, trước đó: **tổng tài sản theo thời gian** — mục #5 khảo sát lần hai, mục 3.30 `ANALYTICS_FEATURE.md` — **không mở lỗ hổng nào**. Nó *đóng* một chỗ chưa ai gọi tên: `daiTrucDuBao` dựng trần rộng gấp đôi mức cần với dải bắt đầu từ 0, thứ **không test nào bắt được** vì mọi tính chất vẫn đúng — chỉ máy ảo thấy; nay siết tại chính hàm ấy, xem bẫy **4.21** vế ba. Cũng lượt này, giả định của mục 3.25 về "vách khoản neo 2026-09-13" bị **phép đo lật**: vách ấy không tồn tại trên dữ liệu thật) · trước đó 2026-09-16 (cuối ngày: **lịch chi tiêu** — mục #6 khảo sát lần hai, mục 3.29 `ANALYTICS_FEATURE.md` — **không mở lỗ hổng nào**; hai chỗ nó suýt để lọt đều bị bản sai có chủ ý và máy ảo bắt tại chỗ, ghi ở mục 3.29 chứ không thành lỗ hổng. Trước đó cùng ngày: mở rồi **đóng G43** — nút "Tuỳ chọn" của bộ chọn phạm vi ném assertion và chết **im lặng** ở đúng trạng thái mặc định của trang, **có sẵn từ P1**; tìm được khi nghiệm thu máy ảo cho **so cùng kỳ năm trước** (mục #2 khảo sát lần hai), thứ **không** mở lỗ hổng nào. Trước đó cùng ngày: mở rồi **đóng G42** trong cùng ngày — ví đã xoá mềm vẫn phình "số dư cuối kỳ" của trang Phân tích; tìm được khi soát tài liệu sau tính năng **dự báo dòng tiền 30 ngày**, thứ **không** mở lỗ hổng nào) · trước đó 2026-09-15 (mở rồi **đóng G41** trong cùng ngày — giao dịch trỏ vào danh mục mặc định toàn cục mất tên, máy ảo lộ ra bằng **hai chip cùng tên**; cùng ngày: **tỉ lệ tiết kiệm** và **A8 #8 dòng tiền tự do** — không mở lỗ hổng nào. Trước đó cùng ngày: mở rồi **đóng G40** — trang Xem trước báo cáo lệch cột số tiền thật, và lệch **93px**, nặng hơn chỗ đã sửa ở trang Phân tích; không phải hai khối mà **sáu**. Cùng ngày: P1 phạm vi thời gian và P2 bốn khối mượn từ trang Báo cáo — **không mở lỗ hổng nào**, schema giữ v22) · trước đó 2026-09-14 (mở rồi **đóng G39** ngay trong ngày — nhãn trục tung khối "Xu hướng 6 tháng" in đè lên nhau, tìm được khi nghiệm thu máy ảo lát A8 #3/#7; mở rồi **đóng G38** ngay trong ngày — ba trang giao dịch rơi về tài khoản admin; **đóng G28** — `wallet.status` đi qua đồng bộ hai chiều, schema v22) · trước đó 2026-09-13 (mở rồi **đóng G37** ngay trong ngày — số dư ví nay suy từ sổ giao dịch; đóng G36) · trước đó 2026-09-11 (sau khi nhánh gộp `main` @ `cc65f4f` và CSDL dev áp `database/12`: đóng G29, G31, G32; G24 thành lỗi phía client rồi đóng cùng ngày; thêm G34; G35 mở rồi đóng cùng ngày; đóng G30; đóng G33); 2026-09-12: gộp `main` @ `cbbeeb4` — CAN-LAM 17 A đóng, kênh thời gian thực nối được trên máy ảo, G34 hết bị chặn rồi **đóng tối cùng ngày** (client nghe `sync.completed`, im lặng, kiểm máy ảo hai máy); chiều muộn thêm **G36** — chờ backend; tối muộn gộp `main` @ `7779999` — backend làm xong CAN-LAM 20 (chốt trả hai lần ở `upsertTransaction`, client đo thật 4 ca; G36 sửa ở mã, **chưa đo đầu-cuối** ca khoá/xoá vì cần API admin — chờ đo rồi đóng); **2026-09-13: đo đầu-cuối ba ca G36 qua API admin — cả ba đúng, G36 ✅ ĐÓNG** (kéo theo: đường `lamMoi` **có** mang `daXoa`, nên ngoại lệ §3.6b không còn vô nghĩa — người dùng chốt **giữ** cùng ngày); cùng ngày, nghiệm thu bước 12 trên hai máy ảo đóng bốn lỗi im lặng của luồng tự động trả hoá đơn và mở **G37** — số dư ví không phản ánh giao dịch sau một lần đẩy bị xung đột
**Mục đích:** ghi lại những hạng mục đã được **cân nhắc và cố ý hoãn**, kèm lý do và bán kính ảnh hưởng. Không có tài liệu này thì người tiếp theo sẽ hoặc bỏ sót, hoặc làm lại từ đầu việc phân tích rủi ro.

Mỗi mục đều ghi rõ **vì sao hoãn** — đó là phần dễ mất nhất.

> ♻️ **Tham chiếu tới `SyncEngine` trong các mục dưới là ảnh chụp trước 2026-10-19.** Ngày ấy `sync_engine.dart` (2.153 dòng) tách thành `SyncEngine` + ba lớp cộng tác (mục lục `core/sync`: `KIEN_TRUC_CLIENT_APP.md` mục 3): `_collectPendingOps` → `ThuGomThaoTacDay.collectPendingOps` (`thu_gom_day.dart`), `_sendBatch` · `_classifyFailure` · `_permanentCodes` · `_markSyncedById` → `GuiLoDongBo` (`gui_lo_dong_bo.dart`), `_pullFromBackend` → `ApDuLieuKeoVe.pullFromBackend` (`ap_du_lieu_keo_ve.dart`; từ 2026-10-20 phần dựng companion từng thực thể — các chốt `Value.absent()` khi server im lặng — ở `anh_xa_keo_ve.dart`), `_resolveCategoryId` → `resolveCategoryId` (`uuid_dong_bo.dart`). Số dòng kiểu `sync_engine.dart:1025` là của tệp cũ — đừng mở theo số; tìm theo tên ký hiệu.

---
> **Phiên 2026-09-03 đã đóng 9/10 mục có lúc đó.** Mô tả gốc bên dưới được giữ
> nguyên (kể cả phần *vì sao hoãn*) vì nó ghi lại bối cảnh và bán kính ảnh
> hưởng — thứ vẫn cần khi ai đó đọc lại đoạn mã tương ứng.
>
> **Đang mở tính tới 2026-09-21.** Mục đã đóng vẫn nằm lại trong bảng, gạch
> ngang tên — xoá đi thì người sau lại mở ra làm lần nữa.
>
> ⚠️ **Bảng này trôi khỏi thân tài liệu năm lần rồi** (G16, G17, G21, G18, G15 — cả năm đều
> ghi *còn mở* trong khi mục tương ứng bên dưới ghi *đã đóng*). Sửa một mục ở
> thân thì **phải sửa dòng của nó ở đây cùng lúc**; đây là bảng người đọc nhìn
> trước tiên nên nó sai là cả tài liệu sai.
>
> | Mục | Vì sao còn mở |
> |---|---|
> | ~~**G10**~~ | ✅ **Đóng 2026-09-07** — mỗi tài khoản nay có bản sao riêng, việc gán nhóm nằm trong `Idgroup` của chính hàng ấy |
> | ~~**G15**~~ | ✅ **Đóng 2026-09-07** — tab "Đã hết hạn" nay phân biệt "đã chốt sổ" với "hỏng, chưa bao giờ lên tới server". ⚠️ Dòng cũ ở đây ghi *hoãn có chủ ý*, mâu thuẫn với chính mục G15 bên dưới — **lần trôi thứ năm**; sửa 2026-09-10 |
> | ~~**G16**~~ | ✅ **Đóng trọn 2026-09-07.** Nguồn tự sinh đóng 2026-09-05; **vế lệch ràng buộc với CSDL cũng đã đóng** — hai partial unique index mới đều có `WHERE "Delete_at" IS NULL`. ⚠️ Dòng cũ ở đây ghi vế ấy *vẫn còn*, mâu thuẫn với chính mục G16 bên dưới; sửa 2026-09-08. Lớp cầm máu `_uniqueConstraintPattern` **vẫn giữ, đừng gỡ** |
> | ~~**G17**~~ | ✅ **Đóng 2026-09-07** — `context.watch<AuthBloc>()` + `key: ValueKey(idaccount)` trên `GoalPage`, có test canh. ⚠️ Dòng cũ ở đây ghi mục này còn mở, mâu thuẫn với chính mục G17 bên dưới; sửa 2026-09-08 |
> | **G18** | ⏸️ **THU HẸP DẦN, không còn chặn ở backend.** Cột `transaction.Idgoal` đã có từ 2026-09-07 và client đẩy/đọc nó; thứ còn lại chỉ là **hàng cũ trên server mang `Idgoal = NULL`**, chúng nhận ID khi được đẩy lại. ⚠️ Dòng cũ ở đây ghi *chặn ở backend*, mâu thuẫn với chính mục G18 bên dưới — **lần trôi thứ tư**; sửa 2026-09-08 |
> | **G19** | **Không phải lỗi** — ghi lại để người sau không "sửa" nhầm |
> | **G23** | Bản sao danh mục chỉ đầy đủ khi bộ mặc định **cục bộ** đầy đủ — pull tăng dần, tự khỏi ở lượt sau |
> | ~~**G24**~~ | ✅ **Đóng 2026-09-11** — client đổi `colour` → `color` ở `categoryForPush` và đọc `c['color']` khi kéo về; server nhận màu (kiểm trên máy ảo: `category.Color = #FF5722`). Danh mục đã `synced` từ trước chỉ lên màu khi được **lưu lại**. ⚠️ Dòng này từng ghi *không có cột, chặn ở backend*, rồi *lỗi phía client, chưa sửa* — đúng tới trước khi gộp `main` và trước bản sửa |
> | ~~**G21**~~ | ✅ **Đóng 2026-09-07** — backend đã có ba cột `auto_deposit_*`, client đẩy và kéo cả ba. ⚠️ Dòng cũ ở đây ghi *chặn ở backend*, mâu thuẫn với chính mục G21 bên dưới; sửa 2026-09-08. Còn đúng một khe hở hẹp: hai máy cùng mở đúng lúc tới kỳ |
> | ~~**G22**~~ | ✅ **MỞ LẠI VÀ LÀM 2026-10-10** (người dùng chọn) — trích mục tiêu và tự trả hoá đơn chạy nền qua WorkManager trên Android, đồng bộ trong lượt nền; spec `specs/2026-10-10-tu-chuyen-tien-chay-nen-design.md`. Giờ vẫn không chính xác tới phút (WorkManager lùi khi máy ngủ sâu); iOS giữ hành vi cũ. Trước đó: *không phải lỗi — giờ trong mốc neo chỉ giữ được một chiều* |
> | **G25** | **Không phải lỗi** — hai máy cùng sắp lại thứ tự ưu tiên khi ngoại tuyến thì được một thứ tự trộn (2026-09-08) |
> | ~~**G26**~~ | ✅ **ĐÓNG 2026-09-18 bằng quyết định sản phẩm** — nhóm **bỏ hẳn** liên kết ngân hàng, nên màn duyệt giao dịch ngân hàng không còn là việc thiếu. Phần client đã gỡ cùng ngày (màn mockup, thẻ ở Quản lý ví, hai route, `RealtimeEvent.giaoDichNganHang`). ⚠️ Đừng viện mục này để mở `status`/`provider` vào hợp đồng đồng bộ — hai cột ấy ở lại ngoài. Trước đó: hoãn có chủ ý vì đây là một tính năng riêng, không phải phần còn thiếu của việc nối socket (2026-09-09) |
> | ~~**G27**~~ ✅ **ĐÓNG 2026-09-17** (cờ `allowNegative`, schema v23) — trước đó: không còn cách nói "ví này **được phép âm**" sau khi loại `debt` bị bỏ; cần một cột mới ở cả hai đầu cho một tình huống CSDL hiện không có hàng nào (2026-09-09) |
> | ~~**G28**~~ | ✅ **ĐÓNG 2026-09-14** — `wallet.status` đi qua đồng bộ **hai chiều**: lưu trữ ví trên máy A nay có hiệu lực trên máy B. Ba mảnh khớp nhau (payload **13 trường**, `walletForPush` dịch sang `'Active'`/`'Inactive'`, nhánh kéo về đọc về chữ thường) cộng **migration v22** đánh dấu ví lưu trữ cũ để đẩy lại — bốn thứ vào **cùng một commit** vì bước cứu chỉ chạy một lần trong đời mỗi máy. ⚠️ Máy chủ chưa áp `database/7` vẫn `varchar(7)` và ví lưu trữ sẽ kẹt hàng đợi đẩy vĩnh viễn, im lặng. Dòng cũ ghi *chờ client mở lại* — đúng tới trước bản này |
> | ~~**G29**~~ | ✅ **Đóng 2026-09-11** — bộ lọc ghi chú mới của `7675b35` (Luhn + hình dạng số thẻ; mật khẩu phải có `:`/`=`; bỏ "pin") chạy đúng **15/15** ca của tài liệu xin, đo bằng chính hàm `filterSensitiveNote` — **chưa** đo đầu-cuối. Còn một hở nhỏ chấp nhận được và một việc cùng gốc ở backend (khoá mã hoá, mục 18 §2.6), không giữ mục này mở. Dòng cũ ghi *chặn ở backend* — đúng tới trước khi gộp `main` |
> | ~~**G30**~~ | ✅ **Đóng 2026-09-11** — `database/12` bỏ `uq_wallet_saving_active` và client gỡ chốt tạm: màn Thêm ví cho chọn "Tiết kiệm" dù đã có một ví Tiết kiệm, datasource không còn từ chối. ⚠️ Máy chủ nào chưa áp tệp 12 vẫn từ chối ví Tiết kiệm thứ hai. Chốt **trùng tên ví** ở lại vĩnh viễn |
> | ~~**G31**~~ | ✅ **Đóng 2026-09-11** — backend nay ánh xạ `22001`/`P2000` (dài quá cột) và `23502` về `CONSTRAINT_VIOLATION`, mã client đã xếp **vĩnh viễn**, nên bản ghi bị chặn theo thời gian thay vì gửi lại mãi; và một thao tác hỏng không còn làm **cả lô** 400. Bộ lọc bảy ô tên của client (2026-09-10) **vẫn giữ** — nó chặn trước để bản ghi không kẹt ngay từ đầu. Đo trên mã HEAD, chưa chạy đầu-cuối. Dòng cũ ghi *chặn ở backend* — đúng tới trước khi gộp `main` |
> | ~~**G32**~~ | ✅ **Đóng 2026-09-11** — backend giữ `priority: null` khi đẩy (hết `Number(null)` → `0`), nhánh tạo mặc định `null`, và `database/12` đã đưa các hàng `<= 0` về `NULL` trên CSDL dev. Lớp đọc `<= 0` là chưa sắp phía client **vẫn giữ** cho dữ liệu cũ và bản backend/client cũ. Dòng cũ ghi *chặn ở backend* — đúng tới trước khi gộp `main` |
> | ~~**G33**~~ | ✅ **Đóng 2026-09-11** — tài khoản chờ xoá nay dùng tiếp app trong 30 ngày thay vì bị đăng xuất ngay: `UserModel` mang `status`/`countdown`, trang Xoá tài khoản thôi hứa *"đăng nhập lại là tự khôi phục"*, hai thẻ (Trang chủ, "Vùng nguy hiểm" ở Cài đặt) hiện số ngày còn lại và nút huỷ. Kiểm trên máy ảo với tài khoản 11. Dòng cũ ghi *lỗi đang chạy, chưa sửa* — đúng tới trước bản sửa |
> | ~~**G34**~~ | ✅ **ĐÓNG 2026-09-12 tối** — client dịch `sync.completed` → `RealtimeEvent.dongBoXong`, đánh thức `syncNow()`, **im lặng** (không toast: máy vừa đẩy cũng nhận lại sự kiện của mình và payload là hộp đen nên toast sẽ nói sai). Kiểm máy ảo hai máy cùng tài khoản: máy kia kéo về **cùng giây** backend phát. Trước đó: mở 2026-09-11, chặn bởi 17 A tới sáng 2026-09-12 |
> | ~~**G36**~~ | ✅ **ĐÓNG 2026-09-13 — đo đầu-cuối ba ca qua API admin, cả ba đúng; client không đổi mã.** `Active` → 200; admin khoá → **401 + `ACCOUNT_INACTIVE`** kèm `idaccount` + `reason_inactive` ở cấp gốc; admin xoá mềm → **401 + `ACCOUNT_DELETED`** kèm `idaccount`, **dù 4/4 refresh token đã bị thu hồi** — đúng thứ CAN-LAM 20 §2.7 sửa (nhánh token thu hồi gọi `getAccountValidity` trước khi ném). Mô tả gốc: tài khoản bị xoá qua admin trong lúc app giữ token hết hạn và không có socket → `/auth/refresh` trả 401 **không mã** → app đăng xuất **trơn, không hộp thoại** (đo thật 2026-09-12 chiều). ⚠️ Kéo theo: đường `lamMoi` **CÓ** mang `daXoa`, nên ngoại lệ §3.6b không còn vô nghĩa — xem mục G36 |
> | ~~**G35**~~ | ✅ **Đóng 2026-09-11** — ba màn quản lý danh mục nay lấy tài khoản qua `currentAccountIdOrNull`: chưa có phiên thì không đọc gì (kể cả tài khoản 0 — bộ khuôn toàn cục), và nút lưu/xoá báo "Chưa xác định được tài khoản đăng nhập". Test quét `lib/` cấm `?? 1` nhiều dòng. ⚠️ Dòng này từng ghi *lỗi đang chạy, chưa sửa* — đúng tới trước bản sửa |
> | ~~**G38**~~ | ✅ **Mở rồi ĐÓNG 2026-09-14** — ba trang giao dịch (`transaction_page`, `choose_category_page`, `add_transaction_page`) khai `this.idaccount = 1` rồi dùng `?? widget.idaccount`, nên khi phiên chưa sẵn sàng chúng **đọc** ví/danh mục của admin và — nặng nhất — **GHI** giao dịch dưới danh nghĩa admin. Cùng họ G4/G35 nhưng khác hình dạng nên lọt cả hai lượt đóng ấy. Nay dùng `int?` không mặc định + `null` thì chặn; lưới quét `khong_du_phong_admin_test.dart` thêm ca thứ hai bắt đúng dạng này. Nghiệm thu máy ảo: giao dịch ghi vào `Idaccount = 25`, tài khoản 1 không có hàng nào |
> | ~~**G39**~~ | ✅ **Mở rồi ĐÓNG 2026-09-14** — nhãn trục tung của khối "Xu hướng 6 tháng" in **đè lên nhau** ở một số dải giá trị: đo trên máy ảo thấy "63.2K" và "63.3K" chồng khít. Gốc rễ là `3 * (maxY / 3) != maxY` trong dấu phẩy động rơi đúng ranh giới làm tròn của `rutGon`, nên **cùng một vị trí** ra hai chuỗi. Sửa: tính `buoc` trước rồi đặt `maxY = buoc * 3`. **Có sẵn từ lát 2b (2026-09-08)**; lát A8 #3/#7 chỉ làm dễ gặp hơn. Ca test tái hiện được **ngay trong widget test**, không cần máy thật |
> | ~~**G37**~~ | ✅ **ĐÓNG 2026-09-13** — số dư ví nay là **cache của tổng sổ giao dịch**, không còn là giá trị tuyệt đối đồng bộ theo LWW. Điểm neo là một giao dịch "Số dư ban đầu" (id suy **tất định** từ `walletId` nên hai máy sinh ra một hàng), `SoDuViService` là nơi duy nhất ghi `balance`, nhánh kéo về thôi đọc cột ấy và tính lại sau mỗi lần pull. Nghiệm thu hai máy ảo: sau một cuộc đua tự trả, **hai máy đều 1.650.000 và bằng tổng sổ** — trước đó máy thắng giữ 2.000.000. Spec: `2026-09-13-so-du-vi-suy-tu-so-giao-dich-design.md` |
> | ~~**G40**~~ | ✅ **ĐÓNG 2026-09-15** — trang **Xem trước báo cáo** lệch cột số tiền thật, và **nặng hơn** chỗ đã sửa ở trang Phân tích: đo trên máy ảo thấy khối "Chi theo danh mục" lệch **93px** (trang Phân tích chỉ 26,5px). Và không phải **hai** khối như dòng này từng đoán mà **sáu** — thêm ngân sách, thu/chi theo danh mục, danh sách giao dịch, và hàng "Thay đổi trong kỳ" của khối dòng tiền. Sáu `Flexible` đổi thành `Expanded`; đo lại trên máy ảo: lệch **0px** ở mọi khối. Sáu ca test mới, và chúng chỉ canh được gì khi chạy ở **khổ gấp đôi** — xem bẫy 4.19 |
> | ~~**G43**~~ | ✅ **Mở rồi ĐÓNG 2026-09-16** — nút **"Tuỳ chọn"** của bộ chọn phạm vi **không làm gì cả, hoàn toàn im lặng**, ở đúng trạng thái **mặc định** của trang. `showDateRangePicker` ném assertion vì `initialDateRange` thò ra ngoài `[firstDate, lastDate]`: kỳ "Tháng này" kết thúc 30/09 trong khi `lastDate` là hôm nay 16/09. Đó là exception **bất đồng bộ không ai bắt** — không toast, không màn đỏ, chỉ một dòng logcat người dùng không bao giờ thấy. **Có sẵn từ P1 (2026-09-15)**; lượt nghiệm thu máy ảo của mục #2 mới chạm vào nút ấy. Phép kẹp nay là hàm thuần `khoangKhoiTaoBoChonNgay` có test riêng |
> | ~~**G42**~~ | ✅ **Mở rồi ĐÓNG 2026-09-16** — ví **đã xoá mềm** vẫn được cộng vào "số dư cuối kỳ" của khối Dòng tiền và thác nước (đo được **7.000.000** trên một ví thử). `AnalyticsRepositoryImpl` đọc ví bằng truy vấn thẳng **không lọc `deletedAt`** — cố ý, vì bảng tra tên cần hàng đã xoá — rồi cộng `balance` qua `viTinhVaoTong`, hàm khi ấy chỉ kiểm `includeInTotal` và trạng thái lưu trữ. Đây là **bản chép tay thứ năm** của đúng luật mà `vi_tinh_vao_tong_test.dart` sinh ra để chặn, chỉ khác vế. Sửa bằng cách đưa vế `isDeleted` **vào chính hàm** (mặc định `false`), không vá ở chỗ gọi |
> | ~~**G41**~~ | ✅ **Mở rồi ĐÓNG 2026-09-15** — giao dịch trỏ vào **danh mục mặc định toàn cục** mất tên, hiện thành "Danh mục đã xoá". `sync_engine` quy `is_default = true` thành **`idaccount = 0`**, nhưng cả hai repository tra danh mục lọc đúng một `idaccount` — mỗi nơi một bản chép tay của cùng truy vấn. Máy ảo lộ ra vì khối Xu hướng hiện **hai chip cùng một tên**; truy vấn PostgreSQL xác nhận tài khoản 10 có đúng hai danh mục như thế (`Chi khác`, `Làm thêm`, cùng bị backend xoá mềm hôm 2026-09-07). Nay có **một** định nghĩa `categoryDao.getBangTraTen` lọc theo **cờ `isDefault`**, cả hai repository dùng chung. Ảnh hưởng rộng hơn chip: donut, thác nước và danh sách danh mục đều mất tên |
> | ~~**G44**~~ | ✅ **ĐÓNG 2026-09-18** — kỳ rỗng thì tệp xuất in bảng *Ngân sách kỳ này* mà màn Xem trước giấu, vì ngân sách là khối **duy nhất** không tự rỗng theo một kỳ rỗng. Người dùng chốt chiều **"tệp theo màn"**; luật nay là vị từ thuần `inKhoiTheoKy` mà cả CSV, PDF lẫn màn Xem trước cùng đọc. ⚠️ Lượt sửa đính chính chính tiêu đề cũ: màn **không** giấu "mọi khối" — đầu báo cáo, khối Dòng tiền và ba thẻ tổng vẫn hiện, nên hai bên lệch **đúng một khối**. ⚠️ Ca PDF so **độ dài tệp** chứ không tìm chuỗi (PDF nén luồng nội dung); bản sai làm nó đỏ với **2 847 byte** chênh lệch |
> | ~~**G45**~~ | ✅ **Mở rồi ĐÓNG 2026-09-18** — sáu lỗ hổng của mảng ví tìm bằng lượt soát đối chiếu từng ràng buộc PostgreSQL với chốt phía client; nặng nhất là ô số dư không giới hạn chữ số (numeric(15,2) → 22003 → gửi lại mọi chu kỳ). *(Dòng này thêm 2026-09-19 — bảng từng trôi khỏi thân, thiếu G45 và G46.)* |
> | ~~**G46**~~ | ✅ **Mở rồi ĐÓNG 2026-09-18** — trần số chữ số thiếu ở bốn mảng còn lại (giao dịch, hoá đơn, mục tiêu, ngân sách); bàn phím tự vẽ của giao dịch nặng nhất. Test quét `lib/` thứ tám canh ô tiền mới |
> | ~~**G47**~~ | ✅ **Mở rồi ĐÓNG 2026-09-19** — thẻ **hoá đơn** và bảng tra tên của **ngân sách** mất tên danh mục mặc định toàn cục / đã xoá mềm: cùng họ G41 nhưng ở ba bản chép tay khác (`BillPage`, `BillDetailPage`, `BudgetLocalDataSourceImpl.getAllCategories`) vẫn gọi `categoryDao.getAll`. Máy ảo: 2/3 thẻ hoá đơn hiện "Danh mục đã xoá". Cả ba về `getBangTraTen` |
> | ~~**G48**~~ | ✅ **Mở rồi ĐÓNG 2026-09-21** — đường tắt "Xem giao dịch" của màn Quản lý ví **thôi lọc sẵn ví** nếu tab Giao dịch đã mở trước đó trong phiên: `_filter` lấy `initialWalletId` trong **field initializer**, mà State của nhánh shell còn sống nên `initState` không chạy lại; hỏng im lặng, người dùng thấy sổ đầy đủ và tưởng ví ấy có chừng ấy khoản. **Không** phải hồi quy của lát cùng ngày — có từ nhóm D (2026-09-19). Sửa bằng `didUpdateWidget`, chỉ áp khi ví **khác lần trước**, và `null` **không** đọc là "bỏ lọc". Nghiệm thu máy ảo đúng kịch bản từng hỏng |
> | ~~**G49**~~ | ✅ **Mở rồi ĐÓNG 2026-09-29** — thẻ tổng **Sổ giao dịch** cộng thô theo `type` nên đếm cả khoản *"Điều chỉnh số dư"*: Thu nhập 15.145.000 trong khi Trang chủ / Phân tích / trợ lý AI nói 15.135.000 (Realme). Bước 1a sửa Trang chủ mà để sót chỗ này. `summarizeTransactions` nay đi qua `khoanVaoThongKe`; hàng điều chỉnh vẫn hiện trong danh sách, không cộng vào thẻ. Cùng ngày: tiêu đề nhóm ngày cũng đi qua hàm ấy |
> | ~~**G50**~~ | ✅ **Mở rồi ĐÓNG 2026-09-29** — cặp nạp mục tiêu **dạng cũ** (thu *"Tích lũy nhận từ …"* + chi *"Tích lũy mục tiêu: …"*, không danh mục, trước 05/09) được tính là thu **và** chi ở mọi màn: chi tháng 9 tài khoản 10 2.351.000 thay vì 1.851.000. `khoanVaoThongKe` nay loại hai nửa (`laNuaCapNapMucTieuCu`, cặp dấu hiệu); một cặp duy nhất trên PostgreSQL dev |
> | ~~**G51**~~ | ✅ **Mở rồi ĐÓNG 2026-09-29** — số tiền trên **thẻ hoá đơn** bị cắt ở 360 dp (*"45.0…"*, *"3.00…"*): `Flexible(Text(amount))` đứng cùng hàng với một `Spacer`, cả hai `flex: 1`, nên số tiền chỉ được **một nửa** chỗ trống. Có từ trước B2, lộ khi nghiệm thu B2 trên Realme. Sửa `77521f2`: [số tiền · bút · thùng rác] trong một `Expanded`. Mục chi tiết bên dưới |
> | ~~**G52**~~ | ✅ **ĐÓNG 2026-10-09** (G74 xử lý nửa ngày hạn; dòng danh mục • ví nay trải rộng dưới chip) — ⏸️ hoãn 2026-09-29 (người dùng chốt) — hai chỗ bố cục nhỏ của **đầu thẻ hoá đơn** ở 360 dp, có từ trước: dòng *"Hạn 05/10/2026"* xuống hai dòng khi đứng cạnh chip *"CHƯA THANH TOÁN"*, và tên ví trong dòng phụ bị cắt (*"Nhà cửa • Tiền…"*). Thông tin vẫn đọc được. Mục chi tiết bên dưới |
> | ~~**G53**~~ | ✅ **Mở rồi ĐÓNG 2026-09-29** — nhãn trục tung của thác nước *"Tiền đi đâu"* (trang Phân tích) **in đè lên nhau** (*"5.9M"* chồng *"5.5M"*) khi số dư đầu kỳ **âm**: `minY = lo` âm không phải bội của bước, fl_chart vẽ mốc tại bội của `interval` **cộng** hai biên. Có từ trước, lộ khi nghiệm thu B3 trên Realme. Sửa bằng hàm thuần `daiTrucCot` (sàn, trần là bội của bước tròn, trục chứa 0, 3–5 khoảng); Realme nay in *5M · 0 · −5M · −10M · −15M*. Mục chi tiết bên dưới |
> | ~~**G54**~~ | ✅ **Mở rồi ĐÓNG 2026-09-29** — nhãn **trục hoành** thác nước *"Tiền đi đâu"* dính nhau ở 360 dp (*"chuyểnphân l…"*): ô nhãn thẳng 32 dp hai dòng, trong khi chín cột ở 360 dp mỗi cột chỉ còn ~27 dp. Có từ trước (A8 #10 chỉ tính cho 411 dp), lộ trong ảnh nghiệm thu G53. Nay nhãn **xoay −35°, một dòng** đúng màn Stitch `52450ac5…` (người dùng chọn), đầu phải neo tâm cột. Mục chi tiết bên dưới |
> | ~~**G55**~~ | ✅ **Mở rồi ĐÓNG 2026-09-29** — chấm của kỳ đầu và kỳ cuối trên **bốn biểu đồ đường** (Xu hướng, Dòng tiền tự do, Tổng tài sản, Tiến độ mục tiêu) bị **cắt mất nửa** vì `FlClipData.all()` cắt đúng theo mép vùng vẽ. Có từ trước. Nay `FlClipData.vertical()` — người dùng chọn giữ phòng thủ bẫy 4.17 cho trục dọc, nên chấm giá trị 0 ở đáy khối Xu hướng **vẫn** cắt nửa (cố ý). Mục chi tiết bên dưới |
> | ~~**G56**~~ | ✅ **Mở rồi ĐÓNG 2026-09-29** — tuần có thu nhập gần 0 cho *"chi vượt thu nhập 26360,0%"* (khối Nhận xét), *"Để dành −26360% thu nhập"* (thẻ Số dư còn lại) — đúng mà không đọc được. Nay từ **2 lần** thu nhập trở lên nói *"chi gấp N lần thu nhập"* (người dùng chọn), một hàm `soLanChiGapThuNhap` cho cả ba chỗ kể cả tool tổng quan của Trợ lý AI. Mục chi tiết bên dưới |
> | ~~**G57**~~ | ✅ **Mở rồi ĐÓNG 2026-09-29** — trang Hoá đơn: nút rộng cố định *"Tạo hóa đơn lặp lại mới"* đè lên hàng tab ở 360 dp khi có thẻ khoản lặp. Nay nút **+** ở góc phải thanh tiêu đề, đúng màn Stitch `e8b460b4…` (người dùng chọn). Mục chi tiết bên dưới |
> | ~~**G58**~~ | ✅ **Mở rồi ĐÓNG 2026-09-29** — màn **Thêm giao dịch** ở 360 dp: gõ ghi chú (bàn phím hệ thống mở) thì hàng phím cuối của bàn phím số tự vẽ **tràn 9,7 px** và ô ghi chú đang gõ bị ép về **0** — người dùng gõ mà không thấy chữ. Có từ nhóm C UX (`2263f9b`, 19/09 — bàn phím neo đáy). Người dùng thấy giữa lượt nghiệm thu B4. Nay bàn phím hệ thống mở thì **không dựng 16 phím số** (người dùng chọn). Mục chi tiết bên dưới |
> | ~~**G59**~~ | ✅ **Mở rồi ĐÓNG 2026-09-29** — đổi **giờ nhắc** (hoá đơn, ghi chép, giờ/thứ tổng kết) ở trang Cài đặt thông báo **không dời** lịch đã đặt: khoá lịch không chứa giờ nên cùng id, `resync` bỏ qua id đang chờ — tới 30 ngày nhắc hoá đơn vẫn nổ giờ cũ. Có từ lát 5/7 thông báo; lộ khi soát kế hoạch B5b (nút "Đổi sang …" đi đúng đường ấy). Nay `resync(datLai: true)`, trang gọi khi một trường mốc đổi (người dùng chọn sửa trước B5b). Mục chi tiết bên dưới |
> | ~~**G60**~~ | ✅ **Mở rồi ĐÓNG 2026-09-29** — bảng chọn **thứ** tổng kết tuần (7 dòng, ~392 dp) tràn ở màn thấp: bottom sheet mặc định chỉ cao 9/16 màn, nên máy cao dưới ~700 dp (vd. 360 × 640) tràn; widget test ở 800 × 600 đo **55 px**. Realme (800 dp) không lộ. Có từ lát Tổng kết tuần (2026-09-09); lộ khi viết ca G59. Người dùng chọn sửa: `isScrollControlled` + thân cuộn được. Mục chi tiết bên dưới |
> | ~~**G61**~~ | ✅ **Mở rồi ĐÓNG 2026-10-01** — **không còn lối vào trang nhập từ khoá**: nút *"Từ khóa của tôi"* chỉ có ở hàng của mục *Danh mục mặc định* (`_defaultRow`), mà `CategoryManagementRepository.watchTree` trả `defaultChildren: const []` cho mọi tài khoản từ 2026-09-07; form *Chỉnh sửa danh mục* (`_formBody`) nạp và giữ từ khoá nhưng **không vẽ** `_KeywordsEditor`. Người dùng chỉ thêm được từ khoá qua dòng *đề xuất thêm từ khoá* (2026-09-30), và **không gỡ được** từ khoá nào. Nay form Thêm / Chỉnh sửa danh mục có khối *Từ khóa nhận diện* (6 ca test), nghiệm thu Realme. Mục chi tiết bên dưới |
> | ~~**G62**~~ | ✅ **Mở rồi ĐÓNG 2026-10-02** — hàng **sáu ô OTP** tràn ở máy 360 dp (*"RIGHT OVERFLOWED BY 6.9 PIXELS"*, OnePlus 13R, người dùng báo khi đăng ký): sáu `SizedBox(width: 45)` = 270 dp cứng trong ~263 dp; cả màn OTP đăng ký lẫn quên mật khẩu. Nay là widget chung `HangOOtp` (ô co được, khe 6 dp); sáu ca `o_otp_khong_tran_test.dart`. Chưa nhìn lại trên máy thật |
> | ~~**G63**~~ | ✅ **ĐÓNG 2026-10-05 tối** — ví trùng tên giữa hai máy cùng tài khoản: ví bị từ chối nay được **giữ** khỏi lô đẩy cùng mọi thứ dính tới nó, màn Quản lý ví có thẻ **VÍ TRÙNG TÊN** với **Gộp / Đổi tên** và nhãn CHƯA ĐỒNG BỘ, Trang chủ có dòng nhắc có ✕; Sửa ví lưu được khi máy có hai ví cùng tên; kéo về chỉ còn một ví mặc định. Nghiệm thu hai máy ảo bắt và sửa hai lỗi (vòng đồng bộ nóng ở bước 1b · máy kia kéo thiếu sau Đổi tên). Mục chi tiết bên dưới
> | ~~**G64**~~ | ✅ **Mở rồi ĐÓNG 2026-10-03** — mục *Đăng xuất* ở drawer Trang chủ hiện hộp thoại nhưng bấm xác nhận **không làm gì** (context của drawer bị gỡ khi drawer đóng; có sẵn từ 2026-09-19). Nay drawer tự đóng + tự hỏi bằng context của Scaffold (`c2d6985`); nghiệm thu Realme. Mục chi tiết bên dưới |
> | ~~**G65**~~ | ✅ **Mở rồi ĐÓNG 2026-10-03** — dải *"Đã xoá thông báo · Hoàn tác"* **không tự ẩn**, đi theo qua mọi màn (Flutter 3.47 giữ SnackBar có `action`). Nay `persist: false` (`c18e095`); nghiệm thu Realme. Mục chi tiết bên dưới |
> | ~~**G66**~~ | ✅ **Mở rồi ĐÓNG 2026-10-04** — ngân sách bắt đầu ngày **29–31** trôi hẳn về ngày đã kẹp **từ kỳ thứ hai** (31/01 → 28/02 → 28/03 → 28/04…), vì mọi kỳ sau nhảy từ mốc neo **đã kẹp**. Nay **`BudgetEntity.mocKy(s)`** là định nghĩa duy nhất của lưới kỳ, nhảy `s + 1` chu kỳ **từ ngày bắt đầu** (`02d46ca`): 28/02 → 31/03 → 30/04. Dữ liệu thật không có ngân sách nào dính. Mục chi tiết bên dưới |
> | ~~**G67**~~ | ✅ **ĐÓNG 2026-10-08** (nghiệm thu hai máy ảo, tài khoản 27, hai lượt; đơn 37 + 40 backend đóng; CSDL dev áp `database/21`; client lấy mốc từ `maxSince` qua `mocTuMaxSince` — lớn nhất giữa các bảng, kẹp `pulledAt − 2 phút` — khoá lưu `_v2` ép kéo toàn bộ một lần) — **kéo về bỏ sót bản ghi lên server muộn hơn giờ ghi của nó**: `/sync/pull` lọc `update_at > since` mà `update_at` là giờ ghi **của máy** (cũng là khoá LWW), nên bản ghi của một máy offline lâu rồi đẩy muộn rơi dưới mốc của máy khác và **không bao giờ** được kéo — im lặng, không tự lành. Đo trong nghiệm thu G63. Ca G63 đã chữa ở client (`ThaViBiGiu`); ca chung cần backend. Mục chi tiết bên dưới |
> | ~~**G68**~~ | ✅ **Mở rồi ĐÓNG 2026-10-06 khuya** — thanh điều hướng dưới tràn *"RIGHT OVERFLOWED BY 40 PIXELS"*, tab **Cá nhân** bị đẩy khỏi màn ở mọi trang khi nâng cỡ chữ/hiển thị ColorOS. **Gốc: không phải chữ to** — năm ô rộng CỐ ĐỊNH 72 dp (bốn tab + chỗ nút +) cộng **đúng 360 dp**, và ColorOS phóng bằng cách đổi **mật độ** (`wm density` đo: *Override density 540*, `font_scale` vẫn 1.0) → 1080 px còn **320 dp**, thiếu đúng 40. Vế tiềm ẩn cùng họ: chữ ×1,5 làm nhãn xuống hai dòng, tràn đáy ô 64 dp 16 px. Sửa `main_shell.dart`: bốn tab `Expanded`, nền chọn **tối đa** 72 dp, nhãn một dòng `FittedBox.scaleDown`; luật nhãn ≤ 9 ký tự giữ (dài hơn bị thu nhỏ). Test `test/shared/widgets/main_shell_thanh_duoi_hep_test.dart` (6 ca: 360/320/300 dp × chữ 1,0/1,3/1,5, font thật — mã cũ đỏ đúng 40 và 60 px). Nghiệm thu Realme 320 dp: đủ bốn tab, bấm được *Cá nhân* / *Phân tích*. ⚠️ ColorOS chặn cả `wm density` (`WRITE_SECURE_SETTINGS`) — đổi cỡ hiển thị phải nhờ người dùng |
> | ~~**G69**~~ | ✅ **Mở rồi ĐÓNG 2026-10-06 khuya** — header Phân tích **nhảy từ một lên hai hàng** lúc tải xong ở 360 dp: ô kỳ lúc tải nói `ky.nhanNgan` (*"T10 2026"*, vừa một hàng) còn tải xong nói `nhanOChon` (*"Tháng này (T10 2026)"*, không vừa → hai hàng). Gốc: `AnalyticsLoading` không mang mốc nên không dựng được nhãn thật. Nay nó mang **`moc`** (cùng `now` mà `AnalyticsLoaded` sẽ mang) và ô kỳ dùng `nhanOChon` ở cả hai pha. Ca `⭐ G69` cuối nhóm G2 `analytics_page_test.dart` (font thật, so khung ô kỳ trước/sau). Nghiệm thu Realme: khung chờ đã hiện đúng *"Tháng này (T10 2026)"*, header đứng yên |
> | ~~**G70**~~ | ✅ **Mở rồi ĐÓNG 2026-10-06 khuya** — form **Thêm ví bật sẵn *"ví mặc định"*** nên tạo ví mới âm thầm cướp vai mặc định của ví cũ. Người dùng chốt: **tắt sẵn, trừ khi tài khoản chưa có ví nào đang hoạt động** (ví đầu tiên / chỉ còn ví lưu trữ → bật). `wallet_add_page.dart`: `_isDefault = false`, `_napViHienCo` bật lại khi không ví nào `!isDeleted && WalletStatus.laHoatDong`; `_daGatMacDinh` để lượt nạp muộn không đè lựa chọn của người dùng. Nhóm `G70` ở `wallet_add_guard_ui_test.dart` (4 ca). Nghiệm thu Realme: công tắc tắt sẵn |
> | ~~**G71**~~ | ✅ **Mở rồi ĐÓNG 2026-10-06 khuya** — thông báo số dư của **ví đã xoá** không tự gỡ. Gốc: bộ quét đọc ví qua `walletDao.getAll` (lọc bỏ `deletedAt`) nên ví đã xoá chỉ **biến mất**, và `hangSapCanDaHoi` / `hangAmDaHoi` cố ý *"không biết ví thì không đoán"*. Nay loader **`loadViDaXoa`** (`WalletDao.idDaXoa` — id ví CSDL ghi rõ đã xoá mềm, kể cả kéo về từ máy khác) + hàm thuần **`hangCuaViDaXoa`** (`subjectType == 'wallet'`) gỡ ở cùng chỗ, chạy cả khi danh sách ví rỗng; chỉ đọc khi còn hàng ví chưa gỡ. Ví vắng mà không ghi đã xoá → vẫn không đoán. Test: `notification_rules_goal_wallet_test` (2) · `notification_scanner_test` (2, đỏ trên bản sai) · `core/database/wallet_id_da_xoa_test` (2). ⚠️ **Chưa nghiệm thu máy thật** (dựng ví thử có cảnh báo rồi xoá là chuỗi dài trên máy người dùng) |
> | ~~**G72**~~ | ✅ **Mở 2026-10-06, ĐÓNG 2026-10-07** — ba thẻ **Thu nhập / Chi tiêu / Thu net** ở Trang chủ **lệch chiều cao** ở màn hẹp: nhãn *"Thu nhập"* xuống hai dòng, và mỗi số tiền tự co bằng `FittedBox` **riêng** nên ba con số co theo ba tỉ lệ khác nhau. Nay `TheSoLieuThang` đo một lần (`doRongChu`) và dùng **chung một cỡ chữ** cho cả ba số tiền và chung một cỡ cho ba nhãn — cỡ lớn nhất (≤ 16 / ≤ 13) mà cả ba vừa ô; màn đủ chỗ giữ cỡ cũ. ⚠️ Cỡ ước **theo tỉ lệ** chưa đủ: bề rộng chữ không tỉ lệ thuận đúng với cỡ chữ, nên phải **đo lại** ở cỡ đã tính và lùi 0,1 tới khi vừa (bản đầu cắt *"+13.590.000 đ"*). Test `the_so_lieu_thang_hep_test.dart` (5 ca, font thật 300/320/411; mã cũ đỏ 4 ca); ba ca cũ `the_so_lieu_thang_test.dart` vẫn xanh. ✅ Nghiệm thu Realme 2026-10-07 tối (mật độ 540 = 320 dp, bản debug `e1ce2b38…`) |
> | ~~**G73**~~ | ✅ **Mở rồi ĐÓNG 2026-10-07** — hàng **"CHỌN BIỂU TƯỢNG"** ở form Thêm ví tràn *"RIGHT OVERFLOWED BY 40 PIXELS"* ở màn 320 dp (Realme, mật độ 540 — lộ lúc nghiệm thu G70). Cùng họ G68: biểu tượng đang chọn 48 dp + bốn ô **cố định** 40 dp kèm lề 12 dp = 256 dp, không ô nào co. Nay bốn ô là `Expanded` chia đều phần còn lại. Ca `G73` 360/320/300 dp ở `wallet_add_guard_ui_test.dart` (mã cũ đỏ đúng 40/60 px). Nghiệm thu Realme 320 dp đạt. ⚠️ Họ lỗi này (hàng ô rộng cố định cộng vừa khít 360 dp) có thể còn ở màn khác — chưa quét cả app |
> | ~~**G74**~~ | ✅ **Mở rồi ĐÓNG 2026-10-07** (quét Realme 320 dp, mật độ 540) — **thẻ hoá đơn** trang Hoá đơn: số tiền chỉ còn *"100.0…"*, ngày hạn **gãy** *"Hạn 12/1 ⏎ 0/2026"*, tên *"Kiem t…"*. Đo font thật ở 320 dp: chip *"CHƯA THANH TOÁN"* 110 dp để cột chữ 68 dp (ngày cần 107); nút *Thanh toán* 128 dp để số tiền 58 dp (cần 74) — ở 360 dp số tiền vừa **khít** 74/74, G51 chỉ đo ở đó. Người dùng chọn **chỉ xếp chồng khi chật**: `BillStatusHeader` và hàng số tiền (`_HangSoTien` trong `bill_page.dart`) **đo bề rộng thật** bằng `doRongChu` (`core/ui/do_chu.dart` — tách từ `_doChu` của header Phân tích G2, nay một định nghĩa) — không vừa thì chip xuống dưới cột chữ, số tiền lên dòng riêng trên hàng [bút · thùng rác · nút]; màn đủ chỗ giữ dáng cũ. ⚠️ Thẻ bỏ `IntrinsicHeight` (vạch màu nay là `Positioned` trong `Stack`): `LayoutBuilder` không trả được kích thước nội tại, bọc nó là lỗi ở mọi khung (lượt test đầu treo). Test `bill_page_hep_test.dart` (8 ca, font thật, 300/320/360 dp; mã cũ đỏ 5 ca). ✅ Nghiệm thu Realme 2026-10-07 tối (mật độ 540 = 320 dp, bản debug `e1ce2b38…`) |
> | ~~**G75**~~ | ✅ **Mở rồi ĐÓNG 2026-10-07** — thẻ **ngân sách ở Trang chủ** (`home_budget_card.dart`): *"Đã dùng 10.000 đ / 50…"* — **mất hạn mức**; dòng nhịp *"Nên chi 19.600 đ/ngày · còn 25 ng…"* cũng cụt (cả hai `maxLines: 1` + ellipsis). Cùng nguyên tắc G74 (chỉ đổi khi chật): dòng *"Đã dùng"* **đo bề rộng thật** (`doRongChu`), không vừa thì tự ngắt thành *"Đã dùng X"* ⏎ *"/ Y"* — ⚠️ **không trông vào bộ ngắt dòng**: Unicode cấm ngắt TRƯỚC *"/"* kể cả sau dấu cách (LB13), nên cả cụm *"1.250.000 đ / 3.000.000 đ"* thành một khối và bị cắt ở 300 dp. Dòng nhịp `maxLines: 2`, `budgetPaceLine` nay dính liền *"còn N ngày"* và số tiền bằng U+00A0 (ngắt rơi sau *"·"*; trang Ngân sách và chi tiết dùng chung câu ấy). `CurrencyFormatter.formatLienKhoi` mới (như `format`, số và `đ` không ngắt). Test `home_budget_card_hep_test.dart` (5 ca, font thật 300/320/411; mã cũ đỏ 3 ca). ✅ Nghiệm thu Realme 2026-10-07 tối (mật độ 540 = 320 dp, bản debug `e1ce2b38…`) |
> | ~~**G76**~~ | ✅ **Mở rồi ĐÓNG 2026-10-07** — tab trang Ngân sách *"Đang hoạt động (4"* mất dấu đóng ngoặc (`budget_tabs_view.dart`); thẻ mục tiêu *"2.000.000 đ55.0%"* — phần trăm **dính sát** số tiền (`goal_page.dart`, `Row(spaceBetween)` không phần nào co; 300 dp thì tràn 11–48 px). Tab: nhãn `_NhanTab` co nhẹ bằng `FittedBox.scaleDown` (cùng cách G68). Mục tiêu: `_HangTienMucTieu` **đo bề rộng thật** (`doRongChu`) — không vừa thì *"/ đích"* xuống dòng dưới số đã có, phần trăm vẫn to bên phải (người dùng chọn); màn đủ chỗ giữ dáng cũ. ⚠️ `Tab` dựng chữ với `overflow: fade` nên hộp chữ luôn gọn trong ô — ca test phải so **bề rộng cần** của chữ, so mép hộp thì xanh cả với mã cũ. Roboto của bộ test hẹp hơn Inter: ca mục tiêu 320 dp phóng chữ ×1,1 để chừa biên. Test `budget_tabs_hep_test.dart` (3 ca) · `goal_page_hep_test.dart` (4 ca), font thật; mã cũ đỏ 2 + 3 ca. ✅ Nghiệm thu Realme 2026-10-07 tối (mật độ 540 = 320 dp, bản debug `e1ce2b38…`) |
> | ~~**G77**~~ | ✅ **Mở rồi ĐÓNG 2026-10-07** — **Sổ giao dịch**: ô kỳ *"Tháng này (T10 20…"* **mất năm** (`transaction_page.dart`, `nhanRong` + ellipsis); **form Thêm hoá đơn**: tiêu đề *"Thêm Hóa Đơn …"* cụt (chung hàng mũi tên + nút Lưu, còn ~160 dp, chữ cần ~215), nút *"Tạo Hóa Đơn & Đăng Ký Nhắc Nhở"* trông như **xén mép phải** — chữ đã co (`FittedBox`) nhưng nút **không có lề ngang** nên chạm sát mép bo tròn (0 dp ở 300 dp). Sửa: ô kỳ **đo bề rộng** (`doRongChu`), không vừa thì lùi về `nhanNgan` (*"T10 2026"* — bỏ *"Tháng này"*, giữ năm; cùng lối header Phân tích G2); tiêu đề form đo, không vừa thì *"Thêm Hóa Đơn"* (người dùng chọn rút ngắn, giữ cỡ 20); nút thêm lề ngang 16. Test `so_giao_dich_ky_hep_test.dart` (3) · `bill_add_hep_test.dart` (5), font thật; ca 320 dp của ô kỳ phóng chữ ×1,1 (Roboto đậm hẹp hơn Inter). ✅ Nghiệm thu Realme 2026-10-07 tối (mật độ 540 = 320 dp, bản debug `e1ce2b38…`) |
> | ~~**G78**~~ | ✅ **Mở rồi ĐÓNG 2026-10-07** — chữ phụ cụt ở màn hẹp, không mất số liệu: *"NGÀY CHI NHIỀU NH…"* (Số liệu nhanh), gợi ý *"Bỏ chọn hết để x…"* (Xu hướng), *"ĐỀ XUẤT CÂN ĐỐI · KH…"*, *"khoảng 2.010.000 đ m…"* (Chưa đặt ngân sách); số dư ví ở màn Thêm giao dịch xuống dòng riêng chữ *"đ"*. Sửa: bốn dòng chữ phụ được xuống **tối đa hai dòng** thay vì cắt (`maxLines: 2`); hàng hai ô Số liệu nhanh canh **mép trên** để ô bên cạnh không bị đẩy xuống giữa; số tiền dùng `CurrencyFormatter.formatLienKhoi` (số và *"đ"* dính liền) ở dòng *"khoảng … mỗi tháng"* và dòng ví của màn Thêm giao dịch. Test `budget/presentation/chu_phu_hep_test.dart` (4 ca, font thật, hai thẻ trang Ngân sách; mã cũ đỏ cả 4). Hai chỗ trang Phân tích và dòng ví chưa có ca riêng. ✅ Nghiệm thu Realme 2026-10-07 tối (mật độ 540 = 320 dp, bản debug `e1ce2b38…`) |
> | ~~**G79**~~ | ✅ **Mở rồi ĐÓNG 2026-10-07** (nghiệm thu Realme 320 dp) — chấm kỳ đầu/cuối của **bốn biểu đồ đường** (Xu hướng, Dòng tiền tự do, Tổng tài sản ở trang Phân tích; Tiến độ ở chi tiết mục tiêu) **vẫn mất nửa** dù G55 đã "đóng". Gốc: G55 đặt `FlClipData.vertical()` theo **tên** hằng, nhưng trong fl_chart 1.2.0 nó vẫn cắt nửa chấm ở mép trái — đo bằng ảnh vẽ ra (`toImage`); ca canh G55 chỉ đọc **cấu hình** nên xanh suốt. Sửa (người dùng chọn *chừa lề hai đầu*): `core/ui/bieu_do_cham.dart` — `trucNgangCoCham` nới trục ngang 5 % dải (≈ 8,6 dp ở vùng vẽ 190 dp), `clipData` về `all()` (giữ phòng thủ bẫy 4.17); nhãn kỳ chỉ nhận mốc nguyên (`laMocChiSo` — fl_chart hỏi nhãn ở hai biên đã nới, `-0,25` làm tròn ra 0 là in trùng nhãn kỳ đầu); biểu đồ mục tiêu kẹp nhãn biên về ngày đầu/cuối thật. Chấm giá trị 0 ở đáy vẫn mất nửa dưới (quyết định G55 giữ nguyên). Test `core/ui/bieu_do_cham_test.dart` (đo điểm ảnh) + hai ca canh viết lại (`analytics_page_test`, `goal_progress_chart_test`) — đỏ trên mã cũ. ✅ Realme 320 dp: chấm T5/T10 tròn đủ ở Xu hướng, Dòng tiền tự do, Tổng tài sản; nhãn kỳ không in trùng |
> | ~~**G80**~~ | ✅ **Mở rồi ĐÓNG 2026-10-07** (nghiệm thu Realme 320 dp) — tiêu đề màn **Thêm / Sửa giao dịch** bị cắt *"Thêm giao dị…"* khi 16 phím số ẩn và ✓ lên thanh tiêu đề. Sửa (người dùng chọn *co chữ cho vừa*, cùng lối nhãn tab G76): tiêu đề trong `FittedBox(scaleDown)`; màn rộng giữ cỡ gốc. Test `transaction/presentation/tieu_de_them_giao_dich_hep_test.dart` (3 ca, font thật ×1,1; mã cũ đỏ 2 ca). ✅ Realme 320 dp: *"Thêm giao dịch"* hiện đủ cạnh ✓ |
> | ~~**G81**~~ | ✅ **Mở rồi ĐÓNG 2026-10-07** (nghiệm thu E6 trên Realme) — hàng **"Số dư ví sắp cạn — chỉ còn 0 đồng"** treo cạnh hàng *"đang âm"* khi ví âm lại: hai hàng cùng nói về một ví, hàng sắp cạn mang số cũ. Sửa (người dùng chọn *tự gỡ khi ví âm*): `hangSapCanDaHoi` → **`hangSapCanLoiThoi`** (`notification_rules.dart`) — lỗi thời là ví đã lên trên ngưỡng **hoặc** đã âm (vế âm không phụ thuộc ngưỡng); ví âm không đi qua luật sắp cạn nên hàng không sinh lại. Test: một ca ⭐ G81 ở `notification_rules_goal_wallet_test.dart` (đỏ trên mã cũ). ✅ Realme: hàng *"test chỉ còn 0 đồng"* tự gỡ khi ví "test" đang âm |
> | ~~**G82**~~ | ✅ **Mở rồi ĐÓNG 2026-10-07** (nghiệm thu Realme) — chip của khối **Nhận xét** bỏ tên đối tượng: trang Ngân sách hiện ba chip *"Tỉ lệ 0,0%"* y hệt (ba ngân sách khác nhau), trang Hoá đơn bốn chip *"Đã quá hạn …"*. Gói số đã mang `SoLieu.ten`; chỉ `the_so_lieu.dart` in `nhan + chuoi`. Sửa: mục có tên in *"tên · nhãn chuỗi"* — đúng quy ước sẵn có của thẻ Trợ lý AI (`the_cua_cau.dart`); nhãn `SoLieu` **không** đổi (lớp chắn `kiemNhan` suy từ khoá từ nhãn). Test: ca ⭐ G82 ở `khoi_nhan_xet_test.dart` (đỏ trên mã cũ). ✅ Realme: *"Giáo dục · Tỉ lệ 0,0%"*, *"Kiem · Đã quá hạn 45.000 đ"* |
> | ~~**G83**~~ | ✅ **Mở rồi ĐÓNG 2026-10-07** (nghiệm thu Realme 320 dp) — chữ gợi ý ô **ghi chú** màn Thêm giao dịch cắt thành *"Thêm ghi chú cho gi…"*. Sửa (người dùng chọn *rút gọn chữ*, không cho xuống dòng — ô giữ chiều cao, form không xê dịch): `hintText` → *"Thêm ghi chú…"*. Stitch `8afdfe11…` vẽ ô đã có chữ nên không quy định câu gợi ý. Test: `goi_y_ghi_chu_hep_test.dart` (font thật, 320/300 dp, tìm chữ gợi ý theo vị trí — đỏ trên mã cũ). ✅ Realme: *"Thêm ghi chú…"* hiện trọn |
> | ~~**G84**~~ | ✅ **Mở rồi ĐÓNG 2026-10-07** (nghiệm thu Realme 320 dp, cùng lượt G83) — màn Thêm giao dịch: (1) chữ gợi ý ô **Nhập nhanh** cắt *"VD: hôm qua ăn phở …"* — mất đúng phần số tiền + ví, thứ câu ví dụ sinh ra để chỉ; ở Basic *"Tính năng Premium"* cũng cắt sát mép; (2) ô **ghi chú** mang nền + viền bo góc của theme (`border: none` một mình không che được `enabledBorder` / `focusedBorder`) và chữ thụt 16 dp so với cột *"Chọn danh mục"* / *"Ngày"*, trong khi Stitch `8afdfe11…` vẽ hàng phẳng. Sửa (người dùng chọn câu): Premium *"phở 45k tiền mặt"* (đo 123 dp, ô còn 141 ở 300 dp), Basic *"Chỉ Premium"*; ô ghi chú `filled: false` + ba viền `none` (cùng lối ô Nhập nhanh) + `contentPadding` chỉ dọc. Test: năm ca G84 ở `goi_y_ghi_chu_hep_test.dart` (vừa ô 320/300 dp cả Premium lẫn Basic, ví dụ còn số tiền + ví, hàng phẳng, thẳng cột với *"Ngày"*) — đều đỏ trên mã cũ. Spec Premium §8.2 ghi chú chữ mới. ✅ Realme: cả hai câu hiện trọn; ô ghi chú phẳng, thẳng cột, gõ chữ không hiện viền focus |
> | ~~**G85**~~ | ✅ **Mở rồi ĐÓNG 2026-10-08** (nghiệm thu G67 hai máy ảo) — **ví chưa có khoản mở sổ nhận giao dịch của máy khác thì neo nuốt giao dịch ấy**: lượt kéo về ghi giao dịch vào sổ **trước**, rồi mới vá neo `balance − Σ sổ` cho ví đã có trên máy. Ví seed (server tạo khi đăng ký) không bao giờ có neo, nên ca này xảy ra ở **mọi tài khoản dùng hai máy**. Đo: ví Tiết kiệm, B −11.000 offline, kéo về −22.000 của A → neo +22.000, cả hai máy −11.000 thay vì −33.000. Sửa: vá neo **trước** khi ghi giao dịch kéo về (`viDungToi` ở `_pullFromBackend`); kèm ví **đích** của khoản chuyển vừa về nay cũng được tính lại. Lượt hai trên ví Tiền mặt seed: −12.000 cả hai máy, không neo. Hàng neo hỏng của tài khoản 27 xoá mềm qua giao diện |
> | ~~**G86**~~ | ✅ **Mở rồi ĐÓNG 2026-10-09** (người dùng báo *"khi vào phải đợi vài giây mới hiện thông tin"*) — **mở app thì mọi trang đợi một lượt gọi mạng**: `AuthBloc._onAuthCheckRequested` chỉ phát `AuthSuccess` SAU `verifySession()` (`GET /auth/profile`, trần 30 s), trong khi mọi trang cần `AuthSuccess` để biết `idaccount`. Server chậm / Render đang ngủ / Wi-Fi không ra Internet là quay vòng tới 30 s, còn Trang chủ in *"0 đ"* và *"Người dùng"* — dữ liệu thì nằm sẵn trong SQLite. Đo Realme (bản debug không tới được server): trang Hoá đơn quay vòng ~30 s. Sửa (người dùng chọn *hiện dữ liệu ngay, hỏi server ở nền*): phần **không chạm mạng** (đọc người dùng đã lưu, kiểm `idaccount`, dọn tài khoản khác, chuyển `cat_*`) rồi **phát `AuthSuccess` ngay**; sau đó mới `verifySession()` — phiên chết → đăng xuất như cũ; hợp lệ / không rõ → đọc lại người dùng (thẻ chờ xoá), phát lại nếu đổi, **rồi mới** khởi động socket, SyncEngine (chốt *không đồng bộ với phiên chết* giữ nguyên). **Bộ quét thông báo** (nhập hàng chờ D1 / biên lai, chuông, nhắc, tự trả) chạy **trước** `AuthSuccess` — người dùng chọn sau khi lượt soát chỉ ra bản đầu làm danh sách *chờ ghi* rỗng tới 30 s khi chạm thông báo biến động lúc mất mạng; phiên chết thì `_dungMoiThuCuaPhien` dừng nó. ⚠️ Phiên chết nay vẫn dọn dữ liệu tài khoản khác và chạy một lượt quét cục bộ trước khi bị đẩy ra. ⚠️ Sau mỗi `await` phải kiểm `_vanLaPhien(user)`: lượt mở app về muộn từng **phát lại `AuthSuccess` đè lên đăng xuất** — lỗi có sẵn trước bản này, ca test *"đăng xuất trong lúc chờ server"* đỏ trên mã cũ. Hệ quả cố ý: tài khoản bị xoá/khoá thấy Trang chủ chớp rồi mới về màn Đăng nhập. Nghiệm thu Realme: số dư thật hiện ở ~9 s kể từ `am start` của bản **debug** (gồm khởi động JIT), đồng bộ bắt đầu sau khi lượt hỏi server hết |
> | ~~**G87**~~ | ✅ **Mở rồi ĐÓNG 2026-10-09** (thấy khi nghiệm thu G52: trang Hoá đơn Realme có hai *Netflix* 05/10 và hai 12/10) — **kỳ hoá đơn trùng sống lại, bộ tự trả trừ tiền cho từng kỳ trùng**. Máy offline tự trả lại một kỳ đã trả → sinh kỳ con; hoá đơn đẩy **trước** giao dịch nên kỳ con lên server, khoản chi bị `BILL_ALREADY_PAID`, bộ gỡ xoá mềm kỳ con nhưng **Pull cùng chu kỳ ghi đè** lệnh xoá (`upsertAll` không xét hàng chờ đẩy). Đo PostgreSQL dev, tài khoản 10: ba kỳ 05/10, cả ba đã trả (**−300.000 đ thay vì −100.000**), năm kỳ 12/10 dưới ba cha. Sửa: `kyTrungCanGo` (gộp theo **gốc chuỗi + ngày hạn**, giữ kỳ đã đóng / id nhỏ nhất, không bao giờ gỡ kỳ đã trả) + `BillRepository.gopKyTrung` ở **đầu** `NotificationScanner.scan` (trước bộ tự trả, không gác quyền, **chỉ khi vừa kéo về thành công** — `SyncEngine.soLanKeoVeXong`; gộp trên dữ liệu cũ lúc mở app là xoá hoá đơn máy khác đã trả) + chốt `kyCungKyDaDong` trong `payBill`. Không đổi luật Pull. Mục 6.8 `BILL_DOCUMENTATION.md`. Hai khoản chi thừa của kỳ 05/10 (`22bb274a`, `cccb14ee`) để người dùng tự Hoàn tác. ✅ **Nghiệm thu đầu-cuối 2026-10-09**: Realme (bản mới, kéo về xong) đánh dấu đúng bốn kỳ 12/10 trùng; OnePlus đăng nhập tài khoản 10, kéo về, gộp ra **cùng tập** và đẩy — PostgreSQL: `780e51b2`, `7ebadb82`, `9886bc31`, `c0038a49` nhận `Delete_at`, giữ `65ece89a`, ba kỳ 05/10 đã trả không đổi, khoản chi Netflix vẫn 4. Lượt ấy lộ thêm: `gopKyTrung` không hẹn đồng bộ nên lệnh xoá nằm chờ tới 15 phút — nay `scheduleSync()` khi có gỡ |
> | ~~**G90**~~ | ✅ **Mở 2026-10-11, ĐÓNG 2026-10-12** (`9bc57c63`; lộ ở lượt nghiệm thu chạy nền, máy ảo `FlowMoney_16G`) — **bảng chọn giờ, chế độ gõ chữ, trên máy đặt định dạng 12 giờ**: gõ *"21"* → *"Nhập thời gian hợp lệ"*, và hai ca sai **im lặng** (từ 20:00 gõ 8 lưu 20:00; từ 08:00 gõ 12 lưu 00:00). Gốc: Flutter hiển thị theo ngôn ngữ (`vi` = 24 giờ, không SA/CH) nhưng đọc chữ gõ theo `MediaQuery.alwaysUse24HourFormat` của máy. Sửa ở tầng app: `bocDongHo24Gio` (`core/constants/app_localization.dart`) ép cờ 24 giờ trong `builder` của `MaterialApp.router` — phủ năm chỗ `showTimePicker` và mọi chỗ thêm sau. Nghiệm thu máy ảo đặt 12 giờ + đối chứng bản chưa sửa. Mục chi tiết bên dưới |
> | **G102** | ✅ **MỞ VÀ ĐÓNG 2026-10-21 tối** (lộ khi nghiệm thu C4 giọng nói trên Realme; mã + test + kiểm lại trên máy) — **hai lỗi của giọng nói C4**: (1) **lối Android tự dừng sau ~2 giây** — `speech_to_text` 7.5.0 tính `pauseFor` từ lúc bắt đầu nghe, mã đặt `pauseFor` = 2 s nên người dùng chưa kịp nói đã dừng, Google trả `NO_SPEECH_DETECTED` (*"Không nghe rõ"*); (2) **lối Gemma đem bản ghi im lặng đi chép** — Gemma trả lại câu lệnh, app điền *"Chép lại chính xác câu tiếng Việt…"* vào ô Nhập nhanh. Sửa: lối Android chờ tiếng đầu 6 s (`kChoTiengDau`), có chữ rồi `changePauseFor(kImDeDung)` (bọc `try` — gói ném khi đã `notListening`); bộ đo không thấy tiếng sau 6 s thì không gọi Gemma; `lamSachLoiChep` bỏ lời chép chứa mảnh câu lệnh. Kiểm lại Realme: lối Android nói giọng thật 4 câu đều ra chữ, dừng ~2 s sau chữ cuối; lượt Gemma im lặng không còn gọi mô hình. |
> | **G103** | ✅ **MỞ VÀ ĐÓNG 2026-10-21 tối** (lộ ở lối Android của C4 trên Realme; mã + test + kiểm lại trên máy) — **lời nghe của Google viết khác chữ gõ, bộ đọc câu trượt**: *"chuyển 500.000 từ **mbbank** sang tiết kiệm"* → ví nguồn rơi về **Tiền mặt**, ghi chú sót *"từ mbbank"* (mẫu tên gọi tắt *"mb bank"* đòi `\s+`); *"500.000**₫**"* → ghi chú sót *"₫"* (mẫu số tiền chạy trên câu bỏ dấu, chỉ nhận *đ → d*). Sửa: tên gọi tắt khớp cả dạng viết dính (`\s*`, vẫn chặn ranh giới từ và vẫn chỉ sau giới từ); `_chuanCau` đổi *₫ → đ* ở đầu vào của ba phép đọc. Cả gõ tay cũng hưởng. |
> | **G113** | 🚧 **MỞ 2026-10-28 phiên 23** (gia đình lát 1 — hẹp, chưa có màn nên chưa ai chạm; chấp nhận ở lát 1, **lát 2 PHẢI sửa neo (3) trước khi mở lối tạo ví chung**) — **dữ liệu nhà có thể thiếu / kẹt trên máy**: (1) lịch sử nhà mới vắng VĨNH VIỄN (kho trạng thái nhà ghi trước khi phát `DoiNha`; hai isolate, `clear` nuốt lỗi, tiến trình chết giữa chừng); (2) yêu cầu kéo toàn bộ xoá mốc kho ngay ⇒ chết trước lượt kế thì lượt ấy bỏ so từ khoá khuôn; (3) dọn nhà cũ hỏng ⇒ hàng nhà cũ nằm lại, và hàng con `idhousehold` NULL trỏ ví nhà (neo "Số dư ban đầu") làm `xoaHangCuaNha` / purge vỡ khoá ngoại vĩnh viễn ⇒ `moPhienCucBo` ném ⇒ **người dùng bị khoá ở cửa đăng nhập**; cùng gốc `nhaGiu` null: purge xoá ví nhà rồi kéo tăng dần ⇒ vỡ khoá ngoại cả lượt kéo tới khi có `DoiNha`; (4) thành viên đăng nhập lần đầu trên máy mới kéo toàn bộ HAI lần (chấp nhận); (5) quyền không chứng minh được trên máy — 🔎 2026-10-30: 56.1 / 56.4 đạt theo mã sau gộp `e3248955` (chưa đo trên máy; `PersonFinance` chưa áp migration 41), còn 56.2 phần `Transfer` (58.1) và 57.4 chặn đường ghi; nợ lát 2 thêm (review toàn nhánh): tính lại số dư đánh `pending` lên ví nhà, đo `/me` mới trước khi gộp `main`, bản giả `HouseholdApiGia` lệch backend, tần suất `/me` khi 56.8 đóng (✅ nợ 12 phía client 2026-10-30: giãn cách 30 s `kGianCachNhaDoi`, `1227d8a2` — còn chờ đơn 58.4 phía server), `xuLy` không kiểm phiên (purge giữ từ khoá / quan hệ nhóm trỏ danh mục nhà khác — cố ý), `getLastTransactionDate` bỏ khoản nhà, ca canh khối 1b. Thân: mục G113 dưới. |
> | **G112** | ✅ **MỞ VÀ ĐÓNG 2026-10-28 phiên 22** (lộ khi nhìn G111 trên Realme; mã + test + nhìn lại trên máy — cú vuốt cũ nay cuộn trang) — **vuốt để cuộn trang Mục tiêu đổi thứ tự ưu tiên**: thẻ mục tiêu bọc `ReorderableDragStartListener` — bắt kéo NGAY khi ngón tay di chuyển — trong khi chữ dưới danh sách nói *"Nhấn giữ một mục tiêu để kéo"*. Một cú vuốt từ thẻ MuaDT đã kéo nó lên trên MuaXe (ưu tiên 1 / 3 → 100 / 200), đồng bộ lên server, không hộp nào hỏi. Nay `ReorderableDelayedDragStartListener` (kéo sau khi nhấn giữ); thứ tự trên Realme trả lại bằng tay (MuaXe 50 · MuaDT 100). Thân G112 |
> | **G111** | ✅ **MỞ VÀ ĐÓNG 2026-10-28 phiên 21** (ghi nhận phiên 19 khi nghiệm thu B1 Task 13; mã + test; **nhìn Realme phiên 22 — đạt** ở cả năm loại công tắc) — **công tắc bị khoá theo quyền vẽ y hệt công tắc mở**: bảy chỗ khoá bằng `Switch(onChanged: null)` kèm `activeTrackColor` / `inactiveTrackColor` đặt cứng, mà màu đặt cứng thắng màu khoá mặc định của Material 3 (đo bằng widget test). Nay mọi công tắc khoá theo quyền đi qua **`CongTacTheoQuyen`** (`premium/presentation/widgets/the_khoa_quyen.dart`) — mờ 50 %, ổ khoá trong núm, giữ màu của chỗ gọi (Stitch `68593384…`); **test quét 41** cấm `Switch(` / `HangCongTac(` khoá bằng `coQuyen` trong `onChanged` |
> | **G110** | ✅ **ĐÓNG 2026-10-28 phiên 21** (mã + test; Stitch `2dd819da…`, người dùng duyệt thiết kế + màn; **nhìn Realme phiên 22 — đạt**, cả vòng đổi tên rồi trả tên) — mục *"Đang tạm ngừng (N)"* thu gọn cuối màn Danh mục liệt kê mọi danh mục đang ẩn theo khuôn, bút mở form Sửa (`?tamNgung=1`) có dải nhắc; đổi tên là hiện lại. Mô tả gốc: ⏸ **MỞ 2026-10-27** (lộ khi review toàn nhánh kế hoạch danh mục theo thao tác Admin-web) — **danh mục người dùng TỰ TẠO trùng (tên, loại) một khuôn bị ẩn y như bản sao khi admin xoá khuôn đó**, và màn Danh mục không có lối nào để đổi tên một danh mục đang ẩn (dữ liệu còn nguyên; admin khôi phục khuôn là hiện lại). Đề xuất mục *"Đang tạm ngừng"* thu gọn ở màn Danh mục — chi tiết ở thân G110, **cần màn Stitch trước khi làm** |
> | **G109** | ✅ **MỞ 2026-10-27 phiên 17, ĐÓNG 2026-10-28 phiên 18** (lộ khi thiết kế B1 `2026-10-27-phan-quyen-cot-premium-va-cong-tac-design.md` mục 0; mã + test, `f4d35331` + `97357a0b` / `d885e16d`) — **Basic sau khi Premium hết hạn LÚC OFFLINE dùng trần của Premium**: `conTaoDuoc` đọc `goi.tran` — trần đã lưu là của gói Premium (toàn `null`) — nên người đã về Basic tạo ví / ngân sách / mục tiêu **không giới hạn** tới lượt `lamMoi` kế. Nay mọi chỗ đọc trần đi qua `tranHieuLuc` (thân G109) |
> | **G108** | ✅ **MỞ VÀ ĐÓNG 2026-10-27** (lộ khi làm kế hoạch danh mục theo thao tác Admin-web; mã + test, commit `ca2a0364`) — **bộ tạo bản sao danh mục so (tên, loại) trong khi chỉ mục server chỉ có tên**: khuôn cùng tên khác loại làm bộ tạo sinh bản sao thứ hai mà `uq_category_owner_name` từ chối → vòng đẩy hỏng. Nay so theo **tên chuẩn hoá** (chi tiết: thân G108) |
> | **G107** | ✅ **MỞ VÀ ĐÓNG 2026-10-27** (lộ khi đo Realme phiên 14 — máy ảnh khi giữ Gemma; mã + test + nghiệm thu Realme bằng `am crash` lúc máy ảnh mở) — **ảnh của lượt Quét mất khi tiến trình chết lúc máy ảnh / trình chọn ảnh đang mở**: màn Quét không gọi `ImagePicker.retrieveLostData()`, ảnh nằm trong bộ đệm `image_picker` và người dùng về Trang chủ như chưa quét. Sửa: `NhanAnhQuetBoDo` (widget không vẽ gì trong cột Trang chủ) hỏi ảnh bỏ dở một lần mỗi lần trang dựng mới, có ảnh thì `push('/quet')` — tiến trình mới 16769 đọc ảnh bằng Gemma, màn khoá → *Đang đọc* → form → Lưu. |
> | **G106** | ✅ **MỞ VÀ ĐÓNG 2026-10-24 tối** (lộ khi đo Realme phiên 4; mã + test + đo lại trên máy) — **lịch nhắc đặt trước mất im lặng sau force-stop**: `pendingIds()` đọc danh sách lịch của plugin, không phải AlarmManager; force-stop xoá báo thức mà danh sách còn, `resync` thấy "đã chờ" thì bỏ qua → nhắc hoá đơn mất hẳn. Sửa: lượt `resync` đầu mỗi tiến trình đặt lại cả lịch "đã chờ" (không huỷ, không ghi `dat_lich`). Đo: force-stop → 0, mở app → 3. Bẫy 7.14 `NOTIFICATION_FEATURE.md`. |
> | **G105** | ✅ **ĐÓNG 2026-10-28 phiên 22** (phần hai: khối ≥ 2 dòng chữ Latin ở đầu nhường dòng viết hoa có dấu NGAY SAU — tờ `N01c` ra *ỦA TEA*, 35 tờ cũ không đổi; còn hở biết trước ở thân) · ◐ **SỬA MỘT PHẦN 2026-10-22** (+ dòng nhắc chụp ở sheet chọn nguồn — người dùng chọn thay vì thêm luật, `2bdc2a68`; lộ khi đo Quét ảnh trên Realme; dòng toàn chữ thường nay xếp sau mọi dòng có chữ hoa — N01 dính *"card n"* ra *ỦA TEA 2DEE*; ⚠️ đo lại khuya: chụp dính một tấm thẻ in chữ tiếng Anh, sáu dòng rác **lẫn hoa thường** đứng trước *ỦA TEA* → ghi chú *"ral Setl Ths cad rd effect"*, luật hiện tại không che) — **mẩu rác hai từ ngắn ở mép ảnh thắng tên cửa hàng**: N01 chụp lần đầu, OCR dòng đầu là *"card n"* (chữ lạ ở mép khung), dòng 3 *"ỦA TEA 2DEE"* → ghi chú điền *"card n"*. Luật tên (chốt 12 `QUET_ANH_FEATURE.md`) chỉ bỏ mẩu **một** từ ≤ 4 chữ cái. Chụp lại không dính mép → *ỦA TEA* đúng. Số tiền / ngày giờ không ảnh hưởng; người dùng sửa ghi chú bằng một lần gõ. |
> | **G104** | ✅ **ĐÓNG 2026-10-23** (hoãn 2026-10-22; mã + test, **chưa đo trên máy** — không máy nào cắm) — **đường luật bỏ trống của N1 từng tin bản cụt của Gemma**: câu *"một triệu hai tiền sách"* (chữ số lẻ không ở chỗ của tiền) luật để trống, Gemma chọn trong `cachDocSoTien` = {1.000.000, 1.200.000} và form điền không hỏi. **Sửa (người dùng chọn hai chip):** luật đưa `KetQuaDocCau.luaChonSoTien` = [cụt, dài] → ô số tiền trống + hai chip (khối chip có sẵn của C4), Gemma **không** lấp ô số tiền, ô ấy không tính là ô thiếu; lời nhắc Gemma không đổi. Cùng lượt (người dùng chốt): *"X bậc Y"* viết chữ có **một** định nghĩa `_docXBacY`, X 1–99 — *"trả hai trăm nghìn tám"* thôi điền 200.800 (ô trống + *"chưa rõ"*), *"mười lăm triệu hai"* vẫn 15.200.000. |
> | **G101** | ✅ **MỞ VÀ ĐÓNG 2026-10-21** (mở khi nghiệm thu A5 trên Realme; mã + test trên chữ `/quet` thật chép từ logcat; **nghiệm thu Realme Premium cùng tối đạt** — R08 và R13 nay hỏi hai chip; đường Basic chưa nhìn trên máy) — **Quét ảnh điền sẵn số tiền SAI mà không hỏi khi OCR làm mất / đổi chữ số dòng tổng**: R13 MAXIDI 72.127 → OCR *"2,127"* → form **2.127 đ** (Gemma đọc đúng 72.127 nhưng bị bỏ); R08 75.700 → OCR *"75,706"* → form **75.706 đ** (Gemma 55.000). `chotTongQuet` bỏ số AI không có trong chữ OCR và không khác số luật đúng một chữ số **cùng độ dài**, rồi điền số luật **không kiểm gì thêm**; Basic còn không đi qua phép chốt. Sửa (người dùng chọn **ba lưới A + B + C**): **C** số Gemma thêm / bớt một chữ số so với số luật là ứng viên; **A** số luật đứng một mình mà nhỏ hơn một dòng món phía trên dòng tổng → ô trống; **B** số luật đứng một mình mà tờ in một số khác lệch ≤ 1% → hai chip; `/quet` chốt **mọi** hoá đơn, kể cả Basic. Đo trên 34 tờ chữ (15 chữ 08/10 · 16 chữ `/quet` 21/10 · 3 OnePlus), hai gói: **0** tờ điền sẵn sai; cái giá: R13 chữ 08/10 (luật đúng) chuyển sang hỏi chip 72.127 · 72.121. Dữ liệu `hoa_don_quet_that_du_lieu.dart`. |
> | **G100** | ✅ **ĐÓNG 2026-10-21** (hai đường. **Back hai lần** ở Trang chủ đưa app **xuống nền** — kênh `flowmoney/xuong_nen` → `moveTaskToBack(true)`; nghiệm thu OnePlus GPU trước / sau: bản cũ 420 → 799 MB Native, bản mới giữ 423 MB, không nạp lại. **Gỡ task khỏi Đa nhiệm** khi tiến trình đang giữ mô hình → `MainActivity.onDestroy` **giết tiến trình** (cờ từ `BoNapMoHinh.baoGiu` qua kênh `flowmoney/giu_mo_hinh`; chỉ khi không đổi cấu hình và là activity cuối), hệ điều hành dựng lại tiến trình cho dịch vụ D1 sau ~1 s; nghiệm thu Realme CPU: mở lại chỉ nạp một bản, Native 1,90 GB thay vì 3,71 GB. Gốc: `flutter_gemma_litertlm` chỉ cất địa chỉ engine native trong đối tượng Dart, không `NativeFinalizer`) — **Back thoát app (hoặc gỡ task) rồi mở lại thì mô hình Gemma bị nạp thêm một bản**: tiến trình sống tiếp nhờ dịch vụ D1, engine Flutter dựng lại, isolate mới nạp bản thứ hai, bản cũ không ai đóng (`lib/` không nghe `detached`). Đo Realme CPU: Native Heap 1,89 GB (một bản) → **3,72 GB** sau một vòng, PSS 4,9 GB; dựng lại được hai lần. Chạm mọi đường nạp mô hình (Trợ lý, C2, C3, C4, A5). ⚠️ Đóng mô hình khi `detached` đụng chốt 4b (OnePlus GPU sập ở lần đóng thứ hai trong một tiến trình) — vì thế lối sửa chọn *xuống nền*, không đóng gì. |
> | **G99** | ✅ **MỞ VÀ ĐÓNG 2026-10-20** (lộ khi đo G95 trên Realme; sửa bằng `_mauMocBatDau` — cụm *kể từ / bắt đầu từ / từ + tuần·tháng·quý·năm·ngày + mốc* bị gạt trước khi xét chữ thời gian; đo lại Realme: thẻ không còn hạn bịa) — **lệnh tạo mục tiêu nhận hạn mô hình bịa khi câu chỉ nêu mốc BẮT ĐẦU**: *"ke tu thang sau de danh 2 trieu moi thang"* → thẻ *"Tạo mục tiêu · hạn 30/06/2027"* (mô hình trả `han: 30/06/2027`; câu không nêu hạn nào). Lưới `_hanAiHopLe` chỉ đòi câu có **một chữ chỉ thời gian bất kỳ** ngoài cụm chu kỳ — *tháng* của *"kể từ tháng sau"* là đủ. Có từ trước G95 (cổng cũ cũng mở cho câu này). Form vẫn để người dùng sửa trước khi Lưu (bất biến ④) nên không ghi sai thẳng. |
> | **G98** | ⏳ **CHỜ BACKEND — đơn 48** (mở 2026-10-20, lộ khi nghiệm thu G89; người dùng chốt hướng cùng ngày) — ví test `test-wallet-1789014227658` (id **không** phải UUID, một test backend chèn thẳng vào CSDL dev, tài khoản 18) **không bao giờ đẩy lên được**: `toValidUuid` đổi id → server không thấy → `create` → trùng `(Idaccount, Name)` với chính nó → `WALLET_NAME_DUPLICATE` → G63 gắn cờ rồi thả, lặp mỗi lượt; và mỗi chu kỳ có hàng ấy bị tính là chu kỳ hỏng → giãn cách đồng bộ cả tài khoản lên **15 phút** (đo 16:08:26). Toàn CSDL dev chỉ có 1 ví + 9 giao dịch id không phải UUID, tất cả `test-` của tài khoản 18 — người dùng thật không gặp. **Nguồn:** ca 11 `Test/test_data_security_encryption_and_masking.js` (`findFirst` tài khoản Active **không** `orderBy` → trúng 18 ngày 2026-09-10). **Người dùng chốt** dọn dữ liệu + sửa script → đơn 48 `CAN-LAM/LICH-SU/DU_LIEU_TEST_TRONG_TAI_KHOAN_THAT.md`; client không đổi mã. Sau bước 1 của đơn, máy đang kẹt tạo một ví "ma" ở id giả `00000000-0000-4000-8000-4534d71cc54d` (bước 3 xoá). |
> | ~~**G97**~~ | ✅ **Mở và ĐÓNG 2026-10-20** (review toàn nhánh G89 đề nghị) — body lỗi không phải JSON (trang HTML của proxy / Render) làm `AuthRemoteDataSourceImpl` đọc `String['message']` → `TypeError`, và màn Đăng nhập in nguyên câu *"type 'String' is not a subtype of type 'int' of 'index'"*; nhánh 2xx cùng bệnh ở `data['success']`. Sửa: `_cauLoi` / `_thanhCong` (14 lời gọi, một định nghĩa); `getProfile` chỉ giữ `statusCode` khi body là JSON — trang 404 của proxy không được thành *phiên chết*. 30 ca ở `auth_remote_data_source_body_khong_json_test.dart`. |
> | **G96** | ⏳ **CHỜ BACKEND — đơn 47 việc 5–7** (mở 2026-10-18 sau nghiệm thu OnePlus 13R trên backend dev chạy thật) — **đường Trợ lý online phụ thuộc ba việc backend, cả ba có số đo**: Dừng không tới server (client đóng socket thật — ESTABLISHED tới :3000 4 → 2 — nhưng `req.on('close')` không nổ trên Node 22, service chạy Gemini tới cùng); server im > 45 s sau `meta` khi `gemini-3.8-flash` suy nghĩ → `receiveTimeout` rơi về máy (người dùng chốt **giữ 45 s**, xin keep-alive `: ping` — ✅ backend đã gửi `: ping` (soát 2026-10-26); hệ quả `receiveTimeout` không còn nổ nên client thêm **trần tổng 120 s** `kTranTongOnline`, 2026-10-26 phiên 13); `maxOutputTokens: 1024` gồm token suy nghĩ → câu dài cụt ở điểm ngẫu nhiên, client hiện phần cụt không cảnh báo (đúng hợp đồng). Vế 1 và 3 chờ backend. |
> | **G95** | ✅ **ĐÓNG 2026-10-20** (mở 2026-10-18 khi nghiệm thu OnePlus; mã + test, đo Realme đạt cùng ngày) — **cổng lệnh tạo C3 `coVeLenhTao` bắt nhầm câu hỏi** *"Hãy viết 15 lời khuyên tiết kiệm tiền…"* (có *tiết kiệm* + số đếm 15 đọc ra 15.000 đ) → Gemma đọc lệnh ~5 s, từ chối, rồi câu mới đi online. Sửa: vế `_moBangXinVietChu` — câu mở bằng *viết · liệt kê · kể · soạn · giải thích · tóm tắt · gợi ý · phân tích* (sau tiền tố lịch sự, có thể kèm *bạn*) không phải lệnh; *"kế hoạch… / kể từ… / kể cả…"* vẫn lọt. 11 ca mới, gồm một ca khoá 10 câu C3 đã đo. |
> | **G94** | 🚧 **MÃ XONG 2026-10-18 tối (lát 1 dọn kiến trúc + lát 2 tính năng) — chờ nghiệm thu sandbox PayOS trên OnePlus** (cần khoá PayOS + phép `npm install` backend). ⚠️ **Bẫy khi nghiệm thu (2026-10-23, đơn 49 vế G — lỗi backend):** đồng bộ JIT với PayOS (`payment.service.js:673`) gọi `activatePremiumSubscription` sai chữ ký → trả tiền mà webhook **không** tới (dev không ngrok) thì đơn thành `PAID` nhưng tài khoản **vẫn Basic** — màn *Thành công* hiện mà gói không đổi; đó là lỗi backend, không phải client. Đo khi có webhook (ngrok / tự ký), hoặc chờ backend sửa. Màn Chờ không tự mở PayOS, có QR + *Lưu mã QR* + thông tin chuyển khoản; trạng thái đối soát → Chi tiết đơn (nơi duy nhất gọi `confirm-upgrade`); Lịch sử mua bấm được; Nâng cấp có thẻ đơn cần xử lý + khoá *Thanh toán*. Lịch sử mục: (trước đó ⏳ hoãn chờ đơn 43; mở 2026-10-16 khi soát sau gộp `main` @ `d72ccd45`; người dùng chốt cùng ngày; đơn 44 không chặn). 🔀 **2026-10-18:** gộp `e7570e16` mang mã backend viết thẳng vào client — ba trạng thái đơn, hai nút xác nhận chuyển thừa, nhãn lịch sử, hạn 10 phút — nhưng ca chính vẫn hở: đồng hồ trên máy về 0 lúc màn không hiện thì người chuyển thừa vẫn thấy *"hết hạn"*, và chỉ màn chờ gọi được `confirm-upgrade`; danh sách ở khối 🔀 thân mục. ✅ **2026-10-18 tối:** đợt sửa hai lỗi đang chạy mở đầu lượt — đồng hồ trên máy thôi tự kết luận hết hạn (server quyết), lỗi khi xác nhận có câu báo; còn lối xác nhận khi đã rời màn chờ (việc 2) và bảy việc khác — **chuyển thừa / thiếu tiền khi nâng Premium thì app nói "Đơn đã hết hạn"**. Backend thêm ba trạng thái đơn `WAITING_CONFIRMATION` · `REFUND_PENDING` · `REFUNDED`, endpoint `POST /payment/confirm-upgrade` và ba sự kiện socket. `trangThaiDonTuChuoi` đọc chuỗi lạ là `pending`, nên màn Chờ thanh toán quay tới khi đồng hồ phía máy về 0 rồi hiện *"Đơn đã hết hạn"*: người vừa chuyển tiền không bao giờ thấy hộp xác nhận, server chờ mãi. Lịch sử mua ghi đơn đã hoàn tiền là *"Chờ thanh toán"*. Câu *"chỉ có hiệu lực 30 phút"* sai (server nay 10 phút). |
> | ~~**G93**~~ | ✅ **Mở và ĐÓNG 2026-10-14** — hook `datGoi` trong `moPhienCucBo` (trước bộ quét) + `noiPhien` so với phiên đã nối của nó; bốn ca test đỏ trên mã cũ; không đo được trên máy (cần Basic hạ cấp). Mô tả gốc: (tìm ra khi điều tra G92; đọc mã) — **lượt quét đầu mỗi phiên chạy tự trả / tự trích / đọc biến động không qua cửa quyền gói**: từ G86 `moPhienCucBo` quét **trước** `AuthSuccess`, lúc `GoiRepository` chưa có tài khoản nên `coQuyenNen` trả `true`. Ai bị: Basic có bảng `features` khoá tắt (hạ cấp còn bật tự trả / tự trích). Đường nền đã chặn (`datGoi` trước `quet`). Chờ người dùng quyết. |
> | ~~**G92**~~ | ✅ **Mở 2026-10-13, ĐÓNG 2026-10-14** — nguyên nhân đúng như đoán; `chanTheoGoi` + `chanTheoQuyen` chờ `GoiRepository.choNapKho()` rồi mới đọc (cửa quyền hỏng chiều ngược: Basic bị tắt quyền lọt vào Xuất báo cáo); 5 ca ở `chan_theo_goi_test.dart`, máy ảo mở lạnh 3/3 vào form. Mô tả gốc: (nghiệm thu máy ảo đợt tách bốn trang) — **deeplink `/goals/add` lúc khởi động nguội bị chuyển sang `/premium` dù tài khoản là Premium**; app đang chạy thì vào đúng form. Nguyên nhân khả dĩ, chưa đo: `chanTheoGoi` đọc `goi.hienTai` đồng bộ khi gói đã lưu chưa nạp xong → Basic mặc định → chạm trần 3. Ba route tạo có cửa chặn, chỉ đường khởi động nguội; không mất dữ liệu. |
> | ~~**G91**~~ | ✅ **Mở 2026-10-13, ĐÓNG 2026-10-14** — `d1DangHienPin` thêm vế `context.coQuyen(MaQuyen.bankNotificationParser)`; ca ⭐ G91 ở `nhac_sau_ngan_hang_cai_dat_test.dart`. Mô tả gốc: (lượt soát đợt tách bốn trang) — **Cài đặt thông báo không còn hàng gợi ý pin nào** khi người dùng Basic còn `docBienDong` bật (từ hồi Premium) **và** bật *Nhắc ghi sau khi dùng app ngân hàng* có quyền *Truy cập dữ liệu sử dụng*: thẻ D1 khoá (`DongKhoaCongTac`, không hàng pin), còn `d1DangHienPin` của khối nhắc không xét quyền gói nên tưởng D1 đang hiện hàng ấy và giấu hàng của mình. Hậu quả nhẹ: thiếu một dòng gợi ý. |
> | ~~**G89**~~ | **✅ ĐÓNG 2026-10-20 — nghiệm thu OnePlus 13R đạt bốn kịch bản** (bảo trì · phong toả có giờ · khoá tài khoản lúc mất mạng, cả đường HTTP lẫn đường socket · đăng nhập lúc bảo trì; kết quả ở mục 12 spec) (12 commit `b7ca4512..98d58c64`; spec `specs/2026-10-20-g89-may-chu-chan-va-tai-khoan-bi-tu-choi-design.md`, mục 11 = 20 mục thi công khác bản viết): `MayChuInterceptor` ghi `TrangThaiMayChu` (bảo trì / phong toả) → dòng nhắc Trang chủ + một toast + câu màn Đăng nhập; lượt đồng bộ bị chặn (bảo trì / phong toả có giờ) kết thúc `pending`, không tính lượt hỏng — phong toả không giờ giữ giãn cách như cũ; `connect_error` có `data.code` → đăng xuất, dừng nối lại; `account.downgraded` + 403 `FEATURE_DISABLED` → làm mới gói; `ACCOUNT_DELETED` **không xoá SQLite ở mọi nguồn**; nghiệm thu máy đạt 2026-10-20 (spec mục 12). Lịch sử trước khi mã xong: 🚧 lượt đã mở 2026-10-18 tối (đợt đầu của lượt là hai lỗi G94; trước đó ⏳ hoãn tới khi backend đóng đơn 43; lượt ấy gộp cả **G94**, người dùng chốt 2026-10-16; **2026-10-18** backend báo đóng đơn 43, client soát: đạt `accountRejection` mặc định `ACCOUNT_INACTIVE` — vế chặn client xoá SQLite — và 503 bảo trì có `code`, còn sáu việc phía AIOps, CSDL và tài liệu hợp đồng; **người dùng chốt cùng ngày: thế đã đủ** — lượt G89 + G94 bắt đầu từ phiên sau, mở bằng brainstorm → spec → Stitch) (người dùng chốt 2026-10-15; trước đó ⏸️ để nguyên có chủ ý, mở 2026-10-11 — lượt soát sau gộp `main` @ `79e46225`) — **thao tác của admin vô hình trên client**: bảo trì khẩn cấp = backend phát `user.notification` + `system.broadcast` (client cố ý không nghe từ 2026-09-30) rồi trả **503 `MAINTENANCE_MODE`** cho mọi request; phong toả AIOps = **403 `AIOPS_QUARANTINED`**. Client không có nhánh đọc hai mã ấy: đồng bộ rơi `transportFailed` (im lặng, đúng), đăng nhập hiện `message` server, không dải / hộp thoại nào — trong khi `docs/Admin-web/README.md` §3 và `07-maintenance` §7 tả *Modal đỏ toàn màn hình*, *SnackBar*, *đếm ngược phong toả*. Người dùng chốt để nguyên; nếu làm thì đọc **mã HTTP + `code`** (không nghe sự kiện mới) → dải Trang chủ + toast nói rõ lý do. |
> | ~~**G88**~~ | ✅ **ĐÓNG 2026-10-16** (gạch 1–6 đều xong; gạch 4 + quét 28 ở khối ✅ cuối mục G88) — ⏸️ nợ có tên, mở 2026-10-10 — phần kiến trúc **cố ý** để lại sau đợt bịt điểm rò (spec `specs/2026-10-10-bit-diem-ro-kien-truc-client-design.md`): trang Thêm giao dịch ~~còn **2.007** dòng~~ ✅ **đóng 2026-10-11** (gạch 1: 779 dòng + `ThemGiaoDichCubit`) · ~~**4** tệp trong danh sách miễn trừ trần 1.200 dòng~~ ✅ **đóng 2026-10-13** (gạch 2: `mienTru` rỗng) · ~~UI cầm kiểu hàng Drift, Entity 6/14 mảng~~ ✅ **gạch 3 đóng 2026-10-15** (Entity 7/14: đợt 1/4 Hoá đơn ✅ 2026-10-14; đợt 2/4 Giao dịch + Ví ✅ 2026-10-14; đợt 3/4 Danh mục + hai nợ Mục tiêu + `ghiPhanHoi` ✅ 2026-10-15; đợt 4/4 Thông báo ✅ 2026-10-15, nghiệm thu máy ảo ✅ đạt) · ~~18 dòng (7 tệp) hạ tầng `core` import `features/`~~ ✅ **gạch 4 đóng 2026-10-16** (còn 8 dòng trỏ vào năm tệp domain thuần, danh sách cố định ở quét 25 luật 5 / 5b; quét 28 mới) · ~~`core/notification` 35 tệp là mảng nghiệp vụ nằm trong `core`~~ ✅ **gạch 5 đóng 2026-10-15** · ~~`data/services/` là tầng application chưa đổi tên~~ ✅ **gạch 6 đóng 2026-10-15** (`features/<x>/application/`; gạch 7 vị trí tệp ✅ 2026-10-10 — quét 25). Câu từng chờ người dùng quyết — form Thêm/Sửa hoá đơn cho chọn **nhóm** danh mục — ✅ đã quyết 2026-10-10: **không** |
>
> **G20 đã đóng ngày 2026-09-05** — `depositToGoal` nhận `occurredAt` chặn hai
> đầu; đã kiểm cả bằng test lẫn trên máy ảo Android.

| Mục | Đã làm gì | Test canh chừng |
|---|---|---|
| **G1** | Thêm `SyncStatus.authExpired`; `_runSync()` kết thúc ở `error` khi còn thao tác hỏng, `authExpired` khi phiên chết. Thêm `SyncStatusX.isTerminal` để test chờ trạng thái kết thúc bất kỳ (12 chỗ trong 6 file đã đổi theo). `scheduleSync()` nay quay lại `pending` được từ cả `error`. | `sync_failure_handling_test.dart` |
| **G2** | Giãn cách luỹ tiến 30s → 1p → 5p → 15p → 60p, kiểm ở đầu `_runSync`, reset khi có chu kỳ sạch và khi `start()`/`stop()`. Đồng hồ tiêm được qua tham số `now`. | nt (nhóm G2) |
| **G3** | `schemaVersion` 8 → 9: thêm `syncRetryCount` / `syncError` / `syncBlockedUntil` cho cả 6 bảng. Lỗi **vĩnh viễn** chặn bản ghi theo THỜI GIAN (không đổi `syncStatus` thành `'failed'`, đúng cảnh báo ở mục G3). `markSynced` xoá sạch dấu vết. | nt (nhóm G3) |
| **G4** | Gỡ mọi fallback về admin: `_getAccountId` (có `?? 1` và `return 1`) ở 4 trang bill/goal, **và 9 biểu thức `?? 1` nội tuyến** ở `goal_page.dart` / `goal_add_page.dart`. Thay bằng `current_account.dart` (nay `features/auth/presentation/bloc/current_account.dart`, dời từ `core/auth/` 2026-10-10) trả `int?` — đường ĐỌC dùng `?? 0` (rỗng, không phải dữ liệu admin), đường GHI chặn hẳn kèm thông báo. Bỏ **mọi** nhánh `getAllNonDeleted()` không lọc tài khoản (4 trang + `goal_repository_impl.dart`); nay không còn nơi gọi nào. | `test/features/auth/current_account_test.dart` |
| **G5** | `isLocalDbEmpty` dùng `walletDao.getAll(accountId)`. | — |
| **G8** | Cả 6 chỗ dùng thẳng tham số `idaccount` của `_collectPendingOps`. | `sync_payload_contract_test.dart` |
| **G9** | `conflict` = LWW đã phân xử, server thắng → `markSynced` để thoát vòng đẩy lại vô hạn. | `sync_failure_handling_test.dart` |
| **G11** | `schemaVersion` 7 → 8 + migration `UPDATE categories SET is_local_only = 0, sync_status = 'pending' WHERE is_local_only = 1`. | `category_dao_test.dart` |
| **G12** | `AuthInterceptor` phát `sessionExpiredStream` khi xoá token (chỉ khi thật sự có token để mất, tránh dội sự kiện); AuthBloc nghe kênh này song song với `SyncEngine`. | `test/core/api/auth_interceptor_test.dart`, `session_validation_test.dart` |
| ~~**G10**~~ | ✅ **ĐÓNG 2026-09-07 — không cần backend làm gì.** Bảng ấy tồn tại chỉ vì danh mục mặc định là hàng toàn cục nên không ghi `Idgroup` riêng cho từng tài khoản được. Nay **mỗi tài khoản có bản sao riêng** của bộ mặc định, nên việc gán nhóm nằm gọn trong `Idgroup` của chính hàng họ sở hữu — cột đã có và đã đồng bộ. Client đã gỡ mọi lời gọi tới bảng phụ; bảng còn trong lược đồ cục bộ nhưng không nơi nào ghi vào nữa. Xem `docs/superpowers/specs/2026-09-07-per-account-default-categories-design.md`. | `default_category_seeder_test.dart` |


## 1. Việc đã cố ý hoãn

### ~~G1 — Trạng thái kết thúc của `_runSync()` luôn là `idle`, kể cả khi mọi thao tác đều thất bại~~ · ✅ ĐÃ SỬA (2026-09-03)

**Hiện trạng:** `sync_engine.dart` kết thúc chu kỳ bằng `_setStatus(SyncStatus.idle)` bất kể kết quả. `SyncStatus.error` gần như là mã chết đối với lỗi đẩy dữ liệu, vì `_sendBatch` không ném lỗi ra ngoài nên khối `catch` không bao giờ chạm tới.

**Vì sao hoãn:** đổi trạng thái kết thúc sẽ làm **treo 11 chỗ trong 6 file test** đang chờ đúng `SyncStatus.idle`:

```
test/core/sync/sync_checkpoint_test.dart
test/core/sync/sync_failure_handling_test.dart
test/core/sync/sync_payload_contract_test.dart
test/e2e_sqlite_to_backend_sync_test.dart
test/features/auth/session_validation_test.dart
test/features/category/category_create_test.dart
```

Chúng dùng `await statusStream.where((s) => s == SyncStatus.idle).first` kèm `.timeout(5s)` — đổi trạng thái mà không sửa đồng thời thì test sẽ fail dạng "timeout", rất khó đọc.

**Cách làm khi bắt tay vào:** thêm `SyncStatus.authExpired`, đổi 11 chỗ trên sang chờ **trạng thái kết thúc bất kỳ** (`idle | error | authExpired`) trong cùng một lần sửa. Lưu ý `scheduleSync()` chỉ chuyển sang `pending` khi status đang `idle`, nên nếu status kẹt ở `error` thì nhãn "chờ đồng bộ" sẽ không còn hiện.

**Giá trị thu được:** trung bình. Việc thoát khỏi vòng lặp lỗi đã được giải quyết bằng kênh `sessionInvalidStream` riêng; mục này chỉ làm trạng thái phản ánh đúng thực tế.

---

### ~~G2 — Không có exponential backoff~~ · ✅ ĐÃ SỬA (2026-09-03)

**Hiện trạng:** thao tác thất bại loại `transient` được thử lại ở chu kỳ kế tiếp, không giãn dần. Nguồn kích hoạt gồm: debounce 2 giây sau mỗi lần ghi dữ liệu (nhiều call-site `scheduleSync()` rải khắp các repository), đổi trạng thái kết nối, timer định kỳ 15 phút, và mỗi lần `start()`.

**Vì sao hoãn:** bản bền vững cần thêm cột vào schema (xem G3). Bản chỉ giữ trong RAM thì làm được ngay nhưng mất tác dụng sau mỗi lần mở lại app.

**Cách làm:** `_consecutiveFailures` + `_nextAllowedSyncAt` (30s → 1p → 5p → 15p → 60p), kiểm tra ở đầu `_runSync`. Reset khi có một chu kỳ thành công.

---

### ~~G3 — Lược đồ SQLite không có trạng thái thất bại~~ · ✅ ĐÃ SỬA (2026-09-03)

**Hiện trạng LÚC PHÁT HIỆN (2026-09-02):** `schemaVersion = 7`. Các bảng chỉ có `syncStatus` với đúng hai giá trị được ghi trong thực tế: `'pending'` và `'synced'`. Không có `syncRetryCount`, `syncError`, `syncBlockedUntil`. Một bản ghi lỗi vĩnh viễn vẫn nằm ở `pending` mãi mãi.

**Vì sao hoãn:** cần bump `schemaVersion` + viết migration chạy trên máy người dùng thật — rủi ro cao hơn hẳn các thay đổi thuần logic.

> ⚠️ **Bẫy khi làm:** đừng chuyển `syncStatus` sang `'failed'` rồi loại khỏi `getPending`. Cơ chế thử lại hợp lệ (giao dịch tham chiếu ID danh mục mặc định cũ, phải Pull xong mới đẩy lại được) sẽ chết theo. Dùng `syncBlockedUntil` + backoff thay vì loại vĩnh viễn.

---

### ~~G4 — Nhiều truy vấn không lọc theo tài khoản~~ · ✅ ĐÃ SỬA (2026-09-03)

**Hiện trạng:** `WalletDao.getAllNonDeleted()` không nhận tham số `idaccount`. Còn **5 nơi** đang gọi bản không lọc:

| Nơi gọi | Ghi chú |
|---|---|
| `lib/core/sync/sync_engine.dart:234` | Dùng để tính `isLocalDbEmpty` — quyết định có full pull hay không |
| `lib/features/bill/presentation/pages/bill_add_page.dart:57` | Danh sách ví để chọn |
| `lib/features/bill/presentation/pages/bill_page.dart:45` | nt |
| `lib/features/goal/data/repositories/goal_repository_impl.dart:113` | nt |
| `lib/features/goal/presentation/pages/goal_detail_page.dart:58` | nt |

`TransactionDao.watchAllNonDeleted()` và `GoalDao.watchAllNonDeleted()` cũng cùng dạng.

**Đã giảm nhẹ tới đâu:** đường nguy hiểm nhất — sync engine dùng nó để **suy ra danh tính người dùng** — đã bị gỡ bỏ. Việc đăng nhập cũng gọi `purgeDataForOtherAccounts()` nên dữ liệu tài khoản khác không còn tồn tại trong máy ở điều kiện bình thường.

**Vì sao hoãn:** lịch sử git có commit *"fix(goal): add watchAllNonDeleted fallback query in GoalDao to prevent goals from disappearing on wallet creation"* — tức việc **không lọc** từng được thêm **có chủ đích** để chữa một triệu chứng khác. Thêm bộ lọc mà không hiểu bug gốc đó rất có thể làm nó tái phát.

**Cách làm:** dựng lại kịch bản trong commit kia (tạo ví mới rồi xem danh sách mục tiêu) thành test trước, rồi mới thêm bộ lọc.

---

### ~~G5 — `isLocalDbEmpty` tính trên toàn bộ ví, không riêng tài khoản hiện tại~~ · ✅ ĐÃ SỬA (2026-09-03)

`sync_engine.dart:234` — nếu máy còn ví của tài khoản khác, `isLocalDbEmpty` sẽ là `false` và bỏ qua full pull, dù tài khoản hiện tại chưa có dữ liệu gì. Sửa: dùng `walletDao.getAll(accountId)`. Nhỏ, nhưng nằm trong G4 nên gộp làm một lần.

---

### ~~G6 — `purgeDataForOtherAccounts()` chỉ chạy khi đăng nhập~~ · ✅ ĐÃ SỬA

Hàm dọn dữ liệu tài khoản khác trước đây chỉ được gọi trong `_onLoginSubmitted`. Nay được gọi cả trong `_onAuthCheckRequested` (khôi phục phiên lúc mở app), ngay trước `SyncEngine.start()`.

Test bao phủ: `session_validation_test.dart` — *"Khôi phục phiên cũng dọn dữ liệu tài khoản khác, không chỉ lúc đăng nhập"*.

---

### ~~G7 — Pull ghi cứng `isDeleted = false` cho mọi danh mục~~ · ✅ ĐÃ SỬA

`sync_engine.dart` nay đọc `isDeleted: Value(c['delete_at'] != null)` như các thực thể khác.

Đã kiểm chứng backend **không** lọc `delete_at` khi trả dữ liệu (`getCategoriesByAccount` chỉ lọc theo `is_default`/`create_by`/`update_at`), nên hàng đã xoá thật sự nằm trong response — đây là lỗi thật, không phải giả định.

Test bao phủ: `category_create_test.dart` — *"Pull đọc cờ xoá của danh mục thay vì hồi sinh nó"*.

---

### ~~G8 — Fallback `?? 1` vẫn còn trong khâu dựng payload đồng bộ~~ · ✅ ĐÃ SỬA (2026-09-03)

`sync_engine.dart` dòng 671, 699, 781, 818, 859, 892 — cả 6 thực thể vẫn có `(_currentIdaccount ?? 1)`.

**Hiện KHÔNG gây hại:** `_runSync()` đã có chốt trả về sớm khi `_currentIdaccount == null`, nên nhánh `?? 1` không còn tới được. Nhưng nó vẫn là mìn: ai đó gọi `_collectPendingOps()` từ chỗ khác sẽ làm nó sống lại, và hậu quả là ghi dữ liệu dưới danh nghĩa **tài khoản admin**.

**Cách sửa:** đổi tham số của `_collectPendingOps` thành `int idaccount` bắt buộc và dùng thẳng nó thay cho `_currentIdaccount ?? 1`.

---

### ~~G9 — Trạng thái `conflict` bị bỏ lửng~~ · ✅ ĐÃ SỬA (2026-09-03)

`sync_engine.dart:1009-1014` — thao tác trả về `status == 'conflict'` chỉ được thêm vào `conflictIds` và `debugPrint`. Bản ghi **không** được `markSynced`, **không** tính vào `failed`, và không có bất kỳ mã giải quyết xung đột nào. Nó sẽ được đẩy lại ở mọi chu kỳ sau.

---

### ~~G10 — `CategoryGroupMemberships` không bao giờ được đồng bộ~~ · ✅ ĐÓNG (2026-09-07)

Quan hệ "danh mục mặc định thuộc nhóm nào" lưu trong bảng `CategoryGroupMemberships`, và bảng ấy **không có `SyncEntityType` tương ứng** nên chỉ tồn tại trên một máy.

**Cách đóng không phải là thêm entity.** Bảng phụ ấy tồn tại chỉ vì danh mục mặc định là hàng **toàn cục** — không ghi `Idgroup` riêng cho từng tài khoản lên một hàng dùng chung được. Ngày 2026-09-07 client đổi hướng: mỗi tài khoản có **bản sao riêng** của bộ mặc định, còn hàng toàn cục lui về làm khuôn. Từ đó việc gán nhóm nằm gọn trong `Idgroup` của chính hàng người dùng sở hữu — một cột đã có sẵn, đã nằm trong payload đẩy và đã được `upsertCategory` ghi thật.

Client đã gỡ mọi lời gọi tới bảng phụ. Bảng vẫn còn trong lược đồ SQLite cục bộ vì bỏ một bảng Drift là một migration trên máy đang có dữ liệu, nhưng **không nơi nào ghi vào nó nữa**.

---

### ~~G11 — Không có migration đưa `isLocalOnly` của dữ liệu cũ về `false`~~ · ✅ ĐÃ SỬA (2026-09-03)

**Mô tả lúc phát hiện (2026-09-02):** `schemaVersion` khi ấy vẫn là 7. Người dùng đã có nhóm danh mục tạo **trước** phiên 2026-09-02 sẽ mang `isLocalOnly = true`, và bộ lọc trong `getSyncableCategories` sẽ loại chúng khỏi batch đẩy — tức **nhóm cũ không bao giờ lên backend**, chỉ nhóm tạo mới mới lên.

**Cách sửa:** bump `schemaVersion` lên 8 + migration `UPDATE categories SET is_local_only = 0, sync_status = 'pending' WHERE is_local_only = 1`.

---

### ~~G12 — `AuthInterceptor` xoá token khi refresh thất bại nhưng không báo cho ai~~ · ✅ ĐÃ SỬA (2026-09-03)

`auth_interceptor.dart` — `_clearTokens()` được gọi ở dòng 54 và 69, bản thân hàm nằm ở dòng 130-133. Không có mã nào trong `lib/` lắng nghe sự kiện này. App sẽ kẹt ở trạng thái `AuthSuccess` với token đã bị xoá: mọi request sau đó không có header → 401 → refresh (đã mất refresh token) → xoá lại → lặp cho tới khi khởi động lại app.

Kênh `sessionInvalidStream` thêm trong phiên 2026-09-02 mới chỉ nối từ **SyncEngine**, chưa nối từ interceptor.

---

### ~~G13 — Kích hoạt đồng bộ bị giãn cách từ chối thì không được hẹn lại~~ · ✅ ĐÃ SỬA (2026-09-03)

Phát hiện khi chạy app thật, không phải khi đọc mã: xoá một ngân sách trong lúc engine đang giãn cách thì thao tác đó **không lên tới backend**, kể cả sau khi giãn cách đã hết. Phải chờ tới lần mở app sau.

Đây là kiểu hỏng tệ nhất về mặt trải nghiệm: mục biến mất khỏi màn hình ngay lập tức nên người dùng tin là xong, trong khi máy khác vẫn thấy nó nguyên vẹn.

**Nguyên nhân:** nhánh giãn cách trong `_runSync` chỉ `debugPrint` rồi `return`. Ba nguồn kích hoạt còn lại đều thưa hoặc ngẫu nhiên — timer 15 phút, đổi trạng thái mạng, và `start()` lúc mở app — nên khoảng chờ thật dài hơn bậc giãn cách rất nhiều. Đã đo: chờ thêm 60 giây **sau** mốc hết giãn cách vẫn không có lệnh đẩy nào.

**Bản vá:** `_scheduleBackoffRetry()` — từ chối một yêu cầu đồng bộ nghĩa là **nợ người gọi một lần chạy**, nên hẹn giờ chạy lại đúng lúc hết giãn cách. Nhiều kích hoạt bị chặn liên tiếp dùng chung một hẹn giờ, nếu không thì mỗi lần ghi dữ liệu lại đẩy mốc chạy lại lùi về sau.

Bốn test canh vùng này ở `test/core/sync/sync_failure_handling_test.dart`, nhóm G2.

> ⚠️ Bản vá này chỉ rút ngắn **độ trễ**. Nguyên nhân khiến engine rơi vào giãn cách ngay từ đầu vẫn còn nguyên — xem G14.

---

### ~~G14 — 5 danh mục cá nhân đẩy hỏng vĩnh viễn, kéo theo mọi thứ khác chậm~~ · ✅ ĐÃ SỬA Ở CLIENT (2026-09-03)

> **Bản vá:** `PersonalDefaultCategories` tách làm hai giai đoạn. `convertLegacyRows()` chạy trước chu kỳ đồng bộ đầu tiên và **chỉ đụng tới máy còn hàng seed `cat_*`** — máy sạch thì không tạo gì. `ensureMissing()` chạy **sau** khi pull xong, lúc đã biết tài khoản thật sự đang có những gì. `auth_bloc` gọi hai giai đoạn đúng thứ tự ở cả đường đăng nhập lẫn khôi phục phiên, và chỉ gọi giai đoạn 2 khi `SyncEngine.hasCompletedPull` — pull hỏng thì hoãn tới lần mở app sau chứ không tạo mù.
>
> Cũng vá luôn một lỗ hổng có sẵn từ bản gốc: hàng seed `cat_*` **tự khớp tên với chính nó**, bị dùng làm đích trỏ tới rồi bị xoá mềm ngay sau — giao dịch kết thúc ở một danh mục đã xoá. Nay `_findOwned` loại chính hàng đó ra khỏi tập ứng viên.
>
> 6 test canh vùng này ở `test/features/category/data/personal_default_categories_test.dart` (còn 6 sau khi nhóm `foldIntoBackendDefaults` bị gỡ ngày 2026-09-07 — xem G16).
>
> **Máy đã lỡ tạo bản trùng cũng đã tự thoát được.** Bản vá trên ngăn phát sinh mới; bước khử trùng lặp sau pull dọn nốt hậu quả cũ — xem cuối mục này.

Đo được trên app thật ngày 2026-09-03 với tài khoản có sẵn dữ liệu, bằng cách đọc log của `SyncEngine` trong trình duyệt:

```
[SyncEngine] Push failed [transient]: entity=category, localId=6d16eab1-…, reason=
… (5 danh mục, lặp lại ở MỌI chu kỳ)
[SyncEngine] Real Sync Complete: 0/5 synced successfully.
[SyncEngine] Đang trong thời gian giãn cách sau 2 chu kỳ hỏng — hoãn tới 19:50:31
```

**Chuỗi nguyên nhân**, đã đối chiếu bằng truy vấn PostgreSQL:

1. Backend **đã có** 5 danh mục cá nhân của tài khoản (Chi khác, Thu khác, Làm thêm, Trả nợ, Thu nợ), mỗi cái một UUID — do một máy trước đó tạo ra và đẩy lên.
2. Trên một máy chưa từng chạy app, `PersonalDefaultCategories.ensureForAccount()` sinh lại đúng 5 danh mục đó với **UUID mới**.
3. Đẩy lên vi phạm quy tắc trùng tên → backend trả `status: failed` **kèm message rỗng**.
4. `reason` rỗng nên `_classifyFailure` không nhận ra được gì, xếp vào `transient` → **thử lại vĩnh viễn**.
5. Mọi chu kỳ đồng bộ vì thế kết thúc ở trạng thái hỏng → giãn cách luỹ tiến 30s → 1p → 5p → 15p → 60p.

**Bán kính ảnh hưởng rộng hơn tài liệu cũ ghi.** `CATEGORY_NAME_UNIQUENESS.md` mô tả hậu quả là "vi phạm trùng tên hỏng âm thầm". Thực tế nặng hơn: 5 thao tác hỏng vĩnh viễn này giữ engine trong giãn cách gần như liên tục, nên **mọi thay đổi khác** — ví, giao dịch, ngân sách — đều bị đẩy chậm theo. G13 chỉ rút ngắn độ trễ đó, không xoá được nó.

#### Nguyên nhân là THỨ TỰ chạy ở client, không phải ID không ổn định

> ⚠️ Bản ghi đầu tiên của mục này (commit `25915ec`) quy sai cho `CATEGORY_STABLE_IDS.md`. Đọc lại mã nguồn thì không phải vậy. Giữ lại đính chính này vì nó đúng kiểu sai mà mục 4 dưới đây cảnh báo: kết luận từ một tài liệu liên quan thay vì từ mã nguồn.

`ensureForAccount()` **có** kiểm trùng — nó gọi `getNamesInUse(idaccount)` rồi so bằng `normalizeCategoryName`, và chỉ tạo khi không thấy bản nào cùng tên ([`personal_default_categories.dart:55-66`](../src/Client-app/lib/features/category/application/personal_default_categories.dart)).

Vấn đề là nó chạy **trước** `SyncEngine.start()` trong `auth_bloc.dart` (cả hai đường: đăng nhập và khôi phục phiên). Đó là chủ ý, có ghi chú hẳn hoi: việc chuyển dữ liệu cũ trỏ vào hàng seed `cat_*` phải xong trước khi chu kỳ đồng bộ đầu tiên chạm vào. Nhưng trên máy mới, CSDL cục bộ **rỗng** nên phép kiểm trùng không thấy gì → tạo 5 UUID mới → pull sau đó mới kéo về 5 bản của backend → trùng tên.

Hai hướng sửa, đều thuần client:

- **Hoãn tới sau lần pull đầu tiên khi không có gì để chuyển đổi.** Nếu trong máy không tồn tại hàng `cat_*` nào thì lý do "phải chạy trước start()" không còn, và chờ pull xong mới tạo là an toàn.
- **Khử trùng lặp sau pull.** `removeDuplicateLocalSeedCategories()` đã làm việc tương tự nhưng chỉ cho `isDefault = true` và chỉ xoá bản có id không phải UUID — không xử lý được hai danh mục **người dùng** cùng tên mà cả hai đều là UUID. Cần mở rộng, kèm repoint tham chiếu trước khi xoá (repoint TRƯỚC, xoá SAU — đảo lại chính là lỗi 11.6).

**Phần thuộc backend là lớp phòng thủ thứ hai, không phải điều kiện tiên quyết:** cho `/sync/push` trả mã lỗi ổn định `CATEGORY_NAME_DUPLICATE` thay vì message rỗng, để client xếp được vào `permanent` bằng một dòng trong `_classifyFailure`. Đáng làm vì **mọi** vi phạm trùng tên khác cũng sẽ hỏng theo đúng kiểu này, không riêng 5 danh mục trên.

#### Dọn hậu quả trên máy đã lỡ tạo bản trùng · ✅ ĐÃ LÀM (2026-09-03)

Bản vá thứ tự chỉ ngăn phát sinh mới. Máy nào đã chạy bản client cũ và tạo ra 5 danh mục trùng thì chúng vẫn nằm ở `pending` và vẫn hỏng mỗi chu kỳ. `CategoryDao.mergeDuplicatePersonalCategories(idaccount)` dọn nốt phần đó, chạy **sau pull**, ngay sau `removeDuplicateLocalSeedCategories()` trong `SyncEngine`.

Cách nó chọn bản giữ lại:

- Gom các danh mục **không mặc định, chưa xoá** của tài khoản theo `normalizeCategoryName` — không tính `classify`, đúng quy tắc 7.
- Chỉ hành động khi nhóm có **đúng một** bản `synced` — đó là bản backend công nhận. Không bản nào hoặc nhiều hơn một thì bỏ qua, không đoán bừa.
- Chỉ hấp thụ các bản `pending`. Một hàng đã `synced` không bao giờ bị xoá — nó có thể đang được máy khác dùng.

`_absorbCategory()` **repoint TRƯỚC, xoá SAU** (đảo lại chính là lỗi 11.6):

1. `repointCategoryReferences()` — giao dịch, ngân sách, hoá đơn.
2. `parentId` của các danh mục con.
3. Từ khoá phân loại — bỏ qua những từ khoá bản giữ lại đã có, vì khoá duy nhất là `(idaccount, categoryId, normalizedKeyword)`.
4. Xoá thành viên nhóm của bản bị hấp thụ.
5. **Xoá vật lý** hàng đó.

Xoá vật lý là ngoại lệ có chủ ý của quy tắc 5: hàng `pending` này **chưa từng tồn tại trên server**, nên không có gì để đồng bộ; xoá mềm sẽ để lại đúng một thao tác đẩy vô nghĩa — thứ đang gây ra chính vấn đề này.

`removeDuplicateLocalSeedCategories()` vẫn giữ nguyên vai trò cũ: nó chỉ lo cho `isDefault = true` và chỉ xoá bản có id không phải UUID. Hai hàm bổ sung nhau chứ không chồng nhau.

9 test canh vùng này ở `test/core/database/category_dao_test.dart`, nhóm `mergeDuplicatePersonalCategories — dọn bản trùng do máy tự tạo`.

---

### G15 — Bản ghi vừa hết hạn vừa hỏng đồng bộ thì không sửa được · ✅ ĐÓNG (2026-09-07)

Tab **"Đã hết hạn"** của trang ngân sách khoá cả sửa lẫn xoá — đúng yêu cầu: số
liệu đã chốt sổ không được đổi về sau. Nhưng khoá đó không phân biệt "đã chốt
sổ" với "hỏng, chưa bao giờ lên tới server".

Một ngân sách rơi vào **cả hai** trạng thái kẹt không lối thoát: không đẩy lên
được (backend từ chối vĩnh viễn), mà cũng không mở ra sửa hay xoá được. **Đã
gặp thật** ngày 2026-09-04 với một ngân sách bị sửa thành `end = start`, vi phạm
`chk_budget_end_after_start`; lối thoát duy nhất khi ấy là xoá dữ liệu site của
trình duyệt rồi pull lại từ server.

**Đã sửa 2026-09-07** theo đúng hướng ghi sẵn ở đây: *khoá thao tác là để bảo
vệ số liệu đã chốt, không phải để nhốt dữ liệu hỏng.*

- Quy tắc gom về **một nơi**: `domain/budget_locking.dart`,
  `budgetActionsLocked({expired, budget})`. Trước đó phép kiểm nằm rải **ba**
  chỗ trong giao diện — chặn vuốt xoá, bỏ nút Sửa trên trang chi tiết, và (chỗ
  thật sự quyết định) danh sách hết hạn dựng thẻ mà **không truyền** `onEdit`/
  `onDelete`. Nới hai chỗ đầu mà quên chỗ thứ ba thì không có gì đổi cả.
- `BudgetEntity` nay mang `syncError` (cột đã có sẵn trong bảng từ G3, chỉ là
  chưa đưa lên tầng model) và `hasSyncError`.
- Thẻ hỏng có dấu hiệu riêng — biểu tượng `cloud_off` kèm chữ "Chưa đồng bộ
  được". **Không** nêu nguyên văn lỗi backend: nó là stack trace hoặc câu
  tiếng Việt của server, cả hai đều không giúp người dùng làm gì.
- Dòng thông báo đầu tab đổi theo: câu cũ "không sửa hay xoá" nay chỉ hiện khi
  **không có** thẻ hỏng. Để nguyên là giao diện nói sai về chính nó — người
  dùng thấy một thẻ sửa được ngay dưới dòng bảo không sửa được.

**Yêu cầu gốc KHÔNG bị nới.** Ngân sách hết hạn và đồng bộ sạch vẫn khoá y như
trước. Hai phép canh cho chiều ấy nằm cùng chỗ với phép canh cho ngoại lệ:
`budget_locking_test.dart` (ca *"hết hạn và đồng bộ sạch thì khoá"*) và
`budget_tabs_view_test.dart` (ca *"bản ghi SẠCH vẫn khoá, kể cả khi có thẻ
hỏng"* — mở cả danh sách vì có **một** thẻ hỏng là bỏ luôn yêu cầu gốc mà không
ai nhận ra).

⚠️ Chuỗi `syncError` **rỗng** không tính là hỏng. Vài đường ghi xoá cột ấy về
rỗng chứ không về `null`; coi rỗng là "đang hỏng" sẽ mở khoá cho **mọi** ngân
sách hết hạn. Có test canh riêng ca này.

---

### ~~G16 — Xoá một danh mục cá nhân mặc định thì nó mọc lại ở mỗi lần mở app~~ · ✅ ĐÃ ĐÓNG (2026-09-05)

Chuỗi năm bước, mỗi bước đều đúng theo ý đồ riêng của nó, nhưng ghép lại thì hỏng:

1. Người dùng xoá một trong 5 danh mục cá nhân mặc định. Xoá mềm, đẩy lên, server đặt `Delete_at`.
2. Lần mở app sau, `PersonalDefaultCategories.ensureMissing()` chạy (gọi ở `auth_bloc.dart:135` khi đăng nhập và `:176` khi khôi phục phiên).
3. Hàm đó hỏi `CategoryDao.getNamesInUse()` xem tài khoản còn thiếu gì. Nhưng `getNamesInUse` lọc `isDeleted = false` **và** `deletedAt IS NULL` — nên nó **không thấy hàng người dùng vừa xoá**, và kết luận là còn thiếu.
4. `_create()` tạo lại danh mục với **UUID mới**, `syncStatus = 'pending'`.
5. Đẩy lên đụng `uq_category_owner_name_classify` phía PostgreSQL. Index đó **không có mệnh đề `WHERE`** nên hàng đã xoá mềm vẫn giữ chỗ tên → PostgreSQL trả **23505**.

Và bản ghi đó không thoát ra được: `_classifyFailure` (`lib/core/sync/sync_engine.dart`) không có nhánh nào cho vi phạm UNIQUE — chỉ có `23514` cho ràng buộc CHECK — nên 23505 rơi vào `transient` và được **đẩy lại ở mọi chu kỳ**. `_markBlockedById` chỉ chạy với `permanent`, nên bản ghi giữ nguyên `pending` mãi mãi.

**Mỗi lần mở app lại thêm một bản ghi kẹt.**

**Vì sao trước đây không ai thấy.** `getNamesInUse` lọc hàng đã xoá là **cố ý và đúng** — quy tắc 7 nói "hàng đã xoá mềm không giữ chỗ", nên người dùng phải tạo lại được danh mục cùng tên. Lỗi nằm ở chỗ `ensureMissing` dùng nhầm hàm đó để trả lời một câu hỏi khác: *"tài khoản này có chủ ý không muốn danh mục đó không?"* — chứ không phải *"tên này còn trống không?"*.

**Đã làm ở phía client (2026-09-04):** `_classifyFailure` có thêm `_uniqueConstraintPattern` khớp `23505 | violates unique constraint | unique constraint failed` → xếp `permanent`. Bản ghi hỏng nay bị chặn **theo thời gian** thay vì đẩy lại ở mọi chu kỳ, nên nó không còn kích hoạt giãn cách luỹ tiến và không kéo chậm các thay đổi khác. Hai test canh chừng ở `test/core/sync/sync_failure_handling_test.dart` — một cho dạng câu chữ Prisma bọc, một cho mã SQLSTATE trần, vì Prisma đổi cách diễn đạt theo phiên bản.

> ⚠️ Đây là **lớp cầm máu, không phải bản vá gốc**. Bản ghi vẫn được tạo ra ở mỗi lần mở app, chỉ là không còn đẩy lại vô hạn.

~~**Còn chờ backend:** thêm `WHERE "Delete_at" IS NULL` vào unique index~~ — ✅ **backend làm xong 2026-09-07**, xem đoạn cuối mục này. Hồ sơ: `CATEGORY_NAME_UNIQUENESS.md` mục 4.1 và mục 10 của `2026-09-04-ocr-classify-review.md`. Khi có, bản ghi bị chặn tự quay lại hàng đợi mà người dùng không phải làm gì.

> ### ⚠️ Cập nhật 2026-09-07 — cách đóng đã đổi, nhưng G16 vẫn đóng
>
> `foldIntoBackendDefaults()` **đã bị gỡ**. Hướng đi đảo chiều: mỗi tài khoản nay
> có **bản sao riêng** của toàn bộ bộ mặc định (`DefaultCategorySeeder`), còn
> hàng toàn cục lui về làm khuôn và không hiện ra ở đâu. Để hàm gộp chạy song
> song với bước sao chép là một vòng lặp huỷ lẫn nhau.
>
> **Vì sao G16 vẫn không quay lại:** luật tạo bản sao đếm **cả hàng đã xoá mềm**.
> Người dùng xoá một danh mục thì hàng xoá mềm còn đó, và lượt seed sau nhìn thấy
> nó nên **không tạo lại**. Ba chữ ấy là khác biệt **duy nhất** với `ensureMissing()`
> — ai "dọn dẹp" chúng đi là tái hiện nguyên vẹn G16.
>
> Thiết kế: `docs/superpowers/specs/2026-09-07-per-account-default-categories-design.md`.
>
> Phần dưới giữ nguyên làm hồ sơ của chặng 2026-09-05.

**Đóng ngày 2026-09-05 — bằng cách bỏ hẳn nguồn kích hoạt.** Câu hỏi mà `ensureMissing` không trả lời được ("chưa từng có" hay "người dùng đã cố tình xoá") nay **không cần trả lời nữa**: backend đã nhận đúng 5 danh mục ấy vào bộ mặc định của nó (`Create_by = 1`, `Is_default = true`), nên không tài khoản nào phải giữ bản riêng.

`ensureMissing()` được thay bằng `foldIntoBackendDefaults()`: gộp bản riêng vào bản mặc định (dời tham chiếu ở cả `transactions`, `budgets`, `bills`) rồi **xoá mềm** bản riêng — và **không tạo mới gì cả**. Danh mục mặc định là toàn cục, không thuộc tài khoản nào, nên không còn gì để "mọc lại" ở mỗi lần mở app.


Ba điều kiện dừng, vì gộp là thao tác phá huỷ:

| Tình huống | Xử lý |
|---|---|
| Không thấy bản mặc định (backend cũ, hoặc pull hỏng) | Không đụng gì — không tạo, không xoá |
| Trùng tên nhưng **khác classify** | Không gộp. Quy tắc 7 không tính classify, nên một danh mục người dùng tự tạo có thể trùng tên mà khác loại; gộp nó là âm thầm đổi loại của mọi giao dịch bên trong |
| Hàng của tài khoản khác | Không đụng. `getNamesInUse` trả cả hàng mặc định của mọi tài khoản nên phép lọc phải nằm ở chính chỗ tìm bản riêng |

~~Test canh chừng: nhóm `foldIntoBackendDefaults` — chín ca.~~ **Nhóm ấy đã bị xoá cùng hàm, 2026-09-07.** Phép canh cho cơ chế hiện tại nằm ở `test/features/category/application/default_category_seeder_test.dart` — 13 ca, trong đó ca *"bản sao đã bị xoá mềm thì KHÔNG tạo lại"* chính là phép canh G16.

✅ **Phần lệch ràng buộc với CSDL cũng đã đóng — 2026-09-07.** Trước đó `uq_category_owner_name_classify` không có `WHERE "Delete_at" IS NULL`, nên hàng đã xoá mềm vẫn giữ chỗ tên ở PostgreSQL trong khi client cho tạo lại (quy tắc 7): xoá rồi tạo lại một danh mục **của chính mình** cùng tên vẫn nhận 23505. Đợt migration 2026-09-07 thay nó bằng hai partial unique index **có** mệnh đề ấy — và bỏ luôn `Classify` khỏi khoá, đúng quy tắc 7. Đo trên CSDL thật cùng ngày.

⚠️ Lớp cầm máu `_uniqueConstraintPattern` trong `_classifyFailure` **vẫn giữ, đừng gỡ.** Nó không còn phục vụ ca trên nữa, nhưng 23505 vẫn xảy ra được — hai người dùng khác nhau trùng tên danh mục mặc định, hay bất kỳ ràng buộc UNIQUE nào khác — và không có nó thì bản ghi hỏng quay lại bị đẩy ở mọi chu kỳ. Từ 2026-09-07 nhánh phân loại đi theo `code` của backend (`UNIQUE_VIOLATION`, `CATEGORY_NAME_DUPLICATE`), regex chỉ còn là đường dự phòng.

---

### G17 — Trang đọc theo tài khoản không đăng ký lại khi phiên tới muộn · ✅ ĐÓNG (2026-09-07)

Tái hiện nhiều lần trên máy ảo. Vào Mục tiêu **ngay sau khi mở app nguội** thì
danh sách rỗng dù CSDL có dữ liệu; thoát ra vào lại là thấy.

**Nguyên nhân gốc — ghi chép cũ nói sai.** Bản ghi 2026-09-05 đổ cho `?? 0`.
Nhưng `?? 0` chỉ làm lỗi **im lặng** thay vì nổ; bỏ nó đi thì trang hiện thông
báo lỗi thay vì danh sách rỗng — vẫn hỏng, chỉ ồn ào hơn.

Gốc thật: `GoalPage` đọc mã tài khoản **đúng một lần**, bên trong
`BlocProvider.create`. `currentAccountIdOrNull` dùng `context.read<AuthBloc>()`
— `read` **không đăng ký** gì cả — và `create` chỉ chạy một lần trong đời của
provider. Trang dựng trước khi phiên khôi phục xong sẽ đăng ký `watchGoals(0)`
rồi **giữ nguyên đăng ký ấy mãi**. Thoát ra vào lại thì provider mới được dựng,
lúc đó phiên đã sẵn sàng — đúng cách người dùng vô tình "chữa" nó.

`home_page` và `transaction_page` không mắc lỗi này vì chúng dùng
`context.watch<AuthBloc>()`.

**Đã sửa cho trang Mục tiêu (2026-09-07):** `context.watch<AuthBloc>()` để
build chạy lại khi phiên tới, cộng `key: ValueKey(idaccount)` trên
`BlocProvider` để `create` chạy lần nữa với đúng tài khoản. Thiếu khoá thì
`watch` chỉ khiến build chạy lại mà cubit vẫn giữ đăng ký cũ — hai nửa phải đi
cùng nhau. Test canh: `goal_page_cold_start_test.dart`, đỏ đúng chỗ trước bản
vá (`Expected: contains <10>, Actual: [0]`).

**Đã kiểm và sửa cả bốn trang đọc theo tài khoản.** Mỗi trang có test riêng,
và mỗi test đều **đỏ trước** ở đúng assertion "phiên tới rồi mà trang chưa bao
giờ hỏi lại":

| Trang | Hỏng vì | Bằng chứng đỏ | Bản vá |
|---|---|---|---|
| `goal_page` | `currentAccountIdOrNull` + `BlocProvider.create` (chạy một lần) | `Actual: [0]` | `watch` + `ValueKey` |
| `budget_page` | y hệt | `Actual: []` ở assertion thứ hai | `watch` + `ValueKey` |
| `wallet_list_page` | y hệt, **cộng** bản chép tay `int.tryParse(user?.id ?? '') ?? 0` | `Actual: [0]` | `watch` + `ValueKey`, và gọi `currentAccountIdOrNull` thay bản chép tay |
| `bill_page` | **Khác:** nạp trong `addPostFrameCallback` của `initState` với `if (accountId == null) return;` | `Actual: []` | `watch` + `_thuNap()` gọi từ `build`, hoãn việc phát sự kiện sang `addPostFrameCallback` |

Ba trang đầu dùng chung bản vá `context.watch<AuthBloc>()` + `key:
ValueKey(idaccount)`. **Hai nửa phải đi cùng nhau:** thiếu `watch` thì build
không chạy lại, thiếu khoá thì build chạy lại mà cubit vẫn giữ đăng ký cũ.

`bill_page` không dùng được khoá vì nó **không có `BlocProvider`** — `BillBloc`
do router cung cấp. Ở đó bản vá là một hàm `_thuNap()` gọi từ `build`, có chốt
`_daNapCho` để chỉ nạp một lần cho mỗi mã tài khoản, và **hoãn việc phát sự
kiện** sang `addPostFrameCallback` — phát sự kiện bloc trong lúc dựng là lỗi
khung.

**Việc gỡ được kèm theo:** `wallet_list_page` là bản chép tay **cuối cùng** của
phép suy mã tài khoản mà G4 sinh ra để xoá bỏ. Nay cả bốn trang đều đi qua
`currentAccountIdOrNull`.

**Còn lại, cố ý chưa làm:** một trạng thái *"đang chờ phiên"* — khác hẳn *"không
có dữ liệu"* — dùng chung cho mọi trang. Bản vá hiện tại làm trang **tự khỏi**,
nhưng trong vài nhịp đầu người dùng vẫn thấy màn rỗng chứ không thấy "đang tải".
Đó là việc giao diện, tách riêng được, và không còn lỗi nào chờ nó.

⚠️ **`?? 0` giữ nguyên, có chủ ý.** Đây là bài học G4: đường ĐỌC không được
mặc định về `1` (tài khoản admin thật), và `0` là "rỗng, không phải dữ liệu
của ai". Nay nó chỉ còn là trạng thái **tạm** trong vài nhịp đầu, vì khoá
`ValueKey` kéo trang về đúng tài khoản ngay khi phiên tới.

---

### G18 — Nhánh dự phòng của lịch sử tích luỹ vẫn so bằng TÊN mục tiêu · ⏸️ THU HẸP DẦN (2026-09-07)

`TransactionDao.watchByGoal` có hai nhánh: nối bằng `goal_id` cho hàng có ID, và
`note LIKE '%Tích lũy mục tiêu: <tên>%'` cho hàng không có. Nhánh thứ hai mang
đúng khuyết điểm mà `goal_id` sinh ra để chữa — mục tiêu tên `"Mua"` vẫn nuốt
lịch sử của `"Mua xe"`.

**Đã đổi 2026-09-07:** backend có cột `transaction.Idgoal`, và client nay **đẩy**
`idgoal` trong payload giao dịch **lẫn đọc lại** ở nhánh pull. Nguồn sinh ra hàng
thiếu ID đã tắt: từ nay mọi hàng đi qua đồng bộ đều mang liên kết.

**Vì sao vẫn chưa gỡ được nhánh so tên:** hàng **đã nằm sẵn** trên server đều
mang `Idgoal = NULL`, vì chúng được đẩy lên trước khi client biết gửi trường này.
Chúng chỉ nhận ID khi được đẩy lại — tức khi người dùng sửa gì đó, hoặc không bao
giờ. Bỏ nhánh so tên bây giờ là lịch sử tích luỹ **đã có** biến mất khỏi màn hình.
Nhánh ấy nay **teo dần** thay vì đứng yên; gỡ được khi không còn hàng nào
`goal_id IS NULL` mà ghi chú khớp mẫu.

**Đã đo trên máy thật** (`emulator-5554`, tài khoản 10, 2026-09-07): trước bản vá,
cả **12** giao dịch tích luỹ trên server đều `Idgoal = NULL` — chính con số ấy là
thứ nhánh `Value.absent()` bảo vệ. Sau bản vá, gửi thêm 1.000 đ vào `MuaXe` sinh
ra hàng **đầu tiên** có `Idgoal`, và giá trị khớp chính xác `idgoal` của mục tiêu
(`dc2656fa-…`); `current_amount` đi từ 1.100.000 lên 1.101.000. Mười hai hàng cũ
vẫn `NULL` — đúng như mô tả ở trên, chúng chỉ nhận ID khi được đẩy lại.

⚠️ **Nhánh pull dùng `Value.absent()`, KHÔNG ghi đè null.** Server im lặng về
`idgoal` nghĩa là *chưa biết*, không phải *hãy xoá*. Ghi đè thẳng thì đúng ở chu
kỳ đồng bộ đầu tiên sau bản vá, mọi liên kết cục bộ đang có bị xoá sạch và toàn
bộ lịch sử rơi xuống nhánh so tên — tái hiện nguyên vẹn G18 mà không có lỗi nào
báo ra. Đã dựng bản ngây thơ để xem test có bắt được không: **có**, và đó là
`'hàng server KHÔNG có idgoal thì liên kết cục bộ phải còn nguyên'`.

⚠️ Điều kiện `goal_id IS NULL` ở nhánh dự phòng là thứ chặn không cho một hàng
đã có chủ bị mục tiêu khác nhận vơ. **Đừng bỏ nó khi dọn dẹp.**

---

### G19 — Tiến độ mục tiêu và số dư ví lệch nhau được, và app chỉ cảnh báo · ✅ CỐ Ý (2026-09-05)

Ghi ở đây để người sau **không "sửa"** nó.

Tiêu tiền từ ví tích luỹ bằng một giao dịch thường không hạ `current_amount` —
giao dịch ấy không mang `goal_id`. Mục tiêu có thể ghi "đã tích 2 triệu" trong
khi ví chỉ còn 300 nghìn.

**App không tự hoà giải, và đó là chủ ý.** Không đủ căn cứ để hoà giải đúng: một
ví phục vụ được nhiều mục tiêu, ví tích luỹ cũng chứa tiền không thuộc mục tiêu
nào, và tự hạ tiến độ là bất ngờ với người dùng. `canhBaoViKhongDu()` phơi ra sự
lệch để họ tự quyết. Lý do đầy đủ ở `docs/GOAL_FEATURE.md` mục 3.4.

Muốn tiến độ phản ánh thực tế thì phải **đánh dấu** khoản rút — luồng "Rút khỏi
mục tiêu" đã có, nhưng khoản chi tiêu thường thì theo định nghĩa không thuộc mục
tiêu nào.

---

### ~~G20 — Giao dịch trích bù mang dấu thời gian **lúc bù**, không phải mốc của kỳ~~ · ✅ ĐÃ SỬA (2026-09-05)

**Hiện trạng:** bộ trích tự động chạy trong vòng quét, tức khi app mở. Bỏ app ba
ngày với chu kỳ hàng ngày thì ba kỳ được trích bù cùng lúc — và cả ba hàng giao
dịch đều mang `date = DateTime.now()`, tức thời điểm bù. Đã đo trên máy ảo: ba
khoản của kỳ 06, 07, 08/09 đều ghi `2026-09-08 14:28`.

Thông báo thì **ngược lại** — nó lấy mốc kỳ làm `createdAt`, nên trung tâm thông
báo hiện đúng ngày từng kỳ. Hai nơi nói hai chuyện khác nhau về cùng một sự
việc.

**Bán kính ảnh hưởng:** không sai một đồng nào — số tiền, số dư ví và tiến độ
đều đúng. Chỉ phần thống kê **theo ngày** thấy ba khoản dồn vào một ngày.

**Vì sao hoãn (bối cảnh gốc):** `depositToGoal` cố tình không nhận tham số ngày;
nó luôn ghi "bây giờ", đúng như một khoản nạp tay. Thêm một tham số `date` tuỳ
chọn là mở đường cho nơi gọi khác truyền vào một ngày bịa — và đó là tầng ghi
tiền, chỗ ít đáng nới lỏng nhất. Muốn sửa thì phải làm cùng lúc: thêm tham số,
chặn nó ở mọi đường gọi khác, và viết test canh chừng.

**Đã sửa thế nào:** `depositToGoal` nhận `occurredAt`, chặn **hai đầu** (không ở
tương lai, không trước `startDate` của mục tiêu). Nơi gọi duy nhất là
`GoalAutoDepositRunner`; đường nạp tay không truyền, và `GoalCubit` cố ý không
phơi tham số ra. Chỉ cột `date` lùi lại — `updatedAt` vẫn là "bây giờ" vì nó là
sổ sách đồng bộ. Chi tiết và các phương án đã loại: mục **3.14** `GOAL_FEATURE.md`.

**Kiểm trên máy ảo 2026-09-05:** ba kỳ bù ghi lúc 17:30 mang `date` 06/07/08-09
lúc 08:00 với cùng một `updated_at` 17:30, và lịch sử tích luỹ (`orderBy: date
desc`) **xen kẽ đúng ngày** thay vì dồn lên đầu — đúng chỗ mà ghi chú cũ dặn phải
kiểm bằng mắt.

⚠️ **Bẫy để lại cho người sau:** runner nhận `now` tiêm vào, còn `depositToGoal`
đọc `DateTime.now()` — ở production hai thứ ấy là **một** đồng hồ. Bộ test cũ giả
lập kịch bản ở **tương lai** nên vỡ ngay khi phép chặn đầu trên ra đời; nay cả
`goal_auto_deposit_runner_test.dart` nằm trong quá khứ. Đừng "sửa" nó ngược lại.

---

### G21 — Cấu hình trích tự động không theo người dùng sang máy khác · ✅ ĐÓNG (2026-09-07)

**Đã đóng.** Backend thêm ba cột `auto_deposit_amount`,
`auto_deposit_wallet_id`, `auto_deposit_last_run` vào bảng `goal` trong đợt
2026-09-07; client đẩy và kéo **cả ba cùng một lúc**. Bật trích ở máy A rồi
đăng nhập máy B thì B nhận đủ cấu hình **lẫn mốc kỳ gần nhất**, nên nó không
trích lại kỳ mà A vừa trích xong.

**Đã đo trên máy thật, không chỉ bằng test** (`emulator-5554`, tài khoản 10,
2026-09-07): mục tiêu `MuaXe` vốn đã bật trích 100.000 đ/tháng từ ví `test`
nhưng ba cột trên server vẫn `null` — đúng vì trước bản vá chúng không bao giờ
được đẩy. Bấm Lưu một lần là cả ba lên tới PostgreSQL: `auto_deposit_amount`
= 100000, `auto_deposit_wallet_id` = ví **`test` (Cash)**, `auto_deposit_last_run`
có giá trị. Mục tiêu `MuaDT` (không bật trích) vẫn `null` cả ba, nên không phải
ghi bừa. Đáng chú ý nhất: ví nguồn khác hẳn `idwallet` = ví **`Tiết kiệm`
(Saving)** là ví NHẬN — gửi nhầm một trong hai thì app sẽ trích tiền từ đúng cái
ví lẽ ra phải nhận, và không có gì báo lỗi.

⚠️ **Ba cột vẫn phải đi cùng nhau.** `auto_deposit_last_run` là cột chặn trích
hai lần. Ai đó "dọn dẹp" payload và bỏ nó ra thì mỗi máy giữ một mốc riêng và
**cả hai cùng chuyển tiền** — tệ hơn hẳn hiện trạng cũ, nơi máy thứ hai đơn
giản là không trích gì. `sync_payload_contract_test.dart` khoá bộ khoá của
payload mục tiêu (21 trường **lúc ấy** — đếm lại bằng máy 2026-09-18 từ chính
tệp test: **22**, sau khi `priority` vào ngày 2026-09-08) nên nó bắt được ngay.

**Khe hở còn lại, chấp nhận được:** hai máy cùng mở, cùng tới kỳ, cùng chưa kịp
kéo `last_run` của nhau thì vẫn trích hai lần. Hẹp vì trích chỉ chạy khi app mở,
và `Current_amount` là giá trị tuyệt đối nên LWW hội tụ chứ không cộng dồn sai.
Vá triệt để cần một khoá phía máy chủ trên `(Idgoal, kỳ trích)` — phụ thuộc
`transaction.Idgoal`, cột đã có và client đẩy/đọc từ 2026-09-07 (xem **G18**);
còn khoá phía máy chủ ấy thì chưa có (đo 2026-09-11: bảng `goal` không có ràng buộc
duy nhất nào ngoài khoá chính). ✅ **2026-10-10:** chạy nền làm khe ấy thành ca thường (hai máy cùng tự chạy lúc 08:00), nên nó được vá ở client
bằng **id tất định** `idKhoanTrichTuDong` (UUID v5 của mục tiêu + mốc kỳ UTC): hai máy cùng trích một kỳ thì server chỉ
có **một** hàng (LWW), máy thấy hàng cùng id đã có thì không trừ tiền. Không cần khoá phía máy chủ.

---

### ~~G22 — Giờ trong mốc trích chỉ giữ được MỘT chiều~~ · ✅ MỞ LẠI VÀ LÀM (2026-10-10; trước đó ✅ CỐ Ý 2026-09-05)

> ✅ **2026-10-10 — người dùng mở lại quyết định dưới đây** sau khi được nêu rõ người dùng thấy khác ở đâu: giao dịch
> vốn đã ghi theo **mốc kỳ** nên sổ và số dư không đổi; thứ đổi là **thông báo đúng lúc** và **máy khác thấy ngay** (lượt
> nền đồng bộ). Spec `docs/superpowers/specs/2026-10-10-tu-chuyen-tien-chay-nen-design.md`. Trên **Android**:
> `TuChuyenTienWorker` (WorkManager, lượt một-lần theo mốc + định kỳ 6 giờ) — app đang mở thì gọi `quetNgay` vào engine
> của app, app đóng thì dựng engine headless chạy `chayNenTuChuyenTien`. Rủi ro "kết nối SQLite thứ hai" dưới đây được
> trả lời bằng ba chốt: **khoá thuê** `khoa_tu_chuyen_tiens` (một câu `UPDATE` nguyên tử — khoá tệp không chặn hai
> isolate cùng tiến trình), `busy_timeout`, và `autoDepositLastRun` ghi **cùng giao tác** với khoản nạp. Hai **máy**
> cùng trích một kỳ: id tất định `idKhoanTrichTuDong` (UUID v5) → server một hàng. Hoá đơn tự trả chạy lúc **giờ nhắc
> chung** ngày đến hạn. Còn đúng: giờ không chính xác tới phút (WorkManager lùi khi máy ngủ sâu); Realme/ColorOS
> force-stop khi vuốt Recents **huỷ** WorkManager (giới hạn hãng); **iOS** giữ nguyên hành vi dưới đây. Đoạn dưới giữ
> làm lịch sử.


Ghi ở đây để người sau **không "sửa"** nó, và không hứa với người dùng nhiều hơn
những gì app làm được.

Người dùng chọn được "ngày 15 hàng tháng lúc 08:00". Giờ ấy được tôn trọng theo
chiều **không bao giờ sớm hơn** — nhưng bộ trích chạy khi app mở, nên nếu 21 giờ
mới mở app thì nó trích lúc 21 giờ.

Có một lời nhắc đặt trước qua AlarmManager nổ đúng 08:00 kể cả khi app đóng
(`ReminderScheduler`), nhưng nó chỉ **báo tin**; tiền vẫn chỉ chuyển khi mở app.

**Vì sao không làm WorkManager:** tác vụ nền phải mở một kết nối SQLite **thứ
hai** vào cùng tệp để chuyển tiền. Đây là chỗ duy nhất trong app tự chuyển tiền
khi người dùng vắng mặt; đổi vài giờ sớm hơn lấy rủi ro ấy là không đáng. Quyết
định này do người dùng chọn sau khi được nêu cả ba phương án.

**Nếu vẫn muốn làm:** `GoalAutoDepositRunner` viết độc lập với *khi nào* nó được
gọi, nên thêm một trigger nền chỉ là gọi `chay()` thêm một chỗ nữa. Phần khó nằm
ở kết nối CSDL trong isolate nền, không nằm ở logic trích.

---

### G23 — Bản sao danh mục chỉ đầy đủ khi bộ mặc định CỤC BỘ đầy đủ · ⏸️ CHẤP NHẬN ĐƯỢC (2026-09-07)

`DefaultCategorySeeder` sao chép từ những hàng mặc định **đã có trên máy này**
(`getBackendDefaults()` đọc SQLite, không gọi mạng). Mà pull là **tăng dần theo
`since`**: hàng nào không đổi kể từ mốc kiểm cuối thì không bao giờ được gửi lại.

Hệ quả: một máy có thể chỉ biết một phần bộ mặc định của server, và bản sao thiếu
theo. **Đo được 2026-09-07 trên `emulator-5554`:** server có **18** hàng mặc định,
máy ấy tạo được **13** bản sao (hai trong số còn lại bị chặn đúng luật vì tài
khoản từng có bản riêng cùng tên; ba cái còn lại đơn giản là chưa từng về máy).

**Vì sao không sửa ngay:** bước seed chạy sau **mọi** lần pull và luỹ đẳng (⚠️ câu này chỉ
đúng với mã từ 2026-10-20 — cổng `SyncEngine.sauKeoVe`; trước đó mã gieo một lần mỗi phiên, sau `start()`), nên
khi một hàng mặc định thật sự về máy thì bản sao được tạo ở lượt kế tiếp. Người
dùng không mất gì — họ chỉ có ít danh mục dựng sẵn hơn, và tự thêm được.

**Nếu muốn dứt điểm:** cần một lần pull đầy đủ bộ mặc định (bỏ `since` cho riêng
nhánh `is_default = true`) ở lần đăng nhập đầu. Đó là thay đổi ở đường đồng bộ,
không phải ở bước seed — đừng vá bằng cách cho seeder gọi mạng.

---

### ~~G24 — Màu danh mục không đi qua đồng bộ, vì client dùng sai tên khoá~~ · ✅ ĐÓNG (2026-09-11; trước đó cùng ngày ghi "lỗi phía client, sửa được, chưa sửa", và 2026-09-07 ghi "không có chỗ trên server · ⛔ chặn ở backend")

> ✅ **Đã sửa 2026-09-11 (TDD).** `SyncPayloadNormalizer.categoryForPush` đổi `colour` → `color` — một chỗ phủ cả thao tác
> danh mục đang chờ lẫn danh mục mà bước 1b gửi kèm, vì cả hai đi qua normalizer ở bước POST; nhánh kéo về đọc
> `c['color']` (`null` thì rơi về màu cục bộ như cũ). Test: một ca ở `sync_payload_normalizer_test.dart`; trong
> `sync_payload_contract_test.dart` tập khoá danh mục nay khoá `'color'`, ca kéo về đọc `color`, và ca mới "server chưa
> có màu thì màu cục bộ còn nguyên" — ba ca đầu đỏ đúng lý do trước khi sửa. **Kiểm trên máy ảo:** mở "Ăn uống" ở màn
> Quản lý danh mục, lưu lại không đổi gì → đẩy `1/1`, không xung đột → `category.Color` từ `NULL` thành `#FF5722`, kéo về
> vẫn `#FF5722`.
>
> ⚠️ **Danh mục đã `synced` từ trước vẫn mang `Color = NULL` trên server cho tới khi được lưu lại.** Đẩy cùng mốc
> `update_at` thì server trả xung đột "bản server mới hơn" và giữ bản của nó — nên bước 1b (gửi kèm danh mục khi đẩy
> giao dịch) **không** tự bổ sung màu. Chưa bổ sung hàng loạt: đổi `updatedAt` của mọi danh mục để đẩy lại là thay đổi
> dữ liệu, chờ người dùng quyết. Đoạn dưới là ảnh chụp trước bản sửa.

**Hiện trạng (đo 2026-09-11, sau khi gộp `main` @ `cc65f4f` và CSDL dev áp `database/12`).**
Server **đã có** chỗ: cột `category."Color"` (`varchar(9)`), `/sync/push` nhận khoá
`color` (`sync.repository.js:149`, ghi ở nhánh tạo `:175` và nhánh sửa `:196`), và
`/sync/pull` trả `color` (`:228`). Backend không có nhánh nào đọc `colour`.

Client thì vẫn nói **`colour`** cho danh mục, ở cả hai chiều:

- payload danh mục dựng tay mang `'colour'` ở **hai** chỗ: `sync_engine.dart:1025` (thao tác
  danh mục đang chờ) và `:1109` (bước 1b — kèm danh mục người dùng mà một giao dịch chờ trỏ
  tới, nên chỗ này gửi `colour` ở **mọi** lần đẩy một giao dịch có danh mục);
- `SyncPayloadNormalizer.categoryForPush` (`sync_payload_normalizer.dart:101-116`)
  **không** đổi khoá — khác `walletForPush` ngay trên nó (`:82-83`), vốn đổi
  `colour` → `color`;
- nhánh kéo về đọc `c['colour']` (`sync_engine.dart:603`), nên luôn nhận `null`;
- và `sync_payload_contract_test.dart:333` khoá `'colour'` trong tập khoá danh mục
  — tức **chính bộ test đang canh bản sai**.

Hệ quả không đổi so với ảnh chụp bên dưới — màu chỉ sống trên máy đã chọn — nhưng
**nguyên nhân đã đổi**: không còn là thiếu cột mà là lệch tên khoá. Đúng kiểu hỏng
im lặng của quy tắc 4 `CLAUDE.md`, và nay nằm hẳn ở phía client.

**Kiểm đầu-cuối 2026-09-11** (máy ảo, tài khoản 10, backend của nhánh đã gộp): danh mục
"Ăn uống" (`70b7e251-…`) mang `colour = '#FF5722'` trong SQLite nhưng `category."Color"`
vẫn `NULL` trên PostgreSQL sau hai lần đẩy, và bộ chọn danh mục hiện mọi danh mục bằng màu
mặc định. Mỗi lần đẩy một giao dịch có danh mục, bước 1b gửi kèm danh mục ấy và server trả
xung đột "bản server mới hơn" (hai bên cùng `Update_at`) — vô hại, không ghi đè gì, nhưng là
lý do log đồng bộ báo `1 conflicts` ở những lần ấy.

**Cách sửa (thuần client) — ✅ đã làm 2026-09-11 theo đúng ba bước dưới:**

1. **Đẩy:** đổi `colour` → `color` trong `categoryForPush`, theo đúng khuôn
   `walletForPush`. Chọn **một** chỗ đổi (normalizer hoặc hai chỗ dựng payload),
   đừng cả hai.
2. **Kéo về:** đọc `c['color']` (có thể giữ `c['colour']` làm dự phòng). Nhánh ấy
   đã rơi về màu cục bộ khi server trả rỗng (`sync_engine.dart:629-640`), nên hàng
   server còn `Color = NULL` **không** xoá màu đang có trên máy.
3. **Cập nhật `sync_payload_contract_test.dart` cùng lúc:** tập khoá danh mục
   `'colour'` → `'color'`, và thêm một ca kéo về như ca ví ở `:639`.

⚠️ Sửa xong thì màu chỉ lên server khi danh mục được **đẩy lại** — hàng đã
`synced` từ trước vẫn mang `Color = NULL` cho tới lần sửa kế tiếp, cùng dạng
"teo dần" với G18. Phía backend không cần làm gì; hai việc **tuỳ chọn** ghi ở mục
18 §2.3 (`CAN-LAM/VERIFY_7675B35_REMAINING.md`): nhận thêm bí danh `colour` cho
bản client cũ, và `getDefaultCategories` chưa trả `color`.

> **Ảnh chụp 2026-09-07 — lý do cũ, đúng tới trước khi gộp `main`.** Bốn đoạn dưới
> giữ nguyên làm hồ sơ; vế "không có cột" và "client không sửa được" nay **sai**.

Bảng `category` phía PostgreSQL có **đúng 12 cột** và không cột nào cho màu.
Client vẫn đẩy khoá `colour` lên ở mỗi lần đồng bộ, backend **bỏ qua im lặng** —
đúng kiểu hỏng mà quy tắc 4 của `CLAUDE.md` mô tả, lần này còn khó thấy hơn vì
tên trường không sai, chỉ là không có chỗ nào để ghi.

Hệ quả: màu người dùng chọn **chỉ sống trên máy đã chọn**. Đăng nhập máy khác
hoặc cài lại app là mất, không lỗi, không log.

Lỗi này **có sẵn từ trước**, không do thay đổi 2026-09-07 sinh ra — nhưng bán
kính vừa rộng ra hẳn: trước đây người dùng gần như không đổi màu được gì vì hàng
mặc định là toàn cục và bị chặn sửa; nay họ sở hữu cả bộ và sửa được từng cái.

**Client không sửa được** — không có cột thì không có chỗ ghi. Tài liệu xin:
`docs/superpowers/backend/DA-XONG/CATEGORY_COLOUR_COLUMN.md`.

---

### G25 — Hai máy cùng sắp lại thứ tự ưu tiên khi ngoại tuyến thì được một thứ tự trộn · ✅ CỐ Ý (2026-09-08)

Thứ tự ưu tiên mục tiêu (schema v19) đồng bộ qua cột `Priority`, và phép phân
xử của dự án là **LWW theo từng hàng**. Sắp lại danh sách thì lại là một thao
tác trên **cả danh sách**. Hai thứ ấy không khớp nhau.

Máy A kéo `MuaXe` lên đầu, máy B kéo `MuaDT` lên đầu, cả hai đang ngoại tuyến.
Khi cùng đẩy lên, mỗi hàng thắng riêng theo `Update_at` của nó — kết quả có thể
là một thứ tự **không giống lần sắp nào**. Không hàng nào sai, không có lỗi,
không có gì trên màn hình nói ra điều đó.

**Vì sao không vá:**

- Vá triệt để cần khoá thứ tự kiểu **phân số hoặc chuỗi** (`"a0"`, `"a0V"`, lối
  của LexoRank) thay cho số nguyên. Đó là đổi cả kiểu dữ liệu ở hai đầu, cho
  một tình huống cần hai máy cùng hoạt động và cùng ngoại tuyến.
- Hậu quả tệ nhất là người dùng **kéo lại vài mục tiêu**. Không mất tiền, không
  mất bản ghi, không kẹt hàng đợi đẩy — khác hẳn G21, nơi cấu hình trích tự
  động không sang máy khác thì tiền không được chuyển mà cũng không ai biết.
- FlowMoney gần như luôn chỉ có một máy hoạt động cho mỗi tài khoản.

**Bán kính:** `uuTienSauKhiKeo`, `GoalRepositoryImpl.capNhatUuTien`, và nhánh
`priority` của `sync_engine.dart`. Ghi ở đây để người sau không tưởng chỗ này
bị bỏ sót — nó đã được cân nhắc, và lý lẽ nằm ở
`docs/superpowers/backend/DA-XONG/2026-09-05-backend-goal-priority.md` mục 5.

> ⚠️ Đừng nhầm với một lỗi **khác** cũng thuộc vùng mục tiêu, nay **đã sửa**
> (2026-09-08): `GoalDetailPage` không nghe dòng dữ liệu (bẫy 4.5
> `GOAL_FEATURE.md`), nên đồng bộ kéo về một thay đổi của mục tiêu **đang mở**
> thì màn hình vẫn hiện số cũ. Bán kính của nó vừa rộng ra vì `priority` nay
> cũng đi qua đường đồng bộ. Đó là lỗi **sửa được ở client**, không phải một
> đánh đổi — nên nó không có mục G nào và nằm trong danh sách việc phải làm.

---

### ~~G26 — Không có màn "Giao dịch chờ duyệt" cho giao dịch ngân hàng về~~ · ✅ ĐÓNG BẰNG QUYẾT ĐỊNH SẢN PHẨM (2026-09-18)

> ✅ **Đóng 2026-09-18 — nhóm BỎ HẲN tính năng liên kết ngân hàng.** Mục này
> không còn là một lỗ hổng: màn duyệt giao dịch ngân hàng không thiếu, nó
> **không còn nằm trong sản phẩm**. Phần client của luồng ấy đã gỡ cùng ngày —
> màn mockup `bank_link_page.dart`, thẻ "LIÊN KẾT NGÂN HÀNG" ở màn Quản lý ví,
> hai route, và `RealtimeEvent.giaoDichNganHang`. Xem khối
> "🏦 Gỡ phần client của liên kết ngân hàng" ở mục 14 `docs/PROJECT_CONTEXT.md`.
>
> ⚠️ **Hệ quả cho việc lên kế hoạch:** đoạn "Bán kính nếu làm" dưới đây từng đặt
> `status` và `provider` vào hàng đợi "sẽ phải thêm vào hợp đồng đồng bộ". Nay
> **không**: hai cột ấy ở lại ngoài hợp đồng, và đừng viện mục này để mở chúng
> ra. Backend vẫn giữ module `bank/` cùng ba endpoint của mình — đó là việc của
> họ, client không xin gì.
>
> Phần còn lại giữ nguyên làm ảnh chụp lý do hoãn ban đầu.

Khi nối Socket.io, client bắt được sự kiện `bank_transaction.incoming` và hiện
một toast. Nhưng nó **không** có chỗ nào để người dùng *duyệt* giao dịch ấy —
gán danh mục, xác nhận hoặc từ chối.

Backend đã có sẵn cả ba endpoint (`api/bank.routes.js`):

- `GET  /api/bank/pending-transactions`
- `POST /api/bank/confirm-transaction`
- `POST /api/bank/reject-transaction`

**Vì sao hoãn:** đây là **một tính năng riêng**, không phải phần còn thiếu của
việc nối socket. Nó kéo theo cả một luồng liên kết ngân hàng (`register-account`,
`link-url`, WebView của SePay), một màn danh sách, và một khái niệm mới trong
giao diện — "giao dịch chưa được duyệt" — mà SQLite cục bộ hiện **không phân
biệt được**: cột `status` và `provider` có trong bảng nhưng **không nằm trong
hợp đồng đồng bộ theo chiều nào cả** (quy tắc 4 `CLAUDE.md`), nên một giao dịch
`Pending` kéo về qua `/sync/pull` trông y hệt một giao dịch bình thường.

**Bán kính nếu làm:** thêm `status`/`provider` vào hợp đồng đồng bộ (và do đó
vào `sync_payload_contract_test.dart`), một màn hình mới, và một badge đếm ở
tab Giao dịch. ⚠️ **Phải lên Stitch trước** — đây là màn hình mới, chưa có
thiết kế nào.

**Không chặn gì đang chạy.** Kênh realtime vẫn có ích mà không cần nó: mọi sự
kiện đều đánh thức đồng bộ, nên giao dịch ngân hàng vẫn hiện ra trong danh sách
sau vài giây thay vì sau 15 phút.

---

### ~~G27 — Không còn cách nào nói "ví này được phép âm"~~ · ✅ ĐÓNG (2026-09-17)

> ✅ **Đóng 2026-09-17 — cờ `Wallets.allowNegative`, schema v23.** Ví đánh dấu
> "cho phép âm" không sinh cảnh báo số dư nào cả (**cả** `walletNegative` lẫn
> `walletLowBalance`, đúng luật mà chốt `debt` cũ đã có), và màn Quản lý ví thôi
> tô đỏ **cả biểu tượng lẫn số tiền**. Công tắc ở màn Thêm ví và Sửa ví.
>
> ⚠️ **Cột CỤC BỘ, không đi qua đồng bộ** — payload ví vẫn **13 trường**. Bật cờ
> trên máy A thì máy B không biết. Mở đồng bộ cần một cột PostgreSQL và một tài
> liệu `CAN-LAM`; người dùng chốt **không** mở lại hàng đợi ấy. Có **test quét
> `lib/` thứ bảy** canh cờ không lọt vào `sync_engine` / `sync_payload_normalizer`
> / hợp đồng payload — đúng bài học `wallet.status`, nơi ba chú thích ở ba tệp
> khác từng nói một cột cục bộ là "đi ra máy khác".
>
> **Bản sai có chủ ý: bảy lượt**, và **hai** trong bảy đi lọt ở vòng đầu — cả hai
> đều là lỗ hổng trong chính bộ test vừa viết, không phải trong mã:
>
> 1. Ca *"cờ cũng tắt cảnh báo SẮP CẠN"* dựng ví số dư **−5.000.000**, mà nhánh
>    sắp cạn chỉ chạy khi `balance >= 0` — nên nó **không canh gì**, y hệt G43.
>    Số dư phải **dương** và dưới ngưỡng thì ca mới có nghĩa.
> 2. Ca datasource đặt **sai tiền đề**: quên cột trong `_toCompanion` **không**
>    làm cờ tự tắt — `write(companion)` chỉ ghi cột có mặt, nên giá trị cũ ở
>    lại và triệu chứng thật là **cờ không đổi được**. ⚠️ Chú thích của `status`
>    ngay cạnh trong `_toCompanion` mang đúng nhận định sai ấy; chưa sửa, đã ghi
>    lại trong ca test.
>
> ⚠️ Máy ảo bắt được một chỗ **nửa việc**: bản đầu chỉ đổi màu **biểu tượng**,
>  còn con số `-100.000 đ` vẫn đỏ chói — mà đó mới là thứ mắt đọc trước. Màu ấy
>  là `AppColors.error`, tức màu **cảnh báo** chứ không phải quy ước dấu; ví lưu
>  trữ đã có sẵn tiền lệ chuyển số âm sang xám vì đúng lý do đó.
>
> Nghiệm thu máy ảo 2026-09-17 với ví `test` (−100.000): migration v23 chạy sạch
> trên CSDL đang có (33 giao dịch nguyên vẹn), bật cờ → ví trung tính hoàn toàn,
> và cờ **sống sót qua `force-stop` + khởi động lại**. ⚠️ Vế thông báo thì lượt
> quét trả `0 hàng mới` **không chứng minh được gì** — khoá chống trùng của ngày
> hôm ấy đã tồn tại từ trước khi bật cờ; vế ấy do bộ test canh.

*Các đoạn dưới giữ nguyên — chúng ghi lại vì sao lỗ hổng này từng tồn tại.*

Từ 2026-09-07, ví loại `debt` mang số dư âm **không** sinh cảnh báo: âm là đúng
bản chất của nó, và trước đó nó bị nhắc mỗi ngày cho tới khi trả hết nợ — đúng
loại nhiễu khiến người dùng tắt cả nhóm thông báo.

Ngày 2026-09-09 loại ví thu về ba (`WalletType`: `cash | bank | saving`) vì
`ewallet` và `debt` vỡ `chk_wallet_type` của PostgreSQL và làm ví **kẹt hàng
đợi đẩy vĩnh viễn**. Ví cũ chuyển thành `bank`, và chốt kia mất chỗ bám: không
còn tín hiệu nào để phân biệt "âm vì đang nợ" với "âm vì ghi nhầm".

**Hệ quả:** ai từng theo dõi thẻ tín dụng bằng ví `debt` nay được nhắc "ví âm"
mỗi ngày trở lại.

**Vì sao hoãn:** chữa đúng cần một khái niệm **mới** — một cờ "ví được phép âm"
trên bảng `wallets` — chứ không phải khôi phục chuỗi `'debt'` đã chết. Cờ ấy là
cột mới ở **cả hai đầu** (client + PostgreSQL, tức một tài liệu `CAN-LAM` nữa),
cho một tình huống mà CSDL hiện **không có hàng nào**: đo 2026-09-09, server chỉ
có ví `Cash` (3) và `Saving` (2).

**Bán kính nếu làm:** cột mới trên `wallets` + hợp đồng đồng bộ
(`sync_payload_contract_test.dart`), một công tắc ở trang sửa ví, và khôi phục
hai nhánh loại trừ trong `_walletCandidates`. Hai test ở
`notification_rules_goal_wallet_test.dart` đã ghi lại chiều cũ lẫn chiều mới —
đọc chúng trước khi làm.

---

### ~~G28 — Lưu trữ ví chỉ sống trên máy đã bấm~~ · ✅ ĐÓNG (2026-09-14; tiêu đề trước ghi "⏸️ hết chặn phía server, chờ client mở lại" 2026-09-10, trước nữa "chặn ở CSDL — tệp `database/7` chưa áp", trước nữa "chặn ở backend")

> ✅ **Đóng 2026-09-14 — `wallet.status` đi qua đồng bộ hai chiều.** Lưu trữ ví trên
> máy A nay có hiệu lực trên máy B của cùng tài khoản. Ba mảnh khớp nhau, thiếu mảnh
> nào cũng vô hiệu cả ba: payload đẩy mang `status` (**13 trường**), `walletForPush`
> dịch sang `'Active'`/`'Inactive'` qua `WalletStatus.khoaGuiLen`, nhánh kéo về đọc
> ngược lại về **chữ thường**. Cộng **migration schema v22** đánh dấu ví lưu trữ cũ
> để đẩy lại — chúng đang ở `synced` nên không ai gửi lại chúng, trong khi cột
> `Status` của server là `NOT NULL DEFAULT 'Active'`; thiếu bước ấy thì lượt pull
> **đầu tiên** sau khi cập nhật app lặng lẽ bỏ lưu trữ chúng. Bốn mảnh vào **cùng một
> commit** (`268eb50`) vì bước cứu chỉ chạy **một lần trong đời** mỗi máy.
> Spec: `docs/superpowers/specs/2026-09-14-g28-luu-tru-vi-qua-dong-bo-design.md`.
>
> ⚠️ **Thứ duy nhất còn có thể làm G28 hỏng, và client không chặn trước được:** máy
> chủ nào **chưa áp `database/7`** vẫn giữ `Status` ở `varchar(7)` và sẽ từ chối
> `'Inactive'` (8 ký tự) — ví lưu trữ **kẹt hàng đợi đẩy vĩnh viễn, im lặng**. CSDL
> dev đã áp (đo 2026-09-14: `varchar(20)`, `NOT NULL`, `DEFAULT 'Active'`); **chưa đo
> môi trường nào khác**.
>
> *Các đoạn dưới giữ nguyên theo thứ tự thời gian — chúng ghi lại vì sao cột này từng
> là cột cục bộ, không phải trạng thái hôm nay.* Dòng cũ ghi *chờ client mở lại* —
> đúng tới trước bản này.

Tính năng **lưu trữ ví** (2026-09-10) ghi trạng thái vào cột `wallets.status`
của SQLite. Cột cùng tên đã có sẵn ở PostgreSQL và `upsertWallet` phía backend
đã xử lý nó ở cả nhánh tạo lẫn nhánh cập nhật — nên nhìn qua thì đây là thứ đẩy
lên được ngay. Nó không.

Lược đồ **tự mâu thuẫn ở đúng cột ấy**, hai phép đo trên cùng một cột:

```
chk_wallet_status => CHECK (("Status")::text = ANY (ARRAY['Active','Inactive']))
Status            => character varying(7)
```

CHECK tuyên bố `'Inactive'` hợp lệ; kiểu cột không chứa nổi nó — chuỗi ấy dài
**8 ký tự**. Không giá trị nào vừa **cả hai** ngoài `'Active'`, nên trên thực tế
cột này là một **hằng số** chứ không phải một trạng thái.

Bản đầu của client có đẩy `status` lên, và trên máy ảo nó **kẹt hàng đợi đẩy**:
backend trả lỗi ràng buộc, bản ghi quay lại hàng đợi và thử lại ở mọi chu kỳ,
kéo chậm cả hàng đợi. Đây là điều `flutter test` **không** bắt được — hợp đồng
đồng bộ được canh bằng adapter giả, không bằng CSDL thật.

**Vì sao không vá ở client:** không có chỗ ghi thì không có cách ghi. Cột được
gỡ khỏi **cả hai** chiều của đồng bộ, cùng diện với `bills.autoPayEnabled` (và
`bills.anchorDay` cho tới 2026-09-12 — nay cột ấy đã đi qua đồng bộ). Chiều **kéo về** phải im lặng cùng lúc chứ không chỉ chiều
đẩy: client không đẩy cột này nên server giữ `'Active'` cho mọi ví của tài khoản còn dùng (chỉ ví của tài khoản đã bị xoá hẳn mới bị `scheduler.service.js` đặt `'Inactive'`)
— nên một bản chỉ gỡ chiều đẩy sẽ khiến ví vừa lưu trữ **tự bỏ lưu
trữ** sau đúng một chu kỳ đồng bộ, im lặng. Có test riêng canh ca ấy, và nó gửi
`'status': 'Active'` chứ không gửi payload thiếu khoá, vì dạng thiếu khoá không
phân biệt được hai cách cài đặt.

**Hệ quả:** hai máy cùng một tài khoản thấy khác nhau, và người dùng không được
báo gì. Cùng hạng với `bill.Auto_pay` nhưng **nhẹ hơn**: lưu trữ ví không tự
tiêu tiền của ai, chỉ làm một ví hiện lại ở máy chưa bấm.

**Bán kính khi mở lại** (phía server đã xong trên CSDL dev tối 2026-09-10 — một dòng `ALTER TABLE`, không cần đụng CHECK —
nó đã cho phép đúng hai giá trị cần thiết), rồi client mở lại **ba chỗ** — nhánh
đẩy và nhánh kéo về của `sync_engine.dart`, cộng `walletForPush` trong
`sync_payload_normalizer.dart` — và cập nhật `sync_payload_contract_test.dart`
cùng lúc (payload đẩy ví **12 → 13** trường). Cả ba chỗ đều còn nguyên chú thích
chỉ ngược về tài liệu xin:
`docs/superpowers/backend/DA-XONG/WALLET_STATUS_COLUMN_WIDTH.md`.

`WalletStatus.khoaGuiLen` (`'Active'`/`'Inactive'`) vẫn ở lại và vẫn được
`wallet_status_test.dart` canh, đúng để ngày nối lại chỉ tốn một dòng — **đừng
đọc nó là mã chết bỏ quên**.

*(Hai đoạn ngay dưới là **ảnh chụp trong ngày 2026-09-10, trước khi áp tệp 7** —
câu "đẩy `'Inactive'` lên lại vỡ" và "CSDL dev vẫn `varchar(7)`" nay **sai**; trạng
thái đúng là đoạn "Cập nhật tối 2026-09-10" cuối mục.)*

✅ **CSDL dev trên máy người dùng đã trở về lược đồ chuẩn** (2026-09-10). Cùng
ngày cột ấy từng bị đổi sang `varchar(16)` **ngoài quy trình**, rồi được hoàn
tác theo yêu cầu **đích danh** của người dùng — đo lại: `varchar(7)`, lịch sử
migration 3 dòng, bốn CHECK đủ, số hàng không đổi. Nên trên máy ấy đẩy
`'Inactive'` lên **lại vỡ** — G28 vẫn đúng trên máy ấy. Diễn biến
đầy đủ ở mục **3b** của `DA-XONG/WALLET_STATUS_COLUMN_WIDTH.md`.

⚠️ **Cập nhật cùng ngày, sau khi gộp `main` (`bef37d3`) — chỗ chặn đã dời từ mã
sang CSDL.** Backend **đã** làm phần của mình từ 2026-09-09 (`7523c8c`, NPBao):
`schema.prisma` khai `wallet.status` là `VarChar(20)`, và bước 4 của
`src/Backend/database/7_Update_Account_User_Delete_Rules.sql` nới đúng cột ấy. Lúc
mục này được viết, commit ấy chỉ nằm trên `main`. Đo lại sau khi gộp: CSDL dev vẫn
`varchar(7)` vì **tệp 7 chưa được áp** — cùng với 8, 9, 10, 11
(`docs/superpowers/backend/DA-XONG/DEV_DB_MIGRATIONS_7_11.md`). Nên câu "lược đồ tự
mâu thuẫn" ở trên đúng với **CSDL**, không còn đúng với **mã nguồn** backend. Bán
kính phía client không đổi: vẫn đúng ba chỗ ở đoạn trên. Người dùng chốt **để
sau** — đừng mở lại khi chưa được hỏi.

✅ **Cập nhật tối 2026-09-10 — tệp 7 đã áp lên CSDL dev.** Người dùng yêu cầu
**đích danh** áp `database/7`–`11`; đo lại: `wallet."Status"` là
`character varying(20)`. Chỗ chặn phía server của G28 **đã hết** trên máy này.
Client **chưa** mở lại ba chỗ — vẫn theo lời chốt *để sau*. ⚠️ Chưa đo môi trường
nào khác (CSDL cloud), đừng suy ra từ máy này.

---

### ~~G29 — `/sync/push` viết lại ghi chú, và bản đã lọc đè lên máy~~ · ✅ ĐÓNG (2026-09-11; tiêu đề trước ghi "⛔ chặn ở backend", 2026-09-10)

> ✅ **Đóng 2026-09-11.** Bộ lọc mới của `7675b35` (gộp về nhánh cùng ngày,
> `utils/content-filter.util.js:122-167`) chỉ coi là số thẻ khi chuỗi **vừa** đúng
> hình dạng số thẻ (`CARD_SHAPE`) **vừa** qua Luhn; chỉ coi là mật khẩu khi từ khoá có
> `:` hoặc `=` theo sau; và không có `pin`. Đo bằng chính hàm `filterSensitiveNote`
> trên đủ **15 ca** của bảng 6.3 trong tài liệu xin: **15/15 đúng**, gồm `CK cho Nam STK
> 1903 4567 8901 23`, `Mua sổ ghi mật khẩu wifi`, `Tích lũy mục tiêu: Két mật khẩu (tự
> động)` (giữ nguyên) và `Thay pin: 350000`. ⚠️ **Chưa đo đầu-cuối** trên máy ảo như lần
> tái hiện bên dưới — backend chưa chạy lại từ mã đã gộp.
>
> **Hở nhỏ, chấp nhận được:** một tên do người dùng tự gõ mà chính nó chứa
> `password:`/`mật khẩu:` thì phần sau vẫn bị lọc — kể cả khi tên ấy nằm trong ghi chú
> do app sinh (`Tích lũy mục tiêu: <tên>`). Dạng ấy trông đúng như một mật khẩu thật;
> bộ lọc không thể phân biệt, và client cũng không.
>
> **Việc cùng gốc còn ở backend, không giữ G29 mở:** khoá mã hoá ghi chú rơi về chuỗi
> viết cứng khi thiếu biến môi trường (mục 18 §2.6,
> `CAN-LAM/VERIFY_7675B35_REMAINING.md`). Không làm hỏng ghi chú nào phía client.
>
> Phần dưới là **ảnh chụp 2026-09-10**; "hai biểu thức bắt nhầm" nói về bộ lọc cũ.
> Lý lẽ *"vì sao không vá ở client"* và cảnh báo về `SensitiveNoteValidator` vẫn đúng.

Đợt `main` ngày 2026-09-10 cho `/sync/push` chạy mọi `note` (giao dịch, ngân sách,
hoá đơn, mục tiêu) qua `filterSensitiveNote()` rồi mới mã hoá. Mục đích đúng — NĐ
13/2023, PCI-DSS. Nhưng hai biểu thức của bộ lọc **bắt nhầm**: phần số thẻ cộng
gộp các số rời nhau và không kiểm Luhn (`0912345678 2500000` thành "số thẻ"; số tài
khoản từ 13 chữ số cũng vậy), còn từ khoá mật khẩu không đòi dấu `:` nên nuốt từ
đứng sau (`mật khẩu wifi` mất `wifi`; `Két mật khẩu (tự động)` mất `(tự`).

**Tái hiện đầu-cuối trên máy ảo:** thêm một khoản qua giao diện với ghi chú
`KiemThuDongBo STK 1903 4567 8901 23 mat khau wifi`. Server lưu bản đã lọc (mã
hoá), và **trong cùng giây** lượt kéo về đè lên SQLite: hàng mang `synced`, màn Sổ
giao dịch hiện `… STK [THÔNG TIN THẺ ĐÃ ĐƯỢC LƯỢC BỎ] Mật khẩu: [ĐÃ LƯỢC BỎ]`. Không
lỗi, không log phía client. Khoản thử đã xoá mềm sau khi đo.

**Vì sao không vá ở client:** đường đè là **chủ ý** của backend —
`docs/progress/Client-app.md` mục 13.9 ghi client "lưu thẳng" `note` kéo về, để bản
sao trên máy cũng được làm sạch khi đó thật là số thẻ. Giữ bản gốc ở client là vô
hiệu bộ lọc đúng chỗ nó có ích; và client cũng không có cách nào biết một chuỗi
kéo về đã bị lọc **nhầm**. Chỗ sửa là độ chính xác của bộ lọc.

**Bán kính:** mất nội dung không đảo ngược ở cả hai đầu; và vỡ quy ước ghi chú do
app sinh — hậu tố `(tự động)` mất thì khoản trích tự động đọc thành nạp tay
(`goal_history_direction.dart`). Tiền tố `Điều chỉnh số dư` và hai tiền tố mục tiêu
sống sót ở mọi ca đã đo. **Chưa hỏng dữ liệu thật:** chạy bộ lọc trên mọi ghi chú
đang có (26 hàng không rỗng, đo 2026-09-10) thì chỉ đúng khoản thử bị viết lại.

⚠️ **Khi làm mục 13.3 của `Client-app.md`** (cảnh báo trước khi lưu): **đừng** dán
mã mẫu `SensitiveNoteValidator` ở 13.10.2 — đo 2026-09-10 nó chặn nhầm **5/10**
ghi chú hợp lệ, gồm cả `Thay pin: 350000` ("pin" là pin điện thoại). Theo quy tắc đã
sửa trong tài liệu xin, và chừa chuỗi do app sinh.

Tài liệu xin: `docs/superpowers/backend/DA-XONG/SYNC_NOTE_FILTER_REWRITE.md`.

---

### ~~G30 — Chỉ một ví Tiết kiệm mỗi tài khoản, vì một index không ai ghi thành luật~~ · ✅ ĐÓNG (2026-09-11; mở 2026-09-10)

> ✅ **Đã gỡ 2026-09-11 (TDD).** `viTietKiemDaCo`, `thongBaoMotViTietKiem`, khối chặn ở
> `WalletLocalDataSourceImpl._kiemRangBuocServer`, và khoá ô "Tiết kiệm" cùng dòng giải thích ở màn Thêm ví đều đã gỡ;
> luật trùng tên ở lại. Test: nhóm "nhiều ví Tiết kiệm — G30" ở `wallet_unique_constraints_test.dart` (thêm ví saving thứ
> hai được, đổi loại sang saving được — đỏ đúng lý do trước khi gỡ; hai ví saving trùng tên vẫn bị từ chối) và ca "đã có
> ví Tiết kiệm vẫn chọn được ô Tiết kiệm" ở `wallet_add_guard_ui_test.dart`; nhóm test của hàm đã xoá ở
> `rang_buoc_vi_test.dart` bỏ theo. **Kiểm trên máy ảo:** tài khoản có ví Tiết kiệm mặc định, màn Thêm ví hiện ô "Tiết
> kiệm" đậm như các ô khác, chạm vào thì được chọn, không còn dòng giải thích (rời màn không lưu).
>
> ⚠️ **Máy chủ nào chưa áp `database/12` vẫn còn index** — ví Tiết kiệm thứ hai tạo trên app sẽ bị từ chối
> (`UNIQUE_VIOLATION`, vĩnh viễn) và kẹt hàng đợi đẩy. Đoạn dưới là ảnh chụp trước khi gỡ.

> ✅ **2026-09-11:** `database/12` (`7675b35`, gộp về nhánh cùng ngày) chạy `DROP INDEX IF EXISTS
> "uq_wallet_saving_active"`, và CSDL dev đã áp — đo `pg_indexes` sau khi áp: index không còn.
> Đoạn dưới là ảnh chụp trước đó. Chốt tạm phía client gỡ cùng ngày — banner ngay trên.

PostgreSQL có `uq_wallet_saving_active ("Idaccount") WHERE "Type" = 'Saving' AND
"Delete_at" IS NULL` từ migration 2026-09-01. Luật ấy **không có** trong
`Rule_project.md` mục 2 lẫn `New_Database.md` 3.2.8 — chỉ có trong SQL, từ bản
`New_Database.sql` 2026-08-26 khi Tiết kiệm còn được coi là "một ví cứng".

Client tạo sẵn ví "Tiết kiệm" (`saving`) cho mọi tài khoản mới, rồi vẫn cho
chọn "Tiết kiệm" khi thêm ví. Ví thứ hai: SQLite ghi bình thường → server trả
23505 → `UNIQUE_VIOLATION` → xếp **vĩnh viễn** → ví không bao giờ lên server;
giao dịch trong ví vỡ `fk_transaction_wallet` → coi là tạm thời → thử lại mãi.
Im lặng, cùng lớp với `ewallet`/`debt`.

**Cách xử lý (người dùng chốt 2026-09-10):** xin backend bỏ index
(`DA-XONG/WALLET_SAVING_INDEX.md`) **và** chặn tạm trong lúc chờ —
`wallet/domain/rang_buoc_vi.dart` (`viTietKiemDaCo`), chốt ở
`WalletLocalDataSourceImpl._kiemRangBuocServer`, và màn Thêm ví khoá ô "Tiết
kiệm" kèm dòng giải thích. Khi backend xác nhận đã bỏ: gỡ `viTietKiemDaCo`, hai
chỗ gọi nó, nhóm test "một ví Tiết kiệm" ở hai tệp test, và dòng này — ✅ đã làm 2026-09-11.

**Không phải gap:** chốt **trùng tên ví** thêm cùng ngày (`viTrungTen`, cùng
tệp) canh `uq_wallet_account_name_active` — luật hợp lý, có trong
`New_Database.md`, ở lại vĩnh viễn.

**Bài học đo:** phép đo 2026-09-09 "không unique index nào ở server" dùng
`pg_constraint`, nơi partial unique index **không hiện**. Đo `pg_indexes`.

### ~~G31 — Tên dài hơn độ rộng cột kẹt hàng đợi đẩy, vì server gọi đó là lỗi tạm thời~~ · ✅ ĐÓNG (2026-09-11; tiêu đề trước ghi "⛔ chặn ở backend", 2026-09-10)

> ✅ **Đóng 2026-09-11** (đo trên mã HEAD sau khi gộp `main` @ `cc65f4f`; **chưa** chạy
> đầu-cuối). Hai vế phía server đều đã sửa:
>
> - `sync.service.js:197-203` ánh xạ `22001` / `P2000` / `value too long for type`
>   **và** `23502` / `P2011` / `P2012` về `CONSTRAINT_VIOLATION`. Mã ấy nằm trong
>   `_permanentCodes` của client, nên bản ghi quá dài bị **chặn theo thời gian** thay vì
>   gửi lại ở mọi chu kỳ, và không còn kéo giãn cách lên cả hàng đợi.
> - `sync.validation.js` tách `validateBatch` (400 chỉ cho lỗi khung của cả lô) khỏi
>   `validateOperation` (lỗi từng thao tác vào `results[i]`) — một giá trị hỏng không
>   còn làm **cả lô** 400.
>
> **Bộ lọc bảy ô tên phía client VẪN GIỮ, đừng gỡ.** Hậu quả của tên quá dài nay là
> "kẹt vĩnh viễn có mã" thay vì "gửi lại mãi" — bản ghi vẫn **không lên server**. Chặn
> lúc người dùng đang gõ vẫn là chỗ duy nhất giữ được bản ghi. Vế "ví bị cắt âm thầm"
> ở dưới **vẫn đúng**: `upsertWallet` còn `substring(0, 100)` ở cả hai nhánh.
>
> Phần dưới là **ảnh chụp 2026-09-10**; câu "không có nhánh cho mã ấy → `DB_ERROR`" và
> đoạn "Còn mở" cuối mục nói về backend trước khi gộp.

Trên PostgreSQL, `wallet.Name`, `goal.Name`, `bill.Name` rộng **100** ký tự và
`category.NameCategory` rộng **200** (đo `information_schema.columns`). Form
client không giới hạn độ dài: quét `lib/` ngày 2026-09-10 được 3 chỗ `maxLength`
/ `LengthLimitingTextInputFormatter`, **không** chỗ nào ở bốn form ấy.

`upsertGoal`, `upsertBill`, `upsertCategory` không cắt chuỗi. Tên dài hơn → Prisma
`P2000` → `sync.service.js` không có nhánh cho mã ấy → `DB_ERROR` → client xếp
**tạm thời** (`_classifyFailure`, `sync_engine.dart:1716`) → gửi lại ở mọi chu
kỳ, và giãn cách luỹ tiến áp lên **cả** hàng đợi. Không lỗi nào hiện ra.

Riêng ví thì không kẹt mà **bị cắt âm thầm**: `upsertWallet` lưu 100 ký tự đầu,
và lượt kéo về mang bản đã cắt về máy (suy từ mã, chưa đo trên máy ảo).

**Cách xử lý:** client giới hạn độ dài ở form, vì client là nơi duy nhất báo được
cho người dùng lúc họ đang gõ; và xin backend ánh xạ `22001` / `P2000` về
`CONSTRAINT_VIOLATION` để bản client cũ cùng mọi nguồn ghi khác không lặp vô hạn —
`docs/superpowers/backend/DA-XONG/SYNC_PUSH_ERROR_MAPPING.md`.

✅ **Phía client xong cùng ngày.** Bảy ô tên — Thêm ví, Sửa ví, Thêm/Sửa mục
tiêu, Thêm hoá đơn, Sửa hoá đơn, Thêm/Sửa danh mục, Nhóm danh mục — đi qua
`GioiHanDoRong` ở `lib/core/utils/gioi_han_do_dai.dart`: 100 cho tên ví, mục
tiêu, hoá đơn; 200 cho tên danh mục. Bộ lọc đếm **code point** chứ không dùng
`maxLength`, vì PostgreSQL đếm `varchar(n)` theo code point còn `maxLength` đếm
theo grapheme — chữ gõ ở dạng tách dấu và emoji sẽ lọt qua. Nó cắt theo trọn cụm
grapheme, và theo đúng chính sách của Flutter về việc có cắt lúc bộ gõ đang ghép
chữ hay không (Android cắt ngay — nên bấm Lưu lúc chữ cuối chưa chốt vẫn không
lọt). Test: 12 ca thuần ở `core/utils/gioi_han_do_dai_test.dart`, và mỗi ô một
widget test. Kiểm trên `emulator-5554`: gõ 120 ký tự vào ô tên mục tiêu, ô dừng
ở 100.

~~**Còn mở:** phía server — bản client đã cài trước đó, Admin-web và mọi nguồn ghi
khác vẫn lặp vô hạn cho tới khi backend ánh xạ lỗi.~~ ✅ Hết từ 2026-09-11 — xem
banner đầu mục. Hàng tạo trước bản vá mà dài hơn cột thì vẫn không lên được (nay bị
chặn theo thời gian thay vì gửi lại mãi); gõ bất kỳ phím nào vào ô tên ở màn Sửa là
bộ lọc cắt nó xuống vừa cột.

### ~~G32 — Mục tiêu chưa sắp nhảy lên đầu danh sách sau một vòng đồng bộ~~ · ✅ ĐÓNG (2026-09-11; tiêu đề trước ghi "⛔ chặn ở backend", 2026-09-10)

> ✅ **Đóng 2026-09-11** (đo trên mã HEAD sau khi gộp `main` @ `cc65f4f` và trên CSDL
> dev đã áp `database/12`; **chưa** chạy đầu-cuối):
>
> - `mapEntityFields('goal')` nay giữ `null` (`sync.repository.js:124`:
>   `m.priority === null ? null : Number(m.priority)`), nhánh tạo mặc định `null`
>   (`:515`), nhánh sửa giữ giá trị cũ khi khoá vắng (`:541`).
> - `database/12` đưa các hàng `Priority <= 0` về `NULL`; trên CSDL dev không còn hàng
>   nào `<= 0`. Môi trường khác chưa đo.
>
> **Lớp đọc `<= 0` là chưa sắp phía client VẪN GIỮ** (`goal/domain/uu_tien_hop_le.dart`,
> ở cả ba ranh giới). Lý do "backend đang ép `0`" nay là lịch sử, nhưng lớp ấy vẫn cần
> cho hàng `0` đã kéo về máy từ trước, cho server chưa chạy tệp 12, và vì PostgreSQL
> **không** có CHECK nào cho `Priority` — push vẫn nhận `0` và số âm từ nguồn ghi khác.
>
> Phần dưới là **ảnh chụp 2026-09-10**; câu "`Number(null) === 0`, nên server lưu `0`"
> và đoạn "Còn mở" cuối mục nói về backend trước khi gộp.

Client gửi `priority: null` cho mục tiêu chưa sắp. `mapEntityFields('goal')` ở
backend gọi `Number(m.priority)`, mà `Number(null) === 0`, nên server lưu `0`.
Lượt kéo về đọc `int.tryParse('0')` thành `0`, và `_soSanhUuTien`
(`goal_grouping.dart:70-73`) xếp `0` **trước** mọi số đã sắp.

**Tái hiện đầu-cuối trên `emulator-5554` ngày 2026-09-10:** tạo mục tiêu
"ThuUuTien" bên cạnh hai mục tiêu đã sắp (100 và 200). Một giây sau khi lưu nó
đứng cuối; 16 giây sau, qua một chu kỳ đẩy rồi kéo, nó đứng **đầu**, và server
mang `Priority = 0`. Không lỗi, không log.

Client không bao giờ tự sinh `priority <= 0` (`goal_priority.dart:101-104`), nên
mọi giá trị ấy kéo về đều là một `null` bị ép.

**Cách xử lý:** xin backend giữ `null`
(`docs/superpowers/backend/DA-XONG/GOAL_PRIORITY_NULL_TO_ZERO.md`); client đọc
`<= 0` như chưa sắp. Phía client chỉ sửa được **hiển thị** trên máy đã cập nhật —
giá trị trên server và bản client cũ vẫn chờ backend.

✅ **Phía client xong cùng ngày.** Một định nghĩa,
`goal/domain/uu_tien_hop_le.dart`, áp ở ba ranh giới: `GoalEntity.fromDrift`
(mọi đường đọc mục tiêu, nên hàng `0` kéo về từ trước bản vá cũng về đúng
chỗ), nhánh kéo về của `SyncEngine` (SQLite lưu `NULL` thay vì `0`), và payload
đẩy lên (gửi `null` thay vì đẩy lại `0`, để hàng tự lành khi backend sửa). Áp ở
cả ba chứ không chỉ chỗ sắp xếp: `_mocChenDuoc` coi `0` là một số thật, nên kéo
thả sẽ tính khe từ nó trong khi danh sách lại xếp nó như chưa sắp. Test: 4 ca
thuần, 1 ca repository, 1 ca payload đẩy, 1 tệp kéo về. Kiểm trên
`emulator-5554`: cài bản vá, "ThuUuTien" — kéo về từ trước bản vá và đang đứng
đầu — về **cuối** danh sách ngay khi mở trang, không cần đồng bộ lại.

~~**Còn mở:** phía server — giá trị `0` vẫn nằm trên server, và bản client đã cài
trước đó vẫn thấy mục tiêu nhảy lên đầu.~~ ✅ Hết từ 2026-09-11 trên CSDL dev — xem
banner đầu mục. Mục tiêu thử "ThuUuTien"
(`f7482924-2326-4105-bc33-abc1d993a4cb`) đã được xoá mềm qua giao diện sau khi
kiểm.

---

### ~~G33 — Trang Xoá tài khoản hứa "đăng nhập lại là tự khôi phục", backend không làm vậy~~ · ✅ ĐÓNG (2026-09-11; mở 2026-09-10)

> ✅ **Đóng 2026-09-11 (TDD).** Bốn phần: (1) `UserModel` mang `status`/`countdown`/`countdownNhanLuc`/`dangChoXoa`, gỡ `pendingDeleteCancelled` (`48b01c5`); (2) `AuthRepositoryImpl.deleteAccount` ghi `PendingDelete` và **không** xoá token/phiên (`d1791dd`); (3) hai thẻ đọc trạng thái ấy — Trang chủ (nút "Để sau"/"Huỷ xoá", `292af8d`) và "Vùng nguy hiểm" ở Cài đặt (hộp đếm N ngày, nút "Huỷ yêu cầu xoá", `f7a02aa` + `ff54c6b`); (4) trang Xoá tài khoản thôi đăng xuất và thôi hứa "đăng nhập lại là tự khôi phục" (`866b870`). `AuthBloc` đọc lại thông tin tài khoản qua sự kiện mới `ThongTinTaiKhoanThayDoi` (`361f898` + `eee607e`); hàm đếm ngày thuần ở `ca44dd8`. Lượt sửa sau soát cuối cả nhánh đóng thêm hai lỗi race: trang Xoá tài khoản và nút huỷ báo `AuthBloc` cả khi đã rời cây giữa lúc gửi/huỷ (`5436544`), và kết quả xoá/huỷ của tài khoản cũ không còn ghi vào tài khoản vừa đăng nhập giữa chừng (`46ad023`). Thẻ chỉ hiện câu chung, không có số ngày, ở hai ca: máy **đã giữ phiên** từ trước khi máy khác gửi yêu cầu xoá (chỉ thấy `PendingDelete` qua `/auth/profile`), và bộ nhớ đệm do bản client cũ ghi (có `countdown` nhưng thiếu mốc nhận `countdown_nhan_luc`). Đăng nhập máy khác hay cài lại app thì **có** số — response đăng nhập mang `countdown`. Xin backend qua CAN-LAM **19** (`AUTH_PROFILE_COUNTDOWN.md`, `GET /auth/profile` trả thêm `countdown`); có trường ấy, client sẽ ghi lại số và mốc nhận mỗi lần `/auth/profile` trả `countdown`, kể cả khi trạng thái khớp — cứu cả ca thứ hai lẫn ca **số cũ sai** (máy giữ số của một lần chờ xoá trước; máy khác huỷ rồi gửi lại yêu cầu; lần mở sau `status` vẫn khớp nên thẻ hiện ít ngày hơn thật).
>
> `flutter test` **2078/2078 pass** (3 phút 23 giây, đo 2026-09-11 ở `0591887`, sau lượt sửa sau soát cuối cả nhánh); 49 test mới ở bảy tệp (đếm bằng máy): `dem_nguoc_xoa_test` (13), `user_model_cho_xoa_test` (5), `auth_repository_cho_xoa_test` (11), `auth_bloc_cho_xoa_test` (5), `the_cho_xoa_trang_chu_test` (6), `vung_nguy_hiem_card_test` (5), `delete_account_page_test` (4). `flutter analyze` **25 issue** — khớp mức nền, không issue nào ở tệp G33.
>
> **Kiểm trên `emulator-5554` (tài khoản 11):** gửi yêu cầu xoá → **không** bị đăng xuất, về Trang chủ, thẻ "Tài khoản đang chờ xoá — Còn 30 ngày…" hiện ra; CSDL: `PendingDelete`, `Countdown = 30`. Huỷ ở Cài đặt → CSDL về `Active`, `Countdown = null`, `Delete_at = null` — tài khoản thử về nguyên trạng. Pixel vàng (tràn bố cục): **0** trên **15** ảnh chụp.
>
> ✅ **Đã sửa ở lượt sửa sau soát cuối cả nhánh (`bf34de2`):** khoảng trống 24dp sau "Để sau" ở Trang chủ khi thẻ đã ẩn — khoảng cách nay nằm trong thẻ. Kiểm trên `emulator-5554` (APK từ `0591887`): bấm "Để sau" thì tiêu đề hero về đúng y=315 px như lúc tài khoản `Active`. **§3.8** ✅ sửa cùng ngày (chi tiết ở `docs/PROJECT_CONTEXT.md` mục 14, khối "Sửa hai lỗi làm mới token — spec §3.8"). ✅ **Phần 1** (§3.1–§3.7) và **§5.1** (hộp thoại bị đẩy ra ở màn Đăng nhập) **làm 2026-09-12** — bảy commit `693de3b` → `fc82a94`; khối "Phần 1 cưỡng chế đăng xuất" mục 14 `docs/PROJECT_CONTEXT.md`. Nhánh **HTTP 401 đã kiểm đầu-cuối trên máy thật** ngày 2026-09-12 — hộp thoại hiện đúng, SQLite giữ nguyên 2 ví và 18 danh mục. Chính lượt kiểm ấy tìm ra **hai** lỗi mà cả 63 ca test không bắt được, cùng một triệu chứng (đăng xuất **không kèm hộp thoại**) nhưng khác nguyên nhân: chốt vào của handler nuốt lời từ chối tới muộn (`ac08ed6`), và lượt đăng xuất trơn về sau đè mất lý do (`40a553d`). Nhánh socket và nhánh làm mới vẫn chờ CAN-LAM 17 A.
>
> Phần dưới là **ảnh chụp 2026-09-10** — mô tả đúng bối cảnh phát hiện lỗi lúc đó, giữ nguyên làm lịch sử.

Có **hai** đặc tả nói ngược nhau về giai đoạn chờ xoá. Bản 2026-08-17
(`docs/superpowers/auth/2026-08-17-auth-account-design.md`, thư mục gitignore)
cho đăng nhập lại trong 30 ngày là **tự khôi phục**; bản
`docs/progress/Client-app.md` mục 12 cho người dùng **dùng tiếp** trong 30 ngày và
huỷ bằng một nút. Backend chạy theo **bản mục 12**: `auth.service.js:309` khai
`pendingDeleteCancelled = false` và không chỗ nào gán lại, còn nhánh
`PendingDelete` của `login` chỉ ghi log rồi cấp token. Client vẫn chạy theo bản cũ:

- `delete_account_page.dart` gửi yêu cầu xong thì đăng xuất, và nói *"hãy đăng
  nhập lại trong vòng 30 ngày — hệ thống sẽ tự động khôi phục tài khoản cho
  bạn"*;
- `login_page.dart` chờ cờ `pendingDeleteCancelled` để hiện "Tài khoản đã được
  khôi phục" — cờ ấy không bao giờ bật.

**Hệ quả:** người dùng tin lời hứa, đăng nhập lại, thấy app chạy bình thường.
Tài khoản vẫn `PendingDelete`, và hết 30 ngày thì bộ đếm ngược của backend ẩn
danh hoá dữ liệu rồi xoá mềm tài khoản. Không một chữ nào báo trước.

**Vì sao chưa sửa:** phát hiện ngày 2026-09-10 trong lúc thiết kế hạng mục cưỡng
chế đăng xuất. Cách sửa — dùng tiếp 30 ngày, thẻ nhắc đóng được trên Trang chủ,
nút huỷ ở Cài đặt, trang Xoá tài khoản thôi đăng xuất và thôi hứa — đã chốt với
người dùng, nằm ở mục 4–5 của
`docs/superpowers/specs/2026-09-10-cuong-che-dang-xuat-va-cho-xoa-design.md`,
**đã duyệt ngày 2026-09-11**, ~~chưa sửa~~ — ✅ **đã sửa cùng ngày**, xem banner đầu mục. Trước tối 2026-09-10 đường này còn không chạy nổi trên CSDL dev
(thiếu cột `Countdown`); nay `database/9` đã áp nên lỗi **xảy ra được thật**.

**Bán kính:** chỉ người đã gửi yêu cầu xoá. CSDL dev hiện không có tài khoản
`PendingDelete` nào (đo tối 2026-09-10).

---

### ~~G34 — Client không nghe `sync.completed`, nên thay đổi từ máy khác vẫn chờ chu kỳ đồng bộ~~ · ✅ ĐÓNG (2026-09-12 tối; mở 2026-09-11)

> ✅ **ĐÓNG 2026-09-12 tối (TDD, kiểm máy ảo hai máy cùng tài khoản).** Phương án chọn: **im lặng** — chỉ
> kéo về, **không toast**. Đây không còn là lựa chọn thẩm mỹ: máy vừa đẩy cũng nằm trong phòng `account_<id>`
> nên nhận lại chính sự kiện của mình, mà payload là hộp đen (§4 spec socket) nên **không phân biệt được máy
> gửi** — một toast "máy khác vừa đổi dữ liệu" sẽ nói **sai** trên đúng máy vừa ghi, sau **mỗi** lần ghi. Kết
> quả đồng bộ đã có dải riêng ở bậc cao nhất (§6.3). Mã: `RealtimeEvent.dongBoXong` ↔ `sync.completed`;
> `canDongBoLai = true`; `loiNhan` đổi kiểu thành `String?` và **`null` là định nghĩa duy nhất của "im
> lặng"** — `AppToast._khiCoRealtime` chỉ đọc getter ấy, không tự liệt kê sự kiện. **Không** đổi
> `noiRealtimeVaoDongBo` hay `SyncEngine`. Test: 4 tệp, **2 ca mới** (`realtime_wakeup_test`, `app_toast_test`),
> hai ca cũ đổi tên/nới; toàn bộ **2218/2218**. **Đo trên máy ảo** với tài khoản thử **13** (`kiemthu_g34`, tạo
> qua OTP mock) — máy A là máy ảo, máy B là `POST /api/sync/push` bằng token thật: ba lần đẩy một ví 12.345đ,
> cả ba lần log backend ghi `Emitted sync.completed to room account_13` và lượt `Pull` của máy A **trong cùng
> giây** (20:20:03, 20:25:16, 20:25:50 theo đồng hồ backend); Trang chủ đổi 24.690đ → 37.035đ, ảnh chụp 2 giây
> sau lần đẩy thứ ba **không có toast**. Hai điều biết mà **chưa** xử lý, cả hai có sẵn từ trước cho mọi sự kiện
> realtime: (1) sự kiện tới đúng lúc `_runSync` của máy nhận đang chạy dở thì `syncNow()` bị bỏ qua không log
> (`sync_engine.dart` chốt `_status == syncing`) — nếu lượt pull đang chạy đã đi qua trước khi máy kia ghi xong
> thì thay đổi ấy chờ kích hoạt kế tiếp; cửa sổ vài trăm mili-giây, không mở G; (2) máy vừa đẩy nhận lại sự kiện
> của mình — thường rơi đúng cửa sổ (1) nên bị bỏ qua miễn phí, nếu không thì thêm một chu kỳ chỉ kéo về, không
> đẩy lại (không thành vòng lặp). Đoạn dưới là ảnh chụp trước bản sửa.

> ✅ **2026-09-12 sáng:** không còn gì chặn ngoài quyết định sản phẩm — sau gộp `main` @ `cbbeeb4`, bắt tay socket nối được (đo máy ảo), nên sự kiện **tới được** client và bị `_khiCoSuKien` bỏ qua đúng như mô tả dưới.

**Phía backend đã xong** (đo trên mã HEAD sau khi gộp `main` @ `cc65f4f`): sau mỗi
`/sync/push`, `sync.service.js:223` publish `sync.completed` vào EventBus →
`notification.service.js:79-90` nghe và gọi `emitSyncCompleted` →
`core/socket.js:203-215` phát tới phòng `account_<idaccount>`, payload
`{summary, timestamp}`. Tài liệu xin: `docs/superpowers/backend/DA-XONG/SOCKET_SYNC_COMPLETED.md`.

**Phía client bỏ qua nó.** `RealtimeSocket` nghe mọi sự kiện bằng `onAny`
(`realtime_socket.dart`), nhưng `realtimeEventFromName` (`realtime_event.dart`) chỉ
dịch **ba** tên — `bank_transaction.incoming`, `ocr.completed`, `ocr.duplicate` — nên
`sync.completed` trả `null`, và `RealtimeChannel._khiCoSuKien` chỉ ghi log "Bỏ qua sự
kiện lạ" (`realtime_channel.dart:193-195`). Không lỗi.
*(Ảnh chụp 2026-09-11. Hai lượt đổi kể từ đó: `sync.completed` **được dịch** từ
tối 2026-09-12 khi G34 đóng, và `bank_transaction.incoming` **thôi được dịch**
từ 2026-09-18 khi nhóm bỏ liên kết ngân hàng. Danh sách hiện nay vẫn là **ba**
tên, nhưng là ba tên khác: `ocr.completed`, `ocr.duplicate`, `sync.completed`.)*

**Hệ quả:** một thay đổi đẩy lên từ máy khác chỉ về máy này ở chu kỳ đồng bộ định kỳ
(`_periodicSyncMinutes = 15`) hoặc khi có kích hoạt khác (mở app, mạng về, người dùng
ghi dữ liệu). Không mất dữ liệu, chỉ chậm. Đây đúng là phần giá trị mà spec
`docs/superpowers/specs/2026-09-09-socket-io-realtime-channel-design.md` đặt vào sự kiện
này: §1 điểm 4, việc số 1 ở §8 ("biến kênh này từ hạ tầng thành giá trị thật"), và
dòng đầu bảng rủi ro §9.

**Vì sao chưa làm:** §2 của spec cố ý **không** bắt sẵn `sync.completed` khi server chưa
phát — *"một nhánh mã không bao giờ chạy tới còn tệ hơn là không có"* — và ghi rằng khi
backend xong thì việc thêm là **một dòng** trong bảng ánh xạ ở §4. Backend nay đã phát,
nhưng hôm nay sự kiện **vẫn chưa tới được client**: bắt tay socket từ chối mọi tài khoản
(`CAN-LAM/FIX_BACKEND_3_REGRESSIONS.md` hồi quy A, và §2.1 của mục 18). Thêm bây giờ thì
kiểm được bằng test nhưng **không** kiểm được đầu-cuối. Chờ người dùng quyết.

**Bán kính khi làm:**

- Một giá trị mới trong `RealtimeEvent`, một nhánh trong `realtimeEventFromName`, và
  một chữ cho `loiNhan`. ⚠️ Trình biên dịch chỉ bắt được `loiNhan` (switch phủ đủ):
  `realtimeEventFromName` có nhánh `default`, còn `canDongBoLai` là `this !=
  RealtimeEvent.ocrTrung` nên giá trị mới **mặc định đánh thức đồng bộ** — đúng ý ở
  đây, nhưng là tự nhiên đúng chứ không phải được kiểm. Cập nhật `test/core/realtime/realtime_event_test.dart` và câu "Ba sự kiện…" ở
  đầu `realtime_event.dart`.
- ⚠️ **Toast:** đồng bộ vốn đã có dải kết quả riêng (bậc cao nhất, §6.3 của spec), nên
  hiện thêm một toast "máy khác vừa đổi dữ liệu" là quyết định giao diện chứ không phải
  mặc định — `loiNhan` hiện bắt buộc có chữ cho mọi sự kiện. Chưa có thiết kế Stitch
  nào cho nó.
- ⚠️ **Máy vừa đẩy cũng nằm trong phòng ấy**, nên nó nhận lại sự kiện của chính mình
  và chạy thêm một chu kỳ. Không thành vòng lặp: `_runSync` chỉ gọi `/sync/push` khi có
  thao tác chờ (`sync_engine.dart:375`), nên chu kỳ thừa chỉ kéo về mà không phát lại.
  Không lọc được theo máy gửi — payload là hộp đen, và mọi máy gửi cùng
  `clientId: 'flutter-client-app'`.
- Kiểm đầu-cuối trên máy ảo cần backend sửa hồi quy A trước.

---

### ~~G35 — Ba màn quản lý danh mục lấy tài khoản với dự phòng `?? 1`~~ · ✅ ĐÓNG (2026-09-11; trước đó cùng ngày ghi "lỗi đang chạy, client sửa được — chưa sửa")

> ✅ **Đã sửa 2026-09-11 (TDD), theo khuôn G4.** Getter của cả ba màn thành
> `int? get _accountId => widget.accountId ?? currentAccountIdOrNull(context)`. Chưa có phiên thì
> `CategoryPage` không mở luồng đọc nào và hiện câu báo; `CategoryAddPage`/`CategoryGroupPage` dừng lượt
> nạp, còn lưu và xoá chặn kèm SnackBar "Chưa xác định được tài khoản đăng nhập". Đường đọc **không** dùng
> `?? 0` như trang ví: `idaccount = 0` là bộ khuôn danh mục mặc định toàn cục (quy tắc 8), đọc nó là hiện bộ
> khuôn ra màn hình. Test: `test/core/auth/khong_du_phong_admin_test.dart` quét `lib/` bằng regex nhiều dòng
> (đỏ đúng ba vị trí trước khi sửa), và `test/features/category/presentation/category_no_session_test.dart` —
> ba màn dựng dưới `AuthInitial` không đọc, không ghi. Kiểm trên máy ảo: có phiên thì màn Quản lý danh mục vẫn
> hiện đủ. Đoạn dưới là ảnh chụp trước bản sửa.

**Tìm ra lúc sửa G24** (đọc `category_add_page.dart` để biết màn sửa có giữ màu cũ không). Cả ba màn dùng chung
một khuôn getter:

```dart
int get _accountId {
  if (widget.accountId != null) return widget.accountId!;
  final state = context.read<AuthBloc>().state;
  return int.tryParse((state is AuthSuccess ? state.user?.id : null) ?? '') ??
      1;
}
```

- `lib/features/category/presentation/pages/category_page.dart:42`
- `lib/features/category/presentation/pages/category_group_page.dart:57`
- `lib/features/category/presentation/pages/category_add_page.dart:85`

Đếm bằng script quét toàn `lib/` với regex **nhiều dòng**, 2026-09-11: đúng ba chỗ. Dạng `?? ⏎ 1;` lọt qua mọi
lượt `grep` một dòng trước đây — đó là lý do G4 và G8 đóng mà ba chỗ này vẫn còn.

`1` là tài khoản **admin thật**, không phải giá trị "chưa biết" — quy tắc 2 `CLAUDE.md`. Khi phiên đăng nhập không
cho ra id, ba màn đọc cây danh mục và ghi danh mục (`saveChild`, `saveGroup`) dưới `idaccount = 1` thay vì từ chối.
Chưa thấy xảy ra trên máy thật; mức nguy hiểm là **ghi dưới danh nghĩa admin**, đúng lớp lỗi G4/G8 đã đóng.

**Tài liệu từng nói ngược:** hai dòng "Không còn `?? 1` ở bất kỳ đâu" trong `docs/PROJECT_CONTEXT.md` và mục 3 của
tệp này — đã gắn dấu cùng ngày.

**Cách sửa (chưa làm, chờ người dùng):** theo khuôn G4 — dùng `core/auth/current_account.dart` trả `int?`; đường
đọc trả rỗng khi `null`, đường ghi chặn kèm thông báo. Test theo khuôn `test/core/auth/current_account_test.dart`,
cộng một test quét `lib/` cấm mẫu `?? 1` nhiều dòng — hai test quét `lib/` sẵn có là tiền lệ.

---

### ~~G36 — Tài khoản bị xoá lúc app giữ token hết hạn: đăng xuất không hộp thoại~~ · ✅ ĐÓNG 2026-09-13 (đo đầu-cuối ba ca)

**Đo thật** (spec cưỡng chế đăng xuất, khối ✅ thứ hai đầu §7.3): tạo tài khoản thử `kiemthu_xoa`
(idaccount 12), đăng nhập giữ refresh token, admin `DELETE /api/admin/deleteuser/12`, rồi gọi
`/auth/refresh` bằng token ấy → **401 "Refresh token khong hop le", không `code`**. Nguyên nhân: xoá
mềm **thu hồi toàn bộ refresh token** của tài khoản (5/5 `Status = true`), và `auth.service.js:375-387`
kiểm token **trước** khi kiểm trạng thái tài khoản. `/auth/profile` cùng lúc trả đúng 401 +
`code: ACCOUNT_DELETED`.

**Hệ quả phía client.** Ba nguồn của cưỡng chế đăng xuất (§3.5) đều cần *mã*. Khi app **đang có
socket**, sự kiện `account.force_logout` tới trước và mọi thứ đúng (đo thật: hộp thoại "Tài khoản
đã bị xoá", SQLite dọn). Nhưng khi app **ngoại tuyến lúc bị xoá** rồi mở lại sau khi access token đã
hết hạn: request đầu → 401 "Token expired" (không mã) → interceptor gọi `/auth/refresh` → 401 không
mã → `LamMoiPhienChet` **không lý do** → `AuthUnauthenticated()` trơn → màn Đăng nhập, **không hộp
thoại**. Người dùng chỉ biết vì sao khi đăng nhập lại (login trả câu đúng). Không mất dữ liệu; chỉ
thiếu lời giải thích.

**Client không tự sửa được**: lúc ấy mọi token đều chết, không endpoint nào trả lời được "vì sao".
Xin backend (CAN-LAM 20 §2.7): ở nhánh token đã thu hồi, backend **có** `storedToken.idaccount` — kiểm
`getAccountValidity` trước khi ném, và nếu tài khoản `Inactive`/`Deleted` thì trả 401 kèm `code` như
`authenticate`. Client khi ấy không phải đổi gì: `tuBody401(nguon: lamMoi)` đã đọc đúng hình dạng.

✅ **Backend đã làm** (gộp `main` @ `7779999`, merge `e9b5aef`, 2026-09-12 tối muộn — `auth.service.js`
nhánh `storedToken.status === true` gọi `getAccountValidity(storedToken.idaccount)`, bỏ qua `SCHEMA_ERROR`,
rồi ném 401 kèm `rejection.data` nếu tài khoản không hợp lệ). **Đo mức API cùng tối** (tài khoản thử 14
`kiemthu_cl20_…`, còn `Active`): `/auth/logout` rồi `/auth/refresh` bằng token cũ → 401 *"Refresh token
khong hop le"* **không mã** — đúng, vì tài khoản hợp lệ thì `accountRejection` trả `null`.

✅ **ĐÓNG 2026-09-13 — đo đầu-cuối ba ca qua API admin; client không đổi mã.** Tài khoản thử tự đăng ký
qua `/auth/register` (`kiemthu_g36_…`, idaccount 16), backend dev chạy mã `7779999`, PostgreSQL **chỉ
đọc** — mọi thay đổi trạng thái đi qua API admin đúng đường người dùng thật:

| Ca | Trạng thái | Kết quả `/auth/refresh` |
|---|---|---|
| **A** | `Active` (đối chứng) | **200** *"Token đã được làm mới"*, không mã — đúng |
| **B** | `Inactive` — `PATCH /admin/updatestatus/16` (body **bắt buộc** có `reason_inactive`) | **401 + `code: ACCOUNT_INACTIVE`**, kèm `idaccount: 16` và `reason_inactive` **ở cấp gốc**; `message` mang nguyên câu lý do admin nhập |
| **C** | `Deleted` — `DELETE /admin/deleteuser/16` (xoá **mềm**) | **401 + `code: ACCOUNT_DELETED`**, kèm `idaccount: 16` — **dù 4/4 refresh token của tài khoản đã bị thu hồi** (`SELECT COUNT(*) FILTER (WHERE "Status" = true)`) |

Ca **C** chính là ca gốc của G36: trước bản `7779999`, token bị thu hồi khiến `/auth/refresh` ném 401
*không mã* trước khi kịp kiểm tài khoản. Nay nó trả mã, nên app hiện được hộp thoại lý do.

Phía client **không phải đổi gì**: `tuBody401` đọc `code` ở cấp gốc, `message` và `idaccount` — đúng ba
trường backend trả — và ca `lamMoi` + `ACCOUNT_DELETED` đã có test từ trước
(`test/core/api/auth_interceptor_buoc_dang_xuat_test.dart:267-289`). Chỉ một **chú thích** ở
`lib/core/auth/buoc_dang_xuat.dart` phải sửa, vì nó khẳng định điều ngược lại — xem ngay dưới.

⚠️ **Liên quan §3.6b — kết luận cũ bị lật.** Tài liệu và chú thích trước 2026-09-13 viết rằng *"xoá qua
admin thu hồi refresh token nên `/auth/refresh` trả 401 không mã, đường `lamMoi` không bao giờ mang
`daXoa`"*, và vì thế ngoại lệ *không dọn SQLite khi `daXoa` đến từ nhánh làm mới* là **gần như vô
nghĩa**. Câu ấy đúng cho tới bản `7779999` và **sai từ đó**: ca C vừa đo cho thấy đường `lamMoi` **có**
mang `daXoa`. Ngoại lệ §3.6b nay chặn đúng một ca thật — tài khoản bị xoá, phát hiện qua nhánh làm mới —
chứ không chỉ che ca lỗi lược đồ. ✅ **Người dùng chốt 2026-09-13: GIỮ ngoại lệ.** SQLite là bản duy nhất trên máy nên dọn nhầm
là mất thật; còn nếu xoá là đúng thì `purgeDataForOtherAccounts` vẫn dọn khi tài khoản khác
đăng nhập vào máy — tức chỉ **hoãn** việc dọn chứ không bỏ. Không đổi mã: hành vi hiện tại đã
đúng quyết định ấy, chỉ hai chú thích Dart được ghi lại cho khớp.

### ~~G38 — Ba trang giao dịch rơi về tài khoản admin khi chưa có phiên~~ · ✅ ĐÓNG (2026-09-14, mở và đóng trong cùng ngày)

> ✅ **Đóng ngay khi tìm ra.** Ghi lại vì **cách nó sống sót** đáng nhớ hơn bản
> thân lỗi: nó đi qua cả hai lượt đóng cùng chủ đề — G4 (bốn trang bill/goal)
> và G35 (ba màn quản lý danh mục) — mà không lượt nào thấy.

**Hiện trạng (trước bản sửa).** Ba trang khai tham số mặc định `1`:

```dart
const TransactionPage({super.key, this.idaccount = 1});
...
currentUserId = int.tryParse(authState.user!.id) ?? widget.idaccount;
```

Vế `??` trỏ tới một **biến**, không tới hằng `1` — nên mọi lượt `grep '?? 1'`
đều sạch, kể cả lưới quét `khong_du_phong_admin_test.dart` dựng ra sau G35.
Nhưng route dựng `const TransactionPage()` không truyền gì, nên giá trị thật
sự dùng vẫn là `1`, tức **tài khoản admin thật** (quy tắc 2 `CLAUDE.md`).

| Trang | `idaccount` dùng làm gì | Hậu quả |
|---|---|---|
| `transaction_page.dart` | mở stream ví + danh mục | **đọc** dữ liệu admin |
| `choose_category_page.dart` | đọc danh mục | **đọc** dữ liệu admin |
| `add_transaction_page.dart` | `idaccount:` khi **lưu** giao dịch | **ghi** dưới danh nghĩa admin, rồi đẩy lên và vỡ "Ownership mismatch" |

Chỗ thứ ba đúng kịch bản mà docstring `core/auth/current_account.dart` mô tả
khi G4 được đóng — chỉ khác là nó xảy ra trên đường đi nhiều nhất của app.

**Đã sửa.** Ba trang để tham số `int?` **không mặc định** (widget test vẫn tiêm
được), suy tài khoản trả `null` khi chưa có phiên, và tự xử lý `null`: đường
đọc không mở stream, đường ghi chặn lưu kèm thông báo — cùng khuôn G35.

**Lưới quét nới thêm một ca**, bắt đúng hình dạng vừa lọt. ⚠️ Lượt khảo sát tự
nó suýt kết luận sai: phép `grep -E` đầu tiên dùng `\s`, mà POSIX ERE **không
có** `\s`, nên nó trả rỗng và suýt chốt "chỉ một chỗ" — thật ra có ba.

**Nghiệm thu máy ảo** (tài khoản thử 25, PostgreSQL chỉ đọc): mốc nền cả tài
khoản 1 lẫn 25 đều **0 giao dịch**; thêm một khoản chi 55đ qua giao diện →
`Idtran c045dc60…` với `Idaccount = 25`, `Amount = -55`; tài khoản 1 vẫn **0
hàng**. Màn chọn danh mục và trang Sổ giao dịch vẫn mở đầy đủ.

**Hai ca hành vi** ở `test/features/transaction/presentation/khong_du_phong_admin_trang_giao_dich_test.dart`
canh đường ghi, và chúng ghi thẳng một điều bản đầu của chính chúng làm sai:
trong luồng thường, thiếu phiên thì màn chọn danh mục **cũng rỗng** nên chốt
"Vui lòng chọn danh mục" chặn trước — chốt tài khoản là **lớp phòng thủ thứ
hai**, và phải tiêm lệch mới dựng lại được trạng thái ấy trong widget test.

---

### ~~G48 — Đường tắt "Xem giao dịch" thôi lọc sẵn ví nếu tab Giao dịch đã mở trước đó~~ · ✅ ĐÓNG (2026-09-21, mở và đóng trong cùng ngày)

**Bắt được bằng máy ảo**, trong lượt nghiệm thu 411dp của lát "phạm vi kỳ + lọc
tiền" (Task 5 Step 1). Hỏng **im lặng** theo chiều tệ nhất: người dùng thấy một
sổ giao dịch **đầy đủ** và tin rằng chừng ấy khoản đều thuộc cái ví họ vừa bấm.

**Đo được hai đường, cùng một máy, cùng một ví:**

- App vừa khởi động → drawer → Quản lý ví → ⋮ ví "Tiết kiệm" → *Xem giao dịch*:
  chip ví **bật**, danh sách chỉ còn giao dịch của ví ấy. **Đúng.**
- Vào tab **Giao dịch** trước, rồi làm đúng chuỗi trên: chip **"Tất cả"** bật,
  chip Ví không mang tên ví, danh sách là **toàn bộ** giao dịch của kỳ. **Sai**,
  và không một dòng log nào.

**Nguyên nhân.** `wallet_list_page.dart:283` gọi
`context.go('/transactions?wallet=${w.id}')`, route đọc đúng query param và
truyền `initialWalletId` (`app_router.dart:168`). Chỗ rơi nằm ở
`transaction_page.dart:61`: `_filter` khởi tạo từ `widget.initialWalletId` bằng
một **field initializer**, tức chỉ chạy **một lần trong đời State**. `/transactions`
là một `StatefulShellBranch` nên Navigator của nhánh **giữ State sống**; lần `go`
thứ hai dựng một `TransactionPage` mới cùng kiểu và cùng vị trí, nên Flutter
**cập nhật** State cũ thay vì tạo State mới — `initState` không chạy lại và tham
số ví mới bị bỏ qua.

⚠️ **Không phải hồi quy của lát ngày 2026-09-21.** Nó có từ khi `/transactions`
chuyển vào shell (**nhóm D**, 2026-09-19); trước đó trang là route chồng nên mỗi
lần mở là một State mới. Chú thích ngay tại `transaction_page.dart:57` giải
thích vì sao **không** gán trong `build` (gán ở đó thì người dùng không bỏ lọc ra
được) — lý lẽ ấy vẫn đúng, nên phép sửa **không phải** là chuyển vào `build`.

**Vì sao `flutter test` mù.** Widget test luôn dựng trang **mới tinh**, nên
`initState` luôn chạy và ca "đường tắt lọc sẵn ví" (2026-09-14) vẫn xanh. Chỉ
tái hiện được khi có **cây route thật** cộng một lần ghé tab trước đó — đúng
loại lỗi thứ hai của mục "Ba loại lỗi `flutter test` KHÔNG bắt được".

**Sửa (cùng ngày):** `didUpdateWidget` ở `TransactionPage`, áp ví mới khi nó
**thật sự khác** lần trước. Ba lối từng cân nhắc khác nhau ở chỗ *ai làm chủ bộ
lọc*; lối đã chọn **cố ý không trả lời** câu hỏi rộng ấy mà chỉ chốt một điều hẹp
và rõ: **một lệnh điều hướng có nêu đích danh ví thì thắng bộ lọc đang có**. Câu
hỏi còn để ngỏ — bộ lọc có nên sống sót qua một lần ghé tab hay không — vẫn mở,
và lối "chuyển bộ lọc lên bloc" vẫn là đường đi nếu ngày nào cần trả lời nó.

⚠️ **Hai chốt, phá cái nào cũng hỏng im lặng theo hai chiều ngược nhau:**

- Chỉ đổi khi ví **khác lần trước**. Áp lại ở **mọi** lần dựng lại là quay về
  đúng cái bẫy mà chú thích của `_filter` cảnh báo từ đầu: người dùng bỏ lọc ra
  rồi nó tự giành lại, và họ không thoát ra được.
- `null` **không** có nghĩa *"hãy xem mọi ví"*. Trang dựng lại mà không nêu ví
  nào thì giữ nguyên thứ đang xem; coi `null` là lệnh bỏ lọc thì bộ lọc tự bay
  mất mỗi lần cây widget dựng lại.

**Test:** `test/features/transaction/presentation/so_giao_dich_loc_vi_ban_dau_test.dart`
— **3** ca, và ca giữa **tái hiện đúng cơ chế mà không cần cây route thật**:
dựng trang với `initialWalletId = null` rồi dựng lại **cùng vị trí** với một ví;
`pumpWidget` giữ State vì runtimeType và key không đổi, đúng thứ shell làm. Ca
thứ ba canh chốt `null`. ⚠️ Cả ba **đỏ với dáng vẻ sai** ở lần chạy đầu — *"không
tìm thấy chuỗi nào"* — vì tệp thiếu `initializeDateFormatting('vi')`: danh sách
nhóm theo ngày dựng tiêu đề bằng `DateFormat` locale `vi`, thiếu nó thì
`LocaleDataException` làm **cả cây dừng dựng**. `so_giao_dich_chon_ky_test.dart`
không vấp chỉ vì danh sách của nó rỗng nên không có tiêu đề ngày nào.

**Nghiệm thu máy ảo** (bắt buộc, vì widget test tái hiện *cơ chế* chứ không phải
router thật): chạy đúng kịch bản từng hỏng — mở app, **ghé tab Giao dịch trước**,
rồi drawer → Quản lý ví → ⋮ ví Tiết kiệm → *Xem giao dịch*. Chip ví bật, danh
sách chỉ còn ví ấy.

---

### ~~G49 — Thẻ tổng Sổ giao dịch đếm khoản điều chỉnh số dư, lệch Trang chủ~~ · ✅ ĐÓNG (2026-09-29, mở và đóng trong cùng ngày)

**Thấy bằng mắt trên Realme**, giữa lượt nghiệm thu B1: tháng 9 Sổ giao dịch nói
**Thu nhập 15.145.000 đ**, Trang chủ nói **15.135.000 đ**. Người dùng chọn điều
tra trước (chỉ đọc), rồi chọn cách sửa.

**Nguyên nhân.** Thẻ tổng của Sổ giao dịch gọi `summarizeTransactions`
(`transaction/domain/transaction_filter.dart`), hàm ấy cộng **thô** theo `type`.
Trang chủ, trang Phân tích và trợ lý AI đi qua `tongThuChi` → `khoanVaoThongKe`,
luật bỏ khoản chuyển, khoản **điều chỉnh số dư** và khoản **"Số dư ban đầu"**.
Khoản thừa đọc từ CSDL Realme: *"Điều chỉnh số dư"* +10.000 đ ngày 10/09, ví Tiền
mặt, không danh mục. **Bước 1a (2026-09-23)** đưa Trang chủ sang `tongThuChi`
nhưng để lại định nghĩa thứ hai ở đây; chú thích của hàm vẫn ghi *"cùng quy ước
với bloc và trang chủ"*, câu sai từ đúng hôm ấy. `TransactionBloc` còn một vòng
cộng thô **thứ ba** (trường `totalIncome` / `totalExpense`, không màn nào đọc).

**Sửa (cùng ngày, người dùng chọn):** `summarizeTransactions` đi qua
`khoanVaoThongKe`; bloc gọi lại chính hàm ấy. Hệ quả **cố ý**: hàng điều chỉnh
vẫn **hiện** trong danh sách nhưng không cộng vào thẻ — người dùng đã chốt con số
của Phân tích là con số đúng (2026-09-23). Tool `truy_van_giao_dich` của trợ lý
AI không đổi: nó vốn lọc `khoanVaoThongKe` trước khi gọi hàm này.

**Test:** hai ca ở `test/features/transaction/domain/transaction_filter_test.dart`
— khoản điều chỉnh (thu lẫn chi) và khoản mở sổ không vào thẻ, khoản **chưa phân
loại thật** vẫn vào; và ca ⭐ *Sổ giao dịch = Trang chủ* so thẳng với `tongThuChi`
trên cùng một sổ. Cả hai đỏ trên mã cũ (11.310.000 thay vì 9.300.000).

**Vế thứ hai, cùng ngày (người dùng chọn):** nghiệm thu trên Realme lộ **tiêu đề nhóm
ngày** vẫn tự cộng thô (`transaction_page.dart`, vòng thứ **tư**) — ngày 10/09 chỉ có
khoản điều chỉnh mà tiêu đề hiện *"+10.000 đ"*, cạnh thẻ tổng không cộng nó. Nay tiêu
đề gọi `summarizeTransactions(dayTxs).net`. Ca canh:
`test/features/transaction/presentation/so_giao_dich_tong_ngay_test.dart` — một ngày
chi 55.000 · thu 20.000 · điều chỉnh +10.000, đòi tiêu đề **−35.000 đ** (cùng cột Thu
net của thẻ) và hàng điều chỉnh vẫn hiện; mã cũ ra −25.000 đ.

Cùng lượt soát lộ thêm cặp nạp mục tiêu dạng cũ được tính là thu **và** chi ở mọi
màn — không gây lệch giữa các màn nên không thuộc G49; tách thành **G50** ngay dưới.

---

### ~~G50 — Cặp nạp mục tiêu dạng cũ được tính là thu VÀ chi ở mọi màn~~ · ✅ ĐÓNG (2026-09-29, mở và đóng trong cùng ngày)

**Lộ ra khi điều tra G49.** Bản app trước **2026-09-05** ghi mỗi lần nạp mục tiêu
thành **hai hàng thường** thay vì một khoản `'transfer'`: thu *"Tích lũy nhận từ
Tiền mặt: MuaXe"* vào ví tích luỹ + chi *"Tích lũy mục tiêu: MuaXe"* từ ví nguồn,
cả hai **không danh mục**. `khoanVaoThongKe` chỉ loại `'transfer'`, khoản điều chỉnh
số dư và khoản mở sổ, nên cặp này lọt qua: tháng 9 của tài khoản 10 **thu phồng
500.000 và chi phồng 500.000** ở Trang chủ, Sổ giao dịch, trang Phân tích và trợ lý
AI (chi 2.351.000 thay vì **1.851.000**, thu 15.135.000 thay vì **14.635.000**; thu
net không đổi). Số dư ví **không** sai — hai hàng chuyển tiền đúng giữa hai ví.

**Mức lan rộng** (đo PostgreSQL dev, chỉ đọc): đúng **một cặp** — 2 hàng, tài khoản
10, ngày 05/09. App không còn sinh dạng này từ 2026-09-05.

**Sửa (người dùng chọn "loại khỏi thống kê"):** `laNuaCapNapMucTieuCu` ở
`transaction/domain/khoan_vao_thong_ke.dart` (từ 2026-10-16), là vế **thứ tư** của `khoanVaoThongKe`:
hàng `thu`/`chi` **không danh mục** mang tiền tố `kGhiChuNapMucTieuCu` hoặc
`kGhiChuNapMucTieu`. **Cặp** dấu hiệu như khoản điều chỉnh — hàng có danh mục là
người dùng tự gõ và vẫn được tính. Không nhận tiền tố **rút**: chưa thấy hàng rút
dạng cũ nào. Dữ liệu **không** bị sửa.

**Test:** hai ca ở `test/features/transaction/domain/khoan_vao_thong_ke_test.dart` (hai nửa
bị loại; trùng khuôn mà có danh mục vẫn tính — bản sai bỏ vế danh mục làm ca này
đỏ). Năm kỳ vọng của `test/features/transaction/domain/tim_giao_dich_test.dart` đổi
theo, vì fixture của tệp ấy chép đúng nửa chi dạng cũ của dữ liệu thật; ca *"ngày
tương lai"* thêm một **đối chứng** (`now` sau 10/11 thì khoản hẹn hiện ra) để vẫn
đòi kết quả chứ không chỉ đòi vắng mặt.

**Nghiệm thu Realme** (release `b807e711…`, cùng chiều, gồm cả G49 hai vế): ba màn
nói **cùng một bộ số** tháng 9 — Trang chủ *Thu nhập 14.635.000 · Chi tiêu 1.851.000
· Thu net +12.784.000*; Sổ giao dịch *+14.635.000 · −1.851.000 · +12.784.000*; Phân
tích *Tổng thu +14.635.000 · Tổng chi −1.851.000*, khối Dòng tiền *thay đổi
+12.784.000*, khối Nhận xét *"Kỳ này chi 1.851.000 đ"*. Tìm *"dieu chinh"* ở Sổ: tiêu
đề ngày 10/09 **0 đ**, hàng điều chỉnh +10.000 đ vẫn hiện.

⚠️ Hệ quả: đáp án các câu chi tiêu / thu nhập của bộ câu Trợ lý AI đo trên tài
khoản 10 đổi theo (người dùng dặn bỏ qua phần chat AI ở lượt này — chưa tính lại).

---

### ~~G90~~ — Bảng chọn giờ, chế độ gõ chữ, từ chối mọi giờ > 12 khi máy đặt định dạng 12 giờ · ✅ ĐÓNG 2026-10-12 (mở 2026-10-11)

**Hiện tượng.** Lộ ở lượt nghiệm thu chạy nền 2026-10-11 tối, trên máy ảo `FlowMoney_16G`, lúc đặt giờ trích của mục tiêu
thử: máy đặt **định dạng 12 giờ**, mở bảng chọn giờ, chuyển sang **chế độ gõ chữ**, gõ *"21"* → *"Nhập thời gian hợp lệ"*;
mọi giờ > 12 đều bị từ chối, trong khi chính bảng ấy **hiện kiểu 24 giờ** vì app ghim `locale: kNgonNguApp` (`vi` —
`lib/main.dart:205`, `lib/core/constants/app_localization.dart`). Đặt máy về **24 giờ** rồi khởi động lại app thì nhận.
Người dùng thấy: không gõ được giờ chiều / tối, và câu báo lỗi không nói vì sao. Cài đặt `time_12_24` của máy ảo đã trả
về mặc định sau lượt đo. Bảng đo của lượt ấy: §8.1 `docs/superpowers/specs/2026-10-10-tu-chuyen-tien-chay-nen-design.md`.

**Bán kính.** Năm chỗ gọi `showTimePicker`, không chỗ nào truyền `builder` hay `initialEntryMode` (đếm bằng máy
2026-10-11; số dòng là của TRƯỚC đợt tách bốn trang 2026-10-13 — nay `goal_add_page.dart:722`,
`notification_settings_page.dart:480` / `:490` / `:504`, và hai mốc im lặng ở `HangGioImLang` trong
`notification/presentation/widgets/cai_dat_thong_bao/khung_cai_dat.dart:177`):

- `lib/features/goal/presentation/pages/goal_add_page.dart:1320` — giờ trích tự động của mục tiêu;
- `lib/features/notification/presentation/pages/notification_settings_page.dart:484` (giờ nhắc chung), `:494` (giờ nhắc
  ghi chép), `:508` (giờ Tổng kết tuần), `:1279` (`_hangGioImLang` — hai mốc của khoảng im lặng; nay `HangGioImLang`).

Chế độ **mặt đồng hồ** (mặc định khi mở bảng): không lỗi — vẽ 00–23 hai vòng (đo 2026-10-12, máy ảo đặt 12 giờ).

**Gốc lỗi (đo 2026-10-12).** Bảng chọn giờ của Flutter lấy **kiểu hiển thị** từ ngôn ngữ (`vi` = HH:mm, không có nút
SA/CH) nhưng **đọc giờ gõ vào** theo `MediaQuery.alwaysUse24HourFormat`, tức cài đặt đồng hồ của máy. Máy 12 giờ thì ô giờ
chỉ nhận 1–12 rồi ghép với SA/CH **ẩn** của giờ đang chọn. Widget test thăm dò đo được, ngoài lời từ chối (`20`, `0`), **hai
ca sai im lặng** mà lượt mở mục không thấy: từ 20:00 gõ `8` → lưu **20:00**; từ 08:00 gõ `12` → lưu **00:00** (nửa đêm). Không
đọc mã Flutter — kết luận dựa trên kết quả đo của từng ca, và bọc `alwaysUse24HourFormat: true` làm cả bốn ca đúng.

**Sửa (`9bc57c63`).** Một hàm `bocDongHo24Gio(context, child)` ở `lib/core/constants/app_localization.dart` (cạnh `locale`
ghim — cùng lý lẽ: app một ngôn ngữ, tiếng Việt viết giờ 24 giờ), gọi ở lớp **ngoài cùng** `builder` của `MaterialApp.router`
(`lib/main.dart`, bọc `AppToast`). Chọn tầng app thay vì một hàm chung cho năm chỗ gọi như giả thuyết lúc mở: bảng chọn giờ
thứ sáu thêm sau tự đúng mà không cần test quét; và không chỗ nào khác trong `lib/` đọc cờ ấy hay gọi `TimeOfDay.format`
(đo 2026-10-12), nên ép cờ không đổi gì nhìn thấy được ngoài bảng chọn giờ. Hộp thoại đi qua navigator gốc, nằm **trong**
`builder`, nên nhận cờ. Test: nhóm *G90* ở `test/core/constants/app_localization_test.dart` — ca **tiền đề** (không bọc thì
`flutter test` — vốn là máy 12 giờ — từ chối `20`; ca này xanh-ngược là Flutter đã đổi cách đọc, phải đo lại), bốn ca hành
vi (`20`, `0`, `8`, `12`), ca nối dây `main.dart`. ⚠️ `platformDispatcher.alwaysUse24HourFormatTestValue = true` **không** tới
được `MediaQuery` của `MaterialApp` trong `flutter test` (đo) — đừng dùng nó để giả máy 24 giờ.

**Nghiệm thu máy ảo** (`time_12_24 = 12`, mở lại app): bốn ca trên ô giờ của Cài đặt thông báo + gõ `21` ở giờ trích form
Thêm mục tiêu — đạt. **Đối chứng**: bản dựng từ `main.dart` của `HEAD~1` (không bọc), cùng máy cùng cài đặt, gõ `20` →
*"Nhập thời gian hợp lệ"*. Đo **ba trong năm** chỗ gọi (`:484`, `:494`, goal `:1320`); chưa chạm ô giờ Tổng kết tuần (`:508`)
và hai mốc Giờ im lặng (`:1279`, phải bật công tắc) — cùng một lớp bọc ở `MaterialApp`, không có đường riêng. Chưa đo trên
Realme / OnePlus. Chi tiết: khối 🕗 đầu mục 14 `PROJECT_CONTEXT.md`.

---

### G113 — Lát 1 gia đình: dữ liệu nhà có thể thiếu / kẹt trên máy, và nợ lát 2 · 🚧 MỞ 2026-10-28 phiên 23

**Nguồn.** Các lượt soát Task 1–12 của đợt gia đình lát 1 (`95d33ecc..24f8a258`). Lát 1 chưa có màn và chưa có đường GHI vào nhà, nên mọi mục dưới
là **chấp nhận có điều kiện**, không phải lỗi đang chạy.

**Lỗ hổng đã biết (vì sao chấp nhận).**
1. **Lịch sử nhà mới có thể vắng VĨNH VIỄN** — kho trạng thái nhà ghi TRƯỚC khi phát `DoiNha`: (a) hai isolate — lượt đồng bộ nền đang kéo dở ghi
   mốc vào kho SAU phép xoá mốc của `keoLaiToanBo` ở tiền cảnh, rồi tiến trình chết trước lượt kéo toàn bộ; (b) `SecureStorageSyncCheckpointStore.clear`
   nuốt lỗi; (c) tiến trình chết giữa lúc ghi kho nhà và `yeuCauKeoToanBo`. Hẹp. Sửa ở lát 2: dấu bền *"đã xử lý tới nhà X"* theo tài khoản;
   `DieuPhoiDoiNha` dời dấu sau `xuLy` thành công; mở phiên so dấu với kho nhà.
2. **Yêu cầu kéo toàn bộ xoá mốc kho ngay** ⇒ tiến trình chết / `stop()` trước lượt kéo kế ⇒ lượt ấy là *"không có trạng thái cũ"* ⇒ bỏ so từ khoá
   khuôn (từ khoá admin thêm giữa hai lượt không lan). Hẹp.
3. **Dọn nhà cũ hỏng** ⇒ hàng nhà cũ nằm lại tới purge lúc mở phiên kế. Với hàng con `idhousehold` NULL trỏ ví nhà (neo "Số dư ban đầu"
   `SoDuViService._datNeoNeuThieu` ghi `idhousehold` NULL) ⇒ `xoaHangCuaNha` vỡ khoá ngoại VĨNH VIỄN (purge cũng vậy khi chính tài khoản tạo ví).
   Lát 1 không có đường sinh (chưa ghi vào nhà). ⚠️ **Hệ quả nặng:** purge ném ⇒ `PhienDieuPhoiThat.moPhienCucBo` không `catch` ⇒
   `_onAuthCheckRequested` về màn Đăng nhập mỗi lần mở app, đăng nhập bằng mật khẩu ⇒ `AuthError` — người dùng bị khoá ở cửa đăng nhập, lặp lại.
   Điều kiện: máy của chính người tạo một ví nhà + `nhaGiu` null (kho hỏng / rời nhà / giải tán). ⇒ **Lát 2 PHẢI sửa neo (nợ 1 dưới) TRƯỚC khi
   mở lối tạo ví chung.** Cùng gốc `nhaGiu` null (review toàn nhánh, theo đọc mã, chưa chạy thử): purge xoá ví nhà trong khi ví riêng còn ⇒ lượt kéo
   kế là TĂNG DẦN (`isLocalDbEmpty` chỉ đếm ví riêng) ⇒ giao dịch nhà mới hơn mốc mà ví của nó cũ hơn mốc (vừa bị purge) làm `transactionDao.upsertAll`
   ném vì khoá ngoại ⇒ cả lượt kéo hỏng (ngân sách / mục tiêu / hoá đơn riêng phía sau cũng không về, mốc không tiến) cho tới khi `/me` khác kho ⇒
   `DoiNha` ⇒ kéo toàn bộ. Hẹp, phần lớn tự hồi. Hướng sửa rẻ: phép dọn xoá được hàng nhà nào thì xoá luôn mốc kéo của tài khoản
   (`keoLaiToanBo` ở `moPhienCucBo`).
4. **Thành viên đăng nhập lần đầu trên máy mới kéo toàn bộ HAI lần** (lượt đầu sau đăng nhập + `DoiNha(null → X)` → `keoLaiToanBo`) — hệ quả thiết kế
   spec 4.6, chấp nhận (một lần băng thông).
5. **Quyền KHÔNG chứng minh được trên máy** — đơn 56.1 (`findMember` không tồn tại ⇒ mọi người ghi được vào nhà), 56.4 (Basic tạo được nhà).
   🔎 **2026-10-30 (gộp `e3248955`, PR #170): 56.1 và 56.4 đạt theo mã** (`household.repository.js:46-58` `findMember`; `sync.service.js:88-112`; `households.routes.js:11` `requireFeature('household')`)
   — vẫn **chưa đo trên máy thật** (CSDL 0 nhà); `PersonFinance` chưa áp migration 41 (Basic vẫn 403 nhờ `DEFAULT_PERMISSIONS`, Premium còn hạn vẫn tạo được). Còn chưa chứng minh được: 56.2 phần `Transfer`
   (58.1 — Member tạo được chuyển khoản giữa ví chung) và mọi ca hàng do người khác ghi (57.4 — ca 10, 12, 13 hỏng với payload thật).

**Nợ lát 2.**
1. Neo số dư ban đầu phải kế thừa `idhousehold` của ví (hoặc bỏ qua ví nhà); xét lại phép vá neo (`viDaCoTruocPull` chỉ thấy ví riêng).
2. Purge `nhaGiu == null` xoá cả hàng PENDING tôi ghi vào nhà — khi cho ghi vào nhà phải chừa / đẩy trước.
3. Đường SỬA danh mục đi `categoryDao.insert` (= `insertOrReplace`), companion từ draft không có `idhousehold` ⇒ sửa danh mục của nhà sẽ đặt
   `idhousehold = NULL` im lặng — phải mang `idhousehold` qua đường sửa.
4. `getSyncableCategories` + khối 1b `thu_gom_day.dart` lọc `idaccount = tôi` ⇒ danh mục nhà người khác tạo mà Member sửa không bao giờ lên server;
   đổi sang `idaccount = tôi ∨ idhousehold = nhà tôi`. Khối 1b của `thu_gom_day.dart` CHƯA có ca canh khoá `idhousehold` — thêm ca cùng lúc sửa nợ này.
   ⚠️ **THỨ TỰ (2026-10-30): chỉ làm SAU khi đơn 57.4 đóng** (backend bỏ chốt *"Ownership mismatch"* `sync.service.js:260-268` cho hàng của nhà). Làm trước thì mọi lượt sửa hàng người khác ghi
   (Member sửa danh mục nhà, Chủ sửa khoản của Member) nhận *"Ownership mismatch"* không `code` ⇒ client xếp vĩnh viễn (`gui_lo_dong_bo.dart:409-411`) ⇒ **mất dữ liệu im lặng**. Lối thay thế —
   gửi `idaccount` của **phiên** cho hàng nhà khi sửa (nhánh update `sync.repository.js:491-512` không ghi đè `idaccount` nên người ghi vẫn giữ) — **đảo** quyết định cũ *"app giữ gửi `idaccount` người ghi"*
   (57.4): **CẦN người dùng chốt, chưa làm**.
5. Thêm `MaQuyen` `'household'` ⇒ quét 21 va khoá JSON `'household'` ở `nha_cua_toi.dart` — cần miễn trừ.
6. `quyen_nha.dart` `ghiDuLieu` gộp mọi thực thể; `docs/Family/01` mục 3: ví / mục tiêu / ngân sách chung chỉ Chủ nhà.
7. `tinhNangKhongMo`: chọn câu theo `trangThaiQuyen(MaQuyen.giaDinh)` (Basic → mời nâng cấp; Premium tạm ngừng → *"Đang tạm ngừng"*).
8. `MaMoiEntity.conHieuLuc` không xét `hetHan`; form tên nhà tự chặn 1–100 ký tự (`INVALID_*` rơi `khac`).
9. **Tính lại số dư đánh `pending` lên ví NHÀ** (review toàn nhánh M1): `tinhLaiSoDu` → `updateBalance` ghi `syncStatus: pending` + `updatedAt = now`
   cho cả ví nhà trong `viDungToi`. Máy thành viên: hàng nằm `pending` mãi (`getPending(tôi)` lọc `idaccount`, không bao giờ đẩy); máy người tạo: ví chung
   bị đẩy lại sau mỗi lượt kéo chạm nó, `updatedAt = now` thắng LWW trước sửa thật của người khác, và thành vòng `HOUSEHOLD_ROLE_FORBIDDEN` khi 56.2 lên mà
   người tạo ví không còn là Chủ. Lát 2 phải cho số dư ví nhà là **cache cục bộ** (không `pending`) hoặc chỉ Chủ đẩy.
10. **Chạm hàng nhà khi vắng mặt người dùng (M2 đã sửa; còn lại):** trước khi gộp `main` (`e3248955`, có thể đã đóng 57.1) phải đo hình dạng `/me` mới với
    `nhaCuaToiTuJson` + chốt `laThanTrangThaiNha` (thân không có khoá `household` / `idhousehold` nay KHÔNG được áp — giữ trạng thái cũ).
    ✅ **Đã đo 2026-10-30** (gộp `e3248955`): 57.1 **chưa** làm — `/me` vẫn phẳng, không nhà `{household: null}` (`data` không bao giờ `null`), `POST /` hàng thô + `myRole`; `nhaCuaToiTuJson` + `laThanTrangThaiNha`
    đọc đúng, không đổi mã (mẫu JSON dựng từ danh sách khoá HEAD: `.superpowers/soat-pr170/soat-56-57.md` mục 2a). Đo lại khi 57.1 đóng.
11. **Bản giả lệch backend:** `HouseholdApiGia` mặc định trả thân trạng thái cho `doiVai` / `moiRa` / `giaiTan` trong khi backend thật trả
    `{targetIdaccount, newRole}` / `{removed}` / `{dissolved}` — bloc lát 2 dựng trên bản giả sẽ bị dắt sai; dựng theo hình dạng thật.
12. **Tần suất `/me`:** khi 56.8 đóng, `household.changed` phát sau MỖI `/sync/push` chạm hàng nhà ⇒ mỗi máy thành viên gọi `/me` + `/invitations` mỗi lượt
    đẩy của bất kỳ ai — cần giãn cách.
    ✅ **Phía client xong 2026-10-30** (commit `1227d8a2`): `NhaRepositoryImpl.noiSuKien` — sự kiện `nhaDoi` đi qua cửa sổ `kGianCachNhaDoi` = 30 s (lượt đầu chạy ngay; sự kiện trong cửa sổ chỉ bật cờ bù,
    hết cửa sổ chạy **một** lượt bù rồi mở cửa sổ mới); `loiMoiNha` và thao tác của chính máy (`_thaoTac`, `kMaDayLoiNha`) không qua bộ giãn; huỷ ở `_doiPhien` và `dispose()`.
    Test `nha_repository_impl_test.dart` group *giãn cách household.changed* (6 ca, `fakeAsync`) — `flutter test test/features/household` 89 pass. Sau gộp `e3248955` 56.8 đã đóng phần chính: `household.changed` +
    `sync.completed` tới `account_<id>` mọi thành viên khác sau mỗi `/sync/push` (`sync.service.js:475-506`) — **tần suất thật nay xảy ra**. Còn **chờ 58.4 phía server** (bỏ `household.changed` thừa sau đẩy; chỉ phát
    cho nhà của op đã ghi, không theo `payload.idhousehold` chưa kiểm — người ngoài khuếch đại được).
13. `DieuPhoiDoiNha.xuLy` không kiểm phiên (đăng xuất giữa lượt dọn / kéo). Purge giữ từ khoá / quan hệ nhóm của `keep` trỏ vào danh mục của nhà KHÁC — cố ý.
14. `getLastTransactionDate` bỏ khoản của nhà ⇒ người chỉ ghi vào nhà bị nhắc *"chưa ghi chép"* — lát 2 (khi có đường ghi vào nhà) phải xét lại.

Chi tiết lát 1: khối 🏠 đầu mục 14 `PROJECT_CONTEXT.md`; spec mục 11 #1–#16.

---

### G112 — Vuốt để cuộn trang Mục tiêu từ một thẻ là kéo đổi thứ tự ưu tiên · ✅ MỞ VÀ ĐÓNG 2026-10-28 phiên 22 (mã + test)

**Nguồn.** Nhìn G111 trên Realme (bản debug `4bd0b14d…`, tài khoản 10). `adb shell input swipe 540 1800 540 900 300` để cuộn trang
*Mục tiêu tiết kiệm* bắt đầu trên thẻ MuaDT — thẻ đổi chỗ lên trên MuaXe; CSDL máy: ưu tiên MuaXe **1** · MuaDT **3** (bản sao lưu
đầu phiên) thành MuaDT **100** · MuaXe **200**, `synced`, `/sync/push` 200 — không hộp nào hỏi, khối Nhận xét đổi sang nói về MuaDT.

**Gốc.** `goal_page.dart` bọc cả thẻ bằng `ReorderableDragStartListener` — loại này nhận kéo **ngay** khi ngón tay vượt ngưỡng di
chuyển (loại chờ nhấn giữ là `ReorderableDelayedDragStartListener`). Chú thích cạnh đó nói ngược (*"chỉ bắt thao tác kéo dài"*), còn
chữ dưới danh sách hứa *"Nhấn giữ một mục tiêu để kéo đổi thứ tự ưu tiên"*. Danh sách nằm trong `SingleChildScrollView` nên mọi
cú vuốt dọc bắt đầu trên một thẻ đều thành kéo thả. Ưu tiên quyết thẻ nào khối Nhận xét nói tới và thứ tự hiển thị; đi qua đồng bộ.

**Sửa.** `ReorderableDelayedDragStartListener` (chú thích sửa + ⚠️ đừng đổi lại). Chạm vẫn mở chi tiết.

**Canh.** `test/features/goal/presentation/pages/goal_page_keo_tha_test.dart`: *vuốt nhanh 400 ms từ thẻ thứ hai → không gọi
`capNhatUuTien`* (đỏ trên mã cũ — tái hiện đúng máy) + *nhấn giữ quá `kLongPressTimeout` rồi kéo → đổi ưu tiên*.

**Dữ liệu người dùng.** Thứ tự trên Realme trả lại bằng chính thao tác nhấn giữ + kéo của app: MuaXe **50** · MuaDT **100** (máy và
`PersonFinance` khớp) — thứ tự như cũ, giá trị số khác bản gốc 1 / 3.

**Nhìn trên máy (Realme, bản debug `6fd33863…`, cùng phiên).** Lặp lại đúng cú vuốt gây lỗi (`input swipe 540 1800 540 900 400`, bắt
đầu trên thẻ MuaDT): trang **cuộn** (thẻ dời lên 561 px), thứ tự giữ nguyên, CSDL máy vẫn MuaXe 50 · MuaDT 100. Vế *nhấn giữ rồi kéo*
chỉ có widget test canh — không thử trên máy để khỏi đổi dữ liệu người dùng thêm lần nữa.

---

### G111 — Công tắc bị khoá theo quyền vẽ y hệt công tắc mở · ✅ MỞ VÀ ĐÓNG 2026-10-28 phiên 21 (mã + test)

**Nguồn.** Ghi nhận phiên 19 khi nghiệm thu B1 Task 13 trên máy (*"công tắc bị khoá vẽ giống hệt công tắc mở, chỉ băng báo
khoá"*); phiên 21 đối chiếu Stitch `68593384…` *"Thêm hóa đơn - Tự trả bị khoá (Basic)"*: công tắc khoá **mờ 50 %** (`opacity-50`),
**ổ khoá trong núm**, cả khi tắt lẫn khi đang bật. Spec phân quyền 2026-10-08 mục 4.3 (2) cũng ghi *"công tắc mờ"*.

**Gốc.** Bảy chỗ (form Thêm / Sửa hoá đơn — tự trả; Thêm / Sửa ví — tính vào tổng; Thêm mục tiêu — trích tự động; Cài đặt thông
báo — D1 và nhắc ghi chép) khoá bằng `Switch(onChanged: null)` và tin Material 3 tự làm mờ. Nhưng phần lớn công tắc ấy đặt cứng
`activeTrackColor` / `inactiveTrackColor`, và màu đặt cứng **thắng** màu khoá mặc định: đo bằng widget test (Flutter 3.47.8) —
`Switch(value: true, onChanged: null, activeTrackColor: X)` vẽ rãnh đúng màu `X` đủ độ đậm (y hệt công tắc mở); không đặt màu
thì rãnh khoá còn alpha 0,12. Không lỗi, không log — chỉ mắt người thấy, và `flutter test` cũ chỉ kiểm `onChanged == null`.

**Sửa.** `CongTacTheoQuyen` (`premium/presentation/widgets/the_khoa_quyen.dart`, cạnh `DongKhoaCongTac`) là chỗ duy nhất vẽ công
tắc khoá: `biKhoa` → `Opacity(kDoMoCongTacKhoa = 0.5)` + `thumbIcon` ổ khoá + núm trắng, rãnh **giữ màu của chỗ gọi** (thiếu màu →
màu mở của theme) để không chồng lớp mờ mặc định; không khoá → `Switch` y như cũ. Bảy chỗ truyền `onChanged` thật + `biKhoa:
!coQuyen(…)` (ví: `!doiDuocTinhVaoTong(…)` — I3 vẫn cho bật lại ví đã lưu "không tính"); `HangCongTac` nhận `biKhoa`.
Hai màu `0xFF006E1C` ghi cứng ở `the_bien_dong.dart` / `khung_cai_dat.dart` **giữ nguyên** (`AppColors.secondary` = `#4CAF50`,
khác màu — đổi là đổi màu công tắc đang mở).

**Canh.** Helper `test/helpers/cong_tac_khoa.dart` `laCongTacKhoa` (ba vế: `onChanged == null`, `Opacity` 0,5 bọc ngoài,
`thumbIcon` là ổ khoá) gắn vào bảy ca khoá sẵn có (cả bảy đỏ trên mã cũ) + ca *"có quyền → không dạng khoá"*; nhóm *"G111 —
CongTacTheoQuyen"* ở `the_khoa_quyen_test.dart` đo **màu rãnh vẽ ra** (`paints..rrect`) — bản sai *"khoá thì bỏ màu"* làm nó đỏ;
**test quét 41** `test/features/premium/cong_tac_khoa_mot_noi_test.dart` cấm `Switch(` / `HangCongTac(` mà đối số hỏi
`coQuyen(` / `coQuyenDoc(` / `coQuyenNen(` không qua `biKhoa:` (trên mã cũ bắt 6 chỗ; không bắt `_coQuyenOs` — quyền hệ điều
hành). Ô thả xuống và chip khoá (*Nhắc trước*) không thuộc phạm vi: Material vẽ chúng mờ đúng.

**Nhìn trên máy (Realme 360 dp, bản debug `4bd0b14d…`, 2026-10-28 phiên 22).** Tài khoản 10 Premium; tắt sáu mã ở **cột Premium**
qua API admin trên `PersonFinance`. Cả năm loại công tắc vẽ mờ + ổ khoá trong núm + băng *"Tạm ngừng"*, `disabled` trong cây trợ năng:
*Nhắc ghi chép hằng ngày* (đang bật) · *Biến động số dư* (đang bật — ngay dưới nó *Nhắc ghi sau khi dùng app ngân hàng* không khoá vẽ
xanh đặc, phân biệt rõ) · *Tự động thanh toán* ở form Thêm hoá đơn (đang tắt) · *Tính vào tổng tài sản* ở Sửa ví (cạnh *Kích hoạt
hoạt động* xanh đặc) · *Tự động trích tiền định kỳ* ở Sửa mục tiêu (đang bật). Chip *Nhắc trước* mờ, giữ chip đã chọn. Bật lại → như
cũ. 0 điểm vàng sọc tràn trên 24 ảnh. Chi tiết: mục 8.10 `PREMIUM_FEATURE.md`.

---

### G110 — Danh mục người dùng tự tạo trùng (tên, loại) một khuôn bị ẩn theo khuôn, không có lối đổi tên · ⏸ MỞ 2026-10-27 · ✅ ĐÓNG 2026-10-28 phiên 21

**Nguồn.** Review toàn nhánh kế hoạch *danh mục mặc định theo thao tác Admin-web* (spec `2026-10-27-…-design.md` mục 3, 7). Luật ẩn
`dangAnTheoKhuon` nhận bản sao bằng (tên chuẩn hoá, loại) và **không phân biệt** bản sao do bộ tạo bản sao đẻ ra với danh mục người
dùng tự gõ tay cùng tên + loại (server không lưu mối nối bản sao ↔ khuôn). Khi admin xoá mềm khuôn, cả hai bị ẩn khỏi mọi danh sách
chọn; chỉ bản đã ĐỔI TÊN thì hiện.

**Hệ quả.** Người dùng tự tạo *"Cà phê"* (Chi) trùng khuôn *"Cà phê"* (Chi) rồi admin xoá khuôn → *"Cà phê"* của họ biến khỏi bộ chọn
và màn Danh mục, không có chỗ nào để đổi tên nó cho hiện lại. Dữ liệu còn nguyên (giao dịch cũ vẫn tra được tên); admin khôi phục
khuôn là hiện lại. Bán kính: chỉ ai đã tự tạo trùng đúng tên + loại một khuôn, và chỉ khi admin xoá khuôn đó (Supabase đo 2026-10-27:
0 khuôn xoá mềm).

**Hoãn vì.** Cần một màn mới. Đề xuất mục *"Đang tạm ngừng"* thu gọn ở cuối màn Danh mục: liệt kê các danh mục đang ẩn theo khuôn,
cho đổi tên (đổi tên là hết khớp khuôn → hiện lại, chốt 2 của spec). Quy tắc dự án: phần giao diện chưa có trong Stitch phải đưa lên
Stitch trước khi làm. Trạng thái **MỞ**.

**Đóng 2026-10-28 (phiên 21).** Người dùng duyệt thiết kế rồi duyệt màn Stitch `2dd819da…` *"Danh mục - Mục Đang tạm ngừng"* (lượt tạo
trả `timeout`, màn hiện sau ~1 giờ). Mã:
- Cửa `category/data/danh_sach_chon_danh_muc.dart`: `hangChonVaAn` / `theoDoiHangChonVaAn` tách hàng của tài khoản thành `chon` (đúng
  `hangChonDuoc`) và `an` (đúng những hàng mọi bộ chọn bỏ đi) **từ cùng một truy vấn** — quét 40 giữ nguyên.
- `CategoryTree.dangTamNgung` (mặc định rỗng); `watchTree` / `loadTree` điền. Hàng ẩn không lọt vào nhóm / *Chưa nhóm*.
- `category/presentation/widgets/muc_dang_tam_ngung.dart`: `MucDangTamNgung` — khối xám (`AppColors.khoaNgung*`) **thu gọn sẵn**,
  chỉ dựng khi N > 0 (theo tab loại đang chọn), mỗi dòng biểu tượng mờ 50 % + tên + *"Đổi tên để dùng tiếp"* + bút →
  `/categories/child/:id/edit?tamNgung=1`; `DaiNhacTamNgung` — dải nhắc đầu form Sửa nói theo tên lúc mở form.
- ⚠️ `CategoryAddPage` tìm danh mục trong các nhánh của cây — nay đọc cả `tree.dangTamNgung`; thiếu vế ấy là mở hàng đang ẩn ra form
  **trống** (ca test canh, bản sai làm nó đỏ).
- Liệt kê **mọi** hàng ẩn theo khuôn, kể cả bản sao chưa đổi tên — không phân biệt được với danh mục tự gõ (server không lưu mối nối).
Test: `danh_sach_chon_danh_muc_test` nhóm G110 (3), `category_management_repository_test` (1), `presentation/muc_dang_tam_ngung_test.dart`
(6 — gồm 320 dp font thật). ~~Chưa nhìn trên máy thật~~ — ✅ **nhìn Realme 2026-10-28 phiên 22, đạt** (backend dev trỏ `PersonFinance`
sau hai phép đích danh — áp `database/40`, `prisma generate`; không phải xoá khuôn nào: `PersonFinance` có sẵn khuôn *"Thử đổi tên"*
xoá mềm 27/10 07:23 UTC, sau mốc `kMocAnTheoKhuon`, mà bản sao của tài khoản 10 còn sống): màn Danh mục 360 dp có *"Đang tạm ngừng
(1) · Danh mục hệ thống cùng tên đã ngừng"* thu gọn dưới *Danh mục mặc định*; mở ra → *"Thử đổi tên — Đổi tên để dùng tiếp"* mờ + bút;
bút → form *Chỉnh sửa danh mục* có dải nhắc đúng chữ, tên điền sẵn (không trống). Đổi tên thành *"Thử đổi tên G110"* → Lưu → hàng về
*Chưa nhóm*, mục tạm ngừng biến mất; đổi lại tên cũ → mục *"Đang tạm ngừng (1)"* quay về; hai `/sync/push` 200 (dữ liệu như trước).

---

### G109 — Basic sau khi Premium hết hạn offline dùng trần của Premium · ✅ MỞ 2026-10-27 phiên 17 (thiết kế B1), ĐÓNG 2026-10-28 phiên 18 (mã + test, `f4d35331`, `97357a0b`, `d885e16d`)

**Nguồn.** Lộ khi thiết kế B1 (spec mục 0): `domain/tran_goi.dart` cũ đọc `goi.tran` thô. `/payment/subscription-info` chỉ trả bảng
của gói ĐANG hiệu lực, nên trần lưu trong kho của người Premium là toàn `null` (không giới hạn). Premium hết hạn **lúc offline**
(`laPremium(now)` đổi, kho chưa nhận bảng Basic) → app coi tài khoản là Basic nhưng đọc trần Premium → tạo ví / ngân sách / mục tiêu
không giới hạn tới lượt `lamMoi` kế (bán kính: chỉ cửa sổ offline sau ngày hết hạn).

**Sửa.** `tranHieuLuc(goi, now)` (`premium/domain/tran_goi.dart`) là cửa đọc trần duy nhất: bảng dùng được (`bangDungDuoc`) → `goi.tran`;
không → Premium `TranGoi.khongGioiHan`, Basic `TranGoi.macDinh`. `conTaoDuoc`, cửa route `redirectTaoTheoGoi`, câu màn Nâng cấp, thẻ
Gói đều đọc qua nó; chỗ còn đọc `goi.tran` thô chỉ ở chính `tranHieuLuc` (đợt sửa cuối B1, 2026-10-28: `dacQuyenPremium` — bản trước đọc
`goi.tran` có gác `bangCuaBasic` — nay cũng đọc qua `tranHieuLuc`, spec B1 mục 13 (18)). Ca canh:
`tran_goi_test.dart` *"⭐ G109 …"*, `nang_cap_page_test.dart` *"⭐ G109 trên màn …"*, `the_goi_tai_khoan_test.dart` *"⭐ G109 …"* — mã cũ làm
cả ba đỏ. Nghiệm thu máy thật (spec B1 mục 10 bước 6) thuộc Task 13, **chưa làm**.

---

### G108 — Bộ tạo bản sao danh mục so (tên, loại) nhưng chỉ mục server chỉ có tên · ✅ MỞ VÀ ĐÓNG 2026-10-27 (mã + test, `ca2a0364`)

**Nguồn.** Làm kế hoạch *danh mục mặc định theo thao tác Admin-web* (spec `2026-10-27-danh-muc-mac-dinh-theo-thao-tac-admin-design.md`
mục 6). `DefaultCategorySeeder` quyết "tài khoản đã có bản sao của khuôn chưa" bằng cặp (tên chuẩn hoá, loại), còn PostgreSQL chỉ
có `uq_category_owner_name` khoá `(Create_by, tên chuẩn hoá)` — **không** có loại (quy tắc 7). Ví dụ: người dùng có "Trả nợ" loại Chi, khuôn
"Trả nợ" loại Vay/nợ sống lại → bộ tạo thấy "chưa có" và tạo bản thứ hai cùng tên; đẩy lên bị `CATEGORY_NAME_DUPLICATE`
(lỗi vĩnh viễn) → gộp-xoá-tạo lại mỗi lượt kéo, vòng đẩy hỏng — cùng lớp với G16 (đo `pg_indexes` 2026-10-27).

**Sửa.** Bộ tạo bản sao so theo **tên** chuẩn hoá (không xét loại), vẫn đếm cả hàng đã xoá mềm (ca G16 giữ xanh). `laBanSaoMacDinh`
(nhận bản sao để đếm trần / ẩn) vẫn xét loại — đổi loại khuôn thì bản sao loại cũ rơi khỏi định nghĩa (giới hạn ghi ở spec mục 7).

---

### G107 — Quét ảnh: ảnh vừa chụp mất khi tiến trình chết lúc máy ảnh đang mở (`retrieveLostData` chưa ai gọi) · ✅ MỞ VÀ ĐÓNG 2026-10-27 (mã + test + nghiệm thu Realme)

**Nguồn.** Đo Realme phiên 14 (khối 🧭 *Phiên 14* mục 14 `PROJECT_CONTEXT.md`; bước 21 `KHOA_APP_FEATURE.md` giả định *"ColorOS giết app
khi mở camera lúc đang giữ Gemma → quay về = mở lạnh = màn khoá; mở khoá xong lượt quét vẫn phải hoàn tất"*). Lượt máy ảnh khi giữ
Gemma (~3,0 GB PSS) **không** bị giết, nhưng soát mã thấy màn Quét không có đường nào nhận lại ảnh nếu bị giết: `pickImage` của tiến
trình cũ không bao giờ trả về, `image_picker` cất ảnh tới khi app gọi `retrieveLostData()` — mà `lib/` không gọi chỗ nào.

**Sửa (người dùng chọn *"mở G107 và sửa ngay"*).** `layAnhQuetBoDoThat` + `nhanAnhQuetBoDo` ở `quet_anh_page.dart` (vẫn là tệp duy
nhất import `image_picker` — quét 20): chỉ Android, `isEmpty` / `exception` ⇒ không ảnh, `files.first` rồi `file`; không bao giờ ném.
Widget `NhanAnhQuetBoDo` (`home/presentation/widgets/`, không vẽ gì, đặt sau `DongNhacKeoVe` trong cột Trang chủ) gọi nó **một lần**
ở khung đầu sau `initState` — `HomePage` không trạng thái, `build` chạy lại ở mỗi `AuthSuccess` phát lại. Có ảnh ⇒ `push('/quet')`
như `moQuet` vừa chọn xong. Test `test/features/home/presentation/widgets/nhan_anh_quet_bo_do_test.dart` (5 ca: có ảnh → `/quet` đúng
đường dẫn; không ảnh; ném lỗi — bản sai bỏ `try` đỏ; dựng lại không hỏi lần hai; Trang chủ có đặt widget). Ba ca chính đỏ trước khi sửa.

**Nghiệm thu Realme 2026-10-27** (bản debug `89c85b38…`, khoá bật *30 giây*): ColorOS chặn `settings put global always_finish_activities`
(*Không giữ hoạt động*) → giết bằng `am crash` khi `mCurrentFocus` là `com.oplus.camera` (script chờ). Tiến trình 12695 chết 09:59:45
(`reason=4 APP CRASH(EXCEPTION)` — không phải sập native, canary công cụ không lật), máy ảnh vẫn trên cùng (Android 13 chỉ đóng activity
trên cùng **của app sập**) → người dùng chụp + ✓ → tiến trình mới **16769** dựng 09:59:49 (cho `ImagePickerFileProvider`) → người
dùng thấy **màn khoá → *Đang đọc…* → form**; Gemma đọc ảnh trong tiến trình mới 39,8 s (262.000 · 6 món, *Ăn uống* — nhánh Premium:
`GoiRepository` đọc gói đã lưu dù `lamMoi` hỏng vì backend tắt) → người dùng **Lưu** (giao dịch 262.000 `chi`, `pending`).

**Bán kính / giới hạn.** Chỉ Android. Đường này **bỏ qua** cổng quyền `ocr_receipt` của nút Quét — cố ý: quyền đã xét lúc chọn ảnh. Trang
chủ chưa dựng (mở app vào thẳng một deeplink khác) thì ảnh chờ tới lần Trang chủ dựng đầu tiên. Ảnh bỏ dở từ **trình chọn ảnh** đi cùng
đường nhưng chưa đo trên máy. Test dựng `HomePage` thật gọi `image_picker` thật (nền tảng mặc định của `flutter_test` là Android) —
`MissingPluginException` bị nuốt, có thể thấy dòng `[Quet] đọc ảnh bỏ dở lỗi` trong log test.

### G106 — Lịch nhắc đặt trước (hoá đơn, ghi chép, tổng kết tuần) mất im lặng sau force-stop: `resync` tin danh sách của plugin, không phải AlarmManager · ✅ MỞ VÀ ĐÓNG 2026-10-24 tối (mã + test + đo lại Realme)

**Nguồn.** Đo Realme phiên 4 (khối 🔒 mục 14 `PROJECT_CONTEXT.md`, gạch *Đo Realme lượt 2 + Đợt 7*): cài đặt bật *Nhắc ghi chép
20:00* và *Tổng kết tuần Thứ Hai 08:00*, `scheduled_notifications.xml` của plugin liệt kê `ghiChep:2026-10-25`, `weekly:…`,
`ghiChep:2026-10-26` — mà `dumpsys alarm` có **0** báo thức của app. Lịch sử tiến trình: force-stop 19:55:03 (ngay sau lượt cài
đè). Tái hiện chắc chắn: `am force-stop` → 0; mở app, quét xong → **vẫn 0**, danh sách vẫn 3.

**Cơ chế.** `ReminderScheduler.resync` hỏi `osNotifier.pendingIds()` = `pendingNotificationRequests()`, đọc danh sách
SharedPreferences của plugin. Force-stop xoá báo thức của gói mà không đụng danh sách, và không phát broadcast nào (bộ nhận
`BOOT_COMPLETED` / `MY_PACKAGE_REPLACED` chỉ cứu khởi động lại máy và cập nhật app — đo: cài đè không force-stop thì 3 báo thức
còn). `resync` thấy id "đã chờ" thì bỏ qua (luỹ đẳng); khoá nhắc hoá đơn không đổi giữa các lượt quét nên lịch ấy **không bao giờ**
được đặt lại — tới khi người dùng đổi giờ nhắc (`datLai`). Ghi chép hằng ngày tự lành dần (khoá theo ngày), tổng kết tuần lành
sau một tuần.

**Sửa.** Lượt `resync` đầu tiên của mỗi bộ đặt lịch (`_daKhoiPhuc`; DI `registerLazySingleton` ⇒ mỗi tiến trình / isolate
một lần) đặt lại cả lịch "đã chờ": **không** huỷ trước (cùng id thay chỗ; `cancel` gỡ luôn thông báo cùng id đang nằm trên
khay), **không** ghi `dat_lich` (B5b đếm "tới máy" theo nó); chỉ đánh dấu khi lượt chạy trọn. Test: 2 ca mới ở
`reminder_scheduler_test.dart` (đỏ trước khi sửa); 2 ca cũ (tiền đề G59, B5a lần hai) đổi sang **một** bộ đặt lịch. Đo lại
Realme: force-stop → 0, mở app → **3** (25/10 20:00 · 26/10 08:00 · 26/10 20:00), danh sách 3, không nhân đôi. Bẫy **7.14**
`NOTIFICATION_FEATURE.md`.

**Bán kính.** Mọi lịch đặt trước trên Android sau một lần force-stop (Cài đặt → Buộc dừng, ColorOS gỡ task ở một số trạng thái,
`adb install` + `am force-stop` khi đo). Lịch **Hoãn** (không nằm trong tập "muốn") vẫn mất sau force-stop — hiếm, chấp nhận.

### G105 — Quét ảnh: chữ rác ở mép ảnh thắng tên cửa hàng (*"card n"*, *"ral Setl Ths cad rd effect"*) · ◐ SỬA MỘT PHẦN 2026-10-22 (dòng toàn chữ thường) · ✅ ĐÓNG 2026-10-28 phiên 22 (khối chữ Latin)

**Nguồn.** Đo Quét ảnh trên Realme (bản `16b71a1e…`, khối 🧷 mục 14 `PROJECT_CONTEXT.md`). Người dùng chụp tờ ỦA TEA N01 bằng
nút *Chụp ảnh*; OCR ra ba dòng đầu *"card n"* · *"Dịa chi Kios 01, quang truờng Dramond, Drh Thi"* · *"ỦA TEA 2DEE"* —
*"card n"* là chữ của vật nằm ở mép khung. Luật tên cửa hàng (chốt 12 `QUET_ANH_FEATURE.md`: chỉ tìm trước thân hoá đơn, bỏ
mẩu **một** từ ≤ 4 chữ cái, địa chỉ / liên hệ, tiêu đề chứng từ) cho *"card n"* qua và lấy nó vì đứng đầu → ghi chú
*"card n"*. Số tiền 398.800 và ngày giờ 14/10 14:07 vẫn đúng. Chụp lại (không dính mép) → *ỦA TEA* đúng. Chữ OCR lần ấy (55 dòng
`[Quet][OCR]` của logcat, đã che số khách) ở cuối mục này — nay cũng là tờ `N01b` của `hoa_don_quet_that_du_lieu.dart`.

**Sửa (cùng tối).** Người dùng chọn *ưu tiên dòng viết hoa* trong ba hướng (siết mẩu ngắn · ưu tiên viết hoa · để nguyên).
Bản *"dòng viết hoa toàn bộ thắng"* thử trước bị chính bộ chữ thật lật: R06 (*"NHÀ THUỐc"* — OCR đọc chữ cuối thường) đổi sang
dòng khẩu hiệu viết hoa bên dưới, và tên viết thường (*"Quán Phở Hùng"*, *"eco-shop Invoice"*) thua dòng *DELIVERS* ngay dưới
— trái lời hứa *"tờ tên viết thường không đổi"*. Nên luật làm là bản hẹp của cùng ý: `_cuaHang` (`doc_hoa_don.dart`) xếp
dòng **toàn chữ thường** sau mọi dòng có chữ hoa, vẫn lấy nó khi không còn dòng nào khác. N01 chụp dính mép nay ra
*"ỦA TEA 2DEE"* (đuôi rác *2DEE* **không** cắt — tên kiểu *7ELEVEN*, *24H* sẽ bị cắt oan). Test: tờ `N01b` thêm vào
`hoa_don_quet_that_du_lieu.dart` (17 mục) + bốn ca thuần ở `doc_hoa_don_test` (*card n* · tên lẫn hoa không thua dòng viết
hoa · chỉ dòng thường vẫn lấy · hai dòng thường lấy dòng đầu); 34 tờ chữ thật cũ giữ nguyên kết quả; hai bản sai cấy thử đỏ.

**⚠️ Đo lại trên máy (Realme, bản `5129e9df…`, 2026-10-22 khuya) — phần còn hở.** Người dùng chụp N01 dính một tấm thẻ in
chữ tiếng Anh ở mép trên: OCR ra **sáu** dòng rác đứng trước *"ỦA TEA"* (dòng 7, viết hoa toàn bộ, ngay trên dòng địa chỉ),
dòng đầu *"ral Setl Ths cad rd effect"* có chữ hoa nên không bị xếp sau → ghi chú điền chuỗi ấy. Số tiền 398.800, ngày giờ
14/10 14:07, danh mục Ăn uống vẫn đúng. Luật *"viết hoa toàn bộ thắng"* sẽ ra đúng tờ này nhưng đã bị R06 thật lật (mục
*Sửa*). Chữ OCR ở khối thứ hai cuối mục.

**Hướng chọn cho phần còn hở (người dùng, 2026-10-22 khuya):** *nhắc lúc chụp* (trong ba hướng: hoãn · nhắc · thử thêm luật).
Sheet chọn nguồn ảnh nay theo đúng Stitch `50e001f2…` (bản có dòng nhắc của `8027b781…`, người dùng xác nhận) và có dòng *"Chụp sát tờ hoá đơn, đừng để vật có chữ lọt vào khung"*
(`kNhacChupSat`, `2bdc2a68`; nghiệm thu Realme 360 dp: không tràn). Luật đọc tên không đổi thêm. G105 để ◐ — vật có chữ lẫn
hoa thường lọt vào khung vẫn ra ghi chú sai; người dùng thấy và sửa trên form.

**Đóng phần hai (2026-10-28 phiên 22).** Người dùng chọn *"G105 phần còn lại — mã + test"* (đè lựa chọn *"không thêm luật"* hôm
22/10). Chữ OCR lần chụp dính tấm thẻ (khối thứ hai cuối mục) vào bộ dữ liệu thành tờ **`N01c`** (`hoa_don_quet_that_du_lieu.dart`,
18 mục) — đỏ trên mã cũ đúng như logcat (*"ral Setl Ths cad rd effect"*). Dò 35 tờ chữ thật cũ: hai tên Latin lẫn hoa thường thật
(*eco-shop Invoice*, *DOOKKI Topokki Buftet*) và không tờ nào có dòng viết hoa có dấu ngay sau một khối chữ Latin — khác hẳn N01c
(sáu dòng Latin liền rồi *"ỦA TEA"*). Luật `_cuaHang` (`doc_hoa_don.dart`): ứng viên đầu là khối **≥ 2** dòng không chữ ngoài ASCII
và không viết hoa toàn bộ, **và** ứng viên **ngay sau** khối viết hoa toàn bộ có chữ ngoài ASCII → lấy ứng viên ấy; ngoài ra luật cũ
giữ nguyên. Kết quả: N01c → *ỦA TEA*; 35 tờ cũ không đổi; ba ca tổng hợp ở `doc_hoa_don_test` canh hai vế hẹp — bản sai *"bỏ vế ≥ 2"*
đỏ ở *Circle K / CỬA HÀNG TIỆN LỢI*, bản sai *"bỏ vế ngay sau"* đỏ ở *Phuc Long Coffee … PHIẾU TẠM TÍNH*. ⚠️ **Còn hở biết trước:**
thương hiệu Latin hai dòng mà dòng ngay sau là khẩu hiệu tiếng Việt viết hoa sẽ lấy khẩu hiệu; chữ rác có dấu / viết hoa toàn bộ vẫn
lọt. Hướng chắc hơn: cỡ chữ / độ tin của ML Kit (chữ đã lưu không mang toạ độ — phải đo bằng tờ giấy trên máy). **Chưa chụp lại trên
máy** (cần tờ N01 + tấm thẻ). Dòng nhắc chụp giữ nguyên. Chốt 12 `QUET_ANH_FEATURE.md`.

**Bán kính.** Chỉ ghi chú của hoá đơn quét khi ảnh dính chữ lạ ở mép trên; người dùng thấy ngay trên form và sửa được.

<details><summary>Chữ OCR N01 chụp lần đầu — Realme 2026-10-22 19:58, <code>/quet</code> thật (luật: <code>tong=398800 | ghi="card n" | luc=2026-10-14 14:07</code>)</summary>

```
card n
Dịa chi Kios 01, quang truờng Dramond, Drh Thi
ỦA TEA 2DEE
Thi, Van phúc
Hotline: 0934803456
HÒA ĐƠN THANH TOÁN
So HÐ: UAO068
Mã HD: #TH8HW TN: THU NGAN
an: HUB (GRABF00D) Ngðy: 14/10/2026
(GF-264_TH8HW)
Giò ra 1407
Gid vào: 1407
STT pon Thanh
Tên món
gid tien
MATCHA OATMILK 142,000 42,000
SIZE NM
100% NGOT 1
100% ĐẢ
SÜA TƯƠI TRẢN
CHÅU ĐUỜNG ĐẾN- L 39,000 39,000
50X NGOT
100% ĐẢ
MATCHA LATTE 39,000 39 000
-SIZE M
50% ĐẢ
4 MATCHA LATTE 39, 000 39,000
4gr bột Matcha 12,000 12,000|
- SIZE M 0
MATCHA LATTE 39,000| 39,000
- SIZE M
50% NGỘT
TRA NHO XANH
45,000 90,000
THACH DUA - L
NHẢN DỦA SỬA 149 000 49,000|
TRA TRÁI CAY NHHẾT
8 ĐỚI - L 145,0D0 45,000
HOP TRAI CẢY NHO
|MIX 3 LOAI 29,000 29,000
Tống số mon. i0
Thành tien: 423,000 d
Tien chiết khấu: 24,200 d
Töng tien: 398,800d
+Thanh toán (GRAB_ONLINE) 398,800 d
Ghi chú: (GRABFOOD-GF-264.THEHW-DEL-2026-
10 14 1407 30). Hoa đon áp dung bản hàng thea
kénh
Khách bông - 8410****** -
null
Moi thác Inåc, khiéu nại dưn hàng, quy kihách vui
là ng lién hệ hotline nhé
MR realme Shot on O3 Pro 5G 2026 10 22 19:57
Cảm on Quy Khách
Powered by iPOs.vn
```

</details>

<details><summary>Chữ OCR N01 chụp dính tấm thẻ in chữ tiếng Anh — Realme 2026-10-22 21:31, <code>/quet</code> thật (luật: <code>tong=398800 | ghi="ral Setl Ths cad rd effect" | luc=2026-10-14 14:07</code>)</summary>

```
ral Setl Ths cad rd effect
LDIVNE.BEAST/EFEECT o Normal Saon ifthis cae etroy ais onstes O00 DE ODEF/400
Norma thes card
keqires 1Trbtes
eflects c
trok This card can
ỦA TEA
Dla chi: Kios 01, quang trưong Dianmond, Dirh Thi
Thi, Van phủc
Hottine: 0934803456
HỎA ĐƠN THANH TOẢN
So HÐ: UAO068
Må HD: #TH8HW TN: THU NGÁN
Bàn. HUB (GRABF00D) Ngày: 14/10/2026
(GF-264.THBHW) Giò ra: 1407
Giò vào: 1407
Don Thành
STT Ten mỏn SL giá tien
MATCHA OATMILK 142,000 42,000
SIZE M
100% NGOT
100% ĐẢ
sÜA TƯƠI TRẢN 39,000 39,000
CHÅU ĐUỜNG ĐẾN-L
50% NGOT
100% ĐA
MATCHA LATTE 39 000 39000
SIZE İM
50% ĐÁ
MATCHA LATTE 39,000|39,000
4gr bột Matcha 12,000 12,009|
-SIZE M
MATCHA LATTE 39,000 39000
-S1ZE M
-50% NGOT
TRA NHO XANH
0 THACH DỪA- L 245,000 90,000|
NHÃN DỮA SỬA 149,000 49,000
TRA TRÁI CAY NHIỆT
145,090 45,000
ĐO-L
HÓP TRÁI CẦY NHỎ
MIX 3 LOAI 129,000 29,000
Töng số mon. 10
Thành tien: 423,000 d
Tiên chiết khäu: 24,200 d
Tong tien: 398,800d
+Ihaph 1oản (GRAB_ONLINE) 398,800 d
Ghi chú: (GRABFOOD-GF 264.THEHW-DEL-2026
10 14 1407.30].. Hoa đon áp dụng bản hàng theo
kenn
Khách hang - 8490000000 -
null
Moi thảc Inàc, khiéu nại dun hang, quy kihách vuị
long liên hệ hotline nhé
AR realme Shot on A03 Pro 5G 2026 10 22 21:31
```

</details>

---

### G104 — Đường luật bỏ trống của N1 vẫn có thể điền bản cụt của Gemma (*"một triệu hai tiền sách"* → 1.000.000) · ⏸ HOÃN 2026-10-22 → ✅ ĐÓNG 2026-10-23 (mã + test, chưa đo trên máy)

**Nguồn.** Lượt thu hẹp kiểm chéo C4 (mục 4 `GIONG_NOI_FEATURE.md`, khối 🎯 mục 14 `PROJECT_CONTEXT.md`). Nghiệm thu Realme
2026-10-21: Gemma đọc *"tiền điện một triệu hai"* thành **1.000.000** 2/2 lần. Câu ấy nay luật điền 1.200.000 và không hỏi Gemma.
Nhưng ở câu luật **bỏ trống** — chữ số lẻ không đứng ở chỗ của tiền (*"một triệu hai tiền sách"*, *"chi hai triệu năm nay"*),
`_dungChoTien` — ô số tiền là ô thiếu, Gemma chọn trong `cachDocSoTien` (gồm cả bản cụt) và lưới `soTienAiHopLe` cho qua: nếu
Gemma đọc cụt thì form điền 1.000.000 **không hỏi**. Chưa đo câu nào kiểu này trên máy.

**Vì sao hoãn.** (1) Thêm *"một triệu hai = 1.200.000"* vào `promptNhapNhanh` là đổi lời nhắc của **mọi** câu Nhập nhanh hỏi AI
— phải đo lại cả OnePlus GPU lẫn Realme CPU (bẫy 4.51: lời nhắc dài làm chuỗi số hỏng). (2) Bỏ bản cụt khỏi `cachDocSoTien` thì
Gemma mất cách đọc ấy ở câu mà nó mới đúng (*"chi hai triệu năm nay"* = 2.000.000). (3) Ở những câu này cả hai cách đọc đều có
thể đúng — một lưới thuần mã không biết chọn; hai chip là ứng viên, nhưng là quyết định của người dùng.

**Bán kính.** Chỉ câu *X triệu / nghìn Y* mà Y đứng trước một danh từ khác; câu *X triệu Y* cuối câu / trước ví · ngày (phổ biến
khi nói) không bị.

**Sửa (2026-10-23, người dùng chọn lối hai chip — lý do hoãn (3)).** `_chonSoTien` (`doc_cau_giao_dich.dart`): cụm *"X bậc Y"*
viết chữ mà Y không ở chỗ của tiền, và không hạng nào có cụm khác → hai cách đọc `[cụt, dài]` vào `KetQuaDocCau.luaChonSoTien`
thay cảnh báo *"chưa rõ"*. `docCauGiaoDich`: có chip thì AI **không** lấp ô số tiền và ô ấy không là `OThieu.soTien` (luật biết
cụm là tiền, chỉ cách đọc còn mở); `khongDocDuocGi` tính cả chip; `cauDaDien` trả `''` khi chỉ có chip. `ThemGiaoDichCubit
.dienKetQua`: chip → `luaChonTienCau`, ô số tiền về 0, bỏ dòng tóm tắt khi không còn gì để nói (nếp `_chotSoTien`) — khối
`KhoiChonSoTien` có sẵn. Lời nhắc Gemma **không** đổi; ghi chú vẫn còn cụm số nên `OThieu.ghiChu` vẫn hỏi Gemma — chip hiện sau
đúng lượt chờ như trước, cái lợi là số đúng chứ không phải nhanh hơn. Huỷ lượt AI / mô hình chưa sẵn sàng → chip vẫn hiện.
Ngoài phạm vi: câu trộn dấu *"một triệu tu"* (`moHo`, Gemma còn chọn); dạng chữ số *"1 triệu 2 tiền sách"* (luật vẫn điền
1.000.000 như trước C4 — ca canh *"nộp 2 triệu 3 ngày sau"*); lệnh tạo C3 (`chonSoTienTrongCau` vẫn `null`).

**Cùng lượt — một định nghĩa *"X bậc Y"* (người dùng chốt).** Chạy câu thật lộ thêm: luật điền *"trả hai trăm nghìn tám"* =
**200.800**, *"một triệu hai trăm nghìn ba"* = 1.200.300 không hỏi (cùng công thức, X không phải số người ta nói), và chip của
*"hai trăm nghìn tám tháng"* sẽ là 200.800. `_docXBacY` là định nghĩa duy nhất — luật điền, chip, `cachDocSoTien` cùng gọi: X =
cụm / bậc phải là số nguyên **1–99**. Ranh giới *"X một chữ số"* được đề xuất trước rồi bỏ: chạy câu thật cho thấy nó làm hỏng
*"mười lăm triệu hai"* (15.200.000), *"hai mươi triệu năm"*, *"mười lăm nghìn hai"* — luật đang điền đúng. Dạng chữ số
(`_mauTrieuLe`) cố ý không qua: bỏ cách đọc dài ở đó thì `_mauSoDonVi` đọc *"12 triệu"* thành số chắc, điền bản cụt.

**Test.** `doc_cau_noi_test` — nhóm *"N1 — Y KHÔNG ở chỗ của tiền"* đổi kỳ vọng (ba câu ra chip, *"hai trăm nghìn tám tháng"*
vẫn chưa rõ) + nhóm *G104* 18 ca (X hai chữ số ở chỗ của tiền giữ nguyên; X ≥ 100 thôi điền và rời tập cách đọc; chip + không
`OThieu.soTien` + `khongDocDuocGi` false; *"một triệu tu"* không chip; *"45k"* thắng; câu còn cụm nói luật chọn được — *"một
triệu hai tiền sách năm chục"* — không chip G104, cụm mơ hồ thành `soTienKhac` của C4; AI trả 1.000.000 / 1.200.000 / 20.000 →
không lấp; C3 `null`; `cauDaDien` rỗng). `doc_cau_giao_dich_test` một ca đổi kỳ vọng. `them_giao_dich_kiem_cheo_test` +5 (không
AI chỉ chip, không dòng *"chưa đọc được"*; Gemma trả bản cụt → chip, chạm chip điền; số gõ trước bị bỏ; câu còn cụm luật chọn
được → chip của kiểm chéo C4 [1.000.000, 50.000]; Huỷ lượt AI → chip). Ca mới đỏ trên mã cũ; ba bản sai cấy thử — bỏ chốt *"AI
không lấp"* (4 ca đỏ), bỏ vế chip trong `khongDocDuocGi` (8 ca đỏ), cho chip bật cả khi luật đã chọn cụm (2 ca đỏ).

**Đo trên máy (chưa).** Realme / OnePlus, Premium: gõ và nói *"một triệu hai tiền sách"* → ô trống + hai chip, chạm 1.200.000
thì điền; *"trả hai trăm nghìn tám"* → ô trống + *"chưa rõ"*; *"tiền nhà mười lăm triệu hai"* → 15.200.000. Google có thể chép
*"một triệu hai"* thành chữ số — khi ấy câu đi dạng chữ số, ngoài phạm vi.

---

### G103 — Lời nghe của Google viết khác chữ gõ (*"mbbank"*, *"500.000₫"*): ví nguồn trượt về ví chọn sẵn, ghi chú sót · ✅ MỞ VÀ ĐÓNG 2026-10-21 tối (mã + test + kiểm lại Realme)

**Nguồn.** Lối Android của C4 trên Realme (bảng mục 9.1 `GIONG_NOI_FEATURE.md`), câu nói *"Chuyển năm trăm nghìn từ MB Bank sang
tiết kiệm"*, ví tài khoản 10 gồm *Ví MB Bank* và *Tiết kiệm*.
- Google trả *"chuyển 500.000 từ mbbank sang tiết kiệm"* → form *Chuyển khoản · 500.000 đ · đến Tiết kiệm* nhưng **ví nguồn Tiền
  mặt** (ví chọn sẵn), ghi chú *"từ mbbank"*. `_tenGoiViTrongCau` dựng mẫu tên gọi tắt bằng `\s+` giữa các từ (*"mb\s+bank"*).
- Sau bản sửa ấy, Google trả *"chuyển 500.000₫ từ mbbank sang tiết kiệm"* → ví đúng, ghi chú *"₫"*. Mẫu số tiền chạy trên câu bỏ
  dấu (`removeVietnameseTones`) và chỉ nhận *đ → d* làm đơn vị; *₫* (U+20AB) không phải chữ có dấu nên lọt.

**Sửa (`doc_cau_giao_dich.dart`).** Mẫu tên gọi tắt nối từ bằng `\s*` — hai đầu vẫn chặn ranh giới từ, vẫn chỉ nhận ngay sau *ví ·
bằng · qua · từ · sang · vào · đến · tới*. `_chuanCau(cau)` = NFC + *₫ → đ* (cùng một đơn vị UTF-16, vị trí giữa câu có dấu / bỏ dấu
không lệch) thay `unorm.nfc(cau)` ở cả ba phép đọc (`docCauGiaoDich`, `cachDocSoTien`, `chonSoTienTrongCau`) — lưới số tiền AI dùng
cùng cách đọc. Câu gõ tay cũng hưởng (C2, C3).

**Test.** `doc_cau_noi_test` +4 ca: nguyên văn *"…từ mbbank…"* (chuyển ví đúng, ghi chú không còn *mbbank*), *"…bằng mbbank"*, ca chặn
*"phí mbbank 20 nghìn"* (không giới từ → không chọn ví), và *"…500.000₫…"* / *"ăn phở 45.000₫"* (đơn vị, ghi chú, `cachDocSoTien`).
Hai ca đầu và ca *₫* đỏ trên mã cũ.

**Kiểm lại Realme (bản `685a1ba6…`).** Lượt cuối Google viết *"MB Bank"* có dấu cách: *Chuyển ví · Ví MB Bank → Tiết kiệm · 500.000
đ*, ghi chú sạch. Dạng *mbbank* (bản `34637cf9…`): ví đúng; dạng *₫* chỉ kiểm bằng ca test nguyên văn.

---

### G102 — Giọng nói C4: lối Android tự dừng sau ~2 giây; lối Gemma đem bản ghi im lặng đi chép và điền câu lệnh vào ô · ✅ MỞ VÀ ĐÓNG 2026-10-21 tối (mã + test + kiểm lại Realme)

**Nguồn.** Nghiệm thu C4 lần đầu trên máy — Realme RMX2205CN (CPU), tài khoản 10, bản debug `bf988d6f…`. Bảng đo ở mục 9.1
`GIONG_NOI_FEATURE.md`.

**Lỗi 1 — lối Android (có mạng).** Người dùng báo *"thời gian chờ quá ngắn, nói cũng không thu được"*. Log dịch vụ
`com.google.android.tts`: bắt đầu thu 20:53:51,83 → **app** gọi `stopListening` 20:53:53,70 (*"mics audio processed in millis:
1720"*) → 0 giả thuyết → `NO_SPEECH_DETECTED`. Gốc (đọc mã `speech_to_text` 7.5.0, gói C4 đã được phép đọc): `listen` đặt
`_lastSpeechEventAt = _listenStartedAt` và chỉ đặt lại khi có chữ, tức `pauseFor` tính từ lúc **bắt đầu** nghe; mã đặt `pauseFor:
kImDeDung` (2 s). Lối Gemma có 6 s chờ tiếng đầu (`BoDoIm`), lối Android thì không.

**Lỗi 2 — lối Gemma (mất mạng).** Lượt người dùng chưa kịp đọc: `BoDoIm` dừng đúng ở giây 6 (bản ghi 5,9 s) nhưng `_dungGhi` vẫn
đưa bản ghi im lặng cho Gemma. Gemma trả **nguyên câu lệnh** bỏ dấu chấm cuối (88 ký tự), `lamSachLoiChep` nhận nó, ô Nhập nhanh
hiện *"Chép lại chính xác câu tiếng Việt trong đoạn ghi âm. Chỉ trả về câu ấy, không giải thích"*, rồi C2 tốn thêm ~10 s để báo
*"Mình chưa đọc được câu này"*.

**Sửa.**
- `NgheAndroidThat.nghe`: `pauseFor: kChoTiengDau`; chữ tạm khác rỗng đầu tiên → `changePauseFor(kImDeDung)`. ⚠️ Hàm ấy **ném**
  `ListenNotStartedException` khi gói không còn ở trạng thái nghe (mà `notListening` có thể tới trước chữ cuối) — bọc `try`, chữ
  luôn tới `LuotNghe`. `NgheAndroidThat` nhận `stt` tiêm được (test chạy gói thật qua kênh giả).
- `BoDoIm.daCoTieng`; bộ đo dừng mà chưa thấy tiếng → `_dungGhi(coTieng: false)`: xoá tệp, *"Không nghe rõ"*, không gọi Gemma.
  Bấm ■ thì vẫn chép (ngưỡng −35 dBFS chưa đo mọi máy).
- `lamSachLoiChep` trả rỗng khi lời chép chứa *"chép lại chính xác câu"* hoặc *"chỉ trả về câu ấy"* — lưới thứ hai.

**Test.** `nghe_android_test` 4 ca — hai ca đỏ trên mã cũ (chưa có chữ thì giây 3 vẫn nghe, tới giây 6 mới dừng; chữ tạm rỗng
không tính là đã nói), hai ca canh bản sửa (có chữ ở giây 1 → dừng ở giây 3; chữ tới sau `notListening` không mất), `nghe_giong_noi_cubit_test` +2 ca (6 s im → không chép; bấm ■ khi chưa thấy tiếng vẫn chép),
`chep_loi_test` +2 ca (năm dạng câu lệnh vọng lại; câu thật có chữ *"chép"* vẫn giữ). Năm bản sai cấy thử đều đỏ.

**Kiểm lại Realme (bản `de459fab…`).** Lối Android nghe trọn 6 s khi chưa có chữ; nói bằng giọng thật thì 4 câu đều ra chữ,
lượt dừng ~2 s sau chữ cuối (bảng ở mục 9.1 `GIONG_NOI_FEATURE.md`). ⚠️ Một lượt giữa chừng trả rỗng dù dịch vụ báo
`onStartOfSpeech` (SODA `SpeechError(-73542)`), cả Gboard cũng không nhận — tưởng là lỗi của máy, nhưng người dùng khi ấy cho
**Google Dịch phát câu từ chính chiếc Realme**. Lượt Gemma im lặng: ô trống, không lượt nạp / chép nào trong log.

**Ngoài phạm vi, ghi lại.** ColorOS (HANS) đóng băng `com.google.android.tts` ~8 s sau một lượt và chặn mạng của nó; một lượt
gọi vào lúc ấy không vào trạng thái nghe, kết thúc sau ~20 s với *"Không nghe được — thử lại sau"*.

---

### G101 — Quét ảnh (A5) điền sẵn số tiền SAI mà không hỏi khi OCR làm mất / đổi chữ số của dòng tổng · ✅ MỞ VÀ ĐÓNG 2026-10-21 (mở khi nghiệm thu A5 trên Realme; mã + test trên chữ `/quet` thật; nghiệm thu Realme Premium đạt cùng tối, đường Basic chưa nhìn trên máy)

**Nguồn.** Nghiệm thu A5 trên Realme RMX2205 (CPU, bản debug `b174b8d6…`, 2026-10-21), 15 ảnh hoá đơn R01–R16 của buổi
08/10 đi qua `/quet` thật. Hai tờ được **điền sẵn số sai, không chip**:

| Tờ | Đáp án | Chữ OCR hôm nay | Luật | Gemma CPU | Form |
|---|---|---|---|---|---|
| R13 MAXIDI | 72.127 | *"2,127"* (mất chữ 7) · *"VNO72,121"* | 2.127 | **72.127** (đúng) | **2.127 đ** điền sẵn |
| R08 MAXIDI | 75.700 | *"Teng 75,706"* · dòng VAT *"75,700"* | 75.706 | 55.000 | **75.706 đ** điền sẵn (lệch 6 đ) |

Cùng hai tờ ấy, chữ OCR lưu ở `hoa_don_that_du_lieu.dart` (đọc bằng màn spike 08/10) có đủ *"72.127"* / *"75,700"*. Khác ở
đầu vào: `/quet` đi qua `image_picker`, và gói này **nén lại** ảnh đã rộng 1280 (R08 98.970 → 83.192 byte, R13 99.043 → 82.676
byte), nên OCR chạy trên ảnh nén hai lần. Vì vậy `hoa_don_that_test` (*"13/15 điền sẵn, 2 tờ hỏi chip"* — nay 12/15 sau bản sửa) **không** phải phép
kiểm hồi quy của `/quet` trên các ảnh này — nó chạy trên chữ của đường spike.

**Cơ chế (đọc mã, `transaction/domain/chot_tong_quet.dart`).** Hai nửa:
1. **Số mô hình bị bỏ.** `chotTongQuet` chỉ dùng số AI khi nó có nguyên văn trong chữ OCR (`aiCo`), hoặc khác số luật **đúng
   một chữ số cùng độ dài** (`_lechMotChuSo`). R13: 72.127 không có trong chữ, và so với 2.127 là **thêm** một chữ số chứ không
   phải thay. R08: 55.000 không có trên ảnh và khác 75.706 ba chữ số. Lưới thứ hai được viết đúng cho R08 (chú thích mã nêu ca
   OnePlus *"OCR ra 75.706"*), nhưng chỉ đỡ được khi mô hình đọc đúng; Gemma CPU đọc 55.000.
2. **Số luật được điền vô điều kiện.** Số AI đã bị bỏ thì hàm trả `ChotTong(soTien: luat)`, không còn phép kiểm nào cho số luật.
   R13 điền 2.127 dù trên cùng tờ có món 19.800.

Thiết kế bỏ số AI có lý do đo được: hôm 08/10, 4/5 lần Gemma CPU sai là một số không in trên hoá đơn. *"Vẫn hiện chip"* cho mọi
số AI bị bỏ sẽ đưa lại đúng những số rác ấy, nên không phải hướng mặc định.

**Bán kính.** Mọi ảnh hoá đơn có OCR làm mất / đổi chữ số ở dòng tổng, trên cả Basic (chỉ luật) lẫn Premium. Form chỉ điền
sẵn, người dùng vẫn sửa được trước khi bấm Lưu (bất biến ④), nhưng số sai không có dấu hiệu gì. Câu *"không tờ nào điền sẵn số
sai"* của nghiệm thu OnePlus 08/10 **không** đúng cho Realme hôm nay.

**Bàn đo.** Chữ OCR mà `/quet` thật đã thấy hôm 21/10 có sẵn trong logcat (`[Quet][OCR]` in bằng `print`, không bị tiết
lưu): 16 lượt, chép nguyên văn, che số điện thoại / tên khách → `test/features/transaction/domain/hoa_don_quet_that_du_lieu.dart`.
Hai lượt quét lại R06 / R16 trùng từng byte nên bỏ. Phép kiểm chính dữ liệu ở `hoa_don_quet_that_test.dart`: luật trên chữ đã che
ra đúng dòng `[Quet][luat]` của logcat ở cả 16 tờ (tổng, ghi chú, ngày). Ca G101 đỏ đúng R08 + R13, cả Premium lẫn Basic.

**Hướng đã chọn (người dùng, 2026-10-21): ba lưới A + B + C** — đo cả ba ứng viên trên 34 tờ chữ (15 chữ 08/10 · 16 chữ
`/quet` 21/10 · 3 OnePlus), mỗi tờ chạy cả hai gói, rồi mới hỏi:

| Hướng | Tờ điền sẵn sai | Tờ đang điền đúng chuyển sang hỏi |
|---|---|---|
| Không sửa | 2 (R08, R13) | — |
| C | Premium 1 · Basic 2 | 0 |
| A + C | 1 (R08, lệch 6 đ) | 0 |
| **A + B + C** | **0** | 1 (R13 chữ 08/10) |

- **C** (`_lechMotChuSo`): số Gemma không in trên ảnh vẫn là ứng viên khi khác số luật đúng một chữ số — nay gồm cả **thêm /
  bớt** một chữ số (R13: 72.127 so với 2.127). Khác độ dài thì luôn lệch > 1%, nên lưới này chỉ đổi *"điền số luật"* thành *"hai
  chip"*, không bao giờ điền số Gemma.
- **A** (`_monLonNhatTrenTong`): số luật đứng một mình (không Gemma, hoặc Gemma bị bỏ) mà nhỏ hơn THÀNH TIỀN lớn nhất của các dòng
  phía trên dòng tổng → **ô trống**, toast *"Chưa đọc được số tiền"* (R13 Basic: 2.127, có món 19.800). Đọc thành tiền bằng
  `tienCuoiDong` (luật đọc món), không bằng `docMonHang` — hàm ấy dừng ở dòng tiêu đề cột *"Tổng"* của MAXIDI, trên mọi món. Bỏ
  dòng mang nhãn tổng (*"Thành tiền 246.000"* trước chiết khấu) và nhãn loại.
- **B** (`_soGanNhat`): số luật đứng một mình mà trên tờ có một số KHÁC lệch ≤ 1% → **hai chip** [số luật, số gần nhất] (R08:
  *Tổng 75,706* · dòng VAT *75,700*). Bỏ dòng nhãn loại (tiền mặt làm tròn *45.000* cho tổng 44.745) và ngày giờ (`tienTrenDongHoaDon`).
  Gemma trùng đúng số luật thì vẫn điền. Cái giá đã chấp nhận: R13 chữ 08/10 in tổng 72.127 và dòng tiền mặt OCR đọc 72,121 —
  luật đúng nhưng nay hỏi chip.
- **`/quet` chốt mọi hoá đơn** (`quet_anh_page.dart`): trước đây chỉ nhánh Premium gọi `chotTongQuet`, Basic điền thẳng số luật.
  Phần số tiền chỉ bật cờ *"Đọc bằng AI"* khi số Gemma nằm trên form (điền hoặc chip) — hai chip của hai số OCR không phải
  của AI. Danh mục do Gemma chọn vẫn bật cờ như cũ, nên ở Premium form thường vẫn nói *"Đọc bằng AI"* (ca widget canh cả hai).

Mười một bản sai cấy thử (bỏ từng lưới, bỏ từng vế loại trừ, so `<=`, xét số luật trước số Gemma, cờ AI theo *"có chip"*…) đều
bị ít nhất một ca bắt; bản *"so chuỗi con"* cho lưới C lọt ở lượt đầu, nên có thêm ca *OCR mất chữ số ở GIỮA*.

**✅ Nghiệm thu Realme RMX2205 (CPU, Premium — tài khoản 10), 2026-10-21 tối, bản debug `bf988d6f…` (`884a0c75`).** Chỉ đo lại
hai tờ chưa đạt, qua `/quet` thật: chép R08 / R13 từ `app_flutter/spike_c4/do1/` sang `Download/fmquet/`, chọn bằng trình chọn
ảnh. `image_picker` nén còn 83.192 / 82.676 byte; luật và Gemma ra đúng số của lượt trưa.

| Tờ | Luật | Gemma | Form lượt trưa (bản cũ) | Form bản sửa |
|---|---|---|---|---|
| R08 MAXIDI | 75.706 | 55.000 (không trên ảnh → bỏ) | điền 75.706 ❌ | **0 đ + hai chip 75.706 · 75.700** ✅ — chạm 75.700 điền đúng, ✓ lên thanh tiêu đề |
| R13 MAXIDI | 2.127 | 72.127 | điền 2.127 ❌ | **0 đ + hai chip 72.127 · 2.127** ✅ |

Dải nguồn vẫn *"Đọc bằng AI"* vì danh mục do Gemma chọn (đúng ghi chú ở trên). Lượt R08 thứ hai và thứ ba (khi đo G100) ra y
hệt. Không bấm Lưu (chốt cũ — tài khoản thật). **Đường Basic chưa nhìn trên máy** (khối chip không kèm chữ *"AI"* ở R08, ô trống
ở R13): cần OnePlus (tài khoản 18, Basic).

### G100 — Thoát app bằng Back (hoặc bị gỡ task) rồi mở lại, mô hình Gemma bị nạp THÊM một bản: tiến trình giữ hai bản, ~1,85 GB mỗi vòng · ✅ ĐÓNG 2026-10-21 (Back hai lần → xuống nền, nghiệm thu OnePlus GPU đạt; gỡ task khỏi Đa nhiệm khi đang giữ mô hình → đóng hẳn tiến trình, nghiệm thu Realme CPU đạt)

**Nguồn.** Realme RMX2205 (CPU), 2026-10-21. Trong buổi đo A5, Flutter engine được dựng lại **ba lần** trong cùng tiến trình
14156 (14:00:30 · 14:00:53 · 14:02:10, lúc task bị đóng rồi mở lại). Mỗi lần có một dòng *Impeller* mới, các bộ đếm
`RealtimeChannel` làm lại từ đầu, và màn khởi động hiện lên. Lượt quét kế tiếp ghi `[SLM] nạp mô hình xong` lần nữa. Dựng lại
có kiểm soát (14:24–14:26, tiến trình 29255): Back ở Trang chủ (app thoát, tiến trình **sống**) → `am start` → quét một tờ.

| Thời điểm | Native Heap (cấp phát) | PSS |
|---|---|---|
| Tiến trình mới, chưa nạp | 68 MB | 467 MB |
| Sau lượt quét đầu (một bản mô hình) | **1,89 GB** | 3,04 GB |
| Sau Back thoát app | 1,86 GB (không trả) | — |
| Mở lại + quét một tờ | **3,72 GB** | **4,9 GB** (swap 2,0 GB) |

Lần dựng lại do task bị đóng cho cùng con số (3,73 GB, PSS 5,0 GB, swap 3,4 GB).

**Cơ chế (đọc mã + số đo).** Bản mô hình gắn với Dart isolate của engine (`SlmRuntime._model`, `slm_runtime.dart`). Mô hình chỉ
đóng qua `SlmRuntime.dong()` khi app chủ động đổi bản nạp; `lib/` **không** có chỗ nào nghe `AppLifecycleState.detached`. Khi
engine bị huỷ mà tiến trình còn sống (dịch vụ nghe thông báo D1 giữ nó, Realme ColorOS), bộ nhớ native của bản cũ không ai giải
phóng. Isolate mới không biết bản ấy và nạp bản thứ hai.

**Gốc trong gói (đọc mã `flutter_gemma_litertlm` 1.8.0, phép đích danh 2026-09-23).** `litert_lm_client.dart:852-878` tạo engine
native trong một `Isolate.run` tạm và chỉ trả **địa chỉ** con trỏ; địa chỉ ấy nằm trong trường `_engine` của một đối tượng Dart.
Engine chỉ được giải phóng qua `shutdown()` → `litert_lm_engine_delete` (`:1827`). Thư mục `ffi/` không có `NativeFinalizer`
nào. Isolate chết mà chưa ai gọi `close()` thì địa chỉ mất theo, và engine (trọng số, KV cache, luồng) nằm lại tới hết đời tiến
trình; isolate mới không có cách tìm lại nó.

**Bán kính.** Mọi đường nạp mô hình: Trợ lý AI, Nhập nhanh (C2), lệnh tạo (C3), giọng nói (C4), Quét ảnh (A5). Điều kiện:
engine được dựng lại khi tiến trình còn sống, do Back thoát app hoặc gỡ task khỏi Recents. Hai vòng là tiến trình đã 4,9 GB;
chưa đo vòng ba (khả năng bị hệ điều hành giết vì hết bộ nhớ).

**Hướng (người dùng chọn 2026-10-21, trong bốn lối: xuống nền · một engine cho cả tiến trình · đóng mô hình khi thoát · để
sau).** *Back hai lần ở Trang chủ = đưa app xuống nền*. Lối *đóng mô hình khi thoát* bị loại vì đụng chốt 4b
`QUET_ANH_FEATURE.md`: OnePlus GPU **sập native** ở lần **đóng thứ hai** trong một tiến trình (`gl_release_context` ←
`LiteRtDestroyEnvironment`), và isolate mới lại có bộ đếm lần đóng mới. Lối *một engine cho cả tiến trình*
(`FlutterEngineCache`) phủ được cả đường gỡ task, nhưng đụng `TuChuyenTien` gắn / gỡ engine, deeplink thông báo, đăng ký plugin.

**Đã sửa (đường Back).** `ThoatHaiLan` (`shared/widgets/thoat_hai_lan.dart`): lần nhấn thứ hai gọi kênh `flowmoney/xuong_nen`
→ `MainActivity.kt` `moveTaskToBack(true)` (activity và Flutter engine sống tiếp). Kênh trả `false`, không có kênh, hoặc lỗi thì
rơi về `SystemNavigator.pop()` như cũ. Không có lần đóng mô hình nào, nên an toàn với GPU. Hệ quả cố ý: Back hai lần nay
**giống hệt nút Home**, nên đường khởi động lạnh (G86 `AuthCheckRequested` → `verifySession`, lượt quét đầu của
`moPhienCucBo`, phép kiểm `CanaryCongCu` qua `ApplicationExitInfo` ở `main.dart`) chỉ chạy lại sau khi tiến trình chết thật; mở
lại sau Back là `resumed`, như mở lại sau Home. Test: `thoat_hai_lan_test.dart` (ca
*"⚠️ G100"* đỏ trên mã cũ — không có lời gọi `xuongNen`; hai ca rơi về `pop` khi kênh trả `false` / không có kênh; một ca nối dây
đọc `MainActivity.kt`) và `main_shell_back_test.dart` (ca Back hai lần đòi `xuongNen`, không `pop`; `daGoiThoat()` tính **cả
hai** đường thoát để ca *"không thoát"* không xanh oan).

**✅ Nghiệm thu OnePlus 13R (GPU), 2026-10-21, trên cùng máy, trước và sau.** Tài khoản 18 được nâng tạm lên Premium trong CSDL
dev (người dùng cho phép đích danh) rồi trả về Basic / `NULL` sau khi đo. Mỗi lượt: Nhập nhanh *"mua qua sinh nhat me 250k"* để
nạp mô hình → Back hai lần ở Trang chủ → mở lại → Nhập nhanh lần nữa.

| Bản | Sau lần nạp đầu (Native · Graphics · PSS) | Sau Back hai lần | Mở lại + Nhập nhanh |
|---|---|---|---|
| Cũ (2026-10-20) | 420 MB · 184 MB · 1,04 GB | activity **bị huỷ**, tiến trình sống | engine dựng lại, **nạp lại** mô hình → **799 MB · 363 MB · 1,78 GB** |
| Mới (`a43be813…`) | 420 MB · 183 MB · 1,28 GB | `MainActivity` **còn** trong task | không *Impeller* mới, **không nạp lại** → 423 MB · 185 MB · 1,25 GB; câu đọc bằng AI bình thường |

Trên GPU mỗi vòng của bản cũ mất ~0,75 GB (CPU Realme ~1,85 GB): cùng cơ chế, phần trọng số nằm ở *Graphics*.

**Đã sửa (đường gỡ task, 2026-10-21 tối — người dùng chọn lối *đóng hẳn tiến trình*, trong ba lối: đóng hẳn · một engine cho
cả tiến trình · để nguyên).** Đo trước trên bản `bf988d6f…` (mới có sửa đường Back), Realme CPU, tài khoản 10:
- Gỡ task → tiến trình 32272 **vẫn sống**, Native giữ 1,86 GB. Mở lại → cùng tiến trình có dòng *Impeller* mới và `main()` chạy
  lại (engine dựng lại). Quét một tờ → `[SLM] nạp mô hình xong` lần hai, Native **3,71 GB**, PSS 4,80 GB, swap 2,78 GB.
- `am crash` tiến trình đang giữ dịch vụ D1 → ColorOS dựng lại tiến trình cho `BienDongListenerService` sau ~2 s. Tức đóng hẳn
  tiến trình không làm mất đọc biến động.

Mã:
- `BoNapMoHinh.baoGiu` báo `true` sau khi `nap` xong, `false` sau `dong`. Chỉ báo `true` khi nạp đã XONG (sau khi canary GPU gỡ
  dấu): giết giữa pha nạp là để dấu sót, và lần mở sau đánh dấu GPU hỏng vĩnh viễn.
- `SlmRuntimeThat.baoGiuMoHinh` ← DI `const KenhGiuMoHinh().dat` (`ai_edge/data/datasources/kenh_giu_mo_hinh.dart`, kênh
  `flowmoney/giu_mo_hinh`, `datGiu {giu}`, nuốt lỗi).
- `MainActivity.onDestroy`: `!isChangingConfigurations && soActivitySong <= 0 && dangGiuMoHinh` → `Process.killProcess(myPid())`
  **sau** `super.onDestroy()`. Cờ và bộ đếm activity ở `companion object` (sống theo tiến trình).

Người dùng không thấy gì khác: trước bản sửa, mở lại sau khi gỡ task **đã** là dựng lại engine (màn khởi động → Trang chủ); nay
là khởi động trong tiến trình mới. Chưa dùng AI thì không giết. Không đụng: canary phiên có tool (giết chủ động không phải
`CRASH_NATIVE`); `TuChuyenTien` (lượt nền đang dở bị giết thì WorkManager chạy lại, id tất định chống trùng); đường Back hai lần
(không huỷ activity). Còn một khe hẹp, cố ý: gỡ task **giữa pha nạp** (cờ chưa bật) thì vẫn rò như cũ — giết lúc ấy hỏng canary
GPU.

Test: `bo_nap_mo_hinh_test` +5 ca (nạp xong → `true`; đổi bản → `false` rồi `true`; ⭐ đang nạp chưa báo; nạp ném lỗi không báo;
huỷ giữa pha nạp vẫn báo `true`); `kenh_giu_mo_hinh_test` 5 ca (kênh gửi đúng thứ tự; không kênh / native lỗi không ném; nối dây
Kotlin — đủ ba vế điều kiện, giết sau `super.onDestroy()`; nối dây DI). Bốn bản sai cấy thử (báo `true` trước khi nạp, bỏ báo
`false`, DI không nối kênh, Kotlin bỏ vế `dangGiuMoHinh`) đều đỏ.

**✅ Nghiệm thu Realme RMX2205 (CPU), 2026-10-21 tối, bản debug `9792b5c3…`, tài khoản 10.**

| Ca | Kết quả |
|---|---|
| Chưa dùng AI → gỡ task | tiến trình 10784 giữ nguyên, không có dòng giết ✅ |
| Quét R08 (nạp mô hình, Native 1,91 GB) → Back hai lần ở Trang chủ | về màn chính, `MainActivity` còn trong task, tiến trình giữ nguyên ✅ |
| → gỡ task | dòng `G100: … đóng hẳn tiến trình` 20:08:57,99 → 10784 chết 58,55 → **13926** dựng cho `BienDongListenerService` 59,64 (`crashCount=0`), PSS 54 MB; listener gắn lại với hệ thống thông báo ✅ |
| Mở lại → quét R08 | nạp **một** bản: Native **1,90 GB** (trước bản sửa: 3,71 GB), PSS 3,04 GB ✅ |
| Gỡ task lần hai | 13926 → giết → 14836, PSS 56 MB ✅ |

Chưa đo: OnePlus GPU (giết tiến trình giải phóng cả ngữ cảnh GPU, không đi qua `LiteRtDestroyEnvironment`); vuốt đi nhiều lần
liên tiếp trong thời gian ngắn — hai lần giết đo được đều dựng lại dịch vụ D1 sau ~1 s, nhưng Android giãn dần thời gian khởi
động lại dịch vụ khi nó chết dồn dập.

---

### G99 — Lệnh tạo mục tiêu nhận hạn mô hình bịa khi câu chỉ nêu mốc BẮT ĐẦU (*"kể từ tháng sau…"*) · ✅ MỞ VÀ ĐÓNG 2026-10-20 (lộ khi đo G95 trên Realme; mã + test + đo lại Realme đạt)

**Nguồn.** Đo G95 trên Realme RMX2205 (CPU, bản debug `7c0fe632…`, 2026-10-20 19:21, gõ không dấu qua adb, **không** mở form).
Câu *"ke tu thang sau de danh 2 trieu moi thang"* lọt cổng đúng như mong đợi. Log: `[SLM][lenh] 15614 ms: tao_muc_tieu {ten:
tiết kiệm, so_tien_dich: 2000000, han: 30/06/2027}`. Thẻ hiện ra:
- *"Đọc bằng AI · Tạo mục tiêu · hạn 30/06/2027 · Chưa rõ tên, số tiền"*.
- Tên và số tiền bị lưới bỏ **đúng luật**: *tiết kiệm* không có trong câu; *2 triệu mỗi tháng* là mức góp theo kỳ.
- **Hạn thì lọt.** Câu không nêu hạn nào: *"kể từ tháng sau"* là mốc **bắt đầu**.

**Cơ chế (đọc mã).** `_hanAiHopLe` (`ai_edge/domain/lenh_tao.dart`) nhận hạn mô hình khi `_cauNoiThoiGian` đúng, tức câu có
**một chữ chỉ thời gian bất kỳ** sau khi gạt cụm chu kỳ (*mỗi tháng · hằng tuần · /tháng*). *tháng* của *"tháng sau"* là đủ, dù
nó đứng sau *kể từ*. Cùng họ với chốt 2026-10-02 (cụm chu kỳ không phải thời điểm, mục 9.43 `AI_EDGE_FEATURE.md`), và với bẫy
*"mô hình hay điền thừa"*.

**Bán kính.** Chỉ ô *hạn* của lệnh tạo mục tiêu, khi câu nêu mốc bắt đầu mà không nêu hạn. Thẻ chỉ điền sẵn form; người dùng vẫn
thấy và sửa được hạn trước khi bấm Lưu (bất biến ④). **Có từ trước G95**: cổng cũ cũng mở cho câu này (có *để dành* + số tiền),
nên thẻ y hệt.

**Hướng (người dùng chọn *"sửa rồi đo lại"*, 2026-10-20).** Gạt thêm cụm **mốc bắt đầu** khỏi câu trước khi xét
`_cauNoiThoiGian`, cùng khuôn `_mauCumChuKy`.

**Đã sửa.** Thêm regex `_mauMocBatDau` (`lenh_tao.dart`), gạt khỏi câu sau cụm chu kỳ. Cấu trúc một cụm mốc bắt đầu:
1. Mở bằng *kể từ · bắt đầu từ · bắt đầu · từ*, hoặc dạng không dấu.
2. Có thể có *đầu / cuối*.
3. Một đơn vị: *tuần · tháng · quý · năm · ngày*.
4. Một mốc: *sau · tới · này*, hoặc số / ngày `1/11`.
5. Có thể có đuôi *năm sau / năm 2027*.

`tu` trần chỉ khớp khi ngay sau là đơn vị + mốc, nên *tư / tự* không vướng. Câu vẫn còn chữ thời gian ngoài mốc bắt đầu
(*"từ tháng sau để dành 10 triệu đi du lịch trước tết"*) thì vẫn nhận hạn.

**Test** (`lenh_tao_test.dart`, ca *"⚠️ G99"*):
- 8 câu mốc bắt đầu (gồm nguyên văn câu đo, *bắt đầu từ tuần sau* có chữ *đầu*, *từ ngày 1/11* có dấu `/`, *tháng 11 năm sau*):
  đỏ 8 / 8 trên mã cũ.
- 2 câu vẫn nhận hạn.
- Bản sai bỏ vế đuôi *năm sau* làm ca đỏ.

**✅ Đo lại Realme RMX2205 (bản debug `b174b8d6…`, 2026-10-20 19:30):** cùng câu, mô hình vẫn trả `han: 30/06/2027`. Thẻ nay
ghi *"Đọc bằng luật · Tạo mục tiêu · Chưa rõ tên, số tiền, hạn"*: hạn bịa bị bỏ. Dòng nguồn thành *"Đọc bằng luật"* vì không
còn ô nào do AI lấp (đúng luật *"dòng nguồn nói thứ đã xảy ra"*).

### G98 — Bản ghi server tạo với id KHÔNG phải UUID không bao giờ đẩy lên được (`toValidUuid` đổi id → server `create` → trùng tên với chính nó), và một hàng kẹt kéo giãn cách đồng bộ của cả tài khoản lên 15 phút · ⏳ CHỜ BACKEND — đơn 48 (mở 2026-10-20 khi nghiệm thu G89; người dùng chốt hướng cùng ngày)

**Nguồn.** Nghiệm thu G89 trên OnePlus 13R (2026-10-20), người dùng hỏi kèm *"có dữ liệu nào chưa được đồng bộ không"*. Đọc
CSDL chép từ máy (tài khoản 18): **một** hàng chưa đồng bộ — ví *"Ví Test Note"* `test-wallet-1789014227658`, `pending`,
`sync_error` *"Tên ví đã tồn tại trong tài khoản này"*, cờ `bi_tu_choi_trung_ten = 1`; mọi hàng khác `synced`. Server (truy vấn
đọc) có **đúng một** ví cùng id, cùng tên (`Create_at` 2026-09-10 04:23Z) cùng 9 giao dịch `test-tran-note-*` ghi chú `enc:…` —
một test backend chèn thẳng vào CSDL dev; đó cũng là dòng `enc:01a5ca71610…` hiện thô ở Trang chủ.

**Cơ chế (đọc mã + log backend).** `ThuGomThaoTacDay.collectPendingOps` đặt `id = toValidUuid(w.id)` (`core/sync/uuid_dong_bo.dart`)
— id không phải UUID thành `00000000-0000-4000-8000-…`. Server (`sync.repository.js`, nhánh ví) `findUnique({idwallet})` không
thấy id giả → `prisma.wallet.create` → `Unique constraint failed on the fields: (Idaccount, Name)` với **chính bản ghi gốc** →
`sync.service.js` dịch thành `WALLET_NAME_DUPLICATE`. Rồi G63 quay vòng: `ViTrungTenResolver` gắn cờ; trên máy không có ví nào
khác cùng tên nên `ThaViBiGiu` thả và làm mới giờ sửa; lượt sau đẩy lại. Log backend: hỏng lúc 15:59:39, 16:00:13, 16:01:18, 16:08:26.

**Hỏng thế nào (đo).** Chu kỳ có hàng này hỏng vĩnh viễn được tính là **chu kỳ hỏng** kể cả khi phần còn lại đẩy được — lượt
16:08:26 *"2/4 succeeded, 1 failed"* rồi *"giãn cách sau 4 chu kỳ hỏng — hoãn tới 16:23:29"*: mọi dữ liệu mới của tài khoản chờ
tới **15 phút** (chu kỳ bị máy chủ chặn của G89 thì không tính). Ví test 300.000 đ còn nằm trong tổng số dư Trang chủ. Đếm lượt
hỏng như thế là cố ý hay không thì chưa xét; người dùng không chọn hướng (d) ở dưới.

**Vì sao ví chuyển `pending` lần đầu.** Kết luận đọc mã ngày 2026-10-20, chưa đo trên máy:
1. Nhánh kéo về không chép `balance`, nên ví mới về mang 0 (nghĩa là *chưa biết*).
2. `SoDuViService.tinhLaiSoDu` (`so_du_vi_service.dart:55–56`) tính được 300.000 (2 giao dịch sống × 150.000), khác 0, nên
   gọi `WalletDao.updateBalance`.
3. Hàm ấy (`wallet_dao.dart:249–257`) ghi `syncStatus = 'pending'`.

Ví UUID cũng đi đường này rồi đẩy lên trơn tru. Còn ví này thì **mọi máy đăng nhập tài khoản 18 đều kẹt ngay sau lần kéo về
đầu**, không cần ai bấm gì.

**Nguồn dữ liệu** (đọc mã + CSDL dev, 2026-10-20): ca 11 của `Test/test_data_security_encryption_and_masking.js:236–282`
(NPBao, commit `b147feeb`).
- Script chọn tài khoản bằng `findFirst({ status: 'Active' })` **không** `orderBy`. Ngày 2026-09-10 nó trúng 18; hôm nay trả 82.
- Tài khoản chưa có ví sống thì tạo ví `'test-wallet-' + Date.now()` thẳng bằng Prisma, và không bao giờ dọn ví ấy.
- Mỗi lượt thêm một giao dịch 150.000 đ, chỉ xoá mềm khi mọi `assert` qua. 9 lượt chạy (10/09 → 11/09) để lại 2 giao dịch sống.

Không phải do client test. Lượt nghiệm thu G89 chỉ làm hàng kẹt lộ ra.

**Bán kính (đo toàn CSDL dev 2026-10-20, chỉ đọc).** Hàng có id không phải UUID: `wallet` 1, `transaction` 9 — **tất cả** của
tài khoản 18, tiền tố `test-`; `category` · `bill` · `goal` · `budget` 0. Client luôn tạo UUID, nên người dùng thật không gặp —
chỉ dữ liệu chèn thẳng vào CSDL.

**Hướng — người dùng chốt (b) + (c) ngày 2026-10-20 → đơn 48** (`CAN-LAM/LICH-SU/DU_LIEU_TEST_TRONG_TAI_KHOAN_THAT.md`). Client **không**
đổi mã. Bốn hướng đã trình:
- (a) client không đổi id của bản ghi **đến từ server**. Đụng 18 chỗ gọi `toValidUuid` ở `thu_gom_day.dart` (đếm bằng máy
  2026-10-20), kể cả khoá ngoại `walletId` của giao dịch; cần spec nhỏ.
- (b) backend xoá mềm dữ liệu test.
- (c) script test thôi ghi vào tài khoản dev thật.
- (d) xét lại việc một hàng hỏng vĩnh viễn làm giãn cách cả tài khoản.

Ba điều đọc mã + CSDL được ghi vào đơn:
1. **Xoá ví trong app không gỡ được kẹt.** Nhánh `create` của `upsertWallet` (`sync.repository.js:244–261`) **không** ghi
   `delete_at`, nên lượt đẩy id giả của một ví đã xoá vẫn tạo ví **sống**, rồi vẫn trùng tên. Câu *"(b) chưa đo"* cũ đã có lời
   đáp từ đây.
2. **Xoá ở server sẽ đẻ một ví "ma".** `uq_wallet_account_name_active` chỉ xét `WHERE "Delete_at" IS NULL`. Vậy sau khi server
   xoá mềm ví gốc, máy đang kẹt (đẩy trước, kéo sau) tạo thành công ví **sống** `00000000-0000-4000-8000-4534d71cc54d` (id giả
   tất định, mọi máy cho cùng một id; 300.000 đ trên server, 0 đ trên máy). Đơn có bước 3 để xoá mềm ví ấy; người dùng cũng có
   thể tự xoá trong app.
3. `Server_update_at` tự cập nhật qua trigger `BEFORE UPDATE`, nên xoá mềm bằng `UPDATE` là đủ để `/sync/pull` thấy.

**Đóng khi:** backend báo xong đơn 48, client đo trên OnePlus thấy đủ ba điều: *"Ví Test Note"* biến mất (cả ví gốc lẫn ví ma),
tổng số dư giảm 300.000 đ, và không còn hàng `pending`.

### G97 — Body lỗi không phải JSON (trang HTML của proxy) làm màn Đăng nhập in nguyên câu `TypeError` · ✅ MỞ VÀ ĐÓNG 2026-10-20

**Nguồn.** Review toàn nhánh G89 (2026-10-20) ghi *ngoài phạm vi, có từ trước*: `auth_remote_data_source.dart` đọc
`e.response?.data?['message']`. Dio chỉ giải mã JSON khi `content-type` là JSON; trang HTML của proxy / Render (502 lúc dịch vụ
ngủ, 404 khi không thấy dịch vụ), câu thuần chữ — `data` là `String`, và `String['message']` là `String[]` với khoá chuỗi →
`TypeError` *"type 'String' is not a subtype of type 'int' of 'index'"*. `AuthBloc._onLoginSubmitted` bắt bằng `catch (e)` nên app
không văng, nhưng **câu ấy hiện nguyên văn trên màn Đăng nhập** (cùng các màn Quên mật khẩu, OTP, Đổi mật khẩu, Hồ sơ…). Nhánh
2xx cùng bệnh: `response.data['success'] == true` trên body chuỗi ném trước cả `catch` của Dio. Đo bằng test trên mã cũ: **26 / 26**
lời gọi (13 nhánh lỗi + 12 nhánh 2xx + `getProfile` 404) ném `TypeError`; backend tự trả JSON ở mọi chỗ đã đọc (kể cả
`authLimiter` — `message` là object), nên chỉ thấy khi có tầng đứng giữa.

**Sửa (cùng gốc, cùng tệp — 14 lời gọi).** Hai hàm ở cuối tệp: `_cauLoi(body, macDinh)` — `message` chỉ khi body là `Map` và
`message` là chuỗi có chữ, còn lại câu mặc định của lời gọi (mảng / số / chuỗi rỗng cũng về câu mặc định thay vì in thô);
`_thanhCong(body)` — `body is Map && body['success'] == true`. Không còn chỗ nào đọc `data['message']` / `data['success']` thẳng.
⚠️ **`getProfile` chỉ giữ `statusCode` khi body là JSON của backend**: `verifySession` đọc 401 / 404 là phiên chết → đăng xuất,
mà trang 404 HTML của proxy không nói gì về tài khoản — trên mã cũ ca ấy tình cờ ra `SessionStatus.unknown` nhờ chính
`TypeError`, nên sửa mà quên vế này là **đăng xuất người dùng vì proxy** (bản sai cố ý đã thử: ca đỏ). Test
`test/features/auth/data/datasources/auth_remote_data_source_body_khong_json_test.dart` (30 ca, bảng phủ đủ 14 lời gọi — thêm lời
gọi mới vào datasource thì ca đếm bảng đỏ).

**Bán kính.** Chỉ `AuthRemoteDataSourceImpl`; câu người dùng thấy khi body là JSON của backend không đổi (`auth_remote_data_source_dang_nhap_test.dart`
xanh nguyên). Các datasource khác đã đọc qua `is Map` (`buoc_dang_xuat.dart`, `trang_thai_may_chu.dart`, `payment_api.dart`) —
lượt `grep` 2026-10-20 không còn khuôn `data?['message']` nào trong `lib/`.

### G96 — Đường Trợ lý online phụ thuộc ba việc backend: Dừng không tới server, server im lặng quá 45 s khi Gemini suy nghĩ, câu trả lời cụt vì trần token · ⏳ CHỜ BACKEND (đơn 47 việc 5–7; mở 2026-10-18 sau nghiệm thu OnePlus)

**Nguồn.** Nghiệm thu máy thật 2026-10-18 00:08–00:40 (OnePlus 13R, backend dev chạy thật, Node v22.19.0, `gemini-3.8-flash`
với khoá dev) — khối 🌐 mục 14 `PROJECT_CONTEXT.md`, spec §6, đơn 47 (`CAN-LAM/CLIENT_TRO_LY_ONLINE.md`, phần *đo 2026-10-18*).

**Ba hiện tượng người dùng thấy, cả ba do backend:**

1. **Dừng không làm server dừng.** Bấm *Dừng* → client đóng socket thật (số kết nối ESTABLISHED tới cổng 3000 trên host 4 → 2
   trong 1 s), màn về trạng thái đúng (không bong bóng, không hàng chờ), nhưng backend không ghi dòng ngắt kết nối nào và vẫn
   *"Hoàn tất phiên chat streaming trong 14590ms"* 12 s sau — `req.on('close')` không nổ trên Node 22. Token Gemini bị đốt, kết
   quả vứt. Client **đúng** theo spec (tiêu chí ca 5 của client là giữ chữ + nhãn *đã dừng*); đơn 47 việc 5.
2. **Câu suy nghĩ lâu rơi về máy ở giây 45.** Mô hình có bước suy nghĩ; sau `meta` server im lặng hoàn toàn — đo 49,9 s, một lượt
   curl 91 s. `receiveTimeout` 45 s của client nổ → *"AI trên máy · máy chủ không phản hồi"* trong khi server vẫn chạy tới cùng.
   Người dùng chốt 2026-10-18 **giữ 45 s** (không có cách phân biệt *đang nghĩ* với *máy chủ chết*) và xin backend keep-alive
   `: ping` (đơn 47 việc 6; bộ tách SSE của client đã bỏ qua dòng `:`, không cần đổi client).
   ✅ **2026-10-26:** backend đã gửi `: ping` mỗi 15 s (`chatbot.controller.js:32`, soát phiên 12) — câu nghĩ lâu không còn rơi ở giây 45.
   Hệ quả: `receiveTimeout` không bao giờ nổ khi server còn sống, mà server không có trần cho lời gọi Gemini ⇒ Gemini treo là vòng
   xoay quay mãi. Phiên 13 client thêm **trần tổng 120 s** (`kTranTongOnline`, người dùng chốt; vượt ca 91 s đã đo): quá trần huỷ request
   và rơi về máy. Vế này đóng phía client; server vẫn chạy Gemini tới cùng (vế 1).
3. **Câu trả lời cụt ở điểm ngẫu nhiên** (172 ký tự · 1.851 ký tự dừng ở *"Bước 4"* của 12 bước · chỉ còn câu mở đầu) vì
   `maxOutputTokens: 1024` gồm cả token suy nghĩ; server kết `done {}` bình thường nên client hiện phần cụt với nhãn *Trợ lý
   online*, không cảnh báo — đúng hợp đồng. Đơn 47 việc 7 (nâng trần / giới hạn suy nghĩ; cân nhắc `finishReason` trong `done` —
   có thì client mới hiện được ghi chú *bị cắt*, việc ấy sẽ cần spec riêng).

**Bán kính.** Chỉ màn Trợ lý AI khi online bật. Không đổi mã client cho tới khi backend trả lời; khi có `finishReason` thì mở một
lát nhỏ ở `quyetDinhSauOnline` / `NhanNguon` (ghi chú mới) — chưa làm.

### G95 — Cổng lệnh tạo C3 bắt nhầm câu hỏi dạng *"Hãy viết 15 lời khuyên tiết kiệm tiền…"*: Gemma đọc lệnh ~5 s rồi câu mới đi online · ✅ ĐÓNG 2026-10-20 (mở 2026-10-18 khi nghiệm thu OnePlus; đóng bằng mã + test, đo Realme đạt cùng ngày)

**Nguồn.** Nghiệm thu 2026-10-18 00:19: câu *"Hay viet 15 loi khuyen tiet kiem tien cho sinh vien, moi loi khuyen 2 cau giai
thich"* (online bật, có mạng) hiện *"Đang đọc lệnh bằng AI… Huỷ"* trước — `coVeLenhTao` (cổng C3, chạy TRƯỚC cổng online theo
§3.1) đoán là lệnh tạo mục tiêu (có *tiết kiệm* + số), Gemma đọc tham số (`[SLM][tool] goi_y_han_muc {danh_muc: học phí}` → từ
chối) rồi câu mới đi online. Người dùng chờ thêm ~5 s và thấy một hàng chờ sai nghĩa; không mất dữ liệu.

**Vì sao chưa sửa.** Luật `coVeLenhTao` thuộc lát C3 (2026-10-04) với bộ đo riêng; nới nó (vd. loại câu bắt đầu bằng *hãy viết /
liệt kê / kể*, hay câu có *mỗi … câu*) là đổi hành vi đã đo trên hai máy — cần đo lại bộ câu C3 trước. Spec trợ lý online §3.1 cố ý
đặt C3 trước online nên lát này không chạm.

**Hướng sửa (bản viết 2026-10-18).** Thêm vế loại trừ trong `coVeLenhTao` cho câu hỏi tri thức (động từ yêu cầu viết / liệt kê +
số đếm lớn + không có số tiền), kèm ca test và chạy lại bộ đo C3 (`docs/AI_EDGE_FEATURE.md` mục 9.4x). Nhỏ, nhưng là lát riêng.

**Đã sửa (2026-10-20).** Gốc lỗi đọc mã:
- Câu không theo mẫu §2, không có từ hỏi.
- Có *tiết kiệm* (một đối tượng tạo được).
- `cachDocSoTien` đọc số đếm *15* thành 15.000 đ (luật số trần 10–999 × 1.000 của Nhập nhanh), nên vế *"có số tiền đọc được"* đúng.

Vế loại trừ mới, `_moBangXinVietChu` (`lenh_tao.dart`): câu mở bằng động từ **xin viết chữ** thì cổng đóng.
- Động từ được tính: *viết · liệt kê · kể · soạn · giải thích · tóm tắt · gợi ý · phân tích*. Chúng đứng sau tiền tố lịch sự
  (`_sauTienTo`, tách từ `_nhan`), có thể kèm *bạn*.

**Hai chỗ khác bản viết, cố ý:**
- Không xét *"số đếm lớn"* hay *"không có số tiền"*. Câu xin viết chữ có kèm số tiền (*"viết kế hoạch tiết kiệm 5 triệu…"*) vẫn
  là xin một đoạn chữ; mở thẻ form tạo mục tiêu cho nó là trả lời sai câu.
- Luật theo **động từ**, không theo danh từ đếm, vì không lệnh tạo nào mở đầu như thế. `cachDocSoTien` không đổi, nên Nhập nhanh
  không bị ảnh hưởng.

⚠️ `ke` là âm tiết duy nhất trong danh sách không chỉ là động từ: bỏ dấu nó còn là *kế* (*"kế hoạch…"*), và *kể từ* / *kể cả*
là liên từ (*"kể từ tháng sau để dành 2 triệu"*). Cả ba mở đầu được lệnh tạo, nên `ke` theo sau bởi `hoach` · `tu` · `ca` vẫn
lọt cổng. Vế *kể từ / kể cả* do lượt soát sau bản đầu bắt: bản đầu chỉ chừa *kế hoạch*.

**Giới hạn, cố ý.** Luật chỉ bắt động từ ở **vị trí đầu** (sau tiền tố lịch sự + *bạn*). *"bạn có thể gợi ý…"*, *"bạn ơi hãy
viết…"* chưa bắt. Thêm khi có câu đo thật, vì mỗi luật từ vựng là một dương tính giả mới.

**Test** ở `test/features/ai_edge/domain/lenh_tao_test.dart`:
- 8 ca *"G95 không lọt"* (gồm nguyên văn câu đo), đỏ 8 / 8 trên mã cũ.
- 1 ca *"kế hoạch …"*: bản sai bỏ chặn `ke hoach` làm nó đỏ.
- 1 ca *"kể từ … / kể cả …"* (ba câu): đỏ trên bản đầu, và bản sai rút tập chặn về `{'hoach'}` làm nó đỏ.
- 1 ca ⭐ khoá đúng **10 câu C3 đã đo** trên Realme + OnePlus (mục 9.43), dạng gõ không dấu như lúc đo: bản sai thêm `toi` vào
  danh sách làm nó đỏ.

**Bộ đo C3 không đo lại trên máy.** Cổng là hàm luật thuần; 10 câu đã đo và 72 câu cổng F đều có ca canh; phần mô hình đọc
lệnh không đổi.

**✅ Đo trên Realme RMX2205 (CPU, bản debug `7c0fe632…`, 2026-10-20 19:19–19:21, gõ không dấu qua adb).**

| Câu | Mong đợi | Hiện ra | |
|---|---|---|---|
| hay viet 15 loi khuyen tiet kiem tien cho sinh vien | cổng **đóng** | Khung ≈0,5 s **không** có *"Đang đọc lệnh bằng AI…"*. Log `định tuyến: không … mở phiên … 6 tool`, không dòng `lệnh tạo` → vòng hỏi đáp, *"Đang nghĩ…"*. Mô hình không gọi tool nên rơi L1 sau 41 s: *"Mình chưa chắc về con số cho câu này…"*. Đó là hành vi trên máy của câu tri thức chung khi không có đường online, ngoài phạm vi G95. | ✅ |
| ke tu thang sau de danh 2 trieu moi thang | cổng **mở** | *"Đang đọc lệnh bằng AI… Huỷ"* → thẻ *"Tạo mục tiêu"* + *Mở form tạo mục tiêu* sau 15,6 s (`lệnh tạo LenhTaoMucTieu nguồn ai → form`). | ✅ (hạn bịa → **G99**) |

Hộp đồng ý *"Trợ lý online"* hiện lần đầu trên máy này; Claude chọn **"Chỉ dùng AI trên máy"** (không gửi gì ra ngoài; backend dev
đang tắt). Đổi lại được ở Cài đặt AI.

### G94 — Chuyển thừa / thiếu tiền khi nâng Premium: client không biết ba trạng thái đơn mới, màn chờ báo "hết hạn" · 🚧 MÃ XONG 2026-10-18 TỐI, CHỜ NGHIỆM THU SANDBOX (lượt G89 + G94 mở 2026-10-18 tối; trước đó ⏳ hoãn chờ đơn 43; mở 2026-10-16, người dùng chốt cùng ngày)

**Nguồn.** Gộp `main` @ `d72ccd45` (2026-10-16, PR #138, NPBao): `docs/Payment/PAYMENT_WORKFLOW_SPEC.md` v2.0.0 + mã
`modules/payment/*`. Mục 5.1 của spec ấy tả việc client phải làm. Soát bằng mã: khối 🔀 `d72ccd45` mục 14
`PROJECT_CONTEXT.md` và đơn 44 `CAN-LAM/LICH-SU/SOAT_SAU_GOP_D72CCD45.md`.

**Server nay làm gì** (đọc mã, chưa đo đầu-cuối — backend dev chưa chạy được sau gộp, xem khối 🔀):

- Webhook số tiền **khớp** → `PAID` + `account.upgraded`, như trước.
- **Thừa** → đơn `WAITING_CONFIRMATION`, phát `payment.overpaid_confirmation` tới phòng tài khoản, **không** nâng gói.
  Người dùng phải gọi `POST /api/payment/confirm-upgrade` `{ orderCode, accept }`: `true` thì nâng gói và phát
  `account.upgraded`; `false` thì đơn sang `REFUND_PENDING`.
- **Thiếu** → `REFUND_PENDING`, phát `payment.underpaid_warning`. Admin hoàn tiền xong → `REFUNDED`, phát
  `payment.refunded`.
- Hạn đơn **30 → 10 phút** (`expiredAt` của `create-order`).
- `GET /payment/order-status/:orderCode` trả thêm `amountReceived`, `recognitionCode`, `transferContent` (chưa có
  `fee`, `refund*`).

**Client hôm nay làm gì** (đọc mã 2026-10-16):

1. `trangThaiDonTuChuoi` (`premium/domain/don_thanh_toan.dart`) chỉ biết `PAID · CANCELLED · EXPIRED`, chuỗi lạ là
   `pending` (cố ý: không coi chuỗi lạ là *đã trả*). Ba trạng thái mới đều thành `pending`.
2. Màn Chờ thanh toán (`cho_thanh_toan_page.dart`) hỏi `order-status` mỗi 3 s. Khi đồng hồ phía máy (`hetHanLuc`) về
   0, màn tự sang *"Đơn đã hết hạn — Đơn thanh toán chỉ có hiệu lực 30 phút."* (dòng ~151 và ~213). Tức người **vừa
   chuyển thừa** thấy *hết hạn* sau ≤ 10 phút, còn server đang chờ họ xác nhận. Không có lối nào trong app gọi
   `confirm-upgrade`. Người chuyển thiếu cũng thấy *hết hạn*, không biết sẽ được hoàn tiền.
3. Ba sự kiện socket mới không có trong `RealtimeEvent`, nên bị bỏ qua (đúng cam kết hộp đen).
4. Lịch sử mua (`lich_su_mua_page.dart`, `chuTrangThaiDon`) ghi đơn `REFUNDED` / `REFUND_PENDING` /
   `WAITING_CONFIRMATION` là *"Chờ thanh toán"*.
5. Chữ cũ: *"chỉ có hiệu lực 30 phút"* (`cho_thanh_toan_page.dart`), chú thích *"Backend đặt 30 phút"*
   (`don_thanh_toan.dart:18`), *"màn sống tối đa 30 phút"* (`bo_hoi_trang_thai_don.dart:8`), dự phòng
   `now + 30 phút` khi thiếu `expiredAt` (`donTuJson`).

**Người dùng chốt 2026-10-16:** làm **cùng lượt G89** (bốn việc client của đơn 43), sau khi backend đóng đơn 43 — dù đơn 44
không chặn. **Khi làm** (chưa thiết kế): cần một spec (brainstorm), màn Stitch cho hộp xác nhận chuyển thừa
và thông báo chuyển thiếu / đã hoàn tiền, quyết định đọc sự kiện như **tín hiệu** rồi hỏi lại `order-status` (giữ cam
kết hộp đen) hay mở ngoại lệ thứ hai, thêm ba giá trị vào `TrangThaiDon` (`switch` không `default` sẽ chỉ ra mọi chỗ
phải sửa), sửa năm chỗ chữ *30 phút*. Đơn 44 **không** chặn việc này. Có thể cần thêm trường ở `order-status` (đơn 44
mục F). ⚠️ Nghiệm thu đầu-cuối cần backend dev chạy được (`npm install` cho `multer` + áp hai tệp migration thanh toán —
cả hai cần phép đích danh) và PayOS sandbox (việc tồn chưa làm).

> 🔀 **Soát 2026-10-18 sau gộp `main` @ `e7570e16`: backend viết thẳng một phần G94 vào client, ca chính vẫn hở.**
> Đo bằng đọc mã ở `93f9ea91`. Toàn bộ test vẫn xanh: 7.394 / 10 skip, `flutter analyze` 20.
>
> **Backend đã làm trong `src/Client-app`** (`c545ffb7`, NPBao; stub test ở `26fb397b`):
> - `TrangThaiDon` thêm `waitingConfirmation` · `refundPending` · `refunded`; `trangThaiDonTuChuoi` đọc ba chuỗi ấy.
>   Chuỗi lạ vẫn là `pending`.
> - `DonThanhToan` thêm `recognitionCode` · `qrUrl` · `transferContent` · `amountReceived` · `fee`. Dự phòng hạn khi
>   thiếu `expiredAt` đổi 30 → 10 phút.
> - `PaymentApi.xacNhanNangCap` gọi `POST /payment/confirm-upgrade` với `accept` boolean.
> - Màn Chờ thanh toán: ba thân mới (xác nhận chuyển thừa với hai nút *Đồng ý kích hoạt gói* / *Từ chối & Yêu cầu hoàn
>   tiền*, cần hoàn tiền, đã hoàn tiền), ô mã nhận diện có nút chép, ảnh VietQR. Câu *"30 phút"* ở thân hết hạn đổi thành
>   *"trong thời hạn quy định"*.
> - Lịch sử mua có nhãn *Chờ xác nhận* · *Cần hoàn tiền* · *Đã hoàn tiền*.
>
> **Còn hở — hành vi:**
> 1. ✅ **Đã sửa 2026-10-18 tối** (đợt sửa hai lỗi, cuối khối này). ~~**Ca chính của G94 vẫn còn.**~~ `_nhipDem`
>    (`cho_thanh_toan_page.dart:145`) chạy mỗi giây kể cả khi bộ hỏi đã dừng vì
>    màn không hiện. Đồng hồ về 0 là màn chuyển `cho → hetHan`, rồi `_khiCo` (`:156`) thoát sớm vì `_man != cho`. Người
>    chuyển thừa đang ở app ngân hàng tới phút thứ 10 quay lại vẫn thấy *"Đơn đã hết hạn"*, không bao giờ thấy hộp xác nhận.
> 2. **Chỉ màn chờ gọi được `confirm-upgrade`.** Lịch sử mua chỉ hiện nhãn, không có lối xác nhận. Rời màn chờ là mất
>    lối. Phía server, `autoExpirePendingOrders` chỉ xét `PENDING`, nên đơn `WAITING_CONFIRMATION` nằm chờ mãi. Spec
>    thanh toán cố ý không đặt hạn cho trạng thái ấy; câu hỏi có mặc định *không hạn, client thêm lối xác nhận ở Lịch sử
>    mua* nằm ở banner đơn 44. `GET /payment/history` đã trả đủ mã đơn và trạng thái cho lối ấy.
> 3. ✅ **Đã sửa 2026-10-18 tối.** `_xacNhanNangCap` (`:192`) nuốt lỗi bằng `debugPrint`: bấm nút mà mạng hỏng thì
>    không có phản hồi nào. Phản hồi của
>    app đi qua `baoNhanh` (test quét 19 chỉ cấm `SnackBar`, nên không bắt được việc thiếu phản hồi).
> 4. Ba sự kiện `payment.*` vẫn không có trong `RealtimeEvent`. Màn chỉ biết trạng thái mới qua lượt hỏi 3 s.
>
> **Còn hở — mã và thiết kế:**
> 5. `donTuJson` (`premium/domain/don_thanh_toan.dart` — từ 2026-10-18 lát 1 ở `data/models/don_thanh_toan.dart`) tự dựng
>    URL ảnh `img.vietqr.io` khi server không gửi `qrUrl`, với
>    tên chủ tài khoản dự phòng ghi cứng `'NGUYEN PHU BAO'`. Tầng `domain/` mang tên một người thật và một host bên thứ ba
>    (lát 1 chỉ dời tệp; lát 2 bỏ phần tự dựng URL — spec G94 2026-10-18 mục 5.1).
> 6. Màn dùng `Image.network` tới host bên thứ ba, trong khi spec Premium chốt client không vẽ QR (câu 7). Ảnh tải hỏng
>    thì `SizedBox.shrink()`, im lặng.
> 7. Màu ghi cứng (`0xFF7B1FA2`, `0xFFF3E5F5`, `0xFFCE93D8`, `0xFF4A148C`) thay cho `AppColors`. Lịch sử mua cũng thêm ba
>    màu ghi cứng cho ba nhãn mới (`lich_su_mua_page.dart`). Ba thân mới chưa có màn Stitch, trong khi quy ước của dự án
>    là mọi màn mới phải có trên Stitch trước.
> 8. Docstring đầu lớp mất hai đoạn cũ: mã hai màn Stitch, và lý lẽ ba vế *đang hiện* (`TickerMode` · `isCurrent` ·
>    `resumed`). Chú thích *"ở 360 dp hàng này tràn 155 px khi để trần"* trên `Flexible` cũng bị xoá, còn `Flexible` vẫn ở
>    `:387`. Câu *"Về màn TRƯỚC Nâng cấp (hai lớp)…"* ở nút *Xong* bị xoá.
> 9. Còn hai chỗ chữ *30 phút*: ~~`bo_hoi_trang_thai_don.dart:8` (*"màn sống tối đa 30 phút"*)~~ (sửa cùng việc 1 —
>    câu ấy là lý lẽ của phép hết hạn theo đồng hồ máy) và docstring
>    `don_thanh_toan.dart:22` / `cho_thanh_toan_page.dart:26` (*"10-30 phút"*).
> 10. Test backend viết (`cho_thanh_toan_page_test.dart`, `don_thanh_toan_test.dart`) phủ nhánh *Đồng ý*, nhánh chờ hoàn
>    tiền, ô mã nhận diện và ba chuỗi trạng thái. Chưa có ca cho ~~nút *Từ chối*~~, thân *Đã hoàn tiền*, ~~lỗi mạng khi xác
>    nhận~~, ~~và ca đồng hồ về 0 lúc màn không hiện (việc 1)~~ (gạch: có ca từ 2026-10-18 tối — *Từ chối* mới phủ nhánh
>    lỗi, chưa phủ nhánh thành công). Một ca cũ đổi `pump(50 ms)` thành `pump(400 ms)` mà không ghi lý do.
>    18 tệp test còn lại chỉ thêm hàm giả `xacNhanNangCap` vì interface `PaymentApi` có thêm hàm.
>
> Lượt G89 + G94 vẫn cần spec + Stitch như đoạn *Khi làm* trên. Mã backend vừa viết là **điểm xuất phát**, không phải
> phần đã xong. **Người dùng chốt 2026-10-18:** phần dư của đơn 43 không chặn — lượt G89 + G94 bắt đầu từ phiên sau.
> Client được sửa sáu tệp backend viết như mọi tệp client khác. **Thứ tự chốt cùng ngày:** lượt ấy mở đầu bằng **một đợt
> chỉ sửa hai lỗi đang chạy** — việc 1 (đồng hồ về 0 lúc màn không hiện → *"Đơn đã hết hạn"*) và việc 3 (lỗi mạng khi
> xác nhận không báo gì) — mỗi lỗi một ca test đỏ trước. Sau đợt ấy mới tới spec, Stitch và các màn mới, gồm lối xác
> nhận khi đã rời màn chờ. Người dùng không chọn tách hai lỗi ra sửa ngay, và không chọn gỡ hẳn phần backend viết.
>
> ✅ **Đợt sửa hai lỗi đang chạy — 2026-10-18 tối** (đúng thứ tự trên; mỗi lỗi có ca đỏ trước, đỏ đúng lý do):
> - **Việc 1 — gốc:** đồng hồ trên máy tự đưa màn sang trạng thái kết thúc `hetHan`, và trạng thái kết thúc chặn mọi câu
>   trả lời sau đó của server: `_khiCo` chỉ nhận khi màn còn `cho`, nhánh `resumed` cũng chỉ hỏi khi `cho`. Server mới là
>   nguồn sự thật: `GET order-status` tự trả `EXPIRED` cho đơn `PENDING` quá `expired_at` ngay lúc đọc
>   (`payment.service.js:713`, `payment.repository.js:30`), còn `WAITING_CONFIRMATION` / `REFUND_PENDING` không bao giờ
>   hết hạn. **Sửa:** `_nhipDem` chỉ còn cập nhật số giây; màn sang *"Đơn đã hết hạn"* duy nhất khi server trả `EXPIRED`.
>   Lỗi có từ bản client gốc (2026-10-06). Hồi ấy server chỉ có `PENDING` / `PAID` nên ít khi lộ: chỉ người trả sát hạn
>   rồi quay lại sau hạn mới thấy *"hết hạn"* dù đã trả.
>   - Người dùng thấy khác: quá hạn theo máy mà server chưa trả lời (mất mạng, giờ máy chạy nhanh hơn giờ server) thì màn
>     đứng ở *"Còn 00:00"* + *"Đang chờ xác nhận từ ngân hàng…"*, vẫn hỏi theo nhịp 3 s khi đang hiện; nút *Huỷ* vẫn rời
>     được màn. Trước đây màn báo hết hạn ngay khi đồng hồ về 0. Màn đang hiện thì trễ tối đa 3 s (lượt hỏi kế) — cố ý
>     không thêm lượt hỏi riêng lúc đồng hồ về 0.
>   - Ca (`cho_thanh_toan_page_test.dart`): app ở nền lúc đồng hồ về 0 rồi quay lại → hộp xác nhận; webhook tới sát hạn
>     lúc màn đang hiện → hộp xác nhận. Ca cũ *"đếm ngược về 0 → coi như hết hạn"* ghim chính hành vi lỗi, nay viết lại
>     theo hợp đồng mới: server còn `PENDING` → vẫn chờ, vẫn hỏi; server `EXPIRED` → hết hạn, dừng hỏi.
> - **Việc 3:** lỗi xác nhận nay báo qua `baoNhanh` (loại lỗi), câu từ `cauLoiThanhToan`; nút mở lại để thử. Hàm ấy có thêm
>   tham số `cauTuChoi` cho câu 4xx, vì câu mặc định nói *"Không tạo được đơn thanh toán"* — sai với `confirm-upgrade`
>   (server trả 400 khi đơn không còn chờ xác nhận). Màn chờ dùng *"Không xác nhận được đơn này. Thử lại sau."*. Ca: một
>   widget (mất mạng rồi 400 — kiểm câu, loại, nút mở lại) và một unit.
> - **Để lại cho spec của lượt:** xác nhận bị 4xx (đơn đã được xác nhận ở máy khác, hoặc đã sang chờ hoàn tiền) thì màn
>   vẫn đứng ở hộp xác nhận, bấm lại vẫn 400. Nên hỏi lại `order-status` rồi đổi thân theo server, nhưng `_khiCo` chỉ nhận
>   khi màn còn `cho`. Tám việc còn lại của danh sách trên (2, 4–10) chưa đụng, trừ phần đã gạch ở 9 và 10.
>
> 🧱 **Lát 1 xong 2026-10-18 tối — dọn kiến trúc mảng Premium, không đổi hành vi** (spec
> `specs/2026-10-18-g94-don-thanh-toan-premium-design.md` mục 4; người dùng chốt dọn cả mảng trước khi làm tính năng):
> model sang `data/models/`, `PaymentApi` sang `data/datasources/`, `domain/` hết import Dio, `DonThanhToanRepository`
> cho ba trang, bộ hỏi sang `presentation/state/`, cửa chặn route sang `presentation/bloc/`. Năm commit, mỗi commit test
> toàn phần xanh; `flutter test` 7.406 / 10 skip, analyze 20. Chi tiết: khối 🧱 đầu mục 14 `PROJECT_CONTEXT.md`. Các việc
> 2, 4–10 ở trên chưa đụng — lát 2 (kế hoạch viết sau khi người dùng xác nhận màn Stitch, spec mục 9).
>
> ✅ **Lát 2 — mã xong 2026-10-18 tối** (kế hoạch `plans/2026-10-18-g94-lat-2-tinh-nang-don-thanh-toan.md`, gitignore;
> spec mục 5; năm màn Stitch người dùng xác nhận bằng mắt — bảng ở mục 5 `PREMIUM_FEATURE.md`). Mỗi task có ca đỏ trước và
> bản sai có chủ ý làm đúng ca ấy đỏ; mỗi task `flutter test` toàn phần xanh. Mười việc của khối 🔀:
> - **1, 3** — đã sửa ở đợt hai lỗi (trên).
> - **2** ✅ màn **Chi tiết đơn** `/premium/don/:orderCode` (`463fcf0c`) — một màn cho mọi trạng thái, nơi duy nhất gọi
>   `confirm-upgrade` (*Yêu cầu hoàn tiền* hỏi lại một lần); lối vào: màn Chờ (`pushReplacement` khi server trả trạng thái
>   đối soát), mọi dòng Lịch sử mua (`cc098628`), thẻ đầu màn Nâng cấp (`01e0d630` — đơn chờ xác nhận **khoá** *Thanh toán*,
>   đơn chờ hoàn tiền thì không). Xác nhận bị 4xx (đơn đã đổi ở nơi khác) → báo + nạp lại theo server — đóng luôn chỗ *"Để lại
>   cho spec"* của đợt hai lỗi. Nâng cấp đọc lại khi **màn hiện lại** (`TickerMode`), không theo future của `push` — màn Chờ
>   bị `pushReplacement` nên future ấy không về (bản đầu để nút *Thanh toán* quay mãi; bẫy 22 `PREMIUM_FEATURE.md`).
> - **4** ✅ `RealtimeEvent.donThanhToanDoi` (`af7351fe`) — sáu tên `payment.*`, tín hiệu im lặng; bốn màn nghe.
> - **5** ✅ bỏ bộ tự dựng URL QR + tên ghi cứng (`7f231cc6`) — `donTuJson` chỉ nhận `qrUrl` của server.
> - **6** ✅ **đảo** câu 7 spec 2026-10-06 theo người dùng chốt: màn Chờ giữ ảnh QR (to) + *Lưu mã QR* qua kênh Kotlin
>   `flowmoney/luu_anh` (`072d7d9b`); ảnh hỏng → câu chỉ sang thông tin chuyển khoản, nút Lưu ẩn; **không tự mở** trang PayOS.
> - **7** ✅ màu chỉ `AppColors` ở màn Chờ, Lịch sử mua (`NhanTrangThaiDon`), Chi tiết đơn, `_dongTran` của Nâng cấp; mọi
>   màn có Stitch. (Ngoài phạm vi lượt: `widgets/the_khoa_quyen.dart` — client viết 2026-10-08 — còn 10 `Color(0x…)` theo
>   giá trị Stitch; để đợt soát toàn app.)
> - **8** ✅ docstring màn Chờ khôi phục: mã Stitch, lý lẽ ba vế *đang hiện*, chú thích `Flexible` 155 px, nút *Xong* hai lớp.
> - **9** ✅ chữ *"10-30 phút"* hết ở `lib/` (`grep` 2026-10-18).
> - **10** ✅ test viết lại theo hợp đồng mới: `chi_tiet_don_page_test` (16 ca), `cho_thanh_toan_page_test` (viết lại, 18
>   ca), `lich_su_mua_page_test` (9), `nang_cap_page_test` (+13), model / domain / Cubit / repository / kênh ở Task 1–5.
> - `flutter test` **7.466 / 10 skip**, analyze 20 (HEAD `ddd35e1a`). 🚧 **Còn:** nghiệm thu máy thật — tám bước ở spec mục
>   10 (khoá PayOS sandbox vào `src/Backend/.env` + phép đích danh `npm install` ở `src/Backend`). Đóng G94 khi đạt.

---

### G93 — Lượt quét đầu của mỗi phiên chạy tự trả / tự trích / đọc biến động mà KHÔNG qua cửa quyền gói · ✅ ĐÓNG 2026-10-14 (mở cùng ngày)

> ✅ **Đóng 2026-10-14** (người dùng chọn sửa ngay). **Sửa:** `PhienDieuPhoiThat` nhận hook `datGoi`, `moPhienCucBo` chờ nó
> **sau** hàng seed cũ, **trước** `_boQuet.start` — DI nối `sl<GoiRepository>().datTaiKhoan(id)` (chờ nạp kho; chưa có
> `loaiPhien`). `GoiRepository.noiPhien` nay so với **phiên đã nối của chính nó** (biến cục bộ `daNoi`) thay vì `idaccount`
> — so với `idaccount` là bỏ qua `AuthSuccess` (tài khoản đã đặt sẵn) và mất `lamMoi` lẫn `loaiPhien` (kho trống → `type`
> của phiên) của lần mở app ấy. **Test:** ca ⭐ G93 ở `test/core/auth/phien_dieu_phoi_that_test.dart` (kho Basic
> `bill_auto_pay: false`, bộ quét giả hỏi `coQuyenNen` lúc `start` → `false`); ca ⭐ G93 ở `goi_repository_test.dart`
> (đặt tài khoản trước, `AuthSuccess` cùng tài khoản → làm mới đúng một lần + áp `loaiPhien`); hai ca thứ tự `moPhienCucBo`
> thêm `goi 10` trước `quet 10` — cả bốn đỏ trên mã cũ. **Không đo được trên máy:** máy ảo chỉ có tài khoản Premium, ca này cần
> Basic hạ cấp có bảng `features` khoá tắt + kỳ đến hạn; máy ảo chỉ kiểm hồi quy (xem khối 🩹 mục 14 `PROJECT_CONTEXT.md`).
> Mô tả gốc giữ nguyên bên dưới.

**Hiện tượng (đọc mã, chưa đo trên máy).** Tìm ra khi điều tra G92 — cùng cơ chế: `GoiRepository` chỉ biết tài khoản
qua `noiPhien`, tức **sau** `AuthSuccess`. Nhưng từ G86 (2026-10-09) `AuthBloc` gọi `PhienDieuPhoi.moPhienCucBo` **trước**
`AuthSuccess` (cả `_onAuthCheckRequested` lẫn `_onLoginSubmitted`), và `moPhienCucBo` → `NotificationScanner.start` →
`await scan(idaccount)`. Trong lượt quét ấy `GoiRepository.idaccount == null`, nên `coQuyenNen`
(`premium/data/co_quyen_nen.dart:12`) trả **`true`** cho mọi quyền: `runAutoPays` · `runAutoDeposits` · `loadKeHoach` ·
`NhapBienDong.batBienDong` · `NhapBienLai.coQuyen` (`injection_container.dart`) chạy như Premium.

**Ai bị.** Người dùng Basic mà kho gói đã lưu bảng `features` có khoá **tắt** (`bill_auto_pay: false`…) — tức đúng ca
*"dừng chạy, giữ công tắc"* của spec phân quyền 2026-10-08: tài khoản hạ cấp còn bật tự trả / tự trích. Mỗi lần mở app
hoặc đăng nhập, lượt quét đầu trả hoá đơn / trích mục tiêu cho họ. (Basic không có bảng, hoặc thiếu khoá → `duocDung` rơi về
`macDinhKhiThieu`, mà năm quyền này mặc định **mở** — không đổi gì.) Ba quyền AI không đi qua `coQuyenNen`.

**Vì sao chưa lộ.** Đường NỀN đã chặn đúng ca này (`chay_nen.dart` gọi `datGoi` trước `quet` — chốt *"gói đặt TRƯỚC khi
quét"*, `GOAL_FEATURE.md` mục 3.12); chú thích của `coQuyenNen` (*"chưa có phiên — không có lượt nào chạy lúc ấy"*) đúng
trước G86 và sai từ đó. Lượt quét sau (sự kiện đồng bộ, `resumed`) đã có tài khoản nên chặn đúng.

**Vì sao hoãn.** Phát hiện ngoài phạm vi việc đang làm (G92); chờ người dùng quyết. Hướng khả dĩ: `moPhienCucBo` gọi một
hook đặt gói (`GoiRepository.datTaiKhoan`, chờ nạp kho) **trước** `_boQuet.start` — cùng khuôn đường nền; khi ấy `noiPhien`
phải vẫn `lamMoi` ở `AuthSuccess` dù tài khoản đã trùng (hiện nó `return` sớm khi trùng), và kho trống thì `loaiPhien` chưa
có ở `moPhienCucBo`. Cần ca test: Basic có `bill_auto_pay: false` trong kho, mở phiên → không khoản chi tự trả nào.

---

### G92 — Mở `/goals/add` bằng deeplink khi khởi động nguội bị chuyển sang `/premium` dù tài khoản là Premium · ✅ ĐÓNG 2026-10-14 (mở 2026-10-13)

> ✅ **Đóng 2026-10-14 — nguyên nhân khả dĩ bên dưới là ĐÚNG, đo được cả hai đầu.** Thứ tự: `noiPhien` nghe
> `authBloc.stream` từ `main()` (trước `runApp`) nên chạy **trước** bộ nghe refresh của router; `datTaiKhoan` gán
> `_idaccount` ngay rồi mới `await` secure storage; router chạy lại `redirect` của route đang đứng → cửa đọc `hienTai` = Basic
> mặc định. Không gì kích `redirect` lại khi kho trả lời, nên người dùng ở lại `/premium`. **Sửa:** `GoiRepository` giữ future
> của lượt nạp kho gần nhất (`choNapKho()` — chỉ kho, không `lamMoi`); `chanTheoGoi` **và** `chanTheoQuyen` chờ nó rồi mới đọc
> `idaccount` + `hienTai` (`chanTheoQuyen` thành `Future`). **Cửa quyền hỏng chiều ngược:** Basic mặc định không mang khoá
> nào → `export_reports` rơi về `macDinhKhiThieu` = mở → Basic bị tắt quyền **lọt** vào Xuất báo cáo lúc mở lạnh (ca Premium
> của cửa này xanh ngay trên mã cũ — ca đỏ là ca Basic). **Bán kính thật** (đếm `app_router.dart`): sáu route có cửa trần
> (`/wallets/add` · `/budget/rules` · `/categories/child/new` · `/categories/group/new` · `/bills/add` · `/goals/add`) + hai
> route cửa quyền (`/analytics/export`, `/export-report`) — câu *"Ba route tạo"* bên dưới là của spec gốc. **Test:** nhóm
> *"G92 — kho gói chưa nạp xong lúc cửa chặn chạy"* ở `test/features/premium/data/chan_theo_goi_test.dart` (5 ca, `KhoCho` treo
> `doc` tới khi test trả): ⭐ Premium qua không đếm · Basic chạm trần vẫn chặn · đăng xuất giữa chừng → qua · ⭐ Basic tắt quyền
> vẫn chặn · Premium qua — ba ca đỏ trên mã cũ. **Máy ảo** (`FlowMoney_16G`, debug, tài khoản Premium 3 mục tiêu, backend
> tắt): mã cũ mở lạnh `http://x/goals/add` → màn Premium (*"còn 22 ngày"* — gói nạp xong SAU khi cửa đã quyết); mã mới
> (`3654946f…`) mở lạnh 3/3 lần → form *Thêm Mục Tiêu Tiết Kiệm*, mở nóng → form, mở lạnh `/export-report` → trang Xuất báo
> cáo, mở thường → Trang chủ. Cùng gốc: **G93** (`coQuyenNen` ở lượt quét đầu, đóng cùng ngày). ⚠️ **Bẫy nghiệm thu:** form mở
> bằng `am start -n … -d http://x/goals/add` là trang **gốc** của app — mũi tên *Quay lại* (`context.pop()`) không có chỗ về
> và đứng yên (người dùng vấp ngay sau lượt đo). Không phải lỗi: `MainActivity` chỉ khai `MAIN/LAUNCHER`, người dùng thật không
> tới được trạng thái ấy; lối thường (danh sách → *Thêm mục tiêu mới* → mũi tên) quay về được — đo cùng buổi. Người dùng chốt
> để nguyên. Đo xong thì `am force-stop` rồi mở app thường. Mô tả gốc giữ nguyên bên dưới.

**Hiện tượng.** Lộ ở lượt nghiệm thu máy ảo 2026-10-13 (đợt tách bốn trang lớn): mở deeplink tới `/goals/add` **lúc app chưa
chạy** (khởi động nguội) với tài khoản Premium → app rơi vào `/premium`; cùng deeplink khi app **đã chạy** thì vào đúng form.
Không do đợt tách gây ra — router không bị đụng, `goal_add_page` chỉ dời nguyên văn.

**Nguyên nhân khả dĩ, chưa kiểm.** `chanTheoGoi` (`lib/features/premium/data/chan_theo_goi.dart:27–31`) đọc `goi.idaccount` rồi
`goi.hienTai` **đồng bộ**; nếu `idaccount` đã có mà gói đã lưu chưa nạp xong lúc `redirect` chạy ở khởi động nguội, `hienTai`
là Basic mặc định → `laPremium` sai → đếm mục tiêu đang hoạt động, đã chạm trần 3 → `chuyenHuongTheoGoi` sang `/premium`.
Chưa có phép đo xác nhận (chưa log `hienTai` tại thời điểm `redirect`).

**Bán kính.** Ba route tạo có cửa chặn (`/wallets/add` · `/budget/rules` · `/goals/add`), chỉ đường khởi động nguội qua
deeplink (thông báo, widget); tài khoản Premium có từ 3 mục tiêu / ví / ngân sách đang hoạt động trở lên. Không mất dữ liệu.

**Vì sao hoãn.** Phát hiện lúc nghiệm thu một đợt refactor chỉ-dời-mã; sửa là đổi hành vi vùng Premium, ngoài phạm vi đợt.
Hướng khả dĩ: chờ gói nạp xong (hoặc coi `hienTai` chưa nạp là *chưa biết* → cho qua) trước khi đếm — cần đo trước.

---

### G91 — Hàng gợi ý pin ở Cài đặt thông báo biến mất cả hai nơi khi người dùng Basic đã bật `docBienDong` · ✅ ĐÓNG 2026-10-14 (mở 2026-10-13)

> ✅ **Đóng 2026-10-14.** `d1DangHienPin` nay mở đầu bằng `context.coQuyen(MaQuyen.bankNotificationParser)` — lặp **đủ** điều
> kiện dựng hàng pin của `TheBienDong`, kể cả cửa quyền gói. Ca canh: *"⭐ G91: Basic còn docBienDong bật…"* ở
> `test/features/notification/nhac_sau_ngan_hang_cai_dat_test.dart` (bọc trang trong `GoiCubit` Basic, quyền
> `bank_notification_parser: false`) — đỏ trên mã cũ (0 hàng pin), xanh sau khi sửa; ca *"D1 đã hiện hàng pin → không lặp"*
> cùng tệp vẫn canh chiều ngược (không provider = có quyền). Không nghiệm thu máy: trạng thái cần một tài khoản từng Premium bị
> hạ cấp, và cả hai nhánh đã có ca widget test. Mô tả gốc giữ nguyên bên dưới.

**Hiện tượng.** `KhoiNhacSauNganHang` (`lib/features/notification/presentation/widgets/cai_dat_thong_bao/khoi_nhac_sau_ngan_hang.dart:38`)
tính `d1DangHienPin = prefs.docBienDong && coQuyenBienDong && !duocChayNen` — không xét quyền gói Premium. Người dùng **Basic**
có `docBienDong = true` (bật khi còn Premium / hạ cấp) thì thẻ D1 (`the_bien_dong.dart:301–303`) hiện `DongKhoaCongTac` nên
**không** dựng hàng gợi ý pin (nhánh `dongTreNen` ở `:308` nằm trong `else`), trong khi khối nhắc sau ngân hàng (`:87`,
`coQuyenPhien && !duocChayNen && !d1DangHienPin`) tưởng D1 đang hiện hàng ấy nên cũng giấu hàng của mình → không còn hàng gợi ý
pin ở đâu. Không có nguy cơ trùng khoá (ít hàng, không phải nhiều hàng).

**Có từ trước:** logic được dời nguyên văn trong đợt tách bốn trang 2026-10-13; phát hiện ở lượt soát đợt ấy.

**Bán kính.** Chỉ màn Cài đặt thông báo, chỉ người dùng Basic còn `docBienDong` bật và đã cấp quyền đọc thông báo, **đồng thời**
bật *Nhắc ghi sau khi dùng app ngân hàng* (`nhacSauNganHang`) và đã cấp quyền *Truy cập dữ liệu sử dụng* (`coQuyenPhien`), máy
chưa miễn tối ưu pin — thiếu một trong hai vế sau thì khối nhắc vốn không dựng hàng pin, nên không có gì để mất. Hậu quả nhẹ:
thiếu một dòng gợi ý (lời nhắc có thể trễ do ColorOS đóng băng app).

**Vì sao hoãn.** Sửa là đổi hành vi UI ngoài phạm vi đợt chỉ-dời-mã. Hướng: thêm `context.coQuyen(MaQuyen.bankNotificationParser)`
vào `d1DangHienPin` + một ca test Basic.

---

### G89 — Thao tác của admin (bảo trì khẩn cấp, phong toả AIOps, broadcast) vô hình trên client: không nhánh nào đọc `MAINTENANCE_MODE` / `AIOPS_QUARANTINED` · ✅ ĐÓNG 2026-10-20 (mã xong + nghiệm thu OnePlus đạt) (12 commit `b7ca4512..98d58c64`; spec 2026-10-20 mục 11 = chỗ thi công khác bản viết; lịch sử: lượt mở 2026-10-18 tối; trước đó ⏳ hoãn tới khi backend đóng đơn 43; mở 2026-10-11 ⏸️ để nguyên; người dùng chốt lại 2026-10-15)

> ✅ **ĐÓNG 2026-10-20 — mã xong và NGHIỆM THU OnePlus 13R ĐẠT** (12 commit `b7ca4512..98d58c64` + dọn sau review `2945cb5d`; bốn kịch bản + lượt ép đường socket, bảng ở mục 12 spec — phong toả AIOps chặn HTTP nhưng **không** chặn bắt tay socket, đó là cách ép đường socket thắng). Làm đúng spec bên dưới; chỗ thi công khác bản viết ở mục 11 spec (20 mục).
> Năm câu cũ của mục này đã sai và được đính chính tại chỗ bên dưới: *"503 đăng nhập mất `code`"* (đã đo lại: `auth.controller`
> chuyển `code` cho 503 — đơn 43 đạt), *"`user.notification` sống"* (hàm gửi không có chỗ gọi — mã chết), *"`RealtimeEvent` chỉ dịch
> 5 tên"* (lúc viết: 5 giá trị / 11 tên; nay 6 giá trị / 12 tên, thêm `taiKhoanHaCap`), *"loopback miễn ở mọi môi trường"* (tầng kiểm
> request chỉ miễn khi `development`; mọi môi trường là nhờ lớp từ chối thêm IP được bảo vệ), đường `core/api/auth_interceptor.dart`
> (thật: `core/api/interceptors/`). `AppDatabase.purgeDataForAccount` / `PhienDieuPhoi.xoaDuLieu` **gỡ 2026-10-20 (G89)** — không đường
> nào còn xoá SQLite khi `ACCOUNT_DELETED`.
>
> 📝 **2026-10-20 — spec `docs/superpowers/specs/2026-10-20-g89-may-chu-chan-va-tai-khoan-bi-tu-choi-design.md`** (người dùng
> duyệt ba phần trong phiên; Stitch `006c5a2e…`). Thay đoạn *"Nếu làm"* cuối mục bằng thiết kế ấy: mô hình trạng thái máy chủ ở
> `core/network` + interceptor; dòng nhắc Trang chủ (không phải dải mọi trang); bảo trì / phong toả **không** tính lượt hỏng của
> đồng bộ; `connect_error` có `data.code` → đăng xuất + dừng nối lại; `account.downgraded` + 403 `FEATURE_DISABLED` → làm mới gói;
> `ACCOUNT_DELETED` **không xoá SQLite ở mọi nguồn**. Năm câu đã cũ của mục này liệt kê ở mục 9 spec — sửa khi đóng mục.

> ⏳ **Chốt lại 2026-10-15 (sau gộp `main` @ `cd2ee572`).** Backend thêm hợp đồng `docs/Admin-web/Event-Notification-to-ClientApp.md`
> (*"PO đã phê duyệt"*) đòi client xử lý bảo trì / phong toả / broadcast. Đối chiếu mã hai phía cùng ngày đính chính phần
> *Hiện tượng* dưới đây: backend **không** phát `user.notification` (hàm gửi không có chỗ gọi — mã chết); 503 lúc **đăng nhập**
> bảo trì **mất `code`** (`auth.controller.js:59-67` chỉ chuyển `extra` khi 403) nên màn Đăng nhập chưa nhận ra được *(đính chính 2026-10-20: đã sửa ở backend, client soát 2026-10-18 — 503 có `code`)*; danh sách
> phong toả nay **lưu CSDL** (khởi động lại backend không còn xoá). Client đặt **đơn 43** (`CAN-LAM/LICH-SU/SOAT_SAU_GOP_CD2EE572.md`:
> A — AIOps khoá bằng `'Locked'` → `ACCOUNT_DELETED` → client xoá SQLite; B — webhook nâng nhầm; C — 503 đăng nhập thiếu `code`).
> **2026-10-16:** lượt ấy gộp thêm **G94** (đối soát chuyển thừa / thiếu khi nâng Premium — người dùng chốt).
> **Người dùng chốt:** G89 cùng ba việc khác (xét lại xoá SQLite khi `ACCOUNT_DELETED` từ request thường · `connect_error` có
> `data.code` → dừng nối lại + đăng xuất · `account.downgraded` → làm mới gói) làm **một lượt khi backend đóng đơn 43**. Phạm vi
> G89 giữ ràng buộc *"Nếu làm"* cuối mục (chỉ mã HTTP + `code`); nhận broadcast qua socket vẫn theo quyết định 2026-09-30.

**Hiện tượng.** Khi admin bật bảo trì (`POST /admin/system/maintenance`; từ gộp `main` @ `79e46225` bật tức thì mặc định là
**khẩn cấp**), mọi request người dùng nhận **503** `{code: 'MAINTENANCE_MODE', message, isEmergency}` + `Retry-After: 60`
(`middleware/maintenance.middleware.js`; `/auth/login` đi qua rồi `auth.service` từ chối người dùng thường); backend còn phát
`user.notification` tới `account_<id>` *(đính chính 2026-10-20: hàm gửi `user.notification` không có chỗ gọi — mã chết)* và `system.broadcast` / `system.maintenance_changed` tới **mọi** socket. Client hôm nay:
`SyncEngine` xếp 503 vào `transportFailed` (im lặng, thử lại theo giãn cách — đúng), màn Đăng nhập hiện `message` của server,
còn **không dải / hộp thoại nào**, và `RealtimeEvent` chỉ dịch 5 giá trị (11 tên; từ 2026-10-20: 6 giá trị / 12 tên) nên ba sự kiện kia không được dịch *(đính chính 2026-10-20: `user.notification` là mã chết — thực chất hai sự kiện `system.*` rơi vào hộp đen; từ G89 client còn nghe `account.downgraded`)*. **403
`AIOPS_QUARANTINED`** (phong toả IP) rơi vào cùng nhánh im lặng — từ `79e46225` loopback được miễn nên bàn
dev (`adb reverse`) không gặp *(đính chính 2026-10-20: tầng kiểm request chỉ miễn khi `development`; mọi môi trường là nhờ lớp từ chối thêm IP được bảo vệ)*; máy thật qua LAN / cloud mới gặp.

**Tài liệu backend tả một client không có:** `docs/Admin-web/README.md` §3 hàng 1 (*"đẩy Modal đỏ toàn màn hình"*), hàng 4
(*"hiển thị lý do và thời gian hết hạn"* khi bị phong toả), hàng 5 (*"SnackBar/Dialog thông báo tức thời"*);
`07-maintenance-and-resilience.md` §7 (*"Dialog đỏ không thể bỏ qua"*). `grep` client: 0 chỗ đọc `MAINTENANCE_MODE`,
`AIOPS_QUARANTINED`, `== 403` ở `core/api` lẫn `features/auth/data` (đo 2026-10-11).

**Vì sao để nguyên (người dùng chốt 2026-10-11).** Offline-first chạy trọn khi server bảo trì; đồng bộ tự nối lại khi tắt;
nhận broadcast qua socket đã bị từ chối 2026-09-30 (trái hai quy ước *bảng thông báo cục bộ* và *payload hộp đen*). Giá của
việc không làm: người dùng không biết vì sao đồng bộ im (toast thất bại chỉ nói chung — A4), và bị phong toả thì không biết
bao lâu.

**Nếu làm (khi tới lượt):** đọc **mã HTTP + `code`** của phản hồi — không đọc payload socket, không nghe sự kiện mới — ở
`core/api/interceptors/` (lúc viết ghi nhầm `core/api/auth_interceptor.dart`) và nhánh `transportFailed` của `core/sync/gui_lo_dong_bo.dart` (trước 2026-10-19: `sync_engine.dart`) → một dải trên Trang chủ *"Hệ
thống đang bảo trì — dữ liệu trên máy vẫn dùng được"* (ẩn theo `Retry-After` hoặc khi request kế thành công), toast đồng bộ
nói rõ lý do; 403 `AIOPS_QUARANTINED` một câu riêng. Không đổi payload đồng bộ, không đổi schema. Cần spec ngắn + màn Stitch
(dải chưa có trong thiết kế). Bán kính: hai tệp trên, `shared/app_toast`, Trang chủ.

---

### G88 — Nợ kiến trúc còn lại sau đợt bịt điểm rò 2026-10-10 · ✅ ĐÓNG (2026-10-16; mở 2026-10-10 là ⏸️ nợ có tên)

**Bối cảnh.** Đợt *bịt điểm rò kiến trúc Client-app* (spec `docs/superpowers/specs/2026-10-10-bit-diem-ro-kien-truc-client-design.md`,
tài liệu `docs/KIEN_TRUC_CLIENT_APP.md`) chọn **giữ** kiến trúc feature-first ba tầng và chỉ bịt bốn chỗ méo đo được:
trang thôi cầm CSDL (test quét 22), hai trang lớn tách thành widget theo khối (quét 23), `AuthBloc` chỉ còn trạng thái
(quét 24, `PhienDieuPhoi`), và có CI. Những gì dưới đây là phần **cố ý để lại** — không phải lỗi đang chạy, không ai phải
sửa ngay, nhưng đặt tên để người sau không tưởng đợt ấy đã làm hết. Mọi số đếm bằng lệnh ngày 2026-10-10.

**Vì sao hoãn.** Người dùng chốt mức *"bịt điểm rò, giữ kiến trúc hiện tại"* (quyết định 1 của spec) và *"không Entity cho
14 mảng, không cấm import kiểu Drift ở UI"* (quyết định 10); khi được hỏi *"có cần thêm tầng?"* — **không**; *"có nên dời
tệp cho vị trí đồng nhất?"* — **có, nhưng là đợt dọn riêng** kèm test quét canh luật vị trí.

1. ~~**Trang Thêm giao dịch còn 2.007 dòng**~~ ✅ **đóng 2026-10-11** (`add_transaction_page.dart`, đếm như test quét 23; trước đợt 3.107). Bảy khối
   giao diện đã sang `widgets/them_giao_dich/`; phần còn lại là trạng thái 61 trường và logic chọn ví / gợi ý / chiều tiền.
   Hạ thêm cần **controller hoặc Cubit riêng** (hướng B người dùng để lại) — spec ước ~1.800, số thật 2.007 (phán quyết R15).
   📝 **2026-10-11 người dùng chốt: làm ngay sau nghiệm thu OnePlus, TRƯỚC C4** — C4 giọng nói sẽ chạm đúng màn này (như C2,
   C3, A5, D1 đã chạm). Bốn trang lớn còn lại của gạch 2 có lịch riêng (dưới).
   ✅ **Đóng 2026-10-11** (spec `docs/superpowers/specs/2026-10-11-tach-trang-them-giao-dich-cubit-design.md` — khối *"Chỗ bản thi công KHÁC bản viết"* ở đầu tệp; kế hoạch 7 task `plans/2026-10-11-tach-trang-them-giao-dich-cubit.md` (gitignore); thi công bằng agent con mỗi task; commit `21d4c594` → `18ae5749` + commit đóng sổ): trạng thái 61 trường và logic chọn ví / gợi ý / chiều tiền / điền sẵn / tách khoản / lưu dời sang **`ThemGiaoDichCubit`** (`presentation/bloc/`, không import UI Flutter) + `ThemGiaoDichState`; mọi lần đọc / ghi dữ liệu qua **`ThemGiaoDichNguon`** (`data/`, cổng tiêm được, bản thật dùng `sl` lúc cần). Đo `wc -l` 2026-10-11: trang **2.007 → 779**, Cubit **1.097**, state **184**, nguồn **352** (cả bốn dưới trần 1.200; 7 tệp `widgets/them_giao_dich/` giữ 1.500 dòng). Test mới **64 ca** — `them_giao_dich_cubit_test` 52 + `them_giao_dich_nguon_test` 12; 24 tệp test dựng trang không đổi kỳ vọng nào; `flutter test` 6.617 → **6.681** (+9 skip), `flutter analyze` **20**. Cửa điền sẵn chung cho C4 giọng nói và mọi nguồn khác (Nhập nhanh, D1, biên lai, quét ảnh) là **`ThemGiaoDichCubit.dienKetQua`**. Máy ảo (APK debug SHA-1 `d3488de6…`, tài khoản 10): 5 cặp ảnh trước / sau **0 px khác**, vàng thuần 0; 12 luồng làm tay **11 ✅ · 1 ◐** — thẻ gợi ý theo số tiền ở 360 × 640 dp cuộn hết cỡ mà đầu thẻ vẫn bị cắt (giới hạn G58 có từ trước, không có APK cũ để đối chứng đúng khổ ấy; ở 360 × 800 và 411 dp thì ổn). Nghiệm thu OnePlus gộp vào lượt nghiệm thu kế (việc 1 của thứ tự).
2. ~~**Bốn tệp trong danh sách miễn trừ của test quét 23**~~ ✅ **đóng 2026-10-13** (spec
   `docs/superpowers/specs/2026-10-13-tach-bon-trang-lon-design.md` — khối 🔧 và ✅ ở đầu tệp; kế hoạch 11 task
   `plans/2026-10-13-tach-bon-trang-lon.md` (gitignore); thi công bằng agent con mỗi task; 9 commit mã `ecd01990` → `c4ea8437`).
   Đo `wc -l` 2026-10-13, trước → sau: `goal_add_page` 1.570 → **791** · `goal_detail_page` 1.480 → **664** ·
   `notification_settings_page` 1.615 → **866** · `report_preview_page` 1.270 → **243**; 30 tệp widget mới
   (`goal/presentation/widgets/them_muc_tieu/` 7 · `chi_tiet_muc_tieu/` 7 · `notification/presentation/widgets/cai_dat_thong_bao/` 6 ·
   `analytics/presentation/widgets/xem_truoc_bao_cao/` 10) + 2 tệp `domain/` (`goal/domain/chu_ky_muc_tieu.dart`,
   `notification/domain/cau_chu_dong_y.dart`); `mienTru` của quét 23 **rỗng** (trang lớn nhất trong bốn trang đã tách: 866). `flutter test`
   7.037 → **7.039** (+9 skip; +2 ca phiếu Nạp / Rút), `flutter analyze` **20**. Máy ảo AVD 1080×2400, bản debug (SHA-1 trước
   `bf59ba5b…`, sau `7af9d631…`): **32 cặp ảnh trước / sau 0 px khác**, vàng thuần 0 (lần đầu 6 cặp lệch 1–2 px do quán tính
   cuộn của `input swipe`; chụp lại bằng cuộn giữ-rồi-thả thì 0). **Thay đổi hành vi duy nhất:** hai ô số tiền của phiếu Nạp /
   Rút (Chi tiết mục tiêu) nay có **trần 13 chữ số**, và lưới `o_nhap_tien_co_tran_test` (quét 8) nhận cả ô nhập tiền truyền
   bằng tham số. ⚠️ Chưa chụp được: Cài đặt thông báo khi D1 **bật** và khối nhắc sau ngân hàng bật (cần cấp quyền hệ điều hành),
   dòng gợi ý giờ (máy không có gợi ý) — 35 ca (21 + 14, đếm `test(`/`testWidgets(` 2026-10-13) `dong_y_bien_dong_test` / `nhac_sau_ngan_hang_cai_dat_test` dựng trang thật ở hai trạng thái đầu
   (D1 bật, khối nhắc bật), còn dòng gợi ý do `notification_settings_de_xuat_test` (10 ca, đếm cùng ngày) phủ; nghiệm thu máy thật lần sau bật D1 là bắt được.
   📜 Bản mô tả gốc của mục (giữ làm lịch sử): bốn tệp trong danh sách miễn trừ của test quét 23 (trần 1.200 dòng; trần riêng chỉ giảm; ✅ `add_transaction_page` 2.007 đã rút 2026-10-11 — gạch 1):
   `notification_settings_page` 1.615 · `goal_add_page` 1.570 · `goal_detail_page` 1.480 · `report_preview_page`
   1.270. Tách tệp nào xong thì rút tên khỏi `mienTru`. ✅ Nợ kèm đã trả 2026-10-10: 14 tệp `analytics/presentation/widgets/phan_tich/` từng mang
   `// ignore_for_file: use_key_in_widget_constructors` (phán quyết R13) — nay mọi constructor widget công khai nhận `super.key`,
   dòng ignore đã gỡ (commit `752d4ad0`; `flutter analyze` vẫn 20, 0 info `use_key_in_widget_constructors`).
   📝 **2026-10-11 xếp lịch: bốn trang còn lại (trừ Thêm giao dịch — gạch 1) là một đợt, SAU C4 và TRƯỚC thống nhất Entity**
   — việc cùng loại đợt bịt điểm rò (tách widget theo khối, dời nguyên văn, giữ `Key` và chữ), làm trước Entity để đợt ấy
   sửa tệp nhỏ thay vì tệp 1.270–1.615 dòng; sau C4 để không trì hoãn tính năng. Thứ tự trong đợt: Thêm + Chi tiết mục tiêu
   (cùng mảng) → Cài đặt thông báo → Xem trước báo cáo.
3. ✅ **ĐÓNG 2026-10-15 (đợt 4/4, Entity 7/14)** — ~~**UI cầm kiểu hàng Drift; Entity có ở 6/14 mảng**~~ (trước đợt Thông báo: ví, giao dịch, mục tiêu, ngân sách, hoá đơn, danh mục — nay thêm thông báo = **7/14**); thống nhất xong Hoá đơn, Ví, Giao dịch (2026-10-14), Danh mục, Thông báo (2026-10-15); hai nợ Mục tiêu (`goal_auto_deposit_runner`, `watchGoalTransactions`) và `ghiPhanHoi` đã trả 2026-10-15 (khối ✅ dưới đây); đợt Thông báo xong cùng ngày (khối ✅ cuối mục). Lối thoát của đợt là
   **lối chuyển tiếp** ở repository / nguồn — 11 lúc đầu, 10 sau đợt Hoá đơn, 4 sau đợt Giao dịch + Ví, **0** sau đợt Danh mục (số **10** dưới đây là ảnh chụp sau đợt 1; đếm: 9 trả hàng Drift — `WalletRepository.getActiveRows` · `getAllRows` ·
   `watchAllRows` · `getRowById`; `TransactionRepository.getAllRows` · `watchAllRows`;
   `CategoryManagementRepository.loadBangTraTen` · `watchAllRows` · `getRowById`; `BillRepository.getById` đã thôi, nay trả `BillEntity`)
   cộng `TaiPhanBoNguon.ghiPhanHoi`. Đó **từng là lối tạm** (trang không còn cầm DAO nhưng kiểu Drift vẫn lan tới widget); đã đóng 2026-10-15 cùng đợt Danh mục, chỉ còn `AppNotification` ở đợt Thông báo.
   📝 **2026-10-11 người dùng chốt thống nhất về Entity (hướng A)** — làm **sau** nghiệm thu OnePlus, tách Thêm giao dịch, C4
   và tách bốn trang lớn (gạch 1, 2): giao diện không
   cầm hàng Drift, từng mảng một đợt (Hoá đơn → Giao dịch + Ví → Danh mục → Thông báo), kèm test quét cấm `presentation/`
   dùng kiểu Drift với danh sách chờ chỉ-được-giảm. Đo 2026-10-11 (tệp trang / widget cầm hàng Drift): `Category` 18 ·
   `Wallet` 12 · `Bill` 9 · `Transaction` 5 · `AppNotification` 2 · `Goal` 1. Hướng B (bỏ 4 Entity, ~1.000 dòng) đã loại —
   ngược phân tầng. Bảng phụ chỉ dùng trong `data/` (phản hồi gợi ý, nhật ký xem, khoá chạy nền) không cần Entity.
   📝 **2026-10-14 — đợt 1 (Hoá đơn): spec duyệt** `specs/2026-10-14-entity-hoa-don-design.md` (`f45e6f4f`) + kế hoạch 7 task
   `plans/2026-10-14-entity-hoa-don.md` (gitignore), **chưa thi công** (người dùng chọn bàn giao). Chốt thêm trong brainstorm:
   8 (+1 `reminder_scheduler`) tệp ngoài mảng cùng đổi; ratchet quét 25 nâng +1 ở ba tệp thông báo (về 0 ở gạch 5); test quét
   **27** canh theo tên kiểu với danh sách chờ theo kiểu; runner về `data/services`; đo 2026-10-14: `bill/domain` 11/14 import
   Drift, presentation cầm `Bill` 8 tệp.
   ✅ **2026-10-14 — đợt 1/4 (Hoá đơn) ĐÓNG** (6 commit mã `2a912871` → `a085deb0`, thi công bằng agent con mỗi task; spec khối
   ✅ *"Số đo sau thi công"*): `BillEntity` (`bill/data/models/bill_entity.dart`, 192 dòng) là kiểu **duy nhất** từ repository
   trở lên; ghi qua `BillDraft` (nay Dart thuần) → `companionTaoTu` / `companionSuaTu` (`bill_draft_companion.dart`, 78 dòng);
   `BillAutoPayRunner` dời về `bill/data/services/`; `paymentsOf` trả `TransactionEntity`; `BillRepository` có thêm
   `getUpcoming` và `getAllIncludingDeleted`. Test quét **27** (`core/ui/presentation_domain_khong_kieu_drift_test.dart`) canh:
   `presentation/` + `shared/` không nhắc kiểu hàng Drift (danh sách chờ theo kiểu, chỉ giảm) và `domain/` không import
   `core/database`. Đo bằng máy 2026-10-14: tệp `domain/` import `core/database` **24 → 12** (Hoá đơn 11 → **1**: còn
   `de_xuat_hoa_don.dart`, cần `Transaction` + `GoiYHoaDonPhanHoi` — nợ của đợt Giao dịch); `Bill` Drift ở `presentation/` + `shared/` **0**
   (trước: 8 tệp trang + 8–9 tệp ngoài mảng); lối chuyển tiếp trả hàng Drift **11 → 10**; Entity **5/14** mảng. `flutter test`
   7.047 → **7.057** (+9 skip), `flutter analyze` **20**. Máy ảo 1080×2400 (SHA-1 APK trước `7af9d631…`, sau `b0164475…`):
   **15/15 cặp ảnh trước / sau giống hệt theo SHA-1** (trang Hoá đơn **hai** tab, chi tiết, Thêm, Sửa, bảng Thanh toán, trung tâm
   thông báo, Phân tích *Dự báo 30 ngày*); thao tác ghi trả → hoàn tác và bỏ qua → hoàn tác đạt, dữ liệu hoá đơn / giao dịch về như cũ (riêng chuông thông báo đi 23 → 24: lượt chạy tạo thêm một thông báo cục bộ). ⚠️ Chưa kiểm
   được bằng ảnh: thẻ *"Có vẻ là khoản lặp"* (B2) — không hiện ở cả hai bản; bằng chứng đổi bản chỉ là `Success` của `adb install`
   và hai APK khác SHA-1 (không có `dumpsys … lastUpdateTime`). Còn **một** `Iterable<Bill>` ở `wallet/data/vi_trung_ten_nguon.dart`
   — **cố ý** (cổng đọc của ví, spec mục 7), không phải sót cần sửa. Ba đợt còn lại: Giao dịch + Ví → Danh mục → Thông báo.
   📝 **2026-10-14 — đợt 2 (Giao dịch + Ví): spec duyệt** `specs/2026-10-14-entity-giao-dich-vi-design.md` (`c2c723cb`) + kế hoạch 9 task
   `plans/2026-10-14-entity-giao-dich-vi.md` (gitignore); bốn chốt: `core/notification` → Entity (ratchet 40 → 43, luật tăng viết lại);
   gộp tên repository, bỏ sáu lối `…Rows`, quét 2 phân loại thêm 6 chỗ; `de_xuat_hoa_don` nhận record; máy ảo + `lastUpdateTime`.
   ✅ **2026-10-14 — đợt 2/4 (Giao dịch + Ví) ĐÓNG** (thi công bằng agent con mỗi task; mã `54a6efd1` → `3252db88`: Task 1 `54a6efd1` + `2b0922bd`
   quét 27 mở rộng · Task 2 `a8deac2a` `WalletEntity.fromDrift` + `TransactionEntity` mang `billId` / `deletedAt` chỉ đọc · Task 3 `3bbb988e`
   repository gộp tên · Task 4 `d89d79c4` domain · Task 5 `08014289` giao diện · Task 6 `908b99ec` + `92d39914` `core/notification` + DI ·
   Task 7 `3252db88` bỏ sáu lối `…Rows`, quét 2; spec khối ✅ *"Số đo sau thi công"*). Đo bằng máy 2026-10-14: `Wallet` / `Transaction` Drift
   ở `presentation/` + `shared/` + `lib/core` (trừ `database`, `sync`) **0**; lối chuyển tiếp trả hàng Drift **10 → 4** (`CategoryManagementRepository.loadBangTraTen`
   · `watchAllRows` · `getRowById` + `TaiPhanBoNguon.ghiPhanHoi`); `conChoDomain` (tệp `domain/` import `core/database`) **12 → 8**
   (`bill/domain/de_xuat_hoa_don.dart` hết Drift: phản hồi B2 vào domain bằng record `PhanHoiGoiYHoaDon`, nguồn `de_xuat_hoa_don_nguon` dựng); ratchet quét 25
   hạ tầng **40 → 43** (`notification_rules` 11 → 12 · `notification_scanner` 6 → 7 · `de_xuat_thong_bao_nguon` 0 → 1); quét 27 mở rộng sang `lib/core`
   (trừ `database`, `sync`; ba điểm ghép không miễn trừ) + mẫu `;` / `.fromJson` + luật 2 cấm `package:drift`; quét 2 phân loại thêm **6** chỗ
   đọc mọi ví; `WalletEntity` 147 dòng, `TransactionEntity` 153 dòng; `conChoKieu` còn `Category` 20 tệp + `AppNotification` 9 tệp. `flutter test`
   7.057 → **7.065** (9 skip, 0 fail ở `3252db88`; **10** skip từ `692c7091` — tệp đo chạy tay), `flutter analyze` **20**. **Nghiệm thu máy ảo ✅ đạt:** bản trước `b0164475…` (`lastUpdateTime` 14:05:48) ↔ bản sau `94394e4c88b237b2010a04b7c4a82a51cc73c7d9` (HEAD `84628ee1`, `lastUpdateTime` 21:29:25); **24 cặp ảnh**, cắt 100 px thanh trạng thái: **22/24 cặp 0 px khác**; 2 cặp lệch, không cặp nào do mã — (1) `20_ns_chi_tiet` 997 px, do thời gian: số *"Theo thời gian đã trôi"* tính theo `DateTime.now()` (22.403 đ lúc 21:21, 22.416 đ lúc 21:33 = 50.000 × ngày trôi / 31; +13 đ ≈ 11,5 phút × 1,12 đ/phút); (2) `22_pt_du_bao` 2 px, nhiễu vẽ: hai điểm khử răng cưa trên nét đứt *"Theo ngân sách"*, mọi px khác kể cả số cuối đường bằng 0. Vàng thuần `#FFFF00` **0** trên cả 24 ảnh sau. Nhập nhanh (đo lại có ảnh `nn2_1…3`): chọn **Ví MoMo** ở bảng chọn ví (ảnh xác nhận ví ≠ Tiền mặt), gõ `45k tien mat` (ví vẫn MoMo, số tiền 0 đ), bấm Điền → ví **Tiền mặt**, số tiền 45.000 đ, dòng *"Đã điền: 45.000 đ · Tiền mặt"*; KHÔNG Lưu, thoát bằng Back. `fromDrift` toàn sổ (`test/tool/do_from_drift_test.dart`, `692c7091`): **92 hàng · trung vị 0,028 ms** / 20 lượt (nhỏ nhất 0,026, lớn nhất 0,652) ≈ 0,3 µs mỗi hàng — không đáng tối ưu. Hai lỗ: màn Gắn danh mục (C1) không chụp được — 4 hàng sống không danh mục (ngoài chuyển khoản) đều là ghi chú máy (*Tích lũy…*, *Điều chỉnh số dư*, *Số dư ban đầu*) nên `demChuaGan` = 0, muốn có màn phải ghi dữ liệu (cấm); thẻ gợi ý danh mục ở màn Thêm giao dịch không có ảnh. Ảnh ở scratchpad, không vào repo. Commit: tệp đo `692c7091`, tài liệu `14e9284c` + vòng sửa sau. Hai đợt còn lại: Danh mục → Thông báo.
   ~~⚠️ **Nợ có tên, lối thứ 5 bị giấu (lượt soát cuối 2026-10-14, người dùng chốt ghi lại, sửa ở đợt sau):** `GoalRepository.watchGoalTransactions` (`goal_repository.dart:214`, impl `:665`) khai `Stream<dynamic>` nhưng trả `transactionDao.watchByGoal` — hàng Drift `Transaction` — lên `goal_detail_page.dart` (`_doiSangKhoan` đọc động) và `khoi_lich_su_muc_tieu.dart` (`List<dynamic> txs`); có từ trước đợt (≈ 2026-08-12). **Lỗ của quét 27:** luật 1 chỉ bắt tên kiểu — không thấy `dynamic`, và không quét repository / domain theo tên kiểu. Đề xuất cho đợt sau: repository trả `Stream<List<TransactionEntity>>`, hai widget nhận kiểu rõ.~~ ✅ **đóng 2026-10-15** (`406c20c6`; luật 3 của quét 27 canh lớp lỗ `<dynamic>`).
   📝 **2026-10-15 — đợt 3 (Danh mục + hai nợ Mục tiêu + `ghiPhanHoi`): spec duyệt** `specs/2026-10-15-entity-danh-muc-design.md` (`ec3e6e0a`;
   trạng thái `df1917d8`; sửa đường test rows `c62bc372`) + kế hoạch 7 task `plans/2026-10-15-entity-danh-muc.md` (gitignore), **chưa thi công**
   (người dùng chọn bàn giao). Chốt trong brainstorm: gộp cụm phản hồi tái phân bổ (`PhanHoiTaiPhanBo` lớp thuần 11 trường ở `ai_edge/domain`,
   `TaiPhanBoNguonImpl.ghiPhanHoi` dựng Companion — chỗ duy nhất) và **cả hai** nợ Mục tiêu (`watchGoalTransactions → Stream<List<TransactionEntity>>`,
   hai widget bỏ 8 + 1 phép ép; runner dời `goal/data/services/`, tiền lệ `BillAutoPayRunner`) → sau đợt lối chuyển tiếp **0**, `conChoDomain` **rỗng**,
   Entity **6/14**; `CategoryEntity` 13 trường chỉ đọc (18 cột − 5: `isLocalOnly` · `deletedAt` · ba cột lỗi đồng bộ), `Equatable` **bắt buộc**
   (`DropdownButton<…>` ở Thêm / Sửa hoá đơn so `value` bằng `==`), không `toCompanion` (đường ghi đã qua hai draft); `watchAllRows → watchAll`,
   `getRowById → getById`, **`loadBangTraTen` giữ tên** (nghĩa G41); quét 27 thêm **luật 1 quét `features/*/domain/` theo tên kiểu** (ba sàn đếm
   206 · 77 · 164) và **luật 3** cấm `(Stream|Future|List|Iterable)<dynamic>` ở `features/*/data` (lỗ đã giấu `watchGoalTransactions`), chữ *"đã thống
   nhất Entity"* → *"không có chỗ chờ trong phạm vi quét"*; Task 3 **một commit** đổi kiểu (~45 `lib` + ~45 test — Dart không cho hai hàm cùng tên khác
   kiểu trả sống cạnh nhau), canh bằng script chuẩn hoá diff; hai lời gọi `sl<CategoryManagementRepository>().watchAll(` phải nằm **một dòng** (quét 2
   loại theo chuỗi từng dòng). ⚠️ Chốt *"ghi một khoản thử qua giao diện để chụp C1"* **lật khi soát**: `ThemGiaoDichCubit.chuanBiLuu` :631 từ chối lưu
   thu / chi thiếu danh mục, form Sửa cùng cubit — app không có lối tay sinh khoản không danh mục; nghiệm thu máy ảo **không ghi dữ liệu**, nhận lỗ C1
   như đợt 2. Đo 2026-10-15: `presentation` cầm `Category` 20 tệp · domain 6 · 7 interface / nguồn đổi chữ ký · 11 tệp test dựng `Category(` tay.
   ✅ **2026-10-15 — đợt 3/4 (Danh mục + hai nợ Mục tiêu + `ghiPhanHoi`) ĐÓNG** (6 commit mã, thi công bằng agent con mỗi task, mọi task qua soát không
   phát hiện lỗi Quan trọng; nhánh `TranQuangDat`, đã push tới `fce511a1`): Task 1 `f443a647` quét 27 mở rộng (luật 1 quét cả `domain/` theo tên kiểu, ba sàn đếm,
   luật 3 cấm `<dynamic>` trần ở `features/*/data`) · Task 2 `34f54ec9` `CategoryEntity` (`category/data/models/category_entity.dart`, 83 dòng, 13 trường chỉ đọc,
   `Equatable`) · Task 3 `2e04954d` đổi kiểu trục Danh mục, **một commit** 87 tệp (41 `lib` + 46 `test`); `watchAllRows → watchAll`, `getRowById → getById`,
   `loadBangTraTen` giữ tên · Task 4 `3cfaed55` `PhanHoiTaiPhanBo` lớp thuần, `TaiPhanBoNguon.ghiPhanHoi` dựng Companion (chỗ dựng duy nhất:
   `budget/data/tai_phan_bo_nguon.dart`; tên `AiRebalancingFeedbacksCompanion` còn trong một docstring `ai_edge/domain/ap_dung_ke_hoach.dart`) · Task 5 `406c20c6`
   `watchGoalTransactions → Stream<List<TransactionEntity>>`, bỏ 9 phép ép + 2 `?? ''` · Task 6 `811e1ea8` `goal_auto_deposit_runner` dời `goal/data/services/`.
   Đo bằng máy 2026-10-15 (HEAD `811e1ea8`): lối chuyển tiếp trả hàng Drift **4 → 0**; `conChoDomain` **8 → rỗng**; `conChoDynamic` **rỗng**; `conChoKieu` chỉ còn
   `AppNotification` (9 tệp); Entity **6/14** mảng; ratchet quét 25 **43 giữ**, TOTAL import `features/` trong `core` **185**; `flutter test` 7.065 → **7.069** pass / **10** skip
   (entity +2 · quét 27 +1 · test rows 2 → 3 · Companion 0 ca mới), `flutter analyze` **20**. **Nghiệm thu máy ảo ✅ đạt** (`FlowMoney_16G`, 1080×2400): bản trước
   `94394e4c…` (`lastUpdateTime` 2026-10-14 21:29:25) ↔ bản sau `d3b7b9083a981c80110e8228eba5f200d4354562` (`lastUpdateTime` 2026-10-15 12:09:02); **29 cặp ảnh**, cắt 100 px
   thanh trạng thái: **27/29 cặp cùng SHA-1 (0 px)**; hai cặp lệch (`17_hoa_don_them_cuon` 165.749 px, `18_hoa_don_dropdown` 80.738 px) do cuộn giữ-rồi-thả dừng lệch **1 px** theo
   chiều dọc, nội dung / màu / chữ giống hệt (danh sách 10 mục dropdown giống hệt) — không phải thay đổi giao diện. Vàng thuần `#FFFF00` **0**. Kiểm chức năng bổ sung bản sau (không ghi dữ liệu): chip lọc
   danh mục ở Sổ giao dịch (chọn *Giải trí* → 3 giao dịch, *Xoá lọc*) đạt; thẻ *Gợi ý danh mục* ở Thêm giao dịch (78.000 đ + ghi chú `food` → *Ăn uống*) đạt; `pop<CategoryEntity>` của form
   đạt; logcat 0 dòng `FATAL` / `is not a subtype`. ⚠️ Hai lỗ còn mở: *Đề xuất cân đối ngân sách* (5g) không hiện (dữ liệu không đủ điều kiện) và C1 / thẻ *"Có N giao dịch chưa có danh mục"*
   (`demChuaGan` = 0, cấm ghi dữ liệu; chốt *ghi khoản thử* đã lật vì `chuanBiLuu` chặn lưu thiếu danh mục) — C1 phủ bằng `gan_danh_muc_page_test` (11 ca), `gan_danh_muc_nguon_test` (5), `gan_danh_muc_nguon_lop_test` (2).
   Ảnh ở scratchpad, không vào repo. Còn **một đợt**: Thông báo.
   📝 **2026-10-15 — đợt 4/4 (Thông báo) + gạch 5 + gạch 6: spec duyệt** `specs/2026-10-15-entity-thong-bao-application-design.md` (`b8f17510` +
   `2c24c990`) + kế hoạch 8 task + Task 0 `plans/2026-10-15-entity-thong-bao-application.md` (gitignore), thi công bằng agent con mỗi task
   (Fable preflight · Sonnet thực thi · Opus soát; preflight bắt 5 CHẶN — `tha_vi_bi_giu` về `wallet/data/` thay vì `application/`, hai lớp `*Event` theo spec 7.1
   không `export`). Chốt trong brainstorm: Entity và gạch 5 một spec; `NotificationEntity` 14 trường (bỏ cột chết `osScheduledId`); `ThongBaoRepository` + Impl tách
   tệp thay `ThongBaoNguon`; `chenLai(Entity)` thay `insertIfAbsent(Companion)`; record `SuKienNhatKy` cho `deXuatThongBao`; quét 27 thêm `AppNotificationEvent`,
   luật 3 quét `application/`, luật 4 (interface repository không import Drift), `mauKieu` bắt `is X &&`. Đo trước thi công 2026-10-15: `core/notification`
   35 tệp / 6.869 dòng, 26 tệp lib + 22 test ngoài mảng import; `ThongBaoNguon` 10 lib + 7 test (từ trọn).
   ✅ **2026-10-15 — đợt 4/4 (Thông báo) + gạch 5 + gạch 6 ĐÓNG** (bảy commit mã, thi công bằng agent con mỗi task, mọi task qua soát Opus không lỗi Quan trọng;
   nhánh `TranQuangDat`, đã push tới `fce511a1`; spec khối ✅ *"Số đo sau thi công"* + *"Nghiệm thu máy ảo"*): Task 1 `73429f46` quét 27 (luật 4, `conChoKieu` mở rộng sang
   `AppNotificationEvent`) · Task 2 `362ae94a` `NotificationEntity` (`notification/data/models/notification_entity.dart`, **92** dòng, 14 trường) + `companionTu` ·
   Task 3 `2cb1c00f` `ThongBaoRepository` + `ThongBaoRepositoryImpl` (`data/repositories/`, interface **26** dòng) thay `ThongBaoNguon`, hai trang nhận Entity, `chenLai` ·
   Task 4 `5e19895d` ba hàm `hang*` và `deXuatThongBao` nhận `NotificationEntity`, record `SuKienNhatKy`, bộ quét / nguồn đề xuất map tại chỗ ·
   Task 5 `28d0a2f3` hai lớp `*Event` về `goal/domain/goal_auto_deposit.dart` · `bill/domain/bill_auto_pay.dart` (**theo spec 7.1, runner KHÔNG `export` lại** — lệch (a)
   của kế hoạch không giữ; kế hoạch có câu "qua `export`" là sai với mã), `budget_health` tách khỏi widget → `budget/domain/`, engine gợi ý → `category/domain/`,
   `so_du_vi_service` → `wallet/data/` · Task 6 `d95674ef` **gạch 5**: dời **34** tệp `core/notification` — **31** về `features/notification/{domain 10 · data/datasources 10 ·
   data 3 · application 8}` (thư mục nay domain 11 · data 17 · application 8, gồm tệp có sẵn / mới của Task 2–3) + **ba** tệp hạ tầng về `core/nen` · `core/ocr` · `core/utils` —
   39 test soi gương (lệch (b) của kế hoạch: 34 tệp chứ không 35) ·
   Task 7 `08effea7` **gạch 6**: `data/services/` → `application/` ở ví, danh mục, hoá đơn, mục tiêu (9 tệp + 3 test), quét 25 luật 7. Đo bằng máy 2026-10-15
   (HEAD `08effea7`): `core/notification` **không còn**; `find lib/features -path "*/data/services/*"` **0**; `ThongBaoNguon` **0 dòng mã** (ba dòng chú thích dạng *"trước là …"*:
   DI `:468`, `thong_bao_repository.dart:4`, test cổng `:2`); tệp `data/` · `domain/` import `application/` **0**; interface repository (**11** tệp) import Drift /
   `core/database` **0**; `AppNotification` / `AppNotificationEvent` ngoài `core/database`, `core/sync` **0** ở `presentation/` · `domain/` · `shared/` · `lib/core` (còn
   `notification_entity.dart:58` `fromDrift` và typedef `_HangCo` ở `application/nhap_bien_lai.dart:87` — `data/` · `application/` được cầm DAO); quét 27 **bốn** luật, `conChoKieu`
   **rỗng** (cả ba danh sách chờ rỗng); quét 25 **bảy** luật; ratchet `conChoCoreImport` đo **43 → 47 (Task 4, Luật tăng) → 45 (Task 5) → 18 (Task 6)**, **7** mục;
   TOTAL `lib/core` import `features/` **184** = điểm ghép **166** (DI 107 · router 54 · `chay_nen` 4 · `phien_dieu_phoi_that` 1) + hạ tầng **18**; `lib/core` **15** chủ đề;
   `features/notification` **48** tệp `.dart`; `application/` **17** tệp (thông báo 8 · ví 4 · danh mục 2 · hoá đơn 2 · mục tiêu 1; `tha_vi_bi_giu` ở `wallet/data/` vì datasource gọi — luật 7);
   Entity **7/14**. `flutter test` 7.069 → **7.075** pass / **10** skip, `flutter analyze` **20** (`MUC_NEN` không đổi). **Nghiệm thu máy ảo ✅ đạt** (`FlowMoney_16G`, 18 màn):
   bản trước `d3b7b908…` (`lastUpdateTime` 15:51:49) ↔ bản sau `adedaef848dfc4a321b663945e948abe023a0607` (`lastUpdateTime` 19:45:37); cắt 100 px thanh trạng thái:
   **11/18 cặp cùng SHA-1 (0 px)**, **7** cặp lệch đều giải thích được — số chuông 26 → 25 (ảnh *trước* 01 chụp trước một lần gỡ mềm, không chụp lại), giờ tương đối thẻ đầu
   *"4 → 8 giờ trước"* (03 · 04 · 07 · 08, 1.367 px), toast *"Đã đánh dấu đã đọc"* ở khung mờ khác (06), form Thêm giao dịch cuộn lệch vì toạ độ chạm ô ghi chú
   khác (18, không lệch chức năng); vàng thuần `#FFFF00` **0**; logcat **0** dòng `E/flutter`, bộ quét chạy 3 lượt, `badge=` 25 → 24 → 25 → 24 → 25 đúng theo vuốt-hoàn tác và nhấn giữ.
   ⚠️ **Lỗ nghiệm thu (máy ảo không có dữ liệu)**: *Hoàn tác* xoá cứng hàng D1 (`chenLai`) → `thong_bao_repository_test` (4 ca) + `notification_entity_companion_test` (2);
   nhập biến động / biên lai / phiên ngân hàng → `nhap_bien_dong_test` (32) · `nhap_bien_lai_test` (25) · `nhap_phien_ngan_hang_test` (16); chạy nền →
   `notification_scanner_lich_nen_test` (3). ⚠️ **Tham chiếu cũ còn lại, biết và để nguyên** (Kotlin ngoài phạm vi): chú thích
   `MainActivity.kt:42` · `:48` và `PhienNganHang.kt:43` vẫn nêu `lib/core/notification/…` (các `*_noi_day_test` chỉ so hằng nên không hỏng im lặng); và
   `notification_table.dart:73` (chú thích cột `osScheduledId`, `core/database` ngoài phạm vi); và `docs/Notification/Notification_Client-app.md:4, 52, 291` (tài liệu backend — vùng chỉ đọc, quy tắc 1; cần đơn CAN-LAM nếu muốn sửa). Ảnh / log ở scratchpad, không vào repo. **G88 gạch 3 xong cả bốn đợt.**
4. ✅ **ĐÓNG 2026-10-16 (xem khối ✅ cuối mục này)** — ~~**18 dòng (7 tệp) hạ tầng `core` import `features/`**~~ — ~~43 dòng~~ tới 2026-10-15 (đo lại 2026-10-15 sau đợt Danh mục: TOTAL **185**, ratchet **43 giữ**, không đổi; đo 2026-10-14 sau đợt Giao dịch + Ví bằng `grep -rcE "^(import|export) .*features/" lib/core` = 185; trừ điểm ghép 142 — DI
   87 · router 53 · `chay_nen` 2; ảnh chụp sau đợt Hoá đơn là 182 = 142 + 40; đo 2026-10-10 là 175 = 138 + 37, trước đợt dọn vị trí tệp 172 = 136 + 36)): `notification_rules` 12
   · `sync_engine` 7 · `notification_scanner` 7 · `lich_nen` 4 · `de_xuat_thong_bao_nguon` 1 · `sync_payload_normalizer` 2 · `noi_bo_nghe_ket_qua_day` 2
   · `reminder_scheduler` 2 · `nhap_bien_lai` 2 · `kho_anh_quet`, `nhap_bien_dong`, `wallet_dao`, `other_daos` mỗi tệp 1.
   ✅ Từ 2026-10-10 có **ratchet** ở test quét 25: 13 tệp này nằm trong `conChoCoreImport` chỉ-được-giảm (`sync_engine` 7
   vì `bill_recurrence` về `features/bill/domain`; 13 tệp sau đợt Giao dịch + Ví); con số nay **43**. ✅ **2026-10-14 (đợt Entity Hoá đơn) nâng ba số đúng +1**: `notification_rules` 10 → 11, `notification_scanner` 5 → 6, `lich_nen` 3 → 4 — vì thay kiểu Drift `Bill` (không tính) bằng `BillEntity` của chính mảng `bill` mà tệp ấy đã import; về 0 ở gạch 5. *(Câu luật tăng viết hôm ấy — "chỉ khi Entity của chính mảng đã import" — đã viết lại, xem câu kế.)* ✅ **2026-10-14 (đợt Entity Giao dịch + Ví) nâng thêm +3**: `notification_rules` 11 → 12, `notification_scanner` 6 → 7, mục mới `de_xuat_thong_bao_nguon` 0 → 1 (tổng 40 → **43**; đếm thật bằng máy 12 · 7 · 1) — luật ví và nguồn B5b nhận `WalletEntity` / `TransactionEntity`, mảng `wallet` / `transaction` mà hai tệp đầu chưa từng import. **Luật tăng (viết lại): tăng chỉ khi thay một kiểu Drift bằng Entity trong lộ trình G88 gạch 3; không bao giờ vì ghép một mảng mới vào `core` — ba số ấy về 0 ở gạch 5.**
   📝 **2026-10-11 người dùng chốt: gạch 4 + 5 là MỘT đợt, làm sau hướng A (gạch 3).** Phân nhóm đo cùng ngày: thông báo 20
   dòng (`notification_rules` · `notification_scanner` · `reminder_scheduler` · `nhap_bien_lai` · `nhap_bien_dong`) + `lich_nen`
   3 → hết khi dời `core/notification` sang `features/notification/` (gạch 5); đồng bộ 11 — 6 dòng là hằng số thuần (trạng thái
   / loại ví, trạng thái hoá đơn, chu kỳ, ưu tiên → hợp thức hoá thành luật *"core được đọc hằng số thuần của mảng"*), 5 dòng gọi
   dịch vụ ví / hoá đơn (`so_du_vi_service`, `tha_vi_bi_giu`, `vi_trung_ten_nguon`, hai resolver ở `noi_bo_nghe_ket_qua_day` →
   tiêm hook qua DI như `PhienDieuPhoiThat`); DAO 2 hằng số SQL (luật trên); `kho_anh_quet` 1 (dời hàm). Đợt ấy cần nghiệm thu
   thông báo trên máy thật — vùng nhiều bẫy hỏng im lặng.
   ✅ **2026-10-15 (đợt Thông báo + gạch 5, `d95674ef`) — còn 18 dòng / 7 tệp, ratchet 43 → 47 → 45 → 18**: đo bằng vòng `for` + `grep -cE "^(import|export) .*features/"` từng tệp
   (HEAD `08effea7`): TOTAL **184** = điểm ghép **166** (DI 107 · router 54 · `chay_nen` 4 · `phien_dieu_phoi_that` 1 — từ nay **bốn** tệp ghép) + hạ tầng **18**: `sync_engine` 7 ·
   `lich_nen` 4 · `noi_bo_nghe_ket_qua_day` 2 · `sync_payload_normalizer` 2 · `other_daos` 1 · `wallet_dao` 1 · `kho_anh_quet` 1. Bảy mục thông báo (`notification_rules` · `notification_scanner`
   · `reminder_scheduler` · `nhap_bien_lai` · `nhap_bien_dong` · `de_xuat_thong_bao_nguon` · `hoc_gio_thong_bao`) rút hết khỏi `conChoCoreImport` ở Task 6 (+4 ở Task 4 theo Luật tăng khi
   Drift → `NotificationEntity`, −2 ở Task 5 khi hai lớp `*Event` về `domain/`). **18 dòng còn lại là gạch 4** — đồng bộ 11 (6 hằng số thuần + 5 dịch vụ) · DAO 2 · `lich_nen` 4 · `kho_anh_quet` 1; chưa làm.
5. ✅ **ĐÓNG 2026-10-15** — ~~**`core/notification` (35 tệp) là một mảng nghiệp vụ nằm trong `core`**~~ (nay `features/notification/`) — luật của 20 loại thông báo, bộ quét, nhập biến động /
   biên lai / phiên ngân hàng. Chỗ đúng là `features/notification/{data,domain}`; giao diện đã ở `features/notification/presentation`.
   Cổng `ThongBaoNguon` (đợt này) đặt tạm ở `core/notification` cùng lý do.
   ✅ **2026-10-15 — gạch 5 ĐÓNG** (Task 6 `d95674ef`, thi công bằng agent con): `core/notification` **không còn**. **34** tệp `git mv`: **31** về `features/notification/{domain 10 · data/datasources 10 · data 3 · application 8}`
   (thư mục nay: domain 11 · data 17 · application 8 — gồm tệp có sẵn / mới của Task 2–3) và **ba** tệp hạ tầng về `core/nen/app_lifecycle_watcher` · `core/ocr/ten_tep_bien_lai` · `core/utils/tuan_iso`; 39 test soi gương;
   import tính lại bằng script (300 cặp, chỉ phần trong nháy đổi), 7 chỗ sửa tay (chuỗi đường dẫn trong test `*_noi_day`, quét 2…); `lib/core` còn **15** chủ đề (quét 25 `chuDeCore`),
   `features/notification` **48** tệp `.dart`; `phien_dieu_phoi_that` vào `diemGhep`. Kế hoạch ghi 35 → 34 + một tệp mới nên số đúng là **34**. Cổng nay là `ThongBaoRepository`
   (bảng thông báo vẫn **cục bộ** — quy tắc 9). ⚠️ Biết và để nguyên: chú thích Kotlin `MainActivity.kt:42` · `:48`, `PhienNganHang.kt:43` còn nêu `lib/core/notification/…`.
6. ✅ **ĐÓNG 2026-10-15** — ~~**`data/services/` là tầng application chưa có tên**~~ (nay `features/<x>/application/`) — ở ví (`so_du_vi_service`, `gop_vi_service`, `dieu_chinh_so_du_service`,
   `vi_trung_ten_resolver`, `tha_vi_bi_giu`, `default_account_data_initializer`), hoá đơn (`bill_payment_conflict_resolver`),
   danh mục (`default_category_seeder`, `personal_default_categories`, `category_suggestion_engine`). Nếu cần tầng thứ tư thì **đổi tên thư mục**, không thêm tầng mới (người dùng hỏi 2026-10-10, trả lời: không).
   📝 **2026-10-11 người dùng chốt: ĐỔI TÊN thư mục** (vẫn không thêm tầng), ghép vào đợt gạch 4 + 5; tên cụ thể (vd.
   `application/`) chốt ở spec đợt ấy — dời tệp bằng script, sửa luật mục 8 `KIEN_TRUC_CLIENT_APP.md` và test quét 25.
   📝 **2026-10-15 người dùng chốt tên `features/<x>/application/`** (ngang `data` · `domain` · `presentation`; **chiều một hướng**: `data/` và `domain/`
   không import `application/` — quét 25 luật 7 mới) trong spec đợt 4/4 gạch 3 (mục 3), ✅ **thi công xong cùng ngày** (Task 7, `08effea7`).
   ⚠️ Preflight 2026-10-15 chạy thử bảng dời: `tha_vi_bi_giu` còn được `wallet/data/datasources/wallet_local_data_source.dart:9` gọi → luật 7 đỏ nếu
   vào `application/`; phán quyết: về `wallet/data/` (như `so_du_vi_service`), `application/` còn **17** tệp. Đo trước khi chốt: 3 repository impl
   (hoá đơn, mục tiêu, giao dịch) gọi `so_du_vi_service` và `transaction/domain/doc_cau_giao_dich` gọi `category_suggestion_engine` → hai tệp ấy **không**
   vào `application/`: `so_du_vi_service` ở lại `wallet/data/` (bộ ghi `balance` bọc DAO), engine về `category/domain/` (thuần). 10 tệp còn lại + 8 tệp
   Thông báo = 18 tệp `application/`.
   ✅ **2026-10-15 — gạch 6 ĐÓNG** (Task 7 `08effea7`, thi công bằng agent con): `data/services/` → `features/<x>/application/` ở **ví** (`default_account_data_initializer` ·
   `dieu_chinh_so_du_service` · `gop_vi_service` · `vi_trung_ten_resolver`), **danh mục** (`default_category_seeder` · `personal_default_categories`), **hoá đơn**
   (`bill_auto_pay_runner` · `bill_payment_conflict_resolver`), **mục tiêu** (`goal_auto_deposit_runner`) — 9 tệp + 3 test; cùng gạch 5, thông báo có 8 tệp `application/`.
   Đo 2026-10-15: `application/` **17** tệp (8 + 4 + 2 + 2 + 1); `tha_vi_bi_giu` ở `wallet/data/` (datasource gọi — luật 7) cùng `so_du_vi_service`
   (7 lib + 9 test import, +1 chuỗi đường dẫn ở `so_du_mot_noi_ghi_test`); `category_suggestion_engine` ở `category/domain/`; `budget_health` ở `budget/domain/`;
   `data/services/` **0** tệp. Quét 25 **luật 7** — `data/` và `domain/` không import `application/` (0 tệp vi phạm), `tangMang` có `application`, `diemGhep` có
   `phien_dieu_phoi_that.dart`. Dòng "Thông báo = 18 tệp" ở trên là con số **trước** phán quyết C2 (`tha_vi_bi_giu` về `data/`) — số đúng là **17**.
7. ~~**Vị trí tệp lệch luật mục 8 `docs/KIEN_TRUC_CLIENT_APP.md`**~~ ✅ **đóng 2026-10-10** (spec
   `docs/superpowers/specs/2026-10-10-don-vi-tri-tep-theo-luat-design.md`, thi công bằng agent con mỗi task, 12 task):
   `current_account` → `auth/presentation/bloc/`; `dem_nguoc_xoa` → `auth/domain/`; `buoc_dang_xuat` **ở lại** `core/auth`
   (kiểu thuần bốn tệp hạ tầng dùng — thành hàng luật); hai repository gộp (`transaction_repository`,
   `category_management_repository`) tách `_impl`; 5 repository (analytics 4, premium 1) về `data/repositories/`; bảy tệp
   rời dưới `presentation/` (⚠️ chỉ **ba** là trạng thái thật — `an_the_cho_xoa`, `an_nhac_het_han`, `an_nhac_vi_trung_ten`
   → `state/`; `co_quyen`, `phien_goi_tu_auth` là hàm đọc Bloc → `bloc/`; `xac_nhan_dang_xuat`,
   `huy_yeu_cau_xoa` là hộp thoại / hành động → `widgets/`); `premium/presentation/cubit/` → `bloc/`; `core/bill` →
   `bill/domain/` (quyết định người dùng; `sync_engine` import features 6 → 7); `category_classify` → `category/domain/`,
   `category_visuals` (import Flutter) → `category/presentation/widgets/`; router → `core/router/`; `spike_sql` gỡ,
   `spike_c4` miễn trừ tới sau C4; 2 test ở gốc `test/` + `no_overflow_test` soi gương, `widget_test` (placeholder ở gốc) xoá.
   Tổng: 19 tệp dời + 2 tách + 11 test dời. **Test quét 25** `test/core/ui/vi_tri_tep_theo_luat_test.dart` canh sáu luật,
   `conCho` rỗng. Đo sau đợt (HEAD `e2ab224c`): `flutter test` **6617/6617** (+9 skip), `flutter analyze` **20**; `core`
   import `features/` 175 = điểm ghép 138 + hạ tầng 37 (gạch 4).

✅ **Đã quyết 2026-10-10 (người dùng): form Thêm / Sửa hoá đơn KHÔNG cho chọn nhóm danh mục.** Đợt tái cấu trúc từng giữ
nguyên dropdown phẳng gồm cả hàng nhóm (`isGroup`, phán quyết R8 qua lối `getCategoryRows`); người dùng chốt đó là sai —
hai form nay đọc `selectableChildren(classify: 'chi')` như màn Thêm giao dịch, và lối `getCategoryRows` của repository
đã gỡ. Hoá đơn cũ đang gắn vào một nhóm: mở form Sửa thì ô danh mục **trống** và nút Lưu đòi *"Vui lòng chọn danh mục"* —
không lưu lặng lẽ (ca test ở `bill_edit_page_test`).

✅ **2026-10-16 — gạch 4 + quét 28 ĐÓNG, G88 ĐÓNG** (spec `specs/2026-10-15-g88-gach-4-va-quet-28-design.md`; 18 dòng / 7 tệp hạ tầng `core` → `features/` còn **8** dòng /
4 tệp, cả tám trỏ vào **năm tệp domain thuần** hợp thức hoá bằng danh sách CỐ ĐỊNH thay ratchet). Commit: Task 1 `48bba881` quét 28 (`core/ui/domain_khong_import_tang_tren_test.dart`, danh sách chờ
năm tệp) · Task 2 `592cc0f4` `pickHomeBudget` → `budget/domain/pick_home_budget.dart` · Task 3 `ee05046e` `DongDanhMuc` / `ThongKeKy` / `DongChiBatThuong` → `analytics/data/models/thong_ke_ky.dart`,
`LuaChonLoc` → `analytics/data/models/lua_chon_loc.dart` · Task 4 `62392229` `KhoAnhQuet` → `features/transaction/data/datasources/kho_anh_quet.dart` · Task 5 `8368815f`
`noiBoNgheKetQuaDay` → cuối `core/di/injection_container.dart` (tệp `core/sync/noi_bo_nghe_ket_qua_day.dart` xoá) · Task 6 `9e9df270` cổng `CongSoDuVi` (`core/sync/cong_so_du_vi.dart`) và `CongViBiGiu` /
`BanGhiGiuKhoiDay` (`core/sync/cong_vi_bi_giu.dart`); bản thật `SoDuViService implements CongSoDuVi`, `ViBiGiuDongBo` (`features/wallet/data/vi_bi_giu_dong_bo.dart`); `SyncEngine` nhận hai cổng
**BẮT BUỘC**; helper test `taoSyncEngineThu` (`test/helpers/sync_engine_thu.dart`, mặc định bản thật) cho 32 chỗ dựng + 4 lớp con · Task 7 `9f0c4960` + `e56d22ef` `mocTuTraNen`
(`bill/domain/moc_tu_tra_nen.dart`) · `mocTrichNen` (`goal/domain/moc_trich_nen.dart`) · `gopLichNen` (`core/nen/lich_nen.dart`, thay `lichNenKeTiep`), DI chọn phần theo quyền gói · Task 8 `4b7740a3` quét 25
luật 5 từ ratchet `conChoCoreImport` → danh sách cố định `domainThuanChoCore` (`wallet_status` · `wallet_type` · `bill_pay_status` · `bill_recurrence` · `uu_tien_hop_le`) + luật 5b canh
chúng thuần; quét 25 nay **tám** luật. Đo bằng máy 2026-10-16 (HEAD `4b7740a3`): `lib/core` import `features/` **178** = điểm ghép **170** (DI 111 · router 54 · `chay_nen` 4 ·
`phien_dieu_phoi_that` 1) + hạ tầng **8** (`sync_engine` 4 · `sync_payload_normalizer` 2 · `wallet_dao` 1 · `other_daos` 1), trước đợt 184 = 166 + 18; `features/*/domain` import `presentation/` /
`data/` ngoài `data/models/` **0** (quét 28, `conCho` rỗng; 178 tệp domain). `flutter test` 7.075 → **7.085** pass / **10** skip (đo ở `36180d62` — lượt sửa sau review toàn nhánh
thêm 3 ca; tại `4b7740a3` là 7.082), `flutter analyze` **20** (không đổi).
**Nghiệm thu máy ảo ✅ đạt** (15 cặp ảnh trước/sau): 3 cặp giống hệt, phần còn lại lệch giải thích được (ngày 15 → 16/10 đổi số ngày còn lại và nhịp chi, toast đồng bộ khi backend tắt, cuộn lệch vài px),
vàng `#FFFF00` = 0, `E/flutter` = 0, `SyncEngine` khởi động, app không chết lúc mở. **Lỗ nghiệm thu:** đẩy / kéo thật với máy chủ (backend tắt — phủ bằng bộ test đồng bộ engine thật); lượt nền
WorkManager thật; điều kiện quyền gói của lịch nền ở DI chỉ canh bằng ca đọc nguồn; Trợ lý AI trên máy ảo rơi về "Chưa có mô hình" (gói số `hang_tong_quan` phủ bằng test). Bước neo số dư của engine (cổng
`datNeoNhieuVi`) có thêm ca đòi kết quả từ `36180d62` (`sync_pull_so_du_vi_test`). **Nợ còn giữ có tên, không thuộc G88 (cập nhật 2026-10-16):** hai nợ nêu ở đây lúc ấy — vòng `bill/domain/bill_status.dart` ↔ `notification/domain/notification_rules.dart` và regex quét 27 còn hở — **đã trả** trong đợt nợ kiến trúc nhỏ cùng ngày (`billLeadDays` về `bill/domain/bill_nhac_truoc.dart`; quét 27 bắt thêm `is X ?` / `X(` / `export`). Bốn cặp hai chiều của cụm {analytics, bill, category, transaction} đã gỡ 2026-10-16 (ba lát, spec 2026-10-16-go-vong-mang-domain-design.md) — conCho của quét 29 rỗng; cạnh `bill/application/bill_payment_conflict_resolver.dart → notification_rules.dart` còn, cố ý.

---

### ~~G67 — Kéo về bỏ sót bản ghi lên server muộn hơn giờ ghi của nó~~ · ✅ ĐÓNG (2026-10-08, mở 2026-10-05)

**Lộ ra khi:** nghiệm thu G63 trên hai máy ảo cùng tài khoản thử 27 (2026-10-05 tối), bước 4 — Đổi tên.

**Đo được:** máy B ghi hai giao dịch lúc offline (14:43:31, 14:43:53 giờ VN); máy A kéo về lúc 14:44:27 nên mốc của A là
`07:44:27Z`; hai giao dịch lên server lúc 14:45:32 nhưng mang **giờ ghi** 14:43 → `/sync/pull?since=07:44:27Z` không bao
giờ trả chúng. Máy A: ví 0 đ, không giao dịch; PostgreSQL có đủ. Không phải lệch múi giờ — mọi bên so theo UTC.

**Gốc:** `sync.repository.js` dùng **cùng** cột `update_at` cho LWW (`:186`, giờ ghi của máy) và cho lọc kéo về (`:216`,
`gt since`); client lấy mốc = `update_at` lớn nhất vừa kéo (`SyncEngine._newestUpdateAt`). Mọi bản ghi tới server muộn
hơn giờ ghi — máy offline lâu, bị giãn cách, bị giữ — có thể rơi dưới mốc của máy khác. Mốc chỉ tiến nên **không tự lành**;
chỉ cài lại app (kéo toàn bộ) mới nhận.

**Đã làm ở client:** ca G63 — `ThaViBiGiu` làm mới giờ sửa khi thả ví bị giữ (`3544cc4`). **Không** làm mới giờ sửa cho
ca chung: giờ sửa là dữ liệu LWW của chính bản ghi, đổi nó là để bản sửa cũ thắng bản sửa mới.

**Cần backend:** cột giờ-server riêng (`Server_update_at`, đặt `now()` ở mọi lần ghi) cho sáu bảng đồng bộ; `/sync/pull`
lọc và trả theo cột ấy — đơn `docs/superpowers/backend/CAN-LAM/KEO_VE_BO_SOT_BAN_GHI_DAY_MUON.md` (mục 37). Sau đó client
đổi `_newestUpdateAt` sang `server_update_at` (rơi về `update_at` với backend cũ) và kéo lại toàn bộ một lượt.

**2026-10-07 — backend xong phần mình, nhưng CHƯA đóng được:** backend đóng mục 37 ở `main` @ `2eb3856`/`2280efb`
(migration 20: cột `Server_update_at` + chỉ mục + trigger cho sáu bảng; `/sync/pull` lọc và sắp theo cột ấy, trả `maxSince`
từng entity). Client gộp `main` @ `1edab22`, CSDL dev **áp `database/20`** cùng ngày (cho phép đích danh). Đo trên CSDL
dev (rollback): cột mang **hai đồng hồ** — INSERT qua Prisma lưu UTC, UPDATE bị trigger ghi `CURRENT_TIMESTAMP` theo giờ
phiên `Asia/Bangkok` (**+7 tiếng**). Client lấy mốc theo giờ server hôm nay là **mất** hàng chèn trong khoảng 7 tiếng —
G67 tái hiện với nguyên nhân khác. Đơn mới `CAN-LAM/SERVER_UPDATE_AT_HAI_DONG_HO.md` (mục **40**). Thứ tự: backend sửa
đồng hồ → client lấy mốc từ `maxSince` của phản hồi (không từ `update_at` hay `server_update_at` của từng hàng), có test
canh → nghiệm thu lại hai máy như G63 → đóng G67. Trong lúc chờ, client **không đổi gì**: mốc vẫn theo `update_at`, nên
hệ quả duy nhất là hàng vừa sửa bị kéo lại thừa trong 7 tiếng.

**2026-10-08 — backend sửa đồng hồ, client đổi mốc, CHƯA đóng:** gộp `main` @ `0eb4a05f` (đơn 40 đóng bằng migration
**21**: trigger + DEFAULT `Server_update_at` về `(now() AT TIME ZONE 'UTC')`). CSDL dev **áp 21–23** cùng ngày (cho phép
đích danh): 4 hàng mang mốc "tương lai" kéo về; thử UPDATE rollback lệch trigger **0 s** so với UTC. Client:

- Mốc mới là **`mocTuMaxSince`** (`core/sync/moc_keo_ve.dart`) đọc `maxSince` + `pulledAt` của phản hồi — **lớn nhất**
  giữa các bảng, kẹp về `pulledAt − 2 phút` khi dữ liệu còn nóng (server kéo sáu bảng tuần tự, không giao tác: hàng ghi xen
  giữa hai truy vấn, hàng commit muộn hơn giờ ghi, bảng 0 hàng không có khoá — đều mang giờ gần `pulledAt`), +1 ms khi đã
  nguội (giờ-server lưu µs, JSON mang ms — không cộng thì hàng cuối bị kéo lại mọi chu kỳ). Phản hồi không có khoá
  `maxSince` (server cũ) → `_newestUpdateAt` như trước. Vẫn qua `_kepVeHienTai`.
- Khoá lưu đổi `sync_last_pull_<id>` → **`sync_last_pull_v2_<id>`**: hàng G67 từng bỏ sót mang giờ-server cũ (migration
  20 chép `Update_at` sang), nằm dưới mốc cũ — chỉ đổi luật thì chúng vẫn không về. Khoá mới làm mốc cũ vô hình →
  kéo toàn bộ **một lần** mỗi tài khoản mỗi máy.
- `ThaViBiGiu` vẫn làm mới giờ sửa (lưới cho server cũ); chú thích sửa lý do.
- Test: `moc_keo_ve_test` (7), bốn ca G67 ở `sync_checkpoint_test`, `sync_checkpoint_store_v2_test` (3); ba bản sai có
  chủ ý (lấy lớn nhất · mốc theo `update_at` · khoá cũ) đều đỏ.

**Nghiệm thu hai máy ảo (tài khoản 27, 2026-10-08) — ĐẠT, G67 ĐÓNG.** Lượt một: B chi 11.000 lúc offline (giờ ghi
13:21:46); 3 phút sau A chi 22.000, mốc của A thành `13:22:56Z`; B bật mạng → server nhận lúc 13:25:22 → A kéo về được
(lỗi cũ: bỏ sót mãi). Lượt hai trên ví Tiền mặt: B 5.000 offline (13:38:25), A 7.000, mốc A `13:39:49Z`, B bật mạng → cả
hai máy đủ hai khoản, −12.000. Lượt một lộ hai thứ, sửa cùng tối: (1) bản đầu lấy mốc **nhỏ nhất** giữa các bảng → mốc
neo vào bảng lâu không đổi (05/10), mỗi lượt kéo lại gần hết — đổi sang **lớn nhất** + kẹp, có ca canh; (2) **G85** —
neo nuốt giao dịch của máy kia ở ví seed, lỗi có từ G37.

### ~~G66 — Ngân sách bắt đầu ngày 29–31 trôi hẳn về ngày đã kẹp từ kỳ thứ hai~~ · ✅ ĐÓNG (2026-10-04, mở và đóng trong cùng ngày)

**Lộ ra khi:** lập kế hoạch *dự án C việc hai* (nhịp chi ngân sách, spec
`docs/superpowers/specs/2026-10-04-du-an-c-nhip-chi-ngan-sach-design.md`) — dựng lưới kỳ để lùi về trước ngày tạo ngân
sách. Không đến từ báo lỗi nào.

- **Đo** (test tạm, đã xoá): `BudgetEntity(startDate: 31/01/2026, Hàng tháng, lặp lại)` → `currentPeriod` cho
  31/01→28/02, rồi **28/03→28/04, 28/04→28/05, 28/05→28/06** — trôi hẳn về ngày 28. Người đặt ngày 31 mong 28/02→31/03,
  31/03→30/04, 30/04→31/05…
- **Gốc:** `BudgetEntity._anchor` = `nextTimeRecurrence ?? advancePeriod(startDate, chu kỳ)` — tức mốc **đã kẹp** (31/01
  + 1 tháng = 28/02), và mọi kỳ sau nhảy từ mốc ấy (`advancePeriodFrom(anchor: 28/02, steps: n)`). `advancePeriodFrom` tự
  nó **không** trôi (`budget_period_test`: từ 31/01 bước 2 → 31/03) — nhưng nó được gọi từ mốc đã kẹp, tức đúng cái bẫy mà
  chú thích của `currentPeriod` và đầu `budget_period.dart` nói là đã chặn.
- **Đi được qua giao diện bình thường:** form ngân sách cho tự chọn *Ngày bắt đầu* (`_startDatePicker`) và không đặt
  `nextTimeRecurrence` → chọn ngày 29, 30, 31 cho ngân sách tháng (hoặc ngày rơi vào tháng ngắn với quý/năm, như 29/02) là
  dính. Mặc định (ngày 1 của tháng) không dính.
- **Bán kính:** mọi thứ đọc `currentPeriod` — số đã chi (`spent`), lịch sử sáu kỳ của trang chi tiết (`recentPeriods`),
  dòng *"Nên chi X/ngày"*, thông báo ngân sách (khoá `budgetNear:<id>:<đầu kỳ>`), kế hoạch cân đối. Bộ test mù: ca *"các kỳ
  liền nhau"* của `budget_history_test` dùng đúng ngân sách ngày 31 nhưng chỉ kiểm kỳ **liền nhau**, không kiểm **ngày**.
- **Sửa** (`02d46ca`, phiên sau phiên phát hiện — người dùng chọn làm **trước** việc nhịp chi): **`BudgetEntity.mocKy(int
  s)`** là định nghĩa duy nhất của lưới kỳ — kỳ đầu `[startDate, mocKy(0))`, kỳ s là `[mocKy(s − 1), mocKy(s))`, s âm lùi
  về trước ngày bắt đầu. Không có `nextTimeRecurrence` thì `mocKy(s) = advancePeriodFrom(anchor: startDate, steps: s + 1)`
  — nhảy từ ngày **gốc**, nên 31/01 cho 28/02 → 31/03 → 30/04 → 31/05. Có `nextTimeRecurrence` thì lưới neo vào nó như cũ
  (`mocKy(0)` là chính nó). `currentPeriod`, `recentPeriods`, `expiresAt` cùng đi qua `mocKy`; `_anchor` và
  `periodAnchor` bỏ. `mocKy(0)` bằng mốc neo cũ nên kỳ đầu và hạn của ngân sách không lặp **không đổi**; tuần không đổi.
- **Ca test:** nhóm *"mocKy — lưới kỳ neo vào ngày bắt đầu…"* ở `budget_entity_test.dart` (ngày 31 / 30 / 29; tháng Hai
  năm thường, năm nhuận, 2100; quý từ 30/11; năm từ 29/02 về 29/02/2032; s âm; tuần; `nextTimeRecurrence`; `expiresAt`) —
  **sáu** ca đỏ khi `mocKy` mang lưới cũ; ca *"các kỳ liền nhau"* của `budget_history_test` nay kiểm cả **ngày** (đỏ trên
  mã cũ: 28/03 thay vì 31/03).
- **Dữ liệu thật không đổi gì:** đo trước khi sửa — Realme 10 ngân sách, PostgreSQL dev 12, không cái nào bắt đầu ngày
  29–31 giờ Việt Nam (mấy hàng *"31/08 17:00"* trên server là giờ UTC của 01/09). Nên không ngân sách nào đổi kỳ, `spent`
  không tính lại, khoá thông báo `budgetNear:` không đổi.
- **Giới hạn cố ý:** `nextTimeRecurrence` lưu sẵn mà chính nó đã bị kẹp (vd. 28/02) thì lưới vẫn dính ở ngày ấy — không còn
  biết ngày gốc. Client không ghi cột này; server hiện 0 hàng mang nó.

---

### ~~G65 — Dải "Đã xoá thông báo · Hoàn tác" không tự ẩn, đi theo qua mọi màn~~ · ✅ ĐÓNG (2026-10-03, mở và đóng trong cùng ngày)

**Lộ ra khi:** nghiệm thu *nhắc ghi sau khi dùng app ngân hàng* trên Realme tối 2026-10-03 — vuốt một dòng ở trung tâm
thông báo, dải *"Đã xoá thông báo · Hoàn tác"* đứng yên **hơn 7 phút**, đi theo sang Sổ giao dịch và trang chi tiết
giao dịch, đè lên nút. Người dùng: *"fix trước phần thông báo hiện nó vẫn đang hiện"*.

- **Gốc:** từ Flutter 3.47 (nâng 2026-09-19), `SnackBar` có `action` mặc định **không tự ẩn** (`persist` theo
  `action`) — `duration: 4s` bị bỏ qua. Không liên quan dịch vụ trợ năng của máy: ca tái hiện đỏ ngay trong
  `flutter test`. Đây là `SnackBarAction` **duy nhất** của app (`_xoaCoHoanTac`, `notification_center_page.dart`).
- **Sửa:** `persist: false` (`c18e095`). Ca `dải "Đã xoá thông báo" TỰ ẨN…` ở `notification_center_page_test.dart`
  đỏ trên mã cũ. Đo lại trên Realme: dải hiện ở giây 1, mất ở giây 7.
- Thêm `SnackBarAction` mới thì nhớ `persist: false` (mục 5c `NOTIFICATION_FEATURE.md`). *(Từ 2026-10-06 — E4 — app
  không còn SnackBar nào; nút Hoàn tác là `HanhDongToast` trên viên toast, tự ẩn. Test quét thứ 19 cấm SnackBar mới.)*

---

### ~~G64 — Mục "Đăng xuất" ở drawer Trang chủ không làm gì~~ · ✅ ĐÓNG (2026-10-03, mở và đóng trong cùng ngày)

**Lộ ra khi:** cùng lượt nghiệm thu (dòng 11 — đăng xuất). Bấm *Đăng xuất* ở drawer → hộp thoại xác nhận hiện → bấm
*Đăng xuất* → **không có gì xảy ra**, không log. Nút ở tab Cá nhân vẫn đúng.

- **Gốc:** luồng nằm ở `HomePage._buildDrawer` và dùng `context` của builder **bên trong drawer**: `context.pop()` đóng
  drawer là gỡ cây con của nó, nên sau hộp thoại `context.mounted == false` và lệnh đăng xuất bị bỏ qua, im lặng. Có
  sẵn từ 2026-09-19 (lượt UX thêm *Đăng xuất* vào drawer); ca test cũ dựng drawer làm `body` — không bao giờ đóng.
- **Sửa** (`c2d6985`): `DrawerTrangChu` tự đóng drawer và tự hỏi xác nhận bằng context của **Scaffold**; `onDangXuat`
  chỉ gọi khi đã đồng ý; `HomePage` đăng xuất bằng context của trang. Ca test mở drawer **thật** trong `Scaffold` (đỏ
  trên mã cũ) + ca quét nguồn cấm `xacNhanDangXuat` quay lại `home_page.dart`. Đo lại trên Realme: về màn Đăng nhập.

---

### ~~G63 — Ví trùng tên giữa hai máy cùng tài khoản: máy đẩy sau kẹt mãi, và có hai ví trùng tên~~ · ✅ ĐÓNG (2026-10-05 tối; hoãn 2026-10-03, người dùng chọn làm 2026-10-05)

> ✅ **ĐÓNG 2026-10-05 tối** — trọn 14 task của kế hoạch (`f2a2f52` → `614634f`) cộng **hai bản sửa do nghiệm thu hai
> máy ảo bắt** (`2274a1f`, `3544cc4`). Ví bị server từ chối vì trùng tên (`WALLET_NAME_DUPLICATE`) được **giữ** khỏi lô
> đẩy cùng mọi thứ dính tới nó; màn Quản lý ví có thẻ **"VÍ TRÙNG TÊN"** (màn Stitch `c5a2cece…`) với **Gộp** (hộp
> `303d12a1…`) và **Đổi tên** (hộp `5fea1834…`), nhãn **CHƯA ĐỒNG BỘ** trên dòng ví; Trang chủ có dòng nhắc
> *"N ví trùng tên đang chờ bạn xử lý"* có ✕ (màn `5dd90541…`). Nghiệm thu trên **hai máy ảo cùng tài khoản thử 27**
> (người dùng chọn): bị từ chối **đúng một lần** rồi sạch · thẻ, nhãn, dòng nhắc, ✕ ẩn và mở lại app thì hiện lại · **một**
> ví mặc định · Sửa ví lưu được cho cả hai ví cùng tên · **Gộp**: số dư sau gộp 3.388.000 đ đúng con số trong hộp,
> PostgreSQL còn một ví và giao dịch của máy B nằm dưới nó, máy A kéo về cùng số dư · **Đổi tên**: PostgreSQL có hai ví hai
> tên, giao dịch của B dưới ví đã đổi tên, máy A thấy đủ.
>
> ⚠️ **Hai lỗi lượt nghiệm thu bắt được, 5820 ca test đều mù:**
> 1. **Vòng đồng bộ nóng** (291 chu kỳ trong 5 giây trên máy B): bước **1b** của `_collectPendingOps` (nay `ThuGomThaoTacDay.collectPendingOps`) gửi kèm danh mục
>    của mọi giao dịch đang chờ — kể cả giao dịch **bị giữ**, vốn nằm `pending` vô thời hạn — nên mỗi chu kỳ đẩy lại hai
>    danh mục, server trả xung đột (không lỗi ⇒ không giãn cách), và `/sync/push` phát `sync.completed` về **chính máy
>    này** ⇒ `syncNow` ⇒ chạy bù ⇒ đẩy lại. Trước G63 các giao dịch ấy hỏng khoá ngoại nên giãn cách kìm vòng lại; giữ
>    chúng mà quên bước 1b là tháo phanh. Sửa: 1b bỏ giao dịch bị giữ (`2274a1f`).
> 2. **Máy kia kéo thiếu sau Đổi tên** (ví mới tên hiện 0 đ, không giao dịch): bản ghi ghi lúc offline rồi bị giữ lên
>    server với giờ ghi **cũ hơn** mốc kéo về của máy kia. Sửa phần của G63 bằng **`ThaViBiGiu`** — thả ví (Đổi tên, hoặc
>    ví kia bị xoá / đổi tên ở máy khác) thì làm mới giờ sửa của ví và mọi bản ghi từng bị giữ (`3544cc4`). Ca **chung**
>    (máy offline lâu rồi đẩy muộn) ngoài tầm client → mở **G67**, đơn backend CAN-LAM 37.
>
> Còn lại trên máy ảo A: ví *"Vi doi ten (2)"* 0 đ — dữ liệu của lượt đo **trước** bản sửa thứ hai, đã lên server với giờ
> cũ; client không cứu lại được, đúng ca G67.


> 📝 **2026-10-05 (ảnh chụp lúc bắt đầu):** người dùng chọn làm G63. Thiết kế duyệt trong chat; spec
> `docs/superpowers/specs/2026-10-05-g63-vi-trung-ten-hai-may-design.md`. Ba điều chốt thêm so với phác thảo cuối mục
> này: phạm vi **chỉ ví** (danh mục để lượt sau) · cờ mặc định **bản server thắng** · dòng nhắc Trang chủ **có ✕**.
> **Tiến độ (2026-10-05 chiều):** kế hoạch 14 task (gitignore); **Task 1–8 xong** (`f2a2f52` → `6a68d86`) — schema v28 cờ
> cục bộ `wallets.bi_tu_choi_trung_ten`, `ViTrungTenResolver`, `_collectPendingOps` giữ ví bị từ chối cùng mọi thứ dính tới
> nó, Sửa ví chỉ kiểm trùng tên khi tên đổi (đổi tên gỡ cờ), kéo về chỉ còn một ví mặc định, `GopViService`. **Còn Task
> 9–13:** thẻ Gộp / Đổi tên ở Quản lý ví, dòng nhắc Trang chủ, nghiệm thu hai máy, đóng mục này. Mô tả hành vi bên dưới là
> ảnh chụp 03/10.

**Lộ ra khi:** đăng nhập lại trên Realme sáng 2026-10-03 (nghiệm thu đăng xuất của *chia sẻ biên lai*) — lượt đồng bộ
đầu tiên sau 11 ngày báo 65 thao tác, **10 lỗi**: đúng *"10 failed"* ghi từ 28/09.

**Chuỗi nguyên nhân (đo trên CSDL Realme + PostgreSQL dev, tài khoản 10):**

1. Ngày 30/09 hai máy cùng tài khoản 10 mỗi máy tự tạo **"Ví MB Bank"** và **"Ví MoMo"** để thử D1 — Realme
   (`680dbb73…`, `c21989d2…`, chưa đồng bộ từ 22/09) và một máy khác (`5b33f62d…`, `e7012444…`, lên server
   02/10; giao dịch của chúng 08:48–12:04 sáng 30/09 khớp buổi nghiệm thu D1 trên OnePlus — **suy luận**: OnePlus
   nay đăng nhập tài khoản **26**). Client chặn trùng tên chỉ với ví **trên chính máy ấy**
   (`WalletLocalDataSourceImpl._kiemRangBuocServer`), nên cả hai đều tạo được.
2. Máy đẩy sau nhận `WALLET_NAME_DUPLICATE` (`uq_wallet_account_name_active`). Mã ấy là `permanent`, nhưng
   `permanent` chỉ **chặn theo thời gian** — hết hạn là gửi lại, hỏng lại, **mãi mãi**.
3. Nhánh kéo về ghi ví **theo id** (`walletDao.upsertAll`), không xét tên → máy có **hai ví trùng tên**, cả ở màn Quản lý
   ví lẫn mọi bộ chọn ví. Kèm theo trên Realme: **hai ví MẶC ĐỊNH** (cờ của ví máy này + cờ "Tiền mặt" kéo về), và
   **ví trùng không sửa được** — mọi lần lưu ở trang Chỉnh sửa ví bị chính chốt trùng tên cục bộ chặn (ví kia đã nằm trên
   máy).
4. Giao dịch trong ví bị từ chối vỡ `fk_transaction_wallet`, mà khoá ngoại tới ví là `transient` → **gửi lại ở mọi chu
   kỳ** → mỗi chu kỳ kết thúc bằng lỗi → giãn cách luỹ tiến làm chậm cả dữ liệu khác.

**Vì sao hoãn:** chỉ xảy ra khi **một tài khoản dùng trên hai máy** và cả hai cùng tạo một tên trước khi kịp đồng bộ —
người dùng một máy (cách đồ án được dùng và trình diễn) không gặp. Người dùng chốt: *"nó chỉ xuất hiện do mình đổi
điện thoại lúc test"*. **Danh mục** có cùng lỗ hổng (`CATEGORY_NAME_DUPLICATE`), cũng hoãn.

**Dữ liệu kẹt đã dọn (2026-10-03, người dùng chọn xoá bản của Realme, tôi điều khiển máy):** xoá qua giao diện 7 giao
dịch của "Ví MB Bank" `680dbb73…` (+10.000 đ 30/09 19:04 — một lần chuyển thử; 6 khoản thử 1.000 đ của dự án C 02/10),
rồi xoá hai ví trùng của Realme. Lối vào đúng ví khi hai ví cùng tên: menu ⋮ của thẻ → *Xem giao dịch* (lọc theo **id**).
Bảy giao dịch và "Ví MoMo" lên server lúc 10:39; lệnh xoá "Ví MB Bank" đi lúc **10:54:27**, ngay khi hết hạn chặn
(1 thao tác, 1 lên, 0 lỗi). Đo lại trên PostgreSQL: tài khoản 10 còn đúng một "Ví MB Bank" và một "Ví MoMo", không giao
dịch nào của Realme lọt lên; Realme đồng bộ sạch. ⚠️ Trong lúc dọn, trang *Chỉnh sửa ví* **không lưu được** ví trùng (chốt
trùng tên cục bộ) — kể cả khi chỉ tắt cờ mặc định; xoá thẳng thì được (luật xoá không chặn ví mặc định).

**Phác thảo lối sửa, nếu sau này cần hỗ trợ nhiều máy** (người dùng đã chọn từng điểm trước khi hoãn; từ 2026-10-05 bản
đầy đủ và có thẩm quyền là spec nêu ở đầu mục — chỗ nào hai bên khác nhau thì spec thắng):
- Cột cục bộ `wallets.bi_tu_choi_trung_ten` (schema mới), đặt bởi một bộ nghe `pushResultStream` khi thao tác ví hỏng với
  `WALLET_NAME_DUPLICATE` / `UNIQUE_VIOLATION` — cùng khuôn `BillPaymentConflictResolver`.
- Một hàm thuần `capViTrungTen` ở `wallet/domain/` là định nghĩa duy nhất của "cặp trùng".
- **Trong lúc chờ:** `_collectPendingOps` (nay `ThuGomThaoTacDay.collectPendingOps`) bỏ qua ví mang cờ và mọi giao dịch / hoá đơn / mục tiêu dính tới nó.
- **Thẻ hỏi Gộp / Đổi tên** ở màn Quản lý ví, kèm một dòng nhắc ở Trang chủ. *Gộp* dời giao dịch, hoá đơn, mục tiêu và
  bảng *nguồn → ví* của D1 sang ví đã đồng bộ, bỏ ví máy này **cùng khoản "Số dư ban đầu"** của nó (cùng một tài khoản
  thật — giữ hai số dư mở sổ là đếm đôi), có hộp xác nhận nêu số giao dịch và số dư sau gộp. *Đổi tên* điền sẵn
  "‹tên› (2)".

---

### ~~G62 — Hàng sáu ô OTP tràn ở máy 360 dp~~ · ✅ ĐÓNG (2026-10-02, mở và đóng trong cùng ngày)

**Người dùng báo khi đăng ký tài khoản mới trên OnePlus 13R** (361 dp, bản debug `3837709c…`): ô OTP thứ sáu bị sọc
cảnh báo che, *"RIGHT OVERFLOWED BY 6.9 PIXELS"*.

- **Gốc:** hàng là sáu `SizedBox(width: 45)` = **270 dp cứng**; sau lề trang 24 × 2, lề thẻ 24 × 2 và viền thẻ chỉ còn
  **~263 dp** ở máy 360 dp. Ở 411 dp (máy ảo — khổ của mọi lượt nghiệm thu trước) hàng vừa, nên lỗi nằm sẵn từ khi
  màn ra đời. Màn OTP **quên mật khẩu** (`otp_page.dart`) chép đúng hàng ấy và tràn 6 dp.
- **Sửa:** một widget dùng chung `HangOOtp` (`features/auth/presentation/widgets/hang_o_otp.dart`) — ô `Flexible` rộng
  tối đa 45 dp, **co lại** khi hẹp, luôn chừa khe 6 dp. Ở 411 dp hàng trông như cũ (ô 45 dp); ở 360 dp ô ~38,7 dp; ở
  320 dp ô 32 dp.
- **Test:** `test/features/auth/o_otp_khong_tran_test.dart` — sáu ca (hai màn × 360 / 320 / 411 dp), dựng bằng
  `AppTheme.lightTheme`. Bốn ca hẹp **đỏ trên mã cũ** (tràn 8 · 48 · 6 · 46 dp). Ca hẹp đòi cả **kết quả**: sáu ô rộng
  bằng nhau ≥ 30 dp và có khe ≥ 4 dp — chỉ `takeException() isNull` thì một bản sửa bóp ô về 0 cũng xanh.
- **Chưa thấy trên máy thật:** bản sửa cài lên OnePlus (`c4a9c9aa…`) khi người dùng đã đăng ký xong; muốn nhìn lại phải
  đăng xuất rồi vào *Quên mật khẩu* hoặc đăng ký lần nữa.

---

### ~~G61 — Không còn lối vào trang nhập từ khoá của danh mục~~ · ✅ ĐÓNG (2026-10-01, mở và đóng trong cùng ngày)

**Người dùng hỏi giữa lượt nghiệm thu *đề xuất thêm từ khoá* trên Realme:** *"hình như hiện tại các danh mục mình chưa
thể tự điền tự khóa vào được có phải không"* (ý: *từ khoá*). Đúng — xác nhận bằng mã và trên máy (Realme RMX2205, bản debug
`5ffc0123…`, tài khoản 10):

- Trang nhập từ khoá **còn nguyên** trong mã: route `/categories/:id/keywords` → `CategoryAddPage(keywordOnly: true)` →
  `_keywordOnlyBody` với `_KeywordsEditor`, lưu qua `saveKeywords`.
- Lối vào **duy nhất** là nút *"Từ khóa của tôi"* ở `_defaultRow` của `category_page.dart`, tức hàng của mục *Danh mục
  mặc định*. Mục ấy dựng từ `tree.defaultChildren`, mà `CategoryManagementRepository.watchTree` trả
  **`defaultChildren: const []`** — hàng mặc định toàn cục thôi hiện từ khi mỗi tài khoản có bản sao riêng
  (2026-09-07, quy tắc 8 `CLAUDE.md`). Trên máy: mục ấy in *"Chưa có danh mục mặc định"*.
- Bản sao của tài khoản là danh mục thường (`isDefault = 0`), mở bằng nút bút chì → `_formBody`. Form ấy **nạp** từ
  khoá (`loadKeywords`) và **gửi lại nguyên** qua `saveChild(keywords: _keywords)` nên không làm mất, nhưng **không vẽ**
  `_KeywordsEditor` — `grep` ra đúng một chỗ dùng widget ấy, ở `_keywordOnlyBody`. Trên máy: form *Chỉnh sửa danh mục*
  của Ăn uống chỉ có loại · nhóm cha · tên · biểu tượng · màu · công tắc *Cố định*.
- Nhánh `current.isDefault → _showKeywordOnly` của `category_add_page.dart` và dòng *"Danh mục mặc định • Chỉ có thể sửa
  từ khóa"* của `category_group_page.dart` cùng chết theo: không hàng `isDefault` nào tới được hai trang ấy.

**Hệ quả.** Từ 2026-09-07 tới 2026-09-30 người dùng **không có cách nào** thêm hay gỡ từ khoá; bộ từ khoá của mỗi
tài khoản là đúng bộ seed. Từ 2026-09-30 lối thêm duy nhất là dòng *đề xuất thêm từ khoá* ở màn Thêm giao dịch (mục 5f
`CATEGORY_RATIONALE.md`) — cần một thói quen ≥ 3 lần — và **vẫn không có lối gỡ**: từ khoá thêm nhầm qua đề xuất không
đảo được trên máy, trái câu *"đảo được trong trang Từ khoá"* của spec đề xuất. Bản sửa `saveKeywords` đẩy lên server
(cùng ngày 30/09) cũng chỉ có **một** người gọi tới được.

**Vì sao sống lâu.** Không gì hỏng: không exception, không nút chết (nút nằm trong một danh sách rỗng nên không bao giờ
được dựng), và test của trang từ khoá dựng thẳng `CategoryAddPage(keywordOnly: true)` nên xanh. Ca test quét *"mọi trang
tính năng đều vào được từ menu"* canh trang gốc của tính năng, không canh route con.

**Sửa (người dùng chọn lối *ô từ khoá trong form*, 2026-10-01).** Màn Stitch *"Sửa danh mục — công tắc Cố định"*
(`a5a6ecb3…`) **vốn đã vẽ** khối từ khoá ngay dưới thẻ Cố định — chú thích của chính `_TheCoDinh` còn ghi *"thẻ trắng
giữa khối màu và khối từ khoá"* — mã chỉ chưa dựng. Nay `_formBody` (dùng chung cho **tạo mới** và **sửa**) có khối
*Từ khóa nhận diện*: thẻ trắng chứa `_KeywordsEditor` sẵn có (thẻ từ khoá có nút gỡ, tooltip *"Gỡ từ khóa …"*; ô nhập,
Enter hoặc dấu phẩy tạo thẻ), lưu qua `saveChild(keywords:)` như cũ — đường ấy vốn đánh dấu `pending` và hẹn đồng bộ.
Kèm một chốt cho **cả hai** trang: `_save` nhận luôn **chữ đang gõ dở** trong ô từ khoá (gõ xong bấm Lưu mà chưa Enter
là thao tác thường gặp nhất trên điện thoại; trước đó chữ ấy mất im lặng, kể cả ở trang từ khoá riêng).

Hai chỗ lệch Stitch có chủ ý: nhãn **không** ghi *"cho AI"* (bộ so từ khoá là luật, không phải mô hình), và chip nét
đứt *"+ Thêm"* là một **ô nhập** (chip không gõ chữ được).

**Test:** `test/features/category/presentation/category_form_tu_khoa_test.dart`, 6 ca, **cả sáu đỏ trên mã cũ** — form
sửa danh mục thường (`isDefault = false`) hiện thẻ + ô nhập · thêm một, gỡ một → `saveChild` nhận đúng danh sách · chữ
gõ dở vẫn lưu (form và trang từ khoá riêng) · form tạo mới · theme thật 360 × 640 với sáu từ khoá dài, không tràn.

✅ **Nghiệm thu Realme RMX2205 cùng ngày** (bản debug `f04ed2ea…`, tài khoản 10): form *Chỉnh sửa danh mục* của Ăn uống hiện khối *Từ khóa nhận diện* với ba thẻ `an uong · food · trà sữa`; gõ *bún bò* (Telex) rồi bấm **Lưu danh mục** khi **chưa Enter** — bàn phím hệ thống mở, ô nhập và nút Lưu đều còn trên màn — SQLite `category_keywords` có *bún bò*, danh mục `pending`; mở lại thấy thẻ; gỡ bằng nút × rồi Lưu → SQLite về đúng ba từ khoá cũ. Không để lại dữ liệu thử.

⚠️ **Giới hạn còn lại, không sửa ở đây:** gỡ **hết** từ khoá của một danh mục thì client không gửi khoá `keyword`
(chuỗi rỗng là lệnh xoá cả từ khoá server tự học), và nhánh kéo về `_gieoTuKhoaKhiTrong` gieo lại bộ của server khi
danh mục trên máy không còn từ khoá nào — nên bộ cũ **quay lại sau lượt pull kế**. Gỡ bớt thì giữ được.

---

### ~~G60 — Bảng chọn thứ tổng kết tuần tràn ở màn thấp~~ · ✅ ĐÓNG (2026-09-29, mở và đóng trong cùng ngày)

**Lộ khi viết ca test G59** (đổi thứ tổng kết phải đặt lại lịch): ở khung test mặc định 800 × 600, bảng chọn thứ báo
*"A RenderFlex overflowed by 55 pixels on the bottom"*. Bảng là `showModalBottomSheet` **không** `isScrollControlled`,
thân là `Column(mainAxisSize: min)` chứa 7 `ListTile` (~56 dp mỗi dòng ≈ 392 dp). Bottom sheet mặc định chỉ được cao
**9/16 màn**, nên máy có chiều cao dưới ~700 dp tràn và dòng cuối (*Chủ nhật*) có thể không bấm được. Realme RMX2205
(800 dp → 450 dp) và máy ảo 411 × 914 không lộ. Có từ lát Tổng kết tuần (2026-09-09).

Ca G59 dựng ở khổ 411 × 914 để không trộn hai lỗi. **Sửa (người dùng chọn, `d57cb09`):** `isScrollControlled: true` +
`useSafeArea: true` — bảng cao theo nội dung thay vì kẹt ở 9/16 màn — và thân bọc `SingleChildScrollView` cho màn còn
thấp hơn (xoay ngang). Hai ca ở `notification_settings_page_test.dart` (nhóm G60, khổ 360 × 640 và 800 × 600): không
tràn, chạm được *Chủ nhật*; cả hai đỏ trên mã cũ (32 px và 55 px). Realme bản release `351d062e…`: bảng hiện đủ bảy thứ,
đúng như trước.

---

### ~~G59 — Đổi giờ nhắc không dời lịch đang chờ~~ · ✅ ĐÓNG (2026-09-29, mở và đóng trong cùng ngày)

**Lộ khi soát kế hoạch B5b** với mã thật: spec B5b §3 viết *"Áp dụng … rồi `ReminderScheduler.resync` như khi người
dùng tự đổi"* — nhưng đường ấy **không dời được gì**. Khoá lịch không chứa giờ (`billDue` theo kỳ, `ghiChep` theo ngày,
`weekly` theo tuần), nên cùng khoá = cùng `osScheduledId`; `resync` bỏ qua *"id đã chờ và vẫn được muốn"* (luỹ đẳng).
Tái hiện: đặt lịch 08:00, đổi giờ sang 20:00, `resync` → lịch vẫn 08:00, không huỷ, không đặt lại. Trang Cài đặt cũng
không tự gọi `resync` — lịch chỉ đổi ở lượt quét sau, mà lượt ấy cũng không dời. Hệ quả: tới 30 ngày nhắc hoá đơn,
ba ngày nhắc ghi chép và lần tổng kết đang chờ vẫn nổ giờ cũ, im lặng. *"Đổi số ngày nhắc thì lịch cũ bị huỷ"* (mục 8
`NOTIFICATION_FEATURE.md`) đúng chỉ vì số ngày **nằm trong** khoá.

**Sửa (người dùng chọn sửa trước B5b):** `ReminderScheduler.resync(idaccount, {datLai = false})` — `datLai` huỷ rồi
đặt lại lịch vừa chờ vừa được muốn; lịch Hoãn không nằm trong tập muốn nên không bị đụng; nhật ký B5a ghi đúng một
`huy_lich` + một `dat_lich` mới. Trang Cài đặt: `_ghi` gọi `datLaiLich` (mặc định `resync(id, datLai: true)`) khi một
trong **bảy** trường mốc đổi (`gioNhac`, `phutNhac`, `gioNhacGhiChep`, `phutNhacGhiChep`, `thuTongKet`, `gioTongKet`,
`phutTongKet`); gạt công tắc thì không. Lượt quét thường không truyền `datLai`.

**Test:** 6 ca ở `reminder_scheduler_test.dart` (nhóm G59 — tiền đề luỹ đẳng, hoá đơn, ghi chép, tổng kết, lịch hoãn,
nhật ký) + 2 ca ở `notification_settings_page_test.dart`. **Realme 2026-09-29:** `dumpsys alarm` — hai lịch nhắc hoá
đơn 02/10 **08:00 → 20:00** sau *"Đổi sang 20:00"* của B5b, rồi về 08:00 khi đặt lại bằng bộ chọn giờ (đường tay).

---

### ~~G58 — Màn Thêm giao dịch tràn và che ô ghi chú khi bàn phím hệ thống mở~~ · ✅ ĐÓNG (2026-09-29, mở và đóng trong cùng ngày)

**Người dùng thấy trên Realme RMX2205 (360 dp)** giữa lượt nghiệm thu B4, lúc script gõ ghi chú: sọc vàng đen *"BOTTOM
OVERFLOWED BY 9.7 PIXELS"* ở hàng `00 · 0 · 000 · ✓`. Logcat Realme không giữ được dòng lỗi (log hệ thống quá dày) nên tái
hiện bằng widget test.

**Gốc:** bố cục neo đáy của nhóm C UX (`2263f9b`, 2026-09-19, màn Stitch `acf6f17e…`) đặt thanh Chi/Thu/Chuyển, con số và
16 phím (`mainAxisExtent: 50`, ~240 dp kể đệm) **cao cố định**, chỉ thẻ form ở giữa là `Expanded`. Bàn phím hệ thống
(~303 dp — 908 px / 3,0 đo trên ảnh chụp) làm `Scaffold` co thân còn ~400 dp: thẻ form bị ép về **0** — ô ghi chú đang gõ
**biến mất** — rồi tràn. Đo ở khổ 360 × 800, đệm trên 40 dp: bàn phím hệ thống 250 dp chưa tràn, 280 dp tràn 4 px, 303 dp
tràn 27 px (font test rộng hơn font thật nên con số khác máy). Bốn ca bố cục cũ đo ở 411 × 914 **không** có bàn phím hệ
thống nên mù; màn Stitch cũng chỉ vẽ trạng thái ấy. Nhật ký B2 (`plans/2026-09-28-b2-…`) từng ghi triệu chứng *"bàn phím hệ
thống ép vùng form về 0"* như một bẫy đo, không mở mục.

**Sửa (người dùng chọn trong ba lối — ẩn phím số · cả thân cuộn · bàn phím hệ thống đè lên):**
`MediaQuery.viewInsetsOf(context).bottom == 0` mới dựng 16 phím. Đang gõ chữ thì phím số không có việc gì; đóng bàn phím
hệ thống thì phím số và ✓ (nút lưu **duy nhất**) quay lại, chữ đã gõ giữ nguyên. Không thêm phần tử nào nên không cần màn
Stitch mới. Hai ca ở `add_transaction_bo_cuc_test.dart` (nhóm G58), khổ 360 × 800 + 303 dp: không tràn, không có `000`
lẫn ✓, ô ghi chú nằm **trên** bàn phím hệ thống; đặt `viewInsets` về 0 thì `000` và ✓ hiện lại. Cả hai đỏ trên mã cũ.
Realme bản debug: không sọc, ô ghi chú hiện rõ chữ đang gõ; đóng bàn phím hệ thống thì 16 phím quay lại.

---

### ~~G57 — Nút tạo hoá đơn cố định đè lên hàng tab ở 360 dp~~ · ✅ ĐÓNG (2026-09-29, mở và đóng trong cùng ngày)

**Ghi trong bàn giao sau B3, người dùng chọn sửa trước B4.** Trang Hoá đơn đặt nút rộng *"Tạo hóa đơn lặp lại mới"* bằng
`Positioned(bottom: 24)` trong một `Stack` **đè lên** vùng cuộn. Từ B2 cả trang cuộn, phần đầu (thẻ tổng + khối Nhận xét +
thẻ khoản lặp) cao hơn nên ở 360 dp hàng tab lúc mở trang rơi đúng dưới nút. Màn Stitch mới nhất của trang
(`e8b460b4…`) **không có** nút ấy — nút thêm là biểu tượng **+** ở góc phải thanh tiêu đề; bản thi công lệch Stitch.

**Sửa:** `AppBar.actions` thêm `IconButton` **+** (tooltip *"Tạo hóa đơn lặp lại mới"*, `context.push('/bills/add')`); bỏ
`Stack`, `Positioned` và `_buildAddButton`; đệm đáy danh sách từ 100 về 24 dp (100 là chỗ chừa cho nút cũ). Hai ca ở
`bill_page_khoan_lap_test.dart` (nhóm G57): 360 × 640 có thẻ khoản lặp thì không còn `ElevatedButton` ấy và nút **+** có
trong `AppBar`; chạm nút mở `/bills/add` qua `GoRouter` **thật**. Cả hai đỏ trên mã cũ.

### ~~G56 — Tỉ lệ tiết kiệm năm chữ số khi thu nhập gần 0~~ · ✅ ĐÓNG (2026-09-29, mở và đóng trong cùng ngày)

**Ghi trong bàn giao sau B3** (khối Nhận xét trang Phân tích, tuần có thu nhập gần 0: *"chi vượt thu nhập 26360,0%"*).
Con số đúng — `tyLeTietKiem = (thu nhập − chi) / thu nhập` — nhưng không ai đọc được. Cùng tỉ lệ ấy hiện ở **ba** chỗ:
khối Nhận xét (`GoiSoPhanTich`), thẻ *Số dư còn lại* (*"Để dành −26360% thu nhập"*), tool `tong_quan_tai_chinh` của Trợ lý
AI (`hangTongQuan`, mục *Chi vượt thu nhập*).

**Người dùng chọn:** chi **dưới 2 lần** thu nhập giữ phần trăm như cũ; **từ 2 lần** nói *"chi gấp N lần thu nhập"* — N
một chữ số lẻ dưới 10, số nguyên từ 10, bỏ đuôi `,0`. **Một** hàm `soLanChiGapThuNhap` (cạnh `tyLeTietKiem` ở
`analytics/domain/dong_tien_tu_do.dart`) trả số **đã làm tròn như sẽ in**, và `chuoiSoLan` định dạng — ba chỗ cùng gọi.
Lớp AI chỉ nhận số (test quét 14): gói số mang `soLan('Gấp thu nhập', n)`, loại số mới **`LoaiSo.soLan`** mà `kiemSo` so
với dung sai 0,05 và **không** khớp phần trăm (*"265%"* không phải *"265 lần"*). Nhãn *Gấp thu nhập* chọn để câu mẫu *"chi
gấp 265 lần thu nhập"* chứa đủ âm tiết cho `kiemNhan`.

**Ca canh:** 6 ca thuần (`dong_tien_tu_do_test`, số Realme 20.000 / 5.292.000 → 265; 1,3 lần → `null`; đúng 2 lần tính;
9,96 → 10), 3 ca `kiemSo`, 2 ca `GoiSoPhanTich` (mẫu câu *"gấp"* qua sáu lớp chắn), 1 ca `hangTongQuan`, 1 ca widget thẻ.
⚠️ Ca cũ *"chi vượt thu nhập 720,0%"* (8,2 lần) **mã hoá đúng hành vi vừa đổi** nên viết lại thành hai ca: dưới 2 lần giữ
phần trăm, từ 2 lần nói *"gấp"*.

### ~~G55 — Chấm kỳ đầu/cuối của biểu đồ đường bị cắt nửa~~ · ✅ ĐÓNG (2026-09-29, mở và đóng trong cùng ngày)

> 🛑 **Cách sửa dưới đây KHÔNG có tác dụng** — đo bằng ảnh 2026-10-07: `FlClipData.vertical()` của fl_chart 1.2.0 vẫn cắt nửa chấm ở mép trái/phải, và ca canh chỉ đọc cấu hình nên xanh. Sửa thật ở **G79** (nới trục ngang, `clipData` về `all()`).

**Thấy trên Realme khi nghiệm thu G53:** chấm T4 (kỳ đầu) của khối *Xu hướng* và *Dòng tiền tự do* chỉ còn nửa. Bốn
biểu đồ đường có chấm — Xu hướng, Dòng tiền tự do, Tổng tài sản (trang Phân tích) và Tiến độ theo thời gian (trang chi
tiết mục tiêu) — đều đặt `FlClipData.all()` theo bẫy 4.17, mà clip ấy cắt đúng mép vùng vẽ: chấm nằm ở `minX`/`maxX` mất
một nửa, chấm giá trị 0 ở đáy (`minY: 0`) mất nửa dưới.

**Kiểm lý lẽ 4.17 trên từng đường** trước khi nới: trục **ngang** không thể thoát khung (`minX`/`maxX` là đúng chỉ số / mốc
đầu và cuối của chuỗi); trục **dọc** cũng không thoát trên dữ liệu hôm nay (dải tính từ dữ liệu, đường cong có
`preventCurveOverShooting`) — tức clip chỉ còn là **phòng thủ**. Người dùng chọn **chỉ bỏ cắt trái/phải**
(`FlClipData.vertical()`), giữ phòng thủ cho trục dọc; đổi lại chấm giá trị 0 ở đáy khối Xu hướng **vẫn** cắt nửa — cố ý.
Khối *Dự báo* không vẽ chấm nên giữ `all()`.

**Ca canh:** `kiemCatKhungBieuDoCoCham` (`analytics_page_test.dart`) quét mọi `LineChart` có chấm của trang, đòi **đủ ba**
biểu đồ (một bản sai giấu hết chấm thì vòng quét rỗng và xanh) và mỗi cái cắt trên/dưới, không trái/phải; một ca ở
`goal_progress_chart_test.dart`. Cả hai đỏ trên mã cũ.

### ~~G54 — Nhãn trục hoành thác nước dính nhau ở 360 dp~~ · ✅ ĐÓNG (2026-09-29, mở và đóng trong cùng ngày)

**Thấy trong ảnh nghiệm thu G53 trên Realme RMX2205 (360 dp):** *"Di chuyển"* và *"Chưa phân l…"* dính thành
*"chuyểnphân l…"*. Đo từ cây UI: tâm hai nhãn liền nhau cách **81 px = 27 dp**, còn ô nhãn rộng **32 dp** — mỗi cặp chồng
~5 dp. Ô 32 dp hai dòng cỡ 8 là bản sửa của A8 #10 (mục 3.23 `ANALYTICS_FEATURE.md`), tính cho **411 dp** (~36 dp mỗi cột);
360 dp chưa ai đo. Không exception, không sọc vàng.

**Người dùng chọn theo màn Stitch** `52450ac549df42aea9f31d5ee1347ceb`, vốn vẽ nhãn **xoay −35°, một dòng** (*"xoay nhẹ -35
độ để không bị chồng lấn"*) — bản thi công A8 #10 đã lệch khỏi đó mà không ghi lý do. Sửa ở `_KhoiThacNuoc`:

- Nhãn một dòng, cỡ 9, xoay −35°. Hai nhãn nghiêng song song lệch nhau `p` theo phương ngang thì cách nhau `p × sin 35°`
  theo phương vuông góc (~15 dp ở 360 dp) — rộng hơn chiều cao chữ, nên cột hẹp mấy cũng không chồng.
- ⚠️ **Đầu PHẢI của chữ neo đúng tâm cột**, xoay quanh góc trên-phải (như `text-anchor="end"` của Stitch): ô rộng 0 đặt ở
  tâm cột, `OverflowBox` canh phải cho chữ tràn sang trái. Xoay quanh **tâm** thì nửa phải nhãn dài chồi lên vùng cột.
- ⚠️ `OverflowBox` phải có `minHeight: 0` — thiếu nó thì `Text` nhận chiều cao **chặt** của ô cha (48 dp) thay vì một dòng.
- Chữ dài hơn **72 dp** thì *"…"* (64 dp cắt *"Chưa phân loại"* thành *"Chưa phân l…"* trên Realme). Phần dành cho nhãn cao
  58 dp (40 cũ), khung biểu đồ 218 (200 cũ) — vùng vẽ giữ nguyên.

**Ca canh** `analytics_page_test.dart` *"360dp: nhãn trục hoành MỘT dòng, xoay −35° như Stitch, không chồng nhau (G54)"*:
đủ chín nhãn, `maxLines == 1`, góc −35° (đọc từ `Transform` tổ tiên), mọi **điểm neo** (góc trên-phải sau xoay) trên cùng
một đường, và `bước cột × |sin góc| ≥ chiều cao chữ`. ⚠️ Đo **điểm neo**, không đo tâm chữ: chữ dài ngắn khác nhau nên tâm
lệch nhau — lượt đầu đo tâm ra bước cột 15,8 dp, sai. Đỏ trên mã cũ (hai dòng, không xoay); bản sai *xoay quanh tâm* đỏ ở vế
điểm neo. **Realme**: bản release `c9fa3462…` (64 dp) — chín nhãn nghiêng không chạm nhau nhưng *"Chưa phân l…"*; bản cuối
`d8c10019…` (72 dp) — *"Chưa phân loại"* hiện đủ.

### ~~G53 — Nhãn trục thác nước "Tiền đi đâu" in đè khi số dư âm~~ · ✅ ĐÓNG (2026-09-29, mở và đóng trong cùng ngày)

**Thấy khi nghiệm thu B3 trên Realme RMX2205 (360 dp)**: sau khi dữ liệu thử đẩy ví Tiền mặt xuống âm (số dư đầu kỳ tháng 9
**−10.490.000**, cuối kỳ **−2.356.000**), trục tung của khối *"Tiền đi đâu"* in *"5.9M"* chồng lên *"5.5M"* ở góc trên.

**Nguyên nhân (đọc mã `_KhoiThacNuoc`, `analytics_page.dart`, chưa sửa):** `lo` = đáy thấp nhất của các bậc (âm),
`buocTruc = (hi − lo) × 1,12 / 3`, `minY = lo`, `maxY = lo + 3 × buocTruc`. fl_chart vẽ nhãn tại **các bội của `interval`**
(tính từ 0) **cộng** hai biên `minY` / `maxY` (bẫy 4.18). Luật G39 — *"tính `buocTruc` trước rồi đặt trần bằng bội của nó"*
— chỉ khớp khi trục **bắt đầu từ 0**; thác nước giả định số dư không âm nên `lo = 0`. Số dư âm phá giả định ấy: biên
trên 5,9M không phải bội của bước và đứng sát mốc 5,5M.

**Hướng sửa khả dĩ:** cùng luật với `daiTrucDuBao` (bẫy 4.21 — bước **tròn** họ 1·2·2,5·5 × 10^k, sàn là **bội** của
bước), để mọi biên trùng một mốc. Ca test phải đòi *"các nhãn trục đôi một khác nhau và không chồng nhau"* với dữ liệu có
số dư đầu kỳ âm; tầng vẽ không test được nên phải xem trên máy 360 dp. **Chưa sửa** — người dùng dặn dừng sau B3 để bàn
giao; phiên sau hỏi sửa lúc nào (nếp *sửa lỗi trước, thêm tính năng sau*).

**Sửa (2026-09-29 tối, người dùng chọn *sửa trước B4*):** hàm thuần **`daiTrucCot(lo, hi)`** ở
`analytics/domain/du_bao_dong_tien.dart`, cạnh `daiTrucDuBao` và `buocTron`. Bước lấy trong họ tròn của `buocTron`
(không đẻ họ thứ hai); **sàn và trần đều là bội của bước** nên mọi mốc fl_chart vẽ cách đều đúng một bước; trục **luôn
chứa 0** (luật *cột → từ 0* của 15/09 giữ nguyên — số dư không âm thì sàn đúng bằng 0); số khoảng **3 tới 5**. ⚠️ **Không**
dùng thẳng `daiTrucDuBao`: nó cố định ba khoảng, và dải vắt qua 0 bị làm tròn ra ngoài ở **cả hai đầu** nên phải nới
bước gấp đôi — số liệu Realme cho trục −20M … 10M, dữ liệu còn nửa khung. Số liệu Realme với `daiTrucCot`: −15M … 5M,
bước 5M.

**Ca canh:** widget test *"số dư đầu kỳ ÂM: nhãn trục tung không chồng lên nhau (G53)"* (`analytics_page_test.dart`)
dựng đúng số Realme, lấy **hộp** của từng nhãn trục (fl_chart dựng nhãn trục bằng widget `Text`, nên lỗi này tái hiện
được ngay trong `flutter test`, như G39) và đòi các hộp không chồng nhau — **đỏ trên mã cũ** với đúng hai chuỗi *"5.9M"*,
*"5.5M"*. Năm ca thuần ở `du_bao_dong_tien_test.dart` (nhóm `daiTrucCot`); hai bản sai có chủ ý đều bị bắt (sàn không
làm tròn về bội → 2 ca đỏ; bỏ vòng nới bước → ca *"3 tới 5 khoảng"* đỏ với 6). **Realme** (bản release `79c2cbb1…`, tháng
9 tài khoản 10): trục in *5M · 0 · −5M · −10M · −15M*, cách đều, không đè.

⚠️ Cùng ảnh ấy lộ một chỗ **khác, có từ trước**: ở 360 dp hai nhãn **trục hoành** *"Di chuyển"* và *"Chưa phân l…"*
dính vào nhau — chín cột trên 360 dp mỗi cột chỉ còn chừng 27 dp mà ô nhãn rộng 32 dp (chú thích ở `_KhoiThacNuoc` tính
cho 411 dp). Không thuộc G53 — thành **G54**, đóng cùng tối.

**Khối *Dòng tiền tự do* cũng chuyển sang `daiTrucCot`** (người dùng chọn, cùng lượt): nó đặt sàn = đáy × 1,15, tức cùng
cơ chế G53 ở dạng **tiềm ẩn** — kỳ trả nợ vượt thu nhập một chút cho sàn âm lẻ đứng sát mốc 0. Chưa thấy trên dữ liệu thật
(Realme mọi tháng ≥ 0, vì tự do = *thu nhập − trả nợ*, không phải *thu − chi*); widget test dựng tự do −100.000 thì **đỏ
trên mã cũ** với *"-115K"* đè *"0"*. Nới ×1,05 trước khi làm tròn để chấm ở cực trị không nằm đúng mép khung (nơi
`FlClipData.all()` cắt nửa chấm). Realme: trục nay *15M · 10M · 5M · 0* (cũ *16.3M · 10.8M · 5.4M · 0*).

### ~~G52 — Đầu thẻ hoá đơn chật ở 360 dp~~ · ✅ ĐÓNG (2026-10-09) · ⏸️ hoãn (2026-09-29, người dùng chốt)

> ✅ **Đóng 2026-10-09.** Đo lại bằng font thật trước khi sửa: nửa thứ nhất (*"Hạn 05/10/2026"* gãy hai dòng
> cạnh chip) **đã hết từ G74** (2026-10-07 — `BillStatusHeader` đo tên + hạn + chip, không vừa thì chip xuống
> dòng). Nửa thứ hai **còn**, và chỉ ở **360 dp**: tên + hạn vừa cạnh chip nên chip ở lại cùng hàng, còn dòng
> *"Nhà cửa • Tiền mặt • Tự trả"* — G74 cố ý không đo — chỉ được **108 dp** trong khi cần **150** (ở 320 dp chip
> đã xếp chồng nên dòng ấy vẽ trọn; ở 411 dp vừa khít). Người dùng chọn (trong ba cách: trải rộng · đo cả dòng ví
> rồi xếp chồng chip · cho xuống hai dòng): **khi chip cùng hàng, dòng danh mục • ví ra khỏi cột chữ và trải hết
> bề ngang dưới cả tên lẫn chip** (thụt bằng ô biểu tượng). Chip thấp hơn hai dòng tên + hạn nên không đè, thẻ
> **không cao thêm**; khi chip đã xếp chồng thì dòng ấy ở lại trong cột chữ, trên chip, như G74. Bốn ca font thật
> ở `bill_page_hep_test.dart` (hai ca 360 dp đỏ trên mã cũ). Nghiệm thu **Realme RMX2205 360 dp**: *"Giải trí •
> Tiền mặt • Tự trả"* và *"Chi khác • Tiền mặt"* vẽ trọn dưới chip *QUÁ HẠN* / *SẮP ĐẾN HẠN*.

**Thấy khi nghiệm thu B2 trên Realme RMX2205 (360 dp)**, cùng lượt với G51 nhưng nhẹ
hơn: thông tin vẫn đọc được, nên người dùng chốt **sang B3 trước, ghi lại để sau**.

- Dòng *"Hạn 05/10/2026"* xuống **hai dòng** (*"Hạn"* / *"05/10/2026"*) khi đứng cạnh
  chip trạng thái rộng *"CHƯA THANH TOÁN"* — chip ấy chiếm gần nửa bề ngang đầu thẻ
  (`BillStatusHeader`).
- Tên ví trong dòng phụ bị cắt: *"Nhà cửa • Tiền…"* (danh mục · ví · *Tự trả*).

Không đổi bố cục ở lượt B2 / G51 — hai chỗ này có từ trước. Sửa thì phải đo ở khổ
tương đương như G51 (font test rộng gấp đôi, bẫy 4.4) và nghiệm thu trên máy 360 dp.

### ~~G51 — Số tiền trên thẻ hoá đơn bị cắt ở 360 dp~~ · ✅ ĐÓNG (2026-09-29, mở và đóng trong cùng ngày)

**Lộ ra khi nghiệm thu B2 trên Realme RMX2205 (360 dp).** Mọi thẻ ở trang Hoá đơn in
số tiền cụt — *"45.0…"*, *"10.0…"*, *"3.00…"*, *"100…."* — nên người dùng **không đọc
được số tiền của chính hoá đơn** trên danh sách. Không có sọc vàng nào: `ellipsis`
là cắt hợp lệ, `takeException()` trả `null`.

**Nguyên nhân (đọc mã, chưa sửa):** hàng dưới của thẻ trong `bill_page.dart` là
`Flexible(Text(amount, ellipsis))` · bút · thùng rác · **`Spacer()`** · nút *Thanh
toán*. `Flexible` và `Spacer` cùng `flex: 1` nên **chia đôi** chỗ trống còn lại sau
các con cố định — số tiền bị trần ở một nửa dù `Spacer` sẵn sàng co về 0. Ở 411 dp
chỗ trống đủ rộng nên không lộ; ở 360 dp (cộng cỡ chữ hệ thống của máy) thì lộ.

**Không do B2:** lượt B2 chỉ dời thân dòng hoá đơn vào hàm `_dongHoaDon` (để mỗi tab
thành `CustomScrollView`), không đổi bố cục hàng ấy.

**Sửa (`77521f2`, cùng ngày — theo nếp *sửa lỗi trước, thêm tính năng sau*):**
[số tiền · bút · thùng rác] nằm trong **một** `Expanded`, số tiền là `Flexible` **duy
nhất** của hàng con — được toàn bộ chỗ trống, hai biểu tượng vẫn đi liền sau nó, nút
*Thanh toán* vẫn sát mép phải. ⚠️ **Đừng** chỉ đổi `Flexible` thành `Expanded` và bỏ
`Spacer`: số tiền chiếm hết hàng, bút và thùng rác bị đẩy sang sát nút.

**Ca canh** `test/features/bill/presentation/pages/bill_page_so_tien_test.dart`: font
test rộng gấp đôi (bẫy 4.4) nên đo ở **500 và 600** — bản cũ cắt cả hai khổ, bản sửa
không (đo bằng phép thử 411 · 500 · 600 · 700 · 822). Khoảng *chữ → bút* đo bằng bề
rộng **chữ** (`getMaxIntrinsicWidth`), không đo hộp: số tiền `Expanded` thì hộp giãn
tới sát bút nên khoảng *hộp → bút* vẫn là 12 — bản sai ấy từng **xanh** với phép đo
hộp. Bản cũ và bản sai đều đỏ. Nghiệm thu lại trên Realme: *10.000 đ · 3.000.000 đ ·
100.000 đ* hiện đủ.

### ~~G47 — Thẻ hoá đơn (và bảng tra của ngân sách) mất tên danh mục mặc định toàn cục / đã xoá mềm~~ · ✅ ĐÓNG (2026-09-19, mở và đóng trong cùng ngày)

**Cùng họ G41, ở hai mảng G41 chưa chạm.** Máy ảo trong lượt đánh giá UX
2026-09-19 (mục **E8** của danh sách) cho thấy **2/3 thẻ hoá đơn** hiện "Danh
mục đã xoá". `BillPage._napTenGoi`, `BillDetailPage` và
`BudgetLocalDataSourceImpl.getAllCategories` (hàm chỉ nuôi `lookupFor`) dựng
`TransactionLookup` từ **`categoryDao.getAll(accountId)`** — hàm lọc
`idaccount = accountId` **và** `deletedAt IS NULL`, nên cả hàng mặc định toàn
cục (`idaccount = 0`, `isDefault = true` — `sync_engine.dart:733`) lẫn hàng đã
xoá mềm (tên vẫn còn nguyên trong hàng) đều mất tên. G41 đã đặt định nghĩa
duy nhất `categoryDao.getBangTraTen` cho hai repository của Phân tích, nhưng
ba chỗ này là ba bản chép tay khác của cùng truy vấn sai.

**Sửa:** cả ba về `getBangTraTen`. Không đổi giao diện `BudgetLocalDataSource`
(fake trong test không phải sửa). **Schema không đổi, payload không đổi.**

**Test:** `test/features/bill/presentation/pages/bill_page_ten_danh_muc_mac_dinh_test.dart`
— CSDL trong bộ nhớ với một danh mục `idaccount = 0` + `isDefault` và một danh
mục xoá mềm; thẻ hoá đơn phải hiện tên cả hai, `getAllCategories` phải trả cả
hai. ⚠️ Bản đầu đặt tên mẫu là "Hóa đơn" và **xanh oan**: `textContaining`
bắt trúng **tiêu đề trang** "Hóa đơn" — đổi sang "Nhà cửa" và đòi luôn thẻ
"Tiền điện" dựng được (cùng bài học G43: đòi kết quả, không đòi vắng mặt).

### ~~G46 — Trần số chữ số thiếu ở BỐN mảng còn lại, không riêng ví~~ · ✅ ĐÓNG (2026-09-18)

**Lượt soát nối tiếp G45**, lần này quét cả app thay vì một mảng. Kết quả: lỗ
hổng vừa vá ở ô số dư ví **không phải chuyện riêng của ví**. Đo trên CSDL cùng
ngày, **tám** cột tiền đều là `numeric(15,2)` — `transaction."Amount"`,
`bill."Amount"`, bốn cột của `budget`, `goal."Target_amount"`,
`wallet."Balance"` — và **không ô nhập nào trong bốn mảng còn lại** giới hạn số
chữ số.

| Mảng | Ô | Hỏng thế nào |
|---|---|---|
| **Giao dịch** | bàn phím **tự vẽ**, không phải `TextField` | Nặng nhất: người dùng ghi giao dịch **hàng ngày**, và bàn phím có phím **`000`** nên ba chữ số vào một lúc. `inputFormatters` không với tới đây |
| **Hoá đơn** | ô số tiền ở cả màn Thêm lẫn màn Sửa | Không bộ lọc nào |
| **Mục tiêu** | số tiền mục tiêu, số tiền trích | nt |
| **Ngân sách** | hạn mức, ngưỡng cảnh báo bằng tiền | nt |

Hậu quả giống hệt G45: tràn cho SQLSTATE `22003`, `sync.service.js` **không có
nhánh** cho mã ấy nên trả `DB_ERROR`, và `_permanentCodes` của `GuiLoDongBo` là
**danh sách trắng** — bản ghi bị **gửi lại ở mọi chu kỳ đồng bộ**, im lặng.

**Đã sửa thế nào.** Ba mảng dùng `TextField` thì áp `GioiHanSoChuSo` có sẵn.
Màn giao dịch thì phép gõ tách thành hàm thuần **`themPhimSoTien`**
(`transaction/domain/ban_phim_so_tien.dart`) — ⚠️ phím `000` **cắt bớt cho vừa
trần** thay vì bỏ cả cụm, vì bỏ cả cụm thì người dùng bấm mà không thấy gì xảy
ra. Và thêm **test quét `lib/` thứ tám** (`o_nhap_tien_co_tran_test.dart`) để ô
tiền mới thêm sau này không mở lại lỗ hổng: thiếu trần **không gây lỗi nào** lúc
gõ, chỉ hàng đợi đẩy là hỏng, và nó hỏng ở nơi không ai nhìn.

> ⚠️ **Lại một lỗi bố cục do chính trần sinh ra, lại chỉ máy ảo thấy.** Ở cỡ
> chữ 48 trên 411dp, `9.999.999.999.999đ` — **đúng trần** — **ngắt thành hai
> dòng**, chữ "đ" rơi xuống dòng dưới và đẩy cả màn xuống. Đây **không phải
> tràn**: không sọc vàng, không `FlutterError`, `takeException()` trả `null`.
> `Text` chỉ lặng lẽ ngắt dòng. Sửa bằng widget `SoTienLon` (`FittedBox` +
> `maxLines: 1`), và ca test phải đo **chiều cao thật** — bản sai cho 207px so
> với ngưỡng 80.
>
> Đây là **lần thứ ba trong cùng một ngày** một trần số chữ số biến giá trị lớn
> nhất thành **hợp lệ đạt tới được** rồi lộ ra một bố cục chưa từng được thử với
> giá trị ấy. Hai lần trước ở G45.

⚠️ **`FittedBox` dùng được ở đây mà không dùng được ở ô số dư ví**: nó đo con ở
ràng buộc **vô hạn** rồi mới thu nhỏ; `Text` có bề rộng tự nhiên xác định dưới
ràng buộc ấy, còn `TextField` thì không. Đó là lý do `OSoDuVi` phải đi đường
khác (`Flexible` + bậc thang cỡ chữ).

**Mọi ràng buộc khác đã kiểm và AN TOÀN**, không phải sửa gì: số tiền phải dương
ở hoá đơn / mục tiêu / giao dịch / ngân sách; ngưỡng phần trăm 1–100; ngày kết
thúc sau ngày bắt đầu (khoá bằng `firstDate` của bộ chọn); tiến độ mục tiêu
không âm được (giao diện chặn rút quá, repository có trần thứ hai theo số dư
ví); `chk_transaction_type` và `chk_category_classify` đều được normalizer dịch;
bảy ô nhập tên đều có giới hạn độ dài.

**Nghiệm thu máy ảo:** bấm phím số 20 lần ở màn Thêm giao dịch thì dừng đúng 13
chữ số, hiện **một dòng**, cỡ chữ đã co, bố cục dưới không bị đẩy.

---

### ~~G45 — Sáu lỗ hổng của mảng ví, tìm được bằng một lượt soát có chủ đích~~ · ✅ ĐÓNG (2026-09-18)

**Không đến từ một báo lỗi.** Người dùng hỏi *"chức năng ví đã đầy đủ chưa, có
lỗ hổng nào cần sửa, có ràng buộc nào cần bổ sung không"*, và lượt soát đối
chiếu **từng ràng buộc PostgreSQL với chốt tương ứng phía client**. Sáu chỗ hở,
tất cả đều hỏng **im lặng**.

| # | Lỗ hổng | Hỏng thế nào |
|---|---|---|
| 1 | `softDelete` **không chặn** ví đang gắn **hoá đơn** | `payBill` không kiểm ví còn sống, nên hoá đơn vẫn trả được sau khi ví bị xoá; khoản chi rơi vào một ví đã bị loại khỏi mọi phép cộng tổng. Tiền biến mất khỏi màn hình trong khi hoá đơn báo "đã trả". Server để `fk_bill_wallet` là **ON DELETE RESTRICT** |
| 2 | Phép đếm giao dịch bỏ sót **khoản chuyển đến** | `getByWallet` chỉ lọc cột `walletId`. Ví **chỉ nhận tiền chuyển vào** bị coi là chưa từng dùng và xoá được — đi ngược chính câu "bảo toàn lịch sử tài chính" của thông báo ngay cạnh |
| 3 | Ô nhập số dư **không giới hạn chữ số** | `Balance` là `numeric(15,2)`. 14 chữ số là tràn → SQLSTATE `22003` → `sync.service.js` **không có nhánh** cho mã ấy nên trả `DB_ERROR` → danh sách lỗi vĩnh viễn của client là **danh sách trắng** nên ví bị **gửi lại ở mọi chu kỳ đồng bộ**. Đúng vòng lặp mà G31 và G14 sinh ra để chặn |
| 4 | Thông báo "điều chuyển số dư về 0đ trước khi xóa" dẫn tới **ngõ cụt** | Từ G37 mọi cách đưa số dư về 0 đều **sinh thêm một giao dịch**, nên làm đúng lời khuyên xong thì ràng buộc 2 chặn lại. Người dùng đi hết một vòng về đúng chỗ cũ |
| 5 | `walletForPush` **không chuẩn hoá `currency`** | Cột thứ **ba** có CHECK (`chk_wallet_currency`), và là cột duy nhất chưa được che — `type` và `status` đều đã có lớp này sau khi mỗi cột làm ví kẹt hàng đợi một lần. Chưa có đường kích hoạt vì không màn nào cho đổi tiền tệ |
| 6 | Không chốt cấm đặt ví **đã lưu trữ** làm ví mặc định | Chiều ngược của chốt đã có trong `setArchived`. `chonViChonSan` tìm ví mặc định trong danh sách đã lọc, không thấy thì lặng lẽ rơi về ví đầu — công tắc người dùng vừa bật chẳng làm gì cả |

**Đo được trên dữ liệu thật** (PostgreSQL, cùng ngày): 26 hoá đơn đang gắn ví,
trong đó **một ví xoá được ngay lúc ấy**; 12 giao dịch chuyển có ví đích, chưa
ví nào rơi vào trạng thái của lỗ hổng 2.

**Đã sửa thế nào.** `TransactionDao.demGiaoDichLienQuan` đếm cả hai vai (nguồn
và đích) — `getByWallet` **giữ nguyên nghĩa cũ** vì hai ca test của mục tiêu
dựa đúng vào nó. `softDelete` thêm ràng buộc thứ tư cho hoá đơn. `GioiHanSoChuSo`
+ `kSoChuSoToiDaSoTien` ở `core/utils/gioi_han_do_dai.dart`, áp cho ô số dư ở cả
hai màn. `SyncPayloadNormalizer.tienTeGuiLen` nâng chữ thường thay vì gộp mù về
`VND` (gộp mù là biến một ví USD viết thường thành ví VND).
`_kiemViMacDinhConDung` ở datasource, và nó **chỉ canh đường người dùng chủ
động** — nhánh kéo về ghi thẳng qua DAO nên trạng thái ấy vẫn đến được từ máy
khác, đúng như chốt trong `setArchived`.

> ⚠️ **Hai lỗi NỮA do chính lượt vá sinh ra, cả hai chỉ máy ảo thấy.**
>
> **(a) Tràn bố cục 70px.** Giới hạn 13 chữ số biến một trạng thái vốn vô nghĩa
> thành trạng thái **hợp lệ đạt tới được**, và ở cỡ chữ 40 trên 411dp thì
> `9.999.999.999.999` vỡ ô nhập. Sửa bằng cách tách ô số dư thành widget
> `OSoDuVi`. ⚠️ Và bản sai lật một kết luận: thứ chặn tràn là **`Flexible`**
> bọc `IntrinsicWidth`, **không phải** bậc thang cỡ chữ — ép cỡ chữ về 40 cố
> định mà hai ca bố cục **vẫn xanh**. Bậc thang lo việc khác: giữ con số đọc
> được hết thay vì bị cuộn khuất. Vì thế ca test của nó đo **thẳng giá trị trả
> về**, không đo bề rộng.
>
> **(b) Cỡ chữ không co khi gõ.** `OSoDuVi` là `StatelessWidget` đọc
> `controller.text` một lần lúc dựng, nên số dài giữ nguyên cỡ 40 rồi bị cuộn
> khuất **mất chữ số đầu** — bố cục vẫn lành nhờ `Flexible` nên **không có sọc
> vàng nào để nhìn thấy**, và ba ca dựng-một-lần cũng mù. Sửa bằng
> `ValueListenableBuilder` nghe chính controller.

**Nghiệm thu máy ảo** (`emulator-5554`, tài khoản thật): gõ 18 chữ số vào ô số
dư thì chỉ nhận `9.999.999.999.999`, hiện **trọn vẹn**, cỡ chữ đã co, không tràn
không cuộn khuất. Xoá ví "test" (số dư −100.000) thì hiện đúng thông báo mới và
ví không bị xoá.

**Ba chỗ cố ý KHÔNG làm**, để đúng phạm vi "sửa lỗ hổng": không thêm nút "đưa số
dư về 0 rồi lưu trữ" (tính năng mới); không ép màn Sửa ví dùng `OSoDuVi` (bố cục
riêng, `Expanded` nên vốn không tràn — nhưng khối `onChanged` chèn dấu chấm vẫn
còn **hai bản**); không xoá `bienThang` dù nó đã 0 chỗ gọi từ mục 3.33.

---

### ~~G44 — Kỳ rỗng: tệp xuất in khối Ngân sách mà màn Xem trước giấu~~ · ✅ ĐÓNG (2026-09-18)

**Tìm được khi nghiệm thu máy ảo** cho mục **3.31** `ANALYTICS_FEATURE.md` (ba
khối cuối vào tệp xuất). Tôi xuất một khoảng **rỗng** — 08–17/09 — để chạm
nhánh "kỳ không có giao dịch nào", và thấy tệp PDF ca ấy vẫn in bảng *Ngân sách
kỳ này* với dòng `Giáo dục 45.000đ / 50.000đ / 5.000đ`.

**Triệu chứng.** Kỳ rỗng thì `report_preview_page.dart` đi nhánh
`if (baoCao.rong)` và dựng thẻ *"Không có giao dịch nào trong khoảng đã chọn"*
thay cho cả nhánh `else`. Còn `xuat_tep.dart` gác từng khối theo **độ rỗng của
chính khối ấy** (`if (bc.nganSach.isNotEmpty)`, `if (bc.theoVi.isNotEmpty)`, …).
Với kỳ rỗng thì mọi khối khác cũng rỗng theo nên trùng khớp — **trừ ngân sách**,
thứ tồn tại độc lập với giao dịch.

> ⚠️ **Đính chính, đo lại 2026-09-18 khi sửa.** Tiêu đề cũ của mục này ghi *"màn
> Xem trước giấu **mọi** khối"* — **không đúng**. Kỳ rỗng thì màn vẫn hiện đầu
> báo cáo, khối **Dòng tiền** và **ba thẻ tổng**; chỉ nhóm khối nằm trong nhánh
> `else` mới bị giấu. Điều ấy quan trọng khi chọn chiều sửa: tệp xuất **cũng**
> in đúng ba thứ đó khi kỳ rỗng (số dư đầu/cuối kỳ, ba dòng kỳ trước, tổng bằng
> 0), nên hai bên đã khớp nhau sẵn ở đấy và lệch **đúng một khối**.

**Bán kính ảnh hưởng: hẹp.** Chỉ hiện ra khi (a) kỳ không có giao dịch nào
**và** (b) tài khoản có ít nhất một ngân sách đang chạy. Con số in ra **không
sai** — ngân sách ấy có thật, "đã chi" của nó đếm theo kỳ của chính nó chứ
không theo kỳ báo cáo. Không hàng nào kẹt, không lỗi, không đồng bộ.

**Vì sao từng hoãn.** Chưa rõ **bên nào mới đúng**, và đó là câu hỏi sản phẩm
chứ không phải câu hỏi kỹ thuật:

- Tệp đúng → màn Xem trước đang **giấu** một thông tin có thật chỉ vì kỳ rỗng.
- Màn đúng → tệp đang chở một bảng mà người đọc sẽ hiểu là "của kỳ này", trong
  khi kỳ này chẳng có gì.

Sửa theo chiều nào cũng là một dòng, nhưng chọn sai chiều thì **không ai phát
hiện được** — cả hai bản đều trông hợp lý. Nằm ngoài phạm vi người dùng đã
duyệt cho mục 3.31 (đúng ba khối), nên ghi lại thay vì tự quyết.

**Chiều đã chốt (người dùng, 2026-09-18): tệp theo màn.** Kỳ rỗng thì tệp bỏ
hẳn khối Ngân sách. Lý lẽ: người đọc hiểu mọi bảng trong tệp là "của kỳ này",
mà "đã chi" của ngân sách đếm theo kỳ của **chính nó** — và người cầm tờ PDF
không có chỗ hỏi lại, khác hẳn người đang đứng trước màn hình.

**Đã làm thế nào.** Một vị từ thuần **`inKhoiTheoKy(BaoCao)`** ở
`analytics/domain/bao_cao_xuat.dart`, cạnh `rong`; **ba** chỗ gọi cùng đọc nó:
`csvBaoCao`, `pdfBaoCao`, và nhánh rỗng của `report_preview_page.dart`. Khối
*Số liệu nhanh* vốn đã gác bằng `!bc.rong` kèm chú thích *"cùng luật với màn
Xem trước"* — nay chú thích ấy thành **mã**.

⚠️ **Vế `inKhoiTheoKy` phải đứng cạnh `isNotEmpty` ở khối ngân sách chứ không
thay nó**, và chỉ ở **khối ấy**: mọi khối khác tự rỗng theo kỳ rỗng nên vế thừa,
còn ngân sách thì không.

⚠️ **Ở nhánh PDF phải chặn tại NGUỒN HÀNG, không bọc quanh `_pdfBang`** — hàm ấy
tự bỏ cả bảng khi không còn hàng nào, nên truyền danh sách rỗng là đủ và không
sinh thêm một nhánh `if` thứ hai phải giữ đồng bộ.

**Năm ca test.** Hai ca ở `bao_cao_xuat_test.dart` canh vị từ hai chiều; hai ca
CSV ở `xuat_tep_test.dart` (kỳ rỗng bỏ hẳn bảng · kỳ thường in y như cũ); một ca
PDF. ⚠️ **PDF nén luồng nội dung nên không tìm chuỗi trong byte được** — phép đo
thay thế là so **độ dài** hai tệp của cùng một kỳ rỗng, một bản có ngân sách một
bản không. Bản sai có chủ ý làm ca ấy đỏ với chênh lệch **2 847 byte**, nên nó
canh thật chứ không xanh sẵn.

---

### ~~G43 — Nút "Tuỳ chọn" của bộ chọn phạm vi chết im lặng~~ · ✅ ĐÓNG (2026-09-16, mở và đóng trong cùng ngày)

**Tìm được khi nghiệm thu máy ảo** cho mục #2 (so cùng kỳ năm trước) — tôi cần
một kỳ **tuỳ chọn** để xem nhãn dài nhất, và nút ấy không chịu mở.

**Triệu chứng.** Chạm "Tuỳ chọn" trong bộ chọn phạm vi: **không có gì xảy ra**.
Không bộ chọn ngày, không toast, không màn đỏ, sheet vẫn nguyên đó. Bốn chip
kia (`Tuần`, `Tháng`, `Quý`, `Năm`) đều ăn bình thường ở **cùng một hàng**, nên
thoạt nhìn rất giống lỗi toạ độ chạm của chính mình.

**Bằng chứng.** `adb logcat`:

```
E flutter : Unhandled Exception: 'package:flutter/src/material/date_picker.dart':
  Failed assertion: line 1218 pos 5:
  'initialDateRange == null || !initialDateRange.end.isAfter(lastDate)':
  initialDateRange's end date must be on or before lastDate 2026-09-16 00:00:00.000.
  #2  showDateRangePicker (package:flutter/src/material/date_picker.dart:1218:5)
```

**Gốc rễ.** `_chonKhoangTuyY` truyền thẳng kỳ đang xem làm khoảng khởi tạo:

```dart
lastDate: nay,
initialDateRange: DateTimeRange(
  start: widget.kyHienTai.from,
  end: widget.kyHienTai.to.subtract(const Duration(days: 1)),
),
```

`lastDate` là **hôm nay**, còn kỳ đang xem thì kết thúc ở **cuối kỳ**. Nên bất
cứ khi nào kỳ chứa hôm nay — tức *Tháng này*, *Quý này*, *Năm nay*, *Tuần này*,
**đúng trạng thái mặc định của trang** — mốc cuối nằm ở tương lai và assertion
nổ.

⚠️ **Vì sao nó sống được lâu và im lặng đến thế:** đây là exception trong một
hàm `async` mà **không ai `await` có `catch`**, nên Flutter chỉ in ra console.
Trên bản release người dùng còn không có console. Nút trông như một nút chết.

**Vì sao bộ test mù.** `chon_pham_vi_sheet_test.dart` có **10** ca, nhưng **không
ca nào chạm vào chip "Tuỳ chọn"** — chúng kiểm nhãn, kiểm đổi chip đổi danh sách,
kiểm khổ 411dp. Lỗi nằm sau một cú chạm mà không ai thực hiện. Có sẵn từ **P1
(2026-09-15)**, qua cả lượt nghiệm thu máy ảo hôm ấy.

**Sửa.** Phép kẹp tách thành hàm thuần `khoangKhoiTaoBoChonNgay` ở
`analytics/domain/pham_vi_ky.dart`: kẹp `from` vào `somNhat`, kẹp mốc cuối vào
`muonNhat`, và trả **`null`** khi kỳ không giao với dải cho phép — chỗ gọi mở bộ
chọn mà không đặt khoảng sẵn. Trả một khoảng đảo đầu-cuối chỉ là đổi sang một
assertion khác.

**Bốn ca widget mới** chạm thật vào nút, từ bốn kỳ khác nhau, và **không** chỉ
kiểm "không ném" mà còn đòi `DateRangePickerDialog` thật sự hiện — "không ném"
một mình vẫn xanh với một nút chết. ⚠️ Chúng phải gọi `ensureVisible` trước khi
chạm: font bộ test rộng gấp đôi nên năm chip **không vừa** 411dp ở đó, dù trên
máy thật thì vừa (bẫy 4.4). Nới khổ test là bỏ luôn phép đo chặt mà tệp ấy cố ý
giữ, nên kéo hàng chip — vốn cuộn ngang được — vào tầm nhìn.

**Nghiệm thu máy ảo.** Bộ chọn mở được từ "Tháng này", khoảng khởi tạo hiện
`Sep 1 – Sep 16` và mọi ngày sau 16/09 bị khoá; chọn xong trang đổi sang kỳ
`01/09 – 16/09`; `logcat` **0** dòng `Unhandled Exception`.

**Bài học.** Một hàng nút mà chỉ **một** nút hỏng thì rất dễ bị đổ cho toạ độ
chạm. Cách rẻ để phân biệt: bấm một nút **khác trong cùng hàng** — nếu nó ăn
thì toạ độ đúng, và vấn đề nằm trong mã.

### ~~G42 — Ví đã xoá mềm vẫn phình "số dư cuối kỳ"~~ · ✅ ĐÓNG (2026-09-16, mở và đóng trong cùng ngày)

**Tìm được khi soát tài liệu**, không phải khi chạy app: viết mục 3.27 cho tính
năng dự báo dòng tiền thì phải đọc lại mọi chỗ cộng số dư ví, và một chỗ không
khớp những chỗ còn lại.

**Triệu chứng.** "Số dư cuối kỳ" của khối **Dòng tiền** và của **thác nước
"Tiền đi đâu"** cộng cả số dư những ví người dùng đã xoá. Ca test tái hiện đo
được **17.000.000 thay vì 10.000.000** với một ví xoá mềm còn 7.000.000. Không
exception, không log — chỉ một con số người dùng không có.

**Gốc rễ.** `AnalyticsRepositoryImpl` đọc ví bằng truy vấn thẳng
`db.select(db.wallets)..where(idaccount)`, **không lọc `deletedAt`**. Điều đó
**có chủ ý và vẫn đúng**: giao dịch cũ vẫn trỏ vào ví đã xoá, và bảng tra tên ví
cần hàng ấy để dòng "Phân bổ theo ví" không hiện "Ví đã xoá" thay cho tên thật.
Cái sai là hàng ấy rồi được cộng `balance` qua `viTinhVaoTong`, mà hàm khi ấy
chỉ hỏi hai vế — `includeInTotal` và trạng thái lưu trữ.

⚠️ **Phạm vi hẹp hơn lần báo đầu.** Lượt soát ban đầu ghi
`bao_cao_repository_impl.dart:84` "cần soát cùng"; đọc kỹ thì nó **không sai** —
nó đi qua `walletDao.getAll`, và hàm ấy **có** lọc `deletedAt.isNull()`.
`wallet_repository_impl.dart:115` cũng vậy. Chỉ **một** chỗ hỏng.

**Vì sao sửa trong hàm, không vá ở chỗ gọi.** `vi_tinh_vao_tong_test.dart` mở
đầu bằng câu *"tệp này tồn tại để không có bản thứ năm"* — và đây đúng là bản
thứ năm, chỉ quên một vế khác. Vá tại chỗ gọi là để nguyên cái bẫy cho chỗ gọi
thứ sáu. Nay `viTinhVaoTong` nhận `isDeleted` (mặc định `false`, nên bốn chỗ đọc
qua `walletDao` không phải sửa gì), và `du_bao_dong_tien.dart` bỏ phép kiểm
`isDeleted` riêng nó từng tự làm — đó cũng là một bản chép tay.

**Kiểm:** hai ca mới (một ở tầng thuần, một ở repository); bản sai có chủ ý bỏ
vế `!isDeleted` làm **cả hai** đỏ đúng con số. `flutter test` **2643/2643**,
`flutter analyze` **25 issue, 0 error**.

### ~~G41 — Giao dịch trỏ vào danh mục mặc định toàn cục bị mất tên~~ · ✅ ĐÓNG (2026-09-15, mở và đóng trong cùng ngày)

**Vì sao thấy.** Nghiệm thu máy ảo cho hạng mục *tỉ lệ tiết kiệm*, khối "Xu
hướng 6 tháng" hiện **hai chip cùng mang tên "Danh mục đã xoá"** — hai danh mục
khác nhau đội một cái tên, không cách nào phân biệt. Lỗi không thuộc hạng mục
đang làm; nó có sẵn từ trước.

**Bằng chứng trước, không đoán.** Truy vấn PostgreSQL gom giao dịch theo chủ sở
hữu danh mục cho ra **đúng hai** hàng bất thường ở tài khoản đang đăng nhập:

| Danh mục | `Create_by` | `Is_default` | `Delete_at` | Số giao dịch |
|---|---|---|---|---|
| `Chi khác` | **1** | true | đã xoá mềm | 2 |
| `Làm thêm` | **1** | true | đã xoá mềm | 1 |

Đúng **hai** — khớp số chip trên màn hình. Cả hai là **danh mục mặc định toàn
cục**, nằm trong nhóm năm hàng backend xoá mềm ngày 2026-09-07 khi thu bộ khuôn
về 13 stable UUID.

**Gốc rễ.** `sync_engine` quy `is_default = true` thành **`idaccount = 0`**
(`sync_engine.dart:733`), nên hàng mặc định toàn cục **không mang mã tài khoản
nào**. Nhưng cả hai repository tra danh mục đều lọc `t.idaccount.equals(idaccount)`:

- `analytics_repository_impl.dart` — trang Thống kê
- `bao_cao_repository_impl.dart` — trang Xuất báo cáo và màn Xem trước

Hai bản chép tay của cùng một truy vấn, và **cả hai cùng thiếu** vế `isDefault`.
Giao dịch trỏ vào hàng ấy tra không ra tên → rơi vào nhánh `?? 'Danh mục đã xoá'`.

⚠️ **Ảnh hưởng rộng hơn cái chip đã lộ ra.** Cùng bảng tra ấy nuôi donut "Cơ cấu
theo danh mục", cột thác nước, và danh sách danh mục cuối trang — tất cả đều mất
tên. Chip chỉ tình cờ là chỗ **hai** cái trùng nhau nằm cạnh nhau nên mắt bắt
được; những chỗ kia chỉ hiện *một* nhãn "Danh mục đã xoá" trông hợp lý.

**Vì sao lọt qua mọi lượt trước.** Chú thích ở cả hai chỗ nói rất đúng về vế thứ
nhất — *"kể cả hàng đã xoá mềm, vì tên thật còn nằm trong hàng"* — và có test
canh hẳn hoi. Vế thứ hai thì không ai viết ra: hàng mặc định **cũng** không
thuộc `idaccount` nào. Test cũ dựng danh mục đã xoá mềm với `idaccount: 1`, tức
một hình dạng **không tồn tại trên máy thật** cho danh mục mặc định.

**Bản sửa.** Một định nghĩa duy nhất ở `CategoryDao.getBangTraTen` /
`watchBangTraTen`, lọc theo **cờ** `isDefault` bên cạnh tài khoản — cùng khuôn
với `getNamesInUse` vốn đã làm đúng từ trước. Hai repository nay gọi nó thay vì
tự viết truy vấn. Hai ca test mới, mỗi repository một ca, dựng đúng hình dạng
thật (`idaccount: 0`, `isDefault: true`, đã xoá mềm); cả hai đỏ trước khi sửa.

**Nghiệm thu.** Máy ảo, cùng tài khoản: chip nay là **"Chi khác"**, "Di chuyển",
"Giáo dục" — không còn chip "Danh mục đã xoá" nào; cột thác nước đổi từ
`Danh mục đ…` sang **"Chi khác"**. `flutter test` **2573/2573**, `flutter
analyze` **25 issue, 0 error**.

**Bài học.** Hai bản chép tay của một truy vấn là chỗ lỗi sống lâu nhất: sửa một
bên thì bên kia vẫn sai, và chú thích đúng ở cả hai chỗ khiến không ai nghi. Khi
một luật có hai nơi thi hành, đưa nó về DAO trước rồi mới sửa.

### ~~G40 — Trang Xem trước báo cáo lệch cột số tiền~~ · ✅ ĐÓNG (2026-09-15, mở và đóng trong cùng ngày)

**Vì sao nghi.** Ngày 2026-09-15, người dùng bắt được trên máy ảo rằng cột số
tiền ở hai khối mới của trang Phân tích — "Phân bổ theo ví" và "Top 5 khoản chi"
— **không thẳng mép phải**; đo trong widget test thấy lệch **26,5px**. Gốc rễ là
`Flexible`: nó và `Expanded` đều mang `flex: 1` nên chia đôi chỗ trống như nhau,
nhưng `Flexible` để con giữ **bề rộng tự nhiên** và `MainAxisAlignment.start`
đẩy phần thừa về **cuối hàng**, nên `alignment: centerRight` của `FittedBox`
đang canh phải bên trong một cái hộp đang trôi. Bẫy **4.19**
`ANALYTICS_FEATURE.md`.

Hai khối ấy của trang Phân tích **chép khuôn từ `report_preview_page.dart`**, và
tệp gốc vẫn còn nguyên `Flexible(child: FittedBox(…))`. Cùng khuôn, cùng dạng dữ
liệu (số tiền dài ngắn khác nhau theo hàng), nên nhiều khả năng cùng lệch.

Hạng mục ấy **không sửa ngay**, vì hai lý do cố ý: chưa nhìn tận mắt (suy từ mã
sang kết luận "chắc chắn lệch" là đúng loại sai lầm phiên 12 đã trả giá với
Stitch), và người dùng báo về trang Phân tích chứ không phải trang này.

**Đo được gì khi mở lại.** Mở trang trên máy ảo `emulator-5554` với dữ liệu thật
ngày 2026-09-15, rồi đếm pixel chữ trên từng hàng. Lỗi có thật, và **nặng hơn**
chỗ đã sửa:

| Khối | Mép phải chữ (px, ảnh 1080) | Lệch |
|---|---|---|
| Chi theo danh mục | 856 … 949 | **93px** |
| Phân bổ theo ví | 727 … 783 | **56px** |
| Top 5 khoản chi | 771 … 776 | 5px, nhưng cách mép thẻ hơn 200px |

⚠️ **Và không phải hai khối mà SÁU.** Dòng đầu của lỗ hổng này đoán theo tên hai
khối mà người dùng báo; đếm bằng máy thì `report_preview_page.dart` mang **sáu**
chỗ cùng khuôn `Expanded(tên) + Flexible(FittedBox centerRight)` — thêm khối
ngân sách, thu/chi theo danh mục, danh sách giao dịch, và hàng "Thay đổi trong
kỳ" của khối dòng tiền. Bài học: khi một lỗ hổng mô tả lỗi bằng **tên khối**
người dùng nhìn thấy, hãy `grep` khuôn mã trước khi tin vào con số ấy.

**Sửa.** Sáu `Flexible` → `Expanded`. Cột trái **không mất chỗ nào**: tỉ lệ chia
vẫn 1:1, chỉ khác ai giữ phần thừa. Đo lại trên máy ảo sau khi sửa: **0px** lệch
ở mọi khối, mọi cột kết thúc ở 979–982 — tức sát mép trong của thẻ.

⚠️ **Sáu ca test mới suýt vô dụng vì font của bộ test.** Viết ở khổ 411dp thì ba
trong sáu ca **xanh ngay từ đầu** dù máy ảo đo được lệch 93px: font "Ahem" rộng
gấp đôi ngoài đời (bẫy 4.4) nên mọi chuỗi đều **tràn** suất, `FittedBox` thu nhỏ
chúng cho vừa, và hộp nào cũng lấp đầy suất của nó — đúng thứ mà `Expanded` lẽ
ra mới làm được. Lỗi chỉ lộ khi chữ **ngắn hơn** suất. Phải cho khung rộng **gấp
đôi** (822dp) để trả lại đúng tỷ lệ chữ trên suất của điện thoại thật.

⚠️ **Đừng dựa vào mẹo đếm pixel vàng** để tìm lỗi này: nó không phải lỗi tràn,
không có sọc cảnh báo, không exception và không một dòng log nào.

---

### ~~G39 — Nhãn trục tung của "Xu hướng 6 tháng" in đè lên nhau~~ · ✅ ĐÓNG (2026-09-14, mở và đóng trong cùng ngày)

**Triệu chứng đo được** trên `emulator-5554` ngày 2026-09-14, tài khoản có dữ
liệu thật: bật **ba** danh mục ở khối "Xu hướng 6 tháng" thì nhãn trên cùng của
trục tung là **hai chuỗi đè lên nhau** — "63.2K" và "63.3K" chồng khít, chữ số
thứ ba thành một vệt không đọc được. Phóng to ảnh chụp mới thấy; ở cỡ thật nó
trông như một nhãn in lỗi font.

**Gốc rễ.** `_KhoiXuHuong` tính `maxY` rồi `buoc = maxY / 3`, và `leftTitles`
dùng `interval: buoc`. `fl_chart` vẽ nhãn cho các mốc theo `interval` **và** cho
biên trên. Hai thứ ấy ở **cùng một vị trí** — nhưng `3 * (maxY / 3)` không bằng
`maxY` trong dấu phẩy động, và khi giá trị rơi đúng ranh giới làm tròn của
`toStringAsFixed(1)` (đuôi `…x5`), `rutGon` trả **hai chuỗi khác nhau** cho hai
số chênh nhau chừng `1e-14`. Hai nhãn ấy vẽ chồng.

⚠️ **Cùng họ, khác mặt: bẫy 4.20** (`ANALYTICS_FEATURE.md`, 2026-09-15). Vẫn là
sai số dấu phẩy động ở nhãn trục do `rutGon`, nhưng lần này biểu đồ có **phần
âm** nên biên trên là `san + 3 * buoc` và ra chừng `-1e-16` ngay tại vị trí lẽ ra
là 0 — nhãn in **`-0`**. Đóng G39 (tính `buoc` trước) **không** đóng luôn ca ấy;
nó phải sửa trong chính `rutGon`. Gặp một trong hai thì nhớ kiểm cái kia.

**Không phải lỗi của lát A8 #3/#7.** Khối "Xu hướng 6 tháng" có từ lát **2b**
(2026-09-08) và đã mang sẵn hình dạng này. Lát A8 chỉ làm nó **dễ gặp hơn**:
trước đây `maxY` chỉ nhận đúng một dải (Thu/Chi toàn tháng), nay mỗi tổ hợp chip
được bật là một dải khác. Đo cùng ngày, ba dải **không** lỗi — 16.8M (hai đường
Thu/Chi), 51.7K (một danh mục), 350.8K (năm danh mục) — chỉ dải 63.2K lỗi.

**Đã sửa thế nào.** Dự án có sẵn **một định nghĩa duy nhất** của luật lọc nhãn
trục — `hienNhanTruc` ở `goal/domain/goal_progress_series.dart`, kèm test riêng —
nhưng nó giải bài toán *mốc nằm gần biên*, còn đây là *hai mốc trùng vị trí mà
khác chuỗi*, nên nó **không** cứu được ca này: cả hai đều là biên nên nó giữ cả
hai. Bản sửa đi vào gốc rễ thay vì thêm luật lọc thứ hai — tính `buoc` **trước**,
rồi đặt `maxY = buoc * 3`, để biên trên **chính xác** bằng mốc cuối của
`interval`. Một dòng, không đổi thang đo (`buoc` vẫn là `đỉnh × 1,15 ÷ 3`).

**Ca test tái hiện** — `nhãn trục tung không in HAI chuỗi khác nhau ở cùng một
mốc` ở `analytics_page_test.dart`. Nó dùng đỉnh **43.000**, một trong **tám**
giá trị tìm được khi quét dải 1.000–300.000 (bước 500) bằng máy. Điểm đáng nhớ:
bẫy đồ hoạ này **tái hiện được ngay trong widget test** — fl_chart dựng nhãn
bằng widget thật, nên `find.text` thấy chúng; đây là ngoại lệ hiếm của luật "lỗi
biểu đồ chỉ lộ trên máy thật" (bẫy 4.9). Ca ấy assert theo cách bền với **cả
hai** hướng sửa: không được có đồng thời hai chuỗi ở biên trên, và phải còn đúng
một — chữa bằng cách bỏ luôn nhãn biên là mất mốc cao nhất của thang đo.

**Nghiệm thu máy ảo** `emulator-5554` cùng ngày, đúng dải đã phát hiện lỗi: nhãn
trên cùng nay là **"63.3K" sạch**, một chuỗi duy nhất — trước đó cùng chỗ ấy là
"63.2K" và "63.3K" chồng khít, chữ số thứ ba thành một vệt. Ảnh ghép trước/sau ở
scratchpad phiên: `so_sanh_g39.png`.

**Mức độ:** không hỏng dữ liệu, không hỏng im lặng ở chỗ khác — chỉ một nhãn khó
đọc.

---

### G37 — Số dư ví không phản ánh giao dịch sau một lần đẩy bị xung đột · ✅ ĐÓNG 2026-09-13

**Triệu chứng đo được**, hai máy ảo cùng tài khoản, hoá đơn tự động trả (nghiệm thu bước 12):
máy **thắng** giữ khoản chi hợp lệ −350.000 mà ví vẫn là **2.000.000** thay vì 1.650.000. Máy
thua thì đúng, vì khoản chi của nó đã được gỡ và tiền đã hoàn.

**Gốc rễ.** `wallets.balance` là một cột đồng bộ **LWW thuần**, còn server **không tính lại** số
dư từ giao dịch. Chuỗi:

1. máy trả hoá đơn → `updateBalance` trừ ví cục bộ, hàng thành `pending`;
2. push ví → **xung đột** (`update_at` của server mới hơn) → `_markSyncedById`, client nhận
   "lấy theo server";
3. pull ghi đè `balance` bằng con số server — **lần trừ biến mất không dấu vết**, và vì hàng vừa
   bị đánh dấu `synced` nên không còn gì để đẩy lại.

**Đã đóng cùng ngày.** Sửa tận gốc là đổi *cách số dư ví được quyết định*: `wallets.balance` thôi là
dữ liệu gốc và trở thành **cache của tổng sổ giao dịch**. Vì sổ đã đồng bộ đúng, hai máy có cùng tập
giao dịch tính ra cùng một số — xung đột LWW không phá được nữa, vì không còn gì để mất.

**Nghiệm thu hai máy ảo, tài khoản thử sạch 24:** máy A tự trả hoá đơn (2.000.000 → 1.650.000), máy
B nhận `BILL_ALREADY_PAID` rồi gỡ (→ 1.650.000). **Hai máy bằng nhau và bằng tổng sổ.** Server: hoá
đơn `Payed`, đúng một khoản chi sống, một kỳ kế tiếp.

**⚠️ Ba cái bẫy của cùng một sai lầm, cả ba chỉ lộ ra khi chạy thật** — ai sửa tiếp vùng này phải
biết: neo tính bằng `balance − Σ sổ`, nên **thời điểm** đặt nó quyết định đúng sai.

1. **Đặt neo SAU khi ghi sổ** → neo hấp thụ luôn giao dịch vừa ghi; ví 1.000.000 trả hoá đơn 350.000
   có neo 1.350.000 và số dư đứng im. 53 ca test đỏ vì điều này.
2. **"Lưới đỡ" tự đặt neo trong `tinhLaiSoDu`** → ví số dư 0 nhận 1.000.000 thì neo thành
   `0 − 1.000.000`, một khoản **chi** triệt tiêu đúng khoản vừa nhận.
3. **Đặt neo cho ví vừa kéo về** → nó mang `balance = 0` (nhánh pull thôi đọc cột ấy) trong khi sổ
   đã đầy đủ; neo âm bằng cả tổng sổ. Đo thật: ví 2.000.000 hiện `0đ`.

Chốt rút ra: **số dư 0 nghĩa là "chưa biết", không phải "ví rỗng"**.

**Bán kính** rộng hơn hẳn bước 12 — **mọi** đường ghi ví đi qua đây, không riêng hoá đơn — nên có
test quét `lib/` (thứ **năm** của dự án) cấm mọi nơi khác gọi `updateBalance`.

**✅ Hướng đóng đã chốt 2026-09-13: LÀM Ở CLIENT, không xin backend.** Hai lối đã cân nhắc:

| Lối | Ai làm | Vì sao chọn / loại |
|---|---|---|
| Server tính lại `Balance` từ giao dịch | backend | **Loại.** Client tự đóng được, nên xin là đẩy việc của mình sang người khác. Vẫn phải chốt lại hợp đồng cột này ở cả hai đầu |
| Client thôi coi `balance` là dữ liệu đồng bộ, **suy từ giao dịch** | client | **Chọn.** Không phụ thuộc ai; vướng duy nhất là **số dư ban đầu** lúc tạo ví — nay nằm thẳng trong `balance` mà không có giao dịch tương ứng, nên lối này đòi mỗi ví mới sinh một khoản "số dư ban đầu" |

**Hai dữ kiện đo trên backend 2026-09-13** (chỉ đọc), cần cho bất kỳ ai làm tiếp:

- `modules/sync/sync.repository.js:259` — điều kiện LWW là
  `new Date(mapped.update_at) > new Date(existing.update_at)`, và client thua thì **cả hàng ví**
  bị bỏ qua, không riêng `balance`. Không chỗ nào trong `/sync` tính lại số dư từ giao dịch.
- `workers/bank.worker.js:213` — **đã có tiền lệ server tự ghi `wallet.balance`**, cho ví ngân
  hàng (giá trị lấy từ `bank_account`). Nên hai loại ví hiện ngầm theo **hai** hợp đồng khác nhau:
  ví ngân hàng do server ghi, ví thường do client ghi. Ai làm tiếp phải giữ nguyên vế đầu.

**Không lẫn với lỗi đã sửa trước đó cùng ngày.** Ví **phình thêm** 350.000 sau xung đột là chuyện khác và
**đã đóng**: `SyncEngine` nay phát kết quả đẩy **trước** bước Pull, nên phép hoàn tiền của
`BillPaymentConflictResolver` không còn cộng vào một con số đã bị server đè lên (ca test
`test/core/sync/sync_push_result_truoc_pull_test.dart`). G37 là phần **còn lại** của cùng một gốc,
ở nhánh mà client không bù được.

**Ô đối soát số dư ở màn Sửa ví vẫn giữ nguyên vai trò** — nó sinh một khoản bù qua
`wallet/application/dieu_chinh_so_du_service.dart` chứ không ghi đè. Nay nó càng đúng khuôn: mọi
thứ ảnh hưởng số dư đều là một hàng trong sổ.

**Giới hạn còn lại, chấp nhận có chủ ý:** máy chưa pull đủ giao dịch sẽ thấy số dư tạm thấp cho tới
khi pull xong — khác hẳn trước đây, nơi sai là *vĩnh viễn*. Và ví loại `banking` **bị loại khỏi mọi
phép tính lại**: server tự ghi số dư ví ngân hàng từ SePay (`workers/bank.worker.js:213`), và số dư
ngân hàng thật có thể khác tổng sổ (phí, lãi, giao dịch chưa về). *(Cập nhật 2026-09-18: nhóm đã bỏ
liên kết ngân hàng nên client không tạo được ví loại ấy nữa. Phép loại trừ **giữ nguyên** — nó bảo
vệ hàng cũ kéo về từ một tài khoản từng liên kết, không bảo vệ một tính năng.)*

## 2. Vấn đề đã biết nhưng thuộc về Backend

Tám gạch đầu dòng đầu tiên dưới đây là **ảnh chụp cũ**: cả tám tệp nay nằm ở
`docs/superpowers/backend/DA-XONG/`. Dòng này từng ghi "hai tài liệu" trong khi
liệt kê tám — sửa 2026-09-10; và từng ghi `2026-09-04-backend-idempotent-delete.md`
"còn ở `CAN-LAM/`" — sai từ khi backend chuyển tệp ấy sang `DA-XONG/` (`f8ab027`),
sửa 2026-09-11. Việc backend còn mở đọc ở `docs/superpowers/backend/CAN-LAM/README.md`
— mục 1 (ba tài liệu còn việc: mục 17, 18 và 19) và mục 2 (trạng thái mười lăm tài liệu
backend báo đã xong, đo 2026-09-11):

- **`SESSION_VALIDITY_FINDINGS.md`** — token của tài khoản đã xoá vẫn dùng được; `/auth/me` không chạm CSDL; `/sync/push` luôn trả HTTP 200.
- **`CATEGORY_CLASSIFY_ALIGNMENT.md`** — giá trị `Vay/nợ` (tài liệu) lệch với `Vay/no` (CSDL, seed, client).
- ~~**`CATEGORY_GROUP_MEMBERSHIP_SYNC.md`**~~ — G10 đã **đóng 2026-09-07**; backend không phải làm gì.
- **`2026-09-05-backend-goal-auto-deposit.md`** — G21: ba cột cấu hình trích tiền tự động chưa có chỗ chứa ở backend. **Ba cột phải lên cùng lúc**, đẩy một phần là hai máy cùng trích một kỳ.
- **`CATEGORY_KEYWORD_SYNC.md`** — từ khoá phân loại tồn tại ở hai kho độc lập, không có đường nối; kèm một lỗ hổng phân quyền trong `POST /api/ai/classify/feedback`.
- **`CATEGORY_NAME_UNIQUENESS.md`** — hai unique index của `category` đang khác quy tắc nghiệp vụ theo cả hai chiều; client đã thi hành đúng quy tắc, CSDL thì chưa.
- **`CATEGORY_STABLE_IDS.md`** — ID danh mục mặc định sinh ngẫu nhiên mỗi lần seed, nên tên bị dùng làm khoá nối giữa hai phía; đây là nguyên nhân gốc của các lỗi 11.3–11.6.
- **`2026-09-04-backend-idempotent-delete.md`** — ba lỗ hổng của `/sync/push`: xoá một bản ghi không tồn tại bị trả về là lỗi (làm client đẩy lại vĩnh viễn); `message` là nguyên văn stack trace Prisma kèm đường dẫn máy chủ; và `budget.time_recurrence = null` bị ép về `'Month'`, **chặn hẳn** lựa chọn ngân sách "Ngày cụ thể". ✅ Đo 2026-09-11: (A)(B)(C) của tài liệu đã xong; (D) — `threshold_warning_percent` bị ép `0` — xong ở mã và `schema.prisma`, nhưng CSDL dev vẫn `DEFAULT 0` (`CAN-LAM/VERIFY_7675B35_REMAINING.md` §2.2). Đường `/sync/push` luôn gửi giá trị tường minh nên client không còn dính.
- **`DA-XONG/AUTH_401_BODY_CODE.md`** (2026-09-10) — *ảnh chụp 2026-09-10:* body 401 cho tài khoản bị khoá hoặc xoá không mang `code` / `reason_inactive`, vì tham số thứ ba của `ResponseHandler.unauthorized` rơi mất. ✅ **Nhánh HTTP đã sửa (đo 2026-09-11):** body 401 mang `code`, `idaccount`, `reason_inactive` ở cấp gốc (`core/response-handler.js:32-54`), và lỗi lược đồ ở `authenticate` nay trả 503 thay vì cho qua. ⛔ Nhưng bắt tay socket và `/auth/refresh` từ chối **mọi** tài khoản (hồi quy A, gạch dưới); lời từ chối ở socket không mang mã (§2.1 mục 18), còn `/auth/refresh` trả 401 chỉ có `idaccount`. Không mở G riêng: cưỡng chế đăng xuất phía client **chưa làm** nên client chưa đọc mã nào. ⚠️ Nhưng cùng vùng ấy **có** một lỗi đang chạy, không do backend — **G33** (✅ đóng 2026-09-11, xem mục G33 ở trên).
- **`CAN-LAM/FIX_BACKEND_3_REGRESSIONS.md`** (2026-09-11) — ba hồi quy của `7675b35` trên `main`, **đã gộp** về nhánh client 2026-09-11 (`main` @ `cc65f4f`): bắt tay socket và `/auth/refresh` từ chối mọi tài khoản; chốt trả hai lần đặt ở `upsertBill` chặn hoàn tác thanh toán; tài liệu backend ghi sai ba mã lỗi. Chưa mở G riêng vì backend trên máy client chưa chạy lại từ mã đã gộp (CSDL dev đã áp `database/12` ngày 2026-09-11). ⚠️ Khi chạy lại, hoàn tác một hoá đơn đã đồng bộ **không lên được server** cho tới khi backend sửa hồi quy B, và bắt tay socket cùng `/auth/refresh` từ chối mọi tài khoản cho tới khi sửa hồi quy A. ✅ Chỗ phía client — ba mã mới (`WALLET_NAME_DUPLICATE`, `WALLET_DEFAULT_DUPLICATE` do client tự xin, và `BILL_ALREADY_PAID`) chưa có trong `_permanentCodes` nên sẽ bị gửi lại mãi — đã đóng 2026-09-11: nay chúng bị chặn theo thời gian, không kéo chậm cả hàng đợi.
- **`DA-XONG/RULE_PROJECT_DOC_DRIFT.md`** (2026-09-10) — tài liệu backend (`docs/Rule_Project/`, `docs/progress/Backend.md`) nói ngược mã và CSDL: tài liệu xin 56 chỗ sửa theo dòng cộng ba việc sửa mã. Backend báo đã sửa (`f8ab027`); client soát lại 2026-09-11: **45/56** chỗ vẫn chưa đúng — 31 chưa sửa, 12 sửa nhưng vẫn sai, 2 không còn áp dụng; chỉ 11 chỗ sửa đúng — cộng tám khẳng định mới sai của `7675b35` (`CAN-LAM/VERIFY_7675B35_REMAINING.md` §3). Ba việc mã: bộ lọc ghi chú xong (G29), body 401 xong ở HTTP nhưng hỏng ở socket và `/auth/refresh`, `'ORC'` còn sót. Không mở G: không mã client nào hỏng vì nó, nhưng đó là những tài liệu người mới đọc **trước** mã.
- **`CAN-LAM/VERIFY_7675B35_REMAINING.md`** (mục 18, 2026-09-11) — client soát từng tài liệu trong mười lăm tài liệu backend báo đã xong, với mã HEAD và CSDL dev: chín việc mã/CSDL còn lại, gồm giao dịch SePay vỡ `chk_transaction_type` (suy từ mã), `bank_transaction.incoming` nay phát **hai lần** và vẫn hai hình dạng, khoá mã hoá mặc định viết cứng, tệp `database/)2_can_lam_all_migrations.sql` còn `DELETE FROM "category"`, `budget."Threshold_Warning_Percent"` còn `DEFAULT 0`, cửa hậu `_mock*` mở ngoài `production`, và `WALLET_NAME_DUPLICATE` cần một phép thử khi chạy; cộng 45 chỗ tài liệu ở gạch trên. Không mở G: theo §4 của tài liệu ấy, client không bị chặn bởi việc nào trong đó ngoài hai hồi quy của mục 17. Phần phát sinh phía client — khoá màu danh mục — là **G24**, ✅ đã sửa 2026-09-11.
- G31 và G32 ở trên có tài liệu xin riêng: `DA-XONG/SYNC_PUSH_ERROR_MAPPING.md` và `DA-XONG/GOAL_PRIORITY_NULL_TO_ZERO.md` — ✅ backend đã làm cả hai, client đo 2026-09-11, **hai mục đã đóng**. G24 có `DA-XONG/CATEGORY_COLOUR_COLUMN.md` — phần backend xong, phần client ✅ sửa 2026-09-11. G34 có `DA-XONG/SOCKET_SYNC_COMPLETED.md` — phần backend xong, phần client ✅ 2026-09-12 tối (im lặng, kiểm máy ảo) — **đã đóng**.

Với tám tài liệu cũ, client **không** phụ thuộc vào việc backend có sửa hay không. Với các mục ghi *chặn ở backend* hoặc *chờ backend* ở bảng tóm tắt đầu tài liệu thì có — tính tới 2026-09-11 không mục G nào còn mở ghi như thế; gần nhất là **G34**, kiểm đầu-cuối được sau khi backend sửa hồi quy A (`cbbeeb4`) — ✅ đóng 2026-09-12 tối.

---

## 3. Lưu ý về kiểm thử

Trạng thái hiện tại (đã chạy thật, không phải đếm tay, đo 2026-09-12): `flutter test` toàn bộ **2105/2105 pass** (1 phút 7 giây), trên **200 file test / 45.599 dòng** (200 tệp `_test.dart`; số dòng đếm bằng script trên cả 201 tệp `.dart` dưới `test/`, kể cả `category_test_fakes.dart` — sau lượt sửa sau soát cuối cả nhánh spec §3.8: 27 test mới ở `core/api/`, 2 tệp / 30 test). Mốc 2104/2104 · 200 file · 45.557 dòng là của 2026-09-11 (đóng spec §3.8, trước lượt sửa sau soát cuối cả nhánh). Mốc 2078/2078 · 199 file · 45.147 dòng là của 2026-09-11 (sau G24, G35, G30, nhãn loại ví ở bảng chọn ví, **G33** và lượt sửa sau soát cuối cả nhánh G33, trước khi đóng §3.8). Mốc 2073/2073 · 199 file · 44.905 dòng là của G33 trước lượt sửa ấy. Mốc 2029/2029 · 192 file · 44.041 dòng là của 2026-09-11 (trước G33). Mốc 1529/1529 · 144 file · 33.892 dòng là của 2026-09-08. Trước phiên 2026-09-02 là 56 pass / 9 fail và mất hơn 10 phút (một test treo tới timeout); mốc 180 pass / 27 file ghi ở đây trước đó là con số **cuối phiên 2026-09-03** và đã lạc hậu năm ngày.

> ⚠️ **`.gitignore` có `test/`** (dòng 78, đo 2026-09-10 — từng ghi 77) — luật này khớp mọi thư mục tên `test` ở mọi cấp, và **đã tồn tại từ trước** phiên 2026-09-02 ✅ **HẾT HIỆU LỰC 2026-09-21** — luật `test/` đã bỏ khỏi `.gitignore` (quy tắc 6 `CLAUDE.md`); tệp test mới nay hiện bình thường, không cần `-f`. (kiểm chứng: `git diff .gitignore` chỉ thêm đúng một dòng `src/Backend/scripts/seed_roles.js`).
>
> Hệ quả đã đo được **tại thời điểm phát hiện** (2026-09-02): 16/23 file test đang được git theo dõi (commit trước khi luật có hiệu lực), 7/23 file thì không. Bảy file đó chứa 45 test:
>
> ```
> test/core/sync/sync_checkpoint_test.dart          (5 test)
> test/core/sync/sync_failure_handling_test.dart    (3 test)
> test/core/sync/sync_payload_contract_test.dart    (8 test)
> test/core/database/category_dao_test.dart         (9 test)
> test/features/auth/session_validation_test.dart   (9 test)
> test/features/category/category_create_test.dart  (8 test)
> test/features/wallet/default_account_data_initializer_test.dart (3 test)
> ```
>
> **✅ Đã xử lý (2026-09-02):** 7 file test bị chặn đã được đưa vào git bằng `git add -f`, cùng với `lib/core/sync/sync_checkpoint_store.dart`, và đã đi vào commit `ea0941b`. **Luật ignore lại cắn đúng như dự đoán:** hai file test tạo mới ngày 2026-09-03 (`test/core/api/auth_interceptor_test.dart`, `test/core/auth/current_account_test.dart`) cũng bị chặn âm thầm và phải `git add -f` lần nữa. Sau đó: **25/25 file test đều được git theo dõi**.
>
> **Nhưng luật ignore vẫn còn nguyên.** Mọi file test tạo MỚI từ nay vẫn sẽ bị chặn âm thầm. Cần quyết định: đây là quy ước có chủ đích (thì phải nhớ `git add -f` mỗi lần), hay luật đặt quá rộng (thì nên đổi `test/` thành đường dẫn cụ thể hơn, ví dụ `/Test/` cho thư mục script test cục bộ ở gốc repo).

### Vùng chưa có test nào

- ~~`lib/core/api/interceptors/auth_interceptor.dart`~~ — nay đã có `test/core/api/auth_interceptor_test.dart` (3 test, phiên 2026-09-03).
- ~~3 feature không có test~~ → ~~nay còn hai: profile, ai_chat~~ (đo lại 2026-09-08 bằng `find`/`flutter test`) → ~~nay còn **một**: **ai_chat**~~ (G33 thêm `test/features/profile/` — **2** tệp / **9** test, đếm bằng máy 2026-09-11) → ✅ **không còn feature nào thiếu test**: `ai_chat` có test từ P3 Task 8 (2026-09-22), nay **1** tệp / **24** ca — đếm bằng máy 2026-09-23 (quét mọi thư mục `lib/features/*` đối chiếu `test/features/*`). **analytics** có 4 tệp / **61** test từ 2026-09-08 (lát 2a **và 2b** — `docs/ANALYTICS_FEATURE.md`); **budget** 24 tệp; **home** 3 tệp (đếm bằng máy 2026-09-11); **notification** 20 tệp trong `test/core/notification/` + `test/features/notification/` (cộng 3 tệp liên quan nằm chỗ khác).

---

## 4. Nguyên tắc rút ra từ phiên 2026-09-02

Ghi lại vì chúng đã lặp đi lặp lại trong dự án này:

1. **Tên trường sai không gây lỗi — nó im lặng.** Payload đi qua ba nơi định nghĩa tên trường độc lập (client dựng tay → `SyncPayloadNormalizer` → `mapEntityFields` phía backend). Một tên sai chỉ đơn giản bị bỏ qua. `test/core/sync/sync_payload_contract_test.dart` khoá lại toàn bộ ánh xạ này — **cập nhật nó mỗi khi thêm trường mới cho sync**.

2. **`InsertMode.insertOrReplace` thay CẢ HÀNG.** Cột nào không gán trong companion sẽ bị đưa về giá trị mặc định. Đây từng xoá sạch cấu trúc nhóm danh mục sau mỗi lần pull. Toàn bộ 6 DAO nay dùng `insertAllOnConflictUpdate`. **Đừng đổi ngược lại.**

3. **Đừng bao giờ suy ra danh tính người dùng từ dữ liệu cục bộ.** `idaccount` chỉ được đến từ phiên đăng nhập.

4. **`idaccount = 1` là tài khoản admin THẬT**, không phải giá trị "chưa biết". Các fallback `?? 1` ở khâu đồng bộ (G8), bốn trang bill/goal (G4) và ba màn quản lý danh mục (G35, gỡ nốt 2026-09-11) đã bị gỡ; `test/core/auth/khong_du_phong_admin_test.dart` quét `lib/` bằng regex nhiều dòng để không còn chỗ nào lọt.
