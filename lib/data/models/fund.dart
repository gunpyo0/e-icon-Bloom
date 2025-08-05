import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

/// ───── 회사 정보 ─────
class CompanyInfo {
  final String id;
  final String name;
  final String? description;
  final String? website;
  final String? logoPath;

  const CompanyInfo({
    required this.id,
    required this.name,
    this.description,
    this.website,
    this.logoPath,
  });

  factory CompanyInfo.fromJson(Map<String, dynamic> json) => CompanyInfo(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'],
    website: json['website'],
    logoPath: json['logoPath'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'website': website,
    'logoPath': logoPath,
  };
}

/// ───── 캠페인 전체 ─────
class FundCampaign {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String bannerPath;
  final int goalAmount;
  final int collectedAmount;
  final DateTime? createdAt;
  final DateTime endDate;
  final String createdBy;
  final CompanyInfo company;

  FundCampaign({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.bannerPath,
    required this.goalAmount,
    required this.collectedAmount,
    required this.createdAt,
    required this.endDate,
    required this.createdBy,
    required this.company,
  });

  factory FundCampaign.fromJson(Map<String, dynamic> json) {
    DateTime? _toDate(dynamic v) {
      debugPrint("${v}, , ${v.runtimeType}");
      // Cloud Functions serializes Firestore Timestamp as a map:
      //    { _seconds: <int>, _nanoseconds: <int> }
      if (v.containsKey('_seconds')
          && v.containsKey('_nanoseconds')) {
        final seconds = v['_seconds']   as int;
        final nanos   = v['_nanoseconds'] as int;
        return DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000 + (nanos ~/ 1000000),
        );
      }

      // Web / mobile SDK Timestamp (only when directly reading Firestore)
      if (v is Timestamp) {
        return v.toDate();
      }

      // ISO-8601 string from your own toJson()
      if (v is String) {
        return DateTime.tryParse(v);
      }

      return null;
    }

    // company 필드를 안전하게 Map<String,dynamic> 으로 변환
    final rawCompany = json['company'];
    final companyMap = (rawCompany is Map)
        ? Map<String, dynamic>.from(
        rawCompany.map((k, v) => MapEntry(k.toString(), v)))
        : <String, dynamic>{};

    return FundCampaign(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      description: json['description'] ?? '',
      bannerPath: json['bannerPath'] ?? '',
      goalAmount: (json['goalAmount'] ?? 0) is num
          ? (json['goalAmount'] as num).toInt()
          : int.tryParse(json['goalAmount'].toString()) ?? 0,
      collectedAmount: (json['collectedAmount'] ?? 0) is num
          ? (json['collectedAmount'] as num).toInt()
          : int.tryParse(json['collectedAmount'].toString()) ?? 0,
      createdAt: _toDate(json['createdAt']),
      endDate: _toDate(json['endDate']) ?? DateTime.now(),
      createdBy: json['createdBy'] ?? '',
      company: CompanyInfo.fromJson(companyMap),
    );
  }
}

/// ───── 캠페인 생성 요청 ─────
class CreateCampaignParams {
  final String title;
  final String subtitle;
  final String description;
  final int goalAmount;
  final DateTime endDate;
  final String extension; // jpg, png …
  final CompanyInfo company;

  CreateCampaignParams({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.goalAmount,
    required this.endDate,
    this.extension = 'jpg',
    required this.company,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'subtitle': subtitle,
    'description': description,
    'goalAmount': goalAmount,
    'endDate': endDate.toIso8601String(),
    'extension': extension,
    'company': company.toJson(),
  };
}

/// ───── 캠페인 생성 결과 ─────
class CreateCampaignResult {
  final String campaignId;
  final String storagePath;
  final String uploadPath;

  CreateCampaignResult({
    required this.campaignId,
    required this.storagePath,
    required this.uploadPath,
  });

  factory CreateCampaignResult.fromJson(Map<String, dynamic> json) =>
      CreateCampaignResult(
        campaignId: json['campaignId'] ?? '',
        storagePath: json['storagePath'] ?? '',
        uploadPath: json['uploadPath'] ?? '',
      );
}
