import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 200,
            color: Colors.green.shade400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DrawerHeader(
                  child: Text("Dashboard",
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
                ListTile(
                  leading: Icon(Icons.sports_tennis, color: Colors.white),
                  title: Text("Kelola Lapangan",
                      style: TextStyle(color: Colors.white)),
                  onTap: () {},
                ),
                ListTile(
                  leading: Icon(Icons.receipt, color: Colors.white),
                  title: Text("Kelola Pesanan",
                      style: TextStyle(color: Colors.white)),
                  onTap: () {},
                ),
                ListTile(
                  leading: Icon(Icons.print, color: Colors.white),
                  title: Text("Cetak Laporan",
                      style: TextStyle(color: Colors.white)),
                  onTap: () {},
                ),
                Spacer(),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.white),
                  title: Text("Logout", style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Card(
                      child: Column(
                        children: [
                          Image.asset("assets/lapangan1.jpg", width: 200),
                          Text("Tersedia",
                              style: TextStyle(color: Colors.green)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Card(
                      child: Column(
                        children: [
                          Image.asset("assets/lapangan2.jpg", width: 200),
                          Text("Terbooking",
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
