import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system; // Προεπιλογή στο θέμα συστήματος
  static const String _themePrefKey = 'themeMode';

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme(); // Φόρτωση θέματος κατά την αρχικοποίηση
  }

  // Φόρτωση αποθηκευμένης προτίμησης
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themePrefKey);
    if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system; // Προεπιλογή αν δεν υπάρχει ή είναι άκυρο
    }
    notifyListeners(); // Ενημέρωση widgets που ακούν
  }

  // Αλλαγή θέματος και αποθήκευση προτίμησης
  Future<void> setTheme(ThemeMode themeMode) async {
    if (_themeMode == themeMode) return; // Δεν αλλάζει αν είναι ήδη το ίδιο

    _themeMode = themeMode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    String themeString;
    switch (themeMode) {
      case ThemeMode.light:
        themeString = 'light';
        break;
      case ThemeMode.dark:
        themeString = 'dark';
        break;
      case ThemeMode.system:
      default:
         // Δεν αποθηκεύουμε το 'system' ρητά, το αφήνουμε null
         // ώστε να επιστρέψει στην προεπιλογή του συστήματος
         // ή μπορεί να αποθηκεύσουμε 'system' αν το θέλουμε
         await prefs.remove(_themePrefKey); 
         return; // Έξοδος για system
    }
     await prefs.setString(_themePrefKey, themeString);
  }

  // Συνάρτηση εναλλαγής (toggle)
  Future<void> toggleTheme() async {
     // Αν είναι system, πήγαινε σε light. Αλλιώς, κάνε εναλλαγή light/dark.
     // Αυτή είναι μια απλή λογική, μπορεί να προσαρμοστεί.
    if (_themeMode == ThemeMode.dark) {
      await setTheme(ThemeMode.light);
    } else {
      await setTheme(ThemeMode.dark); // Περιλαμβάνει και την περίπτωση του system -> dark
    }
  }
} 