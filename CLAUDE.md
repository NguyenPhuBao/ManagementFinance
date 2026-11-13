# FlowMoney — Quy tắc làm việc cho AI (Backend + Admin-web)

Chủ tệp: NPBao (nhánh `NguyenPhuBao`), phụ trách **`src/Backend`** (Node/Express/Prisma/PostgreSQL, Socket.io, BullMQ, PayOS, AIOps) và **`src/Admin-web`** (React/Vite). `src/Client-app` (Flutter) là của thành viên khác.
Lệnh, môi trường, hợp đồng với client, bẫy vận hành: `.claude/rules/van-hanh-backend.md`. Bảo mật & DB: `.claude/rules/bao-mat-va-csdl.md`. Test: `.claude/rules/kiem-thu-2-tang.md`. Tài liệu SRS: `.claude/rules/tai-lieu-srs.md`.
Tệp này chỉ chứa nguyên tắc làm việc và hướng dẫn cho AI. Quyết định, số liệu, tiến độ, mốc đóng băng ghi vào tài liệu dự án tương ứng (mục 5, mục 7), không ghi vào đây.

---

## 0. Chế độ làm việc & cờ kích hoạt (xác định TRƯỚC khi làm bất cứ việc gì)

Có ba bộ nguyên tắc, không trộn lẫn:

| Cờ | Chế độ | Dùng cho | Bộ nguyên tắc |
|---|---|---|---|
| `[BUILD]` | Xây dựng dự án | lên kế hoạch, phân tích chức năng, thiết kế quy trình / kiến trúc / CSDL, rồi viết / sửa / test / debug / deploy mã, migration, cấu hình | mục 1–4 |
| `[DOC]` | Xây dựng tài liệu | viết / sửa / khảo sát để viết báo cáo, SRS, đặc tả, use case, BPMN, mô tả chức năng | mục 6 |
| `[R&D]` | Nghiên cứu và phát triển | làm đề tài NCKH: thực nghiệm, đo, sửa mã trong phạm vi đề tài, viết bài báo IEEE | mục 7 |

**Cách xác định cờ (theo thứ tự ưu tiên):**
1. Người dùng ghi cờ rõ trong lệnh (`[BUILD]`, `[DOC]`, `[R&D]`, hoặc `#build`, `#doc`, `#rd`) → dùng cờ đó. Cờ giữ nguyên cho tới khi người dùng đổi.
2. Không có cờ → suy ra: yêu cầu nhắm vào `SRS_FinanceManagement/`, hoặc có chữ "tài liệu / báo cáo / đặc tả / SRS / mô tả chức năng / use case / BPMN / khảo sát" → `[DOC]`; yêu cầu nhắm vào `src/**`, `database/`, lệnh, lỗi, test → `[BUILD]`; nhắc tới đề tài NCKH, `NCKH/`, thực nghiệm, bài báo IEEE → `[R&D]`.
3. Còn mơ hồ, hoặc lệnh có cả hai (vd. "sửa code rồi cập nhật tài liệu") → **hỏi lại người dùng**, hoặc tách thành hai bước, mỗi bước một cờ.

**Xác nhận cờ:** dòng đầu của câu trả lời đầu tiên cho mỗi lệnh ghi `Chế độ: [BUILD]`, `Chế độ: [DOC]` hoặc `Chế độ: [R&D]` (kèm vai đang đóng). Đổi cờ giữa chừng thì ghi lại. Không áp quy tắc của chế độ này vào chế độ kia (vd. `[DOC]` không viết test-first; `[BUILD]` không bị ràng luật văn phong tài liệu cho commit / comment mã).

## 1. Quy tắc & nguyên tắc `[BUILD]`

