import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import '../services/api_service.dart';
import '../widgets/popup_notification.dart';
import '../utils/app_format.dart';
import '../providers/auth_provider.dart';
import '../services/printer_service.dart';
import '../widgets/camera_dialog.dart';
import '../widgets/loading_overlay.dart';
import '../utils/app_animations.dart';
import '../widgets/line_popup.dart';
import 'package:provider/provider.dart';

class ActiveOrdersTab extends StatefulWidget {
  final VoidCallback? onNavigateToHistory;
  final VoidCallback? onOrderCompleted;

  const ActiveOrdersTab({
    super.key,
    this.onNavigateToHistory,
    this.onOrderCompleted,
  });

  @override
  ActiveOrdersTabState createState() => ActiveOrdersTabState();
}

class ActiveOrdersTabState extends State<ActiveOrdersTab>
    with AutomaticKeepAliveClientMixin {
  final ApiService _apiService = ApiService();
  final PrinterService _printerService = PrinterService();
  List<dynamic> _activeOrders = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchActiveOrders();
  }

  void refreshOrders() {
    _fetchActiveOrders();
  }

  Future<void> _fetchActiveOrders() async {
    if (!mounted) return;
    if (_activeOrders.isEmpty) {
      setState(() => _isLoading = true);
    }
    final orders = await _apiService.getActiveOrders();
    if (!mounted) return;
    setState(() {
      _activeOrders = orders;
      _isLoading = false;
    });
  }

  Future<void> _markAsCompleted(
    dynamic order, {
    XFile? photo,
    String? orderType,
    double? amountReceived,
    double? changeAmount,
  }) async {
    LoadingOverlay.show(context, message: 'Menyelesaikan pesanan...');
    final success = await _apiService.updateTransactionStatus(
      order['id'],
      'completed',
      photo: photo,
      orderType: orderType,
      amountReceived: amountReceived,
      changeAmount: changeAmount,
    );
    if (!mounted) return;
    LoadingOverlay.hide(context);
    if (success) {
      // Always refresh the active orders list first (remove completed item)
      await _fetchActiveOrders();
      if (!mounted) return;

      PopupNotification.show(
        context,
        title: 'Order Selesai!',
        message: 'Order #${order['id']} telah dipindahkan ke History.',
        type: PopupType.success,
      );

      // Trigger parent: refresh history tab then navigate to it
      if (widget.onOrderCompleted != null) {
        widget.onOrderCompleted!();
      } else if (widget.onNavigateToHistory != null) {
        widget.onNavigateToHistory!();
      }
    } else {
      PopupNotification.show(
        context,
        title: 'Gagal Update Status',
        message: 'Tidak bisa menyelesaikan order. Coba lagi.',
        type: PopupType.error,
      );
    }
  }

  void _showCompletionDialog(dynamic order) {
    XFile? selectedPhoto;
    Uint8List? photoBytes;
    bool isPickingImage = false;
    String? selectedOrderType = order['order_type'] as String?;

    const orderTypes = [
      {'value': 'dine_in', 'label': 'Dine In', 'icon': Icons.restaurant},
      {
        'value': 'take_away',
        'label': 'Take Away',
        'icon': Icons.shopping_bag_outlined,
      },
      {'value': 'online', 'label': 'Online', 'icon': Icons.delivery_dining},
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> capturePhoto() async {
              if (isPickingImage) return;
              setDialogState(() => isPickingImage = true);
              try {
                final img = await CameraHelper.captureWithCamera(dialogCtx);
                if (img != null) {
                  final bytes = await img.readAsBytes();
                  setDialogState(() {
                    selectedPhoto = img;
                    photoBytes = bytes;
                  });
                }
              } catch (e) {
                debugPrint('Camera capture error: $e');
              } finally {
                setDialogState(() => isPickingImage = false);
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.green[600],
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Selesaikan Orderan',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Order #${order['id']} - ${order['customer_name'] ?? 'Tamu'}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          const Icon(
                            Icons.storefront_outlined,
                            size: 16,
                            color: Colors.black87,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Tipe Order (Wajib)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: orderTypes.map((type) {
                          final isSelected = selectedOrderType == type['value'];
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setDialogState(
                                () =>
                                    selectedOrderType = type['value'] as String,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.grey[300]!,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      type['icon'] as IconData,
                                      size: 20,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black54,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      type['label'] as String,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          const Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Colors.black87,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Foto Bukti (Opsional)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (photoBytes != null)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                photoBytes!,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: () => setDialogState(() {
                                  selectedPhoto = null;
                                  photoBytes = null;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xAA000000),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else if (isPickingImage)
                        Container(
                          height: 100,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  color: Colors.black54,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Mengambil foto...',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: Material(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: capturePhoto,
                                  child: Container(
                                    height: 100,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.camera_alt_outlined,
                                          size: 32,
                                          color: Colors.black87,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Ambil Foto Kamera',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: Text(
                              'Batal',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: (selectedOrderType == null)
                                ? null
                                : () {
                                    Navigator.pop(dialogCtx);
                                    _markAsCompleted(
                                      order,
                                      photo: selectedPhoto,
                                      orderType: selectedOrderType,
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5D4037),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey[300],
                              disabledForegroundColor: Colors.grey[500],
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Ya, Selesai'),
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
      },
    );
  }

  Future<void> _deleteOrder(dynamic order) async {
    final confirm = await LinePopup.showConfirmChoice(
      context,
      title: 'Hapus Pesanan?',
      description:
          'Apakah Anda yakin ingin menghapus pesanan #${order['id']}?\n\nAksi ini akan membatalkan pesanan dan mengembalikan stok produk.',
      dismissText: 'Batal',
      affirmText: 'Ya, Hapus',
      affirmColor: Colors.red,
    );
    if (!confirm) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    final success = await _apiService.deleteTransaction(order['id']);

    if (!mounted) return;

    if (success) {
      PopupNotification.show(
        context,
        title: 'Berhasil',
        message:
            'Pesanan #${order['id']} telah dibatalkan dan stok dikembalikan.',
        type: PopupType.success,
      );
      _fetchActiveOrders();
    } else {
      PopupNotification.show(
        context,
        title: 'Gagal',
        message: 'Tidak dapat menghapus pesanan. Coba lagi.',
        type: PopupType.error,
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Active Orders',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _fetchActiveOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _activeOrders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Tidak ada pesanan aktif',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Pesanan baru akan muncul di sini',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                  SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _fetchActiveOrders,
                    icon: Icon(Icons.refresh),
                    label: Text('Perbarui'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _activeOrders.length,
              itemBuilder: (context, index) {
                final order = _activeOrders[index];
                final customerName = order['customer_name'] ?? 'Guest';
                final items = order['items'] as List;
                final status = order['kitchen_status'];

                return FadeSlideIn(
                  delay: Duration(milliseconds: 60 * index),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Order #${order['id']} - $customerName',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: status == 'pending'
                                      ? Colors.orange[100]
                                      : Colors.blue[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status.toString().toUpperCase(),
                                  style: TextStyle(
                                    color: status == 'pending'
                                        ? Colors.orange[800]
                                        : Colors.blue[800],
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (order['completion_photo'] != null &&
                              order['completion_photo'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Builder(
                                  builder: (context) {
                                    final String photoUrl = ApiService()
                                        .getImageUrl(order['completion_photo']);

                                    return Image.network(
                                      photoUrl,
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) =>
                                          Container(
                                            height: 150,
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.broken_image_outlined,
                                                  color: Colors.grey,
                                                  size: 32,
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Foto tidak tersedia',
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            '${items.length} Items:',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                '${item['quantity']}x ${item['product'] != null ? item['product']['name'] : 'Unknown'}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (item['notes'] != null &&
                                                item['notes']
                                                    .toString()
                                                    .contains(
                                                      '[PESANAN GRATIS]',
                                                    )) ...[
                                              SizedBox(width: 6),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green[100],
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'FREE',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green[800],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (item['notes'] != null &&
                                          item['notes'].toString().contains(
                                            '[PESANAN GRATIS]',
                                          ))
                                        Text(
                                          'Gratis',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      else
                                        Text(
                                          AppFormat.currency(
                                            item['subtotal'] ?? 0,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (item['notes'] != null &&
                                      item['notes'].toString().isNotEmpty &&
                                      item['notes']
                                          .toString()
                                          .replaceAll('[PESANAN GRATIS]', '')
                                          .replaceAll('|', '')
                                          .trim()
                                          .isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber[50],
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.amber[100]!,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.edit_note,
                                            size: 14,
                                            color: Colors.amber[800],
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              item['notes']
                                                  .toString()
                                                  .replaceAll(
                                                    RegExp(
                                                      r'\s*\|\s*\[PESANAN GRATIS\]|\[PESANAN GRATIS\]\s*\|\s*|\[PESANAN GRATIS\]',
                                                    ),
                                                    '',
                                                  )
                                                  .trim(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.amber[900],
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 24),
                          // Transaction Summary
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      AppFormat.currency(order['total']),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                if (order['amount_received'] != null &&
                                    (double.tryParse(
                                              order['amount_received']
                                                  .toString(),
                                            ) ??
                                            0) >
                                        0) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Uang Diterima',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        AppFormat.currency(
                                          double.tryParse(
                                                order['amount_received']
                                                    .toString(),
                                              ) ??
                                              0,
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Kembalian',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        AppFormat.currency(
                                          double.tryParse(
                                                order['change_amount']
                                                        ?.toString() ??
                                                    '0',
                                              ) ??
                                              0,
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Delete Order Button
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Hapus Pesanan',
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                  onPressed: () => _deleteOrder(order),
                                ),
                              ),

                              // Print Receipt Button for Owners
                              Consumer<AuthProvider>(
                                builder: (context, auth, _) {
                                  if (auth.can('print_receipt') &&
                                      status != 'pending') {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        right: 8.0,
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.print,
                                          size: 20,
                                          color: Colors.blue[600],
                                        ),
                                        tooltip: 'Cetak Struk',
                                        padding: EdgeInsets.zero,
                                        constraints: BoxConstraints(),
                                        onPressed: () async {
                                          if (await _printerService
                                              .isConnected) {
                                            try {
                                              await _printerService
                                                  .printReceipt(
                                                    transaction: order,
                                                    items: items,
                                                    isHistory: false,
                                                  );
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Mencetak struk pesanan...',
                                                  ),
                                                ),
                                              );
                                            } catch (e) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Gagal mencetak: $e',
                                                  ),
                                                ),
                                              );
                                            }
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
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
                                    );
                                  }
                                  return SizedBox.shrink();
                                },
                              ),

                              ElevatedButton.icon(
                                onPressed: () => _showCompletionDialog(order),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5D4037),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.camera_alt_outlined,
                                  size: 14,
                                ),
                                label: const Text(
                                  'Mark as Completed',
                                  style: TextStyle(fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ), // closes Container (inside FadeSlideIn)
                ); // closes FadeSlideIn
              },
            ),
    );
  }
}
