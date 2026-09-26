# Bước 2c — lượt rỗng theo bộ lọc không phải câu trả lời · tên `snake_case` (thiết kế)

**Ngày:** 2026-09-24 · **Nhánh:** `TranQuangDat` @ `a66757f` · **Trạng thái:** ✅ **đã duyệt** 2026-09-24 —
thiết kế phần 1 (phạm vi + hai cơ chế) duyệt trong chat, năm câu hỏi phần 2 chốt cùng ngày (mục 1.2), spec duyệt
cùng ngày (`de7c6d5`). Kế hoạch 9 task: `docs/superpowers/plans/2026-09-24-buoc-2c-luot-rong-theo-bo-loc.md` (gitignore).
✅ **Mã xong task 1–7 ngày 2026-09-24 trưa** (`1301de9` → `5b7b7f4`, thi công inline; nhật ký cuối tệp kế hoạch): 24
bản sai đều bị bắt (một bản tương đương sống sót, ghi rõ); `flutter test` **3755/3755**, 3 skip; `flutter analyze` **26**,
0 error. 🛑 **Cổng D lần 3 CHƯA ĐẠT — nhưng HAI BẪY ĐÓNG** (Realme 2026-09-24 13:35–14:06, mục **9.19**
`docs/AI_EDGE_FEATURE.md`): C9 hết SAI (*"Tháng này, ghi chú chứa "chi", đến 1.000.000 đ — không có giao dịch nào
khớp."*), C11 khớp *Tiết kiệm* → 10 khoản đúng; **SAI = 0**, 0 sập, 0 vỡ trần; ba tiêu chí thêm của mục 5 đều ✅.
Nhưng mô hình gọi tool / tham số **y hệt lần 2** ở cả 20 câu C (10/20 · 5/20) → dòng 3 đứng yên; nhóm B 2/4; ĐC3
vẫn trượt tiêu chí. Theo mục 5 bước 5: đòn bẩy kế tiếp đổi tên `chi_tieu_theo_ky` — **chờ người dùng quyết**. Lộ
bẫy mới **4.46** (mô hình đọc số dòng hiện thành số khoản — `kiemSo` chặn đúng, C11/C16 rơi mẫu câu).
*(Sau spec này, cùng chiều: đổi tên tool `chi_tieu_theo_ky` → `tong_ket_thu_chi_ky` (`61f66ba`), cổng D lần 4 —
mục **9.20**; các ví dụ trong spec này vẫn dùng tên cũ vì đó là tên lúc đo lần 3.)*
> ⚠️ **Chỗ thi công KHÁC spec, có chủ ý** (bốn chỗ ghi đầu kế hoạch): gói có danh sách `soLieuBoLoc` riêng thay vì
> nhét vào `tongHop`; `GoiSoTraCuu.luotRong` là getter công khai (vòng lặp ghi log); ca đầu-cuối `vi: "tiet_kiem"` ở
> task 1; thứ tự `cauNoiThem` ghi bằng danh sách loại xảy ra trước.
**Đầu vào:** cổng D lần đo 2 — mục **9.18** `docs/AI_EDGE_FEATURE.md`, bẫy **4.44**, **4.45**; spec bước 2b
`2026-09-24-buoc-2b-tu-choi-giu-cho-mo-ta-tool-design.md` (mục 2.2, 2.3 — cổng hiện chữ, L1b, L2b); spec 4b
`2026-09-23-chang-4b-tool-calling-vong-lap-design.md` (mục 3.6 — chốt L1).
**Khung cố định:** bốn bất biến mục 6 `docs/AI_AGENT_ARCHITECTURE.md` — **không đổi**. Ba lớp chắn (`kiemSo` ·
`kiemNhan` · `kiemGiong`), thẻ số liệu, bậc 1, `maxTokens` 4096, tên tool, mô tả tool, JSON gửi mô hình — **không
đổi**.

> "Bước 2c" là vòng sửa thứ hai của bước 2, chỉ chạm hai bẫy 4.44 và 4.45, để đo được tác dụng **riêng** của chúng
> trước khi dùng đòn bẩy đã để dành (đổi tên `chi_tieu_theo_ky`, spec 2b mục 1.2 hàng 10). Bước 3 (chiều ghi)
> **chưa mở**.

---

## 1. Vì sao

### 1.1 Hai lỗi của cổng D lần 2 mà spec này sửa

| # | Lỗi | Đo được (mục 9.18) | Bẫy |
|---|---|---|---|
| 1 | **Tham số thừa làm hẹp bộ lọc → lượt `tim_giao_dich` THÀNH CÔNG mà 0 khoản → mẫu câu L2 nói *"Số khoản: 0; Tổng chi: 0 đ"*.** C9 *"liệt kê các khoản chi từ 200k đến 1 triệu tháng này"* → `{ky: thang_nay, so_tien_den: 1000000, tu_khoa: "chi"}`: không ghi chú nào chứa "chi", tool trả 0 hàng, và đó là một lượt **thành công** nên cổng hiện chữ mở và mẫu câu in con số 0 — có **2** khoản. Luật bước 2b chỉ xét lượt bị **từ chối**; *"0 hàng thật là dữ liệu thật"* chỉ đúng khi **bộ lọc khớp câu hỏi**, mà không lớp nào biết bộ lọc có khớp không. Ca sinh đôi C15: *"lần gần nhất chi cho di chuyển"* → `chieu: chuyen_vi` → mẫu câu liệt kê khoản **chuyển**, không ai thấy bộ lọc đã lệch | 1 câu SAI (C9), 2 mẫu câu lệch (C15, C16) | 4.44 |
| 2 | **E2B gõ tên theo kiểu `snake_case`**: `vi: "tiet_kiem"` — `khopTheoTen` không đổi `_` thành dấu cách nên không khớp ví *Tiết kiệm* → từ chối → L1b. Đúng luật, không SAI, nhưng câu hỏi đúng ý thành *"chưa tra được"*, và câu cho người dùng hiện nguyên `"tiet_kiem"` — luật (a) của spec 2b (*"không có dấu `_`"*) chỉ nghĩ tới mã tham số, không nghĩ tới giá trị mô hình gõ | C11 | 4.45 |

Cả hai đều là lỗi **mã**, không phải mô tả tool. Ba câu C1, C7, C12 vẫn LỆCH vì chọn sai tool — ngoài phạm vi
(mục 3).

### 1.2 Quyết định đã chốt (2026-09-24, không hỏi lại)

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Thứ tự việc sau cổng D lần 2 | **Sửa 4.44 và 4.45 trước**, **chưa** đổi tên `chi_tieu_theo_ky` — để còn đo được tác dụng riêng |
| 2 | `tim_giao_dich` thành công mà 0 khoản | Chữ mô hình **không hiện**; app hiện **mẫu câu nêu bộ lọc** đã dùng. Giá chấp nhận: câu 0 khoản đúng như C3 (*"Không có giao dịch nào hôm nay"*) cũng thành mẫu câu |
| 3 | Mẫu câu của `tim_giao_dich` khi **có** kết quả | **Luôn** nêu bộ lọc — C15 (đọc *"di chuyển"* thành chuyển ví) và C16 (lẫn khoản thu) tự lộ ra cho người đọc |
| 4 | Chặn đầu vào kiểu *"từ chối `tu_khoa` là chữ chiều tiền"* | **Không** — không có cách nói chắc một từ là chiều tiền hay là chữ trong ghi chú |
| 5 | Lượt rỗng có được **gỡ** không (mô hình gọi lại rộng hơn và ra kết quả) | **Không**, cùng lý lẽ với ca *"abc"* của bước 2b: lượt rộng hơn trả lời một câu hỏi khác |
| 6 | Chỉ `tim_giao_dich` hay mọi tool | **Chỉ `tim_giao_dich`**: tool khác lọc bằng mã kỳ / trạng thái nên 0 hàng là dữ liệu thật (C2 *"hôm qua chi 0 đ"*, A9 vẫn hiện chữ mô hình) |
| 7 | Khoảng tiền đứng ở đâu trong mẫu câu (câu 1 phần 2) | **Lên tiền tố cùng bộ lọc chữ**, thôi in thành vế `Từ:` / `Đến:` — bộ lọc là một thứ, đứng một chỗ. Hai `SoLieu` ấy **vẫn** trong gói (`kiemSo`, thẻ) và **vẫn** vào JSON |
| 8 | Câu cho lượt 0 khoản dựng ở đâu (câu 2) | **`GoiSoTraCuu` dựng**; `hangGiaoDich` chỉ đặt cờ và điền bộ lọc. Ba chi tiết kèm theo: `tongHop` 0 vẫn vào JSON; thẻ số liệu dưới câu rỗng được hiện khoảng tiền; câu nối khi đã có câu hiện đảo trật tự (*"Không có giao dịch nào khớp: ‹tiền tố›."*) |
| 9 | Bộ lọc có vào JSON không; `tu_khoa` có vào `tenLienQuan` không (câu 3) | **Không vào JSON** (mô hình đã biết tham số của nó; `chuThem` cấm chữ số; trần 4096). **`tu_khoa` vào `tenLienQuan`** |
| 10 | Ghép câu lượt rỗng với câu chưa tra được (câu 4) | **Một getter chung `cauNoiThem`**; vòng lặp giữ nguyên nhánh `!choHienChuMoHinh`, chỉ đổi chuỗi nối và log |
| 11 | Đo sau khi mã xong (câu 5) | **Cổng D lần 3 đủ 34 câu** trên Realme, cùng điều kiện hai lần trước |

### 1.3 Điều định hình thiết kế

**Vế "0 hàng thật là dữ liệu thật" của chốt L1 đúng cho tool lọc bằng mã, sai cho tool lọc bằng chữ tự do.**
`chi_tieu_theo_ky {hom_qua}` trả 0 đ là sự thật về hôm qua. `tim_giao_dich {tu_khoa: "chi"}` trả 0 hàng là sự thật
về **ghi chú chứa "chi"** — một câu hỏi mà người dùng không đặt. Mô hình là bên duy nhất dịch câu hỏi thành bộ lọc,
và cổng D lần 2 đo được nó dịch sai ở 5/10 lời gọi `tim_giao_dich` (C6, C9, C15, C16, C19). Nên với tool này,
"0 khoản" không được phép thành một câu trả lời — nó thành một **báo cáo về bộ lọc**, và người đọc tự thấy bộ lọc
có khớp câu hỏi của mình không.

---

## 2. Thiết kế

### 2.1 `KetQuaCongCu` — bộ lọc dội lại (`ai_edge/domain/hang_so_lieu.dart`)

Thêm ba trường, mặc định rỗng, chỉ `hangGiaoDich` điền:

```dart
/// Lượt THÀNH CÔNG mà 0 khoản khớp bộ lọc — với tool lọc bằng chữ tự do,
/// 0 khoản không phải câu trả lời (spec 2c mục 1.3). KHÔNG vào json.
final bool rongTheoBoLoc;

/// Chữ từng điều kiện lọc, theo thứ tự cố định (mục 2.2), cho mẫu câu.
/// Được chứa chữ số (khoảng tiền) vì KHÔNG vào json — khác chuThem.
final List<String> boLoc;

/// Số liệu dội lại của bộ lọc (Từ / Đến): nằm trong gói và trong json như
/// tongHop, nhưng mẫu câu KHÔNG in thành vế — tiền tố đã nêu.
final List<SoLieu> soLieuBoLoc;
```

`json` **không đổi nội dung** so với hôm nay: `soLieuBoLoc` vào `json` y như `tongHop` (`nhan: chuoi`). Hai trường
kia không vào. Hàm dựng `KetQuaCongCu.loi` không nhận ba trường này.

### 2.2 `hangGiaoDich` (`ai_edge/domain/hang_giao_dich.dart`)

- `rongTheoBoLoc = kq.soKhop == 0` (chỉ khi `kq.loi == null`).
- `Từ` / `Đến` chuyển từ `tongHop` sang `soLieuBoLoc`. `tongHop` còn `Số khoản` và các tổng theo chiều — không đổi.
- `boLoc`, thứ tự **cố định**, bỏ mục không có:

| Thứ tự | Điều kiện | Chữ | Nguồn |
|---|---|---|---|
| 1 | `chieu != tatCa` | `khoản chi` · `khoản thu` · `chuyển ví` | `tieuChi.chieu` |
| 2 | có danh mục | `danh mục "Ăn uống"` | **tên thật** đã khớp, không phải chữ mô hình gõ |
| 3 | có ví | `ví "Tiết kiệm"` | tên thật đã khớp |
| 4 | `tuKhoa` không rỗng | `ghi chú chứa "hoa don"` | `tieuChi.tuKhoa` |
| 5 | có `tu` | `từ 200.000 đ` | **cùng chuỗi** với `soTien('Từ', tu).chuoi` |
| 6 | có `den` | `đến 1.000.000 đ` | cùng chuỗi với `soTien('Đến', den).chuoi` |
| 7 | `sapXep == moiNhat` | `mới nhất trước` | `so_tien` là mặc định nên không nêu |

Chữ kỳ **không** vào `boLoc` — nó vẫn ở `chuThem['ky']` như hôm nay, vì phép gom nhóm của `mauCau()` đọc từ đó.

- Tên thật đã khớp: `KetQuaTimGiaoDich` (`transaction/domain/tim_giao_dich.dart`) nay chỉ có `tenKhop` gộp cả hai
  tên không nhãn. Tách thành `tenDanhMucKhop: String?` và `tenViKhop: String?`; `tenKhop` giữ làm getter suy ra để
  ba chỗ đọc hôm nay không đổi. Chỗ chạm duy nhất ngoài `ai_edge`.
- `tenLienQuan` cộng thêm `tuKhoa` (khi không rỗng): tiền tố in *ghi chú chứa "T9"* và bộ kiểm phải hiểu "9" là
  một phần của tên (bước 1c — `trichSoNgoaiTen` chỉ bỏ tên **có chữ cái**, nên `tu_khoa` toàn chữ số không lọt qua
  đường này; nó đã bị `laSoTien` từ chối từ bước 2b).

### 2.3 `GoiSoTraCuu` (`ai_edge/domain/goi_so_tra_cuu.dart`)

```dart
bool get choHienChuMoHinh => daTraCuu && _tuChoi.isEmpty && _luotRong.isEmpty;
String? get cauLuotRong;   // 'Không có giao dịch nào khớp: ‹tiền tố 1›; ‹tiền tố 2›.' — mọi lượt rỗng theo thứ tự,
                           // bỏ trùng, nối bằng '; '; null khi không có. Tiền tố ở đây viết thường chữ đầu
String? get cauNoiThem;    // cauLuotRong + cauChuaTraDuoc, câu của loại xảy ra TRƯỚC đứng trước; null khi cả hai null
```

- **Lượt rỗng theo bộ lọc** vẫn là lượt **thành công**: vào `tenCongCuDaChay` (nên `daTraCuu` đúng, không rơi
  về bậc 1), vào `_luot`, `tongHop` và `soLieuBoLoc` vào `soLieu` của gói. Thêm vào `_luotRong`. **Không bao giờ
  gỡ** (mục 1.2 hàng 5).
- `soLieu` của gói gồm cả `soLieuBoLoc` của mọi lượt: mô hình được nhắc lại khoảng tiền, `kiemSo` phải cho qua;
  thẻ số liệu nhặt được nó.
- **Tiền tố** của một nhóm = `[chuThem['ky'], ...boLoc].join(', ')`, chữ đầu viết hoa, rồi ` — `. Không có gì thì
  rỗng như hôm nay.
- **`_cauCuaNhom`**: nhóm có `rongTheoBoLoc` → `‹tiền tố› — không có giao dịch nào khớp.` và **không** in vế nào;
  nhóm thường → tiền tố + các vế như hôm nay, nhưng chỉ `hang` và `tongHop` — `soLieuBoLoc` không in.
- **Khoá gom nhóm** = nội dung (json bỏ `ky`) **và** `boLoc`: hai lượt khác bộ lọc mà trùng kết quả không được gộp
  dưới một tiền tố.
- **`mauCau()`** giữ ba trạng thái của bước 2b; chỉ khác là lượt rỗng của `tim_giao_dich` có `tongHop` nên đi đường
  nhóm, không đi đường *"Không tìm thấy dữ liệu khớp câu hỏi."* — câu ấy nay chỉ còn cho tool trả rỗng cả hàng lẫn
  tổng hợp. Câu cuối vẫn nối `cauChuaTraDuoc` như hôm nay; **không** nối `cauLuotRong` (nhóm rỗng đã tự nói).
- `tenDoiTuong` không đổi công thức — `tu_khoa` tới qua `tenLienQuan`.

Ví dụ C9 sau sửa (một lượt, rỗng): *"Tháng này, ghi chú chứa "chi", đến 1.000.000 đ — không có giao dịch nào
khớp."* Ví dụ C15: *"Mọi thời gian, chuyển ví, mới nhất trước — Chuyển khoản chuyển ví · Tiền mặt → Tiết kiệm: Số
tiền 900.000 đ, Ngày 08/09; Số khoản: 1; Tổng chuyển: 900.000 đ."*

### 2.4 Vòng lặp (`ai_edge/data/vong_lap_cong_cu.dart`)

- Cổng hiện chữ vẫn là `goi.choHienChuMoHinh` — nay đóng thêm khi có lượt rỗng. Log khi bỏ chữ ghi đủ lý do:
  *chưa có lượt thành công* · *còn lời từ chối chưa gỡ: ‹tool›* · *có lượt rỗng theo bộ lọc*.
- Nhánh `loiGoi.isEmpty && daTraCuu && !choHienChuMoHinh` (L2b hôm nay) giữ nguyên hình dạng:
  `soCauQua == 0 ? goi.mauCau().cau : goi.cauNoiThem!`. Nhãn log: **`(L2b)`** chỉ có lời từ chối · **`(L2c)`** chỉ
  có lượt rỗng · **`(L2b+L2c)`** cả hai. `hoi.sh` thêm `(L2c)` và `(L2b+L2c)` vào điều kiện dừng.
- `BiChan` chỉ xảy ra khi cổng mở → không đổi. L1, L1b, L3, L4, `BacCongCuDaTat` không đổi.
- Màn `ai_chat_page.dart` **không đổi**.

Thang lùi sau bước này: L1 · L1b · L2 · L2b · **L2c** · L3 · L4.

### 2.5 `khopTheoTen` — bậc so thứ ba (`core/utils/khop_ten.dart`)

Chỉ chạy khi hai bậc đầu trượt: **đổi `_` thành dấu cách ở cả hai vế**, chuẩn hoá lại (`normalizeCategoryName`
gom khoảng trắng) rồi so bỏ dấu.

```dart
String gachDuoi(String s) =>
    removeVietnameseTones(normalizeCategoryName(s.replaceAll('_', ' ')));
return theo((s) => s) ?? theo(removeVietnameseTones) ?? theo(gachDuoi) ?? KhongKhop<T>();
```

- `tiet_kiem` khớp *Tiết kiệm*; `tiet_kiem` khớp *Tiết kiệm* mà không khớp *Tiết kiệm mua nhà* (vẫn không so
  chuỗi con); tên thật có `_` (`vi_test`) khớp `vi_test` ở bậc 1 và khớp `vi test` ở bậc 3; hai tên thật chỉ khác
  nhau ở `_` và dấu cách → `KhopNhieu`.
- Hai chỗ gọi (`goi_y_han_muc`, `timGiaoDich`) hưởng chung, không đổi mã.

### 2.6 Câu cho người dùng của lời từ chối (`ai_edge/domain/loi_tham_so.dart`)

`tuChoiKhongKhop` và `tuChoiKhopNhieu` in tên hỏi với `_` đổi thành dấu cách trong `choNguoiDung` (*không có ví nào
tên "tiet kiem"*). `loi` cho mô hình giữ nguyên chữ nó gõ. `tenLienQuan` mang **cả hai** dạng (gõ và đã đổi), vì
câu mẫu in dạng đã đổi còn mô hình có thể chép dạng gõ. Sau mục 2.5 đường này chỉ còn tới được với tên thật sự
không có, nhưng luật (a) của spec 2b thì phải đúng ở mọi đường.

### 2.7 Trần token

Không đổi JSON, không đổi mô tả tool → `tools_json` vẫn 5.431, kết quả tool cùng độ dài. **Không** cần spike.

---

## 3. Những gì bước này KHÔNG làm

- Đổi tên `chi_tieu_theo_ky`; đổi mô tả tool hay chỉ dẫn hệ thống (kể cả để dạy mô hình thôi nhét chữ chiều tiền
  vào `tu_khoa` — đo lần 3 xong mới quyết).
- Từ chối `tu_khoa` là chữ chiều tiền (mục 1.2 hàng 4).
- Gỡ lượt rỗng khi mô hình gọi lại rộng hơn (mục 1.2 hàng 5).
- Áp `rongTheoBoLoc` cho tool khác, kể cả `goi_y_han_muc` lọc theo `danh_muc`: danh mục ở đó là tên đã khớp, 0
  hàng là sự thật về danh mục ấy.
- Nới `thamSoTen`, `laSoTien`; nâng `maxTokens`.
- Ba câu LỆCH do chọn sai tool (C1, C7, C12); B1, 1c; ĐC3 trượt tiêu chí (chữ mô hình đúng nội dung nhưng hiện ở
  lượt `chi_tieu_theo_ky`); các việc ngoài phạm vi của spec 2b mục 3.
- Ba lớp chắn, thẻ số liệu, bậc 1; giao diện, Stitch; schema v24, payload đồng bộ, `pubspec`.

---

## 4. Test

TDD từng task; ca nào xanh ngay từ đầu phải có **bản sai có chủ ý** làm nó đỏ (bài học bước 2b: ca so với chính
hằng nguồn không canh gì — đòi kết quả **độc lập**, con số hay phần tử cụ thể). Không thêm test quét; test quét 14
và 16 giữ xanh (`hang_giao_dich.dart` vẫn không so chiều tiền — chữ chiều lấy từ enum `ChieuTim`).

| Tệp | Ca chính |
|---|---|
| `hang_so_lieu_test` | ba trường mới mặc định rỗng · `soLieuBoLoc` vào `json` y như `tongHop`; `boLoc`, `rongTheoBoLoc` **không** vào `json` · `KetQuaCongCu.loi` không mang chúng |
| `hang_giao_dich_test` | **đổi** ca *"khoảng tiền đã hiểu DỘI LẠI"*: Từ/Đến ở `soLieuBoLoc`, **không** ở `tongHop` · `json` **giống hệt** bản trước (ca so map cụ thể) · `rongTheoBoLoc` đúng khi `soKhop == 0`, sai khi có khoản, không đặt ở lời từ chối · `boLoc` đủ bảy điều kiện, đúng thứ tự, bỏ mục không có, `tat_ca` và `so_tien` không in, tên danh mục / ví là **tên thật** · chuỗi tiền trong `boLoc` **bằng** `soLieuBoLoc[i].chuoi` · `tu_khoa` vào `tenLienQuan`; `tu_khoa` rỗng thì không |
| `tim_giao_dich_test` (transaction) | `tenDanhMucKhop` / `tenViKhop` đúng khi chỉ khớp một trong hai; `tenKhop` suy ra không đổi |
| `goi_so_tra_cuu_test` | ⭐ lượt rỗng theo bộ lọc **vẫn là đã tra cứu** (không rơi bậc 1) nhưng **cổng đóng** · lượt rỗng không gỡ được bằng lượt thành công sau, kể cả cùng tool điền thêm tham số · `cauLuotRong` đúng tiền tố, bỏ trùng, `null` khi không có · `cauNoiThem`: chỉ rỗng · chỉ từ chối · cả hai theo thứ tự xảy ra (hai ca: rỗng trước / từ chối trước) · `mauCau()` nhóm rỗng in tiền tố + *"không có giao dịch nào khớp."*, **không** chứa *"Số khoản: 0"* · nhóm thường in tiền tố có bộ lọc, **không** in vế `Từ:` / `Đến:` · hai lượt trùng kết quả khác bộ lọc → hai nhóm · `soLieu` của gói chứa `soLieuBoLoc` → mẫu câu và câu mô hình nhắc khoảng tiền qua `kiemSo` · tiền tố có `tu_khoa` chứa chữ số (*"T9"*) tự qua `kiemSo` và `theCuaCau` không đẻ thẻ từ "9" |
| `vong_lap_cong_cu_test` | ⭐ **L2c**: lượt `tim_giao_dich` rỗng + mô hình viết chữ → chữ **không** hiện, phát mẫu câu nêu bộ lọc, **không** phát `KhongTraCuu` · đã có câu hiện rồi mới gặp lượt rỗng → giữ câu cũ, nối `cauNoiThem` · rỗng rồi gọi lại rộng hơn có hàng → chữ vẫn không hiện, mẫu câu hai nhóm · cả từ chối lẫn rỗng → một lần nối, log `(L2b+L2c)` · tool **khác** trả 0 hàng (không đặt cờ) → chữ hiện như cũ (canh mục 1.2 hàng 6) · log mỗi nhánh đúng nhãn |
| `khop_ten_test` | ⭐ `tiet_kiem` khớp *Tiết kiệm* · không khớp *Tiết kiệm mua nhà* · tên thật có `_` khớp bậc 1 · `vi test` khớp `vi_test` · hai tên thật chỉ khác `_`/dấu cách → `KhopNhieu` · bậc 1, 2 vẫn thắng bậc 3 (hỏi `an uong`, danh sách có cả *Ăn uống* lẫn *an_uong* → `KhopMot` *Ăn uống*, không `KhopNhieu`) · docstring "ba luật" → bốn |
| `loi_tham_so_test` | `choNguoiDung` in tên đã đổi `_` thành dấu cách; `loi` giữ chữ gõ; `tenLienQuan` mang cả hai |
| `cong_cu_giao_dich_test` | đầu-cuối với repository giả: `tu_khoa` không khớp ghi chú nào → `rongTheoBoLoc`, `boLoc` đúng; `vi: "tiet_kiem"` → khớp, **không** từ chối |

Mức nền trước bước: `flutter test` **3725/3725**, 3 skip · `flutter analyze` **26** issue, **0** error. Chỗ dựng
`KetQuaCongCu(...)` bằng tay trong test không phải sửa (ba trường mới có mặc định).

---

## 5. Đo cổng D lần 3

**Điều kiện:** như spec bước 2 mục 5.1 và spec 2b mục 5 — **Realme RMX2205**, APK release, tài khoản 10, gõ bằng
`adb shell input text` không dấu (`muaxxe`, `tesst` — bẫy 4.41), chụp ô nhập trước khi gửi, logcat ra tệp. Backend
dev **không cần** chạy (app chờ `verifySession` hết timeout rồi vẫn có số). Máy ảo `FlowMoney_16G` cho đáp án.

1. **34 câu như lần 2** — nhóm A (8), nhóm B (5, gồm 1c), nhóm C (20), ĐC3; cùng chữ gõ. `hoi.sh` thêm `(L2c)`,
   `(L2b+L2c)` vào điều kiện dừng; chép bộ script sang scratchpad phiên đo và sửa `S=`.
2. **Chấm theo câu hiện ra** (`uiautomator dump`, `content-desc`), đáp án tính lại cho ngày đo bằng
   `kiem_dap_an_2b.py`. Loại chấm như lần 2, cộng loại **"mẫu câu nêu bộ lọc"** cho câu đi L2c (không ✅, không SAI;
   ghi kèm bộ lọc có khớp câu hỏi không).
3. **Ngưỡng** — như spec 2b mục 5 bước 5 (năm dòng). Riêng bước này đòi thêm: **C9 hết SAI**, C11 **không** còn đi
   L1b vì `_`, và **không câu nào** hiện *"Số khoản: 0"* từ mẫu câu.
4. **Cột phân tích:** số câu đi L2c; trong đó bao nhiêu bộ lọc **khớp** câu hỏi (C3, C4, C6 kiểu ấy) và bao nhiêu
   **lệch** (C9, C15 kiểu ấy); số câu gọi lại sau lời từ chối; số câu chọn `moi_luc`.
5. **Dưới ngưỡng** → ghi mục **9.19** `AI_EDGE_FEATURE.md`, phân tích; **chưa mở bước 3**. Dòng 3 dưới ngưỡng thì
   đòn bẩy kế tiếp vẫn là đổi tên `chi_tieu_theo_ky` — **hỏi người dùng trước**.

---

## 6. Tài liệu

- **Docstring sửa cùng task với mã:** `goi_so_tra_cuu.dart` (đầu tệp — vế *"Tool trả 0 hàng vẫn tính là đã tra
  cứu"* thêm ngoại lệ lượt rỗng theo bộ lọc; `choHienChuMoHinh` ba vế), `hang_so_lieu.dart` (ba trường mới),
  `hang_giao_dich.dart` (bộ lọc dội lại), `vong_lap_cong_cu.dart` (thang lùi thêm L2c), `khop_ten.dart` (bốn luật),
  `loi_tham_so.dart` (luật (a) áp cả giá trị mô hình gõ).
- **Task cuối:** `AI_EDGE_FEATURE.md` — mục **9.19** (bước 2c + cổng D lần 3), dòng trạng thái đầu tệp, mục 3 vị
  trí mã, bẫy 4.44 và 4.45 (✅ nếu đo đạt), bẫy mới nếu lộ ra · banner spec 2b (mục 2.2 — vế 0 hàng; luật (a)) ·
  banner spec bước 2 (mục 3.8) · `AI_AGENT_ARCHITECTURE.md` (ô bậc 2, số test) · hàng *"Đụng vào AI Edge-SLM"* của
  `CLAUDE.md` · mục 14 `PROJECT_CONTEXT.md` · bảng thứ tự đầu `…/plans/2026-09-21-ai-viec-tiep-theo.md` · banner spec
  này · nhật ký thi công của kế hoạch.
- **Lượt soát theo khái niệm:** liệt kê mọi tệp nhắc tới *0 hàng* · `daTraCuu` · `choHienChuMoHinh` · `tenKhop` ·
  `khopTheoTen` · *L2b* · *4.44* · *4.45* · *cổng D* — kể cả `docs/superpowers/backend/` — rồi mở từng tệp.

---

## 7. Phác kế hoạch (viết chi tiết bằng `writing-plans`)

1. **`khopTheoTen` bậc 3** + câu người dùng đổi `_` (mục 2.5, 2.6) — độc lập, nhỏ, làm trước.
2. **`KetQuaCongCu` ba trường** + `json` (mục 2.1).
3. **`KetQuaTimGiaoDich` tách tên khớp** (mục 2.2, chỗ ngoài `ai_edge`).
4. **`hangGiaoDich`**: cờ, `soLieuBoLoc`, `boLoc`, `tu_khoa` vào `tenLienQuan` (mục 2.2).
5. **`GoiSoTraCuu`**: `_luotRong`, cổng ba vế, tiền tố, nhóm rỗng, khoá gom, `cauLuotRong`, `cauNoiThem` (mục 2.3).
6. **Vòng lặp**: log lý do, nhãn L2c / L2b+L2c (mục 2.4).
7. **Đầu-cuối** `cong_cu_giao_dich_test`; `flutter test` + `analyze` toàn bộ.
8. **Đo cổng D lần 3** (mục 5).
9. **Tài liệu** (mục 6).
