import 'dart:io';

import 'package:flutter/material.dart';

/// Chia sẻ biên lai — xem ảnh biên lai TO (spec `2026-10-02-chia-se-bien-lai-design.md` mục 8): nền tối, phóng / kéo
/// được, nút đóng ở góc. Mở từ ảnh nhỏ trên dải nguồn của form Thêm giao dịch, để đối chiếu số tiền và nội dung với
/// thứ FlowMoney vừa điền.
Future<void> xemAnhBienLai(BuildContext context, String duongDan) => showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  key: const Key('bien-lai-anh-to'),
                  maxScale: 5,
                  child: Image.file(
                    File(duongDan),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text('Không mở được ảnh', style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  tooltip: 'Đóng',
                  // Nền tròn tối: nút nằm ĐÈ góc ảnh, và ✕ trắng không nền chìm hẳn trên biên lai nền sáng (nghiệm thu
                  // Realme 2026-10-03; biên lai MB nền xanh đậm thì vẫn rõ nên lượt đo đầu không thấy).
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
