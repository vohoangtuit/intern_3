import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intern_3/presentation/bloc/language/language_cubit.dart';
import 'package:localizations/localizations.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.language),
            subtitle: Text(l10n.selectLanguage),
            trailing: const Icon(Icons.language),
            onTap: () => _showLanguageDialog(context),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.selectLanguage),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(l10n.english),
                onTap: () {
                  context.read<LanguageCubit>().changeLanguage('en');
                  Navigator.pop(context);
                },
                trailing: Localizations.localeOf(context).languageCode == 'en'
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
              ),
              ListTile(
                title: Text(l10n.vietnamese),
                onTap: () {
                  context.read<LanguageCubit>().changeLanguage('vi');
                  Navigator.pop(context);
                },
                trailing: Localizations.localeOf(context).languageCode == 'vi'
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}
