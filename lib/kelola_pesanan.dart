import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class KelolaPesananContent extends StatefulWidget {
  final VoidCallback? onBookingSelesai;

  const KelolaPesananContent({
    super.key,
    this.onBookingSelesai,
    Map<String, dynamic>? lapanganDipilih,
  });

  @override
  State<KelolaPesananContent> createState() => _KelolaPesananContentState();
}

class _KelolaPesananContentState extends State<KelolaPesananContent> {
  final supabase = Supabase.instance.client;

  final TextEditingController namaController = TextEditingController();
  final TextEditingController durasiController = TextEditingController();
  DateTime? tanggalMain;
  String? jamMulaiDipilih;

  final List<String> jamPilihan = [
    "08:00",
    "09:00",
    "10:00",
    "11:00",
    "12:00",
    "13:00",
    "14:00",
    "15:00",
    "16:00",
    "17:00",
    "18:00",
    "19:00",
    "20:00",
    "21:00"
  ];

  List<String> jamSudahDipesan = [];
  Timer? _timer;
  String _statusLapangan = "-";

  List<Map<String, dynamic>> daftarLapangan = [];
  Map<String, dynamic>? lapanganDipilihLocal;

  @override
  void initState() {
    super.initState();
    durasiController.text = "";
    fetchLapangan();
    // langsung cek hari ini
    ambilJamYangSudahDipesan(DateTime.now());
    cekKetersediaanLapangan();

    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      cekKetersediaanLapangan();
      ambilJamYangSudahDipesan(tanggalMain ?? DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchLapangan() async {
    final response = await supabase
        .from("lapangan")
        .select()
        .order("nomor", ascending: true);
    setState(() {
      daftarLapangan = List<Map<String, dynamic>>.from(response);
    });
  }

  String hitungJamSelesai(String jamMulai, int durasi) {
    final parts = jamMulai.split(":");
    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1]);
    DateTime mulai = DateTime(2025, 1, 1, hour, minute);
    DateTime selesai = mulai.add(Duration(hours: durasi));
    String hh = selesai.hour.toString().padLeft(2, '0');
    String mm = selesai.minute.toString().padLeft(2, '0');
    return "$hh:$mm";
  }

  Future<void> ambilJamYangSudahDipesan([DateTime? tanggal]) async {
    if (lapanganDipilihLocal == null) return;

    // kalau belum pilih tanggal → pakai hari ini
    final targetTanggal = tanggal ?? DateTime.now();

    final lapanganId = lapanganDipilihLocal!["id"];
    final startOfDay =
        DateTime(targetTanggal.year, targetTanggal.month, targetTanggal.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final startStr = startOfDay.toIso8601String().split('T').first;
    final endStr = endOfDay.toIso8601String().split('T').first;

    final response = await supabase
        .from("pesanan")
        .select()
        .gte("tanggal", startStr)
        .lt("tanggal", endStr)
        .eq("lapanganid", lapanganId);

    List<String> jamBooked = [];
    DateTime sekarang = DateTime.now();

    for (var data in response) {
      String? jamMulai = data["jamMulai"]?.toString();
      int durasi = int.tryParse(data["durasi"]?.toString() ?? "") ?? 1;
      String? tanggalStr = data["tanggal"]?.toString();

      if (jamMulai != null && jamMulai.isNotEmpty && tanggalStr != null) {
        final parts = jamMulai.split(":");
        int hour = int.tryParse(parts[0]) ?? 0;

        DateTime bookingStart =
            DateTime.parse(tanggalStr).add(Duration(hours: hour));
        DateTime bookingEnd = bookingStart.add(Duration(hours: durasi));

        // hanya hitung kalau booking belum lewat
        if (bookingEnd.isAfter(sekarang)) {
          for (int i = 0; i < durasi; i++) {
            int jamBookedInt = hour + i;
            String jamStr = "${jamBookedInt.toString().padLeft(2, '0')}:00";
            jamBooked.add(jamStr);
          }
        }
      }
    }

    setState(() {
      jamSudahDipesan = jamBooked;
    });

    // update status lapangan
    if (jamSudahDipesan.length >= jamPilihan.length) {
      await supabase
          .from("lapangan")
          .update({"status": "Tidak Tersedia"}).eq("id", lapanganId);
      setState(() {
        _statusLapangan = "Tidak Tersedia";
      });
    } else {
      await supabase
          .from("lapangan")
          .update({"status": "Tersedia"}).eq("id", lapanganId);
      setState(() {
        _statusLapangan = "Tersedia";
      });
    }
  }

  Future<void> cekKetersediaanLapangan() async {
    if (lapanganDipilihLocal == null) return;
    await ambilJamYangSudahDipesan(tanggalMain ?? DateTime.now());
  }

  Future<void> tambahPesanan() async {
    if (lapanganDipilihLocal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Silakan pilih lapangan terlebih dahulu!")),
      );
      return;
    }
    if (namaController.text.isEmpty ||
        jamMulaiDipilih == null ||
        tanggalMain == null ||
        durasiController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lengkapi semua data pesanan!")),
      );
      return;
    }

