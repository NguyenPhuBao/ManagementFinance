# Bước 2b — lời từ chối không phải dữ liệu · giá trị giữ chỗ · mô tả tool (thiết kế)

**Ngày:** 2026-09-24 · **Nhánh:** `TranQuangDat` @ `7308b85` · **Trạng thái:** ✅ **đã duyệt** 2026-09-24 — thiết
kế bốn phần và bốn câu hỏi duyệt trong chat (mục 1.2), spec duyệt cùng ngày. Kế hoạch 10 task:
`docs/superpowers/plans/2026-09-24-buoc-2b-tu-choi-giu-cho-mo-ta-tool.md` (gitignore) — ✅ **mã xong 2026-09-24**
(`5357209` → `e0e4a98`, thi công inline một phiên; nhật ký cuối tệp kế hoạch); kế hoạch lệch spec **bảy** chỗ có
chủ ý, ghi kèm lý do ở đầu tệp kế hoạch (đáng nhớ nhất: `them(…)` nhận `args` bằng tham số có tên mặc định rỗng,
không phải tham số vị trí như mục 2.2; mười task thay vì chín).
🛑 **Cổng D lần 2 CHƯA ĐẠT** (Realme 2026-09-24, mục **9.18** `docs/AI_EDGE_FEATURE.md`): mục 1.1 lỗi 1 và 2 (mã)
**chữa trúng** — năm câu SAI của lần 1 hết SAI, L1b chạy thật; lỗi 3 (mô tả tool) **không** — nhóm C tụt còn
**10/20 tool · 4/20 tham số**. Lộ một cơ chế SAI **mới** ngoài phạm vi spec này: tham số thừa làm hẹp bộ lọc → lượt
**thành công** 0 hàng → mẫu câu *"Số khoản: 0"* (C9, bẫy **4.44**); và tên `snake_case` (`vi: "tiet_kiem"`,
bẫy **4.45**) — luật (a) mục 2.1 *"không có dấu `_`"* không lường giá trị do mô hình gõ. Spike trần token (mục
2.7): `tools_json` **5.431** ký tự, 0 vỡ trần. Theo mục 5 bước 7: đòn bẩy kế tiếp (mục 1.2 hàng 10 — đổi tên
`chi_tieu_theo_ky`) **chờ người dùng quyết**.
> ⚠️ **Chỗ thi công KHÁC spec, ngoài bảy chỗ của kế hoạch:** ca `bo_cong_cu_test` *"chi_tieu_theo_ky giữ TÁM
> mã"* (mục 4) của kế hoạch so `enum` với chính `kMaKy.keys` nên không bắt được bản sai đưa `moi_luc` vào bảng
> chung — ca nay đòi đúng 8 mã và không có `moi_luc`.
**Đầu vào:** cổng D lần đo 1 — mục **9.17** `docs/AI_EDGE_FEATURE.md`, bẫy **4.40**, **4.42**, **4.43**; spec bước 2
`2026-09-23-buoc-2-ba-tool-doc-tim-giao-dich-design.md` (mục 3.8, 3.9, 5); spec 4b
`2026-09-23-chang-4b-tool-calling-vong-lap-design.md` (mục 3.6 — chốt L1).
**Khung cố định:** bốn bất biến mục 6 `docs/AI_AGENT_ARCHITECTURE.md` (① lớp AI không tính · ② tool trả hàng ·
③ luôn có đường lùi · ④ không tool nào ghi) — **không đổi**. Ba lớp chắn (`kiemSo` · `kiemNhan` · `kiemGiong`), thẻ
số liệu, bậc 1, `maxTokens` 4096 — **không đổi**.

> "Bước 2b" là vòng sửa của bước 2 trước khi đo lại cổng D. Bước 3 (chiều ghi) **chưa mở** cho tới khi cổng D đạt.

---

## 1. Vì sao

### 1.1 Ba lỗi của cổng D lần 1 mà spec này sửa

| # | Lỗi | Đo được (mục 9.17) | Bẫy |
|---|---|---|---|
| 1 | **Lời từ chối của tool bị đọc thành "không có dữ liệu"**, ở hai tầng: **mô hình** (C11, C12, spike S3 — câu không chứa số nên lọt cả ba lớp chắn) và **mẫu câu của app** (C8 — `GoiSoTraCuu.mauCau()` in *"Không tìm thấy dữ liệu khớp câu hỏi."* khi mọi lượt rỗng hàng và rỗng tổng hợp, mà lượt bị từ chối cũng rỗng như thế) | 3 trong 5 câu SAI | 4.40 |
| 2 | **Giá trị giữ chỗ trong tham số tuỳ chọn** (`danh_muc: "tat_ca"`, `vi: "tất_cả"`) và **số tiền nhét vào `tu_khoa`** | 5/20 câu nhóm C hỏng tham số vì kiểu này | 4.43 |
| 3 | **Chọn sai tool, thiếu tham số**: 7/20 câu sai tool — 6 gọi `chi_tieu_theo_ky` thay `tim_giao_dich` (C1, C7, C10, C13, C14, C18), 1 gọi `danh_sach_muc_tieu` (C20); thiếu `ky` (C4, C8); thiếu `so_tien_tu` (C6, C8, C9); `danh_muc` thừa hoặc gộp cả cụm câu (C11, C19); B2 gọi `goi_y_han_muc` cho một câu về mục tiêu | nhóm C 13/20 tool · 5/20 tham số | spec bước 2 mục 5.5 |

