import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/catalog_models.dart';
import '../services/store_service.dart';

class StoreState extends ChangeNotifier {
  final service=StoreService();
  bool sq=true,loading=true,admin=false;
  String? errorMessage;
  List<Product> products=[];
  List<CategoryModel> categories=[];
  List<HomepageSectionModel> homepageSections=[];
  final Set<String> favorites={};
  final Map<String,int> cart={};
  String query='',category='all';
  Future<void> init() async{loading=true;notifyListeners();try{await _restoreLocal();final result=await Future.wait([service.products(),service.categories(),service.homepageSections()]);products=result[0] as List<Product>;categories=result[1] as List<CategoryModel>;homepageSections=result[2] as List<HomepageSectionModel>;admin=service.enabled&&service.client.auth.currentSession!=null;errorMessage=null;}catch(_){products=demoProducts;errorMessage='Diçka nuk shkoi siç duhet. Ju lutemi provoni përsëri.';}loading=false;notifyListeners();}
  Future<void> _restoreLocal() async{final p=await SharedPreferences.getInstance();sq=p.getBool('store_sq')??true;favorites..clear()..addAll(p.getStringList('store_favorites')??[]);final raw=p.getString('store_cart');if(raw!=null){final m=Map<String,dynamic>.from(jsonDecode(raw));cart..clear()..addAll(m.map((k,v)=>MapEntry(k,(v as num).toInt())));}}
  Future<void> _persist() async{final p=await SharedPreferences.getInstance();await p.setBool('store_sq',sq);await p.setStringList('store_favorites',favorites.toList());await p.setString('store_cart',jsonEncode(cart));}
  List<Product> get filtered=>products.where((p)=>p.active&&(category=='all'||p.categoryId==category||p.category==category)&&(p.name(sq).toLowerCase().contains(query.toLowerCase())||p.sku.toLowerCase().contains(query.toLowerCase())||p.brand.toLowerCase().contains(query.toLowerCase()))).toList();
  List<Product> get favoriteProducts=>products.where((p)=>favorites.contains(p.id)).toList();
  int get cartCount=>cart.values.fold(0,(a,b)=>a+b);
  double get subtotal=>cart.entries.fold<double>(0,(sum,e)=>sum+products.firstWhere((p)=>p.id==e.key).price*e.value);
  double get total=>cart.entries.fold<double>(0,(sum,e)=>sum+products.firstWhere((p)=>p.id==e.key).finalPrice*e.value);
  double get discount=>subtotal-total;
  void language(bool value){sq=value;_persist();notifyListeners();}
  void search(String v){query=v;notifyListeners();}
  void setCategory(String v){category=v;notifyListeners();}
  void favorite(String id){favorites.contains(id)?favorites.remove(id):favorites.add(id);_persist();notifyListeners();}
  void add(Product p){if(!p.inStock)return;cart[p.id]=(cart[p.id]??0)+1;_persist();notifyListeners();}
  void quantity(String id,int delta){final product=products.firstWhere((x)=>x.id==id);final n=(cart[id]??0)+delta;if(n<=0)cart.remove(id);else cart[id]=n.clamp(1,product.stock).toInt();_persist();notifyListeners();}
  void clearCart(){cart.clear();_persist();notifyListeners();}
  Future<void> login(String u,String p) async{await service.adminLogin(u,p);admin=true;notifyListeners();}
  Future<void> logout() async{await service.logout();admin=false;notifyListeners();}
  Future<void> save(Product p) async{final saved=await service.save(p);final i=products.indexWhere((x)=>x.id==saved.id);if(i<0)products.add(saved);else products[i]=saved;notifyListeners();}
  Future<void> remove(Product p) async{await service.delete(p.id);products.removeWhere((x)=>x.id==p.id);cart.remove(p.id);favorites.remove(p.id);_persist();notifyListeners();}
  Future<String> checkout(String name,String email) async{final id=await service.checkout(name,email,cart);clearCart();return id;}
}
