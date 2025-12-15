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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Gagal ambil data: $e")));
      }
    }
  }

  String _formatTanggal(dynamic raw) {
    if (raw == null) return "-";
    DateTime? dt;
    if (raw is DateTime) dt = raw;
    if (raw is String) dt = DateTime.tryParse(raw);
    return dt == null ? "-" : DateFormat("dd-MM-yyyy").format(dt);
  }

  num _toNum(dynamic raw) {
    if (raw == null) return 0;
    if (raw is num) return raw;
    if (raw is String) return num.tryParse(raw.replaceAll(",", "")) ?? 0;
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

  // =====================================================================
  // PERBAIKAN PDF — SUDAH RAPIH UNTUK HARIAN / BULANAN / SEMUA PERIODE
  // =====================================================================

  pw.Document generatePDF(List<Map<String, dynamic>> dataFiltered) {
    final pdf = pw.Document();
    final num totalKeseluruhan =
        dataFiltered.fold<num>(0, (sum, item) => sum + _toNum(item["total"]));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        build: (context) {
          return [
            pw.Center(
              child: pw.Text(
                getJudulLaporan().toUpperCase(),
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ),
            if (filterTanggal != null)
              pw.Center(
                child: pw.Text(
                  "Periode: ${DateFormat("dd-MM-yyyy").format(filterTanggal!.start)} "
                  "s.d ${DateFormat("dd-MM-yyyy").format(filterTanggal!.end)}",
                  style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                ),
              ),
            pw.SizedBox(height: 20),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.4),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.7),
                4: const pw.FlexColumnWidth(1.2),
                5: const pw.FlexColumnWidth(1.6),
                6: const pw.FlexColumnWidth(1.6),
              },
              children: [
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.green800),
                  children: [
                    _headerCell("Nama"),
                    _headerCell("Lapangan"),
                    _headerCell("Tanggal"),
                    _headerCell("Jam"),
                    _headerCell("Durasi"),
                    _headerCell("Total"),
                    _headerCell("Pembayaran"),
                  ],
                ),

                ...dataFiltered.map((item) {
                  return pw.TableRow(
                    children: [
                      _cell(item["nama"]),
                      _cell(item["lapangan"]),
                      _cell(_formatTanggal(item["tanggal"])),
                      _cell("${item["jamMulai"]} - ${item["jamSelesai"]}"),
                      _cell("${item["durasi"]} Jam"),
                      _cell(formatRupiah.format(_toNum(item["total"])),
                          alignRight: true),
                      _cell(item["metode_pembayaran"]),
                    ],
                  );
                }).toList(),

                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _cell("Total Keseluruhan", bold: true),
                    _cell(""),
                    _cell(""),
                    _cell(""),
                    _cell(""),
                    _cell(formatRupiah.format(totalKeseluruhan),
                        bold: true, alignRight: true),
                    _cell(""),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _cell(String? text,
      {bool bold = false, bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text ?? "-",
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  // =====================================================================
  // CETAK & DOWNLOAD PDF
  // =====================================================================
  Future<void> cetakPDF(List<Map<String, dynamic>> dataFiltered) async {
    try {
      final pdf = generatePDF(dataFiltered);
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Gagal cetak: $e")));
      }
    }
  }

  Future<void> downloadPDF(List<Map<String, dynamic>> dataFiltered) async {
    try {
      final pdf = generatePDF(dataFiltered);
      final bytes = await pdf.save();

      if (kIsWeb) {
        await Printing.sharePdf(
          bytes: Uint8List.fromList(bytes),
          filename: "laporan_pesanan.pdf",
        );
        return;
      }

      Directory? dir = await getDownloadsDirectory();
      dir ??= await getApplicationDocumentsDirectory();
      final file = File(
          "${dir.path}/laporan_${DateTime.now().millisecondsSinceEpoch}.pdf");

      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Berhasil disimpan ke ${file.path}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Gagal download PDF: $e")));
    }
  }

  // =====================================================================
  // UI - TETAP SAMA, HANYA PDF YANG DIPERBAIKI
  // =====================================================================

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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                    child: isMobile
                        ? _headerMobile(primary)
                        : _headerDesktop(primary),
                  ),
                ),
                const SizedBox(height: 18),
                isMobile
                    ? _filterColumn(primary, accent)
                    : _filterRow(primary, accent),
                const SizedBox(height: 18),
                Expanded(
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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

  // HEADER UI
  Widget _headerMobile(Color primary) {
    final total = dataPesanan.fold<num>(0, (s, x) => s + _toNum(x["total"]));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(getJudulLaporan(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          filterTanggal == null
              ? "Semua Periode"
              : "Periode: ${DateFormat("dd-MM-yyyy").format(filterTanggal!.start)} "
                  "s.d ${DateFormat("dd-MM-yyyy").format(filterTanggal!.end)}",
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        Text("Total Transaksi",
            style: TextStyle(color: Colors.grey.shade600)),
        Text(formatRupiah.format(total),
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: primary)),
      ],
    );
  }

  Widget _headerDesktop(Color primary) {
    final total = dataPesanan.fold<num>(0, (s, x) => s + _toNum(x["total"]));
    return Row(
      children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(getJudulLaporan(),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              filterTanggal == null
                  ? "Semua Periode"
                  : "Periode: ${DateFormat("dd-MM-yyyy").format(filterTanggal!.start)} "
                      "s.d ${DateFormat("dd-MM-yyyy").format(filterTanggal!.end)}",
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text("Total Transaksi",
              style: TextStyle(color: Colors.grey.shade600)),
          Text(formatRupiah.format(total),
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: primary)),
        ])
      ],
    );
  }

  // FILTER UI
  Widget _filterColumn(Color primary, Color accent) {
    return Column(
      children: [
        Row(
          children: [
            _btnPilihPeriode(primary),
            const SizedBox(width: 10),
            Expanded(child: _searchField())
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _btnDownload(accent),
            const SizedBox(width: 10),
            _btnCetak(primary),
          ],
        ),
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
          builder: (context, child) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 380,
                  maxHeight: 500,
                ),
                child: Material(
                  borderRadius: BorderRadius.circular(28),
                  clipBehavior: Clip.antiAlias,
                  child: child!,
                ),
              ),
            );
          },
        );

        if (pickedRange != null) {
          setState(() => filterTanggal = pickedRange);
          ambilDataPesanan();
        }
      },
      icon: const Icon(Icons.date_range, color: Colors.white),
      label:
          const Text("Pilih Periode", style: TextStyle(color: Colors.white)),
    );
  }

  Widget _searchField() {
    return TextField(
      decoration: InputDecoration(
        hintText: "Cari nama penyewa...",
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
      ),
      onChanged: (v) => setState(() => searchKeyword = v),
    );
  }

  Widget _btnDownload(Color accent) {
    final dataFiltered = _filterData();
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      onPressed:
          dataFiltered.isEmpty ? null : () => downloadPDF(dataFiltered),
      icon: const Icon(Icons.download),
      label: const Text("Download PDF"),
    );
  }

  Widget _btnCetak(Color primary) {
    final dataFiltered = _filterData();
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      onPressed: dataFiltered.isEmpty ? null : () => cetakPDF(dataFiltered),
      icon: const Icon(Icons.print),
      label: const Text("Cetak"),
    );
  }

  List<Map<String, dynamic>> _filterData() {
    return dataPesanan.where((item) {
      return (item["nama"] ?? "")
          .toString()
          .toLowerCase()
          .contains(searchKeyword.toLowerCase());
    }).toList();
  }

  // DATA TABLE UI
  Widget _buildDataTable() {
    final dataFiltered = _filterData();
    final totalKeseluruhan =
        dataFiltered.fold<num>(0, (s, x) => s + _toNum(x["total"]));

    if (dataFiltered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text("Tidak ada data",
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
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
            columnSpacing: 30,
            headingRowColor:
                MaterialStateProperty.all(Colors.green.shade200),
            border: TableBorder.symmetric(
              inside: BorderSide(color: Colors.green.shade100),
              outside: BorderSide(color: Colors.green.shade400),
            ),
            columns: const [
              DataColumn(label: Text("Nama Penyewa")),
              DataColumn(label: Text("Lapangan")),
              DataColumn(label: Text("Tanggal")),
              DataColumn(label: Text("Jam Main")),
              DataColumn(label: Text("Durasi")),
              DataColumn(label: Text("Total")),
              DataColumn(label: Text("Pembayaran")),
            ],
            rows: [
              ...dataFiltered.map((item) {
                return DataRow(cells: [
                  DataCell(Text(item["nama"])),
                  DataCell(Text(item["lapangan"])),
                  DataCell(Text(_formatTanggal(item["tanggal"]))),
                  DataCell(
                      Text("${item["jamMulai"]} - ${item["jamSelesai"]}")),
                  DataCell(Text("${item["durasi"]} Jam")),
                  DataCell(Text(formatRupiah.format(_toNum(item["total"])))),
                  DataCell(Text(item["metode_pembayaran"])),
                ]);
              }),
              DataRow(cells: [
                DataCell(Text("Total Keseluruhan",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800))),
                const DataCell(Text("")),
                const DataCell(Text("")),
                const DataCell(Text("")),
                const DataCell(Text("")),
                DataCell(Text(formatRupiah.format(totalKeseluruhan),
                    style: const TextStyle(fontWeight: FontWeight.bold))),
                const DataCell(Text("")),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
