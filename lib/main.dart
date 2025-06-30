import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_uts/deliveries/edit_delivery_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'deliveries/add_delivery_page.dart';
import 'products/add_product_page.dart';
import 'products/edit_product_page.dart';
import 'receipts/add_receipt_page.dart';
import 'receipts/edit_receipt_page.dart';
import 'suppliers/add_supplier_page.dart';
import 'suppliers/edit_supplier_page.dart';
import 'warehouses/add_warehouse_page.dart';
import 'warehouses/edit_warehouse_page.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final prefs = await SharedPreferences.getInstance();
  final querySnapshot = await FirebaseFirestore.instance
      .collection('stores')
      .where('code', isEqualTo: "22100016")
      .limit(1)
      .get();

  final storeDoc = querySnapshot.docs.first;
  await prefs.setString('store_ref', storeDoc.reference.path);

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "UAS PALP 2025 - Steve Ariyanto",
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.blue[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    const ReceiptListPage(),
    const DeliveryListPage(),
    const SuppliersPage(),
    const WarehousesPage(),
    const ProductsPage(),
  ];

  final List<String> _pageTitles = [
    'Receipts',
    'Delivery',
    'Suppliers',
    'Warehouses',
    'Products',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitles[_selectedIndex]), 
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Menu Navigasi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.receipt),
              title: const Text('Receipts'),
              selected: _selectedIndex == 0,
              onTap: () => _onItemTapped(0),
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping),
              title: const Text('Delivery'),
              selected: _selectedIndex == 1,
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Suppliers'),
              selected: _selectedIndex == 2,
              onTap: () => _onItemTapped(2),
            ),
            ListTile(
              leading: const Icon(Icons.warehouse),
              title: const Text('Warehouses'),
              selected: _selectedIndex == 3,
              onTap: () => _onItemTapped(3),
            ),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Products'),
              selected: _selectedIndex == 4,
              onTap: () => _onItemTapped(4),
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }
}


class ReceiptListPage extends StatefulWidget {
  const ReceiptListPage({super.key});

  @override
  State<ReceiptListPage> createState() => _ReceiptListPageState();
}

