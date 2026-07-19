import 'package:dio/dio.dart';
import '../models/inquiry_detail_model.dart';
import '../models/inquiry_model.dart';
import '../services/api_service.dart';

/// Thin wrapper around the consumer-facing agent endpoints (`/agents/me/...`) — deliberately
/// uncached, mirrors InquiryRepository exactly. An Agent is a role on the logged-in account, not a
/// separate identity, so every call here is scoped server-side to the caller's own JWT; nothing in
/// this class ever sends an agent/user id itself.
class AgentRepository {
  /// Returns null if the current account isn't linked to an Agent (backend 404 — the expected case
  /// for ~all users, not an error). Any other failure rethrows for the caller to handle.
  Future<Map<String, dynamic>?> getMyAgentProfile() async {
    try {
      final res = await ApiService.get('/agents/me');
      return res['data'] as Map<String, dynamic>?;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Flat, un-paginated — mirrors InquiryRepository.getMyInquiries()'s reasoning: one agent's own
  /// lead volume is small enough that infinite-scroll pagination isn't worth the added complexity.
  Future<List<InquiryModel>> getMyLeads() async {
    final res = await ApiService.get('/agents/me/leads', params: {'page': 1, 'pageSize': 50});
    final items = (res['data']?['items'] as List?) ?? [];
    return items.map((e) => InquiryModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<InquiryDetailModel?> getLeadDetail(String id) async {
    final res = await ApiService.get('/agents/me/leads/$id');
    final data = res['data'];
    if (data is! Map<String, dynamic>) return null;
    return InquiryDetailModel.fromJson(data);
  }

  Future<InquiryDetailModel?> updateLeadStatus(String id, String status, {String? note}) async {
    final res = await ApiService.put('/agents/me/leads/$id/status', {
      'status': status,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    final data = res['data'];
    if (data is! Map<String, dynamic>) return null;
    return InquiryDetailModel.fromJson(data);
  }
}