Lỗi 1 và 2 là lỗi **mã**; lỗi 3 là **mô tả tool**. Bẫy 4.42 (mệnh đề sai trên tên thật, số thật) chỉ được sửa gián
tiếp ở chỗ C7 — gọi đúng `tim_giao_dich` thì câu có hàng thật để dựa vào; ca A3 của bẫy ấy nằm ngoài spec (mục 3).

### 1.2 Quyết định đã chốt (2026-09-24, không hỏi lại)

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Hướng sửa sau cổng D | **Sửa lỗi mã trước, rồi chỉnh mô tả**; viết một spec ngắn trước |
| 2 | Mọi lời gọi tool của một câu hỏi đều bị từ chối | **Mẫu câu trung thực**, không gọi thêm lượt sinh nào — **không** rơi về bậc 1. Sáu gói của bậc 1 không có hàng giao dịch nào, nên với câu hỏi về từng giao dịch, bậc 1 ra câu lệch hoặc *"không có số liệu"*, và người dùng đọc thành *"không có giao dịch"*; lại tốn thêm ~20 s trên Realme |
| 3 | Ca **lẫn** — có lượt thành công, có lượt bị từ chối | **Chặt**: còn lời từ chối **chưa gỡ** thì chữ của mô hình không được hiện; app hiện mẫu câu của các lượt thành công, kèm một câu trung thực về phần chưa tra được |
| 4 | Khi nào một lời từ chối **đã gỡ** | **Theo tham số**: lời từ chối về tham số P được gỡ khi một lượt **thành công** sau đó của **cùng tool** vẫn **điền** P (mục 2.2 — giá trị giữ chỗ không tính là điền). Riêng số tiền nằm trong `tu_khoa`: gỡ khi lượt sau điền `so_tien_tu` hoặc `so_tien_den`. Gọi lại bằng cách **bỏ** P vẫn là chưa gỡ — chặn đường *"bỏ bộ lọc, lấy kết quả rộng hơn, rồi nói như thể trả lời câu hỏi hẹp"* (hỏi danh mục *"abc"* không tồn tại, nhận về mọi khoản chi) |
| 5 | Tham số `ky` của `tim_giao_dich` | **Bắt buộc**, thêm mã **`moi_luc`** (mọi thời gian) **chỉ cho `tim_giao_dich`** — `chi_tieu_theo_ky` giữ tám mã; câu không nêu kỳ thì dùng `moi_luc` |
| 6 | Câu nói với người dùng lấy từ đâu | Mỗi lời từ chối **mang thêm một câu cho người dùng**, dựng cùng chỗ với câu cho mô hình (`loi_tham_so.dart`), nên hai câu không lệch nhau. Không suy ngược từ chuỗi `loi` (giòn), không dùng một câu chung chung (người dùng không biết sửa câu hỏi thế nào) |
| 7 | Giá trị giữ chỗ xử lý ở đâu | Tầng tool — `ai_edge/domain/tham_so_mo_hinh.dart`, chạy **trước** bước khớp tên. **Không** ở `khopTheoTen` (hàm khớp tên dùng chung ở `core/utils`; *"tất cả = không lọc"* là quy ước giữa app và mô hình, không phải luật so tên), **không** ở `timGiaoDich` (`goi_y_han_muc` cũng cần) |
| 8 | Mô tả tool | Như mục 2.6 — gồm cả ba dòng ngoài C1–C20: `danh_sach_muc_tieu` (C20), `goi_y_han_muc` (B2), và một câu trong chỉ dẫn hệ thống |
| 9 | Trần token | **Không** nâng `maxTokens` (RAM đã vượt ngưỡng 0,5 GB một lần, người dùng duyệt đích danh); mô tả mới vượt trần thì **rút gọn mô tả** |
| 10 | Đổi tên `chi_tieu_theo_ky` thành một tên nói rõ "tổng" (ví dụ `tong_chi_theo_ky`) | **Để dành** — làm cùng lúc với sửa mô tả thì không biết thay đổi nào có tác dụng, và nhật ký các buổi đo cũ khó đối chiếu. Chỉ dùng khi lần đo này vẫn dưới 18/20, và **hỏi người dùng trước** |

### 1.3 Hai điều định hình thiết kế

**E2B không gọi lại sau khi bị từ chối.** Theo bảng 9.17, không câu nào có lượt gọi lại thành công sau một lời từ
chối — C6, C8, C11, C12, C19, B2 và spike S3 đều viết chữ ngay, dù lời từ chối đã kèm tên đúng. Nên *"mọi lời gọi
đều bị từ chối"* là **kết cục thường** của một lời từ chối, không phải ca hiếm; và bớt được lời từ chối (mục 2.4,
2.6) quan trọng ngang việc xử lý lời từ chối (mục 2.1–2.3).

**Chốt L1 của spec 4b đúng một nửa.** Mục 3.6 spec 4b và docstring `goi_so_tra_cuu.dart` viết: *"Tool trả 0 hàng
(hay từ chối tham số) vẫn tính là đã chạy: mô hình đã có dữ liệu thật trước mắt, dù dữ liệu ấy là 'không có
gì'."* Vế **0 hàng** đúng — 0 hàng thật là dữ liệu thật. Vế **từ chối** sai: lời từ chối không phải dữ liệu nói
*"không có gì"* mà là *"câu hỏi gửi tới tool bị hỏng"*, và E2B đọc nó như vế trước. Spec này **lật đúng vế ấy**.

