import 'package:dabirkhane_app/db/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shamsi_date/shamsi_date.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  int selectedYear = Jalali.now().year;
  List<int> years = [];

  int totalLetters = 0;
  int thisMonthLetters = 0;

  Map<int, int> monthlyCounts = {};
  Map<String, int> receiverCounts = {};

  final List<String> monthNames = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  @override
  void initState() {
    super.initState();
    loadYears();
  }

  Future<void> loadYears() async {
    final db = await DatabaseHelper.database;
    final result = await db.rawQuery(
      "SELECT DISTINCT substr(date,1,4) as year FROM daftare_andicator",
    );

    years =
        result
            .map((e) => int.tryParse(e['year'].toString()) ?? 0)
            .where((y) => y > 0)
            .toList()
          ..sort((a, b) => a.compareTo(b));

    if (!years.contains(selectedYear) && years.isNotEmpty) {
      selectedYear = years.last;
    }

    await loadStats();
  }

  Future<void> loadStats() async {
    final db = await DatabaseHelper.database;

    // کل نامه‌ها
    final total = await db.rawQuery(
      "SELECT COUNT(*) as count FROM daftare_andicator",
    );
    totalLetters = total.first['count'] as int;

    // ماه جاری
    final now = Jalali.now();
    final currentMonth = "${now.year}/${now.month.toString().padLeft(2, '0')}";

    final monthRes = await db.rawQuery(
      "SELECT COUNT(*) as count FROM daftare_andicator WHERE date LIKE '$currentMonth%'",
    );
    thisMonthLetters = monthRes.first['count'] as int;

    // ماه‌های سال انتخاب شده
    final monthData = await db.rawQuery(
      """
    SELECT substr(date,6,2) as month, COUNT(*) as count
    FROM daftare_andicator
    WHERE substr(date,1,4) = ?
    GROUP BY month
  """,
      [selectedYear.toString()],
    );

    // مقداردهی اولیه ماه‌ها
    monthlyCounts.clear();
    for (var m = 1; m <= 12; m++) {
      monthlyCounts[m] = 0;
    }

    for (var row in monthData) {
      // ایمن تبدیل به int
      int month = 0;
      final monthStr = row['month']?.toString().trim() ?? '';
      if (monthStr.isNotEmpty) {
        // اگر ماه تک‌رقمی است و صفر ندارد
        final parsedMonth = int.tryParse(
          monthStr.replaceAll(RegExp(r'[^0-9]'), ''),
        );
        if (parsedMonth != null && parsedMonth >= 1 && parsedMonth <= 12) {
          month = parsedMonth;
        }
      }

      if (month > 0) {
        monthlyCounts[month] = row['count'] as int;
      }
    }

    // بیشترین گیرنده‌ها (حذف کم‌تعدادها)
    final receiverData = await db.rawQuery(
      """
    SELECT onvan, COUNT(*) as count
    FROM daftare_andicator
    WHERE substr(date,1,4) = ?
    GROUP BY onvan
    HAVING count > 2
    ORDER BY count DESC
    LIMIT 6
  """,
      [selectedYear.toString()],
    );

    receiverCounts.clear();
    for (var row in receiverData) {
      final onvan = row['onvan']?.toString() ?? '';
      if (onvan.isNotEmpty) {
        receiverCounts[onvan] = row['count'] as int;
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("آمار نامه‌ها")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // کارت آمار کلی
            Row(
              children: [
                _infoCard("کل نامه‌ها", totalLetters.toString()),
                const SizedBox(width: 10),
                _infoCard("نامه‌های این ماه", thisMonthLetters.toString()),
              ],
            ),

            const SizedBox(height: 20),

            // انتخاب سال
            DropdownButton<int>(
              value: selectedYear,
              items: years
                  .map(
                    (y) =>
                        DropdownMenuItem(value: y, child: Text(y.toString())),
                  )
                  .toList(),
              onChanged: (value) {
                selectedYear = value!;
                loadStats();
              },
            ),

            const SizedBox(height: 30),

            // نمودار ماهانه
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                "تعداد نامه‌ها بر اساس ماه",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index >= 0 && index < 12) {
                            return Text(
                              monthNames[index],
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(12, (index) {
                    final value = monthlyCounts[index + 1] ?? 0;

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: value.toDouble(),
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // نمودار گیرنده‌ها
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                "بیشترین گیرنده‌ها",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 300,
              child: PieChart(
                PieChartData(
                  sections: receiverCounts.entries.map((e) {
                    return PieChartSectionData(
                      value: e.value.toDouble(),
                      title: "${e.key}\n${e.value}",
                      radius: 80,
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String title, String value) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(title),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
