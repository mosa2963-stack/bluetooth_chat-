import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

void main() => runApp(const TeemXApp());

class TeemXApp extends StatelessWidget {
  const TeemXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Teem X',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const BluetoothChatScreen(),
    );
  }
}

class BluetoothChatScreen extends StatefulWidget {
  const BluetoothChatScreen({super.key});

  @override
  State<BluetoothChatScreen> createState() => _BluetoothChatScreenState();
}

class _BluetoothChatScreenState extends State<BluetoothChatScreen> {
  BluetoothConnection? connection;
  List<BluetoothDevice> devicesList = [];
  BluetoothDevice? selectedDevice;
  bool isConnected = false;
  
  final TextEditingController _textController = TextEditingController();
  final List<Map<String, String>> _messages = [];

  @override
  void initState() {
    super.initState();
    _getBondedDevices();
  }

  Future<void> _getBondedDevices() async {
    List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
    setState(() {
      devicesList = devices;
    });
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      BluetoothConnection conn = await BluetoothConnection.toAddress(device.address);
      setState(() {
        connection = conn;
        isConnected = true;
        selectedDevice = device;
      });

      connection!.input!.listen((Uint8List data) {
        setState(() {
          _messages.add({
            'sender': device.name ?? 'جهاز آخر',
            'text': utf8.decode(data),
          });
        });
      }).onDone(() {
        setState(() {
          isConnected = false;
        });
      });
    } catch (e) {
      print('فشل الاتصال: $e');
    }
  }

  void _sendMessage() async {
    String text = _textController.text.trim();
    if (text.isNotEmpty && connection != null && connection!.isConnected) {
      _textController.clear();
      connection!.output.add(Uint8List.fromList(utf8.encode(text)));
      await connection!.output.allSent;

      setState(() {
        _messages.add({
          'sender': 'أنا',
          'text': text,
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isConnected ? 'Teem X - محادثة مع: ${selectedDevice?.name}' : 'Teem X Bluetooth Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getBondedDevices,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!isConnected) ...[
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text(
                'اختر جهازاً مقترناً للاتصال عبر Teem X:', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: devicesList.length,
                itemBuilder: (context, index) {
                  final device = devicesList[index];
                  return ListTile(
                    leading: const Icon(Icons.bluetooth),
                    title: Text(device.name ?? 'جهاز غير معروف'),
                    subtitle: Text(device.address),
                    trailing: ElevatedButton(
                      child: const Text('اتصال'),
                      onPressed: () => _connectToDevice(device),
                    ),
                  );
                },
              ),
            ),
          ],
          if (isConnected) ...[
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  bool isMe = msg['sender'] == 'أنا';
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.indigo : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${msg['text']}',
                        style: TextStyle(color: isMe ? Colors.white : Colors.black),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالتك هنا...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.indigo),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
