import 'dart:async';
import 'dart:developer' as developer;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'printer_service.dart';

PrinterService getPrinterService() => PrinterServiceStub();

class MockBluetoothDevice {
  final String name;
  final String address;
  MockBluetoothDevice(this.name, this.address);
}

class PrinterServiceStub implements PrinterService {
  bool _connected = false;
  final StreamController<int> _stateController =
      StreamController<int>.broadcast();

  @override
  Future<bool> get isConnected async => _connected;

  @override
  Future<List<dynamic>> getBondedDevices() async {
    await Future.delayed(Duration(milliseconds: 500));
    return [
      MockBluetoothDevice('Web Mock Printer 1', '00:11:22:33:FF:EE'),
      MockBluetoothDevice('Web Mock Printer 2', 'AA:BB:CC:DD:EE:FF'),
    ];
  }

  @override
  Future<void> connect(dynamic device) async {
    await Future.delayed(Duration(seconds: 1));
    _connected = true;
    _stateController.add(1);
    developer.log('Mock: Connected to ${device.name}');
  }

  @override
  Future<void> disconnect() async {
    await Future.delayed(Duration(milliseconds: 500));
    _connected = false;
    _stateController.add(0);
    developer.log('Mock: Disconnected');
  }

  @override
  Stream<int> onStateChanged() => _stateController.stream;

  @override
  Future<void> printTest() async {
    if (_connected) {
      developer.log('Mock: ===== TES PRINTER =====');
      developer.log('Mock: Printer Berhasil Tersambung!');
      developer.log('Mock: Paper Cut');
    } else {
      throw Exception('Printer not connected');
    }
  }

  @override
  Future<void> printReceipt({
    required Map<String, dynamic> transaction,
    required List<dynamic> items,
    required bool isHistory,
  }) async {
    if (_connected) {
      developer.log(
        'Mock: Printing ${isHistory ? "History" : "New"} Receipt for Transaction ID: ${transaction['id']}',
      );
      developer.log('Mock: Items: ${items.length}');
      developer.log('Mock: Total: ${transaction['total']}');
      developer.log('Mock: Paper Cut');
    } else {
      throw Exception('Printer not connected');
    }
  }

  @override
  Future<void> downloadReceiptPdf(int transactionId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final url = Uri.parse(
      '${ApiService.baseUrl}/transactions/$transactionId/receipt?token=$token',
    );

    developer.log('Mock: Launching Receipt PDF URL: $url');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }
}
