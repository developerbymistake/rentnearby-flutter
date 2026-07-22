/// Pure string helpers for displaying a category's admin-set agent role label
/// (e.g. "Travel Expert", "Instructor") — the label itself always comes from
/// the backend (InquiryModel/InquiryDetailModel.agentRoleLabel), never derived
/// client-side.
abstract final class RoleLabelFormat {
  static String plural(String label) => '${label}s';

  static String withIndefiniteArticle(String label) =>
      label.isNotEmpty && 'AEIOU'.contains(label[0].toUpperCase()) ? 'An $label' : 'A $label';
}
