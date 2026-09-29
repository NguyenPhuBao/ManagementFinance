# C2 — Nhập giao dịch bằng câu (ô "Nhập nhanh" ở màn Thêm giao dịch) — thiết kế

> ✅ **MÃ XONG + ĐO REALME 2026-09-30** (commit `fd76114` → `ea12588`; số đo ở mục **9.41** `docs/AI_EDGE_FEATURE.md`).
> Hình dạng cuối khác bản duyệt 28/09 ở ba lượt đổi, mỗi lượt có banner bên dưới: soát với mã trước Task 1 (sáu chỗ) ·
> **AI đọc mọi câu** (§2.8, người dùng chọn 30/09) · **bước từ khoá** trong thứ tự danh mục (§2.5, người dùng đề xuất và
> chốt 30/09: tên → B1 khi chắc → từ khoá → AI). ⚠️ Phần **"đề xuất thêm từ khoá từ thói quen"** (người dùng lặp một chữ
> với một danh mục mà chưa khai từ khoá) là **việc riêng ngay sau C2, trước D1** — người dùng chốt, chưa có spec.
> 🔁 **Sau lượt đo người dùng đã quyết ĐỔI LẦN HAI — CHƯA THI CÔNG** (banner cuối trong khối banner; mã hôm nay vẫn chạy
> *"AI đọc mọi câu"*). Ba câu hỏi chặn việc thi công ở **§8 câu 1, 2, 9**.
> 📝 **Soát thân spec với mã 2026-09-30 (phiên soát tài liệu sau C2):** chữ ký §2, tên hàm §2.3–2.6, lớp kiểm §2.8 (không
> có hàm `hopNhatAi` — kiểm nằm trong `docCauGiaoDich(ai:)`; `cachDocSoTien` không có `n × 1.000.000`) và tình trạng Stitch
> §3 đã sửa theo mã `ea12588`. Chỗ sửa ghi *"(soát 30/09)"*.

**Ngày:** 2026-09-28 (tối). **Người dùng duyệt** bản thiết kế trong chat cùng ngày, với các lựa chọn: ô **"Nhập nhanh" ở
màn Thêm giao dịch** (không ở màn Trợ lý AI) · **chỉ luật**, không mô hình · **một câu một khoản** · nhận cả bốn cách nói
tiền: *k / nghìn / ngàn*, *tr / triệu / củ*, *lít / xị (= 100.000)*, và *số viết bằng chữ*. Bất biến ④ nhóm C: *"không tool
nào ghi thẳng"*, tức form điền sẵn và người dùng bấm **Lưu**. Tầng hậu quả 3. Thứ tự nhóm C: C1 → **C2** → D1 → C3 → C4.
**Phụ thuộc B1** (đoán danh mục). **Không đổi schema.**