---

## 2. Thiết kế

### 2.1 Lời từ chối mang câu cho người dùng

`KetQuaCongCu` (`ai_edge/domain/hang_so_lieu.dart`) thêm hai trường, chỉ có nghĩa khi `loi != null`:

```dart
final String? choNguoiDung;     // câu cho người dùng — mục dưới
final List<String> thamSoGo;    // tham số mà một lượt thành công sau đó phải điền để gỡ (mục 2.2)

const KetQuaCongCu.loi(String vi, {
  required String choNguoiDung,
  required List<String> thamSoGo,
  List<String> tenLienQuan = const [],
});
```

`json` **không đổi** — mô hình chỉ thấy `loi` như hôm nay. Hai trường mới đều **bắt buộc** ở hàm dựng: chỗ nào dựng
lời từ chối cũng phải nghĩ tới câu cho người dùng.

**`loi_tham_so.dart` là chỗ duy nhất dựng lời từ chối.** Mỗi hàm của nó trả `KetQuaCongCu` mang đủ `loi` (câu cho
mô hình — giữ nguyên nội dung hôm nay), `choNguoiDung`, `thamSoGo` và `tenLienQuan`. **13** lời gọi tạo lời từ chối
ở **6** tệp chuyển sang gọi các hàm ấy (đếm bằng máy 2026-09-24: `cong_cu_chi_tieu` 1 · `cong_cu_giao_dich` 6 ·
`cong_cu_goi_y_han_muc` 2 · `hang_chi_tieu` 1 · `hang_giao_dich` 2 · `hang_hoa_don` 1).

| Loại từ chối | `choNguoiDung` | `thamSoGo` |
|---|---|---|
| tên không khớp | `không có danh mục nào tên "‹hỏi›"` · `không có ví nào tên "‹hỏi›"` · riêng `goi_y_han_muc`: `không có danh mục chi nào tên "‹hỏi›"` | `[P]` |
| tên khớp nhiều mục | `tên "‹hỏi›" khớp nhiều ‹danh mục / ví / danh mục chi›: A, B` | `[P]` |
| kỳ sai hoặc thiếu (`ky`) | `chưa hiểu khoảng thời gian trong câu hỏi` | `[ky]` |
| chiều tiền sai (`chieu`) | `chưa hiểu loại giao dịch` | `[chieu]` |
| cách xếp sai (`sap_xep`) | `chưa hiểu cách sắp xếp` | `[sap_xep]` |
| trạng thái hoá đơn sai (`trang_thai`) | `chưa hiểu trạng thái hoá đơn` | `[trang_thai]` |
| số tiền sai (`so_tien_tu`, `so_tien_den`) | `chưa hiểu số tiền trong câu hỏi` | `[P]` |
| khoảng tiền ngược | `khoảng số tiền bị ngược` | `[so_tien_tu, so_tien_den]` |
| số tiền nằm trong `tu_khoa` (mục 2.4) | `chưa hiểu số tiền trong câu hỏi` | `[so_tien_tu, so_tien_den]` |

