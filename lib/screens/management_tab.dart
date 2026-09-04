import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../models/raw_material.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../widgets/popup_notification.dart';
import 'user_management_tab.dart';
import 'printer_settings_screen.dart';
import '../utils/app_format.dart';
import '../providers/auth_provider.dart';

class ManagementTab extends StatefulWidget {
  const ManagementTab({super.key});

  @override
  _ManagementTabState createState() => _ManagementTabState();
}

class _ManagementTabState extends State<ManagementTab>
    with SingleTickerProviderStateMixin {
  TabController? _tabCtrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context);

    // Check permissions
    final bool canStock = auth.can('manage_stock');
    final bool canEmployees = auth.can('manage_employees');
    final bool canPrinter = auth.can('manage_printer');
    final bool canRawItems = auth.can('manage_raw_materials');

    int tabCount = 0;
    if (canStock) tabCount++;
    if (canEmployees) tabCount++;
    if (canPrinter) tabCount++;
    if (canRawItems) tabCount++;

    if (_tabCtrl == null || _tabCtrl!.length != tabCount) {
      _tabCtrl?.dispose();
      _tabCtrl = TabController(length: tabCount, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tabCtrl == null) return SizedBox.shrink();

    return Column(
      children: [
        // Tab bar header
        Container(
          color: Colors.white,
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    'Management',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TabBar(
                  controller: _tabCtrl,
                  indicatorColor: const Color(0xFF5D4037),
                  labelColor: const Color(0xFF5D4037),
                  unselectedLabelColor: Colors.grey[400],
                  tabs: [
                    if (Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    ).can('manage_stock'))
                      Tab(
                        icon: Icon(Icons.inventory_2_outlined),
                        text: 'Stok Produk',
                      ),
                    if (Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    ).can('manage_employees'))
                      Tab(icon: Icon(Icons.people_outline), text: 'Karyawan'),
                    if (Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    ).can('manage_printer'))
                      Tab(icon: Icon(Icons.print_outlined), text: 'Printer'),
                    if (Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    ).can('manage_raw_materials'))
                      Tab(icon: Icon(Icons.bakery_dining), text: 'Bahan Baku'),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              if (Provider.of<AuthProvider>(
                context,
                listen: false,
              ).can('manage_stock'))
                _StockManagementView(),
              if (Provider.of<AuthProvider>(
                context,
                listen: false,
              ).can('manage_employees'))
                UserManagementTab(),
              if (Provider.of<AuthProvider>(
                context,
                listen: false,
              ).can('manage_printer'))
                PrinterSettingsScreen(),
              if (Provider.of<AuthProvider>(
                context,
                listen: false,
              ).can('manage_raw_materials'))
                _RawMaterialsView(),
            ],
          ),
        ),
      ],
    );
  }
}

// ---- Stock Management (Read-Only, synced from raw materials) ----

class _StockManagementView extends StatefulWidget {
  @override
  _StockManagementViewState createState() => _StockManagementViewState();
}

