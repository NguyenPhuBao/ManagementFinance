// Bản tiếng Việt của bài. Đánh dấu: $...$ công thức (mini-LaTeX), [@khoá] trích dẫn, *x* nghiêng, **x** đậm.
'use strict';

exports.title = 'Nghiên cứu và phát triển mô hình dự báo xác suất dựa trên trung vị, EWMA và hồi quy phân vị nhằm cảnh báo sớm nguy cơ vượt ngân sách cuối kỳ từ nhịp chi tiêu cá nhân trong ứng dụng quản lý tài chính cá nhân';
exports.authors = 'Nguyễn Phú Bảo và Trần Quang Đạt';
exports.header = 'NGHIÊN CỨU KHOA HỌC SINH VIÊN, TRƯỜNG ĐẠI HỌC CÔNG NGHIỆP TP. HỒ CHÍ MINH, BẢN THẢO, THÁNG 11/2026';
exports.footnote = 'Bản thảo gửi duyệt ngày 09/11/2026. Đề tài nghiên cứu khoa học sinh viên do ThS. Huỳnh Nam hướng dẫn. Nguyễn Phú Bảo và Trần Quang Đạt thuộc Khoa Công nghệ Thông tin, Trường Đại học Công nghiệp Thành phố Hồ Chí Minh, TP. Hồ Chí Minh, Việt Nam (e-mail: [bổ sung sau]).';

