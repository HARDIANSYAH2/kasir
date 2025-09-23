import 'package:flutter/material.dart';

class KelolaPesananContent extends StatefulWidget {
  final Map<String, dynamic>? lapanganDipilih;

  const KelolaPesananContent({super.key, this.lapanganDipilih});

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

  /// daftar pesanan
  List<Map<String, dynamic>> daftarPesanan = [];

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

  void tambahPesanan() {
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

    // validasi durasi 1–4 jam
    if (durasi < 1 || durasi > 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Durasi hanya boleh 1 sampai 4 jam")),
      );
      return;
    }

    String nama = namaController.text;
    String harga = widget.lapanganDipilih?["harga"] ?? "0";
    int total = int.parse(harga) * durasi;
    String jamSelesai = hitungJamSelesai(jamMulaiDipilih!, durasi);

    // gabung nama lapangan + nomor lapangan
    String lapanganText =
        "${widget.lapanganDipilih?["nama"] ?? "-"} ${widget.lapanganDipilih?["nomor"] ?? ""}".trim();

    setState(() {
      daftarPesanan.add({
        "nama": nama,
        "lapangan": lapanganText,
        "tanggal":
            "${tanggalMain!.day}-${tanggalMain!.month}-${tanggalMain!.year}",
        "jamMulai": jamMulaiDipilih,
        "jamSelesai": jamSelesai,
        "durasi": durasi,
        "total": total,
      });
    });

    resetForm();
  }

  void resetForm() {
    setState(() {
      namaController.clear();
      durasiController.clear();
      jamMulaiDipilih = null;
      tanggalMain = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // tampilkan lapangan + nomor di form
    String lapanganText =
        "${widget.lapanganDipilih?["nama"] ?? ""} ${widget.lapanganDipilih?["nomor"] ?? ""}".trim();

    return SingleChildScrollView(
      child: Column(
        children: [
          // FORM INPUT
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

                  // Nama Penyewa
                  TextField(
                    controller: namaController,
                    decoration: const InputDecoration(
                      labelText: "Nama Penyewa",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Pilih Lapangan (readonly)
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(text: lapanganText),
                    decoration: const InputDecoration(
                      labelText: "Pilih Lapangan",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tanggal Main
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
                        });
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

                  // Jam Mulai (Model Tombol)
                  const Text("Jam Mulai",
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: jamPilihan.map((jam) {
                      bool isSelected = jamMulaiDipilih == jam;

                      Color bgColor;
                      Color textColor = Colors.black;

                      if (isSelected) {
                        bgColor = Colors.green;
                        textColor = Colors.white;
                      } else {
                        bgColor = Colors.white;
                      }

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            jamMulaiDipilih = jam;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Text(
                            jam,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Durasi (Dropdown 1–4 jam)
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

                  // Tombol Aksi
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
                        child: const Text("Batal",style: TextStyle(color: Colors.white),),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),

          // LIST PESANAN
          if (daftarPesanan.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Daftar Pesanan",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: daftarPesanan.length,
                    itemBuilder: (context, index) {
                      var pesanan = daftarPesanan[index];
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
                              Text("Tanggal  : ${pesanan["tanggal"]}"),
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
                                onPressed: () {
                                  setState(() {
                                    namaController.text = pesanan["nama"];
                                    durasiController.text =
                                        pesanan["durasi"].toString();
                                    jamMulaiDipilih = pesanan["jamMulai"];
                                    List<String> tgl =
                                        pesanan["tanggal"].split("-");
                                    tanggalMain = DateTime(
                                      int.parse(tgl[2]),
                                      int.parse(tgl[1]),
                                      int.parse(tgl[0]),
                                    );
                                    daftarPesanan.removeAt(index);
                                  });
                                },
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    daftarPesanan.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
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
