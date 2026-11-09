import 'package:flutter_test/flutter_test.dart';
import 'package:temubarang/main.dart';

void main() {
  testWidgets('TemuBarang menampilkan halaman beranda', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TemuBarangApp());

    expect(find.text('TemuBarang'), findsOneWidget);
    expect(find.text('Laporan terbaru'), findsOneWidget);
    expect(find.text('Kategori barang'), findsOneWidget);
  });
}