exports.build = ({ add, body, H1, H2, EQ, bullet, FIG, FIGBOX, TABLE, LABELED, REFLIST, r }) => {
  add(LABELED('Tóm tắt', 'Cảnh báo ngân sách trong ứng dụng quản lý tài chính cá nhân có thể dựng theo hai cách đơn giản: báo khi số đã chi chạm một tỉ lệ cố định của ngân sách, hoặc kéo thẳng mức chi hiện tại tới cuối tháng. Cách thứ nhất chỉ phản ứng khi tiền đã tiêu. Cách thứ hai đánh giá sai những người trả tiền nhà hay hoá đơn định kỳ vào đầu tháng. Nghiên cứu này ước lượng, tại bất kỳ ngày nào trong kỳ, xác suất tổng chi cuối kỳ vượt ngân sách, và đo xem xác suất ấy cho phép cảnh báo sớm được bao nhiêu ngày. Bài toán được đặt thành dự báo xác suất cho phần tiền còn chi tới cuối kỳ. Bốn phương pháp được so sánh: mô hình chia đều làm mốc, mô hình trung vị nhịp chi đang chạy trong ứng dụng FlowMoney, mô hình trung bình trượt có trọng số mũ cho mức chi và phương sai theo ngày, và hồi quy phân vị tuyến tính huấn luyện trên dữ liệu gộp của mọi người dùng, có sắp lại phân vị cho đơn điệu. Các phương pháp được đánh giá trên bộ giao dịch ngân hàng công khai PKDD-99 Berka và trên một tập người dùng mô phỏng có kiểu chi tiêu biết trước, theo cách đánh giá cuốn chiếu tại năm mốc mỗi tháng và ba mức chặt của ngân sách. Chất lượng xác suất được đo bằng điểm Brier, log loss, diện tích dưới đường cong ROC và sai số hiệu chuẩn kỳ vọng; độ chính xác về số tiền đo bằng sai số tuyệt đối trung bình và pinball loss; chất lượng cảnh báo đo bằng tỉ lệ phát hiện và số ngày báo trước ở một mức báo nhầm cố định. Bài cũng trình bày cách chạy phương pháp được chọn ngay trên điện thoại trong một ứng dụng offline-first. Bản thảo này trình bày thiết kế nghiên cứu; kết quả thực nghiệm sẽ bổ sung ở bản hoàn chỉnh.'));
  add(LABELED('Ý nghĩa thực tiễn', 'Một cảnh báo ngân sách chỉ có ích khi đến đủ sớm để người dùng kịp điều chỉnh và đủ hiếm để họ còn tin. Báo lúc đã tiêu hết ngân sách thì không còn gì để làm. Kéo thẳng mức chi thì tháng nào cũng báo với người trả tiền nhà ngày mùng 1, và người đó sẽ thôi đọc. Nghiên cứu này nêu nguy cơ vượt ngân sách dưới dạng một xác suất đã hiệu chuẩn, đưa ra từ sớm trong tháng, với tỉ lệ báo nhầm đo được. Các phương pháp đủ nhẹ để chạy trên điện thoại, nên dữ liệu giao dịch không phải gửi lên máy chủ. Kết quả so sánh sẽ cho nhóm phát triển biết khi nào quy tắc trung vị là đủ, và khi nào mô hình phân vị học từ dữ liệu đáng với công sức bỏ thêm.'));
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
  add(body(r`Bài có bốn đóng góp. Chúng tôi đặt bài toán cảnh báo vượt ngân sách thành dự báo xác suất cho phần tiền còn chi, và đánh giá cả xác suất lẫn cảnh báo sinh ra từ nó. Chúng tôi so sánh bốn phương pháp, trong đó có quy tắc trung vị đang chạy trong một ứng dụng thật. Một tập người dùng mô phỏng có kiểu chi biết trước được dùng để giải thích phương pháp nào thắng trong trường hợp nào. Cuối cùng, bài đưa ra hướng dẫn tính dự báo ngay trên điện thoại mà không gửi giao dịch lên máy chủ.`));
  add(body(r`Mục II điểm qua các nghiên cứu liên quan, mục III phát biểu bài toán và mục IV mô tả các phương pháp. Mục V trình bày dữ liệu và cách đánh giá, mục VI các giả thuyết và kế hoạch phân tích, mục VII cách tích hợp vào FlowMoney và mục VIII kế hoạch thực hiện. Mục IX kết luận.`));

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
  add(body(r`M1 là quy tắc FlowMoney đang dùng. Với mỗi kỳ trong $K$ kỳ đã đóng gần nhất có phát sinh chi ($3\le K\le6$), gọi $r_{k}(x)=S_{T}^{(k)}-S^{(k)}(x)$ là số tiền chi sau phần kỳ $x$. Dự báo điểm $r_{t}^{med}$ là trung vị của $r_{k}(x_{t})$ theo $k$, nên một tháng bất thường ít ảnh hưởng. Chính $K$ giá trị ấy cũng tạo thành một phân phối dự báo thực nghiệm, làm trơn như ở (3):`));
  add(EQ(r`p_{t}=\frac{\sum_{k=1}^{K}{\one[S_{t}+r_{k}(x_{t})>B]}+1/2}{K+1}.`));
  add(body(r`Với $K\le6$, xác suất này chỉ nhận tối đa bảy giá trị. Khi có ít hơn ba kỳ, ứng dụng quay về M0; chúng tôi báo cáo tần suất xảy ra trường hợp này.`));
  add(H2('M2: Tốc độ chi và độ biến động theo EWMA'));
  add(body(r`M2 làm trơn chuỗi chi theo ngày của người dùng, kể cả kỳ hiện tại tới ngày $t$, bằng một hằng số $\lambda\in(0;1]$ cho cả mức và phương sai [@riskmetrics]:`));
  add(EQ(r`\mu_{d}=\lambda y_{d}+(1-\lambda)\mu_{d-1},`));
  add(EQ(r`v_{d}=\lambda(y_{d}-\mu_{d-1})^{2}+(1-\lambda)v_{d-1}.`));
  add(body(r`Nếu coi $n=T-t$ ngày còn lại là độc lập thì $R_{t}\sim N(n\mu_{t},nv_{t})$ và`, { noIndent: true }));
  add(EQ(r`p_{t}=1-\Phi(\frac{B-S_{t}-n\mu_{t}}{\sqrt{nv_{t}}}),`));
  add(body(r`với $\Phi$ là hàm phân phối chuẩn tắc. $R_{t}$ không âm và lệch phải, nên chúng tôi thử thêm phân phối log-chuẩn có cùng kỳ vọng và phương sai. $\lambda$ được chọn trong $\{0,02;0,05;0,1;0,2\}$ trên các tháng kiểm định. M2 không biết gì về hiệu ứng lịch như tiền nhà trả ngày mùng 1. Chúng tôi dự đoán nó kém với người chi dồn đầu kỳ nhưng thích nghi nhanh nhất khi thói quen chi thay đổi.`, { noIndent: true }));
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
  add(body(r`Bộ dữ liệu chính là bộ dữ liệu tài chính PKDD-99 do một ngân hàng Séc công bố [@berka]. Bộ này có khoảng một triệu giao dịch trên 4.500 tài khoản trong giai đoạn 1993-1998, kèm các bảng tài khoản, khoản vay và lệnh chi định kỳ. Giao dịch ghi nợ được coi là khoản chi, cộng theo ngày, và mỗi tháng dương lịch là một kỳ ngân sách. Tài khoản có lịch sử dưới 18 tháng bị loại để mỗi tháng được đánh giá có ít nhất sáu tháng trước đó. Số tiền tính bằng koruna Séc và chênh lệch lớn giữa các tài khoản, nên mọi mô hình đều làm việc với tỉ lệ so với ngân sách. Một phân tích độ nhạy bỏ các khoản trả nợ vay và chi định kỳ cho hộ gia đình, để tách nghĩa vụ cố định khỏi chi tiêu tuỳ ý.`));
  add(H2('Tập người dùng mô phỏng'));
  add(body(r`Dữ liệu thật không cho biết vì sao một phương pháp thắng, nên chúng tôi sinh thêm 2.000 người dùng mô phỏng trong 36 tháng, mỗi kiểu chi tiêu 500 người. Kiểu A1 chi đều mỗi ngày. Kiểu A2 chi dồn đầu kỳ, trả 30-45% chi tiêu của tháng ngay ngày đầu. Kiểu A3 chi dồn sau ngày lương mùng 10. Kiểu A4 có một khoản mua lớn ngoài kế hoạch ở khoảng 15% số tháng. Mức chi của mỗi người trôi chậm theo thời gian. Vì biết quá trình sinh dữ liệu, có thể so độ hiệu chuẩn với xác suất vượt ngân sách thật.`));
  add(H2('Dựng ngân sách'));
  add(body(r`Dữ liệu công khai không có ngân sách. FlowMoney gợi ý hạn mức từ tổng chi trong 90 ngày gần nhất của người dùng (hoặc từ giao dịch đầu tiên nếu ngắn hơn), quy về mức mỗi tháng. Chúng tôi dùng dạng tương đương theo tháng dương lịch: ngân sách tháng $m$ là $B_{m}=\kappa(S_{m-1}+S_{m-2}+S_{m-3})/3$, với $S_{m}$ là tổng chi tháng $m$ và $\kappa\in\{0,9;1,0;1,1\}$. Ba mức cho ra ngân sách chặt, trung tính và rộng, do đó tỉ lệ vượt ngân sách khác nhau.`));
  add(H2('Quy trình đánh giá'));
  add(body(r`Việc đánh giá đi cuốn chiếu theo tháng dương lịch [@tashman]. Với tháng đánh giá $m$, mỗi phương pháp chỉ thấy dữ liệu trước tháng $m$ cộng với tháng hiện tại tới mốc dự báo. M3 được khớp lại trên dữ liệu của mọi người dùng trước tháng $m$ với cửa sổ mở rộng dần. Hằng số $\lambda$ của M2 được chọn trên 20% số tháng đánh giá đầu tiên rồi giữ cố định. Dự báo được đưa ra vào các ngày 5, 10, 15, 20 và 25. Ở một cách chia thứ hai, 30% người dùng được giữ riêng hoàn toàn để đo M3 với người dùng mới.`));
  add(H2('Chỉ số đánh giá'));
  add(body(r`Bảng II liệt kê các chỉ số. Chất lượng xác suất được đo bằng điểm Brier`));
  add(EQ(r`\text{BS}=\frac{1}{N}\sum_{i=1}^{N}{(p_{i}-o_{i})^{2}},`));
  add(body(r`log loss với xác suất kẹp trong $[10^{-3};1-10^{-3}]$, diện tích dưới đường cong ROC, và sai số hiệu chuẩn kỳ vọng trên mười nhóm có cùng số dự báo,`, { noIndent: true }));
  add(EQ(r`\text{ECE}=\sum_{b=1}^{10}{\frac{N_{b}}{N}|O_{b}-P_{b}|},`));
  add(body(r`trong đó $N_{b}$ là số dự báo trong nhóm $b$, còn $O_{b}$ và $P_{b}$ là tần suất vượt ngân sách quan sát được và xác suất dự báo trung bình trong nhóm đó. Biểu đồ độ tin cậy cho thấy cùng phép so ấy theo từng nhóm. Sai số tuyệt đối trung bình đo dự báo trung vị của $R_{t}$, còn pinball loss lấy trung bình trên $\T$ đo toàn bộ dự báo phân vị. Với cảnh báo, ngưỡng $p^{*}$ của mỗi phương pháp được đặt sao cho 10% (và riêng một lượt 20%) số tháng không vượt ngân sách nhận ít nhất một cảnh báo. Ở tỉ lệ báo nhầm đó, chúng tôi báo cáo tỉ lệ phát hiện, độ chính xác và trung vị số ngày báo trước (2).`, { noIndent: true }));
  add(TABLE('Các chỉ số đánh giá', [1500, 2640, 900],
    ['Chỉ số', 'Trả lời câu hỏi', 'Tốt hơn khi'],
    [
      ['Điểm Brier, log loss', 'Xác suất có đúng tổng thể không?', 'thấp hơn'],
      ['ECE, biểu đồ độ tin cậy', 'Khi báo 30%, có đúng 30% số lần vượt không?', 'thấp hơn'],
      ['AUC', 'Tháng vượt có được xếp trên tháng không vượt không?', 'cao hơn'],
      ['MAE, pinball loss', 'Dự báo phần còn chi sát tới đâu?', 'thấp hơn'],
      ['Tỉ lệ phát hiện ở mức báo nhầm cố định', 'Bao nhiêu phần lần vượt được báo trước?', 'cao hơn'],
      ['Trung vị số ngày báo trước', 'Cảnh báo đến trước bao nhiêu ngày?', 'cao hơn'],
    ], null, 'LLC'));
  add(H2('So sánh thống kê và cài đặt'));
  add(body(r`Điểm số được lấy trung bình theo từng người dùng trước, để người có lịch sử dài không lấn át kết quả. Mỗi chênh lệch giữa hai phương pháp được báo cáo kèm khoảng tin cậy 95% từ 2.000 lần lấy mẫu lại bootstrap theo người dùng [@efron], kiểm định Diebold–Mariano [@dm] dùng để đối chiếu thêm. Thực nghiệm viết bằng Python với pandas và hồi quy phân vị của statsmodels. Bản Python của M1 sẽ được đối chiếu với mã Dart của FlowMoney trên cùng bộ dữ liệu thử, để mốc so sánh đúng là quy tắc ứng dụng đang chạy. Mã nguồn, hạt giống ngẫu nhiên và bộ sinh dữ liệu mô phỏng lưu trong kho mã của dự án.`));

  // VI
  add(H1('Kết quả dự kiến và kế hoạch phân tích'));
  add(body(r`Các giả thuyết dưới đây định hướng việc phân tích. Đây là dự đoán, chưa phải kết quả.`));
  add(bullet(r`H1 (RQ1). M3 có điểm Brier và sai số hiệu chuẩn thấp nhất. M1 gần ngang về độ chính xác điểm, nhưng xác suất của nó thô vì chỉ nhận tối đa $K+1$ giá trị.`));
  add(bullet(r`H2 (RQ2). Ở tỉ lệ báo nhầm 10%, M1 và M3 báo sớm hơn M0 vài ngày với người chi dồn đầu kỳ (A2). M2 kém ở kiểu A2 vì tiền nhà ngày mùng 1 phá giả định các ngày như nhau, nhưng thích nghi nhanh nhất sau khi thói quen chi thay đổi.`));
  add(bullet(r`H3 (RQ3). Chênh lệch lớn nhất ở giữa tháng (ngày 10 đến 20) và với ngân sách chặt; tới ngày 25 các phương pháp gần như như nhau.`));
  add(TABLE('Bảng kết quả dự kiến (chưa điền)', [1130, 560, 560, 560, 560, 830, 840],
    ['Phương pháp', 'Brier', 'Log loss', 'AUC', 'ECE', 'Phát hiện @10% báo nhầm', 'Báo trước (ngày)'],
    [['M0', '-', '-', '-', '-', '-', '-'], ['M1', '-', '-', '-', '-', '-', '-'], ['M2', '-', '-', '-', '-', '-', '-'], ['M3', '-', '-', '-', '-', '-', '-']],
    r`Dữ liệu Berka, $\kappa=1,0$, gộp mọi mốc. Bảng theo từng mốc và từng kiểu chi tiêu dùng cùng bố cục.`));
  add(FIGBOX('[Biểu đồ độ tin cậy của M0 đến M3 tại ngày 15: sẽ bổ sung]', r`Dự kiến: tần suất vượt ngân sách quan sát được theo xác suất dự báo, mỗi phương pháp một ô.`));
  add(FIGBOX('[Trung vị số ngày báo trước theo tỉ lệ báo nhầm: sẽ bổ sung]', r`Dự kiến: số ngày báo trước theo tỉ lệ báo nhầm khi thay đổi $p^{*}$.`));
  add(body(r`Hạn chế của nghiên cứu. Khách hàng trong bộ Berka là khách của một ngân hàng Séc những năm 1990, cách chi tiêu khác người Việt dùng ví điện tử năm 2026. Ngân sách là do chúng tôi dựng, không do người dùng tự đặt. Giao dịch ghi nợ có cả các khoản chuyển tiền không phải tiêu dùng. Ngoài ra, đánh giá ngoại tuyến không đo được người dùng phản ứng thế nào với cảnh báo. Một cảnh báo có thể khiến người dùng tránh được chính lần vượt mà nó dự báo, nên số ngày báo trước đo được chỉ mô tả phương pháp dự báo, không nói lên tác động tới hành vi.`));

  // VII
  add(H1('Tích hợp vào FlowMoney'));
  add(body(r`FlowMoney lưu mọi giao dịch trong cơ sở dữ liệu SQLite trên điện thoại và đồng bộ với máy chủ ở chế độ nền. M1 vốn đã chạy trên máy, và phương án tích hợp đề xuất giữ mọi phép tính ở đó. Xác suất vượt ngân sách được tính lại mỗi khi lưu một giao dịch và trong lượt quét nền hằng ngày vốn dùng để sinh thông báo. Màn hình ngân sách hiện xác suất này cạnh nhãn nhịp chi. Mỗi kỳ chỉ gửi một thông báo, vào lần đầu $p_{t}$ vượt $p^{*}$, kèm khoá chống trùng theo kỳ như các nhắc nhở khác của ứng dụng. Hệ số của M3 được huấn luyện ngoài máy và đóng gói thành hằng số sinh sẵn, giống cách ứng dụng đang đóng gói trọng số của bộ định tuyến câu hỏi, nên không giao dịch nào rời khỏi điện thoại. Khi có ít hơn ba kỳ trước, ứng dụng dùng M2 hoặc M0. Nghiên cứu này không sửa mã của ứng dụng; phần tích hợp là đề xuất.`));

  // VIII
  add(H1('Kế hoạch thực hiện'));
  add(TABLE('Tiến độ', [1000, 4040],
    ['Ngày (2026)', 'Công việc'],
    [
      ['09/11', 'Thiết kế nghiên cứu và bản thảo (tài liệu này).'],
      ['10/11', 'Nạp và làm sạch dữ liệu Berka; bộ sinh dữ liệu mô phỏng; dựng ngân sách.'],
      ['11/11', 'M0, M1 (đối chiếu với mã Dart), M2; khung đánh giá.'],
      ['12/11', 'M3 với khớp lại cuốn chiếu; cách chia giữ riêng người dùng.'],
      ['13/11', 'Chỉ số, khoảng tin cậy bootstrap, hình, phân tích độ nhạy.'],
      ['14/11', 'Kết quả, thảo luận và bài hoàn chỉnh.'],
    ], null, 'LL'));

  // IX
  add(H1('Kết luận'));
  add(body(r`Bài đặt bài toán cảnh báo sớm vượt ngân sách thành dự báo xác suất cho phần tiền còn chi, và thiết kế phép so sánh bốn phương pháp, từ quy tắc chia đều tới hồi quy phân vị huấn luyện trên dữ liệu của mọi người dùng. Phép so sánh đo cả chất lượng xác suất lẫn số ngày báo trước của cảnh báo. Quy tắc trung vị nhịp chi của FlowMoney là mốc so sánh chính, nên kết quả sẽ cho biết một mô hình xác suất học từ dữ liệu có báo sớm hơn và ít báo nhầm hơn quy tắc ứng dụng đang dùng hay không.`));

  add(H1('Lời cảm ơn', false));
  add(body(r`Nhóm tác giả cảm ơn ThS. Huỳnh Nam đã hướng dẫn trong quá trình thực hiện đề tài.`));
  add(H1('Tài liệu tham khảo', false));
  add(REFLIST());
};
