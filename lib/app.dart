import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const orange = Color(0xffE65829);
const ink = Color(0xff1d2635);
const muted = Color(0xff797878);

class Product {
  final String id;
  final String nameSq;
  final String nameEn;
  final String category;
  final String imageKey;
  final String descriptionSq;
  final String descriptionEn;
  final double price;
  final bool active;
  const Product({required this.id, required this.nameSq, required this.nameEn, required this.category, required this.imageKey, required this.descriptionSq, required this.descriptionEn, required this.price, this.active = true});
  factory Product.fromMap(Map<String, dynamic> m) => Product(
    id: m['id'].toString(), nameSq: m['name_sq'] ?? '', nameEn: m['name_en'] ?? '',
    category: m['category'] ?? 'sneakers', imageKey: m['image_key'] ?? 'shooe_tilt_1.png',
    descriptionSq: m['description_sq'] ?? '', descriptionEn: m['description_en'] ?? '',
    price: (m['price'] as num).toDouble(), active: m['active'] ?? true,
  );
  Map<String, dynamic> toMap() => {'name_sq':nameSq,'name_en':nameEn,'category':category,'image_key':imageKey,'description_sq':descriptionSq,'description_en':descriptionEn,'price':price,'active':active};
  String name(bool sq) => sq ? nameSq : nameEn;
  String description(bool sq) => sq ? descriptionSq : descriptionEn;
}

const demoProducts = <Product>[
  Product(id:'demo-1', nameSq:'Nike Air Max 200', nameEn:'Nike Air Max 200', category:'sneakers', imageKey:'shooe_tilt_1.png', price:240, descriptionSq:'Linja të pastra, stil i gjithanshëm dhe amortizim Max Air për rehati në çdo hap.', descriptionEn:'Clean lines, versatile style and Max Air cushioning for comfort in every step.'),
  Product(id:'demo-2', nameSq:'Nike Air Max 97', nameEn:'Nike Air Max 97', category:'sneakers', imageKey:'shoe_tilt_2.png', price:220, descriptionSq:'Dizajn sportiv dhe komoditet i përditshëm me pamje ikonike.', descriptionEn:'Sporty design and everyday comfort with an iconic look.'),
];

class StoreService {
  bool get enabled { try { Supabase.instance.client; return true; } catch (_) { return false; } }
  SupabaseClient get client => Supabase.instance.client;
  Future<List<Product>> products() async {
    if (!enabled) return demoProducts;
    final rows = await client.from('products').select().eq('active', true).order('created_at');
    return (rows as List).map((e) => Product.fromMap(e)).toList();
  }
  Future<void> adminLogin(String username, String password) async {
    if (!enabled) throw Exception('Supabase nuk është konfiguruar.');
    final result = await client.functions.invoke('admin-login', body:{'username':username,'password':password});
    if (result.status != 200 || result.data is! Map) throw Exception('Kredencialet janë të pasakta.');
    final token = (result.data as Map)['refresh_token'];
    if (token == null) throw Exception('Sesioni nuk u krijua.');
    await client.auth.setSession(token);
  }
  Future<void> logout() async { if (enabled) await client.auth.signOut(); }
  Future<Product> save(Product p) async {
    if (!enabled) throw Exception('Supabase nuk është konfiguruar.');
    final map = p.toMap();
    final dynamic row = p.id.startsWith('new-')
      ? await client.from('products').insert(map).select().single()
      : await client.from('products').update(map).eq('id', p.id).select().single();
    return Product.fromMap(row);
  }
  Future<void> delete(String id) async { if (enabled) await client.from('products').delete().eq('id', id); }
  Future<String> checkout(String name, String email, Map<String,int> cart) async {
    if (!enabled) throw Exception('Supabase nuk është konfiguruar.');
    final id = await client.rpc('create_order', params:{'p_customer_name':name,'p_customer_email':email,'p_items':cart.entries.map((e)=>{'product_id':e.key,'quantity':e.value}).toList()});
    return id.toString();
  }
}

