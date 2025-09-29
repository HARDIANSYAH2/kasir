import 'package:flutter/material.dart';
import 'package:kasir/cetak_laporan.dart';
import 'package:kasir/kelola_pesanan.dart';
import 'package:kasir/login_page.dart';
import 'package:kasir/kelola_lapangan.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum DashboardMenu {
  dashboard,
  kelolaLapangan,
  kelolaPesanan,
  cetakLaporan,
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DashboardMenu menuAktif = DashboardMenu.dashboard;
  Map<String, dynamic>? lapanganDipilih;

  final supabase = Supabase.instance.client;

  final NumberFormat rupiahFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ==== Sidebar ====
          Container(
            width: 220,
            color: const Color.fromARGB(255, 76, 175, 124),
            child: Column(
              children: [
                const SizedBox(height: 40),
                _sidebarItem(Icons.home, "Dashboard", DashboardMenu.dashboard),
                _sidebarItem(Icons.sports_tennis, "Kelola Lapangan",
                    DashboardMenu.kelolaLapangan),
                _sidebarItem(Icons.assignment, "Kelola Pesanan",
                    DashboardMenu.kelolaPesanan),
                _sidebarItem(
                    Icons.print, "Cetak Laporan", DashboardMenu.cetakLaporan),
                const Spacer(),
                _sidebarItem(Icons.logout, "Logout", null, isLogout: true),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // ==== Konten ====
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 60,
                  color: Colors.green.shade100,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _getJudulHalaman(menuAktif),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _getKontenHalaman(menuAktif),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String text, DashboardMenu? menu,
      {bool isLogout = false}) {
    bool isActive = menuAktif == menu;
    return InkWell(
      onTap: () {
        if (isLogout) {
          _showLogoutDialog();
        } else {
          setState(() {
            menuAktif = menu!;
          });
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive
              ? const Color.fromARGB(255, 156, 210, 171)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  String _getJudulHalaman(DashboardMenu menu) {
    switch (menu) {
      case DashboardMenu.dashboard:
        return "Halaman Dashboard";
      case DashboardMenu.kelolaLapangan:
        return "Kelola Lapangan";
      case DashboardMenu.kelolaPesanan:
        return "Kelola Pesanan";
      case DashboardMenu.cetakLaporan:
        return "Cetak Laporan";
    }
  }

  Widget _getKontenHalaman(DashboardMenu menu) {
    switch (menu) {
      case DashboardMenu.dashboard:
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _getLapangan(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("Belum ada data lapangan"));
            }

            final dataLapangan = snapshot.data!;

            return LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth < 800 ? 2 : 3;
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 4 / 4,
                  ),
                  itemCount: dataLapangan.length,
                  itemBuilder: (context, index) {
                    final lapangan = dataLapangan[index];
                    return _lapanganCard(lapangan);
                  },
                );
              },
            );
          },
        );

      case DashboardMenu.kelolaLapangan:
        return const KelolaLapanganContent();

      case DashboardMenu.kelolaPesanan:
        return KelolaPesananContent(
          lapanganDipilih: lapanganDipilih,
          onBookingSelesai: _refreshLapangan,
        );

      case DashboardMenu.cetakLaporan:
        return const CetakLaporanPage();
    }
  }

  Widget _lapanganCard(Map<String, dynamic> item) {
    final bool available = item["status"] == "Tersedia";
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.network(
                item["gambar_url"] ?? "",
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Icon(Icons.broken_image)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item["nama"] ?? "",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                Text("Nomor: ${item["nomor"] ?? '-'}",
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black87)),
                Text(
                  "${rupiahFormat.format(item["harga_perjam"] ?? 0)} / jam",
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.circle,
                        color: available ? Colors.green : Colors.red, size: 10),
                    const SizedBox(width: 5),
                    Text(item["status"] ?? "",
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 30,
                  child: ElevatedButton(
                    onPressed: available
                        ? () {
                            setState(() {
                              lapanganDipilih = item;
                              menuAktif = DashboardMenu.kelolaPesanan;
                            });
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          available ? Colors.green : Colors.grey[300],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child:
                        const Text("Booking", style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _refreshLapangan() {
    setState(() {
      menuAktif = DashboardMenu.dashboard;
    });
  }

  Future<List<Map<String, dynamic>>> _getLapangan() async {
    final response = await supabase.from("lapangan").select();
    return List<Map<String, dynamic>>.from(response);
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 10),
              Text("Konfirmasi Logout"),
            ],
          ),
          content: const Text("Apakah anda yakin ingin logout?"),
          actions: [
            TextButton(
              child: const Text("Batal"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Logout",
                  style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