    int durasi = int.tryParse(durasiController.text) ?? 1;
    if (durasi < 1 || durasi > 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Durasi hanya boleh 1 sampai 4 jam")),
      );
      return;
    }

    int mulaiBaru = int.parse(jamMulaiDipilih!.split(":")[0]);
    int selesaiBaru = mulaiBaru + durasi;

    final tanggalString =
        "${tanggalMain!.year}-${tanggalMain!.month.toString().padLeft(2, '0')}-${tanggalMain!.day.toString().padLeft(2, '0')}";

    // 🔎 cek bentrok
    final cekBentrok = await supabase
        .from("pesanan")
        .select()
        .eq("lapanganid", lapanganDipilihLocal?["id"])
        .eq("tanggal", tanggalString);

    for (var data in cekBentrok) {
      int existingMulai = int.parse(data["jamMulai"].toString().split(":")[0]);
      int existingDurasi = int.tryParse(data["durasi"].toString()) ?? 1;
      int existingSelesai = existingMulai + existingDurasi;

      bool bentrok =
          (mulaiBaru < existingSelesai && selesaiBaru > existingMulai);
      if (bentrok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lapangan ini sudah dibooking pada jam tersebut")),
        );
        return;
      }
    }

    // hitung harga
    int hargaPerJam = 0;
    var hargaRaw =
        lapanganDipilihLocal?["harga_perjam"] ?? lapanganDipilihLocal?["harga"];
    if (hargaRaw != null) {
      hargaPerJam = int.tryParse(hargaRaw.toString()) ?? 0;
    }
    if (hargaPerJam == 0) {
      final lapanganId = lapanganDipilihLocal?["id"];
      final lapanganData = await supabase
          .from("lapangan")
          .select("harga_perjam, harga")
          .eq("id", lapanganId)
          .maybeSingle();
      if (lapanganData != null) {
        hargaPerJam =
            int.tryParse(lapanganData["harga_perjam"]?.toString() ?? "") ??
                int.tryParse(lapanganData["harga"]?.toString() ?? "") ??
                0;
      }
    }

    int total = hargaPerJam * durasi;
    String jamSelesai = hitungJamSelesai(jamMulaiDipilih!, durasi);
    String lapanganText =
        "${lapanganDipilihLocal?["nama"] ?? "-"} ${lapanganDipilihLocal?["nomor"] ?? ""}".trim();

    final dataPesanan = {
      "nama": namaController.text,
      "lapanganid": lapanganDipilihLocal?["id"],
      "lapangan": lapanganText,
      "tanggal": tanggalString,
      "jamMulai": jamMulaiDipilih,
      "jamSelesai": jamSelesai,
      "durasi": durasi,
      "total": total,
      "created_at": DateTime.now().toIso8601String(),
    };

    try {
      await supabase.from("pesanan").insert(dataPesanan).select();
      await cekKetersediaanLapangan();
      await ambilJamYangSudahDipesan(tanggalMain!);

      resetForm();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pesanan berhasil disimpan ke Supabase")),
      );
      widget.onBookingSelesai?.call();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal simpan: $e")),
      );
    }
  }

 void resetForm() {
  setState(() {
    namaController.clear();
    durasiController.clear();
    jamMulaiDipilih = null;
    tanggalMain = null;
    lapanganDipilihLocal = null; 
    jamSudahDipesan = [];
    _statusLapangan = "-"; 
  });
}


  @override
  Widget build(BuildContext context) {
    final formatRupiah = NumberFormat("#,##0", "id_ID");

    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            "Status: $_statusLapangan",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: (_statusLapangan == "Tidak Tersedia")
                  ? Colors.red
                  : Colors.green,
            ),
          ),
          const SizedBox(height: 10),

          // Form Tambah Pesanan
          Card(
            margin: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text("Tambah Data Pesanan",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: namaController,
                    decoration: const InputDecoration(
                      labelText: "Nama Penyewa",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: lapanganDipilihLocal,
                    items: daftarLapangan.map((lap) {
                      return DropdownMenuItem(
                        value: lap,
                        child: Text("${lap["nama"]} ${lap["nomor"] ?? ""}"),
                      );
                    }).toList(),
                    onChanged: (val) async {
                      setState(() {
                        lapanganDipilihLocal = val;
                      });
                      await ambilJamYangSudahDipesan(tanggalMain ?? DateTime.now());
                      await cekKetersediaanLapangan();
                    },
                    decoration: const InputDecoration(
                      labelText: "Pilih Lapangan",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final pilihTanggal = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (pilihTanggal != null) {
                        setState(() {
                          tanggalMain = pilihTanggal;
                          jamMulaiDipilih = null;
                        });
                        await ambilJamYangSudahDipesan(pilihTanggal);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Tanggal Main",
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        tanggalMain != null
                            ? "${tanggalMain!.day}-${tanggalMain!.month}-${tanggalMain!.year}"
                            : "Pilih Tanggal",
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text("Jam Mulai"),
                  Wrap(
                    spacing: 8,
                    children: jamPilihan.map((jam) {
                      bool isSelected = jamMulaiDipilih == jam;
                      bool isDisabled = jamSudahDipesan.contains(jam);

                      // kalau tanggal = hari ini, jam yg sudah lewat disable
                      if (tanggalMain != null) {
                        final sekarang = DateTime.now();
                        final parts = jam.split(":");
                        final jamInt = int.parse(parts[0]);
                        final menitInt = int.parse(parts[1]);

                        final waktuJam = DateTime(
                          tanggalMain!.year,
                          tanggalMain!.month,
                          tanggalMain!.day,
                          jamInt,
                          menitInt,
                        );

                        if (waktuJam.isBefore(sekarang)) {
                          isDisabled = true;
                        }
                      }

                      return GestureDetector(
                        onTap: isDisabled
                            ? null
                            : () => setState(() => jamMulaiDipilih = jam),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.green
                                : isDisabled
                                    ? Colors.grey[300]
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Text(
                            jam,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : isDisabled
                                      ? Colors.grey
                                      : Colors.black,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: durasiController.text.isNotEmpty
                        ? int.tryParse(durasiController.text)
                        : null,
                    items: [1, 2, 3, 4]
                        .map((d) =>
                            DropdownMenuItem(value: d, child: Text("$d Jam")))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) durasiController.text = val.toString();
                    },
                    decoration: const InputDecoration(
                      labelText: "Durasi",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: tambahPesanan,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        child: const Text("Simpan",
                            style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: resetForm,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        child: const Text("Batal",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),

          // List Pesanan
          FutureBuilder<List<dynamic>>(
            future: supabase
                .from("pesanan")
                .select()
                .order("created_at", ascending: false),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }
              final pesananDocs = snapshot.data!;
              if (pesananDocs.isEmpty) {
                return const Text("Belum ada pesanan");
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.grey[200]),
                  border: TableBorder.all(color: Colors.black12),
                  columns: const [
                    DataColumn(label: Text("Nama")),
                    DataColumn(label: Text("Lapangan")),
                    DataColumn(label: Text("Tanggal")),
                    DataColumn(label: Text("Jam")),
                    DataColumn(label: Text("Durasi")),
                    DataColumn(label: Text("Total")),
                    DataColumn(label: Text("Aksi")),
                  ],
                  rows: pesananDocs.map((pesanan) {
                    final tanggal =
                        DateTime.tryParse(pesanan["tanggal"]?.toString() ?? "");
                    return DataRow(cells: [
                      DataCell(Text(pesanan["nama"] ?? "-")),
                      DataCell(Text(pesanan["lapangan"] ?? "-")),
                      DataCell(Text(tanggal != null
                          ? "${tanggal.day}-${tanggal.month}-${tanggal.year}"
                          : "-")),
                      DataCell(Text(
                          "${pesanan["jamMulai"]} - ${pesanan["jamSelesai"]}")),
                      DataCell(Text("${pesanan["durasi"]} Jam")),
                      DataCell(
                          Text("Rp ${formatRupiah.format(pesanan["total"])}")),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final konfirmasi = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text("Konfirmasi Hapus"),
                                content: const Text(
                                    "Apakah Anda yakin ingin menghapus pesanan ini?"),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text("Batal"),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red),
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text(
                                      "Hapus",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (konfirmasi == true) {
                              await supabase
                                  .from("pesanan")
                                  .delete()
                                  .eq("id", pesanan["id"]);
                              setState(() {});
                            }
                          },
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              );
            },
          )
        ],
      ),
    );
  }
}
