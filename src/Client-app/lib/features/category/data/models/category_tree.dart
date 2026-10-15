import 'category_entity.dart';

class CategoryTree {
  CategoryTree({
    required List<CategoryGroupNode> groups,
    required List<CategoryEntity> ungroupedChildren,
    required List<CategoryEntity> defaultChildren,
  })  : groups = List.unmodifiable(groups),
        ungroupedChildren = List.unmodifiable(ungroupedChildren),
        defaultChildren = List.unmodifiable(defaultChildren);

  final List<CategoryGroupNode> groups;
  final List<CategoryEntity> ungroupedChildren;
  final List<CategoryEntity> defaultChildren;
}

class CategoryGroupNode {
  CategoryGroupNode({
    required CategoryEntity group,
    required List<CategoryEntity> children,
  })  : group = group,
        children = List.unmodifiable(children);

  final CategoryEntity group;
  final List<CategoryEntity> children;
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
