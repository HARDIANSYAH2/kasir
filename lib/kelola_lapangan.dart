import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

class KelolaLapanganContent extends StatefulWidget {
  const KelolaLapanganContent({super.key});

  @override
  State<KelolaLapanganContent> createState() => _KelolaLapanganContentState();
}

class _KelolaLapanganContentState extends State<KelolaLapanganContent> {
  final supabase = Supabase.instance.client;

  final TextEditingController nomorController = TextEditingController();
  final TextEditingController hargaController = TextEditingController();

  Uint8List? _pickedBytes;
  String? _imageUrl;
  bool _isLoading = false;
  bool _isUploadingImage = false;
  String? _editingId;

  final NumberFormat rupiahFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  // === Upload Gambar === \\
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final fileBytes = result.files.first.bytes;
    final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
    final filePath = "lapangan/$fileName";

    if (fileBytes == null) return;

    setState(() {
      _isUploadingImage = true;
      _pickedBytes = fileBytes;
    });

    try {
      await supabase.storage.from("lapangan").uploadBinary(
            filePath,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl =
          supabase.storage.from("lapangan").getPublicUrl(filePath);

      setState(() {
        _imageUrl = publicUrl;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal upload gambar: $e")),
      );
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  // === Simpan atau Update === \\
  Future<void> _simpanLapangan() async {
    final nomor = nomorController.text.trim();
    final harga = int.tryParse(hargaController.text.trim()) ?? 0;

    if (nomor.isEmpty || harga == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nomor & Harga wajib diisi!")),
      );
      return;
    }

    if ((_imageUrl ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gambar wajib diisi")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_editingId == null) {
        await supabase.from("lapangan").insert({
          "nama": "Lapangan Badminton",
          "nomor": nomor,
          "harga_perjam": harga,
          "gambar_url": _imageUrl ?? "",
          "status": "Tersedia",
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lapangan berhasil disimpan.")),
        );
      } else {
        await supabase.from("lapangan").update({
          "nomor": nomor,
          "harga_perjam": harga,
          "gambar_url": _imageUrl ?? "",
        }).eq("id", _editingId!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lapangan berhasil diperbarui.")),
        );
      }

      _resetForm();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal simpan lapangan: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // === Popup Konfirmasi Hapus === \\
  Future<void> _konfirmasiHapus(String id) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi Hapus"),
        content: const Text("Yakin ingin menghapus lapangan ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text("Hapus",style: TextStyle(color: Colors.white),),
          ),
        ],
      ),
    );

    if (konfirmasi == true) {
      _hapusLapangan(id);
    }
  }

  // === Hapus === \\
  Future<void> _hapusLapangan(String id) async {
    try {
      await supabase.from("lapangan").delete().eq("id", id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lapangan berhasil dihapus.")),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal hapus lapangan: $e")),
      );
    }
  }

  // === Popup Edit === \\
  Future<void> _konfirmasiEdit(Map<String, dynamic> data) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Lapangan"),
        content: const Text("Apakah Anda ingin mengedit data ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Edit"),
          ),
        ],
      ),
    );

    if (konfirmasi == true) {
      _editLapangan(data);
    }
  }

  // === Edit === \\
  void _editLapangan(Map<String, dynamic> data) {
    setState(() {
      _editingId = data["id"].toString();
      nomorController.text = data["nomor"]?.toString() ?? "";
      hargaController.text = data["harga_perjam"]?.toString() ?? "";
      _imageUrl = data["gambar_url"];
      _pickedBytes = null;
    });
  }

  void _resetForm() {
    nomorController.clear();
    hargaController.clear();
    setState(() {
      _pickedBytes = null;
      _imageUrl = null;
      _editingId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === Form === \\
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
                Text(
                  _editingId == null
                      ? "Tambah Data Lapangan"
                      : "Edit Data Lapangan",
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _formField("Nomor Lapangan:", nomorController),
                const SizedBox(height: 20),
                _formField("Harga Perjam:", hargaController,
                    inputType: TextInputType.number),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 150,
                      child: Text("Gambar Lapangan:",
                          style: TextStyle(fontSize: 16)),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          if (_pickedBytes != null)
                            Image.memory(_pickedBytes!,
                                height: 120, fit: BoxFit.cover)
                          else if (_imageUrl != null)
                            Image.network(_imageUrl!,
                                height: 120, fit: BoxFit.cover)
                          else
                            const Text("Belum ada gambar"),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _isUploadingImage ? null : _pickImage,
                            icon: _isUploadingImage
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.image),
                            label: Text(_isUploadingImage
                                ? "Mengunggah..."
                                : "Pilih Gambar"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _isLoading ? null : _simpanLapangan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 76, 175, 80),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_editingId == null ? "Simpan" : "Update",
                              style: const TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _resetForm,
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text("Batal",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // === Tabel === \\
          const Text(
            "Daftar Lapangan",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: supabase.from("lapangan").select().order("created_at"),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text("Belum ada data lapangan.");
              }

              final lapanganList = snapshot.data!;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  border: TableBorder.all(color: Colors.grey.shade300),
                  columns: const [
                    DataColumn(label: Text("No")),
                    DataColumn(label: Text("Gambar")),
                    DataColumn(label: Text("Nama")),
                    DataColumn(label: Text("Nomor")),
                    DataColumn(label: Text("Harga / Jam")),
                    DataColumn(label: Text("Status")),
                    DataColumn(label: Text("Aksi")),
                  ],
                  rows: List.generate(lapanganList.length, (index) {
                    final lapangan = lapanganList[index];
                    return DataRow(
                      cells: [
                        DataCell(Text("${index + 1}")),
                        DataCell(
                          lapangan["gambar_url"] != null &&
                                  lapangan["gambar_url"].toString().isNotEmpty
                              ? Image.network(lapangan["gambar_url"],
                                  width: 50, height: 50, fit: BoxFit.cover)
                              : const Icon(Icons.image_not_supported, size: 40),
                        ),
                        DataCell(Text(lapangan["nama"] ?? "")),
                        DataCell(Text(lapangan["nomor"] ?? "")),
                        DataCell(
                          Text(
                            rupiahFormat.format(
                              int.tryParse(
                                      lapangan["harga_perjam"].toString()) ?? 0,
                            ),
                          ),
                        ),
                        DataCell(Text(lapangan["status"] ?? "Tersedia")),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () =>
                                    _konfirmasiEdit(lapangan),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () =>
                                    _konfirmasiHapus(lapangan["id"].toString()),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              );
            },
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
