// Bản tiếng Việt của bài. Đánh dấu: $...$ công thức (mini-LaTeX), [@khoá] trích dẫn, *x* nghiêng, **x** đậm.
// Số liệu mục V-VI lấy từ ../experiment/results/{berka,berka_nofixed,berka_rows12000,tabformer,synthetic,
// bootstrap,bootstrap_tabformer,m1_compare,m1_compare_tabformer}.json.
'use strict';

exports.title = 'Nghiên cứu và phát triển mô hình dự báo xác suất dựa trên trung vị, EWMA và hồi quy phân vị nhằm cảnh báo sớm nguy cơ vượt ngân sách cuối kỳ từ nhịp chi tiêu cá nhân trong ứng dụng quản lý tài chính cá nhân';
exports.authors = 'Nguyễn Phú Bảo và Trần Quang Đạt';
exports.header = 'NGHIÊN CỨU KHOA HỌC SINH VIÊN, TRƯỜNG ĐẠI HỌC CÔNG NGHIỆP TP. HỒ CHÍ MINH, BẢN THẢO, THÁNG 11/2026';
exports.footnote = 'Bản thảo gửi duyệt ngày 09/11/2026. Đề tài nghiên cứu khoa học sinh viên do ThS. Huỳnh Nam hướng dẫn. Nguyễn Phú Bảo và Trần Quang Đạt thuộc Khoa Công nghệ Thông tin, Trường Đại học Công nghiệp Thành phố Hồ Chí Minh, TP. Hồ Chí Minh, Việt Nam (e-mail: [bổ sung sau]).';

