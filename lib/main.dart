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
  State<BLEImageTransfer> createState() => _BLEImageTransferState();
}

class _BLEImageTransferState extends State<BLEImageTransfer> {
  StreamSubscription? scanSubscription;
  BluetoothDevice? targetDevice;
  final String targetDeviceName = "ESP32_BLE_Image_Receiver";
  final String serviceUUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String characteristicUUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
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

    FlutterBluePlus.scanResults.listen((scanResult) async {
      if (targetCharacteristic != null) return;
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
    if (targetDevice != null) {
      await targetDevice?.disconnect();
      await targetDevice!.connect();
      int newMtu = await targetDevice!.requestMtu(517);
      debugPrint("Negotiated MTU: $newMtu");
      discoverServices();
    }
  }

  Future<void> discoverServices() async {
    if (targetDevice == null) return;
    List<BluetoothService> services = await targetDevice!.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid.toString() == serviceUUID) {
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (characteristic.uuid.toString() == characteristicUUID) {
            targetCharacteristic = characteristic;
            break;
          }
        }
      }
    }
  }

  Future<void> sendImage() async {
    try {
      ByteData data = await rootBundle.load('assets/fruite.png');
      Uint8List imageData = data.buffer.asUint8List();
      // Split data into chunks
      const int mtu = 20; // Check MTU size for your device/connection
      // const int mtu = 512; // Check MTU size for your device/connection
      int rounds = (imageData!.length / mtu).ceil();
      print("started transmit");
      print("started transmit");

      for (int i = 0; i < rounds; i++) {
        int start = i * mtu;
        int end = ((i + 1) * mtu < imageData!.length)
            ? (i + 1) * mtu
            : imageData!.length;
        print("start $start end $end current $i");
        await targetCharacteristic!
            .write(imageData!.sublist(start, end), timeout: 60);
      }
      print("end transmit");
      // Optionally, send an "end" message to signal transmission completion
      await targetCharacteristic?.write(Uint8List.fromList([101, 110, 100]),
          withoutResponse: false, timeout: 60); // Sends "end" as ASCII

      debugPrint("Image successfully sent!");
    } on Exception catch (e) {
      debugPrint("error get.. ${e.toString()}");
      // TODO
    }
    debugPrint("the end!");
  }
  // Future<void> sendImage() async {
  //   try {
  //     ByteData data = await rootBundle.load('assets/fruite.png');
  //     Uint8List imageData = data.buffer.asUint8List();
  //     const int chunkSize = 512; // Adjust according to negotiated MTU
  //     int offset = 0;
  //     debugPrint("Image data : ${imageData.length} ${imageData}..........");

  //     while (offset < imageData.length) {
  //       int end = (offset + chunkSize < imageData.length)
  //           ? offset + chunkSize
  //           : imageData.length;
  //       Uint8List chunk = imageData.sublist(offset, end);
  //       await targetCharacteristic?.write(chunk, withoutResponse: false);
  //       offset += chunkSize;
  //     }

  //     // Optionally, send an "end" message to signal transmission completion
  //     await targetCharacteristic?.write(Uint8List.fromList([101, 110, 100]),
  //         withoutResponse: false); // Sends "end" as ASCII

  //     debugPrint("Image successfully sent!");
  //   } on Exception catch (e) {
  //     debugPrint("error get.. ${e.toString()}");
  //     // TODO
  //   }
  //   debugPrint("the end!");
  // }

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