> **Soát với mã B1 + C1 đã thi công (2026-09-29, trước Task 1).** Sáu chỗ đổi so với bản trên; ba chỗ đầu người dùng
> chọn bằng câu hỏi chọn cùng ngày, ba chỗ sau là nếp sẵn của dự án:
> 1. **Bộ đọc số bằng chữ đầy đủ, một định nghĩa cho ba nơi (§2.6).** Đo bằng test tạm: bộ đọc của `kiem_so` trả **rỗng**
>    cho *"năm mươi nghìn"*, *"hai mươi lăm nghìn"*, *"nam muoi nghin"* (không có hàng chục *mươi*); và có một **bản thứ
>    hai** ở `chinh_tham_so.dart` (chữ bỏ dấu, cho ngưỡng tiền câu hỏi) cũng không đọc hàng chục — *"dưới năm mươi
>    nghìn"* ra **không ngưỡng nào** trong khi *"dưới 50k"* ra 50.000. Nên T1 không "dời không đổi hành vi" mà dựng **một**
>    bộ đọc đầy đủ ở `core/utils/so_bang_chu.dart` (hàng chục *mươi*, *mốt / tư / lăm / nhăm*, *linh / lẻ*; có dấu và
>    không dấu), và **cả** `kiem_so` lẫn `chinh_tham_so` gọi lại nó. Hệ quả cố ý: `kiemSo` chặt hơn (số chữ hàng chục nay
>    được kiểm), Trợ lý AI đọc được ngưỡng viết bằng chữ. Mọi ca test cũ của hai tệp ấy phải xanh không sửa kỳ vọng.
> 2. **Lọc chiều của B1 theo nếp màn (§2.5).** Màn Thêm giao dịch cho B1 đoán trên **cả ba** phân loại (đoạn Chi/Thu chỉ
>    là lối vào, danh mục kéo đoạn theo — `_loadSuggestion`). Nên chỉ lọc `hopLeTheoChieu` khi câu **nói rõ** chiều
>    (`loai != null`); câu không nói thì B1 chọn trên mọi danh mục chọn được, như thẻ gợi ý. Không còn tham số
>    `loaiHienTai` cho phép lọc.
> 3. **Danh mục điền từ B1 ghi phản hồi như thẻ gợi ý.** Lưu với đúng danh mục đoán → `chon`; đổi → `khac`. Nên
>    `KetQuaDocCau` mang cả `DoanDanhMuc? doan` (cần `cumBoDau` cho `CategorySuggestion`), và màn đặt `_choPhanXu` sau khi
>    điền.
> 4. **Tìm tên trong câu (§2.4, §2.5):** `khopTheoTen` so **trọn chuỗi**, không tìm tên nằm giữa câu. Hàm tìm tên trong câu
>    là `tenNeuTrongCau` (`ai_edge/domain/chinh_tham_so.dart`: khớp trọn từ trên chữ bỏ dấu, tên dài trước, tên ngắn
>    dưới 5 ký tự chỉ nhận ngay sau từ loại) — dời ra `core/utils/khop_ten.dart`, `ai_edge` gọi lại. Ví dùng từ loại
>    *"ví"*; danh mục dùng *"danh mục"* (tên danh mục ngắn như *"Học"* chỉ đọc được khi câu viết *"danh mục học"*; còn
>    lại rơi về B1).
> 5. **`kyTuCauHoi` không đọc *"hôm qua"* (§2.3):** nó đọc kỳ nêu cụ thể (tháng 8, quý 2, từ … đến …); *"hôm qua"* đi qua
>    mã kỳ `hom_qua` → `kyTuMa`. Nên `kyTuCauHoi` **không đổi** (nhánh ⚠️ của kế hoạch T2). Thứ dùng chung là `ngayHopLe`
>    (kiểm ngày tồn tại trên lịch) — dời ra `core/utils/ngay_trong_cau.dart`, `ma_ky.dart` gọi lại.
> 6. **Đổi chiều trên màn đi qua `_chonHuong` (§3),** không gán thẳng `_huong`: `_chonHuong` bỏ danh mục thuộc chiều kia,
>    gán thẳng là để danh mục chi đứng dưới đoạn Thu. Test bố cục có thêm ca **bàn phím hệ thống đang mở** (G58: 16 phím
>    ẩn khi `viewInsets.bottom > 0`, mà ô Nhập nhanh là ô chữ). Nghiệm thu trên **Realme** (máy thật đang cắm), không máy ảo.
>
> **Tự chốt lúc thi công T2–T3 (2026-09-29), vì bản trên sai trên câu thường gặp:**
> 7. **Từ chỉ thu (§2.2) khớp theo từng từ, phân biệt dấu** — không bỏ dấu cả câu: *"bạn"* bỏ dấu thành *"ban"* (= *bán*),
>    *"lại"* thành *"lai"* (= *lãi*), *"bình thường"* chứa *"thuong"* (= *thưởng*), nên *"ăn với bạn 200k"* từng thành khoản
>    thu. Từ có dấu: *lương, thưởng, thu, bán, lãi, nhận*; từ không dấu chỉ *luong, thu, nhan*; cụm hai từ: *được cho /
>    tặng / biếu / trả / hoàn*, *hoàn tiền / trả*, *lì xì*, *tiền thưởng* (và dạng không dấu). *"được"* một mình và *"hoàn"*
>    một mình **bỏ** (*"mua được áo"*, *"hoàn thành"*); *nhận hàng / đồ / đơn / gói* không phải thu.
> 8. **Số tiền (§2.1) — thêm:** *đ / đồng / vnd* sau số thuộc cụm (ghi chú bỏ luôn); số trần bắt đầu bằng `0` (số điện thoại,
>    mã) và số ngay sau *"năm"* (*năm 2026*) không phải tiền; phần lẻ dính sau `tr` chỉ với `tr` (*"2k5"* không đọc); số chữ
>    có chữ số đứng ngay sau (*"một triệu hai"* — 1.200.000 hay 1.000.000?) và lượng từ mơ hồ (*"mấy trăm nghìn"*) → **không
>    điền** + cảnh báo *"Số tiền viết bằng chữ chưa rõ — bạn nhập tay nhé."*
> 9. **Ngày (§2.3) — thêm:** *thứ hai … thứ bảy* bằng chữ và *dd/mm/yyyy*. *"thu"* không dấu còn là động từ *thu* tiền,
>    nên chỉ *"thứ"* có dấu nhận dạng chữ; *"thu 5"* không dấu nhận khi không có đơn vị tiền ngay sau.
> 10. **Ghi chú (§2.7) — thêm:** bỏ *hết / mất / tốn* đứng ngay trước số tiền (*"ăn phở hết 45k"* → *"ăn phở"*); *mất* không
>     dấu (*mat*) cố ý không bỏ — đó còn là *mặt* của *"tiền mặt"*.

> **🔁 ĐỔI HƯỚNG 2026-09-30 — AI ĐỌC MỌI CÂU (người dùng chọn bằng câu hỏi chọn, sau khi T1–T4 đã xong).** Bản trên chốt
> *"chỉ luật, không mô hình"*; người dùng hỏi *"dùng AI cho nhập nhanh được không"*, được trình bày giá (7–10 s mỗi câu
> trên Realme CPU, +~27 s nạp lần đầu; cần tải 2,41 GB và bật công tắc; mở **lối B** sang chỗ thứ hai), rồi chọn **"AI
> đọc mọi câu"** thay cho *"luật trước, AI khi luật bó tay"*. Ba điểm chốt cùng lượt: **AI đọc cả ngày**, **B1 thắng khi
> nó chắc**, **nạp mô hình khi chạm vào ô**. Thiết kế ở **§2.8**; luật §2.1–2.7 ở lại làm hai việc: đường chạy khi máy
> không có mô hình, và **lưới kiểm** từng ô của AI. §4 *"Không mô hình"* hết hiệu lực.

