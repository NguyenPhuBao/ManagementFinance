# G5 cổng F — chắn mệnh đề sai: số tổng gán cho đối tượng, chữ kỳ lệch kỳ của số

**Ngày:** 2026-09-28. **Trạng thái:** ✅ người dùng **duyệt bản viết** cùng ngày. Người dùng đã chọn **lối A** (hai luật từ vựng)
trong chat, sau khi chọn sửa cả năm gốc G1–G5 của cổng F lần 1 (mục 9.36 `docs/AI_EDGE_FEATURE.md`). G1–G4 đã sửa ở
mã (`7ce43e1`, `631437f`, `34339a6`); spec này chỉ phủ **G5**.

## 1. Vấn đề

Cổng F lần 1 có **3 câu SAI** — cổng đòi 0. Hai câu lọt **cả năm lớp chắn** của `kiemCauTraLoi` vì mọi con số đều
thật, mọi tên đều thật, chỉ **mệnh đề** sai:

| Câu | Câu trả lời hiện ra | Vì sao lọt |
|---|---|---|
| **E3** *"Danh mục nào tôi ít tiêu nhất trong tháng?"* | *"… là Giáo dục với tổng chi là 2.241.000 đ."* | 2.241.000 là `Tổng chi` (mục **không tên**) — `kiemNhan` chỉ đòi câu có chữ "tổng chi", và câu có. Số của chính Giáo dục (`Chi`, mục có tên) không xuất hiện |
| **E21** *"Hôm nay là ngày bao nhiêu?"* (bậc 1) | *"Thu hôm nay là 15.135.000 đ, Chi hôm nay là 2.241.000 đ …"* | Số là thu / chi **tháng này** của gói Trang chủ; nhãn "Thu", "Chi" có trong câu. Không lớp nào biết số thuộc **kỳ** nào |

E8 (câu SAI thứ ba) đã được G3 xử lý tại gốc: tập hàng của câu nêu tên nay chỉ gồm hoá đơn ấy. Xét lại sau khi đo.

⚠️ Họ lỗi của E21 **không chỉ là câu hỏi ngày giờ**: câu *"hôm nay tôi chi bao nhiêu"* rơi về bậc 1 (mô hình không gọi
tool) sẽ nhận đúng câu SAI ấy với số của cả tháng. Vì thế không chọn lối C (chặn câu ngày giờ trước mô hình).

## 2. Luật (a) — số tổng gán cho đối tượng (trong `kiemNhan`)

Xét **theo vế** (`cacVeCua` — tách ở *và / hoặc / nhưng / ;*, cùng ranh giới của bẫy 4.49). Với mỗi con số **N** trong
vế (`trichSoNgoaiTen`):

1. N là số **tiền** (`LoaiSo.tien`) và **mọi** mục khớp nó (`soLieuKhop`) đều **không tên** (`ten == null`) — gọi tập
   ấy là S;
2. vế **nêu tên** một đối tượng X — X là một `SoLieu.ten` của các gói, nêu theo âm tiết như phép nới 4a
   (`tuKhoaNhan(X)` ⊆ âm tiết của vế);
3. X có một mục T **cùng họ nhãn** với một mục của S: từ khoá của T ⊆ từ khoá của S (`Chi` ⊆ `Tổng chi`, `Còn lại` ⊆
   `Tổng còn lại`, `Số dư` ⊆ `Tổng số dư` — âm tiết "tổng", "số" là âm tiết chung, `kAmTietChung`);
4. vế **không chứa** con số nào khớp một mục của X

→ **chặn**: câu đang đưa con số của cả tập cho riêng X.

| Câu | Kết quả |
|---|---|
| *"Giáo dục với tổng chi là 2.241.000 đ"* (E3) | chặn |
| *"Ngân sách Ăn uống còn lại 1.340.000 đ"* (họ E10: `Tổng còn lại`) | chặn |
| *"Giáo dục chi 10.000 đ, trên tổng chi 2.241.000 đ"* | qua — vế có số của X |
| *"Tổng chi tháng này là 2.241.000 đ"* | qua — không nêu tên |
| *"Có 2 hoá đơn chưa trả, còn phải trả 55.000 đ: Kiem và di h0c"* | qua — hàng hoá đơn không có nhãn cùng họ với `Còn phải trả` |
| *"Hoá đơn Netflix còn phải trả 100.000 đ"* | qua — 100.000 cũng khớp `Số tiền` của Netflix (điều 1 không thoả) |

