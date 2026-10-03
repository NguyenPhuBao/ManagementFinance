# Thông báo: client thêm đường "chia sẻ biên lai" cho tính năng đọc biến động số dư trên máy

**Ngày:** 2026-10-02 · **Người viết:** phía Client-app · **Nhánh:** `TranQuangDat`
**Loại:** **thông báo**, kèm hai câu hỏi có mặc định. **Không xin đổi mã backend, không migration, không trường đồng bộ
mới.** Backend không trả lời thì client làm theo mặc định ở mục 4.

---

## Tệp cần đọc

| Tệp | Vì sao |
|---|---|
| `docs/superpowers/backend/DA-XONG/CLIENT_DOC_BIEN_DONG_SO_DU_TREN_MAY.md` | đơn gốc của D1 và phản hồi duyệt toàn diện của backend (2026-09-26) |
| `docs/superpowers/backend/DA-XONG/D1_DOC_BIEN_DONG_XONG_SOAT.md` | D1 đã xong, đơn soát |
| `docs/superpowers/specs/2026-10-02-chia-se-bien-lai-design.md` | thiết kế phía client, người dùng duyệt 2026-10-02 |
| `docs/BIEN_DONG_SO_DU_FEATURE.md` mục 7 | hiện trạng sau khi làm, bảng nghiệm thu máy thật |

---

## 1. Vì sao có đường này

D1 chỉ đọc **thông báo đã hiện trên máy**. Người dùng báo 2026-10-02: chuyển khoản ngay trong app ngân hàng thì có lần
app ấy **không đăng thông báo biến động** — đo trên Realme cùng ngày: trong sáu lần chuyển từ MB Bank của buổi ấy, năm
lần D1 đọc được thông báo, **một lần (19:46) không có thông báo nào**; MoMo / ZaloPay vốn không bắn tin khi chuyển tiền
đi (đã ghi ở đơn soát D1). Những khoản ấy D1 không thấy.

Android không cho một app đọc màn hình hay dữ liệu của app khác; client **không** dùng quyền Trợ năng và **không** mở
lại liên kết ngân hàng (nhóm đã bỏ 2026-09-18). Lối còn lại là để người dùng **tự đưa** biên lai cho FlowMoney.

## 2. Client đã làm gì

1. Ở màn *"Giao dịch thành công"* của app ngân hàng / ví, người dùng bấm **Chia sẻ → "Ghi vào FlowMoney"**.
2. FlowMoney nhận **một ảnh** ở nền (một activity không giao diện — người dùng vẫn ở app ngân hàng), chép vào vùng riêng
   của app (`files/bien_lai/`), hiện dòng chữ *"FlowMoney đã nhận biên lai"* và thông báo tóm tắt **không số** của D1
   (*"Có N biến động số dư mới — chạm để ghi"*).
3. Khi FlowMoney mở, chữ trên ảnh được đọc **trên máy** bằng ML Kit Text Recognition (gói
   `google_mlkit_text_recognition`, mô hình nằm trong APK — không gọi mạng), thành một dòng *"biến động chưa ghi"* —
   **cùng loại** với dòng sinh từ thông báo ngân hàng (loại thông báo cục bộ thứ 20, không loại mới).
4. Người dùng mở dòng ấy → form Thêm giao dịch điền sẵn, có ảnh biên lai nhỏ để đối chiếu → **Lưu** hoặc **Bỏ qua**.

## 3. Những gì KHÔNG đổi so với bản backend đã duyệt cho D1

- **Không API, không liên kết tài khoản, không đăng nhập ngân hàng / ví.** Không `READ_SMS`, không quyền Trợ năng, không
  quyền đọc thư viện ảnh — app chỉ nhận đúng ảnh người dùng chủ động chia sẻ.
- **Không gửi gì ra khỏi máy.** Ảnh, chữ đọc được và dòng chờ ghi đều cục bộ; bảng thông báo vẫn không nằm trong đường
  đồng bộ.
- **Không tự tạo giao dịch.** Người dùng bấm Lưu; giao dịch đi đồng bộ như nhập tay, `provider = 'Manual'`, payload
  giao dịch vẫn **13** trường. Không đổi schema (vẫn v27).
- **Tối thiểu hoá:** ảnh bị xoá khi người dùng Lưu / Bỏ qua, khi đăng xuất, hoặc sau **30 ngày** không xử lý; hai lần
  chia sẻ cùng một biên lai chỉ giữ một ảnh. Số tài khoản người nhận trên biên lai **không** được lưu vào trường nào.
- **Không log nội dung biên lai.** Chế độ thu mẫu chỉ sống ở bản debug và chỉ in *hình dạng đã che* (chữ số → `9`, từ
  ngoài danh sách nhãn → `…`) — quy tắc §13.6 `docs/progress/Client-app.md`.
- **Màn xin đồng ý của D1 không áp cho đường này**, và công tắc *Đọc biến động số dư* cũng không: việc đọc thông báo là
  app chủ động đọc nên cần đồng ý trước; còn ở đây mỗi ảnh là do người dùng tự bấm chia sẻ. FlowMoney chỉ nhận ảnh khi
  máy đang có tài khoản đăng nhập.

## 4. Câu hỏi cho backend

| # | Câu hỏi | Mặc định của client |
|---|---|---|
| 1 | Phản hồi *"không áp lệnh cấm"* của đơn gốc D1 (lý do dừng Module Bank là API trung gian) có áp cho **ảnh biên lai người dùng tự chia sẻ** không? Và backend có đòi một màn giải thích / đồng ý riêng cho đường này không? | **có áp, không cần màn riêng**: người dùng chủ động từng lần, dữ liệu không rời máy; mục *"Ghi vào FlowMoney"* chỉ làm đúng một việc như tên gọi |
| 2 | Chức năng 3 trong `docs/AI/LogicBusinessAI.md` (và các chỗ tả phần client của nó) có cần ghi thêm nguồn *"biên lai người dùng chia sẻ, đọc chữ trên máy"* cạnh *"thông báo đã hiện trên máy"* không? | backend tự quyết cách ghi; client không sửa tệp ấy |

## 5. Kiểm lại phía client

- `grep -n "NhanBienLaiActivity" src/Client-app/android/app/src/main/AndroidManifest.xml` — một activity, action `SEND`,
  `mimeType="image/*"`, không `SEND_MULTIPLE`.
- `grep -rn "startActivity" src/Client-app/android/app/src/main/kotlin/com/flowmoney/flowmoney/NhanBienLaiActivity.kt` —
  0 dòng (không kéo FlowMoney lên).
- `grep -rln "google_mlkit_text_recognition" src/Client-app/lib` — đúng `core/ocr/doc_chu_anh_mlkit.dart` và màn đo của
  spike C4.
- Payload đồng bộ: `src/Client-app/test/core/sync/sync_payload_contract_test.dart` không đổi một dòng.