> **🔁 ĐỔI LẦN HAI 2026-09-30 tối — CHƯA THI CÔNG, việc đầu tiên của phiên sau.** Sau khi đo Realme, người dùng hỏi *"có
> nên thay đổi các hoạt động của chức năng này không"*; được trình bày số đo (lượt AI **~18 s**, gấp đôi mức 7–10 s báo lúc
> chọn; luật một mình đã đọc đủ số tiền 8/10 câu; AI sai **cả hai** câu có ngày cần đọc và tự điền ví mặc định 9/10 câu —
> đều bị lớp kiểm chặn, tức AI không thêm được gì ở hai ô ấy) rồi chọn bằng câu hỏi chọn:
> 1. **Luật trước, AI chỉ khi các lớp trước bó tay** — thay *"AI đọc mọi câu"*. Luật điền tức thì; chỉ gọi Gemma khi còn
>    **ô câu có nhắc mà luật / B1 / từ khoá không đọc được** — tập ô ấy theo mục 2 dưới đây, định nghĩa từng ô ở **§8 câu
>    9** (chưa chốt). *(Bản ghi đầu tối 30/09 nêu điều kiện gọi là *"luật không đọc được số tiền mà câu có số, hoặc chưa
>    đoán được danh mục"* — viết khi mục 2 còn là *"AI chỉ số tiền + danh mục"*; mục 2 đã thay cùng tối nên điều kiện ấy
>    không còn đủ. Sửa ở lượt soát 30/09.)*
> 2. ~~**AI chỉ đọc số tiền + danh mục**~~ — **thay cùng tối** bằng câu trả lời tự do của người dùng khi được hỏi riêng về
>    ngày: *"tôi muốn AI sẽ thực hiện những phần kia nếu như các lớp trước không thực hiện được"*. Nguyên tắc chốt: **AI là
>    lớp cuối cho MỌI ô** (số tiền, ngày, ví, thu/chi, danh mục) — ô nào luật / B1 / từ khoá đọc được thì **lớp trước
>    thắng**; ô nào câu **có nhắc** mà các lớp trước không đọc được thì AI lấp, **qua lớp kiểm §2.8 như cũ**; không còn ô
>    thiếu thì **không gọi AI**. Người dùng được cho xem số đo trước khi trả lời: AI sai cả 2 câu có ngày cần đọc, và lớp
>    kiểm không bắt được một ngày sai mà hợp lệ. ⚠️ Khác bản đang chạy ở **số tiền**: hôm nay AI thắng luật khi số của AI là
>    một cách đọc hợp lệ; theo nguyên tắc mới luật đọc được số tiền thì luật thắng.
> "Có nhắc mà không đọc được" từng ô là **câu hỏi mở số 9** (§8) — phải chốt trước khi viết mã.
> Chưa chốt (hỏi đầu phiên sau): luật điền **ngay** rồi AI bổ sung ô thiếu khi về (và bỏ qua ô người dùng đã sửa trong lúc
> chờ), hay chờ AI rồi điền một lần; và *"chưa đoán được danh mục"* xảy ra thường (ghi chú mới) — có gọi AI cho riêng danh
> mục không, hay chỉ khi thiếu số tiền.

## 1. Vì sao

Ghi một khoản chi hôm nay tốn: chọn loại, gõ tiền trên bàn phím tự vẽ, chọn danh mục, chọn ví, đổi ngày, gõ ghi chú, tức
năm sáu thao tác. Người dùng nói bằng câu (*"hôm qua ăn phở 45k ví tiền mặt"*) nhanh hơn nhiều. D1 (đọc biến động số dư)
và C4 (giọng nói, chụp hoá đơn) sẽ dùng **chung** bộ đọc câu và đường điền sẵn này.

**Chỉ luật** (người dùng chốt): nhanh (< 50 ms), chạy trên mọi máy kể cả máy không có mô hình, và **không bao giờ bịa
số**. Ô nào luật không đọc được thì để nguyên.

## 2. Hàm thuần — `lib/features/transaction/domain/doc_cau_giao_dich.dart`

`KetQuaDocCau docCauGiaoDich(String cau, {required DateTime now, required List<Wallet> vi, required List<Category> chonDuoc, BoPhanLoaiGhiChu? mo, Set<(String, String)> tatCap = const {}, KetQuaAi? ai, Map<String, List<String>> tuKhoa = const {}})`

`KetQuaDocCau { double? soTien; String? loai; DateTime? ngay; String? walletId; String? categoryId; DoanDanhMuc? doan; String? lyDoDanhMuc; CategorySuggestion? goiY; String ghiChu; List<String> canhBao; bool quaAi; }`
— `doan` khác `null` khi danh mục đến từ B1 (banner mục 3); `goiY` khác `null` khi danh mục đến từ B1 **hoặc từ khoá**
(màn ghi phản hồi đúng nguồn); `ai` là ô thô của mô hình (§2.8), `tuKhoa` là từ khoá theo `categoryId` (bước từ khoá
§2.5); `quaAi` cho dòng nguồn. *(Chữ ký soát 30/09 — bản duyệt thiếu `ai`, `tuKhoa`, `goiY`, `quaAi`.)*
Mọi trường `null` nghĩa là *không đọc được*, và form **giữ nguyên** ô ấy.

### 2.1 Số tiền

Tách câu thành các **cụm tiền** theo thứ tự xuất hiện, ưu tiên cụm có đơn vị:

| Dạng | Giá trị |
|---|---|
| `45k`, `45 k`, `45 nghìn`, `45 ngàn`, `45 nghin`, `45 ngan` | × 1.000 |
| `2tr`, `2 tr`, `2 triệu`, `2 trieu`, `2 củ`, `2 cu` | × 1.000.000 |
| `1tr2` / `1tr200` | 1.200.000 (phần sau `tr` là phần lẻ theo **hàng trăm nghìn** nếu một chữ số, theo nghìn nếu ba chữ số) |
| `1,2 triệu`, `1.5tr` | 1.200.000, 1.500.000 (phẩy **hoặc** chấm thập phân khi đứng trước đơn vị triệu) |
| `2 lít`, `2 lit`, `3 xị`, `3 xi` | × 100.000 |
| số viết bằng chữ: *"năm mươi nghìn"*, *"một triệu rưỡi"* | bộ đọc số bằng chữ (§2.6) |
| số trần có chấm nghìn / không chấm: `45.000`, `45000` | chỉ nhận khi **≥ 1.000** |

