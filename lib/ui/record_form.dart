import 'package:flutter/material.dart';
import '../db/database_helper.dart';

class RecordForm extends StatefulWidget {
  final Map<String, dynamic>? record;

  RecordForm({this.record});

  @override
  State<RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<RecordForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> c = {};

  final fields = [
    'goshashte',
    'date',
    'saheb_name',
    'guy',
    'from_pywa',
    'sh_name_reside',
    't_name_reside',
    'onvan',
    'comment',
    'shomare_badi',
    'wordmost2',
    't_name_ersali',
    'adres_name',
  ];

  @override
  void initState() {
    super.initState();
    for (var f in fields) {
      c[f] = TextEditingController(text: widget.record?[f] ?? '');
    }
  }

  Future<void> save() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {for (var f in fields) f: c[f]!.text};

    if (widget.record == null) {
      await DatabaseHelper.insert(data);
    } else {
      await DatabaseHelper.update(widget.record!['Shomare_Radif'], data);
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.record == null ? 'ثبت نامه' : 'ویرایش نامه'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(12),
          children: [
            ...fields.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextFormField(
                controller: c[f],
                decoration: InputDecoration(
                  labelText: f,
                  border: OutlineInputBorder(),
                ),
              ),
            )),
            ElevatedButton(
              onPressed: save,
              child: Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
  }
}
