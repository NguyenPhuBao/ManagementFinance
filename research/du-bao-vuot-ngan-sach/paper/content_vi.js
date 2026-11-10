// Bản tiếng Việt của bài, cùng nội dung với content_en.js. Markup: $...$ toán, [@khoá] trích dẫn, *x* nghiêng, **x** đậm.
// Viết lại 2026-11-10 theo góp ý của thầy: một bộ dữ liệu (IBM TabFormer chuyển sang chuẩn Việt Nam), kiểm thử trên app
// FlowMoney thật, chấm Likert 5 mức bởi hai người, ít công thức. Số liệu lấy từ ../experiment/results/{tabformer_vn,
// tabformer_vn_profile,bootstrap_vn,m1_compare_tabformer_vn}.json và ../app_test/README.md. Phần Likert chờ điểm ([đang chấm]).
'use strict';

exports.title = 'Dự báo xác suất vượt ngân sách bằng trung vị, làm trơn hàm mũ và hồi quy phân vị';
exports.authors = 'Trần Quang Đạt, Nguyễn Phú Bảo và Huỳnh Nam';
exports.affiliation = 'Khoa Công nghệ Thông tin, Trường Đại học Công nghiệp Thành phố Hồ Chí Minh';
exports.emails = '[e-mail sẽ bổ sung]';
exports.header = 'STUDENT SCIENTIFIC RESEARCH COMMUNICATION, VOLUME II, 2026';

