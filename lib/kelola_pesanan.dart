import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final TextEditingController namaController = TextEditingController();
  final TextEditingController durasiController = TextEditingController();
  DateTime? tanggalMain;
  String? jamMulaiDipilih;

  final List<String> jamPilihan = [
    "08:00", "09:00", "10:00", "11:00", "12:00",
    "13:00", "14:00", "15:00", "16:00", "17:00",
    "18:00", "19:00", "20:00", "21:00"
  ];

  // List jam yang sudah dipesan di tanggal yang sama
  List<String> jamSudahDipesan = [];

  @override
  void initState() {
    super.initState();
    durasiController.text = "";
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

  /// Ambil jam yang sudah dipesan pada tanggal tertentu
  Future<void> ambilJamYangSudahDipesan(DateTime tanggal) async {
    // Kita coba cari pesanan di Firestore dengan field "tanggal" sama
    final snapshot = await FirebaseFirestore.instance
        .collection("pesanan")
        .where("tanggal", isEqualTo: Timestamp.fromDate(
            DateTime(tanggal.year, tanggal.month, tanggal.day)))
        .get();

    List<String> jamBooked = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      String? jamMulai = data["jamMulai"];
      int durasi = int.tryParse(data["durasi"].toString()) ?? 1;

      if (jamMulai != null) {
        final parts = jamMulai.split(":");
        int hour = int.tryParse(parts[0]) ?? 0;

        // tambahkan jamMulai dan jam berikutnya sesuai durasi
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

    // Pastikan jamMulaiDipilih tidak termasuk jamSudahDipesan
    if (jamSudahDipesan.contains(jamMulaiDipilih)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Jam tersebut sudah dibooking")),
      );
      return;
    }

    int hargaPerJam = 0;
    if (widget.lapanganDipilih?["harga"] != null) {
      if (widget.lapanganDipilih!["harga"] is int) {
        hargaPerJam = widget.lapanganDipilih!["harga"];
      } else if (widget.lapanganDipilih!["harga"] is String) {
        hargaPerJam = int.tryParse(widget.lapanganDipilih!["harga"]) ?? 0;
      }
    }

    int total = hargaPerJam * durasi;
    String jamSelesai = hitungJamSelesai(jamMulaiDipilih!, durasi);

    String lapanganText =
        "${widget.lapanganDipilih?["nama"] ?? "-"} ${widget.lapanganDipilih?["nomor"] ?? ""}".trim();

    Map<String, dynamic> dataPesanan = {
      "nama": namaController.text,
      "lapanganId": widget.lapanganDipilih?["id"],
      "lapangan": lapanganText,
      "tanggal": Timestamp.fromDate(tanggalMain!),
      "jamMulai": jamMulaiDipilih,
      "jamSelesai": jamSelesai,
      "durasi": durasi,
      "total": total,
      "createdAt": FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance.collection("pesanan").add(dataPesanan);

      if (widget.lapanganDipilih?["id"] != null) {
        await FirebaseFirestore.instance
            .collection("lapangan")
            .doc(widget.lapanganDipilih!["id"])
            .update({"status": "Tidak Tersedia"});
      }

      resetForm();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pesanan berhasil disimpan ke Firebase")),
      );
      if (widget.onBookingSelesai != null) {
        widget.onBookingSelesai!();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal simpan: $e")),
      );
    }
  }

  Future<void> editPesanan(DocumentSnapshot doc) async {
    var pesanan = doc.data() as Map<String, dynamic>;

    final TextEditingController editNama =
        TextEditingController(text: pesanan["nama"]);
    final TextEditingController editDurasi =
        TextEditingController(text: pesanan["durasi"].toString());

    DateTime? editTanggal;
    try {
      editTanggal = (pesanan["tanggal"] as Timestamp).toDate();
    } catch (e) {
      editTanggal = null;
    }

    String? editJam = pesanan["jamMulai"];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text("Edit Pesanan"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: editNama,
                    decoration: const InputDecoration(labelText: "Nama Penyewa"),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () async {
                      final pilihTanggal = await showDatePicker(
                        context: context,
                        initialDate: editTanggal ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (pilihTanggal != null) {
                        setStateDialog(() {
                          editTanggal = pilihTanggal;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Tanggal Main",
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        editTanggal != null
                            ? "${editTanggal!.day}-${editTanggal!.month}-${editTanggal!.year}"
                            : "Pilih Tanggal",
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: editJam,
                    items: jamPilihan.map((jam) {
                      return DropdownMenuItem(
                        value: jam,
                        child: Text(jam),
                      );
                    }).toList(),
                    decoration: const InputDecoration(
                        labelText: "Jam Mulai", border: OutlineInputBorder()),
                    onChanged: (val) {
                      setStateDialog(() {
                        editJam = val;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: int.tryParse(editDurasi.text),
                    items: [1, 2, 3, 4].map((d) {
                      return DropdownMenuItem<int>(
                        value: d,
                        child: Text("$d Jam"),
                      );
                    }).toList(),
                    decoration: const InputDecoration(
                        labelText: "Durasi", border: OutlineInputBorder()),
                    onChanged: (val) {
                      if (val != null) {
                        editDurasi.text = val.toString();
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text("Batal"),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: const Text("Simpan"),
                onPressed: () async {
                  if (editNama.text.isEmpty || editJam == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Nama dan Jam tidak boleh kosong!")),
                    );
                    return;
                  }

                  int durasi = int.tryParse(editDurasi.text) ?? 1;
                  String jamSelesai =
                      hitungJamSelesai(editJam ?? "08:00", durasi);

                  int hargaPerJam = 0;
                  if (pesanan["total"] != null && pesanan["durasi"] != null) {
                    int totalLama =
                        int.tryParse(pesanan["total"].toString()) ?? 0;
                    int durasiLama =
                        int.tryParse(pesanan["durasi"].toString()) ?? 1;
                    if (durasiLama > 0) {
                      hargaPerJam = totalLama ~/ durasiLama;
                    }
                  }
                  int totalBaru = hargaPerJam * durasi;

                  try {
                    await doc.reference.update({
                      "nama": editNama.text,
                      "lapangan": pesanan["lapangan"],
                      "tanggal":
                          Timestamp.fromDate(editTanggal ?? DateTime.now()),
                      "jamMulai": editJam,
                      "jamSelesai": jamSelesai,
                      "durasi": durasi,
                      "total": totalBaru,
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Pesanan berhasil diupdate")),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Gagal update: $e")),
                    );
                  }
                },
              ),
            ],
          );
        });
      },
    );
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
          Card(
            margin: const EdgeInsets.all(20),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  StreamBuilder<DocumentSnapshot>(
                    stream: widget.lapanganDipilih?["id"] != null
                        ? FirebaseFirestore.instance
                            .collection("lapangan")
                            .doc(widget.lapanganDipilih!["id"])
                            .snapshots()
                        : null,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }

                      if (!snapshot.hasData ||
                          snapshot.data == null ||
                          (snapshot.data!.data() as Map<String, dynamic>)["status"] !=
                              "Tersedia") {
                        return const TextField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: "Lapangan",
                            border: OutlineInputBorder(),
                            hintText: "Tidak ada lapangan tersedia",
                          ),
                        );
                      }

                      return TextField(
                        readOnly: true,
                        controller: TextEditingController(text: lapanganText),
                        decoration: const InputDecoration(
                          labelText: "Lapangan",
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
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
                  const Text("Jam Mulai",
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: jamPilihan.map((jam) {
                      bool isSelected = jamMulaiDipilih == jam;
                      bool isDisabled = jamSudahDipesan.contains(jam);

                      return GestureDetector(
                        onTap: isDisabled
                            ? null
                            : () {
                                setState(() {
                                  jamMulaiDipilih = jam;
                                });
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
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
                              fontWeight: FontWeight.bold,
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
                    items: [1, 2, 3, 4].map((d) {
                      return DropdownMenuItem<int>(
                        value: d,
                        child: Text("$d Jam"),
                      );
                    }).toList(),
                    decoration: const InputDecoration(
                      labelText: "Durasi Main",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        durasiController.text = val.toString();
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: tambahPesanan,
                        child: const Text("Simpan",
                            style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: resetForm,
                        child: const Text("Batal",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),

          // ===== DAFTAR PESANAN =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Daftar Pesanan",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("pesanan")
                      .orderBy("createdAt", descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Text("Belum ada pesanan");
                    }

                    var pesananDocs = snapshot.data!.docs;

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pesananDocs.length,
                      itemBuilder: (context, index) {
                        var doc = pesananDocs[index];
                        var pesanan = doc.data() as Map<String, dynamic>;

                        DateTime tanggal =
                            (pesanan["tanggal"] as Timestamp).toDate();

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          elevation: 2,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            title: Text(
                              pesanan["nama"],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Lapangan : ${pesanan["lapangan"]}"),
                                Text(
                                    "Tanggal  : ${tanggal.day}-${tanggal.month}-${tanggal.year}"),
                                Text(
                                    "Jam      : ${pesanan["jamMulai"]} - ${pesanan["jamSelesai"]}"),
                                Text("Durasi   : ${pesanan["durasi"]} Jam"),
                                Text("Total    : Rp ${pesanan["total"]}"),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => editPesanan(doc),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    try {
                                      String? lapanganId = pesanan["lapanganId"];
                                      await doc.reference.delete();

                                      if (lapanganId != null) {
                                        await FirebaseFirestore.instance
                                            .collection("lapangan")
                                            .doc(lapanganId)
                                            .update({"status": "Tersedia"});
                                      }

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content:
                                                  Text("Pesanan berhasil dihapus")));
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Gagal hapus: $e")),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
