# Việc tiếp theo — chi tiết đủ để bắt tay làm

> **Cho người thi công:** tệp này gom **toàn bộ việc còn mở của dự án** — mảng AI (chặng
> 0–5) **và việc ngoài mảng AI** (hai mục lỗ hổng, bảy việc UX) — sắp theo thứ tự, ghi đủ
> tên tệp / tên hàm / chữ ký để không phải khảo sát lại. Chặng 1 chi tiết nhất vì nó làm
> được ngay; các chặng sau phác thảo dần.
>
> **Nguồn:** `docs/AI_EDGE_FEATURE.md` mục **10** (bản chất mảng AI, mười tiêu chí, bốn
> tầng chiều ghi) và mục **11** (bản đồ khảo sát). Đọc hai mục ấy **trước** khi bắt đầu.

**Viết:** 2026-09-21. **Trạng thái:** chặng 0 ✅ và **trọn chặng 1** xong (2026-09-21) — riêng 1.4 ⚠️ **một phần**, hai hàm còn lại là việc về trùng lặp chứ không về năng lực. Từ **2026-09-23** thứ tự làm việc là mục **"THỨ TỰ … chốt lại 2026-09-23"** ngay dưới đây.

---

# ⭐ THỨ TỰ THỰC HIỆN — chốt lại 2026-09-23, sau cổng C

Người dùng duyệt thứ tự này chiều 2026-09-23 (*"ok vậy thì theo thứ tự bạn đề xuất"*), khi lộ
trình kiến trúc đã đi hết phía client: chặng 1–4 xong, cổng A · B · C đạt, chặng 5 bỏ, chặng 6 là
việc của backend. Mục *"THỨ TỰ … chốt 2026-09-22"* bên dưới nay là **lịch sử** — mọi việc của nó
đã xong hoặc đã chuyển vào bảng này.

Hai nếp người dùng đã chốt quyết định thứ tự: **sửa lỗi trước, thêm tính năng sau** và **ưu tiên
giá trị người dùng**.

| # | Việc | Trạng thái | Ghi chú |
|---|---|---|---|
| 1a | Thẻ thu/chi tháng ở Trang chủ đi qua `khoanVaoThongKe` | ✅ **xong 2026-09-23 tối** — `thuChiThangCua` đi qua `tongThuChi` + `Ky.thang`; 7 ca ở `home/thu_chi_thang_test.dart`; nghiệm thu máy ảo: Trang chủ, khối Nhận xét, trang Phân tích cùng 15.135.000 | Người dùng chốt **LOẠI** khoản điều chỉnh số dư và khoản "Số dư ban đầu" — con số của trang Phân tích là con số đúng. Trước 4b, hai số lệch (15.145.000 / 15.135.000) nằm ở hai trang; từ 4b trợ lý AI (tool `chi_tieu_theo_ky`) nói một số, Trang chủ nói số kia. Sửa **một chỗ**: `thuChiThangCua` — thẻ và khối Nhận xét Trang chủ đổi theo |
| 1b | Canary cho phiên có tool (bẫy 4.33 `AI_EDGE_FEATURE.md`) | ✅ **xong 2026-09-23 tối** — mục 9.15 `AI_EDGE_FEATURE.md`; 24 ca; nghiệm thu máy ảo ba cách chết (`kill -11` → hỏng · `force-stop` / `kill -9` → chỉ xoá dấu). ⚠️ Thi công lệch kế hoạch một chỗ: dấu bao khoảng trước sự kiện đầu của **mỗi** lượt sinh, không chỉ lượt đầu — có lý do thoát rồi thì cửa sổ dài hơn không còn gây báo nhầm, mà bắt được cả cú sập ở lượt sau | Người dùng chốt **lối B** (2026-09-23): canary **cộng** lý do thoát lần trước của Android (`ApplicationExitInfo`, API 30+) — chỉ tắt bậc tool khi lần thoát đầu tiên sau khi đặt dấu là **sập native**; bị giết / buộc dừng / thiếu RAM thì chỉ xoá dấu. Lý do: chép nguyên khuôn GPU thì Realme (giết app khi vuốt khỏi Recents) mất bậc tool vĩnh viễn chỉ vì một lần vuốt giữa lúc trả lời. Android 10 trở xuống: tắt khi dấu sót **hai lần liền** (lối C). Kèm: dấu chỉ bao **khoảng trước sự kiện đầu tiên** của lượt sinh; dấu "hỏng" ghi **phiên bản app** và tự xoá khi app lên bản mới. Khi bậc tool bị tắt: màn đi thẳng bậc 1, im lặng |
| 1c | **Tên đối tượng có chữ số không qua được lớp chắn** (bẫy 4.38 `AI_EDGE_FEATURE.md`) — **thêm vào thứ tự 2026-09-23 tối**, lộ ra khi soát trước bước 2 | ✅ **xong 2026-09-23 tối** — `trichSoNgoaiTen` (bỏ tên của gói khỏi câu trước khi trích số: tên có chữ cái, khớp trọn từ, không phân biệt hoa thường, tên dài trước), một phép tách âm tiết giữ chữ số cho cả tên lẫn câu, `GoiSo.tenDoiTuong` + ba override; 18 ca, 11 bản sai có chủ ý đều bị bắt; mục **9.16** | Đo trên tài khoản 10: **5/9** hoá đơn, **1/16** danh mục có chữ số trong tên — câu đúng nêu tên chúng bị cả `kiemSo` lẫn `kiemNhan` chặn. Người dùng chọn **sửa trước** bước 2 (tool tìm giao dịch sẽ đưa ghi chú *"Thanh toán hóa đơn: <tên có số>"* vào hàng). ⚠️ **Chưa đo trên máy thật** — thêm một câu về hoá đơn có chữ số trong tên vào bộ câu hồi quy của buổi đo bước 2 |
| 2 | Hai tool đọc còn lại của đơn đặt hàng cổng B + **tool tìm giao dịch** (nửa sau mục 2.1 tệp này) + **phép đo 20 câu lệnh** | 📝 **spec viết xong 2026-09-23 tối muộn** (`2e90486`) — `specs/2026-09-23-buoc-2-ba-tool-doc-tim-giao-dich-design.md`; thiết kế ba phần người dùng đã duyệt trong chat. ✅ **Spec đã duyệt** ở phiên sau — kể cả ba chỗ thêm lúc viết (spec mục 1.2 hàng 11–13): bỏ giao dịch ghi ngày tương lai · giữ `maxTokens` 4.096 khi RAM đỉnh tăng ≤ 0,5 GB · tách `tieuDeGiaoDich` khỏi `buildTransactionRowContent` (**4** chỗ gọi, không phải 5 như bản nháp). 🚧 **Đang thi công** theo kế hoạch `2026-09-23-buoc-2-ba-tool-doc-tim-giao-dich.md` (9 task) — task 1–8 xong (mã Dart, `BoCongCu` **bảy** tool; nghiệm thu máy ảo; spike Realme → `maxTokens` **4096**, RAM vượt ngưỡng 0,5 GB — người dùng duyệt). 🛑 **Cổng D CHƯA ĐẠT** — lần đo 1 (Realme, 2026-09-24): nhóm A **7/8 — tụt** · nhóm B 2/4 · nhóm C **13/20 tool · 5/20 tham số** (đúng theo nội dung 4/20) · **5 câu SAI** · 0 sập (mục **9.17** `AI_EDGE_FEATURE.md`). Theo spec 5.5: chỉnh mô tả tool/tham số rồi đo lại nhóm C; **bước 3 chưa mở**. Hướng sửa **đã chốt 2026-09-24** (*sửa lỗi mã trước, rồi chỉnh mô tả*) — ✅ **bước 2b** — spec `specs/2026-09-24-buoc-2b-tu-choi-giu-cho-mo-ta-tool-design.md` đã duyệt, kế hoạch 10 task `plans/2026-09-24-buoc-2b-tu-choi-giu-cho-mo-ta-tool.md`, chưa dòng mã nào: lời từ chối không còn tính là đã tra cứu (bẫy 4.40), giá trị giữ chỗ và số tiền trong `tu_khoa` (4.43), `ky` bắt buộc + `moi_luc`, chỉnh mô tả tool, rồi đo lại **đủ** cổng D; ca A3 của bẫy 4.42 nằm ngoài spec ấy | hai tool: dự báo mục tiêu — dựng thành *danh sách mục tiêu có tên*, cùng hình dạng bốn tool đã có (bài học 4a) — và gợi ý hạn mức (`suggestAmount`). Phép đo chọn-đúng-hàm là **căn cứ để mở chiều ghi** |
| 3 | **Nhập giao dịch bằng câu** (gõ) — mục 2.2, ghi **tầng 3** | ⬜ | cần brainstorm + spec + Stitch. Bản luật chạy trước, mô hình chỉ cho câu lạ; form điền sẵn dựng từ **tham số**; chốt bảng quy đổi *k / củ / lít…* với người dùng trước khi viết mã |
| 4 | **Tạo hoá đơn · mục tiêu · ngân sách bằng lệnh** — mục 2.3, ghi **tầng 2** | ⬜ | cần brainstorm + spec; một hộp thoại có số, một lệnh một bước |
| 5 | **Gắn danh mục hàng loạt** — mục 3.1, ghi **tầng 1** | ⬜ | cần brainstorm + spec; đo lại tỉ lệ vì 15/39 là số của 2026-09-20 |
| 6 | Mở rộng đường vào: **giọng nói**, rồi **chụp hoá đơn** (trả lời luôn việc UX A5 — nút "Quét") | ⬜ | mục 8.7 `AI_EDGE_FEATURE.md` là **cận trên** (giọng tổng hợp, ảnh dựng bằng máy) — phải đo lại bằng giọng người và ảnh chụp thật |

