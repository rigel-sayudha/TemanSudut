import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/popup_notification.dart';
import '../utils/app_format.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/printer_service.dart';
import '../widgets/custom_date_range_picker.dart';

class HistoryTab extends StatefulWidget {
  final VoidCallback? onOrderActivated;
  const HistoryTab({super.key, this.onOrderActivated});

  @override
  HistoryTabState createState() => HistoryTabState();
}

class HistoryTabState extends State<HistoryTab>
    with AutomaticKeepAliveClientMixin {
  final ApiService _apiService = ApiService();
  final PrinterService _printerService = PrinterService();
  String _selectedFilter = 'daily';
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  DateTimeRange? _dateRange;
  final Set<int> _selectedMonths = {}; // months as YYYYMM int

  // ── Saved transactions ───────────────────────────────────────────────────
  bool _showSaved = false;
  List<dynamic> _savedTransactions = [];
  bool _isLoadingSaved = false;

  @override
  bool get wantKeepAlive => true;

  String get _filterTitle {
    if (_selectedFilter == 'daily') return 'Hari Ini';
    if (_selectedFilter == 'weekly') return 'Minggu Ini';
    if (_selectedFilter == 'monthly') return 'Bulan Ini';
    if (_selectedFilter.startsWith('date:')) {
      return 'Tanggal ${_selectedFilter.substring(5)}';
    }
    if (_selectedFilter.startsWith('date_range:')) {
      final parts = _selectedFilter.substring(11).split(',');
      return '${parts[0]} s/d ${parts[1]}';
    }
    if (_selectedFilter.startsWith('week:')) {
      final parts = _selectedFilter.substring(5).split(',');
      return 'Minggu ${parts[1]} / ${parts[0]}';
    }
    if (_selectedFilter.startsWith('month:')) {
      final parts = _selectedFilter.split(';');
      return '${parts.length} Bulan Dipilih';
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  void refreshHistory() {
    if (_showSaved) {
      _fetchSaved();
    } else {
      _fetchHistory();
    }
  }

  void showSavedTab() {
    setState(() {
      _showSaved = true;
    });
    _fetchSaved();
  }

  Future<void> _fetchHistory() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _transactions = [];
    });
    final data = await _apiService.getHistory(_selectedFilter);
    if (!mounted) return;
    setState(() {
      _transactions = data;
      _isLoading = false;
    });
  }

  Future<void> _fetchSaved() async {
    if (!mounted) return;
    setState(() => _isLoadingSaved = true);
    final data = await _apiService.getSavedTransactions();
    if (!mounted) return;
    setState(() {
      _savedTransactions = data;
      _isLoadingSaved = false;
    });
  }

  Future<void> _deleteSaved(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Pesanan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Apakah Anda yakin ingin menghapus pesanan tersimpan ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    final ok = await _apiService.deleteSavedTransaction(id);

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (ok) {
      setState(() => _savedTransactions.removeWhere((t) => t['id'] == id));
      PopupNotification.show(
        context,
        title: 'Pesanan Dihapus',
        message: 'Transaksi tersimpan berhasil dihapus.',
        type: PopupType.success,
      );
    } else {
      PopupNotification.show(
        context,
        title: 'Gagal Menghapus',
        message: 'Terjadi kesalahan saat menghapus pesanan.',
        type: PopupType.error,
      );
    }
  }

  Future<void> _downloadFile(String format) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final url = Uri.parse(
      '${ApiService.baseUrl}/transactions/export/$format?filter=$_selectedFilter&token=$token',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      PopupNotification.show(
        context,
        title: 'Gagal Export',
        message: 'Tidak bisa membuka link export.',
        type: PopupType.error,
      );
    }
  }

  void _showDownloadOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text('Export to PDF'),
                onTap: () {
                  Navigator.pop(context);
                  _downloadFile('pdf');
                },
              ),
              ListTile(
                leading: Icon(Icons.table_chart, color: Colors.green),
                title: Text('Export to Excel'),
                onTap: () {
                  Navigator.pop(context);
                  _downloadFile('excel');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Riwayat Transaksi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              _filterTitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () => refreshHistory(),
            tooltip: 'Refresh',
          ),
          if (auth.can('export_history'))
            IconButton(
              icon: const Icon(
                Icons.file_download_outlined,
                color: Colors.black,
              ),
              onPressed: () => _showDownloadOptions(context),
              tooltip: 'Export Laporan',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),

          Expanded(
            child: _showSaved
                ? _buildSavedList()
                : _isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.black))
                : _transactions.isEmpty
                ? _buildEmptyState()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = constraints.maxWidth ~/ 220;
                      if (crossAxisCount < 2) crossAxisCount = 2;
                      double padding = 24;
                      double crossSpacing =
                          10 * (crossAxisCount - 1).toDouble();
                      double itemWidth =
                          (constraints.maxWidth - padding - crossSpacing) /
                          crossAxisCount;
                      double aspectRatio = itemWidth / 170;
                      return GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: aspectRatio,
                        ),
                        itemCount: _transactions.length,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: false,
                        itemBuilder: (context, index) {
                          return RepaintBoundary(
                            child: _buildHistoryCard(_transactions[index]),
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

  Widget _buildSavedList() {
    if (_isLoadingSaved) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }
    if (_savedTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada transaksi tersimpan',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Gunakan tombol "Simpan" saat checkout untuk menyimpan pesanan ke sini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _savedTransactions.length,
      itemBuilder: (ctx, i) {
        final trx = _savedTransactions[i];
        final items = (trx['items'] as List?) ?? [];
        final total = trx['total'] ?? 0;
        final customer = trx['customer_name'] ?? 'Tamu';
        final createdAt = trx['created_at']?.toString() ?? '';
        final dateStr = createdAt.length >= 10
            ? createdAt.substring(0, 10)
            : createdAt;
        return GestureDetector(
          onTap: () => _showSavedDetailSheet(trx),
          child: Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE8DDD6), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.bookmark_rounded,
                        size: 16,
                        color: Color(0xFF5D4037),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          customer,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        AppFormat.currency((total as num).toDouble()),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${items.length} item  \u2022  $dateStr',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: items.take(4).map<Widget>((it) {
                      final name = it['product']?['name'] ?? '-';
                      final qty = it['quantity'] ?? 1;
                      return Chip(
                        label: Text(
                          '${qty}x $name',
                          style: const TextStyle(fontSize: 10),
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: Colors.grey[100],
                        side: BorderSide.none,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'Hapus',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => _deleteSaved(trx['id']),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: const Text(
                            'Proses',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5D4037),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => _showSavedDetailSheet(trx),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Bottom sheet detail for saved transaction ──────────────────────────────
  void _showSavedDetailSheet(Map<String, dynamic> trx) {
    final items = (trx['items'] as List?) ?? [];
    final total = ((trx['total'] ?? 0) as num).toDouble();
    final customer = trx['customer_name'] ?? 'Tamu';
    final orderType = trx['order_type'] ?? 'dine_in';
    final nameController = TextEditingController(text: customer);
    String selectedPayment = 'cash';
    double amountReceived = 0;
    double changeAmount = 0;
    bool isLoading = false;
    bool globalUseCup = true;

    // Check if any item is a drink
    bool hasDrinks = false;
    for (var it in items) {
      final cat =
          it['product']?['category']?['name']?.toString().toLowerCase() ?? '';
      if (cat.contains('kopi') ||
          cat.contains('coffee') ||
          cat.contains('non-kopi') ||
          cat.contains('non coffee') ||
          cat.contains('milk')) {
        hasDrinks = true;
        break;
      }
    }

    final outerCtx = context;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Title
                    Row(
                      children: [
                        const Icon(
                          Icons.bookmark_rounded,
                          size: 20,
                          color: Color(0xFF5D4037),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Konfirmasi Pesanan Tersimpan',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Customer name
                    const Text(
                      'Nama Pelanggan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      enabled: !isLoading,
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'Default: Tamu',
                        prefixIcon: const Icon(Icons.person_outline, size: 18),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Items list
                    const Text(
                      'Detail Pesanan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: items.asMap().entries.map<Widget>((entry) {
                          final it = entry.value;
                          final product = it['product'] ?? {};
                          final name = product['name'] ?? '-';
                          final qty = it['quantity'] ?? 1;
                          final unitPrice =
                              ((it['unit_price'] ?? product['price'] ?? 0)
                                      as num)
                                  .toDouble();
                          final itemTotal = unitPrice * qty;
                          final notes = it['notes']?.toString() ?? '';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              border: entry.key < items.length - 1
                                  ? Border(
                                      bottom: BorderSide(
                                        color: Colors.grey[200]!,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF5D4037,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${qty}x',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF5D4037),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (notes.isNotEmpty)
                                        Text(
                                          notes,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  AppFormat.currency(itemTotal),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Payment method
                    const Text(
                      'Metode Pembayaran',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: isLoading
                                ? null
                                : () => setSheetState(
                                    () => selectedPayment = 'cash',
                                  ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: selectedPayment == 'cash'
                                    ? const Color(0xFF5D4037)
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selectedPayment == 'cash'
                                      ? const Color(0xFF5D4037)
                                      : Colors.grey[300]!,
                                  width: selectedPayment == 'cash' ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.payments_outlined,
                                    size: 24,
                                    color: selectedPayment == 'cash'
                                        ? Colors.white
                                        : Colors.grey[600]!,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tunai',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: selectedPayment == 'cash'
                                          ? Colors.white
                                          : Colors.grey[700]!,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: isLoading
                                ? null
                                : () => setSheetState(
                                    () => selectedPayment = 'qris',
                                  ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: selectedPayment == 'qris'
                                    ? const Color(0xFF5D4037)
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selectedPayment == 'qris'
                                      ? const Color(0xFF5D4037)
                                      : Colors.grey[300]!,
                                  width: selectedPayment == 'qris' ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.qr_code_scanner_outlined,
                                    size: 24,
                                    color: selectedPayment == 'qris'
                                        ? Colors.white
                                        : Colors.grey[600]!,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'QRIS',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: selectedPayment == 'qris'
                                          ? Colors.white
                                          : Colors.grey[700]!,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Global Cup/Gelas Toggle (if cart has drinks)
                    if (hasDrinks) ...[
                      const Text(
                        'Penyajian Minuman',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  setSheetState(() => globalUseCup = true),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: globalUseCup
                                      ? Colors.brown[50]
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: globalUseCup
                                        ? Colors.brown[300]!
                                        : Colors.grey[200]!,
                                    width: globalUseCup ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.coffee,
                                      size: 20,
                                      color: globalUseCup
                                          ? Colors.brown[700]
                                          : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Gunakan Cup',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: globalUseCup
                                            ? Colors.brown[700]
                                            : Colors.grey[700]!,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  setSheetState(() => globalUseCup = false),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: !globalUseCup
                                      ? Colors.blue[50]
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: !globalUseCup
                                        ? Colors.blue[300]!
                                        : Colors.grey[200]!,
                                    width: !globalUseCup ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.local_drink,
                                      size: 20,
                                      color: !globalUseCup
                                          ? Colors.blue[700]
                                          : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Gunakan Gelas',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: !globalUseCup
                                            ? Colors.blue[700]
                                            : Colors.grey[700]!,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Total summary
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Pembayaran',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            AppFormat.currency(total),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Cash input
                    if (selectedPayment == 'cash') ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              enabled: !isLoading,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Input Uang',
                                prefixText: 'Rp ',
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onChanged: (val) {
                                setSheetState(() {
                                  final raw = val.replaceAll(
                                    RegExp(r'[^0-9]'),
                                    '',
                                  );
                                  amountReceived = double.tryParse(raw) ?? 0;
                                  changeAmount = amountReceived - total;
                                  if (changeAmount < 0) changeAmount = 0;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Kembalian',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  AppFormat.currency(changeAmount),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: changeAmount > 0
                                        ? Colors.green[700]
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            if (amountReceived > 0 && amountReceived < total)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      size: 14,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Uang kurang ${AppFormat.currency(total - amountReceived)}',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Konfirmasi button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5D4037),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed:
                            (isLoading ||
                                (selectedPayment == 'cash' &&
                                    amountReceived < total))
                            ? null
                            : () async {
                                setSheetState(() => isLoading = true);
                                final payload = {
                                  'payment_method': selectedPayment,
                                  'customer_name':
                                      nameController.text.isNotEmpty
                                      ? nameController.text
                                      : customer,
                                  'order_type': orderType,
                                  'use_cup': globalUseCup,
                                  if (selectedPayment == 'cash')
                                    'amount_received': amountReceived,
                                  if (selectedPayment == 'cash')
                                    'change_amount': changeAmount,
                                };
                                final result = await _apiService
                                    .activateSavedTransaction(
                                      trx['id'],
                                      payload,
                                    );
                                if (!ctx.mounted) return;
                                Navigator.pop(sheetCtx);
                                if (result['success'] == true) {
                                  _fetchSaved();
                                  widget.onOrderActivated?.call();
                                  PopupNotification.show(
                                    outerCtx,
                                    title: 'Pesanan Diproses! 🎉',
                                    message: 'Pesanan masuk ke Active Orders.',
                                    type: PopupType.success,
                                  );
                                } else {
                                  final errMsg = result['details'] is List
                                      ? (result['details'] as List).join('\n')
                                      : (result['error'] ??
                                            'Gagal mengaktifkan pesanan');
                                  PopupNotification.show(
                                    outerCtx,
                                    title: 'Gagal Memproses',
                                    message: errMsg.toString(),
                                    type: PopupType.error,
                                  );
                                }
                              },
                        child: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Konfirmasi Pesanan',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Filter bar (quick chips + filter button) ──────────────────────────────
  Widget _buildFilterBar() {
    final quickFilters = [
      {'val': 'daily', 'label': 'Hari Ini'},
      {'val': 'weekly', 'label': 'Minggu Ini'},
      {'val': 'monthly', 'label': 'Bulan Ini'},
    ];

    final hasCustomFilter =
        !['daily', 'weekly', 'monthly'].contains(_selectedFilter) &&
        !_showSaved;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // ── Tersimpan chip ──
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _showSaved = !_showSaved);
                        if (_showSaved) _fetchSaved();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _showSaved
                              ? const Color(0xFF5D4037)
                              : Colors.amber[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _showSaved
                                ? const Color(0xFF5D4037)
                                : const Color(0xFFBFA98A),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bookmark_rounded,
                              size: 12,
                              color: _showSaved
                                  ? Colors.white
                                  : const Color(0xFF5D4037),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Tersimpan',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _showSaved
                                    ? Colors.white
                                    : const Color(0xFF5D4037),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // divider
                  Container(
                    width: 1,
                    height: 20,
                    color: Colors.grey[300],
                    margin: const EdgeInsets.only(right: 8),
                  ),
                  // quick filters (hidden when _showSaved)
                  if (!_showSaved)
                    ...quickFilters.map((f) {
                      final sel = _selectedFilter == f['val'] && !_showSaved;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedFilter = f['val']!;
                              _showSaved = false;
                            });
                            _fetchHistory();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: sel ? Colors.black : Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              f['label']!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sel ? Colors.white : Colors.grey[700],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  // Show active custom filter as a chip
                  if (hasCustomFilter)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: _showFilterSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5D4037),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _filterTitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedFilter = 'daily';
                                    _dateRange = null;
                                    _selectedMonths.clear();
                                  });
                                  _fetchHistory();
                                },
                                child: const Icon(
                                  Icons.close,
                                  size: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Filter icon button (hidden when in saved mode)
          if (!_showSaved)
            IconButton(
              icon: Icon(
                Icons.date_range_rounded,
                size: 20,
                color: hasCustomFilter
                    ? const Color(0xFF5D4037)
                    : Colors.grey[600],
              ),
              onPressed: _showFilterSheet,
              tooltip: 'Filter Tanggal',
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
        ],
      ),
    );
  }

  // ── Filter bottom sheet (Direct Date Picker) ────────────────────────────────────────────────────
  Future<void> _showFilterSheet() async {
    final range = await CustomDateRangePicker.show(
      context,
      initialStartDate: _dateRange?.start,
      initialEndDate: _dateRange?.end,
    );
    if (range != null && mounted) {
      setState(() {
        _dateRange = range;
        _selectedFilter =
            'date_range:${_fmtIso(range.start)},${_fmtIso(range.end)}';
        _selectedMonths.clear();
      });
      _fetchHistory();
    }
  }

  String _fmtIso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
          SizedBox(height: 16),
          Text(
            'Tidak Ada Transaksi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Belum ada riwayat pesanan pada periode ini.',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(dynamic transaction) {
    final date = transaction['created_at'].toString().substring(0, 10);
    final invoice = 'INV-${transaction['id']}';
    final customer = transaction['customer_name'] ?? 'Guest';
    final itemsCount = (transaction['items'] as List).length;
    final total = double.tryParse(transaction['total'].toString()) ?? 0;
    final paymentMethod = (transaction['payment_method'] ?? 'cash')
        .toString()
        .toUpperCase();

    // Order type badge
    String? orderTypeLabel;
    Color? orderTypeColor;
    IconData? orderTypeIcon;
    if (transaction['order_type'] != null) {
      final type = transaction['order_type'].toString();
      if (type == 'dine_in') {
        orderTypeLabel = 'Dine In';
        orderTypeColor = Colors.blue;
        orderTypeIcon = Icons.restaurant;
      } else if (type == 'take_away') {
        orderTypeLabel = 'Take Away';
        orderTypeColor = Colors.orange;
        orderTypeIcon = Icons.takeout_dining;
      } else if (type == 'online') {
        orderTypeLabel = 'Online';
        orderTypeColor = Colors.green;
        orderTypeIcon = Icons.moped;
      }
    }

    return GestureDetector(
      onTap: () => _showDetailSheet(transaction),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF5D4037).withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      invoice,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF5D4037),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (orderTypeLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: orderTypeColor!.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        orderTypeIcon,
                        size: 11,
                        color: orderTypeColor,
                      ),
                    ),
                ],
              ),
            ),
            // Body
            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Total (prominent)
                  Text(
                    AppFormat.currency(total),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.green[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Item Pesanan Summary
                  if (transaction['items'] != null &&
                      (transaction['items'] as List).isNotEmpty) ...[
                    ...((transaction['items'] as List).take(3).map((item) {
                      final name = item['product'] != null
                          ? item['product']['name']
                          : 'Item';
                      final qty = item['quantity'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${qty}x ',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList()),
                    if ((transaction['items'] as List).length > 3)
                      Text(
                        '+ ${(transaction['items'] as List).length - 3} item lainnya',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    const SizedBox(height: 6),
                  ],

                  // Customer
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 10,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          customer,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Date
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 10,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 3),
                      Text(
                        date,
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Footer row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          paymentMethod,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                      Text(
                        '$itemsCount item',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(dynamic transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) {
          final date = transaction['created_at'].toString().substring(0, 10);
          final invoice = 'INV-${transaction['id']}';
          final customer = transaction['customer_name'] ?? 'Guest';
          final cashier = transaction['user'] != null
              ? transaction['user']['name']
              : 'Unknown';
          final total = double.tryParse(transaction['total'].toString()) ?? 0;
          final paymentMethod = (transaction['payment_method'] ?? 'cash')
              .toString()
              .toUpperCase();
          final String photoUrl = ApiService().getImageUrl(
            transaction['completion_photo'],
          );

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            date,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          if (auth.can('print_receipt')) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(ctx);
                                showModalBottomSheet(
                                  context: context,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20),
                                    ),
                                  ),
                                  builder: (context) {
                                    return SafeArea(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 24.0,
                                              bottom: 16,
                                              left: 24,
                                              right: 24,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.print,
                                                  color: Colors.black87,
                                                ),
                                                SizedBox(width: 12),
                                                Text(
                                                  'Cetak Struk',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          ListTile(
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 24,
                                                  vertical: 4,
                                                ),
                                            leading: Container(
                                              padding: EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.blue[50],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.bluetooth,
                                                color: Colors.blue[700],
                                              ),
                                            ),
                                            title: Text(
                                              'Printer Thermal',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            subtitle: Text(
                                              'Cetak via bluetooth',
                                            ),
                                            onTap: () async {
                                              final messenger =
                                                  ScaffoldMessenger.of(context);
                                              Navigator.pop(context);
                                              if (await _printerService
                                                  .isConnected) {
                                                if (!mounted) return;
                                                try {
                                                  await _printerService
                                                      .printReceipt(
                                                        transaction:
                                                            transaction,
                                                        items:
                                                            transaction['items'] ??
                                                            [],
                                                        isHistory: true,
                                                      );
                                                  messenger.showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Mencetak struk...',
                                                      ),
                                                    ),
                                                  );
                                                } catch (e) {
                                                  messenger.showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Gagal: $e',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              } else {
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Printer belum terhubung!',
                                                    ),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                          ListTile(
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 24,
                                                  vertical: 4,
                                                ),
                                            leading: Container(
                                              padding: EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.red[50],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.picture_as_pdf,
                                                color: Colors.red[700],
                                              ),
                                            ),
                                            title: Text(
                                              'Simpan PDF',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            subtitle: Text(
                                              'Download format PDF',
                                            ),
                                            onTap: () async {
                                              final messenger =
                                                  ScaffoldMessenger.of(context);
                                              Navigator.pop(context);
                                              try {
                                                await _printerService
                                                    .downloadReceiptPdf(
                                                      transaction['id'],
                                                    );
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Membuka PDF...',
                                                    ),
                                                  ),
                                                );
                                              } catch (e) {
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text('Gagal: $e'),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                          SizedBox(height: 16),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.print,
                                  size: 18,
                                  color: Colors.grey[700],
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey[200]),
                // Scrollable content
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Info Grid
                      Row(
                        children: [
                          Expanded(
                            child: _infoCell(
                              'Pelanggan',
                              customer,
                              Icons.person_outline,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _infoCell(
                              'Kasir',
                              cashier,
                              Icons.badge_outlined,
                              color: Colors.indigo[400]!,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _infoCell(
                              'Pembayaran',
                              paymentMethod,
                              Icons.payments_outlined,
                              color: Colors.green[600]!,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _infoCell(
                              'Total',
                              AppFormat.currency(total),
                              Icons.attach_money,
                              color: Colors.green[700]!,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(color: Colors.grey[200]),
                      const SizedBox(height: 12),
                      Text(
                        'Item Pesanan',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Items
                      ...(transaction['items'] as List).map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child:
                                    item['product'] != null &&
                                        item['product']['image'] != null
                                    ? Image.network(
                                        ApiService().getImageUrl(
                                          item['product']['image'],
                                        ),
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Icon(
                                          Icons.fastfood,
                                          size: 20,
                                          color: Colors.black12,
                                        ),
                                      )
                                    : Icon(
                                        Icons.fastfood,
                                        size: 20,
                                        color: Colors.black12,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            item['product'] != null
                                                ? item['product']['name']
                                                : 'Item',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          'x${item['quantity']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (item['notes'] != null &&
                                        item['notes'].toString().isNotEmpty &&
                                        item['notes']
                                            .toString()
                                            .replaceAll(
                                              '[FREE CUP / GRATIS]',
                                              '',
                                            )
                                            .replaceAll('|', '')
                                            .trim()
                                            .isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          item['notes']
                                              .toString()
                                              .replaceAll(
                                                RegExp(
                                                  r'\s*\|\s*\[FREE CUP / GRATIS\]|\[FREE CUP / GRATIS\]\s*\|\s*|\[FREE CUP / GRATIS\]',
                                                ),
                                                '',
                                              )
                                              .trim(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.amber[800],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 2),
                                    if (item['notes'] != null &&
                                        item['notes'].toString().contains(
                                          '[FREE CUP / GRATIS]',
                                        ))
                                      Text(
                                        'Gratis',
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    else
                                      Text(
                                        AppFormat.currency(item['subtotal']),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      // Total
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Pembayaran',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              AppFormat.currency(total),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Photo
                      if (photoUrl.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Foto Bukti',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                backgroundColor: const Color(0xFF5D4037),
                                insetPadding: const EdgeInsets.all(12),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: CachedNetworkImage(
                                        imageUrl: photoUrl,
                                        fit: BoxFit.contain,
                                        placeholder: (_, _) => const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                          ),
                                        ),
                                        errorWidget: (_, _, _) => const Icon(
                                          Icons.broken_image,
                                          color: Colors.white,
                                          size: 60,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: IconButton(
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                        ),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.black45,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: photoUrl,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Container(
                                height: 120,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (_, _, _) => Container(
                                height: 80,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoCell(
    String label,
    String value,
    IconData icon, {
    Color color = Colors.black54,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color == Colors.black54 ? Colors.black87 : color,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
