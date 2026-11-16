import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  runApp(const TemuBarangApp());
}

const Color primaryGreen = Color(0xFF789681);
const Color darkGreen = Color(0xFF293B30);
const Color backgroundColor = Color(0xFFF7F5EF);

class TemuBarangApp extends StatelessWidget {
  const TemuBarangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TemuBarang',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: backgroundColor,
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: primaryGreen,
              brightness: Brightness.light,
            ).copyWith(
              primary: primaryGreen,
              secondary: const Color(0xFFD3A878),
              surface: Colors.white,
            ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundColor,
          surfaceTintColor: Colors.transparent,
          foregroundColor: darkGreen,
          elevation: 0,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class LostItem {
  final int? id;
  final String title;
  final String category;
  final String location;
  final String description;
  final String status;
  final DateTime createdAt;
  final List<String> photoPaths;
  final bool isMine;

  LostItem({
    this.id,
    required this.title,
    required this.category,
    required this.location,
    required this.description,
    required this.status,
    required this.createdAt,
    this.photoPaths = const [],
    this.isMine = false,
  });

  String get date {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) {
      return now.difference(createdAt).inMinutes < 1 ? 'Baru saja' : 'Hari ini';
    }
    if (diff == 1) return 'Kemarin';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  Map<String, Object?> toRow() => {
    'id': id,
    'title': title,
    'category': category,
    'location': location,
    'description': description,
    'status': status,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'isMine': isMine ? 1 : 0,
    'photos': jsonEncode(photoPaths),
  };

  factory LostItem.fromRow(Map<String, Object?> row) => LostItem(
    id: row['id'] as int?,
    title: row['title'] as String,
    category: row['category'] as String,
    location: row['location'] as String,
    description: row['description'] as String,
    status: row['status'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['createdAt'] as int),
    photoPaths: List<String>.from(jsonDecode(row['photos'] as String) as List),
    isMine: (row['isMine'] as int) == 1,
  );
}

Future<String> savePhotoFile(XFile image, int index) async {
  final dir = await getApplicationDocumentsDirectory();
  final photosDir = Directory(p.join(dir.path, 'photos'));
  if (!await photosDir.exists()) await photosDir.create(recursive: true);
  final saved = await File(image.path).copy(
    p.join(
      photosDir.path,
      '${DateTime.now().millisecondsSinceEpoch}_$index.jpg',
    ),
  );
  return saved.path;
}

Future<void> deletePhotoFiles(Iterable<String> paths) async {
  for (final path in paths) {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}

class ReportDb {
  static Database? _db;

  static Future<Database> _open() async {
    if (_db != null) return _db!;
    _db = await openDatabase(
      p.join(await getDatabasesPath(), 'temubarang.db'),
      version: 1,
      onCreate: (db, version) => db.execute(
        'CREATE TABLE reports('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'title TEXT, category TEXT, location TEXT, description TEXT, '
        'status TEXT, createdAt INTEGER, isMine INTEGER, photos TEXT)',
      ),
    );
    return _db!;
  }

  static Future<List<LostItem>> loadAll() async {
    final db = await _open();
    final rows = await db.query('reports', orderBy: 'createdAt DESC, id DESC');
    return rows.map(LostItem.fromRow).toList();
  }

  static Future<void> insert(LostItem item) async {
    final db = await _open();
    await db.insert('reports', item.toRow());
  }

  static Future<void> update(LostItem item) async {
    final db = await _open();
    await db.update(
      'reports',
      item.toRow(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  static Future<void> delete(int id) async {
    final db = await _open();
    await db.delete('reports', where: 'id = ?', whereArgs: [id]);
  }
}

List<LostItem> seedItems() => [
  LostItem(
    title: 'Dompet warna hitam',
    category: 'Dompet',
    location: 'Area Kampus',
    description:
        'Dompet warna hitam tertinggal di sekitar area kampus. '
        'Di dalamnya terdapat beberapa kartu.',
    status: 'Hilang',
    createdAt: DateTime.now(),
  ),
  LostItem(
    title: 'Headphone Bluetooth',
    category: 'Elektronik',
    location: 'Perpustakaan',
    description:
        'Headphone Bluetooth warna putih ditemukan di meja '
        'perpustakaan.',
    status: 'Ditemukan',
    createdAt: DateTime.now(),
  ),
  LostItem(
    title: 'Kartu mahasiswa',
    category: 'Dokumen',
    location: 'Gedung Fakultas',
    description:
        'Kartu mahasiswa ditemukan di dekat pintu masuk gedung fakultas.',
    status: 'Ditemukan',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  LostItem(
    title: 'Jam tangan',
    category: 'Aksesoris',
    location: 'Lapangan Kampus',
    description: 'Jam tangan tertinggal di sekitar lapangan kampus.',
    status: 'Hilang',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController searchController = TextEditingController();

  String selectedCategory = 'Semua';
  String selectedStatus = 'Semua';
  int selectedNavigation = 0;

  final List<String> categories = [
    'Semua',
    'Elektronik',
    'Dompet',
    'Dokumen',
    'Aksesoris',
    'Lainnya',
  ];

  final List<LostItem> items = [];

  @override
  void initState() {
    super.initState();
    initItems();
  }

  Future<void> initItems() async {
    if ((await ReportDb.loadAll()).isEmpty) {
      for (final item in seedItems()) {
        await ReportDb.insert(item);
      }
    }
    await refreshItems();
  }

  Future<void> refreshItems() async {
    final saved = await ReportDb.loadAll();
    if (!mounted) return;
    setState(() {
      items
        ..clear()
        ..addAll(saved);
    });
  }

  List<LostItem> get searchCategoryItems {
    final query = searchController.text.toLowerCase();

    return items.where((item) {
      final matchesSearch =
          item.title.toLowerCase().contains(query) ||
          item.location.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query);

      final matchesCategory =
          selectedCategory == 'Semua' || item.category == selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  List<LostItem> get filteredItems {
    final base = searchCategoryItems;
    if (selectedStatus == 'Semua') return base;

    return base.where((item) => item.status == selectedStatus).toList();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void openReportChoice() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Buat Laporan',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pilih jenis laporan yang ingin kamu buat.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 22),
              ReportChoiceCard(
                icon: Icons.search_off_rounded,
                title: 'Barang Hilang',
                description: 'Laporkan barang yang sedang kamu cari.',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  openReportForm('Hilang');
                },
              ),
              const SizedBox(height: 12),
              ReportChoiceCard(
                icon: Icons.inventory_2_outlined,
                title: 'Barang Ditemukan',
                description: 'Laporkan barang yang kamu temukan.',
                color: primaryGreen,
                onTap: () {
                  Navigator.pop(context);
                  openReportForm('Ditemukan');
                },
              ),
              const SizedBox(height: 15),
            ],
          ),
        );
      },
    );
  }

  void openReportForm(String status, {LostItem? existing}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportPage(
          status: status,
          existing: existing,
          onSubmit: (item) async {
            if (item.id == null) {
              await ReportDb.insert(item);
            } else {
              final old = items.firstWhere((e) => e.id == item.id);
              await deletePhotoFiles(
                old.photoPaths.where((path) => !item.photoPaths.contains(path)),
              );
              await ReportDb.update(item);
            }
            if (!mounted) return;
            setState(() {
              selectedCategory = 'Semua';
              selectedStatus = 'Semua';
              searchController.clear();
              selectedNavigation = 0;
            });
            await refreshItems();
          },
        ),
      ),
    );
  }

  void openDetail(LostItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                if (item.photoPaths.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: PageView.builder(
                        itemCount: item.photoPaths.length,
                        itemBuilder: (context, index) => Image.file(
                          File(item.photoPaths[index]),
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFE8EFE8),
                            child: const Icon(
                              Icons.broken_image_outlined,
                              size: 60,
                              color: primaryGreen,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EFE8),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      size: 75,
                      color: primaryGreen,
                    ),
                  ),
                if (item.photoPaths.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${item.photoPaths.length} foto — geser untuk melihat',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 20),
                StatusBadge(status: item.status),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                DetailInfo(icon: Icons.category_outlined, text: item.category),
                DetailInfo(
                  icon: Icons.location_on_outlined,
                  text: item.location,
                ),
                DetailInfo(
                  icon: Icons.calendar_today_outlined,
                  text: item.date,
                ),
                const SizedBox(height: 15),
                const Text(
                  'Deskripsi',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  item.description.isEmpty
                      ? 'Tidak ada deskripsi tambahan.'
                      : item.description,
                  style: const TextStyle(color: Colors.black54, height: 1.6),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Fitur kontak akan dikembangkan selanjutnya.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Hubungi Pelapor'),
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void confirmDelete(LostItem item) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus laporan?'),
          content: Text('"${item.title}" akan dihapus dari daftar.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    ).then((confirmed) async {
      if (confirmed != true || !mounted) return;

      await ReportDb.delete(item.id!);
      await deletePhotoFiles(item.photoPaths);
      await refreshItems();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan dihapus.')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: selectedNavigation == 0
            ? buildHome()
            : selectedNavigation == 1
            ? buildActivity()
            : buildProfile(),
      ),
      floatingActionButton: selectedNavigation == 0
          ? FloatingActionButton.extended(
              onPressed: openReportChoice,
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text(
                'Buat Laporan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedNavigation,
        onDestinationSelected: (index) {
          setState(() {
            selectedNavigation = index;
          });
        },
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDCE7DC),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Aktivitas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget buildHome() {
    final base = searchCategoryItems;
    final lostCount = base.where((item) => item.status == 'Hilang').length;
    final foundCount = base.where((item) => item.status == 'Ditemukan').length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryGreen,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.travel_explore,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'TemuBarang',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: darkGreen,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Belum ada notifikasi.'),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        size: 27,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                const Text(
                  'Halo, selamat datang! 👋',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: darkGreen,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Temukan kembali barang yang hilang bersama kami.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Cari nama barang atau lokasi...',
                    prefixIcon: const Icon(Icons.search, color: primaryGreen),
                    filled: true,
                    fillColor: const Color(0xFFFCFBF7),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Jenis Laporan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkGreen,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'Semua',
                      label: Text('Semua (${base.length})'),
                    ),
                    ButtonSegment(
                      value: 'Hilang',
                      label: Text('Hilang ($lostCount)'),
                    ),
                    ButtonSegment(
                      value: 'Ditemukan',
                      label: Text('Ditemukan ($foundCount)'),
                    ),
                  ],
                  selected: {selectedStatus},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    setState(() {
                      selectedStatus = selection.first;
                    });
                  },
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: primaryGreen,
                    selectedForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kategori Barang',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: darkGreen,
                      ),
                    ),
                    Text(
                      '${categories.length - 1} kategori',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 9),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final selected = selectedCategory == category;

                      return ChoiceChip(
                        label: Text(category),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            selectedCategory = category;
                          });
                        },
                        selectedColor: primaryGreen,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide.none,
                        showCheckmark: false,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 22),
                buildBanner(),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Laporan Terbaru',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: darkGreen,
                      ),
                    ),
                    Text(
                      '${filteredItems.length} laporan',
                      style: const TextStyle(
                        color: primaryGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
        if (filteredItems.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(35),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 55, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'Barang tidak ditemukan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Coba kata kunci atau kategori lain.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = filteredItems[index];

                return ItemCard(item: item, onTap: () => openDetail(item));
              }, childCount: filteredItems.length),
            ),
          ),
      ],
    );
  }

  Widget buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF829D88), Color(0xFF526F5A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Barang Hilang?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Buat laporan dan bantu orang lain '
                  'menemukan barangnya.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: openReportChoice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primaryGreen,
                    elevation: 0,
                  ),
                  child: const Text(
                    'Buat Laporan',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.find_in_page_rounded, color: Colors.white, size: 75),
        ],
      ),
    );
  }

  Widget buildActivity() {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aktivitas Saya',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: darkGreen,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Daftar laporan yang kamu buat.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 22),
          Expanded(
            child: Builder(
              builder: (context) {
                final myItems = items.where((item) => item.isMine).toList();

                if (myItems.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 65,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Belum ada aktivitas',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Laporan yang kamu buat akan muncul di sini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: myItems.length,
                  itemBuilder: (context, index) {
                    return ItemCard(
                      item: myItems[index],
                      onTap: () => openDetail(myItems[index]),
                      onEdit: () => openReportForm(
                        myItems[index].status,
                        existing: myItems[index],
                      ),
                      onDelete: () => confirmDelete(myItems[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildProfile() {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profil',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: darkGreen,
            ),
          ),
          const SizedBox(height: 30),
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: const Color(0xFFDCE7DC),
                  child: const Icon(
                    Icons.person,
                    size: 55,
                    color: primaryGreen,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Pengguna TemuBarang',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Pengguna aplikasi',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 35),
          const ProfileMenu(
            icon: Icons.person_outline,
            title: 'Informasi Akun',
          ),
          const ProfileMenu(icon: Icons.help_outline, title: 'Bantuan'),
          const ProfileMenu(
            icon: Icons.info_outline,
            title: 'Tentang TemuBarang',
          ),
        ],
      ),
    );
  }
}

class ReportPage extends StatefulWidget {
  final String status;
  final Function(LostItem) onSubmit;
  final LostItem? existing;

  const ReportPage({
    super.key,
    required this.status,
    required this.onSubmit,
    this.existing,
  });

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final locationController = TextEditingController();
  final descriptionController = TextEditingController();

  final ImagePicker imagePicker = ImagePicker();

  String selectedCategory = 'Elektronik';
  List<String> photoPaths = [];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      titleController.text = existing.title;
      locationController.text = existing.location;
      descriptionController.text = existing.description;
      selectedCategory = existing.category;
      photoPaths = List.of(existing.photoPaths);
    }
  }

  final List<String> categoryOptions = [
    'Elektronik',
    'Dompet',
    'Dokumen',
    'Aksesoris',
    'Lainnya',
  ];

  Future<void> pickPhotos() async {
    try {
      final images = await imagePicker.pickMultiImage(
        imageQuality: 75,
        maxWidth: 1200,
      );
      if (images.isEmpty) return;

      final saved = <String>[];
      for (var i = 0; i < images.length; i++) {
        saved.add(await savePhotoFile(images[i], i));
      }
      if (!mounted) return;
      setState(() {
        photoPaths.addAll(saved);
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengambil foto. Coba lagi.')),
      );
    }
  }

  void submitReport() {
    if (!formKey.currentState!.validate()) return;

    final newItem = LostItem(
      id: widget.existing?.id,
      title: titleController.text.trim(),
      category: selectedCategory,
      location: locationController.text.trim(),
      description: descriptionController.text.trim(),
      status: widget.status,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      photoPaths: photoPaths,
      isMine: true,
    );

    widget.onSubmit(newItem);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.existing == null
              ? 'Laporan berhasil ditambahkan!'
              : 'Laporan diperbarui.',
        ),
        backgroundColor: primaryGreen,
      ),
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    titleController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Buat Laporan' : 'Edit Laporan',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: backgroundColor,
        surfaceTintColor: backgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: widget.status == 'Hilang'
                      ? const Color(0xFFFFF7ED)
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.status == 'Hilang'
                          ? Icons.search_off
                          : Icons.inventory_2_outlined,
                      color: widget.status == 'Hilang'
                          ? Colors.orange
                          : primaryGreen,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Laporan Barang ${widget.status}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              const Text(
                'Foto Barang',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 110,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var i = 0; i < photoPaths.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.file(
                                File(photoPaths[i]),
                                width: 100,
                                height: 110,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 100,
                                  height: 110,
                                  color: const Color(0xFFE8EFE8),
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                    color: primaryGreen,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  final path = photoPaths[i];
                                  setState(() {
                                    photoPaths.removeAt(i);
                                  });
                                  if (!(widget.existing?.photoPaths
                                          .contains(path) ??
                                      false)) {
                                    deletePhotoFiles([path]);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    GestureDetector(
                      onTap: pickPhotos,
                      child: Container(
                        width: 100,
                        height: 110,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EFE8),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: const Color(0xFFC8D8C9),
                            width: 1.5,
                          ),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 30,
                              color: primaryGreen,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Tambah Foto',
                              style: TextStyle(
                                color: primaryGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Bisa lebih dari satu foto.',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const SizedBox(height: 20),
              const Text(
                'Nama Barang',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 9),
              TextFormField(
                controller: titleController,
                decoration: inputDecoration(
                  'Contoh: Dompet warna hitam',
                  Icons.inventory_2_outlined,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama barang wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Kategori',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 9),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: inputDecoration(
                  'Pilih kategori',
                  Icons.category_outlined,
                ),
                items: categoryOptions.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedCategory = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Lokasi',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 9),
              TextFormField(
                controller: locationController,
                decoration: inputDecoration(
                  'Contoh: Perpustakaan Kampus',
                  Icons.location_on_outlined,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Lokasi wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Deskripsi',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 9),
              TextFormField(
                controller: descriptionController,
                maxLines: 4,
                decoration: inputDecoration(
                  'Jelaskan ciri-ciri barang atau informasi lainnya...',
                  Icons.description_outlined,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: submitReport,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text(
                    'Kirim Laporan',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration inputDecoration(String hint, IconData icon) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: primaryGreen),
    filled: true,
    fillColor: const Color(0xFFFCFBF7),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: primaryGreen),
    ),
  );
}

class ItemCard extends StatelessWidget {
  final LostItem item;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ItemCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: item.photoPaths.isNotEmpty
                  ? Image.file(
                      File(item.photoPaths.first),
                      width: 95,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 95,
                        height: 100,
                        color: const Color(0xFFE8EFE8),
                        child: const Icon(
                          Icons.broken_image_outlined,
                          size: 37,
                          color: primaryGreen,
                        ),
                      ),
                    )
                  : Container(
                      width: 95,
                      height: 100,
                      color: const Color(0xFFE8EFE8),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        size: 37,
                        color: primaryGreen,
                      ),
                    ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusBadge(status: item.status),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    item.category,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          item.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.date,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (onEdit != null)
              IconButton(
                onPressed: onEdit,
                tooltip: 'Edit laporan',
                icon: const Icon(Icons.edit_outlined, color: primaryGreen),
              ),
            if (onDelete != null)
              IconButton(
                onPressed: onDelete,
                tooltip: 'Hapus laporan',
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              )
            else if (onEdit == null)
              const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isLost = status == 'Hilang';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isLost ? const Color(0xFFFFF1E6) : const Color(0xFFE4EEE4),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isLost ? const Color(0xFFEA580C) : const Color(0xFF526F5A),
        ),
      ),
    );
  }
}

class ReportChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const ReportChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFAF6),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 27),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class DetailInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const DetailInfo({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 19, color: primaryGreen),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class ProfileMenu extends StatelessWidget {
  final IconData icon;
  final String title;

  const ProfileMenu({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: primaryGreen),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title akan dikembangkan selanjutnya.')),
        );
      },
    );
  }
}