class _StockManagementViewState extends State<_StockManagementView>
    with AutomaticKeepAliveClientMixin {
  final ApiService _apiService = ApiService();
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (!forceRefresh) {
      final cached = await CacheService.getMgmtStock();
      if (cached != null && mounted) {
        setState(() {
          _products = cached.map((e) => Product.fromJson(e)).toList();
          _isLoading = false;
        });
        _fetchProducts(forceRefresh: true);
        return;
      }
    }
    if (_products.isEmpty && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final products = await _apiService.getProducts();
      await CacheService.saveMgmtStock(
        products.map((p) => p.toJson()).toList(),
      );
      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: const Color(0xFF5D4037)),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey[400]),
            SizedBox(height: 12),
            Text(
              'Tidak ada produk',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Tambah produk melalui panel admin web',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
            SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _fetchProducts(forceRefresh: true),
              icon: Icon(Icons.refresh),
              label: Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    final lowStock = _products.where((p) => p.stock <= 5).length;
    final outOfStock = _products.where((p) => p.stock <= 0).length;

    return RefreshIndicator(
      onRefresh: () => _fetchProducts(forceRefresh: true),
      child: ListView(
        padding: EdgeInsets.all(12),
        children: [
          // Summary header
          Container(
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF5D4037).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _summaryChip('Total', '${_products.length}', Colors.blueGrey),
                SizedBox(width: 8),
                if (outOfStock > 0) ...[
                  _summaryChip('Habis', '$outOfStock', Colors.red),
                  SizedBox(width: 8),
                ],
                if (lowStock > 0)
                  _summaryChip('Rendah', '$lowStock', Colors.orange),
              ],
            ),
          ),
          // Product list
          ..._products.map((product) {
            final stockColor = product.stock <= 0
                ? Colors.red
                : product.stock <= 10
                ? Colors.orange
                : Colors.green;

            return Container(
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: product.image != null
                          ? CachedNetworkImage(
                              imageUrl: _apiService.getImageUrl(product.image),
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorWidget: (c, u, e) => Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.broken_image,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.fastfood,
                                size: 20,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            AppFormat.currency(product.price),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: stockColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: stockColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        '${product.stock}',
                        style: TextStyle(
                          color: stockColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
          SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}

// ---- Raw Materials Management ----

class _RawMaterialsView extends StatefulWidget {
  @override
  _RawMaterialsViewState createState() => _RawMaterialsViewState();
}

class _RawMaterialsViewState extends State<_RawMaterialsView>
    with AutomaticKeepAliveClientMixin {
  final ApiService _apiService = ApiService();
  List<RawMaterial> _materials = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchMaterials();
  }

  Future<void> _fetchMaterials() async {
    if (!mounted) return;
    if (_materials.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final materials = await _apiService.getRawMaterials();
      if (!mounted) return;
      setState(() {
        _materials = materials;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: const Color(0xFF5D4037)),
      );
    }

    if (_materials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bakery_dining, size: 56, color: Colors.grey[400]),
            SizedBox(height: 12),
            Text(
              'Tidak ada bahan baku',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _fetchMaterials,
              icon: Icon(Icons.refresh),
              label: Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    final lowStock = _materials
        .where((m) => m.isActive && m.stock <= m.minStock)
        .length;

    return RefreshIndicator(
      onRefresh: _fetchMaterials,
      child: ListView(
        padding: EdgeInsets.all(12),
        children: [
          // Summary header
          Container(
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _chip('Total', '${_materials.length}', Colors.blueGrey),
                SizedBox(width: 8),
                if (lowStock > 0)
                  _chip('Stok Rendah', '$lowStock', Colors.orange),
              ],
            ),
          ),
          // Material list
          ..._materials.map((material) {
            final isLow =
                material.isActive && material.stock <= material.minStock;
            final stockColor = material.stock <= 0
                ? Colors.red
                : isLow
                ? Colors.orange
                : Colors.green;

            return Container(
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showEditDialog(material),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(10),
                          image:
                              material.image != null &&
                                  material.image!.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(
                                    _apiService.getImageUrl(material.image),
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: material.image == null || material.image!.isEmpty
                            ? Icon(
                                Icons.bakery_dining,
                                size: 22,
                                color: Colors.amber[700],
                              )
                            : null,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              material.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2),
                            Text(
                              '${material.stock.toStringAsFixed(material.stock == material.stock.roundToDouble() ? 0 : 1)} ${material.unit}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: stockColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: stockColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLow
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline,
                              size: 14,
                              color: stockColor,
                            ),
                            SizedBox(width: 4),
                            Text(
                              material.stock <= 0
                                  ? 'Habis'
                                  : isLow
                                  ? 'Rendah'
                                  : 'OK',
                              style: TextStyle(
                                color: stockColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _chip(String label, String count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
          SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  void _showEditDialog(RawMaterial material) {
    final nameCtrl = TextEditingController(text: material.name);
    final stockCtrl = TextEditingController(text: material.stock.toString());
    final unitCtrl = TextEditingController(text: material.unit);

    InputDecoration fieldDeco(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: Colors.grey[600]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF5D4037), width: 2),
      ),
      fillColor: Colors.grey[50],
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5D4037).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.bakery_dining,
                      size: 18,
                      color: Color(0xFF5D4037),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Edit ${material.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Fields
              TextField(
                controller: nameCtrl,
                decoration: fieldDeco(
                  'Nama Bahan',
                  Icons.shopping_bag_outlined,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: stockCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: fieldDeco('Stok', Icons.inventory_2_outlined),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: unitCtrl,
                      decoration: fieldDeco('Satuan', Icons.straighten),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5D4037),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final success = await _apiService
                            .updateRawMaterial(material.id, {
                              'name': nameCtrl.text,
                              'stock':
                                  double.tryParse(stockCtrl.text) ??
                                  material.stock,
                              'unit': unitCtrl.text,
                            });
                        if (success) {
                          PopupNotification.show(
                            context,
                            title: 'Berhasil Diperbarui ✏️',
                            message: '${material.name} telah diupdate.',
                            type: PopupType.success,
                          );
                          _fetchMaterials();
                        } else {
                          PopupNotification.show(
                            context,
                            title: 'Gagal Memperbarui',
                            message: 'Tidak bisa mengupdate ${material.name}.',
                            type: PopupType.error,
                          );
                        }
                      },
                      child: const Text(
                        'Simpan Perubahan',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
