import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/gioi_han_do_dai.dart';
import '../../../../shared/theme/app_colors.dart';

/// Cỡ chữ cho ô số dư, co theo độ dài chuỗi **đã có dấu chấm ngăn nghìn**.
///
/// ## Vì sao phải co
///
/// Con số ở đây dựng bằng `TextField` bọc `IntrinsicWidth`, tức nó lấy đúng bề
/// rộng tự nhiên của chuỗi và **không co**. Ở cỡ 40 trên màn 411dp, một số dư
/// 13 chữ số (`9.999.999.999.999`, 17 ký tự kể cả dấu chấm) tràn khỏi thẻ — đo
/// trên máy ảo ngày 2026-09-18: **70 pixel**.
///
/// 13 chữ số không phải con số ngẫu nhiên: đó đúng là trần mà
/// [kSoChuSoToiDaSoTien] đặt ra cho khớp `numeric(15,2)` của cột `Balance`.
/// Tức trước bản này, **giá trị lớn nhất mà app cho phép vẫn làm vỡ bố cục**.
///
/// ## ⚠️ Hàm này KHÔNG phải thứ chặn tràn — `Flexible` mới là
///
/// Ghi lại vì suýt kết luận sai: bản đầu tưởng bậc thang cỡ chữ là phép vá, và
/// ca test "13 chữ số không tràn" **xanh ngay cả khi ép cỡ chữ về 40 cố định**.
/// Thứ thật sự chặn tràn là `Flexible` bọc quanh `IntrinsicWidth` — nó cho
/// `TextField` một ràng buộc bề rộng hữu hạn, nên chuỗi dài cuộn bên trong ô
/// thay vì đẩy vỡ hàng.
///
/// Hai thứ làm hai việc khác nhau, và cần cả hai:
///
/// * `Flexible` giữ bố cục **không vỡ**. Bỏ nó là hai ca test đỏ ngay.
/// * [coChuSoDu] giữ con số **đọc được hết**. Không có nó thì bố cục vẫn lành
///   nhưng số dư dài bị cuộn khuất, và người dùng không thấy mình vừa gõ gì.
///
/// Đó là lý do ca test của bậc thang này đo **thẳng giá trị trả về**, không đo
/// bề rộng: một phép đo bố cục sẽ xanh dù hàm có đúng hay không.
///
/// Không dùng `FittedBox`: nó đo con ở ràng buộc **vô hạn** rồi mới thu nhỏ,
/// mà `TextField` không có bề rộng tự nhiên xác định dưới ràng buộc ấy.
double coChuSoDu(int soKyTu) {
  if (soKyTu <= 11) return 40; // tới 999.999.999
  if (soKyTu <= 13) return 34; // tới 99.999.999.999
  if (soKyTu <= 15) return 29; // tới 9.999.999.999.999 thiếu một bậc
  return 24; // 17 ký tự — trần của numeric(15,2)
}

/// Ô nhập "SỐ DƯ BAN ĐẦU" của màn **Thêm ví**.
///
/// ⚠️ **Màn Sửa ví cố ý KHÔNG dùng widget này.** Nó có bố cục riêng —
/// `Expanded` trong một `Container` có nền, cỡ chữ 32 — và chính vì `Expanded`
/// mà nó **không tràn**, nên lỗi bố cục ngày 2026-09-18 chỉ có ở màn Thêm.
/// Ép nó dùng chung là đổi giao diện một màn không hỏng, nằm ngoài phạm vi lượt
/// vá ấy.
///
/// Hệ quả phải biết: khối `onChanged` chèn dấu chấm ngăn nghìn vẫn còn **hai
/// bản**, ở đây và ở màn Sửa. Ai gộp nốt thì nhớ cả hai thứ ở đoạn dưới.
///
/// ⚠️ Hai thứ **không được đánh rơi** khi đụng vào widget này:
///
/// 1. [GioiHanSoChuSo] — thiếu nó thì một số 14 chữ số làm ví **kẹt hàng đợi
///    đẩy vĩnh viễn**, im lặng (xem [kSoChuSoToiDaSoTien]).
/// 2. [coChuSoDu] — thiếu nó thì số dư lớn tràn bố cục, và `flutter test`
///    **không bắt được** vì bộ test chạy ở 1280px còn điện thoại thật là 411dp.
class OSoDuVi extends StatelessWidget {
  const OSoDuVi({
    super.key,
    required this.controller,
    this.onChanged,
  });

  final TextEditingController controller;

  /// Gọi sau khi chuỗi đã được chèn dấu chấm. Màn Sửa ví dùng nó để so với số
  /// dư cũ mà quyết định có sinh khoản điều chỉnh hay không.
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    // ⚠️ Phải NGHE `controller`, không được đọc `controller.text` một lần.
    //
    // Widget này không giữ state, nên nếu chỉ đọc thẳng thì cỡ chữ đóng băng ở
    // giá trị lúc dựng: người dùng gõ số dài, `onChanged` cập nhật controller,
    // nhưng không gì gọi `build` lại — số giữ nguyên cỡ 40 rồi **bị cuộn khuất
    // mất chữ số đầu**. Bố cục vẫn lành nhờ `Flexible`, nên không có sọc vàng
    // nào để nhìn thấy, và ba ca test dựng-một-lần cũng không thấy.
    //
    // Đo được trên máy ảo 2026-09-18, sau khi bản vá tràn đã xong.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, giaTri, _) => _hang(coChuSoDu(giaTri.text.length)),
    );
  }

  Widget _hang(double co) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: IntrinsicWidth(
            child: TextField(
              controller: controller,
              style: TextStyle(
                fontSize: co,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                  color: AppColors.outlineVariant,
                  fontSize: co,
                ),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                // `wallet."Balance"` là `numeric(15,2)`. Không chặn ở đây thì
                // một số 14 chữ số làm ví KẸT HÀNG ĐỢI ĐẨY VĨNH VIỄN, im lặng.
                const GioiHanSoChuSo(kSoChuSoToiDaSoTien),
              ],
              onChanged: (value) {
                // `digitsOnly` đã lọc, nhưng sau khi ta ghi lại chuỗi đã chèn
                // chấm thì lần gọi sau mang cả dấu chấm — nên vẫn phải bóc.
                final chuSo = value.replaceAll('.', '');
                if (chuSo.isNotEmpty) {
                  final so = int.tryParse(chuSo) ?? 0;
                  final daCham = CurrencyFormatter.formatSoThoi(so);
                  if (controller.text != daCham) {
                    controller.value = TextEditingValue(
                      text: daCham,
                      selection:
                          TextSelection.collapsed(offset: daCham.length),
                    );
                  }
                }
                onChanged?.call(controller.text);
              },
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'đ',
          style: TextStyle(
            fontSize: co * 0.6,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
