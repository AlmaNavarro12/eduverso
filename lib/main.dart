import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduVerso',
debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: const MyHomePage(title: 'EduVerso'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Offset> points = [];
  final GlobalKey key = GlobalKey();
  Sockets socket = Sockets();

  @override
  void initState() {
    super.initState();
    socket = Sockets();

    Future.delayed(const Duration(seconds: 5)).then(
      (_) => socket.clearCanvas().listen((event) {
        points.clear();
      }),
    );
  }

  void _addPointsForCurrentFrame(Offset globalPosition) {
  final RenderBox? renderBox = key.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox != null) {
    final Offset offset = renderBox.globalToLocal(globalPosition);
    socket.emitPaint(offset.dx, offset.dy);
  } else {
    final Offset? offset = renderBox?.globalToLocal(globalPosition);
    if (offset != null) {
      socket.emitPaint(offset.dx, offset.dy);
    }
  }
}


  void _finishLine() {
    socket.emitEndLine();
  }

  void _clearCanvas() {
    socket.emitClearCanvas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Container(
          key: key,
          color: Colors.grey[200],
          height: MediaQuery.of(context).size.height - 200,
          width: MediaQuery.of(context).size.width - 50,
          child: GestureDetector(
            onPanDown: (details) {
              _addPointsForCurrentFrame(details.globalPosition);
            },
            onPanUpdate: (details) {
              _addPointsForCurrentFrame(details.globalPosition);
            },
            onPanEnd: (_) {
              _finishLine();
            },
            child: StreamBuilder<Offset>(
              stream: socket.recivedPaint(),
              builder: (BuildContext context, AsyncSnapshot<Offset> snapshot) {
                if (snapshot.hasData) {
                  // Convertir Offset? a Offset, utilizando el operador '??' para proporcionar un valor predeterminado en caso de que sea nulo.
                  Offset offset = snapshot.data ?? Offset.zero;
                  points.add(offset);
                }

                return CustomPaint(
                  painter: Painter(offsets: points, drawColor: Colors.teal),
                );
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _clearCanvas,
        tooltip: 'Borrar',
        child: Icon(Icons.delete),
      ),
    );
  }
}

class Sockets {
  final socket = IO.io('https://render-server-kse7.onrender.com', <String, dynamic>{
    'transports': ['websocket'],
  });

  final _paintStreamController = StreamController<Offset>.broadcast();
  final _clearStreamController = StreamController<bool>.broadcast();

  bool isConnected = false;

  Sockets() {
    socket.onConnect((_) {
      isConnected = true;
    });
  }

  emitPaint(double dx, double dy) {
    if (isConnected) {
      socket.emit('canvas', '{"dx": $dx, "dy": $dy}');
    }
  }

  emitEndLine() {
    if (isConnected) {
      socket.emit('endLine');
    }
  }

  emitClearCanvas() {
    if (isConnected) {
      socket.emit('clearCanvas', '');
    }
  }

  Stream<Offset> recivedPaint() {
    if (isConnected) {
      socket.on('draw', (data) {
        final offset = jsonDecode(data);

        _paintStreamController.add(Offset(offset['dx'], offset['dy']));
      });

      socket.on('endLine', (data) => _paintStreamController.add(Offset.zero));
    }

    return _paintStreamController.stream;
  }

  Stream<bool> clearCanvas() {
    if (isConnected) {
      socket.on('cleaningCanvas', (_) {
        _clearStreamController.add(true);
      });
    }

    return _clearStreamController.stream;
  }
}

class Painter extends CustomPainter {
  final List<Offset> offsets;
  final Color drawColor;

  Painter({required this.offsets, required this.drawColor}) : super();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = drawColor
      ..isAntiAlias = true
      ..strokeWidth = 6.0;

    for (int i = 0; i < offsets.length; i++) {
      if (shouldDrawLine(i)) {
        canvas.drawLine(offsets[i], offsets[i + 1], paint);
      }
      if (shouldDrawPoint(i)) {
        canvas.drawPoints(PointMode.points, [offsets[i]], paint);
      }
    }
  }

  bool shouldDrawPoint(int i) => offsets[i] != null && offsets[i + 1] == null;

  bool shouldDrawLine(int i) => offsets[i] != null && offsets[i + 1] != null;

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