- Số trần < 1.000 **không** đọc (người dùng chốt): *"2 ly cà phê"* là số lượng.
- ⚠️ *"lít"* còn là đơn vị xăng. Có **nhiều** cụm tiền thì cụm **k / nghìn / tr / số trần ≥ 1.000** được ưu tiên trước
  *lít / xị*: *"đổ 2 lít xăng 50k"* → 50.000. Chỉ có cụm *lít / xị* thì mới dùng nó.
- Sau ưu tiên mà còn ≥ 2 cụm cùng hạng → lấy cụm **đầu** và thêm cảnh báo *"Câu có nhiều số tiền — mình chỉ điền khoản
  đầu."* (một câu một khoản, người dùng chốt).
- Kết quả ≤ 0 hoặc > 13 chữ số (`kSoChuSoToiDaSoTien`, trần cột `numeric(15,2)`) → không đọc, kèm cảnh báo.

### 2.2 Loại (chi / thu)

- ⚠️ *(soát 30/09)* Dòng dưới là bản duyệt — **mã khớp từng từ có phân biệt dấu**, danh sách thật ở banner mục 7 (bỏ dấu
  cả câu thì *"bạn"* = *"bán"*).
- Câu chứa từ thu (so trọn âm tiết trên chữ bỏ dấu): *nhận, được, lương, thưởng, thu, bán, hoàn tiền, hoàn, lãi* →
  `'thu'`. Không có → `null` (form **giữ** loại đang chọn; mặc định của form là chi).
- ⚠️ *"thu"* trong *"thu nợ"* thuộc vay/nợ: câu có *nợ / vay* thì **không** đặt loại (để người dùng chọn), vì chiều tiền
  của vay/nợ đọc từ danh mục + ô *Chiều tiền* (mục 3.22 `ANALYTICS_FEATURE.md`).

### 2.3 Ngày

- `hôm nay`, `sáng nay`, `trưa nay`, `chiều nay`, `tối nay` → hôm nay; `hôm qua` → hôm qua; `hôm kia` → hai ngày trước;
  `thứ 2` … `thứ 7`, `chủ nhật` / `cn` → ngày gần nhất **trong quá khứ hoặc hôm nay** có thứ ấy; `5/9`, `05/09`, `ngày 5/9`
  → ngày ấy của **năm hiện tại** (không hợp lệ thì bỏ; nếu rơi vào tương lai quá 7 ngày thì lùi một năm).
- Không nêu → `null` (form giữ ngày của nó). Giờ trong ngày giữ như form (chỉ đổi phần ngày).
- **Một định nghĩa:** phép đọc ngày tách thành `NgayTrongCau? timNgayTrongCau(String cau, DateTime now)` ở
  `core/utils/ngay_trong_cau.dart` — trả record `({DateTime ngay, int batDau, int ketThuc})`, vị trí trong câu NFC để ghi
  chú bỏ đúng đoạn — cùng `ngayHopLe` (dời từ `ai_edge/domain/ma_ky.dart`, tệp ấy gọi lại). Mã còn đọc *thứ hai … thứ
  bảy* bằng chữ, *dd/mm/yyyy* (banner mục 9) và *"thứ X tuần trước / tuần này"*. *(Tên soát 30/09 — bản duyệt gọi
  `ngayTrongCau` trả `DateTime?`.)*
  ⚠️ `kyTuCauHoi` **không** gọi `timNgayTrongCau`: nó chỉ đọc kỳ nêu cụ thể, còn *"hôm qua"* của Trợ lý AI đi qua mã kỳ
  `hom_qua` → `kyTuMa` (banner mục 5) — hai phép không trùng định nghĩa.

### 2.4 Ví

- Tên ví nêu trong câu → `timTenTrongCau(cau, tenVi, tuLoai: 'ví')` (`core/utils/khop_ten.dart`, banner mục 4 — bản trả
  kèm vị trí để ghi chú bỏ đúng đoạn; `tenNeuTrongCau` là bản chỉ trả tên, Trợ lý AI dùng) trên các ví **đang hoạt động**
  (danh sách `_wallets` màn đã nạp bằng `getActive`, bộ chọn ví — không thêm chỗ đọc ví mới). Tên khớp đúng một ví (so
  `normalizeCategoryName`) → ví ấy. *(Tên soát 30/09.)*
- *"tiền mặt"* / *"tien mat"* mà không khớp tên nào → ví loại `cash` nếu có **đúng một**.
- Không đọc được → `null`.

### 2.5 Danh mục

- Tên danh mục nêu trong câu (`timTenTrongCau(<câu đã bỏ đoạn tiền / ngày / ví>, tên, tuLoai: 'danh mục')` trên tập hợp
  lệ — bỏ đoạn ví để *"45k ví Tiết kiệm"* không thành danh mục *Tiết kiệm*) → danh mục ấy, `lyDoDanhMuc = null`, `doan =
  null`. *(Soát 30/09.)*
- Không nêu → `mo?.doan(ghiChu, hopLe: …, tatCap: tatCap)` của B1 trên **ghi chú đã rút** (§2.7). Có kết quả thì kèm
  `doan` và `cauLyDoHoc`.
