import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; 

class AddDeliveryPage extends StatefulWidget {
  const AddDeliveryPage({super.key});

  @override
  State<AddDeliveryPage> createState() => _AddDeliveryPageState();
}

class _AddDeliveryPageState extends State<AddDeliveryPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _formNumberController = TextEditingController();
  DateTime? _selectedPostDate;
  final TextEditingController _postDateController = TextEditingController();

  DocumentReference? _selectedStore;
  DocumentReference? _selectedWarehouse;
  List<DocumentSnapshot> _stores = [];
  List<DocumentSnapshot> _warehouses = [];
  List<DocumentSnapshot> _products = [];

  final List<_DetailItem> _productDetails = [];

  int get itemTotal => _productDetails.fold(0, (sum, item) => sum + item.qty);
  int get grandTotal => _productDetails.fold(0, (sum, item) => sum + item.subtotal);

  final rupiahFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
    _generateFormNumber();
  }

  Future<void> _fetchDropdownData() async {
    final prefs = await SharedPreferences.getInstance();
    final storeRefPath = prefs.getString('store_ref');
    if (storeRefPath == null) return;
    final storeRef = FirebaseFirestore.instance.doc(storeRefPath);

    final storesQuery = await FirebaseFirestore.instance.collection('stores').get();
    final stores = storesQuery.docs.where((doc) => doc.reference.path != storeRef.path).toList();

    final warehouses = await FirebaseFirestore.instance.collection('warehouses').where('store_ref', isEqualTo: storeRef).get();
    final products = await FirebaseFirestore.instance.collection('products').where('store_ref', isEqualTo: storeRef).get();

    final generatedFormNo = await _generateFormNumber();

    if (!mounted) return;
    setState(() {
      _stores = stores;
      _warehouses = warehouses.docs;
      _products = products.docs;
      _formNumberController.text = generatedFormNo;
    });
  }

  Future<String> _generateFormNumber() async {
    final receipts = await FirebaseFirestore.instance
        .collection('deliveries')
        .orderBy('created_at', descending: true)
        .get();

    int maxNumber = 0;
    final base = 'TTJ22100034';

    for (var doc in receipts.docs) {
      final lastForm = doc['no_form'];
      final parts = lastForm.split('_');
      if (parts.length == 2) {
        final number = int.tryParse(parts[1]) ?? 0;
        if (number > maxNumber) {
          maxNumber = number;
        }
      }
    }

    final nextNumber = maxNumber + 1;
    return '${base}_$nextNumber';
  }

  Future<void> _saveDelivery() async {
    if (!_formKey.currentState!.validate() ||
        _selectedStore == null ||
        _selectedWarehouse == null ||
        _productDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Harap lengkapi semua data yang diperlukan."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final storeRefPath = prefs.getString('store_ref');
    if (storeRefPath == null) return;
    final storeRef = FirebaseFirestore.instance.doc(storeRefPath);

    final deliveryData = {
      'no_form': _formNumberController.text.trim(),
      'grandtotal': grandTotal,
      'item_total': itemTotal,
      'post_date': _selectedPostDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'created_at': DateTime.now(),
      'store_ref': storeRef,
      'destination_store_ref': _selectedStore,
      'warehouse_ref': _selectedWarehouse,
      'synced': true,
    };

    final deliveryDoc = await FirebaseFirestore.instance.collection('deliveries').add(deliveryData);

    for (final item in _productDetails) {
      await deliveryDoc.collection('details').add(item.toMap());

      if (item.productRef != null && _selectedWarehouse != null) {
        final stockQuery = await FirebaseFirestore.instance
            .collection('stocks')
            .where('product_ref', isEqualTo: item.productRef)
            .where('warehouse_ref', isEqualTo: _selectedWarehouse)
            .limit(1)
            .get();

        if (stockQuery.docs.isNotEmpty) {
          final stockDoc = stockQuery.docs.first;
          final stockRef = stockDoc.reference;
          final stockData = stockDoc.data();
          final stockQty = stockData['qty'] ?? 0;

          if (stockQty == item.qty) {
            await stockRef.delete();
          } else if (stockQty > item.qty) {
            await stockRef.update({'qty': stockQty - item.qty});
          } else {
            print('Warning: Stock qty (${stockQty}) < delivery qty (${item.qty}) for product ${item.productRef!.id}');
          }
        } else {
          print('Warning: No stock found for product ${item.productRef!.id} in selected warehouse');
        }

        final productSnap = await item.productRef!.get();
        final currentQty = productSnap['qty'] ?? 0;
        await item.productRef!.update({
          'qty': currentQty - item.qty,
        });
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Delivery berhasil ditambah."),
        backgroundColor: Colors.green,
      ),
    );

    if (mounted) Navigator.pop(context);
  }

  void _addProductRow() {
    setState(() {
      _productDetails.add(_DetailItem(products: _products));
    });
  }

  void _removeProductRow(int index) {
    setState(() {
      _productDetails.removeAt(index);
    });
  }

  Future<void> _selectPostDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedPostDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue, 
              onPrimary: Colors.white, 
              onSurface: Colors.black, 
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPostDate = picked;
        _postDateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Delivery Baru'),
        elevation: 0,
      ),
      body: _products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Informasi Utama", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.blue[800])),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _formNumberController,
                            decoration: _buildInputDecoration('No. Form', icon: Icons.article_outlined),
                            readOnly: true,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<DocumentReference>(
                            items: _stores.map((doc) {
                              return DropdownMenuItem(value: doc.reference, child: Text(doc['name']));
                            }).toList(),
                            onChanged: (value) => setState(() => _selectedStore = value),
                            decoration: _buildInputDecoration("Store Tujuan", icon: Icons.store_mall_directory_outlined),
                            validator: (value) => value == null ? 'Pilih store tujuan' : null,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<DocumentReference>(
                            items: _warehouses.map((doc) {
                              return DropdownMenuItem(value: doc.reference, child: Text(doc['name']));
                            }).toList(),
                            onChanged: (value) => setState(() => _selectedWarehouse = value),
                            decoration: _buildInputDecoration("Warehouse Asal", icon: Icons.warehouse_outlined),
                            validator: (value) => value == null ? 'Pilih warehouse asal' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _postDateController,
                            decoration: _buildInputDecoration('Tanggal Post', icon: Icons.calendar_today_outlined),
                            readOnly: true,
                            onTap: () => _selectPostDate(context),
                            validator: (value) => value == null || value.isEmpty ? 'Pilih tanggal post' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text("Detail Produk", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.blue[800])),
                  const SizedBox(height: 8),
                  if (_productDetails.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: Text(
                          "Belum ada produk. Klik tombol di bawah untuk menambahkan.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),

                  ..._productDetails.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            DropdownButtonFormField<DocumentReference>(
                              value: item.productRef,
                              items: _products.map((doc) => DropdownMenuItem(value: doc.reference, child: Text(doc['name']))).toList(),
                              onChanged: (value) async {
                                 if (value != null && _selectedWarehouse != null) {
                                  final stockQuery = await FirebaseFirestore.instance
                                      .collection('stocks')
                                      .where('product_ref', isEqualTo: value)
                                      .where('warehouse_ref', isEqualTo: _selectedWarehouse)
                                      .limit(1)
                                      .get();
                              
                                  int stockQty = 0;
                                  if (stockQuery.docs.isNotEmpty) {
                                    final stockData = stockQuery.docs.first.data();
                                    stockQty = stockData['qty'] ?? 0;
                                  }
                              
                                  setState(() {
                                    item.productRef = value;
                                    item.unitName = 'pcs';
                                    item.unitController.text = item.unitName;
                                    item.availableStock = stockQty;
                                  });
                                }
                              },
                              decoration: _buildInputDecoration("Produk"),
                              validator: (value) => value == null ? 'Pilih produk' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              initialValue: item.price.toString(),
                              decoration: _buildInputDecoration("Harga", icon: Icons.price_change_outlined),
                              keyboardType: TextInputType.number,
                              onChanged: (val) => setState(() => item.price = int.tryParse(val) ?? 0),
                              validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              initialValue: item.qty.toString(),
                              decoration: _buildInputDecoration(
                                "Jumlah",
                                icon: Icons.format_list_numbered,
                                suffix: "/ Stok: ${item.availableStock}",
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (val) => setState(() => item.qty = int.tryParse(val) ?? 1),
                              validator: (val) {
                                final inputQty = int.tryParse(val ?? '') ?? 0;
                                if (val!.isEmpty) return 'Wajib diisi';
                                if (inputQty <= 0) return 'Qty min 1';
                                if (inputQty > item.availableStock) return 'Qty melebihi stok!';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text("Subtotal: ${rupiahFormat.format(item.subtotal)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const Divider(height: 20),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _removeProductRow(index),
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                label: const Text("Hapus", style: TextStyle(color: Colors.red)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _addProductRow,
                    icon: const Icon(Icons.add_shopping_cart_outlined),
                    label: const Text('Tambah Produk'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Total Item:", style: TextStyle(fontSize: 16)),
                              Text("$itemTotal", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Grand Total:", style: Theme.of(context).textTheme.titleMedium),
                              Text(rupiahFormat.format(grandTotal), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.blue[800], fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
      persistentFooterButtons: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ElevatedButton.icon(
            onPressed: _saveDelivery,
            icon: const Icon(Icons.save_alt_outlined),
            label: const Text('Simpan Delivery'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        )
      ],
    );
  }

  InputDecoration _buildInputDecoration(String label, {IconData? icon, String? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: Colors.blue[700]) : null,
      suffixText: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
    );
  }
}
// --- PERUBAHAN GAYA DESAIN SELESAI ---

class _DetailItem {
  DocumentReference? productRef;
  int price = 0;
  int qty = 1;
  String unitName = 'unit';
  int availableStock = 0;
  TextEditingController unitController = TextEditingController();
  final List<DocumentSnapshot> products;

  _DetailItem({required this.products});

  int get subtotal => price * qty;

  Map<String, dynamic> toMap() {
    return {
      'product_ref': productRef,
      'price': price,
      'qty': qty,
      'unit_name': unitController.text.trim(),
      'subtotal': subtotal,
    };
  }
}