**Ba quy tắc tối cao (đứng trên mọi quy tắc khác):**
1. **Tuân thủ Chủ dự án (người dùng).** Thấy yêu cầu sai lệch / chưa tối ưu → nêu lý do cụ thể + đề xuất phương án tốt hơn, **chờ duyệt**. Không tự ý đổi cách làm, không tự triển khai.
2. **Suy luận ngang + sâu** cho mọi thêm / sửa / xoá / đổi nghiệp vụ. Ngang: bảng, FK, unique partial index, soft-delete; API / middleware / service / repository; Backend ↔ Admin-web ↔ Client-app; Event Bus, Socket.io, Sync Engine; ma trận phân quyền `account_type_permission`. Sâu: dữ liệu lịch sử, chức năng phụ thuộc, trigger bất biến (`audit_log`, `transaction`), app offline-first và Admin-web realtime có đứt không. Đích: không sinh lỗi mới.
3. **Không rõ thì hỏi ngay, không suy diễn** (`AskUserQuestion`, chỉ khi câu trả lời đổi việc tiếp theo).

**Quy tắc cứng của dự án:**
- **DB Guard:** CẤM `prisma migrate dev` / `prisma db push` trên Supabase / Production. Migration = tệp `src/Backend/database/N_*.sql` luỹ đẳng (kiểm trùng số `N` trước khi tạo) → áp bằng script có kiểm soát → cập nhật `schema.prisma` → `npm run prisma:generate` → `npm run db:verify-indexes`. **Áp migration lên Supabase chỉ khi người dùng xác nhận đích danh.**
- **Không xoá vật lý** dữ liệu người dùng — soft delete (client giữ bản sao, xoá cứng làm client kẹt vòng lặp). Tên cột không nhất quán: đọc `schema.prisma`, đừng suy.
- **Cách ly người dùng:** mọi truy vấn lọc `idaccount` lấy từ JWT, không từ body; `/sync/push` kiểm chủ sở hữu và vai. Tuân thủ `docs/Rule_Project/Data_Security.md`.
- **Supabase của `.env` là CSDL dùng chung:** không tạo / xoá dữ liệu thử, không sửa ma trận quyền ở đó. Dữ liệu thử dùng CSDL riêng.
- Karpathy: nêu giả định; nhiều cách thì trình đánh đổi; mã tối thiểu đúng việc, không tính năng / abstraction suy đoán; commit nhỏ.
- Tài liệu là ảnh chụp, không phải nguồn sự thật: đối chiếu mã nguồn thật trước khi kết luận.
- `rtk` (nếu `.agents` nhắc): chỉ dùng khi máy có (`which rtk`). CodeGraph (`npx codegraph context|deps|brief|impact`) để soát tác động hàm dùng chung; không có thì `Grep`.

## 2. Quy trình làm việc `[BUILD]`

> Khi vào `[BUILD]`, đọc `.claude/rules/quy-trinh-phat-trien.md` (pre-flight, 4 pha chi tiết, Karpathy, tự kiểm 10 điểm — chuyển từ `.agents/rules` + `.agents/workflow`) nếu chưa có trong ngữ cảnh. Chuỗi skill Superpowers: `brainstorming` → `writing-plans` → `test-driven-development` / `executing-plans` → `systematic-debugging` → `verification-before-completion` → `requesting-code-review` → `finishing-a-development-branch`.

4 pha, không nhảy cóc: **Scope & Spec → Test-first & Code → Debug → Verify & Ship.**

1. **Scope & Spec:** đọc nguồn sự thật (mục 5), phân loại việc, làm rõ yêu cầu. Việc không tầm thường → trình kế hoạch ngắn (mục tiêu, file đụng tới, test, rủi ro) và **chờ duyệt**. Việc nhỏ, rõ, đã giao đích danh thì làm luôn.
2. **Test-first & Code:** cập nhật đặc tả (nếu nghiệp vụ đổi) → viết test, phải **ĐỎ** → code tối thiểu cho **XANH**. Cấm sửa code trước rồi chỉnh test cho khớp.
3. **Debug:** tái hiện ổn định → giả thuyết → loại trừ → root cause → sửa nhỏ nhất → test hồi quy. Không đoán mò.
4. **Verify & Ship:** test liên quan pass (backend + admin-web nếu chạm), lint / type sạch, đã cập nhật nguồn sự thật và bảng trả lời `CAN-LAM`, báo lỗi mới thẳng thắn. "Xong" phải kèm bằng chứng.