exports.build = ({ add, body, H1, H2, EQ, bullet, FIG, TABLE, LABELED, REFLIST, r }) => {
  add(LABELED('Tóm tắt', 'Cảnh báo ngân sách trong ứng dụng quản lý tài chính cá nhân có thể dựa trên tỉ lệ ngân sách đã tiêu, vốn chỉ phản ứng khi tiền đã hết, hoặc kéo thẳng mức chi tới cuối tháng, vốn đánh giá sai người trả tiền nhà hay hoá đơn vào đầu tháng. Nghiên cứu này ước lượng, tại bất kỳ ngày nào trong kỳ, xác suất tổng chi cuối kỳ vượt ngân sách, và đo xem xác suất ấy cho phép cảnh báo sớm được bao lâu. Bốn phương pháp dự báo phần tiền còn chi được so sánh: mô hình chia đều làm mốc, quy tắc trung vị nhịp chi đang chạy trong ứng dụng FlowMoney, trung bình trượt có trọng số mũ của chi tiêu theo ngày, và hồi quy phân vị tuyến tính huấn luyện trên dữ liệu gộp của mọi người dùng. Các phương pháp được đánh giá cuốn chiếu tại năm mốc mỗi tháng và ba mức ngân sách, trên ba bộ dữ liệu: dữ liệu ngân hàng PKDD-99 Berka (4.051 tài khoản, 1993 đến 1998), giao dịch thẻ mô phỏng của IBM (1.518 người dùng, 2015 đến 2020), và một tập người dùng mô phỏng có kiểu chi biết trước. Trên dữ liệu ngân hàng, quy tắc trung vị có điểm Brier thấp nhất ở mức ngân sách trung tính (0,169 so với 0,172 của hồi quy phân vị), chênh lệch nhỏ nhưng có ý nghĩa thống kê, và hồi quy phân vị hiệu chuẩn tốt nhất ở cả ba mức. Trên dữ liệu thẻ, nơi người dùng chi gần như mỗi ngày, hồi quy phân vị và trung bình trượt gần ngang nhau và cùng hơn rõ quy tắc trung vị (Brier 0,148 và 0,149 so với 0,166), và ở tỉ lệ báo nhầm không quá 10% hồi quy phân vị báo trước được 77% số lần vượt, trung vị sớm 12 ngày; trên dữ liệu ngân hàng, mọi phương pháp chỉ báo trước được khoảng một phần năm số lần vượt, sớm năm hoặc sáu ngày. Hồi quy phân vị cũng thắng trên dữ liệu ngân hàng khi bỏ các khoản chi cố định hằng tháng, và thắng trên tập mô phỏng. Chạy trên 40.000 trường hợp chung, mã Dart của ứng dụng cho cùng dự báo trung vị với bản Python khi mỗi giao dịch được đặt vào cuối ngày của nó. Quy tắc trung vị hợp với kiểu chi mà phần lớn là khoản cố định lặp lại; với kiểu chi như dữ liệu thẻ, mô hình phân vị gộp là lựa chọn tốt hơn, và cả hai đều chạy được trên điện thoại.'));
  add(LABELED('Ý nghĩa thực tiễn', 'Một cảnh báo ngân sách chỉ có ích khi đến đủ sớm để người dùng kịp điều chỉnh và đủ hiếm để họ còn tin. Nghiên cứu này biến nguy cơ vượt ngân sách thành một xác suất và đo xem ở một tỉ lệ báo nhầm cho trước thì bắt được bao nhiêu lần vượt, sớm bao nhiêu ngày. Câu trả lời tuỳ vào cách người ta chi tiêu. Cứ mười tháng không vượt thì chấp nhận một lần báo nhầm, khi đó với tài khoản ngân hàng những năm 1990, nơi mỗi tháng chỉ có vài khoản chi lớn, khoảng một phần năm số lần vượt được báo trước, trung vị sớm năm ngày. Với dữ liệu chi tiêu bằng thẻ mô phỏng từ 2015 đến 2020, ba phần tư số lần vượt được báo trước, sớm 12 ngày. Quy tắc trung vị FlowMoney đang chạy trên điện thoại chính xác ngang mô hình phân vị học từ dữ liệu trên dữ liệu ngân hàng, nhưng kém hơn nó trên dữ liệu thẻ. Mô hình học từ dữ liệu hiệu chuẩn tốt hơn ở cả hai, và lúc chạy chỉ cần vài hệ số, nên mô hình nào cũng đưa vào ứng dụng được mà không phải gửi giao dịch lên máy chủ.'));
  add(LABELED('Từ khoá', 'Cảnh báo sớm, dự báo xác suất, hồi quy phân vị, quản lý tài chính cá nhân, trung bình trượt có trọng số mũ, vượt ngân sách.', 160));

  // I
  add(H1('Giới thiệu'));
  add(body(r`Lập kế hoạch tài chính kém gây thiệt hại đo được cho các hộ gia đình [@lusardi]. Người ta thường chia tiền vào những "tài khoản tâm lý" theo từng kỳ, chẳng hạn tiền ăn của tháng này [@thaler], và ngân sách tháng trong ứng dụng quản lý tài chính đi theo đúng thói quen ấy. Lời nhắc gửi đúng lúc đã được chứng minh là làm thay đổi hành vi tài chính [@karlan], nên cảnh báo ngân sách đến vào lúc nào cũng quyết định nó có tác dụng hay không.`));
  add(body(r`Một cách cảnh báo đơn giản là báo khi số đã chi chạm một tỉ lệ cố định của ngân sách, ví dụ 80% hoặc 100%. Cách này chỉ nhìn vào số tiền đã tiêu. Một cách khác là kéo thẳng: nếu tháng đã trôi 40% mà ngân sách đã hết 60% thì người dùng đang chi quá nhanh. Phép kéo thẳng sai với người chi dồn vào đầu kỳ. Ai trả tiền nhà ngày mùng 1 sẽ bị coi là vượt nhịp ở mọi mốc đầu tháng, và chẳng bao lâu sẽ bỏ qua cảnh báo.`));
  add(body(r`FlowMoney, ứng dụng quản lý tài chính cá nhân offline-first do nhóm xây dựng, học một *nhịp chi* cho mỗi ngân sách từ ba đến sáu kỳ đã đóng gần nhất có phát sinh chi. Tại mỗi phần kỳ đã trôi, ứng dụng lấy trung vị qua các kỳ ấy của tỉ lệ đã chi và của số tiền còn chi. Nhịp hiện tại được xếp vào ba bậc chậm, đúng nhịp hoặc nhanh theo một biên năm điểm phần trăm quanh nhịp đã học; khi chưa đủ ba kỳ, ứng dụng giả định chi đều. Trung vị không bị một tháng bất thường kéo lệch. Tuy vậy nó chỉ cho một con số dự báo chứ không cho xác suất, và với tối đa sáu kỳ thì phân phối thực nghiệm rất thô.`));
  add(body(r`Bài này đặt câu hỏi: dự báo dưới dạng xác suất có cho cảnh báo sớm tốt hơn không. Xác suất $p_{t}=P(S_{T}>B\mid\F_{t})$ để tổng chi cuối kỳ $S_{T}$ vượt ngân sách $B$ chấm được bằng các quy tắc tính điểm chuẩn tắc [@gneitingR] và kiểm được độ hiệu chuẩn [@gneitingC]. Nó cũng cho phép ứng dụng chọn ngưỡng cảnh báo, đánh đổi giữa số lần báo nhầm và số ngày báo trước. Nghiên cứu trả lời ba câu hỏi:`));
  add(bullet(r`RQ1: Phương pháp nào cho xác suất vượt ngân sách hiệu chuẩn tốt nhất và sắc nét nhất?`));
  add(bullet(r`RQ2: Ở cùng một tỉ lệ báo nhầm, mỗi phương pháp báo trước được sớm hơn các mốc so sánh bao nhiêu ngày?`));
  add(bullet(r`RQ3: Độ chặt của ngân sách và mức đều đặn trong chi tiêu của người dùng làm thứ hạng thay đổi ra sao?`));
  add(body(r`Bài có bốn đóng góp. Chúng tôi đặt bài toán cảnh báo vượt ngân sách thành dự báo xác suất cho phần tiền còn chi, và đánh giá cả xác suất lẫn cảnh báo sinh ra từ nó. Chúng tôi so sánh bốn phương pháp trên dữ liệu ngân hàng công khai, dữ liệu thẻ mô phỏng và một tập người dùng mô phỏng, trong đó có quy tắc trung vị đang chạy trong một ứng dụng thật, và đối chiếu bản cài đặt quy tắc ấy với chính mã của ứng dụng. Kết quả cho thấy quy tắc trung vị chính xác ngang mô hình phân vị học từ dữ liệu trên dữ liệu ngân hàng, nơi khoản cố định chiếm phần lớn, nhưng kém rõ trên dữ liệu thẻ, và độ hiệu chuẩn là điểm yếu của nó trên cả ba bộ. Cuối cùng, bài đưa ra hướng dẫn tính dự báo ngay trên điện thoại mà không gửi giao dịch lên máy chủ.`));
  add(body(r`Mục II điểm qua các nghiên cứu liên quan, mục III phát biểu bài toán và mục IV mô tả các phương pháp. Mục V trình bày dữ liệu và cách đánh giá, mục VI báo cáo và thảo luận kết quả. Mục VII bàn cách tích hợp vào FlowMoney, mục VIII nêu phần việc còn lại, và mục IX kết luận.`));

  // II
  add(H1('Các nghiên cứu liên quan'));
  add(H2('Làm trơn hàm mũ'));
  add(body(r`Roberts đưa ra trung bình trượt có trọng số mũ (EWMA) cho bài toán giám sát quy trình [@roberts], và phương pháp này trở thành nền của các mô hình dự báo làm trơn hàm mũ [@holt], [@hunter]. RiskMetrics dùng cùng công thức truy hồi cho phương sai của lợi suất tài chính, nên một hằng số làm trơn theo dõi được cả mức lẫn độ biến động [@riskmetrics]. Hyndman và Athanasopoulos tổng hợp các phương pháp làm trơn hàm mũ cùng khoảng dự báo của chúng [@hyndman]. EWMA thích nghi nhanh và gần như không tốn chi phí tính, hợp với điện thoại. Điểm yếu của nó với bài toán này là coi mọi ngày trong tháng như nhau.`));
  add(H2('Hồi quy phân vị và dự báo xác suất'));
  add(body(r`Hồi quy phân vị ước lượng phân vị có điều kiện bằng cách cực tiểu hoá hàm mất mát kiểm (check loss) [@koenkerB], [@koenker]. Taylor kết hợp nó với trọng số mũ để dự báo phân phối doanh số bán hàng theo ngày của siêu thị [@taylor], một bài toán gần với bài này, còn rừng hồi quy phân vị mở rộng phương pháp sang mô hình phi tuyến [@meinshausen]. Các phân vị ước lượng riêng rẽ có thể cắt nhau; phép sắp lại đơn điệu loại bỏ chỗ cắt mà không làm giảm độ chính xác [@chernozhukov]. Một dự báo xác suất cần được hiệu chuẩn và, khi đã hiệu chuẩn, càng sắc nét càng tốt [@gneitingC]. Nó được đánh giá bằng các điểm số chuẩn tắc chặt như điểm Brier [@brier] và điểm logarit [@gneitingR]. Độ hiệu chuẩn thường tóm tắt bằng sai số hiệu chuẩn kỳ vọng [@naeini], [@guo], còn khả năng phân biệt bằng diện tích dưới đường cong ROC [@fawcett].`));
  add(H2('Đánh giá dự báo'));
  add(body(r`Dự báo phải được đánh giá ngoài mẫu và theo đúng thứ tự thời gian. Đánh giá cuốn chiếu (rolling origin) khớp lại hoặc cập nhật mô hình tại mỗi mốc dự báo chỉ bằng dữ liệu trước đó [@tashman]. Hai phương pháp có thể so sánh bằng kiểm định Diebold–Mariano [@dm], hoặc bằng bootstrap theo người dùng khi các quan sát gom theo từng người [@efron].`));
  add(body(r`Các nghiên cứu trên đánh giá dự báo cho một đại lượng. Ở bài này, thứ được đánh giá là một lời cảnh báo, nên số ngày báo trước được đo cùng với chất lượng của xác suất.`));

  // III
  add(H1('Phát biểu bài toán'));
  add(body(r`Xét một người dùng và một kỳ ngân sách dài $T$ ngày với ngân sách $B>0$. Gọi $y_{d}\ge0$ là số tiền chi trong ngày $d$, $S_{t}=\sum_{d=1}^{t}{y_{d}}$ là tổng chi tích luỹ sau ngày $t$, và $x_{t}=t/T$ là phần kỳ đã trôi. Kỳ kết thúc bằng vượt ngân sách khi $O=\one[S_{T}>B]$ bằng một. Tại mốc $t$, mô hình thấy tập thông tin $\F_{t}$ gồm kỳ hiện tại tới ngày $t$ và mọi kỳ trước đó của người dùng, rồi trả về`));
  add(EQ(r`p_{t}=P(S_{T}>B\mid\F_{t})=P(R_{t}>B-S_{t}\mid\F_{t}),`));
  add(body(r`trong đó $R_{t}=S_{T}-S_{t}\ge0$ là phần tiền còn chi. Vì vậy mỗi phương pháp ở mục IV đều cho ra một phân phối dự báo của $R_{t}$. Khi $S_{t}>B$ thì kỳ đã vượt ngân sách; khi đó $p_{t}=1$ và mốc này không đưa vào chấm điểm xác suất.`, { noIndent: true }));
  add(body(r`Cảnh báo được phát tại mốc đầu tiên có $p_{t}\ge p^{*}$. Gọi $\tau_{O}$ là ngày đầu tiên có $S_{d}>B$. Với một kỳ có vượt ngân sách, số ngày báo trước của cảnh báo phát ở ngày $t_{a}$ là`));
  add(EQ(r`L=\tau_{O}-t_{a},`));
  add(body(r`và $L$ dương nghĩa là người dùng được báo trước khi thực sự vượt ngân sách. Hình 1 tóm tắt quy trình, Hình 2 minh hoạ bài toán tại một mốc.`, { noIndent: true }));
  add(FIG('fig1_pipeline.png', 300, 265, r`Quy trình dự báo và cảnh báo. Mỗi phương pháp cho ra phân phối dự báo của phần tiền còn chi; xác suất vượt ngân sách và quyết định cảnh báo được tính từ phân phối này.`));
  add(FIG('fig2_problem.png', 320, 198, r`Chuỗi số tự dựng để minh hoạ (không phải dữ liệu thật): trả tiền nhà ngày 1, một khoản chi lớn ngày 10, và dải dự báo 10-90% cho tổng chi cuối tháng tại mốc $t=12$.`));

  // IV
  add(H1('Phương pháp'));
  add(body(r`Bảng I tóm tắt bốn phương pháp, xếp theo lượng thông tin sử dụng tăng dần.`));
  add(TABLE('Tóm tắt bốn phương pháp', [1150, 1330, 1330, 1230],
    ['Phương pháp', 'Thông tin dùng', 'Đầu ra dự báo', 'Chi phí trên máy'],
    [
      ['M0 Chia đều', 'các kỳ trước của chính người dùng', r`thực nghiệm, $K+1$ mức`, r`$O(K)$`],
      ['M1 Trung vị nhịp chi', '3-6 kỳ gần nhất', r`thực nghiệm, $K+1$ mức`, r`$O(K\cdot n)$`],
      ['M2 EWMA', 'chuỗi chi theo ngày', 'chuẩn hoặc log-chuẩn', r`$O(1)$ mỗi ngày`],
      ['M3 Hồi quy phân vị', 'đặc trưng + huấn luyện gộp', '19 phân vị', r`$O(|\T|\cdot|\phi|)$`],
    ],
    r`$K$: số kỳ trước dùng được; $n$: số giao dịch mỗi kỳ; $\T$: tập mức phân vị; $\phi$: véc-tơ đặc trưng.`));
  add(H2('M0: Mô hình chia đều'));
  add(body(r`Mô hình chia đều giả định tiền được chi đều trong kỳ, $S_{T}^{pr}=S_{t}/x_{t}$. FlowMoney dùng giả định này khi chưa học được nhịp chi. Để có xác suất, chúng tôi dùng sai số nhân $e_{k}=S_{T}^{(k)}x_{t}/S^{(k)}(x_{t})$ quan sát ở các kỳ trước $k=1,\ldots,K$ của người dùng, với $S^{(k)}(x)$ là tổng chi tích luỹ của kỳ $k$ tại phần kỳ đã trôi $x$:`));
  add(EQ(r`p_{t}=\frac{\sum_{k=1}^{K}{\one[S_{t}e_{k}/x_{t}>B]}+1/2}{K+1}.`));
  add(H2('M1: Trung vị nhịp chi'));
  add(body(r`M1 là quy tắc đứng sau nhãn nhịp chi và con số dự phóng cuối kỳ của FlowMoney. Với mỗi kỳ trong $K$ kỳ đã đóng gần nhất có phát sinh chi ($3\le K\le6$), gọi $r_{k}(x)=S_{T}^{(k)}-S^{(k)}(x)$ là số tiền chi sau phần kỳ $x$. Dự báo điểm $r_{t}^{med}$ là trung vị của $r_{k}(x_{t})$ theo $k$, nên một tháng bất thường ít ảnh hưởng, và ứng dụng dự phóng tổng chi cuối kỳ là $S_{t}+r_{t}^{med}$. Ứng dụng không hiện xác suất nào. Chúng tôi thêm xác suất bằng cách coi chính $K$ giá trị ấy là một phân phối dự báo thực nghiệm, làm trơn như ở (3):`));
  add(EQ(r`p_{t}=\frac{\sum_{k=1}^{K}{\one[S_{t}+r_{k}(x_{t})>B]}+1/2}{K+1}.`));
  add(body(r`Với $K\le6$, xác suất này chỉ nhận tối đa bảy giá trị. Khi có ít hơn ba kỳ, ứng dụng giả định chi đều, còn chúng tôi dùng M0.`));
  add(H2('M2: Tốc độ chi và độ biến động theo EWMA'));
  add(body(r`M2 làm trơn chuỗi chi theo ngày của người dùng, kể cả kỳ hiện tại tới ngày $t$, bằng một hằng số $\lambda\in(0;1]$ cho cả mức và phương sai [@riskmetrics]:`));
  add(EQ(r`\mu_{d}=\lambda y_{d}+(1-\lambda)\mu_{d-1},`));
  add(EQ(r`v_{d}=\lambda(y_{d}-\mu_{d-1})^{2}+(1-\lambda)v_{d-1}.`));
  add(body(r`Nếu coi $n=T-t$ ngày còn lại là độc lập thì $R_{t}\sim N(n\mu_{t},nv_{t})$ và`, { noIndent: true }));
  add(EQ(r`p_{t}=1-\Phi(\frac{B-S_{t}-n\mu_{t}}{\sqrt{nv_{t}}}),`));
  add(body(r`với $\Phi$ là hàm phân phối chuẩn tắc. $R_{t}$ không âm và lệch phải, nên dạng log-chuẩn có cùng kỳ vọng và phương sai được dự kiến làm biến thể. $\lambda$ được chọn trong $\{0,001;0,002;0,005;0,01;0,02;0,05;0,1;0,2\}$ trên các tháng kiểm định. M2 không biết gì về hiệu ứng lịch như tiền nhà trả ngày mùng 1, nên chúng tôi dự đoán nó kém với người chi dồn đầu kỳ nhưng thích nghi nhanh nhất khi thói quen chi thay đổi.`, { noIndent: true }));
  add(H2('M3: Hồi quy phân vị tuyến tính trên dữ liệu gộp'));
  add(body(r`M3 được huấn luyện trên dữ liệu của mọi người dùng cùng lúc. Biến mục tiêu là phần còn chi chia cho ngân sách, $z=R_{t}/B$. Véc-tơ $\phi$ gồm hệ số chặn và tám đặc trưng: phần kỳ đã trôi $x_{t}$, tỉ lệ đã chi $S_{t}/B$, dự báo của M1 $r_{t}^{med}/B$, kỳ vọng $n\mu_{t}/B$ và độ phân tán $\sqrt{nv_{t}}/B$ của M2, tỉ lệ chi trong quá khứ rơi vào những ngày còn lại của tháng, hệ số biến thiên của tổng chi các tháng trước, và $K$. Với mỗi mức $\tau\in\T=\{0,05;0,10;\ldots;0,95\}$, hệ số được chọn để cực tiểu hoá hàm mất mát kiểm [@koenkerB]`));
  add(EQ(r`b_{\tau}=\text{arg min}_{\beta}\sum_{i}{\rho_{\tau}(z_{i}-\phi_{i}^{\top}\beta)},`));
  add(EQ(r`\rho_{\tau}(u)=u(\tau-\one[u<0]).`));
  add(body(r`19 phân vị dự báo được sắp lại để không cắt nhau [@chernozhukov], rồi nối bằng nội suy tuyến tính, phần đuôi giữ phẳng, thành hàm phân phối dự báo $F_{t}$ của $z$. Khi đó`, { noIndent: true }));
  add(EQ(r`p_{t}=1-F_{t}((B-S_{t})/B).`));
  add(body(r`Trên điện thoại, M3 chỉ cần 19 phép nhân vô hướng, mỗi phép chín số, và ứng dụng chỉ phải mang theo bộ hệ số.`, { noIndent: true }));

  // V
  add(H1('Thiết kế thực nghiệm'));
  add(H2('Dữ liệu'));
  add(body(r`Bộ dữ liệu chính là bộ dữ liệu tài chính PKDD-99 do một ngân hàng Séc công bố [@berka], lấy từ một bản sao công khai của các tệp gốc. Bộ này có 1.056.320 giao dịch trên 4.500 tài khoản từ tháng 1/1993 đến tháng 12/1998, kèm các bảng tài khoản, khoản vay và lệnh chi định kỳ. Khoản chi là mọi giao dịch ghi nợ trừ phí ngân hàng (phí sao kê và lãi phạt), cộng theo ngày, và mỗi tháng dương lịch là một kỳ ngân sách. Mỗi tài khoản bắt đầu từ tháng trọn vẹn đầu tiên sau ngày mở; tài khoản có dưới 18 tháng bị loại, còn lại 4.051 tài khoản. Chi tiêu ở đây rất dồn cục: trung vị mỗi tài khoản chỉ có hai ngày phát sinh chi trong tháng, chủ yếu là rút tiền mặt và lệnh chi định kỳ, và 6,6% số tháng không chi đồng nào. Số tiền tính bằng koruna Séc và chênh lệch lớn giữa các tài khoản, nên mọi mô hình đều làm việc với tỉ lệ so với ngân sách. Một phân tích độ nhạy bỏ các khoản trả nợ vay và chi định kỳ cho hộ gia đình, tức các nghĩa vụ cố định hằng tháng.`));
  add(H2('Giao dịch thẻ mô phỏng'));
  add(body(r`Bộ dữ liệu thứ hai là dữ liệu thẻ tín dụng mô phỏng của IBM, công bố cùng các mô hình TabFormer [@padhi] và sinh ra bởi bộ mô phỏng giao dịch thẻ của IBM [@altman]. Bộ này có 24.386.900 giao dịch của 2.000 người dùng từ năm 1991 đến tháng 2/2020, mỗi giao dịch có ngày, giờ trong ngày, số tiền, nhóm ngành hàng và nhãn gian lận. Chúng tôi giữ giai đoạn tháng 1/2015 đến tháng 1/2020, vì tháng 2/2020 không đủ ngày. Khoản chi là mọi giao dịch có số tiền dương và không bị đánh dấu gian lận, nên các khoản hoàn tiền (5,1% số dòng) bị loại, và các thẻ của cùng một người được gộp lại. Người dùng có dưới 18 tháng bị loại, cùng 27 người ngừng chi trước tháng cuối, còn lại 1.518 người. Tính trên toàn tệp, trung vị mỗi người mỗi tháng có 78 giao dịch trong 29 ngày, trung vị hệ số biến thiên của tổng chi theo tháng của từng người là 0,24, và các khoản cùng số tiền, cùng nhóm ngành hàng lặp lại ít nhất sáu tháng chiếm 16,8% số tiền chi. Đây là dữ liệu sinh ra, nên nó cho thấy các phương pháp làm việc ra sao với kiểu chi tiêu thẻ thường xuyên, nhưng không nói trực tiếp gì về người dùng thật.`));
  add(H2('Tập người dùng mô phỏng'));
  add(body(r`Dữ liệu thật không cho biết vì sao một phương pháp thắng, nên chúng tôi sinh thêm 2.000 người dùng mô phỏng trong 36 tháng, mỗi kiểu chi tiêu 500 người. Kiểu A1 chi đều mỗi ngày. Kiểu A2 chi dồn đầu kỳ, trả 30-45% chi tiêu của tháng ngay ngày đầu. Kiểu A3 chi dồn sau ngày lương mùng 10. Kiểu A4 có một khoản mua lớn ngoài kế hoạch ở khoảng 15% số tháng. Mức chi của mỗi người trôi chậm theo thời gian. Vì biết quá trình sinh dữ liệu, có thể đọc kết quả theo từng kiểu chi.`));
  add(H2('Dựng ngân sách'));
  add(body(r`Dữ liệu công khai không có ngân sách. FlowMoney gợi ý hạn mức từ tổng chi trong 90 ngày gần nhất của người dùng (hoặc từ giao dịch đầu tiên nếu ngắn hơn), quy về mức mỗi tháng. Chúng tôi dùng dạng tương đương theo tháng dương lịch: ngân sách tháng $m$ là $B_{m}=\kappa(S_{m-1}+S_{m-2}+S_{m-3})/3$, với $S_{m}$ là tổng chi tháng $m$ và $\kappa\in\{0,9;1,0;1,1\}$. Ba mức cho ra ngân sách chặt, trung tính và rộng, do đó tỉ lệ vượt ngân sách khác nhau.`));
  add(H2('Quy trình đánh giá'));
  add(body(r`Việc đánh giá đi cuốn chiếu theo tháng dương lịch [@tashman]. Với tháng đánh giá $m$, mỗi phương pháp chỉ thấy dữ liệu trước tháng $m$ cộng với tháng hiện tại tới mốc dự báo, và M3 được khớp lại trên dữ liệu của mọi người dùng trước tháng $m$. 20% số tháng đánh giá được đầu tiên dùng để chọn $\lambda$ cho M2 và không đưa vào báo cáo: các tháng trước tháng 11/1995 với dữ liệu ngân hàng, trước tháng 6/2016 với dữ liệu thẻ, và tháng 6 đến 11 với tập người dùng mô phỏng. Dự báo được đưa ra vào các ngày 5, 10, 15, 20 và 25, bỏ các mốc đã vượt ngân sách. Cách chia giữ riêng hoàn toàn 30% người dùng được dự kiến cho bản hoàn chỉnh.`));
  add(H2('Chỉ số đánh giá'));
  add(body(r`Bảng II liệt kê các chỉ số. Chất lượng xác suất được đo bằng điểm Brier`));
  add(EQ(r`\text{BS}=\frac{1}{N}\sum_{i=1}^{N}{(p_{i}-o_{i})^{2}},`));
  add(body(r`log loss với xác suất kẹp trong $[10^{-3};1-10^{-3}]$, diện tích dưới đường cong ROC, và sai số hiệu chuẩn kỳ vọng trên mười nhóm có cùng số dự báo,`, { noIndent: true }));
  add(EQ(r`\text{ECE}=\sum_{b=1}^{10}{\frac{N_{b}}{N}|O_{b}-P_{b}|},`));
  add(body(r`trong đó $N_{b}$ là số dự báo trong nhóm $b$, còn $O_{b}$ và $P_{b}$ là tần suất vượt ngân sách quan sát được và xác suất dự báo trung bình trong nhóm đó. Biểu đồ độ tin cậy cho thấy cùng phép so ấy theo từng nhóm. Với cảnh báo, mỗi ngưỡng $p^{*}$ trên lưới bước 0,02 cho một tỉ lệ báo nhầm (phần các tháng không vượt mà vẫn nhận ít nhất một cảnh báo), một tỉ lệ phát hiện và một trung vị số ngày báo trước (2). Các bảng ghi ngưỡng có tỉ lệ phát hiện cao nhất trong các ngưỡng có tỉ lệ báo nhầm không quá 10%.`, { noIndent: true }));
  add(TABLE('Các chỉ số đánh giá', [1500, 2640, 900],
    ['Chỉ số', 'Trả lời câu hỏi', 'Tốt hơn khi'],
    [
      ['Điểm Brier, log loss', 'Xác suất có đúng tổng thể không?', 'thấp hơn'],
      ['ECE, biểu đồ độ tin cậy', 'Khi báo 30%, có đúng 30% số lần vượt không?', 'thấp hơn'],
      ['AUC', 'Tháng vượt có được xếp trên tháng không vượt không?', 'cao hơn'],
      ['Tỉ lệ phát hiện ở mức báo nhầm cố định', 'Bao nhiêu phần lần vượt được báo trước?', 'cao hơn'],
      ['Trung vị số ngày báo trước', 'Cảnh báo đến trước bao nhiêu ngày?', 'cao hơn'],
    ], null, 'LLC'));
  add(H2('So sánh thống kê và cài đặt'));
  add(body(r`Điểm Brier được lấy trung bình theo từng người dùng trước, để người có lịch sử dài không lấn át kết quả. Mỗi chênh lệch giữa hai phương pháp được báo cáo kèm khoảng tin cậy 95% từ 2.000 lần lấy mẫu lại bootstrap theo người dùng [@efron]. Thực nghiệm viết bằng Python 3.13 với NumPy, pandas, SciPy và hồi quy phân vị của scikit-learn (bộ giải HiGHS); một lượt chạy với ba mức ngân sách mất khoảng tám phút trên máy tính xách tay, với cả dữ liệu ngân hàng lẫn dữ liệu thẻ. Bản Python của M1 làm theo mã Dart của FlowMoney (trung vị trên tối đa sáu kỳ có chi, quay về M0 khi dưới ba kỳ), và mục VI-E đối chiếu nó với chính mã ấy. Hai giản lược giúp lượt chạy ngắn. M3 được khớp lại sáu tháng một lần trên mẫu con ngẫu nhiên 4.000 dòng; với 12.000 dòng, điểm Brier của nó trên dữ liệu ngân hàng ở $\kappa=1,0$ chỉ đổi từ 0,1716 xuống 0,1707, nên cỡ mẫu con không làm đổi thứ hạng. M2 chỉ dùng dạng chuẩn. Mã nguồn, hạt giống ngẫu nhiên và kết quả lưu trong kho mã của dự án.`));

  // VI
  add(H1('Kết quả và thảo luận'));
  add(H2('Giả thuyết'));
  add(body(r`Ba giả thuyết được viết trước khi chạy bất kỳ thực nghiệm nào.`));
  add(bullet(r`H1 (RQ1). M3 có điểm Brier và sai số hiệu chuẩn thấp nhất. M1 gần ngang về độ chính xác điểm, nhưng xác suất của nó thô vì chỉ nhận tối đa $K+1$ giá trị.`));
  add(bullet(r`H2 (RQ2). Ở tỉ lệ báo nhầm 10%, M1 và M3 báo sớm hơn M0 vài ngày với người chi dồn đầu kỳ. M2 kém với kiểu chi dồn đầu kỳ nhưng thích nghi nhanh nhất sau khi thói quen chi thay đổi.`));
  add(bullet(r`H3 (RQ3). Chênh lệch lớn nhất ở giữa tháng và với ngân sách chặt; tới ngày 25 các phương pháp gần như như nhau.`));
  add(H2('Kết quả trên dữ liệu ngân hàng'));
  add(body(r`Ở $\kappa=1,0$ có 478.778 dự báo được chấm trên 120.358 tháng-tài khoản, 27,8% trong số đó thuộc các tháng kết thúc bằng vượt ngân sách. M1 phải quay về M0 ở 0,9% số dự báo. Với M2, $\lambda=0,002$ cho điểm Brier kiểm định thấp nhất (0,207), tương ứng chu kỳ bán rã khoảng một năm. Bảng III ghi kết quả.`));
  add(TABLE('Kết quả trên dữ liệu ngân hàng (κ = 1,0)', [900, 520, 560, 500, 520, 620, 600, 820],
    ['Phương pháp', 'Brier', 'Log loss', 'AUC', 'ECE', 'Báo nhầm', 'Phát hiện', 'Báo trước (ngày)'],
    [
      ['M0', '0,180', '0,540', '0,720', '0,066', '0,080', '0,20', '5'],
      ['M1', '0,169', '0,512', '0,760', '0,062', '0,042', '0,21', '5'],
      ['M2', '0,211', '0,627', '0,657', '0,116', '0,096', '0,17', '6'],
      ['M3', '0,172', '0,515', '0,761', '0,040', '0,096', '0,20', '5'],
    ],
    r`Gộp mọi mốc. Tỉ lệ báo nhầm, tỉ lệ phát hiện và trung vị số ngày báo trước lấy tại ngưỡng có tỉ lệ phát hiện cao nhất mà tỉ lệ báo nhầm không quá 10%; ngưỡng kế tiếp của M1 nhảy lên 10,2%.`));
  add(body(r`M1 có điểm Brier (0,169) và log loss (0,512) thấp nhất, M3 theo sát (0,172 và 0,515) với AUC gần như bằng (0,761 so với 0,760). Tính trung bình theo người dùng, M3 trừ M1 bằng 0,0018 điểm Brier, khoảng tin cậy 95% từ 0,0010 đến 0,0025, nghĩa là quy tắc trung vị tốt hơn với cách biệt nhỏ nhưng có ý nghĩa thống kê; M3 tốt hơn ở 49% số người dùng. Cả hai đều hơn hẳn M0, lần lượt 0,008 (M3) và 0,010 (M1), khoảng tin cậy cách xa 0. M2 kém nhất ở mọi chỉ số, và điểm Brier của nó không cải thiện từ ngày 5 tới ngày 15 (0,228 và 0,230) trong khi mọi phương pháp khác đều cải thiện.`));
  add(body(r`Hình 3 cho thấy độ hiệu chuẩn. M3 bám đường chéo tới xác suất khoảng 0,4 và báo cao quá mức ở trên đó (dự báo quanh 0,78 thì thực tế chỉ 50% số trường hợp vượt). M0 và M1 báo quá ít hơn ở vùng xác suất cao (0,77 so với 0,58) nhưng không đều ở vùng thấp vì chỉ nhận bảy giá trị. M2 báo thấp ở vùng rủi ro thấp nhất và báo cao quá mức ở phần còn lại.`));
  add(TABLE('Điểm Brier / ECE theo mức ngân sách, có và không có khoản cố định', [700, 720, 720, 720, 720, 720, 720],
    ['Phương pháp', 'Đủ, κ=0,9', 'Đủ, 1,0', 'Đủ, 1,1', 'Bỏ cố định, 0,9', 'Bỏ cố định, 1,0', 'Bỏ cố định, 1,1'],
    [
      ['M0', '0,197/ 0,068', '0,180/ 0,066', '0,166/ 0,052', '0,199/ 0,076', '0,183/ 0,069', '0,171/ 0,061'],
      ['M1', '0,176/ 0,060', '0,169/ 0,062', '0,157/ 0,060', '0,186/ 0,089', '0,177/ 0,086', '0,167/ 0,085'],
      ['M2', '0,228/ 0,103', '0,211/ 0,116', '0,189/ 0,113', '0,208/ 0,091', '0,196/ 0,101', '0,181/ 0,100'],
      ['M3', '0,183/ 0,046', '0,172/ 0,040', '0,153/ 0,032', '0,181/ 0,034', '0,170/ 0,036', '0,155/ 0,030'],
    ],
    r`"Bỏ cố định" loại các khoản trả nợ vay và chi định kỳ hộ gia đình khỏi chi tiêu. Tỉ lệ vượt ngân sách: 34,1%, 27,8%, 23,3% (đủ) và 30,7%, 26,4%, 23,2% (bỏ cố định).`));
  add(body(r`Bảng IV cho thấy thứ hạng dịch chuyển ra sao. M1 có điểm Brier thấp nhất ở ngân sách chặt và trung tính, M3 ở ngân sách rộng (0,153 so với 0,157). M3 có sai số hiệu chuẩn thấp nhất ở cả sáu cấu hình. Khi bỏ các khoản trả nợ vay và chi định kỳ hộ gia đình, M3 có điểm Brier thấp nhất ở cả ba mức còn M1 kém đi (0,177 so với 0,169 ở $\kappa=1,0$). Như vậy lợi thế của quy tắc trung vị trên dữ liệu đầy đủ có vẻ đến từ các khoản cố định lặp lại cùng thời điểm mỗi tháng, thứ mà trung vị của các kỳ trước nắm được trực tiếp.`));
  add(body(r`Hình 4 cho thấy phép đánh đổi khi cảnh báo. Trên dữ liệu này, cảnh báo sớm khó với mọi phương pháp: ở tỉ lệ báo nhầm không quá 10%, tỉ lệ phát hiện chỉ 17% đến 21% và trung vị số ngày báo trước là năm hoặc sáu ngày (Bảng III). M1 có tỉ lệ phát hiện cao nhất trên phần lớn dải; ở tỉ lệ báo nhầm khoảng 11%, nó bắt được 33% số lần vượt so với 22% của M3, và ở khoảng 24% thì bắt được 50% so với khoảng 42%. Trung vị số ngày báo trước chỉ đạt mười ngày khi tỉ lệ báo nhầm trên 50%.`));
  add(FIG('fig3_reliability.png', 300, 291, r`Biểu đồ độ tin cậy tại ngày 15 trên dữ liệu ngân hàng ($\kappa=1,0$), mười nhóm cùng số dự báo. Đường nét đứt là hiệu chuẩn hoàn hảo.`));
  add(FIG('fig4_warning.png', 300, 291, r`Phép đánh đổi khi cảnh báo trên dữ liệu ngân hàng ($\kappa=1,0$): (a) tỉ lệ phát hiện và (b) trung vị số ngày báo trước theo tỉ lệ báo nhầm khi thay đổi $p^{*}$.`));
  add(H2('Kết quả trên dữ liệu thẻ'));
  add(body(r`Ở $\kappa=1,0$, dữ liệu thẻ cho 310.973 dự báo được chấm trên 65.734 tháng-người dùng, 44,3% thuộc các tháng kết thúc bằng vượt ngân sách, và M1 phải quay về M0 ở 0,02% số dự báo. $\lambda=0,01$ được chọn (Brier kiểm định 0,151). Bảng V ghi kết quả. Thứ hạng đảo ngược so với dữ liệu ngân hàng. M3 tốt nhất ở mọi chỉ số, nhưng M2 theo rất sát (Brier 0,148 so với 0,149, AUC 0,864 so với 0,863), và cả hai đều hơn hẳn M1 và M0. Thứ tự này giữ nguyên ở ngân sách chặt (Brier 0,138, 0,139, 0,155 và 0,168 lần lượt của M3, M2, M1, M0), ở ngân sách rộng (0,124, 0,125, 0,139 và 0,166), và ở mọi mốc. Tính trung bình theo người dùng, M3 trừ M1 bằng -0,0177 điểm Brier (khoảng tin cậy 95% từ -0,0184 đến -0,0171), và M3 tốt hơn ở 94% số người dùng. M2 hơn M1 0,017 (khoảng từ 0,016 đến 0,017), còn M1 hơn M0 0,012.`));
  add(TABLE('Kết quả trên dữ liệu thẻ (κ = 1,0)', [900, 520, 560, 500, 520, 620, 600, 820],
    ['Phương pháp', 'Brier', 'Log loss', 'AUC', 'ECE', 'Báo nhầm', 'Phát hiện', 'Báo trước (ngày)'],
    [
      ['M0', '0,177', '0,538', '0,812', '0,062', 'không có', 'không có', 'không có'],
      ['M1', '0,166', '0,501', '0,828', '0,030', '0,062', '0,68', '9'],
      ['M2', '0,149', '0,454', '0,863', '0,024', '0,098', '0,78', '12'],
      ['M3', '0,148', '0,450', '0,864', '0,005', '0,089', '0,77', '12'],
    ],
    r`Bố cục như Bảng III. M0 không có ngưỡng nào phát được cảnh báo ở tỉ lệ báo nhầm không quá 10%.`));
  add(body(r`M3 gần như hiệu chuẩn hoàn hảo (ECE 0,005 ở $\kappa=1,0$ và không quá 0,005 ở mọi mức ngân sách; Hình 5). M1 báo cao quá mức ở vùng xác suất khoảng 0,3 đến 0,8, M2 báo thấp ở vùng rủi ro thấp và báo cao ở vùng rủi ro cao, còn M0 báo cao quá mức trên cả nửa trên của dải. Cảnh báo ở đây tốt hơn nhiều so với dữ liệu ngân hàng (Hình 6). Ở tỉ lệ báo nhầm không quá 10%, M2 và M3 bắt được 78% và 77% số lần vượt với trung vị sớm 12 ngày, so với 68% và chín ngày của M1. M0 không phát cảnh báo nào trong vùng này. Ở tỉ lệ báo nhầm 2%, M3 vẫn bắt được 60% số lần vượt, sớm tám ngày, và M2 khoảng 54%, trong khi M1 không phát cảnh báo nào.`));
  add(FIG('fig5_reliability.png', 300, 291, r`Biểu đồ độ tin cậy tại ngày 15 trên dữ liệu thẻ ($\kappa=1,0$).`));
  add(FIG('fig6_warning.png', 300, 291, r`Phép đánh đổi khi cảnh báo trên dữ liệu thẻ ($\kappa=1,0$).`));
  add(H2('Kết quả trên tập mô phỏng'));
  add(body(r`Lượt chạy mô phỏng cho 225.889 dự báo được chấm ở $\kappa=1,0$, 44% thuộc các tháng kết thúc bằng vượt ngân sách; $\lambda=0,01$ được chọn. Bảng VI ghi kết quả. Ở đây M3 chính xác nhất ở mọi mức ngân sách (Brier 0,120, 0,125 và 0,103 lần lượt với $\kappa$ = 0,9, 1,0 và 1,1) và ở mọi mốc, sai số hiệu chuẩn dưới 0,02. Theo người dùng, M3 hơn M1 0,013 (khoảng tin cậy 95% từ 0,013 đến 0,014), còn M1 và M0 không khác nhau có ý nghĩa (khoảng từ -0,001 đến 0,001).`));
  add(TABLE('Kết quả trên tập mô phỏng (κ = 1,0)', [900, 520, 560, 500, 520, 620, 600, 820],
    ['Phương pháp', 'Brier', 'Log loss', 'AUC', 'ECE', 'Báo nhầm', 'Phát hiện', 'Báo trước (ngày)'],
    [
      ['M0', '0,138', '0,434', '0,879', '0,042', 'không có', 'không có', 'không có'],
      ['M1', '0,138', '0,429', '0,881', '0,045', '0,044', '0,78', '9'],
      ['M2', '0,172', '0,504', '0,850', '0,105', '0,097', '0,81', '13'],
      ['M3', '0,125', '0,387', '0,903', '0,017', '0,098', '0,87', '13'],
    ],
    r`Bố cục như Bảng III. M0 không có ngưỡng nào phát được cảnh báo ở tỉ lệ báo nhầm không quá 10%.`));
  add(body(r`Theo kiểu chi tiêu, M2 kém nhất với người chi dồn đầu kỳ (Brier 0,240 ở A2, so với 0,096 đến 0,110 của các phương pháp khác) và nhỉnh hơn M3 một chút với người chi đều (0,131 so với 0,135 ở A1). M0 hơn M1 ở A2 (0,099 so với 0,110): theo định nghĩa (3), M0 học tỉ số sai số từ các kỳ trước, nên nó cũng nắm được khoản tiền nhà ngày mùng 1. Cảnh báo ở đây dễ hơn nhiều so với dữ liệu ngân hàng; ở tỉ lệ báo nhầm khoảng 10%, M3 bắt được 87% số lần vượt với trung vị sớm 13 ngày (Hình 8).`));
  add(FIG('fig7_reliability.png', 300, 291, r`Biểu đồ độ tin cậy tại ngày 15 trên tập mô phỏng ($\kappa=1,0$).`));
  add(FIG('fig8_warning.png', 300, 291, r`Phép đánh đổi khi cảnh báo trên tập mô phỏng ($\kappa=1,0$). M0 và M1 chỉ có bảy mức xác suất nên đường cong của chúng ít điểm.`));
  add(H2('Đối chiếu với mã của ứng dụng'));
  add(body(r`Để chắc M1 được đánh giá đúng là quy tắc ứng dụng đang chạy, chúng tôi lấy ngẫu nhiên 20.000 dự báo có $K\ge3$ từ mỗi bộ dữ liệu ngân hàng và dữ liệu thẻ, rồi chạy nguyên hàm Dart của FlowMoney trên chúng, không sửa gì. Ứng dụng xếp mỗi giao dịch vào kỳ theo thời điểm nó được ghi, còn mã Python cộng tiền chi của một ngày vào cuối ngày ấy. Khi mọi giao dịch được đặt lúc 23:59:59, hai bên khớp ở cả 40.000 trường hợp về $K$, $r_{t}^{med}$, tỉ lệ đã chi trung vị và quyết định vượt ngân sách. Nếu đặt lúc 0 giờ, 18,8% trường hợp của dữ liệu ngân hàng lệch $r_{t}^{med}$ và 2,9% lệch quyết định. Với giờ thật trong dữ liệu thẻ, 57,5% trường hợp lệch, trung vị mức lệch là 1,0% ngân sách, và 2,1% quyết định thay đổi. Xác suất (4) và con số dự phóng của ứng dụng cho cùng một quyết định ($p_{t}>0,5$ so với $S_{t}+r_{t}^{med}>B$) mỗi khi $K$ lẻ. Khi $K$ chẵn, trung vị là trung bình của hai giá trị giữa, và quyết định lệch ở 5,6% trường hợp của dữ liệu ngân hàng và 6,7% của dữ liệu thẻ.`));
  add(H2('Đối chiếu giả thuyết'));
  add(body(r`H1 đúng trên dữ liệu thẻ và tập mô phỏng nhưng không đúng trên dữ liệu ngân hàng, nơi M1 chính xác hơn M3 một chút. Vế hiệu chuẩn của H1 đúng trên cả ba: M3 có sai số hiệu chuẩn thấp nhất ở mọi cấu hình. H2 không được dữ liệu ngân hàng ủng hộ: ở tỉ lệ báo nhầm 10%, M1 và M3 không báo sớm hơn M0 (năm và bốn ngày so với năm). Trên dữ liệu thẻ, M0 không phát cảnh báo nào ở tỉ lệ ấy trong khi M3 báo trước trung vị 12 ngày, nhưng người dùng thẻ không chi dồn đầu kỳ nên kết quả này không kiểm được giả thuyết như đã viết. M2 đúng là thất bại với kiểu chi dồn đầu kỳ, và cũng thất bại trên dữ liệu ngân hàng vốn dồn cục, còn trên dữ liệu thẻ nó gần ngang M3. H3 bị bác bỏ. Trên dữ liệu ngân hàng, M3 càng có lợi khi ngân sách càng rộng chứ không phải càng chặt, và M1 chính xác ít nhất bằng M3 ở mọi mốc, cách biệt lớn nhất ở ngày 20 (0,141 so với 0,146). Trên dữ liệu thẻ, khoảng cách giữa M3 và M1 giữ trong khoảng 0,017 đến 0,019 từ ngày 5 tới ngày 25 thay vì thu hẹp, và gần như bằng nhau ở mọi mức ngân sách (0,015 đến 0,018).`));
  add(body(r`Bộ sinh dữ liệu của chúng tôi chi một ít mỗi ngày với nhiễu trơn, hợp với một mô hình gộp đọc tỉ lệ đã chi và phần kỳ đã trôi. Tài khoản trong bộ Berka chỉ chi khoảng hai ngày mỗi tháng, và phần lớn là cùng một khoản chi định kỳ tháng nào cũng có. Trung vị trên các tháng trước của chính tài khoản nắm được cấu trúc ấy trực tiếp, còn một mô hình tuyến tính dùng chung cho mọi tài khoản thì không. Người dùng thẻ chi gần như mỗi ngày và chỉ khoảng một phần sáu số tiền là khoản lặp lại, và ở đó mô hình gộp thắng giống như trên bộ sinh dữ liệu của chúng tôi, còn EWMA, vốn bám theo mức chi hằng ngày, tốt gần bằng. Xét cả ba bộ dữ liệu, M1 chỉ hơn M3 khi phần lớn chi tiêu là cùng một khoản trả vào cùng thời điểm mỗi tháng.`));
  add(H2('Hạn chế của nghiên cứu'));
  add(body(r`Khách hàng trong bộ Berka là khách của một ngân hàng Séc những năm 1990, và chi tiêu của họ dồn cục hơn nhiều so với người ghi từng khoản mua sắm vào ứng dụng. Ngân sách là do chúng tôi dựng, không do người dùng tự đặt. Giao dịch ghi nợ có cả các khoản chuyển tiền không phải tiêu dùng. Đánh giá ngoại tuyến không đo được người dùng phản ứng thế nào với cảnh báo; một cảnh báo có thể khiến người dùng tránh được chính lần vượt mà nó dự báo, nên số ngày báo trước đo được chỉ mô tả phương pháp dự báo, không nói lên tác động tới hành vi. Dữ liệu thẻ là dữ liệu mô phỏng: nó mô tả người dùng của bộ sinh dữ liệu IBM, vốn chi đều hơn dữ liệu ngân hàng và có thể đều hơn cả người dùng thẻ thật. Bản Python của M1 chỉ khớp tuyệt đối với mã Dart khi giao dịch được đặt vào cuối ngày; với giờ ghi thật, khoảng 2% quyết định khác nhau. $\lambda$ được chọn trên lưới tám giá trị, và mỗi lượt chạy chỉ dùng một hạt giống ngẫu nhiên.`));

  // VII
  add(H1('Tích hợp vào FlowMoney'));
  add(body(r`Kết quả không chỉ ra một bộ máy duy nhất. Trên dữ liệu ngân hàng, M1 chính xác ngang M3 và có tỉ lệ phát hiện cao nhất ở vùng báo nhầm thấp; trên dữ liệu thẻ, M3 tốt hơn ở mọi chỉ số và báo sớm hơn ba ngày, còn M2, chỉ cần giữ hai giá trị trung bình trượt cho mỗi người dùng, theo rất sát nó. M1 không cần huấn luyện và vốn đã chạy trên điện thoại, nơi FlowMoney lưu mọi giao dịch trong cơ sở dữ liệu SQLite và đồng bộ với máy chủ ở chế độ nền. Điểm yếu của nó là độ hiệu chuẩn, điều quan trọng nếu xác suất được hiện cho người dùng dưới dạng phần trăm. Một hướng thận trọng là giữ M1 làm mặc định và ánh xạ bảy mức xác suất của nó sang tỉ lệ vượt quan sát được ở các tháng trước (bước này chưa kiểm trong bài), để con số phần trăm trên màn hình phản ánh đúng thực tế. M3 trở thành lựa chọn tốt hơn khi ứng dụng có đủ dữ liệu của chính mình để thấy người dùng chi tiêu giống người dùng thẻ hơn là giống khách hàng ngân hàng. Xác suất vượt ngân sách sẽ được tính lại mỗi khi lưu giao dịch và trong lượt quét nền hằng ngày vốn dùng để sinh thông báo, hiện cạnh nhãn nhịp chi, và mỗi kỳ chỉ gửi một thông báo vào lần đầu $p_{t}$ vượt $p^{*}$, kèm khoá chống trùng theo kỳ như các nhắc nhở khác của ứng dụng. Hệ số của M3 có thể huấn luyện ngoài máy và đóng gói thành hằng số sinh sẵn, giống cách ứng dụng đang đóng gói trọng số của bộ định tuyến câu hỏi, nên không giao dịch nào rời khỏi điện thoại. Nghiên cứu này không sửa mã của ứng dụng; phần tích hợp là đề xuất.`));

  // VIII
  add(H1('Phần việc còn lại'));
  add(TABLE('Tiến độ', [1000, 4040],
    ['Ngày (2026)', 'Công việc'],
    [
      ['09/11', 'Thiết kế; chạy trên dữ liệu ngân hàng, dữ liệu thẻ và tập mô phỏng; phân tích độ nhạy; khoảng tin cậy bootstrap; đối chiếu M1 với mã Dart; mở rộng lưới λ (đã xong).'],
      ['10/11', 'M2 dạng log-chuẩn.'],
      ['11/11', 'Cách chia giữ riêng người dùng; khớp lại M3 hằng tháng với mẫu lớn hơn.'],
      ['12/11', 'Hiệu chuẩn lại xác suất của M1 trên các tháng trước.'],
      ['13/11', 'Bảng theo từng mốc và mức ngân sách; nhiều hạt giống ngẫu nhiên; soát tài liệu tham khảo.'],
      ['14/11', 'Bài hoàn chỉnh.'],
    ], null, 'LL'));

  // IX
  add(H1('Kết luận'));
  add(body(r`Bài đặt bài toán cảnh báo sớm vượt ngân sách thành dự báo xác suất cho phần tiền còn chi và so sánh bốn phương pháp, từ quy tắc chia đều tới hồi quy phân vị huấn luyện trên dữ liệu của mọi người dùng, trên dữ liệu ngân hàng công khai, dữ liệu thẻ mô phỏng và một tập người dùng mô phỏng. Trên dữ liệu ngân hàng, quy tắc trung vị nhịp chi mà FlowMoney đang dùng chính xác hơn hồi quy phân vị một chút và cảnh báo tốt nhất. Trên dữ liệu thẻ, trên tập mô phỏng và trên dữ liệu ngân hàng khi bỏ các khoản chi cố định, hồi quy phân vị thắng, và nó hiệu chuẩn tốt nhất ở mọi nơi. Cảnh báo sớm được bao lâu tuỳ vào dữ liệu: ở tỉ lệ báo nhầm 10%, khoảng một phần năm số lần vượt được báo trước vài ngày trên dữ liệu ngân hàng, còn trên dữ liệu thẻ là ba phần tư, sớm 12 ngày. Bản cài đặt quy tắc trung vị của chúng tôi tái hiện đúng mã của ứng dụng. Với ứng dụng, điều này có nghĩa là trước mắt giữ quy tắc trung vị, hiệu chuẩn xác suất của nó trước khi hiện cho người dùng, và chuyển sang mô hình phân vị nếu người dùng của chính ứng dụng hoá ra chi tiêu giống người dùng thẻ.`));

  add(H1('Lời cảm ơn', false));
  add(body(r`Nhóm tác giả cảm ơn ThS. Huỳnh Nam đã hướng dẫn trong quá trình thực hiện đề tài.`));
  add(H1('Tài liệu tham khảo', false));
  add(REFLIST());
};
