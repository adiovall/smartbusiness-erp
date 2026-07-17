/// Supabase project credentials. The anon/publishable key is safe to
/// ship in client code — it has no special privileges on its own; all
/// real access control happens via Row Level Security policies on the
/// Supabase side (see the SQL run during setup). Never put the
/// service_role key here or anywhere in the app.
class SupabaseConfig {
  static const String url = 'https://jxhewfyrggjffvobnllm.supabase.co';
  static const String anonKey = 'sb_publishable_FkyVsQdvRGpEkIsT3VaxKg_uZqgikx5';
}