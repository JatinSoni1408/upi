import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

const String kMerchantName = 'SHUBHAM JEWELLERS';
const String kMerchantTagline = 'SINCE 1996: TRUST & TRADITION';
const String kShopLogoAsset = 'assets/images/logo.png';
const String kUpiId = 'Q596211014@ybl';
const String kUpiQrBase =
    'upi://pay?mode=02&pa=$kUpiId&purpose=00&mc=0000&pn=PhonePeMerchant&orgid=180001';
const List<({String name, String imageUrl})> kAcceptedBrandLogos =
    <({String name, String imageUrl})>[
  (
    name: 'UPI',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6f/UPI_logo.svg/1280px-UPI_logo.svg.png',
  ),
  (
    name: 'GPay',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f2/Google_Pay_Logo.svg/960px-Google_Pay_Logo.svg.png',
  ),
  (
    name: 'PhonePe',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/71/PhonePe_Logo.svg/1280px-PhonePe_Logo.svg.png',
  ),
  (
    name: 'VISA',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5c/Visa_Inc._logo_%282021%E2%80%93present%29.svg/1280px-Visa_Inc._logo_%282021%E2%80%93present%29.svg.png',
  ),
];

String buildUpiQr(double? amount) {
  const note = 'QRTags Payment';
  final encodedNote = Uri.encodeComponent(note);
  if (amount == null) {
    return '$kUpiQrBase&tn=$encodedNote&cu=INR';
  }
  final normalized = amount.toStringAsFixed(2);
  return '$kUpiQrBase&am=$normalized&tn=$encodedNote&cu=INR';
}

void main() {
  runApp(const UpiApp());
}

class UpiApp extends StatelessWidget {
  const UpiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'upi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0C5DFF)),
      ),
      home: const UpiHomePage(),
    );
  }
}

class UpiHomePage extends StatefulWidget {
  const UpiHomePage({super.key});

  @override
  State<UpiHomePage> createState() => _UpiHomePageState();
}

class _UpiHomePageState extends State<UpiHomePage> {
  static const double _maxAmountPerQr = 100000;
  static const int _maxQrCount = 1;
  static const double _maxTotalAmount = _maxAmountPerQr;

  final TextEditingController _amountController = TextEditingController();
  List<double?> _amounts = const <double?>[null];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String _formatIndianInteger(String value) {
    if (value.isEmpty) {
      return value;
    }
    if (value.length <= 3) {
      return value;
    }
    final lastThree = value.substring(value.length - 3);
    String prefix = value.substring(0, value.length - 3);
    final groups = <String>[];
    while (prefix.length > 2) {
      groups.insert(0, prefix.substring(prefix.length - 2));
      prefix = prefix.substring(0, prefix.length - 2);
    }
    if (prefix.isNotEmpty) {
      groups.insert(0, prefix);
    }
    return '${groups.join(',')},$lastThree';
  }

  List<double> _splitAmounts(double amount) {
    if (!amount.isFinite || amount <= 0 || amount > _maxTotalAmount) {
      return const <double>[];
    }

    final chunks = <double>[];
    double remaining = double.parse(amount.toStringAsFixed(2));

    while (remaining > _maxAmountPerQr && chunks.length < _maxQrCount) {
      chunks.add(_maxAmountPerQr);
      remaining -= _maxAmountPerQr;
    }

    if (remaining > 0.0) {
      chunks.add(double.parse(remaining.toStringAsFixed(2)));
    }

    return chunks;
  }

  void _generateQrs({bool showErrors = true}) {
    FocusScope.of(context).unfocus();

    final rawValue = _amountController.text.trim().replaceAll(',', '');
    if (rawValue.isEmpty) {
      setState(() {
        _amounts = const <double?>[null];
      });
      return;
    }
    final amount = double.tryParse(rawValue);

    if (amount == null || !amount.isFinite || amount <= 0) {
      if (showErrors) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      }
      return;
    }

