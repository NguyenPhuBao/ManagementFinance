import 'van_ban.dart';

/// Điều khoản sử dụng FlowMoney v1.0 — sinh nguyên văn từ `docs/superpowers/specs/2026-11-16-van-ban-dieu-khoan-chinh-sach.md`
/// (người dùng duyệt 2026-11-16). Sửa chữ ở tệp ấy trước, rồi sinh / chép lại đây.
final kDieuKhoanSuDung = VanBan(
  ma: 'dieu-khoan',
  tenNgan: 'Điều khoản sử dụng',
  tieuDe: 'Điều khoản sử dụng FlowMoney',
  phienBan: '1.0',
  ngayHieuLuc: DateTime(2026, 11, 16),
  moDau: 'Chào mừng bạn đến với FlowMoney. Điều khoản sử dụng này ("Điều khoản") là thỏa thuận giữa bạn '
      'và nhóm phát triển FlowMoney ("FlowMoney", "chúng tôi") về việc sử dụng ứng dụng FlowMoney và '
      'các dịch vụ đi kèm. Vui lòng đọc kỹ trước khi tạo tài khoản. Khi đánh dấu ô đồng ý lúc đăng ký '
      'hoặc tiếp tục sử dụng ứng dụng, bạn xác nhận đã đọc, hiểu và đồng ý với Điều khoản này cùng '
      'Chính sách bảo mật của FlowMoney. Nếu không đồng ý, vui lòng không sử dụng ứng dụng.',
  muc: const [
    MucVanBan('1. Định nghĩa', [
      KhoiVanBan.gach('"Ứng dụng": ứng dụng FlowMoney trên điện thoại và máy chủ phục vụ ứng dụng.'),
      KhoiVanBan.gach('"Dịch vụ": mọi chức năng FlowMoney cung cấp qua Ứng dụng, gồm ghi chép thu chi, đồng bộ dữ '
          'liệu, thống kê, Trợ lý AI, nhóm gia đình và gói Premium.'),
      KhoiVanBan.gach('"Dữ liệu của bạn": thông tin tài khoản và dữ liệu tài chính bạn nhập hoặc tạo trong Ứng dụng.'),
      KhoiVanBan.gach('"Nhóm gia đình": nhóm nhiều tài khoản cùng quản lý một phần dữ liệu tài chính chung.'),
    ]),
    MucVanBan('2. Điều kiện sử dụng', [
      KhoiVanBan.gach('Bạn cần có năng lực hành vi dân sự để chấp nhận Điều khoản này. Người chưa đủ 16 tuổi chỉ được '
          'sử dụng khi có sự đồng ý của cha, mẹ hoặc người giám hộ.'),
      KhoiVanBan.gach('Mỗi tài khoản dành cho một cá nhân. Bạn không được chuyển nhượng, cho thuê hoặc bán tài khoản.'),
    ]),
    MucVanBan('3. Tài khoản và bảo mật', [
      KhoiVanBan.gach('Bạn cung cấp thông tin đăng ký chính xác và cập nhật khi có thay đổi.'),
      KhoiVanBan.gach('Bạn tự bảo quản mật khẩu, mã PIN khóa ứng dụng và thiết bị của mình, và chịu trách nhiệm với '
          'mọi hoạt động diễn ra trong tài khoản.'),
      KhoiVanBan.gach('Khi phát hiện tài khoản bị truy cập trái phép, bạn cần đổi mật khẩu ngay và báo cho chúng tôi '
          'theo địa chỉ ở mục 14.'),
    ]),
    MucVanBan('4. Phạm vi Dịch vụ', [
      KhoiVanBan.gach('FlowMoney là công cụ ghi chép và theo dõi tài chính. FlowMoney không phải ngân hàng, ví điện tử '
          'hay tổ chức trung gian thanh toán, không giữ tiền và không chuyển tiền thật thay bạn. Các chức '
          'năng tự động trích tiền cho mục tiêu và tự động thanh toán hóa đơn chỉ ghi giao dịch vào sổ của '
          'bạn trong Ứng dụng.'),
      KhoiVanBan.gach('Số dư, thống kê, dự báo, gợi ý và câu trả lời của Trợ lý AI chỉ mang tính tham khảo. FlowMoney '
          'không cung cấp tư vấn tài chính, đầu tư, thuế hay kế toán. Bạn tự chịu trách nhiệm về các quyết '
          'định tài chính của mình.'),
      KhoiVanBan.gach('Nội dung do AI tạo ra có thể không chính xác. Ứng dụng chỉ điền sẵn thông tin; giao dịch chỉ '
          'được ghi khi bạn kiểm tra và bấm Lưu.'),
    ]),
    MucVanBan('5. Gói dịch vụ và thanh toán', [
      KhoiVanBan.gach('Gói Basic miễn phí và có giới hạn về số ví, ngân sách, mục tiêu cùng một số tính năng.'),
      KhoiVanBan.gach('Gói Premium được trả phí theo từng kỳ. Giá và thời hạn hiển thị tại màn hình Nâng cấp trước khi '
          'bạn thanh toán. Việc thanh toán do cổng thanh toán PayOS xử lý bằng chuyển khoản ngân hàng; '
          'FlowMoney không lưu thông tin tài khoản ngân hàng hay thẻ của bạn.'),
      KhoiVanBan.gach('Gói Premium không tự động gia hạn. Khi hết kỳ mà bạn không gia hạn, tài khoản chuyển về gói '
          'Basic; dữ liệu của bạn được giữ nguyên.'),
      KhoiVanBan.gach('Phí đã thanh toán cho một kỳ Premium không được hoàn lại, trừ trường hợp số tiền chuyển khoản '
          'không khớp giá gói. Khi đó bạn chọn cách xử lý (nâng cấp hoặc yêu cầu hoàn tiền) trong màn hình '
          'Chi tiết đơn.'),
      KhoiVanBan.gach('Quyền lợi của từng gói có thể thay đổi; thay đổi không ảnh hưởng tới kỳ Premium bạn đã thanh '
          'toán.'),
    ]),
    MucVanBan('6. Nhóm gia đình', [
      KhoiVanBan.gach('Chủ nhóm có quyền mời, phân vai và mời thành viên rời nhóm. Thành viên xem và ghi dữ liệu chung '
          'của nhóm (ví chung, mục tiêu chung) theo vai được giao.'),
      KhoiVanBan.gach('Dữ liệu riêng của bạn không chia sẻ cho nhóm. Khi bạn ghi một giao dịch vào ví chung, các thành '
          'viên khác trong nhóm sẽ thấy giao dịch đó.'),
      KhoiVanBan.gach('Bạn chỉ nên mời người mà bạn đồng ý cho xem dữ liệu chung của nhóm.'),
    ]),
    MucVanBan('7. Quyền đối với dữ liệu và nội dung', [
      KhoiVanBan.gach('Dữ liệu của bạn thuộc về bạn. Bạn cho phép FlowMoney lưu trữ, đồng bộ và xử lý Dữ liệu của bạn '
          'trong phạm vi cần thiết để cung cấp Dịch vụ, theo Chính sách bảo mật.'),
      KhoiVanBan.gach('Bạn có thể nhận bản sao Dữ liệu của bạn tại Cá nhân → Dữ liệu của tôi.'),
    ]),
    MucVanBan('8. Quyền sở hữu trí tuệ', [
      KhoiVanBan.doan('FlowMoney cấp cho bạn quyền sử dụng Ứng dụng có giới hạn, không độc quyền, không chuyển nhượng, '
          'cho mục đích cá nhân và không thương mại. Mã nguồn, giao diện, tên gọi, biểu trưng và nội dung '
          'của Ứng dụng thuộc về nhóm phát triển FlowMoney. Bạn không được sao chép, sửa đổi, dịch ngược '
          'hoặc khai thác thương mại Ứng dụng khi chưa được chấp thuận bằng văn bản.'),
    ]),
    MucVanBan('9. Hành vi bị cấm', [
      KhoiVanBan.doan('Khi sử dụng Dịch vụ, bạn không được:'),
      KhoiVanBan.gach('truy cập trái phép, dò tìm hoặc khai thác lỗ hổng bảo mật, gây quá tải hoặc làm gián đoạn hệ '
          'thống;'),
      KhoiVanBan.gach('dùng công cụ tự động gửi yêu cầu hàng loạt tới máy chủ;'),
      KhoiVanBan.gach('sử dụng tài khoản của người khác hoặc mạo danh cá nhân, tổ chức khác;'),
      KhoiVanBan.gach('gian lận trong thanh toán hoặc lợi dụng lỗi để nhận quyền lợi không đúng;'),
      KhoiVanBan.gach('dùng Dịch vụ cho mục đích vi phạm pháp luật Việt Nam.'),
    ]),
    MucVanBan('10. Tạm khóa và chấm dứt', [
      KhoiVanBan.gach('FlowMoney có thể tạm khóa hoặc khóa tài khoản vi phạm Điều khoản này, hoặc khi cần bảo vệ an '
          'toàn hệ thống. Lý do được thông báo khi bạn đăng nhập.'),
      KhoiVanBan.gach('Bạn có thể ngừng sử dụng và yêu cầu xóa tài khoản bất cứ lúc nào tại Cá nhân. Tài khoản được '
          'giữ ở trạng thái chờ xóa 30 ngày, trong thời gian này bạn có thể hủy yêu cầu. Việc lưu giữ và '
          'xóa dữ liệu sau đó thực hiện theo Chính sách bảo mật.'),
    ]),
    MucVanBan('11. Gián đoạn Dịch vụ và miễn trừ bảo đảm', [
      KhoiVanBan.gach('Dịch vụ được cung cấp theo hiện trạng và theo khả năng sẵn có. FlowMoney nỗ lực duy trì Dịch vụ '
          'ổn định nhưng không bảo đảm Dịch vụ luôn liên tục, không có lỗi.'),
      KhoiVanBan.gach('FlowMoney có thể tạm dừng máy chủ để bảo trì và sẽ thông báo trước trong Ứng dụng khi có thể. '
          'Trong thời gian này bạn vẫn ghi chép được trên thiết bị; dữ liệu tự đồng bộ khi máy chủ hoạt '
          'động trở lại.'),
    ]),
    MucVanBan('12. Giới hạn trách nhiệm', [
      KhoiVanBan.doan('Trong phạm vi pháp luật cho phép, FlowMoney không chịu trách nhiệm đối với thiệt hại gián tiếp '
          'hoặc thiệt hại phát sinh từ quyết định tài chính bạn đưa ra dựa trên số liệu, dự báo hay gợi ý '
          'của Ứng dụng; từ việc bạn để lộ mật khẩu hoặc thiết bị; hoặc từ sự cố của dịch vụ bên thứ ba '
          'ngoài khả năng kiểm soát hợp lý của FlowMoney. Tổng trách nhiệm của FlowMoney với bạn không '
          'vượt quá số tiền bạn đã thanh toán cho FlowMoney trong 12 tháng gần nhất.'),
    ]),
    MucVanBan('13. Thay đổi Điều khoản', [
      KhoiVanBan.doan('FlowMoney có thể cập nhật Điều khoản này. Phiên bản mới được đưa vào bản cập nhật của Ứng dụng, '
          'kèm số phiên bản và ngày hiệu lực; bạn xem lại bất cứ lúc nào tại Cá nhân → Điều khoản & chính '
          'sách. Việc bạn tiếp tục sử dụng Ứng dụng sau ngày hiệu lực đồng nghĩa với việc bạn chấp nhận '
          'phiên bản mới.'),
    ]),
    MucVanBan('14. Luật áp dụng và liên hệ', [
      KhoiVanBan.gach('Điều khoản này được điều chỉnh bởi pháp luật Việt Nam. Tranh chấp được ưu tiên giải quyết bằng '
          'thương lượng; nếu không thành, tranh chấp được đưa ra Tòa án có thẩm quyền tại Việt Nam.'),
      KhoiVanBan.gach('Nếu một điều khoản bị coi là vô hiệu, các điều khoản còn lại vẫn giữ nguyên hiệu lực.'),
      KhoiVanBan.gach('Mọi câu hỏi, góp ý và khiếu nại xin gửi về: phubao12as@gmail.com.'),
    ]),
  ],
);
