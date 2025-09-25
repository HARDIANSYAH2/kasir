import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart';

class KelolaLapanganContent extends StatefulWidget {
  const KelolaLapanganContent({super.key});

  @override
  State<KelolaLapanganContent> createState() => _KelolaLapanganContentState();
}

class _KelolaLapanganContentState extends State<KelolaLapanganContent> {
  final TextEditingController nomorController = TextEditingController();
  final TextEditingController hargaController = TextEditingController();

  String? _imageUrl;
  bool _isLoading = false; 
  bool _isUploadingImage = false; 
  double _uploadProgress = 0; 
  String? _editingDocId; // simpan id dokumen yg sedang diedit

  final NumberFormat rupiahFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _isUploadingImage = true;
        _uploadProgress = 0;
      });

      try {
        final compressedBytes = await FlutterImageCompress.compressWithFile(
          pickedFile.path,
          quality: 70,
        );

        if (compressedBytes == null) throw Exception("Gagal kompres gambar");

        final fileName = DateTime.now().millisecondsSinceEpoch.toString();
        final ref =
            FirebaseStorage.instance.ref().child('lapangan/$fileName.jpg');

        final uploadTask = ref.putData(Uint8List.fromList(compressedBytes));

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          setState(() {
            _uploadProgress = progress;
          });
        });

        final snapshot = await uploadTask;
        final downloadURL = await snapshot.ref.getDownloadURL();

        setState(() {
          _imageUrl = downloadURL;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal upload gambar: $e")),
        );
      } finally {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _simpanLapangan() async {
    final nomor = nomorController.text.trim();
    final harga = hargaController.text.trim();

    if (nomor.isEmpty || harga.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nomor & Harga wajib diisi!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_editingDocId == null) {
        // tambah data baru
        await FirebaseFirestore.instance.collection("lapangan").add({
          "nama": "Lapangan Badminton",
          "nomor": nomor,
          "harga": int.tryParse(harga) ?? 0,
          "imageUrl": _imageUrl ?? "",
          "status": "Tersedia",
          "createdAt": FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lapangan berhasil disimpan.")),
        );
      } else {
        // update data lama
        await FirebaseFirestore.instance
            .collection("lapangan")
            .doc(_editingDocId)
            .update({
          "nomor": nomor,
          "harga": int.tryParse(harga) ?? 0,
          "imageUrl": _imageUrl ?? "",
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lapangan berhasil diperbarui.")),
        );
      }

      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal simpan lapangan: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _hapusLapangan(String docId) async {
    try {
      await FirebaseFirestore.instance.collection("lapangan").doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lapangan berhasil dihapus.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal hapus lapangan: $e")),
      );
    }
  }

  void _editLapangan(String docId, Map<String, dynamic> data) {
    setState(() {
      _editingDocId = docId;
      nomorController.text = data["nomor"] ?? "";
      hargaController.text = data["harga"]?.toString() ?? "";
      _imageUrl = data["imageUrl"];
    });
  }

  void _resetForm() {
    nomorController.clear();
    hargaController.clear();
    setState(() {
      _imageUrl = null;
      _editingDocId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  _editingDocId == null
                      ? "Tambah Data Lapangan"
                      : "Edit Data Lapangan",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                          _imageUrl != null
                              ? Image.network(_imageUrl!,
                                  height: 120, fit: BoxFit.cover)
                              : const Text("Belum ada gambar"),
                          if (_isUploadingImage)
                            Column(
                              children: [
                                const SizedBox(height: 10),
                                LinearProgressIndicator(value: _uploadProgress),
                              ],
                            ),
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
                          : Text(_editingDocId == null ? "Simpan" : "Update",
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
          const Text(
            "Daftar Lapangan",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("lapangan")
                .orderBy("createdAt", descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text("Belum ada data lapangan.");
              }

              final lapanganDocs = snapshot.data!.docs;

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
                  rows: List.generate(lapanganDocs.length, (index) {
                    final lapangan =
                        lapanganDocs[index].data() as Map<String, dynamic>;
                    final docId = lapanganDocs[index].id;
                    return DataRow(
                      cells: [
                        DataCell(Text("${index + 1}")),
                        DataCell(
                          lapangan["imageUrl"] != null &&
                                  lapangan["imageUrl"].toString().isNotEmpty
                              ? Image.network(lapangan["imageUrl"],
                                  width: 60, height: 60, fit: BoxFit.cover)
                              : const Icon(Icons.image_not_supported, size: 40),
                        ),
                        DataCell(Text(lapangan["nama"] ?? "")),
                        DataCell(Text(lapangan["nomor"] ?? "")),
                        DataCell(Text(
                            rupiahFormat.format(lapangan["harga"] ?? 0))),
                        DataCell(Text(lapangan["status"] ?? "Tersedia")),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editLapangan(docId, lapangan),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _hapusLapangan(docId),
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
