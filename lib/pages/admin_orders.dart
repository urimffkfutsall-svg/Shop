import 'dart:async';
import 'package:flutter/material.dart';
import '../state/store_state.dart';
import 'admin_catalog.dart';
import 'admin_homepage.dart';

const adminOrange = Color(0xffE65829);
const orderStatusLabels = <String, String>{
  'new': 'E re',
  'confirmed': 'E konfirmuar',
  'preparing': 'Në përgatitje',
  'shipped': 'Dërguar',
  'delivered': 'E dorëzuar',
  'completed': 'E dorëzuar',
  'cancelled': 'Anuluar',
};

class AdminDashboardPage extends StatefulWidget {
  final StoreState state;
  const AdminDashboardPage({super.key, required this.state});
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int section = 0;
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final content = switch (section) {
      0 => AdminStatsView(state: widget.state),
      1 => AdminOrdersView(state: widget.state),
      2 => AdminProductsView(state: widget.state),
      3 => AdminCategoriesView(state: widget.state),
      4 => AdminHomepageContentView(
          state: widget.state,
          kind: AdminContentKind.hero,
        ),
      5 => AdminHomepageContentView(
          state: widget.state,
          kind: AdminContentKind.sponsors,
        ),
      6 => AdminHomepageContentView(
          state: widget.state,
          kind: AdminContentKind.ads,
        ),
      _ => AdminHomepageSectionsView(state: widget.state),
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrimi'),
        actions: [
          IconButton(
            tooltip: 'Dil',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await widget.state.logout();
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      drawer: wide
          ? null
          : Drawer(
              child: SafeArea(
                child: AdminMenu(
                  selected: section,
                  onSelect: (value) {
                    setState(() => section = value);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
      body: Row(
        children: [
          if (wide)
            SizedBox(
              width: 245,
              child: AdminMenu(
                selected: section,
                onSelect: (value) => setState(() => section = value),
              ),
            ),
          if (wide) const VerticalDivider(width: 1),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class AdminMenu extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const AdminMenu({super.key, required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('DYQANI ONLINE',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ),
          ListTile(
            selected: selected == 0,
            selectedColor: adminOrange,
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text('Dashboard'),
            onTap: () => onSelect(0),
          ),
          ListTile(
            selected: selected == 1,
            selectedColor: adminOrange,
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Porositë'),
            onTap: () => onSelect(1),
          ),
          const Divider(),
          ListTile(
            selected: selected == 2,
            selectedColor: adminOrange,
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Produktet'),
            onTap: () => onSelect(2),
          ),
          ListTile(
            selected: selected == 3,
            selectedColor: adminOrange,
            leading: const Icon(Icons.category_outlined),
            title: const Text('Kategoritë'),
            onTap: () => onSelect(3),
          ),
          const Divider(),
          ListTile(
            selected: selected == 4,
            selectedColor: adminOrange,
            leading: const Icon(Icons.slideshow_outlined),
            title: const Text('Slideshow'),
            onTap: () => onSelect(4),
          ),
          ListTile(
            selected: selected == 5,
            selectedColor: adminOrange,
            leading: const Icon(Icons.handshake_outlined),
            title: const Text('Sponsorët'),
            onTap: () => onSelect(5),
          ),
          ListTile(
            selected: selected == 6,
            selectedColor: adminOrange,
            leading: const Icon(Icons.campaign_outlined),
            title: const Text('Reklamat'),
            onTap: () => onSelect(6),
          ),
          ListTile(
            selected: selected == 7,
            selectedColor: adminOrange,
            leading: const Icon(Icons.web_outlined),
            title: const Text('Seksionet e ballinës'),
            onTap: () => onSelect(7),
          ),
        ],
      );
}

class AdminStatsView extends StatelessWidget {
  final StoreState state;
  const AdminStatsView({super.key, required this.state});
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
        future: state.service.adminStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null)
            return const AdminErrorBox();
          final data = snapshot.data!;
          final orders = Map<String, dynamic>.from(data['orders'] ?? {});
          final products = Map<String, dynamic>.from(data['products'] ?? {});
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Dashboard',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Përmbledhje e aktivitetit të dyqanit.'),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  AdminStatCard(
                      'Porosi gjithsej', orders['total'], Icons.receipt_long),
                  AdminStatCard(
                      'Porosi të reja', orders['new'], Icons.fiber_new),
                  AdminStatCard(
                      'Në përgatitje', orders['preparing'], Icons.inventory),
                  AdminStatCard(
                      'Dërguar', orders['shipped'], Icons.local_shipping),
                  AdminStatCard(
                      'Të dorëzuara', orders['delivered'], Icons.check_circle),
                  AdminStatCard('Produkte aktive', products['active'],
                      Icons.shopping_bag),
                  AdminStatCard(
                      'Pa stok', products['out_of_stock'], Icons.warning_amber),
                  AdminStatCard(
                      'Me zbritje', products['discounted'], Icons.discount),
                ],
              ),
            ],
          );
        },
      );
}

class AdminStatCard extends StatelessWidget {
  final String title;
  final dynamic value;
  final IconData icon;
  const AdminStatCard(this.title, this.value, this.icon, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: 220,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white, border: Border.all(color: Colors.black12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: adminOrange),
            const SizedBox(height: 16),
            Text('${value ?? 0}',
                style:
                    const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
            Text(title, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      );
}

class AdminOrdersView extends StatefulWidget {
  final StoreState state;
  const AdminOrdersView({super.key, required this.state});
  @override
  State<AdminOrdersView> createState() => _AdminOrdersViewState();
}

class _AdminOrdersViewState extends State<AdminOrdersView> {
  final search = TextEditingController();
  String status = 'all';
  Timer? debounce;
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<List<Map<String, dynamic>>> load() => widget.state.service
      .adminOrders(search: search.text.trim(), status: status);
  void refresh() => setState(() => future = load());
  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Porositë',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 340,
                  child: TextField(
                    controller: search,
                    onChanged: (_) {
                      debounce?.cancel();
                      debounce =
                          Timer(const Duration(milliseconds: 400), refresh);
                    },
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Kërko numrin, klientin ose telefonin',
                        border: OutlineInputBorder()),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(
                        labelText: 'Statusi', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(
                          value: 'all', child: Text('Të gjitha')),
                      ...orderStatusLabels.entries.map((e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value))),
                    ],
                    onChanged: (value) {
                      status = value ?? 'all';
                      refresh();
                    },
                  ),
                ),
                IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) return const AdminErrorBox();
                  final rows = snapshot.data ?? [];
                  if (rows.isEmpty)
                    return const Center(
                        child: Text('Nuk ka porosi për t’u shfaqur.'));
                  return ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final order = rows[index];
                      return Card(
                        elevation: 0,
                        child: ListTile(
                          onTap: () => openOrder(context, order),
                          leading: const Icon(Icons.receipt_long),
                          title: Text(order['order_number'] ?? 'Pa numër',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(
                              "${order['customer_name'] ?? ''} • ${order['phone'] ?? ''}\n${order['created_at'] ?? ''}"),
                          isThreeLine: true,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('€${order['total'] ?? 0}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              Text(orderStatusLabels[order['status']] ??
                                  '${order['status'] ?? ''}'),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
  Future<void> openOrder(
      BuildContext context, Map<String, dynamic> order) async {
    final changed = await showDialog<bool>(
        context: context,
        builder: (_) => AdminOrderDialog(state: widget.state, order: order));
    if (changed == true) refresh();
  }
}

class AdminOrderDialog extends StatefulWidget {
  final StoreState state;
  final Map<String, dynamic> order;
  const AdminOrderDialog({super.key, required this.state, required this.order});
  @override
  State<AdminOrderDialog> createState() => _AdminOrderDialogState();
}

class _AdminOrderDialogState extends State<AdminOrderDialog> {
  late String status;
  bool saving = false;
  late Future<List<Map<String, dynamic>>> items;
  @override
  void initState() {
    super.initState();
    status = widget.order['status'] ?? 'new';
    items = widget.state.service.adminOrderItems(widget.order['id']);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.order['order_number'] ?? 'Porosia'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.order['customer_name'] ?? ''}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                Text("Telefon: ${widget.order['phone'] ?? ''}"),
                Text("Email: ${widget.order['customer_email'] ?? '—'}"),
                Text(
                    "Adresa: ${widget.order['country'] ?? ''}, ${widget.order['city'] ?? ''}, ${widget.order['address'] ?? ''} ${widget.order['street'] ?? ''} ${widget.order['apartment'] ?? ''}"),
                const Divider(height: 28),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: items,
                  builder: (_, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done)
                      return const CircularProgressIndicator();
                    return Column(
                      children: (snapshot.data ?? [])
                          .map((item) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                    item['product_name_snapshot'] ?? 'Produkt'),
                                subtitle: Text(
                                    "${item['quantity']} × €${item['unit_price']}"),
                                trailing: Text("€${item['line_total']}"),
                              ))
                          .toList(),
                    );
                  },
                ),
                const Divider(),
                Text('Totali: €${widget.order['total'] ?? 0}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(
                      labelText: 'Statusi i porosisë',
                      border: OutlineInputBorder()),
                  items: orderStatusLabels.entries
                      .map((e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => status = value ?? status),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Mbyll')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: adminOrange),
            onPressed: saving ? null : save,
            child: const Text('Ruaj statusin'),
          ),
        ],
      );
  Future<void> save() async {
    setState(() => saving = true);
    try {
      await widget.state.service.updateOrderStatus(widget.order['id'], status);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => saving = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Ndryshimi nuk u ruajt. Provoni përsëri.')));
    }
  }
}

class AdminErrorBox extends StatelessWidget {
  const AdminErrorBox({super.key});
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 42),
            SizedBox(height: 10),
            Text('Diçka nuk shkoi siç duhet.'),
            Text('Ju lutemi provoni përsëri.'),
          ],
        ),
      );
}
