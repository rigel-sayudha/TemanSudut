import 'dart:developer' as developer;

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../utils/app_format.dart';
import 'printer_service.dart';

PrinterService getPrinterService() => PrinterServiceMobile();

class PrinterServiceMobile implements PrinterService {
  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  @override
  Future<bool> get isConnected async {
    return (await bluetooth.isConnected) ?? false;
  }

  @override
  Future<List<dynamic>> getBondedDevices() async {
    return await bluetooth.getBondedDevices();
  }

  @override
  Future<void> connect(dynamic device) async {
    await bluetooth.connect(device);
  }

  @override
  Future<void> disconnect() async {
    await bluetooth.disconnect();
  }

  @override
  Stream<int> onStateChanged() {
    return bluetooth.onStateChanged().map((state) => state as int);
  }

  @override
  Future<void> printTest() async {
    if (await isConnected) {
      bluetooth.printNewLine();
      bluetooth.printCustom("===== TES PRINTER =====", 1, 1);
      bluetooth.printNewLine();
      bluetooth.printCustom("Printer Berhasil Tersambung!", 1, 1);
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.paperCut();
    }
  }

  @override
  Future<void> downloadReceiptPdf(int transactionId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final url = Uri.parse(
      '${ApiService.baseUrl}/transactions/$transactionId/receipt?token=$token',
    );

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Future<void> printReceipt({
    required Map<String, dynamic> transaction,
    required List<dynamic> items,
    required bool isHistory,
  }) async {
    if (!(await isConnected)) {
      developer.log('Printer not connected');
      throw Exception('Printer not connected');
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    bytes += generator.text(
      's u d u t  k o p i.',
      styles: PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      'Jl. Contoh Alamat Resto No.123',
      styles: PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'Telp: 08123456789',
      styles: PosStyles(align: PosAlign.center),
    );
    bytes += generator.feed(1);
    bytes += generator.hr(ch: '=');

    // Meta Info
    bytes += generator.row([
      PosColumn(
        text: 'Tgl: ${transaction['created_at'].toString().substring(0, 10)}',
        width: 6,
      ),
      PosColumn(
        text: 'Jam: ${transaction['created_at'].toString().substring(11, 16)}',
        width: 6,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);
    String custName = transaction['customer_name'] ?? 'Guest';
    String tableNum = '-';
    if (custName.contains(' - Meja ')) {
      final parts = custName.split(' - Meja ');
      custName = parts[0];
      tableNum = parts[1];
    }

    bytes += generator.row([
      PosColumn(text: 'No: INV-${transaction['id']}', width: 6),
      PosColumn(
        text: 'Kasir: ${transaction['user']?['name'] ?? 'Staff'}',
        width: 6,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.text('Pelanggan: $custName');
    bytes += generator.text('Meja: $tableNum');

    bytes += generator.hr();

    // Items List
    for (var item in items) {
      String name = item['product']['name'];
      int qty = int.tryParse(item['quantity'].toString()) ?? 1;
      double price = double.tryParse(item['unit_price'].toString()) ?? 0;
      double subtotal =
          double.tryParse(item['subtotal'].toString()) ?? (price * qty);
      double extraCharge =
          double.tryParse(item['extra_charge']?.toString() ?? '0') ?? 0;

      bytes += generator.text(name, styles: PosStyles(bold: true));
      bytes += generator.row([
        PosColumn(text: '  $qty x ${AppFormat.currency(price)}', width: 7),
        PosColumn(
          text: AppFormat.currency(subtotal),
          width: 5,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);

      if (extraCharge > 0) {
        bytes += generator.row([
          PosColumn(
            text: '  + Extra: ${AppFormat.currency(extraCharge)}/item',
            width: 8,
          ),
          PosColumn(text: '', width: 4),
        ]);
      }
    }

    bytes += generator.hr();

    // Footer Totals
    double txSubtotal =
        double.tryParse(transaction['subtotal'].toString()) ?? 0;
    double txTax = double.tryParse(transaction['tax'].toString()) ?? 0;
    double txTotal = double.tryParse(transaction['total'].toString()) ?? 0;
    double txReceived =
        double.tryParse(transaction['amount_received']?.toString() ?? '') ??
        txTotal;
    double txChange =
        double.tryParse(transaction['change_amount']?.toString() ?? '') ?? 0;

    bytes += generator.row([
      PosColumn(text: 'Subtotal', width: 6),
      PosColumn(
        text: AppFormat.currency(txSubtotal),
        width: 6,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);
    if (txTax > 0) {
      bytes += generator.row([
        PosColumn(text: 'Pajak (PPN)', width: 6),
        PosColumn(
          text: AppFormat.currency(txTax),
          width: 6,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.row([
      PosColumn(
        text: 'TOTAL',
        width: 6,
        styles: PosStyles(
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      ),
      PosColumn(
        text: AppFormat.currency(txTotal),
        width: 6,
        styles: PosStyles(
          align: PosAlign.right,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      ),
    ]);

    bytes += generator.feed(1);
    bytes += generator.row([
      PosColumn(
        text:
            'Bayar (${transaction['payment_method'].toString().toUpperCase()})',
        width: 7,
      ),
      PosColumn(
        text: AppFormat.currency(txReceived),
        width: 5,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Kembali', width: 6),
      PosColumn(
        text: AppFormat.currency(txChange),
        width: 6,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += generator.feed(1);
    bytes += generator.hr(ch: '-');
    bytes += generator.text(
      'Terima Kasih Telah Berbelanja',
      styles: PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      isHistory ? '*** SALINAN (COPY) ***' : 'SUDUT KOPI POS SYSTEM',
      styles: PosStyles(align: PosAlign.center, fontType: PosFontType.fontB),
    );
    bytes += generator.feed(3);
    bytes += generator.cut();

    bluetooth.writeBytes(Uint8List.fromList(bytes));
  }
}
