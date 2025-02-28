import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

import 'plural_rules.dart';
import 'translations.dart';

class Localization {
  Translations? _translations, _subTranslations, _fallbackTranslations, _subFallbackTranslations;
  late Locale _locale;
  late Locale _subLocale;

  final RegExp _replaceArgRegex = RegExp('{}');
  final RegExp _linkKeyMatcher = RegExp(r'(?:@(?:\.[a-z]+)?:(?:[\w\-_|.]+|\([\w\-_|.]+\)))');
  final RegExp _linkKeyPrefixMatcher = RegExp(r'^@(?:\.([a-z]+))?:');
  final RegExp _bracketsMatcher = RegExp('[()]');
  final _modifiers = <String, String Function(String?)>{
    'upper': (String? val) => val!.toUpperCase(),
    'lower': (String? val) => val!.toLowerCase(),
    'capitalize': (String? val) => '${val![0].toUpperCase()}${val.substring(1)}'
  };

  Localization();

  static Localization? _instance;
  static Localization get instance => _instance ?? (_instance = Localization());
  static Localization? of(BuildContext context) => Localizations.of<Localization>(context, Localization);

  static bool load(
    Locale locale,
    Locale? subLocale, {
    Translations? translations,
    Translations? subTranslations,
    Translations? fallbackTranslations,
    Translations? subFallbackTranslations,
  }) {
    instance._locale = locale;
    instance._translations = translations;
    instance._subTranslations = subTranslations;
    instance._fallbackTranslations = fallbackTranslations;
    instance._subFallbackTranslations = subFallbackTranslations;
    if (subLocale != null) {
      instance._subLocale = subLocale;
    }
    return translations == null ? false : true;
  }

  String tr(
    String key, {
    List<String>? args,
    Map<String, String>? namedArgs,
    String? gender,
  }) {
    late String res;

    if (gender != null) {
      res = _gender(key, gender: gender);
    } else {
      res = _resolve(key);
    }

    res = _replaceLinks(res);

    res = _replaceNamedArgs(res, namedArgs);

    return _replaceArgs(res, args);
  }

  String trSub(
    String key, {
    List<String>? args,
    Map<String, String>? namedArgs,
    String? gender,
  }) {
    late String res;

    if (gender != null) {
      res = _genderSub(key, gender: gender);
    } else {
      res = _resolveSub(key);
    }

    res = _replaceLinks(res);

    res = _replaceNamedArgs(res, namedArgs);

    return _replaceArgs(res, args);
  }

  String _replaceLinks(String res, {bool logging = true}) {
    // TODO: add recursion detection and a resolve stack.
    final matches = _linkKeyMatcher.allMatches(res);
    var result = res;

    for (final match in matches) {
      final link = match[0]!;
      final linkPrefixMatches = _linkKeyPrefixMatcher.allMatches(link);
      final linkPrefix = linkPrefixMatches.first[0]!;
      final formatterName = linkPrefixMatches.first[1];

      // Remove the leading @:, @.case: and the brackets
      final linkPlaceholder = link.replaceAll(linkPrefix, '').replaceAll(_bracketsMatcher, '');

      var translated = _resolve(linkPlaceholder);

      if (formatterName != null) {
        if (_modifiers.containsKey(formatterName)) {
          translated = _modifiers[formatterName]!(translated);
        } else {
          if (logging) {
            EasyLocalization.logger.warning('Undefined modifier $formatterName, available modifiers: ${_modifiers.keys.toString()}');
          }
        }
      }

      result = translated.isEmpty ? result : result.replaceAll(link, translated);
    }

    return result;
  }

  String _replaceArgs(String res, List<String>? args) {
    if (args == null || args.isEmpty) return res;
    for (var str in args) {
      res = res.replaceFirst(_replaceArgRegex, str);
    }
    return res;
  }

  String _replaceNamedArgs(String res, Map<String, String>? args) {
    if (args == null || args.isEmpty) return res;
    args.forEach((String key, String value) => res = res.replaceAll(RegExp('{$key}'), value));
    return res;
  }

  static PluralRule? _pluralRule(String? locale, num howMany) {
    startRuleEvaluation(howMany);
    return pluralRules[locale];
  }

  static PluralCase _pluralCaseFallback(num value) {
    switch (value) {
      case 0:
        return PluralCase.ZERO;
      case 1:
        return PluralCase.ONE;
      case 2:
        return PluralCase.TWO;
      default:
        return PluralCase.OTHER;
    }
  }