⚠️ Bước 3–4 **đổi bất biến ④** của `AI_AGENT_ARCHITECTURE.md`: *"không tool nào ghi"* thành
*"không tool nào ghi **thẳng** — tool chiều ghi chỉ trả đề xuất để người dùng duyệt"*. Thay đổi ấy
phải nằm trong spec và được người dùng duyệt. Tầng 4 (bật tự trả / trích tự động) và mọi thao tác
**xoá** vẫn **không có hàm nào** (mục 10.5 `AI_EDGE_FEATURE.md`).

**Chờ người dùng gọi tên — không tự làm:** rút ngắn câu chào ~23 s trên Realme và dạy trợ lý nói
"không có dữ liệu" (cả hai đổi hành vi L1, cần thiết kế); bảy việc UX hoãn (mục cuối tệp).

---

# ⭐ THỨ TỰ THỰC HIỆN — chốt 2026-09-22 *(lịch sử — thay bằng mục trên từ 2026-09-23)*

Người dùng duyệt thứ tự này cuối phiên 2026-09-22, sau khi P3 xong 10/10 task.
**Đọc mục này trước mọi mục khác trong tệp** — các chặng bên dưới là *nội dung*, mục này
là *thứ tự*.

### Ba thay đổi bối cảnh của ngày 2026-09-22, đọc trước khi xếp lại

1. ✅ **P3 xong 10/10 task** — mô hình đã chạy thật trên OnePlus 13R, bảng đo ở mục **9**
   `AI_EDGE_FEATURE.md`. Mất mạng vẫn trả lời trong 1.898 ms, 0 request đi ra.
2. 🛑 **Nhưng CỔNG A chưa qua.** Đối chiếu sáu điểm của cổng
   (`2026-09-21-lo-trinh-edge-ai-agent-rag.md:100`) với bảng đo: điểm 1, 3, 6 ✅; điểm
   **2 (chữ hiện dần) chưa có**; điểm **4 (hỏi thứ gói số không có → rơi về mẫu câu)
   ĐANG HỎNG**; điểm 5 chưa đo. Đừng ghi "P3 xong nên cổng A xong" — hai thứ khác nhau.
   *(Cập nhật tối cùng ngày: việc số 1 xong và **cổng A đã qua** — đo máy thật mục 9.9
   `AI_EDGE_FEATURE.md`; khung ở mục 1.)*
3. ✅ **Backend đóng cả hai tài liệu `CAN-LAM`** (gộp `main` @ `1428918`, client gộp về ở
   `92dd5cc`): năm điểm sai đặc tả đã sửa trong `docs/AI/AI_Edge-SLM.md/Client-app.md`
   (90 dòng), thuật ngữ đổi sang **Edge AI**, và **hai mâu thuẫn được chốt** — ① dữ liệu
   tài chính người dùng **không** index lên vector DB server, số liệu cá nhân đi bằng
   **function-calling**; ② giữ Cloud AI ở tầng 3 phân loại, thêm `maskTransactionDescription`
   lọc dữ liệu nhạy cảm trước khi gửi prompt. ⚠️ Quyết định ① **khớp đúng hướng** của việc
   số 3 dưới đây — hai đầu nay đi cùng một lối thay vì mỗi bên một kiểu.

---

### 🛑 Bẫy đánh số: dự án có HAI hệ "chặng" khác nhau, và chúng LỆCH nhau

| "Chặng" | Trong `2026-09-21-lo-trinh-edge-ai-agent-rag.md` (lộ trình kiến trúc) | Trong **tệp này** (việc theo tính năng) |
|---|---|---|
| 1 | Chặn lỗi + tài liệu + spike RAG | Năm việc gói số |
| **2** | **P3 — cắm SLM** | **Function calling** |
| **3** | **Đo: bậc 1 hỏng ở đâu** | **Phân loại tự động** |
| **4** | **Tool-calling + vòng lặp** | **P3** |
| 5 | RAG client (🛑 bỏ) | Phần còn lại |
| 6 | Backend RAG (NPBao) | — |

⚠️ Đọc *"chặng 2"* ở tệp này rồi đi làm *"chặng 2"* ở tệp kia là làm nhầm hẳn một hạng mục.
**Thứ tự dưới đây dùng LỘ TRÌNH KIẾN TRÚC làm khung** vì chỉ nó có cổng kiểm; chỗ nào nhắc
chặng của tệp này thì ghi rõ *"(mục X tệp này)"*.

---

## 1 · Chất lượng câu trả lời + đóng cổng A

**Vì sao đứng đầu:** đây là **lỗi đang chạy**, không phải tính năng thiếu — và nó rẻ.
Người dùng hỏi thẳng *"AI trả lời không đúng có phải do giới hạn của SLM không"* ngày
2026-09-22, và câu trả lời đo được là **không, phần lớn là lỗi phía ta**:

| Nguyên nhân | Bằng chứng | Sửa được? |
|---|---|---|
| **2/4 chip hỏi thứ gói số KHÔNG CÓ** | gói mục tiêu chỉ có `Tiến độ` · `Còn thiếu` · `Còn` · `Theo nhịp hiện tại`; không có "dự báo tiết kiệm" nào. Không gói nào có "gợi ý cắt giảm" (`TaiPhanBoNguon` không vào `NguonGoiSo`) | ✅ rẻ |
| **`kiemSo` canh SỐ, không canh NHÃN** | *"Tỉ lệ phân bổ là 85,4%"* qua được, dù 85,4 % là tỉ lệ **để dành** | ⚠️ cần thiết kế |
| **Few-shot toàn câu nhận xét** | `promptHoiDap` dùng chung `_viDu` với `promptCauTheoMan` — không ví dụ hỏi–đáp nào, không ví dụ *"không có dữ liệu"* nào | ✅ rẻ |
| Giới hạn thật của E2B | prompt đã dặn *"thiếu thông tin thì nói rõ"*; mô hình ~2 B không tuân nổi | 🛑 đổi mô hình cũng không khá hơn — P1 đo E4B chậm gấp đôi, tiếng Việt không hơn |

**Kèm trong việc này — điểm 2 của cổng A (streaming).** ✅ Gói **có sẵn**
`Chat.generateChatResponseAsync()` trả `Stream<ModelResponse>` (`flutter_gemma-1.8.3/lib/core/chat.dart:315`),
nên không phải tự dựng gì.

⚠️ **Nhưng streaming va chạm với `kiemSo`, và đây là câu hỏi thiết kế phải chốt trước khi
viết mã:** bộ kiểm số chạy trên **câu đã đầy đủ**. Hiện chữ dần nghĩa là người dùng **đọc
được câu trước khi nó bị chặn** — tức dây an toàn còn nguyên nhưng đã muộn. Ba lối để cân:
hiện dần rồi thay bằng câu mẫu nếu trượt (người đọc thấy chữ nhảy); giữ nguyên khối như
hôm nay (bỏ điểm 2 của cổng A); hoặc hiện chỉ báo "đang viết" có nhịp thay vì chữ thật.
**Cần brainstorm trước khi làm.**

**Đo lại cả ba điểm còn thiếu của cổng A** (2, 4, 5) trên máy thật sau khi sửa.

