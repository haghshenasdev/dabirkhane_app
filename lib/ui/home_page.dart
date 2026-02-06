import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../db/database_helper.dart';
import 'record_form.dart';

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> records = [];
  List<Map<String, dynamic>> filtered = [];
  String query = '';
  
  VoidCallback? get exportDb => null;
  
  VoidCallback? get importDb => null;

  Future<void> load() async {
    records = await DatabaseHelper.getAll();
    applyFilter();
  }

  void applyFilter() {
    filtered = records.where((r) {
      final q = query.toLowerCase();
      return (r['onvan'] ?? '').toString().toLowerCase().contains(q) ||
          (r['saheb_name'] ?? '').toString().toLowerCase().contains(q) ||
          r['Shomare_Radif'].toString().contains(q);
    }).toList();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('دبیرخانه'),
        actions: [
          IconButton(
            icon: Icon(Icons.upload_file),
            onPressed: importDb,
          ),
          IconButton(
            icon: Icon(Icons.download),
            onPressed: exportDb,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () async {
          final r = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RecordForm()),
          );
          if (r == true) load();
        },
      ),
      body: Column(
        children: [
          // 🔍 سرچ
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'جستجو...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                query = v;
                applyFilter();
              },
            ),
          ),

          // 📄 لیست
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final r = filtered[i];
                return ListTile(
                  title: Text(r['onvan'] ?? ''),
                  subtitle: Text('تاریخ: ${r['date'] ?? ''}'),
                  trailing: Text('${r['Shomare_Radif']}'),
                  onTap: () async {
                    final res = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecordForm(record: r),
                      ),
                    );
                    if (res == true) load();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

