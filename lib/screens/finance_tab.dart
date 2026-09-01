import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/app_format.dart';
import '../utils/app_animations.dart';
import '../providers/auth_provider.dart';
import '../widgets/popup_notification.dart';
import '../widgets/custom_date_range_picker.dart';
import '../widgets/line_popup.dart';
import '../services/cache_service.dart';

class FinanceTab extends StatefulWidget {
  const FinanceTab({Key? key}) : super(key: key);

  @override
  FinanceTabState createState() => FinanceTabState();
}

class FinanceTabState extends State<FinanceTab> with AutomaticKeepAliveClientMixin {
  final ApiService _api = ApiService();

  List<dynamic> _entries = [];
  Map<String, dynamic> _summary = {'income': 0.0, 'expense': 0.0, 'net': 0.0};
  Map<String, dynamic> _chartData = {'labels': <String>[], 'incomes': <double>[], 'expenses': <double>[]};
  
  List<Map<String, dynamic>> _allocations = [
    {'label': 'Operasional', 'pct': 40, 'color': 0xFF1E88E5},
    {'label': 'Gaji Karyawan', 'pct': 20, 'color': 0xFF3F51B5},
    {'label': 'Dana Darurat', 'pct': 10, 'color': 0xFFFB8C00},
    {'label': 'Pajak & Perizinan', 'pct': 10, 'color': 0xFFF44336},
    {'label': 'Pengembangan Bisnis', 'pct': 10, 'color': 0xFF009688},
    {'label': 'Keuntungan Owner', 'pct': 15, 'color': 0xFFFFA000},
  ];

  bool _isLoading = true;
  String _filterSummary = 'monthly';   
  String _filterList = '';             
  String _filterCategory = '';         
  String _chartPeriod = 'monthly';     

  bool _isAllocationExpanded = true;
  bool _isChartExpanded = true;

  // Date range untuk ringkasan
  DateTimeRange? _summaryDateRange;
  // Date range untuk riwayat catatan
  DateTimeRange? _entriesDateRange;

