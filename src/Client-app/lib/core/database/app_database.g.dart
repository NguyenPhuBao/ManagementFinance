// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $WalletsTable extends Wallets with TableInfo<$WalletsTable, Wallet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalletsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _idaccountMeta =
      const VerificationMeta('idaccount');
  @override
  late final GeneratedColumn<int> idaccount = GeneratedColumn<int>(
      'idaccount', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('cash'));
  static const VerificationMeta _balanceMeta =
      const VerificationMeta('balance');
  @override
  late final GeneratedColumn<double> balance = GeneratedColumn<double>(
      'balance', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('VND'));
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
      'icon', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('wallet'));
  static const VerificationMeta _colourMeta = const VerificationMeta('colour');
  @override
  late final GeneratedColumn<String> colour = GeneratedColumn<String>(
      'colour', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('#4CAF50'));
  static const VerificationMeta _isDefaultMeta =
      const VerificationMeta('isDefault');
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
      'is_default', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_default" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _includeInTotalMeta =
      const VerificationMeta('includeInTotal');
  @override
  late final GeneratedColumn<bool> includeInTotal = GeneratedColumn<bool>(
      'include_in_total', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("include_in_total" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _bankCassoIdMeta =
      const VerificationMeta('bankCassoId');
  @override
  late final GeneratedColumn<String> bankCassoId = GeneratedColumn<String>(
      'bank_casso_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('active'));
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _syncRetryCountMeta =
      const VerificationMeta('syncRetryCount');
  @override
  late final GeneratedColumn<int> syncRetryCount = GeneratedColumn<int>(
      'sync_retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _syncErrorMeta =
      const VerificationMeta('syncError');
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
      'sync_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncBlockedUntilMeta =
      const VerificationMeta('syncBlockedUntil');
  @override
  late final GeneratedColumn<DateTime> syncBlockedUntil =
      GeneratedColumn<DateTime>('sync_blocked_until', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        idaccount,
        name,
        type,
        balance,
        currency,
        icon,
        colour,
        isDefault,
        isDeleted,
        includeInTotal,
        bankCassoId,
        status,
        syncStatus,
        syncRetryCount,
        syncError,
        syncBlockedUntil,
        updatedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallets';
  @override
  VerificationContext validateIntegrity(Insertable<Wallet> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('idaccount')) {
      context.handle(_idaccountMeta,
          idaccount.isAcceptableOrUnknown(data['idaccount']!, _idaccountMeta));
    } else if (isInserting) {
      context.missing(_idaccountMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    }
    if (data.containsKey('balance')) {
      context.handle(_balanceMeta,
          balance.isAcceptableOrUnknown(data['balance']!, _balanceMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('icon')) {
      context.handle(
          _iconMeta, icon.isAcceptableOrUnknown(data['icon']!, _iconMeta));
    }
    if (data.containsKey('colour')) {
      context.handle(_colourMeta,
          colour.isAcceptableOrUnknown(data['colour']!, _colourMeta));
    }
    if (data.containsKey('is_default')) {
      context.handle(_isDefaultMeta,
          isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('include_in_total')) {
      context.handle(
          _includeInTotalMeta,
          includeInTotal.isAcceptableOrUnknown(
              data['include_in_total']!, _includeInTotalMeta));
    }
    if (data.containsKey('bank_casso_id')) {
      context.handle(
          _bankCassoIdMeta,
          bankCassoId.isAcceptableOrUnknown(
              data['bank_casso_id']!, _bankCassoIdMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('sync_retry_count')) {
      context.handle(
          _syncRetryCountMeta,
          syncRetryCount.isAcceptableOrUnknown(
              data['sync_retry_count']!, _syncRetryCountMeta));
    }
    if (data.containsKey('sync_error')) {
      context.handle(_syncErrorMeta,
          syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta));
    }
    if (data.containsKey('sync_blocked_until')) {
      context.handle(
          _syncBlockedUntilMeta,
          syncBlockedUntil.isAcceptableOrUnknown(
              data['sync_blocked_until']!, _syncBlockedUntilMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Wallet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Wallet(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      idaccount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}idaccount'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      balance: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}balance'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      icon: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon'])!,
      colour: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}colour'])!,
      isDefault: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_default'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      includeInTotal: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}include_in_total'])!,
      bankCassoId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bank_casso_id']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      syncRetryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_retry_count'])!,
      syncError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_error']),
      syncBlockedUntil: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}sync_blocked_until']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $WalletsTable createAlias(String alias) {
    return $WalletsTable(attachedDatabase, alias);
  }
}

class Wallet extends DataClass implements Insertable<Wallet> {
  final String id;

  /// idaccount từ backend — dùng để filter data của user hiện tại
  final int idaccount;
  final String name;
  final String type;
  final double balance;
  final String currency;
  final String icon;
  final String colour;
  final bool isDefault;
  final bool isDeleted;

  /// Nếu true: số dư ví được cộng vào tổng tài sản trên dashboard
  final bool includeInTotal;
  final String? bankCassoId;
  final String status;
  final String syncStatus;
  final int syncRetryCount;
  final String? syncError;
  final DateTime? syncBlockedUntil;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Wallet(
      {required this.id,
      required this.idaccount,
      required this.name,
      required this.type,
      required this.balance,
      required this.currency,
      required this.icon,
      required this.colour,
      required this.isDefault,
      required this.isDeleted,
      required this.includeInTotal,
      this.bankCassoId,
      required this.status,
      required this.syncStatus,
      required this.syncRetryCount,
      this.syncError,
      this.syncBlockedUntil,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['idaccount'] = Variable<int>(idaccount);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['balance'] = Variable<double>(balance);
    map['currency'] = Variable<String>(currency);
    map['icon'] = Variable<String>(icon);
    map['colour'] = Variable<String>(colour);
    map['is_default'] = Variable<bool>(isDefault);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['include_in_total'] = Variable<bool>(includeInTotal);
    if (!nullToAbsent || bankCassoId != null) {
      map['bank_casso_id'] = Variable<String>(bankCassoId);
    }
    map['status'] = Variable<String>(status);
    map['sync_status'] = Variable<String>(syncStatus);
    map['sync_retry_count'] = Variable<int>(syncRetryCount);
    if (!nullToAbsent || syncError != null) {
      map['sync_error'] = Variable<String>(syncError);
    }
    if (!nullToAbsent || syncBlockedUntil != null) {
      map['sync_blocked_until'] = Variable<DateTime>(syncBlockedUntil);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  WalletsCompanion toCompanion(bool nullToAbsent) {
    return WalletsCompanion(
      id: Value(id),
      idaccount: Value(idaccount),
      name: Value(name),
      type: Value(type),
      balance: Value(balance),
      currency: Value(currency),
      icon: Value(icon),
      colour: Value(colour),
      isDefault: Value(isDefault),
      isDeleted: Value(isDeleted),
      includeInTotal: Value(includeInTotal),
      bankCassoId: bankCassoId == null && nullToAbsent
          ? const Value.absent()
          : Value(bankCassoId),
      status: Value(status),
      syncStatus: Value(syncStatus),
      syncRetryCount: Value(syncRetryCount),
      syncError: syncError == null && nullToAbsent
          ? const Value.absent()
          : Value(syncError),
      syncBlockedUntil: syncBlockedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(syncBlockedUntil),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Wallet.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Wallet(
      id: serializer.fromJson<String>(json['id']),
      idaccount: serializer.fromJson<int>(json['idaccount']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      balance: serializer.fromJson<double>(json['balance']),
      currency: serializer.fromJson<String>(json['currency']),
      icon: serializer.fromJson<String>(json['icon']),
      colour: serializer.fromJson<String>(json['colour']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      includeInTotal: serializer.fromJson<bool>(json['includeInTotal']),
      bankCassoId: serializer.fromJson<String?>(json['bankCassoId']),
      status: serializer.fromJson<String>(json['status']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      syncRetryCount: serializer.fromJson<int>(json['syncRetryCount']),
      syncError: serializer.fromJson<String?>(json['syncError']),
      syncBlockedUntil:
          serializer.fromJson<DateTime?>(json['syncBlockedUntil']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'idaccount': serializer.toJson<int>(idaccount),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'balance': serializer.toJson<double>(balance),
      'currency': serializer.toJson<String>(currency),
      'icon': serializer.toJson<String>(icon),
      'colour': serializer.toJson<String>(colour),
      'isDefault': serializer.toJson<bool>(isDefault),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'includeInTotal': serializer.toJson<bool>(includeInTotal),
      'bankCassoId': serializer.toJson<String?>(bankCassoId),
      'status': serializer.toJson<String>(status),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'syncRetryCount': serializer.toJson<int>(syncRetryCount),
      'syncError': serializer.toJson<String?>(syncError),
      'syncBlockedUntil': serializer.toJson<DateTime?>(syncBlockedUntil),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Wallet copyWith(
          {String? id,
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
          Value<String?> bankCassoId = const Value.absent(),
          String? status,
          String? syncStatus,
          int? syncRetryCount,
          Value<String?> syncError = const Value.absent(),
          Value<DateTime?> syncBlockedUntil = const Value.absent(),
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      Wallet(
        id: id ?? this.id,
        idaccount: idaccount ?? this.idaccount,
        name: name ?? this.name,
        type: type ?? this.type,
        balance: balance ?? this.balance,
        currency: currency ?? this.currency,
        icon: icon ?? this.icon,
        colour: colour ?? this.colour,
        isDefault: isDefault ?? this.isDefault,
        isDeleted: isDeleted ?? this.isDeleted,
        includeInTotal: includeInTotal ?? this.includeInTotal,
        bankCassoId: bankCassoId.present ? bankCassoId.value : this.bankCassoId,
        status: status ?? this.status,
        syncStatus: syncStatus ?? this.syncStatus,
        syncRetryCount: syncRetryCount ?? this.syncRetryCount,
        syncError: syncError.present ? syncError.value : this.syncError,
        syncBlockedUntil: syncBlockedUntil.present
            ? syncBlockedUntil.value
            : this.syncBlockedUntil,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  Wallet copyWithCompanion(WalletsCompanion data) {
    return Wallet(
      id: data.id.present ? data.id.value : this.id,
      idaccount: data.idaccount.present ? data.idaccount.value : this.idaccount,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      balance: data.balance.present ? data.balance.value : this.balance,
      currency: data.currency.present ? data.currency.value : this.currency,
      icon: data.icon.present ? data.icon.value : this.icon,
      colour: data.colour.present ? data.colour.value : this.colour,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      includeInTotal: data.includeInTotal.present
          ? data.includeInTotal.value
          : this.includeInTotal,
      bankCassoId:
          data.bankCassoId.present ? data.bankCassoId.value : this.bankCassoId,
      status: data.status.present ? data.status.value : this.status,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      syncRetryCount: data.syncRetryCount.present
          ? data.syncRetryCount.value
          : this.syncRetryCount,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
      syncBlockedUntil: data.syncBlockedUntil.present
          ? data.syncBlockedUntil.value
          : this.syncBlockedUntil,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Wallet(')
          ..write('id: $id, ')
          ..write('idaccount: $idaccount, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('balance: $balance, ')
          ..write('currency: $currency, ')
          ..write('icon: $icon, ')
          ..write('colour: $colour, ')
          ..write('isDefault: $isDefault, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('includeInTotal: $includeInTotal, ')
          ..write('bankCassoId: $bankCassoId, ')
          ..write('status: $status, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncRetryCount: $syncRetryCount, ')
          ..write('syncError: $syncError, ')
          ..write('syncBlockedUntil: $syncBlockedUntil, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      idaccount,
      name,
      type,
      balance,
      currency,
      icon,
      colour,
      isDefault,
      isDeleted,
      includeInTotal,
      bankCassoId,
      status,
      syncStatus,
      syncRetryCount,
      syncError,
      syncBlockedUntil,
      updatedAt,
      deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Wallet &&
          other.id == this.id &&
          other.idaccount == this.idaccount &&
          other.name == this.name &&
          other.type == this.type &&
          other.balance == this.balance &&
          other.currency == this.currency &&
          other.icon == this.icon &&
          other.colour == this.colour &&
          other.isDefault == this.isDefault &&
          other.isDeleted == this.isDeleted &&
          other.includeInTotal == this.includeInTotal &&
          other.bankCassoId == this.bankCassoId &&
          other.status == this.status &&
          other.syncStatus == this.syncStatus &&
          other.syncRetryCount == this.syncRetryCount &&
          other.syncError == this.syncError &&
          other.syncBlockedUntil == this.syncBlockedUntil &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class WalletsCompanion extends UpdateCompanion<Wallet> {
  final Value<String> id;
  final Value<int> idaccount;
  final Value<String> name;
  final Value<String> type;
  final Value<double> balance;
  final Value<String> currency;
  final Value<String> icon;
  final Value<String> colour;
  final Value<bool> isDefault;
  final Value<bool> isDeleted;
  final Value<bool> includeInTotal;
  final Value<String?> bankCassoId;
  final Value<String> status;
  final Value<String> syncStatus;
  final Value<int> syncRetryCount;
  final Value<String?> syncError;
  final Value<DateTime?> syncBlockedUntil;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const WalletsCompanion({
    this.id = const Value.absent(),
    this.idaccount = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.balance = const Value.absent(),
    this.currency = const Value.absent(),
    this.icon = const Value.absent(),
    this.colour = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.includeInTotal = const Value.absent(),
    this.bankCassoId = const Value.absent(),
    this.status = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncRetryCount = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncBlockedUntil = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WalletsCompanion.insert({
    required String id,
    required int idaccount,
    required String name,
    this.type = const Value.absent(),
    this.balance = const Value.absent(),
    this.currency = const Value.absent(),
    this.icon = const Value.absent(),
    this.colour = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.includeInTotal = const Value.absent(),
    this.bankCassoId = const Value.absent(),
    this.status = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncRetryCount = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncBlockedUntil = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        idaccount = Value(idaccount),
        name = Value(name),
        updatedAt = Value(updatedAt);
  static Insertable<Wallet> custom({
    Expression<String>? id,
    Expression<int>? idaccount,
    Expression<String>? name,
    Expression<String>? type,
    Expression<double>? balance,
    Expression<String>? currency,
    Expression<String>? icon,
    Expression<String>? colour,
    Expression<bool>? isDefault,
    Expression<bool>? isDeleted,
    Expression<bool>? includeInTotal,
    Expression<String>? bankCassoId,
    Expression<String>? status,
    Expression<String>? syncStatus,
    Expression<int>? syncRetryCount,
    Expression<String>? syncError,
    Expression<DateTime>? syncBlockedUntil,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (idaccount != null) 'idaccount': idaccount,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (balance != null) 'balance': balance,
      if (currency != null) 'currency': currency,
      if (icon != null) 'icon': icon,
      if (colour != null) 'colour': colour,
      if (isDefault != null) 'is_default': isDefault,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (includeInTotal != null) 'include_in_total': includeInTotal,
      if (bankCassoId != null) 'bank_casso_id': bankCassoId,
      if (status != null) 'status': status,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (syncRetryCount != null) 'sync_retry_count': syncRetryCount,
      if (syncError != null) 'sync_error': syncError,
      if (syncBlockedUntil != null) 'sync_blocked_until': syncBlockedUntil,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WalletsCompanion copyWith(
      {Value<String>? id,
      Value<int>? idaccount,
      Value<String>? name,
      Value<String>? type,
      Value<double>? balance,
      Value<String>? currency,
      Value<String>? icon,
      Value<String>? colour,
      Value<bool>? isDefault,
      Value<bool>? isDeleted,
      Value<bool>? includeInTotal,
      Value<String?>? bankCassoId,
      Value<String>? status,
      Value<String>? syncStatus,
      Value<int>? syncRetryCount,
      Value<String?>? syncError,
      Value<DateTime?>? syncBlockedUntil,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return WalletsCompanion(
      id: id ?? this.id,
      idaccount: idaccount ?? this.idaccount,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      icon: icon ?? this.icon,
      colour: colour ?? this.colour,
      isDefault: isDefault ?? this.isDefault,
      isDeleted: isDeleted ?? this.isDeleted,
      includeInTotal: includeInTotal ?? this.includeInTotal,
      bankCassoId: bankCassoId ?? this.bankCassoId,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
      syncRetryCount: syncRetryCount ?? this.syncRetryCount,
      syncError: syncError ?? this.syncError,
      syncBlockedUntil: syncBlockedUntil ?? this.syncBlockedUntil,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (idaccount.present) {
      map['idaccount'] = Variable<int>(idaccount.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (balance.present) {
      map['balance'] = Variable<double>(balance.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (colour.present) {
      map['colour'] = Variable<String>(colour.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (includeInTotal.present) {
      map['include_in_total'] = Variable<bool>(includeInTotal.value);
    }
    if (bankCassoId.present) {
      map['bank_casso_id'] = Variable<String>(bankCassoId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (syncRetryCount.present) {
      map['sync_retry_count'] = Variable<int>(syncRetryCount.value);
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
    }
    if (syncBlockedUntil.present) {
      map['sync_blocked_until'] = Variable<DateTime>(syncBlockedUntil.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalletsCompanion(')
          ..write('id: $id, ')
          ..write('idaccount: $idaccount, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('balance: $balance, ')
          ..write('currency: $currency, ')
          ..write('icon: $icon, ')
          ..write('colour: $colour, ')
          ..write('isDefault: $isDefault, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('includeInTotal: $includeInTotal, ')
          ..write('bankCassoId: $bankCassoId, ')
          ..write('status: $status, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncRetryCount: $syncRetryCount, ')
          ..write('syncError: $syncError, ')
          ..write('syncBlockedUntil: $syncBlockedUntil, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _walletIdMeta =
      const VerificationMeta('walletId');
  @override
  late final GeneratedColumn<String> walletId = GeneratedColumn<String>(
      'wallet_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES wallets (id)'));
  static const VerificationMeta _idaccountMeta =
      const VerificationMeta('idaccount');
  @override
  late final GeneratedColumn<int> idaccount = GeneratedColumn<int>(
      'idaccount', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
      'category_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Confirmed'));
  static const VerificationMeta _providerMeta =
      const VerificationMeta('provider');
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
      'provider', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Manual'));
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _imagesMeta = const VerificationMeta('images');
  @override
  late final GeneratedColumn<String> images = GeneratedColumn<String>(
      'images', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
      'goal_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _walletTransferMeta =
      const VerificationMeta('walletTransfer');
  @override
  late final GeneratedColumn<String> walletTransfer = GeneratedColumn<String>(
      'wallet_transfer', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bankTranIdMeta =
      const VerificationMeta('bankTranId');
  @override
  late final GeneratedColumn<String> bankTranId = GeneratedColumn<String>(
      'bank_tran_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _syncRetryCountMeta =
      const VerificationMeta('syncRetryCount');
  @override
  late final GeneratedColumn<int> syncRetryCount = GeneratedColumn<int>(
      'sync_retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _syncErrorMeta =
      const VerificationMeta('syncError');
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
      'sync_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncBlockedUntilMeta =
      const VerificationMeta('syncBlockedUntil');
  @override
  late final GeneratedColumn<DateTime> syncBlockedUntil =
      GeneratedColumn<DateTime>('sync_blocked_until', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        walletId,
        idaccount,
        categoryId,
        amount,
        type,
        status,
        provider,
        note,
        date,
        images,
        goalId,
        walletTransfer,
        bankTranId,
        deletedAt,
        syncStatus,
        syncRetryCount,
        syncError,
        syncBlockedUntil,
        updatedAt,
        isDeleted
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(Insertable<Transaction> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('wallet_id')) {
      context.handle(_walletIdMeta,
          walletId.isAcceptableOrUnknown(data['wallet_id']!, _walletIdMeta));
    } else if (isInserting) {
      context.missing(_walletIdMeta);
    }
    if (data.containsKey('idaccount')) {
      context.handle(_idaccountMeta,
          idaccount.isAcceptableOrUnknown(data['idaccount']!, _idaccountMeta));
    } else if (isInserting) {
      context.missing(_idaccountMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('provider')) {
      context.handle(_providerMeta,
          provider.isAcceptableOrUnknown(data['provider']!, _providerMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('images')) {
      context.handle(_imagesMeta,
          images.isAcceptableOrUnknown(data['images']!, _imagesMeta));
    }
    if (data.containsKey('goal_id')) {
      context.handle(_goalIdMeta,
          goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta));
    }
    if (data.containsKey('wallet_transfer')) {
      context.handle(
          _walletTransferMeta,
          walletTransfer.isAcceptableOrUnknown(
              data['wallet_transfer']!, _walletTransferMeta));
    }
    if (data.containsKey('bank_tran_id')) {
      context.handle(
          _bankTranIdMeta,
          bankTranId.isAcceptableOrUnknown(
              data['bank_tran_id']!, _bankTranIdMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('sync_retry_count')) {
      context.handle(
          _syncRetryCountMeta,
          syncRetryCount.isAcceptableOrUnknown(
              data['sync_retry_count']!, _syncRetryCountMeta));
    }
    if (data.containsKey('sync_error')) {
      context.handle(_syncErrorMeta,
          syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta));
    }
    if (data.containsKey('sync_blocked_until')) {
      context.handle(
          _syncBlockedUntilMeta,
          syncBlockedUntil.isAcceptableOrUnknown(
              data['sync_blocked_until']!, _syncBlockedUntilMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      walletId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}wallet_id'])!,
      idaccount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}idaccount'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_id']),
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      provider: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}provider'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
      images: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}images'])!,
      goalId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}goal_id']),
      walletTransfer: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}wallet_transfer']),
      bankTranId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bank_tran_id']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      syncRetryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_retry_count'])!,
      syncError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_error']),
      syncBlockedUntil: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}sync_blocked_until']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final String id;
  final String walletId;
  final int idaccount;
  final String? categoryId;
  final double amount;
  final String type;

  /// status: trạng thái giao dịch — 'Pending' | 'Confirmed' | 'Rejected' | 'Fail'
  /// Mặc định 'Confirmed' (khớp backend default)
  final String status;

  /// provider: nguồn tạo giao dịch
  /// Backend values: 'Manual' | 'BankSync' | 'SMS' | 'ORC' | 'Bill'
  /// Client legacy:  'Manual' | 'Casso'   | 'SMS' | 'OCR'
  ///
  /// ⚠️ **Cột này KHÔNG đi qua đồng bộ theo chiều nào cả**, và **không có mapper
  /// chuẩn hoá nào**. Payload đẩy (`sync_engine.dart`, `_collectPendingOps`)
  /// gồm 11 trường và không có `provider`; nhánh kéo về cũng không đọc nó. Nên
  /// mọi hàng client đẩy lên đều nằm trên server với `Provider = 'Manual'`, kể
  /// cả giao dịch do ngân hàng tạo rồi kéo về máy này.
  ///
  /// Chú thích cũ ở đây từng hứa "sync mapper sẽ chuẩn hoá Casso→BankSync,
  /// OCR→ORC". **Hành vi đó chưa bao giờ tồn tại** — đã kiểm ngày 2026-09-04.
  ///
  /// Trước khi thêm cột này vào payload đẩy, đọc `docs/superpowers/backend/
  /// 2026-09-04-ocr-classify-review.md` mục 7: backend đang có
  /// `@@unique([provider, bank_tran_id])` **không tách theo tài khoản**, và
  /// ràng buộc đó hiện chỉ trơ vì client gửi lên toàn NULL.
  final String provider;
  final String note;
  final DateTime date;
  final String images;

  /// goalId: mục tiêu tiết kiệm mà giao dịch này thuộc về. NULL với mọi giao
  /// dịch thường.
  ///
  /// ⚠️ **Cột CỤC BỘ — cố ý KHÔNG nằm trong hợp đồng đồng bộ.** Bảng `goal`
  /// phía backend không có chiều ngược lại, và thêm trường vào payload đẩy đòi
  /// backend sửa trước (quy tắc 4 trong `CLAUDE.md`).
  /// `sync_payload_contract_test.dart` khoá đúng bộ khoá của payload giao dịch
  /// nên nó bắt được ngay nếu cột này lọt vào.
  ///
  /// Vì là cục bộ, hàng **kéo về từ server luôn để trống** cột này — cũng như
  /// mọi hàng do bản app cũ tạo. Nơi đọc (`TransactionDao.watchByGoal`) phải
  /// giữ nhánh tra theo ghi chú cho những hàng đó, nếu không lịch sử tích luỹ
  /// đã có sẽ biến mất sau lần đồng bộ đầu tiên.
  ///
  /// Vì sao cần: trước đây lịch sử tích luỹ tra bằng
  /// `note LIKE '%Tích lũy mục tiêu: <tên>%'`. Tên mục tiêu không duy nhất, và
  /// tệ hơn, một tên là **tiền tố** của tên khác ("Mua" với "Mua xe") thì nuốt
  /// luôn lịch sử của mục tiêu kia.
  final String? goalId;

  /// walletTransfer: Wallet_Transfer — ví đích khi chuyển khoản nội bộ
  final String? walletTransfer;

  /// bankTranId: Bank_tran_id — ID giao dịch từ ngân hàng (Casso/SMS)
  ///
  /// ⚠️ **Bảng này KHÔNG khai `uniqueKeys`**, nên `(provider, bankTranId)`
  /// **không** duy nhất ở SQLite — chú thích cũ hứa như vậy là sai. Phía
  /// PostgreSQL thì có `uq_transaction_external`, nhưng nó ràng buộc trên
  /// **toàn bảng** chứ không theo từng tài khoản.
  ///
  /// ⚠️ Cột này cũng **không đi qua đồng bộ theo chiều nào**, giống `provider`.
  /// Hiện chưa nơi nào trong app gán giá trị cho nó, nên nó luôn NULL.
  final String? bankTranId;

  /// deletedAt: NULL = đang dùng, có giá trị = đã xóa mềm
  final DateTime? deletedAt;
  final String syncStatus;
  final int syncRetryCount;
  final String? syncError;
  final DateTime? syncBlockedUntil;
  final DateTime updatedAt;
  final bool isDeleted;
  const Transaction(
      {required this.id,
      required this.walletId,
      required this.idaccount,
      this.categoryId,
      required this.amount,
      required this.type,
      required this.status,
      required this.provider,
      required this.note,
      required this.date,
      required this.images,
      this.goalId,
      this.walletTransfer,
      this.bankTranId,
      this.deletedAt,
      required this.syncStatus,
      required this.syncRetryCount,
      this.syncError,
      this.syncBlockedUntil,
      required this.updatedAt,
      required this.isDeleted});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['wallet_id'] = Variable<String>(walletId);
    map['idaccount'] = Variable<int>(idaccount);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['amount'] = Variable<double>(amount);
    map['type'] = Variable<String>(type);
    map['status'] = Variable<String>(status);
    map['provider'] = Variable<String>(provider);
    map['note'] = Variable<String>(note);
    map['date'] = Variable<DateTime>(date);
    map['images'] = Variable<String>(images);
    if (!nullToAbsent || goalId != null) {
      map['goal_id'] = Variable<String>(goalId);
    }
    if (!nullToAbsent || walletTransfer != null) {
      map['wallet_transfer'] = Variable<String>(walletTransfer);
    }
    if (!nullToAbsent || bankTranId != null) {
      map['bank_tran_id'] = Variable<String>(bankTranId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    map['sync_retry_count'] = Variable<int>(syncRetryCount);
    if (!nullToAbsent || syncError != null) {
      map['sync_error'] = Variable<String>(syncError);
    }
    if (!nullToAbsent || syncBlockedUntil != null) {
      map['sync_blocked_until'] = Variable<DateTime>(syncBlockedUntil);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      walletId: Value(walletId),
      idaccount: Value(idaccount),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      amount: Value(amount),
      type: Value(type),
      status: Value(status),
      provider: Value(provider),
      note: Value(note),
      date: Value(date),
      images: Value(images),
      goalId:
          goalId == null && nullToAbsent ? const Value.absent() : Value(goalId),
      walletTransfer: walletTransfer == null && nullToAbsent
          ? const Value.absent()
          : Value(walletTransfer),
      bankTranId: bankTranId == null && nullToAbsent
          ? const Value.absent()
          : Value(bankTranId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      syncStatus: Value(syncStatus),
      syncRetryCount: Value(syncRetryCount),
      syncError: syncError == null && nullToAbsent
          ? const Value.absent()
          : Value(syncError),
      syncBlockedUntil: syncBlockedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(syncBlockedUntil),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory Transaction.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<String>(json['id']),
      walletId: serializer.fromJson<String>(json['walletId']),
      idaccount: serializer.fromJson<int>(json['idaccount']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      amount: serializer.fromJson<double>(json['amount']),
      type: serializer.fromJson<String>(json['type']),
      status: serializer.fromJson<String>(json['status']),
      provider: serializer.fromJson<String>(json['provider']),
      note: serializer.fromJson<String>(json['note']),
      date: serializer.fromJson<DateTime>(json['date']),
      images: serializer.fromJson<String>(json['images']),
      goalId: serializer.fromJson<String?>(json['goalId']),
      walletTransfer: serializer.fromJson<String?>(json['walletTransfer']),
      bankTranId: serializer.fromJson<String?>(json['bankTranId']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      syncRetryCount: serializer.fromJson<int>(json['syncRetryCount']),
      syncError: serializer.fromJson<String?>(json['syncError']),
      syncBlockedUntil:
          serializer.fromJson<DateTime?>(json['syncBlockedUntil']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'walletId': serializer.toJson<String>(walletId),
      'idaccount': serializer.toJson<int>(idaccount),
      'categoryId': serializer.toJson<String?>(categoryId),
      'amount': serializer.toJson<double>(amount),
      'type': serializer.toJson<String>(type),
      'status': serializer.toJson<String>(status),
      'provider': serializer.toJson<String>(provider),
      'note': serializer.toJson<String>(note),
      'date': serializer.toJson<DateTime>(date),
      'images': serializer.toJson<String>(images),
      'goalId': serializer.toJson<String?>(goalId),
      'walletTransfer': serializer.toJson<String?>(walletTransfer),
      'bankTranId': serializer.toJson<String?>(bankTranId),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'syncRetryCount': serializer.toJson<int>(syncRetryCount),
      'syncError': serializer.toJson<String?>(syncError),
      'syncBlockedUntil': serializer.toJson<DateTime?>(syncBlockedUntil),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  Transaction copyWith(
          {String? id,
          String? walletId,
          int? idaccount,
          Value<String?> categoryId = const Value.absent(),
          double? amount,
          String? type,
          String? status,
          String? provider,
          String? note,
          DateTime? date,
          String? images,
          Value<String?> goalId = const Value.absent(),
          Value<String?> walletTransfer = const Value.absent(),
          Value<String?> bankTranId = const Value.absent(),
          Value<DateTime?> deletedAt = const Value.absent(),
          String? syncStatus,
          int? syncRetryCount,
          Value<String?> syncError = const Value.absent(),
          Value<DateTime?> syncBlockedUntil = const Value.absent(),
          DateTime? updatedAt,
          bool? isDeleted}) =>
      Transaction(
        id: id ?? this.id,
        walletId: walletId ?? this.walletId,
        idaccount: idaccount ?? this.idaccount,
        categoryId: categoryId.present ? categoryId.value : this.categoryId,
        amount: amount ?? this.amount,
        type: type ?? this.type,
        status: status ?? this.status,
        provider: provider ?? this.provider,
        note: note ?? this.note,
        date: date ?? this.date,
        images: images ?? this.images,
        goalId: goalId.present ? goalId.value : this.goalId,
        walletTransfer:
            walletTransfer.present ? walletTransfer.value : this.walletTransfer,
        bankTranId: bankTranId.present ? bankTranId.value : this.bankTranId,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        syncStatus: syncStatus ?? this.syncStatus,
        syncRetryCount: syncRetryCount ?? this.syncRetryCount,
        syncError: syncError.present ? syncError.value : this.syncError,
        syncBlockedUntil: syncBlockedUntil.present
            ? syncBlockedUntil.value
            : this.syncBlockedUntil,
        updatedAt: updatedAt ?? this.updatedAt,
        isDeleted: isDeleted ?? this.isDeleted,
      );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      walletId: data.walletId.present ? data.walletId.value : this.walletId,
      idaccount: data.idaccount.present ? data.idaccount.value : this.idaccount,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      amount: data.amount.present ? data.amount.value : this.amount,
      type: data.type.present ? data.type.value : this.type,
      status: data.status.present ? data.status.value : this.status,
      provider: data.provider.present ? data.provider.value : this.provider,
      note: data.note.present ? data.note.value : this.note,
      date: data.date.present ? data.date.value : this.date,
      images: data.images.present ? data.images.value : this.images,
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      walletTransfer: data.walletTransfer.present
          ? data.walletTransfer.value
          : this.walletTransfer,
      bankTranId:
          data.bankTranId.present ? data.bankTranId.value : this.bankTranId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      syncRetryCount: data.syncRetryCount.present
          ? data.syncRetryCount.value
          : this.syncRetryCount,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
      syncBlockedUntil: data.syncBlockedUntil.present
          ? data.syncBlockedUntil.value
          : this.syncBlockedUntil,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('walletId: $walletId, ')
          ..write('idaccount: $idaccount, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('provider: $provider, ')
          ..write('note: $note, ')
          ..write('date: $date, ')
          ..write('images: $images, ')
          ..write('goalId: $goalId, ')
          ..write('walletTransfer: $walletTransfer, ')
          ..write('bankTranId: $bankTranId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncRetryCount: $syncRetryCount, ')
          ..write('syncError: $syncError, ')
          ..write('syncBlockedUntil: $syncBlockedUntil, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        walletId,
        idaccount,
        categoryId,
        amount,
        type,
        status,
        provider,
        note,
        date,
        images,
        goalId,
        walletTransfer,
        bankTranId,
        deletedAt,
        syncStatus,
        syncRetryCount,
        syncError,
        syncBlockedUntil,
        updatedAt,
        isDeleted
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.walletId == this.walletId &&
          other.idaccount == this.idaccount &&
          other.categoryId == this.categoryId &&
          other.amount == this.amount &&
          other.type == this.type &&
          other.status == this.status &&
          other.provider == this.provider &&
          other.note == this.note &&
          other.date == this.date &&
          other.images == this.images &&
          other.goalId == this.goalId &&
          other.walletTransfer == this.walletTransfer &&
          other.bankTranId == this.bankTranId &&
          other.deletedAt == this.deletedAt &&
          other.syncStatus == this.syncStatus &&
          other.syncRetryCount == this.syncRetryCount &&
          other.syncError == this.syncError &&
          other.syncBlockedUntil == this.syncBlockedUntil &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<String> id;
  final Value<String> walletId;
  final Value<int> idaccount;
  final Value<String?> categoryId;
  final Value<double> amount;
  final Value<String> type;
  final Value<String> status;
  final Value<String> provider;
  final Value<String> note;
  final Value<DateTime> date;
  final Value<String> images;
  final Value<String?> goalId;
  final Value<String?> walletTransfer;
  final Value<String?> bankTranId;
  final Value<DateTime?> deletedAt;
  final Value<String> syncStatus;
  final Value<int> syncRetryCount;
  final Value<String?> syncError;
  final Value<DateTime?> syncBlockedUntil;
  final Value<DateTime> updatedAt;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.walletId = const Value.absent(),
    this.idaccount = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.amount = const Value.absent(),
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    this.provider = const Value.absent(),
    this.note = const Value.absent(),
    this.date = const Value.absent(),
    this.images = const Value.absent(),
    this.goalId = const Value.absent(),
    this.walletTransfer = const Value.absent(),
    this.bankTranId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncRetryCount = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncBlockedUntil = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionsCompanion.insert({
    required String id,
    required String walletId,
    required int idaccount,
    this.categoryId = const Value.absent(),
    required double amount,
    required String type,
    this.status = const Value.absent(),
    this.provider = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime date,
    this.images = const Value.absent(),
    this.goalId = const Value.absent(),
    this.walletTransfer = const Value.absent(),
    this.bankTranId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncRetryCount = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncBlockedUntil = const Value.absent(),
    required DateTime updatedAt,
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        walletId = Value(walletId),
        idaccount = Value(idaccount),
        amount = Value(amount),
        type = Value(type),
        date = Value(date),
        updatedAt = Value(updatedAt);
  static Insertable<Transaction> custom({
    Expression<String>? id,
    Expression<String>? walletId,
    Expression<int>? idaccount,
    Expression<String>? categoryId,
    Expression<double>? amount,
    Expression<String>? type,
    Expression<String>? status,
    Expression<String>? provider,
    Expression<String>? note,
    Expression<DateTime>? date,
    Expression<String>? images,
    Expression<String>? goalId,
    Expression<String>? walletTransfer,
    Expression<String>? bankTranId,
    Expression<DateTime>? deletedAt,
    Expression<String>? syncStatus,
    Expression<int>? syncRetryCount,
    Expression<String>? syncError,
    Expression<DateTime>? syncBlockedUntil,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (walletId != null) 'wallet_id': walletId,
      if (idaccount != null) 'idaccount': idaccount,
      if (categoryId != null) 'category_id': categoryId,
      if (amount != null) 'amount': amount,
      if (type != null) 'type': type,
      if (status != null) 'status': status,
      if (provider != null) 'provider': provider,
      if (note != null) 'note': note,
      if (date != null) 'date': date,
      if (images != null) 'images': images,
      if (goalId != null) 'goal_id': goalId,
      if (walletTransfer != null) 'wallet_transfer': walletTransfer,
      if (bankTranId != null) 'bank_tran_id': bankTranId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (syncRetryCount != null) 'sync_retry_count': syncRetryCount,
      if (syncError != null) 'sync_error': syncError,
      if (syncBlockedUntil != null) 'sync_blocked_until': syncBlockedUntil,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? walletId,
      Value<int>? idaccount,
      Value<String?>? categoryId,
      Value<double>? amount,
      Value<String>? type,
      Value<String>? status,
      Value<String>? provider,
      Value<String>? note,
      Value<DateTime>? date,
      Value<String>? images,
      Value<String?>? goalId,
      Value<String?>? walletTransfer,
      Value<String?>? bankTranId,
      Value<DateTime?>? deletedAt,
      Value<String>? syncStatus,
      Value<int>? syncRetryCount,
      Value<String?>? syncError,
      Value<DateTime?>? syncBlockedUntil,
      Value<DateTime>? updatedAt,
      Value<bool>? isDeleted,
      Value<int>? rowid}) {
    return TransactionsCompanion(
      id: id ?? this.id,
      walletId: walletId ?? this.walletId,
      idaccount: idaccount ?? this.idaccount,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      status: status ?? this.status,
      provider: provider ?? this.provider,
      note: note ?? this.note,
      date: date ?? this.date,
      images: images ?? this.images,
      goalId: goalId ?? this.goalId,
      walletTransfer: walletTransfer ?? this.walletTransfer,
      bankTranId: bankTranId ?? this.bankTranId,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncRetryCount: syncRetryCount ?? this.syncRetryCount,
      syncError: syncError ?? this.syncError,
      syncBlockedUntil: syncBlockedUntil ?? this.syncBlockedUntil,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (walletId.present) {
      map['wallet_id'] = Variable<String>(walletId.value);
    }
    if (idaccount.present) {
      map['idaccount'] = Variable<int>(idaccount.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (images.present) {
      map['images'] = Variable<String>(images.value);
    }
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (walletTransfer.present) {
      map['wallet_transfer'] = Variable<String>(walletTransfer.value);
    }
    if (bankTranId.present) {
      map['bank_tran_id'] = Variable<String>(bankTranId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (syncRetryCount.present) {
      map['sync_retry_count'] = Variable<int>(syncRetryCount.value);
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
    }
    if (syncBlockedUntil.present) {
      map['sync_blocked_until'] = Variable<DateTime>(syncBlockedUntil.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('walletId: $walletId, ')
          ..write('idaccount: $idaccount, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('provider: $provider, ')
          ..write('note: $note, ')
          ..write('date: $date, ')
          ..write('images: $images, ')
          ..write('goalId: $goalId, ')
          ..write('walletTransfer: $walletTransfer, ')
          ..write('bankTranId: $bankTranId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncRetryCount: $syncRetryCount, ')
          ..write('syncError: $syncError, ')
          ..write('syncBlockedUntil: $syncBlockedUntil, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _idaccountMeta =
      const VerificationMeta('idaccount');
  @override
  late final GeneratedColumn<int> idaccount = GeneratedColumn<int>(
      'idaccount', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _classifyMeta =
      const VerificationMeta('classify');
  @override
  late final GeneratedColumn<String> classify = GeneratedColumn<String>(
      'classify', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
      'icon', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('category'));
  static const VerificationMeta _colourMeta = const VerificationMeta('colour');
  @override
  late final GeneratedColumn<String> colour = GeneratedColumn<String>(
      'colour', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('#4CAF50'));
  static const VerificationMeta _isDefaultMeta =
      const VerificationMeta('isDefault');
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
      'is_default', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_default" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
      'parent_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isGroupMeta =
      const VerificationMeta('isGroup');
  @override
  late final GeneratedColumn<bool> isGroup = GeneratedColumn<bool>(
      'is_group', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_group" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isLocalOnlyMeta =
      const VerificationMeta('isLocalOnly');
  @override
  late final GeneratedColumn<bool> isLocalOnly = GeneratedColumn<bool>(
      'is_local_only', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_local_only" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _syncRetryCountMeta =
      const VerificationMeta('syncRetryCount');
  @override
  late final GeneratedColumn<int> syncRetryCount = GeneratedColumn<int>(
      'sync_retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _syncErrorMeta =
      const VerificationMeta('syncError');
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
      'sync_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncBlockedUntilMeta =
      const VerificationMeta('syncBlockedUntil');
  @override
  late final GeneratedColumn<DateTime> syncBlockedUntil =
      GeneratedColumn<DateTime>('sync_blocked_until', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        idaccount,
        name,
        classify,
        icon,
        colour,
        isDefault,
        isDeleted,
        parentId,
        isGroup,
        isLocalOnly,
        deletedAt,
        syncStatus,
        syncRetryCount,
        syncError,
        syncBlockedUntil,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(Insertable<Category> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('idaccount')) {
      context.handle(_idaccountMeta,
          idaccount.isAcceptableOrUnknown(data['idaccount']!, _idaccountMeta));
    } else if (isInserting) {
      context.missing(_idaccountMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('classify')) {
      context.handle(_classifyMeta,
          classify.isAcceptableOrUnknown(data['classify']!, _classifyMeta));
    } else if (isInserting) {
      context.missing(_classifyMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
          _iconMeta, icon.isAcceptableOrUnknown(data['icon']!, _iconMeta));
    }
    if (data.containsKey('colour')) {
      context.handle(_colourMeta,
          colour.isAcceptableOrUnknown(data['colour']!, _colourMeta));
    }
    if (data.containsKey('is_default')) {
      context.handle(_isDefaultMeta,
          isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    }
    if (data.containsKey('is_group')) {
      context.handle(_isGroupMeta,
          isGroup.isAcceptableOrUnknown(data['is_group']!, _isGroupMeta));
    }
    if (data.containsKey('is_local_only')) {
      context.handle(
          _isLocalOnlyMeta,
          isLocalOnly.isAcceptableOrUnknown(
              data['is_local_only']!, _isLocalOnlyMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('sync_retry_count')) {
      context.handle(
          _syncRetryCountMeta,
          syncRetryCount.isAcceptableOrUnknown(
              data['sync_retry_count']!, _syncRetryCountMeta));
    }
    if (data.containsKey('sync_error')) {
      context.handle(_syncErrorMeta,
          syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta));
    }
    if (data.containsKey('sync_blocked_until')) {
      context.handle(
          _syncBlockedUntilMeta,
          syncBlockedUntil.isAcceptableOrUnknown(
              data['sync_blocked_until']!, _syncBlockedUntilMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      idaccount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}idaccount'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      classify: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}classify'])!,
      icon: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon'])!,
      colour: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}colour'])!,
      isDefault: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_default'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_id']),
      isGroup: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_group'])!,
      isLocalOnly: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_local_only'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      syncRetryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_retry_count'])!,
      syncError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_error']),
      syncBlockedUntil: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}sync_blocked_until']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final String id;
  final int idaccount;
  final String name;
  final String classify;
  final String icon;
  final String colour;
  final bool isDefault;
  final bool isDeleted;
  final String? parentId;
  final bool isGroup;
  final bool isLocalOnly;

  /// deletedAt: NULL = đang dùng, có giá trị = đã xóa mềm (đồng bộ với backend)
  final DateTime? deletedAt;
  final String syncStatus;
  final int syncRetryCount;
  final String? syncError;
  final DateTime? syncBlockedUntil;
  final DateTime updatedAt;
  const Category(
      {required this.id,
      required this.idaccount,
      required this.name,
      required this.classify,
      required this.icon,
      required this.colour,
      required this.isDefault,
      required this.isDeleted,
      this.parentId,
      required this.isGroup,
      required this.isLocalOnly,
      this.deletedAt,
      required this.syncStatus,
      required this.syncRetryCount,
      this.syncError,
      this.syncBlockedUntil,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['idaccount'] = Variable<int>(idaccount);
    map['name'] = Variable<String>(name);
    map['classify'] = Variable<String>(classify);
    map['icon'] = Variable<String>(icon);
    map['colour'] = Variable<String>(colour);
    map['is_default'] = Variable<bool>(isDefault);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['is_group'] = Variable<bool>(isGroup);
    map['is_local_only'] = Variable<bool>(isLocalOnly);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    map['sync_retry_count'] = Variable<int>(syncRetryCount);
    if (!nullToAbsent || syncError != null) {
      map['sync_error'] = Variable<String>(syncError);
    }
    if (!nullToAbsent || syncBlockedUntil != null) {
      map['sync_blocked_until'] = Variable<DateTime>(syncBlockedUntil);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      idaccount: Value(idaccount),
      name: Value(name),
      classify: Value(classify),
      icon: Value(icon),
      colour: Value(colour),
      isDefault: Value(isDefault),
      isDeleted: Value(isDeleted),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      isGroup: Value(isGroup),
      isLocalOnly: Value(isLocalOnly),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      syncStatus: Value(syncStatus),
      syncRetryCount: Value(syncRetryCount),
      syncError: syncError == null && nullToAbsent
          ? const Value.absent()
          : Value(syncError),
      syncBlockedUntil: syncBlockedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(syncBlockedUntil),
      updatedAt: Value(updatedAt),
    );
  }

  factory Category.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<String>(json['id']),
      idaccount: serializer.fromJson<int>(json['idaccount']),
      name: serializer.fromJson<String>(json['name']),
      classify: serializer.fromJson<String>(json['classify']),
      icon: serializer.fromJson<String>(json['icon']),
      colour: serializer.fromJson<String>(json['colour']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      isGroup: serializer.fromJson<bool>(json['isGroup']),
      isLocalOnly: serializer.fromJson<bool>(json['isLocalOnly']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      syncRetryCount: serializer.fromJson<int>(json['syncRetryCount']),
      syncError: serializer.fromJson<String?>(json['syncError']),
      syncBlockedUntil:
          serializer.fromJson<DateTime?>(json['syncBlockedUntil']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'idaccount': serializer.toJson<int>(idaccount),
      'name': serializer.toJson<String>(name),
      'classify': serializer.toJson<String>(classify),
      'icon': serializer.toJson<String>(icon),
      'colour': serializer.toJson<String>(colour),
      'isDefault': serializer.toJson<bool>(isDefault),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'parentId': serializer.toJson<String?>(parentId),
      'isGroup': serializer.toJson<bool>(isGroup),
      'isLocalOnly': serializer.toJson<bool>(isLocalOnly),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'syncRetryCount': serializer.toJson<int>(syncRetryCount),
      'syncError': serializer.toJson<String?>(syncError),
      'syncBlockedUntil': serializer.toJson<DateTime?>(syncBlockedUntil),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Category copyWith(
          {String? id,
          int? idaccount,
          String? name,
          String? classify,
          String? icon,
          String? colour,
          bool? isDefault,
          bool? isDeleted,
          Value<String?> parentId = const Value.absent(),
          bool? isGroup,
          bool? isLocalOnly,
          Value<DateTime?> deletedAt = const Value.absent(),
          String? syncStatus,
          int? syncRetryCount,
          Value<String?> syncError = const Value.absent(),
          Value<DateTime?> syncBlockedUntil = const Value.absent(),
          DateTime? updatedAt}) =>
      Category(
        id: id ?? this.id,
        idaccount: idaccount ?? this.idaccount,
        name: name ?? this.name,
        classify: classify ?? this.classify,
        icon: icon ?? this.icon,
        colour: colour ?? this.colour,
        isDefault: isDefault ?? this.isDefault,
        isDeleted: isDeleted ?? this.isDeleted,
        parentId: parentId.present ? parentId.value : this.parentId,
        isGroup: isGroup ?? this.isGroup,
        isLocalOnly: isLocalOnly ?? this.isLocalOnly,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        syncStatus: syncStatus ?? this.syncStatus,
        syncRetryCount: syncRetryCount ?? this.syncRetryCount,
        syncError: syncError.present ? syncError.value : this.syncError,
        syncBlockedUntil: syncBlockedUntil.present
            ? syncBlockedUntil.value
            : this.syncBlockedUntil,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      idaccount: data.idaccount.present ? data.idaccount.value : this.idaccount,
      name: data.name.present ? data.name.value : this.name,
      classify: data.classify.present ? data.classify.value : this.classify,
      icon: data.icon.present ? data.icon.value : this.icon,
      colour: data.colour.present ? data.colour.value : this.colour,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      isGroup: data.isGroup.present ? data.isGroup.value : this.isGroup,
      isLocalOnly:
          data.isLocalOnly.present ? data.isLocalOnly.value : this.isLocalOnly,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      syncRetryCount: data.syncRetryCount.present
          ? data.syncRetryCount.value
          : this.syncRetryCount,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
      syncBlockedUntil: data.syncBlockedUntil.present
          ? data.syncBlockedUntil.value
          : this.syncBlockedUntil,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('idaccount: $idaccount, ')
          ..write('name: $name, ')
          ..write('classify: $classify, ')
          ..write('icon: $icon, ')
          ..write('colour: $colour, ')
          ..write('isDefault: $isDefault, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('parentId: $parentId, ')
          ..write('isGroup: $isGroup, ')
          ..write('isLocalOnly: $isLocalOnly, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncRetryCount: $syncRetryCount, ')
          ..write('syncError: $syncError, ')
          ..write('syncBlockedUntil: $syncBlockedUntil, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      idaccount,
      name,
      classify,
      icon,
      colour,
      isDefault,
      isDeleted,
      parentId,
      isGroup,
      isLocalOnly,
      deletedAt,
      syncStatus,
      syncRetryCount,
      syncError,
      syncBlockedUntil,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.idaccount == this.idaccount &&
          other.name == this.name &&
          other.classify == this.classify &&
          other.icon == this.icon &&
          other.colour == this.colour &&
          other.isDefault == this.isDefault &&
          other.isDeleted == this.isDeleted &&
          other.parentId == this.parentId &&
          other.isGroup == this.isGroup &&
          other.isLocalOnly == this.isLocalOnly &&
          other.deletedAt == this.deletedAt &&
          other.syncStatus == this.syncStatus &&
          other.syncRetryCount == this.syncRetryCount &&
          other.syncError == this.syncError &&
          other.syncBlockedUntil == this.syncBlockedUntil &&
          other.updatedAt == this.updatedAt);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> id;
  final Value<int> idaccount;
  final Value<String> name;
  final Value<String> classify;
  final Value<String> icon;
  final Value<String> colour;
  final Value<bool> isDefault;
  final Value<bool> isDeleted;
  final Value<String?> parentId;
  final Value<bool> isGroup;
  final Value<bool> isLocalOnly;
  final Value<DateTime?> deletedAt;
  final Value<String> syncStatus;
  final Value<int> syncRetryCount;
  final Value<String?> syncError;
  final Value<DateTime?> syncBlockedUntil;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.idaccount = const Value.absent(),
    this.name = const Value.absent(),
    this.classify = const Value.absent(),
    this.icon = const Value.absent(),
    this.colour = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.parentId = const Value.absent(),
    this.isGroup = const Value.absent(),
    this.isLocalOnly = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncRetryCount = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncBlockedUntil = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required int idaccount,
    required String name,
    required String classify,
    this.icon = const Value.absent(),
    this.colour = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.parentId = const Value.absent(),
    this.isGroup = const Value.absent(),
    this.isLocalOnly = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncRetryCount = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncBlockedUntil = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        idaccount = Value(idaccount),
        name = Value(name),
        classify = Value(classify),
        updatedAt = Value(updatedAt);
  static Insertable<Category> custom({
    Expression<String>? id,
    Expression<int>? idaccount,
    Expression<String>? name,
    Expression<String>? classify,
    Expression<String>? icon,
    Expression<String>? colour,
    Expression<bool>? isDefault,
    Expression<bool>? isDeleted,
    Expression<String>? parentId,
    Expression<bool>? isGroup,
    Expression<bool>? isLocalOnly,
    Expression<DateTime>? deletedAt,
    Expression<String>? syncStatus,
    Expression<int>? syncRetryCount,
    Expression<String>? syncError,
    Expression<DateTime>? syncBlockedUntil,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (idaccount != null) 'idaccount': idaccount,
      if (name != null) 'name': name,
      if (classify != null) 'classify': classify,
      if (icon != null) 'icon': icon,
      if (colour != null) 'colour': colour,
      if (isDefault != null) 'is_default': isDefault,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (parentId != null) 'parent_id': parentId,
      if (isGroup != null) 'is_group': isGroup,
      if (isLocalOnly != null) 'is_local_only': isLocalOnly,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (syncRetryCount != null) 'sync_retry_count': syncRetryCount,
      if (syncError != null) 'sync_error': syncError,
      if (syncBlockedUntil != null) 'sync_blocked_until': syncBlockedUntil,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith(
      {Value<String>? id,
      Value<int>? idaccount,
      Value<String>? name,
      Value<String>? classify,
      Value<String>? icon,
      Value<String>? colour,
      Value<bool>? isDefault,
      Value<bool>? isDeleted,
      Value<String?>? parentId,
      Value<bool>? isGroup,
      Value<bool>? isLocalOnly,
      Value<DateTime?>? deletedAt,
      Value<String>? syncStatus,
      Value<int>? syncRetryCount,
      Value<String?>? syncError,
      Value<DateTime?>? syncBlockedUntil,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return CategoriesCompanion(
      id: id ?? this.id,
      idaccount: idaccount ?? this.idaccount,
      name: name ?? this.name,
      classify: classify ?? this.classify,
      icon: icon ?? this.icon,
      colour: colour ?? this.colour,
      isDefault: isDefault ?? this.isDefault,
      isDeleted: isDeleted ?? this.isDeleted,
      parentId: parentId ?? this.parentId,
      isGroup: isGroup ?? this.isGroup,
      isLocalOnly: isLocalOnly ?? this.isLocalOnly,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncRetryCount: syncRetryCount ?? this.syncRetryCount,
      syncError: syncError ?? this.syncError,
      syncBlockedUntil: syncBlockedUntil ?? this.syncBlockedUntil,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (idaccount.present) {
      map['idaccount'] = Variable<int>(idaccount.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (classify.present) {
      map['classify'] = Variable<String>(classify.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (colour.present) {
      map['colour'] = Variable<String>(colour.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (isGroup.present) {
      map['is_group'] = Variable<bool>(isGroup.value);
    }
    if (isLocalOnly.present) {
      map['is_local_only'] = Variable<bool>(isLocalOnly.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (syncRetryCount.present) {
      map['sync_retry_count'] = Variable<int>(syncRetryCount.value);
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
    }
    if (syncBlockedUntil.present) {
      map['sync_blocked_until'] = Variable<DateTime>(syncBlockedUntil.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('idaccount: $idaccount, ')
          ..write('name: $name, ')
          ..write('classify: $classify, ')
          ..write('icon: $icon, ')
          ..write('colour: $colour, ')
          ..write('isDefault: $isDefault, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('parentId: $parentId, ')
          ..write('isGroup: $isGroup, ')
          ..write('isLocalOnly: $isLocalOnly, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncRetryCount: $syncRetryCount, ')
          ..write('syncError: $syncError, ')
          ..write('syncBlockedUntil: $syncBlockedUntil, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoryKeywordsTable extends CategoryKeywords
    with TableInfo<$CategoryKeywordsTable, CategoryKeyword> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryKeywordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _idaccountMeta =
      const VerificationMeta('idaccount');
  @override
  late final GeneratedColumn<int> idaccount = GeneratedColumn<int>(
      'idaccount', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
      'category_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _keywordMeta =
      const VerificationMeta('keyword');
  @override
  late final GeneratedColumn<String> keyword = GeneratedColumn<String>(
      'keyword', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _normalizedKeywordMeta =
      const VerificationMeta('normalizedKeyword');
  @override
  late final GeneratedColumn<String> normalizedKeyword =
      GeneratedColumn<String>('normalized_keyword', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        idaccount,
        categoryId,
        keyword,
        normalizedKeyword,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category_keywords';
  @override
  VerificationContext validateIntegrity(Insertable<CategoryKeyword> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('idaccount')) {
      context.handle(_idaccountMeta,
          idaccount.isAcceptableOrUnknown(data['idaccount']!, _idaccountMeta));
    } else if (isInserting) {
      context.missing(_idaccountMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('keyword')) {
      context.handle(_keywordMeta,
          keyword.isAcceptableOrUnknown(data['keyword']!, _keywordMeta));
    } else if (isInserting) {
      context.missing(_keywordMeta);
    }
    if (data.containsKey('normalized_keyword')) {
      context.handle(
          _normalizedKeywordMeta,
          normalizedKeyword.isAcceptableOrUnknown(
              data['normalized_keyword']!, _normalizedKeywordMeta));
    } else if (isInserting) {
      context.missing(_normalizedKeywordMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {idaccount, categoryId, normalizedKeyword},
      ];
  @override
  CategoryKeyword map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryKeyword(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      idaccount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}idaccount'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_id'])!,
      keyword: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}keyword'])!,
      normalizedKeyword: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}normalized_keyword'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $CategoryKeywordsTable createAlias(String alias) {
    return $CategoryKeywordsTable(attachedDatabase, alias);
  }
}

class CategoryKeyword extends DataClass implements Insertable<CategoryKeyword> {
  final String id;
  final int idaccount;
  final String categoryId;
  final String keyword;
  final String normalizedKeyword;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CategoryKeyword(
      {required this.id,
      required this.idaccount,
      required this.categoryId,
      required this.keyword,
      required this.normalizedKeyword,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['idaccount'] = Variable<int>(idaccount);
    map['category_id'] = Variable<String>(categoryId);
    map['keyword'] = Variable<String>(keyword);
    map['normalized_keyword'] = Variable<String>(normalizedKeyword);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CategoryKeywordsCompanion toCompanion(bool nullToAbsent) {
    return CategoryKeywordsCompanion(
      id: Value(id),
      idaccount: Value(idaccount),
      categoryId: Value(categoryId),
      keyword: Value(keyword),
      normalizedKeyword: Value(normalizedKeyword),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CategoryKeyword.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryKeyword(
      id: serializer.fromJson<String>(json['id']),
      idaccount: serializer.fromJson<int>(json['idaccount']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      keyword: serializer.fromJson<String>(json['keyword']),
      normalizedKeyword: serializer.fromJson<String>(json['normalizedKeyword']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'idaccount': serializer.toJson<int>(idaccount),
      'categoryId': serializer.toJson<String>(categoryId),
      'keyword': serializer.toJson<String>(keyword),
      'normalizedKeyword': serializer.toJson<String>(normalizedKeyword),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CategoryKeyword copyWith(
          {String? id,
          int? idaccount,
          String? categoryId,
          String? keyword,
          String? normalizedKeyword,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      CategoryKeyword(
        id: id ?? this.id,
        idaccount: idaccount ?? this.idaccount,
        categoryId: categoryId ?? this.categoryId,
        keyword: keyword ?? this.keyword,
        normalizedKeyword: normalizedKeyword ?? this.normalizedKeyword,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  CategoryKeyword copyWithCompanion(CategoryKeywordsCompanion data) {
    return CategoryKeyword(
      id: data.id.present ? data.id.value : this.id,
      idaccount: data.idaccount.present ? data.idaccount.value : this.idaccount,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      keyword: data.keyword.present ? data.keyword.value : this.keyword,
      normalizedKeyword: data.normalizedKeyword.present
          ? data.normalizedKeyword.value
          : this.normalizedKeyword,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryKeyword(')
          ..write('id: $id, ')
          ..write('idaccount: $idaccount, ')
          ..write('categoryId: $categoryId, ')
          ..write('keyword: $keyword, ')
          ..write('normalizedKeyword: $normalizedKeyword, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, idaccount, categoryId, keyword,
      normalizedKeyword, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryKeyword &&
          other.id == this.id &&
          other.idaccount == this.idaccount &&
          other.categoryId == this.categoryId &&
          other.keyword == this.keyword &&
          other.normalizedKeyword == this.normalizedKeyword &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CategoryKeywordsCompanion extends UpdateCompanion<CategoryKeyword> {
  final Value<String> id;
  final Value<int> idaccount;
  final Value<String> categoryId;
  final Value<String> keyword;
  final Value<String> normalizedKeyword;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CategoryKeywordsCompanion({
    this.id = const Value.absent(),
    this.idaccount = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.keyword = const Value.absent(),
    this.normalizedKeyword = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoryKeywordsCompanion.insert({
    required String id,
    required int idaccount,
    required String categoryId,
    required String keyword,
    required String normalizedKeyword,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        idaccount = Value(idaccount),
        categoryId = Value(categoryId),
        keyword = Value(keyword),
        normalizedKeyword = Value(normalizedKeyword),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<CategoryKeyword> custom({
    Expression<String>? id,
    Expression<int>? idaccount,
    Expression<String>? categoryId,
    Expression<String>? keyword,
    Expression<String>? normalizedKeyword,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (idaccount != null) 'idaccount': idaccount,
      if (categoryId != null) 'category_id': categoryId,
      if (keyword != null) 'keyword': keyword,
      if (normalizedKeyword != null) 'normalized_keyword': normalizedKeyword,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoryKeywordsCompanion copyWith(
      {Value<String>? id,
      Value<int>? idaccount,
      Value<String>? categoryId,
      Value<String>? keyword,
      Value<String>? normalizedKeyword,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return CategoryKeywordsCompanion(
      id: id ?? this.id,
      idaccount: idaccount ?? this.idaccount,
      categoryId: categoryId ?? this.categoryId,
      keyword: keyword ?? this.keyword,
      normalizedKeyword: normalizedKeyword ?? this.normalizedKeyword,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (idaccount.present) {
      map['idaccount'] = Variable<int>(idaccount.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (keyword.present) {
      map['keyword'] = Variable<String>(keyword.value);
    }
    if (normalizedKeyword.present) {
      map['normalized_keyword'] = Variable<String>(normalizedKeyword.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryKeywordsCompanion(')
          ..write('id: $id, ')
          ..write('idaccount: $idaccount, ')
          ..write('categoryId: $categoryId, ')
          ..write('keyword: $keyword, ')
          ..write('normalizedKeyword: $normalizedKeyword, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoryGroupMembershipsTable extends CategoryGroupMemberships
    with TableInfo<$CategoryGroupMembershipsTable, CategoryGroupMembership> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryGroupMembershipsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _idaccountMeta =
      const VerificationMeta('idaccount');
  @override
  late final GeneratedColumn<int> idaccount = GeneratedColumn<int>(
      'idaccount', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
      'category_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, idaccount, groupId, categoryId, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category_group_memberships';
  @override
  VerificationContext validateIntegrity(
      Insertable<CategoryGroupMembership> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('idaccount')) {
      context.handle(_idaccountMeta,
          idaccount.isAcceptableOrUnknown(data['idaccount']!, _idaccountMeta));
    } else if (isInserting) {
      context.missing(_idaccountMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {idaccount, categoryId},
      ];
  @override
  CategoryGroupMembership map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryGroupMembership(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      idaccount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}idaccount'])!,
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $CategoryGroupMembershipsTable createAlias(String alias) {
    return $CategoryGroupMembershipsTable(attachedDatabase, alias);
  }
}

class CategoryGroupMembership extends DataClass
    implements Insertable<CategoryGroupMembership> {
  final String id;
  final int idaccount;
  final String groupId;
  final String categoryId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CategoryGroupMembership(
      {required this.id,
      required this.idaccount,
      required this.groupId,
      required this.categoryId,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['idaccount'] = Variable<int>(idaccount);
    map['group_id'] = Variable<String>(groupId);
    map['category_id'] = Variable<String>(categoryId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CategoryGroupMembershipsCompanion toCompanion(bool nullToAbsent) {
    return CategoryGroupMembershipsCompanion(
      id: Value(id),
      idaccount: Value(idaccount),
      groupId: Value(groupId),
      categoryId: Value(categoryId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CategoryGroupMembership.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryGroupMembership(
      id: serializer.fromJson<String>(json['id']),
      idaccount: serializer.fromJson<int>(json['idaccount']),
      groupId: serializer.fromJson<String>(json['groupId']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'idaccount': serializer.toJson<int>(idaccount),
      'groupId': serializer.toJson<String>(groupId),
      'categoryId': serializer.toJson<String>(categoryId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CategoryGroupMembership copyWith(
          {String? id,
          int? idaccount,
          String? groupId,
          String? categoryId,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      CategoryGroupMembership(
        id: id ?? this.id,
        idaccount: idaccount ?? this.idaccount,
        groupId: groupId ?? this.groupId,
        categoryId: categoryId ?? this.categoryId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  CategoryGroupMembership copyWithCompanion(
      CategoryGroupMembershipsCompanion data) {
    return CategoryGroupMembership(
      id: data.id.present ? data.id.value : this.id,
      idaccount: data.idaccount.present ? data.idaccount.value : this.idaccount,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryGroupMembership(')
          ..write('id: $id, ')
          ..write('idaccount: $idaccount, ')
          ..write('groupId: $groupId, ')
          ..write('categoryId: $categoryId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, idaccount, groupId, categoryId, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryGroupMembership &&
          other.id == this.id &&
          other.idaccount == this.idaccount &&
          other.groupId == this.groupId &&
          other.categoryId == this.categoryId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CategoryGroupMembershipsCompanion
    extends UpdateCompanion<CategoryGroupMembership> {
  final Value<String> id;
  final Value<int> idaccount;
  final Value<String> groupId;
  final Value<String> categoryId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CategoryGroupMembershipsCompanion({
    this.id = const Value.absent(),
    this.idaccount = const Value.absent(),
    this.groupId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoryGroupMembershipsCompanion.insert({
    required String id,
    required int idaccount,
    required String groupId,
    required String categoryId,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        idaccount = Value(idaccount),
        groupId = Value(groupId),
        categoryId = Value(categoryId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<CategoryGroupMembership> custom({
    Expression<String>? id,
    Expression<int>? idaccount,
    Expression<String>? groupId,
    Expression<String>? categoryId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (idaccount != null) 'idaccount': idaccount,
      if (groupId != null) 'group_id': groupId,
      if (categoryId != null) 'category_id': categoryId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoryGroupMembershipsCompanion copyWith(
      {Value<String>? id,
      Value<int>? idaccount,
      Value<String>? groupId,
      Value<String>? categoryId,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return CategoryGroupMembershipsCompanion(
      id: id ?? this.id,
      idaccount: idaccount ?? this.idaccount,
      groupId: groupId ?? this.groupId,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (idaccount.present) {
      map['idaccount'] = Variable<int>(idaccount.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryGroupMembershipsCompanion(')
          ..write('id: $id, ')
          ..write('idaccount: $idaccount, ')
          ..write('groupId: $groupId, ')
          ..write('categoryId: $categoryId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BudgetsTable extends Budgets with TableInfo<$BudgetsTable, Budget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _idaccountMeta =
      const VerificationMeta('idaccount');
  @override
  late final GeneratedColumn<int> idaccount = GeneratedColumn<int>(
      'idaccount', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
      'category_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _spentMeta = const VerificationMeta('spent');
  @override
  late final GeneratedColumn<double> spent = GeneratedColumn<double>(
      'spent', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _overSpendingMeta =
      const VerificationMeta('overSpending');
  @override
  late final GeneratedColumn<String> overSpending = GeneratedColumn<String>(
      'over_spending', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Over'));
  static const VerificationMeta _overAmountMeta =
      const VerificationMeta('overAmount');
  @override
  late final GeneratedColumn<double> overAmount = GeneratedColumn<double>(
      'over_amount', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _thresholdWarningAmountMeta =
      const VerificationMeta('thresholdWarningAmount');
  @override
  late final GeneratedColumn<double> thresholdWarningAmount =
      GeneratedColumn<double>('threshold_warning_amount', aliasedName, true,
          type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _thresholdWarningPercentMeta =
      const VerificationMeta('thresholdWarningPercent');
  @override
  late final GeneratedColumn<double> thresholdWarningPercent =
      GeneratedColumn<double>('threshold_warning_percent', aliasedName, true,
          type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _startDateMeta =
      const VerificationMeta('startDate');
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
      'start_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endDateMeta =
      const VerificationMeta('endDate');
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
      'end_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _recurrenceMeta =
      const VerificationMeta('recurrence');
  @override
  late final GeneratedColumn<bool> recurrence = GeneratedColumn<bool>(
      'recurrence', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("recurrence" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _timeRecurrenceMeta =
      const VerificationMeta('timeRecurrence');
  @override
  late final GeneratedColumn<String> timeRecurrence = GeneratedColumn<String>(
      'time_recurrence', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _nextTimeRecurrenceMeta =
      const VerificationMeta('nextTimeRecurrence');
  @override
  late final GeneratedColumn<DateTime> nextTimeRecurrence =
      GeneratedColumn<DateTime>('next_time_recurrence', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _syncRetryCountMeta =
      const VerificationMeta('syncRetryCount');
  @override
  late final GeneratedColumn<int> syncRetryCount = GeneratedColumn<int>(
      'sync_retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _syncErrorMeta =
      const VerificationMeta('syncError');
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
      'sync_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncBlockedUntilMeta =
      const VerificationMeta('syncBlockedUntil');
  @override
  late final GeneratedColumn<DateTime> syncBlockedUntil =
      GeneratedColumn<DateTime>('sync_blocked_until', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        idaccount,
        categoryId,
        amount,
        spent,
        overSpending,
        overAmount,
        thresholdWarningAmount,
        thresholdWarningPercent,
        startDate,
        endDate,
        recurrence,
        timeRecurrence,
        note,
        nextTimeRecurrence,
        deletedAt,
        isDeleted,
        syncStatus,
        syncRetryCount,
        syncError,
        syncBlockedUntil,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budgets';
  @override
  VerificationContext validateIntegrity(Insertable<Budget> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('idaccount')) {
      context.handle(_idaccountMeta,
          idaccount.isAcceptableOrUnknown(data['idaccount']!, _idaccountMeta));
    } else if (isInserting) {
      context.missing(_idaccountMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('spent')) {
      context.handle(
          _spentMeta, spent.isAcceptableOrUnknown(data['spent']!, _spentMeta));
    }
    if (data.containsKey('over_spending')) {
      context.handle(
          _overSpendingMeta,
          overSpending.isAcceptableOrUnknown(
              data['over_spending']!, _overSpendingMeta));
    }
    if (data.containsKey('over_amount')) {
      context.handle(
          _overAmountMeta,
          overAmount.isAcceptableOrUnknown(
              data['over_amount']!, _overAmountMeta));
    }
    if (data.containsKey('threshold_warning_amount')) {
      context.handle(
          _thresholdWarningAmountMeta,
          thresholdWarningAmount.isAcceptableOrUnknown(
              data['threshold_warning_amount']!, _thresholdWarningAmountMeta));
    }
    if (data.containsKey('threshold_warning_percent')) {
      context.handle(
          _thresholdWarningPercentMeta,
          thresholdWarningPercent.isAcceptableOrUnknown(
              data['threshold_warning_percent']!,
              _thresholdWarningPercentMeta));
    }
    if (data.containsKey('start_date')) {
      context.handle(_startDateMeta,
          startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta));
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(_endDateMeta,
          endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta));
    }
    if (data.containsKey('recurrence')) {
      context.handle(
          _recurrenceMeta,
          recurrence.isAcceptableOrUnknown(
              data['recurrence']!, _recurrenceMeta));
    }
    if (data.containsKey('time_recurrence')) {
      context.handle(
          _timeRecurrenceMeta,
          timeRecurrence.isAcceptableOrUnknown(
              data['time_recurrence']!, _timeRecurrenceMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('next_time_recurrence')) {
      context.handle(
          _nextTimeRecurrenceMeta,
          nextTimeRecurrence.isAcceptableOrUnknown(
              data['next_time_recurrence']!, _nextTimeRecurrenceMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('sync_retry_count')) {
      context.handle(
          _syncRetryCountMeta,
          syncRetryCount.isAcceptableOrUnknown(
              data['sync_retry_count']!, _syncRetryCountMeta));
    }
    if (data.containsKey('sync_error')) {
      context.handle(_syncErrorMeta,
          syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta));
    }
    if (data.containsKey('sync_blocked_until')) {
      context.handle(
          _syncBlockedUntilMeta,
          syncBlockedUntil.isAcceptableOrUnknown(
              data['sync_blocked_until']!, _syncBlockedUntilMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Budget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Budget(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      idaccount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}idaccount'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_id']),
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      spent: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}spent'])!,
      overSpending: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}over_spending'])!,
      overAmount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}over_amount']),
      thresholdWarningAmount: attachedDatabase.typeMapping.read(
          DriftSqlType.double,
          data['${effectivePrefix}threshold_warning_amount']),
      thresholdWarningPercent: attachedDatabase.typeMapping.read(
          DriftSqlType.double,
          data['${effectivePrefix}threshold_warning_percent']),
      startDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_date'])!,
      endDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end_date']),
      recurrence: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}recurrence'])!,
      timeRecurrence: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}time_recurrence']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note'])!,
      nextTimeRecurrence: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}next_time_recurrence']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      syncRetryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_retry_count'])!,
      syncError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_error']),
      syncBlockedUntil: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}sync_blocked_until']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $BudgetsTable createAlias(String alias) {
    return $BudgetsTable(attachedDatabase, alias);
  }
}

class Budget extends DataClass implements Insertable<Budget> {
  final String id;
  final int idaccount;
  final String? categoryId;
  final double amount;
  final double spent;
  final String overSpending;
  final double? overAmount;
  final double? thresholdWarningAmount;

  /// Threshold_Warning_Percent: tỉ lệ đã tiêu chạm ngưỡng cảnh báo, đơn vị
  /// **phần trăm 0–100** (không phải 0.0–1.0) để khớp `Decimal(15,2)` bên
  /// backend. `BudgetEntity` quy về tỉ lệ khi so sánh.
  ///
  /// Thêm ở v11. Backend đã có cột này từ đợt DB v2 nhưng client thì chưa, nên
  /// mọi ngưỡng cảnh báo theo phần trăm người dùng đặt trên một máy đều không
  /// sang được máy khác.
  final double? thresholdWarningPercent;
  final DateTime startDate;
  final DateTime? endDate;
  final bool recurrence;

  /// Time_recurrence: 'Week' | 'Month' | 'Quarter' | 'Year', hoặc **null**.
  ///
  /// null = ngân sách **không theo chu kỳ** nào: người dùng chọn "Ngày cụ thể"
  /// và tự đặt ngày kết thúc. Backend biểu diễn đúng như vậy — ràng buộc
  /// `chk_budget_time_recurrence` là `IS NULL OR IN (...)`.
  ///
  /// Thành nullable ở v12. Trước đó cột là `NOT NULL DEFAULT 'Month'` nên
  /// trạng thái "không chu kỳ" không lưu nổi ở client dù backend vẫn nhận.
  final String? timeRecurrence;
  final String note;

  /// nextTimeRecurrence: thời điểm bắt đầu chu kỳ ngân sách tiếp theo
  final DateTime? nextTimeRecurrence;

  /// deletedAt: NULL = đang dùng, có giá trị = đã xóa mềm
  final DateTime? deletedAt;
  final bool isDeleted;
  final String syncStatus;
  final int syncRetryCount;
  final String? syncError;
  final DateTime? syncBlockedUntil;
  final DateTime updatedAt;
  const Budget(
      {required this.id,
      required this.idaccount,
      this.categoryId,
      required this.amount,
      required this.spent,
      required this.overSpending,
      this.overAmount,
      this.thresholdWarningAmount,
      this.thresholdWarningPercent,
      required this.startDate,
      this.endDate,
      required this.recurrence,
      this.timeRecurrence,
      required this.note,
      this.nextTimeRecurrence,
      this.deletedAt,
      required this.isDeleted,
      required this.syncStatus,
      required this.syncRetryCount,
      this.syncError,
      this.syncBlockedUntil,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['idaccount'] = Variable<int>(idaccount);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['amount'] = Variable<double>(amount);
    map['spent'] = Variable<double>(spent);
    map['over_spending'] = Variable<String>(overSpending);
    if (!nullToAbsent || overAmount != null) {
      map['over_amount'] = Variable<double>(overAmount);
    }
    if (!nullToAbsent || thresholdWarningAmount != null) {
      map['threshold_warning_amount'] =
          Variable<double>(thresholdWarningAmount);
    }
    if (!nullToAbsent || thresholdWarningPercent != null) {
      map['threshold_warning_percent'] =
          Variable<double>(thresholdWarningPercent);
    }
    map['start_date'] = Variable<DateTime>(startDate);
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    map['recurrence'] = Variable<bool>(recurrence);
    if (!nullToAbsent || timeRecurrence != null) {
      map['time_recurrence'] = Variable<String>(timeRecurrence);
    }
    map['note'] = Variable<String>(note);
    if (!nullToAbsent || nextTimeRecurrence != null) {
      map['next_time_recurrence'] = Variable<DateTime>(nextTimeRecurrence);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['sync_status'] = Variable<String>(syncStatus);
    map['sync_retry_count'] = Variable<int>(syncRetryCount);
    if (!nullToAbsent || syncError != null) {
      map['sync_error'] = Variable<String>(syncError);
    }
    if (!nullToAbsent || syncBlockedUntil != null) {
      map['sync_blocked_until'] = Variable<DateTime>(syncBlockedUntil);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BudgetsCompanion toCompanion(bool nullToAbsent) {
    return BudgetsCompanion(
      id: Value(id),
      idaccount: Value(idaccount),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      amount: Value(amount),
      spent: Value(spent),
      overSpending: Value(overSpending),
      overAmount: overAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(overAmount),
      thresholdWarningAmount: thresholdWarningAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(thresholdWarningAmount),
      thresholdWarningPercent: thresholdWarningPercent == null && nullToAbsent
          ? const Value.absent()
          : Value(thresholdWarningPercent),
      startDate: Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      recurrence: Value(recurrence),
      timeRecurrence: timeRecurrence == null && nullToAbsent
          ? const Value.absent()
          : Value(timeRecurrence),
      note: Value(note),
      nextTimeRecurrence: nextTimeRecurrence == null && nullToAbsent
          ? const Value.absent()
          : Value(nextTimeRecurrence),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      isDeleted: Value(isDeleted),
      syncStatus: Value(syncStatus),
      syncRetryCount: Value(syncRetryCount),
      syncError: syncError == null && nullToAbsent
          ? const Value.absent()
          : Value(syncError),
      syncBlockedUntil: syncBlockedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(syncBlockedUntil),
      updatedAt: Value(updatedAt),
    );
  }

  factory Budget.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Budget(
      id: serializer.fromJson<String>(json['id']),
      idaccount: serializer.fromJson<int>(json['idaccount']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      amount: serializer.fromJson<double>(json['amount']),
      spent: serializer.fromJson<double>(json['spent']),
      overSpending: serializer.fromJson<String>(json['overSpending']),
      overAmount: serializer.fromJson<double?>(json['overAmount']),
      thresholdWarningAmount:
          serializer.fromJson<double?>(json['thresholdWarningAmount']),
      thresholdWarningPercent:
          serializer.fromJson<double?>(json['thresholdWarningPercent']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      recurrence: serializer.fromJson<bool>(json['recurrence']),
      timeRecurrence: serializer.fromJson<String?>(json['timeRecurrence']),
      note: serializer.fromJson<String>(json['note']),
      nextTimeRecurrence:
          serializer.fromJson<DateTime?>(json['nextTimeRecurrence']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      syncRetryCount: serializer.fromJson<int>(json['syncRetryCount']),
      syncError: serializer.fromJson<String?>(json['syncError']),
      syncBlockedUntil:
          serializer.fromJson<DateTime?>(json['syncBlockedUntil']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'idaccount': serializer.toJson<int>(idaccount),
      'categoryId': serializer.toJson<String?>(categoryId),
      'amount': serializer.toJson<double>(amount),
      'spent': serializer.toJson<double>(spent),
      'overSpending': serializer.toJson<String>(overSpending),
      'overAmount': serializer.toJson<double?>(overAmount),
      'thresholdWarningAmount':
          serializer.toJson<double?>(thresholdWarningAmount),
      'thresholdWarningPercent':
          serializer.toJson<double?>(thresholdWarningPercent),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'recurrence': serializer.toJson<bool>(recurrence),
      'timeRecurrence': serializer.toJson<String?>(timeRecurrence),
      'note': serializer.toJson<String>(note),
      'nextTimeRecurrence': serializer.toJson<DateTime?>(nextTimeRecurrence),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'syncRetryCount': serializer.toJson<int>(syncRetryCount),
      'syncError': serializer.toJson<String?>(syncError),
      'syncBlockedUntil': serializer.toJson<DateTime?>(syncBlockedUntil),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Budget copyWith(
          {String? id,
          int? idaccount,
          Value<String?> categoryId = const Value.absent(),
          double? amount,
          double? spent,
          String? overSpending,
          Value<double?> overAmount = const Value.absent(),
          Value<double?> thresholdWarningAmount = const Value.absent(),
          Value<double?> thresholdWarningPercent = const Value.absent(),
          DateTime? startDate,
          Value<DateTime?> endDate = const Value.absent(),
          bool? recurrence,
          Value<String?> timeRecurrence = const Value.absent(),
          String? note,
          Value<DateTime?> nextTimeRecurrence = const Value.absent(),
          Value<DateTime?> deletedAt = const Value.absent(),
          bool? isDeleted,
          String? syncStatus,
          int? syncRetryCount,
          Value<String?> syncError = const Value.absent(),
          Value<DateTime?> syncBlockedUntil = const Value.absent(),
          DateTime? updatedAt}) =>
      Budget(
        id: id ?? this.id,
        idaccount: idaccount ?? this.idaccount,
        categoryId: categoryId.present ? categoryId.value : this.categoryId,
        amount: amount ?? this.amount,
        spent: spent ?? this.spent,
        overSpending: overSpending ?? this.overSpending,
        overAmount: overAmount.present ? overAmount.value : this.overAmount,
        thresholdWarningAmount: thresholdWarningAmount.present
            ? thresholdWarningAmount.value
            : this.thresholdWarningAmount,
        thresholdWarningPercent: thresholdWarningPercent.present
            ? thresholdWarningPercent.value
            : this.thresholdWarningPercent,
        startDate: startDate ?? this.startDate,
        endDate: endDate.present ? endDate.value : this.endDate,
        recurrence: recurrence ?? this.recurrence,
        timeRecurrence:
            timeRecurrence.present ? timeRecurrence.value : this.timeRecurrence,
        note: note ?? this.note,
        nextTimeRecurrence: nextTimeRecurrence.present
            ? nextTimeRecurrence.value
            : this.nextTimeRecurrence,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        isDeleted: isDeleted ?? this.isDeleted,
        syncStatus: syncStatus ?? this.syncStatus,
        syncRetryCount: syncRetryCount ?? this.syncRetryCount,
        syncError: syncError.present ? syncError.value : this.syncError,
        syncBlockedUntil: syncBlockedUntil.present
            ? syncBlockedUntil.value
            : this.syncBlockedUntil,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Budget copyWithCompanion(BudgetsCompanion data) {
    return Budget(
      id: data.id.present ? data.id.value : this.id,
      idaccount: data.idaccount.present ? data.idaccount.value : this.idaccount,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      amount: data.amount.present ? data.amount.value : this.amount,
      spent: data.spent.present ? data.spent.value : this.spent,
      overSpending: data.overSpending.present
          ? data.overSpending.value
          : this.overSpending,
      overAmount:
          data.overAmount.present ? data.overAmount.value : this.overAmount,
      thresholdWarningAmount: data.thresholdWarningAmount.present
          ? data.thresholdWarningAmount.value
          : this.thresholdWarningAmount,
      thresholdWarningPercent: data.thresholdWarningPercent.present
          ? data.thresholdWarningPercent.value
          : this.thresholdWarningPercent,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      recurrence:
          data.recurrence.present ? data.recurrence.value : this.recurrence,
      timeRecurrence: data.timeRecurrence.present
          ? data.timeRecurrence.value
          : this.timeRecurrence,
      note: data.note.present ? data.note.value : this.note,
      nextTimeRecurrence: data.nextTimeRecurrence.present
          ? data.nextTimeRecurrence.value
          : this.nextTimeRecurrence,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      syncRetryCount: data.syncRetryCount.present
          ? data.syncRetryCount.value
          : this.syncRetryCount,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
      syncBlockedUntil: data.syncBlockedUntil.present
          ? data.syncBlockedUntil.value
          : this.syncBlockedUntil,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Budget(')
          ..write('id: $id, ')
          ..write('idaccount: $idaccount, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('spent: $spent, ')
          ..write('overSpending: $overSpending, ')
          ..write('overAmount: $overAmount, ')
          ..write('thresholdWarningAmount: $thresholdWarningAmount, ')
          ..write('thresholdWarningPercent: $thresholdWarningPercent, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('recurrence: $recurrence, ')
          ..write('timeRecurrence: $timeRecurrence, ')
          ..write('note: $note, ')
          ..write('nextTimeRecurrence: $nextTimeRecurrence, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncRetryCount: $syncRetryCount, ')
          ..write('syncError: $syncError, ')
          ..write('syncBlockedUntil: $syncBlockedUntil, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        idaccount,
        categoryId,
        amount,
        spent,
        overSpending,
        overAmount,
        thresholdWarningAmount,
        thresholdWarningPercent,
        startDate,
        endDate,
        recurrence,
        timeRecurrence,
        note,
        nextTimeRecurrence,
        deletedAt,
        isDeleted,
        syncStatus,
        syncRetryCount,
        syncError,
        syncBlockedUntil,
        updatedAt
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Budget &&
          other.id == this.id &&
          other.idaccount == this.idaccount &&
          other.categoryId == this.categoryId &&
          other.amount == this.amount &&
          other.spent == this.spent &&
          other.overSpending == this.overSpending &&
          other.overAmount == this.overAmount &&
          other.thresholdWarningAmount == this.thresholdWarningAmount &&
          other.thresholdWarningPercent == this.thresholdWarningPercent &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.recurrence == this.recurrence &&
          other.timeRecurrence == this.timeRecurrence &&
          other.note == this.note &&
          other.nextTimeRecurrence == this.nextTimeRecurrence &&
          other.deletedAt == this.deletedAt &&
          other.isDeleted == this.isDeleted &&
          other.syncStatus == this.syncStatus &&
          other.syncRetryCount == this.syncRetryCount &&
          other.syncError == this.syncError &&
          other.syncBlockedUntil == this.syncBlockedUntil &&
          other.updatedAt == this.updatedAt);
}

class BudgetsCompanion extends UpdateCompanion<Budget> {
  final Value<String> id;
  final Value<int> idaccount;
  final Value<String?> categoryId;
  final Value<double> amount;
  final Value<double> spent;
  final Value<String> overSpending;
  final Value<double?> overAmount;
  final Value<double?> thresholdWarningAmount;
  final Value<double?> thresholdWarningPercent;
  final Value<DateTime> startDate;
  final Value<DateTime?> endDate;
  final Value<bool> recurrence;
  final Value<String?> timeRecurrence;
  final Value<String> note;
  final Value<DateTime?> nextTimeRecurrence;
  final Value<DateTime?> deletedAt;
  final Value<bool> isDeleted;
  final Value<String> syncStatus;
  final Value<int> syncRetryCount;
  final Value<String?> syncError;
  final Value<DateTime?> syncBlockedUntil;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BudgetsCompanion({
    this.id = const Value.absent(),
    this.idaccount = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.amount = const Value.absent(),
    this.spent = const Value.absent(),
    this.overSpending = const Value.absent(),
    this.overAmount = const Value.absent(),
    this.thresholdWarningAmount = const Value.absent(),
    this.thresholdWarningPercent = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.timeRecurrence = const Value.absent(),
    this.note = const Value.absent(),
    this.nextTimeRecurrence = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncRetryCount = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncBlockedUntil = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BudgetsCompanion.insert({
    required String id,
    required int idaccount,
    this.categoryId = const Value.absent(),
    required double amount,
    this.spent = const Value.absent(),
    this.overSpending = const Value.absent(),
    this.overAmount = const Value.absent(),
    this.thresholdWarningAmount = const Value.absent(),
    this.thresholdWarningPercent = const Value.absent(),
    required DateTime startDate,
    this.endDate = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.timeRecurrence = const Value.absent(),
    this.note = const Value.absent(),
    this.nextTimeRecurrence = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncRetryCount = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncBlockedUntil = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        idaccount = Value(idaccount),
        amount = Value(amount),
        startDate = Value(startDate),
        updatedAt = Value(updatedAt);
  static Insertable<Budget> custom({
    Expression<String>? id,
    Expression<int>? idaccount,
    Expression<String>? categoryId,
    Expression<double>? amount,
    Expression<double>? spent,
    Expression<String>? overSpending,
    Expression<double>? overAmount,
    Expression<double>? thresholdWarningAmount,
    Expression<double>? thresholdWarningPercent,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<bool>? recurrence,
    Expression<String>? timeRecurrence,
    Expression<String>? note,
    Expression<DateTime>? nextTimeRecurrence,
    Expression<DateTime>? deletedAt,
    Expression<bool>? isDeleted,
    Expression<String>? syncStatus,
    Expression<int>? syncRetryCount,
    Expression<String>? syncError,
    Expression<DateTime>? syncBlockedUntil,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (idaccount != null) 'idaccount': idaccount,
      if (categoryId != null) 'category_id': categoryId,
      if (amount != null) 'amount': amount,
      if (spent != null) 'spent': spent,
      if (overSpending != null) 'over_spending': overSpending,
      if (overAmount != null) 'over_amount': overAmount,
      if (thresholdWarningAmount != null)
        'threshold_warning_amount': thresholdWarningAmount,
      if (thresholdWarningPercent != null)
        'threshold_warning_percent': thresholdWarningPercent,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (recurrence != null) 'recurrence': recurrence,
      if (timeRecurrence != null) 'time_recurrence': timeRecurrence,
      if (note != null) 'note': note,
      if (nextTimeRecurrence != null)
        'next_time_recurrence': nextTimeRecurrence,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (syncRetryCount != null) 'sync_retry_count': syncRetryCount,
      if (syncError != null) 'sync_error': syncError,
      if (syncBlockedUntil != null) 'sync_blocked_until': syncBlockedUntil,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BudgetsCompanion copyWith(
      {Value<String>? id,
      Value<int>? idaccount,
      Value<String?>? categoryId,
      Value<double>? amount,
      Value<double>? spent,
      Value<String>? overSpending,
      Value<double?>? overAmount,
      Value<double?>? thresholdWarningAmount,
      Value<double?>? thresholdWarningPercent,
      Value<DateTime>? startDate,
      Value<DateTime?>? endDate,
      Value<bool>? recurrence,
      Value<String?>? timeRecurrence,
      Value<String>? note,
      Value<DateTime?>? nextTimeRecurrence,
      Value<DateTime?>? deletedAt,
      Value<bool>? isDeleted,
      Value<String>? syncStatus,
      Value<int>? syncRetryCount,
      Value<String?>? syncError,
      Value<DateTime?>? syncBlockedUntil,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return BudgetsCompanion(
      id: id ?? this.id,
      idaccount: idaccount ?? this.idaccount,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      spent: spent ?? this.spent,
      overSpending: overSpending ?? this.overSpending,
      overAmount: overAmount ?? this.overAmount,
      thresholdWarningAmount:
          thresholdWarningAmount ?? this.thresholdWarningAmount,
      thresholdWarningPercent:
          thresholdWarningPercent ?? this.thresholdWarningPercent,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      recurrence: recurrence ?? this.recurrence,
      timeRecurrence: timeRecurrence ?? this.timeRecurrence,
      note: note ?? this.note,
      nextTimeRecurrence: nextTimeRecurrence ?? this.nextTimeRecurrence,
      deletedAt: deletedAt ?? this.deletedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
      syncRetryCount: syncRetryCount ?? this.syncRetryCount,
      syncError: syncError ?? this.syncError,
      syncBlockedUntil: syncBlockedUntil ?? this.syncBlockedUntil,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (idaccount.present) {
      map['idaccount'] = Variable<int>(idaccount.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (spent.present) {
      map['spent'] = Variable<double>(spent.value);
    }
    if (overSpending.present) {
      map['over_spending'] = Variable<String>(overSpending.value);
    }
    if (overAmount.present) {
      map['over_amount'] = Variable<double>(overAmount.value);
    }
    if (thresholdWarningAmount.present) {
      map['threshold_warning_amount'] =
          Variable<double>(thresholdWarningAmount.value);
    }
    if (thresholdWarningPercent.present) {
      map['threshold_warning_percent'] =
          Variable<double>(thresholdWarningPercent.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (recurrence.present) {
      map['recurrence'] = Variable<bool>(recurrence.value);
    }
    if (timeRecurrence.present) {
      map['time_recurrence'] = Variable<String>(timeRecurrence.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (nextTimeRecurrence.present) {
      map['next_time_recurrence'] =
          Variable<DateTime>(nextTimeRecurrence.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (syncRetryCount.present) {
      map['sync_retry_count'] = Variable<int>(syncRetryCount.value);
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
    }
    if (syncBlockedUntil.present) {
      map['sync_blocked_until'] = Variable<DateTime>(syncBlockedUntil.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetsCompanion(')
          ..write('id: $id, ')
          ..write('idaccount: $idaccount, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('spent: $spent, ')
          ..write('overSpending: $overSpending, ')
          ..write('overAmount: $overAmount, ')
          ..write('thresholdWarningAmount: $thresholdWarningAmount, ')
          ..write('thresholdWarningPercent: $thresholdWarningPercent, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('recurrence: $recurrence, ')
          ..write('timeRecurrence: $timeRecurrence, ')
          ..write('note: $note, ')
          ..write('nextTimeRecurrence: $nextTimeRecurrence, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncRetryCount: $syncRetryCount, ')
          ..write('syncError: $syncError, ')
          ..write('syncBlockedUntil: $syncBlockedUntil, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BillsTable extends Bills with TableInfo<$BillsTable, Bill> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BillsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _idaccountMeta =
      const VerificationMeta('idaccount');
  @override
  late final GeneratedColumn<int> idaccount = GeneratedColumn<int>(
      'idaccount', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _walletIdMeta =
      const VerificationMeta('walletId');
  @override
  late final GeneratedColumn<String> walletId = GeneratedColumn<String>(
      'wallet_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
      'category_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _startDateMeta =
      const VerificationMeta('startDate');
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
      'start_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _dueDateMeta =
      const VerificationMeta('dueDate');
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
      'due_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _payStatusMeta =
      const VerificationMeta('payStatus');
  @override
  late final GeneratedColumn<String> payStatus = GeneratedColumn<String>(
      'pay_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Pending'));
  static const VerificationMeta _isPaidMeta = const VerificationMeta('isPaid');
  @override
  late final GeneratedColumn<bool> isPaid = GeneratedColumn<bool>(
      'is_paid', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_paid" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _timeNotificationMeta =
      const VerificationMeta('timeNotification');
  @override
  late final GeneratedColumn<String> timeNotification = GeneratedColumn<String>(
      'time_notification', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isRecurrenceMeta =
      const VerificationMeta('isRecurrence');
  @override
  late final GeneratedColumn<bool> isRecurrence = GeneratedColumn<bool>(
      'is_recurrence', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_recurrence" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _timeRecurrenceMeta =
      const VerificationMeta('timeRecurrence');
  @override
  late final GeneratedColumn<String> timeRecurrence = GeneratedColumn<String>(
      'time_recurrence', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Month'));
  static const VerificationMeta _recurrenceMeta =
      const VerificationMeta('recurrence');
  @override
  late final GeneratedColumn<String> recurrence = GeneratedColumn<String>(
      'recurrence', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('monthly'));
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
      'icon', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('receipt'));
  static const VerificationMeta _colourMeta = const VerificationMeta('colour');
  @override
  late final GeneratedColumn<String> colour = GeneratedColumn<String>(
      'colour', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('#4CAF50'));
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _syncRetryCountMeta =
      const VerificationMeta('syncRetryCount');
  @override
  late final GeneratedColumn<int> syncRetryCount = GeneratedColumn<int>(
      'sync_retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _syncErrorMeta =
      const VerificationMeta('syncError');
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
      'sync_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncBlockedUntilMeta =
      const VerificationMeta('syncBlockedUntil');
  @override
  late final GeneratedColumn<DateTime> syncBlockedUntil =
      GeneratedColumn<DateTime>('sync_blocked_until', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        idaccount,
        walletId,
        categoryId,
        name,
        amount,
        startDate,
        dueDate,
        payStatus,
        isPaid,
        timeNotification,
        isRecurrence,
        timeRecurrence,
        recurrence,
        icon,
        colour,
        note,
        deletedAt,
        isDeleted,
        syncStatus,
        syncRetryCount,
        syncError,
        syncBlockedUntil,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bills';
  @override
  VerificationContext validateIntegrity(Insertable<Bill> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('idaccount')) {
      context.handle(_idaccountMeta,
          idaccount.isAcceptableOrUnknown(data['idaccount']!, _idaccountMeta));
    } else if (isInserting) {
      context.missing(_idaccountMeta);
    }
    if (data.containsKey('wallet_id')) {
      context.handle(_walletIdMeta,
          walletId.isAcceptableOrUnknown(data['wallet_id']!, _walletIdMeta));
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(_startDateMeta,
          startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta));
    }
    if (data.containsKey('due_date')) {
      context.handle(_dueDateMeta,
          dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta));
    } else if (isInserting) {
      context.missing(_dueDateMeta);
    }
    if (data.containsKey('pay_status')) {
      context.handle(_payStatusMeta,
          payStatus.isAcceptableOrUnknown(data['pay_status']!, _payStatusMeta));
    }
    if (data.containsKey('is_paid')) {
      context.handle(_isPaidMeta,
          isPaid.isAcceptableOrUnknown(data['is_paid']!, _isPaidMeta));
    }
    if (data.containsKey('time_notification')) {
      context.handle(
          _timeNotificationMeta,
          timeNotification.isAcceptableOrUnknown(
              data['time_notification']!, _timeNotificationMeta));
    }
    if (data.containsKey('is_recurrence')) {
      context.handle(
          _isRecurrenceMeta,
          isRecurrence.isAcceptableOrUnknown(
              data['is_recurrence']!, _isRecurrenceMeta));
    }
    if (data.containsKey('time_recurrence')) {
      context.handle(
          _timeRecurrenceMeta,
          timeRecurrence.isAcceptableOrUnknown(
              data['time_recurrence']!, _timeRecurrenceMeta));
    }
    if (data.containsKey('recurrence')) {
      context.handle(
          _recurrenceMeta,
          recurrence.isAcceptableOrUnknown(
              data['recurrence']!, _recurrenceMeta));
    }
    if (data.containsKey('icon')) {
      context.handle(
          _iconMeta, icon.isAcceptableOrUnknown(data['icon']!, _iconMeta));
    }
    if (data.containsKey('colour')) {
      context.handle(_colourMeta,
          colour.isAcceptableOrUnknown(data['colour']!, _colourMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('sync_retry_count')) {
      context.handle(
          _syncRetryCountMeta,
          syncRetryCount.isAcceptableOrUnknown(
              data['sync_retry_count']!, _syncRetryCountMeta));
    }
    if (data.containsKey('sync_error')) {
      context.handle(_syncErrorMeta,
          syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta));
    }
    if (data.containsKey('sync_blocked_until')) {
      context.handle(
          _syncBlockedUntilMeta,
          syncBlockedUntil.isAcceptableOrUnknown(
              data['sync_blocked_until']!, _syncBlockedUntilMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Bill map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bill(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      idaccount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}idaccount'])!,
      walletId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}wallet_id']),
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_id']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      startDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_date']),
      dueDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}due_date'])!,
      payStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pay_status'])!,
      isPaid: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_paid'])!,
      timeNotification: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}time_notification']),
      isRecurrence: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_recurrence'])!,
      timeRecurrence: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}time_recurrence'])!,
      recurrence: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recurrence'])!,
      icon: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon'])!,
      colour: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}colour'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      syncRetryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_retry_count'])!,
      syncError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_error']),
      syncBlockedUntil: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}sync_blocked_until']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $BillsTable createAlias(String alias) {
    return $BillsTable(attachedDatabase, alias);
  }
}

class Bill extends DataClass implements Insertable<Bill> {
  final String id;
  final int idaccount;

  /// walletId: ví thanh toán bill (BẮT BUỘC theo backend v2)
  final String? walletId;

  /// categoryId: danh mục bill (BẮT BUỘC theo backend v2)
  final String? categoryId;
  final String name;
  final double amount;

  /// startDate: ngày bắt đầu tính hoá đơn (Start_date từ backend)
  final DateTime? startDate;
  final DateTime dueDate;

  /// payStatus: trạng thái thanh toán — 'Pending' | 'Payed' | 'Overdue'
  /// Thay thế isPaid (boolean) để biểu diễn đủ 3 trạng thái từ backend
  final String payStatus;

  /// isPaid: giữ backward compat — TRUE = Payed, FALSE = Pending
  final bool isPaid;

  /// timeNotification: số ngày nhắc trước khi đến hạn — '1' | '3' | '5' | '7'
  final String? timeNotification;

  /// isRecurrence: có lặp lại định kỳ không (DB v2: Recurrence bool)
  final bool isRecurrence;

  /// timeRecurrence: 'Week' | 'Month' | 'Quarter' | 'Year' (DB v2)
  final String timeRecurrence;

  /// recurrence: giữ backward compat — text cũ ('once'/'weekly'/'monthly'...)
  final String recurrence;
  final String icon;
  final String colour;
  final String note;

  /// deletedAt: NULL = đang dùng, có giá trị = đã xóa mềm
  final DateTime? deletedAt;
  final bool isDeleted;
  final String syncStatus;
  final int syncRetryCount;
  final String? syncError;
  final DateTime? syncBlockedUntil;
  final DateTime updatedAt;
  const Bill(
      {required this.id,
      required this.idaccount,
      this.walletId,
      this.categoryId,
      required this.name,
      required this.amount,
      this.startDate,
      required this.dueDate,
      required this.payStatus,
      required this.isPaid,
      this.timeNotification,
      required this.isRecurrence,
      required this.timeRecurrence,
      required this.recurrence,
      required this.icon,
      required this.colour,
      required this.note,
      this.deletedAt,
      required this.isDeleted,
      required this.syncStatus,
      required this.syncRetryCount,
      this.syncError,
      this.syncBlockedUntil,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['idaccount'] = Variable<int>(idaccount);
    if (!nullToAbsent || walletId != null) {
      map['wallet_id'] = Variable<String>(walletId);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['name'] = Variable<String>(name);
    map['amount'] = Variable<double>(amount);
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<DateTime>(startDate);
    }
    map['due_date'] = Variable<DateTime>(dueDate);
    map['pay_status'] = Variable<String>(payStatus);
    map['is_paid'] = Variable<bool>(isPaid);
    if (!nullToAbsent || timeNotification != null) {
      map['time_notification'] = Variable<String>(timeNotification);
    }
    map['is_recurrence'] = Variable<bool>(isRecurrence);
    map['time_recurrence'] = Variable<String>(timeRecurrence);
    map['recurrence'] = Variable<String>(recurrence);
    map['icon'] = Variable<String>(icon);
    map['colour'] = Variable<String>(colour);
    map['note'] = Variable<String>(note);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['sync_status'] = Variable<String>(syncStatus);
    map['sync_retry_count'] = Variable<int>(syncRetryCount);
    if (!nullToAbsent || syncError != null) {
      map['sync_error'] = Variable<String>(syncError);
    }
    if (!nullToAbsent || syncBlockedUntil != null) {
      map['sync_blocked_until'] = Variable<DateTime>(syncBlockedUntil);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BillsCompanion toCompanion(bool nullToAbsent) {
    return BillsCompanion(
      id: Value(id),
      idaccount: Value(idaccount),
      walletId: walletId == null && nullToAbsent
          ? const Value.absent()
          : Value(walletId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      name: Value(name),
      amount: Value(amount),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      dueDate: Value(dueDate),
      payStatus: Value(payStatus),
      isPaid: Value(isPaid),
      timeNotification: timeNotification == null && nullToAbsent
          ? const Value.absent()
          : Value(timeNotification),
      isRecurrence: Value(isRecurrence),
      timeRecurrence: Value(timeRecurrence),
      recurrence: Value(recurrence),
      icon: Value(icon),
      colour: Value(colour),
      note: Value(note),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      isDeleted: Value(isDeleted),
      syncStatus: Value(syncStatus),
      syncRetryCount: Value(syncRetryCount),
      syncError: syncError == null && nullToAbsent
          ? const Value.absent()
          : Value(syncError),
      syncBlockedUntil: syncBlockedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(syncBlockedUntil),
      updatedAt: Value(updatedAt),
    );
  }

  factory Bill.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bill(
      id: serializer.fromJson<String>(json['id']),
      idaccount: serializer.fromJson<int>(json['idaccount']),
      walletId: serializer.fromJson<String?>(json['walletId']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      name: serializer.fromJson<String>(json['name']),
      amount: serializer.fromJson<double>(json['amount']),
      startDate: serializer.fromJson<DateTime?>(json['startDate']),
      dueDate: serializer.fromJson<DateTime>(json['dueDate']),
      payStatus: serializer.fromJson<String>(json['payStatus']),
      isPaid: serializer.fromJson<bool>(json['isPaid']),
      timeNotification: serializer.fromJson<String?>(json['timeNotification']),
      isRecurrence: serializer.fromJson<bool>(json['isRecurrence']),
      timeRecurrence: serializer.fromJson<String>(json['timeRecurrence']),
      recurrence: serializer.fromJson<String>(json['recurrence']),
      icon: serializer.fromJson<String>(json['icon']),
      colour: serializer.fromJson<String>(json['colour']),
      note: serializer.fromJson<String>(json['note']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      syncRetryCount: serializer.fromJson<int>(json['syncRetryCount']),
      syncError: serializer.fromJson<String?>(json['syncError']),
      syncBlockedUntil:
          serializer.fromJson<DateTime?>(json['syncBlockedUntil']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'idaccount': serializer.toJson<int>(idaccount),
      'walletId': serializer.toJson<String?>(walletId),
      'categoryId': serializer.toJson<String?>(categoryId),
      'name': serializer.toJson<String>(name),
      'amount': serializer.toJson<double>(amount),
      'startDate': serializer.toJson<DateTime?>(startDate),
      'dueDate': serializer.toJson<DateTime>(dueDate),
      'payStatus': serializer.toJson<String>(payStatus),
      'isPaid': serializer.toJson<bool>(isPaid),
      'timeNotification': serializer.toJson<String?>(timeNotification),
      'isRecurrence': serializer.toJson<bool>(isRecurrence),
      'timeRecurrence': serializer.toJson<String>(timeRecurrence),
      'recurrence': serializer.toJson<String>(recurrence),
      'icon': serializer.toJson<String>(icon),
      'colour': serializer.toJson<String>(colour),
      'note': serializer.toJson<String>(note),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'syncRetryCount': serializer.toJson<int>(syncRetryCount),
      'syncError': serializer.toJson<String?>(syncError),
      'syncBlockedUntil': serializer.toJson<DateTime?>(syncBlockedUntil),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Bill copyWith(
          {String? id,
          int? idaccount,
          Value<String?> walletId = const Value.absent(),
          Value<String?> categoryId = const Value.absent(),
          String? name,
          double? amount,
          Value<DateTime?> startDate = const Value.absent(),
          DateTime? dueDate,
          String? payStatus,
          bool? isPaid,
          Value<String?> timeNotification = const Value.absent(),
          bool? isRecurrence,
          String? timeRecurrence,
          String? recurrence,
          String? icon,
          String? colour,
          String? note,
          Value<DateTime?> deletedAt = const Value.absent(),
          bool? isDeleted,
          String? syncStatus,
          int? syncRetryCount,
          Value<String?> syncError = const Value.absent(),
          Value<DateTime?> syncBlockedUntil = const Value.absent(),
          DateTime? updatedAt}) =>
      Bill(
        id: id ?? this.id,
        idaccount: idaccount ?? this.idaccount,
        walletId: walletId.present ? walletId.value : this.walletId,
        categoryId: categoryId.present ? categoryId.value : this.categoryId,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        startDate: startDate.present ? startDate.value : this.startDate,
        dueDate: dueDate ?? this.dueDate,
        payStatus: payStatus ?? this.payStatus,
        isPaid: isPaid ?? this.isPaid,
        timeNotification: timeNotification.present
            ? timeNotification.value
            : this.timeNotification,
        isRecurrence: isRecurrence ?? this.isRecurrence,
        timeRecurrence: timeRecurrence ?? this.timeRecurrence,
        recurrence: recurrence ?? this.recurrence,
        icon: icon ?? this.icon,
        colour: colour ?? this.colour,
        note: note ?? this.note,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        isDeleted: isDeleted ?? this.isDeleted,
        syncStatus: syncStatus ?? this.syncStatus,
        syncRetryCount: syncRetryCount ?? this.syncRetryCount,
        syncError: syncError.present ? syncError.value : this.syncError,
        syncBlockedUntil: syncBlockedUntil.present
            ? syncBlockedUntil.value
            : this.syncBlockedUntil,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Bill copyWithCompanion(BillsCompanion data) {
    return Bill(
      id: data.id.present ? data.id.value : this.id,
      idaccount: data.idaccount.present ? data.idaccount.value : this.idaccount,
      walletId: data.walletId.present ? data.walletId.value : this.walletId,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      name: data.name.present ? data.name.value : this.name,
      amount: data.amount.present ? data.amount.value : this.amount,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      payStatus: data.payStatus.present ? data.payStatus.value : this.payStatus,
      isPaid: data.isPaid.present ? data.isPaid.value : this.isPaid,
      timeNotification: data.timeNotification.present
          ? data.timeNotification.value
          : this.timeNotification,
      isRecurrence: data.isRecurrence.present
          ? data.isRecurrence.value
          : this.isRecurrence,
      timeRecurrence: data.timeRecurrence.present
          ? data.timeRecurrence.value
          : this.timeRecurrence,
      recurrence:
          data.recurrence.present ? data.recurrence.value : this.recurrence,
      icon: data.icon.present ? data.icon.value : this.icon,
      colour: data.colour.present ? data.colour.value : this.colour,
      note: data.note.present ? data.note.value : this.note,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      syncRetryCount: data.syncRetryCount.present
          ? data.syncRetryCount.value
          : this.syncRetryCount,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
      syncBlockedUntil: data.syncBlockedUntil.present
          ? data.syncBlockedUntil.value
          : this.syncBlockedUntil,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bill(')
          ..write('id: $id, ')
          ..write('idaccount: $idaccount, ')
          ..write('walletId: $walletId, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('amount: $amount, ')
          ..write('startDate: $startDate, ')
          ..write('dueDate: $dueDate, ')
          ..write('payStatus: $payStatus, ')
          ..write('isPaid: $isPaid, ')
          ..write('timeNotification: $timeNotification, ')
          ..write('isRecurrence: $isRecurrence, ')
          ..write('timeRecurrence: $timeRecurrence, ')
          ..write('recurrence: $recurrence, ')
          ..write('icon: $icon, ')
          ..write('colour: $colour, ')
          ..write('note: $note, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncRetryCount: $syncRetryCount, ')
          ..write('syncError: $syncError, ')
          ..write('syncBlockedUntil: $syncBlockedUntil, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        idaccount,
        walletId,
        categoryId,
        name,
        amount,
        startDate,
        dueDate,
        payStatus,
        isPaid,
        timeNotification,
        isRecurrence,
        timeRecurrence,
        recurrence,
        icon,
        colour,
        note,
        deletedAt,
        isDeleted,
        syncStatus,
        syncRetryCount,
        syncError,
        syncBlockedUntil,
        updatedAt
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bill &&
          other.id == this.id &&
          other.idaccount == this.idaccount &&
          other.walletId == this.walletId &&
          other.categoryId == this.categoryId &&
          other.name == this.name &&
          other.amount == this.amount &&
          other.startDate == this.startDate &&
          other.dueDate == this.dueDate &&
          other.payStatus == this.payStatus &&
          other.isPaid == this.isPaid &&
          other.timeNotification == this.timeNotification &&
          other.isRecurrence == this.isRecurrence &&
          other.timeRecurrence == this.timeRecurrence &&
          other.recurrence == this.recurrence &&
          other.icon == this.icon &&
          other.colour == this.colour &&
          other.note == this.note &&
          other.deletedAt == this.deletedAt &&
          other.isDeleted == this.isDeleted &&
          other.syncStatus == this.syncStatus &&
          other.syncRetryCount == this.syncRetryCount &&
          other.syncError == this.syncError &&
          other.syncBlockedUntil == this.syncBlockedUntil &&
          other.updatedAt == this.updatedAt);
}

class BillsCompanion extends UpdateCompanion<Bill> {
  final Value<String> id;
  final Value<int> idaccount;
  final Value<String?> walletId;
  final Value<String?> categoryId;
  final Value<String> name;
  final Value<double> amount;
  final Value<DateTime?> startDate;
  final Value<DateTime> dueDate;
  final Value<String> payStatus;
  final Value<bool> isPaid;
  final Value<String?> timeNotification;
  final Value<bool> isRecurrence;
  final Value<String> timeRecurrence;
  final Value<String> recurrence;
  final Value<String> icon;
  final Value<String> colour;
  final Value<String> note;
  final Value<DateTime?> deletedAt;
  final Value<bool> isDeleted;
  final Value<String> syncStatus;
  final Value<int> syncRetryCount;
  final Value<String?> syncError;
  final Value<DateTime?> syncBlockedUntil;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BillsCompanion({
    this.id = const Value.absent(),
    this.idaccount = const Value.absent(),
    this.walletId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.name = const Value.absent(),
    this.amount = const Value.absent(),
    this.startDate = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.payStatus = const Value.absent(),
    this.isPaid = const Value.absent(),
    this.timeNotification = const Value.absent(),
    this.isRecurrence = const Value.absent(),
    this.timeRecurrence = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.icon = const Value.absent(),
    this.colour = const Value.absent(),
    this.note = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncRetryCount = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncBlockedUntil = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BillsCompanion.insert({
    required String id,
    required int idaccount,
    this.walletId = const Value.absent(),
    this.categoryId = const Value.absent(),
    required String name,
    required double amount,
    this.startDate = const Value.absent(),
    required DateTime dueDate,
    this.payStatus = const Value.absent(),
    this.isPaid = const Value.absent(),
    this.timeNotification = const Value.absent(),
    this.isRecurrence = const Value.absent(),
    this.timeRecurrence = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.icon = const Value.absent(),
    this.colour = const Value.absent(),
    this.note = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncRetryCount = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncBlockedUntil = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        idaccount = Value(idaccount),
        name = Value(name),
        amount = Value(amount),
        dueDate = Value(dueDate),
        updatedAt = Value(updatedAt);
  static Insertable<Bill> custom({
    Expression<String>? id,
    Expression<int>? idaccount,
    Expression<String>? walletId,
    Expression<String>? categoryId,
    Expression<String>? name,
    Expression<double>? amount,
    Expression<DateTime>? startDate,
    Expression<DateTime>? dueDate,
    Expression<String>? payStatus,
    Expression<bool>? isPaid,
    Expression<String>? timeNotification,
    Expression<bool>? isRecurrence,
    Expression<String>? timeRecurrence,
    Expression<String>? recurrence,
    Expression<String>? icon,
    Expression<String>? colour,
    Expression<String>? note,
    Expression<DateTime>? deletedAt,
    Expression<bool>? isDeleted,
    Expression<String>? syncStatus,
    Expression<int>? syncRetryCount,
    Expression<String>? syncError,
    Expression<DateTime>? syncBlockedUntil,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (idaccount != null) 'idaccount': idaccount,
      if (walletId != null) 'wallet_id': walletId,
      if (categoryId != null) 'category_id': categoryId,
      if (name != null) 'name': name,
      if (amount != null) 'amount': amount,
      if (startDate != null) 'start_date': startDate,
      if (dueDate != null) 'due_date': dueDate,
      if (payStatus != null) 'pay_status': payStatus,
      if (isPaid != null) 'is_paid': isPaid,
      if (timeNotification != null) 'time_notification': timeNotification,
      if (isRecurrence != null) 'is_recurrence': isRecurrence,
      if (timeRecurrence != null) 'time_recurrence': timeRecurrence,
      if (recurrence != null) 'recurrence': recurrence,
      if (icon != null) 'icon': icon,
      if (colour != null) 'colour': colour,
      if (note != null) 'note': note,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (syncRetryCount != null) 'sync_retry_count': syncRetryCount,
      if (syncError != null) 'sync_error': syncError,
      if (syncBlockedUntil != null) 'sync_blocked_until': syncBlockedUntil,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BillsCompanion copyWith(
      {Value<String>? id,
      Value<int>? idaccount,
      Value<String?>? walletId,
      Value<String?>? categoryId,
      Value<String>? name,
      Value<double>? amount,
      Value<DateTime?>? startDate,
      Value<DateTime>? dueDate,
      Value<String>? payStatus,
      Value<bool>? isPaid,
      Value<String?>? timeNotification,
      Value<bool>? isRecurrence,
      Value<String>? timeRecurrence,
      Value<String>? recurrence,
      Value<String>? icon,
      Value<String>? colour,
      Value<String>? note,
      Value<DateTime?>? deletedAt,
      Value<bool>? isDeleted,
      Value<String>? syncStatus,
      Value<int>? syncRetryCount,
      Value<String?>? syncError,
      Value<DateTime?>? syncBlockedUntil,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return BillsCompanion(
      id: id ?? this.id,
      idaccount: idaccount ?? this.idaccount,
      walletId: walletId ?? this.walletId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      payStatus: payStatus ?? this.payStatus,
      isPaid: isPaid ?? this.isPaid,
      timeNotification: timeNotification ?? this.timeNotification,
      isRecurrence: isRecurrence ?? this.isRecurrence,
      timeRecurrence: timeRecurrence ?? this.timeRecurrence,
      recurrence: recurrence ?? this.recurrence,
      icon: icon ?? this.icon,
      colour: colour ?? this.colour,
      note: note ?? this.note,
      deletedAt: deletedAt ?? this.deletedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
      syncRetryCount: syncRetryCount ?? this.syncRetryCount,
      syncError: syncError ?? this.syncError,
      syncBlockedUntil: syncBlockedUntil ?? this.syncBlockedUntil,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (idaccount.present) {
      map['idaccount'] = Variable<int>(idaccount.value);
    }
    if (walletId.present) {
      map['wallet_id'] = Variable<String>(walletId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (payStatus.present) {
      map['pay_status'] = Variable<String>(payStatus.value);
    }
    if (isPaid.present) {
      map['is_paid'] = Variable<bool>(isPaid.value);
    }
    if (timeNotification.present) {
      map['time_notification'] = Variable<String>(timeNotification.value);
    }
    if (isRecurrence.present) {
      map['is_recurrence'] = Variable<bool>(isRecurrence.value);
    }
    if (timeRecurrence.present) {
      map['time_recurrence'] = Variable<String>(timeRecurrence.value);
    }
    if (recurrence.present) {
      map['recurrence'] = Variable<String>(recurrence.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (colour.present) {
      map['colour'] = Variable<String>(colour.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (syncRetryCount.present) {
      map['sync_retry_count'] = Variable<int>(syncRetryCount.value);
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
    }
    if (syncBlockedUntil.present) {
      map['sync_blocked_until'] = Variable<DateTime>(syncBlockedUntil.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BillsCompanion(')
          ..write('id: $id, ')
          ..write('idaccount: $idaccount, ')
          ..write('walletId: $walletId, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('amount: $amount, ')
          ..write('startDate: $startDate, ')
          ..write('dueDate: $dueDate, ')
          ..write('payStatus: $payStatus, ')
          ..write('isPaid: $isPaid, ')
          ..write('timeNotification: $timeNotification, ')
          ..write('isRecurrence: $isRecurrence, ')
          ..write('timeRecurrence: $timeRecurrence, ')
          ..write('recurrence: $recurrence, ')
          ..write('icon: $icon, ')
          ..write('colour: $colour, ')
          ..write('note: $note, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncRetryCount: $syncRetryCount, ')
          ..write('syncError: $syncError, ')
          ..write('syncBlockedUntil: $syncBlockedUntil, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GoalsTable extends Goals with TableInfo<$GoalsTable, Goal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _idaccountMeta =
      const VerificationMeta('idaccount');
  @override
  late final GeneratedColumn<int> idaccount = GeneratedColumn<int>(
      'idaccount', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _targetAmountMeta =
      const VerificationMeta('targetAmount');
  @override
  late final GeneratedColumn<double> targetAmount = GeneratedColumn<double>(
      'target_amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _currentAmountMeta =
      const VerificationMeta('currentAmount');
  @override
  late final GeneratedColumn<double> currentAmount = GeneratedColumn<double>(
      'current_amount', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _startDateMeta =
      const VerificationMeta('startDate');
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
      'start_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _targetDateMeta =
      const VerificationMeta('targetDate');
  @override
  late final GeneratedColumn<DateTime> targetDate = GeneratedColumn<DateTime>(
      'target_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _walletIdMeta =
      const VerificationMeta('walletId');
  @override
  late final GeneratedColumn<String> walletId = GeneratedColumn<String>(
      'wallet_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cycleTakeMoneyMeta =
      const VerificationMeta('cycleTakeMoney');
  @override
  late final GeneratedColumn<String> cycleTakeMoney = GeneratedColumn<String>(
      'cycle_take_money', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timeCycleTakeMoneyMeta =
      const VerificationMeta('timeCycleTakeMoney');
  @override
  late final GeneratedColumn<DateTime> timeCycleTakeMoney =
      GeneratedColumn<DateTime>('time_cycle_take_money', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _autoDepositAmountMeta =
      const VerificationMeta('autoDepositAmount');
  @override
  late final GeneratedColumn<double> autoDepositAmount =
      GeneratedColumn<double>('auto_deposit_amount', aliasedName, true,
          type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _autoDepositWalletIdMeta =
      const VerificationMeta('autoDepositWalletId');
  @override
  late final GeneratedColumn<String> autoDepositWalletId =
      GeneratedColumn<String>('auto_deposit_wallet_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _autoDepositLastRunMeta =
      const VerificationMeta('autoDepositLastRun');
  @override
  late final GeneratedColumn<DateTime> autoDepositLastRun =
      GeneratedColumn<DateTime>('auto_deposit_last_run', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _recurrenceMeta =
      const VerificationMeta('recurrence');
  @override
  late final GeneratedColumn<bool> recurrence = GeneratedColumn<bool>(
      'recurrence', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("recurrence" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _timeRecurrenceMeta =
      const VerificationMeta('timeRecurrence');
  @override
  late final GeneratedColumn<String> timeRecurrence = GeneratedColumn<String>(
      'time_recurrence', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
      'icon', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('flag'));
  static const VerificationMeta _colourMeta = const VerificationMeta('colour');
  @override
  late final GeneratedColumn<String> colour = GeneratedColumn<String>(
      'colour', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('#4CAF50'));
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _isCompletedMeta =
      const VerificationMeta('isCompleted');
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
      'is_completed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_completed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _syncRetryCountMeta =
      const VerificationMeta('syncRetryCount');
  @override
  late final GeneratedColumn<int> syncRetryCount = GeneratedColumn<int>(
      'sync_retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _syncErrorMeta =
      const VerificationMeta('syncError');
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
      'sync_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncBlockedUntilMeta =
      const VerificationMeta('syncBlockedUntil');
  @override
  late final GeneratedColumn<DateTime> syncBlockedUntil =
      GeneratedColumn<DateTime>('sync_blocked_until', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        idaccount,
        name,
        targetAmount,
        currentAmount,
        startDate,
        targetDate,
        walletId,
        cycleTakeMoney,
        timeCycleTakeMoney,
        autoDepositAmount,
        autoDepositWalletId,
        autoDepositLastRun,
        recurrence,
        timeRecurrence,
        icon,
        colour,
        note,
        isCompleted,
        deletedAt,
        isDeleted,
        syncStatus,
        syncRetryCount,
        syncError,
        syncBlockedUntil,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goals';
  @override
  VerificationContext validateIntegrity(Insertable<Goal> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('idaccount')) {
      context.handle(_idaccountMeta,
          idaccount.isAcceptableOrUnknown(data['idaccount']!, _idaccountMeta));
    } else if (isInserting) {
      context.missing(_idaccountMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('target_amount')) {
      context.handle(
          _targetAmountMeta,
          targetAmount.isAcceptableOrUnknown(
              data['target_amount']!, _targetAmountMeta));
    } else if (isInserting) {
      context.missing(_targetAmountMeta);
    }
    if (data.containsKey('current_amount')) {
      context.handle(
          _currentAmountMeta,
          currentAmount.isAcceptableOrUnknown(
              data['current_amount']!, _currentAmountMeta));
    }
    if (data.containsKey('start_date')) {
      context.handle(_startDateMeta,
          startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta));
    }
    if (data.containsKey('target_date')) {
      context.handle(
          _targetDateMeta,
          targetDate.isAcceptableOrUnknown(
              data['target_date']!, _targetDateMeta));
    } else if (isInserting) {
      context.missing(_targetDateMeta);
    }
    if (data.containsKey('wallet_id')) {
      context.handle(_walletIdMeta,
          walletId.isAcceptableOrUnknown(data['wallet_id']!, _walletIdMeta));
    }
    if (data.containsKey('cycle_take_money')) {
      context.handle(
          _cycleTakeMoneyMeta,
          cycleTakeMoney.isAcceptableOrUnknown(
              data['cycle_take_money']!, _cycleTakeMoneyMeta));
    }
    if (data.containsKey('time_cycle_take_money')) {
      context.handle(
          _timeCycleTakeMoneyMeta,
          timeCycleTakeMoney.isAcceptableOrUnknown(
              data['time_cycle_take_money']!, _timeCycleTakeMoneyMeta));
    }
    if (data.containsKey('auto_deposit_amount')) {
      context.handle(
          _autoDepositAmountMeta,
          autoDepositAmount.isAcceptableOrUnknown(
              data['auto_deposit_amount']!, _autoDepositAmountMeta));
    }
    if (data.containsKey('auto_deposit_wallet_id')) {
      context.handle(
          _autoDepositWalletIdMeta,
          autoDepositWalletId.isAcceptableOrUnknown(
              data['auto_deposit_wallet_id']!, _autoDepositWalletIdMeta));
    }
    if (data.containsKey('auto_deposit_last_run')) {
      context.handle(
          _autoDepositLastRunMeta,
          autoDepositLastRun.isAcceptableOrUnknown(
              data['auto_deposit_last_run']!, _autoDepositLastRunMeta));
    }
    if (data.containsKey('recurrence')) {
      context.handle(
          _recurrenceMeta,
          recurrence.isAcceptableOrUnknown(
              data['recurrence']!, _recurrenceMeta));
    }
    if (data.containsKey('time_recurrence')) {
      context.handle(
          _timeRecurrenceMeta,
          timeRecurrence.isAcceptableOrUnknown(
              data['time_recurrence']!, _timeRecurrenceMeta));
    }
    if (data.containsKey('icon')) {
      context.handle(
          _iconMeta, icon.isAcceptableOrUnknown(data['icon']!, _iconMeta));
    }
    if (data.containsKey('colour')) {
      context.handle(_colourMeta,
          colour.isAcceptableOrUnknown(data['colour']!, _colourMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('is_completed')) {
      context.handle(
          _isCompletedMeta,
          isCompleted.isAcceptableOrUnknown(
              data['is_completed']!, _isCompletedMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('sync_retry_count')) {
      context.handle(
          _syncRetryCountMeta,
          syncRetryCount.isAcceptableOrUnknown(
              data['sync_retry_count']!, _syncRetryCountMeta));
    }
    if (data.containsKey('sync_error')) {
      context.handle(_syncErrorMeta,
          syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta));
    }
    if (data.containsKey('sync_blocked_until')) {
      context.handle(
          _syncBlockedUntilMeta,
          syncBlockedUntil.isAcceptableOrUnknown(
              data['sync_blocked_until']!, _syncBlockedUntilMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Goal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Goal(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      idaccount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}idaccount'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      targetAmount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}target_amount'])!,
      currentAmount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}current_amount'])!,
      startDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_date']),
      targetDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}target_date'])!,
      walletId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}wallet_id']),
      cycleTakeMoney: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}cycle_take_money']),
      timeCycleTakeMoney: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}time_cycle_take_money']),
      autoDepositAmount: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}auto_deposit_amount']),
      autoDepositWalletId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}auto_deposit_wallet_id']),
      autoDepositLastRun: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}auto_deposit_last_run']),
      recurrence: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}recurrence'])!,
      timeRecurrence: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}time_recurrence']),
      icon: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon'])!,
      colour: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}colour'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note'])!,
      isCompleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_completed'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      syncRetryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_retry_count'])!,
      syncError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_error']),
      syncBlockedUntil: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}sync_blocked_until']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $GoalsTable createAlias(String alias) {
    return $GoalsTable(attachedDatabase, alias);
  }
}

class Goal extends DataClass implements Insertable<Goal> {
  final String id;
  final int idaccount;
  final String name;
  final double targetAmount;
  final double currentAmount;

  /// startDate: ngày bắt đầu tích luỹ (Start_date từ backend)
  final DateTime? startDate;
  final DateTime targetDate;
  final String? walletId;

  /// cycleTakeMoney: chu kỳ trích tiền — 'Day'|'Week'|'Month'|'Quarter'|'Year'
  final String? cycleTakeMoney;

  /// timeCycleTakeMoney: thời điểm cụ thể trích tiền trong chu kỳ
  ///
  /// ⚠️ Cột này đồng bộ hai chiều nhưng **client chưa bao giờ ghi**. Bộ trích
  /// tự động cố ý KHÔNG dùng nó làm mốc chạy: nó là cột dùng chung với
  /// backend/Admin-web, và đổi ý nghĩa một cột dùng chung mà phía kia chưa
  /// đồng ý là cách hỏng im lặng nhất. Mốc chạy nằm ở [autoDepositLastRun].
  final DateTime? timeCycleTakeMoney;

  /// autoDepositAmount: số tiền trích mỗi kỳ. NULL = không bật trích tự động.
  final double? autoDepositAmount;

  /// autoDepositWalletId: ví NGUỒN của khoản trích. Ví nhận luôn là
  /// [walletId] của chính mục tiêu.
  ///
  /// Không khai khoá ngoại — cùng lý do với `walletTransfer` (bẫy 4.1) — nên
  /// nơi chạy phải tự kiểm ví còn tồn tại.
  final String? autoDepositWalletId;

  /// autoDepositLastRun: mốc của kỳ **gần nhất đã trích xong**.
  ///
  /// NULL nghĩa là chưa bật. Được đặt bằng "bây giờ" tại đúng lúc người dùng
  /// bật công tắc, nên kỳ đầu tiên rơi vào một chu kỳ sau đó. Lấy ngày tạo mục
  /// tiêu làm mốc thay thế là bật công tắc hôm nay rồi bị trích ngược lại sáu
  /// kỳ cùng một lúc.
  final DateTime? autoDepositLastRun;

  /// recurrence: tự động lặp lại mục tiêu sau khi hoàn thành
  final bool recurrence;

  /// timeRecurrence: chu kỳ lặp lại — 'Day'|'Week'|'Month'|'Quarter'|'Year'
  final String? timeRecurrence;
  final String icon;
  final String colour;
  final String note;
  final bool isCompleted;

  /// deletedAt: NULL = đang dùng, có giá trị = đã xóa mềm
  final DateTime? deletedAt;
  final bool isDeleted;
  final String syncStatus;
  final int syncRetryCount;
  final String? syncError;
  final DateTime? syncBlockedUntil;
  final DateTime updatedAt;
  const Goal(
      {required this.id,
      required this.idaccount,
      required this.name,
      required this.targetAmount,
      required this.currentAmount,
      this.startDate,
      required this.targetDate,
      this.walletId,
      this.cycleTakeMoney,
      this.timeCycleTakeMoney,
      this.autoDepositAmount,
      this.autoDepositWalletId,
      this.autoDepositLastRun,
      required this.recurrence,
      this.timeRecurrence,
      required this.icon,
      required this.colour,
      required this.note,
      required this.isCompleted,
      this.deletedAt,
      required this.isDeleted,
      required this.syncStatus,
      required this.syncRetryCount,
      this.syncError,
      this.syncBlockedUntil,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['idaccount'] = Variable<int>(idaccount);
    map['name'] = Variable<String>(name);
    map['target_amount'] = Variable<double>(targetAmount);
    map['current_amount'] = Variable<double>(currentAmount);
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<DateTime>(startDate);
    }
    map['target_date'] = Variable<DateTime>(targetDate);
    if (!nullToAbsent || walletId != null) {
      map['wallet_id'] = Variable<String>(walletId);
    }
    if (!nullToAbsent || cycleTakeMoney != null) {
      map['cycle_take_money'] = Variable<String>(cycleTakeMoney);
    }
    if (!nullToAbsent || timeCycleTakeMoney != null) {
      map['time_cycle_take_money'] = Variable<DateTime>(timeCycleTakeMoney);
    }
    if (!nullToAbsent || autoDepositAmount != null) {
      map['auto_deposit_amount'] = Variable<double>(autoDepositAmount);
    }
    if (!nullToAbsent || autoDepositWalletId != null) {
      map['auto_deposit_wallet_id'] = Variable<String>(autoDepositWalletId);
    }
    if (!nullToAbsent || autoDepositLastRun != null) {
      map['auto_deposit_last_run'] = Variable<DateTime>(autoDepositLastRun);
    }
    map['recurrence'] = Variable<bool>(recurrence);
    if (!nullToAbsent || timeRecurrence != null) {
      map['time_recurrence'] = Variable<String>(timeRecurrence);
    }
    map['icon'] = Variable<String>(icon);
    map['colour'] = Variable<String>(colour);
    map['note'] = Variable<String>(note);
    map['is_completed'] = Variable<bool>(isCompleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['sync_status'] = Variable<String>(syncStatus);
    map['sync_retry_count'] = Variable<int>(syncRetryCount);
    if (!nullToAbsent || syncError != null) {
      map['sync_error'] = Variable<String>(syncError);
    }
    if (!nullToAbsent || syncBlockedUntil != null) {
      map['sync_blocked_until'] = Variable<DateTime>(syncBlockedUntil);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GoalsCompanion toCompanion(bool nullToAbsent) {
    return GoalsCompanion(
      id: Value(id),
      idaccount: Value(idaccount),
      name: Value(name),
      targetAmount: Value(targetAmount),
      currentAmount: Value(currentAmount),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      targetDate: Value(targetDate),
      walletId: walletId == null && nullToAbsent
          ? const Value.absent()
          : Value(walletId),
      cycleTakeMoney: cycleTakeMoney == null && nullToAbsent
          ? const Value.absent()
          : Value(cycleTakeMoney),
      timeCycleTakeMoney: timeCycleTakeMoney == null && nullToAbsent
          ? const Value.absent()
          : Value(timeCycleTakeMoney),
      autoDepositAmount: autoDepositAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(autoDepositAmount),
      autoDepositWalletId: autoDepositWalletId == null && nullToAbsent
          ? const Value.absent()
          : Value(autoDepositWalletId),
      autoDepositLastRun: autoDepositLastRun == null && nullToAbsent
          ? const Value.absent()
          : Value(autoDepositLastRun),
      recurrence: Value(recurrence),
      timeRecurrence: timeRecurrence == null && nullToAbsent
          ? const Value.absent()
          : Value(timeRecurrence),
      icon: Value(icon),
      colour: Value(colour),
      note: Value(note),
      isCompleted: Value(isCompleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      isDeleted: Value(isDeleted),
      syncStatus: Value(syncStatus),
      syncRetryCount: Value(syncRetryCount),
      syncError: syncError == null && nullToAbsent
          ? const Value.absent()
          : Value(syncError),
      syncBlockedUntil: syncBlockedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(syncBlockedUntil),
      updatedAt: Value(updatedAt),
    );
  }

  factory Goal.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Goal(
      id: serializer.fromJson<String>(json['id']),
      idaccount: serializer.fromJson<int>(json['idaccount']),
      name: serializer.fromJson<String>(json['name']),
      targetAmount: serializer.fromJson<double>(json['targetAmount']),
      currentAmount: serializer.fromJson<double>(json['currentAmount']),
      startDate: serializer.fromJson<DateTime?>(json['startDate']),
      targetDate: serializer.fromJson<DateTime>(json['targetDate']),
      walletId: serializer.fromJson<String?>(json['walletId']),
      cycleTakeMoney: serializer.fromJson<String?>(json['cycleTakeMoney']),
      timeCycleTakeMoney:
          serializer.fromJson<DateTime?>(json['timeCycleTakeMoney']),
      autoDepositAmount:
          serializer.fromJson<double?>(json['autoDepositAmount']),
      autoDepositWalletId:
          serializer.fromJson<String?>(json['autoDepositWalletId']),
      autoDepositLastRun:
          serializer.fromJson<DateTime?>(json['autoDepositLastRun']),
      recurrence: serializer.fromJson<bool>(json['recurrence']),
      timeRecurrence: serializer.fromJson<String?>(json['timeRecurrence']),
      icon: serializer.fromJson<String>(json['icon']),
      colour: serializer.fromJson<String>(json['colour']),
      note: serializer.fromJson<String>(json['note']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      syncRetryCount: serializer.fromJson<int>(json['syncRetryCount']),
      syncError: serializer.fromJson<String?>(json['syncError']),
      syncBlockedUntil:
          serializer.fromJson<DateTime?>(json['syncBlockedUntil']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'idaccount': serializer.toJson<int>(idaccount),
      'name': serializer.toJson<String>(name),
      'targetAmount': serializer.toJson<double>(targetAmount),
      'currentAmount': serializer.toJson<double>(currentAmount),
      'startDate': serializer.toJson<DateTime?>(startDate),
      'targetDate': serializer.toJson<DateTime>(targetDate),
      'walletId': serializer.toJson<String?>(walletId),
      'cycleTakeMoney': serializer.toJson<String?>(cycleTakeMoney),
      'timeCycleTakeMoney': serializer.toJson<DateTime?>(timeCycleTakeMoney),
      'autoDepositAmount': serializer.toJson<double?>(autoDepositAmount),
      'autoDepositWalletId': serializer.toJson<String?>(autoDepositWalletId),
      'autoDepositLastRun': serializer.toJson<DateTime?>(autoDepositLastRun),
      'recurrence': serializer.toJson<bool>(recurrence),
      'timeRecurrence': serializer.toJson<String?>(timeRecurrence),
      'icon': serializer.toJson<String>(icon),
      'colour': serializer.toJson<String>(colour),
      'note': serializer.toJson<String>(note),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'syncRetryCount': serializer.toJson<int>(syncRetryCount),
      'syncError': serializer.toJson<String?>(syncError),
      'syncBlockedUntil': serializer.toJson<DateTime?>(syncBlockedUntil),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Goal copyWith(
          {String? id,
          int? idaccount,
          String? name,
          double? targetAmount,
          double? currentAmount,
          Value<DateTime?> startDate = const Value.absent(),
          DateTime? targetDate,
          Value<String?> walletId = const Value.absent(),
          Value<String?> cycleTakeMoney = const Value.absent(),
          Value<DateTime?> timeCycleTakeMoney = const Value.absent(),
          Value<double?> autoDepositAmount = const Value.absent(),
          Value<String?> autoDepositWalletId = const Value.absent(),
          Value<DateTime?> autoDepositLastRun = const Value.absent(),
          bool? recurrence,
          Value<String?> timeRecurrence = const Value.absent(),
          String? icon,
          String? colour,
          String? note,
          bool? isCompleted,
          Value<DateTime?> deletedAt = const Value.absent(),
          bool? isDeleted,
          String? syncStatus,
          int? syncRetryCount,
          Value<String?> syncError = const Value.absent(),
          Value<DateTime?> syncBlockedUntil = const Value.absent(),
          DateTime? updatedAt}) =>
      Goal(
        id: id ?? this.id,
        idaccount: idaccount ?? this.idaccount,
        name: name ?? this.name,
        targetAmount: targetAmount ?? this.targetAmount,
        currentAmount: currentAmount ?? this.currentAmount,
        startDate: startDate.present ? startDate.value : this.startDate,
        targetDate: targetDate ?? this.targetDate,
        walletId: walletId.present ? walletId.value : this.walletId,
        cycleTakeMoney:
            cycleTakeMoney.present ? cycleTakeMoney.value : this.cycleTakeMoney,
        timeCycleTakeMoney: timeCycleTakeMoney.present
            ? timeCycleTakeMoney.value
            : this.timeCycleTakeMoney,
        autoDepositAmount: autoDepositAmount.present
            ? autoDepositAmount.value
            : this.autoDepositAmount,
        autoDepositWalletId: autoDepositWalletId.present
            ? autoDepositWalletId.value
            : this.autoDepositWalletId,
        autoDepositLastRun: autoDepositLastRun.present
            ? autoDepositLastRun.value
            : this.autoDepositLastRun,
        recurrence: recurrence ?? this.recurrence,
        timeRecurrence:
            timeRecurrence.present ? timeRecurrence.value : this.timeRecurrence,
        icon: icon ?? this.icon,
        colour: colour ?? this.colour,
        note: note ?? this.note,
        isCompleted: isCompleted ?? this.isCompleted,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        isDeleted: isDeleted ?? this.isDeleted,
        syncStatus: syncStatus ?? this.syncStatus,
        syncRetryCount: syncRetryCount ?? this.syncRetryCount,
        syncError: syncError.present ? syncError.value : this.syncError,
        syncBlockedUntil: syncBlockedUntil.present
            ? syncBlockedUntil.value
            : this.syncBlockedUntil,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Goal copyWithCompanion(GoalsCompanion data) {
    return Goal(
      id: data.id.present ? data.id.value : this.id,
      idaccount: data.idaccount.present ? data.idaccount.value : this.idaccount,
      name: data.name.present ? data.name.value : this.name,
      targetAmount: data.targetAmount.present
          ? data.targetAmount.value
          : this.targetAmount,
      currentAmount: data.currentAmount.present
          ? data.currentAmount.value
          : this.currentAmount,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      targetDate:
          data.targetDate.present ? data.targetDate.value : this.targetDate,
      walletId: data.walletId.present ? data.walletId.value : this.walletId,
      cycleTakeMoney: data.cycleTakeMoney.present
          ? data.cycleTakeMoney.value
          : this.cycleTakeMoney,
      timeCycleTakeMoney: data.timeCycleTakeMoney.present
          ? data.timeCycleTakeMoney.value
          : this.timeCycleTakeMoney,
      autoDepositAmount: data.autoDepositAmount.present
          ? data.autoDepositAmount.value
          : this.autoDepositAmount,
      autoDepositWalletId: data.autoDepositWalletId.present
          ? data.autoDepositWalletId.value
          : this.autoDepositWalletId,
      autoDepositLastRun: data.autoDepositLastRun.present
          ? data.autoDepositLastRun.value
          : this.autoDepositLastRun,
      recurrence:
          data.recurrence.present ? data.recurrence.value : this.recurrence,
      timeRecurrence: data.timeRecurrence.present
          ? data.timeRecurrence.value
          : this.timeRecurrence,
      icon: data.icon.present ? data.icon.value : this.icon,
      colour: data.colour.present ? data.colour.value : this.colour,
      note: data.note.present ? data.note.value : this.note,
      isCompleted:
          data.isCompleted.present ? data.isCompleted.value : this.isCompleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      syncRetryCount: data.syncRetryCount.present
          ? data.syncRetryCount.value
          : this.syncRetryCount,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
      syncBlockedUntil: data.syncBlockedUntil.present
          ? data.syncBlockedUntil.value
          : this.syncBlockedUntil,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Goal(')
          ..write('id: $id, ')
          ..write('idaccount: $idaccount, ')
          ..write('name: $name, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('currentAmount: $currentAmount, ')
          ..write('startDate: $startDate, ')
          ..write('targetDate: $targetDate, ')
          ..write('walletId: $walletId, ')
          ..write('cycleTakeMoney: $cycleTakeMoney, ')
          ..write('timeCycleTakeMoney: $timeCycleTakeMoney, ')
          ..write('autoDepositAmount: $autoDepositAmount, ')
          ..write('autoDepositWalletId: $autoDepositWalletId, ')
          ..write('autoDepositLastRun: $autoDepositLastRun, ')
          ..write('recurrence: $recurrence, ')
          ..write('timeRecurrence: $timeRecurrence, ')
          ..write('icon: $icon, ')
          ..write('colour: $colour, ')
          ..write('note: $note, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncRetryCount: $syncRetryCount, ')
          ..write('syncError: $syncError, ')
          ..write('syncBlockedUntil: $syncBlockedUntil, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        idaccount,
        name,
        targetAmount,
        currentAmount,
        startDate,
        targetDate,
        walletId,
        cycleTakeMoney,
        timeCycleTakeMoney,
        autoDepositAmount,
        autoDepositWalletId,
        autoDepositLastRun,
        recurrence,
        timeRecurrence,
        icon,
        colour,
        note,
        isCompleted,
        deletedAt,
        isDeleted,
        syncStatus,
        syncRetryCount,
        syncError,
        syncBlockedUntil,
        updatedAt
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Goal &&
          other.id == this.id &&
          other.idaccount == this.idaccount &&
          other.name == this.name &&
          other.targetAmount == this.targetAmount &&
          other.currentAmount == this.currentAmount &&
          other.startDate == this.startDate &&
          other.targetDate == this.targetDate &&
          other.walletId == this.walletId &&
          other.cycleTakeMoney == this.cycleTakeMoney &&
          other.timeCycleTakeMoney == this.timeCycleTakeMoney &&
          other.autoDepositAmount == this.autoDepositAmount &&
          other.autoDepositWalletId == this.autoDepositWalletId &&
          other.autoDepositLastRun == this.autoDepositLastRun &&
          other.recurrence == this.recurrence &&
          other.timeRecurrence == this.timeRecurrence &&
          other.icon == this.icon &&
          other.colour == this.colour &&
          other.note == this.note &&
          other.isCompleted == this.isCompleted &&
          other.deletedAt == this.deletedAt &&
          other.isDeleted == this.isDeleted &&
          other.syncStatus == this.syncStatus &&
          other.syncRetryCount == this.syncRetryCount &&
          other.syncError == this.syncError &&
          other.syncBlockedUntil == this.syncBlockedUntil &&
          other.updatedAt == this.updatedAt);
}

class GoalsCompanion extends UpdateCompanion<Goal> {
  final Value<String> id;
  final Value<int> idaccount;
  final Value<String> name;
  final Value<double> targetAmount;
  final Value<double> currentAmount;
  final Value<DateTime?> startDate;
  final Value<DateTime> targetDate;
  final Value<String?> walletId;
  final Value<String?> cycleTakeMoney;
  final Value<DateTime?> timeCycleTakeMoney;
  final Value<double?> autoDepositAmount;
  final Value<String?> autoDepositWalletId;
  final Value<DateTime?> autoDepositLastRun;
  final Value<bool> recurrence;
  final Value<String?> timeRecurrence;
  final Value<String> icon;
  final Value<String> colour;
  final Value<String> note;
  final Value<bool> isCompleted;
  final Value<DateTime?> deletedAt;
  final Value<bool> isDeleted;
  final Value<String> syncStatus;
  final Value<int> syncRetryCount;
  final Value<String?> syncError;
  final Value<DateTime?> syncBlockedUntil;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const GoalsCompanion({
    this.id = const Value.absent(),
    this.idaccount = const Value.absent(),
    this.name = const Value.absent(),
    this.targetAmount = const Value.absent(),
    this.currentAmount = const Value.absent(),
    this.startDate = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.walletId = const Value.absent(),
    this.cycleTakeMoney = const Value.absent(),
    this.timeCycleTakeMoney = const Value.absent(),
    this.autoDepositAmount = const Value.absent(),
    this.autoDepositWalletId = const Value.absent(),
    this.autoDepositLastRun = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.timeRecurrence = const Value.absent(),
    this.icon = const Value.absent(),
    this.colour = const Value.absent(),
    this.note = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncRetryCount = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncBlockedUntil = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalsCompanion.insert({
    required String id,
    required int idaccount,
    required String name,
    required double targetAmount,
    this.currentAmount = const Value.absent(),
    this.startDate = const Value.absent(),
    required DateTime targetDate,
    this.walletId = const Value.absent(),
    this.cycleTakeMoney = const Value.absent(),
    this.timeCycleTakeMoney = const Value.absent(),
    this.autoDepositAmount = const Value.absent(),
    this.autoDepositWalletId = const Value.absent(),
    this.autoDepositLastRun = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.timeRecurrence = const Value.absent(),
    this.icon = const Value.absent(),
    this.colour = const Value.absent(),
    this.note = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncRetryCount = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncBlockedUntil = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        idaccount = Value(idaccount),
        name = Value(name),
        targetAmount = Value(targetAmount),
        targetDate = Value(targetDate),
        updatedAt = Value(updatedAt);
  static Insertable<Goal> custom({
    Expression<String>? id,
    Expression<int>? idaccount,
    Expression<String>? name,
    Expression<double>? targetAmount,
    Expression<double>? currentAmount,
    Expression<DateTime>? startDate,
    Expression<DateTime>? targetDate,
    Expression<String>? walletId,
    Expression<String>? cycleTakeMoney,
    Expression<DateTime>? timeCycleTakeMoney,
    Expression<double>? autoDepositAmount,
    Expression<String>? autoDepositWalletId,
    Expression<DateTime>? autoDepositLastRun,
    Expression<bool>? recurrence,
    Expression<String>? timeRecurrence,
    Expression<String>? icon,
    Expression<String>? colour,
    Expression<String>? note,
    Expression<bool>? isCompleted,
    Expression<DateTime>? deletedAt,
    Expression<bool>? isDeleted,
    Expression<String>? syncStatus,
    Expression<int>? syncRetryCount,
    Expression<String>? syncError,
    Expression<DateTime>? syncBlockedUntil,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (idaccount != null) 'idaccount': idaccount,
      if (name != null) 'name': name,
      if (targetAmount != null) 'target_amount': targetAmount,
      if (currentAmount != null) 'current_amount': currentAmount,
      if (startDate != null) 'start_date': startDate,
      if (targetDate != null) 'target_date': targetDate,
      if (walletId != null) 'wallet_id': walletId,
      if (cycleTakeMoney != null) 'cycle_take_money': cycleTakeMoney,
      if (timeCycleTakeMoney != null)
        'time_cycle_take_money': timeCycleTakeMoney,
      if (autoDepositAmount != null) 'auto_deposit_amount': autoDepositAmount,
      if (autoDepositWalletId != null)
        'auto_deposit_wallet_id': autoDepositWalletId,
      if (autoDepositLastRun != null)
        'auto_deposit_last_run': autoDepositLastRun,
      if (recurrence != null) 'recurrence': recurrence,
      if (timeRecurrence != null) 'time_recurrence': timeRecurrence,
      if (icon != null) 'icon': icon,
      if (colour != null) 'colour': colour,
      if (note != null) 'note': note,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (syncRetryCount != null) 'sync_retry_count': syncRetryCount,
      if (syncError != null) 'sync_error': syncError,
      if (syncBlockedUntil != null) 'sync_blocked_until': syncBlockedUntil,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalsCompanion copyWith(
      {Value<String>? id,
      Value<int>? idaccount,
      Value<String>? name,
      Value<double>? targetAmount,
      Value<double>? currentAmount,
      Value<DateTime?>? startDate,
      Value<DateTime>? targetDate,
      Value<String?>? walletId,
      Value<String?>? cycleTakeMoney,
      Value<DateTime?>? timeCycleTakeMoney,
      Value<double?>? autoDepositAmount,
      Value<String?>? autoDepositWalletId,
      Value<DateTime?>? autoDepositLastRun,
      Value<bool>? recurrence,
      Value<String?>? timeRecurrence,
      Value<String>? icon,
      Value<String>? colour,
      Value<String>? note,
      Value<bool>? isCompleted,
      Value<DateTime?>? deletedAt,
      Value<bool>? isDeleted,
      Value<String>? syncStatus,
      Value<int>? syncRetryCount,
      Value<String?>? syncError,
      Value<DateTime?>? syncBlockedUntil,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return GoalsCompanion(
      id: id ?? this.id,
      idaccount: idaccount ?? this.idaccount,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      startDate: startDate ?? this.startDate,
      targetDate: targetDate ?? this.targetDate,
      walletId: walletId ?? this.walletId,
      cycleTakeMoney: cycleTakeMoney ?? this.cycleTakeMoney,
      timeCycleTakeMoney: timeCycleTakeMoney ?? this.timeCycleTakeMoney,
      autoDepositAmount: autoDepositAmount ?? this.autoDepositAmount,
      autoDepositWalletId: autoDepositWalletId ?? this.autoDepositWalletId,
      autoDepositLastRun: autoDepositLastRun ?? this.autoDepositLastRun,
      recurrence: recurrence ?? this.recurrence,
      timeRecurrence: timeRecurrence ?? this.timeRecurrence,
      icon: icon ?? this.icon,
      colour: colour ?? this.colour,
      note: note ?? this.note,
      isCompleted: isCompleted ?? this.isCompleted,
      deletedAt: deletedAt ?? this.deletedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
      syncRetryCount: syncRetryCount ?? this.syncRetryCount,
      syncError: syncError ?? this.syncError,
      syncBlockedUntil: syncBlockedUntil ?? this.syncBlockedUntil,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (idaccount.present) {
      map['idaccount'] = Variable<int>(idaccount.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (targetAmount.present) {
      map['target_amount'] = Variable<double>(targetAmount.value);
    }
    if (currentAmount.present) {
      map['current_amount'] = Variable<double>(currentAmount.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (targetDate.present) {
      map['target_date'] = Variable<DateTime>(targetDate.value);
    }
    if (walletId.present) {
      map['wallet_id'] = Variable<String>(walletId.value);
    }
    if (cycleTakeMoney.present) {
      map['cycle_take_money'] = Variable<String>(cycleTakeMoney.value);
    }
    if (timeCycleTakeMoney.present) {
      map['time_cycle_take_money'] =
          Variable<DateTime>(timeCycleTakeMoney.value);
    }
    if (autoDepositAmount.present) {
      map['auto_deposit_amount'] = Variable<double>(autoDepositAmount.value);
    }
    if (autoDepositWalletId.present) {
      map['auto_deposit_wallet_id'] =
          Variable<String>(autoDepositWalletId.value);
    }
    if (autoDepositLastRun.present) {
      map['auto_deposit_last_run'] =
          Variable<DateTime>(autoDepositLastRun.value);
    }
    if (recurrence.present) {
      map['recurrence'] = Variable<bool>(recurrence.value);
    }
    if (timeRecurrence.present) {
      map['time_recurrence'] = Variable<String>(timeRecurrence.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (colour.present) {
      map['colour'] = Variable<String>(colour.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (syncRetryCount.present) {
      map['sync_retry_count'] = Variable<int>(syncRetryCount.value);
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
    }
    if (syncBlockedUntil.present) {
      map['sync_blocked_until'] = Variable<DateTime>(syncBlockedUntil.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalsCompanion(')
          ..write('id: $id, ')
          ..write('idaccount: $idaccount, ')
          ..write('name: $name, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('currentAmount: $currentAmount, ')
          ..write('startDate: $startDate, ')
          ..write('targetDate: $targetDate, ')
          ..write('walletId: $walletId, ')
          ..write('cycleTakeMoney: $cycleTakeMoney, ')
          ..write('timeCycleTakeMoney: $timeCycleTakeMoney, ')
          ..write('autoDepositAmount: $autoDepositAmount, ')
          ..write('autoDepositWalletId: $autoDepositWalletId, ')
          ..write('autoDepositLastRun: $autoDepositLastRun, ')
          ..write('recurrence: $recurrence, ')
          ..write('timeRecurrence: $timeRecurrence, ')
          ..write('icon: $icon, ')
          ..write('colour: $colour, ')
          ..write('note: $note, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncRetryCount: $syncRetryCount, ')
          ..write('syncError: $syncError, ')
          ..write('syncBlockedUntil: $syncBlockedUntil, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppNotificationsTable extends AppNotifications
    with TableInfo<$AppNotificationsTable, AppNotification> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppNotificationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _idaccountMeta =
      const VerificationMeta('idaccount');
  @override
  late final GeneratedColumn<int> idaccount = GeneratedColumn<int>(
      'idaccount', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dedupeKeyMeta =
      const VerificationMeta('dedupeKey');
  @override
  late final GeneratedColumn<String> dedupeKey = GeneratedColumn<String>(
      'dedupe_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _severityMeta =
      const VerificationMeta('severity');
  @override
  late final GeneratedColumn<String> severity = GeneratedColumn<String>(
      'severity', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _subjectTypeMeta =
      const VerificationMeta('subjectType');
  @override
  late final GeneratedColumn<String> subjectType = GeneratedColumn<String>(
      'subject_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _subjectIdMeta =
      const VerificationMeta('subjectId');
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
      'subject_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deeplinkMeta =
      const VerificationMeta('deeplink');
  @override
  late final GeneratedColumn<String> deeplink = GeneratedColumn<String>(
      'deeplink', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<DateTime> readAt = GeneratedColumn<DateTime>(
      'read_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _dismissedAtMeta =
      const VerificationMeta('dismissedAt');
  @override
  late final GeneratedColumn<DateTime> dismissedAt = GeneratedColumn<DateTime>(
      'dismissed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _osScheduledIdMeta =
      const VerificationMeta('osScheduledId');
  @override
  late final GeneratedColumn<int> osScheduledId = GeneratedColumn<int>(
      'os_scheduled_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _osDeliveredAtMeta =
      const VerificationMeta('osDeliveredAt');
  @override
  late final GeneratedColumn<DateTime> osDeliveredAt =
      GeneratedColumn<DateTime>('os_delivered_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        idaccount,
        kind,
        dedupeKey,
        title,
        body,
        severity,
        subjectType,
        subjectId,
        deeplink,
        createdAt,
        readAt,
        dismissedAt,
        osScheduledId,
        osDeliveredAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_notifications';
  @override
  VerificationContext validateIntegrity(Insertable<AppNotification> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('idaccount')) {
      context.handle(_idaccountMeta,
          idaccount.isAcceptableOrUnknown(data['idaccount']!, _idaccountMeta));
    } else if (isInserting) {
      context.missing(_idaccountMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('dedupe_key')) {
      context.handle(_dedupeKeyMeta,
          dedupeKey.isAcceptableOrUnknown(data['dedupe_key']!, _dedupeKeyMeta));
    } else if (isInserting) {
      context.missing(_dedupeKeyMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('severity')) {
      context.handle(_severityMeta,
          severity.isAcceptableOrUnknown(data['severity']!, _severityMeta));
    } else if (isInserting) {
      context.missing(_severityMeta);
    }
    if (data.containsKey('subject_type')) {
      context.handle(
          _subjectTypeMeta,
          subjectType.isAcceptableOrUnknown(
              data['subject_type']!, _subjectTypeMeta));
    }
    if (data.containsKey('subject_id')) {
      context.handle(_subjectIdMeta,
          subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta));
    }
    if (data.containsKey('deeplink')) {
      context.handle(_deeplinkMeta,
          deeplink.isAcceptableOrUnknown(data['deeplink']!, _deeplinkMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('read_at')) {
      context.handle(_readAtMeta,
          readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta));
    }
    if (data.containsKey('dismissed_at')) {
      context.handle(
          _dismissedAtMeta,
          dismissedAt.isAcceptableOrUnknown(
              data['dismissed_at']!, _dismissedAtMeta));
    }
    if (data.containsKey('os_scheduled_id')) {
      context.handle(
          _osScheduledIdMeta,
          osScheduledId.isAcceptableOrUnknown(
              data['os_scheduled_id']!, _osScheduledIdMeta));
    }
    if (data.containsKey('os_delivered_at')) {
      context.handle(
          _osDeliveredAtMeta,
          osDeliveredAt.isAcceptableOrUnknown(
              data['os_delivered_at']!, _osDeliveredAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {idaccount, dedupeKey},
      ];
  @override
  AppNotification map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppNotification(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      idaccount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}idaccount'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      dedupeKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dedupe_key'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      severity: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}severity'])!,
      subjectType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subject_type']),
      subjectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subject_id']),
      deeplink: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deeplink']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      readAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}read_at']),
      dismissedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}dismissed_at']),
      osScheduledId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}os_scheduled_id']),
      osDeliveredAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}os_delivered_at']),
    );
  }

  @override
  $AppNotificationsTable createAlias(String alias) {
    return $AppNotificationsTable(attachedDatabase, alias);
  }
}

class AppNotification extends DataClass implements Insertable<AppNotification> {
  final String id;

  /// Mọi truy vấn đọc **bắt buộc** lọc theo cột này. Bỏ sót là thông báo tài
  /// chính của tài khoản khác hiện ra trên máy dùng chung.
  final int idaccount;

  /// `budgetNearLimit` | `budgetOverspent` | `billDueSoon` | `billOverdue`
  /// | `goalCompleted` | `goalBehind` | `syncFailed` | `walletNegative`
  final String kind;

  /// Khoá chống trùng — **trái tim của bảng này**.
  ///
  /// Gồm *loại + chủ thể + đơn vị lặp lại hợp lệ*, và **tuyệt đối không chứa
  /// giá trị biến thiên liên tục** (số đã chi, phần trăm thô). Nhét `spent` vào
  /// đây là biến mỗi giao dịch thành một thông báo mới.
  ///
  /// Cùng với `uniqueKeys` bên dưới và `InsertMode.insertOrIgnore`, đây là toàn
  /// bộ cơ chế chống trùng. Kiểm bằng Dart (`SELECT` rồi `INSERT`) không đủ:
  /// quét được kích hoạt từ nhiều nguồn, hai nguồn nổ gần nhau sẽ cùng đi qua
  /// nhánh "chưa có" trước khi bên nào kịp ghi.
  final String dedupeKey;
  final String title;
  final String body;

  /// `info` | `warning` | `critical` — quyết định màu dải và biểu tượng.
  final String severity;

  /// `budget` | `bill` | `goal` | `sync` | `wallet`
  final String? subjectType;

  /// Id bản ghi gốc, để huỷ lịch khi bản ghi đó bị xoá.
  final String? subjectId;

  /// Route go_router để điều hướng khi người dùng chạm vào.
  final String? deeplink;

  /// Mốc của **sự kiện**, không phải mốc quét.
  final DateTime createdAt;
  final DateTime? readAt;

  /// Xoá mềm. **Giữ hàng lại** vì chính hàng này là bản ghi khoá trùng — xoá
  /// hẳn thì lần quét sau sinh lại ngay, người dùng xoá mãi không hết.
  final DateTime? dismissedAt;

  /// Id đã cấp cho `flutter_local_notifications`, để huỷ lịch.
  final int? osScheduledId;

  /// Đã bắn ra hệ điều hành chưa. null = mới chỉ tồn tại trong app.
  final DateTime? osDeliveredAt;
  const AppNotification(
      {required this.id,
      required this.idaccount,
      required this.kind,
      required this.dedupeKey,
      required this.title,
      required this.body,
      required this.severity,
      this.subjectType,
      this.subjectId,
      this.deeplink,
      required this.createdAt,
      this.readAt,
      this.dismissedAt,
      this.osScheduledId,
      this.osDeliveredAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['idaccount'] = Variable<int>(idaccount);
    map['kind'] = Variable<String>(kind);
    map['dedupe_key'] = Variable<String>(dedupeKey);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['severity'] = Variable<String>(severity);
    if (!nullToAbsent || subjectType != null) {
      map['subject_type'] = Variable<String>(subjectType);
    }
    if (!nullToAbsent || subjectId != null) {
      map['subject_id'] = Variable<String>(subjectId);
    }
    if (!nullToAbsent || deeplink != null) {
      map['deeplink'] = Variable<String>(deeplink);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || readAt != null) {
      map['read_at'] = Variable<DateTime>(readAt);
    }
    if (!nullToAbsent || dismissedAt != null) {
      map['dismissed_at'] = Variable<DateTime>(dismissedAt);
    }
    if (!nullToAbsent || osScheduledId != null) {
      map['os_scheduled_id'] = Variable<int>(osScheduledId);
    }
    if (!nullToAbsent || osDeliveredAt != null) {
      map['os_delivered_at'] = Variable<DateTime>(osDeliveredAt);
    }
    return map;
  }

  AppNotificationsCompanion toCompanion(bool nullToAbsent) {
    return AppNotificationsCompanion(
      id: Value(id),
      idaccount: Value(idaccount),
      kind: Value(kind),
      dedupeKey: Value(dedupeKey),
      title: Value(title),
      body: Value(body),
      severity: Value(severity),
      subjectType: subjectType == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectType),
      subjectId: subjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectId),
      deeplink: deeplink == null && nullToAbsent
          ? const Value.absent()
          : Value(deeplink),
      createdAt: Value(createdAt),
      readAt:
          readAt == null && nullToAbsent ? const Value.absent() : Value(readAt),
      dismissedAt: dismissedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dismissedAt),
      osScheduledId: osScheduledId == null && nullToAbsent
          ? const Value.absent()
          : Value(osScheduledId),
      osDeliveredAt: osDeliveredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(osDeliveredAt),
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppNotification(
      id: serializer.fromJson<String>(json['id']),
      idaccount: serializer.fromJson<int>(json['idaccount']),
      kind: serializer.fromJson<String>(json['kind']),
      dedupeKey: serializer.fromJson<String>(json['dedupeKey']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      severity: serializer.fromJson<String>(json['severity']),
      subjectType: serializer.fromJson<String?>(json['subjectType']),
      subjectId: serializer.fromJson<String?>(json['subjectId']),
      deeplink: serializer.fromJson<String?>(json['deeplink']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      readAt: serializer.fromJson<DateTime?>(json['readAt']),
      dismissedAt: serializer.fromJson<DateTime?>(json['dismissedAt']),
      osScheduledId: serializer.fromJson<int?>(json['osScheduledId']),
      osDeliveredAt: serializer.fromJson<DateTime?>(json['osDeliveredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'idaccount': serializer.toJson<int>(idaccount),
      'kind': serializer.toJson<String>(kind),
      'dedupeKey': serializer.toJson<String>(dedupeKey),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'severity': serializer.toJson<String>(severity),
      'subjectType': serializer.toJson<String?>(subjectType),
      'subjectId': serializer.toJson<String?>(subjectId),
      'deeplink': serializer.toJson<String?>(deeplink),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'readAt': serializer.toJson<DateTime?>(readAt),
      'dismissedAt': serializer.toJson<DateTime?>(dismissedAt),
      'osScheduledId': serializer.toJson<int?>(osScheduledId),
      'osDeliveredAt': serializer.toJson<DateTime?>(osDeliveredAt),
    };
  }

  AppNotification copyWith(
          {String? id,
          int? idaccount,
          String? kind,
          String? dedupeKey,
          String? title,
          String? body,
          String? severity,
          Value<String?> subjectType = const Value.absent(),
          Value<String?> subjectId = const Value.absent(),
          Value<String?> deeplink = const Value.absent(),
          DateTime? createdAt,
          Value<DateTime?> readAt = const Value.absent(),
          Value<DateTime?> dismissedAt = const Value.absent(),
          Value<int?> osScheduledId = const Value.absent(),
          Value<DateTime?> osDeliveredAt = const Value.absent()}) =>
      AppNotification(
        id: id ?? this.id,
        idaccount: idaccount ?? this.idaccount,
        kind: kind ?? this.kind,
        dedupeKey: dedupeKey ?? this.dedupeKey,
        title: title ?? this.title,
        body: body ?? this.body,
        severity: severity ?? this.severity,
        subjectType: subjectType.present ? subjectType.value : this.subjectType,
        subjectId: subjectId.present ? subjectId.value : this.subjectId,
        deeplink: deeplink.present ? deeplink.value : this.deeplink,
        createdAt: createdAt ?? this.createdAt,
        readAt: readAt.present ? readAt.value : this.readAt,
        dismissedAt: dismissedAt.present ? dismissedAt.value : this.dismissedAt,
        osScheduledId:
            osScheduledId.present ? osScheduledId.value : this.osScheduledId,
        osDeliveredAt:
            osDeliveredAt.present ? osDeliveredAt.value : this.osDeliveredAt,
      );
  AppNotification copyWithCompanion(AppNotificationsCompanion data) {
    return AppNotification(
      id: data.id.present ? data.id.value : this.id,
      idaccount: data.idaccount.present ? data.idaccount.value : this.idaccount,
      kind: data.kind.present ? data.kind.value : this.kind,
      dedupeKey: data.dedupeKey.present ? data.dedupeKey.value : this.dedupeKey,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      severity: data.severity.present ? data.severity.value : this.severity,
      subjectType:
          data.subjectType.present ? data.subjectType.value : this.subjectType,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      deeplink: data.deeplink.present ? data.deeplink.value : this.deeplink,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
      dismissedAt:
          data.dismissedAt.present ? data.dismissedAt.value : this.dismissedAt,
      osScheduledId: data.osScheduledId.present
          ? data.osScheduledId.value
          : this.osScheduledId,
      osDeliveredAt: data.osDeliveredAt.present
          ? data.osDeliveredAt.value
          : this.osDeliveredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppNotification(')
          ..write('id: $id, ')
          ..write('idaccount: $idaccount, ')
          ..write('kind: $kind, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('severity: $severity, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('deeplink: $deeplink, ')
          ..write('createdAt: $createdAt, ')
          ..write('readAt: $readAt, ')
          ..write('dismissedAt: $dismissedAt, ')
          ..write('osScheduledId: $osScheduledId, ')
          ..write('osDeliveredAt: $osDeliveredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      idaccount,
      kind,
      dedupeKey,
      title,
      body,
      severity,
      subjectType,
      subjectId,
      deeplink,
      createdAt,
      readAt,
      dismissedAt,
      osScheduledId,
      osDeliveredAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppNotification &&
          other.id == this.id &&
          other.idaccount == this.idaccount &&
          other.kind == this.kind &&
          other.dedupeKey == this.dedupeKey &&
          other.title == this.title &&
          other.body == this.body &&
          other.severity == this.severity &&
          other.subjectType == this.subjectType &&
          other.subjectId == this.subjectId &&
          other.deeplink == this.deeplink &&
          other.createdAt == this.createdAt &&
          other.readAt == this.readAt &&
          other.dismissedAt == this.dismissedAt &&
          other.osScheduledId == this.osScheduledId &&
          other.osDeliveredAt == this.osDeliveredAt);
}

class AppNotificationsCompanion extends UpdateCompanion<AppNotification> {
  final Value<String> id;
  final Value<int> idaccount;
  final Value<String> kind;
  final Value<String> dedupeKey;
  final Value<String> title;
  final Value<String> body;
  final Value<String> severity;
  final Value<String?> subjectType;
  final Value<String?> subjectId;
  final Value<String?> deeplink;
  final Value<DateTime> createdAt;
  final Value<DateTime?> readAt;
  final Value<DateTime?> dismissedAt;
  final Value<int?> osScheduledId;
  final Value<DateTime?> osDeliveredAt;
  final Value<int> rowid;
  const AppNotificationsCompanion({
    this.id = const Value.absent(),
    this.idaccount = const Value.absent(),
    this.kind = const Value.absent(),
    this.dedupeKey = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.severity = const Value.absent(),
    this.subjectType = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.deeplink = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.readAt = const Value.absent(),
    this.dismissedAt = const Value.absent(),
    this.osScheduledId = const Value.absent(),
    this.osDeliveredAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppNotificationsCompanion.insert({
    required String id,
    required int idaccount,
    required String kind,
    required String dedupeKey,
    required String title,
    required String body,
    required String severity,
    this.subjectType = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.deeplink = const Value.absent(),
    required DateTime createdAt,
    this.readAt = const Value.absent(),
    this.dismissedAt = const Value.absent(),
    this.osScheduledId = const Value.absent(),
    this.osDeliveredAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        idaccount = Value(idaccount),
        kind = Value(kind),
        dedupeKey = Value(dedupeKey),
        title = Value(title),
        body = Value(body),
        severity = Value(severity),
        createdAt = Value(createdAt);
  static Insertable<AppNotification> custom({
    Expression<String>? id,
    Expression<int>? idaccount,
    Expression<String>? kind,
    Expression<String>? dedupeKey,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? severity,
    Expression<String>? subjectType,
    Expression<String>? subjectId,
    Expression<String>? deeplink,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? readAt,
    Expression<DateTime>? dismissedAt,
    Expression<int>? osScheduledId,
    Expression<DateTime>? osDeliveredAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (idaccount != null) 'idaccount': idaccount,
      if (kind != null) 'kind': kind,
      if (dedupeKey != null) 'dedupe_key': dedupeKey,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (severity != null) 'severity': severity,
      if (subjectType != null) 'subject_type': subjectType,
      if (subjectId != null) 'subject_id': subjectId,
      if (deeplink != null) 'deeplink': deeplink,
      if (createdAt != null) 'created_at': createdAt,
      if (readAt != null) 'read_at': readAt,
      if (dismissedAt != null) 'dismissed_at': dismissedAt,
      if (osScheduledId != null) 'os_scheduled_id': osScheduledId,
      if (osDeliveredAt != null) 'os_delivered_at': osDeliveredAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppNotificationsCompanion copyWith(
      {Value<String>? id,
      Value<int>? idaccount,
      Value<String>? kind,
      Value<String>? dedupeKey,
      Value<String>? title,
      Value<String>? body,
      Value<String>? severity,
      Value<String?>? subjectType,
      Value<String?>? subjectId,
      Value<String?>? deeplink,
      Value<DateTime>? createdAt,
      Value<DateTime?>? readAt,
      Value<DateTime?>? dismissedAt,
      Value<int?>? osScheduledId,
      Value<DateTime?>? osDeliveredAt,
      Value<int>? rowid}) {
    return AppNotificationsCompanion(
      id: id ?? this.id,
      idaccount: idaccount ?? this.idaccount,
      kind: kind ?? this.kind,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      title: title ?? this.title,
      body: body ?? this.body,
      severity: severity ?? this.severity,
      subjectType: subjectType ?? this.subjectType,
      subjectId: subjectId ?? this.subjectId,
      deeplink: deeplink ?? this.deeplink,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      osScheduledId: osScheduledId ?? this.osScheduledId,
      osDeliveredAt: osDeliveredAt ?? this.osDeliveredAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (idaccount.present) {
      map['idaccount'] = Variable<int>(idaccount.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (dedupeKey.present) {
      map['dedupe_key'] = Variable<String>(dedupeKey.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (severity.present) {
      map['severity'] = Variable<String>(severity.value);
    }
    if (subjectType.present) {
      map['subject_type'] = Variable<String>(subjectType.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (deeplink.present) {
      map['deeplink'] = Variable<String>(deeplink.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<DateTime>(readAt.value);
    }
    if (dismissedAt.present) {
      map['dismissed_at'] = Variable<DateTime>(dismissedAt.value);
    }
    if (osScheduledId.present) {
      map['os_scheduled_id'] = Variable<int>(osScheduledId.value);
    }
    if (osDeliveredAt.present) {
      map['os_delivered_at'] = Variable<DateTime>(osDeliveredAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppNotificationsCompanion(')
          ..write('id: $id, ')
          ..write('idaccount: $idaccount, ')
          ..write('kind: $kind, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('severity: $severity, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('deeplink: $deeplink, ')
          ..write('createdAt: $createdAt, ')
          ..write('readAt: $readAt, ')
          ..write('dismissedAt: $dismissedAt, ')
          ..write('osScheduledId: $osScheduledId, ')
          ..write('osDeliveredAt: $osDeliveredAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WalletsTable wallets = $WalletsTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $CategoryKeywordsTable categoryKeywords =
      $CategoryKeywordsTable(this);
  late final $CategoryGroupMembershipsTable categoryGroupMemberships =
      $CategoryGroupMembershipsTable(this);
  late final $BudgetsTable budgets = $BudgetsTable(this);
  late final $BillsTable bills = $BillsTable(this);
  late final $GoalsTable goals = $GoalsTable(this);
  late final $AppNotificationsTable appNotifications =
      $AppNotificationsTable(this);
  late final Index idxAppnotifFeed = Index('idx_appnotif_feed',
      'CREATE INDEX idx_appnotif_feed ON app_notifications (idaccount, created_at)');
  late final WalletDao walletDao = WalletDao(this as AppDatabase);
  late final TransactionDao transactionDao =
      TransactionDao(this as AppDatabase);
  late final CategoryDao categoryDao = CategoryDao(this as AppDatabase);
  late final BudgetDao budgetDao = BudgetDao(this as AppDatabase);
  late final BillDao billDao = BillDao(this as AppDatabase);
  late final GoalDao goalDao = GoalDao(this as AppDatabase);
  late final NotificationDao notificationDao =
      NotificationDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        wallets,
        transactions,
        categories,
        categoryKeywords,
        categoryGroupMemberships,
        budgets,
        bills,
        goals,
        appNotifications,
        idxAppnotifFeed
      ];
}

typedef $$WalletsTableCreateCompanionBuilder = WalletsCompanion Function({
  required String id,
  required int idaccount,
  required String name,
  Value<String> type,
  Value<double> balance,
  Value<String> currency,
  Value<String> icon,
  Value<String> colour,
  Value<bool> isDefault,
  Value<bool> isDeleted,
  Value<bool> includeInTotal,
  Value<String?> bankCassoId,
  Value<String> status,
  Value<String> syncStatus,
  Value<int> syncRetryCount,
  Value<String?> syncError,
  Value<DateTime?> syncBlockedUntil,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$WalletsTableUpdateCompanionBuilder = WalletsCompanion Function({
  Value<String> id,
  Value<int> idaccount,
  Value<String> name,
  Value<String> type,
  Value<double> balance,
  Value<String> currency,
  Value<String> icon,
  Value<String> colour,
  Value<bool> isDefault,
  Value<bool> isDeleted,
  Value<bool> includeInTotal,
  Value<String?> bankCassoId,
  Value<String> status,
  Value<String> syncStatus,
  Value<int> syncRetryCount,
  Value<String?> syncError,
  Value<DateTime?> syncBlockedUntil,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

final class $$WalletsTableReferences
    extends BaseReferences<_$AppDatabase, $WalletsTable, Wallet> {
  $$WalletsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>>
      _transactionsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.transactions,
              aliasName: 'wallets__id__transactions__wallet_id');

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager($_db, $_db.transactions)
        .filter((f) => f.walletId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$WalletsTableFilterComposer
    extends Composer<_$AppDatabase, $WalletsTable> {
  $$WalletsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get idaccount => $composableBuilder(
      column: $table.idaccount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get balance => $composableBuilder(
      column: $table.balance, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get colour => $composableBuilder(
      column: $table.colour, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDefault => $composableBuilder(
      column: $table.isDefault, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get includeInTotal => $composableBuilder(
      column: $table.includeInTotal,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bankCassoId => $composableBuilder(
      column: $table.bankCassoId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncRetryCount => $composableBuilder(
      column: $table.syncRetryCount,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncError => $composableBuilder(
      column: $table.syncError, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncBlockedUntil => $composableBuilder(
      column: $table.syncBlockedUntil,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> transactionsRefs(
      Expression<bool> Function($$TransactionsTableFilterComposer f) f) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.transactions,
        getReferencedColumn: (t) => t.walletId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TransactionsTableFilterComposer(
              $db: $db,
              $table: $db.transactions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$WalletsTableOrderingComposer
    extends Composer<_$AppDatabase, $WalletsTable> {
  $$WalletsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get idaccount => $composableBuilder(
      column: $table.idaccount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get balance => $composableBuilder(
      column: $table.balance, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get colour => $composableBuilder(
      column: $table.colour, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDefault => $composableBuilder(
      column: $table.isDefault, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get includeInTotal => $composableBuilder(
      column: $table.includeInTotal,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bankCassoId => $composableBuilder(
      column: $table.bankCassoId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncRetryCount => $composableBuilder(
      column: $table.syncRetryCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncError => $composableBuilder(
      column: $table.syncError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncBlockedUntil => $composableBuilder(
      column: $table.syncBlockedUntil,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$WalletsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WalletsTable> {
  $$WalletsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get idaccount =>
      $composableBuilder(column: $table.idaccount, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get balance =>
      $composableBuilder(column: $table.balance, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get colour =>
      $composableBuilder(column: $table.colour, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<bool> get includeInTotal => $composableBuilder(
      column: $table.includeInTotal, builder: (column) => column);

  GeneratedColumn<String> get bankCassoId => $composableBuilder(
      column: $table.bankCassoId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<int> get syncRetryCount => $composableBuilder(
      column: $table.syncRetryCount, builder: (column) => column);

  GeneratedColumn<String> get syncError =>
      $composableBuilder(column: $table.syncError, builder: (column) => column);

  GeneratedColumn<DateTime> get syncBlockedUntil => $composableBuilder(
      column: $table.syncBlockedUntil, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> transactionsRefs<T extends Object>(
      Expression<T> Function($$TransactionsTableAnnotationComposer a) f) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.transactions,
        getReferencedColumn: (t) => t.walletId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TransactionsTableAnnotationComposer(
              $db: $db,
              $table: $db.transactions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$WalletsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WalletsTable,
    Wallet,
    $$WalletsTableFilterComposer,
    $$WalletsTableOrderingComposer,
    $$WalletsTableAnnotationComposer,
    $$WalletsTableCreateCompanionBuilder,
    $$WalletsTableUpdateCompanionBuilder,
    (Wallet, $$WalletsTableReferences),
    Wallet,
    PrefetchHooks Function({bool transactionsRefs})> {
  $$WalletsTableTableManager(_$AppDatabase db, $WalletsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalletsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WalletsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WalletsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<int> idaccount = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<double> balance = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String> icon = const Value.absent(),
            Value<String> colour = const Value.absent(),
            Value<bool> isDefault = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<bool> includeInTotal = const Value.absent(),
            Value<String?> bankCassoId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> syncRetryCount = const Value.absent(),
            Value<String?> syncError = const Value.absent(),
            Value<DateTime?> syncBlockedUntil = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WalletsCompanion(
            id: id,
            idaccount: idaccount,
            name: name,
            type: type,
            balance: balance,
            currency: currency,
            icon: icon,
            colour: colour,
            isDefault: isDefault,
            isDeleted: isDeleted,
            includeInTotal: includeInTotal,
            bankCassoId: bankCassoId,
            status: status,
            syncStatus: syncStatus,
            syncRetryCount: syncRetryCount,
            syncError: syncError,
            syncBlockedUntil: syncBlockedUntil,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required int idaccount,
            required String name,
            Value<String> type = const Value.absent(),
            Value<double> balance = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String> icon = const Value.absent(),
            Value<String> colour = const Value.absent(),
            Value<bool> isDefault = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<bool> includeInTotal = const Value.absent(),
            Value<String?> bankCassoId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> syncRetryCount = const Value.absent(),
            Value<String?> syncError = const Value.absent(),
            Value<DateTime?> syncBlockedUntil = const Value.absent(),
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WalletsCompanion.insert(
            id: id,
            idaccount: idaccount,
            name: name,
            type: type,
            balance: balance,
            currency: currency,
            icon: icon,
            colour: colour,
            isDefault: isDefault,
            isDeleted: isDeleted,
            includeInTotal: includeInTotal,
            bankCassoId: bankCassoId,
            status: status,
            syncStatus: syncStatus,
            syncRetryCount: syncRetryCount,
            syncError: syncError,
            syncBlockedUntil: syncBlockedUntil,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$WalletsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({transactionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (transactionsRefs) db.transactions],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (transactionsRefs)
                    await $_getPrefetchedData<Wallet, $WalletsTable,
                            Transaction>(
                        currentTable: table,
                        referencedTable:
                            $$WalletsTableReferences._transactionsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$WalletsTableReferences(db, table, p0)
                                .transactionsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.walletId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$WalletsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WalletsTable,
    Wallet,
    $$WalletsTableFilterComposer,
    $$WalletsTableOrderingComposer,
    $$WalletsTableAnnotationComposer,
    $$WalletsTableCreateCompanionBuilder,
    $$WalletsTableUpdateCompanionBuilder,
    (Wallet, $$WalletsTableReferences),
    Wallet,
    PrefetchHooks Function({bool transactionsRefs})>;
typedef $$TransactionsTableCreateCompanionBuilder = TransactionsCompanion
    Function({
  required String id,
  required String walletId,
  required int idaccount,
  Value<String?> categoryId,
  required double amount,
  required String type,
  Value<String> status,
  Value<String> provider,
  Value<String> note,
  required DateTime date,
  Value<String> images,
  Value<String?> goalId,
  Value<String?> walletTransfer,
  Value<String?> bankTranId,
  Value<DateTime?> deletedAt,
  Value<String> syncStatus,
  Value<int> syncRetryCount,
  Value<String?> syncError,
  Value<DateTime?> syncBlockedUntil,
  required DateTime updatedAt,
  Value<bool> isDeleted,
  Value<int> rowid,
});
typedef $$TransactionsTableUpdateCompanionBuilder = TransactionsCompanion
    Function({
  Value<String> id,
  Value<String> walletId,
  Value<int> idaccount,
  Value<String?> categoryId,
  Value<double> amount,
  Value<String> type,
  Value<String> status,
  Value<String> provider,
  Value<String> note,
  Value<DateTime> date,
  Value<String> images,
  Value<String?> goalId,
  Value<String?> walletTransfer,
  Value<String?> bankTranId,
  Value<DateTime?> deletedAt,
  Value<String> syncStatus,
  Value<int> syncRetryCount,
  Value<String?> syncError,
  Value<DateTime?> syncBlockedUntil,
  Value<DateTime> updatedAt,
  Value<bool> isDeleted,
  Value<int> rowid,
});

final class $$TransactionsTableReferences
    extends BaseReferences<_$AppDatabase, $TransactionsTable, Transaction> {
  $$TransactionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WalletsTable _walletIdTable(_$AppDatabase db) =>
      db.wallets.createAlias('transactions__wallet_id__wallets__id');

  $$WalletsTableProcessedTableManager get walletId {
    final $_column = $_itemColumn<String>('wallet_id')!;

    final manager = $$WalletsTableTableManager($_db, $_db.wallets)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_walletIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get idaccount => $composableBuilder(
      column: $table.idaccount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get provider => $composableBuilder(
      column: $table.provider, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get images => $composableBuilder(
      column: $table.images, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get goalId => $composableBuilder(
      column: $table.goalId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get walletTransfer => $composableBuilder(
      column: $table.walletTransfer,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bankTranId => $composableBuilder(
      column: $table.bankTranId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncRetryCount => $composableBuilder(
      column: $table.syncRetryCount,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncError => $composableBuilder(
      column: $table.syncError, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncBlockedUntil => $composableBuilder(
      column: $table.syncBlockedUntil,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  $$WalletsTableFilterComposer get walletId {
    final $$WalletsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.walletId,
        referencedTable: $db.wallets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WalletsTableFilterComposer(
              $db: $db,
              $table: $db.wallets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get idaccount => $composableBuilder(
      column: $table.idaccount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get provider => $composableBuilder(
      column: $table.provider, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get images => $composableBuilder(
      column: $table.images, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get goalId => $composableBuilder(
      column: $table.goalId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get walletTransfer => $composableBuilder(
      column: $table.walletTransfer,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bankTranId => $composableBuilder(
      column: $table.bankTranId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncRetryCount => $composableBuilder(
      column: $table.syncRetryCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncError => $composableBuilder(
      column: $table.syncError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncBlockedUntil => $composableBuilder(
      column: $table.syncBlockedUntil,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  $$WalletsTableOrderingComposer get walletId {
    final $$WalletsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.walletId,
        referencedTable: $db.wallets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WalletsTableOrderingComposer(
              $db: $db,
              $table: $db.wallets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get idaccount =>
      $composableBuilder(column: $table.idaccount, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get images =>
      $composableBuilder(column: $table.images, builder: (column) => column);

  GeneratedColumn<String> get goalId =>
      $composableBuilder(column: $table.goalId, builder: (column) => column);

  GeneratedColumn<String> get walletTransfer => $composableBuilder(
      column: $table.walletTransfer, builder: (column) => column);

  GeneratedColumn<String> get bankTranId => $composableBuilder(
      column: $table.bankTranId, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<int> get syncRetryCount => $composableBuilder(
      column: $table.syncRetryCount, builder: (column) => column);

  GeneratedColumn<String> get syncError =>
      $composableBuilder(column: $table.syncError, builder: (column) => column);

  GeneratedColumn<DateTime> get syncBlockedUntil => $composableBuilder(
      column: $table.syncBlockedUntil, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  $$WalletsTableAnnotationComposer get walletId {
    final $$WalletsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.walletId,
        referencedTable: $db.wallets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WalletsTableAnnotationComposer(
              $db: $db,
              $table: $db.wallets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TransactionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TransactionsTable,
    Transaction,
    $$TransactionsTableFilterComposer,
    $$TransactionsTableOrderingComposer,
    $$TransactionsTableAnnotationComposer,
    $$TransactionsTableCreateCompanionBuilder,
    $$TransactionsTableUpdateCompanionBuilder,
    (Transaction, $$TransactionsTableReferences),
    Transaction,
    PrefetchHooks Function({bool walletId})> {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> walletId = const Value.absent(),
            Value<int> idaccount = const Value.absent(),
            Value<String?> categoryId = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> provider = const Value.absent(),
            Value<String> note = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
            Value<String> images = const Value.absent(),
            Value<String?> goalId = const Value.absent(),
            Value<String?> walletTransfer = const Value.absent(),
            Value<String?> bankTranId = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> syncRetryCount = const Value.absent(),
            Value<String?> syncError = const Value.absent(),
            Value<DateTime?> syncBlockedUntil = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TransactionsCompanion(
            id: id,
            walletId: walletId,
            idaccount: idaccount,
            categoryId: categoryId,
            amount: amount,
            type: type,
            status: status,
            provider: provider,
            note: note,
            date: date,
            images: images,
            goalId: goalId,
            walletTransfer: walletTransfer,
            bankTranId: bankTranId,
            deletedAt: deletedAt,
            syncStatus: syncStatus,
            syncRetryCount: syncRetryCount,
            syncError: syncError,
            syncBlockedUntil: syncBlockedUntil,
            updatedAt: updatedAt,
            isDeleted: isDeleted,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String walletId,
            required int idaccount,
            Value<String?> categoryId = const Value.absent(),
            required double amount,
            required String type,
            Value<String> status = const Value.absent(),
            Value<String> provider = const Value.absent(),
            Value<String> note = const Value.absent(),
            required DateTime date,
            Value<String> images = const Value.absent(),
            Value<String?> goalId = const Value.absent(),
            Value<String?> walletTransfer = const Value.absent(),
            Value<String?> bankTranId = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> syncRetryCount = const Value.absent(),
            Value<String?> syncError = const Value.absent(),
            Value<DateTime?> syncBlockedUntil = const Value.absent(),
            required DateTime updatedAt,
            Value<bool> isDeleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TransactionsCompanion.insert(
            id: id,
            walletId: walletId,
            idaccount: idaccount,
            categoryId: categoryId,
            amount: amount,
            type: type,
            status: status,
            provider: provider,
            note: note,
            date: date,
            images: images,
            goalId: goalId,
            walletTransfer: walletTransfer,
            bankTranId: bankTranId,
            deletedAt: deletedAt,
            syncStatus: syncStatus,
            syncRetryCount: syncRetryCount,
            syncError: syncError,
            syncBlockedUntil: syncBlockedUntil,
            updatedAt: updatedAt,
            isDeleted: isDeleted,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$TransactionsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({walletId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (walletId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.walletId,
                    referencedTable:
                        $$TransactionsTableReferences._walletIdTable(db),
                    referencedColumn:
                        $$TransactionsTableReferences._walletIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$TransactionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TransactionsTable,
    Transaction,
    $$TransactionsTableFilterComposer,
    $$TransactionsTableOrderingComposer,
    $$TransactionsTableAnnotationComposer,
    $$TransactionsTableCreateCompanionBuilder,
    $$TransactionsTableUpdateCompanionBuilder,
    (Transaction, $$TransactionsTableReferences),
    Transaction,
    PrefetchHooks Function({bool walletId})>;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required String id,
  required int idaccount,
  required String name,
  required String classify,
  Value<String> icon,
  Value<String> colour,
  Value<bool> isDefault,
  Value<bool> isDeleted,
  Value<String?> parentId,
  Value<bool> isGroup,
  Value<bool> isLocalOnly,
  Value<DateTime?> deletedAt,
  Value<String> syncStatus,
  Value<int> syncRetryCount,
  Value<String?> syncError,
  Value<DateTime?> syncBlockedUntil,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> id,
  Value<int> idaccount,
  Value<String> name,
  Value<String> classify,
  Value<String> icon,
  Value<String> colour,
  Value<bool> isDefault,
  Value<bool> isDeleted,
  Value<String?> parentId,
  Value<bool> isGroup,
  Value<bool> isLocalOnly,
  Value<DateTime?> deletedAt,
  Value<String> syncStatus,
  Value<int> syncRetryCount,
  Value<String?> syncError,
  Value<DateTime?> syncBlockedUntil,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get idaccount => $composableBuilder(
      column: $table.idaccount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get classify => $composableBuilder(
      column: $table.classify, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get colour => $composableBuilder(
      column: $table.colour, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDefault => $composableBuilder(
      column: $table.isDefault, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isGroup => $composableBuilder(
      column: $table.isGroup, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isLocalOnly => $composableBuilder(
      column: $table.isLocalOnly, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncRetryCount => $composableBuilder(
      column: $table.syncRetryCount,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncError => $composableBuilder(
      column: $table.syncError, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncBlockedUntil => $composableBuilder(
      column: $table.syncBlockedUntil,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get idaccount => $composableBuilder(
      column: $table.idaccount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get classify => $composableBuilder(
      column: $table.classify, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get colour => $composableBuilder(
      column: $table.colour, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDefault => $composableBuilder(
      column: $table.isDefault, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isGroup => $composableBuilder(
      column: $table.isGroup, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isLocalOnly => $composableBuilder(
      column: $table.isLocalOnly, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncRetryCount => $composableBuilder(
      column: $table.syncRetryCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncError => $composableBuilder(
      column: $table.syncError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncBlockedUntil => $composableBuilder(
      column: $table.syncBlockedUntil,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get idaccount =>
      $composableBuilder(column: $table.idaccount, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get classify =>
      $composableBuilder(column: $table.classify, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get colour =>
      $composableBuilder(column: $table.colour, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<bool> get isGroup =>
      $composableBuilder(column: $table.isGroup, builder: (column) => column);

  GeneratedColumn<bool> get isLocalOnly => $composableBuilder(
      column: $table.isLocalOnly, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<int> get syncRetryCount => $composableBuilder(
      column: $table.syncRetryCount, builder: (column) => column);

  GeneratedColumn<String> get syncError =>
      $composableBuilder(column: $table.syncError, builder: (column) => column);

  GeneratedColumn<DateTime> get syncBlockedUntil => $composableBuilder(
      column: $table.syncBlockedUntil, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CategoriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CategoriesTable,
    Category,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableAnnotationComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder,
    (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
    Category,
    PrefetchHooks Function()> {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<int> idaccount = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> classify = const Value.absent(),
            Value<String> icon = const Value.absent(),
            Value<String> colour = const Value.absent(),
            Value<bool> isDefault = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> parentId = const Value.absent(),
            Value<bool> isGroup = const Value.absent(),
            Value<bool> isLocalOnly = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> syncRetryCount = const Value.absent(),
            Value<String?> syncError = const Value.absent(),
            Value<DateTime?> syncBlockedUntil = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CategoriesCompanion(
            id: id,
            idaccount: idaccount,
            name: name,
            classify: classify,
            icon: icon,
            colour: colour,
            isDefault: isDefault,
            isDeleted: isDeleted,
            parentId: parentId,
            isGroup: isGroup,
            isLocalOnly: isLocalOnly,
            deletedAt: deletedAt,
            syncStatus: syncStatus,
            syncRetryCount: syncRetryCount,
            syncError: syncError,
            syncBlockedUntil: syncBlockedUntil,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required int idaccount,
            required String name,
            required String classify,
            Value<String> icon = const Value.absent(),
            Value<String> colour = const Value.absent(),
            Value<bool> isDefault = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> parentId = const Value.absent(),
            Value<bool> isGroup = const Value.absent(),
            Value<bool> isLocalOnly = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> syncRetryCount = const Value.absent(),
            Value<String?> syncError = const Value.absent(),
            Value<DateTime?> syncBlockedUntil = const Value.absent(),
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CategoriesCompanion.insert(
            id: id,
            idaccount: idaccount,
            name: name,
            classify: classify,
            icon: icon,
            colour: colour,
            isDefault: isDefault,
            isDeleted: isDeleted,
            parentId: parentId,
            isGroup: isGroup,
            isLocalOnly: isLocalOnly,
            deletedAt: deletedAt,
            syncStatus: syncStatus,
            syncRetryCount: syncRetryCount,
            syncError: syncError,
            syncBlockedUntil: syncBlockedUntil,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CategoriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CategoriesTable,
    Category,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableAnnotationComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder,
    (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
    Category,
    PrefetchHooks Function()>;
typedef $$CategoryKeywordsTableCreateCompanionBuilder
    = CategoryKeywordsCompanion Function({
  required String id,
  required int idaccount,
  required String categoryId,
  required String keyword,
  required String normalizedKeyword,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$CategoryKeywordsTableUpdateCompanionBuilder
    = CategoryKeywordsCompanion Function({
  Value<String> id,
  Value<int> idaccount,
  Value<String> categoryId,
  Value<String> keyword,
  Value<String> normalizedKeyword,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$CategoryKeywordsTableFilterComposer
    extends Composer<_$AppDatabase, $CategoryKeywordsTable> {
  $$CategoryKeywordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get idaccount => $composableBuilder(
      column: $table.idaccount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get keyword => $composableBuilder(
      column: $table.keyword, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get normalizedKeyword => $composableBuilder(
      column: $table.normalizedKeyword,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$CategoryKeywordsTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoryKeywordsTable> {
  $$CategoryKeywordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get idaccount => $composableBuilder(
      column: $table.idaccount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get keyword => $composableBuilder(
      column: $table.keyword, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get normalizedKeyword => $composableBuilder(
      column: $table.normalizedKeyword,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$CategoryKeywordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoryKeywordsTable> {
  $$CategoryKeywordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get idaccount =>
      $composableBuilder(column: $table.idaccount, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<String> get keyword =>
      $composableBuilder(column: $table.keyword, builder: (column) => column);

  GeneratedColumn<String> get normalizedKeyword => $composableBuilder(
      column: $table.normalizedKeyword, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CategoryKeywordsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CategoryKeywordsTable,
    CategoryKeyword,
    $$CategoryKeywordsTableFilterComposer,
    $$CategoryKeywordsTableOrderingComposer,
    $$CategoryKeywordsTableAnnotationComposer,
    $$CategoryKeywordsTableCreateCompanionBuilder,
    $$CategoryKeywordsTableUpdateCompanionBuilder,
    (
      CategoryKeyword,
      BaseReferences<_$AppDatabase, $CategoryKeywordsTable, CategoryKeyword>
    ),
    CategoryKeyword,
    PrefetchHooks Function()> {
  $$CategoryKeywordsTableTableManager(
      _$AppDatabase db, $CategoryKeywordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoryKeywordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoryKeywordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoryKeywordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<int> idaccount = const Value.absent(),
            Value<String> categoryId = const Value.absent(),
            Value<String> keyword = const Value.absent(),
            Value<String> normalizedKeyword = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CategoryKeywordsCompanion(
            id: id,
            idaccount: idaccount,
            categoryId: categoryId,
            keyword: keyword,
            normalizedKeyword: normalizedKeyword,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required int idaccount,
            required String categoryId,
            required String keyword,
            required String normalizedKeyword,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CategoryKeywordsCompanion.insert(
            id: id,
            idaccount: idaccount,
            categoryId: categoryId,
            keyword: keyword,
            normalizedKeyword: normalizedKeyword,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CategoryKeywordsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CategoryKeywordsTable,
    CategoryKeyword,
    $$CategoryKeywordsTableFilterComposer,
    $$CategoryKeywordsTableOrderingComposer,
    $$CategoryKeywordsTableAnnotationComposer,
    $$CategoryKeywordsTableCreateCompanionBuilder,
    $$CategoryKeywordsTableUpdateCompanionBuilder,
    (
      CategoryKeyword,
      BaseReferences<_$AppDatabase, $CategoryKeywordsTable, CategoryKeyword>
    ),
    CategoryKeyword,
    PrefetchHooks Function()>;
typedef $$CategoryGroupMembershipsTableCreateCompanionBuilder
    = CategoryGroupMembershipsCompanion Function({
  required String id,
  required int idaccount,
  required String groupId,
  required String categoryId,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$CategoryGroupMembershipsTableUpdateCompanionBuilder
    = CategoryGroupMembershipsCompanion Function({
  Value<String> id,
  Value<int> idaccount,
  Value<String> groupId,
  Value<String> categoryId,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$CategoryGroupMembershipsTableFilterComposer
    extends Composer<_$AppDatabase, $CategoryGroupMembershipsTable> {
  $$CategoryGroupMembershipsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get idaccount => $composableBuilder(
      column: $table.idaccount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$CategoryGroupMembershipsTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoryGroupMembershipsTable> {
  $$CategoryGroupMembershipsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get idaccount => $composableBuilder(
      column: $table.idaccount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$CategoryGroupMembershipsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoryGroupMembershipsTable> {
  $$CategoryGroupMembershipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get idaccount =>
      $composableBuilder(column: $table.idaccount, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CategoryGroupMembershipsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CategoryGroupMembershipsTable,
    CategoryGroupMembership,
    $$CategoryGroupMembershipsTableFilterComposer,
    $$CategoryGroupMembershipsTableOrderingComposer,
    $$CategoryGroupMembershipsTableAnnotationComposer,
    $$CategoryGroupMembershipsTableCreateCompanionBuilder,
    $$CategoryGroupMembershipsTableUpdateCompanionBuilder,
    (
      CategoryGroupMembership,
      BaseReferences<_$AppDatabase, $CategoryGroupMembershipsTable,
          CategoryGroupMembership>
    ),
    CategoryGroupMembership,
    PrefetchHooks Function()> {
  $$CategoryGroupMembershipsTableTableManager(
      _$AppDatabase db, $CategoryGroupMembershipsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoryGroupMembershipsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoryGroupMembershipsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoryGroupMembershipsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<int> idaccount = const Value.absent(),
            Value<String> groupId = const Value.absent(),
            Value<String> categoryId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CategoryGroupMembershipsCompanion(
            id: id,
            idaccount: idaccount,
            groupId: groupId,
            categoryId: categoryId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required int idaccount,
            required String groupId,
            required String categoryId,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CategoryGroupMembershipsCompanion.insert(
            id: id,
            idaccount: idaccount,
            groupId: groupId,
            categoryId: categoryId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CategoryGroupMembershipsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $CategoryGroupMembershipsTable,
        CategoryGroupMembership,
        $$CategoryGroupMembershipsTableFilterComposer,
        $$CategoryGroupMembershipsTableOrderingComposer,
        $$CategoryGroupMembershipsTableAnnotationComposer,
        $$CategoryGroupMembershipsTableCreateCompanionBuilder,
        $$CategoryGroupMembershipsTableUpdateCompanionBuilder,
        (
          CategoryGroupMembership,
          BaseReferences<_$AppDatabase, $CategoryGroupMembershipsTable,
              CategoryGroupMembership>
        ),
        CategoryGroupMembership,
        PrefetchHooks Function()>;
typedef $$BudgetsTableCreateCompanionBuilder = BudgetsCompanion Function({
  required String id,
  required int idaccount,
  Value<String?> categoryId,
  required double amount,
  Value<double> spent,
  Value<String> overSpending,
  Value<double?> overAmount,
  Value<double?> thresholdWarningAmount,
  Value<double?> thresholdWarningPercent,
  required DateTime startDate,
  Value<DateTime?> endDate,
  Value<bool> recurrence,
  Value<String?> timeRecurrence,
  Value<String> note,
  Value<DateTime?> nextTimeRecurrence,
  Value<DateTime?> deletedAt,
  Value<bool> isDeleted,
  Value<String> syncStatus,
  Value<int> syncRetryCount,
  Value<String?> syncError,
  Value<DateTime?> syncBlockedUntil,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$BudgetsTableUpdateCompanionBuilder = BudgetsCompanion Function({
  Value<String> id,
  Value<int> idaccount,
  Value<String?> categoryId,
  Value<double> amount,
  Value<double> spent,
  Value<String> overSpending,
  Value<double?> overAmount,
  Value<double?> thresholdWarningAmount,
  Value<double?> thresholdWarningPercent,
  Value<DateTime> startDate,
  Value<DateTime?> endDate,
  Value<bool> recurrence,
  Value<String?> timeRecurrence,
  Value<String> note,
  Value<DateTime?> nextTimeRecurrence,
  Value<DateTime?> deletedAt,
  Value<bool> isDeleted,
  Value<String> syncStatus,
  Value<int> syncRetryCount,
  Value<String?> syncError,
  Value<DateTime?> syncBlockedUntil,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$BudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get idaccount => $composableBuilder(
      column: $table.idaccount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get spent => $composableBuilder(
      column: $table.spent, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get overSpending => $composableBuilder(
      column: $table.overSpending, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get overAmount => $composableBuilder(
      column: $table.overAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get thresholdWarningAmount => $composableBuilder(
      column: $table.thresholdWarningAmount,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get thresholdWarningPercent => $composableBuilder(
      column: $table.thresholdWarningPercent,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endDate => $composableBuilder(
      column: $table.endDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get recurrence => $composableBuilder(
      column: $table.recurrence, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get timeRecurrence => $composableBuilder(
      column: $table.timeRecurrence,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get nextTimeRecurrence => $composableBuilder(
      column: $table.nextTimeRecurrence,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncRetryCount => $composableBuilder(
      column: $table.syncRetryCount,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncError => $composableBuilder(
      column: $table.syncError, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncBlockedUntil => $composableBuilder(
      column: $table.syncBlockedUntil,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$BudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get idaccount => $composableBuilder(
      column: $table.idaccount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get spent => $composableBuilder(
      column: $table.spent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get overSpending => $composableBuilder(
      column: $table.overSpending,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get overAmount => $composableBuilder(
      column: $table.overAmount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get thresholdWarningAmount => $composableBuilder(
      column: $table.thresholdWarningAmount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get thresholdWarningPercent => $composableBuilder(
      column: $table.thresholdWarningPercent,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
      column: $table.endDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get recurrence => $composableBuilder(
      column: $table.recurrence, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get timeRecurrence => $composableBuilder(
      column: $table.timeRecurrence,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get nextTimeRecurrence => $composableBuilder(
      column: $table.nextTimeRecurrence,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncRetryCount => $composableBuilder(
      column: $table.syncRetryCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncError => $composableBuilder(
      column: $table.syncError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncBlockedUntil => $composableBuilder(
      column: $table.syncBlockedUntil,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$BudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get idaccount =>
      $composableBuilder(column: $table.idaccount, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<double> get spent =>
      $composableBuilder(column: $table.spent, builder: (column) => column);

  GeneratedColumn<String> get overSpending => $composableBuilder(
      column: $table.overSpending, builder: (column) => column);

  GeneratedColumn<double> get overAmount => $composableBuilder(
      column: $table.overAmount, builder: (column) => column);

  GeneratedColumn<double> get thresholdWarningAmount => $composableBuilder(
      column: $table.thresholdWarningAmount, builder: (column) => column);

  GeneratedColumn<double> get thresholdWarningPercent => $composableBuilder(
      column: $table.thresholdWarningPercent, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<bool> get recurrence => $composableBuilder(
      column: $table.recurrence, builder: (column) => column);

  GeneratedColumn<String> get timeRecurrence => $composableBuilder(
      column: $table.timeRecurrence, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get nextTimeRecurrence => $composableBuilder(
      column: $table.nextTimeRecurrence, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<int> get syncRetryCount => $composableBuilder(
      column: $table.syncRetryCount, builder: (column) => column);

  GeneratedColumn<String> get syncError =>
      $composableBuilder(column: $table.syncError, builder: (column) => column);

  GeneratedColumn<DateTime> get syncBlockedUntil => $composableBuilder(
      column: $table.syncBlockedUntil, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BudgetsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BudgetsTable,
    Budget,
    $$BudgetsTableFilterComposer,
    $$BudgetsTableOrderingComposer,
    $$BudgetsTableAnnotationComposer,
    $$BudgetsTableCreateCompanionBuilder,
    $$BudgetsTableUpdateCompanionBuilder,
    (Budget, BaseReferences<_$AppDatabase, $BudgetsTable, Budget>),
    Budget,
    PrefetchHooks Function()> {
  $$BudgetsTableTableManager(_$AppDatabase db, $BudgetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<int> idaccount = const Value.absent(),
            Value<String?> categoryId = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<double> spent = const Value.absent(),
            Value<String> overSpending = const Value.absent(),
            Value<double?> overAmount = const Value.absent(),
            Value<double?> thresholdWarningAmount = const Value.absent(),
            Value<double?> thresholdWarningPercent = const Value.absent(),
            Value<DateTime> startDate = const Value.absent(),
            Value<DateTime?> endDate = const Value.absent(),
            Value<bool> recurrence = const Value.absent(),
            Value<String?> timeRecurrence = const Value.absent(),
            Value<String> note = const Value.absent(),
            Value<DateTime?> nextTimeRecurrence = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> syncRetryCount = const Value.absent(),
            Value<String?> syncError = const Value.absent(),
            Value<DateTime?> syncBlockedUntil = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BudgetsCompanion(
            id: id,
            idaccount: idaccount,
            categoryId: categoryId,
            amount: amount,
            spent: spent,
            overSpending: overSpending,
            overAmount: overAmount,
            thresholdWarningAmount: thresholdWarningAmount,
            thresholdWarningPercent: thresholdWarningPercent,
            startDate: startDate,
            endDate: endDate,
            recurrence: recurrence,
            timeRecurrence: timeRecurrence,
            note: note,
            nextTimeRecurrence: nextTimeRecurrence,
            deletedAt: deletedAt,
            isDeleted: isDeleted,
            syncStatus: syncStatus,
            syncRetryCount: syncRetryCount,
            syncError: syncError,
            syncBlockedUntil: syncBlockedUntil,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required int idaccount,
            Value<String?> categoryId = const Value.absent(),
            required double amount,
            Value<double> spent = const Value.absent(),
            Value<String> overSpending = const Value.absent(),
            Value<double?> overAmount = const Value.absent(),
            Value<double?> thresholdWarningAmount = const Value.absent(),
            Value<double?> thresholdWarningPercent = const Value.absent(),
            required DateTime startDate,
            Value<DateTime?> endDate = const Value.absent(),
            Value<bool> recurrence = const Value.absent(),
            Value<String?> timeRecurrence = const Value.absent(),
            Value<String> note = const Value.absent(),
            Value<DateTime?> nextTimeRecurrence = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> syncRetryCount = const Value.absent(),
            Value<String?> syncError = const Value.absent(),
            Value<DateTime?> syncBlockedUntil = const Value.absent(),
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              BudgetsCompanion.insert(
            id: id,
            idaccount: idaccount,
            categoryId: categoryId,
            amount: amount,
            spent: spent,
            overSpending: overSpending,
            overAmount: overAmount,
            thresholdWarningAmount: thresholdWarningAmount,
            thresholdWarningPercent: thresholdWarningPercent,
            startDate: startDate,
            endDate: endDate,
            recurrence: recurrence,
            timeRecurrence: timeRecurrence,
            note: note,
            nextTimeRecurrence: nextTimeRecurrence,
            deletedAt: deletedAt,
            isDeleted: isDeleted,
            syncStatus: syncStatus,
            syncRetryCount: syncRetryCount,
            syncError: syncError,
            syncBlockedUntil: syncBlockedUntil,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BudgetsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BudgetsTable,
    Budget,
    $$BudgetsTableFilterComposer,
    $$BudgetsTableOrderingComposer,
    $$BudgetsTableAnnotationComposer,
    $$BudgetsTableCreateCompanionBuilder,
    $$BudgetsTableUpdateCompanionBuilder,
    (Budget, BaseReferences<_$AppDatabase, $BudgetsTable, Budget>),
    Budget,
    PrefetchHooks Function()>;
typedef $$BillsTableCreateCompanionBuilder = BillsCompanion Function({
  required String id,
  required int idaccount,
  Value<String?> walletId,
  Value<String?> categoryId,
  required String name,
  required double amount,
  Value<DateTime?> startDate,
  required DateTime dueDate,
  Value<String> payStatus,
  Value<bool> isPaid,
  Value<String?> timeNotification,
  Value<bool> isRecurrence,
  Value<String> timeRecurrence,
  Value<String> recurrence,
  Value<String> icon,
  Value<String> colour,
  Value<String> note,
  Value<DateTime?> deletedAt,
  Value<bool> isDeleted,
  Value<String> syncStatus,
  Value<int> syncRetryCount,
  Value<String?> syncError,
  Value<DateTime?> syncBlockedUntil,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$BillsTableUpdateCompanionBuilder = BillsCompanion Function({
  Value<String> id,
  Value<int> idaccount,
  Value<String?> walletId,
  Value<String?> categoryId,
  Value<String> name,
  Value<double> amount,
  Value<DateTime?> startDate,
  Value<DateTime> dueDate,
  Value<String> payStatus,
  Value<bool> isPaid,
  Value<String?> timeNotification,
  Value<bool> isRecurrence,
  Value<String> timeRecurrence,
  Value<String> recurrence,
  Value<String> icon,
  Value<String> colour,
  Value<String> note,
  Value<DateTime?> deletedAt,
  Value<bool> isDeleted,
  Value<String> syncStatus,
  Value<int> syncRetryCount,
  Value<String?> syncError,
  Value<DateTime?> syncBlockedUntil,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$BillsTableFilterComposer extends Composer<_$AppDatabase, $BillsTable> {
  $$BillsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get idaccount => $composableBuilder(
      column: $table.idaccount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get walletId => $composableBuilder(
      column: $table.walletId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
      column: $table.dueDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payStatus => $composableBuilder(
      column: $table.payStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPaid => $composableBuilder(
      column: $table.isPaid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get timeNotification => $composableBuilder(
      column: $table.timeNotification,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isRecurrence => $composableBuilder(
      column: $table.isRecurrence, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get timeRecurrence => $composableBuilder(
      column: $table.timeRecurrence,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recurrence => $composableBuilder(
      column: $table.recurrence, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get colour => $composableBuilder(
      column: $table.colour, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncRetryCount => $composableBuilder(
      column: $table.syncRetryCount,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncError => $composableBuilder(
      column: $table.syncError, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncBlockedUntil => $composableBuilder(
      column: $table.syncBlockedUntil,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$BillsTableOrderingComposer
    extends Composer<_$AppDatabase, $BillsTable> {
  $$BillsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get idaccount => $composableBuilder(
      column: $table.idaccount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get walletId => $composableBuilder(
      column: $table.walletId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
      column: $table.dueDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payStatus => $composableBuilder(
      column: $table.payStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPaid => $composableBuilder(
      column: $table.isPaid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get timeNotification => $composableBuilder(
      column: $table.timeNotification,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isRecurrence => $composableBuilder(
      column: $table.isRecurrence,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get timeRecurrence => $composableBuilder(
      column: $table.timeRecurrence,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recurrence => $composableBuilder(
      column: $table.recurrence, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get colour => $composableBuilder(
      column: $table.colour, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncRetryCount => $composableBuilder(
      column: $table.syncRetryCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncError => $composableBuilder(
      column: $table.syncError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncBlockedUntil => $composableBuilder(
      column: $table.syncBlockedUntil,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$BillsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BillsTable> {
  $$BillsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get idaccount =>
      $composableBuilder(column: $table.idaccount, builder: (column) => column);

  GeneratedColumn<String> get walletId =>
      $composableBuilder(column: $table.walletId, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<String> get payStatus =>
      $composableBuilder(column: $table.payStatus, builder: (column) => column);

  GeneratedColumn<bool> get isPaid =>
      $composableBuilder(column: $table.isPaid, builder: (column) => column);

  GeneratedColumn<String> get timeNotification => $composableBuilder(
      column: $table.timeNotification, builder: (column) => column);

  GeneratedColumn<bool> get isRecurrence => $composableBuilder(
      column: $table.isRecurrence, builder: (column) => column);

  GeneratedColumn<String> get timeRecurrence => $composableBuilder(
      column: $table.timeRecurrence, builder: (column) => column);

  GeneratedColumn<String> get recurrence => $composableBuilder(
      column: $table.recurrence, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get colour =>
      $composableBuilder(column: $table.colour, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<int> get syncRetryCount => $composableBuilder(
      column: $table.syncRetryCount, builder: (column) => column);

  GeneratedColumn<String> get syncError =>
      $composableBuilder(column: $table.syncError, builder: (column) => column);

  GeneratedColumn<DateTime> get syncBlockedUntil => $composableBuilder(
      column: $table.syncBlockedUntil, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BillsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BillsTable,
    Bill,
    $$BillsTableFilterComposer,
    $$BillsTableOrderingComposer,
    $$BillsTableAnnotationComposer,
    $$BillsTableCreateCompanionBuilder,
    $$BillsTableUpdateCompanionBuilder,
    (Bill, BaseReferences<_$AppDatabase, $BillsTable, Bill>),
    Bill,
    PrefetchHooks Function()> {
  $$BillsTableTableManager(_$AppDatabase db, $BillsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BillsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BillsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BillsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<int> idaccount = const Value.absent(),
            Value<String?> walletId = const Value.absent(),
            Value<String?> categoryId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<DateTime?> startDate = const Value.absent(),
            Value<DateTime> dueDate = const Value.absent(),
            Value<String> payStatus = const Value.absent(),
            Value<bool> isPaid = const Value.absent(),
            Value<String?> timeNotification = const Value.absent(),
            Value<bool> isRecurrence = const Value.absent(),
            Value<String> timeRecurrence = const Value.absent(),
            Value<String> recurrence = const Value.absent(),
            Value<String> icon = const Value.absent(),
            Value<String> colour = const Value.absent(),
            Value<String> note = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> syncRetryCount = const Value.absent(),
            Value<String?> syncError = const Value.absent(),
            Value<DateTime?> syncBlockedUntil = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BillsCompanion(
            id: id,
            idaccount: idaccount,
            walletId: walletId,
            categoryId: categoryId,
            name: name,
            amount: amount,
            startDate: startDate,
            dueDate: dueDate,
            payStatus: payStatus,
            isPaid: isPaid,
            timeNotification: timeNotification,
            isRecurrence: isRecurrence,
            timeRecurrence: timeRecurrence,
            recurrence: recurrence,
            icon: icon,
            colour: colour,
            note: note,
            deletedAt: deletedAt,
            isDeleted: isDeleted,
            syncStatus: syncStatus,
            syncRetryCount: syncRetryCount,
            syncError: syncError,
            syncBlockedUntil: syncBlockedUntil,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required int idaccount,
            Value<String?> walletId = const Value.absent(),
            Value<String?> categoryId = const Value.absent(),
            required String name,
            required double amount,
            Value<DateTime?> startDate = const Value.absent(),
            required DateTime dueDate,
            Value<String> payStatus = const Value.absent(),
            Value<bool> isPaid = const Value.absent(),
            Value<String?> timeNotification = const Value.absent(),
            Value<bool> isRecurrence = const Value.absent(),
            Value<String> timeRecurrence = const Value.absent(),
            Value<String> recurrence = const Value.absent(),
            Value<String> icon = const Value.absent(),
            Value<String> colour = const Value.absent(),
            Value<String> note = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> syncRetryCount = const Value.absent(),
            Value<String?> syncError = const Value.absent(),
            Value<DateTime?> syncBlockedUntil = const Value.absent(),
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              BillsCompanion.insert(
            id: id,
            idaccount: idaccount,
            walletId: walletId,
            categoryId: categoryId,
            name: name,
            amount: amount,
            startDate: startDate,
            dueDate: dueDate,
            payStatus: payStatus,
            isPaid: isPaid,
            timeNotification: timeNotification,
            isRecurrence: isRecurrence,
            timeRecurrence: timeRecurrence,
            recurrence: recurrence,
            icon: icon,
            colour: colour,
            note: note,
            deletedAt: deletedAt,
            isDeleted: isDeleted,
            syncStatus: syncStatus,
            syncRetryCount: syncRetryCount,
            syncError: syncError,
            syncBlockedUntil: syncBlockedUntil,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BillsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BillsTable,
    Bill,
    $$BillsTableFilterComposer,
    $$BillsTableOrderingComposer,
    $$BillsTableAnnotationComposer,
    $$BillsTableCreateCompanionBuilder,
    $$BillsTableUpdateCompanionBuilder,
    (Bill, BaseReferences<_$AppDatabase, $BillsTable, Bill>),
    Bill,
    PrefetchHooks Function()>;
typedef $$GoalsTableCreateCompanionBuilder = GoalsCompanion Function({
  required String id,
  required int idaccount,
  required String name,
  required double targetAmount,
  Value<double> currentAmount,
  Value<DateTime?> startDate,
  required DateTime targetDate,
  Value<String?> walletId,
  Value<String?> cycleTakeMoney,
  Value<DateTime?> timeCycleTakeMoney,
  Value<double?> autoDepositAmount,
  Value<String?> autoDepositWalletId,
  Value<DateTime?> autoDepositLastRun,
  Value<bool> recurrence,
  Value<String?> timeRecurrence,
  Value<String> icon,
  Value<String> colour,
  Value<String> note,
  Value<bool> isCompleted,
  Value<DateTime?> deletedAt,
  Value<bool> isDeleted,
  Value<String> syncStatus,
  Value<int> syncRetryCount,
  Value<String?> syncError,
  Value<DateTime?> syncBlockedUntil,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$GoalsTableUpdateCompanionBuilder = GoalsCompanion Function({
  Value<String> id,
  Value<int> idaccount,
  Value<String> name,
  Value<double> targetAmount,
  Value<double> currentAmount,
  Value<DateTime?> startDate,
  Value<DateTime> targetDate,
  Value<String?> walletId,
  Value<String?> cycleTakeMoney,
  Value<DateTime?> timeCycleTakeMoney,
  Value<double?> autoDepositAmount,
  Value<String?> autoDepositWalletId,
  Value<DateTime?> autoDepositLastRun,
  Value<bool> recurrence,
  Value<String?> timeRecurrence,
  Value<String> icon,
  Value<String> colour,
  Value<String> note,
  Value<bool> isCompleted,
  Value<DateTime?> deletedAt,
  Value<bool> isDeleted,
  Value<String> syncStatus,
  Value<int> syncRetryCount,
  Value<String?> syncError,
  Value<DateTime?> syncBlockedUntil,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$GoalsTableFilterComposer extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get idaccount => $composableBuilder(
      column: $table.idaccount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get targetAmount => $composableBuilder(
      column: $table.targetAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get currentAmount => $composableBuilder(
      column: $table.currentAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get targetDate => $composableBuilder(
      column: $table.targetDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get walletId => $composableBuilder(
      column: $table.walletId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cycleTakeMoney => $composableBuilder(
      column: $table.cycleTakeMoney,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timeCycleTakeMoney => $composableBuilder(
      column: $table.timeCycleTakeMoney,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get autoDepositAmount => $composableBuilder(
      column: $table.autoDepositAmount,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get autoDepositWalletId => $composableBuilder(
      column: $table.autoDepositWalletId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get autoDepositLastRun => $composableBuilder(
      column: $table.autoDepositLastRun,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get recurrence => $composableBuilder(
      column: $table.recurrence, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get timeRecurrence => $composableBuilder(
      column: $table.timeRecurrence,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get colour => $composableBuilder(
      column: $table.colour, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncRetryCount => $composableBuilder(
      column: $table.syncRetryCount,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncError => $composableBuilder(
      column: $table.syncError, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncBlockedUntil => $composableBuilder(
      column: $table.syncBlockedUntil,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$GoalsTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get idaccount => $composableBuilder(
      column: $table.idaccount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get targetAmount => $composableBuilder(
      column: $table.targetAmount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get currentAmount => $composableBuilder(
      column: $table.currentAmount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get targetDate => $composableBuilder(
      column: $table.targetDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get walletId => $composableBuilder(
      column: $table.walletId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cycleTakeMoney => $composableBuilder(
      column: $table.cycleTakeMoney,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timeCycleTakeMoney => $composableBuilder(
      column: $table.timeCycleTakeMoney,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get autoDepositAmount => $composableBuilder(
      column: $table.autoDepositAmount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get autoDepositWalletId => $composableBuilder(
      column: $table.autoDepositWalletId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get autoDepositLastRun => $composableBuilder(
      column: $table.autoDepositLastRun,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get recurrence => $composableBuilder(
      column: $table.recurrence, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get timeRecurrence => $composableBuilder(
      column: $table.timeRecurrence,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get colour => $composableBuilder(
      column: $table.colour, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncRetryCount => $composableBuilder(
      column: $table.syncRetryCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncError => $composableBuilder(
      column: $table.syncError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncBlockedUntil => $composableBuilder(
      column: $table.syncBlockedUntil,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$GoalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get idaccount =>
      $composableBuilder(column: $table.idaccount, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get targetAmount => $composableBuilder(
      column: $table.targetAmount, builder: (column) => column);

  GeneratedColumn<double> get currentAmount => $composableBuilder(
      column: $table.currentAmount, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get targetDate => $composableBuilder(
      column: $table.targetDate, builder: (column) => column);

  GeneratedColumn<String> get walletId =>
      $composableBuilder(column: $table.walletId, builder: (column) => column);

  GeneratedColumn<String> get cycleTakeMoney => $composableBuilder(
      column: $table.cycleTakeMoney, builder: (column) => column);

  GeneratedColumn<DateTime> get timeCycleTakeMoney => $composableBuilder(
      column: $table.timeCycleTakeMoney, builder: (column) => column);

  GeneratedColumn<double> get autoDepositAmount => $composableBuilder(
      column: $table.autoDepositAmount, builder: (column) => column);

  GeneratedColumn<String> get autoDepositWalletId => $composableBuilder(
      column: $table.autoDepositWalletId, builder: (column) => column);

  GeneratedColumn<DateTime> get autoDepositLastRun => $composableBuilder(
      column: $table.autoDepositLastRun, builder: (column) => column);

  GeneratedColumn<bool> get recurrence => $composableBuilder(
      column: $table.recurrence, builder: (column) => column);

  GeneratedColumn<String> get timeRecurrence => $composableBuilder(
      column: $table.timeRecurrence, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get colour =>
      $composableBuilder(column: $table.colour, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<int> get syncRetryCount => $composableBuilder(
      column: $table.syncRetryCount, builder: (column) => column);

  GeneratedColumn<String> get syncError =>
      $composableBuilder(column: $table.syncError, builder: (column) => column);

  GeneratedColumn<DateTime> get syncBlockedUntil => $composableBuilder(
      column: $table.syncBlockedUntil, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$GoalsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $GoalsTable,
    Goal,
    $$GoalsTableFilterComposer,
    $$GoalsTableOrderingComposer,
    $$GoalsTableAnnotationComposer,
    $$GoalsTableCreateCompanionBuilder,
    $$GoalsTableUpdateCompanionBuilder,
    (Goal, BaseReferences<_$AppDatabase, $GoalsTable, Goal>),
    Goal,
    PrefetchHooks Function()> {
  $$GoalsTableTableManager(_$AppDatabase db, $GoalsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<int> idaccount = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<double> targetAmount = const Value.absent(),
            Value<double> currentAmount = const Value.absent(),
            Value<DateTime?> startDate = const Value.absent(),
            Value<DateTime> targetDate = const Value.absent(),
            Value<String?> walletId = const Value.absent(),
            Value<String?> cycleTakeMoney = const Value.absent(),
            Value<DateTime?> timeCycleTakeMoney = const Value.absent(),
            Value<double?> autoDepositAmount = const Value.absent(),
            Value<String?> autoDepositWalletId = const Value.absent(),
            Value<DateTime?> autoDepositLastRun = const Value.absent(),
            Value<bool> recurrence = const Value.absent(),
            Value<String?> timeRecurrence = const Value.absent(),
            Value<String> icon = const Value.absent(),
            Value<String> colour = const Value.absent(),
            Value<String> note = const Value.absent(),
            Value<bool> isCompleted = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> syncRetryCount = const Value.absent(),
            Value<String?> syncError = const Value.absent(),
            Value<DateTime?> syncBlockedUntil = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GoalsCompanion(
            id: id,
            idaccount: idaccount,
            name: name,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            startDate: startDate,
            targetDate: targetDate,
            walletId: walletId,
            cycleTakeMoney: cycleTakeMoney,
            timeCycleTakeMoney: timeCycleTakeMoney,
            autoDepositAmount: autoDepositAmount,
            autoDepositWalletId: autoDepositWalletId,
            autoDepositLastRun: autoDepositLastRun,
            recurrence: recurrence,
            timeRecurrence: timeRecurrence,
            icon: icon,
            colour: colour,
            note: note,
            isCompleted: isCompleted,
            deletedAt: deletedAt,
            isDeleted: isDeleted,
            syncStatus: syncStatus,
            syncRetryCount: syncRetryCount,
            syncError: syncError,
            syncBlockedUntil: syncBlockedUntil,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required int idaccount,
            required String name,
            required double targetAmount,
            Value<double> currentAmount = const Value.absent(),
            Value<DateTime?> startDate = const Value.absent(),
            required DateTime targetDate,
            Value<String?> walletId = const Value.absent(),
            Value<String?> cycleTakeMoney = const Value.absent(),
            Value<DateTime?> timeCycleTakeMoney = const Value.absent(),
            Value<double?> autoDepositAmount = const Value.absent(),
            Value<String?> autoDepositWalletId = const Value.absent(),
            Value<DateTime?> autoDepositLastRun = const Value.absent(),
            Value<bool> recurrence = const Value.absent(),
            Value<String?> timeRecurrence = const Value.absent(),
            Value<String> icon = const Value.absent(),
            Value<String> colour = const Value.absent(),
            Value<String> note = const Value.absent(),
            Value<bool> isCompleted = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> syncRetryCount = const Value.absent(),
            Value<String?> syncError = const Value.absent(),
            Value<DateTime?> syncBlockedUntil = const Value.absent(),
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              GoalsCompanion.insert(
            id: id,
            idaccount: idaccount,
            name: name,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            startDate: startDate,
            targetDate: targetDate,
            walletId: walletId,
            cycleTakeMoney: cycleTakeMoney,
            timeCycleTakeMoney: timeCycleTakeMoney,
            autoDepositAmount: autoDepositAmount,
            autoDepositWalletId: autoDepositWalletId,
            autoDepositLastRun: autoDepositLastRun,
            recurrence: recurrence,
            timeRecurrence: timeRecurrence,
            icon: icon,
            colour: colour,
            note: note,
            isCompleted: isCompleted,
            deletedAt: deletedAt,
            isDeleted: isDeleted,
            syncStatus: syncStatus,
            syncRetryCount: syncRetryCount,
            syncError: syncError,
            syncBlockedUntil: syncBlockedUntil,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$GoalsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $GoalsTable,
    Goal,
    $$GoalsTableFilterComposer,
    $$GoalsTableOrderingComposer,
    $$GoalsTableAnnotationComposer,
    $$GoalsTableCreateCompanionBuilder,
    $$GoalsTableUpdateCompanionBuilder,
    (Goal, BaseReferences<_$AppDatabase, $GoalsTable, Goal>),
    Goal,
    PrefetchHooks Function()>;
typedef $$AppNotificationsTableCreateCompanionBuilder
    = AppNotificationsCompanion Function({
  required String id,
  required int idaccount,
  required String kind,
  required String dedupeKey,
  required String title,
  required String body,
  required String severity,
  Value<String?> subjectType,
  Value<String?> subjectId,
  Value<String?> deeplink,
  required DateTime createdAt,
  Value<DateTime?> readAt,
  Value<DateTime?> dismissedAt,
  Value<int?> osScheduledId,
  Value<DateTime?> osDeliveredAt,
  Value<int> rowid,
});
typedef $$AppNotificationsTableUpdateCompanionBuilder
    = AppNotificationsCompanion Function({
  Value<String> id,
  Value<int> idaccount,
  Value<String> kind,
  Value<String> dedupeKey,
  Value<String> title,
  Value<String> body,
  Value<String> severity,
  Value<String?> subjectType,
  Value<String?> subjectId,
  Value<String?> deeplink,
  Value<DateTime> createdAt,
  Value<DateTime?> readAt,
  Value<DateTime?> dismissedAt,
  Value<int?> osScheduledId,
  Value<DateTime?> osDeliveredAt,
  Value<int> rowid,
});

class $$AppNotificationsTableFilterComposer
    extends Composer<_$AppDatabase, $AppNotificationsTable> {
  $$AppNotificationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get idaccount => $composableBuilder(
      column: $table.idaccount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dedupeKey => $composableBuilder(
      column: $table.dedupeKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get severity => $composableBuilder(
      column: $table.severity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subjectType => $composableBuilder(
      column: $table.subjectType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subjectId => $composableBuilder(
      column: $table.subjectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deeplink => $composableBuilder(
      column: $table.deeplink, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get readAt => $composableBuilder(
      column: $table.readAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dismissedAt => $composableBuilder(
      column: $table.dismissedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get osScheduledId => $composableBuilder(
      column: $table.osScheduledId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get osDeliveredAt => $composableBuilder(
      column: $table.osDeliveredAt, builder: (column) => ColumnFilters(column));
}

class $$AppNotificationsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppNotificationsTable> {
  $$AppNotificationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get idaccount => $composableBuilder(
      column: $table.idaccount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dedupeKey => $composableBuilder(
      column: $table.dedupeKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get severity => $composableBuilder(
      column: $table.severity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subjectType => $composableBuilder(
      column: $table.subjectType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subjectId => $composableBuilder(
      column: $table.subjectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deeplink => $composableBuilder(
      column: $table.deeplink, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get readAt => $composableBuilder(
      column: $table.readAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dismissedAt => $composableBuilder(
      column: $table.dismissedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get osScheduledId => $composableBuilder(
      column: $table.osScheduledId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get osDeliveredAt => $composableBuilder(
      column: $table.osDeliveredAt,
      builder: (column) => ColumnOrderings(column));
}

class $$AppNotificationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppNotificationsTable> {
  $$AppNotificationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get idaccount =>
      $composableBuilder(column: $table.idaccount, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get dedupeKey =>
      $composableBuilder(column: $table.dedupeKey, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get severity =>
      $composableBuilder(column: $table.severity, builder: (column) => column);

  GeneratedColumn<String> get subjectType => $composableBuilder(
      column: $table.subjectType, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get deeplink =>
      $composableBuilder(column: $table.deeplink, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);

  GeneratedColumn<DateTime> get dismissedAt => $composableBuilder(
      column: $table.dismissedAt, builder: (column) => column);

  GeneratedColumn<int> get osScheduledId => $composableBuilder(
      column: $table.osScheduledId, builder: (column) => column);

  GeneratedColumn<DateTime> get osDeliveredAt => $composableBuilder(
      column: $table.osDeliveredAt, builder: (column) => column);
}

class $$AppNotificationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppNotificationsTable,
    AppNotification,
    $$AppNotificationsTableFilterComposer,
    $$AppNotificationsTableOrderingComposer,
    $$AppNotificationsTableAnnotationComposer,
    $$AppNotificationsTableCreateCompanionBuilder,
    $$AppNotificationsTableUpdateCompanionBuilder,
    (
      AppNotification,
      BaseReferences<_$AppDatabase, $AppNotificationsTable, AppNotification>
    ),
    AppNotification,
    PrefetchHooks Function()> {
  $$AppNotificationsTableTableManager(
      _$AppDatabase db, $AppNotificationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppNotificationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppNotificationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppNotificationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<int> idaccount = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> dedupeKey = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<String> severity = const Value.absent(),
            Value<String?> subjectType = const Value.absent(),
            Value<String?> subjectId = const Value.absent(),
            Value<String?> deeplink = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> readAt = const Value.absent(),
            Value<DateTime?> dismissedAt = const Value.absent(),
            Value<int?> osScheduledId = const Value.absent(),
            Value<DateTime?> osDeliveredAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppNotificationsCompanion(
            id: id,
            idaccount: idaccount,
            kind: kind,
            dedupeKey: dedupeKey,
            title: title,
            body: body,
            severity: severity,
            subjectType: subjectType,
            subjectId: subjectId,
            deeplink: deeplink,
            createdAt: createdAt,
            readAt: readAt,
            dismissedAt: dismissedAt,
            osScheduledId: osScheduledId,
            osDeliveredAt: osDeliveredAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required int idaccount,
            required String kind,
            required String dedupeKey,
            required String title,
            required String body,
            required String severity,
            Value<String?> subjectType = const Value.absent(),
            Value<String?> subjectId = const Value.absent(),
            Value<String?> deeplink = const Value.absent(),
            required DateTime createdAt,
            Value<DateTime?> readAt = const Value.absent(),
            Value<DateTime?> dismissedAt = const Value.absent(),
            Value<int?> osScheduledId = const Value.absent(),
            Value<DateTime?> osDeliveredAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppNotificationsCompanion.insert(
            id: id,
            idaccount: idaccount,
            kind: kind,
            dedupeKey: dedupeKey,
            title: title,
            body: body,
            severity: severity,
            subjectType: subjectType,
            subjectId: subjectId,
            deeplink: deeplink,
            createdAt: createdAt,
            readAt: readAt,
            dismissedAt: dismissedAt,
            osScheduledId: osScheduledId,
            osDeliveredAt: osDeliveredAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppNotificationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppNotificationsTable,
    AppNotification,
    $$AppNotificationsTableFilterComposer,
    $$AppNotificationsTableOrderingComposer,
    $$AppNotificationsTableAnnotationComposer,
    $$AppNotificationsTableCreateCompanionBuilder,
    $$AppNotificationsTableUpdateCompanionBuilder,
    (
      AppNotification,
      BaseReferences<_$AppDatabase, $AppNotificationsTable, AppNotification>
    ),
    AppNotification,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WalletsTableTableManager get wallets =>
      $$WalletsTableTableManager(_db, _db.wallets);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$CategoryKeywordsTableTableManager get categoryKeywords =>
      $$CategoryKeywordsTableTableManager(_db, _db.categoryKeywords);
  $$CategoryGroupMembershipsTableTableManager get categoryGroupMemberships =>
      $$CategoryGroupMembershipsTableTableManager(
          _db, _db.categoryGroupMemberships);
  $$BudgetsTableTableManager get budgets =>
      $$BudgetsTableTableManager(_db, _db.budgets);
  $$BillsTableTableManager get bills =>
      $$BillsTableTableManager(_db, _db.bills);
  $$GoalsTableTableManager get goals =>
      $$GoalsTableTableManager(_db, _db.goals);
  $$AppNotificationsTableTableManager get appNotifications =>
      $$AppNotificationsTableTableManager(_db, _db.appNotifications);
}