- Tập hợp lệ (banner mục 2): `loai` đọc được ở 2.2 thì `hopLeTheoChieu(loai, chonDuoc)` của C1; không đọc được thì **mọi**
  danh mục chọn được (không nhóm, chưa xoá) — cùng nếp thẻ gợi ý của màn, danh mục kéo đoạn Chi/Thu theo.
- **Bước từ khoá (2026-09-30, người dùng đề xuất sau khi đo Realme: *"đổ xăng"*, *"grab"* bị AI xếp Ăn uống):** thứ tự đầy
  đủ là **tên nêu trong câu → B1 khi chắc → từ khoá của danh mục → AI** — cùng thứ tự thẻ gợi ý trên màn (B1 trước từ
  khoá). Khớp bằng chính `CategorySuggestionEngine` (so có dấu trước, bỏ dấu sau, hoà thì không đoán), chỉ trên danh mục
  hợp chiều, trên ghi chú của luật. `KetQuaDocCau.goiY` mang gợi ý (B1 hoặc từ khoá) để lúc lưu ghi phản hồi đúng nguồn.

### 2.6 Bộ đọc số bằng chữ — dời ra `core/utils/so_bang_chu.dart`

Hai bộ đọc riêng tư đang sống: `ai_edge/domain/kiem_so.dart` (chữ có dấu, kiểm câu trả lời) và
`ai_edge/domain/chinh_tham_so.dart` (chữ bỏ dấu, ngưỡng tiền câu hỏi). Cả hai **không** đọc hàng chục (banner mục 1).
Thay bằng **một** `List<CumSoChu> timSoBangChu(String cau, {bool batBuocDonVi = true})` ở
`core/utils/so_bang_chu.dart` (`CumSoChu` = `({int batDau, int ketThuc, double giaTri})`): mỗi từ khớp dạng **có dấu**
hoặc dạng **không dấu hoàn toàn** (không bỏ dấu cả câu — *"một tí"* không phải một tỉ), vị trí trả về theo chính câu
truyền vào, `giaTri` là `NaN` cho lượng từ mơ hồ (*vài, mấy, dăm*). `batBuocDonVi: false` chỉ dùng cho lưới kiểm AI
(`cachDocSoTien` — *"ba chục"* không đơn vị). *(Chữ ký soát 30/09.)* Hàng chục: *mười* (10) · *X mươi* (X·10) · sau
*mươi*: *mốt* (1), *tư* (4), *lăm / nhăm* (5) · *linh / lẻ* (0 chục) — *"hai mươi lăm nghìn"* = 25.000, *"một trăm linh
năm nghìn"* = 105.000. Từ số vẫn phải có **đơn vị** ngay sau cụm (*"năm nay"*, *"một khoản"* không phải số).
`kiem_so.dart` và `chinh_tham_so.dart` gọi lại; mọi test cũ của hai tệp xanh **không sửa kỳ vọng** (gồm các ca bẫy
4.42: *"một triệu"*, lượng từ mơ hồ, *"500 nghìn"* giữ cách đọc cũ — chữ số kèm đơn vị chữ không thuộc bộ đọc này).

### 2.7 Ghi chú

Câu gốc, **bỏ** các đoạn đã dùng cho số tiền, ngày và ví (kèm chữ *"ví"*, *"bằng"*, *"bằng ví"* đứng ngay trước tên ví),
gom khoảng trắng, bỏ dấu câu thừa ở hai đầu, **giữ nguyên** dấu và chữ hoa. *"hôm qua ăn phở 45k ví tiền mặt"* → *"ăn
phở"*. Tên danh mục nêu trong câu **giữ lại** trong ghi chú (*"45k ăn uống với bạn"* → *"ăn uống với bạn"*), vì đó thường
là nội dung người dùng muốn nhớ.

### 2.8 Đọc bằng AI (2026-09-30) — AI đề xuất, luật kiểm

**Khi nào:** máy có mô hình (`MoHinhTaiVe.daCo()`) **và** công tắc AI bật (`CongTacAi.doc()`) — cùng hai điều kiện của
màn Trợ lý AI. Không có thì chỉ luật (§2.1–2.7). Máy từng sập native ở phiên có tool (`BacCongCuDaTat`), mô hình không
nạp được, lượt sinh lỗi hay quá thời gian → dùng kết quả luật, không báo lỗi to.

**Gọi mô hình:** một phiên `SlmRuntime.moPhien` với **đúng một** tool `dien_giao_dich` — prompt ngắn (bẫy 4.51: phiên một
tool mô hình viết đúng mọi số). Tham số: `so_tien` (số đồng, 0 = câu không nói), `loai` (`chi` · `thu` · `khong_ro`),
`ngay` (`dd/mm/yyyy` hoặc rỗng — lời hệ thống cho biết hôm nay là ngày nào, thứ mấy), `vi` và `danh_muc` là **enum** gồm
đúng tên có thật (cộng chuỗi rỗng), `ghi_chu`. Lời gọi đầu tiên là kết quả; phiên đóng ngay, không trả kết quả tool về.
Mã ở `transaction/data/doc_cau_bang_ai.dart` (tầng `ai_edge/` cấm chữ `'thu'`/`'chi'` — test quét 14).

