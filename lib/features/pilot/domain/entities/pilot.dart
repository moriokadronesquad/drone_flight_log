/// パイロットエンティティ
/// 不変なデータクラスとして実装
class Pilot {
  final int id;
  final String name; // 名前
  final String? licenseNumber; // 免許証番号
  final String? licenseType; // 免許の種類（一等、二等、なし）
  final String? licenseExpiry; // 免許有効期限
  final String? organization; // 所属組織
  final String? contact; // 連絡先
  // Phase 4.5: 技能証明書フィールド
  final String? certificateNumber; // 技能証明書番号
  final String? certificateIssueDate; // 技能証明書交付日
  final String? certificateRegistrationDate; // 技能証明書登録日
  final bool autoRegister; // 新規作成時に自動登録
  final DateTime createdAt; // 作成日時
  final DateTime updatedAt; // 更新日時

  /// コンストラクタ
  const Pilot({
    required this.id,
    required this.name,
    this.licenseNumber,
    this.licenseType,
    this.licenseExpiry,
    this.organization,
    this.contact,
    this.certificateNumber,
    this.certificateIssueDate,
    this.certificateRegistrationDate,
    this.autoRegister = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// copyWithメソッド（イミュータブル更新用）
  Pilot copyWith({
    int? id,
    String? name,
    String? licenseNumber,
    String? licenseType,
    String? licenseExpiry,
    String? organization,
    String? contact,
    String? certificateNumber,
    String? certificateIssueDate,
    String? certificateRegistrationDate,
    bool? autoRegister,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Pilot(
      id: id ?? this.id,
      name: name ?? this.name,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseType: licenseType ?? this.licenseType,
      licenseExpiry: licenseExpiry ?? this.licenseExpiry,
      organization: organization ?? this.organization,
      contact: contact ?? this.contact,
      certificateNumber: certificateNumber ?? this.certificateNumber,
      certificateIssueDate: certificateIssueDate ?? this.certificateIssueDate,
      certificateRegistrationDate: certificateRegistrationDate ?? this.certificateRegistrationDate,
      autoRegister: autoRegister ?? this.autoRegister,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pilot &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          licenseNumber == other.licenseNumber &&
          licenseType == other.licenseType &&
          licenseExpiry == other.licenseExpiry &&
          organization == other.organization &&
          contact == other.contact &&
          certificateNumber == other.certificateNumber &&
          certificateIssueDate == other.certificateIssueDate &&
          certificateRegistrationDate == other.certificateRegistrationDate &&
          autoRegister == other.autoRegister &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      licenseNumber.hashCode ^
      licenseType.hashCode ^
      licenseExpiry.hashCode ^
      organization.hashCode ^
      contact.hashCode ^
      certificateNumber.hashCode ^
      certificateIssueDate.hashCode ^
      certificateRegistrationDate.hashCode ^
      autoRegister.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() {
    return 'Pilot(id: $id, name: $name, licenseNumber: $licenseNumber, '
        'licenseType: $licenseType, licenseExpiry: $licenseExpiry, '
        'organization: $organization, contact: $contact, '
        'certificateNumber: $certificateNumber, '
        'createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
