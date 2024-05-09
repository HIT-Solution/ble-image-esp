import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MaterialApp(
      debugShowCheckedModeBanner: false, home: BLEImageTransfer()));
}

class BLEImageTransfer extends StatefulWidget {
  const BLEImageTransfer({super.key});

  @override
  _BLEImageTransferState createState() => _BLEImageTransferState();
}

class _BLEImageTransferState extends State<BLEImageTransfer> {
  StreamSubscription? scanSubscription;
  BluetoothDevice? targetDevice;
  BluetoothCharacteristic? targetCharacteristic;

  @override
  void initState() {
    super.initState();
    print("run 1");
    requestPermissions(); // Call this method here to request permissions on app start
  }

  Future<void> requestPermissions() async {
    try {
      print("run 2");
      await Permission.bluetooth.request();
      await Permission.location.request();
      print("run 3");
      startScan();
    } on Exception catch (e) {
      print("error $e");
    }
  }

  void startScan() {
    print("run 4");
    FlutterBluePlus.startScan(timeout: Duration(seconds: 5));

    scanSubscription = FlutterBluePlus.scanResults.listen((scanResult) async {
      print("run 5");
      for (ScanResult result in scanResult) {
        print("run 6");
        print("Found device: ${result.device.remoteId}");
        print("Found device: ${result.device.advName}");
        if (result.device.advName == 'ESP32_BLE_Image_Receiver') {
          // Adjust the name as needed
          await stopScan();
          targetDevice = result.device;
          connectToDevice();
        }
      }
    });
  }

  Future<void> stopScan() async {
    print("run 7");
    await scanSubscription?.cancel();
    scanSubscription = null;
    await FlutterBluePlus
        .stopScan(); // Ensure scanning is stopped before trying to connect
    print("run end ble");
  }

  Future<void> connectToDevice() async {
    try {
      if (targetDevice != null) {
        await targetDevice?.disconnect();
        await targetDevice!.connect();
        // Request a larger MTU size
        int newMtu =
            await targetDevice!.requestMtu(5000); // Requesting 517 as example
        print("Negotiated MTU: $newMtu");
        discoverServices();
      } else {
        print('not connnect for ');
      }
    } on Exception catch (e) {
      print('not connnect for $e');
      // TODO
    }
  }

  Future<void> discoverServices() async {
    print("run 11");
    if (targetDevice == null) return;

    print("run 12");
    List<BluetoothService> services = await targetDevice!.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid.toString() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
        // Adjust UUID
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (characteristic.uuid.toString() ==
              "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
            // Adjust UUID
            targetCharacteristic = characteristic;
            print("run 13");
          }
        }
      }
    }
  }

  Future<void> sendImage() async {
    // Load the image from assets
    print("run 14");
    ByteData data = await rootBundle.load('assets/fruite.png');
    print("run $data");
    Uint8List imageData = data.buffer.asUint8List();
    print("run 2 $imageData");

    // Chunk and send imageData
    await targetCharacteristic!.write(imageData.toList());
    const int chunkSize = 20;
    for (var i = 0; i < imageData.length; i += chunkSize) {
      int end =
          (i + chunkSize < imageData.length) ? i + chunkSize : imageData.length;
      print("run 66");
      print("run 77");
      await Future.delayed(const Duration(
          milliseconds:
              20)); // A small delay to prevent overwhelming the receiver
      print("run 78");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Image Transfer'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                requestPermissions();
              },
              child: Text('Refresh ble'),
            ),
            SizedBox(
              height: 100,
            ),
            ElevatedButton(
              onPressed: () {
                sendImage();
              },
              child: Text('Sending the image to ESP32'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    stopScan();
    targetDevice?.disconnect();
    super.dispose();
  }
}
