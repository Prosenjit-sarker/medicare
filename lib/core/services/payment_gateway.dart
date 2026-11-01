/// Payment abstraction. Free tier = manual mobile-banking verification (bKash/Nagad/Rocket):
/// the patient submits the transaction id, an admin with the finance role verifies it.
/// A real gateway (SSLCommerz / aamarPay) must create the session and verify the IPN on a
/// server you control, so it is intentionally NOT implemented in the client.
abstract class PaymentGateway {
  const PaymentGateway();
  List<String> get methods;
  bool requiresTransactionId(String method);
}

class ManualMfsGateway extends PaymentGateway {
  const ManualMfsGateway();
  @override
  List<String> get methods => const ['bKash', 'Nagad', 'Rocket', 'Cash at visit'];
  @override
  bool requiresTransactionId(String method) => method != 'Cash at visit';
}
