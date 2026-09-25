import 'package:flutter/material.dart';
import '../state/store_state.dart';

class SecureCheckoutDialog extends StatefulWidget {
  final StoreState state;
  const SecureCheckoutDialog({super.key, required this.state});
  @override
  State<SecureCheckoutDialog> createState() => _SecureCheckoutDialogState();
}

class _SecureCheckoutDialogState extends State<SecureCheckoutDialog> {
  final form = GlobalKey<FormState>();
  final first = TextEditingController(),
      last = TextEditingController(),
      phone = TextEditingController(),
      email = TextEditingController(),
      country = TextEditingController(text: 'Kosovë'),
      city = TextEditingController(),
      address = TextEditingController(),
      street = TextEditingController(),
      apartment = TextEditingController();
  bool busy = false;
  String? error;
  String? requiredText(String? v) => v == null || v.trim().length < 2
      ? 'Kjo fushë është e detyrueshme.'
      : null;
  @override
  Widget build(BuildContext c) => AlertDialog(
          title: const Text('Vazhdo me porosinë'),
          content: SizedBox(
              width: 520,
              child: Form(
                  key: form,
                  child: SingleChildScrollView(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Të dhënat personale',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                        Row(children: [
                          Expanded(
                              child: TextFormField(
                                  controller: first,
                                  validator: requiredText,
                                  decoration: const InputDecoration(
                                      labelText: 'Emri *'))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: TextFormField(
                                  controller: last,
                                  validator: requiredText,
                                  decoration: const InputDecoration(
                                      labelText: 'Mbiemri *')))
                        ]),
                        TextFormField(
                            controller: phone,
                            keyboardType: TextInputType.phone,
                            validator: (v) =>
                                RegExp(r'^\+?[0-9][0-9 ()-]{6,19}$')
                                        .hasMatch(v ?? '')
                                    ? null
                                    : 'Numri i telefonit nuk është valid.',
                            decoration: const InputDecoration(
                                labelText: 'Numri i telefonit *')),
                        TextFormField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => (v ?? '').isEmpty ||
                                    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                        .hasMatch(v!)
                                ? null
                                : 'Email-i nuk është valid.',
                            decoration: const InputDecoration(
                                labelText: 'Email (opsional)')),
                        const SizedBox(height: 20),
                        const Text('Adresa e dërgesës',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                        TextFormField(
                            controller: country,
                            validator: requiredText,
                            decoration:
                                const InputDecoration(labelText: 'Shteti *')),
                        TextFormField(
                            controller: city,
                            validator: requiredText,
                            decoration:
                                const InputDecoration(labelText: 'Qyteti *')),
                        TextFormField(
                            controller: address,
                            validator: (v) => v == null || v.trim().length < 3
                                ? 'Adresa është e detyrueshme.'
                                : null,
                            decoration:
                                const InputDecoration(labelText: 'Adresa *')),
                        TextFormField(
                            controller: street,
                            decoration:
                                const InputDecoration(labelText: 'Rruga')),
                        TextFormField(
                            controller: apartment,
                            decoration: const InputDecoration(
                                labelText: 'Apartamenti / Nr. i banesës')),
                        const SizedBox(height: 20),
                        Container(
                            padding: const EdgeInsets.all(14),
                            color: const Color(0xfffff7ed),
                            child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Pagesa aktualisht bëhet vetëm me Cash.',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  SizedBox(height: 5),
                                  Text(
                                      'Pagesa me kartë bankare, Stripe dhe PayPal do të jetë e disponueshme së shpejti.')
                                ])),
                        if (error != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(error!,
                                  style: const TextStyle(color: Colors.red)))
                      ])))),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(c),
                child: const Text('Anulo')),
            FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!(form.currentState?.validate() ?? false)) return;
                        setState(() => busy = true);
                        try {
                          final key =
                              '${DateTime.now().microsecondsSinceEpoch}-${widget.state.cartCount}';
                          final result = await widget.state.service
                              .checkoutSecure(
                                  firstName: first.text.trim(),
                                  lastName: last.text.trim(),
                                  phone: phone.text.trim(),
                                  email: email.text.trim(),
                                  country: country.text.trim(),
                                  city: city.text.trim(),
                                  address: address.text.trim(),
                                  street: street.text.trim(),
                                  apartment: apartment.text.trim(),
                                  cart: widget.state.cart,
                                  idempotencyKey: key);
                          widget.state.clearCart();
                          if (c.mounted) Navigator.pop(c, result);
                        } catch (_) {
                          setState(() {
                            busy = false;
                            error =
                                'Diçka nuk shkoi siç duhet. Ju lutemi provoni përsëri.';
                          });
                        }
                      },
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Bëj porosinë'))
          ]);
}

class OrderConfirmationPage extends StatelessWidget {
  final Map<String, dynamic> order;
  const OrderConfirmationPage({super.key, required this.order});
  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 74),
                        const SizedBox(height: 20),
                        const Text('Faleminderit për porosinë tuaj!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 30, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        const Text(
                            'Porosia juaj është pranuar me sukses.\nPorosia pritet të arrijë brenda 72 orëve.',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(children: [
                                  const Text('Numri i porosisë'),
                                  SelectableText(
                                      '${order['order_number'] ?? ''}',
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800)),
                                  const Divider(height: 28),
                                  Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Totali'),
                                        Text('€${order['total'] ?? 0}',
                                            style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800))
                                      ]),
                                  const SizedBox(height: 8),
                                  const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [Text('Pagesa'), Text('Cash')])
                                ]))),
                        const SizedBox(height: 24),
                        FilledButton(
                            onPressed: () =>
                                Navigator.popUntil(c, (r) => r.isFirst),
                            child: const Text('Kthehu në dyqan'))
                      ])))));
}