exports.build = ({ add, body, H1, H2, EQ, bullet, FIG, TABLE, LABELED, REFLIST, r }) => {
  add(LABELED('Tóm tắt', r`Cảnh báo ngân sách trong ứng dụng tài chính cá nhân chỉ có ích khi đến sớm và hiếm khi sai. FlowMoney, ứng dụng ưu tiên ngoại tuyến do nhóm xây dựng trong khoá luận tốt nghiệp, đã dự phóng chi tiêu cuối tháng bằng trung vị của các tháng trước. Bài này hỏi liệu một xác suất vượt ngân sách có cho cảnh báo tốt hơn không, và so sánh ba cách dự báo: quy tắc trung vị của ứng dụng, trung bình trượt hàm mũ (EWMA) của chi tiêu theo ngày, và hồi quy phân vị huấn luyện chung trên mọi người dùng. Dữ liệu là giao dịch thẻ mô phỏng của IBM, được chuyển sang chuẩn Việt Nam: 109 mã ngành hàng được gán vào tám danh mục chi của FlowMoney và số tiền được co giãn theo bốn bậc thu nhập; bảng chuyển đổi do Claude đề xuất, nhóm tác giả kiểm lại bằng phiếu Likert 5 mức. Vì ngân sách của mỗi người đặt theo chính chi tiêu cũ của họ, việc chuyển đổi không làm đổi dự báo nào (chênh lệch lớn nhất 0,001). Trên 310.978 dự báo của 1.513 người dùng, hồi quy phân vị và EWMA tốt hơn quy tắc trung vị (điểm Brier 0,148 và 0,149 so với 0,166). Chấp nhận một lần báo nhầm trong mười tháng, hồi quy phân vị bắt được 77% số lần vượt, trung vị 12 ngày trước khi vượt, so với 68% và 9 ngày của quy tắc trung vị. Nhóm còn nạp năm người dùng đã chuyển đổi vào ứng dụng thật qua chính API đồng bộ của nó; cả năm trường hợp, con số nhịp chi trên trang Ngân sách khớp từng đồng với kết quả chạy lại chính mã nguồn ấy trên máy tính.`));
  add(LABELED('Từ khoá', 'Vượt ngân sách, cảnh báo sớm, làm trơn hàm mũ, ứng dụng tài chính cá nhân, hồi quy phân vị, dữ liệu mô phỏng.', 160));

  // I
  add(H1('Giới thiệu'));
  add(body(r`Nhiều người quản lý tiền theo các tài khoản tâm lý hằng tháng, chẳng hạn khoản để dành cho ăn uống tháng này [@thaler], và màn hình ngân sách của ứng dụng tài chính cá nhân dựa trên đúng ý ấy. Một lời nhắc đến đúng lúc có thể thay đổi hành vi tài chính [@karlan], nên cảnh báo ngân sách hiện ra lúc nào cũng quan trọng như việc nó có hiện ra hay không.`, { dropCap: true }));
  add(body(r`FlowMoney là ứng dụng tài chính cá nhân nhóm xây dựng trong khoá luận tốt nghiệp (KLTN). Ứng dụng ưu tiên ngoại tuyến: giao dịch ghi vào SQLite trên điện thoại rồi đồng bộ nền với máy chủ Node.js. Ở trang Ngân sách, ứng dụng so số đã chi với *nhịp chi* học từ ba đến sáu tháng gần nhất đã đóng: ứng với phần tháng đã trôi qua, nó lấy trung vị phần ngân sách thường đã chi tới lúc đó và gắn nhãn nhịp hiện tại là chậm, đúng nhịp hoặc nhanh. Ứng dụng cũng dự phóng chi tiêu cuối tháng bằng số đã chi cộng trung vị số tiền thường chi trong phần còn lại của tháng. Quy tắc này rẻ và một tháng bất thường hầu như không làm nó lệch, nhưng nó không cho xác suất, nên ứng dụng không nói được khả năng vượt là bao nhiêu và không chọn được nên cảnh báo sớm đến đâu.`));
  add(body(r`Bài này biến câu hỏi "tháng này có vượt ngân sách không?" thành một xác suất và so sánh ba cách ước lượng nó trên dữ liệu nạp được vào ứng dụng. Đóng góp gồm: (i) đánh giá quy tắc trung vị của ứng dụng so với EWMA và hồi quy phân vị trên 1.513 người dùng mô phỏng, cả về chất lượng xác suất lẫn cảnh báo sớm; (ii) thiết kế dữ liệu tường minh, chuyển giao dịch thẻ mô phỏng của IBM sang danh mục của FlowMoney và mức chi tiêu Việt Nam, khai rõ nguồn gốc từng thành phần dữ liệu, và cho nhóm tác giả chấm Likert các phần do AI đề xuất; (iii) kiểm thử trên hệ thống thật: nạp người dùng đã chuyển đổi vào FlowMoney qua chính API đồng bộ của nó rồi đối chiếu con số trên trang Ngân sách với kết quả chạy lại mã nguồn của ứng dụng trên máy tính. Mục II điểm qua nghiên cứu liên quan, mục III trình bày phương pháp và dữ liệu, mục IV báo cáo kết quả, mục V thảo luận và mục VI kết luận.`));

  // II
  add(H1('Nghiên cứu liên quan'));
  add(body(r`*Làm trơn hàm mũ.* EWMA cập nhật một mức trung bình chạy sau mỗi quan sát mới, ban đầu dùng để giám sát quy trình [@roberts]; RiskMetrics áp cùng phép cập nhật cho phương sai lợi suất tài chính, nên một hằng số theo dõi được cả mức lẫn độ dao động [@riskmetrics]. Phép tính rẻ và thích nghi nhanh, hợp với điện thoại.`));
  add(body(r`*Hồi quy phân vị và dự báo xác suất.* Hồi quy phân vị ước lượng một phân vị chọn trước của biến mục tiêu thay cho giá trị trung bình [@koenkerB]; Taylor dùng nó cùng trọng số hàm mũ để dự báo phân phối doanh số siêu thị theo ngày [@taylor], một bài toán gần với bài này. Các phân vị khớp riêng rẽ có thể cắt nhau, và sắp xếp lại sẽ khử chỗ cắt [@chernozhukov]. Một dự báo xác suất được chấm bằng hàm điểm đúng đắn như điểm Brier [@brier] và bằng độ hiệu chuẩn, tức các sự kiện được dự báo 30% có xảy ra khoảng 30% số lần không [@gneitingC], [@naeini]. Dự báo phải được đánh giá theo thứ tự thời gian, trên dữ liệu không dùng để khớp mô hình [@tashman].`));
  add(body(r`*Dữ liệu tài chính mô phỏng.* Dữ liệu giao dịch thật khó chia sẻ, nên IBM công bố một bộ giao dịch thẻ tín dụng mô phỏng cùng các mô hình TabFormer [@padhi], do một bộ sinh giao dịch dựa trên tác tử tạo ra [@altman]. Theo hiểu biết của nhóm, chưa có công trình nào chuyển dữ liệu như vậy sang chuẩn Việt Nam hay kiểm một bộ dự báo bên trong một ứng dụng tài chính cá nhân đang chạy, nên bài này báo cáo việc chuyển đổi và phép kiểm trong ứng dụng cùng với kết quả dự báo.`));

  // III
  add(H1('Phương pháp nghiên cứu'));
  add(H2('Câu hỏi nghiên cứu'));
  add(body(r`Bài trả lời bốn câu hỏi. RQ1: cách dự báo nào cho xác suất vượt ngân sách chính xác và hiệu chuẩn tốt nhất? RQ2: chấp nhận nhiều nhất một lần báo nhầm trong mười tháng, mỗi cách bắt được bao nhiêu lần vượt và sớm bao nhiêu ngày? RQ3: quy tắc được đánh giá có cho cùng con số với ứng dụng thật khi nạp cùng dữ liệu vào ứng dụng không? RQ4: người chấm có thấy phần chuyển đổi dữ liệu do AI đề xuất và các cảnh báo sinh ra là hợp lý không?`));
  add(H2('Hệ thống nghiên cứu và các cách dự báo'));
  add(body(r`Hình 1 cho thấy luồng xử lý. Ở ngày $t$ của một tháng có ngân sách $B$, gọi $S_{t}$ là số đã chi tới nay và $S_{T}$ là tổng cuối tháng. Mỗi cách dự báo trả về`));
  add(EQ(r`p_{t}=P(S_{T}>B\mid\text{dữ liệu tới ngày }t),`));
  add(body(r`tức xác suất tháng kết thúc vượt ngân sách. Cảnh báo hiện ra lần đầu $p_{t}$ chạm ngưỡng $p^{*}$.`, { noIndent: true }));
  add(FIG('fig1_pipeline.png', 300, 265, r`Luồng dự báo. Ba cách dự báo đọc cùng chuỗi chi tiêu theo ngày từ cơ sở dữ liệu của FlowMoney; M1 là quy tắc ứng dụng đang chạy.`));
  add(body(r`*M1, trung vị nhịp chi (quy tắc của ứng dụng).* Với mỗi tháng trong $K$ tháng đã đóng gần nhất có chi tiêu ($3\le K\le6$), gọi $r_{k}$ là số tiền chi trong tháng $k$ sau cùng phần tháng đã trôi như hiện tại. Ứng dụng dự phóng $S_{t}$ cộng trung vị của các $r_{k}$. Bài thêm một xác suất bằng cách đếm bao nhiêu tháng cũ sẽ dẫn đến vượt:`));
  add(EQ(r`p_{t}=\frac{\#\{k:S_{t}+r_{k}>B\}+1/2}{K+1}.`));
  add(body(r`Với $K\le6$, xác suất này có nhiều nhất bảy giá trị. Dưới ba tháng, ứng dụng giả định chi đều, và bài cũng vậy.`, { noIndent: true }));
  add(body(r`*M2, EWMA.* M2 giữ hai con số chạy cho mỗi người: chi trung bình một ngày và phương sai của nó. Mỗi ngày cả hai dịch một phần $\lambda$ về phía giá trị của ngày mới [@riskmetrics]. Phần còn lại của tháng được dự báo bằng số ngày còn lại nhân mức trung bình, với độ phân tán theo phân phối chuẩn, và $p_{t}$ là khả năng phần ấy đẩy chi tiêu vượt $B$. Hằng số $\lambda$ được chọn một lần trên 20% số tháng đầu.`));
  add(body(r`*M3, hồi quy phân vị.* M3 là một mô hình huấn luyện chung cho mọi người dùng. Nó đọc bảy tỉ số của tháng hiện tại (phần tháng đã trôi, phần ngân sách đã chi, dự báo của M1 và M2, độ phân tán của M2, phần chi tiêu cũ rơi vào cuối tháng, và mức dao động của tổng chi các tháng) rồi dự báo 19 phân vị của phần còn chi, từ phân vị thứ 5 đến thứ 95 [@koenkerB]. Các phân vị được sắp xếp [@chernozhukov] và nối thành một phân phối, từ đó đọc ra $p_{t}$. Trên điện thoại việc này là 19 tích vô hướng ngắn, nên có thể đóng gói sẵn các hệ số đã huấn luyện vào ứng dụng.`));
  add(H2('Thiết kế dữ liệu thực nghiệm'));
  add(body(r`Mọi thành phần dữ liệu được ghi nguồn gốc ở Bảng I. Không có dữ liệu nào thu từ người dùng FlowMoney thật.`));
  add(TABLE('Nguồn gốc dữ liệu thực nghiệm', [1150, 950, 2940],
    ['Thành phần dữ liệu', 'Nguồn gốc', 'Cách sinh và kiểm tra'],
    [
      ['Giao dịch thẻ: người dùng, ngày, giờ, số tiền, mã ngành hàng, cờ gian lận', 'Mô phỏng (bộ sinh của IBM)', 'Bản TabFormer [@padhi], bộ sinh của [@altman], giấy phép Apache-2.0; nhóm không đổi thiết lập; đã ghi SHA-256 của tệp nén'],
      ['Các dòng chi tiêu', 'Theo luật', 'Số tiền dương, không gian lận, 01/2015 đến 01/2020; gộp các thẻ của một người; giữ 1.518 người'],
      ['Mã ngành hàng sang danh mục FlowMoney (109 mã, 8 danh mục)', 'AI đề xuất', 'Claude đề xuất [@claude]; hai tác giả chấm (mục IV-C); khoá sau khi chấm'],
      ['Bậc thu nhập và mức VND của mỗi người', 'Luật do AI đề xuất, mã áp dụng', 'Bốn bậc do Claude đề xuất; áp theo thứ hạng trung vị chi tiêu tháng của người dùng; làm tròn số tiền tới 1.000 đồng'],
      ['Ngân sách', 'Theo luật', r`$B=\kappa\times$ trung bình tổng chi ba tháng trước, $\kappa\in\{0,9;1,0;1,1\}$`],
      ['Năm người dùng nạp vào ứng dụng', 'Mô phỏng, mã chọn', 'Chọn theo seed trong số người đã chuyển đổi; thêm một khoản lương giả mỗi tháng để ví không âm'],
      ['Điểm Likert', 'Con người', 'Hai tác giả, chấm độc lập; ở phiếu B không biết tên phương pháp và kết quả'],
    ], r`Các bảng chuyển đổi lưu trong dự án dưới dạng mã có cờ trạng thái (DRAFT tới khi chấm xong, rồi LOCKED).`, 'LLL'));
  add(body(r`*Dữ liệu nguồn.* Bộ giao dịch thẻ mô phỏng của IBM có 24.386.900 giao dịch của 2.000 người từ năm 1991 đến tháng 2/2020, mỗi giao dịch có ngày, giờ, số tiền bằng đô la Mỹ, mã ngành hàng (MCC) [@iso] và cờ gian lận [@padhi], [@altman]. Nhóm giữ giai đoạn 01/2015 đến 01/2020, coi là chi tiêu mọi số tiền dương không bị đánh dấu gian lận, và bỏ người dùng có dưới 18 tháng hoặc ngừng chi sớm, còn lại 1.518 người (1.513 người có dự báo được chấm). Một tháng trung vị của một người có 78 giao dịch trong 29 ngày.`));
  add(body(r`*Chuyển sang chuẩn Việt Nam.* Việc chuyển đổi có hai phần, cả hai do Claude (Claude Code, mô hình claude-opus-5-5) đề xuất theo yêu cầu của nhóm rồi nhóm kiểm lại. Thứ nhất, mỗi mã trong 109 MCC của dữ liệu được gán vào một trong tám danh mục chi đang dùng của FlowMoney (Ăn uống, Di chuyển, Nhà cửa, Hóa đơn, Mua sắm, Giải trí, Giáo dục, Y tế), kèm lý do; ví dụ chuyển tiền được gán vào Nhà cửa vì tiền nhà ở Việt Nam thường trả bằng chuyển khoản. Sau chuyển đổi, Di chuyển chiếm 24,6% chi tiêu, Ăn uống 19,2%, Giáo dục 0,8%. Thứ hai, người dùng được xếp hạng theo trung vị chi tiêu tháng và chia bốn bậc với mức chi tháng đích: sinh viên (25%, 3 đến 6 triệu đồng), mới đi làm (35%, 6 đến 12 triệu), đi làm ổn định (30%, 12 đến 20 triệu) và thu nhập cao (10%, 20 đến 35 triệu). Số tiền của mỗi người được nhân với một hệ số để tháng trung vị đạt mức đích, rồi làm tròn tới 1.000 đồng. Hệ số trung vị là 2.691 đồng cho một đô la, thấp hơn nhiều so với tỷ giá, vì mức đích là mức chi của người Việt chứ không phải mức chi Mỹ quy đổi. Giao dịch trung vị trở thành 86.000 đồng.`));
  add(body(r`*Vì sao chuyển đổi không làm đổi dự báo.* Ngân sách là bội số của chi tiêu cũ của chính người dùng, và mọi đại lượng các cách dự báo dùng đều là tỉ số với ngân sách ấy, nên nhân số tiền của một người với một hằng số không làm đổi dự báo nào. Nhóm kiểm bằng cách chạy lại toàn bộ thí nghiệm trên dữ liệu đã chuyển: trên điểm Brier, log loss, AUC và ECE của mọi cách dự báo ở mọi mức ngân sách, chênh lệch lớn nhất so với lần chạy bằng đô la là 0,00096, do làm tròn tới 1.000 đồng. Vì vậy chuyển đổi phục vụ hai mục đích khác: cho phép nạp dữ liệu vào FlowMoney, và giúp người chấm đọc số tiền và danh mục như một người dùng Việt Nam.`));
  add(H2('Thiết kế đánh giá'));
  add(body(r`Bảng II liệt kê các khía cạnh. Mỗi khía cạnh có chỉ số riêng, và kết quả của khía cạnh này không được dùng làm bằng chứng cho khía cạnh khác.`));
  add(TABLE('Các khía cạnh đánh giá, dữ liệu và chỉ số', [1000, 1300, 2740],
    ['Khía cạnh', 'Dữ liệu', 'Chỉ số'],
    [
      ['Chất lượng xác suất (RQ1)', '310.978 dự báo, 1.513 người', 'Điểm Brier (3), sai số hiệu chuẩn kỳ vọng (ECE), diện tích dưới đường ROC'],
      ['Cảnh báo sớm (RQ2)', 'Như trên', 'Tỉ lệ phát hiện khi tỉ lệ báo nhầm không quá 10%; trung vị số ngày báo trước khi vượt'],
      ['Hệ thống thật (RQ3)', '5 người trong ứng dụng; 20.000 ca lấy mẫu', 'Con số trên ứng dụng khớp đúng với kết quả chạy lại mã nguồn trên máy tính'],
      ['Người kiểm tra (RQ4)', '80 mục ánh xạ, 4 bậc, 20 tháng mẫu, 30 cảnh báo', 'Điểm Likert 5 mức trung bình [@likert]; mức đồng thuận giữa hai người chấm [@cohen]'],
    ], null, 'LLL'));
  add(body(r`Điểm Brier là trung bình bình phương khoảng cách giữa xác suất dự báo $p_{i}$ và kết quả $o_{i}$ (bằng 1 nếu tháng kết thúc vượt ngân sách):`));
  add(EQ(r`\text{BS}=\frac{1}{N}\sum_{i=1}^{N}{(p_{i}-o_{i})^{2}}.`));
  add(body(r`Càng thấp càng tốt; luôn dự báo đúng tỉ lệ vượt chung 44% sẽ cho 0,247. ECE lấy trung bình, trên mười nhóm dự báo, khoảng cách giữa xác suất dự báo và tỉ lệ vượt quan sát được. Với cảnh báo, một lần báo nhầm là một tháng không vượt nhưng vẫn nhận cảnh báo, và với mỗi cách dự báo nhóm chọn ngưỡng $p^{*}$ bắt được nhiều lần vượt nhất mà vẫn giữ tỉ lệ báo nhầm ở mức 10% trở xuống.`, { noIndent: true }));
  add(H2('Quy trình thực nghiệm'));
  add(body(r`*Thí nghiệm ngoài ứng dụng.* Các tháng được xử lý theo thứ tự thời gian [@tashman]: với mỗi tháng, một cách dự báo chỉ thấy dữ liệu trước đó cộng phần tháng hiện tại tới mốc, và M3 được khớp lại mỗi sáu tháng trên 4.000 dòng trước đó. Dự báo được làm vào các ngày 5, 10, 15, 20 và 25. 20% số tháng đầu (trước tháng 6/2016) dùng để chọn $\lambda$ (chọn 0,01 trong tám giá trị) và không được báo cáo. Chênh lệch giữa các cách dự báo được lấy trung bình theo người và kèm khoảng tin cậy 95% từ 2.000 lần lấy mẫu lại người dùng [@efron]. Mã thí nghiệm viết bằng Python với scikit-learn; riêng quy tắc của ứng dụng còn được chạy nguyên văn bằng Dart trên máy tính.`));
  add(body(r`*Kiểm thử trên hệ thống thật.* Nhóm dựng bản FlowMoney hiện tại (không sửa mã) cho máy ảo Android 16 và chạy backend của dự án trên máy, với cơ sở dữ liệu PostgreSQL của nó. Năm người dùng đã chuyển đổi được chọn theo seed trong số người có tháng 11 của các năm 2016 đến 2019 nằm trong giai đoạn đánh giá, có sáu tháng lịch sử và tới ngày 10 vẫn chưa vượt ngân sách: hai người có tháng kết thúc vượt và ba người không vượt. Nhóm dùng tháng 11 vì phép thử chạy vào tháng 11, nên có thể dời nguyên một năm mà số ngày của các tháng vẫn khớp. Với mỗi người, tháng 11 nguồn và bảy tháng trước đó được dời sang năm 2026 (số ngày của các tháng trùng khớp), tới ngày 10, vì phép thử chạy ngày 10/11/2026. Một tài khoản thử được đăng ký qua API của ứng dụng, đăng nhập trên máy ảo để ứng dụng tự tạo ví và bản sao danh mục, rồi giao dịch và một ngân sách tổng hằng tháng bằng đúng $B$ của thí nghiệm được đẩy lên qua API đồng bộ của ứng dụng. Sau đó nhóm mở Ngân sách, Ngân sách tổng trong ứng dụng, chụp màn hình, rồi chạy lại quy tắc Dart của ứng dụng trên máy tính với cùng giao dịch, ở đúng giờ máy lúc chụp.`));
  add(body(r`*Chấm Likert.* Hai tác giả chấm độc lập trên phiếu riêng, không xem điểm của nhau. Phiếu A gồm 80 mục ánh xạ (77 mã lẻ và ba dải mã), bốn bậc thu nhập và 20 tháng chi tiêu đã chuyển đổi (năm tháng mỗi bậc, chọn theo seed), mỗi mục kèm nhận định rằng nó hợp lý với một người dùng Việt Nam. Phiếu B cho 30 cảnh báo (ngày 10, 15 và 20; một nửa từ các tháng kết thúc vượt) cùng ngân sách, số đã chi và ba tháng trước; ba cách dự báo hiện thành A, B, C theo thứ tự xáo trộn, và kết quả cuối tháng bị ẩn. Các mục ở phiếu A bị chấm 1 hoặc 2 được sửa trước khi khoá bảng.`));

  // IV
  add(H1('Thực nghiệm và kết quả'));
  add(H2('Chất lượng xác suất và cảnh báo sớm'));
  add(body(r`Với $\kappa=1,0$ có 310.978 dự báo trên 65.734 tháng-người, và 44,3% thuộc các tháng kết thúc vượt ngân sách. Bảng III cho điểm số. M3 tốt nhất ở mọi chỉ số, M2 theo sát, và cả hai bỏ xa quy tắc M1 của ứng dụng. Tính theo người, M3 hơn M1 0,018 điểm Brier (khoảng tin cậy 95% từ 0,017 đến 0,018) và tốt hơn ở 94% người dùng; M2 hơn M1 0,017, còn M3 hơn M2 một khoảng nhỏ nhưng rõ là 0,0013 (0,0011 đến 0,0015). Thứ tự giữ nguyên ở ngân sách chặt (Brier 0,138, 0,139 và 0,155 cho M3, M2 và M1), ở ngân sách rộng (0,124, 0,125 và 0,139), và ở mọi ngày mốc.`));
  add(TABLE('Kết quả trên dữ liệu thẻ đã chuyển đổi (κ = 1,0)', [1150, 520, 500, 520, 620, 620, 1110],
    ['Phương pháp', 'Brier', 'AUC', 'ECE', 'Báo nhầm', 'Phát hiện', 'Số ngày báo trước'],
    [
      ['M1 Trung vị (app)', '0,166', '0,828', '0,030', '6,2%', '68%', '9'],
      ['M2 EWMA', '0,149', '0,863', '0,024', '9,8%', '78%', '12'],
      ['M3 Hồi quy phân vị', '0,148', '0,864', '0,006', '8,9%', '77%', '12'],
    ],
    r`Gộp mọi mốc. Ba cột cuối dùng ngưỡng cho tỉ lệ phát hiện cao nhất mà tỉ lệ báo nhầm không quá 10%; số ngày báo trước là trung vị.`));
  add(body(r`Hình 2 cho thấy độ hiệu chuẩn. M3 nằm gần như trên đường chéo (ECE 0,006, và không quá 0,006 ở mọi mức ngân sách), nên con số 30% của M3 có thể hiện cho người dùng đúng là 30%. M1 phóng đại rủi ro trong khoảng 0,3 đến 0,8. Hình 3 cho thấy đánh đổi của cảnh báo. Với nhiều nhất một lần báo nhầm trong mười tháng, M3 và M2 bắt được 77% và 78% số lần vượt, trung vị 12 ngày trước khi vượt ngân sách, so với 68% và 9 ngày của M1. Với tỉ lệ báo nhầm không quá 2%, M3 vẫn bắt được 60% sớm 8 ngày và M2 bắt 54%, còn M1 không có ngưỡng nào thấp đến thế vì xác suất của nó chỉ có bảy giá trị.`));
  add(FIG('fig2_vn_reliability.png', 300, 291, r`Độ hiệu chuẩn ở ngày 15 ($\kappa=1,0$): tỉ lệ vượt quan sát được theo xác suất dự báo trong mười nhóm bằng nhau. Đường đứt là hiệu chuẩn hoàn hảo.`));
  add(FIG('fig3_vn_warning.png', 300, 291, r`Đánh đổi của cảnh báo ($\kappa=1,0$): (a) phần số lần vượt bắt được và (b) trung vị số ngày báo trước, theo tỉ lệ báo nhầm khi ngưỡng $p^{*}$ thay đổi.`));
  add(H2('Kiểm thử trên hệ thống thật'));
  add(body(r`Bảng IV và Hình 4 cho kết quả kiểm thử trong ứng dụng. Ở cả năm tài khoản, ứng dụng học từ sáu tháng đã đóng, giống thí nghiệm, và con số nhịp chi trên trang Ngân sách tổng ("Theo nhịp thường lệ", số tiền thường đã chi tới thời điểm này) khớp từng đồng với kết quả chạy lại mã Dart của ứng dụng trên máy tính. Số đã chi và ngân sách cũng khớp thí nghiệm. Năm trường hợp còn cho thấy một xác suất sẽ bổ sung gì cho nhãn của ứng dụng. Với người 1 và 2, ứng dụng gắn nhãn chậm và dự phóng dưới ngân sách, nhưng cả hai tháng đều kết thúc vượt; cả ba cách dự báo cho 0,15 đến 0,33 ở ngày 10, nên đây là lần bỏ sót mà không cách nào tránh được sớm như vậy. Với người 4, ứng dụng gắn nhãn nhanh và dự phóng 4,28 triệu so với ngân sách 3,23 triệu, cả ba cách dự báo cho khoảng 0,8, nhưng tháng kết thúc ở 2,86 triệu: một lần báo nhầm. Người 3 cho thấy chỗ một xác suất nói được nhiều hơn một con số dự phóng: dự phóng của ứng dụng là 22,87 triệu so với ngân sách 22,96 triệu, gần như hoà, điều một con số đơn lẻ không diễn đạt được; M1 cho 0,50 còn M2 và M3 cho 0,14 và 0,15; tháng kết thúc ở 18,40 triệu.`));
  add(TABLE('Năm người dùng đã chuyển đổi nạp vào FlowMoney (ngày 10)', [300, 760, 640, 640, 900, 880, 980],
    ['#', 'Ngân sách', 'Đã chi', 'Nhãn app', 'Nhịp thường lệ, app = mã', 'Cuối tháng', 'p1/p2/p3'],
    [
      ['1', '16.054.000', '3.511.000', 'chậm', '4.965.176', '16.986.000 (vượt)', ',21/,18/,15'],
      ['2', '6.404.000', '1.767.000', 'chậm', '2.198.954', '8.609.000 (vượt)', ',21/,33/,28'],
      ['3', '22.961.000', '5.680.000', 'đúng nhịp', '5.717.261', '18.400.000', ',50/,14/,15'],
      ['4', '3.226.000', '1.476.000', 'nhanh', '878.969', '2.859.000', ',79/,84/,84'],
      ['5', '4.128.000', '798.000', 'chậm', '1.266.831', '3.043.000', ',21/,22/,15'],
    ],
    r`Số tiền tính bằng đồng. Bậc: 1 ổn định, 2 mới đi làm, 3 thu nhập cao, 4 và 5 sinh viên. Ứng dụng hiện nhãn và con số nhịp chi; xác suất lấy từ thí nghiệm.`, 'LLLLLLL'));
  add(FIG('fig4_app.png', 300, 170, r`Trang Ngân sách tổng của FlowMoney trong phép kiểm thử: (a) người 1, nhãn chậm, tháng sau đó kết thúc vượt; (b) người 4, nhãn nhanh, tháng không vượt.`));
  add(body(r`Phép kiểm trong ứng dụng chỉ có năm người. Một phép kiểm lớn hơn cho cùng quy tắc được chạy trên máy tính với 20.000 dự báo rút ngẫu nhiên từ dữ liệu đã chuyển: khi mỗi giao dịch đặt ở cuối ngày của nó, M1 bằng Python của nhóm và hàm Dart của ứng dụng khớp ở mọi trường hợp. Với giờ thật trong dữ liệu, 2,1% quyết định vượt hay không khác nhau, vì ứng dụng xếp giao dịch theo thời điểm nhập.`));
  add(H2('Người kiểm tra dữ liệu và cảnh báo'));
  add(body(r`[đang chấm] Hai người chấm đang điền phiếu A và B. Bảng V sẽ cho điểm trung bình và mức đồng thuận của từng phần, và các mục ánh xạ bị một trong hai người chấm 1 hoặc 2 sẽ được liệt kê cùng thay đổi đã làm trước khi khoá bảng. Với phiếu B, điểm trung bình cảnh báo của từng cách dự báo sẽ được so với kết quả cuối tháng đã bị ẩn khỏi người chấm.`));
  add(TABLE('Điểm Likert (1 đến 5) của hai người chấm', [1900, 800, 800, 800, 740],
    ['Phần', 'Số mục', 'Người 1', 'Người 2', 'Đồng thuận'],
    [
      ['Ánh xạ MCC sang danh mục', '80', '[đang chấm]', '[đang chấm]', '[đang chấm]'],
      ['Bậc thu nhập', '4', '[đang chấm]', '[đang chấm]', '[đang chấm]'],
      ['Tháng chi tiêu đã chuyển đổi', '20', '[đang chấm]', '[đang chấm]', '[đang chấm]'],
      ['Cảnh báo M1 / M2 / M3', 'mỗi loại 30', '[đang chấm]', '[đang chấm]', '[đang chấm]'],
    ],
    r`Điểm trung bình; đồng thuận đo bằng kappa có trọng số bậc hai [@cohen].`, 'LCCCC'));

  // V
  add(H1('Thảo luận'));
  add(body(r`*Dữ liệu ủng hộ điều gì.* Với kiểu chi tiêu giống thẻ, mua sắm rơi vào hầu hết các ngày, xác suất từ M3 hoặc M2 chính xác và hiệu chuẩn tốt hơn quy tắc trung vị của ứng dụng, và cảnh báo sớm hơn khoảng ba ngày trong khi bắt được nhiều lần vượt hơn ở cùng tỉ lệ báo nhầm. M2 gần như không tốn gì trên điện thoại mà tốt gần bằng M3. Quy tắc của ứng dụng, như đang cài đặt, cho cùng con số trong ứng dụng thật và trong phép đánh giá ngoài ứng dụng, nên phép so sánh nói về đúng quy tắc người dùng đang thấy.`));
  add(body(r`*Điều chỉ đúng trong điều kiện nhất định.* Thứ hạng đến từ bộ sinh của IBM, nơi người dùng chi vào hầu hết các ngày và khoảng một phần sáu chi tiêu là cùng một khoản lặp lại mỗi tháng. Người dùng mà mỗi tháng chỉ có vài khoản cố định lớn như tiền nhà, học phí là trường hợp khác: trung vị của các tháng trước bám trực tiếp những khoản ấy, và khi đó quy tắc của ứng dụng có thể tốt ngang một mô hình huấn luyện chung. Vì vậy thứ hạng phụ thuộc vào mức đều đặn và mức thường xuyên của chi tiêu.`));
  add(body(r`*Điều dữ liệu chưa cho thấy.* Dữ liệu không cho thấy người dùng FlowMoney thật chi tiêu thế nào, họ phản ứng ra sao với cảnh báo, hay cảnh báo có ngăn được lần vượt mà nó dự báo không. Năm tài khoản cho thấy luồng xử lý chạy được trong hệ thống thật; con số ấy quá ít để nói ứng dụng đúng thường xuyên đến đâu.`));
  add(body(r`*Hàm ý cho FlowMoney.* Ứng dụng có thể giữ quy tắc trung vị làm mặc định, vì nó không cần huấn luyện, và thêm một xác suất cạnh nhãn nhịp chi. Nếu hiện xác suất dưới dạng phần trăm, con số nên lấy từ M2 hoặc M3, hoặc trước hết phải ánh xạ bảy mức của M1 sang tỉ lệ vượt quan sát được. Thông báo nên gửi một lần mỗi tháng, lần đầu $p_{t}$ vượt ngưỡng đã chọn. Hệ số của M3 có thể huấn luyện sẵn và đóng gói cùng ứng dụng, nên không giao dịch nào phải rời điện thoại.`));
  add(body(r`*Hạn chế.* Thói quen chi tiêu là của chủ thẻ Mỹ do IBM mô phỏng: thanh toán bằng thẻ, loại cửa hàng ở Mỹ, không có Tết. Việc chuyển đổi đổi số tiền và nhãn; thói quen vẫn là của người dùng mô phỏng. Bảng chuyển đổi do một mô hình AI đề xuất và được kiểm bởi hai người chấm cũng chính là tác giả. Ngân sách được dựng theo luật, không do người dùng chọn. Phép kiểm trong ứng dụng dùng máy ảo và năm người. Mỗi lần chạy dùng một seed ngẫu nhiên.`));

  // VI
  add(H1('Kết luận'));
  add(body(r`Bài so sánh ba cách dự báo xác suất một tháng kết thúc vượt ngân sách, dùng dữ liệu thẻ mô phỏng của IBM đã chuyển sang danh mục của FlowMoney và mức chi tiêu Việt Nam, với phần chuyển đổi do AI đề xuất và con người kiểm tra. Hồi quy phân vị và EWMA chính xác và hiệu chuẩn tốt hơn quy tắc trung vị của ứng dụng, và cảnh báo được 77% đến 78% số lần vượt sớm khoảng 12 ngày ở tỉ lệ báo nhầm 10%. Nạp người dùng đã chuyển đổi vào ứng dụng thật cho lại đúng con số của ứng dụng. Bước tiếp theo là hoàn tất phần chấm Likert và khoá bảng chuyển đổi, sinh một tập người dùng có thói quen Việt Nam như lương tháng và chi tiêu dịp Tết, và đưa xác suất cùng thông báo mỗi tháng một lần vào trang Ngân sách.`));

  add(H1('Lời cảm ơn và khai báo', false));
  add(body(r`Claude (Anthropic) [@claude] đề xuất bảng ánh xạ mã ngành hàng và các bậc thu nhập dùng để chuyển đổi dữ liệu, và hỗ trợ soạn văn bản cùng các script thí nghiệm. Nhóm tác giả kiểm phần chuyển đổi bằng phiếu Likert, đối chiếu mọi con số với hồ sơ thí nghiệm, và chịu hoàn toàn trách nhiệm về nội dung.`, { noIndent: true }));

  add(H1('Tài liệu tham khảo', false));
  add(REFLIST());
};
