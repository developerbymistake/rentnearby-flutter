import '../data/quote_models.dart' show QuoteUsage;

class QuoteBankLines {
  const QuoteBankLines({this.holder = '', this.accountNo = '', this.ifsc = '', this.bank = '', this.branch = '', this.upi = ''});

  final String holder;
  final String accountNo;
  final String ifsc;
  final String bank;
  final String branch;
  final String upi;

  bool get isEmpty => holder.isEmpty && accountNo.isEmpty && ifsc.isEmpty && bank.isEmpty && branch.isEmpty && upi.isEmpty;
}

// What the documents and the download need from Business details and the hub, read at one place (QuoteSource).
class QuoteBusiness {
  const QuoteBusiness({
    required this.name,
    this.approved = true,
    this.slogan = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.gstin = '',
    this.preparedBy = '',
    this.termsText = '',
    this.cancellationText = '',
    this.hasLogo = false,
    this.hasSignature = false,
    this.assetsVersion = 0,
    this.bank = const QuoteBankLines(),
    this.nextQuotation = 1,
    this.nextProforma = 1,
    this.previewWatermark = true,
    this.minTemplateVersion = 1,
    this.usage,
  });

  final String name;
  final bool approved;
  final String slogan;
  final String address;
  final String phone;
  final String email;
  final String gstin;
  final String preparedBy;
  final String termsText;
  final String cancellationText;
  final bool hasLogo;
  final bool hasSignature;
  final int assetsVersion;
  final QuoteBankLines bank;
  final int nextQuotation;
  final int nextProforma;
  final bool previewWatermark;
  final int minTemplateVersion;
  final QuoteUsage? usage;

  bool get hasGstin => gstin.trim().isNotEmpty;

  QuoteBusiness copyWith({bool? hasLogo, bool? hasSignature, int? assetsVersion, QuoteBankLines? bank}) => QuoteBusiness(
        name: name,
        approved: approved,
        slogan: slogan,
        address: address,
        phone: phone,
        email: email,
        gstin: gstin,
        preparedBy: preparedBy,
        termsText: termsText,
        cancellationText: cancellationText,
        hasLogo: hasLogo ?? this.hasLogo,
        hasSignature: hasSignature ?? this.hasSignature,
        assetsVersion: assetsVersion ?? this.assetsVersion,
        bank: bank ?? this.bank,
        nextQuotation: nextQuotation,
        nextProforma: nextProforma,
        previewWatermark: previewWatermark,
        minTemplateVersion: minTemplateVersion,
        usage: usage,
      );
}
