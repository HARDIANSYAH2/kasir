import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class KelolaPesananContent extends StatefulWidget {
  const KelolaPesananContent({super.key});

  @override
  State<KelolaPesananContent> createState() => _KelolaPesananContentState();
}

class _KelolaPesananContentState extends State<KelolaPesananContent> {
  final TextEditingController namaController = TextEditingController();
  final TextEditingController lapanganController = TextEditingController();
  final TextEditingController tanggalController = TextEditingController();
  final TextEditingController durasiController = TextEditingController();

  String? selectedJam;

  final List<String> jamPilihan = ['8:00', '9:00', '10:00', '12:00'];

  void _pilihTanggalMain() async {
    DateTime? pilih = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pilih != null) {
      setState(() {
        tanggalController.text = DateFormat('dd/MM/yyyy').format(pilih);
      });
    }
  }

  void _simpanPesanan() {
    if (namaController.text.isEmpty ||
        lapanganController.text.isEmpty ||
        tanggalController.text.isEmpty ||
        selectedJam == null ||
        durasiController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Semua field wajib diisi.")),
      );
      return;
    }

    print("=== Pesanan Disimpan ===");
    print("Nama: ${namaController.text}");
    print("Lapangan: ${lapanganController.text}");
    print("Tanggal: ${tanggalController.text}");
    print("Jam: $selectedJam");
    print("Durasi: ${durasiController.text}");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Pesanan berhasil disimpan.")),
    );

    _resetForm();
  }

  void _resetForm() {
    namaController.clear();
    lapanganController.clear();
    tanggalController.clear();
    durasiController.clear();
    selectedJam = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.green.shade100),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView(
        children: [
          const Text(
            "Tambah Data Pesanan",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          _formField("Nama Penyewa:", namaController),
          const SizedBox(height: 20),
          _formField("Pilih Lapangan:", lapanganController),
          const SizedBox(height: 20),
          _formField(
            "Tanggal Main:",
            tanggalController,
            readOnly: true,
            onTap: _pilihTanggalMain,
          ),
          const SizedBox(height: 20),
          _jamPicker(),
          const SizedBox(height: 20),
          _formField("Durasi Main:", durasiController, inputType: TextInputType.number),
          const SizedBox(height: 30),
          Row(
            children: [
              ElevatedButton(
                onPressed: _simpanPesanan,
                style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 76, 175, 80)),
                child: const Text("Simpan", style: TextStyle(color: Colors.white),),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _resetForm,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Batal",style: TextStyle(color: Colors.white),),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _formField(
    String label,
    TextEditingController controller, {
    TextInputType inputType = TextInputType.text,
    bool readOnly = false,
    void Function()? onTap,
  }) {
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
            readOnly: readOnly,
            onTap: onTap,
            keyboardType: inputType,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _jamPicker() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: 150,
          child: Text("Jam Mulai:", style: TextStyle(fontSize: 16)),
        ),
        Expanded(
          child: Wrap(
            spacing: 10,
            children: jamPilihan.map((jam) {
              final bool aktif = selectedJam == jam;
              return ElevatedButton(
                onPressed: () {
                  setState(() {
                    selectedJam = jam;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: aktif ? Colors.green : Colors.grey[300],
                  foregroundColor: aktif ? Colors.white : Colors.black,
                ),
                child: Text(jam),
              );
            }).toList(),
          ),
        )
      ],
    );
  }
}
