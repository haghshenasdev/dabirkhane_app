import 'dart:async';
import 'package:dabirkhane_app/utils/JalaliDateFormatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db/database_helper.dart';
import 'package:shamsi_date/shamsi_date.dart';

class RecordForm extends StatefulWidget {
  final Map<String, dynamic>? record;
  RecordForm({this.record});

  @override
  State<RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<RecordForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> c = {};
  Map<String, dynamic>? lastRecord;
  String? lastInfoText;
  List<String> guySuggestions = [];
  List<String> onvanSuggestions = [];
  Timer? _debounceGuy;
  Timer? _debounceOnvan;
  final Map<String, FocusNode> focusNodes = {};

  final mainFields = [
    'guy',
    'saheb_name',
    'date',
    'sh_name_reside',
    't_name_ersali',
    'onvan',
  ];

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
    'sh_name_reside': 'شماره تماس',
    't_name_reside': 'نام تحویل گیرنده',
    'onvan': 'نتیجه',
    'comment': 'توضیحات',
    'shomare_badi': 'شماره بعدی',
    'wordmost2': 'کلمه مهم ۲',
    't_name_ersali': 'نام ارسال کننده',
    'adres_name': 'آدرس',
  };

  List<String> sahebSuggestions = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    for (var f in [...mainFields, ...otherFields]) {
      c[f] = TextEditingController(text: widget.record?[f] ?? '');
      focusNodes[f] = FocusNode();
    }

    // تاریخ پیش‌فرض شمسی امروز
    if (widget.record == null) {
      final now = Jalali.now();
      c['date']!.text =
          '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (var controller in c.values) {
      controller.dispose();
    }
    for (var node in focusNodes.values) {
      node.dispose();
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

  Widget buildGuyField() {
    return buildSimpleAutoCompleteField(
      field: 'guy',
      label: 'موضوع',
      suggestions: guySuggestions,
      onChanged: (value) {
        _debounceGuy?.cancel();
        _debounceGuy = Timer(const Duration(milliseconds: 300), () async {
          if (value.trim().isEmpty) {
            setState(() => guySuggestions.clear());
            return;
          }
          final res = await DatabaseHelper.searchDistinctField(
            'guy',
            value.trim(),
          );
          setState(() => guySuggestions = res);
        });
      },
      onSelected: (item) {
        c['guy']!.text = item;
        setState(() => guySuggestions.clear());
      },
      focusNode: focusNodes['guy']!,
      nextFocus: focusNodes['saheb_name'],
    );
  }

  Widget buildOnvanField() {
    return buildSimpleAutoCompleteField(
      field: 'onvan',
      label: 'نتیجه',
      suggestions: onvanSuggestions,
      onChanged: (value) {
        _debounceOnvan?.cancel();
        _debounceOnvan = Timer(const Duration(milliseconds: 300), () async {
          if (value.trim().isEmpty) {
            setState(() => onvanSuggestions.clear());
            return;
          }
          final res = await DatabaseHelper.searchDistinctField(
            'onvan',
            value.trim(),
          );
          setState(() => onvanSuggestions = res);
        });
      },
      onSelected: (item) {
        c['onvan']!.text = item;
        setState(() => onvanSuggestions.clear());
      },
      focusNode: focusNodes['onvan']!,
      nextFocus: null, // فرض کنیم آخرین فیلد هست
    );
  }

  Widget buildSimpleAutoCompleteField({
    required String field,
    required String label,
    required List<String> suggestions,
    required void Function(String) onChanged,
    required void Function(String) onSelected,
    required FocusNode focusNode,
    FocusNode? nextFocus,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: c[field],
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(),
          ),
          textDirection: TextDirection.rtl,
          onChanged: onChanged,
          onFieldSubmitted: (_) {
            // وقتی اینتر زده شد:
            if (suggestions.isNotEmpty) {
              onSelected(suggestions[0]);
            }
            if (nextFocus != null) {
              FocusScope.of(context).requestFocus(nextFocus);
            } else {
              focusNode.unfocus();
            }
          },
        ),
        if (suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: suggestions.length,
              itemBuilder: (_, i) {
                final item = suggestions[i];
                return ListTile(
                  dense: true,
                  title: Text(item, textDirection: TextDirection.rtl),
                  onTap: () {
                    onSelected(item);
                    if (nextFocus != null) {
                      FocusScope.of(context).requestFocus(nextFocus);
                    } else {
                      focusNode.unfocus();
                    }
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  /// 🔹 فیلد مخصوص صاحب نامه با اتوکامپلیت
  Widget buildSahebNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: c['saheb_name'],
          decoration: InputDecoration(
            labelText: 'صاحب نامه',
            border: OutlineInputBorder(),
          ),
          textDirection: TextDirection.rtl,
          onChanged: (value) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), () async {
              final res = await DatabaseHelper.searchSahebName(value.trim());
              setState(() {
                sahebSuggestions = res;
              });
            });
          },
        ),

        // 🔽 لیست پیشنهادها
        if (sahebSuggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: sahebSuggestions.length,
              itemBuilder: (_, i) {
                final item = sahebSuggestions[i];
                return ListTile(
                  dense: true,
                  title: Text(item, textDirection: TextDirection.rtl),
                  onTap: () async {
                    c['saheb_name']!.text = item;

                    final last = await DatabaseHelper.getLastRecordBySahebName(
                      item,
                    );

                    if (last != null) {
                      c['sh_name_reside']!.text =
                          last['sh_name_reside']?.toString() ?? '';

                      lastRecord = last;

                      lastInfoText =
                          'آخرین نامه: ${last['date'] ?? '—'} | ${last['onvan'] ?? '—'}';
                    } else {
                      lastRecord = null;
                      lastInfoText = null;
                    }

                    setState(() {
                      sahebSuggestions.clear();
                    });
                  },
                );
              },
            ),
          ),
        if (lastInfoText != null && lastRecord != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 4),
            child: InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecordForm(record: lastRecord),
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.open_in_new, size: 14, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      lastInfoText!,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget buildTextField(String field) {
    if (field == 'saheb_name') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: buildSahebNameField(),
      );
    }

    if (field == 'guy') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: buildGuyField(),
      );
    }

    if (field == 'onvan') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: buildOnvanField(),
      );
    }

    // 🔹 فیلد تاریخ با فرمت شمسی
    if (field == 'date') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: c[field],
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            JalaliDateFormatter(),
          ],
          decoration: InputDecoration(
            labelText: 'تاریخ',
            hintText: '1404/01/15',
            border: OutlineInputBorder(),
          ),
          textDirection: TextDirection.rtl,
          validator: (v) {
            if (v == null || v.length != 10) {
              return 'تاریخ معتبر وارد کنید';
            }
            return null;
          },
        ),
      );
    }

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
            ...mainFields.map(buildTextField),

            ExpansionTile(
              title: Text('سایر اطلاعات'),
              children: otherFields.map(buildTextField).toList(),
            ),

            const SizedBox(height: 20),

            ElevatedButton(onPressed: save, child: Text('ذخیره')),
          ],
        ),
      ),
    );
  }
}
