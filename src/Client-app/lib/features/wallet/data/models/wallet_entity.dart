import 'package:equatable/equatable.dart';

/// Domain entity Wallet — dùng trong toàn bộ business logic.
///
/// Tách biệt khỏi Drift's `Wallet` data class để:
/// 1. Business layer không phụ thuộc vào DB layer
/// 2. Dễ mock trong test
/// 3. Có thêm computed properties (e.g., `formattedBalance`)
class WalletEntity extends Equatable {
  final String id;
  final int idaccount;
  final String name;
  final String type;      // 'cash' | 'bank' | 'ewallet' | 'investment' | 'debt'
  final double balance;
  final String currency;
  final String icon;
  final String colour;
  final bool isDefault;
  final bool isDeleted;
  final bool includeInTotal;
  final String syncStatus;
  final DateTime updatedAt;

  const WalletEntity({
    required this.id,
    required this.idaccount,
    required this.name,
    required this.type,
    required this.balance,
    this.currency = 'VND',
    this.icon = 'wallet',
    this.colour = '#4CAF50',
    this.isDefault = false,
    this.isDeleted = false,
    this.includeInTotal = true,
    this.syncStatus = 'pending',
    required this.updatedAt,
  });

  /// Label hiển thị loại ví
  String get typeLabel => switch (type) {
    'bank'       => 'Ngân hàng',
    'ewallet'    => 'Ví điện tử',
    'investment' => 'Đầu tư',
    'debt'       => 'Thẻ tín dụng',
    _            => 'Tiền mặt',
  };

  WalletEntity copyWith({
    String? id,
    int? idaccount,
    String? name,
    String? type,
    double? balance,
    String? currency,
    String? icon,
    String? colour,
    bool? isDefault,
    bool? isDeleted,
    bool? includeInTotal,
    String? syncStatus,
    DateTime? updatedAt,
  }) {
    return WalletEntity(
      id:          id          ?? this.id,
      idaccount:   idaccount   ?? this.idaccount,
      name:        name        ?? this.name,
      type:        type        ?? this.type,
      balance:     balance     ?? this.balance,
      currency:    currency    ?? this.currency,
      icon:        icon        ?? this.icon,
      colour:      colour      ?? this.colour,
      isDefault:      isDefault      ?? this.isDefault,
      isDeleted:      isDeleted      ?? this.isDeleted,
      includeInTotal: includeInTotal ?? this.includeInTotal,
      syncStatus:     syncStatus     ?? this.syncStatus,
      updatedAt:      updatedAt      ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, idaccount, name, type, balance,
      currency, icon, colour, isDefault, isDeleted, includeInTotal, syncStatus, updatedAt];
}