**Chỉ số tiền**, không số đếm hay phần trăm: số đếm tổng đứng cạnh tên là câu liệt kê thường gặp (*"Có 11 giao dịch,
ít nhất là Giáo dục"* — hàng nhóm cũng mang `Số giao dịch`), chặn chúng là chặn oan câu đúng; hai câu SAI đã đo đều là
số tiền.

**Giới hạn cố ý** (sai theo chiều an toàn): câu đúng nêu tên X cạnh số tổng mà không nêu số của X — *"Giáo dục chiếm
phần nhỏ trong tổng chi 2.241.000 đ"* — bị chặn và rơi về mẫu câu. Phép lọc từ vựng không định vị được con số đứng cạnh
chữ nào; cùng loại giới hạn đã ghi ở docstring `kiemNhan`.

## 3. Luật (b) — chữ kỳ lệch kỳ của số: lớp chắn thứ SÁU `kiemKy`

**Chữ kỳ tương đối** (từ vựng đóng, so trên chữ **bỏ dấu**, trọn từ): *hôm nay · hôm qua · tuần này · tuần trước · tháng
này · tháng trước · quý này · quý trước · năm nay · năm trước · năm ngoái*. Không có *hiện tại, bây giờ*: số dư ví "hiện
tại" đúng với mọi kỳ.

**Kỳ của một con số** — hàm mới `Set<String>? GoiSo.kyCua(SoLieu s)`, mặc định **`null` = không biết, không xét**:

| Nguồn | Kỳ |
|---|---|
| `GoiSoTrangChu` | `Thu`, `Chi`, `Còn lại` / `Chi vượt thu` → {tháng này}. `Tổng số dư`, `Ngân sách căng nhất` → `null` (số hiện tại) |
| `GoiSoPhanTich` dựng với `chuKy` (tham số mới, tuỳ chọn) | các số của kỳ (`Tổng chi`, `Tổng thu`, `Để dành` / `Vượt thu nhập`, `Khoản lớn nhất`, `Chi` từng danh mục) → {chuKy}; `So kỳ trước` → {chuKy, tháng trước}; `Cam kết`, `Số cam kết` (30 ngày tới) → `null`. `NguonGoiSo` truyền `chuKy: 'tháng này'` (nó luôn dựng tháng hiện tại); khối Nhận xét trang Phân tích không truyền → mọi số `null` |
| `GoiSoTraCuu` | theo **lượt** chứa mục ấy: chữ `chuThem['ky']` nếu là chữ kỳ tương đối, cộng chữ kỳ trong các khoá `so_sanh_*` (E13 *"so với tháng trước"*). Lượt *mọi thời gian*, kỳ tự do, *kỳ tới*, *mọi kỳ*, hay không có khoá `ky` → `null` |
| Bốn gói còn lại (ngân sách, mục tiêu, hoá đơn, ví) | `null` |

**Luật:** với mỗi vế có **ít nhất một** chữ kỳ tương đối P, và mỗi con số N trong vế: gọi M là tập mục khớp N. Nếu M
không rỗng, **mọi** mục trong M có kỳ đã biết, và **không** chữ P nào của vế thuộc hợp các kỳ ấy → **chặn**.

| Câu | Nguồn | Kết quả |
|---|---|---|
| *"Thu hôm nay là 15.135.000 đ"* (E21) | Trang chủ `Thu` {tháng này} | chặn |
| *"Tháng này bạn thu 15.135.000 đ"* | như trên | qua |
| *"Tổng thu 15.135.000 đ"* | vế không có chữ kỳ | qua |
| *"Tháng này bạn chi 2.241.000 đ, trong khi tháng trước bạn chi 0 đ"* (E13) | lượt {tháng này, tháng trước} | qua |
| *"Hôm nay tổng số dư của bạn là 13.004.000 đ"* | `Tổng số dư` → `null` | qua |
| *"Tháng này bạn nạp cho MuaDT 3 lần"* | lượt *mọi thời gian* → `null` | qua (không xét) |

**Giới hạn cố ý:** kỳ gắn theo **lượt** tool chứ không theo từng mục — lượt tổng quan mang cả số tháng này lẫn dư nợ mọi
thời gian dưới một kỳ *tháng này*, nên *"hôm nay bạn đang nợ …"* bị chặn oan (hiếm) và *"tháng này bạn đang nợ …"* lọt.
Gắn kỳ lên từng `SoLieu` (lối B) chính xác hơn nhưng phải sửa mọi hàm dựng số ở ~15 tệp — người dùng không chọn.

`kiemCauTraLoi` = năm lớp cũ **và** `kiemKy`. Vì đường streaming (`gacTheoCau`) và bậc 1 đều gọi `kiemCauTraLoi`, cả hai
được che; câu bị chặn đi đúng đường cũ (L2 mẫu câu ở bậc tool, câu từ chối ở bậc 1).

## 4. Không đổi

Khai báo tool, `tools_json` (6.980), lời hệ thống, mẫu câu, schema, payload đồng bộ. Không lớp chắn nào cũ bị nới.

## 5. Kiểm thử

- **(a)** trong `kiem_nhan_test`: sáu câu bảng mục 2 (chặn / qua đúng như bảng) trên gói giả mang **đúng nhãn** của
  gói thật (hàng nhóm giao dịch, ngân sách, hoá đơn); cộng một ca E3 trên gói **thật** (`hangNhomGiaoDich`, qua
  `kiemCauTraLoi`) — câu SAI của cổng F bị chặn, câu ĐÚNG của 27/09 (*"… Giải trí với tổng chi là 30.000 đ"*, số của
  chính nó) vẫn qua.
- **(b)** tệp mới `kiem_ky_test`: sáu câu bảng mục 3; `kyCua` của `GoiSoTrangChu`, `GoiSoPhanTich` (có và không có
  `chuKy`), `GoiSoTraCuu` (lượt tháng này, lượt có so sánh, lượt mọi thời gian); chữ kỳ không dấu (*"nam nay"*) đọc
  được; *"tháng 9"* không phải chữ kỳ tương đối.
- **Hồi quy:** mọi ca hiện có của `kiem_*`, `hang_*`, `goi_so_*` xanh **không sửa kỳ vọng** — đặc biệt các ca *"mẫu câu
  tự qua năm lớp chắn"* (mẫu câu có tiền tố kỳ, ví dụ *"Tháng này — …"*). Ca nào đỏ là dương tính giả phải xét, không
  sửa ca cho xanh.
- Mỗi luật thử bằng **bản sai có chủ ý** (tắt luật → ca chặn phải đỏ).

## 6. Đo

Sau khi mã xong (cùng G1–G4): build APK release, đo lại **các câu chưa đạt** của cổng F lần 1 (20 câu ✗ / ◐, gồm ba câu
SAI) trên máy đang cắm, bảng ba cột. Chạy lại trọn 72 câu chỉ khi các câu ấy đạt.
