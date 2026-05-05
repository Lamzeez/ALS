class Validators {
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegExp = RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+');
    if (!emailRegExp.hasMatch(value)) {
      return 'Invalid email address';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    // Basic phone validation: 10-12 digits
    final phoneRegExp = RegExp(r'^\+?[0-9]{10,12}$');
    if (!phoneRegExp.hasMatch(value)) {
      return 'Invalid phone number';
    }
    return null;
  }

  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    if (value.trim().split(' ').length < 2) {
      return 'Please enter your full name (First and Last name)';
    }
    return null;
  }

  static String? validateLearnerReferenceNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'LRN is required';
    }
    if (!RegExp(r'^[0-9]{12}$').hasMatch(value)) {
      return 'LRN must be exactly 12 digits';
    }
    return null;
  }
}
