import 'dart:async';
import 'dart:io';
import 'package:dabirkhane_app/pages/settings_page.dart';
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
  final ScrollController _scrollController = ScrollController();

  bool isLoading = false;
  bool hasMore = true;

  int limit = 30;
  int offset = 0;

  Timer? _debounce;

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
        title: Text('دبیرخانه'),
        actions: [
          IconButton(icon: Icon(Icons.upload_file), onPressed: importDb),
          IconButton(icon: Icon(Icons.download), onPressed: exportDb),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingsPage()),
              );
            },
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
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () {
                  query = v;
                  loadMore(reset: true);
                });
              },
            ),
          ),

          // 📄 لیست
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: records.length + (hasMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= records.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final r = records[i];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final res = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecordForm(record: r),
                        ),
                      );
                      if (res == true) {
                        loadMore(reset: true);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          /// سطر اول واکنش‌گرا: guy و صاحب
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
                                        Text(
                                          r['guy'] ?? '—',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Icon(Icons.person_outline, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          r['saheb_name'] ?? '—',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textDirection: TextDirection.rtl,
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              } else {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      textDirection: TextDirection.rtl,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            r['guy'] ?? '—',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            // چندخطی در صفحه کوچک:
                                            // maxLines و overflow حذف شده تا متن چند خطی باشه
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      textDirection: TextDirection.rtl,
                                      children: [
                                        Icon(Icons.person_outline, size: 16),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            r['saheb_name'] ?? '—',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            textDirection: TextDirection.rtl,
                                            // چندخطی:
                                            // maxLines و overflow حذف شده
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

                          /// سطر دوم واکنش‌گرا: تاریخ و شماره ردیف
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
                                        Icon(Icons.calendar_today, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          r['date'] ?? '—',
                                          style: TextStyle(fontSize: 14),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.confirmation_number_outlined,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'ردیف ${r['Shomare_Radif']}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              } else {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      textDirection: TextDirection.rtl,
                                      children: [
                                        Icon(Icons.calendar_today, size: 16),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            r['date'] ?? '—',
                                            style: TextStyle(fontSize: 14),
                                            // چندخطی:
                                            // maxLines و overflow حذف شده
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      textDirection: TextDirection.rtl,
                                      children: [
                                        Icon(
                                          Icons.confirmation_number_outlined,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'ردیف ${r['Shomare_Radif']}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            // چندخطی:
                                            // maxLines و overflow حذف شده
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
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
