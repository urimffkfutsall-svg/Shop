import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/catalog_models.dart';

class StoreService {
  bool get enabled {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  SupabaseClient get client => Supabase.instance.client;
  Future<List<Product>> products({int from = 0, int limit = 48}) async {
    if (!enabled) return demoProducts;
    final rows = await client
        .from('products')
        .select('*,product_images(*)')
        .eq('active', true)
        .order('sort_order')
        .range(from, from + limit - 1);
    return (rows as List)
        .map((e) => Product.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<CategoryModel>> categories() async {
    if (!enabled)
      return const [
        CategoryModel(id: 'demo-category', name: 'Atlete', slug: 'atlete')
      ];
    final rows = await client
        .from('categories')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return (rows as List)
        .map((e) => CategoryModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<HomepageSectionModel>> homepageSections() async {
    if (!enabled) return const [];
    final rows = await client
        .from('homepage_sections')
        .select()
        .eq('is_visible', true)
        .order('sort_order');
    return (rows as List)
        .map((e) => HomepageSectionModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> adminLogin(String username, String password) async {
    if (!enabled) throw Exception('Supabase nuk është konfiguruar.');
    final result = await client.functions.invoke('admin-login',
        body: {'username': username, 'password': password});
    if (result.status != 200 || result.data is! Map)
      throw Exception('Kredencialet janë të pasakta.');
    final token = (result.data as Map)['refresh_token'];
    if (token == null) throw Exception('Sesioni nuk u krijua.');
    await client.auth.setSession(token);
  }

  Future<void> logout() async {
    if (enabled) await client.auth.signOut();
  }

  Future<Product> save(Product p) async {
    if (!enabled) throw Exception('Supabase nuk është konfiguruar.');
    final map = p.toMap();
    final dynamic row = p.id.startsWith('new-')
        ? await client
            .from('products')
            .insert(map)
            .select('*,product_images(*)')
            .single()
        : await client
            .from('products')
            .update(map)
            .eq('id', p.id)
            .select('*,product_images(*)')
            .single();
    return Product.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> delete(String id) async {
    if (enabled) await client.from('products').delete().eq('id', id);
  }

  Future<String> checkout(
      String name, String email, Map<String, int> cart) async {
    if (!enabled) throw Exception('Supabase nuk është konfiguruar.');
    final id = await client.rpc('create_order', params: {
      'p_customer_name': name,
      'p_customer_email': email,
      'p_items': cart.entries
          .map((e) => {'product_id': e.key, 'quantity': e.value})
          .toList()
    });
    return id.toString();
  }

  Future<Map<String, dynamic>> checkoutSecure(
      {required String firstName,
      required String lastName,
      required String phone,
      String email = '',
      required String country,
      required String city,
      required String address,
      String street = '',
      String apartment = '',
      required Map<String, int> cart,
      required String idempotencyKey}) async {
    if (!enabled) throw Exception('Supabase nuk është konfiguruar.');
    final data = await client.rpc('create_order_secure', params: {
      'p_first_name': firstName,
      'p_last_name': lastName,
      'p_phone': phone,
      'p_email': email,
      'p_country': country,
      'p_city': city,
      'p_address': address,
      'p_street': street,
      'p_apartment': apartment,
      'p_items': cart.entries
          .map((e) => {'product_id': e.key, 'quantity': e.value})
          .toList(),
      'p_idempotency_key': idempotencyKey
    });
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>?> adminStats() async {
    if (!enabled) return null;
    final data = await client.rpc('admin_dashboard_stats');
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> adminOrders(
      {String search = '', String status = 'all', int limit = 100}) async {
    if (!enabled) return [];
    dynamic q = client.from('orders').select();
    if (status != 'all') q = q.eq('status', status);
    if (search.isNotEmpty) {
      final v = search.replaceAll(',', ' ');
      q = q.or(
          'order_number.ilike.%$v%,customer_name.ilike.%$v%,phone.ilike.%$v%');
    }
    final rows = await q.order('created_at', ascending: false).limit(limit);
    return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> adminOrderItems(String orderId) async {
    if (!enabled) return [];
    final rows = await client
        .from('order_items')
        .select()
        .eq('order_id', orderId)
        .order('id');
    return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    const allowed = {
      'new',
      'confirmed',
      'preparing',
      'shipped',
      'delivered',
      'cancelled',
      'completed'
    };
    if (!allowed.contains(status)) throw Exception('Statusi nuk është valid.');
    await client.from('orders').update({'status': status}).eq('id', orderId);
  }

  Future<String> uploadMedia(
      {required Uint8List bytes,
      required String fileName,
      required String contentType,
      required String folder}) async {
    if (!enabled) throw Exception('Supabase nuk është konfiguruar.');
    const allowed = {
      'image/jpeg',
      'image/png',
      'image/webp',
      'video/mp4',
      'video/webm'
    };
    if (!allowed.contains(contentType))
      throw Exception('Formati i skedarit nuk lejohet.');
    if (bytes.length > 25 * 1024 * 1024)
      throw Exception('Skedari nuk mund të jetë më i madh se 25 MB.');
    final safe = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '$folder/${DateTime.now().millisecondsSinceEpoch}_$safe';
    await client.storage.from('commerce-media').uploadBinary(path, bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: false));
    return client.storage.from('commerce-media').getPublicUrl(path);
  }

  Future<void> deleteMedia(String publicUrl) async {
    if (!enabled) return;
    final marker = '/commerce-media/';
    final i = publicUrl.indexOf(marker);
    if (i < 0) return;
    await client.storage
        .from('commerce-media')
        .remove([publicUrl.substring(i + marker.length)]);
  }
}