**Luật kiểm từng ô** — nằm **trong** `docCauGiaoDich(cau, …, ai: KetQuaAi)` (`transaction/domain/doc_cau_giao_dich.dart`;
`KetQuaAi.tuThamSo` đọc tham số lời gọi tool, rỗng / `0` / `khong_ro` → `null`). *(Soát 30/09: bản thiết kế đặt tên một
hàm riêng `hopNhatAi` — mã không có hàm ấy.)* Trượt thì dùng ô của luật:
- **Số tiền:** phải thuộc `cachDocSoTien(cau, now:)` — tập mọi cách đọc hợp lệ (≥ 1.000 đ, dưới 13 chữ số) của các con số
  có trong câu: mọi cụm luật thấy (kể cả cụm luật không chọn — *lít / xị*, số thứ hai), số trần `n` → `n`, và `n × 1.000`
  khi `10 ≤ n < 1.000` (*"ăn phở 45"*; số một chữ số là số lượng — *"2 ly"*), số chữ không đơn vị có hàng chục → × 1.000
  (*"ba chục"* → 30.000), *"X triệu Y"* / *"X tr Y"* / *"một triệu hai"* → X,Y triệu, *"2k5"* → 2.500. AI được **chọn cách
  đọc**, không thể đưa ra chữ số không có trong câu. ⚠️ Mã hôm nay: số AI qua kiểm thì **thắng** số luật (và xoá cảnh báo số
  tiền của luật, trừ *"nhiều số tiền"*) — ĐỔI LẦN HAI đảo điều này. *(Soát 30/09: bản thiết kế ghi `n × 1.000.000` và
  *"ba chục"* → 30 — mã không nhận cả hai.)*
- **Ngày:** luật đọc được ngày (chữ không hai nghĩa: *hôm qua*, *5/9*, *thứ 2*) thì **luật thắng**. Luật không đọc được
  thì dùng ngày AI khi: hợp lệ trên lịch, không quá hôm nay + 7 ngày, không cũ hơn 366 ngày, **và** câu có chữ chỉ thời
  gian (`_coChuThoiGian` — khớp **từng từ, phân biệt dấu** như từ chỉ thu: có dấu *tuần, tháng, hôm, trước, qua, đầu,
  cuối, sáng, trưa, chiều, tối, đêm, thứ, nay, ngày, mai, kia, ngoái, nhật*; không dấu chỉ *tuan, thang, hom, truoc, trua,
  chieu, ngay, kia* — vì *"tôi"* bỏ dấu là *"toi"* = tối, *"quà"* là *"qua"*); câu không có chữ nào thì AI không được đổi
  ngày. *(Danh sách soát 30/09.)* AI trả **đúng hôm nay** thì coi là *không biết ngày* (đo Realme 2026-09-30: *"đầu tháng"* → hôm
  nay) — form vốn là hôm nay, nhận nó chỉ làm dòng tóm tắt nói *"Hôm nay"*.
- **Loại:** `chi` / `thu` của AI được dùng; câu có *nợ / vay* → `null` như luật.
- **Ví:** tên AI chọn phải trùng đúng một ví đang hoạt động **và câu phải nhắc ví** — chữ chỉ ví / cách trả (*ví, thẻ,
  quẹt, ck, chuyển khoản, atm*) hoặc viết tắt tên ví (*"techcom"*). Đo Realme 2026-09-30: 9/10 câu mô hình trả ví mặc định
  dù câu không nói — điền nó là bịa một ô và khoá luật *ví hay dùng*.
- **Danh mục:** thứ tự (1) tên nêu trong câu (luật) → (2) **B1 khi nó chắc** (người dùng chốt: thói quen riêng thắng hiểu
  biết chung) → (3) **từ khoá của danh mục** (thêm sau lượt đo, `ea12588`, §2.5) → (4) danh mục AI chọn, phải trùng một
  danh mục chọn được (`khopTheoTen`) và hợp chiều → (5) không có. *(Bước 3 soát 30/09.)*
- **Ghi chú:** mọi âm tiết (bỏ dấu) trong ghi chú AI phải có trong **ghi chú luật** (câu đã bỏ tiền, ngày, ví) — AI được
  bớt chữ, không được thêm chữ; rỗng hoặc trượt thì ghi chú luật.

**Nạp trước:** chạm vào ô Nhập nhanh → nạp mô hình ngầm (một `Future` dùng chung, bấm Điền lúc đang nạp thì chờ nó).

**Trên màn:** lúc chờ, nút **Điền** mờ đi và dưới ô hiện dòng *"Đang đọc bằng AI…"* kèm **Huỷ** (huỷ → điền ngay bằng
luật, mô hình thôi giải mã qua `DocCauBangAi.huy`). Dòng tóm tắt thêm nguồn: *"Đọc bằng AI"* hay *"Đọc bằng luật"*. Vẫn
chỉ điền sẵn; ✓ mới lưu. Quá **45 s** (`kThoiHanDocAi`, tính từ lúc mở phiên) → luật. *(Soát 30/09.)*

## 3. Giao diện — màn Thêm giao dịch

- Ô **"Nhập nhanh"** ở **đầu** màn, **chỉ ở đường tạo mới** (màn sửa giao dịch không có). Gợi ý: *"VD: hôm qua ăn phở 45k
  tiền mặt"*. Bấm **Điền** (hoặc Enter) thì chạy `docCauGiaoDich`.
- Ghi đè **chỉ** những ô đọc được: số tiền (qua **đúng** đường bàn phím tự vẽ đang dùng, để trạng thái biểu thức và trần
  13 chữ số của `themPhimSoTien` nhất quán), loại, ngày, ví (⚠️ đánh dấu *"người dùng đã tự đặt ví"* để luật ví hay dùng
  theo danh mục, mục 1.2, **không** đè lại), danh mục, ghi chú.
