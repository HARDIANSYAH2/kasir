import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KelolaPesananContent extends StatefulWidget {
  final Map<String, dynamic>? lapanganDipilih;
  final VoidCallback? onBookingSelesai;

  const KelolaPesananContent({
    super.key,
    this.lapanganDipilih,
    this.onBookingSelesai,
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

  @override
  void initState() {
    super.initState();
    durasiController.text = "";
    cekKetersediaanLapangan(); // 👈 cek otomatis saat widget load
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

  Future<void> ambilJamYangSudahDipesan(DateTime tanggal) async {
    if (widget.lapanganDipilih == null) return;

    final tanggalISO =
        DateTime(tanggal.year, tanggal.month, tanggal.day).toIso8601String();

    final lapanganId = widget.lapanganDipilih!["id"];

    // ✅ Ambil booking hanya untuk lapangan & tanggal yang sama
    final response = await supabase
        .from("pesanan")
        .select()
        .eq("tanggal", tanggalISO)
        .eq("lapanganid", lapanganId);

    List<String> jamBooked = [];

    for (var data in response) {
      String? jamMulai = data["jamMulai"];
      int durasi = int.tryParse(data["durasi"].toString()) ?? 1;

      if (jamMulai != null) {
        final parts = jamMulai.split(":");
        int hour = int.tryParse(parts[0]) ?? 0;

        for (int i = 0; i < durasi; i++) {
          int jamBookedInt = hour + i;
          String jamStr = "${jamBookedInt.toString().padLeft(2, '0')}:00";
          jamBooked.add(jamStr);
        }
      }
    }

    setState(() {
      jamSudahDipesan = jamBooked;
    });
  }

  /// 🔄 Fungsi tambahan: cek ketersediaan lapangan otomatis
  Future<void> cekKetersediaanLapangan() async {
    if (widget.lapanganDipilih == null || tanggalMain == null) return;

    final lapanganId = widget.lapanganDipilih!["id"];

    // Ambil semua pesanan untuk lapangan ini
    final response = await supabase
        .from("pesanan")
        .select()
        .eq("lapanganid", lapanganId);

    bool masihAdaBookingAktif = false;
    DateTime sekarang = DateTime.now();

    for (var data in response) {
      final tanggal = DateTime.tryParse(data["tanggal"] ?? "");
      final jamSelesai = data["jamSelesai"];

      if (tanggal != null && jamSelesai != null) {
        final parts = jamSelesai.split(":");
        int hour = int.tryParse(parts[0]) ?? 0;
        int minute = int.tryParse(parts[1]) ?? 0;

        DateTime waktuSelesai =
            DateTime(tanggal.year, tanggal.month, tanggal.day, hour, minute);

        if (waktuSelesai.isAfter(sekarang)) {
          masihAdaBookingAktif = true;
          break;
        }
      }
    }

    // Update status lapangan
    await supabase.from("lapangan").update({
      "status": masihAdaBookingAktif ? "Tidak Tersedia" : "Tersedia"
    }).eq("id", lapanganId);

    setState(() {});
  }

  Future<void> tambahPesanan() async {
    if (widget.lapanganDipilih == null) {
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

    if (jamSudahDipesan.contains(jamMulaiDipilih)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Jam tersebut sudah dibooking")),
      );
      return;
    }

    int hargaPerJam = 0;
    var hargaRaw = widget.lapanganDipilih?["harga"];

    if (hargaRaw != null) {
      if (hargaRaw is int) {
        hargaPerJam = hargaRaw;
      } else if (hargaRaw is double) {
        hargaPerJam = hargaRaw.toInt();
      } else if (hargaRaw is String) {
        hargaPerJam = int.tryParse(hargaRaw) ?? 0;
      }
    }

    int total = hargaPerJam * durasi;
    String jamSelesai = hitungJamSelesai(jamMulaiDipilih!, durasi);

    String lapanganText =
        "${widget.lapanganDipilih?["nama"] ?? "-"} ${widget.lapanganDipilih?["nomor"] ?? ""}".trim();

    final dataPesanan = {
      "nama": namaController.text,
      "lapanganid": widget.lapanganDipilih?["id"],
      "lapangan": lapanganText,
      "tanggal": tanggalMain!.toIso8601String(),
      "jamMulai": jamMulaiDipilih,
      "jamSelesai": jamSelesai,
      "durasi": durasi,
      "total": total,
      "createdAt": DateTime.now().toIso8601String(),
    };

    try {
      await supabase.from("pesanan").insert(dataPesanan);

      await cekKetersediaanLapangan(); // 👈 update status otomatis

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
    });
  }

  @override
  Widget build(BuildContext context) {
    String lapanganText =
        "${widget.lapanganDipilih?["nama"] ?? ""} ${widget.lapanganDipilih?["nomor"] ?? ""}".trim();

    return SingleChildScrollView(
      child: Column(
        children: [
          // --- FORM PESANAN ---
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
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(text: lapanganText),
                    decoration: const InputDecoration(
                      labelText: "Lapangan",
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
                                        : Colors.black),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: durasiController.text.isNotEmpty
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
                            backgroundColor:
                                const Color.fromARGB(255, 70, 177, 44)),
                        child: const Text(
                          "Simpan",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: resetForm,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        child: const Text(
                          "Batal",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),

          // --- LIST PESANAN ---
          FutureBuilder<List<Map<String, dynamic>>>(
            future: supabase
                .from("pesanan")
                .select()
                .order("createdAt", ascending: false),
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
                  final pesanan = pesananDocs[index];
                  final tanggal =
                      DateTime.tryParse(pesanan["tanggal"] ?? "");

                  return Card(
                    child: ListTile(
                      title: Text(pesanan["nama"] ?? "-"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Lapangan : ${pesanan["lapangan"] ?? "-"}"),
                          Text(
                              "Tanggal  : ${tanggal != null ? "${tanggal.day}-${tanggal.month}-${tanggal.year}" : "-"}"),
                          Text(
                              "Jam      : ${pesanan["jamMulai"]} - ${pesanan["jamSelesai"]}"),
                          Text("Durasi   : ${pesanan["durasi"]} Jam"),
                          Text("Total    : Rp ${pesanan["total"]}"),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          try {
                            await supabase
                                .from("pesanan")
                                .delete()
                                .eq("id", pesanan["id"]);

                            await cekKetersediaanLapangan(); // 👈 update status otomatis

                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Pesanan berhasil dihapus")),
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