  String plural(
    String key,
    num value, {
    List<String>? args,
    Map<String, String>? namedArgs,
    String? name,
    NumberFormat? format,
  }) {
    late String res;

    final pluralRule = _pluralRule(_locale.languageCode, value);
    final pluralCase = pluralRule != null ? pluralRule() : _pluralCaseFallback(value);

    switch (pluralCase) {
      case PluralCase.ZERO:
        res = _resolvePlural(key, 'zero');
        break;
      case PluralCase.ONE:
        res = _resolvePlural(key, 'one');
        break;
      case PluralCase.TWO:
        res = _resolvePlural(key, 'two');
        break;
      case PluralCase.FEW:
        res = _resolvePlural(key, 'few');
        break;
      case PluralCase.MANY:
        res = _resolvePlural(key, 'many');
        break;
      case PluralCase.OTHER:
        res = _resolvePlural(key, 'other');
        break;
      default:
        throw ArgumentError.value(value, 'howMany', 'Invalid plural argument');
    }

    final formattedValue = format == null ? '$value' : format.format(value);

    if (name != null) {
      namedArgs = {...?namedArgs, name: formattedValue};
    }
    res = _replaceNamedArgs(res, namedArgs);

    return _replaceArgs(res, args ?? [formattedValue]);
  }

  String pluralSub(
    String key,
    num value, {
    List<String>? args,
    Map<String, String>? namedArgs,
    String? name,
    NumberFormat? format,
  }) {
    late String res;

    final pluralRule = _pluralRule(_subLocale.languageCode, value);
    final pluralCase = pluralRule != null ? pluralRule() : _pluralCaseFallback(value);

    switch (pluralCase) {
      case PluralCase.ZERO:
        res = _resolvePluralSub(key, 'zero');
        break;
      case PluralCase.ONE:
        res = _resolvePluralSub(key, 'one');
        break;
      case PluralCase.TWO:
        res = _resolvePluralSub(key, 'two');
        break;
      case PluralCase.FEW:
        res = _resolvePluralSub(key, 'few');
        break;
      case PluralCase.MANY:
        res = _resolvePluralSub(key, 'many');
        break;
      case PluralCase.OTHER:
        res = _resolvePluralSub(key, 'other');
        break;
      default:
        throw ArgumentError.value(value, 'howMany', 'Invalid plural argument');
    }

    final formattedValue = format == null ? '$value' : format.format(value);

    if (name != null) {
      namedArgs = {...?namedArgs, name: formattedValue};
    }
    res = _replaceNamedArgs(res, namedArgs);

    return _replaceArgs(res, args ?? [formattedValue]);
  }

  String _gender(String key, {required String gender}) {
    return _resolve('$key.$gender');
  }

  String _genderSub(String key, {required String gender}) {
    return _resolveSub('$key.$gender');
  }

  String _resolvePlural(String key, String subKey) {
    if (subKey == 'other') return _resolve('$key.other');

    final tag = '$key.$subKey';
    var resource = _resolve(tag, logging: false, fallback: _fallbackTranslations != null);
    if (resource == tag) {
      resource = _resolve('$key.other');
    }
    return resource;
  }

  String _resolvePluralSub(String key, String subKey) {
    if (subKey == 'other') return _resolve('$key.other');

    final tag = '$key.$subKey';
    var resource = _resolveSub(tag, logging: false, fallback: _subFallbackTranslations != null);
    if (resource == tag) {
      resource = _resolveSub('$key.other');
    }
    return resource;
  }

  String _resolve(String key, {bool logging = true, bool fallback = true}) {
    var resource = _translations?.get(key);
    if (resource == null) {
      if (logging) {
        EasyLocalization.logger.warning('Localization key [$key] not found');
      }
      if (_fallbackTranslations == null || !fallback) {
        return key;
      } else {
        resource = _fallbackTranslations?.get(key);
        if (resource == null) {
          if (logging) {
            EasyLocalization.logger.warning('Fallback localization key [$key] not found');
          }
          return key;
        }
      }
    }
    return resource;
  }

  String _resolveSub(String key, {bool logging = true, bool fallback = true}) {
    var resource = _subTranslations?.get(key);
    if (resource == null) {
      if (logging) {
        EasyLocalization.logger.warning('Localization key [$key] not found');
      }
      if (_subFallbackTranslations == null || !fallback) {
        return key;
      } else {
        resource = _subFallbackTranslations?.get(key);
        if (resource == null) {
          if (logging) {
            EasyLocalization.logger.warning('Fallback localization key [$key] not found');
          }
          return key;
        }
      }
    }
    return resource;
  }

  bool exists(String key) {
    return _translations?.get(key) != null;
  }

  bool existsSub(String key) {
    return _subTranslations?.get(key) != null;
  }
}
