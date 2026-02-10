import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dabirkhane_app/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../db/database_helper.dart';
import 'record_form.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> records = [];
  List<Map<String, dynamic>> filtered = [];
  String query = '';
  final ScrollController _scrollController = ScrollController();

  bool isLoading = false;
  bool hasMore = true;

  int limit = 30;
  int offset = 0;

  Timer? _debounce;

  bool selectionMode = false;
  Set<int> selectedIndexes = {};

  Future<void> loadMore({bool reset = false}) async {
    if (isLoading) return;

    if (reset) {
      offset = 0;
      hasMore = true;
      records.clear();
    }

    if (!hasMore) return;

    isLoading = true;
    setState(() {});

    final data = await DatabaseHelper.getPaged(
      limit: limit,
      offset: offset,
      search: query,
    );

    if (data.length < limit) {
      hasMore = false;
    }

    offset += data.length;
    records.addAll(data);

    isLoading = false;
    setState(() {});
  }

  Future<bool> confirmImport() async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('هشدار'),
            content: Text(
              'با این کار دیتابیس فعلی جایگزین می‌شود.\n'
              'آیا مطمئن هستید؟',
            ),
            actions: [
              TextButton(
                child: Text('انصراف'),
                onPressed: () => Navigator.pop(context, false),
              ),
              ElevatedButton(
                child: Text('بله، ادامه بده'),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ) ??
        false;
  }

  void showMessage(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: Text('باشه'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> importDb() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['sqlite', 'db'],
    );

    if (result == null) return;

    // تأیید کاربر
    final ok = await confirmImport();
    if (!ok) return;

    try {
      // 1️⃣ مسیر دیتابیس را بگیر (بدون باز کردنش)
      final String targetPath = await DatabaseHelper.getDbPath();
      final File targetFile = File(targetPath);

      // 2️⃣ اگر دیتابیس باز است، ببند
      await DatabaseHelper.closeDb();

      // 3️⃣ حذف فایل قبلی
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      // 4️⃣ کپی دیتابیس جدید
      final File selectedFile = File(result.files.single.path!);
      await selectedFile.copy(targetPath);

      // 5️⃣ دیتابیس جدید باز شود
      await DatabaseHelper.database;

      // 6️⃣ بارگذاری مجدد دیتا
      await load();

      showMessage('موفقیت', 'دیتابیس با موفقیت جایگزین شد.');
    } catch (e) {
      showMessage(
        'خطا',
        'ویندوز اجازه جایگزینی فایل را نداد.\n'
            'لطفاً مطمئن شوید فایل دیتابیس در برنامه یا جای دیگری باز نباشد.\n\n$e',
      );
      debugPrint(e.toString());
    }
  }

  Future<void> exportDb() async {
    try {
      String? dir = await FilePicker.platform.getDirectoryPath();
      if (dir == null) return;

      final db = await DatabaseHelper.database;
      final File dbFile = File(db.path);

      final String target = '$dir/dabirkhane.sqlite';

      if (await File(target).exists()) {
        await File(target).delete();
      }

      await dbFile.copy(target);

      showMessage('موفقیت', 'دیتابیس با موفقیت ذخیره شد.');
    } catch (e) {
      showMessage('خطا', 'خطا در اکسپورت دیتابیس:\n$e');
    }
  }

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
    loadMore();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        loadMore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: selectionMode
            ? Text('${selectedIndexes.length} مورد انتخاب شده')
            : const Text('دبیرخانه'),
        leading: selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    selectionMode = false;
                    selectedIndexes.clear();
                  });
                },
              )
            : null,
        actions: selectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: 'انتخاب همه',
                  onPressed: () {
                    setState(() {
                      selectedIndexes = Set.from(
                        List.generate(records.length, (i) => i),
                      );
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.table_view),
                  tooltip: 'خروجی اکسل',
                  onPressed: exportSelectedToCsv,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.upload_file),
                  onPressed: importDb,
                ),
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: exportDb,
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SettingsPage()),
                    );
                  },
                ),
              ],
      ),

      floatingActionButton: selectionMode
          ? null
          : FloatingActionButton(
              child: const Icon(Icons.add),
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
              decoration: const InputDecoration(
                labelText: 'جستجو...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () {
                  query = v;
                  loadMore(reset: true);
                });
              },
            ),
          ),

          // 📄 لیست کارت‌ها
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: records.length + (hasMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= records.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final r = records[i];
                final isSelected = selectedIndexes.contains(i);

                return Card(
                  color: isSelected ? Colors.blue.withOpacity(0.15) : null,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  elevation: isSelected ? 4 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isSelected
                        ? const BorderSide(color: Colors.blue, width: 1.5)
                        : BorderSide.none,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),

                    // 👆 کلیک کوتاه
                    onTap: () async {
                      if (selectionMode) {
                        setState(() {
                          if (isSelected) {
                            selectedIndexes.remove(i);
                          } else {
                            selectedIndexes.add(i);
                          }

                          if (selectedIndexes.isEmpty) {
                            selectionMode = false;
                          }
                        });
                      } else {
                        final res = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecordForm(record: r),
                          ),
                        );
                        if (res == true) {
                          loadMore(reset: true);
                        }
                      }
                    },

                    // ✋ کلیک طولانی
                    onLongPress: () {
                      setState(() {
                        selectionMode = true;
                        selectedIndexes.add(i);
                      });
                    },

                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              /// سطر اول: guy و صاحب
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth > 400;
                                  if (isWide) {
                                    return Row(
                                      textDirection: TextDirection.rtl,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          r['guy'] ?? '—',
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.person_outline,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              r['saheb_name'] ?? '—',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  } else {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          r['guy'] ?? '—',
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.person_outline,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                r['saheb_name'] ?? '—',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  }
                                },
                              ),

                              const SizedBox(height: 10),

                              /// سطر دوم: تاریخ و ردیف
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth > 400;
                                  if (isWide) {
                                    return Row(
                                      textDirection: TextDirection.rtl,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.calendar_today,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(r['date'] ?? '—'),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons
                                                  .confirmation_number_outlined,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'ردیف ${r['Shomare_Radif']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  } else {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.calendar_today,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(r['date'] ?? '—'),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons
                                                  .confirmation_number_outlined,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'ردیف ${r['Shomare_Radif']}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),

                        // ✅ آیکن انتخاب
                        if (selectionMode)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isSelected ? Colors.blue : Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> exportSelectedToCsv() async {
    if (selectedIndexes.isEmpty) {
      debugPrint('❌ هیچ آیتمی انتخاب نشده');
      return;
    }

    final selectedRecords = selectedIndexes
        .where((i) => i >= 0 && i < records.length)
        .map((i) => records[i])
        .toList();

    if (selectedRecords.isEmpty) {
      debugPrint('❌ لیست انتخاب‌شده خالی است');
      return;
    }

    // 🟢 ساخت هدرها (امن)
    final headers = selectedRecords.first.keys
        .map((e) => e.toString())
        .toList();

    final StringBuffer csv = StringBuffer();

    csv.write('\uFEFF');

    // 🔹 سطر هدر
    csv.writeln(headers.join(';'));

    // 🔹 داده‌ها
    for (final record in selectedRecords) {
      final row = headers
          .map((h) {
            final value = record[h]?.toString() ?? '';
            final escaped = value.replaceAll('"', '""');
            return '"$escaped"';
          })
          .join(';');

      csv.writeln(row);
    }

    final fileName = 'export_${DateTime.now().millisecondsSinceEpoch}.csv';

    final path = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'CSV', extensions: ['csv']),
      ],
    );

    if (path == null) return;

    final file = File(path.path);
    await file.writeAsString(csv.toString(), flush: true, encoding: utf8);

    debugPrint('✅ CSV exported: $path.path');
  }
}
