import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RekapPage extends StatelessWidget {
  const RekapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rekap Presensi Siswa')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('presensi')
            .orderBy('waktu', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Terjadi kesalahan'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.docs ?? [];

          if (data.isEmpty) {
            return const Center(child: Text('Belum ada data presensi'));
          }

          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              final doc = data[index];

              final nama = doc['nama'] ?? '';
              final divisi = doc['divisi'] ?? '';
              final status = doc['status'] ?? '';
              final Timestamp waktu = doc['waktu'] as Timestamp;
              final tanggal = DateFormat(
                'dd/MM/yyyy – kk:mm',
              ).format(waktu.toDate());

              return ListTile(
                title: Text(nama),
                subtitle: Text(
                  'Divisi: $divisi\nTanggal: $tanggal | Status: $status',
                ),
                leading: Icon(
                  status.toLowerCase() == 'hadir'
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: status.toLowerCase() == 'hadir'
                      ? Colors.green
                      : Colors.red,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
