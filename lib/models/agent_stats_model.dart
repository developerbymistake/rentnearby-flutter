/// Month-wise lead stats for one agent/year — mirrors
/// RentNearBy.Core.DTOs.Responses.AgentLeadStatsDto exactly. Powers the Agent Dashboard screen;
/// the admin app's Agent Stats page consumes the same shape from a different endpoint
/// (GET /agents/{id}/stats vs GET /agents/me/stats).
class AgentLeadStatsModel {
  final String agentId;
  final String agentName;
  final int year;
  final int totalLeads;
  final int totalSubmitted;
  final int totalContacted;
  final int totalClosed;
  // Always 12 entries, index 0 = January .. index 11 = December.
  final List<MonthlyLeadStatModel> months;

  AgentLeadStatsModel({
    required this.agentId,
    required this.agentName,
    required this.year,
    required this.totalLeads,
    required this.totalSubmitted,
    required this.totalContacted,
    required this.totalClosed,
    required this.months,
  });

  factory AgentLeadStatsModel.fromJson(Map<String, dynamic> json) => AgentLeadStatsModel(
        agentId: json['agentId'] as String? ?? '',
        agentName: json['agentName'] as String? ?? '',
        year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
        totalLeads: (json['totalLeads'] as num?)?.toInt() ?? 0,
        totalSubmitted: (json['totalSubmitted'] as num?)?.toInt() ?? 0,
        totalContacted: (json['totalContacted'] as num?)?.toInt() ?? 0,
        totalClosed: (json['totalClosed'] as num?)?.toInt() ?? 0,
        months: ((json['months'] as List?) ?? [])
            .map((e) => MonthlyLeadStatModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// The current calendar month's bucket, or an all-zero fallback if [months] is somehow short
  /// (e.g. a year with no data at all still zero-fills server-side, but this guards regardless).
  MonthlyLeadStatModel get currentMonth {
    final idx = DateTime.now().month - 1;
    if (idx >= 0 && idx < months.length) return months[idx];
    return MonthlyLeadStatModel(month: DateTime.now().month, submitted: 0, contacted: 0, closed: 0, total: 0);
  }
}

class MonthlyLeadStatModel {
  final int month; // 1-12
  final int submitted;
  final int contacted;
  final int closed;
  final int total;

  MonthlyLeadStatModel({
    required this.month,
    required this.submitted,
    required this.contacted,
    required this.closed,
    required this.total,
  });

  factory MonthlyLeadStatModel.fromJson(Map<String, dynamic> json) => MonthlyLeadStatModel(
        month: (json['month'] as num?)?.toInt() ?? 1,
        submitted: (json['submitted'] as num?)?.toInt() ?? 0,
        contacted: (json['contacted'] as num?)?.toInt() ?? 0,
        closed: (json['closed'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
      );
}
