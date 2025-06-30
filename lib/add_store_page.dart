import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddStorePage extends StatefulWidget{
  const AddStorePage({super.key});

  @override
  _AddStorePageState createState() => _AddStorePageState();
}

class _AddStorePageState extends State<AddStorePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nimController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  

  void _saveStore() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      final code = _nimController.text.trim();
      final name = _nameController.text.trim();

      final querySnapshot = await FirebaseFirestore.instance
          .collection('stores')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Store dengan kode tersebut tidak ditemukan.")),
        );
        return;
      }

      final storeDoc = querySnapshot.docs.first;
  
      await prefs.setString('code', code);
      await prefs.setString('name', name);
      await prefs.setString('store_ref', storeDoc.reference.path);

      if (mounted) Navigator.pop(context);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Tambah Toko")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nimController,
                decoration: InputDecoration(labelText: "Kode Toko"),
                validator: (value) =>
                  value!.isEmpty ? 'NIM tidak boleh kosong' : null,
              ),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: "Nama Toko"),
                validator: (value) =>
                  value!.isEmpty ? 'Nama Toko tidak boleh kosong' : null,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveStore,
                child: Text('Simpan Toko'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}