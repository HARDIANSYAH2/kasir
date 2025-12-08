// lib/pages/cetak_laporan.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';

class CetakLaporanPage extends StatefulWidget {
  const CetakLaporanPage({super.key});

  @override
  State<CetakLaporanPage> createState() => _CetakLaporanPageState();
}

class _CetakLaporanPageState extends State<CetakLaporanPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> dataPesanan = [];
  bool isLoading = true;
  DateTimeRange? filterTanggal;
  String searchKeyword = "";

  final formatRupiah =
      NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    ambilDataPesanan();
  }

  // ------------------------
  // Ambil data pesanan
  // ------------------------
  Future<void> ambilDataPesanan() async {
    try {
      if (mounted) setState(() => isLoading = true);

      var query = supabase.from("pesanan").select();

      if (filterTanggal != null) {
        final start = filterTanggal!.start.toIso8601String();
        final end = DateTime(
          filterTanggal!.end.year,
          filterTanggal!.end.month,
          filterTanggal!.end.day,
          23,
          59,
          59,
        ).toIso8601String();
        query = query.gte("tanggal", start).lte("tanggal", end);
      }

      final response = await query.order("createdAt", ascending: false);

      if (mounted) {
        setState(() {
          dataPesanan = List<Map<String, dynamic>>.from(response as List);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal ambil data: $e")),
        );
      }
    }
  }

  // ------------------------
  // Utility
  // ------------------------
  String _formatTanggal(dynamic raw) {
    if (raw == null) return "-";
    DateTime? dt;
    if (raw is DateTime) {
      dt = raw;
    } else if (raw is String) {
      dt = DateTime.tryParse(raw);
    }
    return dt == null ? "-" : DateFormat("dd-MM-yyyy").format(dt);
  }

  num _toNum(dynamic raw) {
    if (raw == null) return 0;
    if (raw is num) return raw;
    if (raw is String) return num.tryParse(raw.replaceAll(',', '')) ?? 0;
    return 0;
  }

  String getJudulLaporan() {
    if (filterTanggal == null) return "Laporan Semua Periode";

    final start = filterTanggal!.start;
    final end = filterTanggal!.end;

    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) return "Laporan Harian";

    if (end.difference(start).inDays + 1 == 7) return "Laporan Mingguan";

    if (start.year == end.year && start.month == end.month) return "Laporan Bulanan";

    return "Laporan Per Periode";
  }

  // ------------------------
  // Generate & Cetak PDF
  // ------------------------
  pw.Document generatePDF(List<Map<String, dynamic>> dataFiltered) {
    final pdf = pw.Document();
    final num totalKeseluruhan =
        dataFiltered.fold<num>(0, (sum, item) => sum + _toNum(item["total"]));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return [
            pw.Center(
              child: pw.Text(
                getJudulLaporan().toUpperCase(),
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
            ),
            if (filterTanggal != null)
              pw.Center(
                child: pw.Text(
                  "Periode: ${DateFormat("dd-MM-yyyy").format(filterTanggal!.start)} s.d ${DateFormat("dd-MM-yyyy").format(filterTanggal!.end)}",
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: ["Nama", "Lapangan", "Tanggal", "Jam", "Durasi", "Total", "Pembayaran"],
              data: dataFiltered.map((item) {
                final tglStr = _formatTanggal(item["tanggal"]);
                final jam = "${item["jamMulai"] ?? ""} - ${item["jamSelesai"] ?? ""}";
                final durasi = item["durasi"] ?? "-";
                final total = _toNum(item["total"]);
                final metode = item["metode_pembayaran"] ?? "-";
                return [
                  item["nama"] ?? "-",
                  item["lapangan"] ?? "-",
                  tglStr,
                  jam,
                  "$durasi Jam",
                  formatRupiah.format(total),
                  metode,
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: PdfColors.green800),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 10),
              border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  "Total Keseluruhan: ${formatRupiah.format(totalKeseluruhan)}",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  Future<void> cetakPDF(List<Map<String, dynamic>> dataFiltered) async {
    try {
      final pdf = generatePDF(dataFiltered);
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal cetak: $e")),
      );
    }
  }

  Future<void> downloadPDF(List<Map<String, dynamic>> dataFiltered) async {
    try {
      final pdf = generatePDF(dataFiltered);
      final bytes = await pdf.save();

      if (kIsWeb) {
        await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: "laporan_pesanan.pdf");
        return;
      }

      Directory? dir = await getDownloadsDirectory();
      dir ??= await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/laporan_pesanan_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(bytes);

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("File berhasil disimpan di ${file.path}")),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal download PDF: $e")),
      );
    }
  }

  // ------------------------
  // Build UI (Responsive)
  // ------------------------
  @override
  Widget build(BuildContext context) {
    final Color primary = Colors.green.shade800;
    final Color accent = Colors.greenAccent.shade400;
    final Color cardBg = Colors.green.shade50;

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 750;

        return Scaffold(
          backgroundColor: Colors.green.shade100,
          appBar: AppBar(backgroundColor: primary, elevation: 0, toolbarHeight: 0),
          body: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: Column(
              children: [
                Card(
                  color: cardBg,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: isMobile ? _headerMobile(primary) : _headerDesktop(primary),
                  ),
                ),
                const SizedBox(height: 18),
                isMobile ? _filterColumn(primary, accent) : _filterRow(primary, accent),
                const SizedBox(height: 18),
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildDataTable(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------
  // Header
  // ------------------------
  Widget _headerMobile(Color primary) {
    final totalAll = dataPesanan.fold<num>(0, (sum, item) => sum + _toNum(item["total"]));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(getJudulLaporan(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          filterTanggal == null
              ? 'Semua Periode'
              : 'Periode: ${DateFormat('dd-MM-yyyy').format(filterTanggal!.start)} s.d ${DateFormat('dd-MM-yyyy').format(filterTanggal!.end)}',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        Text('Total Transaksi', style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        Text(formatRupiah.format(totalAll),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primary)),
      ],
    );
  }

  Widget _headerDesktop(Color primary) {
    final totalAll = dataPesanan.fold<num>(0, (sum, item) => sum + _toNum(item["total"]));
    return Row(
      children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(getJudulLaporan(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              filterTanggal == null
                  ? 'Semua Periode'
                  : 'Periode: ${DateFormat('dd-MM-yyyy').format(filterTanggal!.start)} s.d ${DateFormat('dd-MM-yyyy').format(filterTanggal!.end)}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Total Transaksi', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          Text(formatRupiah.format(totalAll),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primary)),
        ]),
      ],
    );
  }

  // ------------------------
  // Filter & Buttons
  // ------------------------
  Widget _filterColumn(Color primary, Color accent) {
    return Column(
      children: [
        Row(children: [_btnPilihPeriode(primary), const SizedBox(width: 12), Expanded(child: _searchField())]),
        const SizedBox(height: 12),
        Row(children: [_btnDownload(accent), const SizedBox(width: 8), _btnCetak(primary)]),
      ],
    );
  }

  Widget _filterRow(Color primary, Color accent) {
    return Row(
      children: [
        _btnPilihPeriode(primary),
        const SizedBox(width: 12),
        Expanded(child: _searchField()),
        const SizedBox(width: 12),
        _btnDownload(accent),
        const SizedBox(width: 8),
        _btnCetak(primary),
      ],
    );
  }

  Widget _btnPilihPeriode(Color primary) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onPressed: () async {
      final pickedRange = await showDateRangePicker(
  context: context,
  firstDate: DateTime(2020),
  lastDate: DateTime(2100),
  initialDateRange: filterTanggal ??
      DateTimeRange(start: DateTime.now(), end: DateTime.now()),
  helpText: 'Pilih Periode Tanggal',

  builder: (context, child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 380,  // <–– ukuran popup seperti gambar
          maxHeight: 500, // <–– tingginya juga diperkecil
        ),
        child: Material(
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  },
);


        if (pickedRange != null) {
          setState(() => filterTanggal = pickedRange);
          await ambilDataPesanan();
        }
      },
      icon: const Icon(Icons.date_range, color: Colors.white),
      label: const Text('Pilih Periode', style: TextStyle(color: Colors.white)),
    );
  }

  Widget _searchField() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Cari nama penyewa...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
      onChanged: (val) => setState(() => searchKeyword = val),
    );
  }

  Widget _btnDownload(Color accent) {
    final dataFiltered = _filterData();
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      onPressed: dataFiltered.isEmpty ? null : () => downloadPDF(dataFiltered),
      icon: const Icon(Icons.download_rounded),
      label: const Text('Download PDF'),
    );
  }

  Widget _btnCetak(Color primary) {
    final dataFiltered = _filterData();
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      onPressed: dataFiltered.isEmpty ? null : () => cetakPDF(dataFiltered),
      icon: const Icon(Icons.print),
      label: const Text('Cetak'),
    );
  }

  List<Map<String, dynamic>> _filterData() {
    return dataPesanan.where((item) {
      final nama = (item["nama"] ?? "").toString().toLowerCase();
      return nama.contains(searchKeyword.toLowerCase());
    }).toList();
  }

  // ------------------------
  // DataTable
  // ------------------------
  Widget _buildDataTable() {
    final dataFiltered = _filterData();
    final num totalKeseluruhan = dataFiltered.fold<num>(0, (sum, item) => sum + _toNum(item["total"]));

    if (dataFiltered.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text('Tidak ada data', style: TextStyle(color: Colors.grey.shade600)),
        ]),
      );
    }

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 56,
            dataRowHeight: 56,
            columnSpacing: 28,
            headingRowColor: MaterialStateProperty.all(Colors.green.shade200),
            border: TableBorder.symmetric(
              inside: BorderSide(color: Colors.green.shade100),
              outside: BorderSide(color: Colors.green.shade300),
            ),
            columns: const [
              DataColumn(label: Text('Nama Penyewa')),
              DataColumn(label: Text('Lapangan')),
              DataColumn(label: Text('Tanggal')),
              DataColumn(label: Text('Jam Main')),
              DataColumn(label: Text('Durasi')),
              DataColumn(label: Text('Total')),
              DataColumn(label: Text('Pembayaran')),
            ],
            rows: [
              ...dataFiltered.map((item) {
                final tglStr = _formatTanggal(item['tanggal']);
                final jam = '${item['jamMulai'] ?? ''} - ${item['jamSelesai'] ?? ''}';
                final durasi = item['durasi'] ?? '-';
                final total = _toNum(item['total']);
                final metode = item['metode_pembayaran'] ?? '-';

                return DataRow(cells: [
                  DataCell(Text(item['nama'] ?? '-')),
                  DataCell(Text(item['lapangan'] ?? '-')),
                  DataCell(Text(tglStr)),
                  DataCell(Text(jam)),
                  DataCell(Text('$durasi Jam')),
                  DataCell(Text(formatRupiah.format(total))),
                  DataCell(Text(metode)),
                ]);
              }).toList(),
              DataRow(cells: [
                DataCell(Text('Total Keseluruhan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800))),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                DataCell(Text(formatRupiah.format(totalKeseluruhan), style: const TextStyle(fontWeight: FontWeight.bold))),
                const DataCell(Text('')),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
