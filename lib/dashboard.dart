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
          // ==== Sidebar ==== \\
          Container(
            width: 220,
            color: const Color(0xFF4CAF7C),
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

          // ==== Konten Utama ==== \\
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

  /// ==== Sidebar Item ==== \\
  Widget _sidebarItem(IconData icon, String text, DashboardMenu? menu,
      {bool isLogout = false}) {
    final bool isActive = menuAktif == menu;

    return InkWell(
      onTap: () {
        if (isLogout) {
          _showLogoutDialog();
        } else if (menu != null) {
          setState(() {
            menuAktif = menu;
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
              child: Text(
                text,
                style: const TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ==== Judul Halaman ==== \\
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

  /// ==== Konten Halaman ==== \\
  Widget _getKontenHalaman(DashboardMenu menu) {
    switch (menu) {
      case DashboardMenu.dashboard:
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _getLapangan(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text(
                "Terjadi kesalahan: ${snapshot.error}",
                textAlign: TextAlign.center,
              ));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("Belum ada data lapangan"));
            }

            final dataLapangan = snapshot.data!;

            return LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth < 800 ? 2 : 3;
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

  /// ==== Kartu Lapangan ==== \\
  Widget _lapanganCard(Map<String, dynamic> item) {
    final bool available =
        (item["status"]?.toString().toLowerCase() ?? "") == "tersedia";

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
                Text(
                  item["nama"] ?? "",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  "Nomor: ${item["nomor"] ?? '-'}",
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                ),
                Text(
                  "${rupiahFormat.format(item["harga_perjam"] ?? 0)} / jam",
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      color: available ? Colors.green : Colors.red,
                      size: 10,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item["status"] ?? "",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ==== Refresh setelah booking selesai ==== \\
  void _refreshLapangan() {
    setState(() {
      menuAktif = DashboardMenu.dashboard;
    });
  }

  /// ==== Ambil Data Lapangan dari Supabase ==== \\
  Future<List<Map<String, dynamic>>> _getLapangan() async {
    final response = await supabase
        .from("lapangan")
        .select()
        .order("nomor", ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  /// ==== Dialog Logout ==== \\
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
          content: const Text("Apakah Anda yakin ingin logout?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                }
              },
              child: const Text(
                "Logout",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