class StoreState extends ChangeNotifier {
  final service = StoreService();
  bool sq = true, loading = true, admin = false;
  List<Product> products = [];
  final Set<String> favorites = {};
  final Map<String,int> cart = {};
  String query = '', category = 'sneakers';
  Future<void> init() async {
    try { products = await service.products(); admin = service.enabled && service.client.auth.currentSession != null; }
    catch (_) { products = demoProducts; }
    loading = false; notifyListeners();
  }
  List<Product> get filtered => products.where((p)=>p.active && (category=='all'||p.category==category) && p.name(sq).toLowerCase().contains(query.toLowerCase())).toList();
  List<Product> get favoriteProducts => products.where((p)=>favorites.contains(p.id)).toList();
  int get cartCount => cart.values.fold(0,(a,b)=>a+b);
  double get total => cart.entries.fold<double>(0,(sum,e)=>sum+products.firstWhere((p)=>p.id==e.key).price*e.value);
  void language(bool value){sq=value;notifyListeners();}
  void search(String v){query=v;notifyListeners();}
  void setCategory(String v){category=v;notifyListeners();}
  void favorite(String id){favorites.contains(id)?favorites.remove(id):favorites.add(id);notifyListeners();}
  void add(Product p){cart[p.id]=(cart[p.id]??0)+1;notifyListeners();}
  void quantity(String id,int delta){final n=(cart[id]??0)+delta;if(n<=0)cart.remove(id);else cart[id]=n;notifyListeners();}
  void clearCart(){cart.clear();notifyListeners();}
  Future<void> login(String u,String p) async {await service.adminLogin(u,p);admin=true;notifyListeners();}
  Future<void> logout() async {await service.logout();admin=false;notifyListeners();}
  Future<void> save(Product p) async {final saved=await service.save(p);final i=products.indexWhere((x)=>x.id==saved.id);if(i<0)products.add(saved);else products[i]=saved;notifyListeners();}
  Future<void> remove(Product p) async {await service.delete(p.id);products.removeWhere((x)=>x.id==p.id);cart.remove(p.id);favorites.remove(p.id);notifyListeners();}
  Future<String> checkout(String name,String email) async {final id=await service.checkout(name,email,cart);clearCart();return id;}
}

class StoreApp extends StatefulWidget { const StoreApp({super.key}); @override State<StoreApp> createState()=>_StoreAppState(); }
class _StoreAppState extends State<StoreApp>{
  final state=StoreState();
  @override void initState(){super.initState();state.init();}
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:state,builder:(_,__)=>MaterialApp(
    debugShowCheckedModeBanner:false,title:state.sq?'Dyqani Online':'E-Commerce',
    theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:const Color(0xfff8f8f8),colorScheme:ColorScheme.fromSeed(seedColor:orange),textTheme:GoogleFonts.mulishTextTheme().apply(bodyColor:ink,displayColor:ink)),
    home:StoreShell(state:state),
  ));
}

String tr(StoreState s,String sq,String en)=>s.sq?sq:en;
String asset(Product p)=>'assets/${p.imageKey}';