- Dưới ô: một dòng tóm tắt *"Đã điền: 45.000 đ · Hôm qua · Tiền mặt · Ăn uống"* (tiền qua `CurrencyFormatter`), kèm
  cảnh báo nếu có, và câu lý do danh mục nếu đến từ B1. Không đọc được gì → *"Mình chưa đọc được câu này — bạn điền tay
  nhé."*
- Người dùng xem lại rồi bấm **Lưu** như thường. **Không** tự lưu.
- **Stitch (T5, 2026-09-30):** màn `8afdfe113cc84874b2009aa80fe755fd` *"Thêm giao dịch - Nhập nhanh bằng câu"* — thẻ
  *NHẬP NHANH* ở **đầu vùng cuộn** (trên thẻ form; ô cố định trên cùng thì ở 360 × 640 thẻ form còn chưa tới 70 dp), nút
  **Điền nằm trong khung ô**, tia sét đỏ cam, dòng *"Đã điền: …"* xanh có dấu tích, câu lý do B1 in nghiêng. Hai trạng
  thái của §2.8 (*"Đang đọc bằng AI…"* + Huỷ; nhãn nguồn *"Đọc bằng AI"*) gửi tạo cùng ngày — lời gọi trả *timeout*.
  Kết quả (kiểm `list_screens` 2026-09-30, phiên soát tài liệu): màn **`63e981f5b66c4e599572c02e14134a6f`** *"Thêm giao
  dịch - Nhập nhanh - Đang đọc bằng AI"* **có**; màn *"… - Đã điền bằng AI"* **vẫn chưa** (dự án 83 màn) — đừng gọi lại.
  Cả ba màn **chưa được người dùng duyệt** (§8 câu 5).
- ⚠️ Giao diện mới → **Stitch trước**. ⚠️ Màn Thêm giao dịch có bẫy bố cục đã biết (số 13 chữ số ngắt dòng, `FittedBox`)
  và bàn phím tự vẽ. Ô mới không được đẩy bàn phím ra khỏi màn ở khổ 360 × 640.

## 4. Không làm

~~Không mô hình~~ (đổi 2026-09-30, §2.8). Không tách nhiều khoản. Không ở màn Trợ lý AI. Không tự lưu. Không đổi schema.

## 5. Giới hạn nói trước

- Câu tự do quá xa khuôn (*"cái hôm đi Đà Lạt tốn mấy trăm"*) → không đọc được số, người dùng điền tay.
- *"thứ 2"* luôn là thứ Hai **gần nhất đã qua hoặc hôm nay**; nói về thứ Hai tuần sau thì phải chọn ngày tay.
- Ví trùng tên gần nhau (*"Tiết kiệm"* và *"Tiết kiệm 2"*) → `khopTheoTen` có thể không ra đúng một, và ô ví giữ nguyên.

## 6. Kiểm thử

- **`docCauGiaoDich` (hàm thuần), mỗi dạng ở §2.1 một ca:** `45k`, `45 nghìn`, `45 ngàn`, `2tr`, `1tr2`, `1tr200`,
  `1,2 triệu`, `2 củ`, `2 lít`, `3 xị`, *"năm mươi nghìn"*, *"một triệu rưỡi"*, `45.000`, `45000`; `"2 ly cà phê"` → `null`;
  *"đổ 2 lít xăng 50k"* → 50.000; *"ăn sáng 30k, grab 50k"* → 30.000 + cảnh báo; 14 chữ số → `null` + cảnh báo.
