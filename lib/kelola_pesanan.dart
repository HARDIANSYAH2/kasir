import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KelolaPesananContent extends StatefulWidget {
  final VoidCallback? onBookingSelesai;

  const KelolaPesananContent({
    super.key,
    this.onBookingSelesai, Map<String, dynamic>? lapanganDipilih,
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
    "08:00", "09:00", "10:00", "11:00", "12:00",
    "13:00", "14:00", "15:00", "16:00", "17:00",
    "18:00", "19:00", "20:00", "21:00"
  ];

  List<String> jamSudahDipesan = [];
  Timer? _timer;
  String _statusLapangan = "-";

  // daftar lapangan & lapangan dipilih
  List<Map<String, dynamic>> daftarLapangan = [];
  Map<String, dynamic>? lapanganDipilihLocal;

  @override
  void initState() {
    super.initState();
    durasiController.text = "";
    fetchLapangan();
    cekKetersediaanLapangan();

    // auto cek tiap menit biar jam bisa aktif lagi
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      cekKetersediaanLapangan();
      if (tanggalMain != null) {
        ambilJamYangSudahDipesan(tanggalMain!);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchLapangan() async {
    final response = await supabase.from("lapangan").select();
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

  /// ✅ perbaikan: filter jam yang sudah lewat supaya bisa aktif lagi
  Future<void> ambilJamYangSudahDipesan(DateTime tanggal) async {
    if (lapanganDipilihLocal == null) return;

    final lapanganId = lapanganDipilihLocal!["id"];
    final startOfDay = DateTime(tanggal.year, tanggal.month, tanggal.day);
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

        DateTime bookingStart = DateTime.parse(tanggalStr).add(Duration(hours: hour));
        DateTime bookingEnd = bookingStart.add(Duration(hours: durasi));

        // ✅ hanya simpan booking kalau belum lewat jam selesai
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
      await supabase.from("lapangan").update({"status": "Tidak Tersedia"}).eq("id", lapanganId);
      setState(() {
        _statusLapangan = "Tidak Tersedia";
      });
    } else {
      await supabase.from("lapangan").update({"status": "Tersedia"}).eq("id", lapanganId);
      setState(() {
        _statusLapangan = "Tersedia";
      });
    }
  }

  Future<void> cekKetersediaanLapangan() async {
    if (lapanganDipilihLocal == null) return;

    final lapanganId = lapanganDipilihLocal!["id"];
    final response = await supabase.from("pesanan").select().eq("lapanganid", lapanganId);

    bool masihAdaBookingAktif = false;
    DateTime sekarang = DateTime.now();

    for (var data in response) {
      final tanggal = DateTime.tryParse(data["tanggal"]?.toString() ?? "");
      final jamSelesai = data["jamSelesai"]?.toString();
      if (tanggal != null && jamSelesai != null && jamSelesai.isNotEmpty) {
        final parts = jamSelesai.split(":");
        int hour = int.tryParse(parts[0]) ?? 0;
        int minute = int.tryParse(parts[1]) ?? 0;
        DateTime waktuSelesai = DateTime(tanggal.year, tanggal.month, tanggal.day, hour, minute);
        if (waktuSelesai.isAfter(sekarang)) {
          masihAdaBookingAktif = true;
          break;
        }
      }
    }

    final statusBaru = masihAdaBookingAktif ? "Tidak Tersedia" : "Tersedia";

    await supabase.from("lapangan").update({"status": statusBaru}).eq("id", lapanganId);

    setState(() {
      _statusLapangan = statusBaru;
    });
  }

  Future<void> tambahPesanan() async {
    if (lapanganDipilihLocal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Silakan pilih lapangan terlebih dahulu!")),
      );
      return;
    }
    if (namaController.text.isEmpty || jamMulaiDipilih == null || tanggalMain == null || durasiController.text.isEmpty) {
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

    for (String jam in jamSudahDipesan) {
      int jamBooked = int.parse(jam.split(":")[0]);
      if (jamBooked >= mulaiBaru && jamBooked < selesaiBaru) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Waktu yang dipilih sudah dibooking")),
        );
        return;
      }
    }

    int hargaPerJam = 0;
    var hargaRaw = lapanganDipilihLocal?["harga_perjam"] ?? lapanganDipilihLocal?["harga"];
    if (hargaRaw != null) {
      hargaPerJam = int.tryParse(hargaRaw.toString()) ?? 0;
    }
    if (hargaPerJam == 0) {
      final lapanganId = lapanganDipilihLocal?["id"];
      final lapanganData = await supabase.from("lapangan").select("harga_perjam, harga").eq("id", lapanganId).maybeSingle();
      if (lapanganData != null) {
        hargaPerJam =
            int.tryParse(lapanganData["harga_perjam"]?.toString() ?? "") ??
            int.tryParse(lapanganData["harga"]?.toString() ?? "") ??
            0;
      }
    }

    int total = hargaPerJam * durasi;
    String jamSelesai = hitungJamSelesai(jamMulaiDipilih!, durasi);

    String lapanganText = "${lapanganDipilihLocal?["nama"] ?? "-"} ${lapanganDipilihLocal?["nomor"] ?? ""}".trim();

    final tanggalString =
        "${tanggalMain!.year}-${tanggalMain!.month.toString().padLeft(2, '0')}-${tanggalMain!.day.toString().padLeft(2, '0')}";

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
      if (tanggalMain != null) {
        await ambilJamYangSudahDipesan(tanggalMain!);
      }

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
      jamSudahDipesan = [];
      lapanganDipilihLocal = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            "Status: $_statusLapangan",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: (_statusLapangan == "Tidak Tersedia") ? Colors.red : Colors.green,
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      if (tanggalMain != null) {
                        await ambilJamYangSudahDipesan(tanggalMain!);
                      }
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

                      return GestureDetector(
                        onTap: isDisabled ? null : () => setState(() => jamMulaiDipilih = jam),
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
                                        : Colors.black),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: durasiController.text.isNotEmpty ? int.tryParse(durasiController.text) : null,
                    items: [1, 2, 3, 4].map((d) => DropdownMenuItem(value: d, child: Text("$d Jam"))).toList(),
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
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text("Simpan", style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: resetForm,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text("Batal", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),

          // List Pesanan
          FutureBuilder<List<dynamic>>(
            future: supabase.from("pesanan").select().order("created_at", ascending: false),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }
              final pesananDocs = snapshot.data!;
              if (pesananDocs.isEmpty) {
                return const Text("Belum ada pesanan");
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pesananDocs.length,
                itemBuilder: (context, index) {
                  final pesanan = pesananDocs[index] as Map<String, dynamic>;
                  final tanggal = DateTime.tryParse(pesanan["tanggal"]?.toString() ?? "");
                  return Card(
                    child: ListTile(
                      title: Text(pesanan["nama"] ?? "-"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Lapangan : ${pesanan["lapangan"] ?? "-"}"),
                          Text("Tanggal  : ${tanggal != null ? "${tanggal.day}-${tanggal.month}-${tanggal.year}" : "-"}"),
                          Text("Jam      : ${pesanan["jamMulai"]} - ${pesanan["jamSelesai"]}"),
                          Text("Durasi   : ${pesanan["durasi"]} Jam"),
                          Text("Total    : Rp ${pesanan["total"]}"),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          try {
                            await supabase.from("pesanan").delete().eq("id", pesanan["id"]);
                            await cekKetersediaanLapangan();
                            if (tanggalMain != null) {
                              await ambilJamYangSudahDipesan(tanggalMain!);
                            }
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Pesanan berhasil dihapus")),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Gagal hapus: $e")),
                            );
                          }
                        },
                      ),
                    ),
                  );
                },
              );
            },
          )
        ],
      ),
    );
  }
}
