import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Someone in the family group who can spend from the shared budget.
class FamilyMember {
  const FamilyMember({
    this.id,
    required this.name,
    required this.color,
    this.isOwner = false,
    this.userId,
  });

  /// UUID; null until saved.
  final String? id;
  final String name;
  final Color color;
  final bool isOwner;

  /// Account behind this member once the family is synced; null for people
  /// without an account (e.g. kids).
  final String? userId;

  static const palette = <Color>[
    AppColors.blue,
    AppColors.purple,
    AppColors.green,
    AppColors.orange,
    AppColors.red,
    Color(0xFF00ACC1),
    Color(0xFFD81B60),
  ];

  String get initial =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  FamilyMember copyWith({String? name, Color? color}) => FamilyMember(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
    isOwner: isOwner,
    userId: userId,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'color': color.toARGB32(),
    'is_owner': isOwner ? 1 : 0,
    'user_id': userId,
  };

  factory FamilyMember.fromMap(Map<String, Object?> m) => FamilyMember(
    id: m['id'] as String?,
    name: m['name'] as String,
    color: Color(m['color'] as int),
    isOwner: (m['is_owner'] as int) == 1,
    userId: m['user_id'] as String?,
  );

  factory FamilyMember.fromJson(Map<String, dynamic> j) => FamilyMember(
    id: j['id'] as String,
    name: j['name'] as String,
    color: Color(j['color'] as int),
    isOwner: j['isOwner'] as bool,
    userId: j['userId'] as String?,
  );
}
