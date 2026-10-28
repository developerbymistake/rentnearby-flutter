enum FactTone { accent, cyan, slate }

class CardFact {
  final String label;
  final FactTone tone;
  const CardFact(this.label, {this.tone = FactTone.accent});
}