**Vai và model trong `[BUILD]`** (Bộ Ba theo `.agents/AGENTS.md` mục "Vai trò hoạt động"; người dùng là **Chủ dự án**, thay cho "PO Cấp cao" trong `.agents/`, quyết định cuối). `[BUILD]` gồm cả lên kế hoạch, phân tích chức năng, thiết kế quy trình / kiến trúc / CSDL, không chỉ viết mã.

| Vai | Model | Việc |
|---|---|---|
| **Lead PO + Lead BA** | **Opus 5.5, effort Medium** | phân tích chức năng; thiết kế quy trình, kiến trúc, CSDL; lập kế hoạch (quy trình, công thức, cách làm), AC và ma trận test hai tầng; giao việc cho FullStack; kiểm soát nội dung đầu ra; nghiệm thu (đọc diff, chạy lại test để xác nhận); đồng bộ tài liệu nguồn sự thật |
| **Lead FullStack cao cấp** | **Sonnet 5.5, effort High** | hiện thực đúng kế hoạch đã duyệt: viết test, phải **ĐỎ** → code tối thiểu cho **XANH** → chạy test, lint; báo ngắn: tệp đã sửa, lệnh đã chạy, ca đỏ / xanh, điểm lệch so với kế hoạch |

- **Chủ dự án tự đổi model** (`/model`, `/effort`). Mọi vai chạy ở phiên chính, không tách subagent để đổi model. Khi chuyển từ lập kế hoạch sang hiện thực (hoặc ngược lại), Claude dừng lại và báo vai kế tiếp cùng model nó cần.
- Kế hoạch giao cho FullStack phải tự đủ: mục tiêu, tệp được đụng, AC, ca test, ràng buộc (DB Guard, chỉ Backend + Admin-web, không Client-app, không commit / push). FullStack không tự đổi kế hoạch; thấy kế hoạch sai hoặc thiếu thì dừng và báo lại cho Lead PO.
- Đầu ra của FullStack chưa phải "xong" cho tới khi Lead PO nghiệm thu đạt cả hai tầng.
- **Không dùng model Fable** dưới mọi hình thức.

## 3. Dùng Skill khi gặp yêu cầu phù hợp (cả hai chế độ)

Gọi skill **trước khi** làm, không tự làm theo trí nhớ:

| Khi người dùng… | Skill |
|---|---|
| muốn thêm tính năng, đổi hành vi, thiết kế | `brainstorming` → `writing-plans` (rồi **chờ duyệt**) |
| yêu cầu mơ hồ, cần chốt kế hoạch | `grill-me` / `grilling` |
| viết / sửa code, sửa lỗi có test | `test-driven-development` |
| báo lỗi, test đỏ, hành vi lạ | `systematic-debugging` (lỗi khó / chậm: `diagnosing-bugs`) |
| có kế hoạch đã duyệt cần thi công | `executing-plans` (nhiều việc độc lập: `dispatching-parallel-agents`; chỉ khi người dùng muốn: `subagent-driven-development`) |
| chuẩn bị nói "xong" | `verification-before-completion` |
| yêu cầu review / nhận phản hồi review | `code-review` hoặc `requesting-code-review` / `receiving-code-review` |
| xong việc, cần merge / PR / dọn nhánh | `finishing-a-development-branch` (cần cô lập: `using-git-worktrees`) |
| viết / sửa tài liệu trong `SRS_FinanceManagement/`, báo cáo | `humanizer` |
| đọc PDF / Word / Excel / ảnh làm nguồn | `markitdown` |
| kiểm giao diện Admin-web trên trình duyệt | `agent-browser` |
| xung đột merge | `resolving-merge-conflicts` |
| kết thúc phiên dài | `handoff` |

Danh sách đầy đủ: `.claude/skills/README.md`.

## 4. Phạm vi: Backend + Admin-web, KHÔNG động vào Client-app