class StoreShell extends StatefulWidget {final StoreState state;const StoreShell({super.key,required this.state});@override State<StoreShell> createState()=>_StoreShellState();}
class _StoreShellState extends State<StoreShell>{int tab=0;
  @override Widget build(BuildContext context){final s=widget.state;return Scaffold(
    body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1120),child:Padding(padding:const EdgeInsets.fromLTRB(20,18,20,92),child:Column(children:[
      Header(state:s,onAdmin:()=>_admin(context,s)),const SizedBox(height:22),Expanded(child:IndexedStack(index:tab,children:[HomePage(state:s,onDetail:(p)=>_detail(context,s,p)),HomePage(state:s,onDetail:(p)=>_detail(context,s,p),autoFocus:true),CartPage(state:s),FavoritesPage(state:s,onDetail:(p)=>_detail(context,s,p))]))
    ]))))),
    bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),indicatorColor:orange,destinations:[
      NavigationDestination(icon:const Icon(Icons.home_outlined),selectedIcon:const Icon(Icons.home,color:Colors.white),label:tr(s,'Kryefaqja','Home')),
      NavigationDestination(icon:const Icon(Icons.search),label:tr(s,'Kërko','Search')),
      NavigationDestination(icon:Badge(label:Text('${s.cartCount}'),isLabelVisible:s.cartCount>0,child:const Icon(Icons.shopping_bag_outlined)),label:tr(s,'Shporta','Cart')),
      NavigationDestination(icon:const Icon(Icons.favorite_border),label:tr(s,'Të preferuara','Favorites')),
    ]));}
  Future<void> _admin(BuildContext c,StoreState s) async {if(!s.admin){final ok=await showDialog<bool>(context:c,builder:(_)=>AdminLogin(state:s));if(ok!=true)return;}if(c.mounted)Navigator.push(c,MaterialPageRoute(builder:(_)=>AdminPage(state:s)));}
  void _detail(BuildContext c,StoreState s,Product p)=>showModalBottomSheet(context:c,isScrollControlled:true,backgroundColor:Colors.transparent,builder:(_)=>ProductDetail(state:s,product:p));
}

class Header extends StatelessWidget{final StoreState state;final VoidCallback onAdmin;const Header({super.key,required this.state,required this.onAdmin});@override Widget build(BuildContext c)=>Row(children:[
  const SoftIcon(icon:Icons.sort),const Spacer(),SegmentedButton<bool>(segments:const [ButtonSegment(value:true,label:Text('SQ')),ButtonSegment(value:false,label:Text('EN'))],selected:{state.sq},onSelectionChanged:(v)=>state.language(v.first),showSelectedIcon:false),const Spacer(),
  SoftIcon(icon:Icons.key_outlined,onTap:onAdmin,color:orange),const SizedBox(width:10),ClipRRect(borderRadius:BorderRadius.circular(14),child:Image.asset('assets/user.png',width:48,height:48,fit:BoxFit.cover))
]);}
class SoftIcon extends StatelessWidget{final IconData icon;final VoidCallback? onTap;final Color? color;const SoftIcon({super.key,required this.icon,this.onTap,this.color});@override Widget build(BuildContext c)=>Material(color:Colors.white,borderRadius:BorderRadius.circular(14),elevation:1,child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(14),child:SizedBox(width:48,height:48,child:Icon(icon,color:color??Colors.black54))));}

