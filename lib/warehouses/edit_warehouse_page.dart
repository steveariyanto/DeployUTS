import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditWarehouseModal extends StatefulWidget {
  final DocumentReference warehouseRef;

  const EditWarehouseModal({
    super.key,
    required this.warehouseRef,
  });

  @override
  State<EditWarehouseModal> createState() => _EditWarehouseModalState();
}

class _EditWarehouseModalState extends State<EditWarehouseModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _warehouseNameController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWarehouseData();
  }

  Future<void> _loadWarehouseData() async {
    try {
      final doc = await widget.warehouseRef.get();
      if (!mounted) return;
      final data = doc.data() as Map<String, dynamic>?;
      _warehouseNameController.text = data?['name'] ?? '';
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat data warehouse'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
  
  Future<void> _updateWarehouse() async {
    if (!_formKey.currentState!.validate()) return;

    await widget.warehouseRef.update({
      'name': _warehouseNameController.text.trim(),
      'updated_at': DateTime.now(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Warehouse berhasil diedit."), backgroundColor: Colors.green),
    );

    Navigator.pop(context, 'updated');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Warehouse'),
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
                            "Informasi Warehouse",
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.blue[800]),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _warehouseNameController,
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
      persistentFooterButtons: _loading
          ? null
          : [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton.icon(
                  onPressed: _updateWarehouse,
                  icon: const Icon(Icons.save_as_outlined),
                  label: const Text('Update Warehouse'),
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