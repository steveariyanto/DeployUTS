import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class EditReceiptModal extends StatefulWidget {
  final DocumentReference receiptRef;
  final Map<String, dynamic> receiptData;

  const EditReceiptModal({
    super.key,
    required this.receiptRef,
    required this.receiptData,
  });

  @override
  State<EditReceiptModal> createState() => _EditReceiptModalState();
}

class _EditReceiptModalState extends State<EditReceiptModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _formNumberController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  DateTime? _selectedDate;

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
    _formNumberController.text = widget.receiptData['no_form'] ?? '';
    _selectedSupplier = widget.receiptData['supplier_ref'];
    _selectedWarehouse = widget.receiptData['warehouse_ref'];

    if (widget.receiptData['post_date'] != null) {
      _selectedDate = DateTime.tryParse(widget.receiptData['post_date']);
      if (_selectedDate != null) {
        _dateController.text = _formatDate(_selectedDate!);
      }
    }

    _fetchDropdownData();
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _fetchDropdownData() async {
    final prefs = await SharedPreferences.getInstance();
    final storeRefPath = prefs.getString('store_ref');
    if (storeRefPath == null) return;
    final storeRef = FirebaseFirestore.instance.doc(storeRefPath);

    final suppliers = await FirebaseFirestore.instance.collection('suppliers').where('store_ref', isEqualTo: storeRef).get();
    final warehouses = await FirebaseFirestore.instance.collection('warehouses').where('store_ref', isEqualTo: storeRef).get();
    final products = await FirebaseFirestore.instance.collection('products').where('store_ref', isEqualTo: storeRef).get();
    final detailsSnapshot = await widget.receiptRef.collection('details').get();

    if (!mounted) return;
    setState(() {
      _suppliers = suppliers.docs;
      _warehouses = warehouses.docs;
      _products = products.docs;
      _productDetails.clear();
      for (var doc in detailsSnapshot.docs) {
        _productDetails.add(_DetailItem.fromMap(doc.data(), _products, doc.reference));
      }
    });
  }

  void _updateReceipt() async {
    if (!_formKey.currentState!.validate() ||
        _selectedSupplier == null ||
        _selectedWarehouse == null ||
        _productDetails.isEmpty) { return; }

    final detailsRef = widget.receiptRef.collection('details');
    final firestore = FirebaseFirestore.instance;

    final oldDetailsSnapshot = await detailsRef.get();
    final oldQuantities = <String, int>{};

    for (var doc in oldDetailsSnapshot.docs) {
      final data = doc.data();
      final productRef = (data['product_ref'] as DocumentReference).id;
      final qty = (data['qty'] ?? 0);
      oldQuantities[productRef] = (oldQuantities[productRef] ?? 0) + (qty as num).toInt();
    }

    for (var doc in oldDetailsSnapshot.docs) {
      await doc.reference.delete();
    }

    final newQuantities = <String, int>{};

    for (var item in _productDetails) {
      final refId = item.productRef!.id;
      newQuantities[refId] = (newQuantities[refId] ?? 0) + item.qty;

      await item.productRef!.update({'default_price': item.price});
      await detailsRef.add(item.toMap());
    }

    for (var productRefId in {...oldQuantities.keys, ...newQuantities.keys}) {
      final oldQty = oldQuantities[productRefId] ?? 0;
      final newQty = newQuantities[productRefId] ?? 0;
      final qtyDiff = newQty - oldQty;

      if (qtyDiff == 0) continue;

      final stockQuery = await firestore
          .collection('stocks')
          .where('product_ref', isEqualTo: firestore.doc('products/$productRefId'))
          .where('warehouse_ref', isEqualTo: _selectedWarehouse)
          .limit(1)
          .get();

      final productDocRef = firestore.doc('products/$productRefId');

      if (stockQuery.docs.isNotEmpty) {
        final stockDoc = stockQuery.docs.first.reference;
        await firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(stockDoc);
          final currentQty = snapshot['qty'] ?? 0;
          transaction.update(stockDoc, {'qty': currentQty + qtyDiff});
        });
      } else {
        await firestore.collection('stocks').add({
          'product_ref': firestore.doc('products/$productRefId'),
          'warehouse_ref': _selectedWarehouse,
          'qty': qtyDiff,
        });
      }

      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(productDocRef);
        final currentQty = snapshot['qty'] ?? 0;
        transaction.update(productDocRef, {'qty': currentQty + qtyDiff});
      });
    }

    await widget.receiptRef.update({
      'no_form': _formNumberController.text.trim(),
      'supplier_ref': _selectedSupplier,
      'warehouse_ref': _selectedWarehouse,
      'item_total': itemTotal,
      'grandtotal': grandTotal,
      'updated_at': DateTime.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Receipt berhasil diedit."), backgroundColor: Colors.green),
    );

    if (mounted) {
      Navigator.pop(context, 'updated');
    }
  }

  void _removeProductRow(int index) {
    setState(() => _productDetails.removeAt(index));
  }

  void _addProductRow() {
    setState(() => _productDetails.add(_DetailItem(products: _products)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Tanda Terima'), elevation: 0),
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
                            validator: (value) => value!.isEmpty ? 'Wajib diisi' : null,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<DocumentReference>(
                            value: _selectedSupplier,
                            items: _suppliers.map((doc) => DropdownMenuItem(value: doc.reference, child: Text(doc['name']))).toList(),
                            onChanged: (value) => setState(() => _selectedSupplier = value),
                            decoration: _buildInputDecoration("Supplier", icon: Icons.person_outline),
                            validator: (value) => value == null ? 'Pilih supplier' : null,
                          ),
                          const SizedBox(height: 16),
                           DropdownButtonFormField<DocumentReference>(
                            value: _selectedWarehouse,
                            items: _warehouses.map((doc) => DropdownMenuItem(value: doc.reference, child: Text(doc['name']))).toList(),
                            onChanged: (value) => setState(() => _selectedWarehouse = value),
                            decoration: _buildInputDecoration("Warehouse", icon: Icons.warehouse_outlined),
                            validator: (value) => value == null ? 'Pilih warehouse' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text("Detail Produk", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.blue[800])),
                  const SizedBox(height: 8),
                  
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
                              onChanged: (value) => setState(() => item.productRef = value),
                              decoration: _buildInputDecoration("Produk"),
                              validator: (value) => value == null ? 'Pilih produk' : null,
                            ),
                             const SizedBox(height: 12),
                            TextFormField(
                              controller: item.priceController,
                              decoration: _buildInputDecoration("Harga", icon: Icons.price_change_outlined),
                              keyboardType: TextInputType.number,
                              onChanged: (val) => setState(() => item.price = int.tryParse(val) ?? 0),
                              validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
                            ),
                             const SizedBox(height: 12),
                            TextFormField(
                              controller: item.qtyController,
                              decoration: _buildInputDecoration("Jumlah", icon: Icons.format_list_numbered),
                              keyboardType: TextInputType.number,
                              onChanged: (val) => setState(() => item.qty = int.tryParse(val) ?? 1),
                              validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
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
                ],
              ),
            ),
      persistentFooterButtons: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            onPressed: _updateReceipt,
            icon: const Icon(Icons.save_as_outlined),
            label: const Text('Update Tanda Terima'),
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
  int price;
  int qty;
  final List<DocumentSnapshot> products;
  final DocumentReference? docRef;

  late TextEditingController priceController;
  late TextEditingController qtyController;

  _DetailItem({
    this.productRef,
    this.price = 0,
    this.qty = 1,
    required this.products,
    this.docRef,
  }) {
    priceController = TextEditingController(text: price.toString());
    qtyController = TextEditingController(text: qty.toString());
  }

  factory _DetailItem.fromMap(Map<String, dynamic> data, List<DocumentSnapshot> products, DocumentReference ref) {
    return _DetailItem(
      productRef: data['product_ref'],
      price: data['price'],
      qty: data['qty'],
      products: products,
      docRef: ref,
    );
  }

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