class HomePage extends StatelessWidget{final StoreState state;final ValueChanged<Product> onDetail;final bool autoFocus;const HomePage({super.key,required this.state,required this.onDetail,this.autoFocus=false});@override Widget build(BuildContext c){return ListView(children:[
  Text(tr(state,'Produktet\ntona','Our\nProducts'),style:const TextStyle(fontSize:46,height:1.02,fontWeight:FontWeight.w800)),const SizedBox(height:28),
  Row(children:[Expanded(child:TextField(autofocus:autoFocus,onChanged:state.search,decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:tr(state,'Kërko produkte','Search products'),filled:true,fillColor:const Color(0xffeef0ef),border:OutlineInputBorder(borderSide:BorderSide.none,borderRadius:BorderRadius.circular(16))))),const SizedBox(width:12),const SoftIcon(icon:Icons.filter_list)]),const SizedBox(height:22),
  SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[CategoryChip(state:state,keyName:'sneakers',label:tr(state,'Atlete','Sneakers'),image:'shoe_thumb_2.png'),CategoryChip(state:state,keyName:'jacket',label:tr(state,'Xhaketë','Jacket'),image:'jacket.png'),CategoryChip(state:state,keyName:'watch',label:tr(state,'Orë','Watch'),image:'watch.png'),CategoryChip(state:state,keyName:'all',label:tr(state,'Të gjitha','All'),icon:Icons.grid_view_rounded)])),const SizedBox(height:26),
  if(state.loading)const Center(child:CircularProgressIndicator())else if(state.filtered.isEmpty)Padding(padding:const EdgeInsets.all(50),child:Center(child:Text(tr(state,'Nuk u gjet asnjë produkt.','No products found.'))))else LayoutBuilder(builder:(c,b){final wide=b.maxWidth>700;return GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:state.filtered.length,gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:wide?2:1,mainAxisExtent:390,crossAxisSpacing:24,mainAxisSpacing:24),itemBuilder:(_,i)=>ProductCard(state:state,product:state.filtered[i],onTap:()=>onDetail(state.filtered[i])));})
]);}}
class CategoryChip extends StatelessWidget{final StoreState state;final String keyName,label;final String? image;final IconData? icon;const CategoryChip({super.key,required this.state,required this.keyName,required this.label,this.image,this.icon});@override Widget build(BuildContext c){final selected=state.category==keyName;return Padding(padding:const EdgeInsets.only(right:12),child:ChoiceChip(selected:selected,onSelected:(_)=>state.setCategory(keyName),selectedColor:Colors.white,side:BorderSide(color:selected?orange:Colors.black38,width:2),padding:const EdgeInsets.all(10),avatar:image!=null?Image.asset('assets/$image',width:30,height:30):Icon(icon),label:Text(label,style:const TextStyle(fontWeight:FontWeight.w800))));}}
class ProductCard extends StatelessWidget{final StoreState state;final Product product;final VoidCallback onTap;const ProductCard({super.key,required this.state,required this.product,required this.onTap});@override Widget build(BuildContext c)=>Card(elevation:0,color:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(26)),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(26),child:Padding(padding:const EdgeInsets.all(20),child:Stack(children:[
  Align(alignment:Alignment.topLeft,child:IconButton(onPressed:()=>state.favorite(product.id),icon:Icon(state.favorites.contains(product.id)?Icons.favorite:Icons.favorite_border,color:state.favorites.contains(product.id)?Colors.red:Colors.black38))),
  Column(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[Expanded(child:Stack(alignment:Alignment.center,children:[Container(width:150,height:150,decoration:const BoxDecoration(shape:BoxShape.circle,color:Color(0xffffe8df))),Hero(tag:product.id,child:Image.asset(asset(product),height:210,fit:BoxFit.contain))])),Text(product.name(state.sq),textAlign:TextAlign.center,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800)),Text(tr(state,'Në trend tani','Trending now'),style:const TextStyle(color:orange,fontSize:17,fontWeight:FontWeight.w700)),Text(product.price.toStringAsFixed(1),style:const TextStyle(fontSize:26,fontWeight:FontWeight.w800))])
]))));}

