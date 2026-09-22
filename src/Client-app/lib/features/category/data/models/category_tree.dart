import '../../../../core/database/app_database.dart';

class CategoryTree {
  CategoryTree({
    required List<CategoryGroupNode> groups,
    required List<Category> ungroupedChildren,
    required List<Category> defaultChildren,
  })  : groups = List.unmodifiable(groups),
        ungroupedChildren = List.unmodifiable(ungroupedChildren),
        defaultChildren = List.unmodifiable(defaultChildren);

  final List<CategoryGroupNode> groups;
  final List<Category> ungroupedChildren;
  final List<Category> defaultChildren;
}

class CategoryGroupNode {
  CategoryGroupNode({
    required Category group,
    required List<Category> children,
  })  : group = group,
        children = List.unmodifiable(children);

  final Category group;
  final List<Category> children;
}

class CategoryChildDraft {
  CategoryChildDraft({
    this.id,
    required this.accountId,
    required this.name,
    required this.classify,
    required this.parentId,
    required this.icon,
    required this.colour,
    required List<String> keywords,
    this.aiCoDinh = false,
  }) : keywords = List.unmodifiable(keywords);

  final String? id;
  final int accountId;
  final String name;
  final String classify;
  final String? parentId;
  final String icon;
  final String colour;
  final List<String> keywords;

  /// Cờ "Cố định — AI không đề xuất cắt" (cục bộ, schema v24). Mặc định
  /// `false` để mọi chỗ dựng draft cũ giữ nguyên hành vi.
  final bool aiCoDinh;
}

class CategoryGroupDraft {
  CategoryGroupDraft({
    this.id,
    required this.accountId,
    required this.name,
    required this.classify,
    required this.icon,
    required this.colour,
    required List<String> childIds,
  }) : childIds = List.unmodifiable(childIds);

  final String? id;
  final int accountId;
  final String name;
  final String classify;
  final String icon;
  final String colour;
  final List<String> childIds;
}
