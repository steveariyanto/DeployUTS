import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddWarehousePage extends StatefulWidget {
  const AddWarehousePage({super.key});

  @override
  State<AddWarehousePage> createState() => _AddWarehousePageState();
}

class _AddWarehousePageState extends State<AddWarehousePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _warehouseController = TextEditingController();

  void _saveWarehouse() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();

      final storeRefPath = prefs.getString('store_ref');
      if (storeRefPath == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Store reference not found."), backgroundColor: Colors.red),
        );
        return;
      }

      final storeRef = FirebaseFirestore.instance.doc(storeRefPath);

      await FirebaseFirestore.instance.collection('warehouses').add({
        'name': _warehouseController.text.trim(),
        'store_ref': storeRef,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Warehouse berhasil ditambahkan."), backgroundColor: Colors.green),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tambah Warehouse Baru"),
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
                      "Informasi Warehouse",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.blue[800]),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _warehouseController,
                      decoration: _buildInputDecoration('Nama Warehouse', icon: Icons.warehouse_outlined),
                      validator: (value) => value == null || value.isEmpty ? 'Nama warehouse wajib diisi' : null,
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
            onPressed: _saveWarehouse,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Simpan Warehouse'),
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