class _ReceiptListPageState extends State<ReceiptListPage> {
  List<DocumentSnapshot> _allReceipts = [];
  final Map<String, List<DocumentSnapshot>> _detailsMap = {};
  final Set<String> _expandedReceipts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReceiptsForStore();
  }

  Future<void> _loadReceiptsForStore() async {
    final prefs = await SharedPreferences.getInstance();
    final storeRefPath = prefs.getString('store_ref');
    if (storeRefPath == null || storeRefPath.isEmpty) return;

    final storeRef = FirebaseFirestore.instance.doc(storeRefPath);
    print('storeRefPath: $storeRefPath');
    print('storeRef: ${storeRef.path}');
    final receiptsSnapshot = await FirebaseFirestore.instance
        .collection('purchaseGoodsReceipts')
        .where('store_ref', isEqualTo: storeRef)
        .get();

    setState(() {
      _allReceipts = receiptsSnapshot.docs;
      _loading = false;
    });
  }

  Future<List<String>> _resolveReferences(
    DocumentReference? storeRef,
    DocumentReference? supplierRef,
    DocumentReference? warehouseRef,
  ) async {
    final refs = [storeRef, supplierRef, warehouseRef];
    final names = await Future.wait(refs.map((ref) async {
      if (ref == null) return 'Unknown';
      try {
        final doc = await ref.get();
        final data = doc.data() as Map<String, dynamic>?;
        return data?['name']?.toString() ?? 'Unnamed';
      } catch (e) {
        return 'Error';
      }
    }).cast<Future<String>>());

    return names;
  }

  Future<void> _toggleDetails(String receiptId, DocumentReference receiptRef) async {
    if (_expandedReceipts.contains(receiptId)) {
      setState(() {
        _expandedReceipts.remove(receiptId);
      });
      return;
    }

    if (!_detailsMap.containsKey(receiptId)) {
      final detailSnapshot = await receiptRef.collection('details').get();
      _detailsMap[receiptId] = detailSnapshot.docs;
    }

    setState(() {
      _expandedReceipts.add(receiptId);
    });
  }

  Future<String> _resolveProductName(DocumentReference? ref) async {
    if (ref == null) return 'Unknown';
    try {
      final doc = await ref.get();
      final data = doc.data() as Map<String, dynamic>?;
      return data?['name'] ?? 'Unnamed';
    } catch (e) {
      return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: Text('Masukkan kode dan nama toko terlebih dahulu.'))
        : _allReceipts.isEmpty
            ? const Center(child: Text('Tidak ada produk.'))
            : Scaffold(
              body: ListView.builder(
                  itemCount: _allReceipts.length,
                  itemBuilder: (context, index) {
                    final document = _allReceipts[index];
                    final data = document.data() as Map<String, dynamic>;
                    final receiptId = document.id;
                    final postDate = DateTime.tryParse(data['post_date'] ?? '') ??
                        (data['created_at'] as Timestamp).toDate();

                    return FutureBuilder<List<String>>(
                      future: _resolveReferences(
                        data['store_ref'],
                        data['supplier_ref'],
                        data['warehouse_ref'],
                      ),
                      builder: (context, snapshot) {
                        final refNames = snapshot.data ?? ['Loading...', 'Loading...', 'Loading...'];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("No. Form: ${data['no_form']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text("Post Date: ${DateFormat('yyyy-MM-dd').format(postDate)}"),
                                Text("Grand Total: ${rupiahFormat.format(data['grandtotal'])}"),
                                Text("Item Total: ${data['item_total']}"),
                                Text("Store: ${refNames[0]}"),
                                Text("Supplier: ${refNames[1]}"),
                                Text("Warehouse: ${refNames[2]}"),
                                Text("Synced: ${data['synced'] ? 'Yes' : 'No'}"),
                                Text("Created At: ${(data['created_at'] as Timestamp).toDate()}"),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    ElevatedButton(
                                      onPressed: () => _toggleDetails(receiptId, document.reference),
                                      child: Text(_expandedReceipts.contains(receiptId) ? 'Sembunyikan Detail' : 'Lihat Detail'),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () async {
                                        final result = await showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          builder: (_) => EditReceiptModal(
                                            receiptRef: document.reference,
                                            receiptData: data,
                                          ),
                                        );
                                        if (result == 'updated') {
                                          await _loadReceiptsForStore();
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Hapus Receipt?'),
                                            content: const Text('Apakah Anda yakin ingin menghapus receipt ini?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text('Batal'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                child: const Text('Hapus'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true) {
                                          print('Confirmed is true. Proceeding...');
                                          final detailsSnapshot = await document.reference.collection('details').get();

                                          for (var detailDoc in detailsSnapshot.docs) {
                                            final detailData = detailDoc.data();
                                            final productRef = detailData['product_ref'] as DocumentReference?;
                                            final warehouseRef = detailData['warehouse_ref'] as DocumentReference? ?? data['warehouse_ref'];
                                            print(productRef);
                                            print(warehouseRef);
                                            final qty = detailData['qty'];

                                            if (productRef != null && warehouseRef != null && qty != null) {
                                              final stockQuery = await FirebaseFirestore.instance
                                                  .collection('stocks')
                                                  .where('product_ref', isEqualTo: productRef)
                                                  .where('warehouse_ref', isEqualTo: warehouseRef)
                                                  .limit(1)
                                                  .get();

                                              if (stockQuery.docs.isNotEmpty) {
                                                final stockDoc = stockQuery.docs.first;
                                                final stockRef = stockDoc.reference;
                                                final stockData = stockDoc.data();
                                                final stockQty = stockData['qty'] ?? 0;

                                                if (stockQty == qty) {
                                                  await stockRef.delete();
                                                } else if (stockQty > qty) {
                                                  await stockRef.update({'qty': stockQty - qty});
                                                } else {
                                                  print('Warning: Stock qty (${stockQty}) < receipt qty (${qty}) for product ${productRef.id}');
                                                }
                                              } else {
                                                print('Warning: No stock found for product ${productRef.id} in warehouse ${warehouseRef.id}');
                                              }
                                              
                                              await FirebaseFirestore.instance.runTransaction((transaction) async {
                                                final productSnap = await transaction.get(productRef);
                                                final productData = productSnap.data() as Map<String, dynamic>?;
                                                final currentQty = productData?['qty'] ?? 0;
                                                transaction.update(productRef, {
                                                  'qty': currentQty - qty,
                                                });
                                              });
                                            }

                                            await detailDoc.reference.delete();
                                          }

                                          await document.reference.delete();
                                          await _loadReceiptsForStore();
                                        }
                                      }
                                    ),
                                  ],
                                ),
                                if (_expandedReceipts.contains(receiptId))
                                  Column(
                                    children: _detailsMap[receiptId]?.map((detailDoc) {
                                        final detail = detailDoc.data() as Map<String, dynamic>;
                                        return FutureBuilder<String>(
                                          future: _resolveProductName(detail['product_ref']),
                                          builder: (context, snapshot) {
                                            final productName = snapshot.data ?? 'Loading...';
                                            return ListTile(
                                              title: Text(productName),
                                              subtitle: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text("Qty: ${detail['qty']} ${detail['unit_name']}"),
                                                  Text("Price: ${rupiahFormat.format(detail['price'])}"),
                                                  Text("Subtotal: ${rupiahFormat.format(detail['subtotal'])}"),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      }).toList() ??
                                      [const Text('Tidak ada detail')],
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                floatingActionButton: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children : [
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AddReceiptPage()),
                      );
                      await _loadReceiptsForStore();
                    },
                    child: const Text('Tambah Receipt'),
                  ),
                ],
              ),
            );
  }
}                               

class DeliveryListPage extends StatefulWidget {
  const DeliveryListPage({super.key});

  @override
  State<DeliveryListPage> createState() => _DeliveryListPageState();
}

class _DeliveryListPageState extends State<DeliveryListPage> {
  List<DocumentSnapshot> _allDeliveries = [];
  final Map<String, List<DocumentSnapshot>> _detailsMap = {};
  final Set<String> _expandedDeliveries = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDeliveriesForStore();
  }

  Future<void> _loadDeliveriesForStore() async {
    final prefs = await SharedPreferences.getInstance();
    final storeRefPath = prefs.getString('store_ref');
    if (storeRefPath == null || storeRefPath.isEmpty) return;

    final storeRef = FirebaseFirestore.instance.doc(storeRefPath);
    final deliveriesSnapshot = await FirebaseFirestore.instance
        .collection('deliveries')
        .where('store_ref', isEqualTo: storeRef)
        .get();

    setState(() {
      _allDeliveries = deliveriesSnapshot.docs;
      _loading = false;
    });
  }

  Future<List<String>> _resolveReferences(
    DocumentReference? storeRef,
    DocumentReference? storeRefTo,
    DocumentReference? warehouseRef,
  ) async {
    final refs = [storeRef, storeRefTo, warehouseRef];
    final names = await Future.wait(refs.map((ref) async {
      if (ref == null) return 'Unknown';
      try {
        final doc = await ref.get();
        final data = doc.data() as Map<String, dynamic>?;
        return data?['name']?.toString() ?? 'Unnamed';
      } catch (e) {
        return 'Error';
      }
    }).cast<Future<String>>());

    return names;
  }

  Future<void> _toggleDetails(String deliveryId, DocumentReference deliveryRef) async {
    if (_expandedDeliveries.contains(deliveryId)) {
      setState(() {
        _expandedDeliveries.remove(deliveryId);
      });
      return;
    }

    if (!_detailsMap.containsKey(deliveryId)) {
      final detailSnapshot = await deliveryRef.collection('details').get();
      _detailsMap[deliveryId] = detailSnapshot.docs;
    }

    setState(() {
      _expandedDeliveries.add(deliveryId);
    });
  }

  Future<String> _resolveProductName(DocumentReference? ref) async {
    if (ref == null) return 'Unknown';
    try {
      final doc = await ref.get();
      final data = doc.data() as Map<String, dynamic>?;
      return data?['name'] ?? 'Unnamed';
    } catch (e) {
      return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: Text('Masukkan kode dan nama toko terlebih dahulu.'))
        : _allDeliveries.isEmpty
            ? const Center(child: Text('Tidak ada delivery.'))
            : Scaffold(
              body: ListView.builder(
                  itemCount: _allDeliveries.length,
                  itemBuilder: (context, index) {
                    final document = _allDeliveries[index];
                    final data = document.data() as Map<String, dynamic>;
                    final deliveryId = document.id;
                    final postDate = DateTime.tryParse(data['post_date'] ?? '') ??
                        (data['created_at'] as Timestamp).toDate();

                    return FutureBuilder<List<String>>(
                      future: _resolveReferences(
                        data['store_ref'],
                        data['destination_store_ref'],
                        data['warehouse_ref'],
                      ),
                      builder: (context, snapshot) {
                        final refNames = snapshot.data ?? ['Loading...', 'Loading...', 'Loading...'];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("No. Form: ${data['no_form']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text("Post Date: ${DateFormat('yyyy-MM-dd').format(postDate)}"),
                                Text("Grand Total: ${rupiahFormat.format(data['grandtotal'])}"),
                                Text("Item Total: ${data['item_total']}"),
                                Text("Store Asal: ${refNames[0]}"),
                                Text("Store Tujuan: ${refNames[1]}"),
                                Text("Warehouse: ${refNames[2]}"),
                                Text("Synced: ${data['synced'] ? 'Yes' : 'No'}"),
                                Text("Created At: ${(data['created_at'] as Timestamp).toDate()}"),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    ElevatedButton(
                                      onPressed: () => _toggleDetails(deliveryId, document.reference),
                                      child: Text(_expandedDeliveries.contains(deliveryId) ? 'Sembunyikan Detail' : 'Lihat Detail'),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () async {
                                        final result = await showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          builder: (_) => EditDeliveryModal(
                                            deliveryRef: document.reference,
                                            deliveryData: data,
                                          ),
                                        );
                                        if (result == 'updated') {
                                          await _loadDeliveriesForStore();
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Hapus Delivery?'),
                                            content: const Text('Apakah Anda yakin ingin menghapus delivery ini?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text('Batal'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                child: const Text('Hapus'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true) {
                                          final detailsSnapshot = await document.reference.collection('details').get();

                                          for (var detailDoc in detailsSnapshot.docs) {
                                            final detailData = detailDoc.data();
                                            final productRef = detailData['product_ref'] as DocumentReference?;
                                            final warehouseRef = detailData['warehouse_ref'] as DocumentReference? ?? data['warehouse_ref'];
                                            final qty = detailData['qty'];

                                            if (productRef != null && warehouseRef != null && qty != null) {
                                              final stockQuery = await FirebaseFirestore.instance
                                                  .collection('stocks')
                                                  .where('product_ref', isEqualTo: productRef)
                                                  .where('warehouse_ref', isEqualTo: warehouseRef)
                                                  .limit(1)
                                                  .get();

                                              if (stockQuery.docs.isNotEmpty) {
                                                final stockDoc = stockQuery.docs.first;
                                                final stockRef = stockDoc.reference;
                                                final stockData = stockDoc.data();
                                                final stockQty = stockData['qty'] ?? 0;

                                                await stockRef.update({'qty': stockQty + qty});
                                              } else {
                                                await FirebaseFirestore.instance.collection('stocks').add({
                                                  'product_ref': productRef,
                                                  'warehouse_ref': warehouseRef,
                                                  'qty': qty,
                                                });
                                              }

                                              await FirebaseFirestore.instance.runTransaction((transaction) async {
                                                final productSnap = await transaction.get(productRef);
                                                final productData = productSnap.data() as Map<String, dynamic>?;
                                                final currentQty = productData?['qty'] ?? 0;
                                                transaction.update(productRef, {
                                                  'qty': currentQty + qty,
                                                });
                                              });
                                            }

                                            await detailDoc.reference.delete();
                                          }

                                          await document.reference.delete();
                                          await _loadDeliveriesForStore();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                if (_expandedDeliveries.contains(deliveryId))
                                  Column(
                                    children: _detailsMap[deliveryId]?.map((detailDoc) {
                                        final detail = detailDoc.data() as Map<String, dynamic>;
                                        return FutureBuilder<String>(
                                          future: _resolveProductName(detail['product_ref']),
                                          builder: (context, snapshot) {
                                            final productName = snapshot.data ?? 'Loading...';
                                            return ListTile(
                                              title: Text(productName),
                                              subtitle: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text("Qty: ${detail['qty']} ${detail['unit_name']}"),
                                                  Text("Price: ${rupiahFormat.format(detail['price'])}"),
                                                  Text("Subtotal: ${rupiahFormat.format(detail['subtotal'])}"),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      }).toList() ??
                                      [const Text('Tidak ada detail')],
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                floatingActionButton: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AddDeliveryPage()), 
                      );
                      await _loadDeliveriesForStore();
                    },
                    child: const Text('Tambah Delivery'),
                  ),
                ],
              ),
            );
  }
}

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPage();
}

class _SuppliersPage extends State<SuppliersPage> {
  List<DocumentSnapshot> _allSuppliers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSuppliersForStore();
  }

  Future<void> _loadSuppliersForStore() async {
    final prefs = await SharedPreferences.getInstance();
    final storeRefPath = prefs.getString('store_ref');
    if (storeRefPath == null || storeRefPath.isEmpty) return;

    final storeRef = FirebaseFirestore.instance.doc(storeRefPath);
    final receiptsSnapshot = await FirebaseFirestore.instance
        .collection('suppliers')
        .where('store_ref', isEqualTo: storeRef)
        .get();
    
    List<DocumentSnapshot> allSuppliers= [];

    for (var supplier in receiptsSnapshot.docs) {
      allSuppliers.add(supplier);
    }

    setState(() {
      _allSuppliers = allSuppliers;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: Text('Masukkan kode dan nama toko terlebih dahulu.'))
        : _allSuppliers.isEmpty
            ? const Center(child: Text('Tidak ada detail supplier.'))
            : Scaffold(
              body: ListView.builder(
                  itemCount: _allSuppliers.length,
                  itemBuilder: (context, index) {
                    final document = _allSuppliers[index];
                    final data = document.data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text("Nama Supplier: ${data['name']}"),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () async {
                                    final result = await showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (_) => EditSupplierModal(
                                        supplierRef: document.reference,
                                      ),
                                    );
                                    if (result == 'updated') {
                                      await _loadSuppliersForStore();
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Hapus Supplier?'),
                                        content: const Text('Apakah Anda yakin ingin menghapus supplier ini?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Batal'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Hapus'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      await document.reference.delete();
                                      await _loadSuppliersForStore();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                floatingActionButton: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children : [
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AddSupplierPage()),
                      );
                      await _loadSuppliersForStore();
                    },
                    child: const Text('Tambah Supplier'),
                  ),
                ],
              ),
            );
  }
}

class WarehousesPage extends StatefulWidget {
  const WarehousesPage({super.key});

  @override
  State<WarehousesPage> createState() => _WarehousesPage();
}

class _WarehousesPage extends State<WarehousesPage> {
  List<DocumentSnapshot> _allWarehouses = [];
  final Map<String, List<DocumentSnapshot>> _stocksMap = {};
  final Set<String> _expandedReceipts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWarehousesForStore();
  }

  Future<void> _loadWarehousesForStore() async {
    final prefs = await SharedPreferences.getInstance();
    final storeRefPath = prefs.getString('store_ref');
    if (storeRefPath == null || storeRefPath.isEmpty) return;

    final storeRef = FirebaseFirestore.instance.doc(storeRefPath);
    final snapshot = await FirebaseFirestore.instance
        .collection('warehouses')
        .where('store_ref', isEqualTo: storeRef)
        .get();

    setState(() {
      _allWarehouses = snapshot.docs;
      _loading = false;
    });
  }

  Future<void> _toggleDetails(String warehouseId, DocumentReference warehouseRef) async {
    if (_expandedReceipts.contains(warehouseId)) {
      setState(() {
        _expandedReceipts.remove(warehouseId);
      });
      return;
    }

    if (!_stocksMap.containsKey(warehouseId)) {
      final stockSnapshot = await FirebaseFirestore.instance
          .collection('stocks')
          .where('warehouse_ref', isEqualTo: warehouseRef)
          .get();
      setState(() {
        _stocksMap[warehouseId] = stockSnapshot.docs;
      });
    }

    setState(() {
      _expandedReceipts.add(warehouseId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: Text('Masukkan kode dan nama toko terlebih dahulu.'))
        : _allWarehouses.isEmpty
            ? const Center(child: Text('Tidak ada detail warehouse.'))
            : Scaffold(
              body: ListView.builder(
                  itemCount: _allWarehouses.length,
                  itemBuilder: (context, index) {
                    final document = _allWarehouses[index];
                    final data = document.data() as Map<String, dynamic>;
                    final warehouseId = document.id;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Nama Warehouse: ${data['name']}"),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () => _toggleDetails(warehouseId, document.reference),
                                  child: Text(_expandedReceipts.contains(warehouseId)
                                      ? 'Sembunyikan Detail'
                                      : 'Lihat Detail'),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () async {
                                    final result = await showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (_) => EditWarehouseModal(warehouseRef: document.reference),
                                    );
                                    if (result == 'updated') {
                                      await _loadWarehousesForStore();
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Hapus Warehouse?'),
                                        content: const Text('Apakah Anda yakin ingin menghapus warehouse ini?'),
                                        actions: [
                                          TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('Batal')),
                                          TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('Hapus')),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      final stocksSnapshot = await FirebaseFirestore.instance
                                          .collection('stocks')
                                          .where('warehouse_ref', isEqualTo: document.reference)
                                          .get();

                                      for (var stockDoc in stocksSnapshot.docs) {
                                        final stockData = stockDoc.data();
                                        final productRef = stockData['product_ref'] as DocumentReference?;
                                        final qty = stockData['qty'];

                                        if (productRef != null && qty != null) {
                                          await FirebaseFirestore.instance.runTransaction((transaction) async {
                                            final productSnap = await transaction.get(productRef);
                                            final productData = productSnap.data() as Map<String, dynamic>?;
                                            final currentQty = productData?['qty'] ?? 0;
                                            transaction.update(productRef, {'qty': currentQty - qty});
                                          });
                                        }
                                        await stockDoc.reference.delete();
                                      }

                                      await document.reference.delete();
                                      await _loadWarehousesForStore();
                                    }
                                  },
                                ),
                              ],
                            ),
                            if (_expandedReceipts.contains(warehouseId))
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _stocksMap[warehouseId]?.map((stockDoc) {
                                    final detail = stockDoc.data() as Map<String, dynamic>;
                                    final productRef = detail['product_ref'] as DocumentReference?;
                                    final qty = detail['qty'] ?? 0;
                                    final unitName = detail['unit_name'] ?? '';

                                    return FutureBuilder<DocumentSnapshot>(
                                      future: productRef?.get(),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState != ConnectionState.done) {
                                          return const Text("Loading...");
                                        }
                                        if (!snapshot.hasData || snapshot.data == null) {
                                          return const Text("Produk tidak ditemukan.");
                                        }

                                        final productData = snapshot.data!.data() as Map<String, dynamic>?;
                                        final productName = productData?['name'] ?? 'Unknown';
                                        return ListTile(
                                          title: Text(productName),
                                          subtitle: Text('Qty: $qty $unitName'),
                                        );
                                      },
                                    );
                                  }).toList() ??
                                  [const Text('Tidak ada detail')],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                floatingActionButton: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AddWarehousePage()),
                      );
                      await _loadWarehousesForStore();
                    },
                    child: const Text('Tambah Warehouse'),
                  ),
                ],
              ),
            );
  }
}

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPage();
}