  String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _displayDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
  String _displayRange(DateTimeRange r) => '${_displayDate(r.start)} - ${_displayDate(r.end)}';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Default: riwayat catatan tampilkan hari ini
    final today = DateTime.now();
    _entriesDateRange = DateTimeRange(start: today, end: today);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadSummary(), _loadEntries(), _loadChart(), _loadAllocations()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadAllocations() async {
    final cached = await CacheService.getFinanceAllocations();
    if (cached != null && mounted) {
      if (cached is Map) {
        final List<Map<String, dynamic>> migrated = [];
        final defaultColors = [0xFF1E88E5, 0xFF3F51B5, 0xFFFB8C00, 0xFFF44336, 0xFF009688, 0xFFFFA000];
        int i = 0;
        cached.forEach((key, value) {
          migrated.add({'label': key, 'pct': value as int, 'color': defaultColors[i % defaultColors.length]});
          i++;
        });
        setState(() => _allocations = migrated);
      } else if (cached is List) {
        setState(() {
          _allocations = cached.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    }
  }

  Future<void> _loadSummary() async {
    final Map<String, String>? rangeMap = _summaryDateRange != null
        ? {'start': _formatDate(_summaryDateRange!.start), 'end': _formatDate(_summaryDateRange!.end)}
        : null;
    final res = await _api.getFinanceSummary(_filterSummary, dateRange: rangeMap);
    if (mounted && res != null) setState(() => _summary = res);
  }

  Future<void> _loadEntries() async {
    final Map<String, String>? rangeMap = _entriesDateRange != null
        ? {'start': _formatDate(_entriesDateRange!.start), 'end': _formatDate(_entriesDateRange!.end)}
        : null;
    final res = await _api.getFinanceEntries(
      type: _filterList.isEmpty ? null : _filterList,
      category: _filterCategory.isEmpty ? null : _filterCategory,
      dateRange: rangeMap,
    );
    if (mounted) setState(() => _entries = res);
  }

  Future<void> _loadChart() async {
    final res = await _api.getFinanceChart(_chartPeriod);
    if (mounted && res != null) setState(() => _chartData = res);
  }

  void _showAddEditDialog({dynamic entry}) {
    final isEdit = entry != null;
    String selectedType = entry?['type'] ?? 'expense';
    final descCtrl = TextEditingController(text: entry?['description'] ?? '');
    final amountCtrl = TextEditingController(text: entry != null ? entry['amount'].toString() : '');
    final notesCtrl = TextEditingController(text: entry?['notes'] ?? '');
    DateTime selectedDate = entry != null ? DateTime.parse(entry['date']) : DateTime.now();
    String? selectedCategory = entry?['category'];
    String? selectedAllocation = entry?['allocation'];

    final incomeCategories = ['Penjualan', 'Bonus', 'Investasi', 'Lain-lain'];
    final expenseCategories = ['Belanja Bahan', 'Gaji Karyawan', 'Listrik & Air', 'Sewa Tempat', 'Peralatan', 'Operasional', 'Marketing', 'Lain-lain'];
    final allocationOptions = _allocations.map((e) => e['label'] as String).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setModal) {
          final categories = selectedType == 'income' ? incomeCategories : expenseCategories;
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(child: Container(margin: const EdgeInsets.only(top: 12, bottom: 20), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                  Text(isEdit ? 'Edit Catatan' : 'Tambah Catatan', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 20),

                  // Type selector
                  Row(children: [
                    Expanded(child: _typeButton('income', 'Pemasukan', Icons.trending_up, selectedType, (v) => setModal(() { selectedType = v; selectedCategory = null; selectedAllocation = null; }))),
                    const SizedBox(width: 10),
                    Expanded(child: _typeButton('expense', 'Pengeluaran', Icons.trending_down, selectedType, (v) => setModal(() { selectedType = v; selectedCategory = null; selectedAllocation = null; }))),
                  ]),
                  const SizedBox(height: 16),

                  // Category chips
                  Wrap(spacing: 8, runSpacing: 6, children: categories.map((cat) {
                    final sel = selectedCategory == cat;
                    return GestureDetector(
                      onTap: () => setModal(() => selectedCategory = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel ? (selectedType == 'income' ? Colors.green[600] : Colors.red[600]) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(cat, style: TextStyle(fontSize: 12, color: sel ? Colors.white : Colors.black87, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                      ),
                    );
                  }).toList()),
                  const SizedBox(height: 16),

                  // Allocation picker (only for expense)
                  if (selectedType == 'expense') ...[
                    Text('Alokasi Anggaran', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 6, children: allocationOptions.map((alloc) {
                      final sel = selectedAllocation == alloc;
                      return GestureDetector(
                        onTap: () => setModal(() => selectedAllocation = sel ? null : alloc),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? const Color(0xFF5D4037) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                            border: sel ? null : Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (sel) ...[
                                const Icon(Icons.check_circle, size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                              ],
                              Text(alloc, style: TextStyle(fontSize: 12, color: sel ? Colors.white : Colors.black87, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                            ],
                          ),
                        ),
                      );
                    }).toList()),
                    const SizedBox(height: 16),
                  ],

                  // Description
                  TextFormField(
                    controller: descCtrl,
                    decoration: _inputDeco('Keterangan', Icons.notes),
                  ),
                  const SizedBox(height: 12),

                  // Amount
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDeco('Jumlah', Icons.money, prefix: 'Rp '),
                  ),
                  const SizedBox(height: 12),

                  // Date
                  GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(context: ctx2, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2099));
                      if (d != null) setModal(() => selectedDate = d);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10), color: Colors.grey[50]),
                      child: Row(children: [
                        Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 10),
                        Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}', style: const TextStyle(fontSize: 15)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: _inputDeco('Catatan (opsional)', Icons.edit_note),
                  ),
                  const SizedBox(height: 24),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedType == 'income' ? Colors.green[600] : Colors.red[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (descCtrl.text.isEmpty || amountCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keterangan dan jumlah wajib diisi')));
                          return;
                        }
                        final data = {
                          'type': selectedType,
                          'description': descCtrl.text.trim(),
                          'amount': double.tryParse(amountCtrl.text.replaceAll(',', '')) ?? 0.0,
                          'date': '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                          'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                          if (selectedCategory != null) 'category': selectedCategory,
                          'allocation': selectedType == 'expense' ? selectedAllocation : null,
                        };
                        Navigator.pop(ctx2);
                        bool ok;
                        if (isEdit) {
                          ok = await _api.updateFinanceEntry(entry['id'], data);
                        } else {
                          ok = await _api.createFinanceEntry(data);
                        }
                        if (ok) {
                          PopupNotification.show(context, title: 'Berhasil', message: isEdit ? 'Catatan diperbarui.' : 'Catatan ditambahkan.', type: PopupType.success);
                          if (!isEdit) {
                            NotificationService().showFinanceNotification(
                              title: 'Catatan Keuangan Baru',
                              body: '${descCtrl.text.trim()} - ${selectedType == 'income' ? 'Pemasukan' : 'Pengeluaran'}',
                            );
                          }
                          _loadAll();
                        } else {
                          PopupNotification.show(context, title: 'Gagal', message: 'Silakan coba lagi.', type: PopupType.error);
                        }
                      },
                      child: Text(isEdit ? 'Simpan Perubahan' : 'Tambah Catatan', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
              ),
            ),
          );
        });
      },
    );
  }

  Widget _typeButton(String val, String label, IconData icon, String selected, Function(String) onTap) {
    final isSelected = val == selected;
    final color = val == 'income' ? Colors.green[600]! : Colors.red[600]!;
    return GestureDetector(
      onTap: () => onTap(val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: isSelected ? Colors.white : Colors.grey[600], size: 18),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey[700])),
        ]),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon, {String? prefix}) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20),
    prefixText: prefix,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF5D4037), width: 2)),
    fillColor: Colors.grey[50],
    filled: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  Future<void> _deleteEntry(dynamic entry) async {
    final confirm = await LinePopup.showConfirmChoice(
      context,
      title: 'Hapus Catatan?',
      description: 'Hapus catatan "${entry['description']}"?',
      dismissText: 'Batal',
      affirmText: 'Hapus',
      affirmColor: Colors.red,
    );
    if (!confirm) return;
    final ok = await _api.deleteFinanceEntry(entry['id']);
    if (ok) {
      PopupNotification.show(context, title: 'Dihapus', message: 'Catatan berhasil dihapus.', type: PopupType.success);
      _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Keuangan', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.black), onPressed: _loadAll),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF5D4037),
        foregroundColor: Colors.white,
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF5D4037)))
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  _buildSummaryCards(),
                  const SizedBox(height: 16),
                  _buildProfitAllocation(),
                  const SizedBox(height: 16),
                  _buildChartSection(),
                  const SizedBox(height: 16),
                  _buildEntriesList(),
                ],
              ),
            ),
    );
  }

  void _showCustomAllocationSheet() {
    final List<TextEditingController> labelCtrls = [];
    final List<TextEditingController> pctCtrls = [];
    final List<int> colors = [];
    for (var alloc in _allocations) {
      labelCtrls.add(TextEditingController(text: alloc['label']));
      pctCtrls.add(TextEditingController(text: alloc['pct'].toString()));
      colors.add(alloc['color'] as int);
    }
    final defaultColors = [0xFF1E88E5, 0xFF3F51B5, 0xFFFB8C00, 0xFFF44336, 0xFF009688, 0xFFFFA000];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(margin: const EdgeInsets.only(top: 12, bottom: 20), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                      const Text('Set Alokasi Net Profit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 8),
                      Text('Set nama dan persentase alokasi sesuai kebutuhan', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                      const SizedBox(height: 20),
                      ...List.generate(labelCtrls.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: labelCtrls[index],
                                  decoration: InputDecoration(
                                    hintText: 'Nama Alokasi',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                                    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: Color(0xFF5D4037), width: 2)),
                                    fillColor: Colors.grey[50],
                                    filled: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 80,
                                child: TextFormField(
                                  controller: pctCtrls[index],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    suffixText: '%',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                                    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: Color(0xFF5D4037), width: 2)),
                                    fillColor: Colors.grey[50],
                                    filled: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setModalState(() {
                                    labelCtrls.removeAt(index);
                                    pctCtrls.removeAt(index);
                                    colors.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () {
                          setModalState(() {
                            labelCtrls.add(TextEditingController());
                            pctCtrls.add(TextEditingController(text: '0'));
                            colors.add(defaultColors[labelCtrls.length % defaultColors.length]);
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline, color: Color(0xFF5D4037)),
                        label: const Text('Tambah Alokasi', style: TextStyle(color: Color(0xFF5D4037), fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5D4037),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final List<Map<String, dynamic>> newAllocs = [];
                            for (int i = 0; i < labelCtrls.length; i++) {
                              newAllocs.add({
                                'label': labelCtrls[i].text.trim().isEmpty ? 'Alokasi ${i + 1}' : labelCtrls[i].text.trim(),
                                'pct': int.tryParse(pctCtrls[i].text) ?? 0,
                                'color': colors[i],
                              });
                            }
                            await CacheService.saveFinanceAllocations(newAllocs);
                            setState(() => _allocations = newAllocs);
                            Navigator.pop(ctx);
                            PopupNotification.show(context, title: 'Berhasil', message: 'Alokasi berhasil diperbarui.', type: PopupType.success);
                          },
                          child: const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfitAllocation() {
    final income = (_summary['income'] as num?)?.toDouble() ?? 0.0;
    final expense = (_summary['expense'] as num?)?.toDouble() ?? 0.0;
    final net = income - expense;
    final allocationSpent = (_summary['allocation_spent'] as Map<String, dynamic>?) ?? {};

    // Bar max = largest allocation for proportional width
    final maxPct = _allocations.fold<int>(0, (prev, a) => (a['pct'] as int) > prev ? (a['pct'] as int) : prev);
    final totalPct = _allocations.fold<int>(0, (prev, a) => prev + (a['pct'] as int));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xFF5D4037).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.pie_chart_outline, color: Color(0xFF5D4037), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Alokasi Net Profit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              GestureDetector(
                onTap: _showCustomAllocationSheet,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Icon(Icons.edit_outlined, size: 16, color: Colors.grey[700]),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: net >= 0 ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppFormat.currency(net),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: net >= 0 ? Colors.green[700] : Colors.red[700]),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isAllocationExpanded = !_isAllocationExpanded;
                  });
                },
                child: Icon(
                  _isAllocationExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Berdasarkan filter: ${_summaryDateRange != null ? _displayRange(_summaryDateRange!) : _filterSummary == 'daily' ? 'Hari Ini' : _filterSummary == 'weekly' ? 'Minggu Ini' : 'Bulan Ini'}',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          if (_isAllocationExpanded) ...[
            const SizedBox(height: 16),
            ..._allocations.map((a) {
            final pct = a['pct'] as int;
            final allocated = net * pct / 100;
            final label = a['label'] as String;
            final spent = (allocationSpent[label] as num?)?.toDouble() ?? 0.0;
            final remaining = allocated - spent;
            final color = Color(a['color'] as int);
            // Progress: how much of the allocation has been spent
            final spentRatio = allocated > 0 ? (spent / allocated).clamp(0.0, 1.5) : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                      Text('$pct%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[400])),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Allocated vs Spent row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Anggaran: ${AppFormat.currency(allocated)}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                            const SizedBox(height: 2),
                            Text('Terpakai: ${AppFormat.currency(spent)}', style: TextStyle(fontSize: 11, color: spent > allocated && allocated > 0 ? Colors.red[600] : Colors.grey[600], fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: remaining >= 0 ? Colors.green[50] : Colors.red[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Sisa: ${AppFormat.currency(remaining)}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: remaining >= 0 ? Colors.green[700] : Colors.red[600]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        Container(height: 6, width: double.infinity, color: Colors.grey[100]),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          height: 6,
                          width: MediaQuery.of(context).size.width * 0.65 * spentRatio.clamp(0.0, 1.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: spentRatio > 1.0
                                  ? [Colors.red[400]!, Colors.red[600]!]
                                  : [color.withOpacity(0.7), color],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 20),
          // Total row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.functions, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text('Total Alokasi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[700])),
              ]),
              Row(children: [
                Text('$totalPct%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500])),
                const SizedBox(width: 10),
                Text(
                  AppFormat.currency(net * totalPct / 100),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: net >= 0 ? const Color(0xFF5D4037) : Colors.red[600]),
                ),
              ]),
            ],
          ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final income = (_summary['income'] as num?)?.toDouble() ?? 0.0;
    final expense = (_summary['expense'] as num?)?.toDouble() ?? 0.0;
    final net = income - expense;

    final filters = [
      {'val': 'daily', 'label': 'Hari Ini'},
      {'val': 'weekly', 'label': 'Minggu Ini'},
      {'val': 'monthly', 'label': 'Bulan Ini'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Period filter row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            // Tombol preset filter
            ...filters.map((f) {
              final sel = _summaryDateRange == null && _filterSummary == f['val'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () async {
                    setState(() {
                      _filterSummary = f['val']!;
                      _summaryDateRange = null;
                    });
                    await _loadSummary();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFF5D4037) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: sel ? [BoxShadow(color: Colors.brown.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))] : [],
                    ),
                    child: Text(f['label']!, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: sel ? Colors.white : Colors.grey[700])),
                  ),
                ),
              );
            }),
            // Tombol filter rentang tanggal
            GestureDetector(
              onTap: () async {
                final picked = await CustomDateRangePicker.show(
                  context,
                  initialStartDate: _summaryDateRange?.start,
                  initialEndDate: _summaryDateRange?.end,
                );
                if (picked != null && mounted) {
                  setState(() => _summaryDateRange = picked);
                  await _loadSummary();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _summaryDateRange != null ? const Color(0xFF5D4037) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _summaryDateRange != null ? [BoxShadow(color: Colors.brown.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))] : [],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.date_range, size: 13, color: _summaryDateRange != null ? Colors.white : Colors.grey[700]),
                  const SizedBox(width: 5),
                  Text(
                    _summaryDateRange != null ? _displayRange(_summaryDateRange!) : 'Rentang Tanggal',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: _summaryDateRange != null ? Colors.white : Colors.grey[700]),
                  ),
                  if (_summaryDateRange != null) ...[
                    const SizedBox(width: 5),
                    GestureDetector(
                      onTap: () async {
                        setState(() => _summaryDateRange = null);
                        await _loadSummary();
                      },
                      child: const Icon(Icons.close, size: 13, color: Colors.white70),
                    ),
                  ],
                ]),
              ),
            ),
          ]),
        ),
        // Label rentang tanggal yang dipilih
        if (_summaryDateRange != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Row(children: [
              Icon(Icons.info_outline, size: 12, color: Colors.brown[400]),
              const SizedBox(width: 4),
              Text('Ringkasan: ${_displayRange(_summaryDateRange!)}', style: TextStyle(fontSize: 11, color: Colors.brown[400])),
            ]),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _summaryCard('Pemasukan', income, Colors.green[600]!, Icons.trending_up)),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard('Pengeluaran', expense, Colors.red[600]!, Icons.trending_down)),
        ]),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: net >= 0 ? [Colors.green[700]!, Colors.green[500]!] : [Colors.red[700]!, Colors.red[500]!],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: (net >= 0 ? Colors.green : Colors.red).withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Net Profit', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(AppFormat.currency(net), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ]),
            Icon(net >= 0 ? Icons.sentiment_very_satisfied_outlined : Icons.sentiment_very_dissatisfied_outlined, color: Colors.white70, size: 32),
          ]),
        ),
      ],
    );
  }

  Widget _summaryCard(String label, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 16)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 8),
        Text(AppFormat.currency(amount), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
      ]),
    );
  }

  Widget _buildChartSection() {
    final labels = (_chartData['labels'] as List?)?.cast<String>() ?? [];
    final incomes = (_chartData['incomes'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
    final expenses = (_chartData['expenses'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];

    final maxVal = [...incomes, ...expenses].fold(0.0, (prev, e) => e > prev ? e : prev);
    final chartMax = maxVal > 0 ? maxVal * 1.2 : 1000.0;

    final periods = [
      {'val': 'daily', 'label': 'Harian'},
      {'val': 'weekly', 'label': 'Mingguan'},
      {'val': 'monthly', 'label': 'Bulanan'},
    ];

    int visibleCount = _chartPeriod == 'daily' ? 7 : (_chartPeriod == 'weekly' ? 8 : 6);
    final visibleLabels = labels.length > visibleCount ? labels.sublist(labels.length - visibleCount) : labels;
    final visibleIncomes = incomes.length > visibleCount ? incomes.sublist(incomes.length - visibleCount) : incomes;
    final visibleExpenses = expenses.length > visibleCount ? expenses.sublist(expenses.length - visibleCount) : expenses;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Grafik Keuangan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          // chart period buttons and minimize toggle
          Row(children: [
            Row(children: periods.map((p) {
              final sel = _chartPeriod == p['val'];
              return GestureDetector(
                onTap: () async {
                  setState(() => _chartPeriod = p['val']!);
                  await _loadChart();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFF5D4037) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(p['label']!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: sel ? Colors.white : Colors.grey[600])),
                ),
              );
            }).toList()),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isChartExpanded = !_isChartExpanded;
                });
              },
              child: Icon(
                _isChartExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.grey[700],
              ),
            ),
          ]),
        ]),
        if (_isChartExpanded) ...[
          const SizedBox(height: 12),
          // Legend
          Row(children: [
            _legendDot(Colors.green[600]!, 'Pemasukan'),
          const SizedBox(width: 16),
          _legendDot(Colors.red[600]!, 'Pengeluaran'),
        ]),
        const SizedBox(height: 16),
        if (visibleLabels.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Belum ada data', style: TextStyle(color: Colors.grey))))
        else
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(visibleLabels.length, (i) {
                final inc = i < visibleIncomes.length ? visibleIncomes[i] : 0.0;
                final exp = i < visibleExpenses.length ? visibleExpenses[i] : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _bar(inc, chartMax, Colors.green[400]!),
                            const SizedBox(width: 2),
                            _bar(exp, chartMax, Colors.red[400]!),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(visibleLabels[i], style: const TextStyle(fontSize: 8, color: Colors.grey), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _bar(double val, double max, Color color) {
    final h = max > 0 ? (val / max * 120.0).clamp(2.0, 120.0) : 2.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: 8,
      height: h,
      decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
  }

  Widget _buildEntriesList() {
    final filterOptions = [
      {'val': '', 'label': 'Semua'},
      {'val': 'income', 'label': 'Pemasukan'},
      {'val': 'expense', 'label': 'Pengeluaran'},
    ];

    final incomeCategories = ['Penjualan', 'Bonus', 'Investasi', 'Lain-lain'];
    final expenseCategories = ['Belanja Bahan', 'Gaji Karyawan', 'Listrik & Air', 'Sewa Tempat', 'Peralatan', 'Operasional', 'Marketing', 'Lain-lain'];
    
    List<String> currentCategories = [];
    if (_filterList == 'income') {
      currentCategories = incomeCategories;
    } else if (_filterList == 'expense') {
      currentCategories = expenseCategories;
    } else {
      currentCategories = [...incomeCategories, ...expenseCategories].toSet().toList();
    }

    // Double check filter secara lokal walau sudah dari API
    var filtered = _entries;
    if (_filterList.isNotEmpty) {
      filtered = filtered.where((e) => e['type'] == _filterList).toList();
    }
    if (_filterCategory.isNotEmpty) {
      filtered = filtered.where((e) => e['category'] == _filterCategory).toList();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header row: judul + tombol filter rentang tanggal
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Riwayat Catatan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          if (_entriesDateRange != null)
            Text(
              _displayRange(_entriesDateRange!),
              style: TextStyle(fontSize: 11, color: Colors.brown[400], fontWeight: FontWeight.w500),
            )
          else
            Text('Semua Tanggal', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ]),
        // Tombol pilih rentang tanggal
        GestureDetector(
          onTap: () async {
            final picked = await CustomDateRangePicker.show(
              context,
              initialStartDate: _entriesDateRange?.start,
              initialEndDate: _entriesDateRange?.end,
            );
            if (picked != null && mounted) {
              setState(() => _entriesDateRange = picked);
              _loadEntries();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _entriesDateRange != null ? const Color(0xFF5D4037) : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.date_range, size: 13, color: _entriesDateRange != null ? Colors.white : Colors.grey[600]),
              const SizedBox(width: 5),
              Text(
                _entriesDateRange != null ? _displayRange(_entriesDateRange!) : 'Pilih Tanggal',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _entriesDateRange != null ? Colors.white : Colors.grey[600]),
              ),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      // Row 2: filter tipe + tombol tampilkan semua
      Row(children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: filterOptions.map((f) {
              final sel = _filterList == f['val'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _filterList = f['val']!;
                    _filterCategory = ''; // Reset kategori saat tipe berubah
                  });
                  _loadEntries();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFF5D4037) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(f['label']!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: sel ? Colors.white : Colors.grey[600])),
                ),
              );
            }).toList()),
          ),
        ),
        // Tombol tampilkan semua / reset tanggal
        if (_entriesDateRange != null)
          GestureDetector(
            onTap: () {
              setState(() {
                _entriesDateRange = null;
                _filterCategory = '';
                _filterList = '';
              });
              _loadEntries();
            },
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.list_alt, size: 12, color: Colors.grey[700]),
                const SizedBox(width: 4),
                Text('Reset Semua', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[700])),
              ]),
            ),
          ),
      ]),
      const SizedBox(height: 8),
      // Row 3: Filter Kategori
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Opsi "Semua Kategori"
            GestureDetector(
              onTap: () {
                setState(() => _filterCategory = '');
                _loadEntries();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _filterCategory.isEmpty ? const Color(0xFF5D4037) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('Semua Kategori', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _filterCategory.isEmpty ? Colors.white : Colors.grey[600])),
              ),
            ),
            // Kategori lainnya
            ...currentCategories.map((cat) {
              final sel = _filterCategory == cat;
              return GestureDetector(
                onTap: () {
                  setState(() => _filterCategory = cat);
                  _loadEntries();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFF5D4037) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(cat, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: sel ? Colors.white : Colors.grey[600])),
                ),
              );
            }).toList(),
          ],
        ),
      ),
      const SizedBox(height: 10),
      if (filtered.isEmpty)
        Container(
          padding: const EdgeInsets.all(32),
          alignment: Alignment.center,
          child: Column(children: [
            Icon(Icons.receipt_long_outlined, color: Colors.grey[300], size: 48),
            const SizedBox(height: 8),
            Text(
              _entriesDateRange != null
                  ? 'Tidak ada catatan pada ${_displayRange(_entriesDateRange!)}'
                  : 'Belum ada catatan',
              style: TextStyle(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ]),
        )
      else
        ...filtered.asMap().entries.map((e) => FadeSlideIn(
          delay: Duration(milliseconds: 40 * e.key),
          child: _entryCard(e.value),
        )).toList(),
    ]);
  }

  Widget _entryCard(dynamic entry) {
    final isIncome = entry['type'] == 'income';
    final color = isIncome ? Colors.green[600]! : Colors.red[600]!;
    final amount = (entry['amount'] as num?)?.toDouble() ?? 0.0;
    final dateStr = entry['date'] != null ? entry['date'].toString().substring(0, 10) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(isIncome ? Icons.trending_up : Icons.trending_down, color: color, size: 20),
        ),
        title: Text(entry['description'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Row(children: [
          if (entry['category'] != null) ...[
            Container(
              margin: const EdgeInsets.only(top: 3, right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
              child: Text(entry['category'], style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            ),
          ],
          Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            (isIncome ? '+' : '-') + AppFormat.currency(amount),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Edit')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16, color: Colors.red), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: Colors.red))])),
            ],
            onSelected: (val) {
              if (val == 'edit') _showAddEditDialog(entry: entry);
              if (val == 'delete') _deleteEntry(entry);
            },
          ),
        ]),
      ),
    );
  }
}
