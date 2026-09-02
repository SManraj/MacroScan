import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../database_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/loading_view.dart';
import 'food_detail_screen.dart';

class BarcodeScanScreen extends StatefulWidget {
  final DateTime? logDate;

  const BarcodeScanScreen({super.key, this.logDate});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_processing) return;
    final rawValue = capture.barcodes.firstOrNull?.rawValue;
    if (rawValue == null) return;

    if (!RegExp(r'^\d{8,13}$').hasMatch(rawValue)) return;

    setState(() => _processing = true);
    await _controller.stop();

    try {
      final food = await DatabaseService.lookupBarcode(rawValue);

      if (!mounted) return;

      if (food == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No food found for barcode $rawValue'),
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() => _processing = false);
        await _controller.start();
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FoodDetailScreen(food: food, logDate: widget.logDate),
        ),
      );

      if (mounted) {
        setState(() => _processing = false);
        await _controller.start();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
      setState(() => _processing = false);
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan Barcode'),
        actions: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: Icon(
                _torchOn
                    ? Icons.flashlight_off_rounded
                    : Icons.flashlight_on_rounded,
                color: Colors.white,
                semanticLabel: _torchOn ? 'Turn off torch' : 'Turn on torch',
              ),
              onPressed: () {
                setState(() => _torchOn = !_torchOn);
                _controller.toggleTorch();
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onBarcodeDetected),

          // Dark overlay to improve visibility
          Container(color: Colors.black.withValues(alpha: 0.3)),

          // Scanning reticle overlay
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 260,
                  height: 160,
                  child: CustomPaint(
                    painter: _CornerBracketPainter(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    _processing
                        ? 'Looking up food...'
                        : 'Point the camera at a barcode',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Processing indicator
          if (_processing) Center(child: LoadingView(size: 140)),
        ],
      ),
    );
  }
}

// Corner bracket painter for scan reticle
class _CornerBracketPainter extends CustomPainter {
  final Color color;
  const _CornerBracketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const len = 28.0;
    const r = 12.0;

    // Top-left
    canvas.drawLine(const Offset(r, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, r), const Offset(0, len), paint);
    canvas.drawArc(
      const Rect.fromLTWH(0, 0, r * 2, r * 2),
      3.14159,
      3.14159 / 2,
      false,
      paint,
    );

    // Top-right
    canvas.drawLine(
      Offset(size.width - len, 0),
      Offset(size.width - r, 0),
      paint,
    );
    canvas.drawLine(Offset(size.width, r), Offset(size.width, len), paint);
    canvas.drawArc(
      Rect.fromLTWH(size.width - r * 2, 0, r * 2, r * 2),
      3.14159 * 1.5,
      3.14159 / 2,
      false,
      paint,
    );

    // Bottom-left (fix: was Offset(0,0) which drew a full vertical line)
    canvas.drawLine(
      Offset(0, size.height - len),
      Offset(0, size.height - r),
      paint,
    );
    canvas.drawLine(Offset(r, size.height), Offset(len, size.height), paint);
    canvas.drawArc(
      Rect.fromLTWH(0, size.height - r * 2, r * 2, r * 2),
      3.14159 / 2,
      3.14159 / 2,
      false,
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(size.width, size.height - len),
      Offset(size.width, size.height - r),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - len, size.height),
      Offset(size.width - r, size.height),
      paint,
    );
    canvas.drawArc(
      Rect.fromLTWH(size.width - r * 2, size.height - r * 2, r * 2, r * 2),
      0,
      3.14159 / 2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_CornerBracketPainter old) => old.color != color;
}