class ProductDetail extends StatefulWidget{final StoreState state;final Product product;const ProductDetail({super.key,required this.state,required this.product});@override State<ProductDetail> createState()=>_ProductDetailState();}
class _ProductDetailState extends State<ProductDetail>{int size=7;int color=0;@override Widget build(BuildContext c){final s=widget.state,p=widget.product;return DraggableScrollableSheet(initialChildSize:.92,minChildSize:.6,maxChildSize:.96,builder:(_,controller)=>Container(decoration:const BoxDecoration(color:Color(0xfff8f8f8),borderRadius:BorderRadius.vertical(top:Radius.circular(34))),child:ListView(controller:controller,padding:const EdgeInsets.all(24),children:[
  Row(children:[SoftIcon(icon:Icons.arrow_back_ios_new,onTap:()=>Navigator.pop(c)),const Spacer(),IconButton(onPressed:()=>s.favorite(p.id),icon:Icon(s.favorites.contains(p.id)?Icons.favorite:Icons.favorite_border,color:s.favorites.contains(p.id)?Colors.red:null))]),SizedBox(height:300,child:Stack(alignment:Alignment.center,children:[const Text('AIP',style:TextStyle(fontSize:130,fontWeight:FontWeight.w800,color:Color(0xffe1e2e4))),Hero(tag:p.id,child:Image.asset(asset(p),height:230))])),
  Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(30)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:Text(p.name(s.sq).toUpperCase(),style:const TextStyle(fontSize:26,fontWeight:FontWeight.w800))),Text('\$${p.price.toStringAsFixed(0)}',style:const TextStyle(fontSize:26,fontWeight:FontWeight.w800,color:orange))]),const Text('★★★★☆',style:TextStyle(color:Color(0xfffbba01),fontSize:22)),SectionTitle(tr(s,'Madhësitë e disponueshme','Available sizes')),Wrap(spacing:10,children:[6,7,8,9].map((x)=>ChoiceChip(label:Text('US $x'),selected:size==x,onSelected:(_)=>setState(()=>size=x),selectedColor:orange,labelStyle:TextStyle(color:size==x?Colors.white:ink,fontWeight:FontWeight.w800))).toList()),SectionTitle(tr(s,'Ngjyrat e disponueshme','Available colors')),Wrap(spacing:14,children:[Colors.amber,Colors.deepPurple,ink,Colors.red,Colors.blue].asMap().entries.map((e)=>InkWell(onTap:()=>setState(()=>color=e.key),child:Container(width:38,height:38,decoration:BoxDecoration(color:e.value,shape:BoxShape.circle,border:Border.all(color:color==e.key?Colors.white:e.value,width:4),boxShadow:[if(color==e.key)const BoxShadow(color:Colors.black26,spreadRadius:2)])))).toList()),SectionTitle(tr(s,'Përshkrimi','Description')),Text(p.description(s.sq),style:const TextStyle(fontSize:16,height:1.5,color:muted)),const SizedBox(height:22),SizedBox(width:double.infinity,child:FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:orange,padding:const EdgeInsets.all(17)),onPressed:(){s.add(p);Navigator.pop(c);ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text(tr(s,'Produkti u shtua në shportë','Product added to cart'))));},icon:const Icon(Icons.shopping_bag_outlined),label:Text(tr(s,'Shto në shportë','Add to cart'))))]))
])));}}
class SectionTitle extends StatelessWidget{final String text;const SectionTitle(this.text,{super.key});@override Widget build(BuildContext c)=>Padding(padding:const EdgeInsets.only(top:22,bottom:12),child:Text(text,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800)));}

class CartPage extends StatelessWidget{final StoreState state;const CartPage({super.key,required this.state});@override Widget build(BuildContext c){final rows=state.cart.entries.toList();return ListView(children:[Row(children:[Expanded(child:Text(tr(state,'Shporta\ne blerjeve','Shopping\nCart'),style:const TextStyle(fontSize:46,height:1.02,fontWeight:FontWeight.w800))),IconButton(onPressed:state.clearCart,icon:const Icon(Icons.delete_outline,color:orange))]),const SizedBox(height:30),if(rows.isEmpty)Padding(padding:const EdgeInsets.all(60),child:Center(child:Text(tr(state,'Shporta është bosh.','Your cart is empty.')))),...rows.map((e){final p=state.products.firstWhere((x)=>x.id==e.key);return Card(color:Colors.white,elevation:0,child:ListTile(contentPadding:const EdgeInsets.all(12),leading:Image.asset(asset(p),width:74),title:Text(p.name(state.sq),style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('\$ ${p.price.toStringAsFixed(2)}',style:const TextStyle(color:orange)),trailing:Wrap(crossAxisAlignment:WrapCrossAlignment.center,children:[IconButton(onPressed:()=>state.quantity(p.id,-1),icon:const Icon(Icons.remove)),Text('${e.value}',style:const TextStyle(fontWeight:FontWeight.w800)),IconButton(onPressed:()=>state.quantity(p.id,1),icon:const Icon(Icons.add))])));}),const Divider(height:50),Row(children:[Text('${state.cartCount} ${tr(state,'artikuj','items')}',style:const TextStyle(color:muted)),const Spacer(),Text('\$${state.total.toStringAsFixed(2)}',style:const TextStyle(fontSize:26,fontWeight:FontWeight.w800))]),const SizedBox(height:24),FilledButton(style:FilledButton.styleFrom(backgroundColor:orange,padding:const EdgeInsets.all(18)),onPressed:rows.isEmpty?null:()async{final ok=await showDialog<bool>(context:c,builder:(_)=>CheckoutDialog(state:state));if(ok==true&&c.mounted)ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text(tr(state,'Porosia u dërgua me sukses.','Order submitted successfully.'))));},child:Text(tr(state,'Vazhdo','Next')))]);}}

