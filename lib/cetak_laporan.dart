import 'package:flutter/material.dart';

class CetakLaporanPage extends StatefulWidget {
  const CetakLaporanPage({super.key});

  @override
  State<CetakLaporanPage> createState() => _CetakLaporanPageState();
}

class _CetakLaporanPageState extends State<CetakLaporanPage> {
  // contoh dummy data pesanan
  final List<Map<String, dynamic>> dataPesanan = [
    {
      "nama": "Budi",
      "lapangan": "Lapangan A",
      "tanggal": "2025-09-20",
      "jam": "08:00",
      "durasi": "2 Jam",
      "harga": "Rp 100.000"
    },
    {
      "nama": "Sinta",
      "lapangan": "Lapangan B",
      "tanggal": "2025-09-21",
      "jam": "09:00",
      "durasi": "1 Jam",
      "harga": "Rp 50.000"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Cetak Laporan",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        // tabel laporan
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              border: TableBorder.all(color: Colors.grey),
              columns: const [
                DataColumn(label: Text("Nama Penyewa")),
                DataColumn(label: Text("Lapangan")),
                DataColumn(label: Text("Tanggal")),
                DataColumn(label: Text("Jam Mulai")),
                DataColumn(label: Text("Durasi")),
                DataColumn(label: Text("Harga")),
              ],
              rows: dataPesanan
                  .map(
                    (pesanan) => DataRow(cells: [
                      DataCell(Text(pesanan["nama"])),
                      DataCell(Text(pesanan["lapangan"])),
                      DataCell(Text(pesanan["tanggal"])),
                      DataCell(Text(pesanan["jam"])),
                      DataCell(Text(pesanan["durasi"])),
                      DataCell(Text(pesanan["harga"])),
                    ]),
                  )
                  .toList(),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Tombol cetak laporan
        Row(
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                // nanti disambungin ke fungsi export PDF
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Laporan berhasil dicetak!")),
                );
              },
              child: const Text("Cetak Laporan"),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context); // balik ke halaman sebelumnya
              },
              child: const Text("Batal"),
            ),
          ],
        ),
      ],
    );
  }
}
