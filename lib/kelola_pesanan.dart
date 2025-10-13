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
    "08:00","09:00","10:00","11:00","12:00",
    "13:00","14:00","15:00","16:00","17:00",
    "18:00","19:00","20:00","21:00"
  ];

  List<String> jamSudahDipesan = [];
  Timer? _timer;
  String _statusLapangan = "-";
  List<Map<String, dynamic>> daftarLapangan = [];
  Map<String, dynamic>? lapanganDipilihLocal;

  final Color bgColor = const Color.fromARGB(255, 255, 255, 255);
  final Color cardColor = const Color(0xFFE9F8E9);
  final Color primaryGreen = const Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    durasiController.text = "";
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchLapangan();
      ambilJamYangSudahDipesan(DateTime.now());
      cekKetersediaanLapangan();
    });

    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      cekKetersediaanLapangan();
      ambilJamYangSudahDipesan(tanggalMain ?? DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    namaController.dispose();
    durasiController.dispose();
    super.dispose();
  }

  Future<void> fetchLapangan() async {
    try {
      final response = await supabase
          .from("lapangan")
          .select()
          .order("nomor", ascending: true);
      if (mounted) {
        setState(() {
          daftarLapangan = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint("Error fetchLapangan: $e");
    }
  }

  String hitungJamSelesai(String jamMulai, int durasi) {
    final parts = jamMulai.split(":");
    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1]);
    DateTime mulai = DateTime(2025, 1, 1, hour, minute);
    DateTime selesai = mulai.add(Duration(hours: durasi));
    return "${selesai.hour.toString().padLeft(2, '0')}:${selesai.minute.toString().padLeft(2, '0')}";
  }

  Future<void> ambilJamYangSudahDipesan([DateTime? tanggal]) async {
    if (lapanganDipilihLocal == null) return;
    try {
      final targetTanggal = tanggal ?? DateTime.now();
      final lapanganId = lapanganDipilihLocal!["id"];
      final startOfDay = DateTime(targetTanggal.year, targetTanggal.month, targetTanggal.day);
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

        if (jamMulai != null && tanggalStr != null) {
          final parts = jamMulai.split(":");
          int hour = int.tryParse(parts[0]) ?? 0;
          DateTime bookingStart = DateTime.parse(tanggalStr).add(Duration(hours: hour));
          DateTime bookingEnd = bookingStart.add(Duration(hours: durasi));
          if (bookingEnd.isAfter(sekarang)) {
            for (int i = 0; i < durasi; i++) {
              jamBooked.add("${(hour + i).toString().padLeft(2, '0')}:00");
            }
          }
        }
      }

      if (targetTanggal.year == sekarang.year &&
          targetTanggal.month == sekarang.month &&
          targetTanggal.day == sekarang.day) {
        for (var jam in jamPilihan) {
          final jamInt = int.parse(jam.split(":")[0]);
          if (jamInt <= sekarang.hour) jamBooked.add(jam);
        }
      }

      bool semuaJamTidakTersedia = jamBooked.toSet().length >= jamPilihan.length;

      await supabase
          .from("lapangan")
          .update({"status": semuaJamTidakTersedia ? "Tidak Tersedia" : "Tersedia"})
          .eq("id", lapanganId);

      if (mounted) {
        setState(() {
          jamSudahDipesan = jamBooked.toSet().toList();
          _statusLapangan = semuaJamTidakTersedia ? "Tidak Tersedia" : "Tersedia";
        });
      }
    } catch (e) {
      debugPrint("Error ambilJamYangSudahDipesan: $e");
    }
  }

  Future<void> cekKetersediaanLapangan() async {
    if (lapanganDipilihLocal == null) return;
    await ambilJamYangSudahDipesan(tanggalMain ?? DateTime.now());
  }

  Future<void> tambahPesanan() async {
    if (lapanganDipilihLocal == null ||
        namaController.text.isEmpty ||
        jamMulaiDipilih == null ||
        tanggalMain == null ||
        durasiController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lengkapi semua data pesanan!")),
      );
      return;
    }
    try {
      int durasi = int.tryParse(durasiController.text) ?? 1;
      int mulaiBaru = int.parse(jamMulaiDipilih!.split(":")[0]);
      int selesaiBaru = mulaiBaru + durasi;

      final tanggalString =
          "${tanggalMain!.year}-${tanggalMain!.month.toString().padLeft(2, '0')}-${tanggalMain!.day.toString().padLeft(2, '0')}";

      final cekBentrok = await supabase
          .from("pesanan")
          .select()
          .eq("lapanganid", lapanganDipilihLocal?["id"])
          .eq("tanggal", tanggalString);

      for (var data in cekBentrok) {
        int existingMulai = int.parse(data["jamMulai"].toString().split(":")[0]);
        int existingDurasi = int.tryParse(data["durasi"].toString()) ?? 1;
        int existingSelesai = existingMulai + existingDurasi;
        bool bentrok = (mulaiBaru < existingSelesai && selesaiBaru > existingMulai);
        if (bentrok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Jam ini sudah dibooking")),
          );
          return;
        }
      }

      int hargaPerJam = int.tryParse(
            (lapanganDipilihLocal?["harga_perjam"] ?? lapanganDipilihLocal?["harga"]).toString(),
          ) ?? 0;
      int total = hargaPerJam * durasi;
      String jamSelesai = hitungJamSelesai(jamMulaiDipilih!, durasi);

      final dataPesanan = {
        "nama": namaController.text,
        "lapanganid": lapanganDipilihLocal?["id"],
        "lapangan": "${lapanganDipilihLocal?["nama"]} ${lapanganDipilihLocal?["nomor"] ?? ""}".trim(),
        "tanggal": tanggalString,
        "jamMulai": jamMulaiDipilih,
        "jamSelesai": jamSelesai,
        "durasi": durasi,
        "total": total,
        "created_at": DateTime.now().toIso8601String(),
      };

      await supabase.from("pesanan").insert(dataPesanan);
      await ambilJamYangSudahDipesan(tanggalMain!);

      resetForm();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pesanan berhasil disimpan!")),
      );

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error tambahPesanan: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal menyimpan pesanan")),
      );
    }
  }

  Future<void> hapusPesanan(String id) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Konfirmasi Hapus"),
        content: const Text("Apakah Anda yakin ingin menghapus pesanan ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Batal",style: TextStyle(color: Colors.black),),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (konfirmasi == true) {
      await supabase.from("pesanan").delete().eq("id", id);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pesanan berhasil dihapus")),
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
    InputBorder roundedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
    );

    return Container(
      color: bgColor,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= FORM TAMBAH PESANAN ================= \\
              Card(
                color: cardColor,
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        "Tambah Data Pesanan",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          "Status: $_statusLapangan",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: (_statusLapangan == "Tidak Tersedia")
                                ? Colors.red
                                : primaryGreen,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      TextField(
                        controller: namaController,
                        decoration: InputDecoration(
                          labelText: "Nama Penyewa",
                          prefixIcon: const Icon(Icons.person_outline),
                          border: roundedBorder,
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: lapanganDipilihLocal,
                        items: daftarLapangan.map((lap) {
                          return DropdownMenuItem(
                            value: lap,
                            child: Text("${lap["nama"]} ${lap["nomor"] ?? ""}"),
                          );
                        }).toList(),
                        onChanged: (val) async {
                          setState(() => lapanganDipilihLocal = val);
                          await ambilJamYangSudahDipesan(tanggalMain ?? DateTime.now());
                        },
                        decoration: InputDecoration(
                          labelText: "Pilih Lapangan",
                          prefixIcon: const Icon(Icons.sports_tennis_outlined),
                          border: roundedBorder,
                        ),
                      ),
                      const SizedBox(height: 14),
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
                          decoration: InputDecoration(
                            labelText: "Tanggal Main",
                            prefixIcon: const Icon(Icons.calendar_today_outlined),
                            border: roundedBorder,
                          ),
                          child: Text(
                            tanggalMain != null
                                ? "${tanggalMain!.day}-${tanggalMain!.month}-${tanggalMain!.year}"
                                : "Pilih Tanggal",
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Jam Mulai",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: jamPilihan.map((jam) {
                          bool isSelected = jamMulaiDipilih == jam;
                          bool isDisabled = jamSudahDipesan.contains(jam);
                          return ChoiceChip(
                            label: Text(jam),
                            selected: isSelected,
                            onSelected: isDisabled ? null : (_) => setState(() => jamMulaiDipilih = jam),
                            selectedColor: primaryGreen,
                            disabledColor: Colors.grey[300],
                            backgroundColor: Colors.white,
                            elevation: isSelected ? 3 : 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : isDisabled
                                      ? Colors.grey
                                      : Colors.black,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<int>(
                        value: durasiController.text.isNotEmpty
                            ? int.tryParse(durasiController.text)
                            : null,
                        items: [1, 2, 3, 4]
                            .map((d) => DropdownMenuItem(value: d, child: Text("$d Jam")))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) durasiController.text = val.toString();
                        },
                        decoration: InputDecoration(
                          labelText: "Durasi",
                          prefixIcon: const Icon(Icons.timer_outlined),
                          border: roundedBorder,
                        ),
                      ),
                      const SizedBox(height: 26),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: tambahPesanan,
                            icon: const Icon(Icons.save, color: Colors.white),
                            label: const Text("Simpan", style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 3,
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: resetForm,
                            icon: const Icon(Icons.cancel, color: Colors.white),
                            label: const Text("Batal", style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),
              // ================= DAFTAR PESANAN ================= \\
              Text(
                "Daftar Pesanan",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen),
              ),
              const SizedBox(height: 10),
              Card(
                color: cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: supabase
                        .from("pesanan")
                        .select()
                        .order("created_at", ascending: false) as Future<List<Map<String, dynamic>>>,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text("Terjadi kesalahan: ${snapshot.error}"),
                        );
                      }

                      final pesananDocs = snapshot.data ?? [];
                      if (pesananDocs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: Text("Belum ada pesanan")),
                        );
                      }

                      return Column(
                        children: pesananDocs.map((data) {
                          return ListTile(
                            title: Text(
                              data["nama"] ?? "",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "${data["lapangan"] ?? "-"} • ${data["tanggal"] ?? "-"} • ${data["jamMulai"] ?? "-"} - ${data["jamSelesai"] ?? "-"} • ${data["durasi"]} jam",
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Rp ${formatRupiah.format(data["total"] ?? 0)}",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => hapusPesanan(data["id"].toString()),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
