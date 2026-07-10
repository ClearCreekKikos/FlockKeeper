import 'package:flutter/services.dart';

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Handle backspace when a formatting character is deleted
    if (newValue.text.length < oldValue.text.length) {
      final oldDigits = oldValue.text.replaceAll(RegExp(r'\D'), '');
      final newDigits = newValue.text.replaceAll(RegExp(r'\D'), '');
      
      if (oldDigits.length == newDigits.length && oldDigits.isNotEmpty) {
        final updatedDigits = oldDigits.substring(0, oldDigits.length - 1);
        final formatted = _format(updatedDigits);
        return TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }

    final digits = text.replaceAll(RegExp(r'\D'), '');
    final formatted = _format(digits);
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _format(String digits) {
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 3) buffer.write(')');
      if (i == 6) buffer.write('-');
      if (i >= 10) break; // Limit to 10 digits
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