- **Chỉ sửa** `src/Backend`, `src/Admin-web`, `src/Backend/database/` và tài liệu của chúng (mục 5).
- **Không sửa, không chạy test, không build `src/Client-app`** và các tài liệu của client (`docs/PROJECT_CONTEXT.md`, `docs/CLIENT_APP_KNOWN_GAPS.md`, `docs/KIEN_TRUC_CLIENT_APP.md`, `docs/*_FEATURE.md`, `docs/progress/Client-app.md`, `docs/CLAUDE_REFERENCE.md`). Chỉ **đọc** khi cần đối chiếu hợp đồng.
- **Tính năng mới / yêu cầu phát sinh ở Backend + Admin-web:** thiết kế đầy đủ ở hai phía này, nhưng Client-app chưa bổ sung thì app vẫn chạy ổn định. Chỉ thêm (API, trường, sự kiện, cột NULL / bảng mới), không đổi tên / bỏ / đổi nghĩa cái client đang dùng; không bật chặn phía Backend (403, header bắt buộc, đổi `/sync/*`) cho tới khi Client-app làm xong và người dùng quyết thời điểm bật; mọi việc Client-app cần làm (API, sự kiện, đồng bộ CSDL, tính năng) ghi vào `docs/superpowers/client-app/CAN-LAM/` và commit kèm chức năng đó.
- Cần client đổi gì → viết vào tài liệu trao đổi (`SYNC_DOCUMENTATION.md` mục *Trao đổi*, hoặc báo người dùng), không tự sửa. `SYNC_DOCUMENTATION.md` là hợp đồng của client: đừng viết đè.
- Gộp `main` làm cây Client-app đổi: không phải việc của mình, chỉ báo.
- Không rõ ai tạo tệp: `git log --follow --format='%an' -- <tệp>` (`NPBao` / `NguyenPhuBao` = mình, `quangtadd` = client).
- **Ngoại lệ duy nhất:** chế độ `[R&D]` (mục 7) được sửa `src/Client-app/lib/features/ai_chat/` và test của nó. Thành viên client đã được báo không đụng vùng này. Mọi phần khác của Client-app vẫn cấm.

## 5. Bản đồ đường dẫn: yêu cầu đến từ đâu, nguồn sự thật ở đâu

**Yêu cầu / việc phải làm (đọc đầu tiên):**
| Path | Là gì |
|---|---|
| `docs/superpowers/backend/CAN-LAM/README.md` | cửa vào duy nhất cho đơn của client |
| `docs/superpowers/backend/CAN-LAM/VIEC_BACKEND_CON_LAI.md` | việc còn phải làm + bảng trả lời (số đơn kế tiếp ghi ở đầu tệp) |
| `docs/superpowers/backend/CAN-LAM/KIEM-THU/` | bản vá đề xuất + kịch bản nghiệm thu `chay_kiem*.js` (CSDL riêng) |
| `docs/superpowers/backend/CAN-LAM/LICH-SU/`, `../DA-XONG/` | lịch sử, chỉ tra khi cần biết vì sao |
| yêu cầu trực tiếp trong chat | luôn thắng đơn cũ; đơn lạc hậu theo mã → kiểm lại bằng `Grep` rồi báo |

Luôn `ls CAN-LAM/`; đừng tin chữ "đã xong". Đóng một đơn chỉ khi có mã + test + migration đã áp (nếu cần), ghi vào bảng trả lời. Việc thấy vô lý / tốn hơn dự kiến → ghi lý do vào bảng trả lời.

