# Đường nhanh cho câu giao dịch ở màn Trợ lý AI — tool chạy trước, Gemma chỉ viết câu — thiết kế

**Ngày:** 2026-10-02. **Trạng thái:** 📝 người dùng **duyệt thiết kế trong chat** (ba lượt AskUserQuestion); bản viết này
chờ người dùng đọc lại — hỏi lại ở phiên kế cùng ngày, người dùng đáp *"chưa đọc, để sau"* và chốt thêm hai chỗ
(hàng 5–6 mục 2). Chưa có kế hoạch, chưa có dòng mã nào.

Đi tiếp từ dự án B (mục 9.45 `docs/AI_EDGE_FEATURE.md`). Người dùng hỏi sau lượt đo Realme: *"có cách nào để giảm
thời gian phản hồi không vì hiện tại đang quá lâu"*.

## 1. Vì sao

Đo Realme RMX2205 (CPU, bản debug), 02/10, một câu giao dịch ở phiên **một tool** — tổng chờ trung bình **36,9 s**:

| Đoạn | Thời gian | Nguồn |
|---|---|---|
| Mở phiên | ~3,6 s | đo |
| Gemma đọc lời hệ thống (2.679 ký tự) | ~8,5 s | ước |
| Gemma đọc khai báo tool giao dịch (3.278 ký tự) | ~10,5 s | ước |
| Gemma viết lời gọi tool | ~10 s | ước |
| App chạy tool trên SQLite | ~0,1–0,2 s | đo |
| Gemma viết câu trả lời | 2–12 s | đo |

Ba dòng *ước* suy tuyến tính từ hai điểm đo (phiên 6 tool: 9.659 ký tự → 41,0 s; phiên 1 tool: 5.957 ký tự → 29,1 s),
chỉ đúng về độ lớn. Điều chắc chắn: **~29 s trôi qua trước khi app chạm vào dữ liệu**, chỉ để Gemma điền tham số — thứ
mà bộ chỉnh tham số theo câu hỏi (`chinhThamSoTimGiaoDich`) sau đó vẫn sửa lại ở phần lớn các câu.

**Phép đo ngoài máy** (2026-10-02, không đổi app): cho bộ chỉnh tự điền tham số từ `{}` rồi so với tham số cuối app đã
dùng (Gemma điền + bộ chỉnh).

| Bộ câu | Ra đúng kết quả | Hụt |
|---|---|---|
| 35 câu đo trên Realme hôm nay — ⚠️ bộ chỉnh được mài trên chính các câu này | 28/35 (25 trùng từng tham số) | 7 |
| 18 câu giao dịch của bộ đo khoá (bộ chỉnh chưa từng thấy; chấm tay) | 13 đúng · 1 gần đúng | 4 |

Chỗ hụt gom thành bốn họ:

| Họ | Câu | Loại |
|---|---|---|
| Kỳ tương đối kiểu "trước": *hôm qua, tuần trước, tháng trước, kể từ đầu năm* — luật chỉ đọc "… này" và ngày tháng cụ thể | A9 · C2 · C5 · C6 · E5 · hai câu bộ mới | từ vựng **đóng** |
| Chiều chuyển ví: *"chuyển tiền sang ví tiết kiệm"* | C11 · một câu bộ mới | từ vựng **đóng** |
| Tên lạ sau *"danh mục"*: *"danh mục abc"* bị bỏ qua → tool trả mọi khoản chi | DC3 | sửa được |
| Động từ chỉ chiều luật không biết: *"ngốn", "xài", "trả"* | ba câu bộ mới | từ vựng **mở** — rủi ro thật |

Ví dụ họ thứ tư: *"Quý này danh mục nào ngốn nhiều tiền nhất?"* — không có chiều thì tool gộp cả thu lẫn chi và danh
mục *Lương* thắng.

Đây cũng là nếp chung của ứng dụng có SLM trên máy: **mã lấy dữ liệu, mô hình chỉ viết câu**, một lượt sinh.

