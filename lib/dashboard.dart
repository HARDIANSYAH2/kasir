import 'package:flutter/material.dart';
import 'package:kasir/kelola_pesanan.dart';
import 'package:kasir/login_page.dart';
import 'package:kasir/kelola_lapangan.dart';


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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            color: const Color.fromARGB(255, 76, 175, 172),
            child: Column(
              children: [
                const SizedBox(height: 50),
                _sidebarItem(Icons.home, "Dashboard", DashboardMenu.dashboard),
                _sidebarItem(Icons.sports_tennis, "Kelola Lapangan", DashboardMenu.kelolaLapangan),
                _sidebarItem(Icons.assignment, "Kelola Pesanan", DashboardMenu.kelolaPesanan),
                _sidebarItem(Icons.print, "Cetak Laporan", DashboardMenu.cetakLaporan),
                const Spacer(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.white),
                  title: const Text("Logout", style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                    );
                  },
                ),
              ],
            ),
          ),

          // Isi konten berdasarkan menu aktif
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
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _sidebarItem(IconData icon, String text, DashboardMenu menu) {
    bool isActive = menuAktif == menu;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      color: isActive ? const Color.fromARGB(255, 62, 143, 46) : Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: const Color.fromARGB(255, 255, 255, 255)),
        title: Text(text, style: const TextStyle(color: Color.fromARGB(255, 254, 255, 255))),
        onTap: () {
          setState(() {
            menuAktif = menu;
          });
        },
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
        return GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          children: [
            _lapanganCard("Tersedia", Colors.green, true),
            _lapanganCard("Terbooking", Colors.red, false),
          ],
        );
      case DashboardMenu.kelolaLapangan:
      return const KelolaLapanganContent();
      case DashboardMenu.kelolaPesanan:
     return const KelolaPesananContent();
      case DashboardMenu.cetakLaporan:
      return const Center(child: Text("Ini halaman Cetak Laporan"));
    }
  }

  Widget _lapanganCard(String status, Color dotColor, bool available) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.green.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Expanded(
            child: Image.asset("assets/images/logoS.jpg", fit: BoxFit.cover),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, color: dotColor, size: 12),
              const SizedBox(width: 5),
              Text(status),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: available ? () {} : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: available ? Colors.green : Colors.grey,
            ),
            child: const Text("Booking"),
          )
        ],
      ),
    );
  }
}