Ba luật cho `choNguoiDung`: (a) không lộ mã tham số (không có dấu `_`); (b) không chép con số nào từ tham số của
mô hình — chỉ nhắc lại **tên** (`‹hỏi›`); (c) không khẳng định gì về **giao dịch hay dữ liệu** (*"không có giao
dịch"*, *"không tìm thấy dữ liệu"*) — chỉ nói về **câu hỏi** hoặc về **tên**.

Tên sai `‹hỏi›` vào `tenLienQuan` của lời từ chối (cùng danh sách tên thật như hôm nay) → vào
`GoiSoTraCuu.tenDoiTuong` → chữ số trong tên sai không bị bộ kiểm hay thẻ số liệu đọc thành con số (bước 1c).

### 2.2 `GoiSoTraCuu` — thành công, từ chối, từ chối chưa gỡ

```dart
void them(String tenCongCu, Map<String, dynamic> args, KetQuaCongCu kq);  // thêm args
bool get daTraCuu;                       // ≥ 1 lượt THÀNH CÔNG (kq.loi == null) — nghĩa MỚI
List<({String ten, KetQuaCongCu kq})> get tuChoiChuaGo;  // theo thứ tự xảy ra; tên tool cho log
bool get choHienChuMoHinh;               // daTraCuu && tuChoiChuaGo.isEmpty
String? get cauChuaTraDuoc;              // 'Chưa tra được phần còn lại: ‹lý do›.' — null khi không còn gì chưa gỡ
NhanXet mauCau();                        // ba trạng thái, dưới
```

- **Lượt bị từ chối**: ghi `(tên tool, kq)` vào danh sách chưa gỡ, gom `tenLienQuan`; **không** vào
  `tenCongCuDaChay`, hàng hay tổng hợp.
- **Lượt thành công**: như hôm nay, rồi **gỡ** mọi lời từ chối **trước đó** của **cùng tool** mà `thamSoGo` có ít
  nhất một tham số được `args` **điền**. *Điền* = `thamSoTen(args[P]) != null` (mục 2.4) — có giá trị thật, không
  trống, không phải giá trị giữ chỗ. Một định nghĩa cho mọi loại tham số: gọi lại với `chieu: "tat_ca"` sau khi
  `chieu` bị từ chối là **mở rộng** câu hỏi, và được tính như bỏ trống.
- `thieuDuLieu` giữ nguyên chữ (`!daTraCuu`), đổi nghĩa theo `daTraCuu`.

**`mauCau()` — ba trạng thái:**

| Trạng thái | Câu |
|---|---|
| chưa lượt nào thành công, không có lời từ chối | *"Chưa tra cứu được số liệu nào."* — như hôm nay; chỉ còn tới được qua L3 khi mọi lời gọi là tool bịa tên |
| chưa lượt nào thành công, có lời từ chối | *"Chưa tra được số liệu cho câu này: ‹lý do›. Bạn thử hỏi lại cụ thể hơn."* — `theSoLieu` rỗng, mức `thieuDuLieu` |
| có lượt thành công | mẫu câu dữ liệu như hôm nay, **nối thêm** `cauChuaTraDuoc` khi còn lời từ chối chưa gỡ. Câu *"Không tìm thấy dữ liệu khớp câu hỏi."* chỉ còn khi mọi lượt **thành công** đều rỗng — lúc ấy nó đúng nghĩa |

‹lý do› = `choNguoiDung` của các lời từ chối chưa gỡ, theo thứ tự, bỏ bản trùng, nối bằng `; `.

### 2.3 Vòng lặp (`ai_edge/data/vong_lap_cong_cu.dart`)

- **Cổng hiện chữ**: `goi.choHienChuMoHinh` thay `goi.daTraCuu` (dòng 86 hôm nay). Cổng đóng thì chữ bị bỏ và chỉ
  ghi log, kèm lý do: *chưa có lượt thành công* hoặc *còn lời từ chối chưa gỡ: ‹tên tool›*.
- `goi.them(g.ten, g.args, kq)` — vòng lặp có sẵn `g.args`.
- **Mô hình ngừng gọi tool** (`loiGoi.isEmpty`):

| Trạng thái | Phát | Nhánh |
|---|---|---|
| chưa lượt nào thành công, không có lời từ chối | `KhongTraCuu` → bậc 1 | L1 — không đổi |
| chưa lượt nào thành công, có lời từ chối | `CauQua(goi.mauCau().cau)` — mẫu câu trung thực | **L1b** (mới) |
| có thành công, còn lời từ chối chưa gỡ, **chưa** câu nào hiện | `CauQua(goi.mauCau().cau)` — dữ liệu + câu chưa tra được | **L2b** (mới) |
| như trên, **đã có** câu hiện | `CauQua(goi.cauChuaTraDuoc!)` — nối sau các câu đã hiện | **L2b** |
| có thành công, không còn lời từ chối chưa gỡ | như hôm nay (L2 khi chưa câu nào hiện) | L2 — không đổi |

- `BiChan` chỉ xảy ra khi cổng mở, nên nhánh ấy không đổi. L3 gọi `mauCau()`, nên tự theo ba trạng thái của mục
  2.2. L4 và `BacCongCuDaTat` không đổi.
- Log một dòng cho mỗi lần đi L1b, L2b (dùng `print`, bẫy 8.6).
- Màn `ai_chat_page.dart` **không đổi**: nó hiện mọi `CauQua`, và thẻ số liệu dựng từ `goi` — với L1b gói không
  có số nào nên không có thẻ.

### 2.4 Tham số do mô hình sinh (`ai_edge/domain/tham_so_mo_hinh.dart`, tệp mới)

- **`String? thamSoTen(Object? v)`** — `null` (**không lọc**) khi `v` là `null` hay `v.toString()` trống sau khi cắt
  khoảng trắng (nhận cả số — phép *điền* của mục 2.2 dùng nó cho mọi tham số), hoặc khi nó là **giá trị giữ chỗ**:
  chuẩn hoá bằng `normalizeCategoryName` sau khi đổi `_` thành dấu cách, bỏ dấu bằng `removeVietnameseTones`, rồi
  trùng **đúng** một trong `tat ca` · `tatca` · `all`. Còn lại trả giá trị đã cắt khoảng trắng — việc khớp tên vẫn
  là của `khopTheoTen`. Bỏ dấu ở đây là đúng chỗ của `removeVietnameseTones` (đọc tham số, không phải quy tắc trùng
  tên — quy tắc 7 `CLAUDE.md`).
- **`bool laSoTien(String s)`** — `true` khi chuỗi (đã chữ thường, bỏ dấu) chứa một con số kèm đơn vị tiền
  (`k` · `nghin` · `ngan` · `tr` · `trieu` · `cu` · `d` · `dong` · `vnd`, đứng trọn từ), **hoặc** chỉ gồm chữ số,
  dấu ngăn `.` `,` và khoảng trắng, **hoặc** chứa *"nua trieu"*.
  `true`: `500k` · `500 k` · `1 triệu` · `1tr` · `5 củ` · `200.000đ` · `1.000.000` · `1000000` · `trên 500k` ·
  `nửa triệu`. `false`: `hoa don` · `muaxe` · `T9` · `di h0c` · `test1` · `2026-09-04` · `2 kg`.

| Tool | Tham số | Xử lý |
|---|---|---|
| `tim_giao_dich` | `danh_muc`, `vi`, `tu_khoa` | qua `thamSoTen` — giá trị giữ chỗ nghĩa là không lọc |
| `tim_giao_dich` | `tu_khoa` mà `laSoTien` | **từ chối trước khi đọc dữ liệu**. `loi`: *`tu_khoa "‹v›" là số tiền — tu_khoa chỉ tìm chữ trong ghi chú; số tiền dùng so_tien_tu / so_tien_den, số đồng, ví dụ 500000.`* `choNguoiDung` và `thamSoGo` như bảng mục 2.1 |
| `goi_y_han_muc` | `danh_muc` | qua `thamSoTen` |

Từ chối chứ không tự dời số tiền sang `so_tien_tu`: đọc được *"500k"* là việc của mô hình và chính là thứ phép
đo chấm (spec bước 2 mục 1.2 hàng 9). Để nguyên thì nguy hiểm hơn: tìm *"500k"* trong ghi chú ra 0 khoản, đó là
một lượt **thành công**, và mô hình được phép nói *"không có khoản nào"* dù thực tế có.

Thứ tự kiểm ở adapter `tim_giao_dich`: `ky` → `chieu` → `sap_xep` → `so_tien_tu` → `so_tien_den` → khoảng →
`tu_khoa` → đọc dữ liệu → `timGiaoDich` (khớp tên). Mọi tham số vẫn kiểm **trước** khi đọc dữ liệu.

**Giới hạn cố ý:** một danh mục hay ví đặt tên đúng *"Tất cả"* không lọc được qua tool; ghi chú có từ khoá kiểu
*"5k"* (*"gửi xe 5k"*) bị từ chối; chuỗi dài như *"tất cả danh mục"* **không** là giữ chỗ — vẫn bị từ chối, và việc
ngăn mô hình viết như thế là của mô tả tool (mục 2.6). Cố ý không nới thêm (`mọi`, `bất kỳ`): chưa đo được mô hình
viết những chữ ấy, và *"mọi"* bỏ dấu trùng *"mới"*.

### 2.5 `ky` bắt buộc và `moi_luc`

- `hang_chi_tieu.dart`: thêm `kMaKyMoiLuc = 'moi_luc'` và `kChuKyMoiLuc = 'mọi thời gian'` cạnh `kMaKy`. `kMaKy`
  giữ **tám** mã và vẫn là bảng duy nhất của các mã kỳ **chung**; `moi_luc` là mã **riêng** của `tim_giao_dich`,
  docstring nói rõ.
- `tim_giao_dich`: schema thêm `'required': ['ky']`; enum `[...kMaKy.keys, kMaKyMoiLuc]`. Adapter: `ky` trống hoặc
  thiếu → **từ chối** (`chưa hiểu khoảng thời gian trong câu hỏi`), giống `chi_tieu_theo_ky` hôm nay — không tự
  mặc định *tháng này*. `moi_luc` → đọc `watchKhoang(idaccount, DateTime(1970), đầu ngày mai)`; khoản ghi ngày tương
  lai vẫn bị `timGiaoDich` bỏ (spec bước 2 mục 1.2 hàng 11). Chữ kỳ `kChuKyMoiLuc` — không có chữ số.
- `chi_tieu_theo_ky`: enum giữ tám mã; nhận `moi_luc` thì `kyTuMa` trả `null` → từ chối như mọi mã lạ.

### 2.6 Mô tả tool và chỉ dẫn hệ thống

Mọi mô tả giữ cụm **"Gọi khi"** (`bo_cong_cu_test`). Văn bản dưới đây là bản đã duyệt; kế hoạch chép nguyên.

**`tim_giao_dich`** — mô tả:
> Liệt kê TỪNG giao dịch (ghi chú, số tiền, ngày, danh mục, ví) kèm tổng của mọi khoản khớp. Gọi khi hỏi đã tiêu
> gì, chi gì, những khoản nào, khoản thu nào, khoản lớn nhất, khoản trên hay dưới một số tiền, chi từ ví nào, chi
> cho danh mục nào, chuyển tiền sang ví nào, lần gần nhất hay lần cuối là khi nào, tìm theo ghi chú. Chỉ hỏi tổng
> chi, tổng thu của một kỳ thì dùng chi_tieu_theo_ky.

| Tham số | Mô tả |
|---|---|
| `ky` (bắt buộc) | ‹tám mã `mã = chữ`, nối bằng `; `›; moi_luc = mọi thời gian. Câu nêu kỳ nào thì chọn đúng kỳ ấy; câu không nêu kỳ (lần gần nhất, lần cuối, gần đây, tìm theo ghi chú) thì chọn moi_luc. |
| `chieu` | khoan_chi: khoản chi (hỏi tiêu, chi, mua); khoan_thu: khoản thu (hỏi thu, nhận, lương); chuyen_vi: chuyển giữa hai ví; tat_ca: mọi loại (mặc định). |
| `so_tien_tu` | Số đồng tối thiểu. Câu có "trên", "hơn", "từ … trở lên" kèm số tiền thì PHẢI điền. Đổi ra số đồng: 500k = 500000, nửa triệu = 500000, 1 triệu = 1000000. |
| `so_tien_den` | Số đồng tối đa. Câu có "dưới", "không quá", "đến" kèm số tiền thì PHẢI điền. |
| `danh_muc` | Tên MỘT danh mục, chỉ khi câu hỏi nêu tên danh mục. Không nêu thì BỎ TRỐNG, không điền "tất cả". Tên ví điền vào vi. |
| `vi` | Tên MỘT ví, chỉ khi câu hỏi nêu tên ví. Không nêu thì BỎ TRỐNG, không điền "tất cả". |
| `tu_khoa` | Chữ cần tìm trong GHI CHÚ, ví dụ tên hoá đơn, tên mục tiêu. Không điền số tiền, tên danh mục hay tên ví. |
| `sap_xep` | so_tien: lớn nhất trước (mặc định), dùng khi hỏi khoản lớn nhất; moi_nhat: mới nhất trước, dùng khi hỏi lần gần nhất, lần cuối, gần đây. |

**`chi_tieu_theo_ky`** — mô tả (bỏ danh sách kỳ, vì enum đã có):
> Tổng chi, tổng thu và tổng chi theo từng DANH MỤC (có tên) của một kỳ — chỉ có TỔNG, không liệt kê từng khoản.
> Gọi khi hỏi tiêu bao nhiêu trong một kỳ, hoặc danh mục nào chi nhiều nhất. Hỏi tiêu gì, những khoản nào, khoản
> thu nào, khoản lớn nhất, khoản của một ví, trên hay dưới một số tiền thì dùng tim_giao_dich.

**`danh_sach_muc_tieu`** — nối thêm vào mô tả hôm nay (C20):
> Không có lịch sử từng lần nạp: hỏi lần nạp gần nhất thì dùng tim_giao_dich với tu_khoa là tên mục tiêu.

**`goi_y_han_muc`** — nối thêm vào mô tả hôm nay (B2):
> Chỉ dành cho danh mục CHI; hỏi cần để dành bao nhiêu cho một mục tiêu thì dùng danh_sach_muc_tieu.

và tham số `danh_muc`: *"Tên một danh mục chi. Bỏ trống để xem mọi danh mục, không điền "tất cả"."*

**`kPromptHeThongCongCu`** (`slm_prompt.dart`) — thêm một câu, đặt ngay sau câu *"…hãy gọi công cụ phù hợp TRƯỚC khi
trả lời."*:
> Công cụ trả "loi" thì gọi lại ngay với tham số đúng theo lời ấy, chưa trả lời.

Câu không có chữ số — ca test *"prompt hệ thống không chứa chữ số nào ngoài 60"* (`slm_prompt_test`) giữ xanh. Nếu
câu này làm E2B gọi lại nhiều hơn thì luật gỡ theo tham số (mục 1.2 hàng 4) là thứ giữ cho lần gọi lại **bỏ** bộ
lọc không thành một câu SAI.

⚠️ **Test quét 14** (`ai_edge_khong_tinh_test.dart`) cấm chuỗi `'chi'` và `'thu'` đứng trần trong `ai_edge/`.
Mô tả mới có chữ *chi*, *thu* rời; cắt chuỗi Dart sao cho không đoạn nào là đúng `'chi'` hay `'thu'`.

### 2.7 Trần token (bẫy 4.39)

Mô tả mới dài thêm chừng 1.000 ký tự, nên `tools_json` lên chừng 5.400 ký tự (bảy khai báo hôm nay: **4.393**), trên
trần **tổng** 4.096 token.

- **Một định nghĩa**: `String toolsJsonCua(List<KhaiBaoCongCu>)` ở `ai_edge/domain/cong_cu.dart` — chính chuỗi mà
  `slm_runtime.dart` đang dựng tại chỗ để đo (dòng 204–214 hôm nay); runtime gọi lại hàm ấy.
- **Test chặn độ dài**: `bo_cong_cu_test` — `toolsJsonCua(bảy khai báo).length ≤ kTranToolsJsonDaDo`, với con số chốt
  bằng spike Realme và `reason` dặn: *dài hơn thì đo lại phiên dài nhất trên máy (bẫy 4.39) rồi mới nâng số này*.
- **Spike trước buổi đo**: ba câu S1, S2, S3 của spike bước 2 (nhật ký thi công kế hoạch bước 2) với mô tả mới, APK
  release, Realme. Không được có `FAILED_PRECONDITION` (chuỗi lỗi của bẫy 4.39, **không** phải `too long`). Vượt
  trần thì rút gọn mô tả — bắt đầu từ ví dụ trong mô tả tham số — **không** nâng `maxTokens` (mục 1.2 hàng 9).

---

## 3. Những gì bước này KHÔNG làm

- Đổi tên `chi_tieu_theo_ky` — để dành (mục 1.2 hàng 10).
- Nâng `maxTokens`; đo lại RAM (chỉ đo khi `maxTokens` đổi).
- Nới giá trị giữ chỗ (`mọi`, `bất kỳ`, *"tất cả danh mục"*); dịch `ky: "tat_ca"` thành `moi_luc`.
- Tự dời số tiền từ `tu_khoa` sang `so_tien_*`; bảng quy đổi *k / củ* trong mã (bước 3).
- Mã `moi_luc` cho `chi_tieu_theo_ky`.
- Bốn việc ngoài phạm vi, chưa ai chọn: câu A3 xếp cả bốn ngân sách vào *"sắp hết"* (ca thứ hai của bẫy 4.42); mẫu
  câu L2 của `tim_giao_dich` khó đọc, lặp tên danh mục khi dòng không có ghi chú; vượt trần thì màn báo *"Mô hình
  trên máy không chạy được"* dù tool đã chạy xong; OnePlus 13R chưa đo ở 4096.
- Hai việc *"chờ người dùng gọi tên"* của bảng thứ tự: rút ngắn câu chào ~23 s trên Realme; dạy trợ lý nói *"không
  có dữ liệu"* ở ĐC1.
- Ba lớp chắn, thẻ số liệu, bậc 1; khối giao diện mới, Stitch (mẫu câu hiện trong bong bóng chat có sẵn — tiền lệ
  spec bước 2 mục 1.2 hàng 10); schema v24, payload đồng bộ, `pubspec`.

---

## 4. Test

TDD từng task; ca nào xanh ngay từ đầu phải có **bản sai có chủ ý** làm nó đỏ. Không thêm test quét; test quét 14
và 16 giữ xanh.

| Tệp | Ca chính |
|---|---|
| `goi_so_tra_cuu_test` | **lật** ca *"tool từ chối tham số cũng là đã chạy"* (dòng 60) · mọi lượt từ chối → mẫu câu trung thực: đúng lý do, **không** chứa *"Không tìm thấy"*, không thẻ số liệu, mức `thieuDuLieu` · lẫn, còn từ chối chưa gỡ → dữ liệu + *"Chưa tra được phần còn lại…"* · **gỡ theo tham số**: cùng tool thành công mà **điền** P → gỡ; **bỏ** P → chưa gỡ; điền P bằng giá trị giữ chỗ → chưa gỡ; tool **khác** thành công → chưa gỡ · số tiền trong `tu_khoa` gỡ bằng `so_tien_tu` · lý do trùng → bỏ bản trùng · tên sai có chữ số không đẻ ra thẻ số liệu |
| `vong_lap_cong_cu_test` | **lật** ca *"tool từ chối tham số lạ vẫn là ĐÃ tra cứu"* (dòng 212) · mọi lượt từ chối + mô hình viết chữ → chữ **không** hiện, phát mẫu câu trung thực, **không** phát `KhongTraCuu` (L1b) · lẫn → mẫu câu + câu chưa tra được (L2b) · câu đã hiện rồi mới bị từ chối → giữ câu cũ, nối câu chưa tra được · gọi lại **điền** đúng tham số → chữ viết sau đó được hiện · gọi lại **bỏ** tham số → chữ không hiện (ca *"abc"*) · L1 (chưa gọi tool nào) và L3 giữ như cũ · `them` nhận đúng `args` của lời gọi |
| `loi_tham_so_test` | mỗi loại trong bảng mục 2.1 trả đủ `loi` · `choNguoiDung` · `thamSoGo` · `tenLienQuan` · câu cho người dùng không có `_`, không chép số từ tham số, không chứa *"không có giao dịch"* / *"không tìm thấy dữ liệu"* |
| `hang_chi_tieu_test`, `hang_hoa_don_test`, `hang_giao_dich_test` | lời từ chối mang câu cho người dùng và `thamSoGo` đúng |
| `tham_so_mo_hinh_test` (mới) | bảng đúng/sai của `thamSoTen` và `laSoTien` (mục 2.4) |
| `cong_cu_giao_dich_test` | giữ chỗ ở `danh_muc` / `vi` / `tu_khoa` → kết quả **giống hệt** không truyền · `tu_khoa` là số tiền → từ chối, **không** đọc repository · thiếu `ky` → từ chối · `moi_luc` → `watchKhoang` từ 1970, chữ kỳ *"mọi thời gian"* |
| `cong_cu_goi_y_han_muc_test` | giữ chỗ ở `danh_muc` → mọi danh mục |
| `bo_cong_cu_test` | `tim_giao_dich` bắt buộc `ky`, enum có `moi_luc` · `chi_tieu_theo_ky` đúng tám mã, nhận `moi_luc` thì từ chối · `toolsJsonCua(...).length ≤ kTranToolsJsonDaDo` |
| `slm_prompt_test` | ca chữ số của prompt hệ thống giữ xanh với câu mới |

Mức nền trước bước: `flutter test` **3684/3684**, 3 skip · `flutter analyze` **26** issue, **0** error. Ba tệp
test đang dựng `KetQuaCongCu.loi('…')` trần (`goi_so_tra_cuu_test`, `vong_lap_cong_cu_test`, `hang_so_lieu_test` —
4 chỗ, đếm 2026-09-24) phải thêm hai tham số bắt buộc — đổi cơ học, không đổi ý của ca. Hai tệp gọi thẳng hàm dựng
lời từ chối (`loi_tham_so_test` 3 chỗ, `hang_chi_tieu_test` 1 chỗ) đổi theo chữ ký mới của `loi_tham_so.dart`.

---

## 5. Đo cổng D lần 2

**Điều kiện:** như spec bước 2 mục 5.1 — **Realme RMX2205 bắt buộc** (CPU; ngưỡng chấm trên máy này), APK release,
tài khoản 10, gõ bằng `adb shell input text` không dấu, `muaxe` gõ `muaxxe`, `test` gõ `tesst` (bẫy 4.41), chụp ô
nhập trước khi gửi, logcat ghi thẳng ra tệp. OnePlus 13R nếu cắm được — ghi thêm, không chấm ngưỡng.

1. **Spike trần token trước** (mục 2.7) — chốt con số của test chặn độ dài.
2. **33 câu như lần 1** — nhóm A (8), nhóm B (5, gồm câu 1c), nhóm C (20); đúng chữ gõ của spec bước 2 mục 5.2–5.4.
3. **Một câu đối chứng mới — ĐC3**: `cac khoan chi cho danh muc abc thang nay`. Đạt khi màn hiện mẫu câu trung thực
   nêu *"abc"* (L1b), hoặc dữ liệu kèm câu chưa tra được nếu mô hình gọi lại bằng cách bỏ `danh_muc` (L2b). **SAI**
   nếu chữ của mô hình được hiện.
4. **Chấm theo câu hiện ra** — bản ghi nguyên văn bằng `uiautomator dump` (câu trả lời kèm thẻ ở `content-desc`),
   đáp án tính lại cho **ngày đo**. Loại chấm: ✅ · mẫu câu có ích · **mẫu câu trung thực** (mới — không ✅, không
   SAI) · mẫu câu lệch · LỆCH · SAI.
5. **Ngưỡng** — như spec bước 2 mục 5.5, cộng ĐC3 không SAI:
   1. nhóm A không tụt (mục 5.2 spec bước 2);
   2. nhóm B ≥ 3/4, câu 1c được hiện;
   3. nhóm C **≥ 18/20** đúng tool · **≥ 16/20** đúng mọi tham số bắt buộc — chấm theo lời gọi **đầu tiên**, cùng
      đáp án tham số với lần 1 (`ky` vẫn là *tuỳ* với câu không nêu kỳ) để hai lần so được với nhau;
   4. **SAI = 0** trên cả ba nhóm và ĐC3; **0** sập;
   5. không phiên nào vỡ trần (`FAILED_PRECONDITION` hay `too long`).
6. **Cột phân tích** (không chấm ngưỡng): số câu có lượt gọi lại sau lời từ chối; số câu chọn `moi_luc`; số câu
   thiếu `ky` (tức đi L1b vì `ky`); số câu đi L1b / L2b.
7. **Dưới ngưỡng** → ghi bảng, phân tích; **chưa mở bước 3**. Dòng 3 dưới ngưỡng thì đòn bẩy kế tiếp là đổi tên
   `chi_tieu_theo_ky` (mục 1.2 hàng 10) — **hỏi người dùng trước**.

---

## 6. Tài liệu

- **Docstring nói luật cũ sửa CÙNG task với mã**, không để tới cuối: `goi_so_tra_cuu.dart` (đầu tệp — *"tool trả 0
  hàng (hay từ chối tham số) vẫn tính là đã chạy"*), `loi_tham_so.dart` (*"Tool từ chối vẫn TÍNH LÀ ĐÃ CHẠY"*),
  `hang_so_lieu.dart` (`loi` — *"người gọi biết tool ĐÃ chạy (không phải L1)"*), `vong_lap_cong_cu.dart` (thang
  lùi thêm L1b, L2b), `cong_cu_giao_dich.dart`, `hang_chi_tieu.dart` (`kMaKy` và mã riêng `moi_luc`).
- **Task cuối:** `AI_EDGE_FEATURE.md` — mục **9.18** (bước 2b + cổng D lần 2), dòng trạng thái đầu tệp, bẫy 4.40 và
  4.43 (✅ nếu đo đạt), bẫy mới nếu lộ ra · banner spec bước 2 (mục 3.9 — câu *"tool từ chối vẫn tính là đã chạy"*
  bị lật) · banner spec 4b (mục 3.6 — vế *"hay từ chối tham số"* của chốt L1 bị lật) · `AI_AGENT_ARCHITECTURE.md`
  (ô bậc 2 bảng mục 11, đoạn 11.1) · hàng *"Đụng vào AI Edge-SLM"* của `CLAUDE.md` · mục 14 `PROJECT_CONTEXT.md` ·
  bảng thứ tự đầu `…/plans/2026-09-21-ai-viec-tiep-theo.md` · banner spec này · nhật ký thi công của kế hoạch.
- **Lượt soát theo khái niệm** (memory *cập nhật tài liệu*): liệt kê mọi tệp nhắc tới `daTraCuu` · *từ chối* ·
  `tim_giao_dich` · `chi_tieu_theo_ky` · `kMaKy` · *4.40* · *4.43* · *cổng D* — kể cả `docs/superpowers/backend/`
  — rồi mở từng tệp.

---

## 7. Phác kế hoạch (viết chi tiết bằng `writing-plans`)

1. **Lời từ chối mang câu cho người dùng** — `KetQuaCongCu.loi(choNguoiDung:, thamSoGo:)`; các hàm của
   `loi_tham_so.dart` dựng đủ hai câu; 13 lời gọi ở 6 tệp chuyển sang (mục 2.1).
2. **`GoiSoTraCuu`** — `them(ten, args, kq)`, tách thành công / từ chối, gỡ theo tham số, `mauCau()` ba trạng thái,
   `cauChuaTraDuoc` (mục 2.2). Cần `thamSoTen` — viết `tham_so_mo_hinh.dart` ở task này hoặc trước nó.
3. **Vòng lặp** — cổng `choHienChuMoHinh`, L1b, L2b, log (mục 2.3).
4. **Tham số do mô hình sinh** — `laSoTien`; áp `thamSoTen` / `laSoTien` vào hai adapter (mục 2.4).
5. **`ky` bắt buộc + `moi_luc`** (mục 2.5).
6. **Mô tả tool + chỉ dẫn hệ thống**; `toolsJsonCua` một định nghĩa; test chặn độ dài với số tạm = độ dài đo
   bằng máy sau task này (mục 2.6, 2.7).
7. **Spike trần token trên Realme** — chốt `kTranToolsJsonDaDo` (mục 2.7).
8. **Đo cổng D lần 2** (mục 5).
9. **Tài liệu** (mục 6).
