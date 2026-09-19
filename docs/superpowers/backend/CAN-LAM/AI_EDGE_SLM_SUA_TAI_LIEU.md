# Xin sửa chữ đặc tả `docs/AI/AI_Edge-SLM.md/Client-app.md` — không xin đổi mã, không xin schema

**Ngày:** 2026-09-19 · **Người viết:** phía Client-app · **Nhánh:** `TranQuangDat` @ `03fe03a`
**Tệp xin sửa:** `docs/AI/AI_Edge-SLM.md/Client-app.md` (NPBao, bản `fcc20b5` ngày 2026-09-13) —
tệp do backend quản nên client **không tự sửa**, kể cả một dòng.
**Bối cảnh:** client đã bắt đầu thi công mảng Edge-SLM ngày 2026-09-19 theo thiết kế đã duyệt
`docs/superpowers/specs/2026-09-19-ai-edge-slm-design.md`; bản đánh giá và lý lẽ đầy đủ ở
`docs/superpowers/backend/AI_EDGE_SLM_DANH_GIA_AP_DUNG.md` (mục 4, 10, 11, 15, 16).
**Việc xin:** chỉ **sửa chữ** tài liệu để nó mô tả đúng hệ thống đang chạy và đúng thứ client đang
làm. **Không** xin đổi mã backend, **không** xin migration, **không** thêm trường payload.

---

## 1. Năm chỗ sai (mục 4 bản đánh giá, giữ nguyên bảng, thêm câu thay thế)

| # | Chỗ | Đang nói gì | Sai ở đâu | Câu thay thế đề nghị |
|---|---|---|---|---|
| 1 | **F1** (dòng ≈ 367) | *"Toàn bộ dữ liệu giao dịch thô … hoàn toàn không được phép rời khỏi thiết bị"*; dẫn PCI-DSS | Giao dịch thô **đồng bộ hai chiều** lên PostgreSQL qua `/sync/push` từ ngày đầu — đó là kiến trúc offline-first. PCI-DSS là chuẩn về dữ liệu **thẻ thanh toán**, không liên quan | *"Gói số đặc trưng (Tầng 1), kế hoạch tái phân bổ (Tầng 2) và bảng phản hồi cục bộ **không rời khỏi thiết bị** và không gửi tới API phân tích nào của bên thứ ba. Giao dịch thô vẫn đồng bộ với backend của chính hệ thống theo kiến trúc offline-first. Căn cứ: Nghị định 13/2023/NĐ-CP."* (bỏ PCI-DSS và "100%") |
| 2 | **D1** (dòng ≈ 343) | `avg_income_3m` = cộng giao dịch `type = 'thu'` theo tháng | Không loại tiền **đi vay** và **thu nợ** → tháng vay tiền thì "thu nhập" vọt lên. Client có một định nghĩa duy nhất: `thuNhapCua()` ở `features/analytics/domain/dong_tien_tu_do.dart` = tổng thu − mọi khoản tiền vào thuộc nhóm Vay/nợ | *"`avg_income_3m` là trung bình ba tháng liền trước của **thu nhập** theo định nghĩa duy nhất của client (`thuNhapCua`: tổng thu trừ tiền đi vay, thu nợ và khoản vay/nợ tiền vào). Không lưu vào bảng riêng; tính tại chỗ."* |
| 3 | **Bảng đặc trưng** (dòng ≈ 406–421) | `local_category_features` khoá `category_id` kèm cột `month` | Mỗi danh mục chỉ giữ được **một** tháng, trong khi `avg_spend_6m`/`CV` cần lịch sử theo tháng. Client **không dựng bảng này** (tính tại chỗ từ vài trăm hàng rẻ hơn cache) | Bỏ bảng khỏi Phần IV, hoặc ghi rõ *"Client-app không dựng bảng này; nếu sau này cần cache thì khoá phải là `(category_id, month)`"* |
| 4 | **Dòng ≈ 83 và ≈ 402** | *"schema hiện tại v21"* | Client ở **v23** từ 2026-09-17 và **v24** từ P2 Edge-SLM (cột `categories.ai_co_dinh` + bảng `ai_rebalancing_feedbacks`, cả hai cục bộ) | *"schema client hiện tại v24 (2026-09-19); xem `docs/AI_EDGE_FEATURE.md` mục 6"* |
| 5 | **Mục 3.4** (dòng ≈ 274) | *"Apple Foundation Models (iOS 18+)"* | Khung ấy ra ở **iOS 26** | *"Apple Foundation Models (iOS 26+)"* |

