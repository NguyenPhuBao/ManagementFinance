# Gia đình — 02d. Ngân sách chung, báo cáo tháng, báo khi có người chi / góp

> **Ngày:** 2026-10-26 · **Trạng thái:** thiết kế người dùng đã duyệt, chưa có mã · **Người đọc:** backend, PO, client.
> **Cần trước:** `02A` (bảy loại hàng, số liệu của nhà). Quyết định gốc: `00_TONG_QUAN.md` mục 2 — #5 dữ liệu nhà **chỉ** trong khu *Nhà mình*,
> #9 Chủ nhà cấu hình.

---

## 1. Mục đích

Ba thứ giúp cả nhà nhìn chung một bức tranh: **ngân sách** cho chi tiêu của nhà, **báo cáo tháng**, và **thông báo** khi người khác chi / góp.
Phần backend gần như không có gì mới — ngân sách của nhà đi đường đồng bộ đã có (cột `Idhousehold` trên `budget`, đơn 50 B).

## 2. Ngân sách chung

### 2.1 Người dùng thấy gì

- Khu **Nhà mình** có tab / khối **Ngân sách**: danh sách ngân sách của nhà, mỗi thẻ *đã chi / hạn mức* + thanh tiến độ — **dùng lại khối giao
  diện** của trang Ngân sách cá nhân, **không** hiện ngân sách của nhà ở trang Ngân sách cá nhân (`/budget`) hay Trang chủ (quyết định #5).
- **Chủ nhà** tạo / sửa / xoá (form ngân sách ở *chế độ nhà*: chỉ danh mục chi của nhà, hoặc *tổng*; không có chế độ **Chặn** — ngân sách của
  nhà chỉ cảnh báo, cùng lý do với hạn mức `02B`). Thành viên, Chỉ xem: chỉ xem.
- **Lúc ghi chi** (chế độ nhà): nếu khoản làm vượt một ngân sách của nhà ⇒ thêm dòng *"Vượt ngân sách {Ăn uống} của nhà"* vào **cùng hộp** xác
  nhận với hạn mức (`02B` mục 2) — một hộp, không hai.

### 2.2 Luật

- Là hàng `budget` có `Idhousehold` (đơn 50 B); chỉ **Chủ nhà** tạo / sửa / xoá (`01` mục 3 — server `HOUSEHOLD_ROLE_FORBIDDEN`);
  `idcategory` phải là danh mục của nhà (luật tham chiếu đơn 50 D.2).
- **Kỳ và lặp lại** như ngân sách cá nhân: kỳ của ngân sách lặp **tính bằng số học từ mốc gốc** (`budget_period.dart` — `advancePeriodFrom`),
  không sinh hàng mới mỗi kỳ ⇒ nhiều máy trong nhà không nhân bản ngân sách.
- **Đã chi** = Σ **Chi của nhà** (`02A` mục 3 — loại 1) ở **mọi ví chung**, ngày trong kỳ (biên `[from, to)`), khớp danh mục theo
  `khoanThuocNganSach` (tổng ⇒ mọi danh mục; theo danh mục ⇒ đúng id, không gộp danh mục con). **Không** tính góp, rút, chuyển, neo, điều chỉnh.
- Phép tính *đã chi* là **một** hàm (`household/domain/ngan_sach_nha.dart`) dùng chung cho thẻ, hộp lúc ghi và luật thông báo; mượn
  `khoanThuocNganSach` + số học kỳ có sẵn, không chép lại.
- Trang Ngân sách cá nhân, khối Nhận xét, tool ngân sách của Trợ lý AI, *Đề xuất cân đối ngân sách*: **không** đọc ngân sách của nhà (lọc
  `idhousehold IS NULL` — spec 2026-10-23 mục 7.2).

### 2.3 Thông báo (nhóm *Gia đình*, mặc định **bật**, máy Chủ nhà **và** Thành viên — Chỉ xem không nhận)

| Loại | Khi | Khoá chống trùng | Câu |
|---|---|---|---|
| `nhaNganSachSapHet` | đã chi **lần đầu** chạm ngưỡng cảnh báo của chính ngân sách (`thresholdWarningPercent` / `thresholdWarningAmount`, không đặt ⇒ 80%) trong kỳ | `nhaNganSach:<idbudget>:<mã kỳ>:canhBao` | *"Ngân sách {Ăn uống} của nhà sắp hết"* |
| `nhaNganSachVuot` | đã chi vượt 100% trong kỳ | `nhaNganSach:<idbudget>:<mã kỳ>:vuot` | *"Ngân sách {Ăn uống} của nhà đã vượt"* |

Câu không mang số tiền; mỗi ngưỡng mỗi kỳ một lần; mốc *im lặng trước* = lúc vào nhà (không báo cho các kỳ đã qua khi kéo toàn bộ lần đầu).

## 3. Báo cáo tháng của nhà

- Khu **Nhà mình** → **Báo cáo**. Chọn **tháng** (lùi / tiến; không tuần / quý — phạm vi đã chốt là *báo cáo tháng*).
- Nội dung, mọi con số từ hàm domain ở `household/domain/bao_cao_nha.dart` (dựa trên `so_lieu_nha.dart` của `02A`):
  1. **Tiền vào quỹ** (góp + thu khác) · **Tổng chi** (chi của nhà) · **Chênh lệch** — kèm % so với tháng trước (`phanTramSoVoi` có sẵn —
     tháng trước 0 ⇒ không hiện %).
  2. **Theo từng người:** góp · rút · chi (người đã rời hiện tên + *"(đã rời)"*).
  3. **Theo danh mục:** biểu đồ tròn chi của nhà (dùng lại widget donut của trang Phân tích — `fl_chart` 1.2.0 ghim, `FlClipData.all()`).
  4. **Theo ví chung:** số dư đầu / cuối tháng (suy ngược từ số dư hiện tại như *Dòng tiền đầu / cuối kỳ* của trang Phân tích — 3.16).
- **Không** xuất tệp (ngoài phạm vi). Mọi người trong nhà xem được (Chỉ xem cũng vậy) — báo cáo **không** chứa hạn mức hay định mức (thứ có luật
  riêng tư).
- Tầng vẽ không test được bằng `flutter test` ⇒ nghiệm thu bằng mắt trên máy thật (hàng *biểu đồ* `CLAUDE.md`).

## 4. Báo khi có người chi / góp

| Loại | Mặc định | Khi | Khoá | Câu |
|---|---|---|---|---|
| `nhaCoGiaoDich` | **tắt** (bật ở Cài đặt → Thông báo → *Gia đình*) | một **Chi của nhà**, **Góp** hoặc **Rút** (nửa của nhà) do **người khác** ghi, tới máy qua kéo về | `nhaGiaoDich:<idtran>` | *"{An} vừa chi {120.000 đ} · {Tiền chợ}"* / *"{Minh} vừa góp {2.000.000 đ} vào {Tiền chợ}"* |

- Câu **được** mang số tiền: khoá theo id khoản nên số tiền không ảnh hưởng chống trùng (khác các loại khoá theo kỳ ở trên).
- **Mốc im lặng trước** = muộn hơn trong hai mốc *lúc bật công tắc* và *lúc vào nhà* — lần kéo toàn bộ khi mới vào nhà mang về hàng trăm khoản cũ,
  không được đổ ra hàng trăm thông báo (khuôn `silenceBefore` của *Khoản chi lớn*, 5f `NOTIFICATION_FEATURE.md`). So theo **ngày tạo của
  hàng trên máy** không đủ (hàng kéo về nào cũng *mới* với máy) — so theo **ngày giao dịch** như *Khoản chi lớn*.
- Khoản bị sửa sau đó: không báo lại (khoá theo id). Khoản bị xoá trước khi máy kịp báo: không báo.
- Giới hạn: *"vừa"* là khi máy **kéo được** khoản về — tức thì nếu app đang mở (socket), hoặc lượt nền kế tiếp (`00` nguyên tắc 6).

## 5. Việc backend

- **Không** bảng / endpoint / sự kiện mới.
- Ma trận quyền `01` mục 3 đã gồm `budget` của nhà (chỉ Chủ nhà); luật tham chiếu đơn 50 D.2 đã gồm `idcategory` của ngân sách.
- `sync.completed` tới mọi thành viên (đơn 50 F) — điều kiện để `nhaCoGiaoDich` và cảnh báo ngân sách tới kịp khi app đang mở.

## 6. Phía client

- `household/domain/`: `ngan_sach_nha.dart` (đã chi), `bao_cao_nha.dart` (báo cáo tháng) — Dart thuần, mượn `khoanThuocNganSach`,
  `advancePeriodFrom`, `phanTramSoVoi`, `[from, to)`; không chép luật.
- `budget/`: form và thẻ ngân sách nhận **phạm vi** (cá nhân / nhà H) qua nguồn dữ liệu — không nhân đôi trang; DAO ngân sách thêm phép đọc
  theo nhà (`…TheoNha(idhousehold)`, spec 2026-10-23 mục 7.2 dời sang phần cần nó — là phần này).
- `NotificationKind` thêm `nhaNganSachSapHet`, `nhaNganSachVuot`, `nhaCoGiaoDich` (nhóm `giaDinh`); `nhaCoGiaoDich` có công tắc riêng trong
  nhóm (mặc định tắt — khuôn `nguongChiLon` / `docBienDong`).
- Màn **Ngân sách của nhà**, **Báo cáo tháng của nhà**, hàng công tắc *"Báo khi có người chi / góp"* — đưa lên Stitch trước.

## 7. Kiểm thử và nghiệm thu

- **Domain:** đã chi của nhà không gồm góp / rút / chuyển / neo / điều chỉnh; khớp danh mục đúng id; kỳ lặp (tháng ngắn, năm nhuận) qua
  `advancePeriodFrom`; báo cáo tháng — người đã rời, tháng trước 0 ⇒ không %, số dư đầu / cuối suy ngược.
- **Thông báo:** ngưỡng ngân sách một lần mỗi kỳ; `nhaCoGiaoDich` không báo khoản của chính mình, không báo khoản cũ lúc vào nhà, không báo lại
  khi khoản bị sửa.
- **Không rò:** trang Ngân sách cá nhân, Trang chủ, khối Nhận xét, tool AI không thấy ngân sách / khoản của nhà (ca DAO + quét 37 của phần 1).
- **Widget:** tab Ngân sách của nhà, báo cáo ở 360 dp, số 13 chữ số.
- **Nghiệm thu hai máy thật:** Chủ nhà đặt ngân sách *Ăn uống* 500.000 đ → Thành viên chi 450.000 đ ⇒ cả hai máy báo *sắp hết* → bật
  *"Báo khi có người chi"* ở máy Chủ nhà → Thành viên chi tiếp ⇒ máy Chủ nhà nhận *"… vừa chi …"* và *"… đã vượt"*; báo cáo tháng hai máy cùng số.

## 8. Câu hỏi để thảo luận

- **Q-D1** — Không có gì cần backend làm ngoài phần 1 + 2a. Backend thấy còn thiếu gì (ví dụ cần trả ngân sách của nhà trong `/me` cho Admin-web)?

## 9. Trả lời / thảo luận

*(Chờ backend / PO.)*
