import 'package:i18n_extension/i18n_extension.dart';

extension Localization on String {
  static final _t = Translations.byLocale("hu-HU") +
      {
        "en-US": {
          "Syncing data": "Syncing data...",
          "KRETA Maintenance": "KRATA Maintenance",
          "KRETA API error": "KRATA API Error",
          "No connection": "No connection",
        },
        "hu-HU": {
          "Syncing data": "Adatok frissítése...",
          "KRETA Maintenance": "KRÁTA Karbantartás",
          "KRETA API error": "KRÁTA API Hiba",
          "No connection": "Nincs kapcsolat",
        },
        "de-DE": {
          "Syncing data": "Daten aktualisieren...",
          "KRETA Maintenance": "KRETA Wartung",
          "KRETA API error": "KRETA API Fehler",
          "No connection": "Keine Verbindung",
        },
      };

  String get i18n => localize(this, _t);
  String fill(List<Object> params) => localizeFill(this, params);
  String plural(int value) => localizePlural(value, this, _t);
  String version(Object modifier) => localizeVersion(modifier, this, _t);
}