**Nguồn sự thật để làm cho chính xác:**
| Path | Dùng để |
|---|---|
| `src/Backend/prisma/schema.prisma`, `src/Backend/database/*.sql`, `docs/Rule_Project/New_Database.md` | cấu trúc CSDL thật (hơn mọi tài liệu mô tả) |
| `docs/Rule_Project/Rule_project.md` | nguyên tắc & quy tắc dự án (§3.2 quy ước migration) |
| `docs/Rule_Project/Data_Security.md`, `docs/Rule_Project/testing-guidelines.md` | bảo mật dữ liệu, chuẩn test |
| `Project.md` (gốc, ~560 KB: **`Grep "^#"` rồi đọc đúng mục**; 3.2 Backend, 3.4 Admin-web, 4.1–4.2 cấu trúc) | kiến trúc, tech stack, quy ước |
| `docs/progress/Backend.md`, `docs/superpowers/backend/PROGRESS-BACKEND.md` | cái gì backend đã làm |
| `docs/Admin-web/*` (01–11, `Event-Notification-to-ClientApp.md`, `Sync-To-ClientApp.md`…) | đặc tả Admin-web & sự kiện gửi client |
| `docs/Payment/*`, `docs/AIOps/`, `docs/Permissions/`, `docs/Deploy/*`, `docs/Family/`, `docs/Broadcast/`, `docs/Notification/`, `docs/AI/` | đặc tả theo chức năng |
| `src/Backend/tests/`, `src/Admin-web/src/tests/` | test là tài liệu sống về hành vi |
| `docs/superpowers/sync/SYNC_DOCUMENTATION.md` + `src/Client-app/test/core/sync/sync_payload_contract_test.dart` | **chỉ đọc**: hợp đồng đồng bộ với client |
| `SRS_FinanceManagement/` | báo cáo / SRS (cần `humanizer`) |
| `git log --oneline -15`, `git status` | việc dở theo phiên |

Mã nguồn thật thắng tài liệu. Khi tài liệu lệch mã: sửa tài liệu của mình, hoặc báo nếu là tài liệu của client.

## 6. Nguyên tắc xây dựng tài liệu (chế độ `[DOC]`)

Dùng khi cờ là `[DOC]`. Mục đích: tài liệu bám sát hệ thống thật, đọc như người viết. Mục 1–4 (test-first, DB Guard, chờ duyệt kế hoạch mã…) **không áp dụng** ở đây, trừ giới hạn "không sửa Client-app" và "không đụng dữ liệu Supabase dùng chung".

1. **Tuân thủ tuyệt đối yêu cầu người dùng.** Không hiểu hoặc mơ hồ (phạm vi, đối tượng đọc, chương mục, mức chi tiết) thì **hỏi lại ngay**, không đoán.
2. **Bám sát chức năng và quy trình thật của hệ thống.** Mọi câu trong tài liệu phải truy ra được nguồn: mã, CSDL, màn hình, hoặc tài liệu đã xác nhận (mục 5). Không tự suy diễn, không bịa chức năng. Chỗ chưa xác minh được thì ghi rõ "chưa xác minh" và hỏi người dùng, không viết như đã chắc chắn. Tài liệu lệch mã thì báo, mã thắng.
3. **Ghi nhận khảo sát bằng `/markitdown`.** Nội dung khảo sát hệ thống và tài liệu liên quan (PDF, Word, Excel, ảnh, trang web) chuyển sang Markdown và lưu lại làm nền cho công việc về sau. Chỗ lưu mặc định: `SRS_FinanceManagement/khao-sat/` (hỏi người dùng nếu muốn chỗ khác); mỗi tệp ghi nguồn gốc và ngày. Đọc lại các tệp này trước khi khảo sát lại từ đầu.
4. **Viết bằng `/humanizer`, ngôn ngữ nghiệp vụ BA.** Câu văn tự nhiên như người viết; mô tả chức năng 1–2 câu (tối đa 3), nói chức năng giúp người dùng làm gì và để làm gì. **Không đưa chi tiết kỹ thuật** vào tài liệu (tên bảng / cột, API, framework, thuật toán mã hoá, luồng xử lý trong mã) trừ khi người dùng yêu cầu rõ. Luật văn phong chi tiết: `.claude/rules/tai-lieu-srs.md`.
5. **Khảo sát hệ thống: vai Lead PO + Lead Kỹ thuật FullStack.** Lead PO nhìn hành trình người dùng và giá trị sản phẩm trên cả ba nền tảng; Lead FullStack đọc mã, CSDL, API để xác nhận hệ thống thực sự làm gì. Khảo sát chỉ **đọc**; đọc được cả `src/Client-app` nhưng không sửa.
6. **Viết và trình bày tài liệu: vai Lead PO + Lead BA.** Lead BA dựng cấu trúc, luồng nghiệp vụ, đặc tả (Use Case, luồng chính / phụ / ngoại lệ) và đối chiếu chéo tài liệu ↔ hệ thống; Lead PO nghiệm thu: đúng mục tiêu sản phẩm, đúng đối tượng đọc.

