import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  void _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();

      final storeRefPath = prefs.getString('store_ref');
      if (storeRefPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Store reference not found."), backgroundColor: Colors.red),
        );
        return;
      }

      final storeRef = FirebaseFirestore.instance.doc(storeRefPath);

      await FirebaseFirestore.instance.collection('products').add({
        'name': _productController.text.trim(),
        'qty': 0,
        'default_price': int.tryParse(_priceController.text.trim()) ?? 0,
        'store_ref': storeRef,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Produk berhasil ditambahkan."), backgroundColor: Colors.green),
      );

      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tambah Produk Baru"),
        elevation: 0,
      ),
      body: ListView(
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
                      controller: _productController,
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
      persistentFooterButtons: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            onPressed: _saveProduct,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Simpan Produk'),
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