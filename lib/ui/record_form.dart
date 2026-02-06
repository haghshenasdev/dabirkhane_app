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

  // فیلدهای اصلی که میخوایم مستقیم نمایش داده شوند (غیر از "سایر اطلاعات")
  final mainFields = [
    'date',
    'saheb_name',
    'guy',
    'sh_name_reside',
    't_name_ersali',
    'onvan',
  ];

  // فیلدهای داخل بخش "سایر اطلاعات" به صورت کلبس
  final otherFields = [
    'goshashte',
    'from_pywa',
    't_name_reside',
    'comment',
    'shomare_badi',
    'wordmost2',
    'adres_name',
  ];

  final Map<String, String> fieldLabels = {
    'goshashte': 'شماره بعدی',
    'date': 'تاریخ',
    'saheb_name': 'صاحب نامه',
    'guy': 'موضوع',
    'from_pywa': 'از پیوا',
    'sh_name_reside': 'نام ساکن',
    't_name_reside': 'نام تحویل گیرنده',
    'onvan': 'نتیجه',
    'comment': 'توضیحات',
    'shomare_badi': 'شماره بعدی',
    'wordmost2': 'کلمه مهم ۲',
    't_name_ersali': 'نام ارسال کننده',
    'adres_name': 'آدرس',
  };

  @override
  void initState() {
    super.initState();
    for (var f in [...mainFields, ...otherFields]) {
      c[f] = TextEditingController(text: widget.record?[f] ?? '');
    }
  }

  @override
  void dispose() {
    for (var controller in c.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      for (var f in [...mainFields, ...otherFields]) f: c[f]!.text,
    };

    if (widget.record == null) {
      await DatabaseHelper.insert(data);
    } else {
      await DatabaseHelper.update(widget.record!['Shomare_Radif'], data);
    }

    Navigator.pop(context, true);
  }

  Widget buildTextField(String field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c[field],
        decoration: InputDecoration(
          labelText: fieldLabels[field] ?? field,
          border: OutlineInputBorder(),
        ),
        textDirection: TextDirection.rtl,
      ),
    );
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
            // فیلدهای اصلی
            ...mainFields.map(buildTextField),

            // کلبس بسته "سایر اطلاعات"
            ExpansionTile(
              title: Text('سایر اطلاعات'),
              children: otherFields.map(buildTextField).toList(),
            ),

            SizedBox(height: 20),

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
