// The server field and doc 6.2 line of the private money note; the app never asks for or tracks a payment.
abstract final class MoneyWire {
  static const receivedKey = 'advanceReceived';
  static const receivedAboveFinalWire = 'advanceAboveFinal';
  static const receivedAboveFinalLine = 'Advance cannot be more than the final amount.';
}