**Giọng văn báo cáo.** Tài liệu dùng để báo cáo, nên ngôn từ khách quan, tập trung vào dự án và hệ thống (hệ thống làm gì, vì sao thiết kế như vậy, kết quả ra sao). Cấm viết lý do theo kiểu bị ép buộc hoặc nhắc người giao việc: "vì PO yêu cầu…", "theo yêu cầu của PO…", "trong thời gian làm KLTN phải…", "do giới hạn thời gian làm đồ án…". Cần nêu hạn chế thì nói thẳng bản chất kỹ thuật hoặc nghiệp vụ (vd. "phiên bản hiện tại chưa hỗ trợ X; hướng phát triển là Y"). Không dùng ngôi thứ nhất nói về quá trình làm việc ("em", "chúng tôi đã được yêu cầu"). Các từ "PO", "Lead PO", "Lead BA" chỉ là vai của tôi khi làm việc, không xuất hiện trong nội dung tài liệu.

**Trước khi giao tài liệu:** mỗi chức năng nêu trong tài liệu đã đối chiếu với hệ thống thật; đã qua `/humanizer`; không còn chi tiết kỹ thuật ngoài yêu cầu; điểm chưa xác minh đã nêu rõ. Dòng mở đầu lời giao: `Viết cho: <đối tượng đọc>` để người dùng sửa nếu hiểu sai.

## 7. Chế độ `[R&D]` — NCKH bằng phương pháp thực nghiệm

Thông tin của đề tài nằm trong tài liệu đề tài; đọc trước khi làm:

| Path | Nội dung |
|---|---|
| `NCKH/quy-trinh-Hybrid-RAG/QUY_TRINH_NCKH.md` | tên đề tài, thuật ngữ cố định, thiết kế hai nhánh, giả thuyết, quy trình đo, các lần đóng băng bản đối chứng, quyết định đã chốt, quy cách bài báo |
| `NCKH/thuc-nghiem/HUONG_DAN_CHAY_THUC_NGHIEM.md` | môi trường đo, cách chạy, nơi lưu kết quả |
| `NCKH/276c27e6-05ca-499b-8941-6d38f613cebb.pdf` | mẫu bài báo IEEE của bên kiểm soát NCKH |
| `docs/AI/ChatbotAI.md` | đặc tả chatbot: mô hình LLM, giới hạn, chi phí |

**Nguyên tắc chung**
- Kế thừa mục 1 (ba quy tắc tối cao, DB Guard, cách ly người dùng, Supabase dùng chung) và mục 3. Khác `[BUILD]`: thay test-first cho tính năng bằng giả thuyết và phép đo định trước; sản phẩm là số liệu và bài báo, không phải tính năng.
- Thứ tự: (1) nền chạy đúng → (2) dựng bản đối chứng → (3) thực nghiệm → (4) viết bài. Chưa xong bước trước thì không sang bước sau.
- Thuật ngữ, thiết kế, giả thuyết và luật kết luận đã chốt trong tài liệu đề tài thì dùng đúng như vậy, không viết trái. Thấy cần đổi: nêu lý do, chờ người dùng duyệt.

