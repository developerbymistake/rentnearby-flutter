import '../../../utils/money_format.dart';

abstract final class TaxiSetupStrings {
  static const step1Title = 'Vehicle and contact';
  static const step1Vehicle = 'Step 1 of 3 · Vehicle';
  static const step1Licence = 'Step 1 of 3 · Licence';
  static const step1Contact = 'Step 1 of 3 · Contact and base';
  static const progressLabels = ['Vehicle', 'Licence', 'Contact'];
  static const vehicleType = 'Vehicle type';
  static const plateNumber = 'Plate number';
  static const vehiclePhoto = 'Vehicle photo';
  static const plateMustShow = 'Plate must be visible';
  static const licenceNumber = 'Driving licence number';
  static const adminOnly = 'Only Bakhli admin sees this.';
  static const dateOfBirth = 'Date of birth';
  static const keptForChecks = 'Kept for checks only. Removed 180 days after you leave.';
  static const pinNear = 'Pin within 500 m of where you are now.';
  static const next = 'Next';
  static const save = 'Save';

  static const routesTitle = 'Routes and fares';
  static const routesStep = 'Step 2 of 3';
  static const routes = 'Routes';
  static String meterChip(int used, int limit, {required bool free}) => free ? '$used of $limit on Free' : '$used of $limit';
  static String savedLine(int used, int limit, {required bool free}) =>
      '$used of $limit ${limit == 1 ? 'route' : 'routes'} saved${free ? ' on Free' : ''}';
  static String footerMeter(int used, int limit, {required bool free}) => 'Routes: ${meterChip(used, limit, free: free)}';
  static String routeTitle(String from, String to) => '$from to $to';
  static String routeLine(int number, String trip, int fare) => 'Route $number · $trip · ${Money.exact(fare)}';
  static String routeNumber(int number) => 'Route $number';
  static const newRoute = 'New route';
  static const editRoute = 'Edit route';
  static const saveRoute = 'Save route';
  static const seePlus = 'See Plus';
  static const plus = 'Plus';

  static const submitTitle = 'Final Submit';
  static const submitStep = 'Step 3 of 3';
  static const checkYourTaxi = 'Check your taxi';
  static const afterApproval = 'Travellers see this after approval.';
  static const vehicle = 'Vehicle';
  static const seats = 'Seats';
  static const plate = 'Plate';
  static const phone = 'Phone';
  static const base = 'Base';
  static String phoneDisplay(String raw) {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    final ten = d.length == 12 && d.startsWith('91') ? d.substring(2) : d;
    return ten.length == 10 ? '+91 ${ten.substring(0, 5)} ${ten.substring(5)}' : raw;
  }
  static const localDayRate = 'Local day rate';
  static String dayRate(int rate, int? km) => km == null ? Money.exact(rate) : '${Money.exact(rate)} · $km km';
  static const submitForReview = 'Submit for review';
  static const submitting = 'Submitting...';
  static const submittedToast = 'Submitted for review';
  static const addLicence = 'Add licence and date of birth';
  static const edit = 'Edit';
  static const missing = '–';
}
