import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/catalog_models.dart';
import '../state/store_state.dart';

class PremiumHomePage extends StatefulWidget {
  final StoreState state;
  final ValueChanged<Product> onProduct;
  const PremiumHomePage(
      {super.key, required this.state, required this.onProduct});
  @override
  State<PremiumHomePage> createState() => _PremiumHomePageState();
}

class _PremiumHomePageState extends State<PremiumHomePage> {
  List<Map<String, dynamic>> slides = [], sponsors = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = Supabase.instance.client;
      final r = await Future.wait([
        c.from('hero_slides').select().order('sort_order'),
        c.from('sponsors').select().order('sort_order')
      ]);
      slides = (r[0] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      sponsors =
          (r[1] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) {
    final s = widget.state;
    final fresh = [...s.products.where((p) => p.isNew)]..sort((a, b) =>
        (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000)));
    final featured = s.products.where((p) => p.isFeatured).toList();
    final offers = s.products.where((p) => p.discountActive).toList();
    return ListView(children: [
      _hero(),
      const SizedBox(height: 34),
      _title('Kategoritë', 'Shfletoni sipas kategorisë'),
      SizedBox(
          height: 120,
          child: ListView(
              scrollDirection: Axis.horizontal,
              children: s.categories
                  .where((x) => x.showOnHomepage && x.isActive)
                  .map((x) => Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: ActionChip(
                          onPressed: () => s.setCategory(x.id),
                          avatar: const Icon(Icons.category_outlined),
                          label: Text(x.name),
                          padding: const EdgeInsets.all(16))))
                  .toList())),
      _products('Produktet e Reja',
          fresh.isEmpty ? s.products.take(8).toList() : fresh.take(8).toList()),
      _products('Produktet e Zgjedhura', featured.take(8).toList()),
      _products('Ofertat', offers.take(8).toList()),
      _trust(),
      if (sponsors.isNotEmpty) ...[
        const SizedBox(height: 36),
        _title('Partnerët & Sponsorët', 'Partnerët që na besojnë'),
        SizedBox(
            height: 100,
            child: ListView(
                scrollDirection: Axis.horizontal,
                children: sponsors
                    .map((x) => InkWell(
                        onTap: () => _sponsor(c, x),
                        child: Container(
                            width: 160,
                            margin: const EdgeInsets.only(right: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.black12)),
                            child: Image.network(x['logo_url'] ?? '',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Center(
                                    child: Text(x['company_name'] ?? ''))))))
                    .toList()))
      ],
      _footer()
    ]);
  }

  Widget _hero() {
    if (loading)
      return const SizedBox(
          height: 300, child: Center(child: CircularProgressIndicator()));
    if (slides.isEmpty)
      return Container(
          height: 300,
          padding: const EdgeInsets.all(36),
          color: const Color(0xff1d2635),
          child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Dyqani Online',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 12),
                Text('Produkte të zgjedhura. Dërgesë e shpejtë. Pagesë Cash.',
                    style: TextStyle(color: Colors.white70, fontSize: 18))
              ]));
    return SizedBox(
        height: 360,
        child: PageView(
            children: slides
                .map((x) => Stack(fit: StackFit.expand, children: [
                      if ((x['media_type'] ?? 'image') == 'image')
                        Image.network(x['media_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: const Color(0xff1d2635)))
                      else
                        Container(
                            color: const Color(0xff1d2635),
                            child: const Center(
                                child: Icon(Icons.play_circle_outline,
                                    color: Colors.white, size: 64))),
                      Container(color: Colors.black38),
                      Padding(
                          padding: const EdgeInsets.all(34),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(x['title'] ?? '',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 40,
                                        fontWeight: FontWeight.w800)),
                                Text(x['subtitle'] ?? '',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 20)),
                                const SizedBox(height: 16),
                                if ((x['button_text'] ?? '').isNotEmpty)
                                  FilledButton(
                                      onPressed: () {},
                                      child: Text(x['button_text']))
                              ]))
                    ]))
                .toList()));
  }

  Widget _title(String a, String b) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(a,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        Text(b, style: const TextStyle(color: Colors.black54))
      ]));
  Widget _products(String title, List<Product> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.only(top: 34),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title(title, 'Zgjedhje të përditësuara nga dyqani'),
          SizedBox(
              height: 310,
              child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: list
                      .map((p) => InkWell(
                          onTap: () => widget.onProduct(p),
                          child: Container(
                              width: 230,
                              margin: const EdgeInsets.only(right: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.black12)),
                              child: Column(children: [
                                Expanded(
                                    child: p.primaryImageUrl.startsWith('http')
                                        ? Image.network(p.primaryImageUrl,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                    Icons.image_outlined))
                                        : Image.asset(p.primaryImageUrl)),
                                Text(p.nameSq,
                                    maxLines: 2,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                if (p.discountActive)
                                  Text('€${p.price.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          decoration:
                                              TextDecoration.lineThrough,
                                          color: Colors.black45)),
                                Text('€${p.finalPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800)),
                                Text(p.inStock ? 'Në stok' : 'Nuk ka stok',
                                    style: TextStyle(
                                        color: p.inStock
                                            ? Colors.green
                                            : Colors.red))
                              ]))))
                      .toList()))
        ]));
  }

  Widget _trust() => Container(
      margin: const EdgeInsets.only(top: 42),
      padding: const EdgeInsets.all(24),
      color: const Color(0xfff1f2f3),
      child: const Wrap(
          alignment: WrapAlignment.spaceAround,
          spacing: 28,
          runSpacing: 20,
          children: [
            _Trust(Icons.local_shipping_outlined, 'Dërgesë e shpejtë'),
            _Trust(Icons.payments_outlined, 'Pagesë Cash'),
            _Trust(Icons.verified_outlined, 'Produkte të verifikuara'),
            _Trust(Icons.support_agent, 'Mbështetje për klientët')
          ]));
  Widget _footer() => Container(
      margin: const EdgeInsets.only(top: 44),
      padding: const EdgeInsets.all(32),
      color: const Color(0xff1d2635),
      child:
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('DYQANI ONLINE',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800)),
        SizedBox(height: 12),
        Text(
            'Produktet  •  Kategoritë  •  Ofertat  •  Kontakti  •  Politika e privatësisë',
            style: TextStyle(color: Colors.white70)),
        SizedBox(height: 18),
        Text('© 2026 Dyqani Online. Të gjitha të drejtat e rezervuara.',
            style: TextStyle(color: Colors.white54))
      ]));
  void _sponsor(BuildContext c, Map<String, dynamic> x) => showDialog(
      context: c,
      builder: (_) => AlertDialog(
              title: Text(x['company_name'] ?? ''),
              content: Text(x['description'] ?? ''),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Mbyll'))
              ]));
}

class _Trust extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Trust(this.icon, this.text);
  @override
  Widget build(BuildContext c) => SizedBox(
      width: 180,
      child: Row(children: [
        Icon(icon),
        const SizedBox(width: 10),
        Expanded(
            child:
                Text(text, style: const TextStyle(fontWeight: FontWeight.w700)))
      ]));
}
