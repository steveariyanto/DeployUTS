import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProductModal extends StatefulWidget {
  final DocumentReference productRef;

  const EditProductModal({
    super.key,
    required this.productRef,
  });

  @override
  State<EditProductModal> createState() => _EditProductModalState();
}

class _EditProductModalState extends State<EditProductModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProductData();
  }

  Future<void> _loadProductData() async {
    try {
      final doc = await widget.productRef.get();
      if (!mounted) return;
      final data = doc.data() as Map<String, dynamic>?;
      _productNameController.text = data?['name'] ?? '';
      _priceController.text = (data?['default_price']?.toString() ?? '');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat data produk'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) return;

    await widget.productRef.update({
      'name': _productNameController.text.trim(),
      'default_price': int.tryParse(_priceController.text.trim()) ?? 0,
      'updated_at': DateTime.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Produk berhasil diperbarui."), backgroundColor: Colors.green),
    );

    if (mounted) {
      Navigator.pop(context, 'updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Produk'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Informasi Produk",
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.blue[800]),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _productNameController,
                            decoration: _buildInputDecoration('Nama Produk', icon: Icons.shopping_bag_outlined),
                            validator: (value) => value == null || value.isEmpty ? 'Nama produk wajib diisi' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _priceController,
                            decoration: _buildInputDecoration('Harga Default', icon: Icons.price_change_outlined),
                            keyboardType: TextInputType.number,
                            validator: (value) => value == null || value.isEmpty ? 'Harga wajib diisi' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      persistentFooterButtons: _loading
          ? null
          : [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton.icon(
                  onPressed: _updateProduct,
                  icon: const Icon(Icons.save_as_outlined),
                  label: const Text('Update Produk'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
    );
  }

  InputDecoration _buildInputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: Colors.blue[700]) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}