class _ProductsPage extends State<ProductsPage> {
  List<DocumentSnapshot> _allProducts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProductsForStore();
  }

  Future<void> _loadProductsForStore() async {
    final prefs = await SharedPreferences.getInstance();
    final storeRefPath = prefs.getString('store_ref');
    if (storeRefPath == null || storeRefPath.isEmpty) return;

    final storeRef = FirebaseFirestore.instance.doc(storeRefPath);
    final receiptsSnapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('store_ref', isEqualTo: storeRef)
        .get();
    
    List<DocumentSnapshot> allProducts = [];

    for (var product in receiptsSnapshot.docs) {
      allProducts.add(product);
    }

    setState(() {
      _allProducts = allProducts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: Text('Masukkan kode dan nama toko terlebih dahulu.'))
        : _allProducts.isEmpty
            ? const Center(child: Text('Tidak ada detail produk.'))
            : Scaffold(
              body: ListView.builder(
                  itemCount: _allProducts.length,
                  itemBuilder: (context, index) {
                    final document = _allProducts[index];
                    final data = document.data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Nama Product: ${data['name']}"),
                                  Text("Qty: ${data['qty']} pcs"),
                                  Text("Price: ${rupiahFormat.format(data['default_price'])}")
                                ]
                              ) 
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () async {
                                    final result = await showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (_) => EditProductModal(
                                        productRef: document.reference,
                                      ),
                                    );
                                    if (result == 'updated') {
                                      await _loadProductsForStore();
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Hapus Product?'),
                                        content: const Text('Apakah Anda yakin ingin menghapus product ini?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Batal'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Hapus'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      await document.reference.delete();
                                      await _loadProductsForStore();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                floatingActionButton: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [      
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AddProductPage()),
                      );
                      await _loadProductsForStore();
                    },
                    child: const Text('Tambah Product'),
                  ),
                ],
              ),
            );
  }
}

final rupiahFormat = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);