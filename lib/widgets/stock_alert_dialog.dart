import 'package:flutter/material.dart';
import '../services/api_service.dart';

class StockAlertDialog extends StatefulWidget {
  final String title;
  final String message;

  const StockAlertDialog({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  State<StockAlertDialog> createState() => _StockAlertDialogState();
}

class _StockAlertDialogState extends State<StockAlertDialog> {
  bool _isLoading = true;
  int _lowStockProducts = 0;
  int _lowStockMaterials = 0;

  @override
  void initState() {
    super.initState();
    _fetchStockData();
  }

  Future<void> _fetchStockData() async {
    try {
      final api = ApiService();
      final products = await api.getProducts();
      final materials = await api.getRawMaterials();

      debugPrint('DEBUG StockAlertDialog: Fetched ${products.length} products');
      debugPrint(
        'DEBUG StockAlertDialog: Fetched ${materials.length} raw materials',
      );

      if (mounted) {
        setState(() {
          _lowStockProducts = products
              .where((p) => p.isActive && p.stock <= 5)
              .length;
          _lowStockMaterials = materials
              .where((m) => m.isActive && m.stock <= m.minStock)
              .length;
          _isLoading = false;
        });
        debugPrint('DEBUG StockAlertDialog: Low Products = $_lowStockProducts');
        debugPrint(
          'DEBUG StockAlertDialog: Low Materials = $_lowStockMaterials',
        );
      }
    } catch (e, stack) {
      debugPrint('DEBUG StockAlertDialog Error: $e');
      debugPrint('DEBUG StockAlertDialog Stack: $stack');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: Colors.amber[900],
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message,
            style: TextStyle(color: Colors.grey[700], height: 1.5),
          ),
          const SizedBox(height: 24),
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 3,
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      _buildStockRow(
                        Icons.fastfood_outlined,
                        'Produk Menipis',
                        _lowStockProducts,
                        _lowStockProducts > 0
                            ? Colors.red[700]!
                            : Colors.green[700]!,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Divider(height: 1),
                      ),
                      _buildStockRow(
                        Icons.kitchen_outlined,
                        'Bahan Baku Menipis',
                        _lowStockMaterials,
                        _lowStockMaterials > 0
                            ? Colors.orange[700]!
                            : Colors.green[700]!,
                      ),
                    ],
                  ),
                ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5D4037),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Tutup',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    );
  }

  Widget _buildStockRow(IconData icon, String label, int count, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