## 2. Quyết định người dùng chốt

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Hướng giảm chờ | **Luật trước, Gemma lấp ô trống** — cùng nguyên tắc ô Nhập nhanh (C2 đổi lần hai). Không chọn *"hiện trước, Gemma xác nhận sau"* |
| 2 | Phạm vi | **Chỉ câu giao dịch** (`truy_van_giao_dich`). Tám tool kia giữ nguyên, mở rộng sau khi đường nhanh đo đạt |
| 3 | Hiển thị | **Gemma viết câu, giao diện như cũ.** Không đổi bố cục tin nhắn, không cần Stitch. Không chọn *"chỉ mẫu câu"* (ngược nguyên tắc *tính năng AI ở màn Trợ lý phải dùng mô hình*) |
| 4 | Thiết kế tổng | **Duyệt** |
| 5 | Tool **từ chối** trên đường nhanh (vd *"danh mục abc"*) | **Quay về đường cũ** (mục 3.1 bước 2) — chốt 2026-10-02 ở phiên sau, AskUserQuestion. Không chọn *"hiện lời từ chối ngay sau ~1 s"* |
| 6 | Chữ **"khoản"** không kèm chiều (*"các khoản dưới 50k tháng này"*) | **Đường cũ** — chỉ chữ *"giao dịch"* tính là trung tính (mục 3.2). Chốt cùng lượt |

## 3. Luồng

```
câu hỏi ─► coVeLenhTao ─► chuDeBiChan ─► hoiBangCongCu
                                           │
                             dinhTuyen(câu) ─► đích = truy_van_giao_dich ∧ docDuThamSoGiaoDich(câu)
                                           │        │
                                           │        └─► ĐƯỜNG NHANH (mục 3.1)
                                           └─► còn lại ─► y như hôm nay (mở phiên có tool)
```

Hôm nay luật `congCuTheoCauHoi` không bao giờ trả `truy_van_giao_dich`; đích ấy chỉ đến từ bộ định tuyến học (dự án
B). Điều kiện viết theo **đích**, không theo nguồn — nếu về sau luật cũng định tuyến câu giao dịch thì đường nhanh áp
luôn.

### 3.1 Đường nhanh

1. `yield DangTraCuu(truy_van_giao_dich)`. Chạy `boCongCu.chay(truy_van_giao_dich, const {}, cauHoi: câu)` — tool tự gọi
   bộ chỉnh như hôm nay, nên tham số là thứ **luật** đọc từ câu hỏi. **Không** mở phiên Gemma có tool.
2. **Tool từ chối** (`kq.loi != null`) → bỏ kết quả ấy, **không** đưa vào gói, đi **đường hôm nay** (mở phiên một tool).
   Luật đọc sai thì Gemma còn cơ hội; trường hợp tên lạ (DC3) thì kết cục vẫn là L1b như hôm nay.
3. `goi.them(...)`. **Cổng hiện chữ đóng** (`!goi.choHienChuMoHinh`: 0 khoản theo bộ lọc, hoặc tool đòi mẫu câu — câu
   liệt kê) → `yield CauQua(goi.mauCau().cau)` ngay, xong. Không gọi Gemma.
4. Còn lại → `yield DangTraCuu(null)` (màn về *"Đang nghĩ…"*), rồi Gemma **viết câu**:
   `gacTheoCau(runtime.sinhDan(promptVietCau(câu, kq.json)), kiem: kiemCauTraLoi(c, [goi]), huy: runtime.huy)`.
   Chưa câu nào qua kiểm → mẫu câu của gói (L2). Đã có câu hiện rồi mới trượt → giữ câu đã hiện (cùng luật hôm nay).
5. `runtime.sinhDan` ném → lỗi lan lên màn như L4 hôm nay.