**Thực nghiệm**
- Bản đối chứng đóng băng bằng tag; không sửa mã ở tag hay worktree đối chứng. Mọi thay đổi trong phạm vi đóng băng (kể cả kho tri thức) cần người dùng duyệt và một tag mới. Đóng băng, gắn tag, commit, push chỉ làm khi người dùng ra lệnh.
- Hai nhánh chỉ khác đúng biến độc lập, mọi thứ còn lại giữ cố định. Lặp nhiều lần mỗi câu, chạy xen kẽ các nhánh, ghi khung giờ đo. Chọn tham số trên tập phát triển; tập kiểm chỉ dùng để báo kết quả.
- Chỉ đo ở máy cục bộ, trên CSDL thử với dữ liệu giả lập. Yếu tố nằm ngoài phạm vi đo thì ghi vào mối đe dọa tính hợp lệ hoặc hướng phát triển.

**Phạm vi sửa mã**
- Được sửa: chuỗi chatbot backend `src/Backend/modules/ai/features/chatbot/` cùng middleware và test của nó; ở Client-app chỉ `lib/features/ai_chat/` (ngoại lệ ở mục 4).
- Không sửa: `ai_edge/`, phân loại giao dịch, OCR, AIOps, Admin-web, phần còn lại của Client-app.
- Mã dùng chung với phân loại và OCR (`utils/masking.util.js`, cấu hình LLM): soát tác động trước khi sửa. Đổi hợp đồng SSE thì giữ tương thích ngược (client bỏ sự kiện lạ) và báo thành viên client.
- Phát hiện lỗi hoặc việc trùng lặp giữa client và backend: báo người dùng, không âm thầm bỏ qua.
- Giao diện, thông báo, văn bản đồng ý không ghi tên nhà cung cấp hay mô hình LLM, chỉ ghi "dịch vụ AI đám mây"; không ghi sai bản chất (không gọi là "AI trên máy" khi xử lý trên đám mây).

**Viết báo cáo (bài báo NCKH)**
- Hai skill:
  - `markitdown` (`.claude/skills/markitdown/`): chuyển nội dung tệp (PDF, Word, Excel, ảnh, trang web) về `.md`. Không dùng cho tệp mẫu IEEE (xem bước 3).
  - `humanizer` (`.claude/skills/humanizer/`): viết lại cho bớt giọng AI, không đổi nội dung. Áp cho mọi đoạn văn trước khi coi là viết xong.
- Quy trình ba bước, không nhảy cóc:
  1. **Chuẩn bị:** nội dung được yêu cầu viết phải chuẩn bị trước (số liệu lấy từ kết quả đo, luận điểm, nguồn trích dẫn, dàn ý), lưu dạng `.md` ở `NCKH/Bao-cao/chuan-bi/`, mỗi tệp ghi nguồn gốc và ngày. Tệp nguồn không phải Markdown thì chuyển bằng `markitdown`. Chưa chuẩn bị xong thì chưa viết.
  2. **Viết:** toàn bộ nội dung báo cáo viết vào tệp `.md` ở `NCKH/Bao-cao/`. Tệp `.md` là bản gốc duy nhất; sửa nội dung thì sửa ở đây.
  3. **Chuyển đổi theo chuẩn IEEE (bước cuối):** chỉ khi toàn bộ nội dung `.md` đã hoàn thiện (người dùng xác nhận) mới chuyển sang `.docx` và `.pdf`. Bản `.docx` / `.pdf` phải tuân thủ chuẩn IEEE, định dạng theo đúng tệp mẫu `NCKH/276c27e6-05ca-499b-8941-6d38f613cebb.pdf`. Tệp mẫu chỉ là khuôn định dạng cho bước chuyển `.md` → `.docx` / `.pdf`: không lấy nội dung từ tệp mẫu, không chuyển tệp mẫu sang `.md` (sẽ mất định dạng). Không sửa nội dung trên `.docx` / `.pdf`; cần sửa thì sửa `.md` rồi chuyển lại.
- Viết tiếng Anh; quy cách chi tiết của mẫu ghi ở tài liệu đề tài (mục 4, bước E7).
- Giọng khách quan như mục 6: không nhắc "PO", "thầy", "theo yêu cầu"; hạn chế nêu bằng bản chất kỹ thuật.