> ✅ **XONG 2026-09-22 tối — CỔNG A QUA** (đo máy thật mục **9.9** `AI_EDGE_FEATURE.md`; lượt đo
> bắt hai lỗi thật, bẫy 4.18/4.19). Brainstorm chốt trong chat (bounded):
> streaming **chặn theo câu** (`gacTheoCau`, `SlmRuntime.sinhDan`/`huy`), **`kiemNhan`** lớp chắn
> thứ ba, `kiemGiong` nối vào hỏi đáp qua `kiemCauTraLoi` (trước đó **chưa nối** — "chưa đo" ở
> bảng cổng A là sai chữ), `NguonGoiSo` **sáu** gói, bốn chip mới, few-shot hỏi đáp riêng.
> Chi tiết và cách đo: mục **9.8** `AI_EDGE_FEATURE.md`. 3392/3392 · analyze 26.
> ⚠️ Người dùng hỏi *"vậy chỉ hỏi được thứ có sẵn thôi à"* — đúng, và chốt **giữ thứ tự**:
> việc này trước, rồi mới function calling.

## 2 · Tải nền + resume

> ✅ **XONG 2026-09-22 tối muộn** — 7 task, nghiệm thu trên **Realme RMX2205 / Dimensity 1100**
> (máy thứ hai của dự án), bảng đo mục **9.10** `AI_EDGE_FEATURE.md`. Lượt đo bắt sáu lỗi thật,
> nặng nhất là **nạp GPU sập native trên Mali** → thêm canary GPU (ngoài kế hoạch, nhưng là lỗi
> chặn). Hai giới hạn không vá: Realme force-stop khi vuốt Recents; sau force-stop / dừng vì ràng
> buộc thì gói tải lại từ 0 (chỉ Tạm dừng mới giữ byte). **Bước tiếp: chặng 3 (mục 3 dưới).**

**Spec và kế hoạch ĐÃ VIẾT XONG** — chi phí khởi động bằng không:

- Spec: `docs/superpowers/specs/2026-09-22-tai-mo-hinh-nen-resume-design.md` (commit `ce4d7ca`)
- Kế hoạch: `docs/superpowers/plans/2026-09-22-tai-mo-hinh-nen-resume.md` — **7 task**, test viết sẵn

**Vì sao đứng thứ hai chứ không thứ nhất:** nó chặn **người dùng thật** tiếp cận tính năng
(97 KB/s → ~7 giờ, đứt là mất hết), nhưng máy nghiệm thu **đã có mô hình** nên nó không
chặn việc số 1. Làm xong việc 1 thì cái được mở khoá ở việc 2 mới đáng dùng.

## 3 · Chặng 3 của lộ trình — đo: bậc 1 hỏng ở đâu ✅ **XONG 2026-09-22 (tối muộn)**

