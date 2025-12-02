// lib/kelola_lapangan.dart
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

  bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 650;

  // PICK IMAGE
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

      final publicUrl =
          supabase.storage.from("lapangan").getPublicUrl(filePath);

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

  // SIMPAN LAPANGAN
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
        const SnackBar(content: Text("Gambar wajib diisi!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final existingLapangan = await supabase
          .from("lapangan")
          .select("id")
          .eq("nomor", nomor);

      if (existingLapangan.isNotEmpty) {
        final existingId = existingLapangan.first["id"].toString();
        if (_editingId == null || existingId != _editingId) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Nomor lapangan sudah digunakan!"),
              backgroundColor: Colors.redAccent,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

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

  // KONFIRMASI HAPUS
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

  // BUILD UI
  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(mobile ? 16 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _formWidget(mobile),
            const SizedBox(height: 40),
            const Text(
              "Daftar Lapangan",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            mobile ? _listViewMobile() : _dataTableWidget(),
          ],
        ),
      ),
    );
  }

  // FORM
  Widget _formWidget(bool mobile) {
    return Card(
      color: const Color(0xFFDFF4DF),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: EdgeInsets.all(mobile ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                _editingId == null ? "Tambah Data Lapangan" : "Ubah Data Lapangan",
                style: TextStyle(
                  fontSize: mobile ? 18 : 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(height: mobile ? 18 : 30),
            if (!mobile)
              const Text(
                "Nama Lapangan: Lapangan Badminton",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            if (!mobile) const SizedBox(height: 20),
            _textFieldInside("Nomor Lapangan", nomorController),
            SizedBox(height: mobile ? 12 : 20),
            _textFieldInside("Harga Perjam", hargaController,
                inputType: TextInputType.number),
            SizedBox(height: mobile ? 12 : 24),
            _uploadImageWidget(mobile),
            SizedBox(height: mobile ? 16 : 32),
            _actionButtons(mobile),
          ],
        ),
      ),
    );
  }

  // UPLOAD IMAGE WIDGET
  Widget _uploadImageWidget(bool mobile) {
    return Column(
      children: [
        Container(
          height: 130,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: _pickedBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(_pickedBytes!, fit: BoxFit.cover, width: double.infinity, height: 130),
                  )
                : (_imageUrl != null && _imageUrl!.isNotEmpty)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(_imageUrl!, fit: BoxFit.cover, width: double.infinity, height: 130),
                      )
                    : const Text("Belum ada gambar"),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isUploadingImage ? null : _pickImage,
          icon: _isUploadingImage
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.image),
          label: Text(_isUploadingImage ? "Mengunggah..." : "Pilih Gambar"),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.green.shade600),
            foregroundColor: Colors.green.shade800,
          ),
        ),
      ],
    );
  }

  // BUTTONS
  Widget _actionButtons(bool mobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _simpanLapangan,
          icon: const Icon(Icons.save, color: Colors.white),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            padding: EdgeInsets.symmetric(horizontal: mobile ? 16 : 24, vertical: mobile ? 10 : 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          label: Text(_editingId == null ? "Simpan" : "Ubah"),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _resetForm,
          icon: const Icon(Icons.cancel, color: Colors.white),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            padding: EdgeInsets.symmetric(horizontal: mobile ? 14 : 20, vertical: mobile ? 10 : 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          label: const Text("Batal"),
        ),
      ],
    );
  }

  // DESKTOP TABLE
  Widget _dataTableWidget() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase.from("lapangan").select().order("created_at", ascending: true),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.green.shade300),
              dataRowColor: MaterialStateProperty.all(Colors.green.shade50),
              columns: const [
                DataColumn(label: Text("No")),
                DataColumn(label: Text("Gambar")),
                DataColumn(label: Text("Nomor")),
                DataColumn(label: Text("Harga/Jam")),
                DataColumn(label: Text("Status")),
                DataColumn(label: Text("Aksi")),
              ],
              rows: List.generate(data.length, (i) {
                final item = data[i];
                final gambar = item["gambar_url"]?.toString() ?? "";
                final harga = item["harga_perjam"];
                return DataRow(
                  cells: [
                    DataCell(Text("${i + 1}")),
                    DataCell(
                      gambar.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                gambar,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                              ),
                            )
                          : const Icon(Icons.image_not_supported),
                    ),
                    DataCell(Text(item["nomor"]?.toString() ?? "-")),
                    DataCell(Text(rupiahFormat.format(harga ?? 0))),
                    DataCell(Text(item["status"]?.toString() ?? "Tersedia")),
                    DataCell(Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.green),
                          onPressed: () => _editLapangan(item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _konfirmasiHapus(item["id"].toString()),
                        ),
                      ],
                    )),
                  ],
                );
              }),
            ),
          ),
        );
      },
    );
  }

  // MOBILE LIST
  Widget _listViewMobile() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase.from("lapangan").select().order("created_at", ascending: true),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        if (data.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFDFF4DF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text("Belum ada data lapangan.")),
          );
        }

        return Column(
          children: List.generate(data.length, (i) {
            final item = data[i];
            final gambar = item["gambar_url"]?.toString() ?? "";
            final harga = item["harga_perjam"];
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.green.shade50,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (gambar.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          gambar,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 140,
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image, size: 48),
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.image_not_supported, size: 48),
                      ),
                    const SizedBox(height: 12),
                    Text("Lapangan Nomor: ${item["nomor"] ?? "-"}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text("Harga/Jam: ${rupiahFormat.format(harga ?? 0)}"),
                    Text("Status: ${item["status"] ?? "Tersedia"}"),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.green),
                          onPressed: () => _editLapangan(item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _konfirmasiHapus(item["id"].toString()),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // FIELD
  Widget _textFieldInside(String label, TextEditingController controller,
      {TextInputType inputType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.green.shade50,
        prefixIcon: Icon(
          label == "Nomor Lapangan"
              ? Icons.onetwothree_rounded
              : label == "Harga Perjam"
                  ? Icons.attach_money
                  : Icons.edit_note,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.green.shade600, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
