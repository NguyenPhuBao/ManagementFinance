import '../../../../core/database/app_database.dart';

class CategoryTree {
  const CategoryTree({
    required this.groups,
    required this.ungroupedChildren,
    required this.defaultChildren,
  });

  final List<CategoryGroupNode> groups;
  final List<Category> ungroupedChildren;
  final List<Category> defaultChildren;
}

class CategoryGroupNode {
  const CategoryGroupNode({required this.group, required this.children});

  final Category group;
  final List<Category> children;
}

class CategoryChildDraft {
  const CategoryChildDraft({
    this.id,
    required this.accountId,
    required this.name,
    required this.classify,
    required this.parentId,
    required this.icon,
    required this.colour,
    required this.keywords,
  });

  final String? id;
  final int accountId;
  final String name;
  final String classify;
  final String? parentId;
  final String icon;
  final String colour;
  final List<String> keywords;
}

class CategoryGroupDraft {
  const CategoryGroupDraft({
    this.id,
    required this.accountId,
    required this.name,
    required this.classify,
    required this.icon,
    required this.colour,
    required this.childIds,
  });

  final String? id;
  final int accountId;
  final String name;
  final String classify;
  final String icon;
  final String colour;
  final List<String> childIds;
}