    if (amount > _maxTotalAmount) {
      if (showErrors) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Amount too large. Max allowed is ${_maxTotalAmount.toStringAsFixed(2)}',
            ),
          ),
        );
      }
      return;
    }

    final splits = _splitAmounts(amount);
    if (splits.isEmpty) {
      if (showErrors) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to generate QR right now.')),
        );
      }
      return;
    }

    setState(() {
      _amounts = splits.cast<double?>();
    });
  }

  Future<void> _showAmountSheet() async {
    FocusScope.of(context).unfocus();
    bool overLimit = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return PopScope(
              canPop: !overLimit,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _amountController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        _IndianCurrencyInputFormatter(_formatIndianInteger),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        hintText: 'Enter amount',
                        prefixIcon: const Icon(Icons.currency_rupee),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _amountController.clear();
                            if (overLimit) {
                              setSheetState(() {
                                overLimit = false;
                              });
                            }
                            _generateQrs(showErrors: false);
                          },
                          tooltip: 'Clear amount',
                        ),
                        border: const OutlineInputBorder(),
                        errorText: overLimit
                            ? 'Amount cannot be greater than 100000.00'
                            : null,
                      ),
                      onChanged: (_) {
                        final rawValue = _amountController.text
                            .trim()
                            .replaceAll(',', '');
                        final amount = double.tryParse(rawValue);
                        final nextOverLimit =
                            amount != null && amount > _maxTotalAmount;
                        if (nextOverLimit != overLimit) {
                          setSheetState(() {
                            overLimit = nextOverLimit;
                          });
                        }
                        _generateQrs(showErrors: false);
                      },
                      onSubmitted: (_) {
                        _generateQrs();
                        if (!overLimit) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Exit App'),
          content: const Text('Are you sure you want to exit?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
    return shouldExit ?? false;
  }

  Future<void> _onBackPressed(bool didPop) async {
    if (didPop) {
      return;
    }
    final shouldExit = await _confirmExit();
    if (shouldExit && mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildPendantQr(double? amount) {
    return _ScanPayStandeeCard(
      merchantName: kMerchantName,
      tagline: kMerchantTagline,
      shopLogoAsset: kShopLogoAsset,
      upiId: kUpiId,
      acceptedBrandLogos: kAcceptedBrandLogos,
      amount: amount,
      qrData: buildUpiQr(amount),
      onSettings: _showAmountSheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _onBackPressed(didPop),
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                for (int i = 0; i < _amounts.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildPendantQr(_amounts[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IndianCurrencyInputFormatter extends TextInputFormatter {
  _IndianCurrencyInputFormatter(this._formatIndianInteger);

  final String Function(String value) _formatIndianInteger;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(',', '');
    if (raw.isEmpty) {
      return newValue.copyWith(text: '');
    }
    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(raw)) {
      return oldValue;
    }

    final parts = raw.split('.');
    final integerPart = parts[0];
    final hasDot = raw.contains('.');
    final decimalPart = parts.length > 1 ? parts[1] : '';

    final formattedInteger = _formatIndianInteger(integerPart);
    final formatted = hasDot
        ? '$formattedInteger.$decimalPart'
        : formattedInteger;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ScanPayStandeeCard extends StatefulWidget {
  const _ScanPayStandeeCard({
    required this.merchantName,
    required this.tagline,
    required this.shopLogoAsset,
    required this.upiId,
    required this.qrData,
    required this.acceptedBrandLogos,
    required this.amount,
    required this.onSettings,
  });

  final String merchantName;
  final String tagline;
  final String shopLogoAsset;
  final String upiId;
  final String qrData;
  final List<({String name, String imageUrl})> acceptedBrandLogos;
  final double? amount;
  final VoidCallback onSettings;

  @override
  State<_ScanPayStandeeCard> createState() => _ScanPayStandeeCardState();
}

class _ScanPayStandeeCardState extends State<_ScanPayStandeeCard> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _isSharing = false;

  String _formatRupees(double value) => value.toStringAsFixed(2);

  Future<void> _precacheStandeeImages() async {
    try {
      await precacheImage(AssetImage(widget.shopLogoAsset), context);
    } catch (_) {}

    if (!mounted) {
      return;
    }

    for (final brand in widget.acceptedBrandLogos) {
      try {
        await precacheImage(NetworkImage(brand.imageUrl), context);
      } catch (_) {}

      if (!mounted) {
        return;
      }
    }
  }

  Future<void> _waitForBoundaryPaint(RenderRepaintBoundary boundary) async {
    for (int i = 0; i < 10 && boundary.debugNeedsPaint; i++) {
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  Future<void> _shareStandee() async {
    if (_isSharing) {
      return;
    }

    setState(() {
      _isSharing = true;
    });

	    try {
	      await _precacheStandeeImages();

        if (!mounted) {
          return;
        }

	      final pixelRatio =
	          math.min(View.of(context).devicePixelRatio * 2.0, 3.0);
	      final boundaryContext = _repaintKey.currentContext;
	      final boundary =
	          boundaryContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Standee not ready to share.');
      }
      await _waitForBoundaryPaint(boundary);

	      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
	      final ByteData? byteData =
	          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Failed to render image.');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final fileName =
          'upi_standee_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}$fileName',
      );
      await file.writeAsBytes(pngBytes, flush: true);

      await Share.shareXFiles(
        <XFile>[XFile(file.path)],
        text: widget.amount == null
            ? 'UPI ID: ${widget.upiId}'
            : 'UPI ID: ${widget.upiId}\nAmount: \u20B9${_formatRupees(widget.amount!)}',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not share right now. Try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: _repaintKey,
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: Card(
                  elevation: 4,
                  shadowColor: Colors.black.withValues(alpha: 0.12),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: const BorderSide(color: Color(0x11000000)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = constraints.maxWidth;
                      final cardHeight = constraints.maxHeight;

                          final qrBoxSize = math
                              .min(cardWidth * 0.74, cardHeight * 0.40)
                              .toDouble();
                          final qrPadding =
                              math.max(10.0, qrBoxSize * 0.06).toDouble();
                          final qrSize = qrBoxSize - (qrPadding * 2);

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 64,
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onLongPress: widget.onSettings,
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.settings,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                      Expanded(
                                        child: Center(
                                          child: ColorFiltered(
                                            colorFilter: const ColorFilter.mode(
                                              Colors.black,
                                              BlendMode.srcIn,
                                            ),
                                            child: Image.asset(
                                              widget.shopLogoAsset,
                                              fit: BoxFit.contain,
                                              filterQuality:
                                                  FilterQuality.high,
                                              cacheHeight: 128,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return const SizedBox.shrink();
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 48),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  widget.merchantName,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                    fontFamily: 'serif',
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                    color: onSurface,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.tagline,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: onSurface.withValues(alpha: 0.75),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox.square(
                                  dimension: qrBoxSize,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                        color: const Color(0xFF303030),
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(qrPadding),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          QrImageView(
                                            data: widget.qrData,
                                            size: qrSize,
                                            backgroundColor: Colors.white,
                                            errorCorrectionLevel:
                                                QrErrorCorrectLevel.H,
                                            eyeStyle: const QrEyeStyle(
                                              eyeShape: QrEyeShape.circle,
                                              color: Color(0xFF1E1E1E),
                                            ),
                                            dataModuleStyle:
                                                const QrDataModuleStyle(
                                              dataModuleShape:
                                                  QrDataModuleShape.circle,
                                              color: Color(0xFF1E1E1E),
                                            ),
                                            padding: EdgeInsets.zero,
                                          ),
                                          DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(5),
                                              child: Image.asset(
                                                kShopLogoAsset,
                                                width: 50,
                                                height: 50,
                                                fit: BoxFit.contain,
                                                filterQuality:
                                                    FilterQuality.high,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'SCAN & PAY',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.6,
                                    color: onSurface,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Accepted Here:',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: onSurface.withValues(alpha: 0.75),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    for (int i = 0;
                                        i <
                                            widget.acceptedBrandLogos.length;
                                        i++)
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            right: i ==
                                                    widget.acceptedBrandLogos
                                                            .length -
                                                        1
                                                ? 0
                                                : 10,
                                          ),
                                          child: _BrandLogo(
                                            label: widget
                                                .acceptedBrandLogos[i].name,
                                            imageUrl: widget
                                                .acceptedBrandLogos[i].imageUrl,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  widget.merchantName,
                                  textAlign: TextAlign.center,
                                  style:
                                      theme.textTheme.titleMedium?.copyWith(
                                    fontFamily: 'serif',
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: onSurface,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'UPI ID: ${widget.upiId}',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                    color: onSurface.withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  widget.amount == null
                                      ? 'Amount: Enter in app'
                                      : 'Amount: \u20B9${_formatRupees(widget.amount!)}',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: onSurface.withValues(alpha: 0.9),
                                  ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSharing ? null : _shareStandee,
                icon: const Icon(Icons.share),
                label: Text(_isSharing ? 'Preparing…' : 'Share'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.label, required this.imageUrl});

  final String label;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Semantics(
      label: label,
      image: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: onSurface.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 22),
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              cacheHeight: 44,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      color: onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                return Center(
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      color: onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
