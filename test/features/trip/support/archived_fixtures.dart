Map<String, dynamic> archivedSummaryJson() => {
      'version': 1,
      'title': 'Nainital & Mukteshwar',
      'startDate': '2026-05-10',
      'endDate': '2026-05-13',
      'dayCount': 4,
      'spotCount': 9,
      'cities': [
        {
          'name': 'Nainital',
          'nights': 2,
          'spots': ['Naini Lake', 'Snow View Point'],
          'spotCount': 5,
          'stays': ['Lake Inn'],
        },
        {'name': 'Mukteshwar', 'nights': 1, 'spots': ['Chauli ki Jali'], 'spotCount': 1, 'stays': <String>[]},
      ],
      'taxiBooked': true,
      'memberCount': 3,
      'expensesTotal': 12450,
    };

Map<String, dynamic> archivedTripJson({String id = 'arc-1', Object? summary = const _Default(), Object? plan = const <String, dynamic>{}, bool withPlan = true}) => {
      'id': id,
      'title': 'Nainital & Mukteshwar',
      'status': 'Completed',
      'cityKey': 7,
      'cityName': 'Nainital',
      'cityLatitude': 29.4,
      'cityLongitude': 79.4,
      'dayCount': 4,
      'spotCount': 9,
      'startDate': '2026-05-10',
      'endDate': '2026-05-13',
      'createdAt': '2026-04-01T00:00:00Z',
      'updatedAt': '2026-08-20T00:00:00Z',
      'completedAt': '2026-05-14T00:00:00Z',
      'legCount': 2,
      'legCities': ['Nainital', 'Mukteshwar'],
      'archived': true,
      'archivedAt': '2026-08-20T00:00:00Z',
      'summary': summary is _Default ? archivedSummaryJson() : summary,
      if (withPlan) 'plan': plan,
      'enquiries': <Object>[],
      'journeys': <Object>[],
      'isPublic': false,
    };

Map<String, dynamic> archivedListItemJson({String id = 'arc-1'}) => {
      'id': id,
      'title': 'Nainital & Mukteshwar',
      'status': 'Completed',
      'cityName': 'Nainital',
      'dayCount': 4,
      'spotCount': 9,
      'startDate': '2026-05-10',
      'endDate': '2026-05-13',
      'updatedAt': '2026-08-20T00:00:00Z',
      'completedAt': '2026-05-14T00:00:00Z',
      'legCount': 2,
      'legCities': ['Nainital', 'Mukteshwar'],
      'archived': true,
      'archivedAt': '2026-08-20T00:00:00Z',
    };

class _Default {
  const _Default();
}