class CheckoutDialog extends StatefulWidget{final StoreState state;const CheckoutDialog({super.key,required this.state});@override State<CheckoutDialog> createState()=>_CheckoutDialogState();}
class _CheckoutDialogState extends State<CheckoutDialog>{final name=TextEditingController(),email=TextEditingController();bool busy=false;String? error;@override Widget build(BuildContext c)=>AlertDialog(title:Text(tr(widget.state,'Përfundo porosinë','Complete order')),content:SizedBox(width:380,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:InputDecoration(labelText:tr(widget.state,'Emri dhe mbiemri','Full name'))),TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email')),if(error!=null)Padding(padding:const EdgeInsets.only(top:12),child:Text(error!,style:const TextStyle(color:Colors.red)))])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:Text(tr(widget.state,'Anulo','Cancel'))),FilledButton(onPressed:busy?null:()async{if(name.text.trim().isEmpty||!email.text.contains('@')){setState(()=>error=tr(widget.state,'Plotëso të dhënat e sakta.','Enter valid details.'));return;}setState(()=>busy=true);try{await widget.state.checkout(name.text.trim(),email.text.trim());if(c.mounted)Navigator.pop(c,true);}catch(e){setState((){busy=false;error=e.toString().replaceFirst('Exception: ','');});}},child:busy?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)):Text(tr(widget.state,'Dërgo porosinë','Submit order')))]);}

class FavoritesPage extends StatelessWidget{final StoreState state;final ValueChanged<Product> onDetail;const FavoritesPage({super.key,required this.state,required this.onDetail});@override Widget build(BuildContext c)=>ListView(children:[Text(tr(state,'Produktet\ne preferuara','Favorite\nProducts'),style:const TextStyle(fontSize:46,height:1.02,fontWeight:FontWeight.w800)),const SizedBox(height:28),if(state.favoriteProducts.isEmpty)Padding(padding:const EdgeInsets.all(60),child:Center(child:Text(tr(state,'Nuk ka produkte të preferuara.','No favorite products.'))))else...state.favoriteProducts.map((p)=>SizedBox(height:390,child:ProductCard(state:state,product:p,onTap:()=>onDetail(p))))]);}

class AdminLogin extends StatefulWidget{final StoreState state;const AdminLogin({super.key,required this.state});@override State<AdminLogin> createState()=>_AdminLoginState();}
class _AdminLoginState extends State<AdminLogin>{final u=TextEditingController(text:'urimi1806'),p=TextEditingController();bool busy=false;String? error;@override Widget build(BuildContext c)=>AlertDialog(title:Text(tr(widget.state,'Hyrja e administratorit','Administrator login')),content:SizedBox(width:380,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:u,decoration:const InputDecoration(labelText:'Username')),TextField(controller:p,obscureText:true,decoration:const InputDecoration(labelText:'Password')),if(error!=null)Padding(padding:const EdgeInsets.only(top:12),child:Text(error!,style:const TextStyle(color:Colors.red)))])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:Text(tr(widget.state,'Anulo','Cancel'))),FilledButton(onPressed:busy?null:()async{setState(()=>busy=true);try{await widget.state.login(u.text.trim(),p.text);if(c.mounted)Navigator.pop(c,true);}catch(e){setState((){busy=false;error=e.toString().replaceFirst('Exception: ','');});}},child:busy?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)):Text(tr(widget.state,'Kyçu','Log in')))]);}

