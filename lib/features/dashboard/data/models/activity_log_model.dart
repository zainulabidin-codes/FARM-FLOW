import 'dart:convert';
import 'package:flutter/material.dart';

class ActivityLogModel {
  final int? id;
  final int userId;
  final String title;
  final String subtitle;
  final String value;
  final int timeUnix;
  final int iconCode;
  final int isPositive;
  final Map<String, dynamic>? metadata;

  const ActivityLogModel({
    this.id,
    required this.userId,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.timeUnix,
    required this.iconCode,
    required this.isPositive,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'subtitle': subtitle,
      'value': value,
      'time_unix': timeUnix,
      'icon_code': iconCode,
      'is_positive': isPositive,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
    };
  }

  factory ActivityLogModel.fromMap(Map<String, dynamic> map) {
    return ActivityLogModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      title: map['title'] as String,
      subtitle: map['subtitle'] as String,
      value: map['value'] as String,
      timeUnix: map['time_unix'] as int,
      iconCode: map['icon_code'] as int,
      isPositive: map['is_positive'] as int,
      metadata: _parseMetadata(map['metadata']),
    );
  }

  static Map<String, dynamic>? _parseMetadata(dynamic data) {
    if (data == null || data is! String) return null;
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Ignore parse errors, treat as absent
    }
    return null;
  }

  IconData get icon {
    if (iconCode == Icons.pets.codePoint) return Icons.pets;
    if (iconCode == Icons.favorite.codePoint) return Icons.favorite;
    if (iconCode == Icons.update.codePoint) return Icons.update;
    if (iconCode == Icons.child_care.codePoint) return Icons.child_care;
    if (iconCode == Icons.remove_circle_outline.codePoint) return Icons.remove_circle_outline;
    if (iconCode == Icons.person_add_alt_1_rounded.codePoint) return Icons.person_add_alt_1_rounded;
    if (iconCode == Icons.person_remove_alt_1_rounded.codePoint) return Icons.person_remove_alt_1_rounded;
    if (iconCode == Icons.delete_outline_rounded.codePoint) return Icons.delete_outline_rounded;
    if (iconCode == Icons.payments_rounded.codePoint) return Icons.payments_rounded;
    if (iconCode == Icons.money_off_rounded.codePoint) return Icons.money_off_rounded;
    if (iconCode == Icons.water_drop_rounded.codePoint) return Icons.water_drop_rounded;
    return Icons.info_outline;
  }
}
