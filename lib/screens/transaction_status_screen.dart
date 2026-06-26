import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class TransactionStatusScreen extends StatefulWidget {
  final bool isSuccess;
  final String message;
  final VoidCallback onDone;
  final Map<String, dynamic>? transactionData;

  const TransactionStatusScreen({
    Key? key,
    required this.isSuccess,
    required this.message,
    required this.onDone,
    this.transactionData,
  }) : super(key: key);

  @override
  State<TransactionStatusScreen> createState() => _TransactionStatusScreenState();
}

class _TransactionStatusScreenState extends State<TransactionStatusScreen> {
  final ScreenshotController screenshotController = ScreenshotController();
  bool _isSharing = false;

  Future<void> _shareReceipt() async {
    setState(() => _isSharing = true);
    try {
      final imageBytes = await screenshotController.capture(delay: const Duration(milliseconds: 10));
      if (imageBytes != null) {
        final directory = await getApplicationDocumentsDirectory();
        final imagePath = await File('${directory.path}/kainuwa_receipt.png').create();
        await imagePath.writeAsBytes(imageBytes);
        
        await Share.shareXFiles(
          [XFile(imagePath.path)], 
          text: 'Transaction Receipt from Kainuwa VTU'
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to share receipt')));
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black87),
              onPressed: widget.onDone,
            )
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // THE RECEIPT CARD (Wrapped in Screenshot)
                Screenshot(
                  controller: screenshotController,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('KAINUWA VTU', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF7351FF), letterSpacing: 2)),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: widget.isSuccess ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.isSuccess ? Icons.check_circle : Icons.cancel,
                            color: widget.isSuccess ? Colors.green : Colors.redAccent,
                            size: 60,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.isSuccess ? 'Transaction Successful' : 'Transaction Failed',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E1E1E)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        
                        // Dotted Line Separator
                        LayoutBuilder(
                          builder: (context, constraints) => Flex(
                            direction: Axis.horizontal,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(
                              (constraints.constrainWidth() / 8).floor(),
                              (index) => const SizedBox(width: 4, height: 1.5, child: DecoratedBox(decoration: BoxDecoration(color: Colors.grey))),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Transaction Details Map
                        if (widget.transactionData != null)
                          ...widget.transactionData!.entries.map((e) => _buildReceiptRow(e.key, e.value.toString())).toList(),
                          
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // ACTION BUTTONS (Not included in the screenshot)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSharing ? null : _shareReceipt,
                        icon: _isSharing 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                            : const Icon(Icons.share, color: Color(0xFF7351FF)),
                        label: const Text('Share', style: TextStyle(color: Color(0xFF7351FF), fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Color(0xFF7351FF), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: widget.onDone,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7351FF),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String title, String value) {
    // Highlight the Amount or Status
    final isHighlight = title.toLowerCase() == 'amount' || title.toLowerCase() == 'status';
    final isStatus = title.toLowerCase() == 'status';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              value, 
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isStatus 
                    ? (value.toLowerCase() == 'successful' ? Colors.green : Colors.red) 
                    : (isHighlight ? const Color(0xFF1E1E1E) : Colors.black87), 
                fontSize: isHighlight ? 16 : 14, 
                fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w600
              ),
            ),
          ),
        ],
      ),
    );
  }
}
