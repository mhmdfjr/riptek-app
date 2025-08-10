import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
// DIGANTI: Menggunakan import untuk open_filex
import 'package:open_filex/open_filex.dart';
import 'package:data_table_2/data_table_2.dart';

// Model untuk data presensi agar lebih mudah dikelola
class Presensi {
  final String id;
  final String nama;
  final String divisi;
  final DateTime waktu;
  final String status;

  Presensi({
    required this.id,
    required this.nama,
    required this.divisi,
    required this.waktu,
    required this.status,
  });

  factory Presensi.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Presensi(
      id: doc.id,
      nama: data['nama'] ?? '',
      divisi: data['divisi'] ?? '',
      waktu: (data['waktu'] as Timestamp).toDate(),
      status: data['status'] ?? 'Tidak Hadir',
    );
  }
}

// Enum untuk filter tabel
enum TableFilter { thisWeek, thisMonth, thisYear }

class RekapPage extends StatefulWidget {
  const RekapPage({super.key});

  @override
  State<RekapPage> createState() => _RekapPageState();
}

class _RekapPageState extends State<RekapPage> {
  TableFilter _selectedFilter = TableFilter.thisMonth;
  late Stream<List<Presensi>> _presensiStream;

  @override
  void initState() {
    super.initState();
    _presensiStream = FirebaseFirestore.instance
        .collection('presensi')
        .orderBy('waktu', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Presensi.fromFirestore(doc)).toList());
  }

  // --- WIDGET BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: StreamBuilder<List<Presensi>>(
        stream: _presensiStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Belum ada data presensi.'));
          }

          final allData = snapshot.data!;
          final recentActivities = allData.take(5).toList();
          final chartData = _calculateMonthlyStats(allData);
          final filteredData = _filterData(allData, _selectedFilter);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(Icons.history, 'Recent Activities'),
                const SizedBox(height: 16),
                _buildRecentActivities(recentActivities),
                const SizedBox(height: 32),
                _buildSectionHeader(Icons.bar_chart, 'Attendance Stats'),
                const SizedBox(height: 16),
                _buildAttendanceChart(chartData),
                const SizedBox(height: 32),
                _buildSectionHeader(Icons.list_alt, 'List Activities'),
                const SizedBox(height: 16),
                _buildActivitiesTable(filteredData),
                const SizedBox(height: 32),
                _buildExportButtons(allData),
              ],
            ),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      title: Row(
        children: [
          Image.asset(
            'assets/images/logo.png',
            height: 30,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.school, color: Colors.blue, size: 30),
          ),
          const SizedBox(width: 12),
          const Text(
            'Riptek App',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.black54),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildRecentActivities(List<Presensi> activities) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: activities.map((activity) {
            final isHadir = activity.status.toLowerCase() == 'hadir';
            return ListTile(
              leading: Icon(
                isHadir ? Icons.check_circle : Icons.cancel,
                color: isHadir ? Colors.green : Colors.red,
              ),
              title: Text(activity.nama,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${activity.divisi}  •  ${DateFormat('d/M/y HH:mm').format(activity.waktu)}',
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAttendanceChart(List<double> chartData) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                bottomTitles: AxisTitles(sideTitles: _bottomTitles),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: chartData
                      .asMap()
                      .entries
                      .map((e) => FlSpot(e.key.toDouble(), e.value))
                      .toList(),
                  isCurved: true,
                  color: Colors.purple,
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.purple.withOpacity(0.3),
                  ),
                ),
              ],
              minY: 0,
              maxY: 100,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivitiesTable(List<Presensi> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildFilterDropdown(),
        const SizedBox(height: 10),
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 560, // Tinggi tabel agar paginasi terlihat
            child: PaginatedDataTable2(
              columns: const [
                DataColumn2(label: Text('No'), fixedWidth: 50),
                DataColumn(label: Text('Nama')),
                DataColumn(label: Text('Divisi')),
                DataColumn(label: Text('Waktu')),
              ],
              source: _ActivityDataSource(data, context),
              rowsPerPage: 10,
              columnSpacing: 12,
              horizontalMargin: 12,
              minWidth: 600,
              showCheckboxColumn: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TableFilter>(
          value: _selectedFilter,
          icon: const Icon(Icons.filter_list, size: 20),
          items: const [
            DropdownMenuItem(
                value: TableFilter.thisWeek, child: Text('This Week')),
            DropdownMenuItem(
                value: TableFilter.thisMonth, child: Text('This Month')),
            DropdownMenuItem(
                value: TableFilter.thisYear, child: Text('This Year')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedFilter = value;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildExportButtons(List<Presensi> allData) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.grid_on),
            label: const Text('Export XLSX'),
            onPressed: () => _exportToXlsx(allData),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Export PDF'),
            onPressed: () => _exportToPdf(allData),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  // --- LOGIC & HELPERS ---

  List<double> _calculateMonthlyStats(List<Presensi> data) {
    List<double> monthlyCounts = List.filled(12, 0);
    for (var activity in data) {
      int month = activity.waktu.month; // 1 for Jan, 12 for Dec
      monthlyCounts[month - 1]++;
    }
    return monthlyCounts;
  }

  SideTitles get _bottomTitles => SideTitles(
        showTitles: true,
        getTitlesWidget: (value, meta) {
          const style = TextStyle(fontSize: 10);
          String text;
          switch (value.toInt()) {
            case 0:
              text = 'Jan';
              break;
            case 1:
              text = 'Feb';
              break;
            case 2:
              text = 'Mar';
              break;
            case 3:
              text = 'Apr';
              break;
            case 4:
              text = 'Mei';
              break;
            case 5:
              text = 'Jun';
              break;
            case 6:
              text = 'Jul';
              break;
            case 7:
              text = 'Agu';
              break;
            case 8:
              text = 'Sep';
              break;
            case 9:
              text = 'Okt';
              break;
            case 10:
              text = 'Nov';
              break;
            case 11:
              text = 'Des';
              break;
            default:
              text = '';
              break;
          }
          return Text(text, style: style);
        },
      );

  List<Presensi> _filterData(List<Presensi> data, TableFilter filter) {
    final now = DateTime.now();
    switch (filter) {
      case TableFilter.thisWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return data
            .where((d) =>
                d.waktu.isAfter(startOfWeek) && d.waktu.isBefore(endOfWeek))
            .toList();
      case TableFilter.thisMonth:
        return data
            .where(
                (d) => d.waktu.year == now.year && d.waktu.month == now.month)
            .toList();
      case TableFilter.thisYear:
        return data.where((d) => d.waktu.year == now.year).toList();
    }
  }

  // --- EXPORT FUNCTIONS ---

  Future<void> _exportToPdf(List<Presensi> data) async {
    final pdf = pw.Document();
    final headers = ['No', 'Nama', 'Divisi', 'Waktu', 'Status'];

    final tableData = data.asMap().entries.map((entry) {
      int index = entry.key;
      Presensi p = entry.value;
      return [
        (index + 1).toString(),
        p.nama,
        p.divisi,
        DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(p.waktu),
        p.status,
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Laporan Presensi',
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Table.fromTextArray(
            headers: headers,
            data: tableData,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.center,
            },
          ),
        ],
      ),
    );

    await _saveAndOpenFile(await pdf.save(), 'laporan_presensi.pdf');
  }

  Future<void> _exportToXlsx(List<Presensi> data) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Laporan Presensi'];

    // Add headers
    List<String> headers = ['No', 'Nama', 'Divisi', 'Waktu', 'Status'];
    sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

    // Add data
    for (var i = 0; i < data.length; i++) {
      var p = data[i];
      sheetObject.appendRow([
        IntCellValue(i + 1),
        TextCellValue(p.nama),
        TextCellValue(p.divisi),
        TextCellValue(DateFormat('dd-MM-yyyy HH:mm:ss').format(p.waktu)),
        TextCellValue(p.status),
      ]);
    }

    final bytes = excel.save();
    if (bytes != null) {
      await _saveAndOpenFile(bytes, 'laporan_presensi.xlsx');
    }
  }

  Future<void> _saveAndOpenFile(List<int> bytes, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/$fileName';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berhasil disimpan di $path')),
      );

      // DIGANTI: Menggunakan OpenFilex.open
      await OpenFilex.open(path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka file: $e')),
      );
    }
  }
}

// Data source untuk PaginatedDataTable2
class _ActivityDataSource extends DataTableSource {
  final List<Presensi> _data;
  final BuildContext context;

  _ActivityDataSource(this._data, this.context);

  @override
  DataRow? getRow(int index) {
    if (index >= _data.length) {
      return null;
    }
    final activity = _data[index];
    return DataRow2(
      cells: [
        DataCell(Text((index + 1).toString())),
        DataCell(Text(activity.nama)),
        DataCell(Text(activity.divisi)),
        DataCell(Text(DateFormat('d MMM yyyy, HH:mm').format(activity.waktu))),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _data.length;

  @override
  int get selectedRowCount => 0;
}