Log (dòng nào cũng bắt đầu `[SLM][tool]`): `định tuyến: …` như hôm nay · `đường nhanh: luật đọc đủ → truy_van_giao_dich`
· dòng `chỉnh tham số theo câu hỏi: …` của tool · `đường nhanh: N hàng, M ms` · `đường nhanh: tool từ chối (…) → đường
cũ` · kết thúc bằng `xong sau … ms: 0 lời gọi, K câu` (công cụ đo `hoi.sh` dừng theo chuỗi `xong sau`).

### 3.2 "Luật đọc đủ" — `docDuThamSoGiaoDich(cauHoi)`

Hàm thuần ở `chinh_tham_so.dart` (dùng lại đúng các phép của bộ chỉnh, không viết bản thứ hai). Đúng khi **một** trong:

- luật đọc được chiều theo động từ (`_chieuTheoDongTu` khác `null`);
- câu nói **cả** thu lẫn chi (luật 9 — *hai chiều*);
- câu có chữ chuyển tiền (chiều chuyển ví — mục 4);
- câu tự nói trung tính bằng chữ **"giao dịch"** (*"hôm nay tôi có giao dịch nào không"*, *"tìm các giao dịch có ghi
  chú …"*).

Kỳ không nằm trong điều kiện: sau khi vá mục 4, luật luôn có đáp án cho kỳ (đọc được, hoặc câu không nêu kỳ → mọi thời
gian). Kỳ chưa tới (`ky_tuong_lai`) vẫn do tool từ chối → bước 2 đưa về đường cũ.

Không đủ → đường hôm nay. Đây là chốt cho họ động từ lạ: *"danh mục nào ngốn nhiều tiền nhất"* không có chiều, không
có chữ "giao dịch" → Gemma điền như hôm nay. Cái giá: câu trung tính hợp lệ mà không dùng chữ "giao dịch" (*"các khoản
dưới 50k tháng này"*) cũng đi đường chậm.

## 4. Vá bộ chỉnh — ba họ từ vựng đóng

Sửa trong `chinhThamSoTimGiaoDich`, nên **đường cũ cũng được lợi** (Gemma điền thiếu thì luật bù).

| Luật mới | Nội dung | Ca đã đo |
|---|---|---|
| Kỳ tương đối "trước" | *hôm qua* → `hom_qua` · *tuần trước* → `tuan_truoc` · *tháng trước* → `thang_truoc` · *(kể từ) đầu năm* → `nam_nay` · *đầu tháng* → `thang_nay` · *đầu tuần* → `tuan_nay`. Mở rộng luật 15 (`_kyGocNeu`): kỳ nêu trong câu thắng `ky` của mô hình. Không áp khi câu là câu **so sánh** (*"tháng này … hơn tháng trước"* — luật 12 giữ) hoặc đã có kỳ cụ thể (luật 11) | A9 · C2 · C5 · C6 · E5 |
| Chiều chuyển ví | Câu có chữ chuyển tiền (`_tuChuyenTien`) mà `chieu` trống → `chuyen_vi` | C11 |
| Tên lạ sau "danh mục" | Câu có *"danh mục X"* mà X không khớp tên nào và `danh_muc` trống → `danh_muc = X` (để tool **từ chối** đúng lý do) | DC3 |

Ba luật đều so trên chữ bỏ dấu, từ khoá giữ dạng chuỗi tách lúc chạy (test quét 14).

## 5. Lời dặn cho lượt viết câu — `promptVietCau(cauHoi, ketQua)`

Hàm thuần ở `slm_prompt.dart`. Một tin, không few-shot:

- vai và việc: trả lời câu hỏi bằng tiếng Việt, ngắn gọn;
- chỉ dùng tên và số trong phần *Kết quả tra cứu*; chép nguyên chuỗi số và ngày tháng; nêu tên đối tượng trước con số;
  không tự tính, không suy đoán — cùng các ý của phần *"Khi trả lời"* trong `kPromptHeThongCongCu`;
- `Kết quả tra cứu:` + JSON của `KetQuaCongCu.json` (đúng khối Gemma nhận hôm nay qua `traKetQua`);
- `Câu hỏi:` + câu của người dùng.

⚠️ Chỉ dẫn **không chứa chữ số nào** (số trong lời dặn là số mô hình có thể chép vào câu) — có ca test canh, cùng khuôn
ca của `kPromptHeThongCongCu`. Trần token của lượt sinh: 300 (như bậc 1).

Đây là chỗ quyết định chất lượng câu và là thứ **chưa đo**: câu chữ của lời dặn chốt ở lượt đo máy, không chốt ở spec.

## 6. Thứ không đổi

- Sáu lớp chắn (`kiemCauTraLoi` trên `GoiSoTraCuu`), thẻ số liệu, mẫu câu, `theCuaCau`.
- Tool chỉ đọc; Gemma không tính; bất biến ④.
- `congCuTheoCauHoi`, bộ định tuyến học, trọng số, `tools_json`, `kPromptHeThongCongCu`, schema, payload, `pubspec`.
- Câu hoá đơn / ví / ngân sách / mục tiêu / gợi ý / dự báo / tổng quan / danh mục; câu không định tuyến (phiên sáu tool).
- Giao diện màn Trợ lý AI.

Một hệ quả tốt không cố ý: đường nhanh dùng `sinhDan` thường, **không mở phiên có tool** — máy đã bị tắt bậc tool
(canary 1b, `BacCongCuDaTat`) vẫn đi được đường nhanh. ⚠️ Hôm nay ở máy ấy `moPhien` ném trước khi tới đây; thứ tự mới
(đường nhanh xét **trước** `moPhien`) phải có ca test.

## 7. Vị trí mã

| Tệp | Việc |
|---|---|
| `lib/features/ai_edge/domain/chinh_tham_so.dart` | `docDuThamSoGiaoDich`; ba luật mục 4 |
| `lib/features/ai_edge/domain/slm_prompt.dart` | `promptVietCau` |
| `lib/features/ai_edge/data/vong_lap_cong_cu.dart` | nhánh đường nhanh trước `runtime.moPhien`; tách thành hàm riêng trong tệp để `hoiBangCongCu` không phình |
| `test/features/ai_edge/domain/chinh_tham_so_test.dart` | ba luật + phản ví dụ; `docDuThamSoGiaoDich` trên 35 câu đã đo và 18 câu bộ đo khoá (chép câu vào ca, không đọc tệp bộ đo) |
| `test/features/ai_edge/domain/slm_prompt_test.dart` | lời dặn không chữ số; có khối kết quả và câu hỏi |
| `test/features/ai_edge/data/vong_lap_cong_cu_test.dart` | đường nhanh: không mở phiên · tool chạy với `{}` · từ chối → đường cũ · 0 khoản → mẫu câu, `sinhDan` không được gọi · câu trượt kiểm → mẫu câu · câu không đọc đủ → đường cũ · đích khác tool giao dịch → đường cũ · máy tắt bậc tool vẫn đi đường nhanh |
| `test/features/ai_edge/domain/dinh_tuyen_72_cau_test.dart` | thêm cột *đường nhanh?* cho 37 câu giao dịch — canh câu đổi đường ngoài ý muốn |

Khung test của vòng lặp ghim `dinhTuyen: dinhTuyenChiLuat` nên **không** vào đường nhanh — đúng ý: các ca cũ kiểm cơ
chế phiên có tool. Ca đường nhanh dùng bộ định tuyến giả trả đích giao dịch.

## 8. Đo và cổng ra

1. `flutter test` trọn bộ xanh, `flutter analyze` giữ mức nền 26. Mỗi ca canh thử bằng bản sai có chủ ý.
2. Bảng 72: 31 câu theo luật và 4 câu ngoài phạm vi không đổi đường; cột *đường nhanh?* của 37 câu giao dịch ghim.
3. **Đo máy đang cắm** (Realme nếu cắm — máy lợi nhiều nhất), trước / sau cùng buổi, cùng dữ liệu. Bản *trước* = HEAD
   chưa có đường nhanh (`e57753f8…` đang trên Realme).
   - **35 câu đổi đường** của dự án B, trước và sau. Cổng: **không câu nào tụt, SAI 0**; ghi thời gian từng câu.
   - **18 câu giao dịch của bộ đo khoá**, chỉ đo **sau**, chấm tuyệt đối theo dữ liệu trên máy — phép thử trên câu bộ
     chỉnh chưa từng được mài. Ghi nguyên; câu sai thì ghi và hỏi người dùng.
   - Chấm theo **câu trả lời hiện ra**, bảng câu hỏi · trước · sau · đánh giá.
4. Thời gian: câu đi đường nhanh và ra mẫu câu ≤ 3 s; câu đi đường nhanh và Gemma viết: ghi số đo — kỳ vọng 6–13 s
   trên Realme, **chưa đo, không phải cổng cứng**. Nếu lượt viết câu chậm hơn kỳ vọng nhiều thì báo người dùng.

⚠️ Đo trong tháng 10: các câu *"tháng này / hôm nay"* ra 0 khoản (mẫu câu) — với chúng chỉ kiểm được bộ lọc. Câu có dữ
liệu là các câu nêu tháng 9, tháng trước, năm nay, mọi thời gian.

## 9. Rủi ro đã biết

- **Tham số do luật đọc là in-sample trên 35 câu.** Con số 28/35 lạc quan; 18 câu bộ mới cho 13–14/18. Chốt *"không
  đọc ra chiều thì để Gemma điền"* chặn họ lỗi lớn nhất, nhưng luật vẫn có thể đọc **sai** một thứ nó tưởng là đọc được
  (tên danh mục trùng một chữ thường, ngưỡng tiền). Hôm nay Gemma cũng không sửa được các lỗi ấy — bộ chỉnh chạy **sau**
  Gemma và thắng — nên đường nhanh không tệ hơn ở điểm này.
- **Tham số Gemma điền mà luật không có** bị mất trên đường nhanh. Phép đo ngoài máy thấy đúng ba loại (kỳ "trước",
  chiều chuyển ví, tên lạ) và mục 4 vá cả ba; loại thứ tư chưa thấy thì chưa biết.
- **Lời dặn mới** có thể làm Gemma viết khác đi (chữ kỳ, cách kể hàng). Sáu lớp chắn giữ nguyên; trượt thì mẫu câu.
- **Câu giao dịch mà bộ định tuyến học không đủ tin** (p < 0,76 — khoảng một phần tư trên bộ đo khoá) vẫn đi phiên sáu
  tool (~48 s). Ngoài phạm vi.

## 10. Ngoài phạm vi

Tám tool còn lại · hiện thẻ số liệu trước câu (đổi giao diện) · rút lời hệ thống cho phiên một tool · nạp sẵn phiên
khi mở màn · thêm động từ mới vào danh sách chiều (*"ngốn", "xài", "trả"*) · sửa luật `congCuTheoCauHoi` lệch nhãn
(việc mở của dự án B) · hạ ngưỡng bộ định tuyến học.

## 11. Hai câu hỏi từng mở — ✅ người dùng chốt 2026-10-02 (hàng 5–6 mục 2)

- Tool từ chối trên đường nhanh **quay về đường cũ** (thêm ~37 s để rồi thường nhận cùng lời *"không có danh mục tên
  abc"*). Phương án không chọn: hiện thẳng mẫu câu trung thực (L1b) sau ~1 s — luật đọc nhầm tên thì Gemma mất cơ hội sửa.
- Chữ "khoản" (*"các khoản dưới 50k"*) **không** tính là trung tính như "giao dịch", vì *"khoản"* đứng cả trong
  *"khoản thu"*, *"khoản vay"* — câu ấy đi đường cũ.

Không còn câu hỏi mở nào về thiết kế. Bản viết vẫn **chờ người dùng đọc lại** (dòng Trạng thái đầu tệp).
