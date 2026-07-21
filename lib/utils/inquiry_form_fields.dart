/// Resolves a ServiceCategory's `FormType` string (mirrors
/// RentNearBy.Core.Models.ServiceCategoryFormTypes on the backend) to the label InquiryFormScreen
/// should show for its two variable fields — Preferred Date and Number of People. A `null` label
/// means that field is hidden entirely for this type; every other field (Full Name, Mobile, Email,
/// Message) is unaffected by FormType and stays identical across every category.
class InquiryFormFieldConfig {
  final String? dateLabel;
  final String? peopleLabel;
  const InquiryFormFieldConfig({this.dateLabel, this.peopleLabel});
}

/// The Consultation FormType — the one place its string lives in-app. Also
/// drives Service Detail's "Plan" vs "Package" noun (Consultation categories
/// say "Plan").
const kFormTypeConsultation = 'Consultation';

const _kInquiryFormFieldConfigs = <String, InquiryFormFieldConfig>{
  'Travel': InquiryFormFieldConfig(dateLabel: 'Preferred Travel Date', peopleLabel: 'Number of Travelers'),
  'Event': InquiryFormFieldConfig(dateLabel: 'Event Date', peopleLabel: 'Number of Guests'),
  kFormTypeConsultation: InquiryFormFieldConfig(dateLabel: 'Preferred Consultation Date'),
  'Education': InquiryFormFieldConfig(dateLabel: 'Preferred Start Date', peopleLabel: 'Number of Students'),
};

/// Unrecognized/missing FormType (a stale cached response, or a FormType value added on the backend
/// before this app build knows about it) falls back to Travel's shape — today's existing default —
/// rather than silently hiding both fields or crashing.
InquiryFormFieldConfig inquiryFormFieldConfigFor(String? formType) =>
    _kInquiryFormFieldConfigs[formType] ?? _kInquiryFormFieldConfigs['Travel']!;