> ✅ **Đã đo, cổng B qua.** Bảng 20 hàng ở mục **5.6** `docs/AI_AGENT_ARCHITECTURE.md` — đo trên
> **Realme RMX2205** (CPU), tài khoản thật. Kết quả: **✅ 5 · rơi mẫu 3 · sai 0 · lệch câu hỏi
> 12**. Đơn đặt hàng **sáu** tool, bốn cái đứng đầu đều là *"danh sách có **tên**"* — mười tool
> ứng viên ở mục 5.1 không dự đoán hình dạng ấy, và ba trong số chúng không câu nào cần tới.
> ⚠️ Ba câu hỏng **không cần tool nào** (số đã có sẵn trong gói, mô hình chọn nhầm) — sửa ở
> **prompt/nhãn**, và nên làm **trước** khi dựng tool.
>
> ✅ **Phần "làm trước" ấy chính là lát 4a, xong mã 2026-09-23** (spec + plan ngày 2026-09-22),
> 🛑 **cổng của nó chưa đạt**: nhóm A **1/4**, cần ≥ 3/4. ⭐ Và nó lật một phần kết luận ở trên —
> **danh sách có tên là CẦN nhưng CHƯA ĐỦ**: gói nói `Quá hạn: 1` ở một dòng và `Kiem · Phải trả:
> 45.000 đ` ở dòng khác, không chỗ nào nói Kiem **LÀ** cái quá hạn, và E2B không nối được hai mục
> rời. Nên ba câu còn hỏng **không** chữa được bằng gói số; chúng cần tool trả **một hàng đầy
> đủ**. Việc tiếp theo là **lát 4b**.
>
> ✅ **Lát 4b XONG 9/9 task, cổng C ĐẠT (2026-09-23 chiều)** — bốn tool chỉ đọc, màn Trợ lý AI đi
> bậc tool; nhóm A trả lời bằng tên Realme **4/4**, OnePlus **3/4**, 0 câu bịa số. Bảng ở mục
> **9.14** `AI_EDGE_FEATURE.md`. Tức **"function calling" của hệ đánh số trong tệp này (chặng 2)
> nay đã có ở dạng bốn tool đọc** — nửa sau của chặng 2 bên dưới (*"bộ hàm cho function
> calling"*) phần nào đã làm, xem banner ở đó.

🛑 **Bước này từng BỊ BỎ SÓT trong bản thứ tự đầu tiên viết cùng ngày** — bản ấy để
"function calling" ngay sau tải nền. Sai, và lộ trình đã ghi sẵn lý do: danh sách tool phải
**rút từ bảng đo**, không phải từ mười tool đoán sẵn ở mục 5.1 `AI_AGENT_ARCHITECTURE.md`
(mười tool ấy là *ứng viên*, bảng đo mới là *đơn hàng*). Dựng 10 tool rồi thấy 7 cái không
ai gọi là **cùng một lớp lãng phí** với lát "cửa sổ nhìn lại": một hàm đúng từng dòng mà
đầu vào chết thì vẫn vô dụng.

**Điều kiện vào: cổng A đã đóng.** Đo một mô hình còn bịa nhãn thì bảng đo nói dối.

**Không phải task mã.** Một buổi, máy thật, tài khoản thật:

1. Soạn **20 câu** người dùng thật sẽ hỏi — 5 ngân sách · 5 chi tiêu theo kỳ tuỳ ý ·
   5 mục tiêu/hoá đơn · 5 cần **ghép nhiều nguồn**.
2. Hỏi từng câu ở màn Trợ lý AI, ghi: *trả lời được / rơi về mẫu / trả lời sai*.
3. Mỗi câu hỏng → ghi **con số nào thiếu trong sáu gói số**. Đó là tool cần có.

**Ra cổng B:** bảng 20 hàng ở mục **5.6** `AI_AGENT_ARCHITECTURE.md` + danh sách tool rút
từ bảng. 🛑 Nếu **0 câu hỏng** thì vòng 3 **không có việc** — dừng lộ trình và báo; đó cũng
là một kết quả. (Với những gì đo ngày 2026-09-22, khả năng ấy thấp.)

**Ước lượng:** nửa ngày.

## 4 · Chặng 4 của lộ trình — tool-calling + vòng lặp

**Kế hoạch chi tiết VIẾT TẠI CỔNG B**, không viết trước.

⚠️ **Mục 2.1 "nửa sau" của tệp này nằm TRONG chặng 4, không phải một việc riêng** — nó là
một hàm khai `Tool` ánh xạ sang `TransactionFilter` + `Ky`, tức một trong những tool mà
bảng đo sẽ đặt hàng.

Hai thứ đã sẵn, nên chặng này nhẹ hơn vẻ ngoài:

- ✅ **Backend chốt lối ① cùng hướng** (2026-09-22): số liệu cá nhân đi bằng
  function-calling, không index lên vector DB. Hai đầu khớp nhau.
- ✅ Gói **có sẵn** `Chat.generateChatResponseWithTools()` (`flutter_gemma-1.8.3/lib/core/chat.dart:787`).

**Khung cố định** (lộ trình mục "Chặng 4"): kết quả tool là **`List<SoLieu>`** chứ không
phải văn bản · gói số **tích luỹ** qua các lượt, `kiemSo`/`kiemGiong` chạy trên gói tích
luỹ · trần **3** lượt gọi tool · **không tool ghi** · test quét thứ 16 giữ nguyên.

⚠️ **Chốt M3 trước khi viết kế hoạch** (luật ngủ đông: essentiality = 0,5, C4 bị C5 nuốt) —
tool tái phân bổ sẽ lộ luật ấy ra câu trả lời.

**Ra cổng C:** một câu từng hỏng ở bậc 1 nay trả lời đúng trên máy thật, logcat cho thấy
đúng tool được gọi, và câu bịa số vẫn bị chặn. **Ước lượng:** ~2 ngày (≈ 4 task).

## 5 · Gắn danh mục hàng loạt *(mục 3.1 tệp này)*

Vá **38 %** dữ liệu mù (15/39 giao dịch, đo 2026-09-20). Chiều ghi **tầng 1** nên duyệt cả
lô trong một màn; `CategorySuggestionEngine` sẵn có làm **bản đối chứng** — so hai bên là
phép đo sạch cho báo cáo. **Cần brainstorm + spec.**

## 6 · Phần còn lại của 1.4 — thống kê mục tiêu và cảnh báo ví thiếu tiền trích

Xem mục **1.4**. Đòi **mở thêm nguồn dữ liệu cho trang danh sách** (state + repository), và
là quyết định về **trùng lặp** chứ không về năng lực — cả hai hàm đang chạy thật ở trang
Chi tiết mục tiêu. ⚠️ Cân nhắc trước: `canhBaoViKhongDu` báo một **mâu thuẫn dữ liệu thật**
(tiền tích luỹ bị tiêu mất), có lẽ xứng một **thông báo** hơn là một vế trong câu nhận xét.

---

## Việc nhỏ nên kẹp vào đầu phiên

1. **Soát đặc tả AI vừa được backend sửa** (`docs/AI/AI_Edge-SLM.md/Client-app.md`, 90 dòng
   đổi ngày 2026-09-22) — đối chiếu lại với mã client xem còn chỗ nào lệch. Rẻ, và làm
   ngay lúc tài liệu vừa đổi thì rẻ hơn nhiều so với sáu tháng nữa.
2. **Dọn ~4,5 GB ngoài repo:** tệp mô hình trong thư mục tạm của phiên (2,5 GB) và
   `D:/flowmoney_spike_rag` (~2 GB, từ lượt spike RAG). ⚠️ **Hỏi người dùng trước khi xoá.**

## Việc chờ người dùng gọi tên — đừng tự làm

**Bảy việc UX hoãn** (mục riêng cuối tệp này). Người dùng chốt *"lưu lại các phần đó để làm
sau"* — không làm cái nào cho tới khi họ nhắc lại tên.

---

## Luật chung cho mọi việc dưới đây

Trích từ mục 10.4 và 10.5 `AI_EDGE_FEATURE.md` — áp cho **tất cả**, không nhắc lại ở
từng việc:

1. **Lớp `ai_edge/` không tính.** Mọi số từ hàm domain đã có. Test quét thứ 14 cấm
   `'thu'`/`'chi'`/`'transfer'`/`walletId`/`transactionDao`/`.type ==` trong thư mục ấy.
2. **Chạy được khi không có mô hình.** Mẫu câu là bản *chính*, mô hình là bản *nâng cấp*.
3. **Rơi về bản thấp hơn im lặng** — không toast, không dialog.
4. **Mỗi luật học có ngưỡng mẫu tối thiểu; dưới ngưỡng thì im**, rồi tự bật khi đủ.
5. **Chiều ghi luôn xác nhận**, và form xác nhận dựng từ **tham số**, không từ câu mô
   hình viết. 🛑 Không hàm nào bật `auto_pay` / trích tự động / **xoá** bất cứ gì.
6. **TDD**: test đỏ trước; ca xanh ngay từ đầu **phải thử bản sai có chủ ý**.
7. Trước khi báo xong: `flutter test` **trọn bộ** (mức nền **3603/3603, 3 skip** — đo 2026-09-23 tối
   muộn sau bước 1c; mốc 3585 là sau bước 1b, 3106/3106, 1 skip là của 2026-09-20) và `flutter
   analyze` (**26 issue, 0 error**).
   Đụng giao diện → **nghiệm thu máy ảo 411dp**.
8. ✅ Tệp test mới **không cần `git add -f` nữa** — luật `test/` bỏ khỏi `.gitignore`
   ngày 2026-09-21 (quy tắc 6 `CLAUDE.md`).

---

# CHẶNG 0 — Hai phép đo ✅ **XONG 2026-09-21**

> **Kết quả đã vào `AI_EDGE_FEATURE.md`** — hàng NPU ở mục **8.1**, ảnh và âm thanh ở
> tiểu mục **8.7** mới. Tóm tắt: **NPU tệ hơn cả GPU lẫn CPU** (chậm 3,6 lần, RAM gấp
> 3,4 lần) nên bậc thang **giữ nguyên**; còn **ảnh và âm thanh đều chạy được**, đọc đúng
> tổng tiền hoá đơn và rút đúng ý định từ câu nói — nhưng cả hai đo bằng dữ liệu **dựng
> bằng máy**, tức cận trên, chưa phải ảnh chụp thật và giọng người thật.
>
> ⚠️ **Không phép đo nào mở một hạng mục.** Thứ tự việc bên dưới **không đổi**.
>
> Hai cái bẫy của lượt đo, ghi lại vì chúng sẽ cắn lần sau:
> **(1)** `adb devices` im lặng hoàn toàn dù Device Manager báo OK — driver WinUSB generic
> **không công bố** GUID giao diện Android mà adb đi tìm; sửa bằng cách thêm
> `DeviceInterfaceGUIDs = {F72FE0D4-CBCB-407D-8814-9ED673D0DD6B}` vào khoá
> `Device Parameters` của thiết bị (cần quyền admin, gỡ ra là xoá đúng giá trị ấy).
> Cài Google USB Driver **không** giải quyết được vì INF của Google không chứa `VID_22D9`
> của OnePlus, mà sửa INF là hỏng chữ ký số.
> **(2)** Git Bash đổi `/sdcard/Download/x` thành `C:/Program Files/Git/sdcard/...`; adb
> khi ấy báo `secure_mkdirs() failed` **nhưng vẫn in "1 file pushed" kèm tốc độ** — mất 84
> giây đẩy 2,4 GB đi đâu không rõ. Đặt `MSYS_NO_PATHCONV=1` trước mọi lệnh adb.

⚠️ **Tách riêng vì chúng KHÔNG phụ thuộc gì và không chặn ai** — điều kiện duy nhất là
người dùng cắm máy thật. Bản đầu của tệp này chôn chúng ở cuối chặng 5, lẫn trong một
bảng 12 dòng, nên người dùng phải hỏi lại mới thấy.

Hạ tầng còn nguyên: app spike ở `D:/flowmoney-spike` (ngoài repo), bốn tệp mô hình ở
`D:/flowmoney-models` (11 GB). Đẩy lại một tệp 2,41 GB mất ~2 phút qua USB, theo đúng
đường ở mục **8.6** `AI_EDGE_FEATURE.md` (push vào `/sdcard/Download` rồi
`cat … | run-as ‹pkg› sh -c 'cat > files/…'`).

## 0.1 Đo NPU — ✅ XONG, kết quả: KHÔNG dùng NPU

P1 **chỉ đo GPU và CPU**. Máy là Snapdragon 8 Gen 3 có NPU Hexagon; gói có
`PreferredBackend.npu` và README ghi *"NPU Acceleration: Hardware NPU inference for
`.litertlm` models on Qualcomm Snapdragon"*.

**Lấy được chỉ bằng đổi một tham số** trong `_chay()` của spike. Nếu NPU nhanh hơn hoặc
tốn ít pin hơn GPU thì đó là cải thiện thật cho P3; nếu không chạy được thì cũng là một
dòng đáng giá trong bảng đo của đồ án.

**Đã điền:** mục **8.1** `AI_EDGE_FEATURE.md`, hàng thứ năm + ba ghi chú.

## 0.2 Đo vision / audio — ✅ XONG, cả hai chạy được

P1 **chỉ đo văn bản**. E2B đa phương thức (ảnh + âm thanh), nhưng ba câu hỏi chưa có
đáp án, và chúng quyết định nhánh **đọc hoá đơn** có khả thi không:

- Ảnh mất bao lâu, tốn thêm bao nhiêu RAM (nhiều khả năng hơn 0,96 GB đáng kể)?
- Chất lượng đọc **tiếng Việt có dấu** trên hoá đơn in nhiệt mờ — mô hình 2,3 tỉ tham số
  không phải OCR chuyên dụng.
- Âm thanh cần gói `flutter_gemma_speech` riêng hay đi thẳng qua Gemma?

**Đã điền:** mục **8.7** `AI_EDGE_FEATURE.md` (tiểu mục mới).

---

# CHẶNG 1 — Năm việc làm được ngay

Không cần brainstorm, không cần spec, không chờ dữ liệu. Mỗi việc một commit.

## 1.1 Neo ba ngưỡng tái phân bổ theo thu nhập — ✅ XONG 2026-09-21

> 🛑 **Và nó CHƯA TỪNG CÓ HIỆU LỰC cho tới cuối cùng ngày ấy.** Đầu vào
> `thuNhapMoiThang` khi đó tên `thuNhap3Thang` và cắt **ba tháng lịch liền
> trước**; đo trên CSDL dev thì giao dịch sớm nhất trong **toàn bộ** CSDL là
> **02/09/2026** — nên nó luôn bằng **0**, và `max(1% × 0, 50.000)` luôn trả
> đúng cái sàn mà việc neo sinh ra để thay thế. **Mã đúng, đầu vào chết.** Bộ
> test mù vì nó dựng sẵn ba tháng dữ liệu; thứ bắt được là một phép đo trên CSDL
> thật. Cửa sổ đã đổi sang **cuộn theo ngày** cùng ngày (`cuaSoNhinLai`) — xem
> mục **14** `PROJECT_CONTEXT.md`.
>
> ⚠️ Bài học chung: **một luật có thể đúng hoàn toàn về mã mà chưa bao giờ
> chạy**, nếu đầu vào của nó đến từ một cửa sổ mà dữ liệu thật không lấp đầy.

**Vấn đề:** luật tái phân bổ có sáu ngưỡng, chỉ **một** cái neo theo người dùng. Người
thu nhập 5 triệu và người 50 triệu dùng chung ngưỡng thâm hụt **50.000 đ** — với người
thứ hai, app dựng cả một kế hoạch cắt giảm cho tiền lẻ.

**Tệp:** `lib/features/ai_edge/domain/tai_phan_bo.dart`
**Test:** `test/features/ai_edge/domain/tai_phan_bo_test.dart` (đã có, thêm ca)

**Hiện trạng:**

```dart
const double kNguongThamHutTiLe    = 0.10;      // tỉ lệ  → GIỮ NGUYÊN
const double kNguongThamHutTuyetDoi = 50000;    // tuyệt đối → NEO
const double kDuDiaToiThieu        = 100000;    // tuyệt đối → NEO
const double kTranCat              = 0.25;      // tỉ lệ  → GIỮ NGUYÊN
const double kTranCatDaBiCat       = 0.15;      // tỉ lệ  → GIỮ NGUYÊN
const int    kBuocLamTron          = 10000;     // tuyệt đối → NEO

double nguongCoNghia(double thuNhapMoiThang) {    // ← mẫu đã đúng
  final motPhanTram = thuNhapMoiThang * 0.01;
  return motPhanTram > 50000 ? motPhanTram : 50000;
}
```

**Làm:** ba hàm mới cùng khuôn `nguongCoNghia`, nhận `thuNhapMoiThang`, trả về `max(tỉ lệ ×
thu nhập, hằng cũ)` — **hằng cũ thành sàn**, nên tài khoản chưa có thu nhập giữ nguyên
hành vi hôm nay. `taiPhanBoCua` đã nhận `thuNhapMoiThang`, không đổi chữ ký.

⚠️ **Giữ nguyên hai hằng tỉ lệ.** Chúng vốn không phụ thuộc quy mô thu nhập — neo chúng
là làm hỏng một thứ đang đúng.

⚠️ `kBuocLamTron` dùng ở **hai** chỗ: `lamTron10k()` và phép "làm tròn LÊN" trong vòng
chọn nguồn bù. Đổi một chỗ mà quên chỗ kia thì tổng cắt lệch vài nghìn — im lặng.

**Ca test bắt buộc:** cùng một trạng thái ngân sách, hai mức `thuNhapMoiThang` (5 triệu và
50 triệu) → hai kết quả khác nhau; `thuNhapMoiThang = 0` → **y hệt hành vi hôm nay** (sàn).

**Xong khi:** `flutter test test/features/ai_edge/` xanh, ca mới đỏ với bản sai (bỏ phép
neo). **Tài liệu:** mục 11.5 (1) — đổi ⭐ thành ✅ kèm ngày.

✅ **Làm xong 2026-09-21.** 7 ca mới, **không** thêm tệp test; bộ đầy đủ **3113/3113,
1 skip**; `flutter analyze` **26 issue, 0 error**. Không đổi schema, không đổi payload,
không đụng giao diện. Ba điều lượt này học được, ghi đủ ở mục **11.5 (1)**
`AI_EDGE_FEATURE.md`:
- Tỉ lệ chọn sao cho cả ba **xoay quanh cùng mốc 5 triệu/tháng**, nên dưới mốc ấy hành vi
  không đổi một li.
- `buocLamTron` cần thêm vế **kéo lên họ 1·2·2,5·5** mà hai ngưỡng kia không cần — nó là
  con số người dùng **đọc**, không phải con số đem đi so sánh. Dùng lại `buocTron` của
  `du_bao_dong_tien.dart` (nay công khai) thay vì chép bản thứ hai.
- ⭐ **Luật C4 (`kDuDiaToiThieu`) đã chết từ trước**, bị C5 nuốt trọn ở mọi mức thu nhập.
  Bản sai có chủ ý lộ ra điều đó — ca hành vi đầu tiên viết cho C4 **vẫn xanh** khi chưa
  neo gì. Đừng viết ca hành vi cho C4.

## 1.2 Ví chọn sẵn theo danh mục — ✅ XONG 2026-09-21

**Vấn đề:** `chonViChonSan` chọn **ví mặc định**, giống nhau mọi lúc — không theo danh
mục, không theo giờ. Thói quen thật có mẫu (ăn uống → tiền mặt, mua sắm → ví ngân hàng).

**Tệp:**
- `lib/features/transaction/domain/vi_chon_san.dart` — thêm tham số tuỳ chọn
- chỗ gọi ở `add_transaction_page.dart`
- **Test:** `test/features/transaction/vi_chon_san_test.dart` (đã có)

**Chữ ký hiện tại:**

```dart
ViChonSan<T> chonViChonSan<T>(
  List<T> danhSach, {
  required bool Function(T) laMacDinh,
})
```

**Làm:** thêm `T? Function(String danhMucId)? viHayDung` (mặc định `null` → hành vi cũ
nguyên vẹn). Phép tra là **đếm tần suất** trên lịch sử giao dịch của danh mục ấy, đặt ở
`transaction/data/` (không ở `ai_edge/` — nó đọc bảng giao dịch, test quét 14 cấm).

⚠️ **Ngưỡng mẫu tối thiểu** (đề nghị **5** giao dịch cùng danh mục) và **tỉ lệ áp đảo**
(đề nghị ≥ 60 %). Dưới ngưỡng → trả `null` → rơi về ví mặc định. Không có ngưỡng thì một
giao dịch lẻ cũng đổi ví chọn sẵn, và người dùng thấy ví nhảy lung tung.

**Ca test bắt buộc:** 9/10 giao dịch Ăn uống dùng ví Tiền mặt → chọn Tiền mặt; 3 giao
dịch → dưới ngưỡng, giữ ví mặc định; 5 giao dịch chia 3–2 → dưới tỉ lệ áp đảo, giữ mặc
định; `viHayDung == null` → **y hệt hành vi hôm nay**.

✅ **Làm xong 2026-09-21.** 15 ca mới ở **2 tệp mới** (`domain/vi_hay_dung_test.dart` 10 ca,
`presentation/vi_theo_danh_muc_test.dart` 5 ca); bộ đầy đủ **3128/3128, 1 skip**;
`flutter analyze` **26 issue, 0 error**; nghiệm thu máy ảo trên dữ liệu thật. Không đổi
schema, không đổi payload. Chi tiết ở mục **11.5 (2)** `AI_EDGE_FEATURE.md`.

⚠️ **Chữ ký kế hoạch phác ở trên là SAI và tôi đã không theo.** `chonViChonSan` chạy lúc
**mở trang**, khi chưa có danh mục nào để tra — nhét `viHayDung` vào đó thì tham số không
bao giờ dùng được. Luật mới nằm ở tệp riêng `domain/vi_hay_dung.dart` và trang gọi nó
trong `_chonDanhMuc`. `chonViChonSan` **giữ nguyên không sửa một dòng**.

⚠️ Hai con số "đề nghị" của kế hoạch giữ nguyên (**5** giao dịch, **60 %**), nhưng tỉ lệ
là **vượt** chứ không **chạm** — chính ví dụ của kế hoạch đòi thế: 3 trên 5 đúng bằng 0,6
mà kế hoạch xếp nó vào nhóm "giữ mặc định".

## 1.3 Gói số cho HOÁ ĐƠN — ✅ XONG 2026-09-21 (tệp mẫu cho 1.4 và 1.5)

**Vấn đề:** `bill` có **27 tệp, 10 hàm domain** mà AI **chưa chạm gì** — không một gói số
nào cho hoá đơn.

**Tệp mới:** `lib/features/ai_edge/domain/goi_so_hoa_don.dart`
**Test mới:** `test/features/ai_edge/domain/goi_so_hoa_don_test.dart`
**Mẫu chép theo:** `goi_so_ngan_sach.dart` (`class GoiSoNganSach extends GoiSo`)

**`GoiSo` đòi bốn thứ:** `String get man` · `List<SoLieu> get soLieu` ·
`bool get thieuDuLieu` · `NhanXet mauCau()`.

**Số lấy từ (đã tính sẵn, đừng tính lại):**

| Hàm | Chữ ký | Cho gì |
|---|---|---|
| `summarizeBills` | `BillSummary summarizeBills(List<Bill> bills, DateTime now)` | số liệu thẻ tổng |
| `billDisplayStatusOf` | → `BillDisplayStatus` (**năm** trạng thái) | đếm quá hạn / sắp tới hạn |
| `kyKeTiepCua` | `KyKeTiep kyKeTiepCua(Bill current)` | kỳ kế tiếp |
| `bill_an_han.dart` | — | ân hạn |

⚠️ **Đọc `docs/bill/BILL_DOCUMENTATION.md` mục 6.7 trước**: câu "đã trả chưa" **tách làm
hai** (*còn phải trả* vs *đã có khoản chi*) và có **một** định nghĩa duy nhất ở
`bill_pay_status.dart`. Đừng viết vị từ thứ hai.

⚠️ **Nhánh thiếu dữ liệu là một câu THẬT**, không ẩn khối (mục 1 `AI_EDGE_FEATURE.md`).

**Ca test bắt buộc:** *"mẫu câu tự qua bộ kiểm số ở mọi nhánh"* — **mọi** gói số đều phải
có ca này (bẫy 4.1); thiếu nó thì P3 sẽ rơi về một câu mà `kiemSo` cũng chặn.

✅ **Làm xong 2026-09-21, kèm KHỐI NHẬN XÉT trên trang Hoá đơn** — người dùng chốt làm
trọn thay vì chỉ gói số, vì một gói số không có nơi gọi là mã chết (lệ "quét API mới thêm
có 0 chỗ gọi" ở `CLAUDE.md`). 18 ca mới ở **2 tệp mới**; bộ đầy đủ **3146/3146, 1 skip**;
`flutter analyze` **26 issue, 0 error**; nghiệm thu máy ảo xong. Màn Stitch
**`179dbd70b0fd4b6a97df6b7d2c38d0e2`**. Chi tiết và bốn cái bẫy ở **mục 12**
`AI_EDGE_FEATURE.md` — đáng nhớ nhất: khối lấy bớt chiều cao `Expanded` làm **trạng thái
rỗng tràn 73 px** ở khổ màn thấp, thứ chỉ lộ ra vì một ca test cũ chạy ở khổ 600.

## 1.4 Gói số cho MỤC TIÊU (mở rộng) — ⚠️ MỘT PHẦN, 2026-09-21

⭐ **Ba dòng riêng trong bảng mục 11 — *"vì sao trễ"*, *"ví thiếu tiền trích"*, *"dự báo
ngày đạt"* — là MỘT việc.** `goal` có 14 hàm domain mà gói số hiện tại mới dùng 1.

**Tệp:** `lib/features/ai_edge/domain/goi_so_muc_tieu.dart` (**đã có**, mở rộng)

**Ba hàm đã tính sẵn** — ⚠️ câu gốc ở đây viết *"và đang im lặng"*, **SAI**, xem đính chính bên dưới:

```dart
DateTime? duBaoHoanThanh(GoalEntity goal, DateTime now)  // goal_forecast.dart
                                  // dự báo theo NHỊP TÍCH LUỸ THẬT, không phải kế hoạch
String? canhBaoViKhongDu(...)     // goal_wallet_shortfall.dart
                                  // ví tích luỹ không đủ cho các mục tiêu trỏ vào nó
ThongKeMucTieu? thongKeMucTieu(...) // goal_stats.dart — số lần nạp, TB mỗi lần
String tenDonViKy(String? chuKy)    // goal_stats.dart — nhãn đơn vị kỳ
```

✅ **`duBaoHoanThanh` đã vào gói số 2026-09-21** — câu thêm vế *"Theo nhịp hiện tại cần
thêm N ngày"*, chỉ hiện khi **chậm kế hoạch hoặc quá hạn**. 5 ca mới, bộ đầy đủ
**3151/3151, 1 skip**. Chi tiết ở mục **13** `AI_EDGE_FEATURE.md`.

🛑 **Hai hàm kia KHÔNG làm được ở lượt này, và lý do đáng ghi: ba dòng ấy KHÔNG phải một
việc.** Đo bằng mã: `GoalLoaded` chỉ mang `goals` + hai con số tổng.

| Hàm | Cần gì | Trang **danh sách** có chưa | App đã dùng ở đâu |
|---|---|---|---|
| `duBaoHoanThanh` | chính `GoalEntity` | ✅ → đã làm | `goal_detail_page.dart:1082` |
| `thongKeMucTieu` | danh sách `KhoanTichLuy` | ❌ phải nghe thêm `watchGoalTransactions` | `goal_stats_card.dart:34` |
| `canhBaoViKhongDu` | tên ví, số dư ví, tổng mục tiêu trỏ vào ví | ❌ state không mang ví nào | `goal_detail_page.dart:221` |

⚠️ **ĐÍNH CHÍNH 2026-09-21:** câu *"ba hàm đã tính sẵn và đang im lặng"* ở đầu mục 1.4 là
**SAI** — cả ba đang chạy thật trên trang **Chi tiết mục tiêu**. Thứ im lặng là **gói số
của AI**, không phải app. Nên việc còn lại của 1.4 không phải "bật một hàm nằm im" mà là
**nhắc lại trên trang danh sách** — một quyết định về trùng lặp. Sai lầm đến từ một lệnh
`grep` trả về rỗng mà không kiểm lại bằng đường thứ hai.

Hai cái sau đòi **mở thêm nguồn dữ liệu cho trang** (state + repository) — một hạng mục
riêng, chưa làm. ⚠️ Và nên cân nhắc trước khi làm: `canhBaoViKhongDu` cảnh báo một **mâu
thuẫn dữ liệu thật** (tiền tích luỹ bị tiêu mất), có lẽ xứng một **thông báo** chứ không
phải một vế trong câu nhận xét.

⚠️ `duBaoHoanThanh` và `canhBaoViKhongDu` trả **nullable** — `null` nghĩa là *chưa đủ căn
cứ*, và khi ấy câu **không được nhắc tới** nó. Đừng `?? 0` hay `?? DateTime.now()`: đó
đúng là lỗi mà mục 3.30 `ANALYTICS_FEATURE.md` đã chặn (`thayDoiTaiSan` trả `null` thay
vì in một khoản tăng bịa).

## 1.5 Gói số cho VÍ — ✅ XONG 2026-09-21

**Việc:** *"giải thích vì sao số dư lệch"*.
**Tệp mới:** `lib/features/ai_edge/domain/goi_so_vi.dart`

**Số lấy từ:** `wallet/domain/dieu_chinh_so_du.dart` — **nơi duy nhất** định nghĩa phép
tính khoản bù, khuôn ghi chú, và phép nhận dạng ngược; và `vi_tinh_vao_tong.dart`.

⚠️ Phép nhận dạng khoản điều chỉnh đòi **cặp** điều kiện (không danh mục **và** tiền tố
`Điều chỉnh số dư`) — riêng chân danh mục **không đủ**: 17 hàng trên server đang trống
danh mục thật.

⚠️ **G37**: `wallets.balance` là *cache của một công thức* (`TransactionDao.tongTheoVi`),
không phải dữ liệu gốc. Gói số đọc `balance` thì đọc qua `viTinhVaoTong` như mọi chỗ khác.

---

# CHẶNG 2 — Function calling, bắt đầu từ việc AN TOÀN NHẤT

> 🛑 **NÚT THẮT — cả chặng 2 đứng SAU P3, dù tệp này xếp nó trước** (ghi
> 2026-09-21, sau khi nửa đầu 2.1 xong).
>
> Thứ tự trong tệp này gợi ý chặng 2 và chặng 4 (P3 — cài mô hình) độc lập nhau.
> **Không.** Nửa sau của 2.1 đòi *"20 câu lệnh mẫu → đếm bao nhiêu lần chọn đúng
> hàm"*, mà phép đo ấy **cần một mô hình thật mới đo được**; 2.2 và 2.3 cũng vậy,
> và 3.1 thì cần chính lớp dịch câu mà 2.1 dựng ra. Tức **P3 chặn bốn việc**.
>
> ⚠️ Điều này kéo ngược với một quyết định khác đang có hiệu lực: P3 đang được
> xếp **hoãn có chủ ý** vì nó thiên về phần demo, trong khi người dùng đã chốt
> **ưu tiên giá trị người dùng**. Hai điều ấy không tự hoà giải được — **chỉ
> người dùng quyết**. Giữ P3 hoãn thì mọi việc còn lại dồn hết về nhóm *"cần
> chốt phạm vi"*, và những việc **không** cần mô hình là: 3.1 (gắn danh mục hàng
> loạt — bản luật), 3.2, 3.3, ~~đề xuất tạo ngân sách~~ (⚠️ **đang làm dở**: Task 1–5
> xong 2026-09-21, còn **Task 6** dựng thẻ — kế hoạch
> `2026-09-21-cua-so-nhin-lai-va-de-xuat-tao-ngan-sach.md`), cùng bốn chỗ cá nhân hoá ở
> mục 11.5 `AI_EDGE_FEATURE.md`.
>
> Đừng lặng lẽ bắt đầu nửa sau 2.1 rồi phát hiện không nghiệm thu được.

## 2.1 ⭐ Tìm kiếm bằng câu — *"tháng trước tôi tiêu gì trên 500k"* — ⚠️ NỬA ĐẦU XONG 2026-09-21

**Vì sao đây là việc đầu của hạ tầng C, không phải nhập bằng câu:**

- Chiều **đọc** — sai thì kết quả trống, người dùng thấy ngay; **không ghi gì**.
- Đầu ra mô hình là một **bộ lọc**, kiểm được bằng schema chứ không cần `kiemSo`.
- Nó cho **phép đo tỉ lệ chọn đúng hàm** mà 2.2 và 2.3 cần trước khi mở chiều ghi.

### ✅ Nửa đầu — mở rộng bộ lọc (xong 2026-09-21)

Spec `docs/superpowers/specs/2026-09-21-so-giao-dich-pham-vi-ky-va-loc-tien-design.md`,
kế hoạch thi công `…/2026-09-21-so-giao-dich-pham-vi-ky-va-loc-tien.md`. Bốn commit,
31 ca mới, `flutter test` **3200/3200, 1 skip**.

⚠️ **Mục này từng gộp "khoảng tiền" và "khoảng ngày" làm một việc — khảo sát lật
điều đó.** Trang Sổ giao dịch nạp dữ liệu **theo từng tháng**, nên hai vế không cùng
độ khó: khoảng tiền có nghĩa trọn vẹn, còn khoảng ngày bị kẹp trong tháng đang xem và
tạo **hai bộ điều khiển thời gian triệt tiêu nhau** trên cùng một trang. Người dùng
chốt **lối B**: khoảng ngày **thay luôn** phép buộc-theo-tháng, mượn `Ky` và
`ChonPhamViSheet` của trang Phân tích.

Nên `TransactionFilter` nay là:

```dart
TransactionTypeFilter type;  String? walletId;  String? categoryId;  String query;
KhoangTien? khoangTien;   // ← mới; khoảng NGÀY không nằm ở đây mà là nguồn dữ liệu
```

### ⬜ Nửa sau — bộ hàm cho function calling (chưa làm)

> ⚠️ **Hạ tầng tool ĐÃ CÓ từ lát 4b (2026-09-23)** — `CongCu` / `KhaiBaoCongCu` / `BoCongCu`, vòng
> lặp `hoiBangCongCu` (trần 3 lời gọi, thang lùi L1–L4), `GoiSoTraCuu`; thêm một tool là **một
> adapter + một hàm dựng hàng**, không phải dựng lại hạ tầng. Nhưng **tool tìm giao dịch** của mục
> này (ánh xạ sang `TransactionFilter` + `Ky`) thì **vẫn chưa làm**: bốn tool của 4b chỉ trả tổng
> hợp theo danh mục / ngân sách / hoá đơn / ví, không liệt kê giao dịch. Phép đo *"chọn đúng hàm"*
> của 4b là 8/8 câu mỗi máy với **bốn** tool — chưa phải 20 câu lệnh tìm kiếm.

**Tệp:** một hàm khai `Tool` ánh xạ sang `TransactionFilter` + `Ky`. Hai thứ ấy nay
đã đủ trường để mô hình chọn, nên phần còn lại thuần là lớp dịch câu → tham số.

**Phép đo phải ghi lại:** 20 câu lệnh mẫu → đếm bao nhiêu lần **chọn đúng hàm** và
**đúng tham số**. Con số ấy quyết định có mở 2.2/2.3 hay không, và là một bảng cho báo cáo.

## 2.2 Nhập giao dịch bằng câu *(ghi tầng 3)*

Bản **luật** chạy trước (regex số tiền + ngày + `CategorySuggestionEngine`) — tức thì,
**không cần mô hình**; mô hình chỉ để hiểu câu lạ (*"làm tô phở hết bốn chục"*).

⚠️ `kiemSo` **không dùng được** ở chiều ghi (không có gói số để đối chiếu).
⚠️ Xác nhận **từng cái**, hiện rõ số đã hiểu — `40k` là 40.000 hay 40.000.000?
⚠️ **Chốt bảng quy đổi `k` / `củ` / `chai` với người dùng trước khi viết mã.**
**Cần brainstorm + spec.**

## 2.3 Tạo hoá đơn · mục tiêu · ngân sách bằng lệnh *(ghi tầng 2)*

⭐ Ba dòng trong bảng mục 11, nhưng là **một việc**: thêm ba hàm tầng 2 vào bộ hàm của
2.1–2.2. Sai thì nhiễu chứ không mất tiền → xác nhận **một hộp thoại có số cụ thể**.

⚠️ **Form hiện LỆNH, không hiện LỜI** — mô hình có thể viết *"tạo hoá đơn 500 nghìn"*
trong khi tham số thật là `5000000`.
⚠️ **Một lệnh, một bước** — không cho chạy chuỗi *"tạo ngân sách rồi chuyển tiền vào"*.
🛑 Không hàm bật `auto_pay`, trích tự động, hay xoá.

---

# CHẶNG 3 — Phân loại tự động

## 3.1 Gắn danh mục hàng loạt

Vá **38 %** dữ liệu mù (15/39 giao dịch, đo 2026-09-20). Chiều ghi **tầng 1** → duyệt
**cả lô**, một màn. App đã có `CategorySuggestionEngine` làm **bản đối chứng** — so hai
bên là phép đo sạch cho báo cáo. **Cần brainstorm + spec.**

## 3.2 Học từ khoá cho danh mục

AI quan sát *ghi chú → danh mục đã chọn* rồi tự thêm `keyword`. **AI cải thiện chính hệ
luật** thay vì thay nó.

## 3.3 Essentiality học từ phản hồi

Việc **duy nhất** trong bốn việc mục 11.4 dùng được **dữ liệu đã có**
(`AiRebalancingFeedbacks`). Thay `essentiality = 0,5` cứng. ⚠️ Giữ 0,5 tới khi đủ mẫu.

---

# CHẶNG 4 — P3

✅ **NGƯỜI DÙNG CHỐT LỐI B ngày 2026-09-21** — kế hoạch P3 đã sửa theo (banner đầu tệp,
Task 7 Step 4, Task 8 Interfaces).

Mô hình phục vụ **một chỗ duy nhất**: màn Trợ lý AI. Bốn khối Nhận xét **giữ mẫu câu** —
hiện tức thì, không chờ 2,3 giây, không "nhảy" từ mẫu sang câu mô hình.

**Lý lẽ:** P1 đo được câu mô hình ở khối Nhận xét **gần bằng mẫu câu** (khác giọng văn,
không khác thông tin — mẫu câu còn gọn hơn), mà giá là 2,3 s mỗi khối + 2,41 GB tải. Mô
hình chỉ hơn hẳn ở **hỏi đáp tự do**, thứ mẫu câu không làm được.

⚠️ **Đảo ngược được bằng một commit** — bỏ dấu chú thích khối đăng ký DI ở Task 7. Đừng
làm nếu người dùng chưa đổi ý.

Task 0 cần người dùng nghiệm thu màn Stitch.
**Kế hoạch:** `2026-09-20-ai-edge-p3-cam-slm.md`, 10 task.

---

# CHẶNG 5 — Phần còn lại

| Việc | Điều kiện | Ghi chú |
|---|---|---|
| **Giải thích 9 biểu đồ** | không | 9 khối × một hàm gói số. ⚠️ **đừng dùng vision** (11.1); gói phải **tính sẵn** kỳ cao/thấp nhất, % thay đổi, xu hướng — nếu không mô hình tự tính và `kiemSo` chặn |
| **Đề xuất tạo ngân sách** | không | ✅ **XONG 2026-09-21** — trọn sáu Task; thẻ "Chưa đặt ngân sách" đã nghiệm thu trên máy ảo với dữ liệu thật. 🛑 Câu *"`suggestAmount` đã có sẵn con số"* từng đứng ở ô này là **SAI**, và nó suýt làm cả tính năng được xây trên một hàm luôn trả `null`: cửa sổ cũ là ba tháng lịch đã đóng, mà CSDL không có hàng nào trước 02/09/2026. Đo trước, đừng tin ô ghi chú |
| **Nhịp chi theo ngày** + **ngưỡng 70/90 %** | 3 kỳ | ⭐ **làm chung** — một phép học, hai chỗ dùng (`budget_visuals.dart`: `_cautionAt`, `_criticalAt`) |
| **Tự đề xuất cờ Cố định** | vài lượt từ chối | dùng chung dữ liệu với 3.3 |
| **Phát hiện hoá đơn định kỳ** | ~3 kỳ lặp | ⚠️ tuyệt đối **không tự bật `auto_pay`** |
| **Dự đoán số tiền hoá đơn kỳ tới** | 3 kỳ | hồi quy nhỏ, không cần LLM |
| **Bất thường theo danh mục** | 20–30 giao dịch/danh mục | xa nhất; danh mục đông nhất hiện có **6** |
| **Chọn khối Phân tích đáng xem** | không (mức rẻ) | soát khối nào chưa tự ẩn khi rỗng |
| **Tần suất thông báo theo phản ứng** | dữ liệu phản ứng | ⚠️ **không đụng `dedupeKey`**; giữ nguyên `luonBao` |
*(Đo NPU và vision/audio đã tách lên **chặng 0** — chúng không phụ thuộc gì.)*

---

# VIỆC NGOÀI MẢNG AI — gom ngày 2026-09-21

⚠️ Mọi thứ trên đây là **việc của mảng AI**. Dự án còn những việc khác đang mở, và bản
đầu của tệp này không gom chúng — người dùng phải hỏi lại mới thấy. Danh sách đầy đủ ở
đây; **không cái nào chặn mảng AI**.

## Hai mục lỗ hổng còn mở — cả hai HOÃN CÓ CHỦ Ý

Đếm bằng máy: **47 mục G, 45 đã đóng.** Hai mục còn lại đều đã cân nhắc và chấp nhận:

| Mục | Nội dung | Trạng thái |
|---|---|---|
| **G18** | `TransactionDao.watchByGoal` có nhánh dự phòng so bằng **TÊN** mục tiêu (`note LIKE '%Tích lũy mục tiêu: <tên>%'`) cho hàng không có `goal_id` — mang đúng khuyết điểm mà `goal_id` sinh ra để chữa: mục tiêu tên `"Mua"` nuốt cả `"MuaXe"` | ⏸️ **THU HẸP DẦN** — hàng mới đều có `goal_id`, nên nhánh này teo dần theo thời gian |
| **G23** | `DefaultCategorySeeder` sao chép từ hàng mặc định **đã có trên máy này**, mà pull là tăng dần theo `since` — máy chỉ biết một phần bộ mặc định của server | ⏸️ **CHẤP NHẬN ĐƯỢC** |

Đừng "dọn dẹp" hai mục này nếu không có lý do mới — chúng đã được quyết một lần.

## Bảy việc UX hoãn *(A6 đã đóng ở P2 Task 14)*

Nguồn: mục "⏸ Để làm sau" `docs/superpowers/plans/2026-09-19-ux-ui-danh-sach-viec.md`.
⚠️ Người dùng chốt *"lưu lại các phần đó để làm sau"* — **không làm cái nào cho tới khi
họ gọi tên lại.**

**Cần người dùng chốt trước (đừng tự quyết):**

1. **A5** — nút "Quét" ở Trang chủ hiện là stub `SnackBar`: giữ và làm thật, hay gỡ.
2. **A11 còn lại** — **9 handler rỗng** ở 4 tệp: `ai_chat_page` (5 → **đóng ở P3 Task
   8**), `login_page` Google/Apple (2, backend chưa có OAuth), `forgot_password_page`
   "Liên hệ hỗ trợ" (1, chưa có kênh hỗ trợ), `add_transaction_page` menu ⋮ (1). Danh
   sách sống trong `test/core/ui/khong_co_nut_chet_test.dart` — **đỏ nếu lệch mã**.
3. **E6** — nhắc "ví âm" hằng ngày: giữ / đổi hằng tuần / chỉ báo khi **chuyển** sang âm.
   ⚠️ Khoá chống trùng sống **90 ngày**, nên bỏ ngày khỏi khoá là **im 90 ngày** kể cả
   khi ví âm lại.
4. **E2** — mục lục hoặc tab con cho trang Phân tích (15 loại khối — đếm bằng máy 2026-09-21). Đụng bố cục → **vẽ Stitch
   trước**, brainstorming trước.

**Không bị chặn, chỉ chưa làm:**

5. **E1** — skeleton tải cho tab Phân tích; vẽ Stitch trước.
6. **E4** — thay **176** `SnackBar` bằng toast. Kênh `ThongBaoNhanh → AppToast` đã có từ
   E3; phần thay dần đụng **hàng trăm** khẳng định test.
7. **G2 (UX)** — kiểm bố cục với `textScaler` 1.3.

## Việc của người dùng, không phải của agent

Ẩn hoặc xoá màn Stitch cũ `20700200afbc4d5f98962bc9be79b780` *"Thêm giao dịch - Gợi ý
danh mục AI"* — MCP Stitch **không có lệnh xoá/ẩn màn**.

---

# Quyết định đã chốt, và thứ còn lại

✅ **Ưu tiên: GIÁ TRỊ NGƯỜI DÙNG, không phải phần demo** — người dùng chốt 2026-09-21.
Nên thứ tự trên **giữ nguyên**: không đưa P3 hay "giải thích biểu đồ" lên sớm dù chúng
dễ gây ấn tượng khi trình bày.

✅ **Lối B cho P3** — người dùng chốt 2026-09-21. Kế hoạch P3 đã sửa theo.

**Không còn quyết định nào chờ người dùng.** Mọi việc trong tệp này làm được ngay khi
tới lượt, trừ bốn việc UX ghi rõ "cần người dùng chốt trước" ở mục việc ngoài mảng AI.

# Ba chỗ cố ý KHÔNG có trong danh sách

- 🛑 **Dư nợ theo người** — **người dùng gạch khỏi kế hoạch ngày 2026-09-21.** Bản đầu của
  tệp này xếp nó vào chặng 5 và tự mô tả là *"mở lại A8 #9 đã bỏ"*, trong khi người dùng
  đã chốt **bỏ hẳn** A8 #9 (biến động khoản vay) và #11 (Sankey) ngày 2026-09-16 kèm lời
  dặn đừng đề xuất lại — xem banner mục **7.1** `docs/ANALYTICS_FEATURE.md`. Một dòng kế
  hoạch tự xưng là mở lại một mục đã đóng thì **chính nó là lời đề xuất lại**, bất kể lý
  lẽ kỹ thuật bên trong có khác hay không. **Đừng dựng lại dòng ấy**, và đừng mở hàng đợi
  `CAN-LAM/` để xin dư nợ gốc / lãi suất / kỳ hạn.
- **Tóm tắt đầu báo cáo PDF** — PDF **đi ra ngoài** và font nhúng **thiếu glyph**
  (`→ ▲ ▼` bị bỏ im lặng từ 2026-09-09). Nếu làm thì bắt buộc chạy câu qua bộ quét glyph
  ở `xuat_tep_test.dart`. Mục 11.2.
- **AI viết câu thông báo** — cần ngắn, đoán được, `dedupeKey` ổn định. Mục 11.2.

> ✅ **1.5 xong 2026-09-21.** `GoiSoVi` + khối Nhận xét trên trang Quản lý ví, màn Stitch
> `6adf2ad12af246cb87bb1bcc52ddb2b2`. Câu trả lời đúng câu *"vì sao tổng không khớp"*:
> ví tắt cờ `includeInTotal` và ví lưu trữ. 18 ca mới ở 2 tệp mới; bộ đầy đủ
> **3169/3169, 1 skip**. Chi tiết ở **mục 14** `AI_EDGE_FEATURE.md`.
>
> ⚠️ Kế hoạch ghi 1.5 là *"giải thích vì sao số dư lệch"* và trỏ vào
> `dieu_chinh_so_du.dart`. **Bản thi công đi hướng khác**: từ G37 (2026-09-13) số dư ví
> suy từ sổ giao dịch nên nó không còn "lệch" nữa — khoản điều chỉnh là giao dịch tường
> minh. Thứ người dùng thật sự thấy lệch là **tổng tài sản so với tổng các ví nhìn thấy**,
> và đó là thứ khối này giải thích.
