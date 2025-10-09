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

  @override
  void dispose() {
    nomorController.dispose();
    hargaController.dispose();
    super.dispose();
  }

  // === Upload Gambar ===
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final fileBytes = result.files.first.bytes;
    if (fileBytes == null) return;

    final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
    final filePath = "lapangan/$fileName";

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

      final publicUrl = supabase.storage.from("lapangan").getPublicUrl(filePath);

      setState(() {
        _imageUrl = publicUrl;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal upload gambar: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  // === Simpan atau Update ===
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
          const SnackBar(content: Text("Lapangan berhasil diubah.")),
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

  // === Hapus ===
  Future<void> _konfirmasiHapus(String id) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (konfirmasi == true) {
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
  }

  // === Edit ===
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
    return Container(
      color: const Color(0xFFF4F9F4),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.sports_tennis, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text(
                  "Kelola Lapangan",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(thickness: 1, color: Color(0xFFE0E0E0)),
            const SizedBox(height: 28),
            _formWidget(),
            const SizedBox(height: 50),
            const Text(
              "Daftar Lapangan",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _dataTableWidget(),
          ],
        ),
      ),
    );
  }

  // === FORM ===
  Widget _formWidget() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _editingId == null ? "Tambah Data Lapangan" : "Ubah Data Lapangan",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Nama Lapangan: Lapangan Badminton",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            _textFieldInside("Nomor Lapangan", nomorController),
            const SizedBox(height: 20),
            _textFieldInside("Harga Perjam", hargaController,
                inputType: TextInputType.number),
            const SizedBox(height: 24),
            _uploadImageWidget(),
            const SizedBox(height: 32),
            _actionButtons(),
          ],
        ),
      ),
    );
  }

  // === Widget Upload Gambar ===
  Widget _uploadImageWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          padding: const EdgeInsets.all(8),
          child: Center(
            child: _pickedBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(_pickedBytes!,
                        height: 130, fit: BoxFit.cover),
                  )
                : (_imageUrl != null && _imageUrl!.isNotEmpty)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          _imageUrl!,
                          height: 130,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Padding(
                        padding: EdgeInsets.all(10),
                        child: Text("Belum ada gambar"),
                      ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _isUploadingImage ? null : _pickImage,
          icon: _isUploadingImage
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.image_outlined),
          label: Text(_isUploadingImage ? "Mengunggah..." : "Pilih Gambar"),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _simpanLapangan,
          icon: const Icon(Icons.save, color: Colors.white),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          label: Text(
            _editingId == null ? "Simpan" : "Ubah",
            style: const TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: _resetForm,
          icon: const Icon(Icons.cancel, color: Colors.white),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          label: const Text("Batal", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _dataTableWidget() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase.from("lapangan").select().order("created_at"),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text("Terjadi kesalahan: ${snapshot.error}");
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text("Belum ada data lapangan.");
        }

        final lapanganList = snapshot.data!;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                    MaterialStateProperty.all(Colors.green.shade50),
                border: TableBorder.all(color: Colors.grey.shade200),
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
                  final harga = int.tryParse(
                          lapangan["harga_perjam"]?.toString() ?? "0") ??
                      0;
                  final gambarUrl = lapangan["gambar_url"]?.toString() ?? "";

                  return DataRow(
                    cells: [
                      DataCell(Text("${index + 1}")),
                      DataCell(
                        (gambarUrl.isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  gambarUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.image_not_supported),
                      ),
                      DataCell(Text(lapangan["nama"] ?? "")),
                      DataCell(Text(lapangan["nomor"] ?? "")),
                      DataCell(Text(rupiahFormat.format(harga))),
                      DataCell(Text(lapangan["status"] ?? "Tersedia")),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Colors.blueAccent),
                              tooltip: "Edit",
                              onPressed: () => _editLapangan(lapangan),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.redAccent),
                              tooltip: "Hapus",
                              onPressed: () => _konfirmasiHapus(
                                  lapangan["id"].toString()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _textFieldInside(String label, TextEditingController controller,
      {TextInputType inputType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.green.shade600, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