- **Loại:** *"nhận lương 9tr"* → thu; *"thu nợ anh Nam 500k"* → `null`; câu trơn → `null`.
- **Ngày:** hôm nay / hôm qua / hôm kia; *"thứ 2"* khi hôm nay thứ Tư → thứ Hai tuần này; khi hôm nay thứ Hai → hôm nay;
  `31/2` → `null`; đọc ngày 3/1/2027, `30/12` → 30/12/**2026** (30/12/2027 ở tương lai quá 7 ngày nên lùi một năm);
  đọc ngày 3/1/2027, `5/1` → 5/1/2027 (tương lai 2 ngày, giữ). Tháng ngắn, năm nhuận: `29/2` năm thường → `null`, năm
  nhuận → hợp lệ.
- **Ví / danh mục:** tên ví trong câu; *"tiền mặt"* với một và với hai ví cash; tên danh mục trong câu thắng B1; danh mục
  thu không được chọn cho khoản chi.
- **Ghi chú:** các ví dụ ở §2.7.
- **`so_bang_chu` (phép dời):** toàn bộ test `kiem_so_test` xanh không sửa kỳ vọng.
- **`timNgayTrongCau` + `kyTuCauHoi`:** test `ma_ky_test` và `chinh_tham_so_test` xanh không sửa kỳ vọng.
- **Widget màn Thêm giao dịch:** gõ câu → bấm *Điền* → các ô đúng, dòng tóm tắt đúng; ô không đọc được giữ giá trị cũ;
  màn **sửa** giao dịch không có ô; khổ 360 × 640 không tràn; bấm *Lưu* ra đúng giao dịch (khuôn `so_tien_thap_phan_test`
  dựng `GoRouter` thật vì lưu xong trang `pop`).
- **Máy thật** (Realme — banner mục 6; bản duyệt ghi *máy ảo*, mà máy ảo không chạy được mô hình): mười câu thật kiểu
  người dùng hay gõ, đếm số ô điền đúng. Đây là phép đo, không phải cổng; bảng ở mục 9.41 `AI_EDGE_FEATURE.md`.

## 7. Tài liệu đi kèm

Tài liệu tính năng giao dịch (hoặc mục mới trong `PROJECT_CONTEXT.md` mục 14): bảng quy đổi §2.1, luật ưu tiên *lít*,
giới hạn §5. `AI_EDGE_FEATURE.md`: `so_bang_chu` và `ngay_trong_cau` dời ra `core/utils`. `CLAUDE.md` hàng *Đụng vào ô nhập
TIỀN* (một câu: ô Nhập nhanh đi qua cùng đường bàn phím tự vẽ).

## 8. Câu hỏi mở cho buổi thảo luận tiếp (ghi 2026-09-30 tối)

Số đo đứng sau từng câu: mục **9.41** `docs/AI_EDGE_FEATURE.md` (Realme, 10 câu). Câu **1, 2 và 9** **chặn** việc thi công
banner *"ĐỔI LẦN HAI"* — hỏi trước khi viết mã (câu 2 và 9 nên chốt cùng nhau: cùng là "khi nào gọi AI").

1. **Điền ngay rồi AI bổ sung ô thiếu, hay chờ AI rồi điền một lần?** Điền ngay: thấy kết quả luật tức thì, AI về chỉ điền
   ô còn trống và bỏ qua ô người dùng đã sửa trong lúc chờ (phức tạp hơn). Chờ: đơn giản, nhưng câu cần AI vẫn chờ ~18 s.
2. **"Chưa đoán được danh mục" có đủ để gọi AI không?** Ghi chú mới (B1 và từ khoá chưa biết) sẽ rơi vào đây thường xuyên
   → AI chạy gần như mọi câu mới, mất lợi ích tốc độ. Lựa chọn: gọi AI như thường · chỉ gọi khi thiếu số tiền · gọi qua
   nút *"Hỏi AI danh mục"*. Đo: AI đoán danh mục 5 lần → 3 đúng, 2 sai.
3. **AI thiên về "Ăn uống"?** Hai câu sai (*đổ xăng*, *grab*) đều ra Ăn uống — nghi giá trị đầu / phổ biến của enum. Chưa đo;
   thử đảo thứ tự enum hoặc thêm mô tả danh mục.
4. **Ngày kiểu *"đầu tháng / tuần trước / cuối tháng trước"*** — khi AI thôi đọc ngày, có thêm vào luật không (*"đầu tháng"*
   mơ hồ)?
5. **Stitch chưa được duyệt**: `8afdfe113cc84874b2009aa80fe755fd` (màn chính), `63e981f5b66c4e599572c02e14134a6f` (đang đọc
   bằng AI), màn *"… - Đã điền bằng AI"* (gọi tạo, timeout, chưa xuất hiện — kiểm lại 2026-09-30 phiên soát tài liệu: vẫn
   chưa). Câu 1 có thể cần trạng thái mới → Stitch trước.
6. **Ô Ghi chú màn này có khung viền theme** (có từ trước C2; Stitch không khung) — sửa không?
7. **Đề xuất thêm từ khoá từ thói quen** (việc riêng ngay sau C2, người dùng chốt): hiện ở đâu, ngưỡng lặp, **chuyển** từ
   khoá khi chữ đang thuộc danh mục khác (*grab* ở Ăn uống), bỏ qua / thôi đề xuất, từ khoá có đi qua đồng bộ không.
8. **"Dùng lâu dài thì AI có học không?"** (người dùng hỏi 2026-09-30 tối). Gemma **không** học — trọng số cố định, gói
   không có API huấn luyện (mục 10 `AI_EDGE_FEATURE.md`). Thứ học theo thời gian là các lớp quanh nó: **B1** học lại từ sổ
   mỗi lần mở màn (mọi giao dịch có ghi chú + danh mục, kể cả nhập qua Nhập nhanh) và từ phản hồi `chon`/`khac`/`bo_qua`
   (`tatCap`); **ví hay dùng** theo danh mục học từ lịch sử; **từ khoá** sẽ học qua việc đề xuất (câu 7). Vì B1 đứng trước
   AI, dùng càng lâu thì AI càng ít phải đoán danh mục. ⚠️ **Vòng lặp học sai**: danh mục AI đoán sai mà người dùng lưu luôn
   không sửa thì B1 học đúng cái sai ấy (*"xăng" → Ăn uống*), rồi vì B1 thắng AI nên cái sai bị **khoá lại**. Cần bàn: có
   loại giao dịch có danh mục do AI điền (chưa được người dùng xác nhận) khỏi mẫu học của B1 không, hay nhắc người dùng kiểm
   danh mục khi nguồn là AI. Số tiền và ngày là luật cố định — không học, và không cần học; cách nói lạ thì phải sửa luật.
9. **"Câu có nhắc mà các lớp trước không đọc được" — định nghĩa từng ô** (chặn việc thi công, sinh ra từ nguyên tắc *"AI là
   lớp cuối cho mọi ô"*). Đề xuất để bàn: **số tiền** — luật `null` mà `cachDocSoTien(cau)` khác rỗng (câu có số / số chữ);
   **ngày** — luật `null` mà câu có chữ thời gian (`_coChuThoiGian`); **ví** — luật `null` mà câu có chữ nhắc ví
   (`_cauNhacVi`); **thu/chi** — luật `null` (khó biết câu có "nhắc" không: có gọi AI chỉ vì thiếu thu/chi?); **danh mục** —
   tên / B1 / từ khoá đều im (trùng câu 2). Câu nào **không** có ô nào thiếu thì không gọi AI. Kèm: ghi chú — khi AI lấp số
   tiền, ghi chú luật còn chữ của số ấy (*"mất ba chục"*); dùng ghi chú AI (chỉ bớt chữ) cho ca ấy?
