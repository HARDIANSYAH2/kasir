import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart' show PdfColors, PdfPageFormat;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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

  final formatRupiah =
      NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    ambilDataPesanan();
  }

  /// Ambil data dari Supabase
  Future<void> ambilDataPesanan() async {
    try {
      var query = supabase.from("pesanan").select();

      if (filterTanggal != null) {
        final start = DateTime(
          filterTanggal!.start.year,
          filterTanggal!.start.month,
          filterTanggal!.start.day,
        ).toIso8601String();

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

      setState(() {
        dataPesanan = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal ambil data: $e")),
      );
    }
  }

  /// Pilih periode tanggal
  Future<void> pilihTanggal() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
      initialDateRange: filterTanggal ??
          DateTimeRange(
            start: DateTime.now(),
            end: DateTime.now(),
          ),
    );

    if (picked != null) {
      setState(() {
        filterTanggal = picked;
        isLoading = true;
      });
      await ambilDataPesanan();
    }
  }

  /// Format tanggal
  String _formatTanggal(dynamic raw) {
    if (raw == null) return "-";
    DateTime? dt;
    if (raw is DateTime) {
      dt = raw;
    } else if (raw is String) {
      dt = DateTime.tryParse(raw);
    }
    if (dt == null) return "-";
    return DateFormat("dd-MM-yyyy").format(dt);
  }

  /// Convert dynamic ke num
  num _toNum(dynamic raw) {
    if (raw == null) return 0;
    if (raw is num) return raw;
    if (raw is String) {
      return num.tryParse(raw.replaceAll(',', '')) ?? 0;
    }
    return 0;
  }

  /// Generate PDF
  pw.Document generatePDF() {
    final pdf = pw.Document();

    final num totalKeseluruhan =
        dataPesanan.fold<num>(0, (sum, item) => sum + _toNum(item["total"]));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Text(
              "Laporan Pesanan Lapangan",
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            if (filterTanggal != null) ...[
              pw.SizedBox(height: 5),
              pw.Text(
                "Periode: ${DateFormat("dd-MM-yyyy").format(filterTanggal!.start)} "
                "s.d ${DateFormat("dd-MM-yyyy").format(filterTanggal!.end)}",
              ),
            ],
            pw.SizedBox(height: 20),

            // Tabel PDF
            pw.Table.fromTextArray(
              headers: [
                "Nama Penyewa",
                "Lapangan",
                "Tanggal",
                "Jam",
                "Durasi",
                "Total"
              ],
              data: dataPesanan.map((pesanan) {
                final tglStr = _formatTanggal(pesanan["tanggal"]);
                final durasi = pesanan["durasi"] ?? "-";
                final jam =
                    "${pesanan["jamMulai"] ?? ""} - ${pesanan["jamSelesai"] ?? ""}";
                final total = _toNum(pesanan["total"]);
                return [
                  pesanan["nama"] ?? "-",
                  pesanan["lapangan"] ?? "-",
                  tglStr,
                  jam,
                  "$durasi Jam",
                  formatRupiah.format(total),
                ];
              }).toList(),
              cellAlignment: pw.Alignment.center,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(color: PdfColors.green700),
              cellStyle: pw.TextStyle(fontSize: 11),
              border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey600),
            ),

            pw.SizedBox(height: 10),

            // Total keseluruhan
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  "Total Keseluruhan: ${formatRupiah.format(totalKeseluruhan)}",
                  style:
                      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  /// Cetak PDF
  Future<void> cetakPDF() async {
    try {
      final pdf = generatePDF();
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Gagal cetak: $e")));
      }
    }
  }

  /// Download PDF
  Future<void> downloadPDF() async {
    try {
      final pdf = generatePDF();
      final bytes = await pdf.save();

      if (kIsWeb) {
        await Printing.sharePdf(
          bytes: Uint8List.fromList(bytes),
          filename: "laporan_pesanan.pdf",
        );
        return;
      }

      Directory? dir;
      try {
        dir = await getDownloadsDirectory();
      } catch (_) {
        dir = null;
      }
      dir ??= await getApplicationDocumentsDirectory();

      final file = File(
          "${dir.path}/laporan_pesanan_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("File berhasil disimpan di ${file.path}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal download PDF: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final num totalKeseluruhan =
        dataPesanan.fold<num>(0, (sum, item) => sum + _toNum(item["total"]));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Judul
          const Text(
            "Cetak Laporan",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),

          /// Filter tanggal
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: pilihTanggal,
                    icon: const Icon(Icons.date_range),
                    label: const Text("Pilih Periode"),
                  ),
                  const SizedBox(width: 12),
                  if (filterTanggal != null)
                    Text(
                      "${DateFormat("dd-MM-yyyy").format(filterTanggal!.start)} "
                      "s.d ${DateFormat("dd-MM-yyyy").format(filterTanggal!.end)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          /// Tabel laporan
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : dataPesanan.isEmpty
                    ? const Center(
                        child: Text(
                          "Belum ada data pesanan",
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 24,
                            dataRowHeight: 48,
                            headingRowHeight: 52,
                            border:
                                TableBorder.all(color: Colors.grey.shade300),
                            headingRowColor: MaterialStateProperty.all(
                              Colors.green.shade200,
                            ),
                            headingTextStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            columns: const [
                              DataColumn(label: Text("Nama Penyewa")),
                              DataColumn(label: Text("Lapangan")),
                              DataColumn(label: Text("Tanggal")),
                              DataColumn(label: Text("Jam Main")),
                              DataColumn(label: Text("Durasi")),
                              DataColumn(label: Text("Total")),
                            ],
                            rows: [
                              ...dataPesanan.map((pesanan) {
                                final tglStr = _formatTanggal(pesanan["tanggal"]);
                                final jam =
                                    "${pesanan["jamMulai"] ?? ""} - ${pesanan["jamSelesai"] ?? ""}";
                                final durasi = pesanan["durasi"] ?? "-";
                                final total = _toNum(pesanan["total"]);

                                return DataRow(cells: [
                                  DataCell(Text(pesanan["nama"] ?? "-")),
                                  DataCell(Text(pesanan["lapangan"] ?? "-")),
                                  DataCell(Center(child: Text(tglStr))),
                                  DataCell(Center(child: Text(jam))),
                                  DataCell(Center(child: Text("$durasi Jam"))),
                                  DataCell(Center(
                                      child: Text(formatRupiah.format(total)))),
                                ]);
                              }).toList(),

                              /// Baris total keseluruhan
                              DataRow(cells: [
                                const DataCell(Text(
                                  "Total Keseluruhan",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                )),
                                const DataCell(Text("")),
                                const DataCell(Text("")),
                                const DataCell(Text("")),
                                const DataCell(Text("")),
                                DataCell(Text(
                                  formatRupiah.format(totalKeseluruhan),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                )),
                              ]),
                            ],
                          ),
                        ),
                      ),
          ),

          const SizedBox(height: 20),

          /// Tombol aksi
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: dataPesanan.isEmpty ? null : cetakPDF,
                icon: const Icon(Icons.print, color: Colors.white),
                label: const Text(
                  "Cetak Laporan",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: dataPesanan.isEmpty ? null : downloadPDF,
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text(
                  "Download PDF",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.red),
                label: const Text(
                  "Batal",
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