class AdminPage extends StatelessWidget{final StoreState state;const AdminPage({super.key,required this.state});@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text(tr(state,'Paneli i administratorit','Administrator dashboard')),actions:[TextButton(onPressed:()async{await state.logout();if(c.mounted)Navigator.pop(c);},child:Text(tr(state,'Dil','Log out')))]),floatingActionButton:FloatingActionButton.extended(backgroundColor:orange,foregroundColor:Colors.white,onPressed:()=>_edit(c,null),icon:const Icon(Icons.add),label:Text(tr(state,'Shto produkt','Add product'))),body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:900),child:ListView(padding:const EdgeInsets.all(20),children:[const Text('Supabase',style:TextStyle(color:Colors.green,fontWeight:FontWeight.w800)),Text(tr(state,'Menaxho produktet','Manage products'),style:const TextStyle(fontSize:40,fontWeight:FontWeight.w800)),const SizedBox(height:24),...state.products.map((p)=>Card(color:Colors.white,child:ListTile(leading:Image.asset(asset(p),width:70),title:Text(p.name(state.sq),style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('\$${p.price.toStringAsFixed(2)}'),trailing:Wrap(children:[IconButton(onPressed:()=>_edit(c,p),icon:const Icon(Icons.edit_outlined)),IconButton(onPressed:()=>_delete(c,p),icon:const Icon(Icons.delete_outline,color:Colors.red))]))))]))));
  Future<void> _edit(BuildContext c,Product? old) async {final result=await showDialog<Product>(context:c,builder:(_)=>ProductEditor(state:state,product:old));if(result!=null){try{await state.save(result);if(c.mounted)ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text(tr(state,'Produkti u ruajt.','Product saved.'))));}catch(e){if(c.mounted)ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text('$e')));}}}
  Future<void> _delete(BuildContext c,Product p) async {final yes=await showDialog<bool>(context:c,builder:(_)=>AlertDialog(title:Text(tr(state,'Fshi produktin?','Delete product?')),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:Text(tr(state,'Anulo','Cancel'))),FilledButton(onPressed:()=>Navigator.pop(c,true),child:Text(tr(state,'Fshi','Delete')))]));if(yes==true)await state.remove(p);}
}
class ProductEditor extends StatefulWidget{final StoreState state;final Product? product;const ProductEditor({super.key,required this.state,this.product});@override State<ProductEditor> createState()=>_ProductEditorState();}
class _ProductEditorState extends State<ProductEditor>{late final TextEditingController sq,en,price,dsq,den;late String image;@override void initState(){super.initState();final p=widget.product;sq=TextEditingController(text:p?.nameSq??'');en=TextEditingController(text:p?.nameEn??'');price=TextEditingController(text:p?.price.toString()??'');dsq=TextEditingController(text:p?.descriptionSq??'');den=TextEditingController(text:p?.descriptionEn??'');image=p?.imageKey??'shooe_tilt_1.png';}@override Widget build(BuildContext c)=>AlertDialog(title:Text(tr(widget.state,'Produkti','Product')),content:SizedBox(width:440,child:SingleChildScrollView(child:Column(children:[TextField(controller:sq,decoration:const InputDecoration(labelText:'Emri SQ')),TextField(controller:en,decoration:const InputDecoration(labelText:'Name EN')),TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Çmimi / Price')),DropdownButtonFormField(value:image,decoration:const InputDecoration(labelText:'Image'),items:['shooe_tilt_1.png','shoe_tilt_2.png','show_1.png'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>image=v!)),TextField(controller:dsq,maxLines:2,decoration:const InputDecoration(labelText:'Përshkrimi SQ')),TextField(controller:den,maxLines:2,decoration:const InputDecoration(labelText:'Description EN'))]))),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:Text(tr(widget.state,'Anulo','Cancel'))),FilledButton(onPressed:(){final value=double.tryParse(price.text);if(sq.text.trim().isEmpty||en.text.trim().isEmpty||value==null)return;Navigator.pop(c,Product(id:widget.product?.id??'new-${DateTime.now().millisecondsSinceEpoch}',nameSq:sq.text.trim(),nameEn:en.text.trim(),category:'sneakers',imageKey:image,descriptionSq:dsq.text.trim(),descriptionEn:den.text.trim(),price:value));},child:Text(tr(widget.state,'Ruaj','Save')))]);}

