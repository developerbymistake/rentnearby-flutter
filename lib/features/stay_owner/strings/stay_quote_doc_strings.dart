// Words printed on the quotation and proforma documents. Never the app brand name here.
abstract final class StayQuoteDocStrings {
  static const quotation = 'Quotation';
  static const proforma = 'Proforma invoice';
  static const quotationNo = 'Quotation no';
  static const invoiceNo = 'Invoice no';
  static const quotationRef = 'Quotation ref';
  static const date = 'Date';
  static const validTill = 'Valid till';
  static const notTaxInvoice = 'This is not a tax invoice.';

  static const to = 'To';
  static const preparedFor = 'Prepared for';
  static const guest = 'Guest';
  static const phone = 'Phone';
  static const bookedBy = 'Booked by';
  static const stay = 'Stay';
  static const stayDetails = 'Stay details';
  static const checkIn = 'Check-in';
  static const checkOut = 'Check-out';
  static const nightsLabel = 'Nights';
  static const guests = 'Guests';
  static const mealPlan = 'Meal plan';

  static const srNo = 'Sr. No';
  static const no = '#';
  static const description = 'Description';
  static const rate = 'Rate';
  static const rateInr = 'Rate (₹)';
  static const paxQty = 'Pax / Qty';
  static const qty = 'Qty';
  static const amount = 'Amount';
  static const totalInr = 'Total (₹)';
  static const amountInr = 'Amount (₹)';

  static const subtotal = 'Subtotal';
  static const lessDiscount = 'Less discount';
  static const taxable = 'Taxable value';
  static const roundOff = 'Round off';
  static const totalAmount = 'Total amount';
  static const total = 'Total';
  static const amountInWords = 'Amount in words';

  static const paymentsReceived = 'Payments received';
  static const totalReceived = 'Total received';
  static const balanceBill = 'Balance bill amount';
  static const balanceInWords = 'Balance in words';
  static const balance = 'Balance';

  static const terms = 'Terms';
  static const cancellation = 'Cancellation policy';
  static const cancellationShort = 'Cancellation';
  static const bankUpi = 'Bank and UPI';
  static const payTo = 'Pay to';
  static const acName = 'A/c name';
  static const acNo = 'A/c no';
  static const account = 'Account';
  static const ifsc = 'IFSC';
  static const upi = 'UPI';
  static const gstin = 'GSTIN';
  static const note = 'Note';

  static const preparedBy = 'Prepared by';
  static const authorisedSignatory = 'Authorised signatory';
  static const continued = 'Continued from page 1';
  static const pagePattern = 'Page {x} of {y}';

  static String forBusiness(String name) => 'For $name';
  static String thankYou(String name) => 'Thank you for choosing $name';
  static String preparedByLine(String name) => 'Prepared by $name.';
  static String gstAt(String percent) => 'GST @ $percent%';
  static String nights(int n) => n == 1 ? '1 night' : '$n nights';
  static String adults(int n) => n == 1 ? '1 adult' : '$n adults';
  static String kids(int n) => n == 1 ? '1 kid' : '$n kids';
  static String rooms(int n) => n == 1 ? '1 room' : '$n rooms';

  static const mealEp = 'EP · Room only';
  static const mealCp = 'CP · Breakfast';
  static const mealMap = 'MAP · Breakfast and one meal';
  static const mealAp = 'AP · Breakfast, lunch and dinner';

  static const rupeesZero = 'Rupees Zero Only';
  static const rupees = 'Rupees';
  static const only = 'Only';
  static const crore = 'Crore';
  static const lakh = 'Lakh';
  static const thousand = 'Thousand';
  static const hundred = 'Hundred';
  static const ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen',
    'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen',
  ];
  static const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

  static const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String day(DateTime d) => '${d.day} ${months[d.month - 1]} ${d.year}';
  static String weekdayDay(DateTime d) => '${weekdays[d.weekday - 1]}, ${day(d)}';

  static Map<String, String> labels() => const {
        'quotationNo': quotationNo,
        'invoiceNo': invoiceNo,
        'quotationRef': quotationRef,
        'date': date,
        'validTill': validTill,
        'to': to,
        'preparedFor': preparedFor,
        'guest': guest,
        'phone': phone,
        'bookedBy': bookedBy,
        'stay': stay,
        'stayDetails': stayDetails,
        'checkIn': checkIn,
        'checkOut': checkOut,
        'nights': nightsLabel,
        'guests': guests,
        'mealPlan': mealPlan,
        'srNo': srNo,
        'no': no,
        'description': description,
        'rate': rate,
        'rateInr': rateInr,
        'paxQty': paxQty,
        'qty': qty,
        'amount': amount,
        'totalInr': totalInr,
        'amountInr': amountInr,
        'subtotal': subtotal,
        'lessDiscount': lessDiscount,
        'taxable': taxable,
        'roundOff': roundOff,
        'totalAmount': totalAmount,
        'total': total,
        'amountInWords': amountInWords,
        'paymentsReceived': paymentsReceived,
        'totalReceived': totalReceived,
        'balanceBill': balanceBill,
        'balanceInWords': balanceInWords,
        'balance': balance,
        'terms': terms,
        'cancellation': cancellation,
        'cancellationShort': cancellationShort,
        'bankUpi': bankUpi,
        'payTo': payTo,
        'acName': acName,
        'acNo': acNo,
        'account': account,
        'ifsc': ifsc,
        'upi': upi,
        'gstin': gstin,
        'note': note,
        'preparedBy': preparedBy,
        'authorisedSignatory': authorisedSignatory,
        'continued': continued,
      };
}
