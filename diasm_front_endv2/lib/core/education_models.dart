// lib/core/education_models.dart

/// Represents a single education category returned from
/// GET /education/categories
class EducationCategory {
  final int id;
  final String code;
  final String nameEn;
  final String? nameBn;
  final String displayName;

  EducationCategory({
    required this.id,
    required this.code,
    required this.nameEn,
    this.nameBn,
    required this.displayName,
  });

  factory EducationCategory.fromJson(Map<String, dynamic> json) {
    return EducationCategory(
      id: json['id'] ?? 0,
      code: json['code'] ?? '',
      nameEn: json['nameEn'] ?? '',
      nameBn: json['nameBn'],
      displayName: json['displayName'] ?? (json['nameEn'] ?? ''),
    );
  }

  static List<EducationCategory> listFromJson(List<dynamic> data) {
    return data.map((e) => EducationCategory.fromJson(e)).toList();
  }
}

/// Represents a single education content item (one question/article)
/// returned from /education/contents and /education/contents/:id
class EducationContent {
  final int id;
  final int categoryId;
  final String categoryCode;

  final String title;
  final String body;

  final String titleEn;
  final String bodyEn;
  final String? titleBn;
  final String? bodyBn;

  final String mediaType;
  final String? mediaUrl;

  final DateTime createdAt;

  final String lang;

  EducationContent({
    required this.id,
    required this.categoryId,
    required this.categoryCode,
    required this.title,
    required this.body,
    required this.titleEn,
    required this.bodyEn,
    this.titleBn,
    this.bodyBn,
    required this.mediaType,
    this.mediaUrl,
    required this.createdAt,
    required this.lang,
  });

  factory EducationContent.fromJson(Map<String, dynamic> json) {
    return EducationContent(
      id: json['id'] ?? 0,
      categoryId: json['categoryId'] ?? 0,
      categoryCode: json['categoryCode'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      titleEn: json['titleEn'] ?? '',
      bodyEn: json['bodyEn'] ?? '',
      titleBn: json['titleBn'],
      bodyBn: json['bodyBn'],
      mediaType: json['mediaType'] ?? 'text',
      mediaUrl: json['mediaUrl'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lang: json['lang'] ?? 'en',
    );
  }

  static List<EducationContent> listFromJson(List<dynamic> data) {
    return data.map((e) => EducationContent.fromJson(e)).toList();
  }
}
