import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  _PrinterSettingsScreenState createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final PrinterService printerService = PrinterService();

  List<dynamic> _devices = [];
  dynamic _device;
  bool _connected = false;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    // Check if permissions are sufficient
    bool hasBlueprint =
        statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    bool hasScan = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    return (hasBlueprint && hasScan) ||
        statuses[Permission.bluetooth]?.isGranted == true ||
        statuses[Permission.location]?.isGranted == true;
  }

  Future<void> initPlatformState() async {
    if (kIsWeb) return;

    await _requestPermissions();

    try {
      bool isConnected = await printerService.isConnected;
      List<dynamic> devices = await printerService.getBondedDevices();

      printerService.onStateChanged().listen((state) {
        if (mounted) {
          if (state == 1) {
            setState(() => _connected = true);
          } else if (state == 0) {
            setState(() => _connected = false);
          }
        }
      });

      if (mounted) {
        setState(() {
          _devices = devices;
          _connected = isConnected;
        });
      }
    } catch (e) {
      developer.log("Error initializing printer: $e");
    }
  }

  Future<void> scanBluetooth() async {
    bool hasPermission = await _requestPermissions();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Akses Bluetooth/Lokasi ditolak. Mohon izinkan di Pengaturan Aplikasi.",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isScanning = true);
    await Future.delayed(Duration(seconds: 1));

    try {
      List<dynamic> devices = await printerService.getBondedDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
        });
      }
    } catch (e) {
      developer.log("Failed to get bluetooth devices: $e");
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  void _testPrint() async {
    if (await printerService.isConnected) {
      try {
        await printerService.printTest();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal mencetak: $e")));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Printer belum terhubung!"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildInfoBanner(),
          SizedBox(height: 16),
          _buildActionButtons(),
          Expanded(child: _buildDeviceList()),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.blue[700]),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cara Menghubungkan Printer',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Pastikan Bluetooth dan Lokasi aktif. Saat diminta Izin Akses (Allow), pastikan Anda memilih Ya/Menerima untuk menemukan printer.',
                    style: TextStyle(color: Colors.blue[800], fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: _isScanning
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(Icons.search, size: 18),
              label: Text(
                'SCAN BLUETOOTH',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2E8B57), // Green
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _isScanning ? null : scanBluetooth,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.preview_outlined, size: 18),
                    label: Text(
                      'PREVIEW',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Preview fitur dalam pengembangan"),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.print, size: 18),
                    label: Text(
                      'TES PRINTER',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4CAF50), // Lighter Green
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _testPrint,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bluetooth_disabled,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Tidak ada printer ditemukan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Pastikan printer dalam mode pairing dan Bluetooth aktif, lalu klik tombol SCAN.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        dynamic device = _devices[index];
        bool isThisDeviceConnected =
            _connected && _device?.address == device.address;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isThisDeviceConnected ? Colors.green : Colors.grey[200]!,
            ),
          ),
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              Icons.print,
              color: isThisDeviceConnected ? Colors.green : Colors.black87,
            ),
            title: Text(
              device.name ?? 'Unknown Device',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(device.address ?? ''),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isThisDeviceConnected
                    ? Colors.red[50]
                    : Colors.blue[50],
                foregroundColor: isThisDeviceConnected
                    ? Colors.red
                    : Colors.blue,
                elevation: 0,
              ),
              child: Text(isThisDeviceConnected ? 'Disconnect' : 'Connect'),
              onPressed: () async {
                if (isThisDeviceConnected) {
                  await printerService.disconnect();
                  setState(() => _device = null);
                } else {
                  try {
                    await printerService.connect(device);
                    setState(() => _device = device);
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
            ),
          ),
        );
      },
    );
  }
}
