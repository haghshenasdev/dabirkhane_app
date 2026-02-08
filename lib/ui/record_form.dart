import 'dart:async';
import 'dart:io';
import 'package:dabirkhane_app/utils/JalaliDateFormatter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../db/database_helper.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:path/path.dart' as path;

class RecordForm extends StatefulWidget {
  final Map<String, dynamic>? record;
  RecordForm({this.record});

  @override
  State<RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<RecordForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> c = {};
  Map<String, dynamic>? lastRecord;
  String? lastInfoText;
  List<String> guySuggestions = [];
  List<String> onvanSuggestions = [];
  Timer? _debounceGuy;
  Timer? _debounceOnvan;
  final Map<String, FocusNode> focusNodes = {};
  List<File> filesInDirectory = [];
  late TabController _tabController;
  List<String> sahebSuggestions = [];
  Timer? _debounce;

  final mainFields = [
    'Shomare_Radif',
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
    'Shomare_Radif': 'شماره ثبت',
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    for (var f in [...mainFields, ...otherFields]) {
      c[f] = TextEditingController(text: widget.record?[f]?.toString() ?? '');
      focusNodes[f] = FocusNode();
    }

    if (widget.record == null) {
      final now = Jalali.now();
      c['date']!.text =
          '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
      _setDefaultShomareRadif();
    } else {
      _loadFiles(); // بارگذاری فایل‌ها
    }
  }

  Future<void> _setDefaultShomareRadif() async {
    final lastNumber = await DatabaseHelper.getLastShomareRadif();
    final nextNumber = (lastNumber ?? 0) + 1;
    c['Shomare_Radif']!.text = nextNumber.toString();
  }

  // بارگذاری فایل‌ها از پوشه 'letters'
  Future<void> _loadFiles() async {
    final shomareRadif = c['Shomare_Radif']!.text; // گرفتن Shomare_Radif
    final lettersDir = await getLettersDirectory();
    if (await lettersDir.exists()) {
      final files = lettersDir.listSync();
      setState(() {
        filesInDirectory = files.whereType<File>().where((f) {
        final name = path.basenameWithoutExtension(f.path);
        final regex = RegExp('^$shomareRadif(\\D.*)?\$');
        return regex.hasMatch(name);
      }).toList();
      });
    }
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

  Future<Directory> getLettersDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final lettersDir = Directory('${appDocDir.path}/letters');
    if (!await lettersDir.exists()) {
      await lettersDir.create();
    }
    return lettersDir;
  }

  // تابع برای باز کردن فایل
  Future<void> openFile(File file) async {
    // برای باز کردن فایل با استفاده از اپلیکیشن‌های پیش‌فرض دستگاه
    final result = await OpenFile.open(file.path);

    if (result.type != ResultType.done) {
      // اگر باز کردن فایل با خطا مواجه شد، می‌توانید این پیام را نمایش دهید
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در باز کردن فایل')));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _debounceGuy?.cancel();
    _debounceOnvan?.cancel();

    for (var controller in c.values) {
      controller.dispose();
    }
    for (var node in focusNodes.values) {
      node.dispose();
    }

    _tabController.dispose();
    super.dispose();
  }

  Future<void> addFileForRecord() async {
    final shomareRadif = c['Shomare_Radif']?.text.trim();
    if (shomareRadif == null || shomareRadif.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('شماره ثبت مشخص نیست')));
      return;
    }

    // انتخاب فایل
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;

    final pickedFile = File(result.files.single.path!);
    final ext = path.extension(pickedFile.path);

    final lettersDir = await getLettersDirectory();
    if (!await lettersDir.exists()) {
      await lettersDir.create(recursive: true);
    }

    // پیدا کردن نام مناسب فایل
    String targetName = '$shomareRadif$ext';
    File targetFile = File(path.join(lettersDir.path, targetName));

    int index = 1;
    while (await targetFile.exists()) {
      targetName = '${shomareRadif}_$index$ext';
      targetFile = File(path.join(lettersDir.path, targetName));
      index++;
    }

    // کپی فایل
    await pickedFile.copy(targetFile.path);

    // رفرش لیست فایل‌ها
    await _loadFiles();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('فایل اضافه شد')));
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
                          'آخرین نامه: ${last['date'] ?? '—'} | ${last['guy'] ?? '—'} | ${last['onvan'] ?? '—'}';
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
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "اطلاعات فرم"),
            Tab(text: "فایل‌ها"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // تب اول: اطلاعات فرم
          Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.all(12),
              children: [
                ...mainFields.map((field) => buildTextField(field)),
                ExpansionTile(
                  title: Text('سایر اطلاعات'),
                  children: otherFields.map(buildTextField).toList(),
                ),
                ElevatedButton(onPressed: save, child: Text('ذخیره')),
              ],
            ),
          ),
          // تب دوم: لیست فایل‌ها
          Column(
            children: [
              // دکمه‌ها برای افزودن فایل و اسکن فایل
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(Icons.attach_file),
                      label: Text('افزودن فایل'),
                      onPressed: addFileForRecord,
                    ),
                    SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: Icon(Icons.camera_alt),
                      label: Text('اسکن فایل'),
                      onPressed: addFileForRecord,
                    ),
                  ],
                ),
              ),
              // نمایش لیست فایل‌ها
              Expanded(
                child: ListView.builder(
                  itemCount: filesInDirectory.length,
                  itemBuilder: (context, index) {
                    final file = filesInDirectory[index];
                    return ListTile(
                      title: Text(path.basename(file.path)),
                      onTap: () => openFile(file),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}
