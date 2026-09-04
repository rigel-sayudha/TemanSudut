import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_animations.dart';

import 'home_tab.dart';
import 'orders_tab.dart';
import 'history_tab.dart';
import 'finance_tab.dart';
import 'profile_tab.dart';
import 'management_tab.dart';
import 'active_orders_tab.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/floating_bottom_nav.dart';
import '../widgets/line_popup.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/stock_alert_dialog.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  _MainNavScreenState createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _selectedIndex = 0;

  final _historyKey = GlobalKey<HistoryTabState>();
  final _activeOrdersKey = GlobalKey<ActiveOrdersTabState>();

  List<Widget> _pages = [];
  List<BottomNavigationBarItem> _navItems = [];
  List<FloatingNavItem> _floatingNavItems = [];

  bool _isSidebarMinimized = false;
  final TextEditingController _cashController = TextEditingController();
  bool _isOpeningShift = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _buildPagesForRole();
  }

  void _buildPagesForRole() {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final bool canHistory = auth.can('view_history');
    final bool canFinance = auth.can('view_finance');
    final bool canManagement =
        auth.can('manage_stock') ||
        auth.can('manage_employees') ||
        auth.can('manage_printer');

    _pages = [
      HomeTab(),
      if (canHistory)
        HistoryTab(
          key: _historyKey,
          onOrderActivated: () {
            _activeOrdersKey.currentState?.refreshOrders();
            int idx = _pages.indexWhere((p) => p is ActiveOrdersTab);
            if (idx != -1) _onItemTapped(idx);
          },
        ),
      ActiveOrdersTab(
        key: _activeOrdersKey,
        onNavigateToHistory: canHistory
            ? () {
                int idx = _pages.indexWhere((p) => p is HistoryTab);
                if (idx != -1) _onItemTapped(idx);
              }
            : null,
        onOrderCompleted: canHistory
            ? () {
                _historyKey.currentState?.refreshHistory();
                int idx = _pages.indexWhere((p) => p is HistoryTab);
                if (idx != -1) _onItemTapped(idx);
              }
            : null,
      ),
      if (canFinance) const FinanceTab(),
      if (canManagement) ManagementTab(),
      ProfileTab(),
    ];

    _navItems = [
      BottomNavigationBarItem(
        icon: Icon(Icons.storefront_outlined),
        activeIcon: Icon(Icons.storefront),
        label: 'Home',
      ),
      if (canHistory)
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_outlined),
          activeIcon: Icon(Icons.receipt_long),
          label: 'History',
        ),
      BottomNavigationBarItem(
        icon: Icon(Icons.list_alt),
        activeIcon: Icon(Icons.list),
        label: 'Orders',
      ),
      if (canFinance)
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet_outlined),
          activeIcon: Icon(Icons.account_balance_wallet),
          label: 'Keuangan',
        ),
      if (canManagement)
        BottomNavigationBarItem(
          icon: Icon(Icons.grid_view_outlined),
          activeIcon: Icon(Icons.grid_view),
          label: 'Management',
        ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];

    _floatingNavItems = [
      const FloatingNavItem(
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront,
        label: 'Home',
      ),
      if (canHistory)
        const FloatingNavItem(
          icon: Icons.receipt_long_outlined,
          activeIcon: Icons.receipt_long,
          label: 'History',
        ),
      const FloatingNavItem(
        icon: Icons.list_alt,
        activeIcon: Icons.list,
        label: 'Orders',
      ),
      if (canFinance)
        const FloatingNavItem(
          icon: Icons.account_balance_wallet_outlined,
          activeIcon: Icons.account_balance_wallet,
          label: 'Keuangan',
        ),
      if (canManagement)
        const FloatingNavItem(
          icon: Icons.grid_view_outlined,
          activeIcon: Icons.grid_view,
          label: 'Management',
        ),
      const FloatingNavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'Profile',
      ),
    ];

    if (_selectedIndex >= _pages.length) {
      _selectedIndex = 0;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    return await LinePopup.showConfirmChoice(
      context,
      title: 'Keluar Aplikasi?',
      description: 'Apakah Anda yakin ingin keluar dari aplikasi?',
      dismissText: 'Batal',
      affirmText: 'Keluar',
      affirmColor: Colors.red,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Consumer<CartProvider>(
        builder: (context, cart, child) {
          Widget mainContent = LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return _buildTabletLayout(context, cart);
              } else {
                return _buildMobileLayout(context, cart);
              }
            },
          );

          if (cart.isLoadingShift) {
            return Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: CircularProgressIndicator(
                  color: const Color(0xFF5D4037),
                ),
              ),
            );
          }

          return mainContent;
        },
      ),
    );
  }

  Widget _buildOpenShiftCard(BuildContext context, CartProvider cart) {
    return FadeSlideIn(
      delay: const Duration(milliseconds: 100),
      begin: const Offset(0, 0.25),
      child: Card(
        elevation: 20,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 380,
          padding: EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.point_of_sale_rounded,
                  size: 48,
                  color: Colors.blue[700],
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Buka Kasir',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Silakan masukkan modal awal (uang kembalian) untuk memulai shift.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  height: 1.5,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 32),
              TextField(
                controller: _cashController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Modal Awal',
                  prefixText: 'Rp ',
                  prefixStyle: TextStyle(
                    color: const Color(0xFF5D4037),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
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
                    borderSide: BorderSide(
                      color: const Color(0xFF5D4037),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5D4037),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isOpeningShift
                      ? null
                      : () async {
                          if (_cashController.text.isEmpty) return;
                          setState(() => _isOpeningShift = true);
                          double amount =
                              double.tryParse(
                                _cashController.text.replaceAll(',', ''),
                              ) ??
                              0;
                          bool success = await cart.openShift(amount);
                          if (mounted) {
                            setState(() => _isOpeningShift = false);
                            if (!success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Gagal membuka kasir. Coba lagi.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } else {
                              _cashController.clear();
                              showDialog(
                                context: context,
                                builder: (context) => const StockAlertDialog(
                                  title: 'Kasir Dibuka',
                                  message:
                                      'Shift telah dimulai. Berikut adalah ringkasan stok saat ini:',
                                ),
                              );
                            }
                          }
                        },
                  child: _isOpeningShift
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Buka Kasir',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ), // closes Column
        ), // closes Container
      ), // closes Card
    ); // closes FadeSlideIn
  }

  Widget _buildTabletSidebar(BuildContext context) {
    return Container(
      width: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF5D4037),
        border: Border(right: BorderSide(color: const Color(0xFF4E342E))),
      ),
      child: Column(
        children: [
          SizedBox(height: 24),
          // Logo
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              // shape: BoxShape.circle,
              // border: Border.all(color: Colors.white54, width: 2),
            ),
            child: ClipOval(
              child: Image.asset(
                'res/logo.png',
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'TemanSudut',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: -0.5,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 32),
          // Nav Items
          Expanded(
            child: ListView.builder(
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedIndex == index;
                final item = _navItems[index];
                return InkWell(
                  onTap: () => _onItemTapped(index),
                  hoverColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    decoration: isSelected
                        ? BoxDecoration(
                            border: Border.all(
                              color: Colors.white38,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white.withOpacity(0.15),
                          )
                        : null,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected
                              ? (item.activeIcon as Icon).icon
                              : (item.icon as Icon).icon,
                          color: isSelected ? Colors.white : Colors.white54,
                        ),
                        SizedBox(height: 8),
                        Text(
                          item.label ?? '',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white54,
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Settings / Logout at bottom
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                IconButton(
                  icon: Icon(Icons.logout, color: Colors.red[400]),
                  onPressed: () async {
                    bool confirm = await _onWillPop();
                    if (confirm) {
                      Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      ).logout();
                    }
                  },
                ),
                SizedBox(height: 8),
                Text(
                  'Logout',
                  style: TextStyle(color: Colors.white60, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context, CartProvider cart) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Row(
        children: [
          // 1. Sidebar Navigation
          _buildTabletSidebar(context),

          // 2. Main Content
          Expanded(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Stack(
                  children: [
                    AnimatedIndexedStack(
                      index: _selectedIndex,
                      children: _pages,
                    ),
                    if (!cart.isShiftOpen && _pages[_selectedIndex] is HomeTab)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.4),
                          child: Center(
                            child: _buildOpenShiftCard(context, cart),
                          ),
                        ),
                      ),
                    if (_isSidebarMinimized && cart.isShiftOpen)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.extended(
                          backgroundColor: const Color(0xFF5D4037),
                          foregroundColor: Colors.white,
                          onPressed: () =>
                              setState(() => _isSidebarMinimized = false),
                          icon: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(Icons.shopping_cart),
                              if (cart.items.isNotEmpty)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          label: Text(
                            'Cart (${cart.items.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Cart / Orders Right Sidebar
          if (!_isSidebarMinimized && cart.isShiftOpen)
            Container(
              width: MediaQuery.of(context).size.width * 0.35,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(left: BorderSide(color: Colors.grey[200]!)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(-5, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Minimize Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Keranjang (${cart.items.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_fullscreen),
                          tooltip: 'Minimize Cart',
                          onPressed: () =>
                              setState(() => _isSidebarMinimized = true),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: OrdersTab(
                      onOrderFinished: () => _onItemTapped(2),
                      onOrderSaved: () {
                        int idx = _pages.indexWhere((p) => p is HistoryTab);
                        if (idx != -1) {
                          _onItemTapped(idx);
                          _historyKey.currentState?.showSavedTab();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showCartBottomSheet(BuildContext context, CartProvider cart) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.of(sheetContext).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: OrdersTab(
              isBottomSheet: true,
              onOrderFinished: () {
                Navigator.pop(sheetContext); // Close bottom sheet
                int idx = _pages.indexWhere((p) => p is ActiveOrdersTab);
                if (idx != -1) _onItemTapped(idx);
              },
              onOrderSaved: () {
                Navigator.pop(sheetContext); // Close bottom sheet
                int idx = _pages.indexWhere((p) => p is HistoryTab);
                if (idx != -1) {
                  _onItemTapped(idx);
                  _historyKey.currentState?.showSavedTab();
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context, CartProvider cart) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      extendBody: true,
      drawer: CustomDrawer(),
      body: Stack(
        children: [
          SafeArea(
            child: AnimatedIndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
          ),
          if (!cart.isShiftOpen && _pages[_selectedIndex] is HomeTab)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: Center(child: _buildOpenShiftCard(context, cart)),
              ),
            ),
          if (cart.isShiftOpen && cart.items.isNotEmpty)
            Positioned(
              right: 16,
              bottom: 96,
              child: FloatingActionButton.extended(
                backgroundColor: const Color(0xFF5D4037),
                foregroundColor: Colors.white,
                onPressed: () => _showCartBottomSheet(context, cart),
                icon: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.shopping_cart),
                    if (cart.items.isNotEmpty)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                label: Text(
                  'Cart (${cart.items.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return FloatingBottomNav(
      currentIndex: _selectedIndex >= _floatingNavItems.length
          ? 0
          : _selectedIndex,
      items: _floatingNavItems,
      onTap: _onItemTapped,
    );
  }
}
