# AI Edge-SLM trên Client-app — tài liệu tính năng

> **Thuật ngữ.** Tên đúng của ngành là **Edge AI** (học sâu chạy trên thiết bị). Tài liệu này
> và thư mục mã dùng "AI Edge" / `ai_edge` vì lịch sử và vì đặc tả gốc do backend quản
> (`docs/AI/AI_Edge-SLM.md/`) dùng tên ấy — **đừng đổi tên thư mục mã**, nó không mua được gì
> và làm ba test quét phải sửa theo. Trong văn bản, từ 2026-09-22 dùng **Edge AI**.
> ⚠️ Và phân biệt hai tầng: tầng **luật + thống kê** (đang chạy, không phải học máy) và tầng
> **SLM on-device** (P3, ✅ **XONG 2026-09-22**) — chỉ tầng sau mới là Edge AI theo nghĩa ngành.

**Trạng thái:** P0 xong (`03fe03a`) · **P1 spike XONG 2026-09-20** (đo trên OnePlus 13R / Snapdragon 8 Gen 3 — bảng đo mục **8**; người dùng chốt **E2B cho mọi máy**) · **P2 XONG — trọn 17 task** (Task 14 gắn khối Nhận xét vào bốn màn, đóng A6 — ⚠️ **nay là SÁU màn**, Hoá đơn và Quản lý ví thêm 2026-09-21, mục **12** và **14**; Task 15 thẻ + sheet kế hoạch tái phân bổ, nghiệm thu máy ảo đầu-cuối tới PostgreSQL — cả hai 2026-09-19; **Task 16** thông báo `budgetRebalance` 2026-09-20, mục **5g** `NOTIFICATION_FEATURE.md`; **Task 17** nghiệm thu tổng + tài liệu bàn giao 2026-09-20, mục **7.4**) ·
✅ **P3 XONG TRỌN 10/10 TASK ngày 2026-09-22.** *(Câu mở đầu ở đây từng ghi "ĐANG THI CÔNG — xong Task 1–8 / 10"; nó là ảnh chụp giữa ngày và đã nói ngược chính cuối đoạn này, nơi ghi "P3 đến đây là xong 10/10 task".)* Tám tệp mã đã vào: `slm_prompt.dart` và `chu_de_chan.dart` (hàm thuần), `slm_cache.dart`, `slm_runtime.dart` (tệp **duy nhất** import `flutter_gemma`, có test quét thứ **16** canh), `mo_hinh_tai_ve.dart`, `slm_dien_giai.dart` (bản `BoDienGiai` thứ hai, **sáu** nhánh lùi về mẫu câu), cộng **Task 7** ngày 2026-09-22: `cai_dat_ai_page.dart` (màn Cài đặt AI, route `/ai-settings`, nghiệm thu máy ảo 411dp) và `cong_tac_ai.dart`. DI nay đăng ký `SlmRuntime` / `MoHinhTaiVe` / `SlmCache` / `CongTacAi`, **cả bốn đều lazy** và **cố ý không đăng ký `BoDienGiai`** (lối B). `pubspec` thêm `flutter_gemma: 1.8.3` và `flutter_gemma_litertlm: ^1.7.0` *(nâng lên **1.9.0** / **1.8.0** ngày 2026-09-23 — bản cũ sập native ở mọi phiên có tool, mục **9.13**)*. **Task 8** cùng ngày: màn **Trợ lý AI** chạy thật (đóng **A11**) — bốn chip là câu hỏi thật, hỏi tự do qua `chuDeBiChan` **trước** khi gọi mô hình, câu trả lời kèm **thẻ số liệu**, ô nhập khoá khi chưa có mô hình *hoặc* công tắc tắt; thêm `data/nguon_goi_so.dart` và `kiemSoNhieuGoi`. ✅ **Task 9 XONG 2026-09-22** — nghiệm thu máy thật, bảng đo ở **mục 9**: mô hình **đã chạy thật trong app** trên OnePlus 13R (nạp 8.654 ms, câu đầu 3.291 ms, câu sau ~1–2 s, RAM đỉnh 0,85 GB), và ⭐ **cắt sạch mạng vẫn trả lời trong 1.898 ms với 0 request đi ra**. Lượt ấy bắt được **bốn lỗi thật** mà cả 3.348 ca test đều mù (mục **9.7**) — nặng nhất là **APK release thiếu quyền `INTERNET`**, thứ mọi bản debug che mất từ trước tới nay. **P3 đến đây là xong 10/10 task.** ✅ **Việc số 2 — tải nền + resume — XONG 2026-09-22 tối muộn** (7 task, mục **9.10**: đo trên **Realme RMX2205 / Dimensity 1100** — máy thứ hai của dự án; sáu lỗi thật, trong đó **nạp GPU sập native trên Mali** chữa bằng canary). ✅ **Việc số 1 của lộ trình XONG 2026-09-22 tối** (mã: mục **9.8** — streaming chặn theo câu · `kiemNhan` · `kiemGiong` nối vào hỏi đáp · sáu gói · chip mới · few-shot hỏi đáp; đo máy thật: mục **9.9**) — **CỔNG A QUA**. Lượt đo bắt hai lỗi thật (bẫy 4.18, 4.19). ✅ **Lát 4b XONG 9/9 task, CỔNG C ĐẠT trên CẢ HAI máy (2026-09-23)** — màn Trợ lý AI nay đi **bậc tool**: bốn tool đọc (`danh_sach_ngan_sach` · `danh_sach_hoa_don` · `danh_sach_vi` · `chi_tieu_theo_ky`), vòng lặp `hoiBangCongCu` trần 3 lời gọi, thang lùi L1–L4, bậc 1 làm nhánh lùi L1. Đo tám câu (mục **9.14**): nhóm A *"cái nào"* Realme **4/4**, OnePlus **3/4** trả lời **bằng tên**, 0 câu bịa số, 0 lần sập. Lượt đo bắt **ba lỗi thật** 3543 ca test đều mù, sửa cùng ngày (`ace9a53`, bẫy **4.34–4.36**). Trước đó: với `flutter_gemma` 1.8.3 / `flutter_gemma_litertlm` 1.7.0 engine **sập native** ở mọi phiên có tool trên cả hai máy; nâng lên **1.9.0 / 1.8.0** (`af2aa81`, người dùng duyệt) thì hết (mục **9.13**, bẫy **4.33**). ✅ **Bước 1b — canary phiên có tool, lối B — XONG 2026-09-23 tối** (mục **9.15**). ✅ **Bước 1c — tên đối tượng có chữ số qua được lớp chắn — XONG 2026-09-23 tối muộn** (mục **9.16**, bẫy **4.38**; ✅ đo Realme 2026-09-24 ở buổi đo cổng D). *(Dòng này dừng ở lát 4b cho tới lượt soát của bước 1c — bước 1b đã có mục 9.15 mà không được nhắc ở đây.)* 🛑 **Bước 2 — ba tool đọc + phép đo 20 câu lệnh — MÃ XONG, CỔNG D CHƯA ĐẠT (lần đo 1, 2026-09-24, mục 9.17)**: nhóm A **7/8 — tụt** · nhóm B 2/4 · nhóm C **13/20 tool · 5/20 tham số** (đúng theo nội dung **4/20**) · **5 câu SAI** (bẫy 4.40, 4.42) · 0 sập; hướng sửa **đã chốt 2026-09-24** — spec bước 2b `docs/superpowers/specs/2026-09-24-buoc-2b-tu-choi-giu-cho-mo-ta-tool-design.md`. 🛑 **Bước 2b — MÃ XONG (`5357209` → `e0e4a98`), CỔNG D LẦN 2 CHƯA ĐẠT (2026-09-24, mục 9.18)**: năm câu SAI của lần 1 **hết SAI** (lượt bị từ chối thôi là đã tra cứu → L1b / L2b; giá trị giữ chỗ = không lọc) · nhóm A **8/8** · nhóm B 2/4 · nhóm C **10/20 tool · 4/20 tham số — TỤT** (mô tả tool mới không dẫn được; nội dung đúng 6/20) · **1 câu SAI mới** (C9, bẫy **4.44**: tham số thừa làm hẹp bộ lọc → lượt thành công 0 hàng) · ĐC3 trượt tiêu chí · 0 sập · 0 vỡ trần (`tools_json` 5.431). Đòn bẩy kế tiếp để dành (đổi tên `chi_tieu_theo_ky`) **chờ người dùng quyết**; chưa mở bước 3. 🛑 **Bước 2c — MÃ XONG (`1301de9` → `5b7b7f4`), CỔNG D LẦN 3 CHƯA ĐẠT nhưng HAI BẪY ĐÓNG (2026-09-24 chiều, mục 9.19)**: `khopTheoTen` bậc ba đọc `_` là dấu cách (4.45 ✅ — C11 nay 10 khoản, 2.501.000 đ đúng đáp án); lượt `tim_giao_dich` thành công mà 0 khoản là **báo cáo về bộ lọc**, không phải câu trả lời — cổng hiện chữ đóng, mẫu câu nêu bộ lọc, nhánh **L2c** (4.44 ✅ — C9 nay *"Tháng này, ghi chú chứa "chi", đến 1.000.000 đ — không có giao dịch nào khớp."*, **SAI = 0**). Nhưng mô hình chọn tool / tham số **y hệt lần 2** cho cả 20 câu C (10/20 · 5/20), nên dòng 3 đứng yên; đòn bẩy còn lại vẫn là **đổi tên `chi_tieu_theo_ky`** — **chờ người dùng quyết**. Mới thấy bẫy **4.46**: mô hình đọc **số dòng hiện** (4) thành số khoản (C11, C16) — `kiemSo` chặn đúng. Spec `docs/superpowers/specs/2026-09-24-buoc-2c-luot-rong-theo-bo-loc-va-ten-snake-case-design.md`. 🛑 **ĐỔI TÊN TOOL `chi_tieu_theo_ky` → `tong_ket_thu_chi_ky` (`61f66ba`, cùng chiều, người dùng duyệt) — CỔNG D LẦN 4 VẪN CHƯA ĐẠT (mục 9.20)**: tool **13/20 · 6/20** (ba câu ngắn chuyển sang `tim_giao_dich`; sáu câu có điều kiện vẫn về tổng kết), nhưng **SAI 2** — C7 *"hơn **một triệu**"* viết bằng chữ và C10 gán danh mục chi làm *"khoản thu"*: bẫy **4.42** hiện nguyên hình, ba lần trước chỉ bị chặn **do may**. Bẫy **4.47**: nhãn *Số khoản* đòi chữ "khoản" mà mô hình nói "giao dịch" — hai câu đúng (C5, C17) rơi mẫu câu. Bốn hướng kế tiếp ở cuối mục 9.20, **chờ người dùng quyết**. 🛑 **Đổi nhãn `Số khoản` → `Số giao dịch` (`a68a842`) — cổng D lần 5 (mục 9.21) y hệt lần 4** (13/20 · 6/20, SAI 2): C5, C17 hiện chữ nhưng C8 lại bị chặn — bẫy 4.47 chỉ đổi chỗ, gốc là `kiemNhan` đòi từ khoá của **một** nhãn trong khi mô hình dùng "khoản" / "giao dịch" thay nhau; cần nhãn có từ đồng nghĩa. ✅ **Nhãn có từ đồng nghĩa — `SoLieu.nhanKhac` — mã xong (`235d11f`, mục 9.22)**: `nhanKhopAmTiet` một phép cho `kiemNhan` lẫn `theCuaCau`; *Số giao dịch* + thay thế *Số khoản*. 🛑 **Cổng D lần 6 CHƯA ĐO** — APK đã build và cài Realme, người dùng dặn để 34 câu cho phiên sau. Sau lần 6, đòn bẩy còn lại: 4.42 (số viết bằng chữ / mệnh đề) và mô tả tool cho câu có điều kiện. Spec `docs/superpowers/specs/2026-09-23-buoc-2-ba-tool-doc-tim-giao-dich-design.md`; mã xong task 1–8 của kế hoạch 9 task — `LoaiSo.ngayThang`, `khopTheoTen`, `kMaKy` tám mã, ba tool `danh_sach_muc_tieu` · `goi_y_han_muc` · `tim_giao_dich`, `BoCongCu` **bảy** tool; spike Realme (task 7): bảy khai báo (`tools_json` 4.393 ký tự) + hai lời gọi **vượt trần 2048** → `maxTokens` **4096** (RAM đỉnh 2,04 → 2,78 GB, swap 0 → 1,17 GB — vượt ngưỡng 0,5 GB, người dùng duyệt đích danh).

✅ **CỔNG A ĐÃ QUA — đo trên máy thật tối 2026-09-22** (mục **9.9**). ⚠️ Nhưng giữ nguyên bài học
đã phải trả giá một lần: **"P3 xong" KHÔNG đồng nghĩa "cổng A xong"** — hai thứ khác nhau, và
suốt nửa ngày 2026-09-22 bảng dưới đây có ba ô đỏ trong khi P3 đã đủ 10/10 task. Đối chiếu sáu
điểm của cổng (`docs/superpowers/plans/2026-09-21-lo-trinh-edge-ai-agent-rag.md:100`) với chính
bảng đo mục 9:

| # | Điểm cổng A | Trạng thái |
|---|---|---|
| 1 | Màn Cài đặt AI báo mô hình đã tải, đúng dung lượng | ✅ |
| 2 | Chữ **hiện dần** (streaming) khi trả lời | ✅ **đo máy thật 2026-09-22 tối** (mục **9.9**): câu tổng hợp 429 ký tự sinh 8,7 s, bong bóng lớn dần **theo từng câu** — 1 → 3 → 4 câu ở ≈ 3,8 / 5,9 / 7,6 s, chip còn xám; token đầu 1,7 s |
| 3 | Logcat có dòng nạp mô hình và thời gian sinh | ✅ 8.654 ms / 0,9–3,3 s |
| 4 | Hỏi câu mà gói số **không có** số → rơi về mẫu câu, không bịa | ✅ **không bịa** (đo 9.9): hỏi *"Du bao tiet kiem cua toi la bao nhieu?"* → *"Tổng thu là 15.135.000 đ, tổng chi là 2.141.000 đ, còn lại là 12.994.000 đ."* — ba số thật, **đúng nhãn** (trước: *"Dự báo tiết kiệm là 85,4%"*). ⚠️ Mô hình **không** nói "không có dữ liệu" mà chọn số liên quan; không có gì sai để chặn nên không rơi về mẫu. Trước đó ⚠️ đang hỏng, xem 9.5 |
| 5 | Mô hình trấn an sai mức → rơi về mẫu câu (`kiemGiong`) | ✅ **nối và đo** (9.9): gói ngân sách ở mức cảnh báo (Giáo dục 90,0 %), hỏi *"Toi co dang on khong? Ngan sach the nao?"* → *"…Ngân sách căng nhất là 90,0%."* — **không** cụm trấn an, không phải chặn. ⚠️ Lớp chắn chưa bị kích trên máy (mô hình không trấn an); ca `kiem_cau_tra_loi_test` *"⭐ trấn an khi có gói cảnh báo bị chặn"* là bằng chứng nó sống. Trước đó không phải "chưa đo" mà là **chưa nối** |
| 6 | Chế độ máy bay → vẫn trả lời | ✅ 1.898 ms, 0 request |

⚠️ **Điểm 4 từng hỏng theo một đường không ai lường:** nó không bịa **con số** (`kiemSo` chặn
được), nó bịa **cái tên của con số**. Chip *"Dự báo tiết kiệm"* hỏi một thứ **không có
trong gói nào** — gói mục tiêu chỉ mang `Tiến độ`, `Còn thiếu`, `Còn`, `Theo nhịp hiện
tại` — nên mô hình lấy con số gần nghĩa nhất (`Để dành 85,4%`) rồi gắn nhãn của câu hỏi
vào: *"Dự báo tiết kiệm là 85,4%."* Mọi con số đều thật, nên mọi chốt đều cho qua.
✅ Từ 2026-09-22 ba thứ chặn đường ấy: `kiemNhan` (mỗi số phải đứng cùng câu với đủ từ
khoá của nhãn gói gán cho nó — chính câu trên là ca test), bốn chip **chỉ hỏi thứ một gói
có**, và few-shot hỏi đáp có ví dụ *"không có số liệu → trả lời không con số nào"*.

Thứ tự việc để đóng cổng A nằm ở đầu `docs/superpowers/plans/2026-09-21-ai-viec-tiep-theo.md`.
✅ Streaming (điểm 2) làm bằng `Chat.generateChatResponseAsync()` có sẵn của gói, và mâu
thuẫn với `kiemSo` (bộ kiểm chỉ chạy trên câu đầy đủ) giải bằng **gác theo câu** — người
dùng chốt 2026-09-22, mục **9.8**. ✅ **Ba điểm 2, 4, 5 đã đo trên OnePlus 13R tối 2026-09-22** (mục **9.9**) — **CỔNG A QUA**. Lượt đo
bắt thêm **hai lỗi thật** 3392 ca test đều mù: token cắt con số ở cuối bộ đệm (bẫy **4.18**) và
thẻ số liệu so chuỗi con (bẫy **4.19**).

> ⚠️ **Ba chỗ kế hoạch P3 lệch mã thật, phát hiện khi thi công Task 7** (2026-09-22) — ghi ở đây
> vì hai chỗ đầu sẽ tái phát ở Task 8: **(1)** kế hoạch lưu công tắc bằng `SharedPreferences`, mà
> **dự án không có gói ấy**; nơi lưu tuỳ chọn là `flutter_secure_storage`, và `CongTacAi` theo
> đúng khuôn `SecureStorageNotificationPrefsStore` (tên khoá giữ nguyên `ai_tren_may_bat`).
> **(2)** kế hoạch tải mô hình bằng `sl<Dio>()`; `AuthInterceptor.onRequest` gắn
> `Authorization: Bearer` vào **mọi** request **không lọc host**, mà đích là `huggingface.co` —
> dùng chung Dio của dự án là gửi access token của người dùng cho một bên thứ ba, im lặng. Bản
> thi công dùng `Dio()` trần. **(3)** ca test `find.textContaining('không')` của kế hoạch **đỏ
> trên cả bản đúng**: `textContaining` phân biệt hoa thường còn câu hứa bắt đầu bằng *"Không"*.
**Spec đã duyệt:** `docs/superpowers/specs/2026-09-19-ai-edge-slm-design.md` — ⚠️ đọc **mục 8
dưới đây trước mục 4.1 của spec**: P1 đã lật bậc thang ở đó, và spec mục 4.1 nay mang banner 🛑.
**Kế hoạch:** `docs/superpowers/plans/2026-09-19-ai-edge-p0-nang-flutter.md`,
`…-p2-tang-edge-mau-cau.md`, `…/2026-09-20-ai-edge-p3-cam-slm.md` (10 task).
**Chặng 4b (bậc tool):** spec `docs/superpowers/specs/2026-09-23-chang-4b-tool-calling-vong-lap-design.md`,
kế hoạch `…/plans/2026-09-23-chang-4b-tool-calling-vong-lap.md` (9 task, gitignore) — đo cổng C ở mục **9.14**.
**Bản đánh giá gốc:** `docs/superpowers/backend/AI_EDGE_SLM_DANH_GIA_AP_DUNG.md` (2026-09-18, có
banner đính chính ngày 19). **Đặc tả gốc** do backend viết: `docs/AI/AI_Edge-SLM.md/Client-app.md`
(chỉ đọc; chỗ sai xin sửa qua `docs/superpowers/backend/CAN-LAM/`). ⚠️ Vòng **một** của việc soát ấy
— `AI_EDGE_SLM_SUA_TAI_LIEU.md` và `EDGE_AI_THUAT_NGU_VA_HAI_MAU_THUAN.md` — backend **đóng ở
`b147fee` ngày 2026-09-22** và client đã chuyển sang `DA-XONG/`; đơn đang mở là vòng **hai**,
`CAN-LAM/AI_EDGE_SLM_SOAT_SAU_B147FEE.md` (11 chỗ, **12** từ lượt bổ sung 2026-09-23 — mục 3.6, màn chat bị tả "chưa nối API nào"; trong đó **bốn cặp tài liệu tự nói ngược chính
nó** do chính lượt sửa ấy sinh ra). 🛑 Một trong số đó — **D1**, cửa sổ thu nhập — **sai vì lỗi của
client**: đơn vòng một nộp ngày 19/09 đề nghị *"ba tháng liền trước"*, mã đổi sang `cuaSoNhinLai`
ngày 21/09, backend thi hành ngày 22/09 đúng câu đã nộp. **Một đơn xin nằm trong hàng đợi cũng lạc
hậu theo mã** — đổi mã vùng nào thì `grep` vùng ấy trong cả `CAN-LAM/`.

> Tài liệu này là **nguồn sự thật phía client** cho mảng AI. Mỗi task của kế hoạch điền vào đây
> ngay trong task, không dồn cuối. Mọi con số ghi kèm ngày đếm.

---

## 1. Tính năng này là gì, và KHÔNG phải là gì

**Một câu:** *máy tính số, mô hình kể chuyện về số.*

- **Tầng Edge tất định (P2):** mỗi màn dựng một **gói số typed** từ hàm domain **đã có** của app
  (`budgetPaceOf`, `thuNhapCua`, `tyLeTietKiem`, `phanTramSoVoi`, `duBaoCua`, `topKhoanChi`,
  `GoalEntity.progress/isBehindSchedule`, `pickHomeBudget`) → **câu nhận xét** bằng mẫu câu + **thẻ số
  liệu**. Tầng 2 trên trang Ngân sách: phát hiện **thâm hụt** → tìm **nguồn bù** → **kế hoạch chờ
  duyệt** (tick từng dòng, áp dụng mới sửa hạn mức).
- **Tầng SLM trên máy (P3):** cùng gói số, mô hình Gemma 4 qua `flutter_gemma` chỉ **diễn giải**;
  mọi con số trong câu phải có trong gói (bộ kiểm số), sai thì rơi về mẫu câu. Máy yếu, máy ảo,
  chưa tải mô hình → mẫu câu, không toast lỗi.
- **KHÔNG phải:** không học thống kê (CV, elasticity, EMA) vì dữ liệu thật chưa đủ; không bảng cache
  đặc trưng; không gửi giao dịch thô đi đâu; **không đổi schema đồng bộ, không thêm trường payload**.
  ⚠️ **Vế "không học thống kê" là ảnh chụp của P0–P3, và người dùng đã chốt ngược lại ngày
  2026-09-20**: bốn việc học ở **tầng số** sẽ làm (mục **11.4**), với điều kiện mỗi luật có **ngưỡng
  mẫu tối thiểu, dưới ngưỡng thì im**. Vế **không huấn luyện mô hình ngôn ngữ** thì vẫn đứng nguyên và
  có lý lẽ đầy đủ ở mục **10.3** — hai chuyện khác hẳn nhau, đừng gộp.

## 2. Quyết định kèm lý do

| Quyết định | Lý do | Ngày |
|---|---|---|
| Nâng Flutter 3.41.5 → 3.47.5 trước mọi việc AI | `flutter_gemma` 1.8.3 đòi ≥ 3.44; bản cũ 0.13.6 thiếu Gemma 4 | 2026-09-19 |
| ~~Bậc thang mô hình Gemma 4 E4B (≥ 8 GB RAM) → E2B (4–8 GB) → mẫu câu~~ 🛑 **ĐÃ THAY 2026-09-20**, xem hàng dưới | Gói không chạy Gemma 3 4B; Gemma 3 1B gated (cần token HuggingFace nhúng app) nên bỏ; hai bản Gemma 4 ở `litert-community` công khai. ⚠️ Vế *"hai bản Gemma 4 công khai"* vẫn đúng; vế **bậc thang theo RAM** thì P1 lật (mục 8.5) | 2026-09-19 |
| Lớp `ai_edge` **không tính**, chỉ nhận số | Bản định nghĩa thứ hai là thứ sinh bẫy A8 #8 (thu nhập gồm tiền đi vay); test quét 14 canh | 2026-09-19 |
| Nguồn dữ liệu Tầng 2 đặt ở `budget/data/`, không ở `ai_edge/` | Nó đọc bảng giao dịch để tính thu nhập mỗi tháng, mà test quét 14 cấm `ai_edge/` chạm bảng ấy | 2026-09-19 |
| Thông báo tái phân bổ nhận **cả kế hoạch** đã tính | Thẻ trên màn và thông báo dùng đúng một phép tính, không thể nói hai chuyện | 2026-09-19 |
| Nguồn bù xếp theo **dư địa** | essentiality = 0,5 cho mọi danh mục (chưa có thống kê) nên C6 quy về dư địa; cờ Cố định là lớp bảo vệ duy nhất và thắng tuyệt đối | 2026-09-19 |
| Bỏ D5 (trần Σ hạn mức ≤ thu nhập × (1 − tỉ lệ tiết kiệm)) | tái phân bổ giữ tổng hạn mức không đổi nên không thể vi phạm | 2026-09-19 |
| Mỗi lượt **một** kế hoạch, cho ngân sách thâm hụt lớn nhất | người dùng duyệt từng dòng; nhiều kế hoạch là nhiều sheet chồng nhau | 2026-09-19 |
| Ngân sách nhận xét ở Trang chủ và trang Ngân sách = `pickHomeBudget` (căng nhất) | cùng luật với thẻ Ngân sách của Trang chủ, hai chỗ không nói về hai ngân sách khác nhau | 2026-09-19 |
| Tỉ lệ tiết kiệm âm đổi nhãn "Vượt thu nhập" (trị tuyệt đối) | "để dành −720,0%" không ai hiểu; "chi vượt thu nhập 720,0%" thì có | 2026-09-19 |
| Khối Nhận xét ở Ngân sách và Mục tiêu **không dựng khi danh sách rỗng**; ở Phân tích đi theo `_KhoiTong` (kỳ rỗng không dựng) | tab rỗng của hai trang đã có khung rỗng nói đúng câu "chưa có ngân sách / mục tiêu" — thêm thẻ Nhận xét nói y hệt là hai thẻ một câu. Biến thể "thiếu dữ liệu" của Stitch dành cho Trang chủ, nơi thẻ luôn hiện | 2026-09-19 |
| Trang chủ: khối bọc **ba** `StreamBuilder` riêng (`_buildNhanXet`) thay vì kéo vào `StreamBuilder` giao dịch phía trên | khối đứng cuối trang sau thẻ Mục tiêu và Ngân sách; đưa hai thẻ ấy vào trong stream giao dịch là dựng lại chúng — và mở lại stream của chúng — theo mỗi giao dịch. Thu/chi tháng qua **`thuChiThangCua`** (hàm thuần mới, `home/domain/`) mà `TheSoLieuThang` cũng đọc, tổng số dư qua `_tongTaiSan` mà thẻ tài sản cũng đọc — "số trên thẻ = số trong gói" bằng **một định nghĩa**, không phải hai vòng lặp chép tay | 2026-09-19 |
| Sheet kế hoạch có **ba lối ra, ba nghĩa**: Áp dụng = `updateBudget` từng bên + ghi phản hồi từng dòng; Bỏ qua = chỉ ghi `rejected`; vuốt/chạm nền = **không ghi gì** | "chưa quyết" không phải "từ chối": ghi `rejected` khi người dùng chỉ tắt sheet là dạy luật C3 một điều họ không nói, và kế hoạch vẫn hiện lại ở lượt sau | 2026-09-19 |
| Áp dụng đi qua `BudgetRepository.updateBudget` với `copyWith(amount:)`, **không** ghi thẳng DAO | hạn mức mới đi đúng đường đồng bộ như mọi lần sửa tay (`syncStatus` pending + `scheduleSync`); đo máy ảo: `2/2 synced`, PostgreSQL đổi ngay | 2026-09-19 |
| Thẻ **không** có nút "Tăng hạn mức ngân sách" dù Stitch vẽ; thiếu nguồn bù mà **không còn dòng nào** thì cũng không có "Xem kế hoạch" | ngoài phạm vi P2; một nút không đi đâu là nút chết (`khong_co_nut_chet_test`), và sheet rỗng là ngõ cụt | 2026-09-19 |
| Khối Nhận xét nói về ngân sách **căng nhất** (`pickHomeBudget`), thẻ kế hoạch nói về ngân sách **thâm hụt dự phóng lớn nhất** — hai thứ **có thể là hai ngân sách khác nhau** | đo máy ảo 2026-09-19: khối mở đầu "Giáo dục: đã dùng 45.000 / 50.000 (90,0%)" rồi nối "Di chuyển dự kiến vượt…". Đây là hai luật có sẵn ghép lại, không phải lỗi; muốn một ngân sách thì đổi `pickHomeBudget`, không đổi gói số | 2026-09-19 |
| Thông báo `budgetRebalance` khoá theo **tuần ISO**, không theo ngân sách | kế hoạch là hàm của dự phóng, mà dự phóng là hàm của `spent`: khoá bám vào ngân sách hay số tiền là mỗi lượt quét một thông báo mới, mà quét nổ vài lần mỗi ngày | 2026-09-20 |
| Câu thông báo **không nêu số** (tên ngân sách thì có) | con số duy nhất đúng là con số *tại lúc mở trang*; in vào thông báo là hứa một điều sai ngay khi người dùng tiêu tiếp, mà thông báo nằm lại cả tuần | 2026-09-20 |
| Kế hoạch hết nguồn bù **vẫn báo**, bằng câu khác | đó là ca đáng báo nhất (không cứu được bằng san sẻ) và thẻ trên trang vẫn hiện; nhưng `TheKeHoach` giấu nút "Xem kế hoạch" khi `dong` rỗng, nên câu mời xem là lời hứa suông | 2026-09-20 |
| Công tắc **nhóm Ngân sách** là cửa chặn phép đọc (khác `largeExpense` có ngưỡng riêng) | loại này không có công tắc riêng; dựng kế hoạch là đọc toàn bộ sổ giao dịch + một `suggestAmount` mỗi ngân sách, trả giá chừng ấy cho một kết quả bị lọc bỏ là lãng phí im lặng | 2026-09-20 |
| `KeHoachTaiPhanBoLoader` nhận **`budgets` đã nạp**, khác mọi loader khác của scanner | vòng quét vừa đọc đúng danh sách ấy cho bộ luật ngân sách; đọc lần hai là hai **ảnh chụp khác nhau** của cùng dữ liệu, và hai thông báo sinh cùng lượt sẽ nói về hai trạng thái — cả hai trông hợp lý | 2026-09-20 |
| **E2B cho mọi máy; E4B bỏ hẳn** — thay bậc thang theo RAM của spec mục 4.1 | P1 đo trên máy thật: trên GPU hai mô hình tốn RAM **bằng nhau** (0,96 vs 0,97 GB) nên ngưỡng RAM không phân biệt được gì; E2B nhanh **gấp đôi**, tệp nhẹ hơn **1 GB**, tiếng Việt không thua. Mục **8.5** | 2026-09-20 |
| Chỉ tải tệp `‹model›.litertlm` chuẩn, **không** dùng biến thể `-gpu.litertlm` | bản `-gpu` **không nạp được** trên engine FFI Android dù tệp nguyên vẹn, và lỗi nó ném (*"Model may be invalid"*) dẫn người đọc đi sai hướng. Mục **8.2** | 2026-09-20 |
| P3 bắt máy không chạy được bằng **`try/catch` quanh `getActiveModel`**, không tự đọc ABI | gói tự nêu tên ABI trong thông báo lỗi; và lỗi ném ở bước **nạp** chứ không ở `install()`. Mục **8.3** | 2026-09-20 |
| Thêm **`flutter_gemma_litertlm`** cạnh `flutter_gemma` | core **không kèm engine nào**; thiếu nó thì `getActiveModel()` ném lỗi "add the engine package" | 2026-09-20 |
| **Lối B cho P3**: mô hình phục vụ **một chỗ duy nhất** — màn Trợ lý AI; **mọi** khối Nhận xét **giữ mẫu câu** (bốn khối lúc chốt, **sáu** từ 2026-09-21) | P1 đo: câu mô hình ở khối Nhận xét **gần bằng** mẫu câu (khác giọng văn, không khác thông tin — mẫu câu còn gọn hơn), mà giá là **2,3 s mỗi khối + 2,41 GB** tải. Mô hình chỉ hơn hẳn ở **hỏi đáp tự do**. Thi hành bằng cách **không đăng ký `BoDienGiai`** vào DI — đảo ngược bằng một commit | 2026-09-21 |
| **Streaming CHẶN THEO CÂU** (`gacTheoCau`): token vào bộ đệm, đủ một câu thì `kiemCauTraLoi` rồi mới hiện; trượt thì `stopGeneration()` và không hiện. Đã có câu hiện rồi mới trượt → **giữ** các câu ấy và dừng; chưa câu nào → câu lùi "chưa chắc" | Bộ kiểm chỉ có nghĩa trên câu đầy đủ; hiện từng token là để người đọc thấy con số **trước khi** nó bị chặn — ngược lý lẽ của `_kKhongChacChan` (không nói lại câu mô hình vừa viết). Ba lối khác bị loại: hiện token rồi thay (chữ nhảy, đã lộ số sai), giữ khối (bỏ điểm 2 cổng A), chỉ báo có nhịp (không phải streaming). Câu đã qua kiểm là câu đúng — thay nó bằng câu lùi là vứt một câu đúng vì một câu sau nó | 2026-09-22 |
| **`kiemNhan` — lớp chắn thứ ba**: mỗi số trong câu phải đứng cùng câu với **mọi âm tiết có nghĩa** của ít nhất một nhãn gói khớp nó (bỏ *tổng · số · đã · so · với · là*); so theo **âm tiết**, không theo chuỗi con | Mục 9.5: mô hình bịa **tên** của số thật, `kiemSo` mù. Từ khoá suy **từ nhãn lúc chạy** — test quét 14 cấm chuỗi chiều tiền trong `ai_edge/`, và danh sách chép tay lệch ngay khi ai đổi nhãn. "chiều" chứa "chi" nên `contains` là để nhãn lọt nhờ một từ khác. Sai theo chiều **an toàn**: câu đúng nhưng diễn đạt xa nhãn bị chặn — few-shot dạy chép nhãn nên hiếm | 2026-09-22 |
| `kiemGiong` **nối vào đường hỏi đáp** qua `kiemCauTraLoi`, mức tổng hợp = có gói cảnh báo thì cả câu không được trấn an | Điểm 5 cổng A ghi "chưa đo" nhưng thật ra **chưa nối** — `_hoiThat` chỉ gọi `kiemSoNhieuGoi`. Người hỏi về ví mà đọc "yên tâm" khi ngân sách đã 90 % là sai theo chiều nguy hiểm, nên mức tổng hợp lấy phía cảnh báo | 2026-09-22 |
| `NguonGoiSo` gom **sáu** gói (thêm hoá đơn, ví); bốn chip là *Chi tiêu tháng này · Tình hình ngân sách · Tiến độ mục tiêu · Hoá đơn sắp tới* | Hai gói ấy đã có cho khối Nhận xét mà màn Trợ lý AI không thấy — hỏi về hoá đơn là mô hình lấy số gói khác trả lời thay. Chip cũ *"Dự báo tiết kiệm"* / *"Gợi ý cắt giảm chi phí"* hỏi thứ **không gói nào có** (spec 4.6 định nghĩa chúng = gói mục tiêu / kế hoạch tái phân bổ, nhưng nhãn gói không nói thế) — chip là thứ người dùng bấm đầu tiên, không được dẫn vào đúng lỗi bộ kiểm sinh ra để chặn. Chip của gói rỗng **vẫn hiện**: prompt in câu mẫu thiếu dữ liệu của gói ấy cho mô hình chép | 2026-09-22 |
| `promptHoiDap` có **few-shot riêng** ba ví dụ (chép nhãn nguyên văn · mục tiêu · **hỏi thứ không có → trả lời không chữ số**), số liệu có **tiêu đề theo màn** `== Ngân sách ==` | Trước đó dùng chung hai ví dụ nhận xét — không ví dụ hỏi–đáp nào; E2B không suy ra hành vi "nói không có" từ chỉ dẫn suông. `Còn thiếu` / `Tiến độ` / `Còn` trùng tên ở hai gói, chỉ tiêu đề mới phân biệt | 2026-09-22 |
| **Lượt tải là đối tượng có danh tính do hệ thống giữ** (`NguonTaiNen`, taskId cố định `gemma-4-E2B`), không phải `Future` trong tiến trình | người dùng thoát app thì tiến trình chết và không ai gọi `taiTep` nữa; phải hỏi hệ thống "còn lượt nào không" (`luotDangSong`, `khoiPhuc`). Bản thật bọc `background_downloader` (đã là phụ thuộc transitive của `flutter_gemma`); bản giả cho test — đúng khuôn `SlmRuntime` | 2026-09-22 |
| `daCo()` kiểm **kích thước** == `kCoTepByte`, tệp dở **giữ lại** (không xoá khi hỏng) | resume cần tệp dở; mà `existsSync()` không phân biệt được 650 MB với 2,41 GB — chốt đặt ở `daCo`, chỗ nó thuộc về. Không checksum (đọc 2,41 GB mỗi lần mở màn) | 2026-09-22 |
| `enqueued` → `choMang` là trạng thái **riêng** trên màn; `canceled` chỉ là huỷ khi người dùng bấm; `waitingToRetry` giữ `dangChay` | `requiresWiFi` làm lượt đứng im vô thời hạn không lỗi; WorkManager dừng vì ràng buộc báo `canceled` rồi tự xếp lại; thử lại sau lỗi mạng thì máy vẫn ở Wi-Fi — ba tin khác nhau của gói, ba câu khác nhau trên màn | 2026-09-22 |
| Màn Cài đặt AI **không tự `setState`** khi bấm Tạm dừng/Tiếp tục/Huỷ; nguồn là sự thật duy nhất | bấm trên **thông báo** hệ thống cũng phải làm màn đổi theo; màn tự đặt là hai nơi nói hai điều | 2026-09-22 |
| Wi-Fi mặc định, **cho phép 4G sau khi hỏi** (hộp thoại `hoi_dung_4g.dart`) | người dùng chốt; tệp 2,41 GB | 2026-09-22 |
| **Canary GPU**: dấu ghi trước `getActiveModel`, xoá trong `finally`; dấu sót → CPU vĩnh viễn | Mali (Dimensity 1100) sập **native** khi gắn delegate OpenCL — không ném gì; ngoài scope kế hoạch nhưng là lỗi chặn (mỗi lần hỏi là một lần văng). Hai tệp cục bộ, tài sản của máy | 2026-09-22 |
| DI: `NguonTaiNen` **`registerSingleton`** sau `chuanBi()`, bọc `kIsWeb` (bản giả trên Chrome) | lazy nghĩa là `chuanBi()` chạy sau khi màn đã kết luận "không có lượt"; `background_downloader` trên web không có service nền, dựng là ném lúc mở app | 2026-09-22 |
| **Bậc tool — hướng A**: prompt không mang số, dữ liệu chỉ vào qua các tool đọc (bốn của lát 4b; bảy từ bước 2) và tích luỹ vào `GoiSoTraCuu`; **L1** — chưa tool nào chạy thì không câu nào của mô hình được hiện, màn rơi về bậc 1 **im lặng** | chặng 4a đo được *"danh sách có tên"* cần mà chưa đủ: mô hình không nối hai mục rời của gói. `kiemSo` mù với câu bịa **tên** không chứa số, nên câu viết trước khi có dữ liệu không được hiện. Spec `2026-09-23-chang-4b-…-design.md` | 2026-09-23 |
| Thẻ số liệu xét "câu nhắc tới" theo **từng câu**; mẫu câu bậc tool viết **theo lượt gọi** kèm chữ kỳ; markdown gỡ **lúc hiện** | ba lỗi cổng C bắt được trên OnePlus (bẫy 4.34–4.36). Người dùng chọn cả ba lối sửa; gỡ markdown ở màn chứ không ở prompt vì tất định và không phải đo lại mô hình | 2026-09-23 |
| **Canary phiên có tool — lối B** (bước 1b): dấu có mặt từ trước khi engine giải mã tới **sự kiện đầu tiên** của mỗi lượt sinh; dấu sót chỉ thành "hỏng" khi Android xác nhận lần thoát **đầu tiên sau lúc đặt dấu** là sập native (`ApplicationExitInfo`, API 30+); máy không cho biết lý do thì **hai lần liền**; dấu "hỏng" ghi phiên bản app và tự xoá khi app lên bản mới; bậc tool bị tắt thì màn đi thẳng bậc 1, im lặng | chép nguyên khuôn canary GPU thì dấu sót vì app **bị giết** (Realme giết app khi vuốt khỏi Recents, thiếu RAM, Buộc dừng) cũng tắt bậc tool **vĩnh viễn** — rơi đúng vào máy chậm, nơi chờ 10–15 s dễ khiến người ta bỏ đi. Người dùng chọn lối B trong ba lối (A chép khuôn GPU · B lý do thoát · C chỉ hai lần liền) | 2026-09-23 |
| **Chữ số nằm trong tên một đối tượng của gói KHÔNG phải con số** (bước 1c): `trichSoNgoaiTen` bỏ khỏi câu các tên của `GoiSo.tenDoiTuong` — tên phải có chữ cái, khớp **trọn từ**, so theo `normalizeCategoryName`, tên dài bỏ trước — rồi mới trích số; là định nghĩa duy nhất cho `kiemSo`, `kiemNhan`, `theCuaCau`. `amTietCua` và `tuKhoaNhan` dùng **một** phép tách âm tiết có giữ chữ số. Ba gói in tên không nằm trên `SoLieu` nào tự khai tên ấy: Mục tiêu (`ten`), Trang chủ (`tenNganSach`), Ngân sách (ngân sách thâm hụt của câu tóm tắt kế hoạch) | Đo trên CSDL máy ảo, tài khoản 10: **5/9** hoá đơn và **1/16** danh mục có chữ số trong tên, và mọi câu đúng nêu tên chúng bị **cả `kiemSo` lẫn `kiemNhan`** chặn (chạy thử trên mã); thẻ số liệu còn lấy chữ số trong tên khớp nhầm số của gói khác. Người dùng chọn **sửa trước bước 2** (nếp *sửa lỗi trước*). Phương án loại: cho chữ số của tên thành "số được phép" — thế thì số 9 hợp lệ ở **mọi** chỗ trong câu | 2026-09-23 |
| (điền tiếp theo từng task) | | |

## 3. Vị trí mã

Theo spec mục 2.1 — cập nhật ở đây khi lệch:

```
lib/features/ai_edge/
  domain/   goi_so.dart · goi_so_{ngan_sach,phan_tich,muc_tieu,trang_chu,hoa_don,vi}.dart · nhan_xet.dart
            bo_dien_giai.dart · mau_cau.dart · dau_van.dart · tai_phan_bo.dart · kiem_so.dart
            ap_dung_ke_hoach.dart · kiem_giong.dart
            (P3) slm_prompt.dart · chu_de_chan.dart
            (việc số 1, 2026-09-22) kiem_nhan.dart · kiem_cau_tra_loi.dart — định nghĩa DUY NHẤT của "một câu được hiện" · gac_cau.dart — gác theo câu trên stream token · the_cua_cau.dart — thẻ số liệu của một câu (cùng phép khớp với bộ kiểm số)
  data/     (P3) slm_runtime.dart — tệp DUY NHẤT import flutter_gemma (sinh · sinhDan · huy) · slm_dien_giai.dart · slm_cache.dart · mo_hinh_tai_ve.dart (từ tối 2026-09-22 đứng trên NguonTaiNen; tai_tep_dio.dart ĐÃ BỎ) · nguon_tai_nen.dart — giao diện lượt tải sống lâu hơn tiến trình + bản giả · tai_nen_background_downloader.dart — tệp DUY NHẤT import background_downloader · cong_tac_ai.dart · nguon_goi_so.dart — SÁU gói cho màn Trợ lý AI
  domain/   (tải nền) hoi_dung_4g.dart — chuỗi hộp thoại dữ liệu di động · canary_gpu.dart — dấu canary GPU (Mali sập native)
  domain/   (bước 1b, 2026-09-23) canary_cong_cu.dart — CanaryCongCu (xét dấu sót bằng lý do thoát của Android) · quaCanary (bọc một lượt sinh) · BacCongCuDaTat
  data/     (bước 1b) nguon_ly_do_thoat.dart — kênh `flowmoney/ly_do_thoat` tới `MainActivity` (lý do thoát + phiên bản app) · slm_runtime.dart: `moPhien` hỏi `daTat()`, mỗi lượt của `_PhienThat` đi qua `quaCanary` · main.dart xét dấu sót lúc khởi động
  domain/   (lát 4b, 2026-09-23 — NỐI VÀO MÀN Trợ lý AI từ Task 8) hang_so_lieu.dart — HangSoLieu + KetQuaCongCu · goi_so_tra_cuu.dart — gói tích luỹ của bậc tool (mẫu câu theo lượt gọi, bẫy 4.35) · cong_cu.dart — CongCu, KhaiBaoCongCu, bốn tên tool, kTranGoiCongCu · gac_cau.dart thêm DangTraCuu / KhongTraCuu · slm_prompt.dart thêm kPromptHeThongCongCu · hang_{hoa_don,vi,ngan_sach,chi_tieu}.dart — bốn hàm dựng hàng theo tên · goi_so_vi.dart mở viDangAm công khai · bo_markdown.dart — gỡ markdown lúc hiện (bẫy 4.36) · the_cua_cau.dart xét theo từng câu (bẫy 4.34)
  data/     (lát 4b) phien_cong_cu.dart — giao diện phiên có tool + PhienCongCuGia · slm_runtime.dart thêm moPhien (bản thật _PhienThat — sập native với gói 1.7.0, chạy được từ 1.8.0, bẫy 4.33) · cong_cu_{ngan_sach,hoa_don,vi,chi_tieu}.dart — bốn adapter đọc repository · bo_cong_cu.dart — BoCongCu (khai báo + tra theo tên), DI lazy · vong_lap_cong_cu.dart — hoiBangCongCu: trần, thang lùi L1–L4, log print · nguon_goi_so.dart tách viChoGoiSoTu / nganSachDangChay dùng chung
  domain/   (bước 2, 2026-09-23 — mã xong; cổng D chưa đạt, mục 9.17) hang_muc_tieu.dart · hang_goi_y_han_muc.dart · hang_giao_dich.dart — ba hàm dựng hàng · loi_tham_so.dart — lời từ chối tham số chung · cong_cu.dart thêm ba tên tool + ba nhãn chỉ báo · hang_chi_tieu.dart: kMaKy tám mã · goi_so.dart / kiem_so.dart: LoaiSo.ngayThang · hang_so_lieu.dart: KetQuaCongCu.tenLienQuan
  data/     (bước 2) cong_cu_{muc_tieu,goi_y_han_muc,giao_dich}.dart — ba adapter · bo_cong_cu.dart: bảy tool
  domain/   (bước 2b, 2026-09-24 — mã xong; cổng D lần 2 chưa đạt, mục 9.18) loi_tham_so.dart — chỗ DUY NHẤT dựng lời từ chối (tuChoi… → loi + choNguoiDung + thamSoGo) · tham_so_mo_hinh.dart — thamSoTen (giữ chỗ = không lọc) · laSoTien · goi_so_tra_cuu.dart: lượt bị từ chối KHÔNG là đã tra cứu, gỡ theo tham số, choHienChuMoHinh · hang_chi_tieu.dart: kMaKyMoiLuc (mã riêng của tim_giao_dich) · cong_cu.dart: toolsJsonCua
  data/     (bước 2b) vong_lap_cong_cu.dart: cổng hiện chữ choHienChuMoHinh, L1b, L2b · cong_cu_giao_dich.dart: ky bắt buộc + moi_luc · slm_runtime.dart đo tools_json bằng toolsJsonCua
  domain/   (bước 2c, 2026-09-24 — mã xong; cổng D lần 3 chưa đạt nhưng bẫy 4.44 / 4.45 đóng, mục 9.19) hang_so_lieu.dart: KetQuaCongCu.rongTheoBoLoc · boLoc · soLieuBoLoc (bộ lọc dội lại — không vào json trừ soLieuBoLoc) · hang_giao_dich.dart: boLoc bảy điều kiện thứ tự cố định, tên THẬT đã khớp, Từ/Đến rời tongHop, tu_khoa vào tenLienQuan · goi_so_tra_cuu.dart: _luotRong (không bao giờ gỡ), choHienChuMoHinh ba vế, tiền tố kỳ + bộ lọc, nhóm rỗng, cauLuotRong, cauNoiThem · core/utils/khop_ten.dart: bậc ba `_` = dấu cách · loi_tham_so.dart: câu người dùng đổi `_` · transaction/domain/tim_giao_dich.dart: tenDanhMucKhop / tenViKhop (tenKhop thành getter)
  data/     (bước 2c) vong_lap_cong_cu.dart: nhãn L2c / L2b+L2c, log nêu lý do cổng đóng, nối cauNoiThem
  domain/   (đổi tên tool, 2026-09-24 chiều — mục 9.20) cong_cu.dart: kTenCongCuTongKet = 'tong_ket_thu_chi_ky' (tên cũ chi_tieu_theo_ky; hằng cũ kTenCongCuChiTieu bỏ), chỉ báo "Đang tổng kết thu chi…" · cong_cu_chi_tieu.dart / hang_chi_tieu.dart giữ tên tệp (nội dung vẫn là chi tiêu theo kỳ) · bo_cong_cu_test: kTranToolsJsonDaDo 5437
  domain/   (đổi nhãn đếm, 2026-09-24 chiều muộn — mục 9.21) hang_giao_dich.dart: soDem('Số giao dịch', soKhop) thay 'Số khoản' (bẫy 4.47 — chỉ đổi chỗ, gốc ở kiemNhan)
  domain/   (nhãn có từ đồng nghĩa, 2026-09-24 chiều muộn — mục 9.22; đo lần 6 tối cùng ngày, mục 9.23: bẫy 4.47 đóng) goi_so.dart: SoLieu.nhanKhac (mặc định rỗng), soTien / soDem nhận nhanKhac · kiem_nhan.dart: nhanKhopAmTiet — MỘT phép cho kiemNhan lẫn theCuaCau · the_cua_cau.dart: _cauNhacToi gọi nó · hang_giao_dich.dart: soDem('Số giao dịch', …, nhanKhac: ['Số khoản'])
  domain/   (đóng bẫy 4.42, 2026-09-24 đêm — mục 9.24, ba commit) kiem_so.dart: trichSo đọc số viết bằng chữ (_soChu · _donViChu · _mauSoChu · _giaTriSoChu), boTenDoiTuong tách từ trichSoNgoaiTen (kiemNhan dùng với MỌI tên) · goi_so.dart: SoLieu.nhanXungDot, soTien nhận nó · kiem_nhan.dart: ganNhanNguoc (xét trên câu đã bỏ tên) · hang_chi_tieu.dart, goi_so_phan_tich.dart: Chi ↔ ['Thu'] · hang_giao_dich.dart: _nhanChieu / _nguoc — chiều dòng là nhãn thay thế, chiều ngược là xung đột
  domain/ + data/ (định tuyến tool, 2026-09-25 rạng sáng — mục 9.25) slm_prompt.dart: kPromptHeThongCongCu có VÍ DỤ ĐỊNH TUYẾN (không chữ số, tên tool từ hằng; lật "không few-shot" của 4b §3.7) · bo_cong_cu.dart: tim_giao_dich ĐẦU, tổng kết ngay sau · cong_cu_chi_tieu.dart / cong_cu_giao_dich.dart: mô tả thu hẹp ("CHỈ khi … KHÔNG có điều kiện" / "Gọi khi câu hỏi có BẤT KỲ điều kiện nào") · bo_cong_cu_test: kTranToolsJsonDaDo 5491
  domain/   (ví dụ điền tham số, 2026-09-25 rạng sáng — mục 9.26) slm_prompt.dart: kPromptHeThongCongCu nối đoạn "Điền tham số" (chiều · tên vào đúng ô · hai ngưỡng · ky moi_luc; không chữ số)
  domain/   (lớp chắn thứ tư, 2026-09-25 rạng sáng — mục 9.27, bẫy 4.48) kiem_ten.dart: kiemTen — tên bịa trong câu KHÔNG số (từ loại → cụm tên → khớp tenDoiTuong bỏ khoảng trắng, chứa nhau; "không" trước thì bỏ qua; từ chức năng là MỘT chuỗi tách lúc chạy vì test quét 14) · kiem_cau_tra_loi.dart: vế thứ tư
  presentation/widgets/ khoi_nhan_xet.dart · the_so_lieu.dart · the_ke_hoach.dart
  presentation/pages/   ke_hoach_tai_phan_bo_sheet.dart · (P3) cai_dat_ai_page.dart
lib/features/budget/data/tai_phan_bo_nguon.dart   — nguồn dữ liệu Tầng 2 (cờ Cố định, mức mỗi tháng, thu nhập mỗi tháng, phản hồi cũ)
lib/features/transaction/domain/tim_giao_dich.dart — (bước 2) timGiaoDich: nguồn của tool tim_giao_dich, NGOÀI ai_edge vì lọc theo ví / chiều tiền (test quét 14)
lib/features/transaction/domain/tieu_de_giao_dich.dart — (bước 2) tiêu đề dòng giao dịch, MỘT luật cho Sổ giao dịch và tool
lib/core/utils/khop_ten.dart                       — (bước 2) khopTheoTen: tên tham số của tool → mục thật, không so chuỗi con
lib/core/database/tables/ai_feedback_table.dart   — bảng AiRebalancingFeedbacks (cục bộ)
lib/core/database/daos/ai_feedback_dao.dart
lib/features/ai_chat/                             — màn Trợ lý AI (P3), đọc ai_edge
```

## 4. Bẫy — đọc trước khi sửa

| # | Bẫy | Vì sao im lặng | Ca test canh |
|---|---|---|---|
| 4.1 | **Câu mẫu không được chứa chữ số ngoài gói** — nhãn kỳ (`T9 2026`), tiêu đề khoản chi (`Bữa trưa 12/09`), hằng số "30 ngày" đều bị bộ kiểm số chặn, và khi ấy P3 sẽ rơi về một câu mẫu **cũng bị chặn** | bộ kiểm số không phân biệt số "trang trí" với số bịa; câu mẫu vẫn hiện bình thường ở P2 nên không ai thấy cho tới khi SLM rơi về nó | mỗi tệp `goi_so_*_test.dart` có ca *"mẫu câu tự qua bộ kiểm số ở mọi nhánh"* |
| 4.2 | **Số của câu tóm tắt kế hoạch phải vào `soLieu` của gói Ngân sách** (`Thâm hụt`, `Nguồn bù`, `Bù được`, `Còn thiếu`) | `cauTomTat` nối vào đuôi câu nhận xét; thiếu số liệu thì bộ kiểm số chặn chính câu mẫu, cùng lý do 4.1 | `goi_so_ngan_sach_test.dart` *"có kế hoạch → … vẫn qua bộ kiểm số"* |
| 4.3 | **Bộ kiểm số phải bắt dấu âm** — `soPhanTram(-8.3)` in `-8,3%`; regex không bắt dấu thì "giảm 8,3%" và "tăng 8,3%" cùng qua | mất dấu là đảo nghĩa tăng/giảm mà bộ kiểm vẫn cho qua | `kiem_so_test.dart` *"trichSo giữ dấu âm"* |
| 4.3b | **Bộ kiểm số không kiểm NGHĨA** — câu "kiểm soát tốt" cho ngân sách 90 % còn 11 ngày qua được `kiemSo` vì mọi số đều đúng | diễn giải ngược mức mà không ai thấy; người dùng yên tâm tiêu tiếp | `kiem_giong.dart` — blocklist theo cụm + phủ định ba từ; nối vào `_sinh` sau `kiemSo` (P3 Task 6); prompt mang dòng MỨC (P3 Task 1). Ca canh: `kiem_giong_test.dart` *"câu ĐỦ SỐ ĐÚNG nhưng trấn an…"* |
| 4.5 | **Test của trang chứa khối phải tìm chuỗi TRONG thẻ, không trên cả trang** — khối in đúng con số của thẻ bên cạnh (đó là mục đích), nên `find.textContaining('125.000')` ở `budget_tabs_view_test` nay thấy **hai** chỗ; và khối làm trang cao hơn nên `tap` vào chip Xu hướng dưới mép 600dp của khung test **không trúng gì mà không đỏ** (chỉ một dòng Warning) | `findsOneWidget` đỏ ngay thì còn thấy; cú chạm hụt thì ca xanh nửa chừng ở khẳng định sau | `budget_tabs_view_test` bọc `find.descendant(of: Dismissible)`; `analytics_page_test` "bật một chip" gọi `ensureVisible` trước `tap` |
| 4.6 | **Thẻ mục tiêu có sẵn tràn 150px ở 411dp với font Ahem** (`goal_page.dart` hàng số tiền + phần trăm) — có từ trước Task 14, trên máy thật font thường vừa. Ca test trang Mục tiêu vì thế **không** khẳng định `takeException() == null` cho cả trang | bẫy 4.4 của `ANALYTICS_FEATURE.md`: font test rộng gấp đôi | khối có ca 411dp riêng ở `khoi_nhan_xet_test.dart` |
| 4.7 | **Ô tiền của sheet phải vẽ lại dấu chấm ngăn nghìn khi gõ** — giá trị điền sẵn là `formatSoThoi` ("210.000") còn bộ lọc chỉ-chữ-số biến số người dùng gõ thành "150000": hai kiểu hiển thị sống chung trong một ô, chỉ máy ảo thấy (`enterText` của test không nhìn) | không lỗi, không tràn; `_ChiChuSo` nay định dạng lại sau mỗi lần gõ, `onChanged` bỏ dấu chấm trước `double.parse` | `ke_hoach_sheet_test` "sửa số một dòng → tổng bù đổi" vẫn đi qua vì nó parse chuỗi đã bỏ dấu |
| 4.8 | **Tổng bù cộng cả số vượt dư địa** (để người dùng thấy con số mình vừa gõ) nhưng nút Áp dụng tắt riêng bằng `_hopLe`; bỏ vế `_hopLe` là nút bật với một dòng vượt dư địa, rồi `hanMucMoi` ném `ArgumentError` và sheet chỉ hiện dòng lỗi đỏ | bản sai có chủ ý làm đúng một ca đỏ | `ke_hoach_sheet_test` "số vượt dư địa → báo lỗi và nút Áp dụng tắt" |
| 4.9 | **Đọc SQLite máy ảo phải chép cả `-wal` và `-shm`** — tệp `flowmoney.db` chính có mốc sửa cũ hàng giờ, mọi hàng mới (kể cả bảng v24) nằm trong WAL; chép mỗi tệp chính thì `no such table: ai_rebalancing_feedbacks` trông như migration chưa chạy | cách đo: `adb exec-out "run-as com.flowmoney.flowmoney cat app_flutter/flowmoney.db"` ba lần cho ba đuôi, rồi `sqlite3` của Python | — |
| 4.10 | **Đếm "pixel vàng" để tìm tràn bố cục phải bắt VÀNG THUẦN `#FFFF00`, không phải một dải vàng** — sọc cảnh báo của Flutter đúng màu ấy, còn một dải rộng sẽ bắt luôn emoji 💡 của khối Nhận xét (529 px), biểu tượng ⚠ của khối Dự báo (1030 px) và **ô cam trong bảng chọn màu danh mục** (4111 px, màu `(245,158,11)`) | hỏng theo **hai chiều**: dải rộng cho dương tính giả nên người đo đi tìm một cái tràn không tồn tại; mà nếu quen với những con số ấy thì một sọc tràn thật cũng chìm vào chúng. Đo 2026-09-20: 21 ảnh, dải rộng cho 6305 px, vàng thuần cho **0** | — |
| 4.11 | **`dumpsys gfxinfo … framestats` KHÔNG đo được app Flutter** — trả `Total frames rendered: 0` dù màn đang vẽ liên tục, vì Flutter không dựng khung qua View system của Android | không báo lỗi; người đo đọc "0 khung, 0 jank" thành "mượt tuyệt đối" hoặc thành "đo hỏng" mà không biết đằng nào. Thay bằng phép đo trực tiếp: chụp 10 ảnh liên tiếp trong lúc inference chạy rồi so hash — khung đổi 7/10 lần là UI vẫn dựng | — (mục 9.4) |
| 4.12 | **Câu "mô hình không chạy được" còn che một nguyên nhân KHÁC HẲN: chưa có `idaccount`** — `AuthBloc` chỉ vào `AuthSuccess` sau `verifySession()`, một lời gọi **mạng**; mở app lúc mất mạng thì phải đợi hết timeout 30 s | hai nguyên nhân dùng chung một câu, và `catch` của `_hoi` trước đây **nuốt lỗi không log gì** — nên trên màn hình lẫn trong logcat chúng y hệt nhau. Trớ trêu: nó rơi đúng vào ca mất mạng, ca mà AI trên máy sinh ra để phục vụ | `ai_chat_page_test.dart` nhóm *"câu phiên chưa sẵn sàng tách khỏi câu mô hình hỏng"*; cộng `debugPrint` ở **cả hai** nhánh |
| 4.13 | **Quyền `INTERNET` chỉ có trong `debug/AndroidManifest.xml`** (Flutter tạo sẵn), nên bản release không gọi được backend nào | mọi lượt nghiệm thu máy ảo dùng bản debug → không bao giờ lộ; bản release báo *"Không có kết nối mạng"*, đúng câu dùng cho lúc rớt sóng, nên dẫn người đọc đi kiểm Wi-Fi thay vì manifest | `test/core/nhan_dien_app_test.dart` *"manifest chính khai quyền INTERNET"* |
| 4.14 | **`kiemSo` canh SỐ, không canh NHÃN** — *"Tỉ lệ phân bổ là 85,4%"* qua hết mọi chốt vì 85,4 là số thật (`Để dành`) | mọi con số đúng nên không ca nào của bộ kiểm số đỏ; chỉ người đọc biết "tỉ lệ phân bổ" không tồn tại. Nay `kiemNhan` chặn; nhưng nó là phép lọc **từ vựng** — câu gọi đúng nhãn mà sai nghĩa vẫn lọt | `kiem_nhan_test.dart` *"⭐ câu đo trên máy thật 2026-09-22"* |
| 4.15 | **Streaming và bộ kiểm loại trừ nhau nếu hiện từng token** — bộ kiểm chỉ có nghĩa trên câu đầy đủ | người đọc thấy con số sai **trước** khi câu bị chặn; ca test của bộ kiểm vẫn xanh vì nó không biết gì về thứ tự hiện. Chốt: `gacTheoCau` — hiện theo **câu**, trượt là `huy()` và không còn sự kiện nào sau đó | `gac_cau_test.dart` *"⭐ câu trượt: phát BiChan, huỷ đúng một lần, câu sau KHÔNG hiện"*; `ai_chat_page_test.dart` nhóm *"streaming CHẶN THEO CÂU"* |
| 4.16 | **Ca "few-shot không chứa số ngoài gói" cắt khối sai mốc** — nó cắt tới `lastIndexOf('Số liệu:')`, tức gộp cả câu chỉ dẫn *"dưới 40 từ"* vào khối ví dụ, và 40 chỉ qua vì tình cờ là chuỗi con của "400.000" | ca xanh suốt từ P3 Task 1; lộ ra khi bản hỏi đáp mang *"dưới 80 từ"* và 80 không là chuỗi con của gì cả. Nay cắt tới đầu câu chỉ dẫn ở **cả hai** ca | `slm_prompt_test.dart` hai ca *"KHÔNG được chứa số ngoài gói"* |
| 4.17 | **So từ khoá bằng `contains` là so chuỗi con** — "chiều" chứa "chi", nên *"Chiều nay tiêu 2.141.000 đ"* qua `kiemNhan` bản đầu | không lỗi; ca thử đầu viết *"Chính xác…"* và **xanh ngay** vì "chính" có dấu sắc không chứa "chi" — ca xanh ngay là ca không canh gì. Nay so theo **tập âm tiết** | `kiem_nhan_test.dart` *"từ khoá so theo ÂM TIẾT, không theo chuỗi con"* |
| 4.18 | **Cuối bộ đệm token KHÔNG phải cuối câu** — mô hình phát *"…là 2."* rồi *"141.000 đ."*; regex kết câu có `\|$` coi `2.` là câu xong, bộ kiểm chặn "2", cả lượt rơi về câu lùi | không lỗi; câu lùi trông y như mô hình yếu. Fake stream của test đưa nguyên con số nên **3392 ca đều mù** — chỉ máy thật thấy, ngay câu đầu tiên. Kết câu nay chỉ khi dấu chấm **theo sau bởi khoảng trắng**; phần đuôi do `gacTheoCau` kiểm khi luồng **đã đóng**. ⚠️ Ca tái hiện phải cắt token **ngay sau** dấu chấm (`'…là 2.'` + `'141.000'`); cắt trước dấu chấm thì bản sai cũng xanh | `gac_cau_test.dart` *"⭐ dấu chấm ở CUỐI bộ đệm chưa phải kết câu"* và *"⭐ token cắt giữa con số"* |
| 4.19 | **Thẻ số liệu so CHUỖI CON** (`cau.contains(s.chuoi)`) — có từ P3 Task 8, lộ ra khi hai gói mới mang số đếm ngắn: câu *"…tổng thu 15.135.000 đ"* kéo theo *Số cam kết 15 · Quá hạn 1 · Số ví 4 · Ví đang âm 1* | thẻ vẫn là số thật của gói nên không chốt nào đỏ; người đọc tin câu vừa nói tới hoá đơn quá hạn. Nay `theCuaCau` dùng **cùng phép khớp với bộ kiểm số** (`trichSo` + `soLieuKhop`), hai nhãn cùng số → một thẻ | `the_cua_cau_test.dart` *"⭐ số đếm ngắn KHÔNG khớp vì là chuỗi con của một số tiền"* |
| 4.20 | **Chính sách cleartext của Android áp lên worker native, KHÔNG áp lên Dio** — `http://127.0.0.1:8099` chạy được với Dio (backend dev) nhưng `background_downloader` bị *"Cleartext HTTP traffic … not permitted"* | không lỗi phía Dart; gói thử lại ba lần rồi `failed`. Chỉ gặp khi đo qua server cục bộ — URL thật là HTTPS; lúc đo thêm `android:usesCleartextTraffic="true"` **tạm**, không commit | — (mục 9.10) |
| 4.21 | **`background_downloader` dùng tiến độ ÂM làm mã trạng thái** (−1 hỏng · −2 huỷ · −3 không thấy · −4 chờ thử lại · −5 tạm dừng), và `waitingToRetry` KHÔNG phải "chờ Wi-Fi" | màn in *"Đang tải… −400 %"* / *"−9,64 GB / 2,41 GB"*; và lượt thử lại sau lỗi mạng mà nói "Đang chờ Wi-Fi" là chỉ sai nguyên nhân | `tai_nen_background_downloader_test.dart` *"⭐ −4 (chờ thử lại) KHÔNG phải −400%"*, *"⭐ waitingToRetry → dangChay"* |
| 4.22 | **`canceled` của WorkManager ≠ người dùng bấm Huỷ** — mất Wi-Fi thì WorkManager dừng worker vì ràng buộc, gói báo `canceled`, rồi tự xếp lại và chạy tiếp khi Wi-Fi về | màn nói "Chưa tải mô hình" cho một lượt vẫn đang xếp hàng; bấm Tải là xếp trùng (gói từ chối, im lặng). Nay `huy()` đặt cờ + xoá bản ghi; `canceled` không cờ → `dangCho` | `tai_nen_background_downloader_test.dart` *"⭐ không ai bấm Huỷ mà canceled → dangCho"* |
| 4.23 | **Sau force-stop (OEM) hoặc dừng vì ràng buộc, gói tải lại TỪ 0** — *"Partially downloaded file not available, resume not possible"*; chỉ Tạm dừng/Tiếp tục mới nối tiếp bằng `Range` | không lỗi; phần trăm nhảy về 0 và một câu hứa "phần đã tải được giữ lại" thành nói dối — đã bỏ câu ấy khỏi khối chờ Wi-Fi và khối lỗi | `cai_dat_ai_page_test.dart` *"trạng thái chờ mạng…"* đòi `giữ lại` **vắng mặt** |
| 4.24 | **Nạp mô hình bằng GPU sập NATIVE trên Mali** (Dimensity 1100 / Mali-G77: SIGSEGV null-pointer trong `libLiteRtOpenClAccelerator.so` lúc `ModifyGraphWithDelegate`) — `try/catch` quanh `getActiveModel` không bắt được gì | app văng về màn chính mỗi lần hỏi, không log Dart nào; bậc thang "GPU hỏng → CPU" của P1 chỉ tới được khi gói **ném**. Nay **canary**: ghi dấu trước khi thử GPU, xoá trong `finally`; mở lại thấy dấu → ghi nhớ "GPU hỏng" và dùng CPU (27 s nạp, 7–10 s/câu trên máy ấy). ⚠️ **Giới hạn biết rõ, chưa vá:** dấu sót không phân biệt *sập* với *bị giết* — app bị giết trong mấy giây nạp GPU (Realme giết khi vuốt khỏi Recents, thiếu RAM, Buộc dừng) cũng làm máy ấy đi CPU **vĩnh viễn**. Canary phiên có tool (mục **9.15**) phân biệt được nhờ lý do thoát của Android; khuôn GPU **cố ý chưa đổi theo** — người dùng chưa gọi tên việc ấy | `canary_gpu_test.dart` *"⭐ dấu còn sót (lần trước sập) → CPU, và ghi nhớ GPU hỏng"* |
| 4.25 | **Hộp thoại phải pop bằng `Navigator.of(c)`, không `c.pop()` của go_router** | ngoài `GoRouter` (widget test) nút ném *"No GoRouter found in context"* và hộp thoại không đóng — bản đầu của hộp thoại Xoá đã thế mà không ca nào chạm tới | `cai_dat_ai_page_test.dart` *"đồng ý dùng 4G thì tải với chiWifi = false"* |
| 4.26 | **`daCo()` phải kiểm KÍCH THƯỚC, và test không dựng nổi tệp 2,4 GB** | tệp dở giữ cho resume mà `existsSync()` đọc thành "đã có" → engine ném "Model may be invalid" ở nơi không ai ngờ; `coTepByte` tiêm được để `slm_dien_giai_test` đóng vai "đã có" bằng tệp 3 byte | `mo_hinh_tai_ve_test.dart` nhóm *"daCo() kiểm KÍCH THƯỚC"* |
| 4.27 | ⚠️ **Thẻ số liệu gán nhãn của GÓI KHÁC khi hai nhãn trùng GIÁ TRỊ** — bắt được ở chặng 3 (2026-09-22), ✅ **sửa ở chặng 4a Task 3** (`20bbc05`, 2026-09-22 tối) | câu trả lời *"Ví đang âm: 1"* hiện thẻ **"Quá hạn 1"** — nhãn của *hoá đơn quá hạn*, vì cả hai cùng bằng **1** và `theCuaCau` khử trùng theo **giá trị** nên gói đứng trước thắng. Cùng họ 4.19 nhưng nguyên nhân khác hẳn: **trùng giá trị**, không phải chuỗi con. Số nhỏ (`1`, `2`, `3`, `0`) trùng nhau giữa các gói là chuyện **thường**, nên đây không phải ca hiếm. Luật nay: trong các mục cùng giá trị, ưu tiên mục mà **câu nhắc tới** — đủ từ khoá của nhãn **hoặc** của tên, **cùng phép âm tiết với `kiemNhan`** (`amTietCua` mở công khai để hai nơi không tách âm tiết hai kiểu); không mục nào khớp thì mới rơi về thứ tự gói | `the_cua_cau_test.dart` nhóm *"trùng GIÁ TRỊ giữa hai gói — bẫy 4.27 (chặng 4a)"*, ca ⭐ *"câu nói về VÍ thì thẻ lấy nhãn của ví"* |
| 4.28 | ⚠️ **`adb shell input text` làm hỏng chữ hoa giữa từ** — bẫy của phép ĐO, không phải của app. ⚠️ **Đính chính 2026-09-24 (bẫy 4.41): nguyên nhân thật là bàn phím TELEX, không phải chữ hoa** — `muaxe` chữ thường cũng ra `mũae` | gõ `MuaXe` ra **`Mũae`** trên màn hình; câu hỏi chứa tên riêng vì thế không tới được mô hình, và kết quả đo trông như "mô hình không hiểu tên". Câu hỏi có tên riêng phải **chụp màn kiểm lại chữ đã vào** trước khi tin kết quả | *(bẫy thao tác — ghi ở mục 5.6 `AI_AGENT_ARCHITECTURE.md`)* |
| 4.29 | ⭐ **Prompt vượt trần token là lỗi CỨNG, không phải chậm** (chặng 4a, 2026-09-23) | gói ném `INVALID_ARGUMENT: Input token ids are too long: 1084 >= 1024` và câu trả lời **RỖNG** — kế hoạch chỉ lường "prompt phình thì token đầu tăng". ⚠️ `maxTokens` là hằng của **client** (`slm_runtime.dart`), không phải giới hạn của Gemma, và là trần cho **tổng** input + output: prompt 1.084 token + `tranToken: 300` đều phải lọt. Nới 1024 → 2048. **Mỗi lát làm gói số giàu thêm phải đo lại độ dài prompt** | *(đo máy thật — `flutter test` không thấy)* |
| 4.30 | ⭐ **Mẫu câu in số của đối tượng KHÁC khi gói có nhiều mục trùng nhãn** | `{for (final x in soLieu) x.nhan: x.chuoi}` lấy giá trị **cuối**. Bốn ngân sách cùng nhãn `Tỉ lệ` → câu nhận xét về Giáo dục in *"(7,1%)"* của Mua sắm — sai **im lặng**, và khối Nhận xét hiện đúng câu ấy. ⚠️ Ca `contains('Giáo dục')` viết cùng lát **xanh suốt**: cùng bài học G43, ca test phải đòi **kết quả**. Chữa bằng **`chuoiTheoNhan`** ở `goi_so.dart` — bảng tra nhãn **một định nghĩa**, mục **đầu** thắng. ✅ **Cả sáu gói** đi qua nó từ 2026-09-23; trước đó chỉ gói ngân sách có `putIfAbsent` chép tay, còn năm gói kia chỉ an toàn nhờ **đặt nhãn danh sách khác nhãn tổng hợp** (`Đang âm` / `Ví đang âm`, `Đã quá hạn` / `Quá hạn`), và chú thích *"đặt CUỐI để các mục tổng hợp gặp trước"* ở hai gói ấy nói ngược mã. ⚠️ Qua API công khai của gói **không dựng được** nhãn trùng, nên ca test canh nằm ở chính `chuoiTheoNhan`; một gói tự viết lại map literal thì **không ca nào đỏ** | `goi_so_test.dart` *"⭐ nhãn trùng → mục ĐẦU thắng"*; `goi_so_ngan_sach_test.dart` *"⭐ mẫu câu nêu tỉ lệ của CHÍNH ngân sách nó nói tới"* |
| 4.31 | ⭐ **Nhãn giàu hơn có thể làm câu SAI lọt qua `kiemNhan`** | nhãn `Đang âm` (ví âm) có từ khoá "đang"/"âm", nên câu *"Số ví đang âm: −100.000 đ"* — **sai nghĩa**, số ví là 1 — lọt qua, trong khi bản **trước** chặng 4a chặn được. Gốc: luật "khớp nhãn **HOẶC** tên" quá lỏng khi gói mang nhiều mục cùng nhãn. Luật nay: mục **có tên** đòi câu nêu **tên**; mục không tên giữ luật cũ | `kiem_nhan_test.dart` *"⭐ mục CÓ TÊN đòi câu nêu TÊN"* |
| 4.32 | **Lúc mở màn Cài đặt AI, phép dò tệp chạy SONG SONG với `khoiPhuc()`** — `_doTrangThai()` chờ `daCo()`, `khoiPhuc()` chờ `luotDangSong()`, và phép về **sau** thắng (2026-09-23) | tệp dở của một lượt hỏng chưa đủ cỡ nên `daCo()` = `false`; về sau tin khôi phục thì màn đè "Tải không xong" thành "Chưa tải" — mất nút **Thử lại** (đi `tiepTuc`, nối từ chỗ đứt khi nối được), còn lại nút **Tải**. Nay phép dò **không đè mọi trạng thái nguồn đã báo về một lượt** — `dangTai` · `tamDung` · `choMang` · `loi`. ⚠️ Mới kiểm bằng **bộ giả**: bản thật `luotDangSong()` luôn trả `loi: null` (màn hiện câu dự phòng *"Kết nối đứt giữa chừng."*), và lượt **hỏng** có được `taskForId` của `background_downloader` trả về hay không thì **chưa đo** | `cai_dat_ai_page_test.dart` *"⭐ lượt HỎNG của lần chạy trước KHÔNG bị phép dò tệp về muộn đè thành 'Chưa tải'"* |
| 4.33 | ⭐ **Phiên có tool là phiên GIẢI MÃ CÓ RÀNG BUỘC — và với gói 1.7.0 nó sập NATIVE ngay lượt giải mã đầu, trên CẢ HAI máy** (2026-09-23, spike lát 4b) | `flutter_gemma_litertlm` 1.7.0 gắn cứng `enable_constrained_decoding = true` khi có tool (`litert_lm_client.dart:1083`), không tham số tắt; `CompositeLogitMask::Apply` nhảy qua một con trỏ hàm rác vào `libGemmaModelConstraintProvider.so` — Realme (CPU) `SIGSEGV`/`SEGV_ACCERR` **3/3**, OnePlus 13R (GPU) `SIGBUS`/`BUS_ADRALN` **2/2** — kể cả câu không cần tool. `try/catch` vô dụng, app văng; `flutter test` mù hoàn toàn vì x86_64 không chạy engine. Đường không tool trên cùng APK chạy bình thường. ✅ **Chữa bằng nâng lên `flutter_gemma` 1.9.0 + `flutter_gemma_litertlm` 1.8.0** (`af2aa81`, người dùng duyệt đích danh): đo lại **6/6 không sập** trên hai máy. ⚠️ Rủi ro còn lại: máy khác **chưa đo**, và một cú sập native ở đây là app văng **mỗi lần** người dùng hỏi — một canary kiểu 4.24 quanh lượt giải mã đầu của phiên có tool sẽ chặn được — ✅ **làm xong 2026-09-23 tối** (bước 1b, lối B: canary **cộng** lý do thoát của Android, mục **9.15**). Đừng hạ gói về 1.7.x | *(đo máy thật — mục 9.13)* |
| 4.34 | ⭐ **Thẻ số liệu xét "câu nhắc tới" trên CẢ tin nhắn** — cổng C, OnePlus 2026-09-23, ✅ sửa cùng ngày (`ace9a53`) | tool ngân sách trả Di chuyển (**hạn mức 450.000**) trước Ăn uống (**còn lại 450.000**); câu trả lời nhắc hai tên ở **hai câu khác nhau**, nên với luật 4.27 cả hai mục đều "được nhắc" và mục đứng trước thắng — thẻ in *"Di chuyển · Hạn mức 450.000 đ"* dưới câu *"Ăn uống: … Còn lại 450.000 đ"*. Câu thì đúng, chỉ thẻ sai, nên không chốt nào đỏ. Nay `theCuaCau` tách câu bằng đúng `tachCauHoanChinh` của `gacTheoCau` rồi xét từng câu — cùng đơn vị với `kiemNhan`; khử trùng theo giá trị vẫn trên cả tin nhắn | `the_cua_cau_test.dart` nhóm *"xét theo TỪNG CÂU — bẫy 4.34"* |
| 4.35 | ⭐ **Mẫu câu bậc tool sau NHIỀU lời gọi lặp hàng và mất nhãn kỳ** — cổng C, OnePlus 2026-09-23, ✅ sửa cùng ngày | câu ĐC1 (*"lãi suất tiết kiệm"*): E2B gọi `chi_tieu_theo_ky` cho *tháng này* → *năm nay* → *tháng trước* rồi đòi lần thứ tư → L3 → `mauCau()`. Bản phẳng in cả bộ hàng **hai lần** và *"Tổng chi: 2.141.000 đ … Tổng chi: 0 đ"* không nói kỳ nào — không số nào bịa, nhưng câu tự mâu thuẫn trước mắt người đọc. Nay `GoiSoTraCuu` nhớ từng lượt; mỗi nhóm một câu mở bằng **chữ kỳ**, lượt cùng nội dung gộp nhãn: *"Tháng này, năm nay — …. Tháng trước — …"*. `hang` / `tongHop` / `soLieu` không đổi, nên ba lớp chắn không đổi | `goi_so_tra_cuu_test.dart` nhóm *"mẫu câu sau NHIỀU lời gọi — bẫy 4.35"* |
| 4.36 | **Câu trả lời bậc tool có thể là MARKDOWN** — cổng C, OnePlus 2026-09-23, ✅ sửa cùng ngày | *"Danh sách ngân sách sắp hết:\n*   Giáo dục: …  *   Di chuyển: …"* — màn hiện chữ trần nên dấu `*` lộ giữa câu. Bậc 1 chưa từng thấy (prompt có few-shot văn xuôi); lượt trả lời bậc tool thì không. `boDanhDauMarkdown` gỡ `* ` / `- ` / `• ` đầu dòng và `**` **lúc hiện**, sau khi câu đã qua kiểm; ⚠️ dấu gạch chỉ là dấu khi **theo sau bởi khoảng trắng** — `-100.000 đ` đầu câu là số âm | `bo_markdown_test.dart` *"⭐ số ÂM ở đầu câu KHÔNG bị gỡ dấu"*; `ai_chat_page_test.dart` *"câu markdown hiện KHÔNG còn dấu `*`"* |
| 4.37 | **Huỷ một luồng `async*` đang chờ `await for` KHÔNG chạy `finally` ngay** — bước 1b, 2026-09-23 | `sub.cancel()` chỉ có hiệu lực khi luồng **bên trong** phát sự kiện hoặc đóng; trước đó `cancel()` trả về một future **không bao giờ hoàn tất** — ca test đầu của `quaCanary` treo tới hết thời hạn mà không có dòng lỗi nào. Mã không sai: trong app, lượt bị huỷ luôn kèm `stopGeneration` nên luồng của engine đóng lại và `finally` gỡ dấu. Cùng lượt, một cái bẫy sinh đôi: `sub.asFuture()` gắn **sau** khi luồng đã đóng cũng không bao giờ hoàn tất — gắn nó ngay sau `listen` | `canary_cong_cu_test.dart` *"lượt rỗng, lượt ném lỗi, lượt bị huỷ — đều gỡ dấu"* — ca huỷ gọi `cancel()`, **rồi** đóng luồng trong, **rồi** mới chờ |
| 4.38 | ⭐ **Tên đối tượng có CHỮ SỐ không bao giờ qua được lớp chắn** — bước 1c, 2026-09-23, ✅ sửa cùng ngày | `trichSo` đọc "9" của *"Tiền nhà T9"* là một con số không có trong gói → `kiemSo` chặn; `amTietCua` tách câu ở mọi ký tự không phải chữ nên âm tiết "t9" của tên không bao giờ có trong câu → `kiemNhan` chặn; `theCuaCau` lấy "9" khớp nhầm *"Còn 9 ngày"* của gói khác → thẻ sai. Hỏng theo chiều **an toàn** (rơi về mẫu câu), nên không ai thấy: cổng C đo bằng hoá đơn tên `Kiem`, không có chữ số — trong khi **5/9** hoá đơn thật của tài khoản 10 có. Cùng lượt lộ một lỗ sinh đôi: tên tách theo khoảng trắng còn câu tách theo mọi ký tự lạ, nên tên có dấu gạch (`Điện/Nước`) cũng không bao giờ khớp. ⚠️ Khi bỏ tên khỏi câu, bốn chốt giữ lớp chắn không bị nới: tên có chữ cái · khớp **trọn từ** ở hai đầu (*"an 5"* nằm trong *"Ban 5"*; *"Quỹ 9"* nằm trong *"Quỹ 95"*) · không phân biệt hoa thường · tên **dài** trước. ⚠️ Thêm một member vào `GoiSo` làm lớp giả nào **`implements GoiSo`** gãy biên dịch — ba lớp giả trong test đổi sang `extends` | `kiem_so_test.dart` nhóm *"tên đối tượng có chữ số (bước 1c)"* (8 ca, **11** bản sai có chủ ý qua hai tệp đều bị bắt); `kiem_nhan_test.dart` nhóm *"tên có chữ số hoặc dấu câu (bước 1c)"*; `the_cua_cau_test.dart` *"⭐ chữ số trong TÊN không đẻ ra thẻ…"*; `goi_so_tra_cuu_test.dart` *"⭐ câu đúng nêu tên hoá đơn CÓ CHỮ SỐ → qua cả ba lớp"* |
| 4.39 | ⭐ **Vượt trần token ở phiên có tool mang CHUỖI LỖI KHÁC bẫy 4.29** — bước 2, Realme 2026-09-23 | bảy khai báo tool (`tools_json` 4.393 ký tự) + phiên hai lời gọi ở `maxTokens` 2048 → `FAILED_PRECONDITION: Prefill input length exceeds available state entries (remaining capacity: 133)`, **không** phải `INVALID_ARGUMENT … too long`. Kế hoạch dặn grep chuỗi của 4.29 — grep ấy **mù** lỗi này. Màn hiện *"Mô hình trên máy không chạy được"* dù tool đã chạy xong. Chữa: `maxTokens` 4096 (RAM +0,71 GiB, swap +1,1 GB trên Realme — người dùng duyệt vượt ngưỡng). **Mỗi tool thêm vào phải đo lại** — trần là của **tổng** khai báo + kết quả tool + câu trả lời | *(đo máy thật — mục 9.17)* |
| 4.40 | ⭐ **Mô hình đọc LỜI TỪ CHỐI của tool thành "không có dữ liệu" — và câu ấy KHÔNG chứa số** — cổng D 2026-09-24 | tool từ chối tham số (`vi: "tất_cả"`, `danh_muc` thừa) → mô hình viết *"Không có dữ liệu giao dịch nào cho danh mục 'ăn uống'"* trong khi có thật. `kiemSo` mù với câu không số, `kiemNhan` không có nhãn nào để soát, và chốt L1 coi lượt từ chối là **đã tra cứu** (spec 4b: "tool trả 0 hàng hay từ chối vẫn tính là đã chạy") — nên câu **hiện**. 3 lần trong một buổi đo (C11, C12 + spike S3 *"Tôi đã gợi ý hạn mức…"*). ⚠️ **Và chính app cũng mắc**: `GoiSoTraCuu.mauCau()` trả *"Không tìm thấy dữ liệu khớp câu hỏi."* khi mọi lượt **rỗng hàng + rỗng tổng hợp** — một lượt bị từ chối cũng rỗng như thế, nên câu C8 (*"năm nay có khoản thu nào từ 5 triệu"* — có **2**) nhận câu ấy từ **mẫu câu**, không từ mô hình. Đó là **lỗi mã**. ✅ **Sửa ở bước 2b** (`1d21b24`, `eeac28f`, 2026-09-24): lượt bị từ chối **không** còn là đã tra cứu; mọi lượt bị từ chối → **mẫu câu trung thực** nêu lý do (L1b); còn lời từ chối chưa gỡ (gỡ **theo tham số**) thì chữ mô hình không hiện (L2b). Đo lại (cổng D lần 2, mục **9.18**): C8 ✅, C11 → L1b, C12 LỆCH — **0** câu SAI theo cơ chế này; L1b chạy thật 2 lần (B2, C11) | `goi_so_tra_cuu_test.dart` *"⭐ lượt bị TỪ CHỐI không phải đã tra cứu"*; `vong_lap_cong_cu_test.dart` *"⭐ L1b…"*, *"⭐ L2b…"*, *"⭐ gọi lại BỎ tham số…"* |
| 4.41 | ⚠️ **Bàn phím TELEX của Realme đổi chữ khi `adb shell input text`** — bẫy của phép ĐO | `s f r x j` đứng **sau nguyên âm trong cùng từ** thành dấu: `muaxe` → `mũae`, `test` → `tét`. Gõ **đôi** chữ ấy để Telex huỷ dấu: `muaxxe` → `muaxe`, `tesst` → `test` (đo 2026-09-24). Đây là nguyên nhân thật của 4.28 (không phải chữ hoa). Luôn **chụp màn kiểm chữ đã vào** trước khi gửi | *(bẫy thao tác)* |
| 4.42 | ⭐ **Câu SAI có TÊN THẬT và SỐ THẬT vẫn lọt cả ba lớp chắn** — cổng D C7 | mô hình gọi `chi_tieu_theo_ky` (tổng theo danh mục) cho câu hỏi *"các khoản chi hơn nửa triệu trong quý này"* rồi viết *"Các khoản chi có số tiền hơn một triệu là: Cho vay (800.000 đ), Chưa phân loại (500.000 đ), Di chuyển (355.000 đ)…"* — mọi số có trong gói, mọi số đi kèm đúng tên, nên `kiemSo`/`kiemNhan` qua; lời **khẳng định** ("hơn một triệu") sai. Ca thứ hai, nhóm A câu 3: *"các ngân sách sau sắp hết: … Ăn uống: còn lại 450.000 đ … Mua sắm: còn lại 790.000 đ"* — cổng C trả lời đúng (chỉ Giáo dục). Lớp chắn kiểm **số và nhãn**, không kiểm **mệnh đề**. Gốc ở chỗ chọn **sai tool** — có hàng giao dịch thật thì câu không có chỗ để sai. Bước 2b chỉ chạm **gián tiếp**: mô tả tool dẫn câu kiểu C7 về `tim_giao_dich`, và luật gỡ lời từ chối **theo tham số** chặn đường *bỏ bộ lọc rồi nói như thể trả lời câu hẹp*. ⚠️ **Cổng D lần 2 (mục 9.18): mô tả mới KHÔNG dẫn được** — C1, C7 vẫn gọi `chi_tieu_theo_ky` và mô hình viết lại **đúng câu SAI ấy** (*"Các khoản chi trên 500k là: Cho vay (800.000 đ), Chưa phân loại (500.000 đ)…"*); câu chỉ bị chặn vì mô hình chép số **của câu hỏi** (`500`, `1` của *"500k"*, *"1 triệu"*) — chặn **do may**, không phải lớp chắn thấy mệnh đề sai. A3 lần 2 thì đúng (*"Giáo dục"*). ⚠️ **Lần đo 4 (mục 9.20, sau khi đổi tên tool) hai câu ấy LỌT**: C7 viết *"hơn **một triệu**"* bằng chữ, C10 gán danh mục chi làm *"khoản thu"* — không chữ số nào ngoài gói nên `kiemSo` im, và không lớp nào kiểm mệnh đề. Ba lần trước "chặn do may" — nay hết may. ✅ **ĐÓNG — ba commit `b43d5ae` · `6ca112f` · `986307c`, đo lần 8 rạng sáng 2026-09-25 SAI = 0** (mục 9.24): `trichSo` đọc số **viết bằng chữ** (*"một triệu"* → 1.000.000, gói không có → chặn; lượng từ mơ hồ → không bao giờ khớp; chữ số + đơn vị chữ *"500 nghìn"* cố ý giữ cách đọc cũ); `SoLieu.nhanXungDot` — mục có tên bị chặn khi câu gán nhãn ngược (*"khoản thu"* cho số `Chi`), xét trên câu **đã bỏ tên đối tượng** (lần 7 lộ: *"Chi khác"* mang chữ "chi"), và hàng `tim_giao_dich` mang nhãn **chiều** làm nhãn thay thế (lần 7 lộ: câu đúng C12 bị chặn oan vì *"Kiem thu hoa don"*). Hai câu SAI đứng yên bốn lần đo nay thành LỆCH | `kiem_so_test` nhóm *"số viết bằng CHỮ"*; `kiem_nhan_test` nhóm *"nhãn XUNG ĐỘT"* (ba ca ⭐ là câu nguyên văn máy thật: C10 lần 6, C10 lần 7, C12 lần 7); `hang_chi_tieu_test`, `hang_giao_dich_test`, `goi_so_phan_tich_test` canh chỗ khai; *(đo máy thật — mục 9.17, 9.18, 9.20, 9.23, 9.24)* |
| 4.43 | **E2B nhét giá trị giữ chỗ vào tham số TUỲ CHỌN** — cổng D | `danh_muc: "tat_ca"`, `vi: "tất_cả"`, `danh_muc: "giao duc tu vi test"` (gộp cả cụm câu hỏi), số tiền nhét vào `tu_khoa` — tool từ chối đúng luật (tên không khớp), nhưng mỗi lần là một suất trong trần 3 và mở đường cho bẫy 4.40. 5/20 câu nhóm C hỏng tham số vì kiểu này. ✅ **Sửa ở bước 2b** (`a7a4413`, `22198ab`): `thamSoTen` — `tat ca` · `tatca` · `all` (sau khi đổi `_` thành dấu cách, bỏ dấu) nghĩa là **không lọc**, cố ý hẹp; `laSoTien` — số tiền trong `tu_khoa` bị từ chối **trước** khi đọc dữ liệu. Đo lại: spike S3 `goi_y_han_muc {danh_muc: tất cả}` nay ra **4 hàng**; cổng D lần 2 **0** lời từ chối vì giá trị giữ chỗ. ⚠️ Nhưng E2B vẫn điền tham số thừa theo kiểu **khác** — bẫy **4.44**, **4.45** | `tham_so_mo_hinh_test.dart`; `cong_cu_giao_dich_test.dart` *"⭐ giá trị giữ chỗ … GIỐNG HỆT không truyền"* |
| 4.44 | ⭐ **Tham số THỪA làm HẸP bộ lọc → lượt THÀNH CÔNG 0 hàng → mẫu câu "Số khoản: 0" SAI** — cổng D lần 2 C9, 2026-09-24 | *"liệt kê các khoản chi từ 200k đến 1 triệu tháng này"* → `tim_giao_dich {ky: thang_nay, so_tien_den: 1000000, tu_khoa: "chi"}` — thiếu `so_tien_tu`, thiếu `chieu`, và **chữ chiều tiền nhét vào `tu_khoa`**. Không ghi chú nào chứa "chi" nên tool trả **0 hàng — một lượt THÀNH CÔNG**; câu mô hình (*"Không có giao dịch chi tiêu nào…"*) bị `kiemSo` chặn nhờ "200k", rồi **mẫu câu L2 của app** nói *"Tháng này — Số khoản: 0; Tổng chi: 0 đ; …; Đến: 1.000.000 đ"* — có **2** khoản (và 18 khoản chi ≤ 1 triệu). Cùng họ 4.40 nhưng **qua được luật của bước 2b**: luật ấy chỉ xét lượt bị **từ chối**; *"0 hàng thật là dữ liệu thật"* chỉ đúng khi **bộ lọc khớp câu hỏi**, và không lớp nào biết bộ lọc có khớp không. `laSoTien` không bắt vì "chi" không phải số tiền. Ca sinh đôi C15: *"lần gần nhất chi cho di chuyển"* → `chieu: chuyen_vi` (đọc "di chuyển" thành chuyển ví) → mẫu câu liệt kê khoản chuyển. ✅ **Sửa ở bước 2c** (`2a9b80b`, `da9b41b`, `f0d639d`, 2026-09-24): với tool lọc bằng chữ tự do, 0 khoản là **báo cáo về bộ lọc** chứ không phải câu trả lời — `hangGiaoDich` đặt cờ `rongTheoBoLoc` + dội lại bộ lọc (`boLoc`), `GoiSoTraCuu` đóng cổng hiện chữ và **không bao giờ gỡ**, mẫu câu chỉ nêu bộ lọc (nhánh **L2c**). Đo lại (cổng D lần 3, mục **9.19**): C9 → *"Tháng này, ghi chú chứa "chi", đến 1.000.000 đ — không có giao dịch nào khớp."* — người đọc thấy bộ lọc lệch ở đâu, **SAI = 0**; C15 tiền tố lộ *"chuyển ví"*. Giá đã chấp nhận: C3 đúng cũng thành mẫu câu | `hang_giao_dich_test` *"⭐ rongTheoBoLoc…"*; `goi_so_tra_cuu_test` nhóm *"lượt RỖNG THEO BỘ LỌC"*; `vong_lap_cong_cu_test` *"⭐ L2c…"* |
| 4.45 | **E2B viết tên theo kiểu `snake_case`** — cổng D lần 2 C11 | `vi: "tiet_kiem"` — `khopTheoTen` không đổi `_` thành dấu cách nên **không khớp** ví *Tiết kiệm* → từ chối → L1b (đúng luật, không SAI). Hai hệ quả: câu hỏi đúng ý thành *"chưa tra được"*; và câu cho người dùng hiện **`"tiet_kiem"`** — luật (a) *"không có dấu `_`"* của spec 2b chỉ nghĩ tới **mã tham số**, không nghĩ tới **giá trị** mô hình gõ (ca *"ba luật"* chỉ thử tên không có `_`). Mô hình chưa gọi lại lần nào sau lời từ chối (0/2), dù chỉ dẫn hệ thống nay dặn *"gọi lại ngay"*. ✅ **Sửa ở bước 2c** (`1301de9`): `khopTheoTen` thêm **bậc ba** — đổi `_` thành dấu cách ở cả hai vế rồi so bỏ dấu, chỉ chạy khi hai bậc đầu trượt; câu người dùng của lời từ chối in tên gõ với `_` đổi thành dấu cách. Đo lại (mục 9.19): C11 `vi: "tiet_kiem"` khớp *Tiết kiệm* → 10 khoản, 2.501.000 đ đúng đáp án (mẫu câu có ích — chữ mô hình bị chặn vì bẫy 4.46) | `khop_ten_test` *"⭐ bậc ba…"*, *"⭐ bậc 2 THẮNG bậc 3"*; `loi_tham_so_test` *"⭐ tên gõ kiểu snake_case"*; `cong_cu_giao_dich_test` *"⭐ ví "tiet_kiem""* |
| 4.46 | **E2B đọc SỐ DÒNG HIỆN (4 = `kToiDaMucMoiGoi`) thành số khoản** — cổng D lần 3 C11, C16, 2026-09-24 | tool trả 4 hàng + `Số khoản: 10` (C11) / `36` (C16); mô hình viết *"bạn đã có **4** giao dịch chuyển tiền sang ví Tiết kiệm"* và *"Dưới đây là **4** giao dịch chi tiêu gần nhất"* — `kiemSo` chặn vì 4 không có trong gói, câu rơi về mẫu câu (L2). Chặn **đúng** (câu sai thật), nhưng là lý do C11 không hiện chữ mô hình dù tool và tham số đều đúng. Bẫy 10 của spec bước 2 (`soKhop ≠ dong.length`) đã lo phía app, chưa lo phía mô hình. ⚠️ **Chưa sửa**, chưa ai chọn hướng (ứng viên: chữ kèm *"hiện 4 trong 10"* trong JSON — nhưng `chuThem` cấm chữ số). Lần 4 tái phát ở C11, C12 | *(đo máy thật — mục 9.19, 9.20)* |
| 4.47 | **Nhãn `Số khoản` đòi chữ "khoản" mà mô hình nói "giao dịch"** — cổng D lần 4 C5, C17, 2026-09-24 | `kiemNhan` đòi câu nêu từ khoá của nhãn mà con số khớp; `hangGiaoDich` đặt nhãn *Số khoản* cho `soKhop`, mô hình viết *"bạn đã có 6 giao dịch"* / *"Có 5 giao dịch có ghi chú…"* — số đúng, nhãn không có chữ "khoản" → chặn, câu đúng rơi mẫu câu. Lần 3 C17 lọt chỉ vì câu dài hơn tình cờ chứa chữ "khoản" ở phần sau. ⚠️ **Đổi nhãn thành *"Số giao dịch"* (`a68a842`) chỉ ĐỔI CHỖ bẫy** — lần đo 5 (mục 9.21): C5, C17 hiện được nhưng C8 *"Có 2 khoản thu…"* lại bị chặn. Gốc là `kiemNhan` đòi từ khoá của **một** nhãn trong khi mô hình dùng "khoản" / "giao dịch" thay nhau; cần nhãn có **từ đồng nghĩa**. ✅ **Sửa gốc ở `235d11f`** (mục 9.22): `SoLieu.nhanKhac` + `nhanKhopAmTiet` dùng chung cho `kiemNhan` và `theCuaCau`; nhãn chính *Số giao dịch*, thay thế *Số khoản*. ✅ **ĐÓNG — đo cổng D lần 6 tối 2026-09-24** (mục 9.23): C5, C8, C17 cùng hiện chữ trong một lượt, năm câu còn bị chặn không câu nào vì "khoản"/"giao dịch"; 33/34 câu y hệt lần 5, chỉ C8 đổi | `kiem_nhan_test` nhóm *"nhãn có TỪ ĐỒNG NGHĨA"*; `the_cua_cau_test` *"⭐ thẻ nhận ra mục qua nhãn THAY THẾ"*; `hang_giao_dich_test` *"⭐ nhãn đếm là "Số giao dịch""*; *(đo máy thật — mục 9.20, 9.21, 9.23)* |
| 4.48 | ⭐ **Câu KHÔNG có số nêu TÊN BỊA lọt cả ba lớp chắn** — cổng D lần 10 B1, 2026-09-25 | *"Bạn có thể đặt mục tiêu mua xe hoặc **mua nhà**."* — mục tiêu thật là MuaXe và MuaDT (mua điện thoại). `kiemSo` và `kiemNhan` chỉ kiểm **khi câu có con số** (câu không số thì lọt — "không có gì để bịa"), `kiemGiong` chỉ kiểm giọng theo mức; không lớp nào kiểm **tên**. Lần 4–9 B1 nêu tên thật nên không lộ. ✅ **ĐÓNG `ec13fdf`** (mục 9.27): lớp chắn thứ tư `kiemTen` — sau từ loại (*mục tiêu / danh mục / ví / hoá đơn / ngân sách*) cụm tên phải khớp một `tenDoiTuong` của gói bất kỳ (bỏ khoảng trắng, chứa nhau), *và/hoặc* nối cụm kế, "không" trước từ loại thì bỏ qua; lần đo 11 mô hình viết y hệt câu ấy và bị chặn → mẫu câu | `kiem_ten_test` (⭐ câu B1 nguyên văn; hai bản sai bị bắt); `kiem_cau_tra_loi_test` *"lớp thứ tư đã NỐI"*; *(đo máy thật — mục 9.26, 9.27)* |
| 4.4 | **Luật "đã bị cắt hai kỳ liền trước" (C3) chỉ kích hoạt khi ngân sách đã tồn tại ≥ 3 kỳ** — `recentPeriods` trả một kỳ cho ngân sách tạo tháng này, và luật im lặng | không lỗi; chỉ là trần 25 % thay vì 15 % | `tai_phan_bo_test.dart` *"đã bị cắt hai kỳ liền trước → trần 15 %"* có cả hai fixture |

## 5. Màn Stitch

| Màn | Id | Ngày | Nghiệm thu |
|---|---|---|---|
| Khối Nhận xét — bốn biến thể (+ thẻ thiếu dữ liệu) | `b396533ba02042b390377137144eedf8` | 2026-09-19 | người dùng OK cùng ngày. ⚠️ Lượt gọi trả `timeout`, màn hiện sau vài phút — không gọi lại. API ghi `DESKTOP` 2560px dù truyền `MOBILE`; thân vẽ trong cột 390px |
| Thẻ + sheet kế hoạch tái phân bổ (ba khối: thẻ tóm tắt · sheet · thẻ thiếu nguồn bù) | `f02861d93e7a46ef8183a0b27e9e03d6` | 2026-09-19 | người dùng OK cùng ngày. Stitch vẽ thêm nút "Tăng hạn mức ngân sách" ở thẻ thiếu nguồn bù — bản thi công **không** dựng nút ấy (ngoài phạm vi P2) |
| Công tắc Cố định ở màn Sửa danh mục | `a5a6ecb39151491d8e847a75d7c0a7ad` | 2026-09-19 | người dùng OK cùng ngày. Thẻ nằm giữa khối màu và khối từ khoá, chip "Chỉ lưu trên máy này" |
| (P3) Màn Cài đặt AI | `1da347e753964e15a91b10c473975923` | 2026-09-22 | ✅ **người dùng xem và xác nhận 2026-09-22**. Vẽ **ba trạng thái xếp dọc** trong một thẻ để so sánh (chưa tải · đang tải 42% có nút Huỷ · đã tải 2,41 GB có nút Xoá màu đỏ), dòng Wi-Fi, công tắc *Dùng AI trên máy*, khối giải thích *không có số liệu nào rời khỏi thiết bị*. ⚠️ API lại ghi `DESKTOP` 2560px dù truyền `MOBILE` — lần thứ ba; thân vẫn vẽ một cột điện thoại căn giữa. ⚠️ Bản thi công dựng **một** trạng thái tại một thời điểm, không xếp ba thẻ chồng nhau: ba khối trong màn Stitch là để **so sánh khi thiết kế**, không phải bố cục thật |
| Trợ lý AI (có sẵn) | `75abffa956bb4da99a112df704f2d487` | trước 2026-09-19 | có sẵn; P3 bỏ nút ảnh/mic |

## 6. Schema v24 (2026-09-19)

| Thứ | Ở đâu | Khuôn mẫu | Ghi chú |
|---|---|---|---|
| Cột `categories.ai_co_dinh` (`BoolColumn`, mặc định `false`) | `tables/categories_table.dart` | `wallets.allow_negative` (v23, G27) | Cờ "Cố định — AI không đề xuất cắt" (luật C2). Bật ở màn Thêm/Sửa danh mục (`_TheCoDinh`, key `cong-tac-ai-co-dinh`); ẩn ở màn chỉ-từ-khoá của danh mục mặc định. Đi qua `CategoryChildDraft.aiCoDinh` → `saveChild` |
| Bảng `AiRebalancingFeedbacks` | `tables/ai_feedback_table.dart`, DAO `daos/ai_feedback_dao.dart` (`ghi`, `getAll`) | `AppNotifications` (quy tắc 9) | 11 cột, **không** `syncStatus`/`syncError`/`updatedAt`/`isDeleted`. `purgeDataForOtherAccounts` và `purgeDataForAccount` xoá theo `idaccount` (nay **mười** bảng) |

Migration `from < 24`: `addColumn` + `createTable`, không điền hàng cũ. **Test quét thứ 15**
(`test/features/ai_edge/ai_edge_cuc_bo_khong_dong_bo_test.dart`) cấm năm chuỗi (`aiCoDinh`,
`ai_co_dinh`, `AiRebalancingFeedback`, `ai_rebalancing_feedbacks`, `aiRebalancingFeedbacks`) trong
`sync_engine.dart`, `sync_payload_normalizer.dart`, `sync_models.dart` và trong hợp đồng payload —
**không** bỏ dòng chú thích (khác test 14): một chú thích nhắc tên cột ở đường đồng bộ là dấu hiệu ai
đó định đưa nó vào. Bản sai có chủ ý (`final String banSaiCoChuY = 'ai_co_dinh';` cuối
`sync_engine.dart`) làm nó đỏ đúng dòng ngày 2026-09-19. `sync_payload_contract_test.dart` không đổi.

⚠️ **Hai bẫy của lượt này**: (1) data class Drift `Category` đòi thêm tham số bắt buộc → **7** chỗ
dựng `Category(...)` bằng tay trong test phải thêm `aiCoDinh: false` (cùng việc cơ học của G27);
(2) `categoryDao.insert` là **`insertOrReplace`** — `saveChild` không gán `aiCoDinh` thì mỗi lần
sửa tên danh mục lặng lẽ **tắt cờ**; có ca test canh (*"sửa tên mà vẫn truyền cờ bật → cờ còn"*).

## 7. Kiểm thử

| Tệp | Ca | Canh gì | Ngày |
|---|---|---|---|
| `test/features/ai_edge/domain/goi_so_test.dart` | 3 | định dạng số liệu: `đ` có cách, phần trăm 1 chữ số thập phân (G2), số âm giữ dấu | 2026-09-19 |
| `test/features/ai_edge/domain/dau_van_test.dart` | 4 | dấu vân đổi theo số và màn, **không** đổi theo thứ tự | 2026-09-19 |
| `test/features/ai_edge/ai_edge_khong_tinh_test.dart` | 1 | **test quét `lib/` thứ 14** — `ai_edge/` không chứa `'thu'`/`'chi'`/`'transfer'`/`walletId`/`transactionDao`/`.type ==`/`amount <`/`amount >`; bỏ dòng chú thích. Bản sai có chủ ý (`final String banSaiCoChuY = 'thu';` ở `goi_so.dart:81`) làm nó đỏ đúng dòng ngày 2026-09-19, gỡ → xanh | 2026-09-19 |
| `test/features/ai_edge/domain/kiem_so_test.dart` | 9 | bộ kiểm số: câu bịa bị chặn, ±0,5 đ, ±0,05 điểm %, **dấu âm**, loại số phải khớp | 2026-09-19 |
| `test/features/ai_edge/domain/goi_so_ngan_sach_test.dart` | 7 | gói Ngân sách (căng nhất qua `pickHomeBudget`), câu vượt/chưa vượt, **mẫu câu tự qua bộ kiểm số**, có kế hoạch vẫn qua | 2026-09-19 |
| `test/features/ai_edge/domain/goi_so_phan_tich_test.dart` | 10 | gói Phân tích: nền 0 không in %, tỉ lệ âm → "vượt thu nhập", cam kết, khoản lớn nhất không in tiêu đề | 2026-09-19 |
| `test/features/ai_edge/domain/goi_so_muc_tieu_test.dart` | 6 | gói Mục tiêu: chậm/đúng/quá hạn, phần tử đầu của đang theo đuổi | 2026-09-19 |
| `test/features/ai_edge/domain/goi_so_trang_chu_test.dart` | 6 | gói Trang chủ nhận số của trang; số 0 không mang dấu; ngân sách căng nhất | 2026-09-19 |
| `test/features/ai_edge/domain/tai_phan_bo_test.dart` | 15 | Tầng 2: dự phóng, ngưỡng kép, nguồn bù theo dư địa, cờ Cố định, dư địa ≥ 100k, trần 15 % (cần ≥ 3 kỳ), làm tròn, ngưỡng có nghĩa, cạn nguồn, hụt lớn nhất, `categoryId` null | 2026-09-19 |
| `test/core/database/schema_v24_test.dart` | 6 | v24: cột `ai_co_dinh`, bảng phản hồi không cột đồng bộ, DAO, hai hàm purge | 2026-09-19 |
| `test/features/ai_edge/ai_edge_cuc_bo_khong_dong_bo_test.dart` | 2 | **test quét thứ 15** — hai thứ v24 không lọt vào ba tệp đồng bộ và hợp đồng payload; bản sai có chủ ý đỏ đúng dòng | 2026-09-19 |
| `test/features/category/category_ai_co_dinh_test.dart` | 7 | cờ Cố định: `saveChild` ghi/giữ cờ (`insertOrReplace`), công tắc ở màn Sửa danh mục (cuộn tới bằng `scrollUntilVisible` — ListView lười dựng), ẩn ở màn chỉ-từ-khoá, 411dp không tràn | 2026-09-19 |
| `test/features/ai_edge/presentation/khoi_nhan_xet_test.dart` | 7 | khối Nhận xét: mẫu câu hiện ngay, câu mô hình thay sau + nhãn AI, thiếu dữ liệu không thẻ, 200 ký tự không tràn, lỗi bộ diễn giải giữ mẫu, viền cảnh báo, nền tối | 2026-09-19 |
| `test/features/budget/data/tai_phan_bo_nguon_test.dart` | 7 | nguồn Tầng 2: cờ Cố định bỏ hàng xoá mềm, thu nhập mỗi tháng **không đếm đi vay**, cửa sổ cuộn (tài khoản quá trẻ → 0; chi cũ hơn 90 ngày không đếm), mức mỗi tháng theo `budget.id`, phản hồi cũ | 2026-09-19 |
| `test/features/budget/budget_cubit_ke_hoach_test.dart` | 5 | `BudgetCubit`: không nguồn → đồng bộ như cũ; có nguồn → kế hoạch; cờ Cố định; nguồn lỗi vẫn `BudgetLoaded`; lượt nạp chậm không đè lượt mới | 2026-09-19 |
| `test/features/budget/budget_khoi_nhan_xet_test.dart` | 6 | Task 14 — trang Ngân sách: một khối, câu đúng số của state (33,3 %, còn 16 ngày), nói về ngân sách **căng nhất**, có `keHoach` thì nối câu tóm tắt (tìm **trong khối**, vì thẻ cũng in câu ấy), rỗng thì không dựng. Task 15: +2 ca — thẻ đứng dưới khối và chạm "Xem kế hoạch" gọi `onXemKeHoach` với **đúng** kế hoạch của state; không có callback thì không nút | 2026-09-19 |
| `test/features/analytics/analytics_page_test.dart` (+2) | 2 | Task 14 — trang Phân tích: khối sau "Số dư còn lại" trước Xu hướng, câu "tăng 25,0% so với kỳ trước"; kỳ rỗng không dựng. Đặt trong tệp có sẵn để dùng lại helper `_tk` | 2026-09-19 |
| `test/features/goal/goal_khoi_nhan_xet_test.dart` | 2 | Task 14 — trang Mục tiêu (dựng `GoalPage` thật): câu "MuaXe: 55,0%, còn thiếu 900.000 đ"; chỉ có mục tiêu hoàn thành thì không dựng. ⚠️ tháo cây ở **cuối thân test**, không qua `addTearDown` (khung kiểm "Pending timers" trước tearDown) | 2026-09-19 |
| `test/features/home/home_khoi_nhan_xet_test.dart` | 2 | Task 14 — Trang chủ (quét nguồn, cùng lối `trang_chu_gon_test`): hết "Insight AI"/"Thêm thêm"/`_buildInsightCard`; có `KhoiNhanXet(` + `GoiSoTrangChu.tu(` + `nenToi: true` | 2026-09-19 |

| `test/features/ai_edge/domain/ap_dung_ke_hoach_test.dart` | 9 | Task 15 — `hanMucMoi`: hai nguồn trừ / thâm hụt cộng Σ, **Σ hạn mức không đổi** (bản sai "trừ thay vì cộng" làm 3 ca đỏ), rỗng khi không chọn, `ArgumentError` khi âm/vượt dư địa, id lạ bỏ qua; `phanHoiTu`: accepted/modified/rejected, `boQua` → mọi dòng rejected, hàng mang đủ khoá C3 và kỳ **của nguồn** | 2026-09-19 |
| `test/features/ai_edge/presentation/the_ke_hoach_test.dart` | 4 | Task 15 — thẻ: biến thể đủ nguồn bù (chip "Dự kiến vượt", `cauTomTat`, "Nguồn bù: …", nút gọi `onXem`), thiếu một phần (nhãn đỏ, chip số thiếu, dòng gợi ý, link phân tích), không nguồn nào → không nút, không `onXemPhanTich` → không link; **không** có "Tăng hạn mức" | 2026-09-19 |
| `test/features/ai_edge/presentation/ke_hoach_sheet_test.dart` | 9 | Task 15 — sheet thật qua `showModalBottomSheet`: tiêu đề/thâm hụt/hai dòng/100 %, cao **cố định 70 %**, bỏ tick và sửa số đổi tổng bù, ô tiền có `GioiHanSoChuSo`, Áp dụng → 2 `updateBudget` đúng hạn mức + 2 hàng (`modified`, `rejected`) + đóng, Bỏ qua → 0 update + 2 `rejected`, chạm nền → **0 hàng**, không tick → nút tắt, vượt dư địa → lỗi + nút tắt (bản sai bỏ `_hopLe` làm đúng ca này đỏ) | 2026-09-19 |

| `test/core/notification/notification_rules_rebalance_test.dart` | 13 | Task 16 — luật `budgetRebalance`: kế hoạch `null` thì im; khoá **chỉ có tuần ISO** (cùng tuần khác ngày → cùng khoá; sang tuần → khác; 31/12/2025 → `2026-W01`); `body` **không chứa chữ số** nhưng có tên; hết nguồn bù → câu khác, không mời "Xem kế hoạch"; nhóm `budget` và **chịu** công tắc; `silenceBefore`; cold start → `/budget` | 2026-09-20 |
| `test/core/notification/notification_scanner_test.dart` (+4) | 4 | Task 16 — **chỗ nối**: có kế hoạch → một hàng; hai lượt cùng tuần → một hàng; **loader không được gọi** khi tắt nhóm Ngân sách hoặc không có ngân sách — hai ca này **xanh ngay từ đầu** nên đã kiểm bằng bản sai có chủ ý (bỏ cả hai điều kiện → cả hai đỏ) | 2026-09-20 |
| `test/core/notification/notification_deeplink_test.dart` (sửa) | — | Task 16 — phép canh "đủ mọi loại" **tự đỏ** khi enum thêm giá trị: phải dựng thêm `keHoachTaiPhanBo` cho `tatCaUngVien()`. Đúng cách lưới ấy sinh ra để làm việc | 2026-09-20 |
| `test/features/ai_edge/domain/kiem_nhan_test.dart` | 12 | việc số 1 — bộ kiểm NHÃN: ⭐ câu đo trên máy thật *"Tỉ lệ phân bổ là 85,4%"* bị chặn; đúng nhãn qua; số khớp hai nhãn ở hai gói đủ một nhãn; nhãn nhiều âm tiết đòi đủ; so theo **âm tiết** ("chiều" ≠ "chi"); `tuKhoaNhan` bỏ âm tiết chung | 2026-09-22 |
| `test/features/ai_edge/domain/kiem_cau_tra_loi_test.dart` | 9 | việc số 1 — định nghĩa duy nhất "một câu được hiện": `mucTongHop` (một gói cảnh báo → cả câu cảnh báo); ⭐ trấn an khi có gói cảnh báo bị chặn (điểm 5 cổng A, trước đó **chưa nối**); số bịa / sai nhãn / báo động khi bình thường bị chặn; phủ định ba từ giữ nguyên | 2026-09-22 |
| `test/features/ai_edge/domain/gac_cau_test.dart` | 11 | việc số 1 — gác theo câu: ⭐ **cuối bộ đệm chưa phải kết câu** và **token cắt ngay sau dấu chấm** (hai ca từ lỗi máy thật, bẫy 4.18); `tachCauHoanChinh` không cắt ở chấm ngăn nghìn; ⭐ câu trượt → `BiChan`, huỷ **một** lần, câu sau **không** hiện (dựng `StreamController` thật); hết luồng không dấu kết vẫn kiểm phần đuôi; luồng rỗng không phát gì | 2026-09-22 |
| `test/features/ai_edge/data/nguon_goi_so_test.dart` | 3 | việc số 1 — **sáu** gói theo thứ tự cố định; hoá đơn hỏi đúng `idaccount`; ví đọc **một** lần. Fake ghi đè `noSuchMethod` — chỉ dựng hàm được gọi, hàm lạ thì ném | 2026-09-22 |
| `test/features/ai_edge/domain/the_cua_cau_test.dart` | 5 | đo cổng A — thẻ của một câu: ⭐ số đếm ngắn không khớp vì là chuỗi con của số tiền (bẫy 4.19); cùng loại/ngưỡng với bộ kiểm số; hai nhãn cùng số → một thẻ; câu không số → không thẻ | 2026-09-22 |
| `test/features/ai_edge/data/nguon_tai_nen_test.dart` | 5 | tải nền — giao diện `NguonTaiNen` + bản giả: chưa bắt đầu thì `luotDangSong` null; batDau/tamDung/tiepTuc/huy; `tienToi` | 2026-09-22 |
| `test/features/ai_edge/data/mo_hinh_tai_ve_test.dart` (viết lại) | 15 | tải nền — `daCo()` kiểm **kích thước** (tệp 8 byte = chưa có; ca 2,4 GB `skip`); `khoiPhuc()` nối lượt lần trước / không có lượt thì im; `dangCho` → `choMang`; tamDung/tiepTuc; hỏng → `loi` kèm câu ngắn và **giữ** tệp dở; `huy()` xoá tệp dở; `cauLoiTai` 4 ca giữ nguyên | 2026-09-22 |
| `test/features/ai_edge/data/tai_nen_background_downloader_test.dart` | 9 | tải nền — hai hàm thuần của bản thật: ⭐ tiến độ âm là mã (bẫy 4.21); ⭐ `canceled` của WorkManager → `dangCho`, của người dùng → `huy` (4.22); `waitingToRetry` → `dangChay`; các trạng thái còn lại | 2026-09-22 |
| `test/features/ai_edge/domain/canary_gpu_test.dart` | 5 | tải nền (lộ ra ở nghiệm thu) — canary GPU: máy sạch thử GPU và dấu ghi **trước**; nạp xong dọn dấu; ⭐ dấu sót → CPU + ghi nhớ; đã hỏng → CPU mãi; đã hỏng thì không ghi canary | 2026-09-22 |
| `test/features/ai_edge/presentation/cai_dat_ai_page_test.dart` (+9) | 9 | tải nền — mở màn **hỏi lại** lượt lần trước; chờ mạng nói "Wi-Fi" và **không** hứa "giữ lại"; Tạm dừng ↔ Tiếp tục; bấm Tạm dừng **không tự đặt** trạng thái (`_NguonKhongPhanHoi`); hàng nút 411dp; hộp thoại 4G: hỏi trước / đồng ý → `chiWifi=false` / Để sau → không tải / có Wi-Fi → không hỏi | 2026-09-22 |
| `test/core/nhan_dien_app_test.dart` (+1) | 1 | manifest khai `FOREGROUND_SERVICE_DATA_SYNC` (Android 14+ đòi; build xanh nếu thiếu) | 2026-09-22 |
| `test/features/ai_edge/domain/slm_prompt_test.dart` (+7) | 7 | việc số 1 — `promptHoiDap`: ba ví dụ có Câu hỏi/Trả lời; ⭐ có ví dụ trả lời **không chữ số**; bất biến số-trong-gói cho bộ mới (⚠️ mốc cắt sửa ở **cả hai** ca — bẫy 4.16); chỉ dẫn "dùng đúng nhãn"; tiêu đề `== Ngân sách ==` đứng trước số liệu; gói thiếu dữ liệu in câu mẫu; prompt nhận xét **không đổi** | 2026-09-22 |
| `test/features/ai_chat/ai_chat_page_test.dart` (+4) | 4 | việc số 1 — nhóm *"streaming CHẶN THEO CÂU"*: câu qua kiểm hiện **khi luồng còn mở**; bị chặn khi chưa câu nào → câu lùi, không lộ "85,4"; bị chặn sau một câu → **giữ** câu ấy, không câu lùi; luồng lỗi → câu "không chạy được", ô nhập mở lại. Khe tiêm `onHoi` nay nhận `Stream<SuKienGac>`; chip test đổi sang bộ mới | 2026-09-22 |

### 7.3 Nghiệm thu máy ảo Task 16 (2026-09-20, `emulator-5554`, tài khoản 10, backend dev chạy)

Trạng thái đầu: **không** ngân sách nào thâm hụt đủ ngưỡng kép — trang Ngân sách
không có thẻ "Đề xuất cân đối", trung tâm thông báo không có hàng nào. Đúng: Task 15
đã áp dụng kế hoạch hôm trước nên thâm hụt đã được cân đối.

Tạo thâm hụt **thật** qua giao diện: một khoản chi **50.000 đ / Di chuyển** (ngân sách
305.000 / 450.000, đã qua 19/30 ngày → dự phóng 355.000 × 30/19 = 560.526, thâm hụt
**110.526 đ**). Kết quả đo được:

| Đo | Kết quả |
|---|---|
| Lượt quét sau khi đồng bộ xong | `[NotificationScanner] Quét xong cho tài khoản 10 — **1 hàng mới**` |
| Thẻ trong trung tâm thông báo | *"Đề xuất cân đối ngân sách — Di chuyển dự kiến vượt hạn mức. Xem kế hoạch bớt từ ngân sách khác. — Vừa xong"*, viền đỏ (warning), icon ngân sách. **Không một chữ số**, có tên ngân sách |
| Chạm vào thông báo | mở **đúng** trang Ngân sách, có nút Back (route chồng, đúng nhóm D) |
| Thẻ trên trang sau khi tới | *"ĐỀ XUẤT CÂN ĐỐI · Dự kiến vượt — Di chuyển dự kiến vượt **110.526 đ**. Bớt từ 1 ngân sách khác? · Nguồn bù: Mua sắm"* — **cùng một ngân sách** với thông báo, đúng cam kết một định nghĩa |
| Lượt quét thứ hai (đưa app vào nền rồi quay lại) | `— **0 hàng mới**`: khoá tuần chống trùng làm việc |
| Chip **Ngân sách** của trung tâm | lọc ra đủ **bốn** loại của nhóm: Đề xuất cân đối · Đã vượt · Sắp vượt · Khoản chi lớn |
| Tràn bố cục | **0 pixel vàng** trên cả **12** ảnh (`t16_01–12`, scratchpad) |
| Logcat | 0 exception của app (hai dòng `BluetoothPowerStatsCollector` là của Android) |

⚠️ Khoản chi 50.000 đ ấy **để lại** trên tài khoản 10 (đã đẩy lên PostgreSQL): xóa đi là
thâm hụt biến mất và Task 17 không nghiệm thu lại được trạng thái này.

### 7.4 Nghiệm thu TỔNG — Task 17 (2026-09-20, `emulator-5554`, tài khoản 10, backend dev chạy)

Lượt cuối của P2: đi qua **sáu** chỗ người dùng gặp tầng Edge, trên bản APK có đủ
Task 0–16.

| Màn | Đo được |
|---|---|
| **Trang chủ** (khối nền tối) | *"Tháng này thu 15.145.000 đ, chi 2.141.000 đ, còn lại 13.004.000 đ. Ngân sách Giáo dục đã dùng 90,0%."* — năm thẻ số liệu, mọi con số **khớp thẻ ngay phía trên** |
| **Phân tích** | khối đứng ngay sau "Số dư còn lại": *"Kỳ này chi 2.141.000 đ; để dành 85,4% thu nhập. Một tháng tới có 14 cam kết phải trả, tổng 665.000 đ. Khoản chi lớn nhất 800.000 đ."* |
| **Mục tiêu** | *"MuaXe: 55,0%, còn thiếu 899.000 đ, còn 585 ngày; đúng kế hoạch."* — khớp thẻ mục tiêu đầu danh sách |
| **Ngân sách** | khối Nhận xét (ngân sách **căng nhất** = Giáo dục 90,0%) + thẻ **Đề xuất cân đối** (ngân sách **thâm hụt lớn nhất** = Di chuyển) — hai ngân sách **khác nhau**, đúng như mục 2 ghi |
| **Sheet kế hoạch** | *"Kế hoạch cân đối ngân sách · Di chuyển · thâm hụt dự kiến 110.526 đ"*, một dòng *Mua sắm · dư địa 755.263 đ · −120.000*, **"Tổng bù: 120.000 đ / 110.526 đ · 100% CÂN ĐỐI"**. Vuốt tắt → **không ghi phản hồi nào** (lối ra thứ ba) |
| **Sửa danh mục** | công tắc *"Cố định — AI không đề xuất cắt"* kèm chip **"Chỉ lưu trên máy này"** và câu giải thích; tắt sẵn |

Cộng **thông báo `budgetRebalance`** đã nghiệm thu riêng ở mục 7.3.

**Tràn bố cục: 0.** Đo trên **21** ảnh (`t16_01–12`, `t17_01–09`, scratchpad) — 0
pixel vàng thuần `#FFFF00`. ⚠️ Một dải vàng rộng cho **6305** px trên cùng bộ ảnh,
toàn bộ là emoji 💡, biểu tượng ⚠ và ô cam của bảng chọn màu danh mục — xem bẫy
**4.10**. **Logcat: 0** dòng lỗi/cảnh báo của `flutter`.

**Trọn bộ test 3106/3106 pass, 1 skip** (3 phút 49 giây, chạy song song với
`flutter build apk`); `flutter analyze` **26 issue, 0 error** — mức nền.

### 7.2 Nghiệm thu máy ảo Task 15 (2026-09-19 tối, `emulator-5554`, tài khoản 10, backend dev chạy)

Dữ liệu dựng bằng giao diện: ba ngân sách tháng **Di chuyển 300.000** (đã chi 305.000 — dự phóng
508.333 → thâm hụt **208.333**), **Mua sắm 1.000.000** (chi 60.000 → dư địa 900.000), **Ăn uống
500.000**. Ảnh ở scratchpad phiên, **0 pixel vàng** ở cả năm: `t15_b.png` (thẻ biến thể **thiếu
nguồn bù** khi mới chỉ có Di chuyển: "-208.333 đ", dòng "Không ngân sách nào còn dư địa…", link
"Xem phân tích chi tiêu"), `t15_the.png` (đủ nguồn bù: "Nguồn bù: Mua sắm" + "Xem kế hoạch"),
`t15_sheet.png` (một dòng, đề xuất **210.000** = làm tròn 10k của 208.333, "100% CÂN ĐỐI"),
`t15_sheet_edit2.png` (sửa thành 150.000 → "72% CÂN ĐỐI"), `t15_after.png` (sau Áp dụng).

Đo đầu-cuối sau Áp dụng: logcat `[SyncEngine] Sending batch 2 operations` → `2/2 synced`;
PostgreSQL `budget.TotalAmount`: Di chuyển **450.000**, Mua sắm **850.000** (Σ không đổi); SQLite
máy ảo `ai_rebalancing_feedbacks` có đúng **một** hàng `modified`, `suggested 210000`, `actual
150000`, kỳ 01/09–01/10 (đọc qua WAL — bẫy 4.9). Trang tính lại ngay: kế hoạch mới cho phần còn
thiếu **58.333** (150.000 < 208.333, đúng nghĩa "bù một phần").

### 7.1 Nghiệm thu máy ảo Task 14 (2026-09-19, `emulator-5554`, AVD `FlowMoney_16G`, tài khoản 10)

Bốn ảnh ở scratchpad phiên: `t14_home_bottom.png`, `t14_analytics.png`, `t14_goal.png`,
`t14_budget.png` — **0 pixel vàng thuần** ở cả bốn (đếm bằng PIL). Khối hiện đúng chỗ ở bốn màn và
câu chép **đúng số của thẻ bên cạnh**: Ngân sách *"Giáo dục: đã dùng 45.000 đ / 50.000 đ (90,0%), còn
12 ngày — nên chi tối đa 417 đ mỗi ngày"* khớp dòng "Nên chi 417 đ/ngày · còn 12 ngày" của thẻ; Mục
tiêu *"MuaXe: 55,0%, còn thiếu 899.000 đ, còn 586 ngày; đúng kế hoạch"*; Trang chủ nền tối *"Tháng
này thu 15.145.000 đ, chi 2.091.000 đ, còn lại 13.054.000 đ. Ngân sách Giáo dục đã dùng 90,0%"*.

⚠️ **Hai chỗ lệch nhìn thấy được, cả hai có từ trước và cố ý không vá trong Task 14:**

1. Trang chủ nói thu **15.145.000 đ**, trang Phân tích nói **15.135.000 đ** (chênh 10.000). Thẻ số
   liệu tháng của Trang chủ **cộng thô theo `type`** (kể cả khoản điều chỉnh số dư / mở sổ), còn Phân
   tích đi qua `khoanVaoThongKe`. Khối Nhận xét ở mỗi trang **chép đúng số của trang ấy** — đó là
   điều kiện 12 — nên hai khối nói hai số là *hệ quả* của hai thẻ đã nói hai số từ trước. Muốn hai
   trang khớp thì đổi `thuChiThangCua` (một chỗ), không đổi gói số.
   ✅ **Đã vá 2026-09-23** (bước 1a của thứ tự mới, sau cổng C): người dùng chốt con số của Phân
   tích; `thuChiThangCua` nay **đi qua `tongThuChi`** và cắt tháng bằng `Ky.thang`, nên hai trang
   không còn hai vòng cộng. Nghiệm thu máy ảo cùng tối (tài khoản 10): thẻ Trang chủ, khối Nhận xét
   Trang chủ và trang Phân tích cùng nói *thu 15.135.000 đ · chi 2.141.000 đ*, khối Nhận xét
   *"…còn lại 12.994.000 đ"*. Chỗ lệch **có nghĩa hơn** từ lát 4b: trợ lý AI trả lời bằng tool
   `chi_tieu_theo_ky` (đọc `tongThuChi`), nên trước bản vá nó nói một số còn thẻ ngay trên Trang chủ
   nói số kia. Test: `test/features/home/thu_chi_thang_test.dart`.
2. Thẻ "Số dư còn lại" in "Để dành **86%**" (làm tròn nguyên) còn khối in "**85,7%**" (luật G2,
   một chữ số thập phân). Cùng một `tyLeTietKiem`, hai cách làm tròn.

## 8. Bảng đo P1 (2026-09-20) — ✅ ĐÃ ĐO TRÊN MÁY THẬT

**Máy:** OnePlus 13R `CPH2691`, SoC **SM8650 = Snapdragon 8 Gen 3** (QTI), `arm64-v8a`,
RAM **10,95 GB** (`MemTotal` 11.483.184 kB), Android **16** / SDK 36, trống 110 GB.
Pin 31–34 %, **đang sạc**; nhiệt CPU nghỉ ~35 °C.

**Cách đo:** app spike riêng (`D:/flowmoney-spike`, **mã vứt đi, không commit**),
`flutter_gemma 1.8.3` + `flutter_gemma_litertlm 1.7.0`, `maxTokens: 1024`,
`temperature: 0.2`. Prompt = prompt hệ thống **nguyên văn** mục 3.2 đặc tả gốc + **hai** ví
dụ few-shot + gói số dạng `Nhãn: chuỗi`. Ba gói số là số **thật** của tài khoản 10 (đúng
những con số khối Nhận xét đang hiện). RAM đỉnh = `TOTAL PSS` của `dumpsys meminfo`, lấy
mẫu 3 s/lần trong suốt lượt chạy.

### 8.1 Bốn tổ hợp chạy được

| Mô hình | Tệp | Backend | Nạp | Ba gói (ms) | 10 câu, TB | Câu 1 → câu 10 | **RAM đỉnh** |
|---|---|---|---|---|---|---|---|
| **E4B** | `gemma-4-E4B-it.litertlm` 3,41 GB | **GPU** | 9.944 ms | 5.425 / 5.097 / 2.734 | **4.668 ms** | 4.596 → 4.678 (**+1,8 %**) | **0,97 GB** |
| E4B | nt | CPU | 10.499 ms | 8.226 / 7.968 / 5.848 | 12.675 ms | 12.704 → 8.943 (−29,6 %) | **3,27 GB** |
| **E2B** | `gemma-4-E2B-it.litertlm` 2,41 GB | **GPU** | 9.131 ms | 3.486 / 2.293 / 1.383 | **2.329 ms** | 2.335 → 2.279 (**−2,4 %**) | **0,96 GB** |
| E2B | nt | CPU | **4.516 ms** | 3.839 / 3.420 / 2.336 | 3.313 ms | 3.288 → 3.355 (+2,0 %) | 1,73 GB |
| E2B | nt | **NPU** | 8.626 ms | 14.542 / 8.821 / 6.049 | 8.430 ms | 8.837 → 8.438 (−4,5 %) | **3,24 GB** |

⚠️ **Hàng NPU đo ngày 2026-09-21 (chặng 0.1), và nó KHÔNG phải một cải thiện** — NPU
**chậm hơn GPU 3,6 lần** (8.430 ms so với 2.329 ms) và tốn RAM **gấp 3,4 lần** (3,24 GB so
với 0,96 GB), tức tệ hơn **cả CPU** ở cả hai mặt. Đây là hàng đo để **đóng một câu hỏi**,
không phải để đổi bậc thang: bậc thang mục 8.5 **giữ nguyên**, không thêm nhánh NPU.

Ba điều đi kèm, đọc trước khi có ai định thử lại NPU:

1. **Nó CHẠY THẬT, không phải rơi về CPU.** Nhật ký cho thấy gói tự giải nén bộ thư viện
   Qualcomm (`libQnnHtp.so`, `libQnnHtpV73/V75/V79/V81*`) vào `code_cache/npu_libs` rồi
   đăng ký `NpuAccelerator`. Nên con số chậm là con số **của NPU**, không phải của một
   lần rơi nhánh âm thầm.
2. ⚠️ **Lần đăng ký ĐẦU thất bại, lần thứ hai mới được** —
   `npu_registry.cc:34] NPU accelerator could not be loaded and registered:
   kLiteRtStatusErrorInvalidArgument`, rồi ngay sau đó `npu_registry.cc:30] NPU
   accelerator registered.` Ai đọc logcat mà dừng ở dòng cảnh báo đầu sẽ kết luận nhầm là
   NPU không chạy được.
3. ⚠️ **NPU bỏ qua tham số lấy mẫu.** Chính gói in ra: *"the NPU executor samples greedily
   and never reads them — output is deterministic argmax"*. Tức `temperature` của spec
   **không có tác dụng** trên nhánh này — một lý do nữa để không dùng nó.

**Nhiệt: không thành vấn đề.** Sau 13 câu liên tiếp, CPU đi từ 35,2 °C lên **37,1 °C**, pin
giữ 30,4 °C. Ba trong bốn tổ hợp có câu 10 **nhanh bằng hoặc hơn** câu 1 — không thấy
throttle. Riêng E4B/CPU dao động rất mạnh (8.508 – 21.723 ms, ±150 %) nhưng theo chiều
*nhanh dần*, tức là warm-up chứ không phải nóng lên.

### 8.2 ⚠️ Tệp `-gpu.litertlm` KHÔNG nạp được, dù tệp nguyên vẹn

`gemma-4-E4B-it-gpu.litertlm` (2,77 GB) ném `BackendInitException: all FFI backends
failed … Failed to create engine. Model may be invalid` với **cả hai** backend. Kích thước
tệp khớp từng byte ở cả ba nơi (máy tính → `/sdcard` → thư mục app: 2.969.059.328), nên
**không phải hỏng khi chép**. Biến thể `-gpu` của litert-community dành cho đường khác
(web/desktop), không phải engine FFI Android.

**Kết luận thực dụng: chỉ tải bản `‹model›.litertlm` chuẩn.** Bản `-gpu` nhẹ hơn 0,6 GB
nhưng vô dụng, và thông báo lỗi của nó (*"Model may be invalid"*) dẫn người đọc đi sai
hướng — sẽ mất hàng giờ kiểm tra tải hỏng.

### 8.3 ✅ Máy ảo x86_64 rơi về mẫu câu — và lỗi ĐỌC ĐƯỢC

Cùng APK, cùng tệp mô hình, trên `emulator-5554` (`x86_64`):

```
Unsupported operation: flutter_gemma .litertlm models require an arm64-v8a
Android device (got android_x64). Use a `.task` MediaPipe model on this ABI
or run on an arm64-v8a device / Apple Silicon emulator.
```

Gói tự nêu tên ABI, nên **P3 không cần tự đọc ABI**: một `try/catch` quanh
`getActiveModel` là đủ để rơi về mẫu câu. Lỗi ném ở bước **nạp**, sau khi `install()` đã
thành công (265 ms) — tức `install()` **không** phải chỗ phát hiện máy không chạy được.

### 8.4 Chất lượng tiếng Việt — cả hai mô hình đều đạt

Câu sinh ra (gói Ngân sách, số thật):

- **E4B/GPU:** *"Giáo dục đã chi 45.000 đ / 50.000 đ (90,0%), còn 11 ngày, mỗi ngày 455 đ,
  thâm hụt 110.526 đ, nguồn bù 1."*
- **E2B/GPU:** *"Ngân sách Giáo dục đã chi 45.000 đ trên hạn mức 50.000 đ (90,0%), còn 11
  ngày, với mức chi mỗi ngày là 455 đ và thâm hụt 110.526 đ."*

Ngữ pháp đúng, giọng tự nhiên, **mọi con số lấy từ gói** — không thấy bịa số ở lượt nào
trong 52 câu đã sinh. E2B thậm chí đọc trôi hơn (*"trên hạn mức"*, *"với mức chi mỗi ngày
là"*) trong khi E4B liệt kê khô hơn.

⚠️ **Cả hai đều mắc cùng một lỗi, và đó là lỗi của PROMPT chứ không của mô hình:** chúng
**đọc hết mọi dòng** trong gói, kể cả dòng vô nghĩa với người đọc — E4B nói *"nguồn bù 1"*.
P3 phải hoặc lọc gói trước khi bơm vào prompt, hoặc nói rõ trong prompt là được phép bỏ
qua dòng không đáng nhắc.

### 8.5 Điều P1 lật của bản thiết kế

| Giả định trong spec (mục 4.1) | Phép đo nói gì |
|---|---|
| Bậc thang theo **RAM thiết bị**: ≥ 8 GB → E4B, 4–8 GB → E2B | RAM đỉnh **không** phụ thuộc mô hình mà phụ thuộc **backend**: trên GPU, E4B tốn **0,97 GB** còn E2B **0,96 GB** — bằng nhau. Ngưỡng 8 GB dựa trên con số CPU (3,27 GB) và **quá chặt** cho đường GPU |
| E4B ≈ 4,3 GB, E2B ≈ 2,4 GB | tệp chuẩn: E4B **3,41 GB**, E2B **2,41 GB** (bản `-gpu` nhẹ hơn nhưng **không dùng được**, xem 8.2) |
| `flutter_gemma` là gói duy nhất cần thêm | core **không kèm engine nào**; `.litertlm` đòi thêm **`flutter_gemma_litertlm`** |
| Ngưỡng rơi về mẫu câu: RAM < 4 GB hoặc không arm64 | vế "không arm64" đúng và **gói tự báo** (8.3). Vế RAM thì đo được là rộng rãi hơn nhiều so với giả định |

### ✅ BẬC THANG MỚI — người dùng chốt 2026-09-20

**E2B cho MỌI máy; E4B bỏ hẳn.**

| Điều kiện | Mô hình | Backend |
|---|---|---|
| arm64-v8a, GPU dựng được | **E2B** | GPU |
| arm64-v8a, GPU hỏng, RAM ≥ 4 GB | E2B | CPU |
| còn lại (x86_64, RAM thấp, chưa tải, pin yếu, lỗi runtime) | **mẫu câu** | — |

Lý lẽ: E2B/GPU **nhanh gấp đôi** E4B/GPU (2,3 s vs 4,7 s), tốn RAM **bằng nhau**, tệp nhẹ
hơn **1 GB**, và chất lượng tiếng Việt trên đúng việc này — diễn giải một gói số đã tính
sẵn — **không thua**. E4B chỉ hơn nếu về sau cần suy luận nhiều bước, thứ kiến trúc
"máy tính số, mô hình kể chuyện" cố ý không giao cho mô hình.

⚠️ **Spec đã duyệt (mục 4.1) vẫn ghi bậc thang CŨ.** Chính spec ấy nói *"P1 có thể
đổi con số ngưỡng; bảng này là điểm xuất phát"* — và P1 đã đổi. Ai đọc spec mà không
đọc mục này sẽ lặng lẽ cài lại E4B.

### 8.6 ⚠️ Bốn cái bẫy của việc đưa mô hình lên máy

Không cái nào là lỗi Flutter, nhưng cái thứ hai tốn nhiều thời gian nhất:

1. `/data/local/tmp/models` — adb ghi được, **app sandbox không đọc được**.
2. `/sdcard/Android/data/‹pkg›/files/` — `adb push` in *"1 file pushed, 0 skipped"* kèm tốc
   độ và **exit 0**, mà thư mục vẫn **rỗng**: scoped storage nuốt sạch, không một dòng lỗi.
   **Đừng tin mã thoát của `adb push` ở đây — phải `ls` lại.**
3. `/sdcard/Download/…` ghi được, nhưng app cần All files access, mà ROM OnePlus **chặn**
   `appops set` từ shell (`uid 2000 does not have MANAGE_APP_OPS_MODES`).
4. ✅ Đường đi được: push vào `/sdcard/Download`, rồi
   `adb shell "cat … | run-as ‹pkg› sh -c 'cat > files/models/…'"` — `cat` chạy dưới shell
   (đọc được sdcard), `run-as` ghi dưới uid app. 2 GB mất **12 giây**, và **không hỏng byte
   nào** (kiểm bằng kích thước: khớp từng byte).

Cộng hai cái bẫy của chính lượt dựng spike: chú thích XML trong `AndroidManifest.xml`
**không được chứa hai dấu gạch ngang** (`--uid` trong một ví dụ lệnh làm manifest merger
chết với *"Error parsing"*), và **logcat trôi nhanh hơn một lượt đo** — số liệu đọc trên
**màn hình app** mới đủ, `adb logcat -d` chỉ còn vài dòng cuối.

### 8.7 Ảnh và âm thanh (chặng 0.2, đo 2026-09-21) — ✅ CẢ HAI CHẠY ĐƯỢC

P1 chỉ đo **văn bản**. Ba câu hỏi của chặng 0.2 nay có đáp án, và đáp án **tốt hơn dự
đoán**: nhánh đọc hoá đơn là **khả thi về mặt kỹ thuật**.

Cùng máy, cùng tệp `gemma-4-E2B-it.litertlm`, `maxTokens: 2048` (ảnh ăn token, 1024 chật).
Pin 85–86 % **đang sạc**; nhiệt pin đi từ **33,1 °C** lúc bắt đầu tới **34,8 °C** sau trọn
cả chặng 0 (NPU + bốn lượt đa phương thức) — **nhiệt vẫn không thành vấn đề**, đúng như 8.1.
Ảnh bơm bằng `Message.withImage`, âm thanh bằng `Message.withAudio`, bật qua
`getActiveModel(supportImage:/supportAudio:)`.

| Lượt | Backend | Nạp | Ba/hai câu hỏi (ms) | **RAM đỉnh** |
|---|---|---|---|---|
| Ảnh **sạch** 73,6 KB | GPU | 9.352 ms | 6.263 / 4.858 / 11.574 | **1,66 GB** |
| Ảnh **mờ** 50,0 KB | GPU | 4.431 ms | 5.787 / 4.631 / 11.744 | *(không lấy mẫu)* |
| Ảnh **sạch** | CPU | 4.423 ms | 6.946 / 5.719 / 14.513 | **2,64 GB** |
| Âm thanh 2,89 s | GPU | 4.235 ms | 2.086 / 943 | **1,05 GB** |

**Giá của đa phương thức, tính theo RAM:** ảnh **+0,70 GB** so với văn bản (1,66 so với
0,96 GB trên GPU), âm thanh chỉ **+0,09 GB**. Cả hai vẫn **dưới** mức CPU-văn bản
(1,73 GB), nên không mở ra ngưỡng RAM mới nào.

**Chất lượng đọc hoá đơn — số thì đúng, chữ thì sai dấu.** Cả **ba** lượt ảnh đều trả về
tổng tiền **`191.862`** chính xác, và **mọi** con số dòng hàng đều đúng. Chỗ sai chỉ nằm ở
**chữ có dấu**: `sầu riêng` đọc thành *"sả riêng"* (GPU) và *"sáu riêng"* (ảnh mờ),
`thối lại` thành *"thống lại"* / *"thôi lại"*.

⚠️ **Ảnh mờ KHÔNG tệ hơn ảnh sạch** — cùng đọc đúng `191.862`, cùng đúng mọi dòng hàng,
thời gian chênh không đáng kể. Phép đo dựng hai ảnh để kẹp lấy khả năng thật, và kết quả
là hai đầu kẹp **trùng nhau**; mức nhoè này chưa chạm tới giới hạn của mô hình.

⚠️ **Nhưng đây là cận trên, đừng đọc thành lời hứa.** Ảnh là ảnh **dựng bằng máy** (PIL,
phông Roboto, chữ thẳng hàng, nền đều) chứ không phải ảnh **chụp** một tờ in nhiệt thật —
không có nếp gấp, loá đèn, nghiêng phối cảnh, mực phai không đều hay phông chữ máy in
nhiệt. Con số ở đây trả lời *"mô hình có đọc nổi tiếng Việt có dấu không"* (có), **không**
trả lời *"đọc nổi hoá đơn trong túi người dùng không"*. Muốn biết vế sau thì phải đo lại
bằng ảnh chụp thật.

**Âm thanh: đi thẳng qua Gemma, không cần mô hình thứ hai.** `supportAudio: true` nhận
thẳng WAV 16 kHz mono. Câu thử *"Hôm nay tôi ăn trưa hết bốn mươi nghìn đồng"* (giọng tổng
hợp `Microsoft An`, vi-VN):

- Chép lại: *"Hôm nay tôi ăn chưa hết 40.000đ."* — sai **một** chữ (`trưa` → `chưa`), và
  tự đổi *"bốn mươi nghìn đồng"* thành **`40.000đ`**.
- Rút ý định: **`40000đ | ăn trưa`** — **đúng cả hai vế**.

⚠️ Chỗ đáng chú ý nhất: câu thứ hai trả về `ăn trưa` **đúng**, trong khi bản chép lại của
chính nó nói `ăn chưa`. Tức **đừng bắt mô hình chép lại rồi mới phân tích bản chép** — hỏi
thẳng thứ mình cần thì nó dùng chính âm thanh, còn đi qua bản chép là tự chuốc thêm một
nguồn sai. Điều này áp thẳng cho chặng 2.2 (nhập giao dịch bằng câu).

⚠️ **Giọng tổng hợp sạch hơn giọng người** — cùng lối "cận trên" như ảnh dựng. Chưa đo với
giọng thật, chưa đo trong tiếng ồn.

⚠️ **Đọc mã gói 1.8.3 thì thấy HAI đường âm thanh khác nhau, đừng lẫn:** `supportAudio`
bơm byte thẳng vào Gemma (đường vừa đo), còn `FlutterGemma.installStt()` cài một mô hình
**riêng** (`.tflite` + tokenizer, ví dụ Moonshine) qua `SttInstallationBuilder`. Đường thứ
hai **chưa đo**. Chú thích của gói ở `getActiveModel` còn ghi `supportAudio` là *"for
Gemma 3n E4B"* — **câu ấy đã cũ**, phép đo này cho thấy nó chạy trên Gemma 4 E2B.

🛑 **Không phép đo nào ở đây mở một hạng mục.** Đọc hoá đơn và nhập bằng giọng nói đều
**chưa có trong kế hoạch**; mục này chỉ đóng hai câu hỏi để khi nào tới lượt thì không
phải đo lại. Riêng "đọc hoá đơn" còn vướng chiều **ghi** (mục 10.5) và cần ảnh chụp thật.

## 9. Bảng đo P3 (2026-09-22) — ✅ ĐÃ ĐO TRÊN MÁY THẬT, TRONG CHÍNH APP

Khác mục 8: P1 đo bằng **app spike vứt đi**, còn đây là **FlowMoney thật** — bản
`--release`, mô hình tải qua chính màn Cài đặt AI, câu hỏi đi qua chính màn Trợ lý AI,
số liệu là dữ liệu thật của tài khoản 10.

**Máy:** OnePlus 13R `CPH2691`, Snapdragon 8 Gen 3, `arm64-v8a`, Android 16 / SDK 36,
màn 1264×2780 @ 560dpi (**361dp** — hẹp hơn khổ 411dp mà bộ test dùng). Pin 86–88 %,
**đang sạc**. Backend dev nối qua `adb reverse tcp:3000` (cáp USB).

### 9.1 Thời gian

| Lượt | Prompt | Câu ra | Thời gian |
|---|---|---|---|
| **Nạp mô hình** (`getActiveModel`, GPU) | — | — | **8.654 ms** |
| Câu 1 — chip *"Phân tích chi tiêu tháng này"* | 988 ký tự | 85 ký tự | **3.291 ms** |
| Câu 2 — chip *"Dự báo tiết kiệm"* | 976 | 26 | **874 ms** |
| Câu 3 — hỏi tự do | 1.010 | 29 | **971 ms** |
| Câu 4 — **chip 1 lại, KHÔNG CÓ MẠNG** | 988 | 85 | **1.898 ms** |

⚠️ **Câu 1 và câu 4 là CÙNG một prompt cho ra CÙNG một câu 85 ký tự, nhưng lệch
1,4 giây** — 3.291 ms so với 1.898 ms. Chênh lệch ấy **không phải** do mạng (câu 4 là
lượt *không có mạng*): nó là cái giá của lượt chạy **đầu tiên** sau khi nạp. Đọc con số
"3,3 giây" như giá thường trực của một câu là sai; giá thường trực là **~1 đến 2 giây**.
Nạp 8,65 s chỉ trả **một lần mỗi phiên**, và trả **trước** câu đầu.

Đối chiếu P1 (mục 8.1, cùng máy, app spike): E2B/GPU nạp 9.131 ms, ba gói số
3.486 / 2.293 / 1.383 ms. Cùng bậc — **app thật không chậm hơn spike**.

### 9.2 RAM

`TOTAL PSS` của `dumpsys meminfo`, lấy mẫu 3 s/lần quanh lượt sinh câu đầu:

| Mốc | TOTAL PSS |
|---|---|
| Trước khi nạp | 235.728 KB (0,22 GB) |
| Đang nạp | 434.429 KB |
| **Đỉnh** (ngay sau nạp, đang sinh câu) | **889.899 KB ≈ 0,85 GB** |
| Sau 30 s nghỉ | 785.708 KB (0,75 GB) |

P1 đo 0,96 GB cho E2B/GPU — **khớp**, và app thật còn thấp hơn chút.

### 9.3 ⭐ Không có mạng vẫn trả lời — phép đo chính của cả mảng

Đây là **lý do mảng này tồn tại** (mục 10.2): người dùng chốt làm AI trên máy để app
**dùng được khi mất mạng**. Phép đo dựng đúng trạng thái ấy:

- `svc wifi disable` **và** `svc data disable` (máy có 2 SIM — tắt mỗi Wi-Fi **không**
  cắt mạng), cộng `adb reverse --remove-all` để **cắt luôn cầu USB** tới backend.
- Kiểm trước khi hỏi: `curl huggingface.co` → **HTTP 000**, `curl 127.0.0.1:3000` →
  **HTTP 000**. Không còn đường nào ra.
- Hỏi lại chip 1: mô hình trả lời sau **1.898 ms**, câu **y hệt** lượt online, đủ **6**
  thẻ số liệu.
- `logcat` lọc `dio|httpclient|okhttp|SocketException|ConnectException` trong suốt lượt:
  **0 dòng**.

### 9.4 Hai ô kế hoạch đòi mà KHÔNG đo được — và vì sao

1. **`dumpsys gfxinfo … framestats` trả "Total frames rendered: 0".** Không phải lỗi đo:
   Flutter **không vẽ qua View system của Android**, nên bộ đếm khung hình của
   `gfxinfo` không thấy gì cả. Mọi kế hoạch sau dựa vào framestats cho một màn Flutter
   sẽ vấp lại đúng chỗ này. Thay thế bằng một phép đo trực tiếp: chụp **10 ảnh liên
   tiếp** trong lúc mô hình sinh câu và so hash — khung **đổi 7 lần trên 10 ảnh**, tức
   UI vẫn dựng khung mới trong khi inference chạy. Lượt câu 1 (3,3 giây) còn vuốt cuộn
   được suốt thời gian sinh. Kết luận: **inference không chặn UI thread** — đúng điều
   kiện 7, chỉ bằng chứng cứ khác loại.
2. **"Câu thứ hai cùng gói phải 0 ms nhờ cache" — không áp dụng.** Đường hỏi đáp
   (`ai_chat_page._hoiThat`) gọi thẳng `SlmRuntime.sinh`, **không đi qua `SlmCache`**.
   Cache chỉ nằm trong `SlmDienGiai`, mà lối B **cố ý không đăng ký** lớp ấy vào DI —
   nên hôm nay `SlmCache` được đăng ký nhưng **không nằm trên đường chạy nào**; nó vẫn
   được dọn khi đổi tài khoản, và sẽ sống lại nguyên vẹn nếu ai đó bật lối A. Đây là hệ
   quả cố ý của lối B, không phải thiếu sót — nhưng chú thích trong `injection_container`
   từng mô tả sai (nói màn Trợ lý AI *"tự dựng `SlmDienGiai`"*), đã sửa cùng lượt này.

### 9.5 Chất lượng câu — và giới hạn `kiemSo` không bắt được

Câu 1 và 4 (cùng prompt):

> *"Chi tiêu tháng này là 2.141.000 đ trên tổng thu 15.135.000 đ. Tỉ lệ phân bổ là 85,4%."*

Ba con số **đều đúng** và đều có trong gói số, nên `kiemSoNhieuGoi` cho qua. Nhưng
**nhãn thì sai**: 85,4 % là tỉ lệ *để dành*, không phải *"tỉ lệ phân bổ"* — gói số gọi
nó là `Để dành 85,4%`. ⚠️ Đây là giới hạn **thật** của thiết kế, đáng nhớ: `kiemSo` canh
**con số**, không canh **cái tên người ta gán cho con số**. Một câu có thể qua hết mọi
chốt mà vẫn gọi sai tên đại lượng. Thẻ số liệu bên dưới chính là thứ chữa cháy cho việc
này — người đọc thấy `Để dành 85,4%` ngay cạnh câu — nhưng nó không thay được một bộ
kiểm nhãn, thứ **chưa có** và chưa lên kế hoạch.

Câu 2 (*"Dự báo tiết kiệm là 85,4%."*) và câu 3 đều ngắn và đúng số.

### 9.6 Tải mô hình — ba đường, chênh nhau 274 lần

| Đường | Tốc độ | 2,41 GB mất |
|---|---|---|
| Máy thật → HuggingFace (Wi-Fi 2.4 GHz) | **97 KB/s** | ~7 giờ (và **đứt giữa chừng**) |
| Máy tính → HuggingFace | 7,6 MB/s | 5 phút 30 |
| Máy thật → máy tính qua **cáp USB** (`adb reverse`) | **25,4 MB/s** | **97 giây** |

Lượt đo này tải bằng đường thứ ba: tệp tải sẵn trên máy tính, phục vụ qua một HTTP
server cục bộ, `kUrlMoHinh` trỏ tạm vào `127.0.0.1:8099`. Đường tải **trong app** không
đổi một dòng nào — chỉ đổi nguồn. Tệp về máy đủ **2.588.147.712 byte**, đúng
`kCoTepByte` từng byte, và app nạp được ngay.

⚠️ **Lượt tải thẳng đầu tiên đã hỏng thật** với `HttpException: Connection closed while
receiving data` sau chừng 650 MB, và mất trắng chừng ấy vì **đường tải không resume**.
Việc này mở hạng mục *"tải nền + resume"* — người dùng chốt làm **sau** khi đóng P3, và
`flutter_gemma` đã kéo sẵn `background_downloader` vào dự án (phụ thuộc transitive) nên
lối đi có sẵn.

### 9.7 Bốn lỗi THẬT mà lượt nghiệm thu này bắt được

Cả bốn đều **im lặng** với `flutter test`, `flutter analyze` và `flutter build apk`; cả
bốn chỉ lộ khi **chạy một bản `--release` trên máy thật**. Ba cái đầu đã sửa trong cùng
lượt, cái thứ tư mở một hạng mục.

1. ⭐ **APK release KHÔNG có quyền `INTERNET`.** `android/app/src/debug/AndroidManifest.xml`
   khai quyền ấy (Flutter tạo sẵn cho hot reload) còn `main/` thì **không** — nên mọi
   bản debug, tức **mọi lượt nghiệm thu máy ảo của dự án từ trước tới nay**, gọi backend
   bình thường, và thiếu sót ở manifest chính chưa từng lộ ra. Bản release đầu tiên của
   dự án không đăng nhập được, chỉ hiện *"Không có kết nối mạng"* — đúng câu app dùng
   cho lúc rớt sóng, nên nó còn dẫn người đọc đi kiểm Wi-Fi. Bằng chứng phân biệt:
   `adb shell curl` tới cùng URL **từ chính máy ấy** trả về HTTP 200. Nay có ca test đọc
   thẳng manifest (`test/core/nhan_dien_app_test.dart`).
2. **Thông báo lỗi tải in nguyên URL ký hàng nghìn ký tự.** `DioException.toString()` nhét
   trọn đường ký của CDN (chữ ký + policy base64 + hạn dùng) vào màn hình; câu duy nhất
   có ích nằm lọt ở dòng thứ hai của một bức tường base64. Nay có hàm thuần `cauLoiTai`
   — *"Mất kết nối giữa chừng…"*, *"Máy không đủ dung lượng…"* — còn chi tiết đi vào
   `debugPrint`. 4 ca test, một ca dùng **chuỗi lỗi thật chép từ máy**.
3. ⭐ **"Mô hình trên máy không chạy được" khi mô hình hoàn toàn bình thường.** Mở app
   trong điều kiện backend không tới được rồi hỏi ngay → câu ấy. Nguyên nhân thật:
   `currentAccountIdOrNull` trả `null` vì `AuthBloc` chưa vào `AuthSuccess` —
   `verifySession()` là lời gọi **mạng** và phải đợi hết timeout 30 s trước khi giữ lại
   phiên cũ. Đo: chờ 45 giây rồi hỏi **cùng câu ấy** → mô hình nạp trong **4.103 ms** và
   trả lời bình thường. ⚠️ Trớ trêu nhất là nó rơi đúng vào ca **mất mạng** — ca mà AI
   trên máy sinh ra để phục vụ (mục 10.2). Nay nhánh ấy có câu riêng
   `kChuaSanSangPhien` (*"Đang mở lại phiên đăng nhập trên máy…"*), cộng `debugPrint`
   cho **cả hai** nhánh: trước lượt này `catch` của `_hoi` nuốt lỗi **không log gì**,
   nên hai nguyên nhân khác hẳn nhau nhìn y hệt nhau cả trên màn hình lẫn trong logcat.
4. **Tải 2,41 GB không resume và không chạy nền** — xem 9.6. Hạng mục riêng, người dùng
   chốt làm sau P3.

⚠️ **Bài học chung, đáng nhớ hơn cả bốn lỗi:** ba trong bốn cái trên không phải lỗi của
mã mới viết ở P3 — chúng đã nằm sẵn trong dự án, và cái đầu tiên có thể đã nằm đó từ
ngày `flutter create`. Thứ bắt được chúng không phải một ca test nào, mà là **lần đầu
tiên chạy một bản release trên một máy thật**. Cả hai vế đều cần: bản debug che mất lỗi
số 1, còn máy ảo che mất lỗi số 3 (ở đó backend `10.0.2.2` luôn tới được).

### 9.8 Việc số 1 của lộ trình — chất lượng câu trả lời + mã cho cổng A (2026-09-22 tối)

Lộ trình ở đầu `docs/superpowers/plans/2026-09-21-ai-viec-tiep-theo.md`; người dùng duyệt
thiết kế trong chat (bounded, không spec) và chốt **giữ thứ tự** sau khi hỏi *"vậy là chỉ hỏi
được thứ có sẵn thôi à"* — **đúng**: bậc này mô hình chỉ thấy gói số, và thứ gỡ giới hạn ấy
là function calling (việc số 3), không phải việc này. Việc này làm cho cái *"không có dữ liệu"*
thật sự xảy ra thay vì bịa nhãn.

**Sáu thay đổi, không đổi schema, không đổi payload, không thêm gói:**

| # | Thay đổi | Tệp |
|---|---|---|
| 1 | **Streaming chặn theo câu** — `SlmRuntime.sinhDan` (token) + `huy` (`stopGeneration()`); `gacTheoCau` gom token, đủ câu thì kiểm rồi phát `CauQua`, trượt thì huỷ và phát `BiChan`, không còn sự kiện nào sau. Màn dựng bong bóng lớn dần theo câu; bị chặn sau ≥ 1 câu → **giữ** các câu ấy; chưa câu nào → câu lùi | `data/slm_runtime.dart` · `domain/gac_cau.dart` · `ai_chat_page.dart` |
| 2 | **`kiemNhan`** — lớp chắn thứ ba (số thật gán tên sai); từ khoá suy từ nhãn lúc chạy, so theo âm tiết | `domain/kiem_nhan.dart`; `kiem_so.dart` mở `soLieuKhop` |
| 3 | **`kiemCauTraLoi`** — định nghĩa duy nhất của "một câu được hiện": số + nhãn + giọng theo `mucTongHop` (có gói cảnh báo → cả câu không được trấn an). Đây là chỗ **nối `kiemGiong` vào hỏi đáp** — trước đó chưa nối | `domain/kiem_cau_tra_loi.dart` |
| 4 | `NguonGoiSo` gom **sáu** gói (thêm hoá đơn, ví); ví đọc **một** lần cho cả gói ví lẫn tổng của trang chủ | `data/nguon_goi_so.dart` · DI |
| 5 | `promptHoiDap` có **few-shot riêng** (3 ví dụ, một là "không có số liệu → không chữ số"), chỉ dẫn "dùng đúng nhãn", số liệu có **tiêu đề theo màn**, gói thiếu dữ liệu in câu mẫu của nó | `domain/slm_prompt.dart` |
| 6 | Bốn chip: *Chi tiêu tháng này · Tình hình ngân sách · Tiến độ mục tiêu · Hoá đơn sắp tới* — mỗi chip hỏi thứ một gói có | `ai_chat_page.dart` |

**Test:** 44 ca mới ở 6 tệp, 4 tệp mới (`kiem_nhan_test` 12 · `kiem_cau_tra_loi_test` 9 ·
`gac_cau_test` 9 · `data/nguon_goi_so_test` 3 — fake `noSuchMethod`, chỉ dựng hàm được gọi);
`slm_prompt_test` +7, `ai_chat_page_test` +4 (khe tiêm `onHoi` nay nhận `Stream<SuKienGac>`).
Toàn bộ **3392/3392** trước khi đo máy thật, **3399/3399** sau (mục 9.9: +2 `gac_cau_test`, +5 tệp mới `the_cua_cau_test`), analyze 26. Hai bẫy lộ ra trong lượt viết mã: **4.16** (ca few-shot cắt sai
mốc, xanh nhờ "40" ⊂ "400.000") và **4.17** (`contains` là chuỗi con; ca thử đầu *"Chính
xác…"* xanh ngay vì "chính" có dấu sắc — ca xanh ngay là ca không canh gì).

`SlmRuntime.sinh` (không stream) **giữ nguyên** cho `SlmDienGiai` — lối B vẫn không đăng ký lớp
ấy. Đo máy thật ở mục **9.9** ngay dưới.

### 9.9 Đo cổng A trên máy thật (2026-09-22 tối) — ✅ CỔNG A QUA

OnePlus 13R, bản `--release` cài đè (giữ mô hình đã tải và phiên tài khoản 10), backend dev qua
`adb reverse tcp:3000` với `baseUrl` đổi tạm `127.0.0.1` (**đã hoàn tác, không commit**). Câu hỏi
tự do gõ bằng `adb shell input text` nên **không dấu** — mô hình vẫn hiểu; chip thì có dấu.
Ảnh chụp liên tiếp bằng `screencap` **trên máy** (~0,4 s/khung) rồi `pull` thư mục riêng.

| Lượt | Câu hỏi | Kết quả | Thời gian |
|---|---|---|---|
| Nạp | — | — | 3.729–4.523 ms (bốn lần; Task 9 đo 8.654 ms) |
| Chip 1 *"Chi tiêu tháng này"* | 61 ký tự, **một** câu | qua cả ba lớp; thẻ đúng hai số câu nhắc | 1.596–2.869 ms; token đầu 549 ms (ấm) / 1.766 ms (sau nạp) |
| Chip 2 *"Tình hình ngân sách"* | 56 ký tự | qua | 1.565 ms; token đầu 942 ms |
| **Điểm 4** — *"Du bao tiet kiem cua toi la bao nhieu?"* | *"Tổng thu là 15.135.000 đ, tổng chi là 2.141.000 đ, còn lại là 12.994.000 đ."* | **không bịa**, ba nhãn đúng; không nói "không có dữ liệu" *(⚠️ câu ấy đúng cho **lượt này**, không phải luôn luôn — chặng 3 ngày 2026-09-22 đo được **hai** câu mô hình nói thẳng là không có dữ liệu; xem **9.11**)* | 3.135 ms; token đầu 1.682 ms |
| **Điểm 5** — *"Toi co dang on khong? Ngan sach the nao?"* (Giáo dục 90,0 % → gói cảnh báo) | *"Thu là 15.135.000 đ, Chi là 2.141.000 đ, còn lại là 12.994.000 đ. Ngân sách căng nhất là 90,0%."* | **không trấn an**, không phải chặn | 3.371 ms |
| **Điểm 2** — *"Tom tat tinh hinh tai chinh thang nay…"* | **429 ký tự, 4 câu** (chi tiêu · ngân sách · mục tiêu · hoá đơn), mọi số đúng nhãn | bong bóng **1 → 3 → 4 câu** ở ≈ 3,8 / 5,9 / 7,6 s sau khi bắt đầu sinh, chip xám suốt; xong ở 8.672 ms | token đầu 1.674 ms |

**Hai lỗi thật lượt này bắt được, cả hai 3392 ca test mù:**

1. ⭐ **Câu đầu tiên trên máy bị chặn**: *"Chi tiêu tháng này là 2."* — token cắt con số ngay sau
   dấu chấm ngăn nghìn, bộ đệm dừng ở `2.` một nhịp, regex `[.!?](?=\s|$)` coi đó là kết câu.
   Bẫy **4.18**; sửa + hai ca; đo lại: qua.
2. **Thẻ số liệu in số đếm không ai nhắc** (*Số cam kết 15 · Chưa trả 3 · Quá hạn 1 · Số ví 4 · Ví
   đang âm 1*) vì so chuỗi con — lỗi có từ Task 8, chỉ lộ khi có gói mang số đếm ngắn. Bẫy
   **4.19**; `theCuaCau` mới + 5 ca; đo lại: đúng hai thẻ.

⚠️ Điều đáng ghi về **điểm 4**: `kiemNhan` đóng đúng đường đã hỏng (gắn nhãn lạ cho số thật),
nhưng mô hình E2B **không** chọn nói "không có dữ liệu" dù few-shot có ví dụ ấy — nó trả lời bằng
những số liên quan thật. Đó là hành vi chấp nhận được (không sai, không bịa) chứ không phải hành
vi lý tưởng; muốn hơn thì phải function calling (việc số 3), không phải thêm lớp chắn.

⚠️ Bốn bẫy thao tác máy thật của lượt này ghi ở `CLAUDE.md` mục *"Chạy trên MÁY THẬT"* (màn quét
`InstallGuideActivity` của OnePlus chặn `adb install` im lặng; `adb pull /sdcard/Download/` kéo cả
ảnh riêng của người dùng; `input text` không gõ được dấu; Enter không gửi được ô chat).

---

### 9.10 Tải nền + resume — nghiệm thu máy thật (2026-09-22 tối, Realme RMX2205) — ✅ XONG

Việc số 2 của lộ trình; kế hoạch `docs/superpowers/plans/2026-09-22-tai-mo-hinh-nen-resume.md`
(7 task), spec cùng ngày. ⚠️ Máy đo **khác** mọi lượt trước: **Realme RMX2205** — Dimensity 1100
(`mt6893`, Mali-G77), arm64, Android 13 / SDK 33, 1080×2400 @ 480 dpi (**360 dp**), 7,7 GB RAM,
Realme UI. Người dùng đổi máy giữa chừng; đó hoá ra là điều may, vì bốn trong sáu lỗi lượt này
bắt được **chỉ có trên máy này** (OEM, SoC).

Tệp phục vụ từ server cục bộ có `Range` qua `adb reverse tcp:8099` (25 MB/s → **~101 s** cho
2,41 GB); `kUrlMoHinh`, `baseUrl` và `usesCleartextTraffic` đổi **tạm**, đã hoàn tác.

| # | Phép đo | Kết quả |
|---|---|---|
| 1 | Bắt đầu tải → vuốt app khỏi Recents | ❌ **Realme UI force-stop** (`ActivityManager: Killing … remove task` → `Force stopping`), giết cả service nền lẫn WorkManager. Giới hạn OEM, không phải lỗi mã — Android gốc/OnePlus không làm thế. Lượt tải **không** chết mất: xem phép 2 |
| 2 | Mở lại app → Cài đặt AI | ✅ WorkManager chạy lại lượt **ngay khi app mở** (không cần vào màn), màn hiện đúng "Đang tải… 68 %" nhờ `khoiPhuc()`. ⚠️ Nhưng chạy lại **từ 0** (GET không `Range`) — sau force-stop gói không giữ tệp dở |
| 3 | Bấm **Pause trên thông báo** | ✅ Màn đổi sang "Đã tạm dừng · 72 %", server đóng kết nối, logcat `Task paused`. Thông báo có Cancel/Pause, thanh tiến độ — và hiện **dù `POST_NOTIFICATION: ignore`** (thông báo của foreground service không cần quyền ấy) |
| 4 | Tắt Wi-Fi giữa lượt, bật lại | ✅ tự chạy tiếp khi Wi-Fi về (bản đầu màn nói sai "Chưa tải" — bẫy 4.22, đã sửa và đo lại: "Đang chờ Wi-Fi"). ⚠️ Nhưng **tải lại từ 0**: WorkManager dừng worker vì ràng buộc, gói báo `canceled` rồi *"Partially downloaded file not available, resume not possible"* |
| 5 | Ngắt rồi tiếp tục | ✅ Tiếp tục sau Tạm dừng gửi **`Range: bytes=1895276544-`** (73 %), phần đã tải giữ nguyên; tệp cuối đúng `kCoTepByte` |
| 6 | Tải xong → nạp → hỏi | ✅ `daCo()` đúng cỡ; ❌ **nạp sập native** trên Mali (bẫy 4.24) → thêm **canary GPU** → lần mở sau nạp **CPU 27,2 s**, câu đầu 9,9 s (token đầu 7,7 s), câu ấm 7,3 s (token đầu 4,6 s), RAM 1,61 GB PSS; câu đúng số đúng nhãn |

**Sáu lỗi thật lượt này bắt được, 3411 ca test đều mù; bốn cái đầu chỉ máy thật thấy:**

1. **Cleartext bị chặn ở tầng native** — worker của `background_downloader` là mã Android, chịu
   chính sách `usesCleartextTraffic`; Dio của Dart thì không, nên backend dev `http://127.0.0.1`
   chạy được suốt còn lượt tải thì *"Cleartext HTTP traffic to 127.0.0.1 not permitted"* và thử
   lại ba lần. Chỉ là chuyện **môi trường đo** (URL thật là HTTPS) — bẫy 4.20.
2. **Tiến độ âm là mã trạng thái** (−4 = chờ thử lại) → màn *"Đang tải… −400 %"* — bẫy 4.21.
3. **`canceled` của WorkManager không phải huỷ** — mất Wi-Fi thì màn nói "Chưa tải" cho một
   lượt vẫn xếp hàng — bẫy 4.22.
4. **Nạp GPU sập native trên Mali** — bẫy 4.24; canary là cách chữa.
5. `waitingToRetry` dịch thành "chờ Wi-Fi" — chỉ sai nguyên nhân (máy đang ở Wi-Fi) — bẫy 4.21.
6. Câu *"Phần đã tải được giữ lại"* ở khối chờ Wi-Fi là lời hứa **sai** trên đúng đường ấy
   (xem phép 4) — bỏ; chỉ khối Tạm dừng được nói thế.

⚠️ **Hai giới hạn nói ra, không vá:** OEM force-stop khi vuốt Recents (phép 1) và tải lại từ 0
sau khi WorkManager dừng vì ràng buộc (phép 4) đều là hành vi của nền tảng/gói; lát này làm việc
tải *chịu được gián đoạn* (không mất lượt, không phải ngồi nhìn) chứ chưa làm nó *không mất byte*
trong mọi trường hợp — chỉ Tạm dừng/Tiếp tục mới giữ được byte. Và `_doTrangThai()` của màn Cài
đặt AI từng ghi đè trạng thái `loi` khôi phục từ lần chạy trước bằng "Chưa tải" (nó chỉ gác
`dangTai`/`tamDung`/`choMang`) — ✅ **sửa 2026-09-23**, bẫy **4.32**; mới kiểm bằng bộ giả, chưa
đo trên máy thật. *(Câu cũ ở đây còn ghi hậu quả "bấm Tải là xếp lượt mới cùng `taskId`" — không
đo; chú thích trong chính `batDau` ghi gói **từ chối** `enqueue` khi cùng `taskId` còn sống, nên
nếu gói coi lượt hỏng là còn sống thì nút Tải ấy **không làm gì**. Chưa ai đo đường này.)*

---

### 9.11 Chặng 3 — đo bậc 1 hỏng ở đâu (2026-09-22 tối muộn, Realme RMX2205) — ✅ CỔNG B QUA

**Bảng 20 hàng đầy đủ nằm ở mục 5.6 `docs/AI_AGENT_ARCHITECTURE.md`** — chỗ ấy là nơi lộ trình
chỉ định, và nó cũng là chỗ chặng 4 sẽ đọc để lấy đơn đặt hàng. Ở đây chỉ ghi phần thuộc về
*tính năng*, tức những gì lượt đo nói về chính mô-đun này.

**Kết quả: ✅ 5 · rơi mẫu 3 · SAI 0 · lệch câu hỏi 12** (nạp 9.196 ms trên CPU; sinh 4,8–8,9 s
mỗi câu; tài khoản thật, backend không chạy).

**Ba lớp chắn làm đúng việc.** `SAI = 0` trên 20 câu là con số đáng giữ: không một số sai nào
lọt ra. Hai ca thấy rõ nhất:

- Câu 1 — mô hình sinh *"Ngân sách của bạn đang ở mức 90,0%"*; số **thật**, nhưng nhãn gói là
  *Tỉ lệ* nên `kiemNhan` **chặn**. Hậu quả với người dùng: câu ngân sách cơ bản nhất rơi về mẫu
  câu. Chốt đúng, trải nghiệm dở — và đó là đánh đổi đã chọn có chủ ý.
- Câu 7 — mô hình sinh *"Hôm nay bạn đã chi 556 đ"*, mà **556** là *mức nên chi mỗi ngày* của
  ngân sách Giáo dục. Số thật, nhãn sai hẳn. `kiemNhan` chặn. ⭐ Đây là **bằng chứng sống** cho
  lý do `kiemNhan` ra đời ở việc số 1: không có nó, câu này đã hiện ra và người dùng sẽ tin.

⚠️ **Nhưng mô hình KHÔNG phải lúc nào cũng im khi thiếu dữ liệu** — nó **lệch**. Câu 13 hỏi
*"hoá đơn nào quá hạn"* và nhận *"Ngân sách căng nhất là 90,0%"*: sang **hẳn chủ đề khác**, mọi
số đều thật nên mọi chốt đều cho qua. Ba lớp chắn bảo vệ *tính đúng của con số*, **không** bảo vệ
*tính liên quan của câu trả lời* — đó là ranh giới thật của bậc 1, và bảng 5.6 đo đúng nó.

✅ **Ghi nhận ngược lại một câu của lượt đo cổng A.** Mục 9.9 kết luận *mô hình không nói "không
có dữ liệu"*. Lượt này **hai câu nói thẳng** — câu 4 (*"Không có dữ liệu để trả lời câu hỏi của
bạn"*) và câu 11 (*"…không có thông tin cụ thể trong dữ liệu"*). Vậy few-shot **có** tác dụng;
câu cũ nên đọc là *"không đáng tin cậy"* chứ không phải *"không bao giờ"*.

**Hai lỗi của mô-đun này lượt đo bắt được:** thẻ số liệu gán nhãn của gói khác khi hai nhãn
**trùng giá trị** (bẫy **4.27** — ✅ **đã sửa ở chặng 4a**, `20bbc05`) và **tổng thu lệch 10.000 đ**
giữa Trang chủ (15.145.000) và gói số (15.135.000) — ✅ cái sau **đóng 2026-09-23** (bước 1a):
người dùng chốt con số của Phân tích, `thuChiThangCua` nay đi qua `tongThuChi` (xem mục **7.1**,
chỗ lệch 1). *(Câu ở đây từng ghi "chưa sửa" cho cả hai, rồi "cái sau vẫn mở" — mỗi câu đúng tới
lúc lỗi tương ứng được sửa.)*

---

### 9.12 Chặng 4a — tên đối tượng trong gói số (2026-09-23) — 🛑 CỔNG CHƯA ĐẠT

Spec `superpowers/specs/2026-09-22-chang-4a-ten-doi-tuong-goi-so-design.md`; bảng đo lại ở mục
**5.6** `AI_AGENT_ARCHITECTURE.md`. Chín task, 3468/3468 pass, analyze 26 issue, schema **không
đổi** (v24), payload **không đổi**.

**Làm gì:** `SoLieu` thêm một trường `ten` (`String?`) — tên đối tượng, tách khỏi `nhan` vốn là
tên chỉ số; bốn gói (ngân sách · ví · hoá đơn · phân tích) nhồi **danh sách** thay vì một mục,
trần `kToiDaMucMoiGoi = 4`; `kiemNhan` và `theCuaCau` đọc `ten`; prompt nêu tên.

**Kết quả: nhóm A 1/4** — câu *"ngân sách nào sắp hết"* nay đáp **"…là Giáo dục với tỉ lệ 90,0%"**
thay vì một con số trần. Ba câu còn lại vẫn hỏng.

⭐ **Bài học trung tâm — danh sách có tên là CẦN nhưng CHƯA ĐỦ.** Log gói số thật chứng minh cả
bốn gói mang tên đúng thiết kế. Nhưng gói nói `Quá hạn: 1` ở một dòng và `Kiem · Phải trả:
45.000 đ` ở dòng khác — **không chỗ nào nói Kiem LÀ cái quá hạn**. Mô hình phải nối hai mục rời
bằng suy luận, và E2B không làm được. 🛑 Vậy ba câu còn hỏng **không** chữa được bằng cách làm gói
giàu thêm; thứ cần là **tool trả một hàng đầy đủ** — việc của lát 4b.

**Bốn lỗi thật lượt đo bắt được, 3462 ca test đều mù:**

1. ⭐ **Prompt vượt trần token là lỗi CỨNG, không phải chậm** — bẫy **4.29**. Kế hoạch chỉ lường
   "prompt phình thì token đầu tăng"; thực tế gói ném `INVALID_ARGUMENT: Input token ids are too
   long: 1084 >= 1024` và câu trả lời **rỗng**.
2. ⭐ **Mẫu câu ngân sách in tỉ lệ của ngân sách KHÁC** — bẫy **4.30**, sai **im lặng**, và ca
   `contains('Giáo dục')` viết cùng lát ấy **xanh suốt**.
3. ⭐ **Nhãn mới làm một câu SAI lọt qua `kiemNhan`** — bẫy **4.31**; bản trước chặng 4a chặn được
   câu ấy. Luật siết ra từ đây: mục **có tên** đòi câu nêu **tên**.
4. `debugPrint` bị **tiết lưu** nên sáu dòng log gói số bị nuốt sạch — phải dùng `print` và mỗi
   mục một dòng ngắn. Vế thứ ba của bẫy **8.6**, và là thứ đã chặn phép chẩn đoán mất một lượt
   build.

**Đo được kèm:** prompt hỏi đáp **1.704 → ~2.280** ký tự; token đầu trên CPU Realme **4,6 s →
8,4–11,1 s**. Trần `maxTokens` nới **1024 → 2048** (nó là hằng của client, không phải giới hạn
của Gemma, và là trần cho **tổng** input + output).

### 9.13 Chặng 4b — spike tool-calling (2026-09-23) — 🛑 gói cũ SẬP NATIVE trên cả hai máy → ✅ NÂNG GÓI, CỔNG TASK 4 ĐẠT

Task 4 của kế hoạch `superpowers/plans/2026-09-23-chang-4b-tool-calling-vong-lap.md`: APK release
kèm móc tạm `/spike` (**không commit**) mở một phiên có **một** tool (`danh_sach_vi`, JSON giả)
qua `SlmRuntime.moPhien` rồi chạy tối đa ba lượt. Tài khoản 10, cùng một APK trên hai máy:
**Realme RMX2205** (Dimensity 1100, Android 13, CPU — canary đã đánh dấu GPU máy này hỏng từ 9.10)
và **OnePlus 13R** (Snapdragon 8 Gen 3, Android 16, GPU — máy demo).

| Máy | Câu (gõ) | Nạp · mở phiên | Lượt 1 | Kết quả |
|---|---|---|---|---|
| Realme | `/spike Vi nao dang am?` | — (logcat không giữ dòng `print` nào, xem dưới) | sập 7 s sau khi gửi | 🛑 SIGSEGV |
| Realme | `/spike Toi co tat ca bao nhieu vi?` | 841 ms · **2.669 ms** | sập 3,2 s sau khi mở phiên, **trước token đầu** | 🛑 SIGSEGV |
| Realme | `/spike Xin chao` (đối chứng — câu không cần tool) | 798 ms · 2.668 ms | sập 2,7 s sau khi mở phiên | 🛑 SIGSEGV |
| Realme | chip *"Chi tiêu tháng này"* — đường **bậc 1**, không tool, **cùng APK** | 799 ms | token đầu 10.711 ms, xong 13.454 ms | ✅ câu đúng, ba thẻ đúng |
| OnePlus | `/spike Vi nao dang am?` | 9.253 ms · 2.081 ms | sập 1,0 s sau khi mở phiên | 🛑 SIGBUS |
| OnePlus | `/spike Xin chao` (đối chứng) | 3.715 ms · 1.583 ms | sập 1,0 s sau khi mở phiên | 🛑 SIGBUS |

**Backtrace trùng từng offset trên mỗi máy, và cùng một đường giữa hai máy**: `#01
litert::lm::CompositeLogitMask::Apply(…) const+412` ← `#02–03 ConstrainedDecoder::ProcessLogits(…)`
← `#04 LlmLiteRtCompiledModelExecutorBase::DecodeLogits` ← `Tasks::Decode` ← `ThreadPool::RunWorker`,
trên luồng `execution_thread` của LiteRT-LM. Khung `#00` là nơi nó nhảy tới qua một **con trỏ hàm
rác**: trên OnePlus unwinder gọi được tên — **`libGemmaModelConstraintProvider.so`+0x2e7da**, địa
chỉ lẻ nên `SIGBUS (BUS_ADRALN)`; trên Realme `base.apk+0x39dd0`, địa chỉ chẵn nhưng không được
thực thi nên `SIGSEGV (SEGV_ACCERR)`. Logits là `float` trên CPU, `half` trên GPU — khác kiểu, cùng
chỗ sập.

⭐ **Gốc nằm ở gói, không ở mã Dart của lát, và không ở một máy riêng:** `flutter_gemma_litertlm`
1.7.0 **gắn cứng** `litert_lm_conversation_config_set_enable_constrained_decoding(…, true)` hễ phiên
có tool (`lib/src/ffi/litert_lm_client.dart:1080–1086`) — không tham số nào tắt được. Hai SoC, hai
bản Android, hai backend đều sập ở cùng một chỗ, nên với phiên bản gói này **mọi** phiên có tool
đều sập, bất kể câu hỏi (câu không cần tool vẫn sập). `try/catch` không bắt được gì; app văng về
màn chính. `flutter pub outdated` cùng ngày: có `flutter_gemma` **1.9.0** và
`flutter_gemma_litertlm` **1.8.0** — và bản mới **đã sửa** lỗi này, xem tiểu mục ngay dưới.

**Đo được kèm, còn giá trị khi lỗi sập được sửa:**
- Mở phiên có tool mất **2.669 ms** (Realme) / **1.583–2.081 ms** (OnePlus), trong đó **935 ms** /
  **446–612 ms** là dựng FST ràng buộc (`vocab_utils.cc: Converted 262158 tokens into 278614 state
  FST`) — dựng lại **mỗi phiên**, tức mỗi câu hỏi. Ngân sách độ trễ hai lượt của spec (mục 1.2)
  chưa tính khoản này.
- Một tool: `tools_json` **323** ký tự; chỉ dẫn hệ thống 469 ký tự. Bốn tool chưa đo.
- Nạp mô hình: Realme CPU có cache XNNPack **~0,8 s** (lần đầu trên máy ấy 27 s, mục 9.10);
  OnePlus GPU **9,3 s** lần đầu sau khi cài APK, **3,7 s** lần sau.

⚠️ **Bẫy của phép đo:** lượt 1, `logcat -d` chạy sau cú sập **không** có dòng `print` nào của móc
tạm; lượt 2 và 3 ghi logcat **trực tiếp ra tệp** trong lúc chạy thì có đủ. Chưa rõ vì sao. Với
một phép đo có thể sập native, ghi logcat trực tiếp chứ đừng dựa vào một lần `logcat -d`.

Với gói cũ, **cổng Task 4 trượt** — không thấy `GoiCongCu` nào; thi công dừng, người dùng chọn đo
thêm trên OnePlus rồi chọn **nâng gói lên bản mới nhất** (changelog `flutter_gemma_litertlm` 1.7.1:
*"Native runtime `native-v0.17.0-a`: tool calls no longer crash the app"*).

#### Sau khi nâng lên `flutter_gemma` 1.9.0 + `flutter_gemma_litertlm` 1.8.0 — ✅ CỔNG TASK 4 ĐẠT

Commit `af2aa81` (người dùng duyệt đích danh việc đổi `pubspec`). Cùng móc spike, cùng câu:

| Máy | Câu | Nạp · mở phiên | Lượt 1 | Lượt 2 (câu trả lời) |
|---|---|---|---|---|
| OnePlus | `Vi nao dang am?` | 4.340 · 2.062 ms | **gọi `danh_sach_vi {}`**, 1.912 ms, **0 ký tự chữ** | *"Ví test đang âm với số dư là -100.000 đ."* — token đầu 347 ms, 1.136 ms |
| OnePlus | `Toi co tat ca bao nhieu vi?` | 3.764 · 2.131 ms | gọi `danh_sach_vi {}`, 1.878 ms, 0 ký tự | *"Bạn có 4 ví. Tổng tài sản là 13.004.000 đ."* — 1.391 ms |
| OnePlus | `Xin chao` (đối chứng) | 4.116 · 2.180 ms | **không gọi tool** — *"Chào bạn, tôi là trợ lý tài chính của FlowMoney. Tôi có thể giúp gì cho bạn?"* | — |
| OnePlus | chip *"Chi tiêu tháng này"* — bậc 1 | 3.775 ms | token đầu 1.720 ms, xong 3.155 ms, câu + ba thẻ đúng | — |
| Realme | `Vi nao dang am?` | 1.103 · 2.784 ms | gọi `danh_sach_vi {}`, 4.850 ms, 0 ký tự | *"Ví test đang âm với số dư là -100.000 đ."* — token đầu 2.733 ms, 3.683 ms |
| Realme | `Toi co tat ca bao nhieu vi?` | 820 · 2.788 ms | gọi `danh_sach_vi {}`, 3.047 ms, 0 ký tự | *"Bạn có 4 ví. Các ví có số dư như sau: test: -100.000 đ, mua nhà: 0 đ, Tiết kiệm: 3.201.000 đ, Tiền mặt: 9.903.000 đ."* — 5.378 ms |
| Realme | `Xin chao` (đối chứng) | 541 · 3.152 ms | không gọi tool — lời chào, không chữ số | — |
| Realme | chip *"Chi tiêu tháng này"* — bậc 1 | 457 ms | token đầu 10.387 ms, xong 12.919 ms (trước khi nâng: 10.711 / 13.454) | — |

**6/6 không sập.** Mọi tên và số trong câu trả lời đều có trong JSON tool trả về. Tính từ lúc gửi,
một câu cần tool mất khoảng **9 s** trên OnePlus (phần lớn là nạp mô hình lần đầu sau khi mở app) và
**~12 s** trên Realme CPU — **không chậm hơn** bậc 1 trên CPU (~13 s), vì prompt của từng lượt ngắn
hơn nhiều so với prompt sáu gói của bậc 1. Ước lượng *"Realme CPU ~20–25 s"* ở spec 1.2 là quá bi
quan. Dựng FST ràng buộc vẫn tốn **0,66 s** (OnePlus) / **1,0–1,2 s** (Realme) ở **mỗi** phiên.

**Các điều spec và kế hoạch đoán, đối chiếu:** (1) bốn tên `Tool` · `ToolChoice` ·
`FunctionCallResponse` · `ParallelFunctionCallResponse` có trong barrel `flutter_gemma.dart`, và
`ModelResponse` là `sealed` đúng bốn lớp con — ✅ `flutter analyze` xác nhận (cả 1.8.3 lẫn 1.9.0);
(2) *"lượt gọi tool không phát chữ"* — ✅ **0 ký tự** ở cả 4/4 lượt gọi; (3) *"`ToolChoice.auto`
đủ để E2B gọi tool"* — ✅ 4/4 câu cần tool đều gọi, và 2/2 câu chào **không** gọi; (4) *"bốn tool
dưới ~600 token"* — chưa đo (mới một tool, 323 ký tự). ⚠️ Spec 3.7 bảo đo `chat.currentTokens` để
canh bẫy 4.29 — **không dùng được**: thuộc tính ấy chỉ cộng token của **câu trả lời**
(`flutter_gemma` `lib/core/chat.dart:706–708`; ảnh +257 ở `:193`), không tính câu hỏi, chỉ dẫn hệ
thống hay `tools_json`. Phép đo quyết định vẫn là lỗi native `INVALID_ARGUMENT … too long`.

⚠️ Câu chào không gọi tool thì mô hình **trả lời thẳng** — trong vòng lặp thật đó là **L1**: câu bị
vứt, màn rơi về bậc 1. Đúng thiết kế, và là lý do L1 phải có: câu thẳng ở bước này không có dữ liệu
nào trước mắt mô hình.

Móc tạm đã gỡ. ✅ **Task 5a** (hàm dựng hàng hoá đơn) xong cùng ngày (`21389ea`). Bẫy **4.33**.
Task 5b–9 và phép đo cổng C: mục **9.14**.

### 9.14 Chặng 4b — cổng C (2026-09-23 chiều) — ✅ ĐẠT TRÊN CẢ HAI MÁY

Task 5b–8 thi công cùng ngày: `hangVi` · `hangNganSach` · `hangChiTieu` (`4cb0b3b`), bốn adapter +
`BoCongCu` + DI (`af11ce0`), vòng lặp `hoiBangCongCu` (`af31c7f`), nối màn Trợ lý AI (`863c4cd`,
nghiệm thu máy ảo 411dp: 0 pixel `#FFFF00` trên 10 khung, nhánh L4 *"arm64-v8a"* đúng trên x86_64).
Rồi Task 9: **APK release**, tài khoản 10, tám câu của kế hoạch gõ **không dấu**. Realme RMX2205
(CPU) trước, OnePlus 13R (GPU) sau. Mọi câu mở phiên với **4 tool, `tools_json` 1.798 ký tự**,
chỉ dẫn hệ thống 469 ký tự.

| # 5.6 | Câu | Realme — tool · tổng ms · câu | OnePlus — tool · tổng ms · câu |
|---|---|---|---|
| 13 | `Hoa don nao qua han?` | `danh_sach_hoa_don {trang_thai: qua_han}` · 15.090 (câu đầu; nạp CPU 1.072 ms trước đó) · ✅ *"Hoa đơn Kiem đã quá hạn với số tiền là 45.000 đ. Tổng cộng còn phải trả là 155.000 đ."* | cùng tool · 6.896 (nạp GPU 4.151 ms trước đó) · ✅ *"Có 1 hóa đơn quá hạn: Kiem với số tiền là 45.000 đ. …"* |
| 15 | `Vi nao dang am?` | `danh_sach_vi {}` · 11.902 · ✅ *"Ví test đang âm với số dư là -100.000 đ."* | cùng · 4.488 · ✅ cùng câu |
| 8 | `Thang nay toi chi nhieu nhat vao danh muc nao?` | `chi_tieu_theo_ky {ky: thang_nay}` · 14.459 · ✅ *"…Các danh mục chi tiêu là: Cho vay (800.000 đ), Chưa phân loại (500.000 đ), …"* — xếp giảm dần nhưng **không nói thẳng** "nhiều nhất" | cùng · 8.074 · ✅ *"…Các danh mục chi tiêu có chi phí **cao nhất** là: Cho vay (800.000 đ), …"* |
| 3 | `Ngan sach nao sap het?` | `danh_sach_ngan_sach {}` · 11.406 · ✅ *"Ngân sách Giáo dục còn 8 ngày."* — tên đúng, chọn số ngày thay vì 90,0 % | cùng · 8.619 · ⚠️ **LỆCH**: *"Danh sách ngân sách sắp hết: * Giáo dục … * Di chuyển … * Ăn uống … * Mua sắm: Còn lại 790.000 đ."* — gộp **cả bốn** vào "sắp hết"; lộ bẫy 4.34 và 4.36 |
| 2 | `Con bao nhieu tien ngan sach thang nay?` | `danh_sach_ngan_sach {}` · 11.404 · ✅ *"Tổng còn lại của các ngân sách là 1.340.000 đ."* | cùng · 4.866 · ✅ |
| 9 | `Thang truoc toi chi bao nhieu?` | `chi_tieu_theo_ky {ky: thang_truoc}` → 0 hàng · 10.073 · ✅ *"Tháng trước bạn đã chi tổng cộng 0 đ."* — **đúng**: giao dịch sớm nhất của CSDL là 02/09/2026 | cùng · 4.507 · ✅ |
| ĐC1 | `Lai suat tiet kiem cua toi la bao nhieu?` | `chi_tieu_theo_ky {thang_nay}` · 12.479 · **LỆCH**, không bịa: *"Dựa trên dữ liệu tháng này, tổng chi … 2.141.000 đ và tổng thu … 15.135.000 đ."* | **3 lời gọi** (`thang_nay` → `nam_nay` → `thang_truoc`), lượt 4 vượt trần → **L3** · ~7.500 (từ lúc mở phiên; L3 không in dòng `xong sau`) · mẫu câu lặp hàng, mất nhãn kỳ — lộ bẫy **4.35**; không số nào bịa |
| ĐC2 | `Thang nay toi chi bao nhieu?` | `chi_tieu_theo_ky {thang_nay}` · 11.501 · ✅ không tụt | cùng · 7.472 · ✅ |
| *(ngoài bảng)* | `Xin chao` — chạy thật nhánh L1 | không gọi tool, 84 ký tự bị **bỏ** → bậc 1 · 8.575 + 14.363 ms | cùng · 3.695 + 3.089 ms |

**Chấm cổng C** (kế hoạch Task 9 Step 3): nhóm A (13, 15, 8, 3) trả lời bằng tên — Realme **4/4**,
OnePlus **3/4** (≥ 3/4 ✅) · câu 2 và 9 ✅ hai máy · ĐC1 **không bịa số** ở cả hai máy · ĐC2 không
tụt · logcat thấy đúng tool ở mọi câu đúng · **0 dòng `FATAL`/`SIGSEGV`/`SIGBUS`** trong hai tệp
logcat. → **ĐẠT.** Mô hình gọi đúng tool và đúng tham số ở **8/8** câu trên mỗi máy (ĐC1 không có
tool phù hợp — nó chọn tool gần nhất chứ không nói "không có").

**Độ trễ** (đọc từ log): lượt gọi tool **5,2–9,3 s** Realme / **1,1–2,8 s** OnePlus, luôn **0 ký
tự** chữ; lượt trả lời token đầu **0,9–2,6 s** / **0,2–0,5 s**; tổng một câu (sau khi nạp) **10–15
s** / **4,5–8,6 s**; mở phiên **2,7–2,9 s** / **2,0–2,2 s** (gồm dựng FST ràng buộc, mục 9.13). Đúng
dải spec chấp nhận; không câu nào tụt so với bậc 1.

⭐ **Ba lỗi thật lượt đo bắt được, cả ba chỉ trên OnePlus, 3543 ca test đều mù** — bẫy **4.34**
(thẻ gán nhầm đối tượng khi hai hàng cùng giá trị), **4.35** (mẫu câu sau nhiều lời gọi), **4.36**
(markdown). Người dùng chọn sửa cả ba ngay (`ace9a53`, +11 ca). Kiểm lại trên Realme sau khi sửa
(16:16–16:22): câu 3 và ĐC1 cho **đúng câu cũ**, chip *"Tình hình ngân sách"* cho câu hai vế kèm hai
thẻ đúng — không hồi quy. L3 và markdown **không tái hiện** được trên Realme (mô hình ra câu khác
theo máy), nên hai ca ấy được canh bằng unit test dựng lại **đúng đầu ra** máy thật.

⚠️ **Điều đo được mà chưa sửa, để người dùng quyết:** (1) câu chào trên Realme mất **~23 s** rồi
nhận một câu tổng hợp số — giá của L1 (vứt câu mô hình, sinh lại ở bậc 1); (2) ĐC1 không bao giờ
nói *"không có dữ liệu lãi suất"* — nó luôn tìm tool gần nhất; (3) canary cho phiên có tool
(bẫy 4.33) vẫn **chưa làm** — ✅ **làm xong 2026-09-23 tối**, bước **1b** của thứ tự mới (mục
**9.15**). (1) và (2) vẫn chờ người dùng gọi tên.

### 9.15 Bước 1b — canary cho phiên có tool, lối B (2026-09-23 tối) — ✅ NGHIỆM THU MÁY ẢO

**Vì sao có.** Bẫy **4.33**: với gói 1.7.0 phiên có tool sập **native** ngay lượt giải mã đầu, trên
cả hai máy đo; `try/catch` vô dụng nên app văng ở **mọi** câu hỏi. Bản 1.9.0 / 1.8.0 hết sập trên
hai máy ấy, nhưng máy khác chưa đo — canary là lưới cho chúng.

**Vì sao không chép khuôn canary GPU (4.24).** Dấu còn sót không phân biệt *sập* với *bị giết*.
Realme giết app khi vuốt khỏi Recents (đo 2026-09-22), hệ điều hành giết khi thiếu RAM, người dùng
bấm Buộc dừng — cả ba để dấu lại y hệt một cú sập, và khuôn GPU sẽ tắt bậc tool **vĩnh viễn** trên
máy ấy. Người dùng chọn **lối B** trong ba lối (A chép khuôn GPU · B hỏi lý do thoát · C chỉ đếm hai
lần liền).

**Thiết kế** (`domain/canary_cong_cu.dart`):

| Mảnh | Luật |
|---|---|
| Đặt dấu | `quaCanary` bọc **mỗi** lượt sinh của `_PhienThat`: ghi tệp `slm_cong_cu_dang_thu` (nội dung = mốc mili giây) **trước** khi gọi engine, gỡ ở **sự kiện đầu tiên** của lượt; lượt rỗng / ném lỗi thường / bị huỷ cũng gỡ. Chỉ cú sập native — thứ không chạy tới `finally` — để dấu lại |
| Xét dấu sót | `xetDauSot()` chạy **lúc app khởi động** (`main.dart`, chỉ Android) và lại một lần trước mỗi phiên. Hỏi kênh `flowmoney/ly_do_thoat` (Kotlin, `MainActivity`) danh sách `ApplicationExitInfo`; lấy lần thoát **đầu tiên sau lúc đặt dấu** — không phải lần mới nhất — và chỉ coi là sập khi lý do là `REASON_CRASH_NATIVE` (5) |
| Không biết lý do | Android 10 trở xuống, hoặc không có bản ghi nào sau lúc đặt dấu: tắt khi dấu sót **hai lần liền** (`slm_cong_cu_sot`); một lượt chạy trơn ở giữa đếm lại từ đầu |
| Dấu "hỏng" | `slm_cong_cu_hong` ghi `versionCode`; app lên bản khác thì tự xoá và bậc tool mở lại; không đọc được phiên bản thì **giữ** trạng thái tắt |
| Khi đã tắt | `SlmRuntimeThat.moPhien` ném `BacCongCuDaTat`; `hoiBangCongCu` bắt đúng lỗi ấy và phát `KhongTraCuu` — màn đi thẳng bậc 1, im lặng, **không** phải câu L4 "không chạy được" |

**Nghiệm thu máy ảo** (`emulator-5554`, API 36, APK debug `versionCode=1`). Máy ảo không nạp được
mô hình (x86_64), nhưng phép xét dấu sót chạy **lúc khởi động** nên kiểm được trọn đường Kotlin →
Dart mà không cần mô hình: đặt dấu bằng `run-as`, làm tiến trình chết theo ba cách, mở lại app.

| Cách chết | `dumpsys activity exit-info` | Sau khi mở lại |
|---|---|---|
| `run-as … kill -11 <pid>` — giả lập sập native | `reason=5 (APP CRASH(NATIVE))`, `status=11` | dấu xoá; `slm_cong_cu_hong` = **`1`** (đúng `versionCode`) ✅ |
| `am force-stop` — Buộc dừng | `reason=10 (USER REQUESTED)`, `subreason=21 (FORCE STOP)` | dấu xoá; **không** tệp hỏng, **không** bộ đếm ✅ |
| `run-as … kill -9 <pid>` — cách hệ điều hành dọn app | `reason=2 (SIGNALED)`, `status=9` | dấu xoá; **không** tệp hỏng ✅ |

⚠️ **Chưa đo trên máy thật có mô hình**: đường "sập thật trong engine" không tái hiện được với gói
1.9.0 (nó đã hết sập) — phép giả lập bằng SIGSEGV cho **đúng** lý do mà một cú sập thật trong engine
sẽ có, nên đó là phép đo gần nhất làm được. Đường Android 10 trở xuống chỉ canh bằng unit test (không
có máy ảo API ≤ 29 trong dự án).

**Test:** `domain/canary_cong_cu_test.dart` **15** ca · `data/nguon_ly_do_thoat_test.dart` **4** ·
`data/vong_lap_cong_cu_test.dart` +**1** · `canary_cong_cu_noi_day_test.dart` **4** (đọc mã nguồn
của bốn mối nối — runtime, DI, `main.dart`, Kotlin — vì `flutter test` chạy trên x86_64, nơi đường
thật của phiên có tool là vùng mù). Các ca "không được tắt nhầm" xanh ngay trên khung rỗng nên đã
thử bằng **năm** bản sai có chủ ý (coi mọi dấu sót là sập · lấy bản ghi mới nhất · lượt trơn không
đếm lại · gỡ dấu ở cuối lượt thay vì sự kiện đầu · bỏ `try/catch` quanh kênh) — mỗi bản làm đúng các
ca ấy đỏ. Bẫy **4.37** (huỷ luồng `async*`) lộ ra khi viết chính các ca này.

### 9.16 Bước 1c — tên đối tượng có chữ số (2026-09-23 tối muộn) — ✅ UNIT TEST · ✅ ĐO REALME 2026-09-24

**Vì sao có.** Lượt soát trước bước 2 đo CSDL máy ảo (`emulator-5554`, tài khoản 10, chỉ **đọc**,
chép cả `-wal`/`-shm` — bẫy 4.9): **39** giao dịch sống, **21** có ghi chú, **3** ghi chú có chữ số
— cả ba là ghi chú hệ thống *"Thanh toán hóa đơn: <tên hoá đơn có số>"*. Tên có chữ số: hoá đơn
**5/9**, danh mục **1/16**, ví 0/4, mục tiêu 0/2. Chạy thử trên mã bằng một test tạm (không commit):
*"Hoá đơn Kiem thu hoa don 123 chưa trả, số tiền 50.000 đ."* → `kiemSoNhieuGoi` **false**, `kiemNhan`
**false**; cùng câu ấy với tên `Kiem` → cả ba lớp **true**. Cổng C không thấy vì hoá đơn đo được tên
`Kiem`, không có chữ số.

**Một gốc, ba chỗ hỏng:**

| Chỗ | Hỏng thế nào |
|---|---|
| `kiemSo` / `kiemSoNhieuGoi` | `trichSo` đọc chữ số trong tên là một con số không có trong gói |
| `kiemNhan` | trích số như trên; và `amTietCua` tách câu ở mọi ký tự không phải chữ nên âm tiết "t9"/"123" của tên không bao giờ có trong câu. Sinh đôi: `tuKhoaNhan` tách **tên** theo khoảng trắng còn câu theo mọi ký tự lạ, nên tên có dấu gạch (`Điện/Nước`) cũng không bao giờ khớp |
| `theCuaCau` | "9" của `Tiền nhà T9` khớp nhầm *"Còn 9 ngày"* của gói khác — thẻ nói về một đại lượng câu không nhắc tới |

**Cách sửa.** `trichSoNgoaiTen(cau, goi)` ở `kiem_so.dart` — định nghĩa duy nhất của "con số trong một
câu trả lời", ba chỗ trên cùng gọi — bỏ khỏi câu các tên của gói (`GoiSo.tenDoiTuong`) rồi mới
`trichSo`. Bốn chốt để lớp chắn không bị nới cho câu bịa: tên **có chữ cái** (`2027` không được miễn);
khớp **trọn từ** ở cả hai đầu; so theo `normalizeCategoryName`; tên **dài** bỏ trước. So bằng tìm
chuỗi trên câu đã chuẩn hoá chứ **không** dựng regex từ tên — tên do người dùng đặt, và
`RegExp.escape` + `unicode: true` là một chỗ có thể ném lỗi ngay trong bộ kiểm. `tenDoiTuong` mặc
định là mọi `SoLieu.ten`; ba gói in tên không nằm trên `SoLieu` nào override: Mục tiêu (`ten`), Trang
chủ (`tenNganSach`), Ngân sách (`keHoach.thieu` — ngân sách thâm hụt của câu tóm tắt kế hoạch, có
thể nằm ngoài danh sách bốn tên). `amTietCua` và `tuKhoaNhan` dùng **một** phép tách
`[^\p{L}\p{N}]+`.

**Test:** **18** ca ở **7** tệp đã có — `kiem_so_test` 8 · `kiem_nhan_test` 4 · `goi_so_tra_cuu_test`
2 · `the_cua_cau_test` 1 · `goi_so_muc_tieu_test` 1 · `goi_so_trang_chu_test` 1 ·
`goi_so_ngan_sach_test` 1. Sáu ca xanh ngay từ đầu, nên thử **11** bản sai có chủ ý — sáu trên
`kiem_so.dart` (bỏ kiểm biên · miễn tên toàn chữ số · tên ngắn trước · bỏ mọi chữ số từng có trong
một tên · phân biệt hoa thường · có tên thì bỏ kiểm cả câu) và năm trên `kiem_nhan.dart` (miễn vế
nêu tên khi tên có số · bỏ âm tiết có chữ số · trích số thô · câu tách âm tiết như cũ · tên tách theo
khoảng trắng như cũ) — mỗi bản làm đúng ca canh chốt của nó đỏ. Trọn bộ **3603/3603** (3 skip),
analyze **26**, 0 error. ⚠️ Hai điều lượt viết test lộ ra: (1) ca biên đầu dự tính dùng *"Bạn 5"* cho
tên `An 5`, nhưng `ạ` khác `a` nên chuỗi con không khớp và ca ấy **xanh cả trên bản không kiểm biên**
— đổi sang *"Ban 5"*; (2) ca của gói Ngân sách phải tự khẳng định **hai tiền đề** (ngân sách thâm hụt
đúng là `Tiền nhà T9`, và tên ấy không nằm trên `SoLieu` nào) trước khi canh — thiếu vế sau thì
getter mặc định đã phủ tên và ca không canh gì. Và thêm getter vào `GoiSo` làm **ba lớp giả
`implements GoiSo`** trong test gãy biên dịch — đổi sang `extends` (bẫy 4.38).

**✅ Đo trên máy thật 2026-09-24** (Realme, buổi đo cổng D, mục **9.17**): câu A13 *"Hoa don nao qua
han?"* hiện nguyên văn *"Có 2 hóa đơn đã quá hạn: Kiem với số tiền 45.000 đ và **di h0c** với số tiền
10.000 đ. Tổng cộng còn phải trả là 155.000 đ."* — tên có chữ số được nêu và câu **hiện** (trước 1c câu
này rơi về mẫu câu). Câu đo riêng của 1c (*"hoa don di h0c con phai tra bao nhieu"*) thì mô hình trả lời
tổng còn phải trả mà không nêu tên — lệch câu hỏi, không phải lớp chắn chặn.

**Bước 2 đã quyết** (spec mục 3.8): **ghi chú là `ten` của hàng giao dịch** (`tieuDeGiaoDich`), nên chữ
số trong ghi chú hệ thống *"Thanh toán hóa đơn: di h0c"* được phủ bằng chính cơ chế này — thẻ
*"Thanh toán hóa đơn: di h0c · Số tiền 10.000 đ"* hiện đúng trên máy thật.

### 9.17 Bước 2 — ba tool đọc + cổng D (2026-09-23 → 24) — 🛑 CỔNG D CHƯA ĐẠT (lần đo 1)

Mã: spec `docs/superpowers/specs/2026-09-23-buoc-2-ba-tool-doc-tim-giao-dich-design.md`, kế hoạch 9 task
(gitignore, nhật ký thi công ở cuối tệp), commit `daf201a` → `bc03303`. Bảy tool (`tools_json` **4.393** ký tự
— bốn tool 4b là 1.798), `LoaiSo.ngayThang`, `khopTheoTen`, `kMaKy` tám mã, `tieuDeGiaoDich`, `timGiaoDich`;
**43** bản sai có chủ ý qua tám task đều bị test bắt.

**Spike trần token (task 7, Realme, CPU).** Bảy khai báo + phiên hai lời gọi (`danh_sach_muc_tieu` →
`chi_tieu_theo_ky`) **vượt trần 2048**: `FAILED_PRECONDITION: Prefill input length exceeds available state
entries (remaining capacity: 133)` — chuỗi **khác** bẫy 4.29 (bẫy **4.39**). Nâng `maxTokens` **4096**:

| Câu ngắn *"thang nay toi chi bao nhieu"* | 2048 | 4096 |
|---|---|---|
| Nạp mô hình (CPU) | 1.188 ms | 1.045 ms |
| Tổng một câu | 21,5 s | 29,1 s |
| `TOTAL PSS` đỉnh | 2.040.400 KB | 2.782.971 KB (**+0,71 GiB**) |
| `TOTAL SWAP PSS` của app | ≤ 36 MB | **1.169 MB** |
| Sập / bị giết | 0 | 0 |

Mức tăng **vượt** ngưỡng ≤ 0,5 GB của spec mục 3.10 — **người dùng duyệt đích danh cho vượt** ("cho ram vượt
ngưỡng"). Ở 4096 phiên hai lời gọi đi trọn (2 câu, 31,8 s, số đúng). OnePlus 13R **chưa đo** (không cắm).

**Cổng D** (Realme, APK release `maxTokens` 4096, tài khoản 10, 2026-09-24 00:07–00:40, gõ không dấu —
`muaxe` gõ `muaxxe`, `test` gõ `tesst` vì bàn phím Telex, bẫy **4.41**). Chấm theo lời gọi **đầu tiên**;
đáp án nhóm C kiểm lại bằng script cho ngày đo — trùng bảng 5.4 của spec.

| Dòng | Ngưỡng | Đo được | |
|---|---|---|---|
| 1. Nhóm A không tụt | "cái nào" 4/4 · câu 2, 9 đúng · ĐC1 không bịa · ĐC2 không tụt | **7/8 — TỤT**: cùng tool như 9.14, nhưng câu **3** *"Ngân sách nào sắp hết?"* **SAI** — *"các ngân sách sau sắp hết: Giáo dục … Di chuyển … Ăn uống: còn lại 450.000 đ … Mua sắm: còn lại 790.000 đ"*, xếp cả bốn vào "sắp hết" (cổng C trả lời đúng: chỉ Giáo dục). Câu 13 đúng nhưng câu cuối *"Tổng cộng còn phải trả là 155.000 đ"* đặt ngay sau hai hoá đơn quá hạn (45.000 + 10.000) dễ đọc thành tổng của hai hoá đơn ấy. ĐC1 **tốt hơn** — *"Tôi không có thông tin về tỷ lệ tiết kiệm cụ thể"* | ✗ |
| 2. Nhóm B ≥ 3/4 · câu 1c hiện | | **2/4** — B3 ✅ (bốn danh mục có tên + mức, khớp `suggestAmount` ngày đo), B4 ✅ (*"Ăn uống"* 80.000 đ); B1 gọi đúng tool nhưng câu trượt `kiemNhan` → mẫu câu (L2) dài, có *"cần thêm 16 ngày"* lẫn giữa mọi số của hai mục tiêu; B2 gọi **sai tool** (`goi_y_han_muc {danh_muc: muaxe}`) → *"Không tìm thấy danh mục 'muaxe'"* — LỆCH (đáp án: cần tích 46.420 đ/tháng). Câu 1c LỆCH — hỏi *di h0c* (10.000 đ), trả lời tổng còn phải trả của mọi hoá đơn (155.000 đ); A13 thì **hiện** *"di h0c"* | ✗ |
| 3. Nhóm C | ≥ 18/20 tool · ≥ 16/20 tham số | **13/20 · 5/20**; theo **nội dung câu hiện ra**: đúng **4/20** (C2, C3, C15, C18) — bảng dưới | ✗ |
| 4. SAI = 0 · 0 sập | | **5 câu SAI** (A3, C7, C8, C11, C12) · 0 sập · 0 bị giết | ✗ |
| 5. Không vỡ trần | | 0 lần | ✅ |

⚠️ **Lượt chấm đầu (cùng ngày) ghi "nhóm A 8/8, 3 câu SAI" — SAI**: nó chấm theo log tool/tham số và chỉ lướt
ảnh, nên bỏ sót A3 và C8; người dùng nhìn màn hình điện thoại và chỉ ra. Bảng dưới chấm lại **theo câu trả lời
hiện ra**, đối chiếu đáp án dữ liệu thật ngày đo, trên **bản ghi nguyên văn** cả 36 cặp hỏi–đáp — lấy bằng cách
cuộn màn và `adb shell uiautomator dump` từng màn: Flutter đưa mỗi bong bóng ra lớp trợ năng, câu trả lời **kèm
thẻ số liệu** nằm ở thuộc tính `content-desc` (bọc nháy **đơn** khi chữ có nháy kép). Ảnh chụp cắt mất câu dài,
bản ghi thì không. Thêm hai chi tiết chỉ bản ghi mới cho thấy: ĐC1 đáp *"không có thông tin về **tỷ lệ tiết
kiệm**"* cho câu hỏi về **lãi suất** tiết kiệm (nhầm khái niệm, không bịa); mẫu câu của B1 có câu trả lời
(*"Theo nhịp hiện tại cần thêm 16 ngày"*) nhưng lẫn giữa mười sáu số của **cả hai** mục tiêu.

| # | Câu hỏi (gõ) | Câu hiện ra (rút gọn) | Đáp án thật | Chấm |
|---|---|---|---|---|
| C1 | tháng này tiêu gì trên 500k | *"Tổng chi trong tháng này là 2.141.000 đ."* | 2 khoản: Cho vay 800.000 · MuaXe 500.000 | LỆCH |
| C2 | hôm qua đã chi những gì | *"Hôm qua bạn đã chi 0 đ."* | 0 | ✅ |
| C3 | hôm nay có giao dịch nào không | *"Hôm nay bạn chưa có giao dịch nào."* | 0 | ✅ |
| C4 | tuần này có khoản chi nào dưới 100 nghìn | mẫu câu **tháng này**: 13 khoản, tổng 415.000 đ | 0 (tuần này) | mẫu câu **lệch kỳ** |
| C5 | tuần trước đã tiêu những khoản nào | mẫu câu 6 khoản, **lẫn khoản thu** (Cho vay +500.000) | 4 khoản chi | mẫu câu lệch |
| C6 | tháng trước có khoản chi nào trên 1 triệu | *"Không tìm thấy dữ liệu khớp câu hỏi."* (mẫu câu sau lời gọi **bị từ chối**) | 0 | đúng **do may** |
| C7 | các khoản chi hơn nửa triệu trong quý này | *"Các khoản chi có số tiền hơn một triệu là: Cho vay (800.000 đ), Chưa phân loại (500.000 đ), Di chuyển (355.000 đ)…"* | 2 khoản | **SAI** |
| C8 | năm nay có khoản thu nào từ 5 triệu trở lên | *"Không tìm thấy dữ liệu khớp câu hỏi."* (mẫu câu sau lời gọi **bị từ chối**) | **2**: Lương 9.000.000 · 5.000.000 | **SAI** |
| C9 | các khoản chi từ 200k đến 1 triệu tháng này | mẫu câu 18 khoản ≤ 1 triệu, **có cả 180.000 và 123.000** | 2 khoản | mẫu câu lệch |
| C10 | tháng này nhận được những khoản thu nào | *"tổng thu là 15.135.000 đ. Các khoản chi bao gồm: Cho vay…"* | 8 khoản thu | LỆCH |
| C11 | tháng này chuyển tiền sang ví tiết kiệm những lần nào | *"Không tìm thấy giao dịch chuyển tiền vào ví 'tiet kiem'…"* | **10** khoản | **SAI** |
| C12 | liệt kê các khoản ăn uống tháng này | *"Không có dữ liệu giao dịch nào … danh mục 'ăn uống'"* | **1** (50.000 đ) | **SAI** |
| C13 | ví tiền mặt tháng này chi những gì | *"Tổng chi trong tháng này là 2.141.000 đ, bao gồm…"* (mọi ví) | 13 khoản, 2.031.000 đ | LỆCH |
| C14 | chi gì cho mua sắm từ ví tiền mặt | *"Tổng chi trong tháng này là 2.141.000 đ."* | Mua sắm 60.000 đ | LỆCH |
| C15 | lần gần nhất chi cho di chuyển là ngày nào | *"… gần nhất là ngày 20/09 với số tiền 50.000 đ"* | 20/09 · 50.000 | ✅ |
| C16 | 5 khoản chi gần đây nhất | mẫu câu 4 khoản mới nhất (trần 4) | 4 hàng, mới nhất 20/09 | mẫu câu có ích |
| C17 | tìm giao dịch có ghi chú hoá đơn | mẫu câu 4/5 khoản + *"Số khoản: 5"* | 5 khoản | mẫu câu có ích |
| C18 | khoản chi lớn nhất tháng này | *"… 'Cho vay' với số tiền 800.000 đ"* (từ tổng danh mục — trùng do may) | Cho vay 800.000 | ✅ |
| C19 | các khoản chi cho giáo dục từ ví test | *"Không tìm thấy … danh mục 'giao duc tu vi test'"* + liệt kê danh mục | 2 khoản | LỆCH |
| C20 | lần cuối nạp tiền cho mục tiêu muaxe | *"mục tiêu 'MuaXe' còn 581 ngày"* | **08/09** (100.000 đ) | LỆCH |

Nhóm C, lời gọi đầu: ✅ tool + tham số — **C2** `{hom_qua, khoan_chi}` · **C3** `{hom_nay}` · **C15**
`{khoan_chi, danh_muc: di chuyển, moi_nhat}` (câu *"… gần nhất là ngày 20/09 với số tiền 50.000 đ"*, thẻ
*"Di chuyển · Ngày 20/09"* — `LoaiSo.ngayThang` chạy đúng trên máy thật) · **C16** · **C17**. Đúng tool, sai
tham số — C4 (thiếu `ky=tuan_nay`), C5 (thiếu `chieu`), C6 (`danh_muc: tat_ca`, số tiền nhét vào `tu_khoa`),
C8 (`danh_muc: tat_ca`), C9 (thiếu `so_tien_tu`), C11 (`danh_muc: tiet kiem` thừa cạnh `vi`), C12 (`vi: tất_cả`),
C19 (`danh_muc: "giao duc tu vi test"`). **Sai tool** — `chi_tieu_theo_ky` cho C1, C7, C10, C13, C14, C18;
`danh_sach_muc_tieu` cho C20.

**Năm câu SAI được hiện**, theo ba cơ chế:
- **Lời từ chối của tool bị đọc thành "không có dữ liệu"** (bẫy **4.40**) — ở **hai tầng**: (a) **mô hình**: C11
  *"Không tìm thấy giao dịch chuyển tiền vào ví 'tiet kiem'…"* (có **10** khoản), C12 *"Không có dữ liệu giao dịch
  nào … 'ăn uống'"* (có **1**) — câu không số nên `kiemSo` mù; spike có ca thứ ba (*"Tôi đã gợi ý hạn mức…"*);
  (b) ⚠️ **mẫu câu của CHÍNH APP**: C8 *"Không tìm thấy dữ liệu khớp câu hỏi."* (có **2**) — `GoiSoTraCuu.mauCau()`
  trả câu ấy khi mọi lượt đều **rỗng hàng và rỗng tổng hợp**, mà một lượt bị từ chối cũng rỗng như thế. Đây là
  **lỗi mã**, không phải của mô hình; C6 đi cùng đường và chỉ đúng vì đáp án thật cũng là 0.
- **Mệnh đề sai trên tên thật và số thật** (bẫy **4.42**): C7 *"Các khoản chi có số tiền hơn một triệu là: Cho vay
  (800.000 đ), Chưa phân loại (500.000 đ), Di chuyển (355.000 đ)…"* (tổng theo danh mục của `chi_tieu_theo_ky`); A3
  *"các ngân sách sau sắp hết"* kèm cả ngân sách còn 450.000 và 790.000.

**Phát hiện khác:** mô hình nhét giá trị giữ chỗ (`"tat_ca"`, `"tất_cả"`) vào tham số **tuỳ chọn** (bẫy **4.43**);
chép số của **câu hỏi** vào câu trả lời (*"5 giao dịch…"*, *"có 4 giao dịch"*) → bị chặn (đúng) → mẫu câu; mẫu câu
L2 của `tim_giao_dich` **khó đọc** (một chuỗi dài *"Giáo dục khoản chi · Giáo dục · test: Số tiền 10.000 đ, Ngày
06/09; …"*); vượt trần ở 2048 thì màn báo *"Mô hình trên máy không chạy được"* dù hai tool đã chạy xong.

**Theo spec mục 5.5:** dưới ngưỡng dòng 3 → chỉnh mô tả tool / tham số, đo lại nhóm C; **chưa mở bước 3**. Dòng 2
và 4 trượt → ghi bảng, phân tích, **người dùng quyết** hướng sửa trước khi đo lại. Hướng sửa **đã chốt 2026-09-24** — *sửa lỗi mã trước, rồi
chỉnh mô tả*; spec bước 2b `docs/superpowers/specs/2026-09-24-buoc-2b-tu-choi-giu-cho-mo-ta-tool-design.md`.

### 9.18 Bước 2b — lời từ chối · giá trị giữ chỗ · mô tả tool (2026-09-24) — 🛑 CỔNG D CHƯA ĐẠT (lần đo 2)

Mã: spec bước 2b (đã duyệt), kế hoạch 10 task (gitignore, nhật ký thi công ở cuối tệp), commit `5357209` →
`e0e4a98`, thi công inline trong một phiên. Bảy task mã:

| Task | Commit | Việc |
|---|---|---|
| 1 | `5357209` | `KetQuaCongCu.loi` đòi `choNguoiDung` + `thamSoGo`; `loi_tham_so.dart` là chỗ **duy nhất** dựng lời từ chối (`tuChoiGiaTri` · `tuChoiSoTien` · `tuChoiKhoangNguoc` · `tuChoiKhongKhop` · `tuChoiKhopNhieu`); 13 lời gọi ở 6 tệp chuyển sang; `loiMaKy` bỏ |
| 2 | `a7a4413` | `tham_so_mo_hinh.dart`: `thamSoTen` (giữ chỗ = không lọc), `laSoTien` |
| 3 | `1d21b24` | `GoiSoTraCuu`: lượt bị từ chối **không** là đã tra cứu; gỡ **theo tham số**; `choHienChuMoHinh`, `cauChuaTraDuoc`; `mauCau()` ba trạng thái |
| 4 | `eeac28f` | vòng lặp: cổng hiện chữ `choHienChuMoHinh`, **L1b**, **L2b** |
| 5 | `22198ab` | `tim_giao_dich` (`danh_muc` · `vi` · `tu_khoa`) và `goi_y_han_muc` đọc tham số qua `thamSoTen`; `tu_khoa` là số tiền → `tuChoiTuKhoaLaSoTien` |
| 6 | `3b99ffd` | `ky` của `tim_giao_dich` **bắt buộc** + mã riêng **`moi_luc`** (mọi thời gian); `chi_tieu_theo_ky` giữ tám mã |
| 7 | `e0e4a98` | mô tả tool chỉ đường chéo; chỉ dẫn hệ thống thêm *"Công cụ trả "loi" thì gọi lại ngay…"*; `toolsJsonCua` một định nghĩa + test chặn độ dài |

**36** bản sai có chủ ý đều bị test bắt (34 của kế hoạch + 2 thêm cho ca xanh ngay — đếm 2026-09-24). ⚠️ Kế hoạch đoán sai **một** ca:
bản sai đưa `moi_luc` vào `kMaKy` **sống sót** — ca canh "tám mã" so `enum` với chính `kMaKy.keys`, hai vế đổi
cùng nhau; nay ca đòi đúng 8 mã và không có `moi_luc`. `flutter test` **3725/3725**, 3 skip; `flutter analyze`
**26**, 0 error.

**Spike trần token (task 8, Realme, APK release, 10:50–10:54).** `tools_json` **5.431** ký tự (bảy khai báo cũ
4.393; spec đoán ~5.400) — ba phiên dài nhất S1 (3 lời gọi, 38,2 s) · S2 (2 lời gọi, 36,3 s) · S3 (2 lời gọi,
~33 s, rơi L2): **0** `FAILED_PRECONDITION`, **0** sập. Không rút gọn mô tả; `kTranToolsJsonDaDo` = 5.431.

**Cổng D lần 2** (Realme, cùng APK, tài khoản 10, 2026-09-24 10:58–11:30; điều kiện như lần 1). Đáp án tính lại
cho ngày đo bằng script — **trùng** bảng 5.4 của spec bước 2 (mọi giao dịch nằm trong tháng 9, nên đáp án
`moi_luc` trùng `thang_nay`); đối chiếu chéo tổng thu 15.135.000 / tổng chi 2.141.000 khớp Trang chủ Realme.
Chấm theo **câu hiện ra** trên bản ghi nguyên văn (`uiautomator dump`, 34 cặp hỏi–đáp).

| Dòng | Ngưỡng | Lần 1 | **Lần 2** | |
|---|---|---|---|---|
| 1. Nhóm A không tụt | "cái nào" 4/4 · câu 2, 9 đúng · ĐC1 không bịa · ĐC2 | 7/8 (A3 SAI) | **8/8** — A3 *"Ngân sách "Giáo dục" còn 7 ngày"* (tên đúng; chỉ số là số ngày còn của kỳ). ĐC1 không bịa nhưng LỆCH: hỏi lãi suất, đáp *"Tổng chi tháng này 2.141.000 đ"* (lần 1: *"không có thông tin về tỷ lệ tiết kiệm"*) | ✅ |
| 2. Nhóm B ≥ 3/4 · câu 1c hiện | | 2/4 | **2/4** — B3, B4 ✅; B1 LỆCH (*"Bạn có hai mục tiêu: MuaXe và MuaDT"*); B2 vẫn gọi `goi_y_han_muc {danh_muc: muaxe}` → **L1b** *"Chưa tra được số liệu cho câu này: không có danh mục chi nào tên "muaxe"…"* (lần 1: *"Không tìm thấy danh mục…"*); 1c LỆCH (tổng 155.000, không nêu *di h0c*) | ✗ |
| 3. Nhóm C | ≥ 18/20 tool · ≥ 16/20 tham số | 13/20 · 5/20 | **10/20 · 4/20 — TỤT**; theo nội dung câu hiện ra đúng **6/20** (lần 1: 4/20) | ✗ |
| 4. SAI = 0 · 0 sập | | 5 SAI | **1 SAI** (C9, mẫu câu — bẫy 4.44) · ĐC3 trượt tiêu chí · 0 sập | ✗ |
| 5. Không vỡ trần | | 0 | **0** | ✅ |

| # | Lời gọi đầu | Câu hiện ra (rút gọn) | Đáp án | Chấm |
|---|---|---|---|---|
| C1 | `chi_tieu_theo_ky` ✗ | *"Tổng chi trong tháng này là 2.141.000 đ."* — câu thứ hai (*"Các khoản chi trên 500k là: Cho vay…, Chưa phân loại…"*) bị chặn nhờ "500k" | 2 khoản | LỆCH |
| C2 | `chi_tieu_theo_ky {hom_qua}` ✗ (lần 1 ✓) | *"Hôm qua bạn đã chi 0 đ."* | 0 | ✅ |
| C3 | `tim {hom_nay}` ✓✓ | *"Không có giao dịch nào hôm nay."* | 0 | ✅ |
| C4 | `tim {tuan_nay, khoan_chi, den 100000}` ✓✓ | L2: *"Tuần này — Số khoản: 0; Tổng chi: 0 đ; Đến: 100.000 đ."* | 0 | mẫu câu có ích |
| C5 | `chi_tieu_theo_ky {tuan_truoc}` ✗ | *"…đã chi tổng cộng 1.096.000 đ. Các khoản chi bao gồm: Cho vay (800.000 đ), Chi khác (246.000 đ), và Di chuyển (50.000 đ)."* | 4 khoản, 1.096.000 | ✅ (theo danh mục) |
| C6 | `tim {thang_truoc, tu 1000000}` — thiếu `chieu` | L2: *"Tháng trước — Số khoản: 0; …; Từ: 1.000.000 đ."* | 0 | mẫu câu có ích |
| C7 | `chi_tieu_theo_ky {quy_nay}` ✗ | *"Tổng chi trong quý này là 2.141.000 đ."* — câu SAI kiểu 4.42 bị chặn nhờ "1 triệu" | 2 khoản | LỆCH (lần 1 **SAI**) |
| C8 | `tim {nam_nay, khoan_thu, tu 5000000}` ✓✓ | *"Có 2 khoản thu từ 5.000.000 đ trở lên…: Lương (9.000.000 đ ngày 04/09) và Lương (5.000.000 đ ngày 04/09)."* | 2 | ✅ (lần 1 **SAI**) |
| C9 | `tim {thang_nay, den 1000000, tu_khoa: "chi"}` — thiếu `so_tien_tu`, `chieu`; `tu_khoa` bịa | L2: *"Tháng này — Số khoản: 0; Tổng chi: 0 đ; …; Đến: 1.000.000 đ."* | **2** khoản | **SAI** (bẫy 4.44) |
| C10 | `chi_tieu_theo_ky` ✗ | *"…tổng thu của bạn là 15.135.000 đ."* | 8 khoản thu | LỆCH |
| C11 | `tim {thang_nay, chuyen_vi, vi: "tiet_kiem"}` — tên `snake_case` không khớp | L1b: *"Chưa tra được số liệu cho câu này: không có ví nào tên "tiet_kiem"…"* | 10 khoản | mẫu câu trung thực (lần 1 **SAI**; bẫy 4.45) |
| C12 | `chi_tieu_theo_ky` ✗ | *"Tổng chi … 2.141.000 đ. Các khoản chi bao gồm: Cho vay…, Chưa phân loại…, Di chuyển…, Chi khác…"* — không nhắc Ăn uống | 1 (50.000) | LỆCH (lần 1 **SAI**) |
| C13 | `chi_tieu_theo_ky` ✗ | *"Tổng chi trong tháng này là 2.141.000 đ, bao gồm…"* (mọi ví) | 13 khoản, 2.031.000 | LỆCH |
| C14 | `chi_tieu_theo_ky` ✗ | *"Tổng chi … 2.141.000 đ."* | Mua sắm 60.000 | LỆCH |
| C15 | `tim {moi_luc, chieu: chuyen_vi, moi_nhat}` — thiếu `danh_muc`, sai `chieu` | L2 liệt kê khoản **chuyển** MuaXe 08/09 | 20/09 · 50.000 | mẫu câu lệch (lần 1 ✅) |
| C16 | `tim {moi_luc, moi_nhat}` — thiếu `chieu` | L2 bốn khoản mới nhất, **lẫn khoản thu** | 4 khoản chi | mẫu câu lệch |
| C17 | `tim {moi_luc, tu_khoa: hoa don}` ✓✓ | *"Có 5 giao dịch có ghi chú "hoa don": …"* bốn dòng + *"Tổng chi là 311.000 đ."* | 5 khoản | ✅ |
| C18 | `chi_tieu_theo_ky` ✗ | *"…là Cho vay với số tiền 800.000 đ."* | Cho vay 800.000 | ✅ (trùng do may, như lần 1) |
| C19 | `tim {moi_luc, khoan_chi}` — thiếu `danh_muc`, `vi` | *"Tổng chi cho giao dịch là 2.141.000 đ. Các giao dịch chi tiêu bao gồm: Cho vay…"* | 2 khoản | LỆCH |
| C20 | `danh_sach_muc_tieu` ✗ | *"…Tôi không có thông tin về ngày nạp tiền gần nhất cho bất kỳ mục tiêu nào."* | 08/09 | LỆCH (trung thực) |
| ĐC3 | `chi_tieu_theo_ky` ✗ | *"Không có dữ liệu chi tiết cho danh mục "abc" trong kỳ tháng này. Tổng chi … 2.141.000 đ."* | không có danh mục *abc* | **trượt tiêu chí** (chữ mô hình hiện) — nội dung đúng |

**Cột phân tích:** gọi lại sau lời từ chối **0/2** (B2, C11 — chỉ dẫn *"gọi lại ngay"* không có tác dụng); chọn
`moi_luc` **4** (C15, C16, C17, C19 — đều là câu không nêu kỳ); thiếu `ky` **0**; L1b **2** · L2b **0** · L2 **5**;
mọi câu đúng **một** lời gọi.

**Đọc kết quả.** Hai lỗi **mã** của lần 1 đã chữa trúng: cả năm câu SAI (A3, C7, C8, C11, C12) hết SAI, và L1b
chạy thật trên máy. Phần **mô tả tool** thì không: chọn tool **tụt** 13 → 10 — `chi_tieu_theo_ky` được gọi cho
**chín** câu nhóm C (lần 1: sáu), kể cả C2 lần 1 gọi đúng; câu *"chỉ có TỔNG, không liệt kê từng khoản"* và
chỉ đường sang `tim_giao_dich` không đổi được lựa chọn. Và lộ một cơ chế SAI **mới** mà luật bước 2b không
chạm tới — tham số thừa làm hẹp bộ lọc thành một lượt **thành công** 0 hàng (bẫy **4.44**), cộng tên
`snake_case` (bẫy **4.45**). ĐC3 đi đường không ai lường: mô hình không gọi `tim_giao_dich` mà gọi
`chi_tieu_theo_ky`, nên không có lời từ chối nào để L1b/L2b bắt; câu nó viết **đúng nội dung** nhưng trượt
tiêu chí đã khai *"chữ mô hình không được hiện"*.

**Theo spec 2b mục 5 bước 7:** dòng 3 dưới ngưỡng → đòn bẩy kế tiếp đã để dành là **đổi tên
`chi_tieu_theo_ky`** (spec 2b mục 1.2 hàng 10) — **hỏi người dùng trước**; **chưa mở bước 3**.
*(Người dùng chốt cùng ngày: sửa 4.44 / 4.45 **trước**, chưa đổi tên — bước 2c, mục 9.19.)*

### 9.19 Bước 2c — lượt rỗng theo bộ lọc · tên `snake_case` (2026-09-24) — 🛑 CỔNG D CHƯA ĐẠT (lần đo 3), ✅ bẫy 4.44 / 4.45 ĐÓNG

Mã: spec bước 2c (`docs/superpowers/specs/2026-09-24-buoc-2c-luot-rong-theo-bo-loc-va-ten-snake-case-design.md`,
đã duyệt), kế hoạch 9 task (gitignore, nhật ký thi công cuối tệp), commit `1301de9` → `5b7b7f4`, thi công inline
một phiên. Bảy task mã:

| Task | Commit | Việc |
|---|---|---|
| 1 | `1301de9` | `khopTheoTen` bậc ba (`_` = dấu cách, chỉ khi hai bậc đầu trượt); `loi_tham_so.dart` in tên gõ với `_` đổi thành dấu cách trong `choNguoiDung`, `tenLienQuan` mang cả hai dạng |
| 2 | `4dc674e` | `KetQuaCongCu.rongTheoBoLoc` · `boLoc` · `soLieuBoLoc` — **JSON gửi mô hình không đổi** (`soLieuBoLoc` vào json y như `tongHop`) |
| 3 | `b29f4de` | `KetQuaTimGiaoDich.tenDanhMucKhop` / `tenViKhop`; `tenKhop` thành getter (chỗ chạm duy nhất ngoài `ai_edge`) |
| 4 | `2a9b80b` | `hangGiaoDich`: Từ/Đến rời `tongHop` sang `soLieuBoLoc`; `boLoc` bảy điều kiện thứ tự cố định (chiều ≠ tất cả · danh mục · ví · ghi chú chứa · từ · đến · mới nhất trước), tên là **tên thật đã khớp**; cờ khi `soKhop == 0`; `tu_khoa` vào `tenLienQuan` |
| 5 | `da9b41b` | `GoiSoTraCuu`: `_luotRong` **không bao giờ gỡ**; `choHienChuMoHinh` ba vế; tiền tố = kỳ + bộ lọc; nhóm rỗng in *"‹tiền tố› — không có giao dịch nào khớp."*, không in vế `Từ:`/`Đến:`; khoá gom nhóm có bộ lọc; `cauLuotRong`; `cauNoiThem` (lượt rỗng + lời từ chối, loại xảy ra trước đứng trước) |
| 6 | `f0d639d` | vòng lặp: nhãn **L2c** / **L2b+L2c**, log nêu lý do cổng đóng, nối `cauNoiThem` |
| 7 | `5b7b7f4` | đầu-cuối qua `CongCuGiaoDich` |

**24** bản sai có chủ ý: **23** bị bắt, **1** sống sót là bản tương đương trên dữ liệu test (`dong.isEmpty` ⟺
`soKhop == 0`), ghi ở nhật ký. ⚠️ Kế hoạch đoán sai **hai** kỳ vọng ở task 4: fixture `kq` của
`hang_giao_dich_test` mang `tenViKhop: 'Tiền mặt'` nên `boLoc` luôn có `ví "Tiền mặt"` — sửa ca, không sửa mã.
`flutter test` **3755/3755**, 3 skip (3 phút 57 giây song song `analyze`); `flutter analyze` **26**, 0 error;
`ai_edge` + `ai_chat` **55** tệp / **591** ca.

**Cổng D lần 3** (Realme, APK release `5b7b7f4` cài 12:53, tài khoản 10, 2026-09-24 13:35–14:06, 34 câu, 31
phút; điều kiện như hai lần trước). Đáp án tính lại lúc 12:51 bằng `kiem_dap_an_3.py` — **trùng** lần 2 (cùng dữ
liệu, cùng ngày). Chấm theo **câu hiện ra** (`uiautomator dump`, 69 mục). ⚠️ Buổi đo suýt hỏng vì Realme **khoá
màn hình bằng khuôn mặt**: chạm vào màn khoá mở nhầm thanh thông báo, ảnh chụp đen tuyền, `vao_tro_ly.sh` chờ đủ 84
s không báo gì; `wm dismiss-keyguard` vô hiệu với khoá sinh trắc — phải nhờ người dùng mở khoá. Kiểm
`dumpsys window | grep isKeyguardShowing` **trước** khi chạm. Và `svc power stayon usb` bị Realme từ chối
(`WRITE_SETTINGS`, in `FATAL EXCEPTION` của `com.android.shell` vào logcat — **không phải app sập**).

| Dòng | Ngưỡng | Lần 1 | Lần 2 | **Lần 3** | |
|---|---|---|---|---|---|
| 1. Nhóm A không tụt | | 7/8 | 8/8 | **8/8** — y hệt lần 2 từng câu; ĐC1 vẫn LỆCH (tổng chi thay vì "không có") nhưng không bịa | ✅ |
| 2. Nhóm B ≥ 3/4 · 1c hiện | | 2/4 | 2/4 | **2/4** — B1 LỆCH, B2 L1b (vẫn gọi `goi_y_han_muc`), 1c LỆCH; B4 in *70.000* (lần 2 *80.000* — số domain của `suggestAmount`, không phải chuyện AI) | ✗ |
| 3. Nhóm C | ≥ 18/20 tool · ≥ 16/20 tham số | 13 · 5 | 10 · 4 | **10/20 · 5/20** — lời gọi **trùng từng tham số** với lần 2 ở cả 20 câu; C11 nay đúng tham số vì `tiet_kiem` khớp. Nội dung đúng **9/20** (lần 2: 6) | ✗ |
| 4. SAI = 0 · 0 sập | | 5 SAI | 1 SAI | **0 SAI** ✅ · ĐC3 vẫn trượt tiêu chí (chữ mô hình hiện, nội dung đúng) · 0 sập | ✗ (ĐC3) |
| 5. Không vỡ trần | | 0 | 0 | **0** (`tools_json` 5.431 mọi phiên) | ✅ |
| Thêm của 2c | C9 hết SAI · C11 không L1b vì `_` · không *"Số khoản: 0"* | | | **✅ · ✅ · ✅** (đếm trên bản ghi: 0) | ✅ |

| # | Lời gọi đầu (= lần 2) | Câu hiện ra (rút gọn) | Đáp án | Chấm |
|---|---|---|---|---|
| C1 | `chi_tieu_theo_ky` ✗ | *"Tổng chi trong tháng này là 2.141.000 đ."* — câu 2 *"trên 500k là: Cho vay…"* bị chặn nhờ "500k" | 2 khoản | LỆCH |
| C2 | `chi_tieu {hom_qua}` ✗ | *"Hôm qua bạn đã chi 0 đ."* | 0 | ✅ |
| C3 | `tim {hom_nay}` ✓✓ | **L2c**: *"Hôm nay — không có giao dịch nào khớp."* | 0 | mẫu câu nêu bộ lọc, **khớp** (lần 2 chữ mô hình ✅ — giá đã chấp nhận) |
| C4 | `tim {tuan_nay, khoan_chi, den 100000}` ✓✓ | **L2c**: *"Tuần này, khoản chi, đến 100.000 đ — không có giao dịch nào khớp."* | 0 | mẫu câu nêu bộ lọc, khớp |
| C5 | `chi_tieu {tuan_truoc}` ✗ | 1.096.000; Cho vay 800.000, Chi khác 246.000, Di chuyển 50.000 | 4 khoản | ✅ (theo danh mục) |
| C6 | `tim {thang_truoc, tu 1000000}` thiếu `chieu` | **L2c**: *"Tháng trước, từ 1.000.000 đ — không có giao dịch nào khớp."* | 0 | mẫu câu nêu bộ lọc (thiếu chiều, kết quả vẫn đúng) |
| C7 | `chi_tieu {quy_nay}` ✗ | *"Tổng chi trong quý này là 2.141.000 đ."* — câu 2 kiểu 4.42 bị chặn nhờ "1 triệu" | 2 khoản | LỆCH |
| C8 | `tim {nam_nay, khoan_thu, tu 5000000}` ✓✓ | *"Có 2 khoản thu từ 5.000.000 đ trở lên…: Lương (9.000.000 đ ngày 04/09) và Lương (5.000.000 đ ngày 04/09)."* | 2 | ✅ |
| C9 | `tim {thang_nay, den 1000000, tu_khoa: "chi"}` — y hệt lần 2 | **L2c**: *"Tháng này, ghi chú chứa "chi", đến 1.000.000 đ — không có giao dịch nào khớp."* | **2** khoản | mẫu câu nêu bộ lọc, bộ lọc **lệch — và người đọc thấy lệch ở đâu**. **Hết SAI** (bẫy 4.44 ✅) |
| C10 | `chi_tieu_theo_ky` ✗ | tổng thu 15.135.000 | 8 khoản thu | LỆCH |
| C11 | `tim {thang_nay, chuyen_vi, vi: "tiet_kiem"}` ✓✓ (tên `_` nay khớp) | **L2**: *"Tháng này, chuyển ví, ví "Tiết kiệm" — Tích lũy mục tiêu: MuaXe … 900.000 đ, Ngày 05/09; … Số khoản: 10; Tổng chuyển: 2.501.000 đ."* — chữ mô hình *"bạn đã có **4** giao dịch chuyển tiền sang ví Tiết kiệm"* bị `kiemSo` chặn (bẫy 4.46) | 10 khoản, 2.501.000 | mẫu câu có ích, **đúng** (bẫy 4.45 ✅; lần 2 L1b) |
| C12 | `chi_tieu_theo_ky` ✗ | Tổng chi + 4 danh mục, không nhắc Ăn uống | 1 (50.000) | LỆCH |
| C13 | `chi_tieu_theo_ky` ✗ | 2.141.000 (mọi ví) | 13 khoản, 2.031.000 | LỆCH |
| C14 | `chi_tieu_theo_ky` ✗ | 2.141.000 | Mua sắm 60.000 | LỆCH |
| C15 | `tim {moi_luc, chuyen_vi, moi_nhat}` sai `chieu` | **L2**: *"Mọi thời gian, chuyển ví, mới nhất trước — …MuaXe chuyển ví…"* — chữ mô hình *"Lần gần nhất bạn chi cho chuyển tiền là ngày 08/09"* bị chặn (không nêu tên hàng) | 20/09 · 50.000 | mẫu câu lệch — tiền tố nay **lộ "chuyển ví"** |
| C16 | `tim {moi_luc, moi_nhat}` thiếu `chieu` | **L2**: *"Mọi thời gian, mới nhất trước — Di chuyển khoản chi 50.000 20/09; Cho vay khoản thu 500.000…; Số khoản: 36…"* — chữ mô hình *"Dưới đây là **4** giao dịch chi tiêu gần nhất"* bị chặn (4.46) | 4 khoản chi | mẫu câu lệch (lẫn khoản thu; tiền tố không nêu chiều → lộ) |
| C17 | `tim {moi_luc, tu_khoa: hoa don}` ✓✓ | *"Có 5 giao dịch có ghi chú "hoa don": …"* bốn dòng + *"Tổng chi là 311.000 đ."* | 5 khoản | ✅ |
| C18 | `chi_tieu_theo_ky` ✗ | Cho vay 800.000 | Cho vay 800.000 | ✅ (trùng do may) |
| C19 | `tim {moi_luc, khoan_chi}` thiếu `danh_muc`, `vi` | *"Tổng chi cho giao dịch là 2.141.000 đ. Các giao dịch chi tiêu bao gồm: Cho vay…"* | 2 khoản, 45.000 | LỆCH |
| C20 | `danh_sach_muc_tieu` ✗ | *"…Tôi không có thông tin về ngày nạp tiền gần nhất…"* | 08/09 | LỆCH (trung thực) |
| ĐC3 | `chi_tieu_theo_ky` ✗ | *"Không có dữ liệu chi tiết cho danh mục "abc" trong kỳ tháng này. Tổng chi … 2.141.000 đ."* | không có *abc* | trượt tiêu chí (chữ mô hình hiện), nội dung đúng — như lần 2 |

**Cột phân tích:** L2c **4** (C3, C4, C6, C9 — bộ lọc khớp câu hỏi 2, lệch 2); L2 **3** (C11, C15, C16 — cả ba
vì chữ mô hình trượt `kiemSo`/`kiemNhan`); L1b **1** (B2); L2b **0**; gọi lại sau lời từ chối **0/1**; chọn
`moi_luc` **4** (C15, C16, C17, C19); thiếu `ky` **0**; mọi câu đúng **một** lời gọi; C1 và C7 chờ hết 240 s của
`hoi.sh` (câu đầu hiện rồi câu sau bị chặn — vòng lặp `return` không in dòng kết, đúng thiết kế).

**Đọc kết quả.** Hai bẫy chữa **trúng và đúng như thiết kế**: C9 từ SAI thành một câu nói ra bộ lọc đã hẹp ở
đâu; C11 từ *"chưa tra được"* thành 10 khoản đúng đáp án. Nhưng cổng D dòng 3 **không nhúc nhích** vì mô hình
chọn tool và điền tham số **y hệt lần 2 ở cả 20 câu** — bước 2c không chạm mô tả tool, và đo được là mô hình
lặp lại chính nó khi mô tả không đổi. Thứ còn lại để kéo dòng 3 là **mô tả / tên tool** — đòn bẩy để dành từ
spec 2b (đổi tên `chi_tieu_theo_ky`) — **hỏi người dùng**. Lộ thêm bẫy **4.46**: mô hình đọc số dòng hiện thành
số khoản, `kiemSo` chặn đúng nhưng đó là lý do một câu đúng tool, đúng tham số (C11) vẫn rơi mẫu câu. ĐC3 vẫn
trượt tiêu chí đã khai (chữ mô hình hiện ở lượt `chi_tieu_theo_ky`, nội dung đúng) — chỉ đóng được khi mô hình
gọi `tim_giao_dich` với `danh_muc: abc`, tức cũng là chuyện chọn tool.

**Theo spec 2c mục 5 bước 5:** dòng 3 dưới ngưỡng → đề xuất đổi tên `chi_tieu_theo_ky` — **hỏi người dùng
trước**; **chưa mở bước 3**. *(Người dùng duyệt đổi tên ngay cùng chiều — mục 9.20.)*

### 9.20 Đổi tên tool `chi_tieu_theo_ky` → `tong_ket_thu_chi_ky` (2026-09-24 chiều) — 🛑 CỔNG D CHƯA ĐẠT (lần đo 4): tool 10 → 13, SAI 0 → 2

Đòn bẩy để dành từ spec 2b mục 1.2 hàng 10, người dùng duyệt sau lần đo 3; việc **bounded**, không spec: chỉ đổi
**tên** (hằng `kTenCongCuTongKet`, chỉ báo *"Đang tổng kết thu chi…"*, mô tả chéo ở `tim_giao_dich`), **mô tả giữ
nguyên** để tách tác dụng của tên. Tên chọn *"tổng kết thu chi kỳ"* vì 9 câu chọn nhầm ở lần 2–3 đều chứa chữ
*chi / tiêu* và tên cũ khớp thẳng chữ ấy. Commit `61f66ba`; +1 ca `bo_cong_cu_test` (tên tool không chứa `chi_tieu`);
`tools_json` 5.431 → **5.437** — spike ba phiên dài nhất trên Realme (14:33: S1 3 lời gọi · S2 2 · S3 2, 0
`FAILED_PRECONDITION`) rồi mới nâng `kTranToolsJsonDaDo`. `flutter test` **3756/3756**, 3 skip; `analyze` 26.

**Cổng D lần 4** (Realme, APK release `61f66ba`, tài khoản 10, 14:33–15:01, 34 câu, 28 phút, đáp án như lần 3).

| Dòng | Lần 2 | Lần 3 | **Lần 4** | |
|---|---|---|---|---|
| 1. Nhóm A | 8/8 | 8/8 | **8/8** (A8 liệt kê 4 danh mục "lớn nhất", tên đúng đứng đầu; ĐC1 gọi `nam_nay`, không bịa) | ✅ |
| 2. Nhóm B | 2/4 | 2/4 | **2/4** — 1c nay là mẫu câu **nêu di h0c 10.000 đ** (L2), chữ mô hình *"Hoa hồng cần trả là 155.000 đ"* bị chặn | ✗ |
| 3. Nhóm C | 10 · 4 | 10 · 5 | **13/20 tool · 6/20 tham số** — C2, C5, C12 chuyển sang `tim_giao_dich`; sáu câu còn gọi tổng kết đều có **điều kiện** (trên 500k · hơn nửa triệu · cho mua sắm từ ví · khoản thu nào · ví tiền mặt) | ✗ |
| 4. SAI · sập | 1 | 0 | **2 SAI** (C7, C10) · 0 sập | ✗ |
| 5. Trần | 0 | 0 | **0** (5.437) | ✅ |

| # | Lời gọi đầu | Câu hiện ra (rút gọn) | Chấm |
|---|---|---|---|
| C2 | **`tim {hom_qua, khoan_chi}`** ✓✓ | L2c *"Hôm qua, khoản chi — không có giao dịch nào khớp."* | mẫu câu nêu bộ lọc, đúng |
| C5 | **`tim {tuan_truoc}`** thiếu `chieu` | L2 mẫu câu 4 dòng lẫn khoản thu, *Số khoản: 6; Tổng chi: 1.096.000 đ* — chữ *"bạn đã có 6 giao dịch"* bị `kiemNhan` chặn (nhãn *Số khoản* đòi chữ "khoản") | mẫu câu lệch (lần 3 ✅ theo danh mục) |
| C7 | tổng kết ✗ | *"Các khoản chi có giá trị hơn **một triệu** là: Cho vay (800.000 đ), Chưa phân loại (500.000 đ), Di chuyển (355.000 đ), Chi khác (301.000 đ)."* — lần 2/3 bị chặn nhờ chữ số "1 triệu"; lần này viết **bằng chữ** → `kiemSo` không có gì để chặn | **SAI** (4.42) |
| C9 | `tim {thang_nay, khoan_chi, den 1000000, tu_khoa: 200000}` | L1b *"chưa hiểu số tiền trong câu hỏi"* (200000 nằm ở `tu_khoa`) | mẫu câu trung thực |
| C10 | tổng kết ✗ | *"Các **khoản thu** bao gồm: Cho vay (800.000 đ), Chưa phân loại (500.000 đ), Di chuyển…"* — danh mục **chi** gán là khoản thu | **SAI** (4.42) |
| C12 | **`tim {thang_nay, khoan_chi}`** thiếu `danh_muc` | L2 mẫu câu *"Tháng này, khoản chi — …; Số khoản: 18"* — chữ *"có 4 khoản chi"* bị chặn (4.46) | mẫu câu lệch (tiền tố lộ thiếu danh mục) |
| C16 | `tim {moi_luc, moi_nhat}` thiếu `chieu` | chữ mô hình **hiện**: *"Giao dịch chi gần nhất: Di chuyển 50.000 đ 20/09. Cho vay 800.000 đ 19/09."* | LỆCH (đúng 2, hỏi 5) |
| C17 | `tim {moi_luc, tu_khoa: hoa don}` ✓✓ | L2 mẫu câu — chữ *"Có 5 giao dịch có ghi chú "hoa don"."* bị `kiemNhan` chặn (lần 3 câu dài hơn chứa "khoản" nên lọt) | mẫu câu có ích, đúng |
| C19 | `tim {moi_luc, khoan_chi, tu_khoa: "giao duc tu vi test"}` | L2c *"…ghi chú chứa "giao duc tu vi test" — không có giao dịch nào khớp."* | mẫu câu nêu bộ lọc, lệch (cả cụm câu hỏi vào `tu_khoa`) |
| còn lại | như lần 3 | C1, C13, C14, C20 LỆCH · C3, C4, C6 L2c đúng · C8, C18 ✅ · C11 mẫu câu đúng (4.46) · C15 mẫu câu lệch · ĐC3 trượt tiêu chí | |

**Cột phân tích:** nội dung đúng **8/20** (lần 3: 9 — C5 từ ✅ thành mẫu câu lệch) · L2c 5 · L2 **6** (lần 3: 3) ·
L1b 2 · gọi lại sau từ chối 0/2 · `moi_luc` 4 · tổng kết còn được gọi 6 câu C + ĐC3 (lần 3: 9 + ĐC3).

**Đọc kết quả.** (1) Đổi tên **có** tác dụng nhưng nhỏ: ba câu ngắn kiểu *"chi những gì / liệt kê"* chuyển sang
`tim_giao_dich`; sáu câu còn lại có **điều kiện lọc** (số tiền, danh mục, ví, chiều thu) vẫn về tổng kết. (2) **Hai
SAI không do đổi tên** — chúng là bẫy **4.42** hiện nguyên hình: cùng câu ấy lần 2/3 bị chặn **do may** (chữ số của
câu hỏi lọt vào câu trả lời), lần này mô hình viết *"một triệu"* bằng **chữ** (C7) hoặc không nêu số điều kiện (C10)
nên ba lớp chắn không có gì để bắt; lớp chắn kiểm số và nhãn, không kiểm **mệnh đề**. (3) Chặn hiển thị **tăng** vì
tool đúng nhiều hơn mà chữ mô hình trượt `kiemNhan`: nhãn **`Số khoản`** đòi chữ *"khoản"* trong khi mô hình nói
*"giao dịch"* (C5, C17 — bẫy **4.47**), cộng 4.46 (C11, C12). Đổi nhãn thành *"Số giao dịch"* là một chữ ở
`hangGiaoDich` và cứu được hai câu đúng. (4) Cả ba lần đo, `tim_giao_dich` chưa từng nhận `so_tien_tu` đúng cho
câu *"từ 200k đến 1 triệu"* — số đầu luôn rơi vào `tu_khoa`.

**Việc tiếp theo — chờ người dùng quyết** (không nằm trong spec nào): (a) đổi nhãn `Số khoản` → `Số giao dịch` (4.47,
rẻ); (b) bắt số viết bằng chữ ở `kiemSo` (*"một triệu"*, *"nửa triệu"*) hoặc lớp chắn mệnh đề — 4.42; (c) mô tả tool
tổng kết thêm câu *"câu có điều kiện số tiền / danh mục / ví thì dùng tim_giao_dich"* (đã có nhưng chưa dẫn được);
(d) dừng đo, chuyển bước 3. *(Người dùng chọn (a) — mục 9.21.)*

### 9.21 Đổi nhãn đếm `Số khoản` → `Số giao dịch` (2026-09-24 chiều muộn) — 🛑 CỔNG D CHƯA ĐẠT (lần đo 5): bẫy 4.47 chỉ ĐỔI CHỖ

Bounded, không spec: một chữ ở `hangGiaoDich` (`a68a842`, +1 ca `hang_giao_dich_test` canh câu *"có 7 giao dịch"*
qua `kiemNhan`); `flutter test` **3757/3757**, 3 skip; `analyze` 26. Cổng D lần 5 (Realme, APK `a68a842`, 15:52–16:20,
34 câu, 28 phút, đáp án như lần 3). **Lời gọi tool y hệt lần 4 ở cả 34 câu** — đúng như kỳ vọng vì nhãn không vào
khai báo tool.

| Dòng | Lần 4 | **Lần 5** | |
|---|---|---|---|
| 1. Nhóm A | 8/8 | **8/8** | ✅ |
| 2. Nhóm B | 2/4 | **2/4** | ✗ |
| 3. Nhóm C | 13 · 6 | **13/20 · 6/20** (y hệt) | ✗ |
| 4. SAI · sập | 2 | **2** (C7, C10 y hệt) · 0 | ✗ |
| 5. Trần | 0 | **0** | ✅ |

**Chỉ bốn câu đổi cách hiện, tất cả do nhãn:**

| # | Lần 4 | **Lần 5** | Chấm |
|---|---|---|---|
| C5 | chữ *"bạn đã có 6 giao dịch"* bị chặn → mẫu câu | chữ **hiện**: *"Trong tuần trước, bạn đã có 6 giao dịch. Tổng chi là 1.096.000 đ và tổng thu là 510.000 đ."* | LỆCH (số đúng, không liệt kê khoản, đếm cả thu) |
| C8 | chữ **hiện** ✅ *"Có 2 khoản thu từ 5.000.000 đ trở lên…"* | chữ ấy **bị chặn** (nhãn mới đòi chữ "giao dịch", câu nói "khoản thu") → L2 mẫu câu *"Năm nay, khoản thu, từ 5.000.000 đ — Lương…; Số giao dịch: 2; Tổng thu: 14.000.000 đ."* | mẫu câu có ích, đúng (mất một ✅) |
| C12 | mẫu câu lệch | chữ hiện *"Các khoản chi bao gồm: Cho vay…"* (không Ăn uống) | LỆCH |
| C17 | chữ bị chặn → mẫu câu | chữ **hiện** ✅ *"Có 5 giao dịch có ghi chú "hoa don". Tổng chi là 311.000 đ."* | ✅ (được một ✅) |
| C16 | chữ hiện 2 khoản (LỆCH) | chữ *"Danh sách 5 giao dịch chi gần nhất…"* bị chặn ("5" của câu hỏi, gói có 36) → mẫu câu lệch | mẫu câu lệch |

Nội dung đúng **8/20** (y hệt lần 4). **Kết luận:** bẫy 4.47 không phải chuyện chọn nhãn nào — `kiemNhan` đòi câu
chứa từ khoá của **một** nhãn, còn mô hình dùng *"khoản"* và *"giao dịch"* thay nhau cho cùng một con số. Nhãn cũ chặn
C5/C17, nhãn mới chặn C8: thứ cần là nhãn có **từ đồng nghĩa** (câu chứa "khoản" **hoặc** "giao dịch" đều qua), tức
`SoLieu` mang thêm danh sách nhãn thay thế cho `kiemNhan`/`theCuaCau` — một thay đổi ở tầng chắn, cần spec ngắn. Giữ
nhãn *Số giao dịch* (đúng chữ tool `tim_giao_dich` và câu hỏi người dùng) cho tới khi có từ đồng nghĩa.

**Việc tiếp theo — chờ người dùng quyết:** (a) nhãn có từ đồng nghĩa ở `kiemNhan` (4.47 gốc); (b) bắt số viết bằng
chữ / lớp chắn mệnh đề (4.42 — hai SAI C7, C10 đứng yên ba lần); (c) dừng đo, mở bước 3. *(Người dùng chọn (a) —
mục 9.22.)*

### 9.22 Nhãn có từ đồng nghĩa — `SoLieu.nhanKhac` (2026-09-24 chiều muộn) — ✅ mã xong, ✅ đã đo tối cùng ngày (cổng D lần 6 — mục 9.23: bẫy 4.47 đóng, cổng vẫn chưa đạt)

Bounded, thiết kế duyệt trong chat (`235d11f`): `SoLieu` thêm **`nhanKhac`** (danh sách nhãn thay thế, mặc định
rỗng — 27 chỗ dựng `SoLieu` không đổi); `soTien` / `soDem` nhận tham số cùng tên. **`nhanKhopAmTiet(s, amTiet)`**
(`kiem_nhan.dart`) là **một** phép cho cả `kiemNhan` (vế mục không tên) lẫn `theCuaCau` (`_cauNhacToi`): câu nêu đủ
từ khoá của nhãn chính **hoặc** của một nhãn thay thế thì qua. `hangGiaoDich`: `soDem('Số giao dịch', soKhop,
nhanKhac: ['Số khoản'])`. JSON, mẫu câu và thẻ vẫn in nhãn chính. Chỉ áp cho nhãn đếm này. Test: **+5** ca
(`kiem_nhan_test` nhóm *"nhãn có TỪ ĐỒNG NGHĨA"* 4 ca — câu *"2 khoản thu"* qua, *"2 giao dịch"* qua, không nhãn thay thế
thì *"2 khoản"* chặn, nhãn thay thế không mở cửa cho *"2 hoá đơn"*; `the_cua_cau_test` 1 ca — thẻ nhận mục qua nhãn
thay thế và in nhãn chính, trong khi gói hoá đơn đứng trước cùng giá trị 2); ca đối chứng cũ ở `hang_giao_dich_test`
**lật** (*"7 khoản"* nay qua). Một bản sai (`nhanKhopAmTiet` bỏ `nhanKhac`) làm đỏ đúng 3 ca ở 3 tệp. `ai_edge` +
`ai_chat` **598** ca.

**Dự đoán cho lần đo 6** (viết khi chưa đo — người dùng dặn *"làm tới phần build và cài, còn chạy 34 câu thì dừng lại để
phiên sau"*): lời gọi tool y hệt lần 4–5 (nhãn không vào khai báo); C8 hiện chữ trở lại, C5/C17 giữ; nội dung đúng
nhóm C kỳ vọng **9/20**; SAI vẫn **2** (C7, C10 — 4.42 chưa chạm). Nếu lần 6 ra đúng thế thì đòn bẩy còn lại cho cổng
D là **4.42** (số viết bằng chữ / mệnh đề) và **mô tả tool cho câu có điều kiện**. *(Kết quả ở mục 9.23: đúng ở mọi
vế trừ con số **9/20** — đó là lỗi đếm, C8 vốn đã nằm trong 8 câu đúng của lần 5 dưới dạng mẫu câu.)*

### 9.23 Cổng D lần đo 6 (2026-09-24 tối) — 🛑 VẪN CHƯA ĐẠT, ✅ bẫy 4.47 ĐÓNG, 33/34 câu y hệt lần 5

Realme, APK `235d11f` (release, cài 16:41), 21:54–22:19, **34 câu, 26 phút, 0 sập, 0 vỡ trần** (`tools_json` 5437 ở
cả 34 phiên). Đáp án như lần 3 — cùng ngày, dữ liệu máy không đổi; bằng chứng không phải giả định: **33/34 câu trả lời
hiện ra trùng từng ký tự với lần 5** (so bản ghi `uiautomator` theo từng câu hỏi), kể cả các mẫu câu in số.
**Lời gọi tool và tham số y hệt lần 5 ở cả 34 câu** — ba lần liền (4, 5, 6) mô hình lặp lại chính nó khi khai báo
tool không đổi, đúng như 9.19 đã thấy.

| Dòng | Lần 5 | **Lần 6** | |
|---|---|---|---|
| 1. Nhóm A | 8/8 | **8/8** | ✅ |
| 2. Nhóm B | 2/4 | **2/4** | ✗ |
| 3. Nhóm C | 13 · 6 | **13/20 · 6/20** (y hệt) | ✗ |
| 4. SAI · sập | 2 | **2** (C7, C10 y hệt) · 0 | ✗ |
| 5. Trần | 0 | **0** | ✅ |

**Câu duy nhất đổi — C8**, và đổi đúng hướng: chữ mô hình *"Có 2 khoản thu từ 5.000.000 đ trở lên trong năm nay: Lương
(9.000.000 đ ngày 04/09) và Lương (5.000.000 đ ngày 04/09)."* **hiện** (lần 5 bị `kiemNhan` chặn vì nhãn *Số giao
dịch* mà câu nói *"khoản thu"*), thẻ *"Số giao dịch 2"* đứng đầu — thẻ nhận mục qua nhãn thay thế và in nhãn chính,
đúng ca `the_cua_cau_test`. Đáp án: 2 khoản, Lương 9.000.000 + 5.000.000 ngày 04/09 → ✅. Log tool: dòng C8 là dòng
**duy nhất** khác giữa `tool_congD5.txt` và `tool_congD6.txt` (hết `chặn [...]`, `1g/1c`).

**Bảng 34 câu** (câu hỏi gõ không dấu; câu trả lời **nguyên văn** hiện trên màn, thẻ số liệu bỏ; chấm theo câu hiện ra):

| # | Câu hỏi | Câu trả lời hiện ra | Chấm |
|---|---|---|---|
| A13 | Hoa don nao qua han? | Có 2 hóa đơn quá hạn: Kiem với số tiền 45.000 đ và di h0c với số tiền 10.000 đ. Tổng cộng còn phải trả 155.000 đ. | ✅ |
| A15 | Vi nao dang am? | Ví test đang âm với số dư là -100.000 đ. | ✅ |
| A8 | Thang nay toi chi nhieu nhat vao danh muc nao? | Trong tháng này, tổng chi là 2.141.000 đ. Các danh mục chi lớn nhất là: Cho vay (800.000 đ), Chưa phân loại (500.000 đ), Di chuyển (355.000 đ), và Chi khác (301.000 đ). | ✅ (tên đúng đứng đầu, liệt kê 4) |
| A3 | Ngan sach nao sap het? | Danh sách ngân sách sắp hết là: Giáo dục (Còn: 7 ngày, Còn lại: 5.000 đ). | ✅ |
| A2 | Con bao nhieu tien ngan sach thang nay? | Tổng còn lại của các ngân sách là 1.340.000 đ. | ✅ |
| A9 | Thang truoc toi chi bao nhieu? | Tháng trước bạn chi tổng cộng 0 đ. | ✅ |
| ĐC1 | Lai suat tiet kiem cua toi la bao nhieu? | Tổng thu của bạn trong năm nay là 15.135.000 đ và tổng chi là 2.141.000 đ. | không bịa ✓ — LỆCH (không nói "không có") |
| ĐC2 | Thang nay toi chi bao nhieu? | Tổng chi trong tháng này là 2.141.000 đ. | ✅ |
| B1 | khi nao toi dat muc tieu muaxe | Bạn có hai mục tiêu đang theo đuổi: "MuaXe" và "MuaDT". | LỆCH |
| B2 | moi thang toi can de danh bao nhieu cho muaxe | Chưa tra được số liệu cho câu này: không có danh mục chi nào tên "muaxe". Bạn thử hỏi lại cụ thể hơn. | L1b mẫu câu trung thực (vẫn gọi `goi_y_han_muc`) |
| B3 | thang sau toi nen dat ngan sach bao nhieu | Dựa trên dữ liệu gần nhất, bạn có thể xem xét đặt ngân sách cho các danh mục sau: Di chuyển (490.000 đ), Mua sắm (90.000 đ), Giáo dục (70.000 đ), và Ăn uống (70.000 đ). | ✅ |
| B4 | ngan sach an uong nen dat bao nhieu | Dựa trên dữ liệu gần nhất, mức chi trung bình mỗi tháng cho danh mục "Ăn uống" là 70.000 đ. | ✅ (câu 2 *"Hạn mức hiện tại là 500.000 đ"* bị `kiemNhan` chặn — không nêu tên Ăn uống) |
| B1c | hoa don di h0c con phai tra bao nhieu | Kiem đã quá hạn: Số tiền 45.000 đ; di h0c đã quá hạn: Số tiền 10.000 đ; Netflix chưa trả: Số tiền 100.000 đ; Còn phải trả: 155.000 đ; Quá hạn: 2; Chưa trả: 3. | L2 mẫu câu có ích, nêu di h0c (chữ *"Hoa hồng cần trả là 155.000 đ"* bị chặn) — "câu 1c hiện" vẫn ✗ |
| C1 | thang nay toi tieu gi tren 500k | Tổng chi trong tháng này là 2.141.000 đ. | LỆCH (đáp án 2 khoản; gọi tổng kết) |
| C2 | hom qua toi da chi nhung gi | Hôm qua, khoản chi — không có giao dịch nào khớp. | L2c mẫu câu nêu bộ lọc, khớp — ✅ (đáp án 0) |
| C3 | hom nay toi co giao dich nao khong | Hôm nay — không có giao dịch nào khớp. | L2c khớp — ✅ (0) |
| C4 | tuan nay co khoan chi nao duoi 100 nghin khong | Tuần này, khoản chi, đến 100.000 đ — không có giao dịch nào khớp. | L2c khớp — ✅ (0) |
| C5 | tuan truoc toi da tieu nhung khoan nao | Trong tuần trước, bạn đã có 6 giao dịch. Tổng chi là 1.096.000 đ và tổng thu là 510.000 đ. | LỆCH (tổng chi đúng; không liệt kê khoản, đếm cả thu — thiếu `chieu`) |
| C6 | thang truoc toi co khoan chi nao tren 1 trieu khong | Tháng trước, từ 1.000.000 đ — không có giao dịch nào khớp. | L2c thiếu chiều, kết quả vẫn đúng — ✅ (0) |
| C7 | cac khoan chi hon nua trieu trong quy nay | Tổng chi trong quý này là 2.141.000 đ. Các khoản chi có giá trị hơn một triệu là: Cho vay (800.000 đ), Chưa phân loại (500.000 đ), Di chuyển (355.000 đ), và Chi khác (301.000 đ). | **SAI** (4.42 — *"hơn một triệu"* viết bằng chữ, bốn danh mục đều dưới một triệu; đáp án 2 khoản > 500k) |
| C8 | nam nay toi co khoan thu nao tu 5 trieu tro len khong | Có 2 khoản thu từ 5.000.000 đ trở lên trong năm nay: Lương (9.000.000 đ ngày 04/09) và Lương (5.000.000 đ ngày 04/09). | ✅ chữ mô hình (lần 5 mẫu câu) |
| C9 | liet ke cac khoan chi tu 200k den 1 trieu thang nay | Chưa tra được số liệu cho câu này: chưa hiểu số tiền trong câu hỏi. Bạn thử hỏi lại cụ thể hơn. | L1b mẫu câu trung thực (`tu_khoa: 200000` bị từ chối; đáp án 2 khoản) |
| C10 | thang nay toi nhan duoc nhung khoan thu nao | Trong tháng này, tổng thu là 15.135.000 đ. Các khoản thu bao gồm: Cho vay (800.000 đ), Chưa phân loại (500.000 đ), Di chuyển (355.000 đ), và Chi khác (301.000 đ). | **SAI** (4.42 — gán danh mục CHI làm "khoản thu"; đáp án 8 khoản thu) |
| C11 | thang nay toi da chuyen tien sang vi tiet kiem nhung lan nao | Tháng này, chuyển ví, ví "Tiết kiệm" — Tích lũy mục tiêu: MuaXe … 900.000 đ, 05/09; … MuaDT 700.000 đ, 05/09; Rút từ mục tiêu: MuaDT 300.000 đ, 05/09; … MuaXe 100.000 đ, 08/09; Số giao dịch: 10; Tổng chuyển: 2.501.000 đ. | L2 mẫu câu có ích — ✅ (10 khoản, 2.501.000; chữ *"4 giao dịch"* bị chặn — 4.46) |
| C12 | liet ke cac khoan an uong thang nay | Tổng chi trong tháng này là 2.141.000 đ. Các khoản chi bao gồm: Cho vay (800.000 đ), Tích lũy mục tiêu: MuaXe (500.000 đ), Di chuyển (180.000 đ), và Thanh toán hóa đơn: Kiem thu hoa don 2026-09-04 (123.000 đ). | LỆCH (không Ăn uống; đáp án 1 khoản 50.000; thiếu `danh_muc`) |
| C13 | vi tien mat thang nay chi nhung gi | Tổng chi trong tháng này là 2.141.000 đ, bao gồm các khoản: Cho vay (800.000 đ), Chưa phân loại (500.000 đ), Di chuyển (355.000 đ), và Chi khác (301.000 đ). | LỆCH (mọi ví; đáp án 13 khoản, 2.031.000) |
| C14 | thang nay toi chi gi cho mua sam tu vi tien mat | Tổng chi của bạn trong tháng này là 2.141.000 đ. | LỆCH (đáp án Mua sắm 60.000) |
| C15 | lan gan nhat toi chi cho di chuyen la ngay nao | Mọi thời gian, chuyển ví, mới nhất trước — Tích lũy mục tiêu: MuaXe … 100.000 đ, 08/09; … 100.000 đ, 08/09; … 1.000 đ, 07/09; … 100.000 đ, 07/09; Số giao dịch: 10; Tổng chuyển: 2.501.000 đ. | mẫu câu lệch (sai chiều; đáp án 20/09 · 50.000; tiền tố lộ "chuyển ví") |
| C16 | 5 khoan chi gan day nhat cua toi | Mọi thời gian, mới nhất trước — Di chuyển khoản chi … 50.000 đ, 20/09; Cho vay khoản thu … 500.000 đ, 19/09; Cho vay khoản chi … 800.000 đ, 19/09; Thưởng khoản thu … 10.000 đ, 19/09; Số giao dịch: 36; Tổng chi: 2.141.000 đ; Tổng thu: 15.135.000 đ; Tổng chuyển: 2.501.000 đ. | mẫu câu lệch (thiếu chiều, lẫn khoản thu; chữ *"Danh sách 5 giao dịch"* bị chặn — "5" của câu hỏi) |
| C17 | tim cac giao dich co ghi chu hoa don | Có 5 giao dịch có ghi chú "hoa don". Tổng chi là 311.000 đ. | ✅ |
| C18 | khoan chi lon nhat thang nay la gi | Khoản chi lớn nhất trong tháng này là "Cho vay" với số tiền là 800.000 đ. | ✅ (trùng do may — gọi tổng kết) |
| C19 | cac khoan chi cho giao duc tu vi test | Mọi thời gian, khoản chi, ghi chú chứa "giao duc tu vi test" — không có giao dịch nào khớp. | L2c mẫu câu nêu bộ lọc, lệch (cả cụm câu hỏi nhét vào `tu_khoa`; đáp án 2 khoản 45.000) |
| C20 | lan cuoi toi nap tien cho muc tieu muaxe la ngay nao | Dựa trên thông tin, mục tiêu "MuaXe" còn 581 ngày. | LỆCH (đáp án 08/09; gọi `danh_sach_muc_tieu`) |
| ĐC3 | cac khoan chi cho danh muc abc thang nay | Không có dữ liệu chi tiết cho danh mục "abc" trong kỳ tháng này. Tổng chi cho tháng này là 2.141.000 đ. | trượt tiêu chí (chữ mô hình hiện), nội dung đúng — như lần 2–5 |

Tool đúng **13/20** · tham số đúng **6/20** (y hệt lần 4, 5). Nội dung đúng **8/20**: ✅ chữ mô hình **3** (C8 C17
C18 — lần 5: 2) + mẫu câu đúng **5** (C2 C3 C4 C6 C11 — lần 5: 6). **SAI 2** (C7, C10) · LỆCH 6 (C1 C5 C12 C13 C14
C20) · mẫu câu lệch 3 (C15 C16 C19) · L2c 5 · L2 **4** (B1c C11 C15 C16 — lần 5: 5, C8 rời) · L1b 2 (B2 C9).

**Chặn còn lại — năm câu, KHÔNG câu nào vì "khoản" / "giao dịch":** B4 câu 2 và B1c, C15 trượt `kiemNhan` vì
**không nêu tên** đối tượng (luật "mục có tên đòi câu nêu tên" — 4a); C11 là 4.46 (số dòng hiện); C16 là *"5"* của câu
hỏi, gói không có. → ✅ **Bẫy 4.47 ĐÓNG**: C5, C8, C17 cùng hiện chữ trong **một** lượt đo — lần 4 chặn C5/C17,
lần 5 chặn C8, nay không câu đúng nào rơi mẫu câu vì mô hình chọn chữ nào cho con số đếm.

**Đối chiếu dự đoán 9.22:** tool y hệt ✅ · C8 hiện ✅ · C5/C17 giữ ✅ · SAI 2 ✅ · *"nội dung đúng 9/20"* ✗ — **đếm
sai lúc dự đoán**: C8 ở lần 5 đã được tính trong 8 (mẫu câu có ích, đúng), nên lên bậc chữ mô hình **không** cộng
thêm; con số đúng là 8/20 với thành phần đổi (chữ 3 · mẫu câu 5). Bài học cũ: *đừng cộng dồn, hãy đếm lại*.

**Đọc kết quả.** Lát nhãn đồng nghĩa làm đúng việc của nó và **chỉ** việc của nó. Cổng D đứng yên ở dòng 3 và 4 vì
hai thứ lát này không chạm: (1) **4.42** — C7 *"hơn một triệu"* viết bằng **chữ**, C10 gán danh mục chi làm *"khoản
thu"*: số thật, tên thật, mệnh đề sai, ba lớp chắn không có gì để bắt; (2) **sáu câu có điều kiện** (C1 C7 C10 C13
C14 C18, cộng ĐC3) vẫn về `tong_ket_thu_chi_ky` dù mô tả đã dặn — và vì khai báo tool không đổi từ lần 4, mô hình
điền y hệt ba lần. Đo thêm lần nữa với cùng khai báo là vô ích.

**Việc tiếp theo — chờ người dùng quyết** (ba hướng còn lại của 9.20, (a) đã làm): (b) bắt số viết bằng chữ ở
`kiemSo` (*"một triệu"*, *"nửa triệu"*) và/hoặc lớp chắn mệnh đề — đóng 4.42, đưa SAI về 0; (c) sửa mô tả /
ví dụ của `tong_ket_thu_chi_ky` và `tim_giao_dich` cho câu có điều kiện — dòng 3; (d) dừng đo, mở bước 3 (đổi
bất biến ④, cần spec). *(Người dùng chọn (b) — mục 9.24.)*

### 9.24 Đóng bẫy 4.42 — số viết bằng chữ · nhãn xung đột (2026-09-24 đêm → 25 rạng sáng) — ✅ SAI = 0 ở lần đo 8, 🛑 cổng D vẫn chưa đạt dòng 2–3

Người dùng chọn hướng (b) sau lần đo 6. Bounded, thiết kế duyệt trong chat; **ba commit** vì lần đo 7 lộ hai lỗi thật:

- `b43d5ae` — **vế 1 (C7):** `trichSo` đọc cụm **toàn chữ** *số + đơn vị* (*nửa · một … mười* × *trăm · nghìn/ngàn ·
  triệu · tỷ/tỉ*, chuỗi đơn vị nhân nhau, nhóm liền nhau cộng lại, hậu tố *rưỡi*) thành con số; lượng từ mơ hồ (*vài,
  mấy, dăm*) thành `NaN` — không bao giờ khớp gói, tức bị chặn. Tách **trước** chữ số, cùng khuôn ngày tháng. ⚠️ **Cố ý
  không đụng** chữ số + đơn vị chữ (*"500 nghìn"*, *"2 triệu"*, *"500k"*) — người dùng chốt: hôm nay chúng trích thành
  500 / 2 và bị chặn vì không có trong gói; đọc thành 500.000 là mở cửa cho câu *"trên 500k là … (500.000 đ)"* của lần
  đo 2 lọt thành SAI. Hai chiều đều có lỗ, giữ chiều đang chặn được. **Vế 2 (C10):** `SoLieu.nhanXungDot` (đối xứng
  `nhanKhac`) — mục **có tên** bị chặn khi câu nêu đủ từ khoá của một nhãn xung đột mà **không** nêu từ khoá của nhãn
  chính hay nhãn thay thế (`ganNhanNguoc`, `kiem_nhan.dart`); khai ở hàng danh mục của tool tổng kết và gói Phân tích
  (`Chi` ↔ `['Thu']`) và hàng `tim_giao_dich` theo chiều dòng. Chữ hoa vì test quét 14 chỉ cấm chuỗi chiều tiền thường.
- `6ca112f` — **lần đo 7 lộ:** C10 **vẫn lọt** dù ca đơn vị với cùng câu đỏ→xanh. Trên máy câu bị tách theo câu, và câu
  thứ hai *"Các khoản thu bao gồm: … và **Chi khác** (301.000 đ)"* mang chữ "chi" **trong tên danh mục**, nên phép
  "câu có nêu nhãn Chi" thấy có. Sửa theo đúng khuôn bước 1c: tách `boTenDoiTuong` (`kiem_so.dart`) thành hàm dùng
  chung — `trichSoNgoaiTen` gọi lại với *chỉ tên có chữ số* như trước — và `kiemNhan` xét gán nhãn ngược trên câu **đã
  bỏ mọi tên**. Ca ⭐ là câu nguyên văn trên máy (ca cũ của tôi bỏ sót danh mục Chi khác).
- `986307c` — **lần đo 7 lộ lỗi thứ hai, chiều ngược:** câu **đúng** C12 *"Các khoản chi bao gồm: … Thanh toán hóa đơn:
  Kiem **thu** hoa don (123.000 đ)"* bị chặn **oan** — "thu" nằm trong tên hoá đơn bị đọc là gán ngược, và nhãn chính
  của hàng `tim_giao_dich` là *Số tiền*, thứ không bao giờ xuất hiện trong câu tự nhiên, nên chữ "chi" của câu không
  cứu được. Nay chiều của dòng là **nhãn thay thế** và chiều ngược là **nhãn xung đột** (`_nhanChieu` / `_nguoc`,
  `hang_giao_dich.dart`); câu trộn thu và chi có ca canh. Khoản chuyển cố ý không khai — người dùng vẫn gọi tiền
  chuyển đi là "chi".

Test: **+21** ca ở **5** tệp đã có (`kiem_so_test` 8 · `kiem_nhan_test` 10 · `hang_chi_tieu_test`, `hang_giao_dich_test`,
`goi_so_phan_tich_test` 1 mỗi tệp), không thêm tệp; ba bản sai có chủ ý (từ số không cần đơn vị · bỏ vế `ganNhanNguoc`)
làm đỏ đúng ca; hai ca canh biên xanh sẵn được kiểm bằng bản sai. `flutter test` **3783/3783**, 3 skip; `analyze` 26;
`ai_edge` + `ai_chat` **55 / 619**. ⚠️ **Hai lượt `flutter build apk` chạy song song với `flutter test` thất bại ở
Gradle** (`assembleRelease failed with exit code 1`) mà `| tail -2` che mất và `ls` cho mã thoát 0 — suýt đo lần 8 bằng
APK cũ; phát hiện nhờ so `LastWriteTime` (23:00 của lần 7). Build một mình thành công; **so SHA-1** trước khi cài.

**Lần đo 7** (Realme, APK `b43d5ae`, 23:02–23:35, 33 phút, 0 sập): tool **y hệt lần 6 ở 34/34**; bản ghi 32/34 trùng lần
6 — C7 câu *"một triệu"* bị `kiemSo` chặn (**SAI → LỆCH** ✅), C12 bị chặn oan (lỗi mới, trên), C10 **vẫn SAI** (Chi
khác). **SAI 1**.

**Lần đo 8** (Realme, APK `986307c`, 23:47 → 00:20, 33 phút, 0 sập, 0 vỡ trần): tool **y hệt lần 5–8 ở 34/34** — bốn lần
liền. Vắt qua nửa đêm: nhóm A, B ngày 24/09, nhóm C ngày 25/09 — đáp án nhóm C **không đổi** (hai ngày ấy đều không có
giao dịch, cùng tuần ISO), chỉ C20 in *"còn 580 ngày"* thay 581. Bản ghi so lần 6: **31/34 trùng**; ba câu đổi đều
đúng hướng.

| Dòng | Lần 6 | Lần 7 | **Lần 8** | |
|---|---|---|---|---|
| 1. Nhóm A | 8/8 | 8/8 | **8/8** | ✅ |
| 2. Nhóm B | 2/4 | 2/4 | **2/4** | ✗ |
| 3. Nhóm C | 13 · 6 | 13 · 6 | **13/20 · 6/20** | ✗ |
| 4. SAI · sập | 2 | 1 | **0** · 0 | ✅ (ĐC3 vẫn trượt tiêu chí "chữ mô hình không hiện", nội dung đúng) |
| 5. Trần | 0 | 0 | **0** | ✅ |

**Bảng 34 câu lần 8** (câu trả lời nguyên văn trên màn, thẻ số liệu bỏ; ba mẫu câu liệt kê dài rút bằng "…"):

| # | Câu hỏi | Câu trả lời hiện ra | Chấm |
|---|---|---|---|
| A13 | Hoa don nao qua han? | Có 2 hóa đơn quá hạn: Kiem với số tiền 45.000 đ và di h0c với số tiền 10.000 đ. Tổng cộng còn phải trả 155.000 đ. | ✅ |
| A15 | Vi nao dang am? | Ví test đang âm với số dư là -100.000 đ. | ✅ |
| A8 | Thang nay toi chi nhieu nhat vao danh muc nao? | Trong tháng này, tổng chi là 2.141.000 đ. Các danh mục chi lớn nhất là: Cho vay (800.000 đ), Chưa phân loại (500.000 đ), Di chuyển (355.000 đ), và Chi khác (301.000 đ). | ✅ |
| A3 | Ngan sach nao sap het? | Danh sách ngân sách sắp hết là: Giáo dục (Còn: 7 ngày, Còn lại: 5.000 đ). | ✅ |
| A2 | Con bao nhieu tien ngan sach thang nay? | Tổng còn lại của các ngân sách là 1.340.000 đ. | ✅ |
| A9 | Thang truoc toi chi bao nhieu? | Tháng trước bạn chi tổng cộng 0 đ. | ✅ |
| ĐC1 | Lai suat tiet kiem cua toi la bao nhieu? | Tổng thu của bạn trong năm nay là 15.135.000 đ và tổng chi là 2.141.000 đ. | không bịa ✓ — LỆCH |
| ĐC2 | Thang nay toi chi bao nhieu? | Tổng chi trong tháng này là 2.141.000 đ. | ✅ |
| B1 | khi nao toi dat muc tieu muaxe | Bạn có hai mục tiêu đang theo đuổi: "MuaXe" và "MuaDT". | LỆCH |
| B2 | moi thang toi can de danh bao nhieu cho muaxe | Chưa tra được số liệu cho câu này: không có danh mục chi nào tên "muaxe". Bạn thử hỏi lại cụ thể hơn. | L1b mẫu câu trung thực |
| B3 | thang sau toi nen dat ngan sach bao nhieu | Dựa trên dữ liệu gần nhất, bạn có thể xem xét đặt ngân sách cho các danh mục sau: Di chuyển (490.000 đ), Mua sắm (90.000 đ), Giáo dục (70.000 đ), và Ăn uống (70.000 đ). | ✅ |
| B4 | ngan sach an uong nen dat bao nhieu | Dựa trên dữ liệu gần nhất, mức chi trung bình mỗi tháng cho danh mục "Ăn uống" là 70.000 đ. | ✅ (câu 2 *"Hạn mức hiện tại là 500.000 đ"* bị chặn — không nêu tên) |
| B1c | hoa don di h0c con phai tra bao nhieu | Kiem đã quá hạn: Số tiền 45.000 đ; di h0c đã quá hạn: Số tiền 10.000 đ; Netflix chưa trả: Số tiền 100.000 đ; Còn phải trả: 155.000 đ; Quá hạn: 2; Chưa trả: 3. | L2 mẫu câu có ích, nêu di h0c |
| C1 | thang nay toi tieu gi tren 500k | Tổng chi trong tháng này là 2.141.000 đ. | LỆCH |
| C2 | hom qua toi da chi nhung gi | Hôm qua, khoản chi — không có giao dịch nào khớp. | L2c khớp — ✅ (0) |
| C3 | hom nay toi co giao dich nao khong | Hôm nay — không có giao dịch nào khớp. | L2c khớp — ✅ (0) |
| C4 | tuan nay co khoan chi nao duoi 100 nghin khong | Tuần này, khoản chi, đến 100.000 đ — không có giao dịch nào khớp. | L2c khớp — ✅ (0) |
| C5 | tuan truoc toi da tieu nhung khoan nao | Trong tuần trước, bạn đã có 6 giao dịch. Tổng chi là 1.096.000 đ và tổng thu là 510.000 đ. | LỆCH |
| C6 | thang truoc toi co khoan chi nao tren 1 trieu khong | Tháng trước, từ 1.000.000 đ — không có giao dịch nào khớp. | L2c — ✅ (0) |
| **C7** | cac khoan chi hon nua trieu trong quy nay | Tổng chi trong quý này là 2.141.000 đ. | **LỆCH** (lần 4–6 SAI; câu *"hơn một triệu…"* bị `kiemSo` chặn) |
| C8 | nam nay toi co khoan thu nao tu 5 trieu tro len khong | Có 2 khoản thu từ 5.000.000 đ trở lên trong năm nay: Lương (9.000.000 đ ngày 04/09) và Lương (5.000.000 đ ngày 04/09). | ✅ |
| C9 | liet ke cac khoan chi tu 200k den 1 trieu thang nay | Chưa tra được số liệu cho câu này: chưa hiểu số tiền trong câu hỏi. Bạn thử hỏi lại cụ thể hơn. | L1b mẫu câu trung thực |
| **C10** | thang nay toi nhan duoc nhung khoan thu nao | Trong tháng này, tổng thu là 15.135.000 đ. | **LỆCH** (lần 4–7 SAI; câu *"Các khoản thu bao gồm: Cho vay…"* bị `kiemNhan` chặn) |
| C11 | thang nay toi da chuyen tien sang vi tiet kiem nhung lan nao | Tháng này, chuyển ví, ví "Tiết kiệm" — Tích lũy mục tiêu: MuaXe … 900.000 đ, 05/09; … Số giao dịch: 10; Tổng chuyển: 2.501.000 đ. | L2 mẫu câu có ích — ✅ |
| C12 | liet ke cac khoan an uong thang nay | Tổng chi trong tháng này là 2.141.000 đ. Các khoản chi bao gồm: Cho vay (800.000 đ), Tích lũy mục tiêu: MuaXe (500.000 đ), Di chuyển (180.000 đ), và Thanh toán hóa đơn: Kiem thu hoa don 2026-09-04 (123.000 đ). | LỆCH (y hệt lần 6 — chặn oan của lần 7 hết) |
| C13 | vi tien mat thang nay chi nhung gi | Tổng chi trong tháng này là 2.141.000 đ, bao gồm các khoản: Cho vay (800.000 đ), Chưa phân loại (500.000 đ), Di chuyển (355.000 đ), và Chi khác (301.000 đ). | LỆCH |
| C14 | thang nay toi chi gi cho mua sam tu vi tien mat | Tổng chi của bạn trong tháng này là 2.141.000 đ. | LỆCH |
| C15 | lan gan nhat toi chi cho di chuyen la ngay nao | Mọi thời gian, chuyển ví, mới nhất trước — Tích lũy mục tiêu: MuaXe … 100.000 đ, 08/09; … Số giao dịch: 10; Tổng chuyển: 2.501.000 đ. | mẫu câu lệch |
| C16 | 5 khoan chi gan day nhat cua toi | Mọi thời gian, mới nhất trước — Di chuyển khoản chi … 50.000 đ, 20/09; Cho vay khoản thu … 500.000 đ, 19/09; … Số giao dịch: 36; … | mẫu câu lệch |
| C17 | tim cac giao dich co ghi chu hoa don | Có 5 giao dịch có ghi chú "hoa don". Tổng chi là 311.000 đ. | ✅ |
| C18 | khoan chi lon nhat thang nay la gi | Khoản chi lớn nhất trong tháng này là "Cho vay" với số tiền là 800.000 đ. | ✅ (trùng do may) |
| C19 | cac khoan chi cho giao duc tu vi test | Mọi thời gian, khoản chi, ghi chú chứa "giao duc tu vi test" — không có giao dịch nào khớp. | L2c lệch |
| C20 | lan cuoi toi nap tien cho muc tieu muaxe la ngay nao | Dựa trên thông tin, mục tiêu "MuaXe" còn 580 ngày. | LỆCH (581 → 580 vì sang ngày) |
| ĐC3 | cac khoan chi cho danh muc abc thang nay | Không có dữ liệu chi tiết cho danh mục "abc" trong kỳ tháng này. Tổng chi cho tháng này là 2.141.000 đ. | trượt tiêu chí, nội dung đúng |

Nội dung đúng **8/20** (chữ 3 · mẫu câu 5) · **SAI 0** · LỆCH 8 (C1 C5 C7 C10 C12 C13 C14 C20) · mẫu câu lệch 3 · L2c 5 ·
L2 4 · L1b 2. ✅ **Bẫy 4.42 ĐÓNG trên máy thật**: hai câu SAI đứng yên bốn lần đo (4–7) nay thành LỆCH, và câu đúng
C12 không còn bị chặn oan.

**Đọc kết quả.** (1) Ba lớp chắn nay kiểm được **hai kiểu mệnh đề sai** mà trước đó mù: ngưỡng viết bằng chữ và gán
chiều ngược — vẫn là phép lọc từ vựng, không hiểu nghĩa, nhưng đúng ở chỗ có bằng chứng. (2) **Cả hai lỗi lần 7 cùng
một gốc**: nhãn xét trên câu còn nguyên **tên đối tượng**, mà tên mang "chi"/"thu" là chuyện thường (*Chi khác*, *Kiem
thu hoa don*, *Thu nợ*) — bài học 1c lặp lại ở lớp nhãn; và một nhãn chính mà câu tự nhiên không bao giờ nói (*Số
tiền*) thì phải có nhãn thay thế trước khi khai xung đột. Ba ca đơn vị của lát này xanh **không** bắt được hai lỗi ấy —
thứ bắt được là bản ghi máy thật. (3) Cổng D **đứng yên ở dòng 2 và 3**: tool/tham số y hệt **bốn lần liền** (5–8) —
đo thêm với cùng khai báo là vô ích; C7, C10 thành LỆCH chứ chưa thành đúng, vì mô hình vẫn gọi tổng kết cho câu có
điều kiện.

**Việc tiếp theo — chờ người dùng quyết** (hai hướng còn lại của 9.20): (c) sửa mô tả / ví dụ của
`tong_ket_thu_chi_ky` và `tim_giao_dich` cho sáu câu có điều kiện (C1 C7 C10 C13 C14 C18 + ĐC3) — dòng 3, cần spike
Realme vì `tools_json` dài hơn trần đã đo; (d) dừng đo, mở bước 3 (đổi bất biến ④, cần spec). *(Người dùng chọn (c) —
mục 9.25.)*

### 9.25 Định tuyến tool — ví dụ trong lời hệ thống · thứ tự · mô tả thu hẹp (2026-09-25 rạng sáng) — ✅ tool 18/20, ĐC3 đạt, 🛑 tham số 9/20, B 2/4

Người dùng chọn hướng (c) sau lần đo 8. Bounded, thiết kế duyệt trong chat, `5ee1a37`. Ba tín hiệu đổi trong **một**
bản (cố ý không tách, vì mỗi lần đo là 30 phút và cả ba đều là "phía prompt", đảo được bằng một commit):

1. **Ví dụ định tuyến trong `kPromptHeThongCongCu`** — lật quyết định *"không few-shot ở bậc tool, mô tả tool là thứ
   duy nhất dẫn E2B"* của spec 4b §3.4/§3.7: đó là **giả định chưa từng đo**, và lần 4–8 sáu câu có điều kiện gọi tổng
   kết **bốn lần liền** dù mô tả chéo (2b) đã dặn. Ví dụ là *câu hỏi kiểu nào → tool nào, tham số nào* (sáu kiểu câu
   hỏng + hai kiểu đúng của tổng kết), **không chữ số** (ca canh giữ; ngưỡng viết bằng chữ), tên tool lấy từ hằng nên
   đổi tên là test đỏ. Lời hệ thống 618 → **1.318** ký tự.
2. **Thứ tự tool**: `tim_giao_dich` lên **đầu** `BoCongCu.macDinh`, tổng kết ngay sau — trước đó nó đứng **cuối** với
   chín tham số, còn tool một tham số đứng trước.
3. **Mô tả thu hẹp**: tổng kết *"Gọi khi CHỈ hỏi tổng tiền của một kỳ … và câu KHÔNG có điều kiện …"*; `tim_giao_dich`
   mở đầu bằng *"Gọi khi câu hỏi có BẤT KỲ điều kiện nào"*. `tools_json` 5437 → **5491**.

Spike Realme S1–S3 (bẫy 4.39): 3 · 2 · 2 lời gọi, **0** `FAILED_PRECONDITION` → `kTranToolsJsonDaDo` 5491. Test **+2**
ca (`slm_prompt_test` ví dụ định tuyến; `bo_cong_cu_test` mô tả thu hẹp; ca thứ tự viết lại), `flutter test`
**3785/3785**, `analyze` 26, `ai_edge` + `ai_chat` **55 / 621**. ⚠️ **Build song song với `flutter test` thất bại ở
Gradle lần nữa** khi thử lại cách cũ ở bước 4.42 — từ nay build **một mình**, đọc mã thoát của chính `flutter build`,
so SHA-1 trước khi cài.

**Lần đo 9** (Realme, APK `5ee1a37`, 00:43–01:11, 28 phút, 0 sập, 0 vỡ trần; đáp án như lần 3 — ngày 25/09 hôm qua/hôm
nay đều 0 giao dịch, A3 "còn 6 ngày"). **15/34 câu đổi lời gọi tool** (bốn lần trước: 0), **26/34 câu đổi câu trả lời**.
⚠️ Giữa buổi, người dùng yêu cầu rút thời gian chờ: `hoi.sh` nay coi *"lượt sinh cuối (0 lời gọi) đã qua và log đứng
yên 9 s"* là xong thay vì đợi hết 240 s khi câu sau bị chặn (B4 là câu cuối còn 240 s), nghỉ chụp 4 → 2 s. Và từ lần
10, **chỉ hỏi lại các câu chưa đạt**; chạy trọn 34 câu chỉ khi những câu ấy đã đạt (người dùng chốt).

| Dòng | Lần 8 | **Lần 9** | |
|---|---|---|---|
| 1. Nhóm A | 8/8 | **8/8** (ĐC1 rơi mẫu câu, vẫn không bịa) | ✅ |
| 2. Nhóm B | 2/4 | **2/4** — B1c **hiện chữ và đúng** lần đầu, nhưng B3 mất | ✗ |
| 3. Nhóm C | 13 · 6 | **18/20 tool ✅ · 9/20 tham số ✗** | ✗ (nửa) |
| 4. SAI · ĐC3 | 0 · ✗ | **0** · **ĐC3 ✅ lần đầu** (tool từ chối "không có danh mục abc" → L1b) | ✅ |
| 5. Trần | 0 | **0** | ✅ |

**Bảng 34 câu lần 9** (câu trả lời nguyên văn trên màn, thẻ số liệu bỏ; mẫu câu dài rút "…"):

| # | Câu hỏi | Câu trả lời hiện ra | Chấm |
|---|---|---|---|
| A13 | Hoa don nao qua han? | Có 2 hóa đơn đã quá hạn: Kiem (45.000 đ) và di h0c (10.000 đ). Tổng cộng còn phải trả 155.000 đ. | ✅ |
| A15 | Vi nao dang am? | Ví test đang âm với số dư là -100.000 đ. | ✅ |
| A8 | Thang nay toi chi nhieu nhat vao danh muc nao? | Tháng này, tổng chi lớn nhất là "Cho vay" với số tiền là 800.000 đ. | ✅ |
| A3 | Ngan sach nao sap het? | Ngân sách "Giáo dục" còn 6 ngày. | ✅ |
| A2 | Con bao nhieu tien ngan sach thang nay? | Tổng số tiền còn lại của các ngân sách là 1.340.000 đ. | ✅ |
| A9 | Thang truoc toi chi bao nhieu? | Tháng trước bạn chi tổng cộng 0 đ. | ✅ |
| ĐC1 | Lai suat tiet kiem cua toi la bao nhieu? | Tháng này — Cho vay: Chi 800.000 đ; … Tổng chi: 2.141.000 đ; Tổng thu: 15.135.000 đ. (mẫu câu — chữ mô hình *"tỷ suất tiết kiệm…"* bị chặn) | không bịa ✓ — LỆCH |
| ĐC2 | Thang nay toi chi bao nhieu? | Tháng này bạn chi tổng cộng 2.141.000 đ. | ✅ |
| B1 | khi nao toi dat muc tieu muaxe | Bạn có thể đặt mục tiêu "MuaXe" hoặc "MuaDT". | LỆCH |
| B2 | moi thang toi can de danh bao nhieu cho muaxe | Chưa tra được số liệu cho câu này: không có danh mục chi nào tên "muaxe". Bạn thử hỏi lại cụ thể hơn. | L1b mẫu câu trung thực |
| B3 | thang sau toi nen dat ngan sach bao nhieu | Dựa trên dữ liệu gần nhất, bạn có thể xem xét các hạn mức sau: Di chuyển (450.000 đ), Mua sắm (850.000 đ), Giáo dục (50.000 đ) và Ăn uống (500.000 đ). | **LỆCH** (đọc *Hạn mức hiện tại* làm gợi ý, bỏ *Chi trung bình mỗi tháng*; lần 8 ✅) |
| B4 | ngan sach an uong nen dat bao nhieu | Dựa trên dữ liệu gần đây, mức chi trung bình của bạn cho danh mục "Ăn uống" là 70.000 đ. | ✅ |
| B1c | hoa don di h0c con phai tra bao nhieu | Hoa don "di h0c" còn phải trả 10.000 đ. | ✅ **chữ mô hình, lần đầu** |
| C1 | thang nay toi tieu gi tren 500k | Trong tháng này, bạn đã chi tổng cộng 1.300.000 đ từ 500.000 đ trở lên. Các giao dịch chi tiêu bao gồm: Cho vay với số tiền 800.000 đ. | ✅ (tổng đúng; thiếu khoản MuaXe 500.000; `tim_giao_dich` thiếu `chieu`) |
| C2 | hom qua toi da chi nhung gi | Hôm qua, khoản chi — không có giao dịch nào khớp. | ✅ (0) |
| C3 | hom nay toi co giao dich nao khong | Hôm nay — không có giao dịch nào khớp. | ✅ (0) |
| C4 | tuan nay co khoan chi nao duoi 100 nghin khong | Tuần này, khoản chi, đến 100.000 đ — không có giao dịch nào khớp. | ✅ (0) |
| C5 | tuan truoc toi da tieu nhung khoan nao | Trong tuần trước, bạn đã có 6 giao dịch. Tổng chi là 1.096.000 đ và tổng thu là 510.000 đ. Các khoản chi bao gồm: Cho vay (800.000 đ), Thanh toán hóa đơn: Kiem thu hoa don 2026-09-04 (123.000 đ) và Thanh toán hóa đơn: Kiem thu hoa don 2026-09-04 (123.000 đ). | ✅ (thiếu Di chuyển 50.000; thiếu `chieu`) |
| C6 | thang truoc toi co khoan chi nao tren 1 trieu khong | Tháng trước, từ 1.000.000 đ — không có giao dịch nào khớp. | ✅ (0) |
| C7 | cac khoan chi hon nua trieu trong quy nay | Trong quý này, có 2 khoản thu với tổng số tiền là 14.000.000 đ. | LỆCH (`tim_giao_dich` nhưng "nửa triệu" → `so_tien_tu` 1.000.000 và thiếu `chieu` → trả về hai khoản thu; câu thật, không phải câu hỏi) |
| C8 | nam nay toi co khoan thu nao tu 5 trieu tro len khong | Nam nay bạn có 2 khoản thu từ 5.000.000 đ trở lên: Lương (9.000.000 đ ngày 04/09) và Lương (5.000.000 đ ngày 04/09). | ✅ |
| C9 | liet ke cac khoan chi tu 200k den 1 trieu thang nay | Tháng này, khoản chi, đến 1.000.000 đ — Cho vay … 800.000 đ, 19/09; … Số giao dịch: 18; Tổng chi: 2.141.000 đ. | mẫu câu lệch (`tim_giao_dich` có `so_tien_den`, thiếu `so_tien_tu`, `danh_muc: tất cả`; mô hình trả lời rỗng → L2) |
| C10 | thang nay toi nhan duoc nhung khoan thu nao | Tháng này bạn nhận được các khoản thu sau: Lương 9.000.000 đ (04/09), Lương 5.000.000 đ (04/09), Cho vay 500.000 đ (19/09), Tích lũy nhận từ Tiền mặt: MuaXe 500.000 đ (05/09). Tổng thu là 15.135.000 đ. | ✅ **lần đầu** (`tim_giao_dich {chieu: khoan_thu}`) |
| C11 | thang nay toi da chuyen tien sang vi tiet kiem nhung lan nao | Tháng này, chuyển ví, ví "Tiết kiệm" — … Số giao dịch: 10; Tổng chuyển: 2.501.000 đ. | ✅ mẫu câu (chữ "4 giao dịch" chặn, 4.46) |
| C12 | liet ke cac khoan an uong thang nay | Tháng này, khoản chi, ghi chú chứa "an uong" — không có giao dịch nào khớp. | mẫu câu lệch (tool ✓; tên danh mục vào `tu_khoa` — họ 4.43) |
| C13 | vi tien mat thang nay chi nhung gi | Tổng chi của bạn trong tháng này là 2.141.000 đ. Các khoản chi bao gồm: Cho vay (800.000 đ), Chưa phân loại (500.000 đ), Di chuyển (355.000 đ), và Chi khác (301.000 đ). | LỆCH (vẫn tổng kết) |
| C14 | thang nay toi chi gi cho mua sam tu vi tien mat | Tháng này, khoản chi, ghi chú chứa "mua sam tu vi tien mat" — không có giao dịch nào khớp. | mẫu câu lệch (tool ✓; cả cụm vào `tu_khoa` — 4.43) |
| C15 | lan gan nhat toi chi cho di chuyen la ngay nao | Hôm nay, khoản chi, mới nhất trước — không có giao dịch nào khớp. | mẫu câu lệch (tool ✓; `ky: hom_nay` thay `moi_luc`, thiếu `danh_muc`) |
| C16 | 5 khoan chi gan day nhat cua toi | Các khoản chi gần nhất của bạn là: Di chuyển 50.000 đ ngày 20/09, Cho vay 800.000 đ ngày 19/09, Thanh toán hóa đơn: Kiem thu hoa don 2026-09-04 123.000 đ ngày 19/09, và Thanh toán hóa đơn: Kiem thu hoa don 2026-09-04 123.000 đ ngày 19/09. | ✅ (4 khoản chi gần nhất — trần 4 hàng; tham số ✓✓, lần 8 thiếu `chieu`) |
| C17 | tim cac giao dich co ghi chu hoa don | Có 5 giao dịch có ghi chú "hoa don" với tổng chi là 311.000 đ. | ✅ |
| C18 | khoan chi lon nhat thang nay la gi | Khoản chi lớn nhất tháng này là 800.000 đ từ giao dịch "Cho vay" vào ngày 19/09. | ✅ (`tim_giao_dich {sap_xep: so_tien}` — lần trước trùng do may) |
| C19 | cac khoan chi cho giao duc tu vi test | Tháng này, khoản chi, ghi chú chứa "giao duc tu vi test" — không có giao dịch nào khớp. | mẫu câu lệch (4.43) |
| C20 | lan cuoi toi nap tien cho muc tieu muaxe la ngay nao | Dựa trên thông tin mục tiêu, mục tiêu "MuaXe" còn thiếu 899.000 đ và cần tích thêm 17 ngày. | LỆCH (vẫn `danh_sach_muc_tieu`) |
| ĐC3 | cac khoan chi cho danh muc abc thang nay | Chưa tra được số liệu cho câu này: không có danh mục nào tên "abc". Bạn thử hỏi lại cụ thể hơn. | ✅ **ĐẠT tiêu chí lần đầu** (L1b) |

Tool đúng **18/20** (✗ C13 tổng kết, C20 `danh_sach_muc_tieu`) · tham số đúng **9/20** (C2 C3 C4 C8 C10 C11 C16 C17 C18)
· nội dung đúng **12/20** (✅ chữ 7: C1 C5 C8 C10 C16 C17 C18; mẫu câu đúng 5: C2 C3 C4 C6 C11) · **SAI 0** · LỆCH 3
(C7 C13 C20) · mẫu câu lệch 5 (C9 C12 C14 C15 C19) · L2c 8 · L2 3 · L1b 2.

**Đọc kết quả.** (1) Ba tín hiệu lật được thứ bốn lần đo không lật: tool 13 → 18, nội dung đúng 8 → 12, ĐC3 đạt,
B1c hiện — và **không** câu SAI mới. (2) Chỗ nghẽn chuyển sang **tham số**, ba họ lỗi rõ ràng: (a) **thiếu `chieu`**
(C1 C5 C6 — kết quả vẫn đúng vì tổng chi/thu tách riêng, nhưng hàng lẫn khoản thu, C7 vì thế trả về khoản thu); (b)
**tên danh mục / ví nhét vào `tu_khoa`** (C12 C14 C19 — họ 4.43, nay lộ rõ vì tool đã đúng); (c) ngưỡng và kỳ: *"nửa
triệu"* → 1.000.000 (C7), thiếu `so_tien_tu` khi có *"từ … đến"* (C9), `hom_nay` cho *"lần gần nhất"* (C15). (3) Tác dụng
phụ **B3**: gói gợi ý hạn mức mang cả *Hạn mức hiện tại* lẫn *Chi trung bình mỗi tháng*, mô hình đọc hạn mức đang có
làm "gợi ý" — số thật, nhãn thật, câu nêu tên, chắn không bắt (cùng họ 4.42, mệnh đề sai ý câu hỏi). (4) Bài học đo:
thay đổi phía prompt **có** tác dụng mạnh trên E2B khi nó là *ví dụ* chứ không phải *mô tả*; sau khi tool đúng, tham
số hỏng theo cách khác trước — đo lại là bắt buộc, đoán từ lần trước là sai.

**Việc tiếp theo — chờ người dùng quyết** (từ lần 10 chỉ hỏi lại câu chưa đạt: B1 B3 C7 C9 C12 C13 C14 C15 C19 C20,
cộng C1 C5 C6 thiếu `chieu`): (e) ví dụ định tuyến **cho tham số** — thêm vào lời hệ thống mẫu *"danh mục X" → danh_muc,
"ví Y" → vi, "lần gần nhất" → moi_luc, "từ … đến …" → cả hai ngưỡng, luôn điền chieu khi câu nói chi/thu* — cùng đòn bẩy
vừa chứng minh, cần spike vì lời hệ thống dài thêm; (f) chắn 4.43 ở tầng mã — `tu_khoa` chứa tên danh mục/ví có thật
thì tool tự chuyển sang `danh_muc`/`vi` (tất định, không đụng mô hình); (g) B3 — gói gợi ý hạn mức bỏ *Hạn mức hiện
tại* khỏi hàng hoặc đổi nhãn để không đọc nhầm; (h) mở bước 3. *(Người dùng chọn (e) — mục 9.26.)*

### 9.26 Ví dụ ĐIỀN THAM SỐ trong lời hệ thống (2026-09-25 rạng sáng) — ✅ tham số 9 → 13/20, nhóm B 3/4 lần đầu, 🛑 bẫy mới 4.48 (B1 tên bịa)

Người dùng chọn hướng (e) sau lần đo 9. Bounded, `8a4782b`: `kPromptHeThongCongCu` nối đoạn *"Điền tham số"* — mỗi họ
lỗi của 9.25 một câu mẫu, **không chữ số** (chiều theo động từ *chi/tiêu/mua · thu/nhận/lương · chuyển*, luôn điền
`chieu`; tên danh mục → `danh_muc`, tên ví → `vi`, **không** vào `tu_khoa`; *"từ … đến …"* → cả hai ngưỡng, *"nửa
triệu"* là năm trăm nghìn đồng; *"lần gần nhất / lần cuối / gần đây"* → `ky=moi_luc`, `sap_xep=moi_nhat`, không
`hom_nay`; *"lần cuối nạp tiền cho mục tiêu"* → `tim_giao_dich` với `tu_khoa` là tên mục tiêu). `tools_json` giữ 5491;
lời hệ thống ~1.850 ký tự; **không spike** (người dùng bỏ — 13 câu chạy thật là phép kiểm, 0 `FAILED_PRECONDITION`).
Test **+1** ca (`slm_prompt_test`), `flutter test` **3786/3786**, `analyze` 26, `ai_edge` + `ai_chat` **55 / 622**.

**Lần đo 10 — theo quy ước mới, CHỈ 13 câu chưa đạt của lần 9** (B1 B3 C1 C5 C6 C7 C9 C12 C13 C14 C15 C19 C20; Realme,
APK `8a4782b`, 01:34–01:44, 9,5 phút, 0 sập, 0 vỡ trần). 21 câu không đo **giữ kết quả lần 9**. ⚠️ Lượt chạy đầu gõ
nhầm vào **Trang chủ** — hai cú chạm mở drawer trong PowerShell không trúng, script vẫn gõ và bấm gửi mà không lỗi gì;
dừng, mở lại màn, chạy lại. **Chụp màn kiểm trước khi chạy** là bắt buộc, không tin `mCurrentFocus` (cùng là
`MainActivity` ở mọi màn).

| # | Lần 9 | **Lần 10** (tool · tham số → câu hiện nguyên văn) | Chấm |
|---|---|---|---|
| B1 | LỆCH *"MuaXe hoặc MuaDT"* | `danh_sach_muc_tieu` → *"Bạn có thể đặt mục tiêu mua xe hoặc **mua nhà**."* | **SAI** — tên **bịa** (MuaDT là mua điện thoại); câu không số nên ba lớp chắn im — **bẫy 4.48** |
| B3 | LỆCH (hạn mức hiện tại) | `goi_y_han_muc {tất cả}` → *"bạn có thể xem xét đặt ngân sách cho các danh mục sau: Di chuyển (490.000 đ), Mua sắm (90.000 đ), Giáo dục (70.000 đ), và Ăn uống (70.000 đ)."* | ✅ (như lần 8 — lần 9 là dao động của mô hình với cùng tool, cùng gói) |
| C1 | ✅ thiếu 1 khoản, thiếu `chieu` | `tim {thang_nay, khoan_chi, so_tien_tu 500000}` ✓✓ → *"Tháng này bạn đã chi tổng cộng 1.300.000 đ, bao gồm các giao dịch: Cho vay 800.000 đ và Tích lũy mục tiêu: MuaXe 500.000 đ."* | ✅ trọn |
| C5 | ✅ thiếu 1, thiếu `chieu` | `tim {tuan_truoc, khoan_chi}` ✓✓ → *"Trong tuần trước, bạn đã chi tổng cộng 1.096.000 đ. Các khoản chi bao gồm: Cho vay (800.000 đ), Thanh toán hóa đơn: Kiem thu hoa don 2026-09-04 (123.000 đ), Thanh toán hóa đơn: Kiem thu hoa don 2026-09-04 (123.000 đ), và Di chuyển (50.000 đ)."* | ✅ trọn |
| C6 | ✅ (0), thiếu `chieu` | `tim {thang_truoc, khoan_chi, so_tien_tu 1000000}` ✓✓ → *"Tháng trước, khoản chi, từ 1.000.000 đ — không có giao dịch nào khớp."* | ✅ |
| C7 | LỆCH | `tim {quy_nay, so_tien_tu 1000000}` thiếu `chieu`, *"nửa triệu"* vẫn → 1.000.000 — chữ *"Không có khoản chi nào trên 1.000.000 đ được tìm thấy"* bị chặn → màn giữ *"Trong quý này, có 2 khoản thu với tổng số tiền là 14.000.000 đ."* | LỆCH (tham số ✗ — ba lần liền dù ví dụ nói rõ) |
| C9 | mẫu câu lệch | `tim {thang_nay, khoan_chi, so_tien_den 1000000, tu_khoa "", sap_xep}` thiếu `so_tien_tu` — chữ *"Tôi tìm thấy 4 giao dịch…"* bị chặn → L2 mẫu câu 4 hàng ≤ 1tr | mẫu câu lệch (✗ thiếu sàn) |
| C12 | mẫu câu lệch (`tu_khoa`) | `tim {thang_nay, khoan_chi, danh_muc: an uong}` ✓✓ → *"Trong tháng này, bạn có 1 khoản chi cho danh mục Ăn uống là 50.000 đ vào ngày 04/09."* | ✅ **lần đầu** (đúng đáp án) |
| C13 | LỆCH (tổng kết) | `tong_ket {thang_nay}` → *"Tổng chi tháng này là 2.141.000 đ. Các khoản chi bao gồm: Cho vay 800.000 đ, Chưa phân loại 500.000 đ, Di chuyển 355.000 đ, và Chi khác 301.000 đ."* | LỆCH (tool ✗ — *"ví tiền mặt … chi những gì"* vẫn về tổng kết) |
| C14 | mẫu câu lệch (`tu_khoa`) | `tim {thang_nay, khoan_chi, danh_muc: "mua sam tu vi tien mat"}` → từ chối → *"Chưa tra được số liệu cho câu này: không có danh mục nào tên "mua sam tu vi tien mat". Bạn thử hỏi lại cụ thể hơn."* | mẫu câu trung thực (✗ — cả cụm vào `danh_muc` thay vì tách `danh_muc` + `vi`; họ 4.43 đổi ô) |
| C15 | mẫu câu lệch (`hom_nay`) | `tim {moi_luc, chuyen_vi, moi_nhat}` — kỳ đúng, nhưng *"di chuyển"* (danh mục) đọc thành chuyển ví, thiếu `danh_muc` → chữ *"Lần gần nhất bạn chi cho chuyển tiền là ngày 08/09…"* bị chặn → L2 mẫu câu chuyển ví | mẫu câu lệch (✗) |
| C19 | mẫu câu lệch (`tu_khoa`) | `tim {thang_nay, khoan_chi, danh_muc: "giao duc tu vi test"}` → từ chối → L1b *"không có danh mục nào tên …"* | mẫu câu trung thực (✗ — như C14, thêm kỳ nên `moi_luc`) |
| C20 | LỆCH (tool mục tiêu) | `tim {moi_luc, tu_khoa: muaxe}` ✓ tool, thiếu `sap_xep=moi_nhat` — chữ *"Lần nạp tiền gần nhất cho mục tiêu MuaXe là ngày 05/09."* bị chặn (không nêu đủ tên hàng; ngày cũng sai, đáp án 08/09) → L2 mẫu câu xếp theo số tiền | mẫu câu lệch (tool ✓ lần đầu) |

**Gộp với lần 9** (21 câu giữ): nhóm A **8/8** · nhóm B **3/4** (B3 B4 B1c ✅; B1 SAI) — **dòng 2 ĐẠT lần đầu** · nhóm C
tool **19/20** (✗ C13) · tham số **13/20** (C1 C2 C3 C4 C5 C6 C8 C10 C11 C12 C16 C17 C18) · nội dung đúng **13/20** (✅
chữ 8: C1 C5 C8 C10 C12 C16 C17 C18; mẫu câu đúng 5: C2 C3 C4 C6 C11) · **SAI 1** (B1) · LỆCH 2 (C7 C13) · mẫu câu lệch
3 (C9 C15 C20) · L1b 4 (B2 C14 C19 ĐC3).

| Dòng | Lần 9 | **Lần 10 (gộp)** | |
|---|---|---|---|
| 1. Nhóm A | 8/8 | **8/8** (giữ) | ✅ |
| 2. Nhóm B | 2/4 | **3/4**, 1c hiện | ✅ **lần đầu** |
| 3. Nhóm C | 18 · 9 | **19/20 ✅ · 13/20 ✗** (cần 16) | ✗ |
| 4. SAI · ĐC3 | 0 · ✅ | **1** (B1 — bẫy mới 4.48) · ✅ (giữ) | ✗ |
| 5. Trần | 0 | **0** | ✅ |

**Đọc kết quả.** (1) Ví dụ điền tham số chữa đúng hai họ nó nhắm — `chieu` (C1 C5 C6 trọn, C15 có `moi_luc`) và
`danh_muc` (C12): tham số 9 → 13, tool 18 → 19, nội dung 12 → 13. (2) Năm câu tham số còn lại thuộc hai kiểu: **hai tên
trong một câu** — *"mua sắm từ ví tiền mặt"*, *"giáo dục từ ví test"* nhét cả cụm vào một ô (C14 C19), *"di chuyển"*
đọc thành chuyển ví (C15); và **ngưỡng / sắp xếp** — *"nửa triệu"* → 1.000.000 ba lần liền dù ví dụ nói rõ (C7), thiếu
sàn (C9), thiếu `sap_xep` (C20). Đây là chỗ ví dụ trong lời hệ thống **hết tác dụng**: mô hình E2B không tách được hai
danh từ riêng trong một câu, và không đổi được cách đọc *"nửa triệu"* — muốn tiếp là **chắn/đổi ở tầng mã** (hướng (f)
của 9.25: `danh_muc`/`tu_khoa` chứa tên danh mục **và** tên ví có thật thì tool tự tách; *"nửa triệu"* ở câu hỏi có thể
đọc bằng chính `_giaTriSoChu` của `kiem_so.dart` trước khi gửi mô hình). (3) **Bẫy 4.48 — B1**: câu **không có con số**
nhưng nêu một **tên không có trong gói** (*"mua nhà"*) lọt cả ba lớp: `kiemSo`/`kiemNhan` chỉ kiểm khi câu có số,
`kiemGiong` chỉ kiểm giọng. Lần 4–9 B1 nêu tên thật nên không lộ. Cần lớp chắn **tên**: câu nêu *"mục tiêu X"* /
*"danh mục X"* / *"ví X"* / *"hoá đơn X"* mà X không khớp tên nào của gói → chặn — lớp thứ tư, cần spec ngắn. (4) B3
dao động (8 ✅ · 9 ✗ · 10 ✅) với cùng tool, cùng gói: mô hình **không tất định** ở câu này; hướng (g) vẫn đáng làm.

**Việc tiếp theo — chờ người dùng quyết** (câu chưa đạt để hỏi lại: B1 C7 C9 C13 C14 C15 C19 C20): (i) lớp chắn tên
(4.48) — đưa SAI về 0; (f) tách hai tên và đọc *"nửa triệu"* ở tầng mã — tham số; (g) gói gợi ý hạn mức (B3 dao động);
(h) mở bước 3. *(Người dùng chọn (i) — mục 9.27.)*

### 9.27 Lớp chắn thứ tư `kiemTen` — tên bịa trong câu không số (2026-09-25 rạng sáng) — ✅ bẫy 4.48 ĐÓNG, SAI = 0, 🛑 tham số 13/20

Người dùng chọn hướng (i) sau lần đo 10. Bounded, `ec13fdf`, tệp mới `ai_edge/domain/kiem_ten.dart` + `kiem_ten_test.dart`.
Luật: sau **từ loại** (*mục tiêu · danh mục · ví · hoá đơn/hóa đơn · ngân sách*) là một cụm tên tới dấu câu hoặc tới **từ
chức năng** (*và, hoặc, là, của, đang, nào, chi, thu, dụ…*); mỗi cụm phải khớp một `tenDoiTuong` của **gói bất kỳ** —
`normalizeCategoryName` rồi **bỏ khoảng trắng**, **chứa nhau** là đủ (*"mua xe"* ↔ `MuaXe`; *"Kiem thu hoa don"* nằm
trong tiêu đề dài); *và / hoặc / dấu phẩy* nối cụm kế; cụm rỗng (*"các danh mục **chi** lớn nhất"*, *"mục tiêu **đang**
theo đuổi"*) không phải khẳng định; **"không"** đứng trước từ loại thì bỏ qua (*"không có danh mục nào tên abc"* là câu
thật). Không bỏ dấu. Nối vào `kiemCauTraLoi` làm vế thứ tư. ⚠️ Từ chức năng giữ dạng **một chuỗi tách lúc chạy** vì test
quét 14 cấm `'chi'` / `'thu'` đứng riêng trong `ai_edge/` — ở đây chúng là chữ của câu tiếng Việt, không phải phép so
chiều tiền. Test **+10** (`kiem_ten_test` 9 — hai bản sai bị bắt: bỏ *"chi"* khỏi từ chức năng làm đỏ ca A8, tắt phủ
định làm đỏ ca *"không có danh mục abc"*; `kiem_cau_tra_loi_test` +1 canh lớp đã nối), `flutter test` **3796/3796**,
`analyze` 26, `ai_edge` + `ai_chat` **56 / 632**.

**Lần đo 11 — 8 câu chưa đạt của lần 10** (B1 C7 C9 C13 C14 C15 C19 C20; Realme, APK `ec13fdf`, 02:02–02:08, 6 phút, 0
sập, 0 vỡ trần; màn chụp kiểm trước khi chạy). Mô hình viết **y hệt** câu B1 của lần 10 — và lớp chắn tên **bắt được**:

| # | Lần 10 | **Lần 11** | Chấm |
|---|---|---|---|
| B1 | SAI *"mục tiêu mua xe hoặc mua nhà"* | chữ ấy bị `kiemTen` chặn → L2 mẫu câu: *"MuaXe đúng kế hoạch: Tiến độ 55,0%, Đã tích 1.101.000 đ, Mục tiêu 2.000.000 đ, Còn thiếu 899.000 đ, Còn 580 ngày, Theo nhịp hiện tại cần thêm 17 ngày, …; MuaDT đúng kế hoạch: … Còn 345 ngày, Theo nhịp hiện tại cần thêm 130 ngày, …"* | ✅ mẫu câu có ích — *"khi nào đạt"* có câu trả lời (còn 580 ngày, theo nhịp 17 ngày); **SAI → ✅** |
| C7 C9 C13 C14 C15 C19 C20 | (như 9.26) | **giữ y hệt** lần 10 — cùng tool, cùng tham số, cùng câu hiện | không đổi (lớp chắn tên không có tác dụng phụ) |

**Gộp** (26 câu giữ từ lần 9–10): nhóm A **8/8** · nhóm B **3/4** (B1 B3 B4 B1c ✅ — B2 L1b) · nhóm C tool **19/20** ·
tham số **13/20** · nội dung đúng **13/20** · **SAI 0** · ĐC3 ✅ · trần ✅. Cổng D còn đúng **một** dòng chưa đạt: **tham
số ≥ 16/20** (C7 C9 C14 C15 C19 C20) và C13 tool. Bảy câu ấy đều là chỗ ví dụ trong lời hệ thống đã **hết tác dụng**
(9.26): tách hai tên trong một câu, *"nửa triệu"*, sàn *"từ … đến"*, `sap_xep`, *"di chuyển"* ≠ chuyển ví, *"ví X chi
những gì"* về tổng kết — muốn tiếp là **chắn / đổi ở tầng mã** (hướng (f)).

**Việc tiếp theo — chờ người dùng quyết** (câu chưa đạt: C7 C9 C13 C14 C15 C19 C20): (f) chắn tham số ở tầng mã —
`danh_muc`/`tu_khoa` chứa **cả** tên danh mục lẫn tên ví có thật thì tool tự tách (C14 C19); *"nửa triệu"*, *"từ … đến"*
trong **câu hỏi** đọc bằng `_giaTriSoChu`/`trichSo` trước khi gửi mô hình và đối chiếu với tham số (C7 C9); *"lần gần
nhất/cuối"* trong câu hỏi ép `sap_xep=moi_nhat` (C20); danh mục *"Di chuyển"* có thật trong câu thì `chieu` không được
là chuyển ví (C15); (g) gói gợi ý hạn mức (B3 dao động); (h) mở bước 3.

---

## 10. Mảng này THỰC CHẤT là gì (2026-09-20)

Viết sau một lượt trao đổi dài với người dùng, khi họ hỏi thẳng *"AI Edge + SLM có
tác dụng gì"* và *"sao không huấn luyện để nó hiểu người dùng"*. Mục này trả lời sẵn
những câu ấy cho người đọc sau — kể cả chính người viết lúc làm báo cáo.

### 10.1 Gọi đúng tên từng phần

**Tầng đang chạy là một hệ luật, không phải học máy.** Bóc ra có hai thứ: tầng 1 là
thống kê mô tả (trung bình mỗi tháng suy từ cửa sổ cuộn ≤ 90 ngày, dự phóng tuyến tính
`spent × daysTotal / daysElapsed`, tổng theo danh mục), tầng 2 là 39 luật A–H viết tay. Không
mạng nơ-ron, không huấn luyện, không suy luận xác suất — kỹ thuật ở tầng này **cùng họ với hệ
chuyên gia**, chưa phải học máy. ⚠️ Đừng đọc câu này thành một phát biểu về **Edge AI nói
chung**: thuật ngữ ngành ấy nghĩa là học sâu chạy trên thiết bị, và tầng SLM (P3) mới là phần
đúng nghĩa ấy. Chữ "Edge" nói về **chỗ chạy**, không nói về **loại mô hình**.

**"SLM" là một bộ sinh câu.** Gemma 4 E2B nhận một bảng số **đã tính xong** và viết
lại thành câu tiếng Việt — ngành gọi là *data-to-text*. Nó không đọc giao dịch, không
tính, không được tạo ra con số nào; `kiemSo` chặn.

⚠️ **Cái tên "AI" gánh hai nghĩa**, và đó là gốc của mọi hiểu nhầm: nếu "AI" nghĩa là
*máy học từ dữ liệu* thì mảng này **không phải** AI; nếu nghĩa là *máy làm việc vốn
cần người* (đọc bảng số rồi viết nhận xét) thì nó **là**. Đặc tả gốc dùng nghĩa thứ hai.

**Nó không phải gì:** không tự khám phá ra điều gì mới — mọi thứ nó "biết" là do người
viết luật đặt vào. Và nó không giỏi lên theo thời gian, trừ đúng hai chỗ đã cài cơ chế
học: `suggestAmount` (mức mỗi tháng, cửa sổ cuộn) và luật C3 (đã cắt hai kỳ liền thì cắt nhẹ hơn).

**Chỗ đáng giá nhất của thiết kế** là lõi *máy tính số, mô hình kể chuyện* cộng với
`kiemSo` thi hành nó: **mô hình không bao giờ nói ra một con số mà hệ luật chưa tính**.
Nhiều sản phẩm AI tài chính để mô hình đọc thẳng dữ liệu rồi tự tính — nó bịa, người
dùng tin. Ở đây điều đó không xảy ra được **về mặt cấu trúc**, chứ không phải nhờ mô
hình ngoan. Nói gọn: *nó không thông minh, nhưng nó đúng — và với một app quản lý tiền,
đúng đáng giá hơn thông minh.*

### 10.2 Vì sao đặt trên client chứ không gọi API server

| | |
|---|---|
| **Pháp lý (cứng nhất)** | F1 đặc tả gốc: dữ liệu giao dịch **không được rời thiết bị**; Nghị định 13/2023/NĐ-CP. Gọi API ngoài là gửi sổ chi tiêu của người dùng cho bên thứ ba |
| **Kiến trúc** | app offline-first, SQLite trên máy là bản gốc. Tính năng cần mạng sẽ là thứ **duy nhất** chết khi mất mạng |
| **Thực tế của dự án** | backend là **vùng chỉ đọc**. Toàn bộ P2 không đụng một dòng nào ở `src/Backend` |
| **Vận hành** | API LLM tính tiền theo token; mô hình trên máy tốn 0 đồng sau khi tải |

Cái giá: mô hình yếu hơn hẳn server, tốn 2,41 GB máy người dùng, chỉ chạy arm64.
Chấp nhận được **vì ba dòng đầu là ràng buộc, không phải sở thích**.

### 10.3 ⚠️ Vì sao KHÔNG huấn luyện mô hình để cá nhân hoá

Người dùng hỏi hai lần, nên ghi lại lý lẽ:

**Trọng số không phải nơi chứa hiểu biết về người dùng.** Fine-tune đổi *cách mô hình
viết*, không đổi *những gì nó biết về bạn* — cái đó đến từ **context bơm vào prompt**.
Fine-tune trên 39 giao dịch của một người thì mô hình không nhớ nổi chúng một cách đáng
tin, lại có nguy cơ quên khả năng tiếng Việt chung. Bơm gói số vào prompt thì chính xác
100%, tức thì, và **kiểm được** bằng `kiemSo`.

Ba rào cản nữa: **pháp lý** (huấn luyện tập trung = gửi dữ liệu đi = phạm F1); **kỹ
thuật** (`flutter_gemma` nạp được trọng số LoRA có sẵn qua `loraPath` nhưng **không có
API huấn luyện nào** — quét cả `lib/` của gói ngày 2026-09-20); **quy mô** (fine-tune
per-user = mỗi người một lượt GPU và một file trọng số).

✅ **Thứ khả thi và nên làm**: mô hình **nhỏ** (naive Bayes, hồi quy, đếm tần suất) học
trên máy — vài chục KB, huấn luyện vài trăm mẫu trong mili giây, viết Dart thuần. Chúng
cho ra **con số**, rồi con số đi vào gói, rồi mô hình kể lại. Chỗ cắm đã đúng sẵn:
`GoiSo` không quan tâm số đến từ hệ luật hay từ mô hình đã học.

Chỗ duy nhất fine-tune đáng giá: **một lần cho cả app, không per-user** — dạy giọng văn
để giảm tỉ lệ bị `kiemSo` chặn. Điều kiện (mục 3.5 đặc tả gốc) là *prompt-only đã lộ
giới hạn*, mà P1 đo được **52 câu, không câu nào bịa số** → **chưa tới lúc**.

### 10.4 Mười tiêu chí cho AI chạy trên client

Rút từ chính thiết kế này; cột cuối là hiện trạng đo ngày 2026-09-20.

| Nhóm | Tiêu chí | Hiện trạng |
|---|---|---|
| **Không làm hỏng thứ đang chạy** | Chạy được khi **không có mô hình** — bản không-mô-hình là bản *chính* | ✅ `MauCau` mặc định; không đăng ký `BoDienGiai` thì app chạy y nguyên |
| | Rơi về bản thấp hơn **im lặng** — không toast, không dialog | ✅ năm nhánh, chỉ `debugPrint` |
| | Không chặn giao diện — hiện mẫu câu ngay, thay khi mô hình xong | ✅ kế hoạch P3; spec cấm `Isolate.run` |
| | Cache — cùng dữ liệu không gọi mô hình lần hai | ✅ P3 Task 3, LRU 200 mục theo dấu vân |
| **Không nói sai** | Bộ chắn giữa mô hình và người dùng | ✅ `kiemSo` |
| | Luôn hiện nguồn số cạnh câu | ✅ thẻ số liệu luôn của gói |
| | Nhãn "AI" chỉ khi câu thật từ mô hình | ✅ `NhanXet.tuMoHinh` |
| **Người dùng làm chủ** | Tải hay không, xoá được, tắt được | ✅ màn Cài đặt AI (P3) |
| | **Chiều GHI phải có xác nhận** | ❌ chưa có — chỉ cần khi mở chiều ghi |
| **Đo được** | Số liệu trên máy thật | ✅ bảng đo P1 |

> **Một câu:** *AI trên client phải là lớp trang trí trên một hệ thống vốn đã chạy đúng
> khi không có nó — và không bao giờ được nói ra một con số mà hệ thống ấy chưa tính.*

### 10.5 ⚠️ Chiều GHI — bốn tầng hậu quả

Chiều ghi **đã tồn tại**: sheet kế hoạch tái phân bổ (P2 Task 15) sửa hạn mức ngân sách
rồi đẩy lên PostgreSQL. Chỉ là quyết định đến từ hệ luật chứ không từ mô hình — và nó
đã có đúng khuôn xác nhận để bắt chước (tick từng dòng, sửa được số, ba lối ra).

Ranh giới nên vẽ theo **hậu quả nếu AI sai**, không theo độ khó kỹ thuật:

| Tầng | Việc | Sai thì sao | Xác nhận |
|---|---|---|---|
| 1 | sửa phân loại (danh mục, từ khoá) | số liệu lệch, sửa lại được | duyệt **cả lô** |
| 2 | tạo mốc theo dõi (ngân sách, mục tiêu, hoá đơn) | nhiễu, không mất tiền | một hộp thoại có số |
| 3 | tạo bản ghi tiền (giao dịch, trả hoá đơn) | **số dư ví sai**, kéo theo mọi thứ | **từng cái**, hiện rõ số |
| 4 | bật `auto_pay` / trích tự động | **tiền thật rời ví lúc người dùng vắng mặt** | 🛑 **AI không chạm** — chỉ dẫn tới công tắc |

⚠️ **`kiemSo` KHÔNG dùng được ở chiều ghi.** Nó chặn mô hình bịa số nhờ có gói số để
đối chiếu; ở chiều ghi không có gói nào — số đến từ câu người dùng. Bộ chắn thay thế
chỉ có một dạng đúng: **không bao giờ ghi thẳng, luôn hiện form điền sẵn.**

⚠️ **Form xác nhận phải hiện LỆNH, không hiện LỜI.** Mô hình có thể nói một đằng gọi
một nẻo — viết *"tạo hoá đơn tiền điện 500 nghìn"* trong khi tham số thật là
`soTien: 5000000`. Form phải dựng từ **tham số hàm**, không từ câu mô hình viết.

Ba thứ **không có hàm nào cả**: bật công tắc tự chuyển tiền, **xoá bất cứ gì**, và
đụng vào đồng bộ / xác thực.

---

## 11. Bản đồ năng lực — AI làm được gì trong hệ thống (khảo sát 2026-09-20)

Quét bằng máy, không theo trí nhớ.

| Đo | Số |
|---|---|
| Mảng tính năng (`lib/features/`) | **13** |
| Route khai trong `app_router.dart` | **43** (41 tuyệt đối + 2 tương đối) |
| Bảng Drift | **10** |
| **Hàm domain thuần** (`*/domain/*.dart`) | **66** |
| Gói số AI đang dùng | **6** (đo lại 2026-09-21) |
| Màn có khối Nhận xét | **6** (đo lại 2026-09-21) |
| Lời gọi biểu đồ `fl_chart` | 8 (→ **9** khối người dùng thấy) |

⚠️ **Hai con số trên là của 2026-09-21, phần còn lại của mục 11 là khảo sát
2026-09-20.** Lúc khảo sát là **4** gói số và **4** màn; chặng 1 thêm hoá đơn,
mục tiêu và ví. Con số **66 hàm domain thuần** thì **giữ nguyên của ngày
2026-09-20** — không phải vì nó còn đúng (thư mục `*/domain/` nay có **70 tệp**,
`vi_hay_dung.dart` và `khoang_tien.dart` thêm sau đó), mà vì **cách đếm cũ không
tái hiện được**, nên thay bằng một con số đếm kiểu khác là làm hỏng chính phép
so sánh mà nó sinh ra để phục vụ. Cần con số mới thì **đếm lại cả hai vế cùng
một cách**, đừng sửa một vế.

### ⭐ Phát hiện chính: app đã tính sẵn 66 thứ, AI mới nói ra 4 (nay là 6)

Tỉ lệ khai thác **dưới 10%** lúc khảo sát — chặng 1 nâng nó lên, nhưng **kết
luận không đổi**: phần lớn việc phía trước vẫn là *gói lại thứ đã tính*. Mỗi hàm trong `*/domain/` là một phép tính **đã xong, đã
có test, đã đúng** — AI chỉ cần gói lại thành `GoiSo` là nói ra được, không phải tính
lại gì. Phần lớn việc phía trước **không phải "thêm AI", mà là "gói lại thứ đã tính"**.

Hai mảng lớn nhất app đang trống:

- **`goal` — 31 tệp, 14 hàm domain, AI mới dùng 2.** ✅ `goal_forecast.duBaoHoanThanh`
  vào gói số ngày 2026-09-21 (chặng 1.4, mục **13**). Còn bỏ qua: `goal_stats`,
  `goal_progress_series`, `goal_wallet_shortfall`, `goal_deposit_warning` — ⚠️ **hai cái
  đầu không phải "chưa làm" mà là "chưa có dữ liệu ở trang"**, xem mục 13.
- **`bill` — 27 tệp, 10 hàm domain.** ✅ **Đã có gói số từ 2026-09-21** (chặng 1.3):
  `GoiSoHoaDon` gói `summarizeBills` + `billDisplayStatusOf`, và trang Hoá đơn có khối
  Nhận xét như các màn kia. Còn chưa chạm: `bill_ky_ke_tiep`, `bill_chain`, `bill_an_han`.

### Bảng theo mảng

| Mảng | Số đã có sẵn | AI làm được | Chiều | Ưu tiên |
|---|---|---|---|---|
| **transaction** | `transaction_filter`, `transaction_lookup`, `khoang_tien`, `vi_hay_dung` | nhập bằng câu · tìm kiếm bằng câu · gắn danh mục hàng loạt | ghi 3 / đọc / ghi 1 | ⭐⭐⭐ |
| **category** | `CategorySuggestionEngine`, cột `keyword` | học từ khoá từ lịch sử · phân loại tự động | ghi 1 | ⭐⭐⭐ |
| **bill** | 10 hàm domain, ✅ **đã có gói số** (`bill_status`) | ~~gói số hoá đơn~~ ✅ xong 2026-09-21 · phát hiện hoá đơn định kỳ · dự đoán số tiền kỳ tới · tạo hoá đơn bằng lệnh | đọc + ghi 2 | ⭐⭐⭐ |
| **goal** | 14 hàm domain, **dùng 2** (`goal_forecast`, `goal_grouping`) | ~~dự báo ngày đạt~~ ✅ xong 2026-09-21 · giải thích vì sao trễ · ví thiếu tiền trích · tạo mục tiêu bằng lệnh | đọc + ghi 2 | ⭐⭐ |
| **analytics** | `thac_nuoc`, `tong_tai_san`, `lich_chi_tieu`, `moc_so_sanh`, `dong_tien_tu_do`… | **giải thích 9 biểu đồ** · chọn khối đáng xem | đọc | ⭐⭐ |
| **analytics / vay-nợ** | `vai_vay_no` | **dư nợ theo người** — đọc tên từ ghi chú | đọc | ⭐⭐ |
| **budget** | `budget_pace`, `budget_impact`, `budget_history`, `cua_so_nhin_lai`, `de_xuat_ngan_sach` | đã có nhận xét + kế hoạch; **đề xuất tạo ngân sách xong 2026-09-21** (thẻ "Chưa đặt ngân sách", trọn sáu Task) | đọc + ghi 2 | ⭐ |
| **wallet** | `vi_tinh_vao_tong`, ✅ **đã có gói số** | ~~giải thích tổng tài sản vs tổng các ví~~ ✅ xong 2026-09-21 | đọc | ⭐ |
| **notification** | 19 loại | chọn loại nào đáng bắn ra hệ điều hành | đọc | ⭐ |
| **analytics / báo cáo** | `bao_cao_xuat`, `xuat_tep` | tóm tắt đầu PDF — ⚠️ xem 11.2 | đọc | cân nhắc |
| **home** | `thu_chi_thang` | đã có | — | — |
| **auth · profile · sync** | — | **không có đất** | — | 🛑 |

⚠️ **Hai điều lượt soát 2026-09-21 tìm ra, đáng nhớ hơn bản thân các con số.**

**(1) Dòng `wallet` sai TỪ GỐC, không phải mới lỗi thời.** Nó ghi việc cần làm là
*"giải thích vì sao số dư lệch"* và trỏ vào `dieu_chinh_so_du` — nhưng từ **G37**
(2026-09-13) số dư ví **suy từ sổ giao dịch**, nên nó **không còn lệch** được
nữa; bảng viết ngày 2026-09-20, tức bảy ngày *sau* khi câu ấy hết đúng. Thứ
người dùng thật sự thấy lệch là **tổng tài sản so với tổng các ví nhìn thấy**
(ví tắt `includeInTotal` và ví lưu trữ bị loại khỏi tổng), và đó mới là thứ khối
Nhận xét trang Quản lý ví giải thích — mục **14**. Việc đã làm, chỉ là **không
đúng việc bảng mô tả**. Bài học: một bảng khảo sát có thể chép lại một câu đã
chết từ trước khi nó được viết ra; đối chiếu với **mã**, đừng đối chiếu với bảng.

**(2) `transaction` là mảng DUY NHẤT chưa có gói số, và đúng ra phải thế.** Cả
ba việc của nó — nhập bằng câu · tìm kiếm bằng câu · gắn danh mục hàng loạt —
đều là **function calling**, tức cần một mô hình chứ không cần gói số. Chúng
nằm ở chặng 2 của `docs/superpowers/plans/2026-09-21-ai-viec-tiep-theo.md`, mà
chặng ấy **đứng sau P3** dù kế hoạch xếp nó trước: nửa sau của 2.1 đòi *"20 câu
lệnh mẫu → đếm bao nhiêu lần chọn đúng hàm"*, và phép đo ấy **cần mô hình mới
đo được**. Đừng đọc ô trống của dòng này như một việc gói số còn sót.

### 11.1 ⚠️ "AI hiểu biểu đồ" — đừng dùng vision

Biểu đồ được vẽ **từ dữ liệu đang nằm sẵn trong máy**. Cho mô hình nhìn ảnh biểu đồ là
bắt nó đọc ngược lại thứ mình vừa vẽ: chậm hơn, tốn RAM hơn, và **đoán số từ pixel thì
sai được** — trong khi đưa thẳng dữ liệu thì chính xác 100% và `kiemSo` kiểm được.

Vision dành cho ảnh **không có dữ liệu đi kèm** (hoá đơn giấy, ảnh chụp app khác), không
phải cho biểu đồ của chính mình.

⚠️ **Điều kiện bắt buộc:** gói số của biểu đồ phải **tính sẵn mọi thứ đáng nói** — kỳ
cao nhất, kỳ thấp nhất, % thay đổi kỳ cuối, trung bình, xu hướng. Đưa chuỗi giá trị trần
thì mô hình sẽ **tự tính** ("tăng 25%"), con số ấy không có trong gói, `kiemSo` chặn, câu
rơi về mẫu — hỏng **im lặng**, trông như mô hình không hoạt động.

### 11.2 Hai chỗ khuyên cân nhắc kỹ

**Tóm tắt đầu báo cáo PDF.** Nghe hợp lý (PDF có 10 khối số mà không câu tổng kết) nhưng
rủi ro hơn mọi chỗ khác: PDF **đi ra ngoài**, gửi cho người khác — câu sai ở đó không ai
kiểm lại được. Và font Roboto nhúng **thiếu glyph**: `→ ▲ ▼` từng bị gói `pdf` bỏ đi im
lặng suốt từ 2026-09-09. Câu do mô hình sinh có thể chứa ký tự ngoài ASCII không lường
trước. Nếu làm thì **bắt buộc** chạy câu qua bộ quét glyph đã có ở `xuat_tep_test.dart`.

**AI viết câu thông báo.** Không nên: thông báo cần ngắn, đoán được, và `dedupeKey` phải
ổn định — câu mô hình sinh mỗi lần một khác thì chống trùng hỏng. Nhưng AI **chọn loại
nào đáng bắn ra hệ điều hành** thì hợp lý.

### 11.3 Năm việc đáng nhất, theo thứ tự

1. **Gắn danh mục hàng loạt** — vá 38% dữ liệu đang mù (15/39 giao dịch của tài khoản
   thật chưa gắn danh mục, đo 2026-09-20), rủi ro thấp nhất (sửa, không tạo; không đụng
   tiền), và **tự sinh dữ liệu huấn luyện cho chính nó**: mỗi lần người dùng duyệt hay
   sửa một đề xuất là một mẫu có nhãn.
2. **Nhập bằng câu** (*"hôm nay tôi đã ăn sáng 40k"*) — việc người dùng làm nhiều nhất;
   bản luật (regex + `CategorySuggestionEngine` đã có) chạy được **không cần mô hình**,
   mô hình chỉ làm nó hiểu câu lạ. ⚠️ Chốt bảng quy đổi `k` / `củ` / `chai` và **hiện rõ
   số đã hiểu** trên form.
3. ✅ **Gói số cho hoá đơn** — **xong 2026-09-21**, xem mục 12.
4. **Trợ lý ra lệnh** (tầng 0 + 2) — tạo hoá đơn, mục tiêu, ngân sách bằng câu nói, qua
   function calling. ⚠️ Đo **tỉ lệ chọn đúng hàm** trước khi mở tầng 3: mô hình 2,3 tỉ
   tham số chọn sai thường xuyên hơn mô hình lớn, và *"tạo tiết kiệm 5 triệu"* có thể là
   ba hàm khác nhau. Phép đo ấy cũng là một bảng số cho báo cáo.
5. **Giải thích biểu đồ** — chín lần cùng một việc (mỗi khối một hàm dựng gói số), nhưng
   mạnh nhất khi demo.

### 11.4 Việc đã chốt nhưng chưa làm

Bốn việc cá nhân hoá ở tầng số, người dùng chọn cả bốn ngày 2026-09-20 (xem memory
`ai-ca-nhan-hoa-cho-tung-nguoi-dung`): học mức thiết yếu từ phản hồi · tự đề xuất bật cờ
Cố định · học nhịp chi theo ngày trong tháng · phát hiện khoản chi bất thường theo danh
mục.

⚠️ **Luật chung cho cả bốn:** mỗi luật có **ngưỡng mẫu tối thiểu, dưới ngưỡng thì im
lặng hoàn toàn**, rồi tự bật khi đủ. Không có ngưỡng thì luật sẽ "im hàng tháng rồi nổ
bừa ngay khi vừa đủ mẫu" — đúng sai lầm mà mục 5f `NOTIFICATION_FEATURE.md` đã loại một
lần. Chỗ trống rõ nhất để cắm: **essentiality đang để cứng 0,5** cho mọi danh mục
(`tai_phan_bo.dart`), khiến phép xếp hạng C6 quy về xếp theo dư địa — mà bảng
`AiRebalancingFeedbacks` **đã ghi sẵn** dữ liệu để học.

### 11.5 Năm chỗ cá nhân hoá được nữa — tìm bằng cách quét HẰNG SỐ

Cách tìm: **mỗi hằng số cứng trong `lib/` là một câu nói "mọi người dùng giống nhau"**.
Quét bằng máy ngày 2026-09-20. ⚠️ **Bốn trong năm nhóm dưới không cần mô hình gì cả** —
chúng là đếm tần suất và neo theo một con số đã có, đúng kết luận mục 10.3: *cá nhân hoá
nằm ở tầng số, không ở mô hình*.

#### ✅ (1) App đã cá nhân hoá MỘT ngưỡng, năm cái kia thì cứng — **XONG 2026-09-21**

Luật tái phân bổ có sáu ngưỡng; đúng **một** cái neo theo người dùng:

```dart
nguongCoNghia = max(1% thuNhapMoiThang, 50.000)   // ← đã cá nhân hoá
```

Năm cái còn lại là số tuyệt đối cho mọi người (`tai_phan_bo.dart`):

| Hằng | Giá trị | Vấn đề |
|---|---|---|
| `kNguongThamHutTuyetDoi` | 50.000 đ | người thu nhập 5 triệu và người 50 triệu **dùng chung một con số** |
| `kDuDiaToiThieu` | 100.000 đ | nt |
| `kBuocLamTron` | 10.000 đ | người tiêu lớn thấy đề xuất lẻ tẻ |
| `kNguongThamHutTiLe` | 10 % | tỉ lệ — có thể hợp lý cho mọi người |
| `kTranCat` / `kTranCatDaBiCat` | 25 % / 15 % | nt |

Với người thu nhập 50 triệu, thâm hụt 50.000 đ là tiền lẻ — mà app vẫn dựng cả một kế
hoạch cắt giảm cho nó. Đây là **sự không nhất quán app đã tự tạo ra**, và nó lộ ra chính
vì `nguongCoNghia` làm đúng.

**Sửa rẻ nhất trong cả mục 11:** cho ba hằng đầu đi qua cùng phép neo. Không cần AI,
không cần dữ liệu mới — `thuNhapMoiThang` đã có sẵn trong `DuLieuTaiPhanBo`. Hai hằng cuối
là **tỉ lệ** nên giữ nguyên là hợp lý.

✅ **Đã làm 2026-09-21.** Ba hằng đầu nay đi qua **một** phép neo duy nhất `_neo(thu
nhập, tỉ lệ, sàn) = max(tỉ lệ × thu nhập, sàn)`, hằng cũ thành **sàn**:

| Hàm mới | Công thức | Sàn |
|---|---|---|
| `nguongThamHutTuyetDoi` | 1 % thu nhập | 50.000 |
| `duDiaToiThieu` | 2 % thu nhập | 100.000 |
| `buocLamTron` | 0,2 % thu nhập, rồi kéo lên họ 1·2·2,5·5 | 10.000 |

Tỉ lệ chọn sao cho **cả ba xoay quanh cùng một mốc: thu nhập 5 triệu/tháng**. Dưới mốc ấy
không gì đổi, đúng tại mốc thì cả ba bằng đúng hằng cũ, trên mốc thì cả ba giãn ra mà
**giữ nguyên tỉ lệ với nhau** — tức luật vẫn là luật cũ, chỉ đổi đơn vị đo.

⚠️ **`thuNhapMoiThang` là trung bình MỘT THÁNG**, không phải tổng cả cửa sổ
(`_thuNhapMoiThang` quy về mức tháng bằng `tổng / số ngày × 30`). Đọc nhầm là mọi tỉ lệ
trên lệch hẳn một bậc, **im lặng**.

🛑 **Và cho tới 2026-09-21, phép neo này CHƯA TỪNG CÓ HIỆU LỰC.** `thuNhapMoiThang` khi ấy
tên là `thuNhap3Thang` và cắt **ba tháng lịch liền trước**; đo trên CSDL dev ngày
2026-09-21 thì giao dịch sớm nhất trong **toàn bộ** CSDL là **02/09/2026** và không có hàng
nào trước tháng 9 — nên cửa sổ ấy rỗng trên **mọi** tài khoản, con số luôn bằng **0**, và
`max(1% × 0, 50.000)` luôn trả đúng cái sàn mà việc neo sinh ra để thay thế. Mã đúng, đầu
vào chết.

Cửa sổ nay **cuộn theo ngày** — `cuaSoNhinLai` ở `features/budget/domain/cua_so_nhin_lai.dart`,
tối đa **90** ngày, ngắn lại theo tuổi dữ liệu của tài khoản, và **im hẳn** (trả `null`,
người gọi hiểu là 0) khi tài khoản trẻ hơn **14** ngày. Cùng cửa sổ ấy nuôi `suggestAmount`.
Spec: `docs/superpowers/specs/2026-09-21-cua-so-nhin-lai-va-de-xuat-tao-ngan-sach-design.md`.

⚠️ Bài học chung, không riêng chỗ này: **một luật có thể đúng hoàn toàn về mã mà vẫn chưa
bao giờ chạy**, nếu đầu vào của nó đến từ một cửa sổ mà dữ liệu thật không lấp đầy. Bộ test
không bắt được — nó dựng sẵn ba tháng dữ liệu. Thứ bắt được là một phép đo trên **CSDL
thật**.

⚠️ **`buocLamTron` có thêm một vế mà hai cái kia không có**: nó phải kéo lên họ
**1·2·2,5·5** (`buocTron`, nay công khai từ `du_bao_dong_tien.dart` — chép sang là bản thứ
hai của cùng một luật). Lý do: hai ngưỡng kia chỉ đem đi **so sánh** nên số lẻ vô hại, còn
bước làm tròn quyết định **con số người dùng đọc** — thiếu vế ấy thì thu nhập 12 triệu cho
bước 24.000 và màn hình đầy 24.000 / 48.000 / 72.000.

⚠️ **`kBuocLamTron` dùng ở HAI chỗ** — `lamTron10k()` (nay là `lamTronBuoc(x, buoc)`, vì
cái tên cũ thành lời nói dối khi bước biến thiên) và phép "làm tròn LÊN" trong vòng chọn
nguồn bù. Sửa một chỗ quên chỗ kia thì tổng cắt lệch vài nghìn, **im lặng**.

⭐ **Phát hiện ngoài dự kiến: luật C4 (`kDuDiaToiThieu`) đã CHẾT từ trước, bị C5 nuốt
trọn.** Nguồn bù bị C4 loại có dư địa dưới ngưỡng, nên phần cắt 25 % của nó luôn dưới
ngưỡng có nghĩa của C5 — C5 đã loại nó trước, ở **mọi** mức thu nhập kể cả 0. Vẫn neo C4
cho nhất quán, nhưng **đừng viết ca test hành vi cho nó**: ca ấy sẽ xanh vì lý do khác.
Biết được là nhờ **bản sai có chủ ý** — ca hành vi đầu tiên viết cho C4 vẫn xanh khi chưa
neo gì cả. Cùng họ bẫy **G43**: ca test phải đòi KẾT QUẢ, không chỉ đòi vắng mặt thứ mình
nghĩ tới.

#### ✅ (2) Ví chọn sẵn theo ngữ cảnh — **XONG 2026-09-21**

`chonViChonSan` (`transaction/domain/vi_chon_san.dart`) chọn **ví mặc định**, rơi về ví
đầu danh sách — **giống nhau mọi lúc**, không theo danh mục, không theo giờ.

Thói quen thật thì có mẫu: ăn uống trả tiền mặt, mua sắm online trả ví ngân hàng. Học
bằng **đếm tần suất** (*"danh mục Ăn uống → 9/10 lần dùng ví Tiền mặt"*), cùng loại phép
tính với `suggestAmount`. Giảm **một cú chạm mỗi lần nhập giao dịch** — mà nhập giao dịch
là việc làm nhiều nhất trong app.

✅ **Đã làm 2026-09-21.** Luật thuần ở `transaction/domain/vi_hay_dung.dart`
(`demViTheoDanhMuc` → `viHayDungCho` → `viHayDungTheoDanhMuc`), trang Thêm giao dịch nạp
bảng một lần lúc mở rồi chỉ **tra bảng** khi người dùng chọn danh mục.

⚠️ **Kế hoạch phác là thêm tham số `viHayDung` vào `chonViChonSan` — làm thế là SAI**, và
lý do đáng nhớ: `chonViChonSan` chạy lúc **mở trang**, khi chưa có danh mục nào để tra.
Luật mới phải chạy ở `_chonDanhMuc`, tức một câu hỏi khác (*"vừa chọn danh mục này thì ví
nào?"*) nên là một hàm khác, không phải tham số của hàm cũ.

**Ba cửa chặn, thiếu cửa nào cũng hỏng theo một kiểu riêng:**

| Cửa | Vì sao |
|---|---|
| chưa đủ **5** giao dịch cùng danh mục | ví nhảy theo một giao dịch lẻ còn tệ hơn ví mặc định đứng yên |
| ví dẫn đầu không **vượt 60 %** | 3–2 gần như tung đồng xu; đòi *vượt* chứ không *chạm*, vì 3/5 đúng bằng 0,6 |
| người dùng **đã tự đặt ví**, hoặc đang **sửa** giao dịch | phép đoán không bao giờ đè lên lựa chọn cố ý; ở chế độ sửa, ví quyết định **ví nào bị trừ tiền** |

⚠️ **Hai ca test xanh ngay từ đầu, và bản sai lộ ra MỘT trong hai canh nhầm chỗ:** ca
"chế độ sửa" bản đầu chỉ mở trang rồi xem ví — nó xanh cả khi bỏ **sạch** hai cửa cuối,
vì ở chế độ sửa danh mục đặt thẳng trong `initState` chứ không đi qua `_chonDanhMuc`. Ca
đúng phải **đổi danh mục** khi đang sửa. Cùng họ bẫy **G43**.

**Nghiệm thu máy ảo trên dữ liệu thật (tài khoản 10, 39 giao dịch):** bảng học được đúng
**một** mục — `Di chuyển → Tiền mặt` (6/6). Mọi danh mục khác im vì chưa đủ mẫu, trong đó
**Giáo dục** có 2 giao dịch **đều ở ví `test`** — chạm vào nó trên máy ảo, ví thanh toán
**giữ nguyên Tiền mặt**, tức ngưỡng mẫu chạy đúng ngoài đời. ⚠️ **15/39 giao dịch bị bỏ**
vì trống danh mục hoặc trống ví — cùng con số "38 % dữ liệu mù" mà chặng 3.1 nhắm tới.

⚠️ **Điều KHÔNG nghiệm thu được, phải nói ra:** trên tài khoản ấy ví mặc định *cũng là*
Tiền mặt, nên phép **đổi ví** không có cách nào hiện ra. Chiều dương chỉ được phủ bởi
widget test; muốn thấy thật thì cần một tài khoản có ≥ 5 giao dịch cùng danh mục ở một ví
**khác** ví mặc định.

#### (3) Ngưỡng cảnh báo ngân sách 70 % / 90 %

`budget_visuals.dart`: `_cautionAt = 0.70`, `_criticalAt = 0.90` — cứng cho mọi người.
Nhưng 70 % vào ngày 20 là bình thường, còn 70 % vào ngày 5 là báo động.

⭐ **Ghép thẳng với việc #3 của mục 11.4** (học nhịp chi theo ngày trong tháng): nhịp chi
không chỉ dùng để dự phóng cuối kỳ mà còn để **dịch ngưỡng cảnh báo** theo từng người.
Một phép học, hai chỗ dùng.

#### (4) Thứ tự khối trang Phân tích

Trang có **10 khối mang tiêu đề** (đếm `_tieuDeKhoi` ngày 2026-09-20), thứ tự giống nhau
với mọi người. Người không có mục tiêu tiết kiệm vẫn cuộn qua khối mục tiêu.

Hai mức: **rẻ** — soát lại khối nào chưa tự ẩn khi không có dữ liệu (nhiều khối đã ẩn);
**học** — đếm khối nào người dùng hay cuộn tới rồi dừng, đưa lên trên. Trang chủ đã làm
một phần: `pickHomeBudget` chọn ngân sách **căng nhất** thay vì ngân sách đầu tiên.

#### (5) Tần suất thông báo theo phản ứng

19 loại, hiện đối xử như nhau. Nhưng người dùng **đã nói cho ta biết** họ nghĩ gì: loại
nào hay bị vuốt bỏ ngay, loại nào hay được chạm vào.

⚠️ **Không đụng `dedupeKey`** — chống trùng phải giữ nguyên; chỉ đổi việc *có bắn ra hệ
điều hành hay không*. Và giữ nguyên `luonBao`: bốn loại báo "app vừa rút tiền của bạn"
không bao giờ được giảm tần suất.

---

## 12. Gói số hoá đơn và khối Nhận xét trang Hoá đơn (2026-09-21, chặng 1.3)

Gói số **thứ năm**, và là tệp mẫu cho gói mục tiêu mở rộng (1.4) lẫn gói ví (1.5).
Trước lượt này mảng `bill` — 27 tệp, 10 hàm domain — không có gói số nào.

**Tệp:** `ai_edge/domain/goi_so_hoa_don.dart` · khối nối ở `bill_page.dart` giữa thẻ tổng
quan và hàng tab, theo màn Stitch **`179dbd70b0fd4b6a97df6b7d2c38d0e2`**
*"Hoá đơn - Khối Nhận xét AI"*.

**Số lấy từ đâu** (lớp này không tính — test quét thứ 14): `summarizeBills` cho tiền và
số hoá đơn của **kỳ này**, `billDisplayStatusOf` cho phép đếm quá hạn.

Bốn nhánh mẫu câu: kỳ rỗng · **có quá hạn** (mức cảnh báo, nói trước mọi thứ khác vì đó
là điều duy nhất cần làm ngay) · còn nợ · đã trả xong cả kỳ.

⚠️ **Phép đếm quá hạn phải lặp lại bộ lọc "chặn ở cuối tháng" của `summarizeBills`.**
Thiếu nó thì con số quá hạn nói về một tập hoá đơn khác với con số tiền đứng ngay cạnh
trong cùng một câu, và không có gì báo. (Vế "bỏ kỳ đã bỏ qua" thì không cần lặp —
`billDisplayStatusOf` tự trả `skipped`.)

⚠️ **Kỳ rỗng thì `soLieu` rỗng, không phải "Quá hạn: 0".** Một thẻ số liệu bằng 0 ở đây
là ô trống đội lốt số liệu; nhánh thiếu dữ liệu vẫn là **một câu thật** (mục 1).

⚠️ **Vế "đã trả" chỉ thêm khi có tiền đã trả thật** — "đã trả 0 đ (0,0%)" làm câu dài ra
mà không nói thêm gì.

⚠️ **Lượt nối khối làm đỏ hai ca test cũ, và một trong hai là lỗi THẬT.** Ca thứ nhất chỉ
là `find.textContaining('60.000')` nay tìm ra ba chỗ vì câu nhận xét nhắc lại cùng con số
— thẻ tổng nay mang khoá `bill-tong-con-phai-tra` để ca cũ trỏ đúng nó. Ca thứ hai nghiêm
trọng hơn: khối lấy bớt chiều cao của `Expanded`, mà **trạng thái rỗng của danh sách là
`Column` cao cố định**, nên nó **tràn 73 px** ở khổ màn thấp. Máy cao không thấy gì đổi —
đúng vùng mù số 1 của `flutter test`. Nay nó cuộn được, và có ca canh ở khổ 411×600.

**Nghiệm thu máy ảo (tài khoản 10):** câu *"Có 1 hoá đơn quá hạn; kỳ này còn phải trả
155.000 đ."* với viền cảnh báo, năm thẻ số liệu, **0 dòng tràn bố cục** trong logcat, con
số khớp thẻ tổng ngay trên nó.

⚠️ **Một chỗ lệch CÓ TỪ TRƯỚC, không phải do lượt này:** thẻ tổng và khối Nhận xét nói
*"3 hoá đơn"* trong khi tab nói *"Cần thanh toán (4)"*. Hai con số đếm hai thứ khác nhau
— thẻ và khối nói về **kỳ này** (chặn ở cuối tháng), tab liệt kê **mọi hoá đơn chưa
đóng** kể cả kỳ sau. Đừng "sửa" cho khớp mà chưa quyết xem con số nào mới là con số người
dùng cần.

---

## 13. Dự báo theo nhịp thật vào gói số Mục tiêu (2026-09-21, chặng 1.4)

`duBaoHoanThanh` nay vào `GoiSoMucTieu`: câu thêm một vế *"Theo nhịp hiện tại cần thêm N
ngày."* và một thẻ số liệu cùng tên.

⚠️ **ĐÍNH CHÍNH (cùng ngày, trước khi push):** bản đầu của mục này — và commit đầu của
chặng 1.4 — viết rằng hàm ấy *"không có một chỗ gọi nào trong `lib/`"*. **Sai.** Nó đang
chạy ở `goal_detail_page.dart:1082`, dựng hộp *"DỰ BÁO HOÀN THÀNH: THÁNG MM/yyyy"*. Câu
đúng là: **gói số của AI** chưa dùng nó, chứ không phải app chưa dùng. Nguồn của sai lầm:
một lệnh `grep` trả về **rỗng** và tôi tin vào cái rỗng ấy — đúng cái bẫy mục "Ghi chú vận
hành" `CLAUDE.md` đã ghi (*"lần trước là `grep` qua rtk"*). Bài học lặp lại: **một phép đo
trả về rỗng phải được kiểm bằng đường thứ hai** trước khi thành một câu khẳng định.

**Vì sao nó đáng thêm dù đã có `isBehindSchedule`:** cờ ấy trả lời *có chậm không*, còn
dự báo trả lời *chậm bao nhiêu*. Mục tiêu thử của bộ test còn **120 ngày** tới hạn nhưng
theo nhịp thật cần **323 ngày** — hai con số ấy mới nói ra mức độ.

⚠️ **Chỉ hiện khi chậm kế hoạch hoặc đã quá hạn.** Mục tiêu đang ổn mà vẫn in "cần thêm N
ngày" là tiếng ồn: người dùng đã biết mình ổn, và một con số thừa làm câu khó đọc hơn.

⚠️ **`null` là *chưa biết*, không phải 0.** Bốn đường cho `null`: thiếu mốc gốc (mục tiêu
do bản app cũ tạo), chưa qua đủ nửa chu kỳ, chưa tích đồng nào (tốc độ 0 → ngày ở vô cực),
và nhịp chậm tới mức ngày đạt vượt 100 năm. Lấp bằng `?? 0` là bịa ra một lời hứa — cùng
lỗi mà `thayDoiTaiSan` (mục 3.30 `ANALYTICS_FEATURE.md`) đã chặn. Ba ca test canh việc im
lặng ấy đều **xanh ngay từ đầu**, chỉ chứng minh được bằng một bản sai cố ý.

⚠️ **Một kỳ vọng cũ phải sửa, và nó là bài học về phép đo gián tiếp:** ca "quá hạn" trước
đây đòi `isNot(contains(' ngày'))` để nói rằng câu *không in vế "còn N ngày"*. Từ lượt này
câu kết thúc bằng "cần thêm 323 ngày" — một con số khác hẳn về nghĩa — nên kỳ vọng ấy đỏ
dù hành vi vẫn đúng. Nay nó đòi thẳng điều nó muốn: `isNot(matches(RegExp(r'còn -?\d+
ngày')))`.

### ⚠️ Hai việc còn lại của chặng 1.4 KHÔNG làm được ở đây — thiếu dữ liệu, không phải thiếu công

Kế hoạch xếp ba dòng *"vì sao mục tiêu trễ"*, *"ví thiếu tiền trích"*, *"dự báo ngày đạt"*
thành **một** việc là "gói số cho `goal`". Đo bằng mã thì chúng **không cùng một việc**:

| Hàm | Cần gì | Trang **danh sách** có chưa | App đã dùng ở đâu |
|---|---|---|---|
| `duBaoHoanThanh` | chính `GoalEntity` | ✅ → **đã làm** | `goal_detail_page.dart:1082` |
| `thongKeMucTieu` | danh sách `KhoanTichLuy` | ❌ phải nghe thêm `watchGoalTransactions` | `goal_stats_card.dart:34` |
| `canhBaoViKhongDu` | tên ví, số dư ví, tổng mọi mục tiêu trỏ vào ví ấy | ❌ `GoalLoaded` không mang ví nào | `goal_detail_page.dart:221` |

⚠️ **Cột cuối đổi hẳn ý nghĩa của việc này.** Cả ba hàm **đã là tính năng sống** trên
trang **Chi tiết mục tiêu**. Đưa chúng vào khối Nhận xét của trang **danh sách** không
phải "bật một hàm đang nằm im" mà là **nhắc lại trên màn khác** — có thể vẫn đáng (xem mà
không phải mở chi tiết), nhưng đó là một quyết định về trùng lặp, không phải về năng lực.

`GoalLoaded` hiện chỉ có `goals`, `totalTargetAmount`, `totalCurrentAmount`. Hai hàm kia
đòi **mở thêm nguồn dữ liệu cho trang** (state + repository), không phải viết thêm một
mẫu câu — đó là một hạng mục riêng, và nên cân nhắc là `canhBaoViKhongDu` cảnh báo về một
**mâu thuẫn dữ liệu thật** (tiền tích luỹ bị tiêu mất), thứ có lẽ xứng đáng một thông báo
chứ không phải một vế trong câu.

**Nghiệm thu máy ảo:** mục tiêu thật của tài khoản 10 (MuaXe, 55 %) đang **đúng kế hoạch**
nên vế dự báo im — đúng thiết kế, và đó là tất cả những gì tài khoản ấy chứng minh được.
Chiều dương chỉ có bộ test phủ.

---

## 14. Gói số ví và khối Nhận xét trang Quản lý ví (2026-09-21, chặng 1.5)

Gói số **thứ sáu**. Câu hỏi nó trả lời là câu người dùng thật sự hay hỏi về ví: *"vì sao
tổng tài sản không bằng tổng các ví tôi nhìn thấy?"* — và đáp án nằm ở hai chỗ tiền **cố
ý** bị loại: ví tắt cờ `includeInTotal`, và ví đã **lưu trữ**. Cả hai là lựa chọn của
chính người dùng, nhưng họ chỉ thấy **hệ quả** (một con số nhỏ hơn) chứ không thấy nguyên
nhân.

**Tệp:** `ai_edge/domain/goi_so_vi.dart` · khối nối ở `wallet_list_page.dart` **ngay dưới**
thẻ tổng quan, theo màn Stitch **`6adf2ad12af246cb87bb1bcc52ddb2b2`**
*"Quản lý ví - Khối Nhận xét AI"*.

⚠️ **Luật "ví nào cộng vào tổng" gọi lại `viTinhVaoTong`, không viết lại.** Chính hàm ấy
sinh ra để dẹp **bốn** bản chép tay không khớp nhau; thêm bản thứ năm trong gói số là tái
hiện đúng lỗi nó đã chữa.

⚠️ **Truyền MỌI ví vào gói, kể cả ví lưu trữ.** Trang chia sẵn `viHoatDong` / `viLuuTru`
để hiển thị, nhưng đưa `viHoatDong` vào gói thì chỗ tiền bị loại khỏi tổng — đúng thứ khối
này sinh ra để nói — biến mất khỏi phép đếm.

⚠️ **Ví đã xoá mềm bị loại khỏi CẢ HAI vế**, kể cả vế "ngoài tổng". Đó là G42 ở dạng khác:
cộng ví đã xoá vào một con số hiển thị.

⚠️ **Ví bật cờ cho phép âm KHÔNG đếm vào "ví đang âm"** — đúng luật G27. Nghiệm thu máy ảo
chạy đúng vào nhánh này: tài khoản 10 có ví `test` đang **−100.000 đ** với
`allow_negative = 1`, và khối **im lặng** về nó, đúng thiết kế.

**Nghiệm thu máy ảo:** câu *"Tổng tài sản 13.004.000 đ từ 4 ví."*, con số **khớp đúng** thẻ
tổng quan ngay trên nó, **0 dòng tràn bố cục**.

⚠️ **Lượt nối khối làm đỏ hai ca test cũ của mảng ví**, và lần này **không** phải lỗi thật:
khối thêm ~100 px vào đầu trang, đẩy mục "Đã lưu trữ" xuống dưới mép khung **600 px** của
bộ test, nên `tap` trượt. Nay bốn chỗ `tap` nút ba chấm đều `ensureVisible` trước. Bài học
chung với mục 12: **thêm một khối vào đầu trang là đổi ngữ cảnh của mọi ca test cuộn tới
cuối trang ấy**.

⚠️ **Lời gọi Stitch trả về `timeout` nhưng màn VẪN được tạo** (`6adf2ad1…`) — lần thứ ba
xác nhận bài học ở mục "Ghi chú vận hành" `CLAUDE.md`: **timeout không phải thất bại, và
đừng gọi lại**.
