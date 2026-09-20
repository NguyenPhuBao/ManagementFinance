# Client-app — Việc còn dang dở & rủi ro đã biết

**Cập nhật:** **2026-09-20** (**AI Edge-SLM P2 XONG** — toàn bộ 17 task; tài liệu tính năng `docs/AI_EDGE_FEATURE.md`, tường thuật ở mục 14 `PROJECT_CONTEXT.md`. Task 16 cuối cùng thêm thông báo `budgetRebalance` — loại thứ **19** của enum, mục **5g** `NOTIFICATION_FEATURE.md`. **Không mở lỗ hổng nào trong cả P2**; schema lên **v24** với hai thứ **cục bộ** (cột `categories.ai_co_dinh`, bảng `AiRebalancingFeedbacks`), **payload không đổi**. Hai việc UX gắn với mảng này: **A6** thẻ "Insight AI" chữ tĩnh — ✅ **đóng 2026-09-19** (Task 14: khối Nhận xét gắn vào **bốn** màn Ngân sách · Phân tích · Mục tiêu · Trang chủ, thẻ cũ xoá hẳn); **A11** năm handler rỗng của `ai_chat_page` — **vẫn mở**, đóng ở **P3** cùng màn Trợ lý AI. Bước tiếp là **P1 spike** khi người dùng cắm máy Snapdragon 8 Gen 3) · trước đó **2026-09-19 tối** (**bắt đầu mảng AI Edge-SLM** — P0 nâng Flutter 3.47.5 xong `03fe03a`) · trước đó **2026-09-19** (**mở rồi đóng G47** — thẻ hoá đơn và bảng tra tên của ngân sách mất tên danh mục mặc định toàn cục / đã xoá mềm, cùng họ G41 ở ba bản chép tay khác của cùng truy vấn; lộ ra ở mục E8 của lượt đánh giá UX cùng ngày. Đếm lại bằng máy: **47** mục G, **45** đã đóng, còn **hai** (G18, G23). Bảng tóm tắt **thiếu G45, G46** từ 2026-09-18 — bổ sung cùng lượt. Lượt UX ấy còn để lại **A12** và **E6** trong `docs/superpowers/plans/2026-09-19-ux-ui-danh-sach-viec.md`, **chưa** mở mục G vì chưa chốt lối sửa — ✅ **A12 đã chốt và sửa 2026-09-19**: phím `.` bỏ khỏi lưới, nhưng chốt thật nằm ở `_saveTransaction` vì lỗi có **hai cửa** và chế độ sửa vẫn nạp được chuỗi có dấu chấm từ `editing.amount.toString()`; xem khối "A12" mục 14 `PROJECT_CONTEXT.md`. **E6** vẫn chờ chốt. ✅ **Nhóm D — cấu trúc menu — cũng xong cùng ngày và KHÔNG mở mục G nào**: sáu chỗ hỏng tìm được đều đóng ngay trong ngày. Hai trong số ấy lộ ra lúc **thiết kế** (push-từ-ngoài-shell, hằng `nhanhThanhTab`), ba lúc **nghiệm thu máy ảo** (hai FAB chồng nhau, trang Ngân sách thành ngõ cụt, "Vùng nguy hiểm" rơi vào giữa trang Cá nhân), và **một do người dùng báo** — trang Quản lý danh mục **mất hẳn lối vào qua menu** vì nhóm module rời tab Cá nhân mà drawer chưa bao giờ có mục ấy. Lần theo báo cáo ấy còn ra hai lỗi nữa: nút bút chì trên avatar **chưa bao giờ bấm được** (không `InkWell`, tức nút **không có handler** — lưới quét nút chết chỉ tìm *handler rỗng*), và avatar **vòng đen trống** ở hai chỗ A9 bỏ sót. Tường thuật đầy đủ ở mục 14 `PROJECT_CONTEXT.md`) · trước đó **2026-09-18** (**đóng G26 bằng một quyết định sản phẩm** — nhóm **bỏ hẳn** liên kết ngân hàng, nên màn duyệt giao dịch ngân hàng thôi là việc còn thiếu. Phần client gỡ cùng ngày: màn mockup `bank_link_page.dart` — **chưa bao giờ gọi một endpoint nào**, số điện thoại và sáu ô OTP điền sẵn ghi cứng trong `initState` — cùng thẻ "LIÊN KẾT NGÂN HÀNG" ở màn Quản lý ví, hai route, và `RealtimeEvent.giaoDichNganHang`. Backend **vẫn phát** `bank_transaction.incoming`, nên client phải bỏ qua nó êm thấm, đúng nhánh `null` sẵn có cho mọi tên lạ. ⚠️ **Ba thứ giữ nguyên, cố ý**: enum `WalletType.banking`, ba cột SQLite `provider`/`bank_tran_id`/`bank_casso_id`, và phép loại ví `banking` khỏi `tinhLaiSoDu` — cả ba bảo vệ **hàng cũ kéo về**, không bảo vệ một tính năng. ⚠️ **Đừng viện G26 để mở `status`/`provider` vào hợp đồng đồng bộ** — đoạn "Bán kính nếu làm" của mục ấy nay là ảnh chụp lịch sử. **Schema không đổi**, vẫn v23; **payload không đổi**. Đếm lại bằng máy: **46** mục G, **44** đã xử lý, còn **hai** (G18, G23) — con số giữ nguyên vì G26 vốn đã mang dấu ✅. Cùng ngày, trước đó: **mở rồi đóng G46** — lượt soát nối tiếp G45, lần này quét **cả app**: lỗ hổng trần số chữ số **không phải chuyện riêng của ví**. Tám cột tiền đều là numeric(15,2), và **bốn mảng còn lại** (giao dịch, hoá đơn, mục tiêu, ngân sách) đều không giới hạn số chữ số. Nặng nhất là **giao dịch** — người dùng ghi hàng ngày, bàn phím **tự vẽ** nên inputFormatters không với tới, lại có phím **000**. Nay phép gõ tách thành hàm thuần themPhimSoTien, và có **test quét lib/ thứ tám** để ô tiền mới không mở lại lỗ hổng. ⚠️ **Lần thứ BA trong cùng ngày** một trần số chữ số biến giá trị lớn nhất thành **hợp lệ đạt tới được** rồi lộ ra bố cục chưa từng thử với giá trị ấy: ở cỡ 48, con số dài nhất **ngắt thành hai dòng** — không sọc vàng, không exception, `Text` chỉ lặng lẽ ngắt dòng, nên ca test phải đo **chiều cao thật**. Mọi ràng buộc khác đã kiểm và an toàn. Đếm lại: **46** mục G, **44** đã đóng, còn **hai** (G18, G23). Cùng ngày, trước đó: **mở rồi đóng G45** — **sáu lỗ hổng của mảng ví**, tìm được bằng một lượt soát đối chiếu **từng ràng buộc PostgreSQL với chốt tương ứng phía client**, không đến từ báo lỗi nào. Nặng nhất: ô nhập số dư không giới hạn chữ số, mà `Balance` là `numeric(15,2)` — tràn cho SQLSTATE `22003`, backend không có nhánh cho mã ấy nên trả `DB_ERROR`, và danh sách lỗi vĩnh viễn của client là **danh sách trắng** nên ví bị **gửi lại ở mọi chu kỳ đồng bộ**. Cùng vòng lặp mà G31 và G14 sinh ra để chặn. Kế đó: `softDelete` không chặn ví gắn **hoá đơn** (server để `ON DELETE RESTRICT`, và đo được **một ví xoá được ngay** trên dữ liệu thật), phép đếm giao dịch bỏ sót **khoản chuyển đến**, thông báo "điều chuyển số dư về 0đ" dẫn tới ngõ cụt từ sau G37, `currency` là cột CHECK duy nhất chưa được `walletForPush` che, và thiếu chốt cấm đặt ví **đã lưu trữ** làm mặc định. ⚠️ Lượt vá sinh ra **hai lỗi nữa, cả hai chỉ máy ảo thấy** — tràn bố cục 70px vì giới hạn mới biến một trạng thái vô nghĩa thành **hợp lệ đạt tới được**, và cỡ chữ không co vì widget mới đọc controller một lần. ⚠️ Một bản sai lật kết luận: thứ chặn tràn là **`Flexible`**, không phải bậc thang cỡ chữ — ép cỡ chữ cố định mà hai ca bố cục **vẫn xanh**. Đếm lại bằng máy: **45** mục G, **43** đã đóng, còn **hai** (G18, G23). Cùng ngày, trước đó: **đóng G44** — kỳ rỗng thì tệp xuất thôi in khối Ngân sách, theo đúng màn Xem trước. Người dùng chốt chiều *"tệp theo màn"*: người cầm tờ PDF không có chỗ hỏi lại rằng con số ấy thuộc kỳ nào. Luật nay là một vị từ thuần **`inKhoiTheoKy`** mà **cả ba** chỗ cùng đọc — CSV, PDF, và màn Xem trước. ⚠️ Lượt sửa **đính chính chính tiêu đề cũ của G44**: màn Xem trước **không** giấu "mọi khối" khi kỳ rỗng, nó vẫn hiện đầu báo cáo, khối Dòng tiền và ba thẻ tổng — hai bên lệch **đúng một khối**. ⚠️ Ca test cho nhánh **PDF** phải so **độ dài tệp** chứ không tìm chuỗi, vì PDF nén luồng nội dung; bản sai có chủ ý làm nó đỏ với chênh lệch **2 847 byte**. Đếm lại bằng máy cùng ngày: **44** mục G, **42** đã đóng, còn **hai** (G18, G23), cả hai hoãn có chủ ý. Cùng lượt, **ngoài phạm vi G44**: ba ca của `os_notifier_native_test.dart` ghi cứng mốc `DateTime(2026, 9, 17, 21, 30)` và `DateTime(2026, 9, 20, 8)` — `flutter_local_notifications` gọi `validateDateIsInTheFuture` và **ném** với mốc đã qua, nên hai ca **đỏ từ sáng 18/09** ở một vùng chẳng ai vừa đụng vào. Nay dùng mốc tương đối; giờ **21:30 giữ nguyên** vì nó là thứ bắt lỗi neo vào UTC) · trước đó **2026-09-17** (**ba khối cuối vào tệp xuất báo cáo** — mục **3.31** `ANALYTICS_FEATURE.md`: PDF/CSV nay có so-với-kỳ-trước, số liệu nhanh, top 5 khoản chi. Lượt này **đóng một lỗi đã chạy từ 2026-09-09** mà không phép đo nào trước đây bắt được — Roboto nhúng cho PDF không có khối Mũi tên lẫn khối Hình học, nên `→` ở dòng dòng tiền bị gói `pdf` bỏ đi **im lặng** trong mọi tệp app từng xuất; nó lộ ra vì bản thiết kế đầu định dùng `▲`/`▼` và **một ca test đỏ đã lật chính bản thiết kế vừa được duyệt**. Và nó **mở G44** — kỳ rỗng thì màn Xem trước giấu mọi khối còn tệp vẫn in khối Ngân sách, chưa rõ bên nào đúng nên hoãn có chủ ý. Đếm lại bằng máy cùng ngày: **44** mục G, **41** đã đóng, còn **ba** (G18, G23, G44), cả ba hoãn có chủ ý. Cùng ngày, trước đó: **đóng G27** — cờ `wallets.allow_negative`, schema **v23**: ví thẻ tín dụng / theo dõi nợ thôi bị nhắc "ví âm" mỗi ngày. ⚠️ Hai bản sai có chủ ý đi lọt ở vòng đầu, **cả hai là lỗ hổng trong chính bộ test vừa viết** — chi tiết ở mục G27. ⚠️ Phép đếm ghi ở đây khi ấy — **43** mục G, **41** đã đóng, còn **hai** (G18, G23) — là **ảnh chụp trước G44** cùng ngày; con số đang đúng nằm ở đầu banner. Cùng ngày, trước đó: **khoản chi lớn** — loại thông báo thứ **18**, mục #7 khảo sát lần hai, mục 5f `NOTIFICATION_FEATURE.md` — **không mở lỗ hổng nào**; khảo sát lần hai nay **đóng**. Cùng ngày, trước đó: **tổng tài sản theo thời gian** — mục #5 khảo sát lần hai, mục 3.30 `ANALYTICS_FEATURE.md` — **không mở lỗ hổng nào**. Nó *đóng* một chỗ chưa ai gọi tên: `daiTrucDuBao` dựng trần rộng gấp đôi mức cần với dải bắt đầu từ 0, thứ **không test nào bắt được** vì mọi tính chất vẫn đúng — chỉ máy ảo thấy; nay siết tại chính hàm ấy, xem bẫy **4.21** vế ba. Cũng lượt này, giả định của mục 3.25 về "vách khoản neo 2026-09-13" bị **phép đo lật**: vách ấy không tồn tại trên dữ liệu thật) · trước đó 2026-09-16 (cuối ngày: **lịch chi tiêu** — mục #6 khảo sát lần hai, mục 3.29 `ANALYTICS_FEATURE.md` — **không mở lỗ hổng nào**; hai chỗ nó suýt để lọt đều bị bản sai có chủ ý và máy ảo bắt tại chỗ, ghi ở mục 3.29 chứ không thành lỗ hổng. Trước đó cùng ngày: mở rồi **đóng G43** — nút "Tuỳ chọn" của bộ chọn phạm vi ném assertion và chết **im lặng** ở đúng trạng thái mặc định của trang, **có sẵn từ P1**; tìm được khi nghiệm thu máy ảo cho **so cùng kỳ năm trước** (mục #2 khảo sát lần hai), thứ **không** mở lỗ hổng nào. Trước đó cùng ngày: mở rồi **đóng G42** trong cùng ngày — ví đã xoá mềm vẫn phình "số dư cuối kỳ" của trang Phân tích; tìm được khi soát tài liệu sau tính năng **dự báo dòng tiền 30 ngày**, thứ **không** mở lỗ hổng nào) · trước đó 2026-09-15 (mở rồi **đóng G41** trong cùng ngày — giao dịch trỏ vào danh mục mặc định toàn cục mất tên, máy ảo lộ ra bằng **hai chip cùng tên**; cùng ngày: **tỉ lệ tiết kiệm** và **A8 #8 dòng tiền tự do** — không mở lỗ hổng nào. Trước đó cùng ngày: mở rồi **đóng G40** — trang Xem trước báo cáo lệch cột số tiền thật, và lệch **93px**, nặng hơn chỗ đã sửa ở trang Phân tích; không phải hai khối mà **sáu**. Cùng ngày: P1 phạm vi thời gian và P2 bốn khối mượn từ trang Báo cáo — **không mở lỗ hổng nào**, schema giữ v22) · trước đó 2026-09-14 (mở rồi **đóng G39** ngay trong ngày — nhãn trục tung khối "Xu hướng 6 tháng" in đè lên nhau, tìm được khi nghiệm thu máy ảo lát A8 #3/#7; mở rồi **đóng G38** ngay trong ngày — ba trang giao dịch rơi về tài khoản admin; **đóng G28** — `wallet.status` đi qua đồng bộ hai chiều, schema v22) · trước đó 2026-09-13 (mở rồi **đóng G37** ngay trong ngày — số dư ví nay suy từ sổ giao dịch; đóng G36) · trước đó 2026-09-11 (sau khi nhánh gộp `main` @ `cc65f4f` và CSDL dev áp `database/12`: đóng G29, G31, G32; G24 thành lỗi phía client rồi đóng cùng ngày; thêm G34; G35 mở rồi đóng cùng ngày; đóng G30; đóng G33); 2026-09-12: gộp `main` @ `cbbeeb4` — CAN-LAM 17 A đóng, kênh thời gian thực nối được trên máy ảo, G34 hết bị chặn rồi **đóng tối cùng ngày** (client nghe `sync.completed`, im lặng, kiểm máy ảo hai máy); chiều muộn thêm **G36** — chờ backend; tối muộn gộp `main` @ `7779999` — backend làm xong CAN-LAM 20 (chốt trả hai lần ở `upsertTransaction`, client đo thật 4 ca; G36 sửa ở mã, **chưa đo đầu-cuối** ca khoá/xoá vì cần API admin — chờ đo rồi đóng); **2026-09-13: đo đầu-cuối ba ca G36 qua API admin — cả ba đúng, G36 ✅ ĐÓNG** (kéo theo: đường `lamMoi` **có** mang `daXoa`, nên ngoại lệ §3.6b không còn vô nghĩa — người dùng chốt **giữ** cùng ngày); cùng ngày, nghiệm thu bước 12 trên hai máy ảo đóng bốn lỗi im lặng của luồng tự động trả hoá đơn và mở **G37** — số dư ví không phản ánh giao dịch sau một lần đẩy bị xung đột
**Mục đích:** ghi lại những hạng mục đã được **cân nhắc và cố ý hoãn**, kèm lý do và bán kính ảnh hưởng. Không có tài liệu này thì người tiếp theo sẽ hoặc bỏ sót, hoặc làm lại từ đầu việc phân tích rủi ro.

Mỗi mục đều ghi rõ **vì sao hoãn** — đó là phần dễ mất nhất.

---
> **Phiên 2026-09-03 đã đóng 9/10 mục có lúc đó.** Mô tả gốc bên dưới được giữ
> nguyên (kể cả phần *vì sao hoãn*) vì nó ghi lại bối cảnh và bán kính ảnh
> hưởng — thứ vẫn cần khi ai đó đọc lại đoạn mã tương ứng.
>
> **Đang mở tính tới 2026-09-16.** Mục đã đóng vẫn nằm lại trong bảng, gạch
> ngang tên — xoá đi thì người sau lại mở ra làm lần nữa.
>
> ⚠️ **Bảng này trôi khỏi thân tài liệu năm lần rồi** (G16, G17, G21, G18, G15 — cả năm đều
> ghi *còn mở* trong khi mục tương ứng bên dưới ghi *đã đóng*). Sửa một mục ở
> thân thì **phải sửa dòng của nó ở đây cùng lúc**; đây là bảng người đọc nhìn
> trước tiên nên nó sai là cả tài liệu sai.
>
> | Mục | Vì sao còn mở |
> |---|---|
> | ~~**G10**~~ | ✅ **Đóng 2026-09-07** — mỗi tài khoản nay có bản sao riêng, việc gán nhóm nằm trong `Idgroup` của chính hàng ấy |
> | ~~**G15**~~ | ✅ **Đóng 2026-09-07** — tab "Đã hết hạn" nay phân biệt "đã chốt sổ" với "hỏng, chưa bao giờ lên tới server". ⚠️ Dòng cũ ở đây ghi *hoãn có chủ ý*, mâu thuẫn với chính mục G15 bên dưới — **lần trôi thứ năm**; sửa 2026-09-10 |
> | ~~**G16**~~ | ✅ **Đóng trọn 2026-09-07.** Nguồn tự sinh đóng 2026-09-05; **vế lệch ràng buộc với CSDL cũng đã đóng** — hai partial unique index mới đều có `WHERE "Delete_at" IS NULL`. ⚠️ Dòng cũ ở đây ghi vế ấy *vẫn còn*, mâu thuẫn với chính mục G16 bên dưới; sửa 2026-09-08. Lớp cầm máu `_uniqueConstraintPattern` **vẫn giữ, đừng gỡ** |
> | ~~**G17**~~ | ✅ **Đóng 2026-09-07** — `context.watch<AuthBloc>()` + `key: ValueKey(idaccount)` trên `GoalPage`, có test canh. ⚠️ Dòng cũ ở đây ghi mục này còn mở, mâu thuẫn với chính mục G17 bên dưới; sửa 2026-09-08 |
> | **G18** | ⏸️ **THU HẸP DẦN, không còn chặn ở backend.** Cột `transaction.Idgoal` đã có từ 2026-09-07 và client đẩy/đọc nó; thứ còn lại chỉ là **hàng cũ trên server mang `Idgoal = NULL`**, chúng nhận ID khi được đẩy lại. ⚠️ Dòng cũ ở đây ghi *chặn ở backend*, mâu thuẫn với chính mục G18 bên dưới — **lần trôi thứ tư**; sửa 2026-09-08 |
> | **G19** | **Không phải lỗi** — ghi lại để người sau không "sửa" nhầm |
> | **G23** | Bản sao danh mục chỉ đầy đủ khi bộ mặc định **cục bộ** đầy đủ — pull tăng dần, tự khỏi ở lượt sau |
> | ~~**G24**~~ | ✅ **Đóng 2026-09-11** — client đổi `colour` → `color` ở `categoryForPush` và đọc `c['color']` khi kéo về; server nhận màu (kiểm trên máy ảo: `category.Color = #FF5722`). Danh mục đã `synced` từ trước chỉ lên màu khi được **lưu lại**. ⚠️ Dòng này từng ghi *không có cột, chặn ở backend*, rồi *lỗi phía client, chưa sửa* — đúng tới trước khi gộp `main` và trước bản sửa |
> | ~~**G21**~~ | ✅ **Đóng 2026-09-07** — backend đã có ba cột `auto_deposit_*`, client đẩy và kéo cả ba. ⚠️ Dòng cũ ở đây ghi *chặn ở backend*, mâu thuẫn với chính mục G21 bên dưới; sửa 2026-09-08. Còn đúng một khe hở hẹp: hai máy cùng mở đúng lúc tới kỳ |
> | **G22** | **Không phải lỗi** — giờ trong mốc neo chỉ giữ được một chiều |
> | **G25** | **Không phải lỗi** — hai máy cùng sắp lại thứ tự ưu tiên khi ngoại tuyến thì được một thứ tự trộn (2026-09-08) |
> | ~~**G26**~~ | ✅ **ĐÓNG 2026-09-18 bằng quyết định sản phẩm** — nhóm **bỏ hẳn** liên kết ngân hàng, nên màn duyệt giao dịch ngân hàng không còn là việc thiếu. Phần client đã gỡ cùng ngày (màn mockup, thẻ ở Quản lý ví, hai route, `RealtimeEvent.giaoDichNganHang`). ⚠️ Đừng viện mục này để mở `status`/`provider` vào hợp đồng đồng bộ — hai cột ấy ở lại ngoài. Trước đó: hoãn có chủ ý vì đây là một tính năng riêng, không phải phần còn thiếu của việc nối socket (2026-09-09) |
> | ~~**G27**~~ ✅ **ĐÓNG 2026-09-17** (cờ `allowNegative`, schema v23) — trước đó: không còn cách nói "ví này **được phép âm**" sau khi loại `debt` bị bỏ; cần một cột mới ở cả hai đầu cho một tình huống CSDL hiện không có hàng nào (2026-09-09) |
> | ~~**G28**~~ | ✅ **ĐÓNG 2026-09-14** — `wallet.status` đi qua đồng bộ **hai chiều**: lưu trữ ví trên máy A nay có hiệu lực trên máy B. Ba mảnh khớp nhau (payload **13 trường**, `walletForPush` dịch sang `'Active'`/`'Inactive'`, nhánh kéo về đọc về chữ thường) cộng **migration v22** đánh dấu ví lưu trữ cũ để đẩy lại — bốn thứ vào **cùng một commit** vì bước cứu chỉ chạy một lần trong đời mỗi máy. ⚠️ Máy chủ chưa áp `database/7` vẫn `varchar(7)` và ví lưu trữ sẽ kẹt hàng đợi đẩy vĩnh viễn, im lặng. Dòng cũ ghi *chờ client mở lại* — đúng tới trước bản này |
> | ~~**G29**~~ | ✅ **Đóng 2026-09-11** — bộ lọc ghi chú mới của `7675b35` (Luhn + hình dạng số thẻ; mật khẩu phải có `:`/`=`; bỏ "pin") chạy đúng **15/15** ca của tài liệu xin, đo bằng chính hàm `filterSensitiveNote` — **chưa** đo đầu-cuối. Còn một hở nhỏ chấp nhận được và một việc cùng gốc ở backend (khoá mã hoá, mục 18 §2.6), không giữ mục này mở. Dòng cũ ghi *chặn ở backend* — đúng tới trước khi gộp `main` |
> | ~~**G30**~~ | ✅ **Đóng 2026-09-11** — `database/12` bỏ `uq_wallet_saving_active` và client gỡ chốt tạm: màn Thêm ví cho chọn "Tiết kiệm" dù đã có một ví Tiết kiệm, datasource không còn từ chối. ⚠️ Máy chủ nào chưa áp tệp 12 vẫn từ chối ví Tiết kiệm thứ hai. Chốt **trùng tên ví** ở lại vĩnh viễn |
> | ~~**G31**~~ | ✅ **Đóng 2026-09-11** — backend nay ánh xạ `22001`/`P2000` (dài quá cột) và `23502` về `CONSTRAINT_VIOLATION`, mã client đã xếp **vĩnh viễn**, nên bản ghi bị chặn theo thời gian thay vì gửi lại mãi; và một thao tác hỏng không còn làm **cả lô** 400. Bộ lọc bảy ô tên của client (2026-09-10) **vẫn giữ** — nó chặn trước để bản ghi không kẹt ngay từ đầu. Đo trên mã HEAD, chưa chạy đầu-cuối. Dòng cũ ghi *chặn ở backend* — đúng tới trước khi gộp `main` |
> | ~~**G32**~~ | ✅ **Đóng 2026-09-11** — backend giữ `priority: null` khi đẩy (hết `Number(null)` → `0`), nhánh tạo mặc định `null`, và `database/12` đã đưa các hàng `<= 0` về `NULL` trên CSDL dev. Lớp đọc `<= 0` là chưa sắp phía client **vẫn giữ** cho dữ liệu cũ và bản backend/client cũ. Dòng cũ ghi *chặn ở backend* — đúng tới trước khi gộp `main` |
> | ~~**G33**~~ | ✅ **Đóng 2026-09-11** — tài khoản chờ xoá nay dùng tiếp app trong 30 ngày thay vì bị đăng xuất ngay: `UserModel` mang `status`/`countdown`, trang Xoá tài khoản thôi hứa *"đăng nhập lại là tự khôi phục"*, hai thẻ (Trang chủ, "Vùng nguy hiểm" ở Cài đặt) hiện số ngày còn lại và nút huỷ. Kiểm trên máy ảo với tài khoản 11. Dòng cũ ghi *lỗi đang chạy, chưa sửa* — đúng tới trước bản sửa |
> | ~~**G34**~~ | ✅ **ĐÓNG 2026-09-12 tối** — client dịch `sync.completed` → `RealtimeEvent.dongBoXong`, đánh thức `syncNow()`, **im lặng** (không toast: máy vừa đẩy cũng nhận lại sự kiện của mình và payload là hộp đen nên toast sẽ nói sai). Kiểm máy ảo hai máy cùng tài khoản: máy kia kéo về **cùng giây** backend phát. Trước đó: mở 2026-09-11, chặn bởi 17 A tới sáng 2026-09-12 |
> | ~~**G36**~~ | ✅ **ĐÓNG 2026-09-13 — đo đầu-cuối ba ca qua API admin, cả ba đúng; client không đổi mã.** `Active` → 200; admin khoá → **401 + `ACCOUNT_INACTIVE`** kèm `idaccount` + `reason_inactive` ở cấp gốc; admin xoá mềm → **401 + `ACCOUNT_DELETED`** kèm `idaccount`, **dù 4/4 refresh token đã bị thu hồi** — đúng thứ CAN-LAM 20 §2.7 sửa (nhánh token thu hồi gọi `getAccountValidity` trước khi ném). Mô tả gốc: tài khoản bị xoá qua admin trong lúc app giữ token hết hạn và không có socket → `/auth/refresh` trả 401 **không mã** → app đăng xuất **trơn, không hộp thoại** (đo thật 2026-09-12 chiều). ⚠️ Kéo theo: đường `lamMoi` **CÓ** mang `daXoa`, nên ngoại lệ §3.6b không còn vô nghĩa — xem mục G36 |
> | ~~**G35**~~ | ✅ **Đóng 2026-09-11** — ba màn quản lý danh mục nay lấy tài khoản qua `currentAccountIdOrNull`: chưa có phiên thì không đọc gì (kể cả tài khoản 0 — bộ khuôn toàn cục), và nút lưu/xoá báo "Chưa xác định được tài khoản đăng nhập". Test quét `lib/` cấm `?? 1` nhiều dòng. ⚠️ Dòng này từng ghi *lỗi đang chạy, chưa sửa* — đúng tới trước bản sửa |
> | ~~**G38**~~ | ✅ **Mở rồi ĐÓNG 2026-09-14** — ba trang giao dịch (`transaction_page`, `choose_category_page`, `add_transaction_page`) khai `this.idaccount = 1` rồi dùng `?? widget.idaccount`, nên khi phiên chưa sẵn sàng chúng **đọc** ví/danh mục của admin và — nặng nhất — **GHI** giao dịch dưới danh nghĩa admin. Cùng họ G4/G35 nhưng khác hình dạng nên lọt cả hai lượt đóng ấy. Nay dùng `int?` không mặc định + `null` thì chặn; lưới quét `khong_du_phong_admin_test.dart` thêm ca thứ hai bắt đúng dạng này. Nghiệm thu máy ảo: giao dịch ghi vào `Idaccount = 25`, tài khoản 1 không có hàng nào |
> | ~~**G39**~~ | ✅ **Mở rồi ĐÓNG 2026-09-14** — nhãn trục tung của khối "Xu hướng 6 tháng" in **đè lên nhau** ở một số dải giá trị: đo trên máy ảo thấy "63.2K" và "63.3K" chồng khít. Gốc rễ là `3 * (maxY / 3) != maxY` trong dấu phẩy động rơi đúng ranh giới làm tròn của `rutGon`, nên **cùng một vị trí** ra hai chuỗi. Sửa: tính `buoc` trước rồi đặt `maxY = buoc * 3`. **Có sẵn từ lát 2b (2026-09-08)**; lát A8 #3/#7 chỉ làm dễ gặp hơn. Ca test tái hiện được **ngay trong widget test**, không cần máy thật |
> | ~~**G37**~~ | ✅ **ĐÓNG 2026-09-13** — số dư ví nay là **cache của tổng sổ giao dịch**, không còn là giá trị tuyệt đối đồng bộ theo LWW. Điểm neo là một giao dịch "Số dư ban đầu" (id suy **tất định** từ `walletId` nên hai máy sinh ra một hàng), `SoDuViService` là nơi duy nhất ghi `balance`, nhánh kéo về thôi đọc cột ấy và tính lại sau mỗi lần pull. Nghiệm thu hai máy ảo: sau một cuộc đua tự trả, **hai máy đều 1.650.000 và bằng tổng sổ** — trước đó máy thắng giữ 2.000.000. Spec: `2026-09-13-so-du-vi-suy-tu-so-giao-dich-design.md` |
> | ~~**G40**~~ | ✅ **ĐÓNG 2026-09-15** — trang **Xem trước báo cáo** lệch cột số tiền thật, và **nặng hơn** chỗ đã sửa ở trang Phân tích: đo trên máy ảo thấy khối "Chi theo danh mục" lệch **93px** (trang Phân tích chỉ 26,5px). Và không phải **hai** khối như dòng này từng đoán mà **sáu** — thêm ngân sách, thu/chi theo danh mục, danh sách giao dịch, và hàng "Thay đổi trong kỳ" của khối dòng tiền. Sáu `Flexible` đổi thành `Expanded`; đo lại trên máy ảo: lệch **0px** ở mọi khối. Sáu ca test mới, và chúng chỉ canh được gì khi chạy ở **khổ gấp đôi** — xem bẫy 4.19 |
> | ~~**G43**~~ | ✅ **Mở rồi ĐÓNG 2026-09-16** — nút **"Tuỳ chọn"** của bộ chọn phạm vi **không làm gì cả, hoàn toàn im lặng**, ở đúng trạng thái **mặc định** của trang. `showDateRangePicker` ném assertion vì `initialDateRange` thò ra ngoài `[firstDate, lastDate]`: kỳ "Tháng này" kết thúc 30/09 trong khi `lastDate` là hôm nay 16/09. Đó là exception **bất đồng bộ không ai bắt** — không toast, không màn đỏ, chỉ một dòng logcat người dùng không bao giờ thấy. **Có sẵn từ P1 (2026-09-15)**; lượt nghiệm thu máy ảo của mục #2 mới chạm vào nút ấy. Phép kẹp nay là hàm thuần `khoangKhoiTaoBoChonNgay` có test riêng |
> | ~~**G42**~~ | ✅ **Mở rồi ĐÓNG 2026-09-16** — ví **đã xoá mềm** vẫn được cộng vào "số dư cuối kỳ" của khối Dòng tiền và thác nước (đo được **7.000.000** trên một ví thử). `AnalyticsRepositoryImpl` đọc ví bằng truy vấn thẳng **không lọc `deletedAt`** — cố ý, vì bảng tra tên cần hàng đã xoá — rồi cộng `balance` qua `viTinhVaoTong`, hàm khi ấy chỉ kiểm `includeInTotal` và trạng thái lưu trữ. Đây là **bản chép tay thứ năm** của đúng luật mà `vi_tinh_vao_tong_test.dart` sinh ra để chặn, chỉ khác vế. Sửa bằng cách đưa vế `isDeleted` **vào chính hàm** (mặc định `false`), không vá ở chỗ gọi |
> | ~~**G41**~~ | ✅ **Mở rồi ĐÓNG 2026-09-15** — giao dịch trỏ vào **danh mục mặc định toàn cục** mất tên, hiện thành "Danh mục đã xoá". `sync_engine` quy `is_default = true` thành **`idaccount = 0`**, nhưng cả hai repository tra danh mục lọc đúng một `idaccount` — mỗi nơi một bản chép tay của cùng truy vấn. Máy ảo lộ ra vì khối Xu hướng hiện **hai chip cùng một tên**; truy vấn PostgreSQL xác nhận tài khoản 10 có đúng hai danh mục như thế (`Chi khác`, `Làm thêm`, cùng bị backend xoá mềm hôm 2026-09-07). Nay có **một** định nghĩa `categoryDao.getBangTraTen` lọc theo **cờ `isDefault`**, cả hai repository dùng chung. Ảnh hưởng rộng hơn chip: donut, thác nước và danh sách danh mục đều mất tên |
> | ~~**G44**~~ | ✅ **ĐÓNG 2026-09-18** — kỳ rỗng thì tệp xuất in bảng *Ngân sách kỳ này* mà màn Xem trước giấu, vì ngân sách là khối **duy nhất** không tự rỗng theo một kỳ rỗng. Người dùng chốt chiều **"tệp theo màn"**; luật nay là vị từ thuần `inKhoiTheoKy` mà cả CSV, PDF lẫn màn Xem trước cùng đọc. ⚠️ Lượt sửa đính chính chính tiêu đề cũ: màn **không** giấu "mọi khối" — đầu báo cáo, khối Dòng tiền và ba thẻ tổng vẫn hiện, nên hai bên lệch **đúng một khối**. ⚠️ Ca PDF so **độ dài tệp** chứ không tìm chuỗi (PDF nén luồng nội dung); bản sai làm nó đỏ với **2 847 byte** chênh lệch |
> | ~~**G45**~~ | ✅ **Mở rồi ĐÓNG 2026-09-18** — sáu lỗ hổng của mảng ví tìm bằng lượt soát đối chiếu từng ràng buộc PostgreSQL với chốt phía client; nặng nhất là ô số dư không giới hạn chữ số (numeric(15,2) → 22003 → gửi lại mọi chu kỳ). *(Dòng này thêm 2026-09-19 — bảng từng trôi khỏi thân, thiếu G45 và G46.)* |
> | ~~**G46**~~ | ✅ **Mở rồi ĐÓNG 2026-09-18** — trần số chữ số thiếu ở bốn mảng còn lại (giao dịch, hoá đơn, mục tiêu, ngân sách); bàn phím tự vẽ của giao dịch nặng nhất. Test quét `lib/` thứ tám canh ô tiền mới |
> | ~~**G47**~~ | ✅ **Mở rồi ĐÓNG 2026-09-19** — thẻ **hoá đơn** và bảng tra tên của **ngân sách** mất tên danh mục mặc định toàn cục / đã xoá mềm: cùng họ G41 nhưng ở ba bản chép tay khác (`BillPage`, `BillDetailPage`, `BudgetLocalDataSourceImpl.getAllCategories`) vẫn gọi `categoryDao.getAll`. Máy ảo: 2/3 thẻ hoá đơn hiện "Danh mục đã xoá". Cả ba về `getBangTraTen` |
>
> **G20 đã đóng ngày 2026-09-05** — `depositToGoal` nhận `occurredAt` chặn hai
> đầu; đã kiểm cả bằng test lẫn trên máy ảo Android.

| Mục | Đã làm gì | Test canh chừng |
|---|---|---|
| **G1** | Thêm `SyncStatus.authExpired`; `_runSync()` kết thúc ở `error` khi còn thao tác hỏng, `authExpired` khi phiên chết. Thêm `SyncStatusX.isTerminal` để test chờ trạng thái kết thúc bất kỳ (12 chỗ trong 6 file đã đổi theo). `scheduleSync()` nay quay lại `pending` được từ cả `error`. | `sync_failure_handling_test.dart` |
| **G2** | Giãn cách luỹ tiến 30s → 1p → 5p → 15p → 60p, kiểm ở đầu `_runSync`, reset khi có chu kỳ sạch và khi `start()`/`stop()`. Đồng hồ tiêm được qua tham số `now`. | nt (nhóm G2) |
| **G3** | `schemaVersion` 8 → 9: thêm `syncRetryCount` / `syncError` / `syncBlockedUntil` cho cả 6 bảng. Lỗi **vĩnh viễn** chặn bản ghi theo THỜI GIAN (không đổi `syncStatus` thành `'failed'`, đúng cảnh báo ở mục G3). `markSynced` xoá sạch dấu vết. | nt (nhóm G3) |
| **G4** | Gỡ mọi fallback về admin: `_getAccountId` (có `?? 1` và `return 1`) ở 4 trang bill/goal, **và 9 biểu thức `?? 1` nội tuyến** ở `goal_page.dart` / `goal_add_page.dart`. Thay bằng `core/auth/current_account.dart` trả `int?` — đường ĐỌC dùng `?? 0` (rỗng, không phải dữ liệu admin), đường GHI chặn hẳn kèm thông báo. Bỏ **mọi** nhánh `getAllNonDeleted()` không lọc tài khoản (4 trang + `goal_repository_impl.dart`); nay không còn nơi gọi nào. | `test/core/auth/current_account_test.dart` |
| **G5** | `isLocalDbEmpty` dùng `walletDao.getAll(accountId)`. | — |
| **G8** | Cả 6 chỗ dùng thẳng tham số `idaccount` của `_collectPendingOps`. | `sync_payload_contract_test.dart` |
| **G9** | `conflict` = LWW đã phân xử, server thắng → `markSynced` để thoát vòng đẩy lại vô hạn. | `sync_failure_handling_test.dart` |
| **G11** | `schemaVersion` 7 → 8 + migration `UPDATE categories SET is_local_only = 0, sync_status = 'pending' WHERE is_local_only = 1`. | `category_dao_test.dart` |
| **G12** | `AuthInterceptor` phát `sessionExpiredStream` khi xoá token (chỉ khi thật sự có token để mất, tránh dội sự kiện); AuthBloc nghe kênh này song song với `SyncEngine`. | `test/core/api/auth_interceptor_test.dart`, `session_validation_test.dart` |
| ~~**G10**~~ | ✅ **ĐÓNG 2026-09-07 — không cần backend làm gì.** Bảng ấy tồn tại chỉ vì danh mục mặc định là hàng toàn cục nên không ghi `Idgroup` riêng cho từng tài khoản được. Nay **mỗi tài khoản có bản sao riêng** của bộ mặc định, nên việc gán nhóm nằm gọn trong `Idgroup` của chính hàng họ sở hữu — cột đã có và đã đồng bộ. Client đã gỡ mọi lời gọi tới bảng phụ; bảng còn trong lược đồ cục bộ nhưng không nơi nào ghi vào nữa. Xem `docs/superpowers/specs/2026-09-07-per-account-default-categories-design.md`. | `default_category_seeder_test.dart` |


## 1. Việc đã cố ý hoãn

### ~~G1 — Trạng thái kết thúc của `_runSync()` luôn là `idle`, kể cả khi mọi thao tác đều thất bại~~ · ✅ ĐÃ SỬA (2026-09-03)

**Hiện trạng:** `sync_engine.dart` kết thúc chu kỳ bằng `_setStatus(SyncStatus.idle)` bất kể kết quả. `SyncStatus.error` gần như là mã chết đối với lỗi đẩy dữ liệu, vì `_sendBatch` không ném lỗi ra ngoài nên khối `catch` không bao giờ chạm tới.

**Vì sao hoãn:** đổi trạng thái kết thúc sẽ làm **treo 11 chỗ trong 6 file test** đang chờ đúng `SyncStatus.idle`:

```
test/core/sync/sync_checkpoint_test.dart
test/core/sync/sync_failure_handling_test.dart
test/core/sync/sync_payload_contract_test.dart
test/e2e_sqlite_to_backend_sync_test.dart
test/features/auth/session_validation_test.dart
test/features/category/category_create_test.dart
```

Chúng dùng `await statusStream.where((s) => s == SyncStatus.idle).first` kèm `.timeout(5s)` — đổi trạng thái mà không sửa đồng thời thì test sẽ fail dạng "timeout", rất khó đọc.

**Cách làm khi bắt tay vào:** thêm `SyncStatus.authExpired`, đổi 11 chỗ trên sang chờ **trạng thái kết thúc bất kỳ** (`idle | error | authExpired`) trong cùng một lần sửa. Lưu ý `scheduleSync()` chỉ chuyển sang `pending` khi status đang `idle`, nên nếu status kẹt ở `error` thì nhãn "chờ đồng bộ" sẽ không còn hiện.

**Giá trị thu được:** trung bình. Việc thoát khỏi vòng lặp lỗi đã được giải quyết bằng kênh `sessionInvalidStream` riêng; mục này chỉ làm trạng thái phản ánh đúng thực tế.

---

### ~~G2 — Không có exponential backoff~~ · ✅ ĐÃ SỬA (2026-09-03)

**Hiện trạng:** thao tác thất bại loại `transient` được thử lại ở chu kỳ kế tiếp, không giãn dần. Nguồn kích hoạt gồm: debounce 2 giây sau mỗi lần ghi dữ liệu (nhiều call-site `scheduleSync()` rải khắp các repository), đổi trạng thái kết nối, timer định kỳ 15 phút, và mỗi lần `start()`.

**Vì sao hoãn:** bản bền vững cần thêm cột vào schema (xem G3). Bản chỉ giữ trong RAM thì làm được ngay nhưng mất tác dụng sau mỗi lần mở lại app.

**Cách làm:** `_consecutiveFailures` + `_nextAllowedSyncAt` (30s → 1p → 5p → 15p → 60p), kiểm tra ở đầu `_runSync`. Reset khi có một chu kỳ thành công.

---

### ~~G3 — Lược đồ SQLite không có trạng thái thất bại~~ · ✅ ĐÃ SỬA (2026-09-03)

**Hiện trạng LÚC PHÁT HIỆN (2026-09-02):** `schemaVersion = 7`. Các bảng chỉ có `syncStatus` với đúng hai giá trị được ghi trong thực tế: `'pending'` và `'synced'`. Không có `syncRetryCount`, `syncError`, `syncBlockedUntil`. Một bản ghi lỗi vĩnh viễn vẫn nằm ở `pending` mãi mãi.

**Vì sao hoãn:** cần bump `schemaVersion` + viết migration chạy trên máy người dùng thật — rủi ro cao hơn hẳn các thay đổi thuần logic.

> ⚠️ **Bẫy khi làm:** đừng chuyển `syncStatus` sang `'failed'` rồi loại khỏi `getPending`. Cơ chế thử lại hợp lệ (giao dịch tham chiếu ID danh mục mặc định cũ, phải Pull xong mới đẩy lại được) sẽ chết theo. Dùng `syncBlockedUntil` + backoff thay vì loại vĩnh viễn.

---

### ~~G4 — Nhiều truy vấn không lọc theo tài khoản~~ · ✅ ĐÃ SỬA (2026-09-03)

**Hiện trạng:** `WalletDao.getAllNonDeleted()` không nhận tham số `idaccount`. Còn **5 nơi** đang gọi bản không lọc:

| Nơi gọi | Ghi chú |
|---|---|
| `lib/core/sync/sync_engine.dart:234` | Dùng để tính `isLocalDbEmpty` — quyết định có full pull hay không |
| `lib/features/bill/presentation/pages/bill_add_page.dart:57` | Danh sách ví để chọn |
| `lib/features/bill/presentation/pages/bill_page.dart:45` | nt |
| `lib/features/goal/data/repositories/goal_repository_impl.dart:113` | nt |
| `lib/features/goal/presentation/pages/goal_detail_page.dart:58` | nt |

`TransactionDao.watchAllNonDeleted()` và `GoalDao.watchAllNonDeleted()` cũng cùng dạng.

**Đã giảm nhẹ tới đâu:** đường nguy hiểm nhất — sync engine dùng nó để **suy ra danh tính người dùng** — đã bị gỡ bỏ. Việc đăng nhập cũng gọi `purgeDataForOtherAccounts()` nên dữ liệu tài khoản khác không còn tồn tại trong máy ở điều kiện bình thường.

**Vì sao hoãn:** lịch sử git có commit *"fix(goal): add watchAllNonDeleted fallback query in GoalDao to prevent goals from disappearing on wallet creation"* — tức việc **không lọc** từng được thêm **có chủ đích** để chữa một triệu chứng khác. Thêm bộ lọc mà không hiểu bug gốc đó rất có thể làm nó tái phát.

**Cách làm:** dựng lại kịch bản trong commit kia (tạo ví mới rồi xem danh sách mục tiêu) thành test trước, rồi mới thêm bộ lọc.

---

### ~~G5 — `isLocalDbEmpty` tính trên toàn bộ ví, không riêng tài khoản hiện tại~~ · ✅ ĐÃ SỬA (2026-09-03)

`sync_engine.dart:234` — nếu máy còn ví của tài khoản khác, `isLocalDbEmpty` sẽ là `false` và bỏ qua full pull, dù tài khoản hiện tại chưa có dữ liệu gì. Sửa: dùng `walletDao.getAll(accountId)`. Nhỏ, nhưng nằm trong G4 nên gộp làm một lần.

---

### ~~G6 — `purgeDataForOtherAccounts()` chỉ chạy khi đăng nhập~~ · ✅ ĐÃ SỬA

Hàm dọn dữ liệu tài khoản khác trước đây chỉ được gọi trong `_onLoginSubmitted`. Nay được gọi cả trong `_onAuthCheckRequested` (khôi phục phiên lúc mở app), ngay trước `SyncEngine.start()`.

Test bao phủ: `session_validation_test.dart` — *"Khôi phục phiên cũng dọn dữ liệu tài khoản khác, không chỉ lúc đăng nhập"*.

---

### ~~G7 — Pull ghi cứng `isDeleted = false` cho mọi danh mục~~ · ✅ ĐÃ SỬA

`sync_engine.dart` nay đọc `isDeleted: Value(c['delete_at'] != null)` như các thực thể khác.

Đã kiểm chứng backend **không** lọc `delete_at` khi trả dữ liệu (`getCategoriesByAccount` chỉ lọc theo `is_default`/`create_by`/`update_at`), nên hàng đã xoá thật sự nằm trong response — đây là lỗi thật, không phải giả định.

Test bao phủ: `category_create_test.dart` — *"Pull đọc cờ xoá của danh mục thay vì hồi sinh nó"*.

---

### ~~G8 — Fallback `?? 1` vẫn còn trong khâu dựng payload đồng bộ~~ · ✅ ĐÃ SỬA (2026-09-03)

`sync_engine.dart` dòng 671, 699, 781, 818, 859, 892 — cả 6 thực thể vẫn có `(_currentIdaccount ?? 1)`.

**Hiện KHÔNG gây hại:** `_runSync()` đã có chốt trả về sớm khi `_currentIdaccount == null`, nên nhánh `?? 1` không còn tới được. Nhưng nó vẫn là mìn: ai đó gọi `_collectPendingOps()` từ chỗ khác sẽ làm nó sống lại, và hậu quả là ghi dữ liệu dưới danh nghĩa **tài khoản admin**.

**Cách sửa:** đổi tham số của `_collectPendingOps` thành `int idaccount` bắt buộc và dùng thẳng nó thay cho `_currentIdaccount ?? 1`.

---

### ~~G9 — Trạng thái `conflict` bị bỏ lửng~~ · ✅ ĐÃ SỬA (2026-09-03)

`sync_engine.dart:1009-1014` — thao tác trả về `status == 'conflict'` chỉ được thêm vào `conflictIds` và `debugPrint`. Bản ghi **không** được `markSynced`, **không** tính vào `failed`, và không có bất kỳ mã giải quyết xung đột nào. Nó sẽ được đẩy lại ở mọi chu kỳ sau.

---

### ~~G10 — `CategoryGroupMemberships` không bao giờ được đồng bộ~~ · ✅ ĐÓNG (2026-09-07)

Quan hệ "danh mục mặc định thuộc nhóm nào" lưu trong bảng `CategoryGroupMemberships`, và bảng ấy **không có `SyncEntityType` tương ứng** nên chỉ tồn tại trên một máy.

**Cách đóng không phải là thêm entity.** Bảng phụ ấy tồn tại chỉ vì danh mục mặc định là hàng **toàn cục** — không ghi `Idgroup` riêng cho từng tài khoản lên một hàng dùng chung được. Ngày 2026-09-07 client đổi hướng: mỗi tài khoản có **bản sao riêng** của bộ mặc định, còn hàng toàn cục lui về làm khuôn. Từ đó việc gán nhóm nằm gọn trong `Idgroup` của chính hàng người dùng sở hữu — một cột đã có sẵn, đã nằm trong payload đẩy và đã được `upsertCategory` ghi thật.

Client đã gỡ mọi lời gọi tới bảng phụ. Bảng vẫn còn trong lược đồ SQLite cục bộ vì bỏ một bảng Drift là một migration trên máy đang có dữ liệu, nhưng **không nơi nào ghi vào nó nữa**.

---

### ~~G11 — Không có migration đưa `isLocalOnly` của dữ liệu cũ về `false`~~ · ✅ ĐÃ SỬA (2026-09-03)

**Mô tả lúc phát hiện (2026-09-02):** `schemaVersion` khi ấy vẫn là 7. Người dùng đã có nhóm danh mục tạo **trước** phiên 2026-09-02 sẽ mang `isLocalOnly = true`, và bộ lọc trong `getSyncableCategories` sẽ loại chúng khỏi batch đẩy — tức **nhóm cũ không bao giờ lên backend**, chỉ nhóm tạo mới mới lên.

**Cách sửa:** bump `schemaVersion` lên 8 + migration `UPDATE categories SET is_local_only = 0, sync_status = 'pending' WHERE is_local_only = 1`.

---

### ~~G12 — `AuthInterceptor` xoá token khi refresh thất bại nhưng không báo cho ai~~ · ✅ ĐÃ SỬA (2026-09-03)

`auth_interceptor.dart` — `_clearTokens()` được gọi ở dòng 54 và 69, bản thân hàm nằm ở dòng 130-133. Không có mã nào trong `lib/` lắng nghe sự kiện này. App sẽ kẹt ở trạng thái `AuthSuccess` với token đã bị xoá: mọi request sau đó không có header → 401 → refresh (đã mất refresh token) → xoá lại → lặp cho tới khi khởi động lại app.

Kênh `sessionInvalidStream` thêm trong phiên 2026-09-02 mới chỉ nối từ **SyncEngine**, chưa nối từ interceptor.

---

### ~~G13 — Kích hoạt đồng bộ bị giãn cách từ chối thì không được hẹn lại~~ · ✅ ĐÃ SỬA (2026-09-03)

Phát hiện khi chạy app thật, không phải khi đọc mã: xoá một ngân sách trong lúc engine đang giãn cách thì thao tác đó **không lên tới backend**, kể cả sau khi giãn cách đã hết. Phải chờ tới lần mở app sau.

Đây là kiểu hỏng tệ nhất về mặt trải nghiệm: mục biến mất khỏi màn hình ngay lập tức nên người dùng tin là xong, trong khi máy khác vẫn thấy nó nguyên vẹn.

**Nguyên nhân:** nhánh giãn cách trong `_runSync` chỉ `debugPrint` rồi `return`. Ba nguồn kích hoạt còn lại đều thưa hoặc ngẫu nhiên — timer 15 phút, đổi trạng thái mạng, và `start()` lúc mở app — nên khoảng chờ thật dài hơn bậc giãn cách rất nhiều. Đã đo: chờ thêm 60 giây **sau** mốc hết giãn cách vẫn không có lệnh đẩy nào.

**Bản vá:** `_scheduleBackoffRetry()` — từ chối một yêu cầu đồng bộ nghĩa là **nợ người gọi một lần chạy**, nên hẹn giờ chạy lại đúng lúc hết giãn cách. Nhiều kích hoạt bị chặn liên tiếp dùng chung một hẹn giờ, nếu không thì mỗi lần ghi dữ liệu lại đẩy mốc chạy lại lùi về sau.

Bốn test canh vùng này ở `test/core/sync/sync_failure_handling_test.dart`, nhóm G2.

> ⚠️ Bản vá này chỉ rút ngắn **độ trễ**. Nguyên nhân khiến engine rơi vào giãn cách ngay từ đầu vẫn còn nguyên — xem G14.

---

### ~~G14 — 5 danh mục cá nhân đẩy hỏng vĩnh viễn, kéo theo mọi thứ khác chậm~~ · ✅ ĐÃ SỬA Ở CLIENT (2026-09-03)

> **Bản vá:** `PersonalDefaultCategories` tách làm hai giai đoạn. `convertLegacyRows()` chạy trước chu kỳ đồng bộ đầu tiên và **chỉ đụng tới máy còn hàng seed `cat_*`** — máy sạch thì không tạo gì. `ensureMissing()` chạy **sau** khi pull xong, lúc đã biết tài khoản thật sự đang có những gì. `auth_bloc` gọi hai giai đoạn đúng thứ tự ở cả đường đăng nhập lẫn khôi phục phiên, và chỉ gọi giai đoạn 2 khi `SyncEngine.hasCompletedPull` — pull hỏng thì hoãn tới lần mở app sau chứ không tạo mù.
>
> Cũng vá luôn một lỗ hổng có sẵn từ bản gốc: hàng seed `cat_*` **tự khớp tên với chính nó**, bị dùng làm đích trỏ tới rồi bị xoá mềm ngay sau — giao dịch kết thúc ở một danh mục đã xoá. Nay `_findOwned` loại chính hàng đó ra khỏi tập ứng viên.
>
> 6 test canh vùng này ở `test/features/category/data/personal_default_categories_test.dart` (còn 6 sau khi nhóm `foldIntoBackendDefaults` bị gỡ ngày 2026-09-07 — xem G16).
>
> **Máy đã lỡ tạo bản trùng cũng đã tự thoát được.** Bản vá trên ngăn phát sinh mới; bước khử trùng lặp sau pull dọn nốt hậu quả cũ — xem cuối mục này.

Đo được trên app thật ngày 2026-09-03 với tài khoản có sẵn dữ liệu, bằng cách đọc log của `SyncEngine` trong trình duyệt:

```
[SyncEngine] Push failed [transient]: entity=category, localId=6d16eab1-…, reason=
… (5 danh mục, lặp lại ở MỌI chu kỳ)
[SyncEngine] Real Sync Complete: 0/5 synced successfully.
[SyncEngine] Đang trong thời gian giãn cách sau 2 chu kỳ hỏng — hoãn tới 19:50:31
```

**Chuỗi nguyên nhân**, đã đối chiếu bằng truy vấn PostgreSQL:

1. Backend **đã có** 5 danh mục cá nhân của tài khoản (Chi khác, Thu khác, Làm thêm, Trả nợ, Thu nợ), mỗi cái một UUID — do một máy trước đó tạo ra và đẩy lên.
2. Trên một máy chưa từng chạy app, `PersonalDefaultCategories.ensureForAccount()` sinh lại đúng 5 danh mục đó với **UUID mới**.
3. Đẩy lên vi phạm quy tắc trùng tên → backend trả `status: failed` **kèm message rỗng**.
4. `reason` rỗng nên `_classifyFailure` không nhận ra được gì, xếp vào `transient` → **thử lại vĩnh viễn**.
5. Mọi chu kỳ đồng bộ vì thế kết thúc ở trạng thái hỏng → giãn cách luỹ tiến 30s → 1p → 5p → 15p → 60p.

**Bán kính ảnh hưởng rộng hơn tài liệu cũ ghi.** `CATEGORY_NAME_UNIQUENESS.md` mô tả hậu quả là "vi phạm trùng tên hỏng âm thầm". Thực tế nặng hơn: 5 thao tác hỏng vĩnh viễn này giữ engine trong giãn cách gần như liên tục, nên **mọi thay đổi khác** — ví, giao dịch, ngân sách — đều bị đẩy chậm theo. G13 chỉ rút ngắn độ trễ đó, không xoá được nó.

#### Nguyên nhân là THỨ TỰ chạy ở client, không phải ID không ổn định

> ⚠️ Bản ghi đầu tiên của mục này (commit `25915ec`) quy sai cho `CATEGORY_STABLE_IDS.md`. Đọc lại mã nguồn thì không phải vậy. Giữ lại đính chính này vì nó đúng kiểu sai mà mục 4 dưới đây cảnh báo: kết luận từ một tài liệu liên quan thay vì từ mã nguồn.

`ensureForAccount()` **có** kiểm trùng — nó gọi `getNamesInUse(idaccount)` rồi so bằng `normalizeCategoryName`, và chỉ tạo khi không thấy bản nào cùng tên ([`personal_default_categories.dart:55-66`](../src/Client-app/lib/features/category/data/services/personal_default_categories.dart)).

Vấn đề là nó chạy **trước** `SyncEngine.start()` trong `auth_bloc.dart` (cả hai đường: đăng nhập và khôi phục phiên). Đó là chủ ý, có ghi chú hẳn hoi: việc chuyển dữ liệu cũ trỏ vào hàng seed `cat_*` phải xong trước khi chu kỳ đồng bộ đầu tiên chạm vào. Nhưng trên máy mới, CSDL cục bộ **rỗng** nên phép kiểm trùng không thấy gì → tạo 5 UUID mới → pull sau đó mới kéo về 5 bản của backend → trùng tên.

Hai hướng sửa, đều thuần client:

- **Hoãn tới sau lần pull đầu tiên khi không có gì để chuyển đổi.** Nếu trong máy không tồn tại hàng `cat_*` nào thì lý do "phải chạy trước start()" không còn, và chờ pull xong mới tạo là an toàn.
- **Khử trùng lặp sau pull.** `removeDuplicateLocalSeedCategories()` đã làm việc tương tự nhưng chỉ cho `isDefault = true` và chỉ xoá bản có id không phải UUID — không xử lý được hai danh mục **người dùng** cùng tên mà cả hai đều là UUID. Cần mở rộng, kèm repoint tham chiếu trước khi xoá (repoint TRƯỚC, xoá SAU — đảo lại chính là lỗi 11.6).

**Phần thuộc backend là lớp phòng thủ thứ hai, không phải điều kiện tiên quyết:** cho `/sync/push` trả mã lỗi ổn định `CATEGORY_NAME_DUPLICATE` thay vì message rỗng, để client xếp được vào `permanent` bằng một dòng trong `_classifyFailure`. Đáng làm vì **mọi** vi phạm trùng tên khác cũng sẽ hỏng theo đúng kiểu này, không riêng 5 danh mục trên.

#### Dọn hậu quả trên máy đã lỡ tạo bản trùng · ✅ ĐÃ LÀM (2026-09-03)

Bản vá thứ tự chỉ ngăn phát sinh mới. Máy nào đã chạy bản client cũ và tạo ra 5 danh mục trùng thì chúng vẫn nằm ở `pending` và vẫn hỏng mỗi chu kỳ. `CategoryDao.mergeDuplicatePersonalCategories(idaccount)` dọn nốt phần đó, chạy **sau pull**, ngay sau `removeDuplicateLocalSeedCategories()` trong `SyncEngine`.

Cách nó chọn bản giữ lại:

- Gom các danh mục **không mặc định, chưa xoá** của tài khoản theo `normalizeCategoryName` — không tính `classify`, đúng quy tắc 7.
- Chỉ hành động khi nhóm có **đúng một** bản `synced` — đó là bản backend công nhận. Không bản nào hoặc nhiều hơn một thì bỏ qua, không đoán bừa.
- Chỉ hấp thụ các bản `pending`. Một hàng đã `synced` không bao giờ bị xoá — nó có thể đang được máy khác dùng.

`_absorbCategory()` **repoint TRƯỚC, xoá SAU** (đảo lại chính là lỗi 11.6):

1. `repointCategoryReferences()` — giao dịch, ngân sách, hoá đơn.
2. `parentId` của các danh mục con.
3. Từ khoá phân loại — bỏ qua những từ khoá bản giữ lại đã có, vì khoá duy nhất là `(idaccount, categoryId, normalizedKeyword)`.
4. Xoá thành viên nhóm của bản bị hấp thụ.
5. **Xoá vật lý** hàng đó.

Xoá vật lý là ngoại lệ có chủ ý của quy tắc 5: hàng `pending` này **chưa từng tồn tại trên server**, nên không có gì để đồng bộ; xoá mềm sẽ để lại đúng một thao tác đẩy vô nghĩa — thứ đang gây ra chính vấn đề này.

`removeDuplicateLocalSeedCategories()` vẫn giữ nguyên vai trò cũ: nó chỉ lo cho `isDefault = true` và chỉ xoá bản có id không phải UUID. Hai hàm bổ sung nhau chứ không chồng nhau.

9 test canh vùng này ở `test/core/database/category_dao_test.dart`, nhóm `mergeDuplicatePersonalCategories — dọn bản trùng do máy tự tạo`.

---

### G15 — Bản ghi vừa hết hạn vừa hỏng đồng bộ thì không sửa được · ✅ ĐÓNG (2026-09-07)

Tab **"Đã hết hạn"** của trang ngân sách khoá cả sửa lẫn xoá — đúng yêu cầu: số
liệu đã chốt sổ không được đổi về sau. Nhưng khoá đó không phân biệt "đã chốt
sổ" với "hỏng, chưa bao giờ lên tới server".

Một ngân sách rơi vào **cả hai** trạng thái kẹt không lối thoát: không đẩy lên
được (backend từ chối vĩnh viễn), mà cũng không mở ra sửa hay xoá được. **Đã
gặp thật** ngày 2026-09-04 với một ngân sách bị sửa thành `end = start`, vi phạm
`chk_budget_end_after_start`; lối thoát duy nhất khi ấy là xoá dữ liệu site của
trình duyệt rồi pull lại từ server.

**Đã sửa 2026-09-07** theo đúng hướng ghi sẵn ở đây: *khoá thao tác là để bảo
vệ số liệu đã chốt, không phải để nhốt dữ liệu hỏng.*

- Quy tắc gom về **một nơi**: `domain/budget_locking.dart`,
  `budgetActionsLocked({expired, budget})`. Trước đó phép kiểm nằm rải **ba**
  chỗ trong giao diện — chặn vuốt xoá, bỏ nút Sửa trên trang chi tiết, và (chỗ
  thật sự quyết định) danh sách hết hạn dựng thẻ mà **không truyền** `onEdit`/
  `onDelete`. Nới hai chỗ đầu mà quên chỗ thứ ba thì không có gì đổi cả.
- `BudgetEntity` nay mang `syncError` (cột đã có sẵn trong bảng từ G3, chỉ là
  chưa đưa lên tầng model) và `hasSyncError`.
- Thẻ hỏng có dấu hiệu riêng — biểu tượng `cloud_off` kèm chữ "Chưa đồng bộ
  được". **Không** nêu nguyên văn lỗi backend: nó là stack trace hoặc câu
  tiếng Việt của server, cả hai đều không giúp người dùng làm gì.
- Dòng thông báo đầu tab đổi theo: câu cũ "không sửa hay xoá" nay chỉ hiện khi
  **không có** thẻ hỏng. Để nguyên là giao diện nói sai về chính nó — người
  dùng thấy một thẻ sửa được ngay dưới dòng bảo không sửa được.

**Yêu cầu gốc KHÔNG bị nới.** Ngân sách hết hạn và đồng bộ sạch vẫn khoá y như
trước. Hai phép canh cho chiều ấy nằm cùng chỗ với phép canh cho ngoại lệ:
`budget_locking_test.dart` (ca *"hết hạn và đồng bộ sạch thì khoá"*) và
`budget_tabs_view_test.dart` (ca *"bản ghi SẠCH vẫn khoá, kể cả khi có thẻ
hỏng"* — mở cả danh sách vì có **một** thẻ hỏng là bỏ luôn yêu cầu gốc mà không
ai nhận ra).

⚠️ Chuỗi `syncError` **rỗng** không tính là hỏng. Vài đường ghi xoá cột ấy về
rỗng chứ không về `null`; coi rỗng là "đang hỏng" sẽ mở khoá cho **mọi** ngân
sách hết hạn. Có test canh riêng ca này.

---

### ~~G16 — Xoá một danh mục cá nhân mặc định thì nó mọc lại ở mỗi lần mở app~~ · ✅ ĐÃ ĐÓNG (2026-09-05)

Chuỗi năm bước, mỗi bước đều đúng theo ý đồ riêng của nó, nhưng ghép lại thì hỏng:

1. Người dùng xoá một trong 5 danh mục cá nhân mặc định. Xoá mềm, đẩy lên, server đặt `Delete_at`.
2. Lần mở app sau, `PersonalDefaultCategories.ensureMissing()` chạy (gọi ở `auth_bloc.dart:135` khi đăng nhập và `:176` khi khôi phục phiên).
3. Hàm đó hỏi `CategoryDao.getNamesInUse()` xem tài khoản còn thiếu gì. Nhưng `getNamesInUse` lọc `isDeleted = false` **và** `deletedAt IS NULL` — nên nó **không thấy hàng người dùng vừa xoá**, và kết luận là còn thiếu.
4. `_create()` tạo lại danh mục với **UUID mới**, `syncStatus = 'pending'`.
5. Đẩy lên đụng `uq_category_owner_name_classify` phía PostgreSQL. Index đó **không có mệnh đề `WHERE`** nên hàng đã xoá mềm vẫn giữ chỗ tên → PostgreSQL trả **23505**.

Và bản ghi đó không thoát ra được: `_classifyFailure` (`lib/core/sync/sync_engine.dart`) không có nhánh nào cho vi phạm UNIQUE — chỉ có `23514` cho ràng buộc CHECK — nên 23505 rơi vào `transient` và được **đẩy lại ở mọi chu kỳ**. `_markBlockedById` chỉ chạy với `permanent`, nên bản ghi giữ nguyên `pending` mãi mãi.

**Mỗi lần mở app lại thêm một bản ghi kẹt.**

**Vì sao trước đây không ai thấy.** `getNamesInUse` lọc hàng đã xoá là **cố ý và đúng** — quy tắc 7 nói "hàng đã xoá mềm không giữ chỗ", nên người dùng phải tạo lại được danh mục cùng tên. Lỗi nằm ở chỗ `ensureMissing` dùng nhầm hàm đó để trả lời một câu hỏi khác: *"tài khoản này có chủ ý không muốn danh mục đó không?"* — chứ không phải *"tên này còn trống không?"*.

**Đã làm ở phía client (2026-09-04):** `_classifyFailure` có thêm `_uniqueConstraintPattern` khớp `23505 | violates unique constraint | unique constraint failed` → xếp `permanent`. Bản ghi hỏng nay bị chặn **theo thời gian** thay vì đẩy lại ở mọi chu kỳ, nên nó không còn kích hoạt giãn cách luỹ tiến và không kéo chậm các thay đổi khác. Hai test canh chừng ở `test/core/sync/sync_failure_handling_test.dart` — một cho dạng câu chữ Prisma bọc, một cho mã SQLSTATE trần, vì Prisma đổi cách diễn đạt theo phiên bản.

> ⚠️ Đây là **lớp cầm máu, không phải bản vá gốc**. Bản ghi vẫn được tạo ra ở mỗi lần mở app, chỉ là không còn đẩy lại vô hạn.

~~**Còn chờ backend:** thêm `WHERE "Delete_at" IS NULL` vào unique index~~ — ✅ **backend làm xong 2026-09-07**, xem đoạn cuối mục này. Hồ sơ: `CATEGORY_NAME_UNIQUENESS.md` mục 4.1 và mục 10 của `2026-09-04-ocr-classify-review.md`. Khi có, bản ghi bị chặn tự quay lại hàng đợi mà người dùng không phải làm gì.

> ### ⚠️ Cập nhật 2026-09-07 — cách đóng đã đổi, nhưng G16 vẫn đóng
>
> `foldIntoBackendDefaults()` **đã bị gỡ**. Hướng đi đảo chiều: mỗi tài khoản nay
> có **bản sao riêng** của toàn bộ bộ mặc định (`DefaultCategorySeeder`), còn
> hàng toàn cục lui về làm khuôn và không hiện ra ở đâu. Để hàm gộp chạy song
> song với bước sao chép là một vòng lặp huỷ lẫn nhau.
>
> **Vì sao G16 vẫn không quay lại:** luật tạo bản sao đếm **cả hàng đã xoá mềm**.
> Người dùng xoá một danh mục thì hàng xoá mềm còn đó, và lượt seed sau nhìn thấy
> nó nên **không tạo lại**. Ba chữ ấy là khác biệt **duy nhất** với `ensureMissing()`
> — ai "dọn dẹp" chúng đi là tái hiện nguyên vẹn G16.
>
> Thiết kế: `docs/superpowers/specs/2026-09-07-per-account-default-categories-design.md`.
>
> Phần dưới giữ nguyên làm hồ sơ của chặng 2026-09-05.

**Đóng ngày 2026-09-05 — bằng cách bỏ hẳn nguồn kích hoạt.** Câu hỏi mà `ensureMissing` không trả lời được ("chưa từng có" hay "người dùng đã cố tình xoá") nay **không cần trả lời nữa**: backend đã nhận đúng 5 danh mục ấy vào bộ mặc định của nó (`Create_by = 1`, `Is_default = true`), nên không tài khoản nào phải giữ bản riêng.

`ensureMissing()` được thay bằng `foldIntoBackendDefaults()`: gộp bản riêng vào bản mặc định (dời tham chiếu ở cả `transactions`, `budgets`, `bills`) rồi **xoá mềm** bản riêng — và **không tạo mới gì cả**. Danh mục mặc định là toàn cục, không thuộc tài khoản nào, nên không còn gì để "mọc lại" ở mỗi lần mở app.


Ba điều kiện dừng, vì gộp là thao tác phá huỷ:

| Tình huống | Xử lý |
|---|---|
| Không thấy bản mặc định (backend cũ, hoặc pull hỏng) | Không đụng gì — không tạo, không xoá |
| Trùng tên nhưng **khác classify** | Không gộp. Quy tắc 7 không tính classify, nên một danh mục người dùng tự tạo có thể trùng tên mà khác loại; gộp nó là âm thầm đổi loại của mọi giao dịch bên trong |
| Hàng của tài khoản khác | Không đụng. `getNamesInUse` trả cả hàng mặc định của mọi tài khoản nên phép lọc phải nằm ở chính chỗ tìm bản riêng |

~~Test canh chừng: nhóm `foldIntoBackendDefaults` — chín ca.~~ **Nhóm ấy đã bị xoá cùng hàm, 2026-09-07.** Phép canh cho cơ chế hiện tại nằm ở `test/features/category/data/services/default_category_seeder_test.dart` — 13 ca, trong đó ca *"bản sao đã bị xoá mềm thì KHÔNG tạo lại"* chính là phép canh G16.

✅ **Phần lệch ràng buộc với CSDL cũng đã đóng — 2026-09-07.** Trước đó `uq_category_owner_name_classify` không có `WHERE "Delete_at" IS NULL`, nên hàng đã xoá mềm vẫn giữ chỗ tên ở PostgreSQL trong khi client cho tạo lại (quy tắc 7): xoá rồi tạo lại một danh mục **của chính mình** cùng tên vẫn nhận 23505. Đợt migration 2026-09-07 thay nó bằng hai partial unique index **có** mệnh đề ấy — và bỏ luôn `Classify` khỏi khoá, đúng quy tắc 7. Đo trên CSDL thật cùng ngày.

⚠️ Lớp cầm máu `_uniqueConstraintPattern` trong `_classifyFailure` **vẫn giữ, đừng gỡ.** Nó không còn phục vụ ca trên nữa, nhưng 23505 vẫn xảy ra được — hai người dùng khác nhau trùng tên danh mục mặc định, hay bất kỳ ràng buộc UNIQUE nào khác — và không có nó thì bản ghi hỏng quay lại bị đẩy ở mọi chu kỳ. Từ 2026-09-07 nhánh phân loại đi theo `code` của backend (`UNIQUE_VIOLATION`, `CATEGORY_NAME_DUPLICATE`), regex chỉ còn là đường dự phòng.

---

### G17 — Trang đọc theo tài khoản không đăng ký lại khi phiên tới muộn · ✅ ĐÓNG (2026-09-07)

Tái hiện nhiều lần trên máy ảo. Vào Mục tiêu **ngay sau khi mở app nguội** thì
danh sách rỗng dù CSDL có dữ liệu; thoát ra vào lại là thấy.

**Nguyên nhân gốc — ghi chép cũ nói sai.** Bản ghi 2026-09-05 đổ cho `?? 0`.
Nhưng `?? 0` chỉ làm lỗi **im lặng** thay vì nổ; bỏ nó đi thì trang hiện thông
báo lỗi thay vì danh sách rỗng — vẫn hỏng, chỉ ồn ào hơn.

Gốc thật: `GoalPage` đọc mã tài khoản **đúng một lần**, bên trong
`BlocProvider.create`. `currentAccountIdOrNull` dùng `context.read<AuthBloc>()`
— `read` **không đăng ký** gì cả — và `create` chỉ chạy một lần trong đời của
provider. Trang dựng trước khi phiên khôi phục xong sẽ đăng ký `watchGoals(0)`
rồi **giữ nguyên đăng ký ấy mãi**. Thoát ra vào lại thì provider mới được dựng,
lúc đó phiên đã sẵn sàng — đúng cách người dùng vô tình "chữa" nó.

`home_page` và `transaction_page` không mắc lỗi này vì chúng dùng
`context.watch<AuthBloc>()`.

**Đã sửa cho trang Mục tiêu (2026-09-07):** `context.watch<AuthBloc>()` để
build chạy lại khi phiên tới, cộng `key: ValueKey(idaccount)` trên
`BlocProvider` để `create` chạy lần nữa với đúng tài khoản. Thiếu khoá thì
`watch` chỉ khiến build chạy lại mà cubit vẫn giữ đăng ký cũ — hai nửa phải đi
cùng nhau. Test canh: `goal_page_cold_start_test.dart`, đỏ đúng chỗ trước bản
vá (`Expected: contains <10>, Actual: [0]`).

**Đã kiểm và sửa cả bốn trang đọc theo tài khoản.** Mỗi trang có test riêng,
và mỗi test đều **đỏ trước** ở đúng assertion "phiên tới rồi mà trang chưa bao
giờ hỏi lại":

| Trang | Hỏng vì | Bằng chứng đỏ | Bản vá |
|---|---|---|---|
| `goal_page` | `currentAccountIdOrNull` + `BlocProvider.create` (chạy một lần) | `Actual: [0]` | `watch` + `ValueKey` |
| `budget_page` | y hệt | `Actual: []` ở assertion thứ hai | `watch` + `ValueKey` |
| `wallet_list_page` | y hệt, **cộng** bản chép tay `int.tryParse(user?.id ?? '') ?? 0` | `Actual: [0]` | `watch` + `ValueKey`, và gọi `currentAccountIdOrNull` thay bản chép tay |
| `bill_page` | **Khác:** nạp trong `addPostFrameCallback` của `initState` với `if (accountId == null) return;` | `Actual: []` | `watch` + `_thuNap()` gọi từ `build`, hoãn việc phát sự kiện sang `addPostFrameCallback` |

Ba trang đầu dùng chung bản vá `context.watch<AuthBloc>()` + `key:
ValueKey(idaccount)`. **Hai nửa phải đi cùng nhau:** thiếu `watch` thì build
không chạy lại, thiếu khoá thì build chạy lại mà cubit vẫn giữ đăng ký cũ.

`bill_page` không dùng được khoá vì nó **không có `BlocProvider`** — `BillBloc`
do router cung cấp. Ở đó bản vá là một hàm `_thuNap()` gọi từ `build`, có chốt
`_daNapCho` để chỉ nạp một lần cho mỗi mã tài khoản, và **hoãn việc phát sự
kiện** sang `addPostFrameCallback` — phát sự kiện bloc trong lúc dựng là lỗi
khung.

**Việc gỡ được kèm theo:** `wallet_list_page` là bản chép tay **cuối cùng** của
phép suy mã tài khoản mà G4 sinh ra để xoá bỏ. Nay cả bốn trang đều đi qua
`currentAccountIdOrNull`.

**Còn lại, cố ý chưa làm:** một trạng thái *"đang chờ phiên"* — khác hẳn *"không
có dữ liệu"* — dùng chung cho mọi trang. Bản vá hiện tại làm trang **tự khỏi**,
nhưng trong vài nhịp đầu người dùng vẫn thấy màn rỗng chứ không thấy "đang tải".
Đó là việc giao diện, tách riêng được, và không còn lỗi nào chờ nó.

⚠️ **`?? 0` giữ nguyên, có chủ ý.** Đây là bài học G4: đường ĐỌC không được
mặc định về `1` (tài khoản admin thật), và `0` là "rỗng, không phải dữ liệu
của ai". Nay nó chỉ còn là trạng thái **tạm** trong vài nhịp đầu, vì khoá
`ValueKey` kéo trang về đúng tài khoản ngay khi phiên tới.

---

### G18 — Nhánh dự phòng của lịch sử tích luỹ vẫn so bằng TÊN mục tiêu · ⏸️ THU HẸP DẦN (2026-09-07)

`TransactionDao.watchByGoal` có hai nhánh: nối bằng `goal_id` cho hàng có ID, và
`note LIKE '%Tích lũy mục tiêu: <tên>%'` cho hàng không có. Nhánh thứ hai mang
đúng khuyết điểm mà `goal_id` sinh ra để chữa — mục tiêu tên `"Mua"` vẫn nuốt
lịch sử của `"Mua xe"`.

**Đã đổi 2026-09-07:** backend có cột `transaction.Idgoal`, và client nay **đẩy**
`idgoal` trong payload giao dịch **lẫn đọc lại** ở nhánh pull. Nguồn sinh ra hàng
thiếu ID đã tắt: từ nay mọi hàng đi qua đồng bộ đều mang liên kết.

**Vì sao vẫn chưa gỡ được nhánh so tên:** hàng **đã nằm sẵn** trên server đều
mang `Idgoal = NULL`, vì chúng được đẩy lên trước khi client biết gửi trường này.
Chúng chỉ nhận ID khi được đẩy lại — tức khi người dùng sửa gì đó, hoặc không bao
giờ. Bỏ nhánh so tên bây giờ là lịch sử tích luỹ **đã có** biến mất khỏi màn hình.
Nhánh ấy nay **teo dần** thay vì đứng yên; gỡ được khi không còn hàng nào
`goal_id IS NULL` mà ghi chú khớp mẫu.

**Đã đo trên máy thật** (`emulator-5554`, tài khoản 10, 2026-09-07): trước bản vá,
cả **12** giao dịch tích luỹ trên server đều `Idgoal = NULL` — chính con số ấy là
thứ nhánh `Value.absent()` bảo vệ. Sau bản vá, gửi thêm 1.000 đ vào `MuaXe` sinh
ra hàng **đầu tiên** có `Idgoal`, và giá trị khớp chính xác `idgoal` của mục tiêu
(`dc2656fa-…`); `current_amount` đi từ 1.100.000 lên 1.101.000. Mười hai hàng cũ
vẫn `NULL` — đúng như mô tả ở trên, chúng chỉ nhận ID khi được đẩy lại.

⚠️ **Nhánh pull dùng `Value.absent()`, KHÔNG ghi đè null.** Server im lặng về
`idgoal` nghĩa là *chưa biết*, không phải *hãy xoá*. Ghi đè thẳng thì đúng ở chu
kỳ đồng bộ đầu tiên sau bản vá, mọi liên kết cục bộ đang có bị xoá sạch và toàn
bộ lịch sử rơi xuống nhánh so tên — tái hiện nguyên vẹn G18 mà không có lỗi nào
báo ra. Đã dựng bản ngây thơ để xem test có bắt được không: **có**, và đó là
`'hàng server KHÔNG có idgoal thì liên kết cục bộ phải còn nguyên'`.

⚠️ Điều kiện `goal_id IS NULL` ở nhánh dự phòng là thứ chặn không cho một hàng
đã có chủ bị mục tiêu khác nhận vơ. **Đừng bỏ nó khi dọn dẹp.**

---

### G19 — Tiến độ mục tiêu và số dư ví lệch nhau được, và app chỉ cảnh báo · ✅ CỐ Ý (2026-09-05)

Ghi ở đây để người sau **không "sửa"** nó.

Tiêu tiền từ ví tích luỹ bằng một giao dịch thường không hạ `current_amount` —
giao dịch ấy không mang `goal_id`. Mục tiêu có thể ghi "đã tích 2 triệu" trong
khi ví chỉ còn 300 nghìn.

**App không tự hoà giải, và đó là chủ ý.** Không đủ căn cứ để hoà giải đúng: một
ví phục vụ được nhiều mục tiêu, ví tích luỹ cũng chứa tiền không thuộc mục tiêu
nào, và tự hạ tiến độ là bất ngờ với người dùng. `canhBaoViKhongDu()` phơi ra sự
lệch để họ tự quyết. Lý do đầy đủ ở `docs/GOAL_FEATURE.md` mục 3.4.

Muốn tiến độ phản ánh thực tế thì phải **đánh dấu** khoản rút — luồng "Rút khỏi
mục tiêu" đã có, nhưng khoản chi tiêu thường thì theo định nghĩa không thuộc mục
tiêu nào.

---

### ~~G20 — Giao dịch trích bù mang dấu thời gian **lúc bù**, không phải mốc của kỳ~~ · ✅ ĐÃ SỬA (2026-09-05)

**Hiện trạng:** bộ trích tự động chạy trong vòng quét, tức khi app mở. Bỏ app ba
ngày với chu kỳ hàng ngày thì ba kỳ được trích bù cùng lúc — và cả ba hàng giao
dịch đều mang `date = DateTime.now()`, tức thời điểm bù. Đã đo trên máy ảo: ba
khoản của kỳ 06, 07, 08/09 đều ghi `2026-09-08 14:28`.

Thông báo thì **ngược lại** — nó lấy mốc kỳ làm `createdAt`, nên trung tâm thông
báo hiện đúng ngày từng kỳ. Hai nơi nói hai chuyện khác nhau về cùng một sự
việc.

**Bán kính ảnh hưởng:** không sai một đồng nào — số tiền, số dư ví và tiến độ
đều đúng. Chỉ phần thống kê **theo ngày** thấy ba khoản dồn vào một ngày.

**Vì sao hoãn (bối cảnh gốc):** `depositToGoal` cố tình không nhận tham số ngày;
nó luôn ghi "bây giờ", đúng như một khoản nạp tay. Thêm một tham số `date` tuỳ
chọn là mở đường cho nơi gọi khác truyền vào một ngày bịa — và đó là tầng ghi
tiền, chỗ ít đáng nới lỏng nhất. Muốn sửa thì phải làm cùng lúc: thêm tham số,
chặn nó ở mọi đường gọi khác, và viết test canh chừng.

**Đã sửa thế nào:** `depositToGoal` nhận `occurredAt`, chặn **hai đầu** (không ở
tương lai, không trước `startDate` của mục tiêu). Nơi gọi duy nhất là
`GoalAutoDepositRunner`; đường nạp tay không truyền, và `GoalCubit` cố ý không
phơi tham số ra. Chỉ cột `date` lùi lại — `updatedAt` vẫn là "bây giờ" vì nó là
sổ sách đồng bộ. Chi tiết và các phương án đã loại: mục **3.14** `GOAL_FEATURE.md`.

**Kiểm trên máy ảo 2026-09-05:** ba kỳ bù ghi lúc 17:30 mang `date` 06/07/08-09
lúc 08:00 với cùng một `updated_at` 17:30, và lịch sử tích luỹ (`orderBy: date
desc`) **xen kẽ đúng ngày** thay vì dồn lên đầu — đúng chỗ mà ghi chú cũ dặn phải
kiểm bằng mắt.

⚠️ **Bẫy để lại cho người sau:** runner nhận `now` tiêm vào, còn `depositToGoal`
đọc `DateTime.now()` — ở production hai thứ ấy là **một** đồng hồ. Bộ test cũ giả
lập kịch bản ở **tương lai** nên vỡ ngay khi phép chặn đầu trên ra đời; nay cả
`goal_auto_deposit_runner_test.dart` nằm trong quá khứ. Đừng "sửa" nó ngược lại.

---

### G21 — Cấu hình trích tự động không theo người dùng sang máy khác · ✅ ĐÓNG (2026-09-07)

**Đã đóng.** Backend thêm ba cột `auto_deposit_amount`,
`auto_deposit_wallet_id`, `auto_deposit_last_run` vào bảng `goal` trong đợt
2026-09-07; client đẩy và kéo **cả ba cùng một lúc**. Bật trích ở máy A rồi
đăng nhập máy B thì B nhận đủ cấu hình **lẫn mốc kỳ gần nhất**, nên nó không
trích lại kỳ mà A vừa trích xong.

**Đã đo trên máy thật, không chỉ bằng test** (`emulator-5554`, tài khoản 10,
2026-09-07): mục tiêu `MuaXe` vốn đã bật trích 100.000 đ/tháng từ ví `test`
nhưng ba cột trên server vẫn `null` — đúng vì trước bản vá chúng không bao giờ
được đẩy. Bấm Lưu một lần là cả ba lên tới PostgreSQL: `auto_deposit_amount`
= 100000, `auto_deposit_wallet_id` = ví **`test` (Cash)**, `auto_deposit_last_run`
có giá trị. Mục tiêu `MuaDT` (không bật trích) vẫn `null` cả ba, nên không phải
ghi bừa. Đáng chú ý nhất: ví nguồn khác hẳn `idwallet` = ví **`Tiết kiệm`
(Saving)** là ví NHẬN — gửi nhầm một trong hai thì app sẽ trích tiền từ đúng cái
ví lẽ ra phải nhận, và không có gì báo lỗi.

⚠️ **Ba cột vẫn phải đi cùng nhau.** `auto_deposit_last_run` là cột chặn trích
hai lần. Ai đó "dọn dẹp" payload và bỏ nó ra thì mỗi máy giữ một mốc riêng và
**cả hai cùng chuyển tiền** — tệ hơn hẳn hiện trạng cũ, nơi máy thứ hai đơn
giản là không trích gì. `sync_payload_contract_test.dart` khoá bộ khoá của
payload mục tiêu (21 trường **lúc ấy** — đếm lại bằng máy 2026-09-18 từ chính
tệp test: **22**, sau khi `priority` vào ngày 2026-09-08) nên nó bắt được ngay.

**Khe hở còn lại, chấp nhận được:** hai máy cùng mở, cùng tới kỳ, cùng chưa kịp
kéo `last_run` của nhau thì vẫn trích hai lần. Hẹp vì trích chỉ chạy khi app mở,
và `Current_amount` là giá trị tuyệt đối nên LWW hội tụ chứ không cộng dồn sai.
Vá triệt để cần một khoá phía máy chủ trên `(Idgoal, kỳ trích)` — phụ thuộc
`transaction.Idgoal`, cột đã có và client đẩy/đọc từ 2026-09-07 (xem **G18**);
còn khoá phía máy chủ ấy thì chưa có (đo 2026-09-11: bảng `goal` không có ràng buộc
duy nhất nào ngoài khoá chính).

---

### G22 — Giờ trong mốc trích chỉ giữ được MỘT chiều · ✅ CỐ Ý (2026-09-05)

Ghi ở đây để người sau **không "sửa"** nó, và không hứa với người dùng nhiều hơn
những gì app làm được.

Người dùng chọn được "ngày 15 hàng tháng lúc 08:00". Giờ ấy được tôn trọng theo
chiều **không bao giờ sớm hơn** — nhưng bộ trích chạy khi app mở, nên nếu 21 giờ
mới mở app thì nó trích lúc 21 giờ.

Có một lời nhắc đặt trước qua AlarmManager nổ đúng 08:00 kể cả khi app đóng
(`ReminderScheduler`), nhưng nó chỉ **báo tin**; tiền vẫn chỉ chuyển khi mở app.

**Vì sao không làm WorkManager:** tác vụ nền phải mở một kết nối SQLite **thứ
hai** vào cùng tệp để chuyển tiền. Đây là chỗ duy nhất trong app tự chuyển tiền
khi người dùng vắng mặt; đổi vài giờ sớm hơn lấy rủi ro ấy là không đáng. Quyết
định này do người dùng chọn sau khi được nêu cả ba phương án.

**Nếu vẫn muốn làm:** `GoalAutoDepositRunner` viết độc lập với *khi nào* nó được
gọi, nên thêm một trigger nền chỉ là gọi `chay()` thêm một chỗ nữa. Phần khó nằm
ở kết nối CSDL trong isolate nền, không nằm ở logic trích.

---

### G23 — Bản sao danh mục chỉ đầy đủ khi bộ mặc định CỤC BỘ đầy đủ · ⏸️ CHẤP NHẬN ĐƯỢC (2026-09-07)

`DefaultCategorySeeder` sao chép từ những hàng mặc định **đã có trên máy này**
(`getBackendDefaults()` đọc SQLite, không gọi mạng). Mà pull là **tăng dần theo
`since`**: hàng nào không đổi kể từ mốc kiểm cuối thì không bao giờ được gửi lại.

Hệ quả: một máy có thể chỉ biết một phần bộ mặc định của server, và bản sao thiếu
theo. **Đo được 2026-09-07 trên `emulator-5554`:** server có **18** hàng mặc định,
máy ấy tạo được **13** bản sao (hai trong số còn lại bị chặn đúng luật vì tài
khoản từng có bản riêng cùng tên; ba cái còn lại đơn giản là chưa từng về máy).

**Vì sao không sửa ngay:** bước seed chạy sau **mọi** lần pull và luỹ đẳng, nên
khi một hàng mặc định thật sự về máy thì bản sao được tạo ở lượt kế tiếp. Người
dùng không mất gì — họ chỉ có ít danh mục dựng sẵn hơn, và tự thêm được.

**Nếu muốn dứt điểm:** cần một lần pull đầy đủ bộ mặc định (bỏ `since` cho riêng
nhánh `is_default = true`) ở lần đăng nhập đầu. Đó là thay đổi ở đường đồng bộ,
không phải ở bước seed — đừng vá bằng cách cho seeder gọi mạng.

---

### ~~G24 — Màu danh mục không đi qua đồng bộ, vì client dùng sai tên khoá~~ · ✅ ĐÓNG (2026-09-11; trước đó cùng ngày ghi "lỗi phía client, sửa được, chưa sửa", và 2026-09-07 ghi "không có chỗ trên server · ⛔ chặn ở backend")

> ✅ **Đã sửa 2026-09-11 (TDD).** `SyncPayloadNormalizer.categoryForPush` đổi `colour` → `color` — một chỗ phủ cả thao tác
> danh mục đang chờ lẫn danh mục mà bước 1b gửi kèm, vì cả hai đi qua normalizer ở bước POST; nhánh kéo về đọc
> `c['color']` (`null` thì rơi về màu cục bộ như cũ). Test: một ca ở `sync_payload_normalizer_test.dart`; trong
> `sync_payload_contract_test.dart` tập khoá danh mục nay khoá `'color'`, ca kéo về đọc `color`, và ca mới "server chưa
> có màu thì màu cục bộ còn nguyên" — ba ca đầu đỏ đúng lý do trước khi sửa. **Kiểm trên máy ảo:** mở "Ăn uống" ở màn
> Quản lý danh mục, lưu lại không đổi gì → đẩy `1/1`, không xung đột → `category.Color` từ `NULL` thành `#FF5722`, kéo về
> vẫn `#FF5722`.
>
> ⚠️ **Danh mục đã `synced` từ trước vẫn mang `Color = NULL` trên server cho tới khi được lưu lại.** Đẩy cùng mốc
> `update_at` thì server trả xung đột "bản server mới hơn" và giữ bản của nó — nên bước 1b (gửi kèm danh mục khi đẩy
> giao dịch) **không** tự bổ sung màu. Chưa bổ sung hàng loạt: đổi `updatedAt` của mọi danh mục để đẩy lại là thay đổi
> dữ liệu, chờ người dùng quyết. Đoạn dưới là ảnh chụp trước bản sửa.

**Hiện trạng (đo 2026-09-11, sau khi gộp `main` @ `cc65f4f` và CSDL dev áp `database/12`).**
Server **đã có** chỗ: cột `category."Color"` (`varchar(9)`), `/sync/push` nhận khoá
`color` (`sync.repository.js:149`, ghi ở nhánh tạo `:175` và nhánh sửa `:196`), và
`/sync/pull` trả `color` (`:228`). Backend không có nhánh nào đọc `colour`.

Client thì vẫn nói **`colour`** cho danh mục, ở cả hai chiều:

- payload danh mục dựng tay mang `'colour'` ở **hai** chỗ: `sync_engine.dart:1025` (thao tác
  danh mục đang chờ) và `:1109` (bước 1b — kèm danh mục người dùng mà một giao dịch chờ trỏ
  tới, nên chỗ này gửi `colour` ở **mọi** lần đẩy một giao dịch có danh mục);
- `SyncPayloadNormalizer.categoryForPush` (`sync_payload_normalizer.dart:101-116`)
  **không** đổi khoá — khác `walletForPush` ngay trên nó (`:82-83`), vốn đổi
  `colour` → `color`;
- nhánh kéo về đọc `c['colour']` (`sync_engine.dart:603`), nên luôn nhận `null`;
- và `sync_payload_contract_test.dart:333` khoá `'colour'` trong tập khoá danh mục
  — tức **chính bộ test đang canh bản sai**.

Hệ quả không đổi so với ảnh chụp bên dưới — màu chỉ sống trên máy đã chọn — nhưng
**nguyên nhân đã đổi**: không còn là thiếu cột mà là lệch tên khoá. Đúng kiểu hỏng
im lặng của quy tắc 4 `CLAUDE.md`, và nay nằm hẳn ở phía client.

**Kiểm đầu-cuối 2026-09-11** (máy ảo, tài khoản 10, backend của nhánh đã gộp): danh mục
"Ăn uống" (`70b7e251-…`) mang `colour = '#FF5722'` trong SQLite nhưng `category."Color"`
vẫn `NULL` trên PostgreSQL sau hai lần đẩy, và bộ chọn danh mục hiện mọi danh mục bằng màu
mặc định. Mỗi lần đẩy một giao dịch có danh mục, bước 1b gửi kèm danh mục ấy và server trả
xung đột "bản server mới hơn" (hai bên cùng `Update_at`) — vô hại, không ghi đè gì, nhưng là
lý do log đồng bộ báo `1 conflicts` ở những lần ấy.

**Cách sửa (thuần client) — ✅ đã làm 2026-09-11 theo đúng ba bước dưới:**

1. **Đẩy:** đổi `colour` → `color` trong `categoryForPush`, theo đúng khuôn
   `walletForPush`. Chọn **một** chỗ đổi (normalizer hoặc hai chỗ dựng payload),
   đừng cả hai.
2. **Kéo về:** đọc `c['color']` (có thể giữ `c['colour']` làm dự phòng). Nhánh ấy
   đã rơi về màu cục bộ khi server trả rỗng (`sync_engine.dart:629-640`), nên hàng
   server còn `Color = NULL` **không** xoá màu đang có trên máy.
3. **Cập nhật `sync_payload_contract_test.dart` cùng lúc:** tập khoá danh mục
   `'colour'` → `'color'`, và thêm một ca kéo về như ca ví ở `:639`.

⚠️ Sửa xong thì màu chỉ lên server khi danh mục được **đẩy lại** — hàng đã
`synced` từ trước vẫn mang `Color = NULL` cho tới lần sửa kế tiếp, cùng dạng
"teo dần" với G18. Phía backend không cần làm gì; hai việc **tuỳ chọn** ghi ở mục
18 §2.3 (`CAN-LAM/VERIFY_7675B35_REMAINING.md`): nhận thêm bí danh `colour` cho
bản client cũ, và `getDefaultCategories` chưa trả `color`.

> **Ảnh chụp 2026-09-07 — lý do cũ, đúng tới trước khi gộp `main`.** Bốn đoạn dưới
> giữ nguyên làm hồ sơ; vế "không có cột" và "client không sửa được" nay **sai**.

Bảng `category` phía PostgreSQL có **đúng 12 cột** và không cột nào cho màu.
Client vẫn đẩy khoá `colour` lên ở mỗi lần đồng bộ, backend **bỏ qua im lặng** —
đúng kiểu hỏng mà quy tắc 4 của `CLAUDE.md` mô tả, lần này còn khó thấy hơn vì
tên trường không sai, chỉ là không có chỗ nào để ghi.

Hệ quả: màu người dùng chọn **chỉ sống trên máy đã chọn**. Đăng nhập máy khác
hoặc cài lại app là mất, không lỗi, không log.

Lỗi này **có sẵn từ trước**, không do thay đổi 2026-09-07 sinh ra — nhưng bán
kính vừa rộng ra hẳn: trước đây người dùng gần như không đổi màu được gì vì hàng
mặc định là toàn cục và bị chặn sửa; nay họ sở hữu cả bộ và sửa được từng cái.

**Client không sửa được** — không có cột thì không có chỗ ghi. Tài liệu xin:
`docs/superpowers/backend/DA-XONG/CATEGORY_COLOUR_COLUMN.md`.

---

### G25 — Hai máy cùng sắp lại thứ tự ưu tiên khi ngoại tuyến thì được một thứ tự trộn · ✅ CỐ Ý (2026-09-08)

Thứ tự ưu tiên mục tiêu (schema v19) đồng bộ qua cột `Priority`, và phép phân
xử của dự án là **LWW theo từng hàng**. Sắp lại danh sách thì lại là một thao
tác trên **cả danh sách**. Hai thứ ấy không khớp nhau.

Máy A kéo `MuaXe` lên đầu, máy B kéo `MuaDT` lên đầu, cả hai đang ngoại tuyến.
Khi cùng đẩy lên, mỗi hàng thắng riêng theo `Update_at` của nó — kết quả có thể
là một thứ tự **không giống lần sắp nào**. Không hàng nào sai, không có lỗi,
không có gì trên màn hình nói ra điều đó.

**Vì sao không vá:**

- Vá triệt để cần khoá thứ tự kiểu **phân số hoặc chuỗi** (`"a0"`, `"a0V"`, lối
  của LexoRank) thay cho số nguyên. Đó là đổi cả kiểu dữ liệu ở hai đầu, cho
  một tình huống cần hai máy cùng hoạt động và cùng ngoại tuyến.
- Hậu quả tệ nhất là người dùng **kéo lại vài mục tiêu**. Không mất tiền, không
  mất bản ghi, không kẹt hàng đợi đẩy — khác hẳn G21, nơi cấu hình trích tự
  động không sang máy khác thì tiền không được chuyển mà cũng không ai biết.
- FlowMoney gần như luôn chỉ có một máy hoạt động cho mỗi tài khoản.

**Bán kính:** `uuTienSauKhiKeo`, `GoalRepositoryImpl.capNhatUuTien`, và nhánh
`priority` của `sync_engine.dart`. Ghi ở đây để người sau không tưởng chỗ này
bị bỏ sót — nó đã được cân nhắc, và lý lẽ nằm ở
`docs/superpowers/backend/DA-XONG/2026-09-05-backend-goal-priority.md` mục 5.

> ⚠️ Đừng nhầm với một lỗi **khác** cũng thuộc vùng mục tiêu, nay **đã sửa**
> (2026-09-08): `GoalDetailPage` không nghe dòng dữ liệu (bẫy 4.5
> `GOAL_FEATURE.md`), nên đồng bộ kéo về một thay đổi của mục tiêu **đang mở**
> thì màn hình vẫn hiện số cũ. Bán kính của nó vừa rộng ra vì `priority` nay
> cũng đi qua đường đồng bộ. Đó là lỗi **sửa được ở client**, không phải một
> đánh đổi — nên nó không có mục G nào và nằm trong danh sách việc phải làm.

---

### ~~G26 — Không có màn "Giao dịch chờ duyệt" cho giao dịch ngân hàng về~~ · ✅ ĐÓNG BẰNG QUYẾT ĐỊNH SẢN PHẨM (2026-09-18)

> ✅ **Đóng 2026-09-18 — nhóm BỎ HẲN tính năng liên kết ngân hàng.** Mục này
> không còn là một lỗ hổng: màn duyệt giao dịch ngân hàng không thiếu, nó
> **không còn nằm trong sản phẩm**. Phần client của luồng ấy đã gỡ cùng ngày —
> màn mockup `bank_link_page.dart`, thẻ "LIÊN KẾT NGÂN HÀNG" ở màn Quản lý ví,
> hai route, và `RealtimeEvent.giaoDichNganHang`. Xem khối
> "🏦 Gỡ phần client của liên kết ngân hàng" ở mục 14 `docs/PROJECT_CONTEXT.md`.
>
> ⚠️ **Hệ quả cho việc lên kế hoạch:** đoạn "Bán kính nếu làm" dưới đây từng đặt
> `status` và `provider` vào hàng đợi "sẽ phải thêm vào hợp đồng đồng bộ". Nay
> **không**: hai cột ấy ở lại ngoài hợp đồng, và đừng viện mục này để mở chúng
> ra. Backend vẫn giữ module `bank/` cùng ba endpoint của mình — đó là việc của
> họ, client không xin gì.
>
> Phần còn lại giữ nguyên làm ảnh chụp lý do hoãn ban đầu.

Khi nối Socket.io, client bắt được sự kiện `bank_transaction.incoming` và hiện
một toast. Nhưng nó **không** có chỗ nào để người dùng *duyệt* giao dịch ấy —
gán danh mục, xác nhận hoặc từ chối.

Backend đã có sẵn cả ba endpoint (`api/bank.routes.js`):

- `GET  /api/bank/pending-transactions`
- `POST /api/bank/confirm-transaction`
- `POST /api/bank/reject-transaction`

**Vì sao hoãn:** đây là **một tính năng riêng**, không phải phần còn thiếu của
việc nối socket. Nó kéo theo cả một luồng liên kết ngân hàng (`register-account`,
`link-url`, WebView của SePay), một màn danh sách, và một khái niệm mới trong
giao diện — "giao dịch chưa được duyệt" — mà SQLite cục bộ hiện **không phân
biệt được**: cột `status` và `provider` có trong bảng nhưng **không nằm trong
hợp đồng đồng bộ theo chiều nào cả** (quy tắc 4 `CLAUDE.md`), nên một giao dịch
`Pending` kéo về qua `/sync/pull` trông y hệt một giao dịch bình thường.

**Bán kính nếu làm:** thêm `status`/`provider` vào hợp đồng đồng bộ (và do đó
vào `sync_payload_contract_test.dart`), một màn hình mới, và một badge đếm ở
tab Giao dịch. ⚠️ **Phải lên Stitch trước** — đây là màn hình mới, chưa có
thiết kế nào.

**Không chặn gì đang chạy.** Kênh realtime vẫn có ích mà không cần nó: mọi sự
kiện đều đánh thức đồng bộ, nên giao dịch ngân hàng vẫn hiện ra trong danh sách
sau vài giây thay vì sau 15 phút.

---

### ~~G27 — Không còn cách nào nói "ví này được phép âm"~~ · ✅ ĐÓNG (2026-09-17)

> ✅ **Đóng 2026-09-17 — cờ `Wallets.allowNegative`, schema v23.** Ví đánh dấu
> "cho phép âm" không sinh cảnh báo số dư nào cả (**cả** `walletNegative` lẫn
> `walletLowBalance`, đúng luật mà chốt `debt` cũ đã có), và màn Quản lý ví thôi
> tô đỏ **cả biểu tượng lẫn số tiền**. Công tắc ở màn Thêm ví và Sửa ví.
>
> ⚠️ **Cột CỤC BỘ, không đi qua đồng bộ** — payload ví vẫn **13 trường**. Bật cờ
> trên máy A thì máy B không biết. Mở đồng bộ cần một cột PostgreSQL và một tài
> liệu `CAN-LAM`; người dùng chốt **không** mở lại hàng đợi ấy. Có **test quét
> `lib/` thứ bảy** canh cờ không lọt vào `sync_engine` / `sync_payload_normalizer`
> / hợp đồng payload — đúng bài học `wallet.status`, nơi ba chú thích ở ba tệp
> khác từng nói một cột cục bộ là "đi ra máy khác".
>
> **Bản sai có chủ ý: bảy lượt**, và **hai** trong bảy đi lọt ở vòng đầu — cả hai
> đều là lỗ hổng trong chính bộ test vừa viết, không phải trong mã:
>
> 1. Ca *"cờ cũng tắt cảnh báo SẮP CẠN"* dựng ví số dư **−5.000.000**, mà nhánh
>    sắp cạn chỉ chạy khi `balance >= 0` — nên nó **không canh gì**, y hệt G43.
>    Số dư phải **dương** và dưới ngưỡng thì ca mới có nghĩa.
> 2. Ca datasource đặt **sai tiền đề**: quên cột trong `_toCompanion` **không**
>    làm cờ tự tắt — `write(companion)` chỉ ghi cột có mặt, nên giá trị cũ ở
>    lại và triệu chứng thật là **cờ không đổi được**. ⚠️ Chú thích của `status`
>    ngay cạnh trong `_toCompanion` mang đúng nhận định sai ấy; chưa sửa, đã ghi
>    lại trong ca test.
>
> ⚠️ Máy ảo bắt được một chỗ **nửa việc**: bản đầu chỉ đổi màu **biểu tượng**,
>  còn con số `-100.000 đ` vẫn đỏ chói — mà đó mới là thứ mắt đọc trước. Màu ấy
>  là `AppColors.error`, tức màu **cảnh báo** chứ không phải quy ước dấu; ví lưu
>  trữ đã có sẵn tiền lệ chuyển số âm sang xám vì đúng lý do đó.
>
> Nghiệm thu máy ảo 2026-09-17 với ví `test` (−100.000): migration v23 chạy sạch
> trên CSDL đang có (33 giao dịch nguyên vẹn), bật cờ → ví trung tính hoàn toàn,
> và cờ **sống sót qua `force-stop` + khởi động lại**. ⚠️ Vế thông báo thì lượt
> quét trả `0 hàng mới` **không chứng minh được gì** — khoá chống trùng của ngày
> hôm ấy đã tồn tại từ trước khi bật cờ; vế ấy do bộ test canh.

*Các đoạn dưới giữ nguyên — chúng ghi lại vì sao lỗ hổng này từng tồn tại.*

Từ 2026-09-07, ví loại `debt` mang số dư âm **không** sinh cảnh báo: âm là đúng
bản chất của nó, và trước đó nó bị nhắc mỗi ngày cho tới khi trả hết nợ — đúng
loại nhiễu khiến người dùng tắt cả nhóm thông báo.

Ngày 2026-09-09 loại ví thu về ba (`WalletType`: `cash | bank | saving`) vì
`ewallet` và `debt` vỡ `chk_wallet_type` của PostgreSQL và làm ví **kẹt hàng
đợi đẩy vĩnh viễn**. Ví cũ chuyển thành `bank`, và chốt kia mất chỗ bám: không
còn tín hiệu nào để phân biệt "âm vì đang nợ" với "âm vì ghi nhầm".

**Hệ quả:** ai từng theo dõi thẻ tín dụng bằng ví `debt` nay được nhắc "ví âm"
mỗi ngày trở lại.

**Vì sao hoãn:** chữa đúng cần một khái niệm **mới** — một cờ "ví được phép âm"
trên bảng `wallets` — chứ không phải khôi phục chuỗi `'debt'` đã chết. Cờ ấy là
cột mới ở **cả hai đầu** (client + PostgreSQL, tức một tài liệu `CAN-LAM` nữa),
cho một tình huống mà CSDL hiện **không có hàng nào**: đo 2026-09-09, server chỉ
có ví `Cash` (3) và `Saving` (2).

**Bán kính nếu làm:** cột mới trên `wallets` + hợp đồng đồng bộ
(`sync_payload_contract_test.dart`), một công tắc ở trang sửa ví, và khôi phục
hai nhánh loại trừ trong `_walletCandidates`. Hai test ở
`notification_rules_goal_wallet_test.dart` đã ghi lại chiều cũ lẫn chiều mới —
đọc chúng trước khi làm.

---

### ~~G28 — Lưu trữ ví chỉ sống trên máy đã bấm~~ · ✅ ĐÓNG (2026-09-14; tiêu đề trước ghi "⏸️ hết chặn phía server, chờ client mở lại" 2026-09-10, trước nữa "chặn ở CSDL — tệp `database/7` chưa áp", trước nữa "chặn ở backend")

> ✅ **Đóng 2026-09-14 — `wallet.status` đi qua đồng bộ hai chiều.** Lưu trữ ví trên
> máy A nay có hiệu lực trên máy B của cùng tài khoản. Ba mảnh khớp nhau, thiếu mảnh
> nào cũng vô hiệu cả ba: payload đẩy mang `status` (**13 trường**), `walletForPush`
> dịch sang `'Active'`/`'Inactive'` qua `WalletStatus.khoaGuiLen`, nhánh kéo về đọc
> ngược lại về **chữ thường**. Cộng **migration schema v22** đánh dấu ví lưu trữ cũ
> để đẩy lại — chúng đang ở `synced` nên không ai gửi lại chúng, trong khi cột
> `Status` của server là `NOT NULL DEFAULT 'Active'`; thiếu bước ấy thì lượt pull
> **đầu tiên** sau khi cập nhật app lặng lẽ bỏ lưu trữ chúng. Bốn mảnh vào **cùng một
> commit** (`268eb50`) vì bước cứu chỉ chạy **một lần trong đời** mỗi máy.
> Spec: `docs/superpowers/specs/2026-09-14-g28-luu-tru-vi-qua-dong-bo-design.md`.
>
> ⚠️ **Thứ duy nhất còn có thể làm G28 hỏng, và client không chặn trước được:** máy
> chủ nào **chưa áp `database/7`** vẫn giữ `Status` ở `varchar(7)` và sẽ từ chối
> `'Inactive'` (8 ký tự) — ví lưu trữ **kẹt hàng đợi đẩy vĩnh viễn, im lặng**. CSDL
> dev đã áp (đo 2026-09-14: `varchar(20)`, `NOT NULL`, `DEFAULT 'Active'`); **chưa đo
> môi trường nào khác**.
>
> *Các đoạn dưới giữ nguyên theo thứ tự thời gian — chúng ghi lại vì sao cột này từng
> là cột cục bộ, không phải trạng thái hôm nay.* Dòng cũ ghi *chờ client mở lại* —
> đúng tới trước bản này.

Tính năng **lưu trữ ví** (2026-09-10) ghi trạng thái vào cột `wallets.status`
của SQLite. Cột cùng tên đã có sẵn ở PostgreSQL và `upsertWallet` phía backend
đã xử lý nó ở cả nhánh tạo lẫn nhánh cập nhật — nên nhìn qua thì đây là thứ đẩy
lên được ngay. Nó không.

Lược đồ **tự mâu thuẫn ở đúng cột ấy**, hai phép đo trên cùng một cột:

```
chk_wallet_status => CHECK (("Status")::text = ANY (ARRAY['Active','Inactive']))
Status            => character varying(7)
```

CHECK tuyên bố `'Inactive'` hợp lệ; kiểu cột không chứa nổi nó — chuỗi ấy dài
**8 ký tự**. Không giá trị nào vừa **cả hai** ngoài `'Active'`, nên trên thực tế
cột này là một **hằng số** chứ không phải một trạng thái.

Bản đầu của client có đẩy `status` lên, và trên máy ảo nó **kẹt hàng đợi đẩy**:
backend trả lỗi ràng buộc, bản ghi quay lại hàng đợi và thử lại ở mọi chu kỳ,
kéo chậm cả hàng đợi. Đây là điều `flutter test` **không** bắt được — hợp đồng
đồng bộ được canh bằng adapter giả, không bằng CSDL thật.

**Vì sao không vá ở client:** không có chỗ ghi thì không có cách ghi. Cột được
gỡ khỏi **cả hai** chiều của đồng bộ, cùng diện với `bills.autoPayEnabled` (và
`bills.anchorDay` cho tới 2026-09-12 — nay cột ấy đã đi qua đồng bộ). Chiều **kéo về** phải im lặng cùng lúc chứ không chỉ chiều
đẩy: client không đẩy cột này nên server giữ `'Active'` cho mọi ví của tài khoản còn dùng (chỉ ví của tài khoản đã bị xoá hẳn mới bị `scheduler.service.js` đặt `'Inactive'`)
— nên một bản chỉ gỡ chiều đẩy sẽ khiến ví vừa lưu trữ **tự bỏ lưu
trữ** sau đúng một chu kỳ đồng bộ, im lặng. Có test riêng canh ca ấy, và nó gửi
`'status': 'Active'` chứ không gửi payload thiếu khoá, vì dạng thiếu khoá không
phân biệt được hai cách cài đặt.

**Hệ quả:** hai máy cùng một tài khoản thấy khác nhau, và người dùng không được
báo gì. Cùng hạng với `bill.Auto_pay` nhưng **nhẹ hơn**: lưu trữ ví không tự
tiêu tiền của ai, chỉ làm một ví hiện lại ở máy chưa bấm.

**Bán kính khi mở lại** (phía server đã xong trên CSDL dev tối 2026-09-10 — một dòng `ALTER TABLE`, không cần đụng CHECK —
nó đã cho phép đúng hai giá trị cần thiết), rồi client mở lại **ba chỗ** — nhánh
đẩy và nhánh kéo về của `sync_engine.dart`, cộng `walletForPush` trong
`sync_payload_normalizer.dart` — và cập nhật `sync_payload_contract_test.dart`
cùng lúc (payload đẩy ví **12 → 13** trường). Cả ba chỗ đều còn nguyên chú thích
chỉ ngược về tài liệu xin:
`docs/superpowers/backend/DA-XONG/WALLET_STATUS_COLUMN_WIDTH.md`.

`WalletStatus.khoaGuiLen` (`'Active'`/`'Inactive'`) vẫn ở lại và vẫn được
`wallet_status_test.dart` canh, đúng để ngày nối lại chỉ tốn một dòng — **đừng
đọc nó là mã chết bỏ quên**.

*(Hai đoạn ngay dưới là **ảnh chụp trong ngày 2026-09-10, trước khi áp tệp 7** —
câu "đẩy `'Inactive'` lên lại vỡ" và "CSDL dev vẫn `varchar(7)`" nay **sai**; trạng
thái đúng là đoạn "Cập nhật tối 2026-09-10" cuối mục.)*

✅ **CSDL dev trên máy người dùng đã trở về lược đồ chuẩn** (2026-09-10). Cùng
ngày cột ấy từng bị đổi sang `varchar(16)` **ngoài quy trình**, rồi được hoàn
tác theo yêu cầu **đích danh** của người dùng — đo lại: `varchar(7)`, lịch sử
migration 3 dòng, bốn CHECK đủ, số hàng không đổi. Nên trên máy ấy đẩy
`'Inactive'` lên **lại vỡ** — G28 vẫn đúng trên máy ấy. Diễn biến
đầy đủ ở mục **3b** của `DA-XONG/WALLET_STATUS_COLUMN_WIDTH.md`.

⚠️ **Cập nhật cùng ngày, sau khi gộp `main` (`bef37d3`) — chỗ chặn đã dời từ mã
sang CSDL.** Backend **đã** làm phần của mình từ 2026-09-09 (`7523c8c`, NPBao):
`schema.prisma` khai `wallet.status` là `VarChar(20)`, và bước 4 của
`src/Backend/database/7_Update_Account_User_Delete_Rules.sql` nới đúng cột ấy. Lúc
mục này được viết, commit ấy chỉ nằm trên `main`. Đo lại sau khi gộp: CSDL dev vẫn
`varchar(7)` vì **tệp 7 chưa được áp** — cùng với 8, 9, 10, 11
(`docs/superpowers/backend/DA-XONG/DEV_DB_MIGRATIONS_7_11.md`). Nên câu "lược đồ tự
mâu thuẫn" ở trên đúng với **CSDL**, không còn đúng với **mã nguồn** backend. Bán
kính phía client không đổi: vẫn đúng ba chỗ ở đoạn trên. Người dùng chốt **để
sau** — đừng mở lại khi chưa được hỏi.

✅ **Cập nhật tối 2026-09-10 — tệp 7 đã áp lên CSDL dev.** Người dùng yêu cầu
**đích danh** áp `database/7`–`11`; đo lại: `wallet."Status"` là
`character varying(20)`. Chỗ chặn phía server của G28 **đã hết** trên máy này.
Client **chưa** mở lại ba chỗ — vẫn theo lời chốt *để sau*. ⚠️ Chưa đo môi trường
nào khác (CSDL cloud), đừng suy ra từ máy này.

---

### ~~G29 — `/sync/push` viết lại ghi chú, và bản đã lọc đè lên máy~~ · ✅ ĐÓNG (2026-09-11; tiêu đề trước ghi "⛔ chặn ở backend", 2026-09-10)

> ✅ **Đóng 2026-09-11.** Bộ lọc mới của `7675b35` (gộp về nhánh cùng ngày,
> `utils/content-filter.util.js:122-167`) chỉ coi là số thẻ khi chuỗi **vừa** đúng
> hình dạng số thẻ (`CARD_SHAPE`) **vừa** qua Luhn; chỉ coi là mật khẩu khi từ khoá có
> `:` hoặc `=` theo sau; và không có `pin`. Đo bằng chính hàm `filterSensitiveNote`
> trên đủ **15 ca** của bảng 6.3 trong tài liệu xin: **15/15 đúng**, gồm `CK cho Nam STK
> 1903 4567 8901 23`, `Mua sổ ghi mật khẩu wifi`, `Tích lũy mục tiêu: Két mật khẩu (tự
> động)` (giữ nguyên) và `Thay pin: 350000`. ⚠️ **Chưa đo đầu-cuối** trên máy ảo như lần
> tái hiện bên dưới — backend chưa chạy lại từ mã đã gộp.
>
> **Hở nhỏ, chấp nhận được:** một tên do người dùng tự gõ mà chính nó chứa
> `password:`/`mật khẩu:` thì phần sau vẫn bị lọc — kể cả khi tên ấy nằm trong ghi chú
> do app sinh (`Tích lũy mục tiêu: <tên>`). Dạng ấy trông đúng như một mật khẩu thật;
> bộ lọc không thể phân biệt, và client cũng không.
>
> **Việc cùng gốc còn ở backend, không giữ G29 mở:** khoá mã hoá ghi chú rơi về chuỗi
> viết cứng khi thiếu biến môi trường (mục 18 §2.6,
> `CAN-LAM/VERIFY_7675B35_REMAINING.md`). Không làm hỏng ghi chú nào phía client.
>
> Phần dưới là **ảnh chụp 2026-09-10**; "hai biểu thức bắt nhầm" nói về bộ lọc cũ.
> Lý lẽ *"vì sao không vá ở client"* và cảnh báo về `SensitiveNoteValidator` vẫn đúng.

Đợt `main` ngày 2026-09-10 cho `/sync/push` chạy mọi `note` (giao dịch, ngân sách,
hoá đơn, mục tiêu) qua `filterSensitiveNote()` rồi mới mã hoá. Mục đích đúng — NĐ
13/2023, PCI-DSS. Nhưng hai biểu thức của bộ lọc **bắt nhầm**: phần số thẻ cộng
gộp các số rời nhau và không kiểm Luhn (`0912345678 2500000` thành "số thẻ"; số tài
khoản từ 13 chữ số cũng vậy), còn từ khoá mật khẩu không đòi dấu `:` nên nuốt từ
đứng sau (`mật khẩu wifi` mất `wifi`; `Két mật khẩu (tự động)` mất `(tự`).

**Tái hiện đầu-cuối trên máy ảo:** thêm một khoản qua giao diện với ghi chú
`KiemThuDongBo STK 1903 4567 8901 23 mat khau wifi`. Server lưu bản đã lọc (mã
hoá), và **trong cùng giây** lượt kéo về đè lên SQLite: hàng mang `synced`, màn Sổ
giao dịch hiện `… STK [THÔNG TIN THẺ ĐÃ ĐƯỢC LƯỢC BỎ] Mật khẩu: [ĐÃ LƯỢC BỎ]`. Không
lỗi, không log phía client. Khoản thử đã xoá mềm sau khi đo.

**Vì sao không vá ở client:** đường đè là **chủ ý** của backend —
`docs/progress/Client-app.md` mục 13.9 ghi client "lưu thẳng" `note` kéo về, để bản
sao trên máy cũng được làm sạch khi đó thật là số thẻ. Giữ bản gốc ở client là vô
hiệu bộ lọc đúng chỗ nó có ích; và client cũng không có cách nào biết một chuỗi
kéo về đã bị lọc **nhầm**. Chỗ sửa là độ chính xác của bộ lọc.

**Bán kính:** mất nội dung không đảo ngược ở cả hai đầu; và vỡ quy ước ghi chú do
app sinh — hậu tố `(tự động)` mất thì khoản trích tự động đọc thành nạp tay
(`goal_history_direction.dart`). Tiền tố `Điều chỉnh số dư` và hai tiền tố mục tiêu
sống sót ở mọi ca đã đo. **Chưa hỏng dữ liệu thật:** chạy bộ lọc trên mọi ghi chú
đang có (26 hàng không rỗng, đo 2026-09-10) thì chỉ đúng khoản thử bị viết lại.

⚠️ **Khi làm mục 13.3 của `Client-app.md`** (cảnh báo trước khi lưu): **đừng** dán
mã mẫu `SensitiveNoteValidator` ở 13.10.2 — đo 2026-09-10 nó chặn nhầm **5/10**
ghi chú hợp lệ, gồm cả `Thay pin: 350000` ("pin" là pin điện thoại). Theo quy tắc đã
sửa trong tài liệu xin, và chừa chuỗi do app sinh.

Tài liệu xin: `docs/superpowers/backend/DA-XONG/SYNC_NOTE_FILTER_REWRITE.md`.

---

### ~~G30 — Chỉ một ví Tiết kiệm mỗi tài khoản, vì một index không ai ghi thành luật~~ · ✅ ĐÓNG (2026-09-11; mở 2026-09-10)

> ✅ **Đã gỡ 2026-09-11 (TDD).** `viTietKiemDaCo`, `thongBaoMotViTietKiem`, khối chặn ở
> `WalletLocalDataSourceImpl._kiemRangBuocServer`, và khoá ô "Tiết kiệm" cùng dòng giải thích ở màn Thêm ví đều đã gỡ;
> luật trùng tên ở lại. Test: nhóm "nhiều ví Tiết kiệm — G30" ở `wallet_unique_constraints_test.dart` (thêm ví saving thứ
> hai được, đổi loại sang saving được — đỏ đúng lý do trước khi gỡ; hai ví saving trùng tên vẫn bị từ chối) và ca "đã có
> ví Tiết kiệm vẫn chọn được ô Tiết kiệm" ở `wallet_add_guard_ui_test.dart`; nhóm test của hàm đã xoá ở
> `rang_buoc_vi_test.dart` bỏ theo. **Kiểm trên máy ảo:** tài khoản có ví Tiết kiệm mặc định, màn Thêm ví hiện ô "Tiết
> kiệm" đậm như các ô khác, chạm vào thì được chọn, không còn dòng giải thích (rời màn không lưu).
>
> ⚠️ **Máy chủ nào chưa áp `database/12` vẫn còn index** — ví Tiết kiệm thứ hai tạo trên app sẽ bị từ chối
> (`UNIQUE_VIOLATION`, vĩnh viễn) và kẹt hàng đợi đẩy. Đoạn dưới là ảnh chụp trước khi gỡ.

> ✅ **2026-09-11:** `database/12` (`7675b35`, gộp về nhánh cùng ngày) chạy `DROP INDEX IF EXISTS
> "uq_wallet_saving_active"`, và CSDL dev đã áp — đo `pg_indexes` sau khi áp: index không còn.
> Đoạn dưới là ảnh chụp trước đó. Chốt tạm phía client gỡ cùng ngày — banner ngay trên.

PostgreSQL có `uq_wallet_saving_active ("Idaccount") WHERE "Type" = 'Saving' AND
"Delete_at" IS NULL` từ migration 2026-09-01. Luật ấy **không có** trong
`Rule_project.md` mục 2 lẫn `New_Database.md` 3.2.8 — chỉ có trong SQL, từ bản
`New_Database.sql` 2026-08-26 khi Tiết kiệm còn được coi là "một ví cứng".

Client tạo sẵn ví "Tiết kiệm" (`saving`) cho mọi tài khoản mới, rồi vẫn cho
chọn "Tiết kiệm" khi thêm ví. Ví thứ hai: SQLite ghi bình thường → server trả
23505 → `UNIQUE_VIOLATION` → xếp **vĩnh viễn** → ví không bao giờ lên server;
giao dịch trong ví vỡ `fk_transaction_wallet` → coi là tạm thời → thử lại mãi.
Im lặng, cùng lớp với `ewallet`/`debt`.

**Cách xử lý (người dùng chốt 2026-09-10):** xin backend bỏ index
(`DA-XONG/WALLET_SAVING_INDEX.md`) **và** chặn tạm trong lúc chờ —
`wallet/domain/rang_buoc_vi.dart` (`viTietKiemDaCo`), chốt ở
`WalletLocalDataSourceImpl._kiemRangBuocServer`, và màn Thêm ví khoá ô "Tiết
kiệm" kèm dòng giải thích. Khi backend xác nhận đã bỏ: gỡ `viTietKiemDaCo`, hai
chỗ gọi nó, nhóm test "một ví Tiết kiệm" ở hai tệp test, và dòng này — ✅ đã làm 2026-09-11.

**Không phải gap:** chốt **trùng tên ví** thêm cùng ngày (`viTrungTen`, cùng
tệp) canh `uq_wallet_account_name_active` — luật hợp lý, có trong
`New_Database.md`, ở lại vĩnh viễn.

**Bài học đo:** phép đo 2026-09-09 "không unique index nào ở server" dùng
`pg_constraint`, nơi partial unique index **không hiện**. Đo `pg_indexes`.

### ~~G31 — Tên dài hơn độ rộng cột kẹt hàng đợi đẩy, vì server gọi đó là lỗi tạm thời~~ · ✅ ĐÓNG (2026-09-11; tiêu đề trước ghi "⛔ chặn ở backend", 2026-09-10)

> ✅ **Đóng 2026-09-11** (đo trên mã HEAD sau khi gộp `main` @ `cc65f4f`; **chưa** chạy
> đầu-cuối). Hai vế phía server đều đã sửa:
>
> - `sync.service.js:197-203` ánh xạ `22001` / `P2000` / `value too long for type`
>   **và** `23502` / `P2011` / `P2012` về `CONSTRAINT_VIOLATION`. Mã ấy nằm trong
>   `_permanentCodes` của client, nên bản ghi quá dài bị **chặn theo thời gian** thay vì
>   gửi lại ở mọi chu kỳ, và không còn kéo giãn cách lên cả hàng đợi.
> - `sync.validation.js` tách `validateBatch` (400 chỉ cho lỗi khung của cả lô) khỏi
>   `validateOperation` (lỗi từng thao tác vào `results[i]`) — một giá trị hỏng không
>   còn làm **cả lô** 400.
>
> **Bộ lọc bảy ô tên phía client VẪN GIỮ, đừng gỡ.** Hậu quả của tên quá dài nay là
> "kẹt vĩnh viễn có mã" thay vì "gửi lại mãi" — bản ghi vẫn **không lên server**. Chặn
> lúc người dùng đang gõ vẫn là chỗ duy nhất giữ được bản ghi. Vế "ví bị cắt âm thầm"
> ở dưới **vẫn đúng**: `upsertWallet` còn `substring(0, 100)` ở cả hai nhánh.
>
> Phần dưới là **ảnh chụp 2026-09-10**; câu "không có nhánh cho mã ấy → `DB_ERROR`" và
> đoạn "Còn mở" cuối mục nói về backend trước khi gộp.

Trên PostgreSQL, `wallet.Name`, `goal.Name`, `bill.Name` rộng **100** ký tự và
`category.NameCategory` rộng **200** (đo `information_schema.columns`). Form
client không giới hạn độ dài: quét `lib/` ngày 2026-09-10 được 3 chỗ `maxLength`
/ `LengthLimitingTextInputFormatter`, **không** chỗ nào ở bốn form ấy.

`upsertGoal`, `upsertBill`, `upsertCategory` không cắt chuỗi. Tên dài hơn → Prisma
`P2000` → `sync.service.js` không có nhánh cho mã ấy → `DB_ERROR` → client xếp
**tạm thời** (`_classifyFailure`, `sync_engine.dart:1716`) → gửi lại ở mọi chu
kỳ, và giãn cách luỹ tiến áp lên **cả** hàng đợi. Không lỗi nào hiện ra.

Riêng ví thì không kẹt mà **bị cắt âm thầm**: `upsertWallet` lưu 100 ký tự đầu,
và lượt kéo về mang bản đã cắt về máy (suy từ mã, chưa đo trên máy ảo).

**Cách xử lý:** client giới hạn độ dài ở form, vì client là nơi duy nhất báo được
cho người dùng lúc họ đang gõ; và xin backend ánh xạ `22001` / `P2000` về
`CONSTRAINT_VIOLATION` để bản client cũ cùng mọi nguồn ghi khác không lặp vô hạn —
`docs/superpowers/backend/DA-XONG/SYNC_PUSH_ERROR_MAPPING.md`.

✅ **Phía client xong cùng ngày.** Bảy ô tên — Thêm ví, Sửa ví, Thêm/Sửa mục
tiêu, Thêm hoá đơn, Sửa hoá đơn, Thêm/Sửa danh mục, Nhóm danh mục — đi qua
`GioiHanDoRong` ở `lib/core/utils/gioi_han_do_dai.dart`: 100 cho tên ví, mục
tiêu, hoá đơn; 200 cho tên danh mục. Bộ lọc đếm **code point** chứ không dùng
`maxLength`, vì PostgreSQL đếm `varchar(n)` theo code point còn `maxLength` đếm
theo grapheme — chữ gõ ở dạng tách dấu và emoji sẽ lọt qua. Nó cắt theo trọn cụm
grapheme, và theo đúng chính sách của Flutter về việc có cắt lúc bộ gõ đang ghép
chữ hay không (Android cắt ngay — nên bấm Lưu lúc chữ cuối chưa chốt vẫn không
lọt). Test: 12 ca thuần ở `core/utils/gioi_han_do_dai_test.dart`, và mỗi ô một
widget test. Kiểm trên `emulator-5554`: gõ 120 ký tự vào ô tên mục tiêu, ô dừng
ở 100.

~~**Còn mở:** phía server — bản client đã cài trước đó, Admin-web và mọi nguồn ghi
khác vẫn lặp vô hạn cho tới khi backend ánh xạ lỗi.~~ ✅ Hết từ 2026-09-11 — xem
banner đầu mục. Hàng tạo trước bản vá mà dài hơn cột thì vẫn không lên được (nay bị
chặn theo thời gian thay vì gửi lại mãi); gõ bất kỳ phím nào vào ô tên ở màn Sửa là
bộ lọc cắt nó xuống vừa cột.

### ~~G32 — Mục tiêu chưa sắp nhảy lên đầu danh sách sau một vòng đồng bộ~~ · ✅ ĐÓNG (2026-09-11; tiêu đề trước ghi "⛔ chặn ở backend", 2026-09-10)

> ✅ **Đóng 2026-09-11** (đo trên mã HEAD sau khi gộp `main` @ `cc65f4f` và trên CSDL
> dev đã áp `database/12`; **chưa** chạy đầu-cuối):
>
> - `mapEntityFields('goal')` nay giữ `null` (`sync.repository.js:124`:
>   `m.priority === null ? null : Number(m.priority)`), nhánh tạo mặc định `null`
>   (`:515`), nhánh sửa giữ giá trị cũ khi khoá vắng (`:541`).
> - `database/12` đưa các hàng `Priority <= 0` về `NULL`; trên CSDL dev không còn hàng
>   nào `<= 0`. Môi trường khác chưa đo.
>
> **Lớp đọc `<= 0` là chưa sắp phía client VẪN GIỮ** (`goal/domain/uu_tien_hop_le.dart`,
> ở cả ba ranh giới). Lý do "backend đang ép `0`" nay là lịch sử, nhưng lớp ấy vẫn cần
> cho hàng `0` đã kéo về máy từ trước, cho server chưa chạy tệp 12, và vì PostgreSQL
> **không** có CHECK nào cho `Priority` — push vẫn nhận `0` và số âm từ nguồn ghi khác.
>
> Phần dưới là **ảnh chụp 2026-09-10**; câu "`Number(null) === 0`, nên server lưu `0`"
> và đoạn "Còn mở" cuối mục nói về backend trước khi gộp.

Client gửi `priority: null` cho mục tiêu chưa sắp. `mapEntityFields('goal')` ở
backend gọi `Number(m.priority)`, mà `Number(null) === 0`, nên server lưu `0`.
Lượt kéo về đọc `int.tryParse('0')` thành `0`, và `_soSanhUuTien`
(`goal_grouping.dart:70-73`) xếp `0` **trước** mọi số đã sắp.

**Tái hiện đầu-cuối trên `emulator-5554` ngày 2026-09-10:** tạo mục tiêu
"ThuUuTien" bên cạnh hai mục tiêu đã sắp (100 và 200). Một giây sau khi lưu nó
đứng cuối; 16 giây sau, qua một chu kỳ đẩy rồi kéo, nó đứng **đầu**, và server
mang `Priority = 0`. Không lỗi, không log.

Client không bao giờ tự sinh `priority <= 0` (`goal_priority.dart:101-104`), nên
mọi giá trị ấy kéo về đều là một `null` bị ép.

**Cách xử lý:** xin backend giữ `null`
(`docs/superpowers/backend/DA-XONG/GOAL_PRIORITY_NULL_TO_ZERO.md`); client đọc
`<= 0` như chưa sắp. Phía client chỉ sửa được **hiển thị** trên máy đã cập nhật —
giá trị trên server và bản client cũ vẫn chờ backend.

✅ **Phía client xong cùng ngày.** Một định nghĩa,
`goal/domain/uu_tien_hop_le.dart`, áp ở ba ranh giới: `GoalEntity.fromDrift`
(mọi đường đọc mục tiêu, nên hàng `0` kéo về từ trước bản vá cũng về đúng
chỗ), nhánh kéo về của `SyncEngine` (SQLite lưu `NULL` thay vì `0`), và payload
đẩy lên (gửi `null` thay vì đẩy lại `0`, để hàng tự lành khi backend sửa). Áp ở
cả ba chứ không chỉ chỗ sắp xếp: `_mocChenDuoc` coi `0` là một số thật, nên kéo
thả sẽ tính khe từ nó trong khi danh sách lại xếp nó như chưa sắp. Test: 4 ca
thuần, 1 ca repository, 1 ca payload đẩy, 1 tệp kéo về. Kiểm trên
`emulator-5554`: cài bản vá, "ThuUuTien" — kéo về từ trước bản vá và đang đứng
đầu — về **cuối** danh sách ngay khi mở trang, không cần đồng bộ lại.

~~**Còn mở:** phía server — giá trị `0` vẫn nằm trên server, và bản client đã cài
trước đó vẫn thấy mục tiêu nhảy lên đầu.~~ ✅ Hết từ 2026-09-11 trên CSDL dev — xem
banner đầu mục. Mục tiêu thử "ThuUuTien"
(`f7482924-2326-4105-bc33-abc1d993a4cb`) đã được xoá mềm qua giao diện sau khi
kiểm.

---

### ~~G33 — Trang Xoá tài khoản hứa "đăng nhập lại là tự khôi phục", backend không làm vậy~~ · ✅ ĐÓNG (2026-09-11; mở 2026-09-10)

> ✅ **Đóng 2026-09-11 (TDD).** Bốn phần: (1) `UserModel` mang `status`/`countdown`/`countdownNhanLuc`/`dangChoXoa`, gỡ `pendingDeleteCancelled` (`48b01c5`); (2) `AuthRepositoryImpl.deleteAccount` ghi `PendingDelete` và **không** xoá token/phiên (`d1791dd`); (3) hai thẻ đọc trạng thái ấy — Trang chủ (nút "Để sau"/"Huỷ xoá", `292af8d`) và "Vùng nguy hiểm" ở Cài đặt (hộp đếm N ngày, nút "Huỷ yêu cầu xoá", `f7a02aa` + `ff54c6b`); (4) trang Xoá tài khoản thôi đăng xuất và thôi hứa "đăng nhập lại là tự khôi phục" (`866b870`). `AuthBloc` đọc lại thông tin tài khoản qua sự kiện mới `ThongTinTaiKhoanThayDoi` (`361f898` + `eee607e`); hàm đếm ngày thuần ở `ca44dd8`. Lượt sửa sau soát cuối cả nhánh đóng thêm hai lỗi race: trang Xoá tài khoản và nút huỷ báo `AuthBloc` cả khi đã rời cây giữa lúc gửi/huỷ (`5436544`), và kết quả xoá/huỷ của tài khoản cũ không còn ghi vào tài khoản vừa đăng nhập giữa chừng (`46ad023`). Thẻ chỉ hiện câu chung, không có số ngày, ở hai ca: máy **đã giữ phiên** từ trước khi máy khác gửi yêu cầu xoá (chỉ thấy `PendingDelete` qua `/auth/profile`), và bộ nhớ đệm do bản client cũ ghi (có `countdown` nhưng thiếu mốc nhận `countdown_nhan_luc`). Đăng nhập máy khác hay cài lại app thì **có** số — response đăng nhập mang `countdown`. Xin backend qua CAN-LAM **19** (`AUTH_PROFILE_COUNTDOWN.md`, `GET /auth/profile` trả thêm `countdown`); có trường ấy, client sẽ ghi lại số và mốc nhận mỗi lần `/auth/profile` trả `countdown`, kể cả khi trạng thái khớp — cứu cả ca thứ hai lẫn ca **số cũ sai** (máy giữ số của một lần chờ xoá trước; máy khác huỷ rồi gửi lại yêu cầu; lần mở sau `status` vẫn khớp nên thẻ hiện ít ngày hơn thật).
>
> `flutter test` **2078/2078 pass** (3 phút 23 giây, đo 2026-09-11 ở `0591887`, sau lượt sửa sau soát cuối cả nhánh); 49 test mới ở bảy tệp (đếm bằng máy): `dem_nguoc_xoa_test` (13), `user_model_cho_xoa_test` (5), `auth_repository_cho_xoa_test` (11), `auth_bloc_cho_xoa_test` (5), `the_cho_xoa_trang_chu_test` (6), `vung_nguy_hiem_card_test` (5), `delete_account_page_test` (4). `flutter analyze` **25 issue** — khớp mức nền, không issue nào ở tệp G33.
>
> **Kiểm trên `emulator-5554` (tài khoản 11):** gửi yêu cầu xoá → **không** bị đăng xuất, về Trang chủ, thẻ "Tài khoản đang chờ xoá — Còn 30 ngày…" hiện ra; CSDL: `PendingDelete`, `Countdown = 30`. Huỷ ở Cài đặt → CSDL về `Active`, `Countdown = null`, `Delete_at = null` — tài khoản thử về nguyên trạng. Pixel vàng (tràn bố cục): **0** trên **15** ảnh chụp.
>
> ✅ **Đã sửa ở lượt sửa sau soát cuối cả nhánh (`bf34de2`):** khoảng trống 24dp sau "Để sau" ở Trang chủ khi thẻ đã ẩn — khoảng cách nay nằm trong thẻ. Kiểm trên `emulator-5554` (APK từ `0591887`): bấm "Để sau" thì tiêu đề hero về đúng y=315 px như lúc tài khoản `Active`. **§3.8** ✅ sửa cùng ngày (chi tiết ở `docs/PROJECT_CONTEXT.md` mục 14, khối "Sửa hai lỗi làm mới token — spec §3.8"). ✅ **Phần 1** (§3.1–§3.7) và **§5.1** (hộp thoại bị đẩy ra ở màn Đăng nhập) **làm 2026-09-12** — bảy commit `693de3b` → `fc82a94`; khối "Phần 1 cưỡng chế đăng xuất" mục 14 `docs/PROJECT_CONTEXT.md`. Nhánh **HTTP 401 đã kiểm đầu-cuối trên máy thật** ngày 2026-09-12 — hộp thoại hiện đúng, SQLite giữ nguyên 2 ví và 18 danh mục. Chính lượt kiểm ấy tìm ra **hai** lỗi mà cả 63 ca test không bắt được, cùng một triệu chứng (đăng xuất **không kèm hộp thoại**) nhưng khác nguyên nhân: chốt vào của handler nuốt lời từ chối tới muộn (`ac08ed6`), và lượt đăng xuất trơn về sau đè mất lý do (`40a553d`). Nhánh socket và nhánh làm mới vẫn chờ CAN-LAM 17 A.
>
> Phần dưới là **ảnh chụp 2026-09-10** — mô tả đúng bối cảnh phát hiện lỗi lúc đó, giữ nguyên làm lịch sử.

Có **hai** đặc tả nói ngược nhau về giai đoạn chờ xoá. Bản 2026-08-17
(`docs/superpowers/auth/2026-08-17-auth-account-design.md`, thư mục gitignore)
cho đăng nhập lại trong 30 ngày là **tự khôi phục**; bản
`docs/progress/Client-app.md` mục 12 cho người dùng **dùng tiếp** trong 30 ngày và
huỷ bằng một nút. Backend chạy theo **bản mục 12**: `auth.service.js:309` khai
`pendingDeleteCancelled = false` và không chỗ nào gán lại, còn nhánh
`PendingDelete` của `login` chỉ ghi log rồi cấp token. Client vẫn chạy theo bản cũ:

- `delete_account_page.dart` gửi yêu cầu xong thì đăng xuất, và nói *"hãy đăng
  nhập lại trong vòng 30 ngày — hệ thống sẽ tự động khôi phục tài khoản cho
  bạn"*;
- `login_page.dart` chờ cờ `pendingDeleteCancelled` để hiện "Tài khoản đã được
  khôi phục" — cờ ấy không bao giờ bật.

**Hệ quả:** người dùng tin lời hứa, đăng nhập lại, thấy app chạy bình thường.
Tài khoản vẫn `PendingDelete`, và hết 30 ngày thì bộ đếm ngược của backend ẩn
danh hoá dữ liệu rồi xoá mềm tài khoản. Không một chữ nào báo trước.

**Vì sao chưa sửa:** phát hiện ngày 2026-09-10 trong lúc thiết kế hạng mục cưỡng
chế đăng xuất. Cách sửa — dùng tiếp 30 ngày, thẻ nhắc đóng được trên Trang chủ,
nút huỷ ở Cài đặt, trang Xoá tài khoản thôi đăng xuất và thôi hứa — đã chốt với
người dùng, nằm ở mục 4–5 của
`docs/superpowers/specs/2026-09-10-cuong-che-dang-xuat-va-cho-xoa-design.md`,
**đã duyệt ngày 2026-09-11**, ~~chưa sửa~~ — ✅ **đã sửa cùng ngày**, xem banner đầu mục. Trước tối 2026-09-10 đường này còn không chạy nổi trên CSDL dev
(thiếu cột `Countdown`); nay `database/9` đã áp nên lỗi **xảy ra được thật**.

**Bán kính:** chỉ người đã gửi yêu cầu xoá. CSDL dev hiện không có tài khoản
`PendingDelete` nào (đo tối 2026-09-10).

---

### ~~G34 — Client không nghe `sync.completed`, nên thay đổi từ máy khác vẫn chờ chu kỳ đồng bộ~~ · ✅ ĐÓNG (2026-09-12 tối; mở 2026-09-11)

> ✅ **ĐÓNG 2026-09-12 tối (TDD, kiểm máy ảo hai máy cùng tài khoản).** Phương án chọn: **im lặng** — chỉ
> kéo về, **không toast**. Đây không còn là lựa chọn thẩm mỹ: máy vừa đẩy cũng nằm trong phòng `account_<id>`
> nên nhận lại chính sự kiện của mình, mà payload là hộp đen (§4 spec socket) nên **không phân biệt được máy
> gửi** — một toast "máy khác vừa đổi dữ liệu" sẽ nói **sai** trên đúng máy vừa ghi, sau **mỗi** lần ghi. Kết
> quả đồng bộ đã có dải riêng ở bậc cao nhất (§6.3). Mã: `RealtimeEvent.dongBoXong` ↔ `sync.completed`;
> `canDongBoLai = true`; `loiNhan` đổi kiểu thành `String?` và **`null` là định nghĩa duy nhất của "im
> lặng"** — `AppToast._khiCoRealtime` chỉ đọc getter ấy, không tự liệt kê sự kiện. **Không** đổi
> `noiRealtimeVaoDongBo` hay `SyncEngine`. Test: 4 tệp, **2 ca mới** (`realtime_wakeup_test`, `app_toast_test`),
> hai ca cũ đổi tên/nới; toàn bộ **2218/2218**. **Đo trên máy ảo** với tài khoản thử **13** (`kiemthu_g34`, tạo
> qua OTP mock) — máy A là máy ảo, máy B là `POST /api/sync/push` bằng token thật: ba lần đẩy một ví 12.345đ,
> cả ba lần log backend ghi `Emitted sync.completed to room account_13` và lượt `Pull` của máy A **trong cùng
> giây** (20:20:03, 20:25:16, 20:25:50 theo đồng hồ backend); Trang chủ đổi 24.690đ → 37.035đ, ảnh chụp 2 giây
> sau lần đẩy thứ ba **không có toast**. Hai điều biết mà **chưa** xử lý, cả hai có sẵn từ trước cho mọi sự kiện
> realtime: (1) sự kiện tới đúng lúc `_runSync` của máy nhận đang chạy dở thì `syncNow()` bị bỏ qua không log
> (`sync_engine.dart` chốt `_status == syncing`) — nếu lượt pull đang chạy đã đi qua trước khi máy kia ghi xong
> thì thay đổi ấy chờ kích hoạt kế tiếp; cửa sổ vài trăm mili-giây, không mở G; (2) máy vừa đẩy nhận lại sự kiện
> của mình — thường rơi đúng cửa sổ (1) nên bị bỏ qua miễn phí, nếu không thì thêm một chu kỳ chỉ kéo về, không
> đẩy lại (không thành vòng lặp). Đoạn dưới là ảnh chụp trước bản sửa.

> ✅ **2026-09-12 sáng:** không còn gì chặn ngoài quyết định sản phẩm — sau gộp `main` @ `cbbeeb4`, bắt tay socket nối được (đo máy ảo), nên sự kiện **tới được** client và bị `_khiCoSuKien` bỏ qua đúng như mô tả dưới.

**Phía backend đã xong** (đo trên mã HEAD sau khi gộp `main` @ `cc65f4f`): sau mỗi
`/sync/push`, `sync.service.js:223` publish `sync.completed` vào EventBus →
`notification.service.js:79-90` nghe và gọi `emitSyncCompleted` →
`core/socket.js:203-215` phát tới phòng `account_<idaccount>`, payload
`{summary, timestamp}`. Tài liệu xin: `docs/superpowers/backend/DA-XONG/SOCKET_SYNC_COMPLETED.md`.

**Phía client bỏ qua nó.** `RealtimeSocket` nghe mọi sự kiện bằng `onAny`
(`realtime_socket.dart`), nhưng `realtimeEventFromName` (`realtime_event.dart`) chỉ
dịch **ba** tên — `bank_transaction.incoming`, `ocr.completed`, `ocr.duplicate` — nên
`sync.completed` trả `null`, và `RealtimeChannel._khiCoSuKien` chỉ ghi log "Bỏ qua sự
kiện lạ" (`realtime_channel.dart:193-195`). Không lỗi.
*(Ảnh chụp 2026-09-11. Hai lượt đổi kể từ đó: `sync.completed` **được dịch** từ
tối 2026-09-12 khi G34 đóng, và `bank_transaction.incoming` **thôi được dịch**
từ 2026-09-18 khi nhóm bỏ liên kết ngân hàng. Danh sách hiện nay vẫn là **ba**
tên, nhưng là ba tên khác: `ocr.completed`, `ocr.duplicate`, `sync.completed`.)*

**Hệ quả:** một thay đổi đẩy lên từ máy khác chỉ về máy này ở chu kỳ đồng bộ định kỳ
(`_periodicSyncMinutes = 15`) hoặc khi có kích hoạt khác (mở app, mạng về, người dùng
ghi dữ liệu). Không mất dữ liệu, chỉ chậm. Đây đúng là phần giá trị mà spec
`docs/superpowers/specs/2026-09-09-socket-io-realtime-channel-design.md` đặt vào sự kiện
này: §1 điểm 4, việc số 1 ở §8 ("biến kênh này từ hạ tầng thành giá trị thật"), và
dòng đầu bảng rủi ro §9.

**Vì sao chưa làm:** §2 của spec cố ý **không** bắt sẵn `sync.completed` khi server chưa
phát — *"một nhánh mã không bao giờ chạy tới còn tệ hơn là không có"* — và ghi rằng khi
backend xong thì việc thêm là **một dòng** trong bảng ánh xạ ở §4. Backend nay đã phát,
nhưng hôm nay sự kiện **vẫn chưa tới được client**: bắt tay socket từ chối mọi tài khoản
(`CAN-LAM/FIX_BACKEND_3_REGRESSIONS.md` hồi quy A, và §2.1 của mục 18). Thêm bây giờ thì
kiểm được bằng test nhưng **không** kiểm được đầu-cuối. Chờ người dùng quyết.

**Bán kính khi làm:**

- Một giá trị mới trong `RealtimeEvent`, một nhánh trong `realtimeEventFromName`, và
  một chữ cho `loiNhan`. ⚠️ Trình biên dịch chỉ bắt được `loiNhan` (switch phủ đủ):
  `realtimeEventFromName` có nhánh `default`, còn `canDongBoLai` là `this !=
  RealtimeEvent.ocrTrung` nên giá trị mới **mặc định đánh thức đồng bộ** — đúng ý ở
  đây, nhưng là tự nhiên đúng chứ không phải được kiểm. Cập nhật `test/core/realtime/realtime_event_test.dart` và câu "Ba sự kiện…" ở
  đầu `realtime_event.dart`.
- ⚠️ **Toast:** đồng bộ vốn đã có dải kết quả riêng (bậc cao nhất, §6.3 của spec), nên
  hiện thêm một toast "máy khác vừa đổi dữ liệu" là quyết định giao diện chứ không phải
  mặc định — `loiNhan` hiện bắt buộc có chữ cho mọi sự kiện. Chưa có thiết kế Stitch
  nào cho nó.
- ⚠️ **Máy vừa đẩy cũng nằm trong phòng ấy**, nên nó nhận lại sự kiện của chính mình
  và chạy thêm một chu kỳ. Không thành vòng lặp: `_runSync` chỉ gọi `/sync/push` khi có
  thao tác chờ (`sync_engine.dart:375`), nên chu kỳ thừa chỉ kéo về mà không phát lại.
  Không lọc được theo máy gửi — payload là hộp đen, và mọi máy gửi cùng
  `clientId: 'flutter-client-app'`.
- Kiểm đầu-cuối trên máy ảo cần backend sửa hồi quy A trước.

---

### ~~G35 — Ba màn quản lý danh mục lấy tài khoản với dự phòng `?? 1`~~ · ✅ ĐÓNG (2026-09-11; trước đó cùng ngày ghi "lỗi đang chạy, client sửa được — chưa sửa")

> ✅ **Đã sửa 2026-09-11 (TDD), theo khuôn G4.** Getter của cả ba màn thành
> `int? get _accountId => widget.accountId ?? currentAccountIdOrNull(context)`. Chưa có phiên thì
> `CategoryPage` không mở luồng đọc nào và hiện câu báo; `CategoryAddPage`/`CategoryGroupPage` dừng lượt
> nạp, còn lưu và xoá chặn kèm SnackBar "Chưa xác định được tài khoản đăng nhập". Đường đọc **không** dùng
> `?? 0` như trang ví: `idaccount = 0` là bộ khuôn danh mục mặc định toàn cục (quy tắc 8), đọc nó là hiện bộ
> khuôn ra màn hình. Test: `test/core/auth/khong_du_phong_admin_test.dart` quét `lib/` bằng regex nhiều dòng
> (đỏ đúng ba vị trí trước khi sửa), và `test/features/category/presentation/category_no_session_test.dart` —
> ba màn dựng dưới `AuthInitial` không đọc, không ghi. Kiểm trên máy ảo: có phiên thì màn Quản lý danh mục vẫn
> hiện đủ. Đoạn dưới là ảnh chụp trước bản sửa.

**Tìm ra lúc sửa G24** (đọc `category_add_page.dart` để biết màn sửa có giữ màu cũ không). Cả ba màn dùng chung
một khuôn getter:

```dart
int get _accountId {
  if (widget.accountId != null) return widget.accountId!;
  final state = context.read<AuthBloc>().state;
  return int.tryParse((state is AuthSuccess ? state.user?.id : null) ?? '') ??
      1;
}
```

- `lib/features/category/presentation/pages/category_page.dart:42`
- `lib/features/category/presentation/pages/category_group_page.dart:57`
- `lib/features/category/presentation/pages/category_add_page.dart:85`

Đếm bằng script quét toàn `lib/` với regex **nhiều dòng**, 2026-09-11: đúng ba chỗ. Dạng `?? ⏎ 1;` lọt qua mọi
lượt `grep` một dòng trước đây — đó là lý do G4 và G8 đóng mà ba chỗ này vẫn còn.

`1` là tài khoản **admin thật**, không phải giá trị "chưa biết" — quy tắc 2 `CLAUDE.md`. Khi phiên đăng nhập không
cho ra id, ba màn đọc cây danh mục và ghi danh mục (`saveChild`, `saveGroup`) dưới `idaccount = 1` thay vì từ chối.
Chưa thấy xảy ra trên máy thật; mức nguy hiểm là **ghi dưới danh nghĩa admin**, đúng lớp lỗi G4/G8 đã đóng.

**Tài liệu từng nói ngược:** hai dòng "Không còn `?? 1` ở bất kỳ đâu" trong `docs/PROJECT_CONTEXT.md` và mục 3 của
tệp này — đã gắn dấu cùng ngày.

**Cách sửa (chưa làm, chờ người dùng):** theo khuôn G4 — dùng `core/auth/current_account.dart` trả `int?`; đường
đọc trả rỗng khi `null`, đường ghi chặn kèm thông báo. Test theo khuôn `test/core/auth/current_account_test.dart`,
cộng một test quét `lib/` cấm mẫu `?? 1` nhiều dòng — hai test quét `lib/` sẵn có là tiền lệ.

---

### ~~G36 — Tài khoản bị xoá lúc app giữ token hết hạn: đăng xuất không hộp thoại~~ · ✅ ĐÓNG 2026-09-13 (đo đầu-cuối ba ca)

**Đo thật** (spec cưỡng chế đăng xuất, khối ✅ thứ hai đầu §7.3): tạo tài khoản thử `kiemthu_xoa`
(idaccount 12), đăng nhập giữ refresh token, admin `DELETE /api/admin/deleteuser/12`, rồi gọi
`/auth/refresh` bằng token ấy → **401 "Refresh token khong hop le", không `code`**. Nguyên nhân: xoá
mềm **thu hồi toàn bộ refresh token** của tài khoản (5/5 `Status = true`), và `auth.service.js:375-387`
kiểm token **trước** khi kiểm trạng thái tài khoản. `/auth/profile` cùng lúc trả đúng 401 +
`code: ACCOUNT_DELETED`.

**Hệ quả phía client.** Ba nguồn của cưỡng chế đăng xuất (§3.5) đều cần *mã*. Khi app **đang có
socket**, sự kiện `account.force_logout` tới trước và mọi thứ đúng (đo thật: hộp thoại "Tài khoản
đã bị xoá", SQLite dọn). Nhưng khi app **ngoại tuyến lúc bị xoá** rồi mở lại sau khi access token đã
hết hạn: request đầu → 401 "Token expired" (không mã) → interceptor gọi `/auth/refresh` → 401 không
mã → `LamMoiPhienChet` **không lý do** → `AuthUnauthenticated()` trơn → màn Đăng nhập, **không hộp
thoại**. Người dùng chỉ biết vì sao khi đăng nhập lại (login trả câu đúng). Không mất dữ liệu; chỉ
thiếu lời giải thích.

**Client không tự sửa được**: lúc ấy mọi token đều chết, không endpoint nào trả lời được "vì sao".
Xin backend (CAN-LAM 20 §2.7): ở nhánh token đã thu hồi, backend **có** `storedToken.idaccount` — kiểm
`getAccountValidity` trước khi ném, và nếu tài khoản `Inactive`/`Deleted` thì trả 401 kèm `code` như
`authenticate`. Client khi ấy không phải đổi gì: `tuBody401(nguon: lamMoi)` đã đọc đúng hình dạng.

✅ **Backend đã làm** (gộp `main` @ `7779999`, merge `e9b5aef`, 2026-09-12 tối muộn — `auth.service.js`
nhánh `storedToken.status === true` gọi `getAccountValidity(storedToken.idaccount)`, bỏ qua `SCHEMA_ERROR`,
rồi ném 401 kèm `rejection.data` nếu tài khoản không hợp lệ). **Đo mức API cùng tối** (tài khoản thử 14
`kiemthu_cl20_…`, còn `Active`): `/auth/logout` rồi `/auth/refresh` bằng token cũ → 401 *"Refresh token
khong hop le"* **không mã** — đúng, vì tài khoản hợp lệ thì `accountRejection` trả `null`.

✅ **ĐÓNG 2026-09-13 — đo đầu-cuối ba ca qua API admin; client không đổi mã.** Tài khoản thử tự đăng ký
qua `/auth/register` (`kiemthu_g36_…`, idaccount 16), backend dev chạy mã `7779999`, PostgreSQL **chỉ
đọc** — mọi thay đổi trạng thái đi qua API admin đúng đường người dùng thật:

| Ca | Trạng thái | Kết quả `/auth/refresh` |
|---|---|---|
| **A** | `Active` (đối chứng) | **200** *"Token đã được làm mới"*, không mã — đúng |
| **B** | `Inactive` — `PATCH /admin/updatestatus/16` (body **bắt buộc** có `reason_inactive`) | **401 + `code: ACCOUNT_INACTIVE`**, kèm `idaccount: 16` và `reason_inactive` **ở cấp gốc**; `message` mang nguyên câu lý do admin nhập |
| **C** | `Deleted` — `DELETE /admin/deleteuser/16` (xoá **mềm**) | **401 + `code: ACCOUNT_DELETED`**, kèm `idaccount: 16` — **dù 4/4 refresh token của tài khoản đã bị thu hồi** (`SELECT COUNT(*) FILTER (WHERE "Status" = true)`) |

Ca **C** chính là ca gốc của G36: trước bản `7779999`, token bị thu hồi khiến `/auth/refresh` ném 401
*không mã* trước khi kịp kiểm tài khoản. Nay nó trả mã, nên app hiện được hộp thoại lý do.

Phía client **không phải đổi gì**: `tuBody401` đọc `code` ở cấp gốc, `message` và `idaccount` — đúng ba
trường backend trả — và ca `lamMoi` + `ACCOUNT_DELETED` đã có test từ trước
(`test/core/api/auth_interceptor_buoc_dang_xuat_test.dart:267-289`). Chỉ một **chú thích** ở
`lib/core/auth/buoc_dang_xuat.dart` phải sửa, vì nó khẳng định điều ngược lại — xem ngay dưới.

⚠️ **Liên quan §3.6b — kết luận cũ bị lật.** Tài liệu và chú thích trước 2026-09-13 viết rằng *"xoá qua
admin thu hồi refresh token nên `/auth/refresh` trả 401 không mã, đường `lamMoi` không bao giờ mang
`daXoa`"*, và vì thế ngoại lệ *không dọn SQLite khi `daXoa` đến từ nhánh làm mới* là **gần như vô
nghĩa**. Câu ấy đúng cho tới bản `7779999` và **sai từ đó**: ca C vừa đo cho thấy đường `lamMoi` **có**
mang `daXoa`. Ngoại lệ §3.6b nay chặn đúng một ca thật — tài khoản bị xoá, phát hiện qua nhánh làm mới —
chứ không chỉ che ca lỗi lược đồ. ✅ **Người dùng chốt 2026-09-13: GIỮ ngoại lệ.** SQLite là bản duy nhất trên máy nên dọn nhầm
là mất thật; còn nếu xoá là đúng thì `purgeDataForOtherAccounts` vẫn dọn khi tài khoản khác
đăng nhập vào máy — tức chỉ **hoãn** việc dọn chứ không bỏ. Không đổi mã: hành vi hiện tại đã
đúng quyết định ấy, chỉ hai chú thích Dart được ghi lại cho khớp.

### ~~G38 — Ba trang giao dịch rơi về tài khoản admin khi chưa có phiên~~ · ✅ ĐÓNG (2026-09-14, mở và đóng trong cùng ngày)

> ✅ **Đóng ngay khi tìm ra.** Ghi lại vì **cách nó sống sót** đáng nhớ hơn bản
> thân lỗi: nó đi qua cả hai lượt đóng cùng chủ đề — G4 (bốn trang bill/goal)
> và G35 (ba màn quản lý danh mục) — mà không lượt nào thấy.

**Hiện trạng (trước bản sửa).** Ba trang khai tham số mặc định `1`:

```dart
const TransactionPage({super.key, this.idaccount = 1});
...
currentUserId = int.tryParse(authState.user!.id) ?? widget.idaccount;
```

Vế `??` trỏ tới một **biến**, không tới hằng `1` — nên mọi lượt `grep '?? 1'`
đều sạch, kể cả lưới quét `khong_du_phong_admin_test.dart` dựng ra sau G35.
Nhưng route dựng `const TransactionPage()` không truyền gì, nên giá trị thật
sự dùng vẫn là `1`, tức **tài khoản admin thật** (quy tắc 2 `CLAUDE.md`).

| Trang | `idaccount` dùng làm gì | Hậu quả |
|---|---|---|
| `transaction_page.dart` | mở stream ví + danh mục | **đọc** dữ liệu admin |
| `choose_category_page.dart` | đọc danh mục | **đọc** dữ liệu admin |
| `add_transaction_page.dart` | `idaccount:` khi **lưu** giao dịch | **ghi** dưới danh nghĩa admin, rồi đẩy lên và vỡ "Ownership mismatch" |

Chỗ thứ ba đúng kịch bản mà docstring `core/auth/current_account.dart` mô tả
khi G4 được đóng — chỉ khác là nó xảy ra trên đường đi nhiều nhất của app.

**Đã sửa.** Ba trang để tham số `int?` **không mặc định** (widget test vẫn tiêm
được), suy tài khoản trả `null` khi chưa có phiên, và tự xử lý `null`: đường
đọc không mở stream, đường ghi chặn lưu kèm thông báo — cùng khuôn G35.

**Lưới quét nới thêm một ca**, bắt đúng hình dạng vừa lọt. ⚠️ Lượt khảo sát tự
nó suýt kết luận sai: phép `grep -E` đầu tiên dùng `\s`, mà POSIX ERE **không
có** `\s`, nên nó trả rỗng và suýt chốt "chỉ một chỗ" — thật ra có ba.

**Nghiệm thu máy ảo** (tài khoản thử 25, PostgreSQL chỉ đọc): mốc nền cả tài
khoản 1 lẫn 25 đều **0 giao dịch**; thêm một khoản chi 55đ qua giao diện →
`Idtran c045dc60…` với `Idaccount = 25`, `Amount = -55`; tài khoản 1 vẫn **0
hàng**. Màn chọn danh mục và trang Sổ giao dịch vẫn mở đầy đủ.

**Hai ca hành vi** ở `test/features/transaction/presentation/khong_du_phong_admin_trang_giao_dich_test.dart`
canh đường ghi, và chúng ghi thẳng một điều bản đầu của chính chúng làm sai:
trong luồng thường, thiếu phiên thì màn chọn danh mục **cũng rỗng** nên chốt
"Vui lòng chọn danh mục" chặn trước — chốt tài khoản là **lớp phòng thủ thứ
hai**, và phải tiêm lệch mới dựng lại được trạng thái ấy trong widget test.

---

### ~~G47 — Thẻ hoá đơn (và bảng tra của ngân sách) mất tên danh mục mặc định toàn cục / đã xoá mềm~~ · ✅ ĐÓNG (2026-09-19, mở và đóng trong cùng ngày)

**Cùng họ G41, ở hai mảng G41 chưa chạm.** Máy ảo trong lượt đánh giá UX
2026-09-19 (mục **E8** của danh sách) cho thấy **2/3 thẻ hoá đơn** hiện "Danh
mục đã xoá". `BillPage._napTenGoi`, `BillDetailPage` và
`BudgetLocalDataSourceImpl.getAllCategories` (hàm chỉ nuôi `lookupFor`) dựng
`TransactionLookup` từ **`categoryDao.getAll(accountId)`** — hàm lọc
`idaccount = accountId` **và** `deletedAt IS NULL`, nên cả hàng mặc định toàn
cục (`idaccount = 0`, `isDefault = true` — `sync_engine.dart:733`) lẫn hàng đã
xoá mềm (tên vẫn còn nguyên trong hàng) đều mất tên. G41 đã đặt định nghĩa
duy nhất `categoryDao.getBangTraTen` cho hai repository của Phân tích, nhưng
ba chỗ này là ba bản chép tay khác của cùng truy vấn sai.

**Sửa:** cả ba về `getBangTraTen`. Không đổi giao diện `BudgetLocalDataSource`
(fake trong test không phải sửa). **Schema không đổi, payload không đổi.**

**Test:** `test/features/bill/presentation/pages/bill_page_ten_danh_muc_mac_dinh_test.dart`
— CSDL trong bộ nhớ với một danh mục `idaccount = 0` + `isDefault` và một danh
mục xoá mềm; thẻ hoá đơn phải hiện tên cả hai, `getAllCategories` phải trả cả
hai. ⚠️ Bản đầu đặt tên mẫu là "Hóa đơn" và **xanh oan**: `textContaining`
bắt trúng **tiêu đề trang** "Hóa đơn" — đổi sang "Nhà cửa" và đòi luôn thẻ
"Tiền điện" dựng được (cùng bài học G43: đòi kết quả, không đòi vắng mặt).

### ~~G46 — Trần số chữ số thiếu ở BỐN mảng còn lại, không riêng ví~~ · ✅ ĐÓNG (2026-09-18)

**Lượt soát nối tiếp G45**, lần này quét cả app thay vì một mảng. Kết quả: lỗ
hổng vừa vá ở ô số dư ví **không phải chuyện riêng của ví**. Đo trên CSDL cùng
ngày, **tám** cột tiền đều là `numeric(15,2)` — `transaction."Amount"`,
`bill."Amount"`, bốn cột của `budget`, `goal."Target_amount"`,
`wallet."Balance"` — và **không ô nhập nào trong bốn mảng còn lại** giới hạn số
chữ số.

| Mảng | Ô | Hỏng thế nào |
|---|---|---|
| **Giao dịch** | bàn phím **tự vẽ**, không phải `TextField` | Nặng nhất: người dùng ghi giao dịch **hàng ngày**, và bàn phím có phím **`000`** nên ba chữ số vào một lúc. `inputFormatters` không với tới đây |
| **Hoá đơn** | ô số tiền ở cả màn Thêm lẫn màn Sửa | Không bộ lọc nào |
| **Mục tiêu** | số tiền mục tiêu, số tiền trích | nt |
| **Ngân sách** | hạn mức, ngưỡng cảnh báo bằng tiền | nt |

Hậu quả giống hệt G45: tràn cho SQLSTATE `22003`, `sync.service.js` **không có
nhánh** cho mã ấy nên trả `DB_ERROR`, và `_permanentCodes` của `SyncEngine` là
**danh sách trắng** — bản ghi bị **gửi lại ở mọi chu kỳ đồng bộ**, im lặng.

**Đã sửa thế nào.** Ba mảng dùng `TextField` thì áp `GioiHanSoChuSo` có sẵn.
Màn giao dịch thì phép gõ tách thành hàm thuần **`themPhimSoTien`**
(`transaction/domain/ban_phim_so_tien.dart`) — ⚠️ phím `000` **cắt bớt cho vừa
trần** thay vì bỏ cả cụm, vì bỏ cả cụm thì người dùng bấm mà không thấy gì xảy
ra. Và thêm **test quét `lib/` thứ tám** (`o_nhap_tien_co_tran_test.dart`) để ô
tiền mới thêm sau này không mở lại lỗ hổng: thiếu trần **không gây lỗi nào** lúc
gõ, chỉ hàng đợi đẩy là hỏng, và nó hỏng ở nơi không ai nhìn.

> ⚠️ **Lại một lỗi bố cục do chính trần sinh ra, lại chỉ máy ảo thấy.** Ở cỡ
> chữ 48 trên 411dp, `9.999.999.999.999đ` — **đúng trần** — **ngắt thành hai
> dòng**, chữ "đ" rơi xuống dòng dưới và đẩy cả màn xuống. Đây **không phải
> tràn**: không sọc vàng, không `FlutterError`, `takeException()` trả `null`.
> `Text` chỉ lặng lẽ ngắt dòng. Sửa bằng widget `SoTienLon` (`FittedBox` +
> `maxLines: 1`), và ca test phải đo **chiều cao thật** — bản sai cho 207px so
> với ngưỡng 80.
>
> Đây là **lần thứ ba trong cùng một ngày** một trần số chữ số biến giá trị lớn
> nhất thành **hợp lệ đạt tới được** rồi lộ ra một bố cục chưa từng được thử với
> giá trị ấy. Hai lần trước ở G45.

⚠️ **`FittedBox` dùng được ở đây mà không dùng được ở ô số dư ví**: nó đo con ở
ràng buộc **vô hạn** rồi mới thu nhỏ; `Text` có bề rộng tự nhiên xác định dưới
ràng buộc ấy, còn `TextField` thì không. Đó là lý do `OSoDuVi` phải đi đường
khác (`Flexible` + bậc thang cỡ chữ).

**Mọi ràng buộc khác đã kiểm và AN TOÀN**, không phải sửa gì: số tiền phải dương
ở hoá đơn / mục tiêu / giao dịch / ngân sách; ngưỡng phần trăm 1–100; ngày kết
thúc sau ngày bắt đầu (khoá bằng `firstDate` của bộ chọn); tiến độ mục tiêu
không âm được (giao diện chặn rút quá, repository có trần thứ hai theo số dư
ví); `chk_transaction_type` và `chk_category_classify` đều được normalizer dịch;
bảy ô nhập tên đều có giới hạn độ dài.

**Nghiệm thu máy ảo:** bấm phím số 20 lần ở màn Thêm giao dịch thì dừng đúng 13
chữ số, hiện **một dòng**, cỡ chữ đã co, bố cục dưới không bị đẩy.

---

### ~~G45 — Sáu lỗ hổng của mảng ví, tìm được bằng một lượt soát có chủ đích~~ · ✅ ĐÓNG (2026-09-18)

**Không đến từ một báo lỗi.** Người dùng hỏi *"chức năng ví đã đầy đủ chưa, có
lỗ hổng nào cần sửa, có ràng buộc nào cần bổ sung không"*, và lượt soát đối
chiếu **từng ràng buộc PostgreSQL với chốt tương ứng phía client**. Sáu chỗ hở,
tất cả đều hỏng **im lặng**.

| # | Lỗ hổng | Hỏng thế nào |
|---|---|---|
| 1 | `softDelete` **không chặn** ví đang gắn **hoá đơn** | `payBill` không kiểm ví còn sống, nên hoá đơn vẫn trả được sau khi ví bị xoá; khoản chi rơi vào một ví đã bị loại khỏi mọi phép cộng tổng. Tiền biến mất khỏi màn hình trong khi hoá đơn báo "đã trả". Server để `fk_bill_wallet` là **ON DELETE RESTRICT** |
| 2 | Phép đếm giao dịch bỏ sót **khoản chuyển đến** | `getByWallet` chỉ lọc cột `walletId`. Ví **chỉ nhận tiền chuyển vào** bị coi là chưa từng dùng và xoá được — đi ngược chính câu "bảo toàn lịch sử tài chính" của thông báo ngay cạnh |
| 3 | Ô nhập số dư **không giới hạn chữ số** | `Balance` là `numeric(15,2)`. 14 chữ số là tràn → SQLSTATE `22003` → `sync.service.js` **không có nhánh** cho mã ấy nên trả `DB_ERROR` → danh sách lỗi vĩnh viễn của client là **danh sách trắng** nên ví bị **gửi lại ở mọi chu kỳ đồng bộ**. Đúng vòng lặp mà G31 và G14 sinh ra để chặn |
| 4 | Thông báo "điều chuyển số dư về 0đ trước khi xóa" dẫn tới **ngõ cụt** | Từ G37 mọi cách đưa số dư về 0 đều **sinh thêm một giao dịch**, nên làm đúng lời khuyên xong thì ràng buộc 2 chặn lại. Người dùng đi hết một vòng về đúng chỗ cũ |
| 5 | `walletForPush` **không chuẩn hoá `currency`** | Cột thứ **ba** có CHECK (`chk_wallet_currency`), và là cột duy nhất chưa được che — `type` và `status` đều đã có lớp này sau khi mỗi cột làm ví kẹt hàng đợi một lần. Chưa có đường kích hoạt vì không màn nào cho đổi tiền tệ |
| 6 | Không chốt cấm đặt ví **đã lưu trữ** làm ví mặc định | Chiều ngược của chốt đã có trong `setArchived`. `chonViChonSan` tìm ví mặc định trong danh sách đã lọc, không thấy thì lặng lẽ rơi về ví đầu — công tắc người dùng vừa bật chẳng làm gì cả |

**Đo được trên dữ liệu thật** (PostgreSQL, cùng ngày): 26 hoá đơn đang gắn ví,
trong đó **một ví xoá được ngay lúc ấy**; 12 giao dịch chuyển có ví đích, chưa
ví nào rơi vào trạng thái của lỗ hổng 2.

**Đã sửa thế nào.** `TransactionDao.demGiaoDichLienQuan` đếm cả hai vai (nguồn
và đích) — `getByWallet` **giữ nguyên nghĩa cũ** vì hai ca test của mục tiêu
dựa đúng vào nó. `softDelete` thêm ràng buộc thứ tư cho hoá đơn. `GioiHanSoChuSo`
+ `kSoChuSoToiDaSoTien` ở `core/utils/gioi_han_do_dai.dart`, áp cho ô số dư ở cả
hai màn. `SyncPayloadNormalizer.tienTeGuiLen` nâng chữ thường thay vì gộp mù về
`VND` (gộp mù là biến một ví USD viết thường thành ví VND).
`_kiemViMacDinhConDung` ở datasource, và nó **chỉ canh đường người dùng chủ
động** — nhánh kéo về ghi thẳng qua DAO nên trạng thái ấy vẫn đến được từ máy
khác, đúng như chốt trong `setArchived`.

> ⚠️ **Hai lỗi NỮA do chính lượt vá sinh ra, cả hai chỉ máy ảo thấy.**
>
> **(a) Tràn bố cục 70px.** Giới hạn 13 chữ số biến một trạng thái vốn vô nghĩa
> thành trạng thái **hợp lệ đạt tới được**, và ở cỡ chữ 40 trên 411dp thì
> `9.999.999.999.999` vỡ ô nhập. Sửa bằng cách tách ô số dư thành widget
> `OSoDuVi`. ⚠️ Và bản sai lật một kết luận: thứ chặn tràn là **`Flexible`**
> bọc `IntrinsicWidth`, **không phải** bậc thang cỡ chữ — ép cỡ chữ về 40 cố
> định mà hai ca bố cục **vẫn xanh**. Bậc thang lo việc khác: giữ con số đọc
> được hết thay vì bị cuộn khuất. Vì thế ca test của nó đo **thẳng giá trị trả
> về**, không đo bề rộng.
>
> **(b) Cỡ chữ không co khi gõ.** `OSoDuVi` là `StatelessWidget` đọc
> `controller.text` một lần lúc dựng, nên số dài giữ nguyên cỡ 40 rồi bị cuộn
> khuất **mất chữ số đầu** — bố cục vẫn lành nhờ `Flexible` nên **không có sọc
> vàng nào để nhìn thấy**, và ba ca dựng-một-lần cũng mù. Sửa bằng
> `ValueListenableBuilder` nghe chính controller.

**Nghiệm thu máy ảo** (`emulator-5554`, tài khoản thật): gõ 18 chữ số vào ô số
dư thì chỉ nhận `9.999.999.999.999`, hiện **trọn vẹn**, cỡ chữ đã co, không tràn
không cuộn khuất. Xoá ví "test" (số dư −100.000) thì hiện đúng thông báo mới và
ví không bị xoá.

**Ba chỗ cố ý KHÔNG làm**, để đúng phạm vi "sửa lỗ hổng": không thêm nút "đưa số
dư về 0 rồi lưu trữ" (tính năng mới); không ép màn Sửa ví dùng `OSoDuVi` (bố cục
riêng, `Expanded` nên vốn không tràn — nhưng khối `onChanged` chèn dấu chấm vẫn
còn **hai bản**); không xoá `bienThang` dù nó đã 0 chỗ gọi từ mục 3.33.

---

### ~~G44 — Kỳ rỗng: tệp xuất in khối Ngân sách mà màn Xem trước giấu~~ · ✅ ĐÓNG (2026-09-18)

**Tìm được khi nghiệm thu máy ảo** cho mục **3.31** `ANALYTICS_FEATURE.md` (ba
khối cuối vào tệp xuất). Tôi xuất một khoảng **rỗng** — 08–17/09 — để chạm
nhánh "kỳ không có giao dịch nào", và thấy tệp PDF ca ấy vẫn in bảng *Ngân sách
kỳ này* với dòng `Giáo dục 45.000đ / 50.000đ / 5.000đ`.

**Triệu chứng.** Kỳ rỗng thì `report_preview_page.dart` đi nhánh
`if (baoCao.rong)` và dựng thẻ *"Không có giao dịch nào trong khoảng đã chọn"*
thay cho cả nhánh `else`. Còn `xuat_tep.dart` gác từng khối theo **độ rỗng của
chính khối ấy** (`if (bc.nganSach.isNotEmpty)`, `if (bc.theoVi.isNotEmpty)`, …).
Với kỳ rỗng thì mọi khối khác cũng rỗng theo nên trùng khớp — **trừ ngân sách**,
thứ tồn tại độc lập với giao dịch.

> ⚠️ **Đính chính, đo lại 2026-09-18 khi sửa.** Tiêu đề cũ của mục này ghi *"màn
> Xem trước giấu **mọi** khối"* — **không đúng**. Kỳ rỗng thì màn vẫn hiện đầu
> báo cáo, khối **Dòng tiền** và **ba thẻ tổng**; chỉ nhóm khối nằm trong nhánh
> `else` mới bị giấu. Điều ấy quan trọng khi chọn chiều sửa: tệp xuất **cũng**
> in đúng ba thứ đó khi kỳ rỗng (số dư đầu/cuối kỳ, ba dòng kỳ trước, tổng bằng
> 0), nên hai bên đã khớp nhau sẵn ở đấy và lệch **đúng một khối**.

**Bán kính ảnh hưởng: hẹp.** Chỉ hiện ra khi (a) kỳ không có giao dịch nào
**và** (b) tài khoản có ít nhất một ngân sách đang chạy. Con số in ra **không
sai** — ngân sách ấy có thật, "đã chi" của nó đếm theo kỳ của chính nó chứ
không theo kỳ báo cáo. Không hàng nào kẹt, không lỗi, không đồng bộ.

**Vì sao từng hoãn.** Chưa rõ **bên nào mới đúng**, và đó là câu hỏi sản phẩm
chứ không phải câu hỏi kỹ thuật:

- Tệp đúng → màn Xem trước đang **giấu** một thông tin có thật chỉ vì kỳ rỗng.
- Màn đúng → tệp đang chở một bảng mà người đọc sẽ hiểu là "của kỳ này", trong
  khi kỳ này chẳng có gì.

Sửa theo chiều nào cũng là một dòng, nhưng chọn sai chiều thì **không ai phát
hiện được** — cả hai bản đều trông hợp lý. Nằm ngoài phạm vi người dùng đã
duyệt cho mục 3.31 (đúng ba khối), nên ghi lại thay vì tự quyết.

**Chiều đã chốt (người dùng, 2026-09-18): tệp theo màn.** Kỳ rỗng thì tệp bỏ
hẳn khối Ngân sách. Lý lẽ: người đọc hiểu mọi bảng trong tệp là "của kỳ này",
mà "đã chi" của ngân sách đếm theo kỳ của **chính nó** — và người cầm tờ PDF
không có chỗ hỏi lại, khác hẳn người đang đứng trước màn hình.

**Đã làm thế nào.** Một vị từ thuần **`inKhoiTheoKy(BaoCao)`** ở
`analytics/domain/bao_cao_xuat.dart`, cạnh `rong`; **ba** chỗ gọi cùng đọc nó:
`csvBaoCao`, `pdfBaoCao`, và nhánh rỗng của `report_preview_page.dart`. Khối
*Số liệu nhanh* vốn đã gác bằng `!bc.rong` kèm chú thích *"cùng luật với màn
Xem trước"* — nay chú thích ấy thành **mã**.

⚠️ **Vế `inKhoiTheoKy` phải đứng cạnh `isNotEmpty` ở khối ngân sách chứ không
thay nó**, và chỉ ở **khối ấy**: mọi khối khác tự rỗng theo kỳ rỗng nên vế thừa,
còn ngân sách thì không.

⚠️ **Ở nhánh PDF phải chặn tại NGUỒN HÀNG, không bọc quanh `_pdfBang`** — hàm ấy
tự bỏ cả bảng khi không còn hàng nào, nên truyền danh sách rỗng là đủ và không
sinh thêm một nhánh `if` thứ hai phải giữ đồng bộ.

**Năm ca test.** Hai ca ở `bao_cao_xuat_test.dart` canh vị từ hai chiều; hai ca
CSV ở `xuat_tep_test.dart` (kỳ rỗng bỏ hẳn bảng · kỳ thường in y như cũ); một ca
PDF. ⚠️ **PDF nén luồng nội dung nên không tìm chuỗi trong byte được** — phép đo
thay thế là so **độ dài** hai tệp của cùng một kỳ rỗng, một bản có ngân sách một
bản không. Bản sai có chủ ý làm ca ấy đỏ với chênh lệch **2 847 byte**, nên nó
canh thật chứ không xanh sẵn.

---

### ~~G43 — Nút "Tuỳ chọn" của bộ chọn phạm vi chết im lặng~~ · ✅ ĐÓNG (2026-09-16, mở và đóng trong cùng ngày)

**Tìm được khi nghiệm thu máy ảo** cho mục #2 (so cùng kỳ năm trước) — tôi cần
một kỳ **tuỳ chọn** để xem nhãn dài nhất, và nút ấy không chịu mở.

**Triệu chứng.** Chạm "Tuỳ chọn" trong bộ chọn phạm vi: **không có gì xảy ra**.
Không bộ chọn ngày, không toast, không màn đỏ, sheet vẫn nguyên đó. Bốn chip
kia (`Tuần`, `Tháng`, `Quý`, `Năm`) đều ăn bình thường ở **cùng một hàng**, nên
thoạt nhìn rất giống lỗi toạ độ chạm của chính mình.

**Bằng chứng.** `adb logcat`:

```
E flutter : Unhandled Exception: 'package:flutter/src/material/date_picker.dart':
  Failed assertion: line 1218 pos 5:
  'initialDateRange == null || !initialDateRange.end.isAfter(lastDate)':
  initialDateRange's end date must be on or before lastDate 2026-09-16 00:00:00.000.
  #2  showDateRangePicker (package:flutter/src/material/date_picker.dart:1218:5)
```

**Gốc rễ.** `_chonKhoangTuyY` truyền thẳng kỳ đang xem làm khoảng khởi tạo:

```dart
lastDate: nay,
initialDateRange: DateTimeRange(
  start: widget.kyHienTai.from,
  end: widget.kyHienTai.to.subtract(const Duration(days: 1)),
),
```

`lastDate` là **hôm nay**, còn kỳ đang xem thì kết thúc ở **cuối kỳ**. Nên bất
cứ khi nào kỳ chứa hôm nay — tức *Tháng này*, *Quý này*, *Năm nay*, *Tuần này*,
**đúng trạng thái mặc định của trang** — mốc cuối nằm ở tương lai và assertion
nổ.

⚠️ **Vì sao nó sống được lâu và im lặng đến thế:** đây là exception trong một
hàm `async` mà **không ai `await` có `catch`**, nên Flutter chỉ in ra console.
Trên bản release người dùng còn không có console. Nút trông như một nút chết.

**Vì sao bộ test mù.** `chon_pham_vi_sheet_test.dart` có **10** ca, nhưng **không
ca nào chạm vào chip "Tuỳ chọn"** — chúng kiểm nhãn, kiểm đổi chip đổi danh sách,
kiểm khổ 411dp. Lỗi nằm sau một cú chạm mà không ai thực hiện. Có sẵn từ **P1
(2026-09-15)**, qua cả lượt nghiệm thu máy ảo hôm ấy.

**Sửa.** Phép kẹp tách thành hàm thuần `khoangKhoiTaoBoChonNgay` ở
`analytics/domain/pham_vi_ky.dart`: kẹp `from` vào `somNhat`, kẹp mốc cuối vào
`muonNhat`, và trả **`null`** khi kỳ không giao với dải cho phép — chỗ gọi mở bộ
chọn mà không đặt khoảng sẵn. Trả một khoảng đảo đầu-cuối chỉ là đổi sang một
assertion khác.

**Bốn ca widget mới** chạm thật vào nút, từ bốn kỳ khác nhau, và **không** chỉ
kiểm "không ném" mà còn đòi `DateRangePickerDialog` thật sự hiện — "không ném"
một mình vẫn xanh với một nút chết. ⚠️ Chúng phải gọi `ensureVisible` trước khi
chạm: font bộ test rộng gấp đôi nên năm chip **không vừa** 411dp ở đó, dù trên
máy thật thì vừa (bẫy 4.4). Nới khổ test là bỏ luôn phép đo chặt mà tệp ấy cố ý
giữ, nên kéo hàng chip — vốn cuộn ngang được — vào tầm nhìn.

**Nghiệm thu máy ảo.** Bộ chọn mở được từ "Tháng này", khoảng khởi tạo hiện
`Sep 1 – Sep 16` và mọi ngày sau 16/09 bị khoá; chọn xong trang đổi sang kỳ
`01/09 – 16/09`; `logcat` **0** dòng `Unhandled Exception`.

**Bài học.** Một hàng nút mà chỉ **một** nút hỏng thì rất dễ bị đổ cho toạ độ
chạm. Cách rẻ để phân biệt: bấm một nút **khác trong cùng hàng** — nếu nó ăn
thì toạ độ đúng, và vấn đề nằm trong mã.

### ~~G42 — Ví đã xoá mềm vẫn phình "số dư cuối kỳ"~~ · ✅ ĐÓNG (2026-09-16, mở và đóng trong cùng ngày)

**Tìm được khi soát tài liệu**, không phải khi chạy app: viết mục 3.27 cho tính
năng dự báo dòng tiền thì phải đọc lại mọi chỗ cộng số dư ví, và một chỗ không
khớp những chỗ còn lại.

**Triệu chứng.** "Số dư cuối kỳ" của khối **Dòng tiền** và của **thác nước
"Tiền đi đâu"** cộng cả số dư những ví người dùng đã xoá. Ca test tái hiện đo
được **17.000.000 thay vì 10.000.000** với một ví xoá mềm còn 7.000.000. Không
exception, không log — chỉ một con số người dùng không có.

**Gốc rễ.** `AnalyticsRepositoryImpl` đọc ví bằng truy vấn thẳng
`db.select(db.wallets)..where(idaccount)`, **không lọc `deletedAt`**. Điều đó
**có chủ ý và vẫn đúng**: giao dịch cũ vẫn trỏ vào ví đã xoá, và bảng tra tên ví
cần hàng ấy để dòng "Phân bổ theo ví" không hiện "Ví đã xoá" thay cho tên thật.
Cái sai là hàng ấy rồi được cộng `balance` qua `viTinhVaoTong`, mà hàm khi ấy
chỉ hỏi hai vế — `includeInTotal` và trạng thái lưu trữ.

⚠️ **Phạm vi hẹp hơn lần báo đầu.** Lượt soát ban đầu ghi
`bao_cao_repository_impl.dart:84` "cần soát cùng"; đọc kỹ thì nó **không sai** —
nó đi qua `walletDao.getAll`, và hàm ấy **có** lọc `deletedAt.isNull()`.
`wallet_repository_impl.dart:115` cũng vậy. Chỉ **một** chỗ hỏng.

**Vì sao sửa trong hàm, không vá ở chỗ gọi.** `vi_tinh_vao_tong_test.dart` mở
đầu bằng câu *"tệp này tồn tại để không có bản thứ năm"* — và đây đúng là bản
thứ năm, chỉ quên một vế khác. Vá tại chỗ gọi là để nguyên cái bẫy cho chỗ gọi
thứ sáu. Nay `viTinhVaoTong` nhận `isDeleted` (mặc định `false`, nên bốn chỗ đọc
qua `walletDao` không phải sửa gì), và `du_bao_dong_tien.dart` bỏ phép kiểm
`isDeleted` riêng nó từng tự làm — đó cũng là một bản chép tay.

**Kiểm:** hai ca mới (một ở tầng thuần, một ở repository); bản sai có chủ ý bỏ
vế `!isDeleted` làm **cả hai** đỏ đúng con số. `flutter test` **2643/2643**,
`flutter analyze` **25 issue, 0 error**.

### ~~G41 — Giao dịch trỏ vào danh mục mặc định toàn cục bị mất tên~~ · ✅ ĐÓNG (2026-09-15, mở và đóng trong cùng ngày)

**Vì sao thấy.** Nghiệm thu máy ảo cho hạng mục *tỉ lệ tiết kiệm*, khối "Xu
hướng 6 tháng" hiện **hai chip cùng mang tên "Danh mục đã xoá"** — hai danh mục
khác nhau đội một cái tên, không cách nào phân biệt. Lỗi không thuộc hạng mục
đang làm; nó có sẵn từ trước.

**Bằng chứng trước, không đoán.** Truy vấn PostgreSQL gom giao dịch theo chủ sở
hữu danh mục cho ra **đúng hai** hàng bất thường ở tài khoản đang đăng nhập:

| Danh mục | `Create_by` | `Is_default` | `Delete_at` | Số giao dịch |
|---|---|---|---|---|
| `Chi khác` | **1** | true | đã xoá mềm | 2 |
| `Làm thêm` | **1** | true | đã xoá mềm | 1 |

Đúng **hai** — khớp số chip trên màn hình. Cả hai là **danh mục mặc định toàn
cục**, nằm trong nhóm năm hàng backend xoá mềm ngày 2026-09-07 khi thu bộ khuôn
về 13 stable UUID.

**Gốc rễ.** `sync_engine` quy `is_default = true` thành **`idaccount = 0`**
(`sync_engine.dart:733`), nên hàng mặc định toàn cục **không mang mã tài khoản
nào**. Nhưng cả hai repository tra danh mục đều lọc `t.idaccount.equals(idaccount)`:

- `analytics_repository_impl.dart` — trang Thống kê
- `bao_cao_repository_impl.dart` — trang Xuất báo cáo và màn Xem trước

Hai bản chép tay của cùng một truy vấn, và **cả hai cùng thiếu** vế `isDefault`.
Giao dịch trỏ vào hàng ấy tra không ra tên → rơi vào nhánh `?? 'Danh mục đã xoá'`.

⚠️ **Ảnh hưởng rộng hơn cái chip đã lộ ra.** Cùng bảng tra ấy nuôi donut "Cơ cấu
theo danh mục", cột thác nước, và danh sách danh mục cuối trang — tất cả đều mất
tên. Chip chỉ tình cờ là chỗ **hai** cái trùng nhau nằm cạnh nhau nên mắt bắt
được; những chỗ kia chỉ hiện *một* nhãn "Danh mục đã xoá" trông hợp lý.

**Vì sao lọt qua mọi lượt trước.** Chú thích ở cả hai chỗ nói rất đúng về vế thứ
nhất — *"kể cả hàng đã xoá mềm, vì tên thật còn nằm trong hàng"* — và có test
canh hẳn hoi. Vế thứ hai thì không ai viết ra: hàng mặc định **cũng** không
thuộc `idaccount` nào. Test cũ dựng danh mục đã xoá mềm với `idaccount: 1`, tức
một hình dạng **không tồn tại trên máy thật** cho danh mục mặc định.

**Bản sửa.** Một định nghĩa duy nhất ở `CategoryDao.getBangTraTen` /
`watchBangTraTen`, lọc theo **cờ** `isDefault` bên cạnh tài khoản — cùng khuôn
với `getNamesInUse` vốn đã làm đúng từ trước. Hai repository nay gọi nó thay vì
tự viết truy vấn. Hai ca test mới, mỗi repository một ca, dựng đúng hình dạng
thật (`idaccount: 0`, `isDefault: true`, đã xoá mềm); cả hai đỏ trước khi sửa.

**Nghiệm thu.** Máy ảo, cùng tài khoản: chip nay là **"Chi khác"**, "Di chuyển",
"Giáo dục" — không còn chip "Danh mục đã xoá" nào; cột thác nước đổi từ
`Danh mục đ…` sang **"Chi khác"**. `flutter test` **2573/2573**, `flutter
analyze` **25 issue, 0 error**.

**Bài học.** Hai bản chép tay của một truy vấn là chỗ lỗi sống lâu nhất: sửa một
bên thì bên kia vẫn sai, và chú thích đúng ở cả hai chỗ khiến không ai nghi. Khi
một luật có hai nơi thi hành, đưa nó về DAO trước rồi mới sửa.

### ~~G40 — Trang Xem trước báo cáo lệch cột số tiền~~ · ✅ ĐÓNG (2026-09-15, mở và đóng trong cùng ngày)

**Vì sao nghi.** Ngày 2026-09-15, người dùng bắt được trên máy ảo rằng cột số
tiền ở hai khối mới của trang Phân tích — "Phân bổ theo ví" và "Top 5 khoản chi"
— **không thẳng mép phải**; đo trong widget test thấy lệch **26,5px**. Gốc rễ là
`Flexible`: nó và `Expanded` đều mang `flex: 1` nên chia đôi chỗ trống như nhau,
nhưng `Flexible` để con giữ **bề rộng tự nhiên** và `MainAxisAlignment.start`
đẩy phần thừa về **cuối hàng**, nên `alignment: centerRight` của `FittedBox`
đang canh phải bên trong một cái hộp đang trôi. Bẫy **4.19**
`ANALYTICS_FEATURE.md`.

Hai khối ấy của trang Phân tích **chép khuôn từ `report_preview_page.dart`**, và
tệp gốc vẫn còn nguyên `Flexible(child: FittedBox(…))`. Cùng khuôn, cùng dạng dữ
liệu (số tiền dài ngắn khác nhau theo hàng), nên nhiều khả năng cùng lệch.

Hạng mục ấy **không sửa ngay**, vì hai lý do cố ý: chưa nhìn tận mắt (suy từ mã
sang kết luận "chắc chắn lệch" là đúng loại sai lầm phiên 12 đã trả giá với
Stitch), và người dùng báo về trang Phân tích chứ không phải trang này.

**Đo được gì khi mở lại.** Mở trang trên máy ảo `emulator-5554` với dữ liệu thật
ngày 2026-09-15, rồi đếm pixel chữ trên từng hàng. Lỗi có thật, và **nặng hơn**
chỗ đã sửa:

| Khối | Mép phải chữ (px, ảnh 1080) | Lệch |
|---|---|---|
| Chi theo danh mục | 856 … 949 | **93px** |
| Phân bổ theo ví | 727 … 783 | **56px** |
| Top 5 khoản chi | 771 … 776 | 5px, nhưng cách mép thẻ hơn 200px |

⚠️ **Và không phải hai khối mà SÁU.** Dòng đầu của lỗ hổng này đoán theo tên hai
khối mà người dùng báo; đếm bằng máy thì `report_preview_page.dart` mang **sáu**
chỗ cùng khuôn `Expanded(tên) + Flexible(FittedBox centerRight)` — thêm khối
ngân sách, thu/chi theo danh mục, danh sách giao dịch, và hàng "Thay đổi trong
kỳ" của khối dòng tiền. Bài học: khi một lỗ hổng mô tả lỗi bằng **tên khối**
người dùng nhìn thấy, hãy `grep` khuôn mã trước khi tin vào con số ấy.

**Sửa.** Sáu `Flexible` → `Expanded`. Cột trái **không mất chỗ nào**: tỉ lệ chia
vẫn 1:1, chỉ khác ai giữ phần thừa. Đo lại trên máy ảo sau khi sửa: **0px** lệch
ở mọi khối, mọi cột kết thúc ở 979–982 — tức sát mép trong của thẻ.

⚠️ **Sáu ca test mới suýt vô dụng vì font của bộ test.** Viết ở khổ 411dp thì ba
trong sáu ca **xanh ngay từ đầu** dù máy ảo đo được lệch 93px: font "Ahem" rộng
gấp đôi ngoài đời (bẫy 4.4) nên mọi chuỗi đều **tràn** suất, `FittedBox` thu nhỏ
chúng cho vừa, và hộp nào cũng lấp đầy suất của nó — đúng thứ mà `Expanded` lẽ
ra mới làm được. Lỗi chỉ lộ khi chữ **ngắn hơn** suất. Phải cho khung rộng **gấp
đôi** (822dp) để trả lại đúng tỷ lệ chữ trên suất của điện thoại thật.

⚠️ **Đừng dựa vào mẹo đếm pixel vàng** để tìm lỗi này: nó không phải lỗi tràn,
không có sọc cảnh báo, không exception và không một dòng log nào.

---

### ~~G39 — Nhãn trục tung của "Xu hướng 6 tháng" in đè lên nhau~~ · ✅ ĐÓNG (2026-09-14, mở và đóng trong cùng ngày)

**Triệu chứng đo được** trên `emulator-5554` ngày 2026-09-14, tài khoản có dữ
liệu thật: bật **ba** danh mục ở khối "Xu hướng 6 tháng" thì nhãn trên cùng của
trục tung là **hai chuỗi đè lên nhau** — "63.2K" và "63.3K" chồng khít, chữ số
thứ ba thành một vệt không đọc được. Phóng to ảnh chụp mới thấy; ở cỡ thật nó
trông như một nhãn in lỗi font.

**Gốc rễ.** `_KhoiXuHuong` tính `maxY` rồi `buoc = maxY / 3`, và `leftTitles`
dùng `interval: buoc`. `fl_chart` vẽ nhãn cho các mốc theo `interval` **và** cho
biên trên. Hai thứ ấy ở **cùng một vị trí** — nhưng `3 * (maxY / 3)` không bằng
`maxY` trong dấu phẩy động, và khi giá trị rơi đúng ranh giới làm tròn của
`toStringAsFixed(1)` (đuôi `…x5`), `rutGon` trả **hai chuỗi khác nhau** cho hai
số chênh nhau chừng `1e-14`. Hai nhãn ấy vẽ chồng.

⚠️ **Cùng họ, khác mặt: bẫy 4.20** (`ANALYTICS_FEATURE.md`, 2026-09-15). Vẫn là
sai số dấu phẩy động ở nhãn trục do `rutGon`, nhưng lần này biểu đồ có **phần
âm** nên biên trên là `san + 3 * buoc` và ra chừng `-1e-16` ngay tại vị trí lẽ ra
là 0 — nhãn in **`-0`**. Đóng G39 (tính `buoc` trước) **không** đóng luôn ca ấy;
nó phải sửa trong chính `rutGon`. Gặp một trong hai thì nhớ kiểm cái kia.

**Không phải lỗi của lát A8 #3/#7.** Khối "Xu hướng 6 tháng" có từ lát **2b**
(2026-09-08) và đã mang sẵn hình dạng này. Lát A8 chỉ làm nó **dễ gặp hơn**:
trước đây `maxY` chỉ nhận đúng một dải (Thu/Chi toàn tháng), nay mỗi tổ hợp chip
được bật là một dải khác. Đo cùng ngày, ba dải **không** lỗi — 16.8M (hai đường
Thu/Chi), 51.7K (một danh mục), 350.8K (năm danh mục) — chỉ dải 63.2K lỗi.

**Đã sửa thế nào.** Dự án có sẵn **một định nghĩa duy nhất** của luật lọc nhãn
trục — `hienNhanTruc` ở `goal/domain/goal_progress_series.dart`, kèm test riêng —
nhưng nó giải bài toán *mốc nằm gần biên*, còn đây là *hai mốc trùng vị trí mà
khác chuỗi*, nên nó **không** cứu được ca này: cả hai đều là biên nên nó giữ cả
hai. Bản sửa đi vào gốc rễ thay vì thêm luật lọc thứ hai — tính `buoc` **trước**,
rồi đặt `maxY = buoc * 3`, để biên trên **chính xác** bằng mốc cuối của
`interval`. Một dòng, không đổi thang đo (`buoc` vẫn là `đỉnh × 1,15 ÷ 3`).

**Ca test tái hiện** — `nhãn trục tung không in HAI chuỗi khác nhau ở cùng một
mốc` ở `analytics_page_test.dart`. Nó dùng đỉnh **43.000**, một trong **tám**
giá trị tìm được khi quét dải 1.000–300.000 (bước 500) bằng máy. Điểm đáng nhớ:
bẫy đồ hoạ này **tái hiện được ngay trong widget test** — fl_chart dựng nhãn
bằng widget thật, nên `find.text` thấy chúng; đây là ngoại lệ hiếm của luật "lỗi
biểu đồ chỉ lộ trên máy thật" (bẫy 4.9). Ca ấy assert theo cách bền với **cả
hai** hướng sửa: không được có đồng thời hai chuỗi ở biên trên, và phải còn đúng
một — chữa bằng cách bỏ luôn nhãn biên là mất mốc cao nhất của thang đo.

**Nghiệm thu máy ảo** `emulator-5554` cùng ngày, đúng dải đã phát hiện lỗi: nhãn
trên cùng nay là **"63.3K" sạch**, một chuỗi duy nhất — trước đó cùng chỗ ấy là
"63.2K" và "63.3K" chồng khít, chữ số thứ ba thành một vệt. Ảnh ghép trước/sau ở
scratchpad phiên: `so_sanh_g39.png`.

**Mức độ:** không hỏng dữ liệu, không hỏng im lặng ở chỗ khác — chỉ một nhãn khó
đọc.

---

### G37 — Số dư ví không phản ánh giao dịch sau một lần đẩy bị xung đột · ✅ ĐÓNG 2026-09-13

**Triệu chứng đo được**, hai máy ảo cùng tài khoản, hoá đơn tự động trả (nghiệm thu bước 12):
máy **thắng** giữ khoản chi hợp lệ −350.000 mà ví vẫn là **2.000.000** thay vì 1.650.000. Máy
thua thì đúng, vì khoản chi của nó đã được gỡ và tiền đã hoàn.

**Gốc rễ.** `wallets.balance` là một cột đồng bộ **LWW thuần**, còn server **không tính lại** số
dư từ giao dịch. Chuỗi:

1. máy trả hoá đơn → `updateBalance` trừ ví cục bộ, hàng thành `pending`;
2. push ví → **xung đột** (`update_at` của server mới hơn) → `_markSyncedById`, client nhận
   "lấy theo server";
3. pull ghi đè `balance` bằng con số server — **lần trừ biến mất không dấu vết**, và vì hàng vừa
   bị đánh dấu `synced` nên không còn gì để đẩy lại.

**Đã đóng cùng ngày.** Sửa tận gốc là đổi *cách số dư ví được quyết định*: `wallets.balance` thôi là
dữ liệu gốc và trở thành **cache của tổng sổ giao dịch**. Vì sổ đã đồng bộ đúng, hai máy có cùng tập
giao dịch tính ra cùng một số — xung đột LWW không phá được nữa, vì không còn gì để mất.

**Nghiệm thu hai máy ảo, tài khoản thử sạch 24:** máy A tự trả hoá đơn (2.000.000 → 1.650.000), máy
B nhận `BILL_ALREADY_PAID` rồi gỡ (→ 1.650.000). **Hai máy bằng nhau và bằng tổng sổ.** Server: hoá
đơn `Payed`, đúng một khoản chi sống, một kỳ kế tiếp.

**⚠️ Ba cái bẫy của cùng một sai lầm, cả ba chỉ lộ ra khi chạy thật** — ai sửa tiếp vùng này phải
biết: neo tính bằng `balance − Σ sổ`, nên **thời điểm** đặt nó quyết định đúng sai.

1. **Đặt neo SAU khi ghi sổ** → neo hấp thụ luôn giao dịch vừa ghi; ví 1.000.000 trả hoá đơn 350.000
   có neo 1.350.000 và số dư đứng im. 53 ca test đỏ vì điều này.
2. **"Lưới đỡ" tự đặt neo trong `tinhLaiSoDu`** → ví số dư 0 nhận 1.000.000 thì neo thành
   `0 − 1.000.000`, một khoản **chi** triệt tiêu đúng khoản vừa nhận.
3. **Đặt neo cho ví vừa kéo về** → nó mang `balance = 0` (nhánh pull thôi đọc cột ấy) trong khi sổ
   đã đầy đủ; neo âm bằng cả tổng sổ. Đo thật: ví 2.000.000 hiện `0đ`.

Chốt rút ra: **số dư 0 nghĩa là "chưa biết", không phải "ví rỗng"**.

**Bán kính** rộng hơn hẳn bước 12 — **mọi** đường ghi ví đi qua đây, không riêng hoá đơn — nên có
test quét `lib/` (thứ **năm** của dự án) cấm mọi nơi khác gọi `updateBalance`.

**✅ Hướng đóng đã chốt 2026-09-13: LÀM Ở CLIENT, không xin backend.** Hai lối đã cân nhắc:

| Lối | Ai làm | Vì sao chọn / loại |
|---|---|---|
| Server tính lại `Balance` từ giao dịch | backend | **Loại.** Client tự đóng được, nên xin là đẩy việc của mình sang người khác. Vẫn phải chốt lại hợp đồng cột này ở cả hai đầu |
| Client thôi coi `balance` là dữ liệu đồng bộ, **suy từ giao dịch** | client | **Chọn.** Không phụ thuộc ai; vướng duy nhất là **số dư ban đầu** lúc tạo ví — nay nằm thẳng trong `balance` mà không có giao dịch tương ứng, nên lối này đòi mỗi ví mới sinh một khoản "số dư ban đầu" |

**Hai dữ kiện đo trên backend 2026-09-13** (chỉ đọc), cần cho bất kỳ ai làm tiếp:

- `modules/sync/sync.repository.js:259` — điều kiện LWW là
  `new Date(mapped.update_at) > new Date(existing.update_at)`, và client thua thì **cả hàng ví**
  bị bỏ qua, không riêng `balance`. Không chỗ nào trong `/sync` tính lại số dư từ giao dịch.
- `workers/bank.worker.js:213` — **đã có tiền lệ server tự ghi `wallet.balance`**, cho ví ngân
  hàng (giá trị lấy từ `bank_account`). Nên hai loại ví hiện ngầm theo **hai** hợp đồng khác nhau:
  ví ngân hàng do server ghi, ví thường do client ghi. Ai làm tiếp phải giữ nguyên vế đầu.

**Không lẫn với lỗi đã sửa trước đó cùng ngày.** Ví **phình thêm** 350.000 sau xung đột là chuyện khác và
**đã đóng**: `SyncEngine` nay phát kết quả đẩy **trước** bước Pull, nên phép hoàn tiền của
`BillPaymentConflictResolver` không còn cộng vào một con số đã bị server đè lên (ca test
`test/core/sync/sync_push_result_truoc_pull_test.dart`). G37 là phần **còn lại** của cùng một gốc,
ở nhánh mà client không bù được.

**Ô đối soát số dư ở màn Sửa ví vẫn giữ nguyên vai trò** — nó sinh một khoản bù qua
`wallet/data/services/dieu_chinh_so_du_service.dart` chứ không ghi đè. Nay nó càng đúng khuôn: mọi
thứ ảnh hưởng số dư đều là một hàng trong sổ.

**Giới hạn còn lại, chấp nhận có chủ ý:** máy chưa pull đủ giao dịch sẽ thấy số dư tạm thấp cho tới
khi pull xong — khác hẳn trước đây, nơi sai là *vĩnh viễn*. Và ví loại `banking` **bị loại khỏi mọi
phép tính lại**: server tự ghi số dư ví ngân hàng từ SePay (`workers/bank.worker.js:213`), và số dư
ngân hàng thật có thể khác tổng sổ (phí, lãi, giao dịch chưa về). *(Cập nhật 2026-09-18: nhóm đã bỏ
liên kết ngân hàng nên client không tạo được ví loại ấy nữa. Phép loại trừ **giữ nguyên** — nó bảo
vệ hàng cũ kéo về từ một tài khoản từng liên kết, không bảo vệ một tính năng.)*

## 2. Vấn đề đã biết nhưng thuộc về Backend

Tám gạch đầu dòng đầu tiên dưới đây là **ảnh chụp cũ**: cả tám tệp nay nằm ở
`docs/superpowers/backend/DA-XONG/`. Dòng này từng ghi "hai tài liệu" trong khi
liệt kê tám — sửa 2026-09-10; và từng ghi `2026-09-04-backend-idempotent-delete.md`
"còn ở `CAN-LAM/`" — sai từ khi backend chuyển tệp ấy sang `DA-XONG/` (`f8ab027`),
sửa 2026-09-11. Việc backend còn mở đọc ở `docs/superpowers/backend/CAN-LAM/README.md`
— mục 1 (ba tài liệu còn việc: mục 17, 18 và 19) và mục 2 (trạng thái mười lăm tài liệu
backend báo đã xong, đo 2026-09-11):

- **`SESSION_VALIDITY_FINDINGS.md`** — token của tài khoản đã xoá vẫn dùng được; `/auth/me` không chạm CSDL; `/sync/push` luôn trả HTTP 200.
- **`CATEGORY_CLASSIFY_ALIGNMENT.md`** — giá trị `Vay/nợ` (tài liệu) lệch với `Vay/no` (CSDL, seed, client).
- ~~**`CATEGORY_GROUP_MEMBERSHIP_SYNC.md`**~~ — G10 đã **đóng 2026-09-07**; backend không phải làm gì.
- **`2026-09-05-backend-goal-auto-deposit.md`** — G21: ba cột cấu hình trích tiền tự động chưa có chỗ chứa ở backend. **Ba cột phải lên cùng lúc**, đẩy một phần là hai máy cùng trích một kỳ.
- **`CATEGORY_KEYWORD_SYNC.md`** — từ khoá phân loại tồn tại ở hai kho độc lập, không có đường nối; kèm một lỗ hổng phân quyền trong `POST /api/ai/classify/feedback`.
- **`CATEGORY_NAME_UNIQUENESS.md`** — hai unique index của `category` đang khác quy tắc nghiệp vụ theo cả hai chiều; client đã thi hành đúng quy tắc, CSDL thì chưa.
- **`CATEGORY_STABLE_IDS.md`** — ID danh mục mặc định sinh ngẫu nhiên mỗi lần seed, nên tên bị dùng làm khoá nối giữa hai phía; đây là nguyên nhân gốc của các lỗi 11.3–11.6.
- **`2026-09-04-backend-idempotent-delete.md`** — ba lỗ hổng của `/sync/push`: xoá một bản ghi không tồn tại bị trả về là lỗi (làm client đẩy lại vĩnh viễn); `message` là nguyên văn stack trace Prisma kèm đường dẫn máy chủ; và `budget.time_recurrence = null` bị ép về `'Month'`, **chặn hẳn** lựa chọn ngân sách "Ngày cụ thể". ✅ Đo 2026-09-11: (A)(B)(C) của tài liệu đã xong; (D) — `threshold_warning_percent` bị ép `0` — xong ở mã và `schema.prisma`, nhưng CSDL dev vẫn `DEFAULT 0` (`CAN-LAM/VERIFY_7675B35_REMAINING.md` §2.2). Đường `/sync/push` luôn gửi giá trị tường minh nên client không còn dính.
- **`DA-XONG/AUTH_401_BODY_CODE.md`** (2026-09-10) — *ảnh chụp 2026-09-10:* body 401 cho tài khoản bị khoá hoặc xoá không mang `code` / `reason_inactive`, vì tham số thứ ba của `ResponseHandler.unauthorized` rơi mất. ✅ **Nhánh HTTP đã sửa (đo 2026-09-11):** body 401 mang `code`, `idaccount`, `reason_inactive` ở cấp gốc (`core/response-handler.js:32-54`), và lỗi lược đồ ở `authenticate` nay trả 503 thay vì cho qua. ⛔ Nhưng bắt tay socket và `/auth/refresh` từ chối **mọi** tài khoản (hồi quy A, gạch dưới); lời từ chối ở socket không mang mã (§2.1 mục 18), còn `/auth/refresh` trả 401 chỉ có `idaccount`. Không mở G riêng: cưỡng chế đăng xuất phía client **chưa làm** nên client chưa đọc mã nào. ⚠️ Nhưng cùng vùng ấy **có** một lỗi đang chạy, không do backend — **G33** (✅ đóng 2026-09-11, xem mục G33 ở trên).
- **`CAN-LAM/FIX_BACKEND_3_REGRESSIONS.md`** (2026-09-11) — ba hồi quy của `7675b35` trên `main`, **đã gộp** về nhánh client 2026-09-11 (`main` @ `cc65f4f`): bắt tay socket và `/auth/refresh` từ chối mọi tài khoản; chốt trả hai lần đặt ở `upsertBill` chặn hoàn tác thanh toán; tài liệu backend ghi sai ba mã lỗi. Chưa mở G riêng vì backend trên máy client chưa chạy lại từ mã đã gộp (CSDL dev đã áp `database/12` ngày 2026-09-11). ⚠️ Khi chạy lại, hoàn tác một hoá đơn đã đồng bộ **không lên được server** cho tới khi backend sửa hồi quy B, và bắt tay socket cùng `/auth/refresh` từ chối mọi tài khoản cho tới khi sửa hồi quy A. ✅ Chỗ phía client — ba mã mới (`WALLET_NAME_DUPLICATE`, `WALLET_DEFAULT_DUPLICATE` do client tự xin, và `BILL_ALREADY_PAID`) chưa có trong `_permanentCodes` nên sẽ bị gửi lại mãi — đã đóng 2026-09-11: nay chúng bị chặn theo thời gian, không kéo chậm cả hàng đợi.
- **`DA-XONG/RULE_PROJECT_DOC_DRIFT.md`** (2026-09-10) — tài liệu backend (`docs/Rule_Project/`, `docs/progress/Backend.md`) nói ngược mã và CSDL: tài liệu xin 56 chỗ sửa theo dòng cộng ba việc sửa mã. Backend báo đã sửa (`f8ab027`); client soát lại 2026-09-11: **45/56** chỗ vẫn chưa đúng — 31 chưa sửa, 12 sửa nhưng vẫn sai, 2 không còn áp dụng; chỉ 11 chỗ sửa đúng — cộng tám khẳng định mới sai của `7675b35` (`CAN-LAM/VERIFY_7675B35_REMAINING.md` §3). Ba việc mã: bộ lọc ghi chú xong (G29), body 401 xong ở HTTP nhưng hỏng ở socket và `/auth/refresh`, `'ORC'` còn sót. Không mở G: không mã client nào hỏng vì nó, nhưng đó là những tài liệu người mới đọc **trước** mã.
- **`CAN-LAM/VERIFY_7675B35_REMAINING.md`** (mục 18, 2026-09-11) — client soát từng tài liệu trong mười lăm tài liệu backend báo đã xong, với mã HEAD và CSDL dev: chín việc mã/CSDL còn lại, gồm giao dịch SePay vỡ `chk_transaction_type` (suy từ mã), `bank_transaction.incoming` nay phát **hai lần** và vẫn hai hình dạng, khoá mã hoá mặc định viết cứng, tệp `database/)2_can_lam_all_migrations.sql` còn `DELETE FROM "category"`, `budget."Threshold_Warning_Percent"` còn `DEFAULT 0`, cửa hậu `_mock*` mở ngoài `production`, và `WALLET_NAME_DUPLICATE` cần một phép thử khi chạy; cộng 45 chỗ tài liệu ở gạch trên. Không mở G: theo §4 của tài liệu ấy, client không bị chặn bởi việc nào trong đó ngoài hai hồi quy của mục 17. Phần phát sinh phía client — khoá màu danh mục — là **G24**, ✅ đã sửa 2026-09-11.
- G31 và G32 ở trên có tài liệu xin riêng: `DA-XONG/SYNC_PUSH_ERROR_MAPPING.md` và `DA-XONG/GOAL_PRIORITY_NULL_TO_ZERO.md` — ✅ backend đã làm cả hai, client đo 2026-09-11, **hai mục đã đóng**. G24 có `DA-XONG/CATEGORY_COLOUR_COLUMN.md` — phần backend xong, phần client ✅ sửa 2026-09-11. G34 có `DA-XONG/SOCKET_SYNC_COMPLETED.md` — phần backend xong, phần client ✅ 2026-09-12 tối (im lặng, kiểm máy ảo) — **đã đóng**.

Với tám tài liệu cũ, client **không** phụ thuộc vào việc backend có sửa hay không. Với các mục ghi *chặn ở backend* hoặc *chờ backend* ở bảng tóm tắt đầu tài liệu thì có — tính tới 2026-09-11 không mục G nào còn mở ghi như thế; gần nhất là **G34**, kiểm đầu-cuối được sau khi backend sửa hồi quy A (`cbbeeb4`) — ✅ đóng 2026-09-12 tối.

---

## 3. Lưu ý về kiểm thử

Trạng thái hiện tại (đã chạy thật, không phải đếm tay, đo 2026-09-12): `flutter test` toàn bộ **2105/2105 pass** (1 phút 7 giây), trên **200 file test / 45.599 dòng** (200 tệp `_test.dart`; số dòng đếm bằng script trên cả 201 tệp `.dart` dưới `test/`, kể cả `category_test_fakes.dart` — sau lượt sửa sau soát cuối cả nhánh spec §3.8: 27 test mới ở `core/api/`, 2 tệp / 30 test). Mốc 2104/2104 · 200 file · 45.557 dòng là của 2026-09-11 (đóng spec §3.8, trước lượt sửa sau soát cuối cả nhánh). Mốc 2078/2078 · 199 file · 45.147 dòng là của 2026-09-11 (sau G24, G35, G30, nhãn loại ví ở bảng chọn ví, **G33** và lượt sửa sau soát cuối cả nhánh G33, trước khi đóng §3.8). Mốc 2073/2073 · 199 file · 44.905 dòng là của G33 trước lượt sửa ấy. Mốc 2029/2029 · 192 file · 44.041 dòng là của 2026-09-11 (trước G33). Mốc 1529/1529 · 144 file · 33.892 dòng là của 2026-09-08. Trước phiên 2026-09-02 là 56 pass / 9 fail và mất hơn 10 phút (một test treo tới timeout); mốc 180 pass / 27 file ghi ở đây trước đó là con số **cuối phiên 2026-09-03** và đã lạc hậu năm ngày.

> ⚠️ **`.gitignore` có `test/`** (dòng 78, đo 2026-09-10 — từng ghi 77) — luật này khớp mọi thư mục tên `test` ở mọi cấp, và **đã tồn tại từ trước** phiên 2026-09-02 (kiểm chứng: `git diff .gitignore` chỉ thêm đúng một dòng `src/Backend/scripts/seed_roles.js`).
>
> Hệ quả đã đo được **tại thời điểm phát hiện** (2026-09-02): 16/23 file test đang được git theo dõi (commit trước khi luật có hiệu lực), 7/23 file thì không. Bảy file đó chứa 45 test:
>
> ```
> test/core/sync/sync_checkpoint_test.dart          (5 test)
> test/core/sync/sync_failure_handling_test.dart    (3 test)
> test/core/sync/sync_payload_contract_test.dart    (8 test)
> test/core/database/category_dao_test.dart         (9 test)
> test/features/auth/session_validation_test.dart   (9 test)
> test/features/category/category_create_test.dart  (8 test)
> test/features/wallet/default_account_data_initializer_test.dart (3 test)
> ```
>
> **✅ Đã xử lý (2026-09-02):** 7 file test bị chặn đã được đưa vào git bằng `git add -f`, cùng với `lib/core/sync/sync_checkpoint_store.dart`, và đã đi vào commit `ea0941b`. **Luật ignore lại cắn đúng như dự đoán:** hai file test tạo mới ngày 2026-09-03 (`test/core/api/auth_interceptor_test.dart`, `test/core/auth/current_account_test.dart`) cũng bị chặn âm thầm và phải `git add -f` lần nữa. Sau đó: **25/25 file test đều được git theo dõi**.
>
> **Nhưng luật ignore vẫn còn nguyên.** Mọi file test tạo MỚI từ nay vẫn sẽ bị chặn âm thầm. Cần quyết định: đây là quy ước có chủ đích (thì phải nhớ `git add -f` mỗi lần), hay luật đặt quá rộng (thì nên đổi `test/` thành đường dẫn cụ thể hơn, ví dụ `/Test/` cho thư mục script test cục bộ ở gốc repo).

### Vùng chưa có test nào

- ~~`lib/core/api/interceptors/auth_interceptor.dart`~~ — nay đã có `test/core/api/auth_interceptor_test.dart` (3 test, phiên 2026-09-03).
- ~~3 feature không có test~~ → ~~nay còn hai: profile, ai_chat~~ (đo lại 2026-09-08 bằng `find`/`flutter test`) → nay còn **một**: **ai_chat** (G33 thêm `test/features/profile/` — **2** tệp / **9** test, đếm bằng máy 2026-09-11). **analytics** có 4 tệp / **61** test từ 2026-09-08 (lát 2a **và 2b** — `docs/ANALYTICS_FEATURE.md`); **budget** 24 tệp; **home** 3 tệp (đếm bằng máy 2026-09-11); **notification** 20 tệp trong `test/core/notification/` + `test/features/notification/` (cộng 3 tệp liên quan nằm chỗ khác).

---

## 4. Nguyên tắc rút ra từ phiên 2026-09-02

Ghi lại vì chúng đã lặp đi lặp lại trong dự án này:

1. **Tên trường sai không gây lỗi — nó im lặng.** Payload đi qua ba nơi định nghĩa tên trường độc lập (client dựng tay → `SyncPayloadNormalizer` → `mapEntityFields` phía backend). Một tên sai chỉ đơn giản bị bỏ qua. `test/core/sync/sync_payload_contract_test.dart` khoá lại toàn bộ ánh xạ này — **cập nhật nó mỗi khi thêm trường mới cho sync**.

2. **`InsertMode.insertOrReplace` thay CẢ HÀNG.** Cột nào không gán trong companion sẽ bị đưa về giá trị mặc định. Đây từng xoá sạch cấu trúc nhóm danh mục sau mỗi lần pull. Toàn bộ 6 DAO nay dùng `insertAllOnConflictUpdate`. **Đừng đổi ngược lại.**

3. **Đừng bao giờ suy ra danh tính người dùng từ dữ liệu cục bộ.** `idaccount` chỉ được đến từ phiên đăng nhập.

4. **`idaccount = 1` là tài khoản admin THẬT**, không phải giá trị "chưa biết". Các fallback `?? 1` ở khâu đồng bộ (G8), bốn trang bill/goal (G4) và ba màn quản lý danh mục (G35, gỡ nốt 2026-09-11) đã bị gỡ; `test/core/auth/khong_du_phong_admin_test.dart` quét `lib/` bằng regex nhiều dòng để không còn chỗ nào lọt.
