import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts technical exceptions (Supabase Auth/Postgrest errors, plain
/// Exceptions, network failures) into short, non-technical messages —
/// safe to show directly to an Owner/Manager who has no reason to
/// understand terms like "PostgrestException" or a raw error code.
String friendlyError(Object error) {
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please verify your email before signing in. Check your inbox for the confirmation link.';
    }
    if (msg.contains('already registered')) {
      return 'An account with this email already exists.';
    }
    if (msg.contains('rate limit')) {
      return 'Too many attempts. Please wait a few minutes and try again.';
    }
    if (msg.contains('jwt') || msg.contains('token')) {
      return 'Your session has expired. Please sign in again.';
    }
    if (msg.contains('password')) {
      return 'Password must be at least 6 characters.';
    }
    return 'Could not complete this action. Please check your details and try again.';
  }

  if (error is PostgrestException) {
    final code = error.code;
    if (code == 'PGRST303') {
      return "There's a mismatch with your device's clock. Please make sure "
          "your computer's date and time are set automatically, then try again.";
    }
    if (code == '23505') return 'This already exists.';
    if (code == '42501') return "You don't have permission to do this.";
    return 'Could not reach the cloud right now. Please check your internet connection and try again.';
  }

  final text = error.toString();
  if (text.contains('SocketException') || text.contains('Failed host lookup') || text.contains('Connection')) {
    return 'No internet connection. Please check your network and try again.';
  }
  if (text.contains('TimeoutException')) {
    return 'The request took too long. Please check your internet connection and try again.';
  }

  // Our own thrown exceptions already use plain language
  // (e.g. "Enter a valid email") — just strip the prefix.
  if (text.startsWith('Exception: ')) {
    return text.substring('Exception: '.length);
  }

  return 'Something went wrong. Please try again.';
}