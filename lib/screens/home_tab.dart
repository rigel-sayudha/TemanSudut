import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/cart_provider.dart';
import '../models/product.dart';
import '../utils/app_format.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/stock_alert_dialog.dart';
import '../widgets/line_popup.dart';
import '../widgets/popup_notification.dart';
import '../utils/app_animations.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: RefreshIndicator(
            color: const Color(0xFF5D4037),
            onRefresh: () => cart.refreshProducts(),
            child: CustomScrollView(
              slivers: [
                // Header Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 20.0,
                      right: 20.0,
                      top: 48,
                      bottom: 16,
                    ),
                    child: MediaQuery.of(context).size.width > 800
                        ? _buildTabletHeader(context, cart)
                        : _buildMobileHeader(context, cart),
                  ),
                ),

                // Categories Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 48,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            children: [
                              _buildCategoryItem(
                                'All',
                                cart.selectedCategory == null,
                                () => cart.filterByCategory(null),
                              ),
                              ...cart.categories.map((cat) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 10.0),
                                  child: _buildCategoryItem(
                                    cat.name,
                                    cart.selectedCategory?.id == cat.id,
                                    () => cart.filterByCategory(cat),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Products Section
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 8.0,
                  ),
                  sliver: cart.availableProducts.isEmpty
                      ? SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 40.0),
                              child: Column(
                                children: [
                                  _searchController.text.isNotEmpty
                                      ? Icon(
                                          Icons.search_off,
                                          size: 48,
                                          color: Colors.grey[300],
                                        )
                                      : CircularProgressIndicator(
                                          color: Colors.black,
                                        ),
                                  SizedBox(height: 16),
                                  Text(
                                    _searchController.text.isNotEmpty
                                        ? 'Produk tidak ditemukan'
                                        : 'Memuat produk...',
                                    style: TextStyle(color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent:
                                    155, // Diperkecil agar card tidak membesar berlebihan
                                childAspectRatio: 0.9,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 30,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final product = cart.availableProducts[index];
                            return FadeSlideIn(
                              delay: Duration(milliseconds: 40 * index),
                              child: _ProductCard(cart: cart, product: product),
                            );
                          }, childCount: cart.availableProducts.length),
                        ),
                ),

                SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryItem(String title, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: isSelected
              ? Border.all(color: Colors.orange, width: 1.5)
              : Border.all(color: Colors.transparent),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.orange : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  // We removed _buildProductCard because it is now replaced by _ProductCard class

  Widget _buildTabletHeader(BuildContext context, CartProvider cart) {
    return Row(
      children: [
        // Search Bar fills space
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products.....',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            cart.setSearchQuery('');
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() {});
                cart.setSearchQuery(value);
              },
            ),
          ),
        ),
        SizedBox(width: 16),
        // Sync icon
        IconButton(
          icon: Icon(Icons.sync, color: Colors.grey[600]),
          onPressed: () => cart.refreshProducts(),
        ),
        SizedBox(width: 8),
        // Webkul close shift / Select table simulation
        if (cart.isShiftOpen &&
            Provider.of<AuthProvider>(context, listen: false).can('open_shift'))
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              elevation: 0,
            ),
            onPressed: () => _showCloseShiftDialog(context, cart),
            child: Text(
              'Close Shift',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget _buildMobileHeader(BuildContext context, CartProvider cart) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'res/logo.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'TemanSudut',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            if (cart.isShiftOpen &&
                Provider.of<AuthProvider>(
                  context,
                  listen: false,
                ).can('open_shift'))
              InkWell(
                onTap: () => _showCloseShiftDialog(context, cart),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red[100]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: Colors.red[700],
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Tutup Kasir',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 20),
        // Persistent Search Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari produk favoritmu...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          cart.setSearchQuery('');
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
            ),
            onChanged: (value) {
              setState(() {});
              cart.setSearchQuery(value);
            },
          ),
        ),
      ],
    );
  }

  void _showCloseShiftDialog(BuildContext context, CartProvider cart) {
    final shift = cart.currentShift;
    double expectedCash =
        double.tryParse(shift?['current_cash']?.toString() ?? '0') ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final cashController = TextEditingController(
          text: expectedCash > 0 ? expectedCash.toInt().toString() : '',
        );
        bool isClosing = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return LinePopup(
              title: 'Tutup Sesi Kasir',
              description:
                  'Masukkan nominal uang akhir di laci kasir (setelah shift selesai).',
              icon: const Icon(
                Icons.lock_outline,
                size: 48,
                color: Colors.black87,
              ),
              content: TextField(
                controller: cashController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Uang Akhir (Opsional)',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF5D4037),
                      width: 2,
                    ),
                  ),
                ),
              ),
              actions: [
                LinePopupAction(
                  label: 'Batal',
                  style: LinePopupActionStyle.textNormal,
                  onTap: isClosing ? null : () => Navigator.pop(context),
                ),
                LinePopupAction(
                  label: isClosing ? 'Menutup...' : 'Tutup Kasir',
                  style: LinePopupActionStyle.filled,
                  onTap: isClosing
                      ? null
                      : () async {
                          setState(() => isClosing = true);
                          double amount =
                              double.tryParse(
                                cashController.text.replaceAll(',', ''),
                              ) ??
                              0;
                          bool success = await cart.closeShift(amount);
                          if (context.mounted) {
                            setState(() => isClosing = false);
                            if (success) {
                              Navigator.pop(context);
                              // Show stock alert after closing shift
                              showDialog(
                                context: context,
                                builder: (context) => const StockAlertDialog(
                                  title: 'Kasir Ditutup',
                                  message:
                                      'Shift telah berakhir. Silakan cek ringkasan stok terakhir:',
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Gagal menutup sesi kasir'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ProductCard extends StatefulWidget {
  final CartProvider cart;
  final Product product;

  const _ProductCard({required this.cart, required this.product});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.90,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await _controller.forward();
        await _controller.reverse();
        if (!mounted) return;

        widget.cart.addToCart(widget.product);
        ScaffoldMessenger.of(context).clearSnackBars();

        PopupNotification.show(
          context,
          title: 'Berhasil',
          message: '${widget.product.name} ditambahkan',
          type: PopupType.success,
          duration: const Duration(milliseconds: 1500),
        );
        _showFloatingPlusOne(context);
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnimation.value, child: child),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Main Card Container
            Positioned.fill(
              top: 38,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.grey[200]!),
                ),
                padding: EdgeInsets.fromLTRB(8, 58, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.product.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      AppFormat.currency(widget.product.price),
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Protruding Circular Image
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child:
                        widget.product.image != null &&
                            widget.product.image!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: ApiService().getImageUrl(
                              widget.product.image,
                            ),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(
                                color: Colors.orange,
                                strokeWidth: 2,
                              ),
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.broken_image_outlined,
                              size: 30,
                              color: Colors.black12,
                            ),
                          )
                        : Icon(Icons.fastfood, size: 36, color: Colors.black26),
                  ),
                ),
              ),
            ),

            // Stock Badge if low/empty
            if (widget.product.stock <= 5)
              Positioned(
                top: 48,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.product.stock == 0
                        ? Colors.red
                        : Colors.orange,
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(4),
                    ),
                  ),
                  child: Text(
                    widget.product.stock == 0
                        ? 'Habis'
                        : 'Sisa ${widget.product.stock}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showFloatingPlusOne(BuildContext context) {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _FloatingPlusOne(
        startPosition: Offset(
          position.dx + size.width / 2 - 15,
          position.dy + size.height / 2 - 15,
        ),
        onComplete: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _FloatingPlusOne extends StatefulWidget {
  final Offset startPosition;
  final VoidCallback onComplete;

  const _FloatingPlusOne({
    required this.startPosition,
    required this.onComplete,
  });

  @override
  State<_FloatingPlusOne> createState() => _FloatingPlusOneState();
}

class _FloatingPlusOneState extends State<_FloatingPlusOne>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _dy;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(_controller);

    _dy = Tween<double>(
      begin: widget.startPosition.dy,
      end: widget.startPosition.dy - 60,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: widget.startPosition.dx,
          top: _dy.value,
          child: Opacity(
            opacity: _opacity.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                '+1',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
