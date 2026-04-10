import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// チェックリストテンプレートのデータモデル
class ChecklistTemplate {
  final String id;
  final String name;
  final String description;
  final List<String> items;
  final String createdAt;

  ChecklistTemplate({
    required this.id,
    required this.name,
    this.description = '',
    required this.items,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'items': items,
    'createdAt': createdAt,
  };

  factory ChecklistTemplate.fromJson(Map<String, dynamic> json) => ChecklistTemplate(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    items: (json['items'] as List<dynamic>).map((e) => e as String).toList(),
    createdAt: json['createdAt'] as String,
  );
}

/// チェックリストテンプレート管理サービス
///
/// 飛行前チェックリストのテンプレートをSharedPreferencesで永続化する
class ChecklistTemplateService {
  static const _storageKey = 'drone_app_checklist_templates';

  /// デフォルトテンプレートを生成
  static List<ChecklistTemplate> _defaultTemplates() {
    final now = DateTime.now().toIso8601String();
    return [
      ChecklistTemplate(
        id: 'default_normal',
        name: '通常飛行',
        description: '一般的な飛行前チェック項目',
        items: [
          '機体外観に損傷がないか確認',
          'プロペラの取り付け・損傷チェック',
          'バッテリー残量の確認（50%以上）',
          '送信機のバッテリー確認',
          'GPS信号の受信確認',
          'コンパスキャリブレーション',
          '飛行エリアの安全確認',
          '天候・風速の確認',
          '関係者への飛行連絡',
          '緊急時の着陸場所の確認',
        ],
        createdAt: now,
      ),
      ChecklistTemplate(
        id: 'default_night',
        name: '夜間飛行',
        description: '夜間飛行用の追加チェック項目',
        items: [
          '機体外観に損傷がないか確認',
          'プロペラの取り付け・損傷チェック',
          'バッテリー残量の確認（70%以上）',
          '送信機のバッテリー確認',
          'GPS信号の受信確認',
          '機体灯火（位置灯・衝突防止灯）の動作確認',
          '補助照明の準備と動作確認',
          '離着陸場所の照明確認',
          'FPVカメラ/赤外線カメラの動作確認',
          '飛行エリアの障害物確認（昼間中に実施）',
          '関係者への飛行連絡',
          '緊急時の着陸場所の確認',
        ],
        createdAt: now,
      ),
      ChecklistTemplate(
        id: 'default_did',
        name: 'DID飛行',
        description: '人口集中地区での飛行チェック',
        items: [
          '機体外観に損傷がないか確認',
          'プロペラガードの装着',
          'バッテリー残量の確認（70%以上）',
          '送信機のバッテリー確認',
          'GPS信号の受信確認',
          '飛行許可証の携行確認',
          '立入禁止区域の設定確認',
          '補助者の配置確認',
          '第三者への注意喚起（看板等）',
          '緊急時の手順確認',
          '関係者への飛行連絡',
        ],
        createdAt: now,
      ),
    ];
  }

  /// 全テンプレートを取得
  static Future<List<ChecklistTemplate>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null) {
      // 初回: デフォルトテンプレートを保存して返す
      final defaults = _defaultTemplates();
      await _saveAll(defaults);
      return defaults;
    }

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => ChecklistTemplate.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return _defaultTemplates();
    }
  }

  /// テンプレートを保存
  static Future<void> _saveAll(List<ChecklistTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(templates.map((t) => t.toJson()).toList()),
    );
  }

  /// テンプレートを追加
  static Future<void> add(ChecklistTemplate template) async {
    final templates = await getAll();
    templates.add(template);
    await _saveAll(templates);
  }

  /// テンプレートを更新
  static Future<void> update(ChecklistTemplate template) async {
    final templates = await getAll();
    final index = templates.indexWhere((t) => t.id == template.id);
    if (index != -1) {
      templates[index] = template;
      await _saveAll(templates);
    }
  }

  /// テンプレートを削除
  static Future<void> delete(String id) async {
    final templates = await getAll();
    templates.removeWhere((t) => t.id == id);
    await _saveAll(templates);
  }

  /// IDでテンプレートを取得
  static Future<ChecklistTemplate?> getById(String id) async {
    final templates = await getAll();
    try {
      return templates.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}
