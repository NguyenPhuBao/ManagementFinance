import 'van_ban.dart';

/// Chính sách bảo mật FlowMoney v1.0 — sinh nguyên văn từ `docs/superpowers/specs/2026-11-16-van-ban-dieu-khoan-chinh-sach.md`
/// (người dùng duyệt 2026-11-16; dựng lại từ `docs/Rule_Project/Chinh_sach_bao_mat_v1.md`, tệp ấy chỉ đọc).
final kChinhSachBaoMat = VanBan(
  ma: 'bao-mat',
  tenNgan: 'Chính sách bảo mật',
  tieuDe: 'Chính sách bảo mật và xử lý dữ liệu cá nhân của FlowMoney',
  phienBan: '1.0',
  ngayHieuLuc: DateTime(2026, 11, 16),
  moDau: 'Chính sách này mô tả cách nhóm phát triển FlowMoney ("FlowMoney", "chúng tôi") thu thập, sử '
      'dụng, lưu trữ, chia sẻ và bảo vệ dữ liệu cá nhân của bạn khi bạn sử dụng ứng dụng FlowMoney, '
      'cũng như các quyền của bạn đối với dữ liệu đó. Chính sách được xây dựng theo pháp luật Việt Nam '
      'về bảo vệ dữ liệu cá nhân và là một phần của Điều khoản sử dụng FlowMoney.',
  muc: const [
    MucVanBan('1. Phạm vi áp dụng', [
      KhoiVanBan.doan('Chính sách áp dụng cho dữ liệu cá nhân được xử lý qua ứng dụng FlowMoney trên điện thoại và máy '
          'chủ phục vụ ứng dụng.'),
    ]),
    MucVanBan('2. Dữ liệu chúng tôi thu thập', [
      KhoiVanBan.tieuDeCon('2.1. Dữ liệu được lưu trên máy chủ'),
      KhoiVanBan.gach('Thông tin tài khoản: email, tên đăng nhập, họ tên, số điện thoại, địa chỉ (nếu bạn nhập). Mật '
          'khẩu được lưu ở dạng băm một chiều, không ai đọc được.'),
      KhoiVanBan.gach('Dữ liệu tài chính bạn tự nhập: giao dịch thu chi, ví, ngân sách, hóa đơn, mục tiêu tiết kiệm, '
          'danh mục và dữ liệu nhóm gia đình.'),
      KhoiVanBan.gach('Dữ liệu thanh toán khi bạn mua gói Premium: mã đơn, số tiền, trạng thái đơn. Việc thanh toán do '
          'cổng thanh toán xử lý; chúng tôi không lưu thông tin thẻ hay tài khoản ngân hàng của bạn.'),
      KhoiVanBan.gach('Dữ liệu truy cập: tên thiết bị, địa chỉ IP, thời điểm đăng nhập và sử dụng, nhật ký thao tác.'),
      KhoiVanBan.doan('Dữ liệu tài chính và dữ liệu truy cập thuộc nhóm dữ liệu cá nhân nhạy cảm. Chúng tôi thông báo '
          'để bạn biết các dữ liệu này đang được xử lý.'),
      KhoiVanBan.tieuDeCon('2.2. Dữ liệu chỉ xử lý trên thiết bị của bạn'),
      KhoiVanBan.doan('Các dữ liệu sau chỉ được xử lý khi bạn bật chức năng tương ứng, và không được gửi lên máy chủ:'),
      KhoiVanBan.gach('nội dung thông báo biến động số dư của các ứng dụng ngân hàng, ví điện tử được hỗ trợ (hiện có '
          'MB Bank, MoMo, ZaloPay);'),
      KhoiVanBan.gach('ảnh biên lai bạn chia sẻ vào ứng dụng và ảnh hóa đơn bạn chụp để quét;'),
      KhoiVanBan.gach('thời gian bạn sử dụng ứng dụng ngân hàng, dùng để nhắc bạn ghi giao dịch.'),
      KhoiVanBan.doan('Chỉ những giao dịch bạn kiểm tra và bấm Lưu mới được đồng bộ lên máy chủ như mọi giao dịch '
          'khác. Chức năng nhập bằng giọng nói sử dụng dịch vụ nhận dạng giọng nói của điện thoại.'),
    ]),
    MucVanBan('3. Mục đích xử lý', [
      KhoiVanBan.gach('Cung cấp các chức năng của ứng dụng: lưu, đồng bộ và thống kê dữ liệu tài chính của bạn trên '
          'các thiết bị.'),
      KhoiVanBan.gach('Bảo vệ tài khoản: phát hiện đăng nhập bất thường, ngăn chặn tấn công, điều tra sự cố an ninh.'),
      KhoiVanBan.gach('Trợ lý AI: khi có kết nối mạng và bạn bật trợ lý trực tuyến, câu hỏi của bạn được gửi tới dịch '
          'vụ AI đám mây để trả lời. Gợi ý danh mục, đọc hóa đơn bằng ảnh và mô hình AI tải về máy được xử '
          'lý ngay trên điện thoại.'),
      KhoiVanBan.gach('Gửi email xác thực, thông báo về tài khoản và thông báo hệ thống.'),
      KhoiVanBan.doan('Chúng tôi không bán dữ liệu của bạn và không sử dụng dữ liệu của bạn cho mục đích quảng cáo.'),
    ]),
    MucVanBan('4. Căn cứ xử lý', [
      KhoiVanBan.doan('Chúng tôi xử lý dữ liệu cá nhân dựa trên: sự đồng ý của bạn khi đăng ký và khi bật từng chức '
          'năng; nhu cầu thực hiện Dịch vụ theo Điều khoản sử dụng; và nghĩa vụ theo quy định của pháp '
          'luật.'),
    ]),
    MucVanBan('5. Chia sẻ dữ liệu và bên xử lý', [
      KhoiVanBan.gach('Dữ liệu được xử lý bởi các nhà cung cấp mà FlowMoney sử dụng: hạ tầng máy chủ và cơ sở dữ liệu, '
          'dịch vụ AI đám mây, dịch vụ gửi email và cổng thanh toán. Các bên này chỉ xử lý dữ liệu trong '
          'phạm vi cần thiết để cung cấp dịch vụ cho FlowMoney.'),
      KhoiVanBan.gach('Thành viên trong nhóm gia đình bạn tham gia được xem dữ liệu chung của nhóm.'),
      KhoiVanBan.gach('Chúng tôi cung cấp dữ liệu cho cơ quan nhà nước có thẩm quyền khi pháp luật yêu cầu.'),
    ]),
    MucVanBan('6. Lưu trữ và chuyển dữ liệu ra nước ngoài', [
      KhoiVanBan.doan('Dữ liệu được lưu trên máy chủ đám mây đặt ngoài lãnh thổ Việt Nam (khu vực châu Á). Bằng việc '
          'đồng ý với Chính sách này, bạn đồng ý cho việc chuyển dữ liệu cá nhân ra nước ngoài nhằm mục '
          'đích cung cấp Dịch vụ.'),
    ]),
    MucVanBan('7. Thời gian lưu giữ', [
      KhoiVanBan.gach('Dữ liệu tài khoản: trong suốt thời gian bạn sử dụng ứng dụng.'),
      KhoiVanBan.gach('Khi bạn yêu cầu xóa tài khoản: tài khoản ở trạng thái chờ xóa 30 ngày, trong thời gian này bạn '
          'có thể hủy yêu cầu. Hết 30 ngày, thông tin định danh bị xóa hoặc ẩn danh.'),
      KhoiVanBan.gach('Dữ liệu tài chính (giao dịch, ví, ngân sách, hóa đơn): lưu tối thiểu 5 năm, kể cả sau khi tài '
          'khoản bị xóa, sau đó được ẩn danh hoặc xóa.'),
      KhoiVanBan.gach('Địa chỉ IP đầy đủ: lưu 365 ngày kể từ lần truy cập cuối, sau đó tự xóa; chỉ giữ lại dạng đã che '
          '(ví dụ 113.161.xx.xx).'),
      KhoiVanBan.gach('Nhật ký thao tác: lưu tối thiểu 12 tháng.'),
    ]),
    MucVanBan('8. Bảo mật dữ liệu', [
      KhoiVanBan.gach('Dữ liệu được mã hóa khi truyền giữa ứng dụng và máy chủ. Số điện thoại, địa chỉ và địa chỉ IP '
          'đầy đủ được mã hóa khi lưu.'),
      KhoiVanBan.gach('Chỉ bạn và các thành viên nhóm gia đình (đối với dữ liệu chung của nhóm) xem được dữ liệu tài '
          'chính. Quản trị viên chỉ thấy thông tin đã che bớt; việc xem địa chỉ IP đầy đủ để điều tra sự '
          'cố phải xác thực bằng mã PIN và mỗi lần xem đều được ghi lại.'),
      KhoiVanBan.gach('Bạn có thể bật khóa ứng dụng bằng mã PIN hoặc vân tay để bảo vệ dữ liệu trên điện thoại.'),
    ]),
    MucVanBan('9. Quyền của bạn', [
      KhoiVanBan.doan('Bạn có quyền:'),
      KhoiVanBan.gach('được biết về việc xử lý dữ liệu cá nhân của mình;'),
      KhoiVanBan.gach('truy cập, xem và chỉnh sửa thông tin của mình trong ứng dụng;'),
      KhoiVanBan.gach('nhận bản sao dữ liệu của mình tại Cá nhân → Dữ liệu của tôi;'),
      KhoiVanBan.gach('tắt các chức năng xử lý dữ liệu trên thiết bị (đọc biến động số dư, nhắc ghi giao dịch, trợ lý '
          'trực tuyến) bất cứ lúc nào trong Cài đặt;'),
      KhoiVanBan.gach('rút lại sự đồng ý và yêu cầu xóa tài khoản;'),
      KhoiVanBan.gach('khiếu nại khi quyền lợi bị xâm phạm.'),
      KhoiVanBan.doan('Gửi yêu cầu tới phubao12as@gmail.com. Chúng tôi phản hồi trong thời hạn pháp luật quy định.'),
    ]),
    MucVanBan('10. Trẻ em', [
      KhoiVanBan.doan('FlowMoney không dành cho người chưa đủ 16 tuổi khi chưa có sự đồng ý của cha, mẹ hoặc người '
          'giám hộ. Nếu phát hiện dữ liệu của trẻ em được cung cấp khi chưa có sự đồng ý này, chúng tôi sẽ '
          'xóa dữ liệu đó.'),
    ]),
    MucVanBan('11. Khi xảy ra sự cố dữ liệu', [
      KhoiVanBan.doan('Nếu dữ liệu bị lộ, mất hoặc bị truy cập trái phép, chúng tôi sẽ ngăn chặn, thông báo cho cơ '
          'quan chức năng trong vòng 72 giờ kể từ khi phát hiện và thông báo cho bạn nếu dữ liệu của bạn '
          'bị ảnh hưởng.'),
    ]),
    MucVanBan('12. Thay đổi Chính sách', [
      KhoiVanBan.doan('Chúng tôi có thể cập nhật Chính sách này. Phiên bản mới được đưa vào bản cập nhật của ứng dụng, '
          'kèm số phiên bản và ngày hiệu lực; bạn xem lại bất cứ lúc nào tại Cá nhân → Điều khoản & chính '
          'sách.'),
    ]),
    MucVanBan('13. Liên hệ', [
      KhoiVanBan.doan('Mọi câu hỏi về Chính sách này và về dữ liệu cá nhân của bạn xin gửi về: phubao12as@gmail.com.'),
    ]),
  ],
);
