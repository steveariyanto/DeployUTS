import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; 

class AddReceiptPage extends StatefulWidget {
  const AddReceiptPage({super.key});

  @override
  State<AddReceiptPage> createState() => _AddReceiptPageState();
}

class _AddReceiptPageState extends State<AddReceiptPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _formNumberController = TextEditingController();
  DateTime? _selectedPostDate;
  final TextEditingController _postDateController = TextEditingController();

  DocumentReference? _selectedSupplier;
  DocumentReference? _selectedWarehouse;
  List<DocumentSnapshot> _suppliers = [];
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
  }

  Future<void> _fetchDropdownData() async {
    final prefs = await SharedPreferences.getInstance();
    final storeRefPath = prefs.getString('store_ref');
    if (storeRefPath == null) return;
    final storeRef = FirebaseFirestore.instance.doc(storeRefPath);

    final suppliers = await FirebaseFirestore.instance.collection('suppliers').where('store_ref', isEqualTo: storeRef).get();
    final warehouses = await FirebaseFirestore.instance.collection('warehouses').where('store_ref', isEqualTo: storeRef).get();
    final products = await FirebaseFirestore.instance.collection('products').where('store_ref', isEqualTo: storeRef).get();

    final generatedFormNo = await _generateFormNumber();

    if (!mounted) return;
    setState(() {
      _suppliers = suppliers.docs;
      _warehouses = warehouses.docs;
      _products = products.docs;
      _formNumberController.text = generatedFormNo;
    });
  }

  Future<String> _generateFormNumber() async {
    final receipts = await FirebaseFirestore.instance
        .collection('purchaseGoodsReceipts')
        .orderBy('created_at', descending: true)
        .limit(1) 
        .get();
    int nextNumber = 1;
    final base = 'TTB22100034';
    if (receipts.docs.isNotEmpty) {
      final lastForm = receipts.docs.first['no_form'];
      final parts = lastForm.split('_');
      if (parts.length == 2) {
        final number = int.tryParse(parts[1]) ?? 0;
        nextNumber = number + 1;
      }
    }
    return '${base}_$nextNumber';
  }

  Future<void> _saveReceipt() async {
    if (!_formKey.currentState!.validate() ||
        _selectedSupplier == null ||
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

    final receiptData = {
      'no_form': _formNumberController.text.trim(),
      'grandtotal': grandTotal,
      'item_total': itemTotal,
      'post_date': _selectedPostDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'created_at': DateTime.now(),
      'store_ref': storeRef,
      'supplier_ref': _selectedSupplier,
      'warehouse_ref': _selectedWarehouse,
      'synced': true,
    };

    final receiptDoc = await FirebaseFirestore.instance.collection('purchaseGoodsReceipts').add(receiptData);

    for (final item in _productDetails) {
      await receiptDoc.collection('details').add(item.toMap());

      if (item.productRef != null) {
        final productSnap = await item.productRef!.get();
        final currentQty = productSnap['qty'] ?? 0;
        await item.productRef!.update({
          'qty': currentQty + item.qty,
        });
      }

      final stockQuery = await FirebaseFirestore.instance
          .collection('stocks')
          .where('warehouse_ref', isEqualTo: _selectedWarehouse)
          .where('product_ref', isEqualTo: item.productRef)
          .get();

      if (stockQuery.docs.isNotEmpty) {
        final stockDoc = stockQuery.docs.first;
        final currentStock = stockDoc['qty'] ?? 0;
        await stockDoc.reference.update({'qty': currentStock + item.qty});
      } else {
        await FirebaseFirestore.instance.collection('stocks').add({
          'store_ref': storeRef,
          'warehouse_ref': _selectedWarehouse,
          'product_ref': item.productRef,
          'qty': item.qty,
        });
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Receipt berhasil ditambah."), backgroundColor: Colors.green),
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
        title: const Text('Tambah Tanda Terima'),
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
                            items: _suppliers.map((doc) => DropdownMenuItem(value: doc.reference, child: Text(doc['name']))).toList(),
                            onChanged: (value) => setState(() => _selectedSupplier = value),
                            decoration: _buildInputDecoration("Supplier", icon: Icons.person_outline),
                            validator: (value) => value == null ? 'Pilih supplier' : null,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<DocumentReference>(
                            items: _warehouses.map((doc) => DropdownMenuItem(value: doc.reference, child: Text(doc['name']))).toList(),
                            onChanged: (value) => setState(() => _selectedWarehouse = value),
                            decoration: _buildInputDecoration("Terima di Warehouse", icon: Icons.warehouse_outlined),
                            validator: (value) => value == null ? 'Pilih warehouse' : null,
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
                      child: Center(child: Text("Belum ada produk.", style: TextStyle(color: Colors.grey))),
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
                              onChanged: (value) {
                                setState(() {
                                  item.productRef = value;
                                  if (value != null) {
                                    final selectedProduct = _products.firstWhere((doc) => doc.reference == value);
                                    final defaultPrice = selectedProduct['default_price'] ?? 0;
                                    item.priceController.text = defaultPrice.toString();
                                  }
                                });
                              },
                              decoration: _buildInputDecoration("Produk"),
                              validator: (value) => value == null ? 'Pilih produk' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: item.priceController,
                              decoration: _buildInputDecoration("Harga", icon: Icons.price_change_outlined),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              validator: (val) => val == null || val.isEmpty ? 'Harga wajib diisi' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: item.qtyController,
                              decoration: _buildInputDecoration("Jumlah", icon: Icons.format_list_numbered),
                              keyboardType: TextInputType.number,
                              onChanged: (val) => setState(() => item.qty = int.tryParse(val) ?? 1),
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'Qty wajib diisi';
                                if ((int.tryParse(val) ?? 0) <= 0) return 'Qty min 1';
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
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            onPressed: _saveReceipt,
            icon: const Icon(Icons.save_alt_outlined),
            label: const Text('Simpan Tanda Terima'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        )
      ],
    );
  }

  InputDecoration _buildInputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: Colors.blue[700]) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
      filled: true,
      fillColor: Colors.white,
    );
  }
}

class _DetailItem {
  DocumentReference? productRef;
  int qty = 1;
  final List<DocumentSnapshot> products;

  TextEditingController priceController = TextEditingController();
  TextEditingController qtyController = TextEditingController(text: '1');
  
  _DetailItem({required this.products});

  int get price => int.tryParse(priceController.text) ?? 0;
  int get subtotal => price * qty;

  Map<String, dynamic> toMap() {
    return {
      'product_ref': productRef,
      'price': price,
      'qty': qty,
      'unit_name': 'pcs',
      'subtotal': subtotal,
    };
  }
}