Số dòng là của bản `fcc20b5`; xin `grep` theo cụm chữ vì dòng có thể trôi.

## 2. Đính chính mô hình và runtime (mục 3.4 và khuyến nghị cuối mục ấy)

Tài liệu khuyên *"MediaPipe LLM Inference + Gemma nhỏ (2B, quantized 4-bit)"*. Đo ngày 2026-09-19
trên pub.dev, gói `flutter_gemma` 1.8.3 (2026-09-15, bọc MediaPipe LLM Inference):

- Danh sách mô hình văn bản: Gemma 3 1B / 270M, Gemma 3n E2B (≈3,1 GB) / E4B (≈6,5 GB), **Gemma 4
  E2B (≈2,4 GB) / E4B (≈4,3 GB)**. **Không có Gemma 2 2B, không có Gemma 3 4B.**
- Hai bản Gemma 4 ở kho `litert-community` **công khai**; Gemma 3 1B và Gemma 3n **gated** (cần token
  HuggingFace).
- Bản 1.8.3 đòi **Flutter ≥ 3.44, Dart ≥ 3.12** — client đã nâng lên 3.47.5 ngày 2026-09-19.
- Tệp `.litertlm` **chỉ chạy arm64-v8a**: máy ảo x86_64 không nạp được mô hình.

Xin sửa khuyến nghị thành: *"MediaPipe LLM Inference qua `flutter_gemma`; mô hình chọn theo RAM lúc
chạy — Gemma 4 E4B (≥ 8 GB), Gemma 4 E2B (4–8 GB), dưới đó hoặc không arm64 thì mẫu câu. Máy demo
Snapdragon 8 Gen 3 / 12 GB chạy E4B."* Con số ngưỡng có thể đổi sau spike đo trên máy thật.

## 3. 39 luật sau khi điều chỉnh (bảng mục 11 bản đánh giá)

| Nhóm | Số luật | Giữ nguyên | Sửa | Hoãn hoặc bỏ |
|---|---|---|---|---|
| A làm sạch | 6 | A3, A4 | A1, A2, A6 | A5 |
| B cảnh báo | 6 | B4 | B1, B2, B3, B5, B6 | |
| C nguồn bù | 7 | cả 7 | | |
| D mục tiêu, thu nhập | 5 | D5 | D1, D3 | D2, D4 |
| E tương tác | 5 | E1, E2, E3, E5 | | E4 |
| F riêng tư | 3 | F2, F3 | F1 | |
| G làm tròn | 3 | cả 3 | | |
| H hiệu năng | 4 | H1, H2 | H3, H4 | |
| **Tổng** | **39** | **22** | **13** | **4** |

Mười ba luật ở cột **Sửa** — mỗi luật một câu nói đổi thành gì (lý do đầy đủ ở mục 10.1 bản đánh giá
và spec mục 3.1):

