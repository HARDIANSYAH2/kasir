import 'package:flutter/material.dart';

class KelolaLapanganContent extends StatefulWidget {
  const KelolaLapanganContent({super.key});

  @override
  State<KelolaLapanganContent> createState() => _KelolaLapanganContentState();
}

class _KelolaLapanganContentState extends State<KelolaLapanganContent> {
  final TextEditingController namaController = TextEditingController();
  final TextEditingController nomorController = TextEditingController();
  final TextEditingController hargaController = TextEditingController();

  // List untuk menampung data lapangan
  final List<Map<String, dynamic>> _lapanganList = [];

  void _simpanLapangan() {
    final nama = namaController.text;
    final nomor = nomorController.text;
    final harga = hargaController.text;

    if (nama.isEmpty || nomor.isEmpty || harga.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Semua field wajib diisi!")),
      );
      return;
    }

    setState(() {
      _lapanganList.add({
        "nama": nama,
        "nomor": nomor,
        "harga": harga,
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Lapangan berhasil disimpan.")),
    );

    namaController.clear();
    nomorController.clear();
    hargaController.clear();
  }

  void _batalInput() {
    namaController.clear();
    nomorController.clear();
    hargaController.clear();
  }

  void _hapusLapangan(int index) {
    setState(() {
      _lapanganList.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Lapangan berhasil dihapus.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Form Input
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.green.shade100),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Tambah Data Lapangan",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                _formField("Nama Lapangan:", namaController),
                const SizedBox(height: 20),
                _formField("Nomor Lapangan:", nomorController),
                const SizedBox(height: 20),
                _formField("Harga Perjam:", hargaController,
                    inputType: TextInputType.number),
                const SizedBox(height: 30),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _simpanLapangan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 76, 175, 80),
                      ),
                      child: const Text(
                        "Simpan",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _batalInput,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text(
                        "Batal",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Tabel Data Lapangan
          const Text(
            "Daftar Lapangan",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _lapanganList.isEmpty
              ? const Text("Belum ada data lapangan.")
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    border: TableBorder.all(color: Colors.grey.shade300),
                    columns: const [
                      DataColumn(label: Text("No")),
                      DataColumn(label: Text("Nama")),
                      DataColumn(label: Text("Nomor")),
                      DataColumn(label: Text("Harga / Jam")),
                      DataColumn(label: Text("Aksi")),
                    ],
                    rows: List.generate(_lapanganList.length, (index) {
                      final lapangan = _lapanganList[index];
                      return DataRow(
                        cells: [
                          DataCell(Text("${index + 1}")),
                          DataCell(Text(lapangan["nama"])),
                          DataCell(Text(lapangan["nomor"])),
                          DataCell(Text("Rp ${lapangan["harga"]}")),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _hapusLapangan(index),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _formField(String label, TextEditingController controller,
      {TextInputType inputType = TextInputType.text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 150,
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: inputType,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
