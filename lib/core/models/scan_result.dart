class ScanResultData {
  final bool success;
  final String status;
  final String message;
  final Map<String, dynamic>? data;

  ScanResultData({
    required this.success,
    required this.status,
    required this.message,
    this.data,
  });

  factory ScanResultData.success(String message, Map<String, dynamic> data) {
    return ScanResultData(
      success: true,
      status: 'success',
      message: message,
      data: data,
    );
  }

  factory ScanResultData.warning(String message, [Map<String, dynamic>? data]) {
    return ScanResultData(
      success: false, // Not a complete success, requires attention
      status: 'warning',
      message: message,
      data: data,
    );
  }

  factory ScanResultData.error(String message) {
    return ScanResultData(
      success: false,
      status: 'error',
      message: message,
    );
  }
}