| Luật | Đổi thành |
|---|---|
| **A1** | Giữ ý "loại khỏi baseline, vẫn tính vào tháng này"; **nguồn ngưỡng** là `nguongChiLon` người dùng đặt (thông báo Khoản chi lớn, 2026-09-17), không phải `3 × avg_spend` |
| **A2** | **Không thêm cột** `is_one_time` (cột cục bộ trên bảng giao dịch làm hai máy lệch nhau). Khoản vượt ngưỡng chi lớn tự coi là "một lần" cho baseline |
| **A6** | Chi cố định lấy từ **bảng hoá đơn** (`Bills`: `anchorDay`, `periodEnd`) và **trích tự động** của mục tiêu — nguồn tin cậy đã có — thay vì suy từ `txn_frequency`/`regularity` |
| **B1** | Cold-start không phải công tắc: dưới 2 tháng dùng prior theo nhóm danh mục; luật thống kê **hoãn** tới khi có ≥ 6 tháng dữ liệu, trình diễn bằng dữ liệu mô phỏng có ghi rõ |
| **B2** | Giữ ngưỡng kép (≥ 10 % hạn mức **và** ≥ 50.000 đ); thi hành trong **bộ luật thông báo hiện hành** (`notification_rules.dart`), không dựng bộ cảnh báo thứ hai |
| **B3** | Cửa sổ 48 giờ thay bằng **khoá chống trùng theo kỳ ngân sách** đã có của bảng `AppNotifications` |
| **B5** | Dự phóng: ≥ 5 ngày → `spent × daysTotal / daysElapsed`; < 5 ngày → `spent + TB 3 tháng × phần kỳ còn lại`, TB 3 tháng mượn `BudgetRepository.suggestAmount`; không có lịch sử thì **chỉ báo khi đã vượt** |
| **B6** | Trần "1 đề xuất/tuần" thi hành bằng khoá `budgetRebalance:<tuần ISO>` — cùng cơ chế Tổng kết tuần |
| **D1** | Thu nhập = `thuNhapCua()` (xem mục 1 #2), trung bình 3 tháng liền trước, tính tại chỗ |
| **D3** | `saving_goal_ratio` **suy từ mục tiêu còn hạn** (phương án (b) của chính tài liệu); câu D3 sửa thành *"AI không sửa số tiền đích hay hạn của mục tiêu"* |
| **F1** | Thu hẹp cam kết về đúng thứ có thật (mục 1 #1) |
| **H3** | Ngưỡng rơi về mẫu câu là **RAM < 4 GB** hoặc **không arm64** (không phải < 1 GB: mô hình 2–4 tỉ tham số cần 2,5–5 GB lúc chạy) |
| **H4** | **Một** bảng cục bộ `ai_rebalancing_feedbacks` (thay ba): bỏ `local_category_features` (tính tại chỗ) và `local_ai_alert_history` (bảng `AppNotifications` đã làm việc ấy) |

Bốn luật **hoãn/bỏ**: **A5** (ngưỡng tuyệt đối cho baseline nhỏ — không có baseline), **D2** (chế độ
thận trọng cần thu nhập 3 tháng ổn định), **D4** (3 tháng `at_risk` liên tiếp), **E4** (EMA cập nhật
essentiality — chưa có dữ liệu phản hồi). Đề nghị đánh dấu *"giai đoạn sau đồ án"* ngay tại bảng.

Đề nghị thêm cho **C6**: ghi chú *"khi chưa có thống kê, essentiality = 0,5 cho mọi danh mục nên xếp
hạng quy về dư địa"* — client làm đúng như vậy và nói thẳng trong giao diện tài liệu.

## 4. Kiểm lại bằng gì

Sau khi sửa, lệnh sau phải ra **0** dòng:

```bash
grep -n "v21\|PCI-DSS\|iOS 18\|Gemma 2B\|2B, quantized\|3 \* avg_spend\|local_category_features\|local_ai_alert_history" "docs/AI/AI_Edge-SLM.md/Client-app.md"
```

(`3 \* avg_spend` chỉ còn được xuất hiện nếu kèm câu "đã thay bằng ngưỡng người dùng đặt".)

## 5. Không xin gì thêm

Không đổi mã backend, không migration, không trường payload mới. Hai thứ mới của schema client v24
là **cục bộ** và có test quét cấm lọt vào đường đồng bộ.
