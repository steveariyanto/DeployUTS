import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditSupplierModal extends StatefulWidget {
  final DocumentReference supplierRef;

  const EditSupplierModal({
    super.key,
    required this.supplierRef,
  });

  @override
  State<EditSupplierModal> createState() => _EditSupplierModalState();
}

class _EditSupplierModalState extends State<EditSupplierModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _supplierNameController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSupplierData();
  }

  Future<void> _loadSupplierData() async {
    try {
      final doc = await widget.supplierRef.get();
      if (!mounted) return;
      final data = doc.data() as Map<String, dynamic>?;
      _supplierNameController.text = data?['name'] ?? '';
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat data supplier'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _updateSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    await widget.supplierRef.update({
      'name': _supplierNameController.text.trim(),
      'updated_at': DateTime.now(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Supplier berhasil diperbarui."), backgroundColor: Colors.green),
    );
    Navigator.pop(context, 'updated');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Supplier'),
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
                            "Informasi Supplier",
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.blue[800]),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _supplierNameController,
                            decoration: _buildInputDecoration('Nama Supplier', icon: Icons.person_outline),
                            validator: (value) => value == null || value.isEmpty ? 'Nama supplier wajib diisi' : null,
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
                  onPressed: _updateSupplier,
                  icon: const Icon(Icons.save_as_outlined),
                  label: const Text('Update Supplier'),
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