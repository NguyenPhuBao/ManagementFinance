import 'package:flutter/material.dart';

/// Hàng đầu thẻ ngân hàng ở trang liên kết: logo + tên + trạng thái kết nối
/// bên trái, chip "Cổng API an toàn" bên phải.
///
/// Tách khỏi `bank_link_page.dart` để test được ở nhiều bề rộng màn hình. Đây
/// là chỗ tràn nặng nhất tìm được trên máy thật (21px): cụm logo + tên chiếm
/// đúng bề rộng chữ của nó, nên chip bị đẩy hẳn ra khỏi thẻ.
class BankHeaderRow extends StatelessWidget {
  const BankHeaderRow({
    super.key,
    required this.bankName,
    required this.statusText,
    required this.chipText,
    this.logo,
  });

  final String bankName;
  final String statusText;
  final String chipText;

  /// Ảnh logo. Nhận từ ngoài để test không phải chạm mạng — `Image.network`
  /// trong widget test sẽ ném `400: Bad Request` từ máy chủ giả của Flutter.
  final Widget? logo;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Cụm trái phải co được, nếu không nó chiếm đúng bề rộng chữ và đẩy
        // chip ra ngoài thẻ.
        Expanded(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E8E4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE8E8E4)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: logo ?? const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bankName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00020D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF006E1C),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            statusText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF46464C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF96F592),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            chipText,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0A7320),
            ),
          ),
        ),
      ],
    );
  }
}
