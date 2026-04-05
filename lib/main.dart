import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A list of options for each app setting
const List<String> _dateFormats = <String>[
  'MM/DD/YYYY',
  'DD/MM/YYYY',
  'YYYY-MM-DD',
];

const List<String> _timeFormats = <String>[
  '12 hr',
  '24 hr',
];

const List<String> _currencySymbols = <String>[
  r'$', // r (raw string) escapes the dollar sign
  '€',
  '£',
  '¥',
  '₹',
  '₩',
  '₱',
  '₽',
  '฿',
  '₫',
  '₴',
  '₦',
  '₪',
];

void main() {
  runApp(const MyApp());
}

class AppSettings {
  const AppSettings({
    required this.dateFormat,
    required this.timeFormat,
    required this.currencySymbol,
  });

  final String dateFormat;
  final String timeFormat;
  final String currencySymbol;

  static const AppSettings fallback = AppSettings(
    dateFormat: 'MM/DD/YYYY',
    timeFormat: '12 hr',
    currencySymbol: r'$',
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Work Hours Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _dateFormatKey = 'app_settings_date_format';
  static const String _timeFormatKey = 'app_settings_time_format';
  static const String _currencySymbolKey = 'app_settings_currency_symbol';
  static const String _jobProfilesKey = 'job_profiles';

  bool _isLoading = true;
  bool _showSettingsAsHome = false;
  AppSettings _settings = AppSettings.fallback;
  List<String> _jobProfiles = <String>[];
  int? _selectedProfileIndex;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    AppSettings loadedSettings = AppSettings.fallback;
    List<String> loadedProfiles = <String>[];
    bool hasInitializedSettings = false;

    try {
      // Fetching app settings from shared preferences
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedDateFormat = prefs.getString(_dateFormatKey);
      final String? savedTimeFormat = prefs.getString(_timeFormatKey);
      final String? savedCurrencySymbol = prefs.getString(_currencySymbolKey);

      // True if all settings are non-null
      hasInitializedSettings =
          savedDateFormat != null &&
          savedTimeFormat != null &&
          savedCurrencySymbol != null;

      // Any setting this is null means settings were never saved or failed to load, so we fallback to defaults for that 
      // specific setting but still try to load others if available
      loadedSettings = AppSettings(
        dateFormat: savedDateFormat ?? AppSettings.fallback.dateFormat,
        timeFormat: savedTimeFormat ?? AppSettings.fallback.timeFormat,
        currencySymbol:
            savedCurrencySymbol ?? AppSettings.fallback.currencySymbol,
      );

      loadedProfiles = prefs.getStringList(_jobProfilesKey) ?? <String>[];
    } catch (_) {
      // If any error occurs during loading (e.g. data corruption), fallback to defaults
      loadedSettings = AppSettings.fallback;
      loadedProfiles = <String>[];
      hasInitializedSettings = false;
    }

    if (!mounted) {
      return;
    }
    // Update state with loaded settings and profiles. If settings were never initialized, show settings page as home, otherwise show main screen.
    setState(() {
      _settings = loadedSettings;
      _jobProfiles = loadedProfiles;
      _selectedProfileIndex = loadedProfiles.isEmpty ? null : 0;
      // User is taken to app settings on first launch or if settings failed to load, otherwise show main screen
      _showSettingsAsHome = !hasInitializedSettings;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings(AppSettings settings) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dateFormatKey, settings.dateFormat);
      await prefs.setString(_timeFormatKey, settings.timeFormat);
      await prefs.setString(_currencySymbolKey, settings.currencySymbol);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings could not be saved. Please try again.'),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    // Update settings in state and return to main screen if we were on the settings page as home
    setState(() {
      _settings = settings;
      _showSettingsAsHome = false;
    });
  }

  Future<void> _persistProfiles() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_jobProfilesKey, _jobProfiles);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job profiles could not be saved to local storage.'),
        ),
      );
    }
  }

  Future<void> _addJobProfile() async {
    final TextEditingController controller = TextEditingController();
    final String? profileName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create Job Profile'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Profile name'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final String trimmed = controller.text.trim();
                Navigator.of(context).pop(trimmed.isEmpty ? null : trimmed);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (profileName == null) {
      return;
    }

    setState(() {
      _jobProfiles = <String>[..._jobProfiles, profileName];
      _selectedProfileIndex = _jobProfiles.length - 1;
    });
    await _persistProfiles();
  }

  Future<void> _deleteProfile(int index) async {
    if (index < 0 || index >= _jobProfiles.length) {
      return;
    }

    setState(() {
      _jobProfiles.removeAt(index);
      if (_jobProfiles.isEmpty) {
        _selectedProfileIndex = null;
      } else if (_selectedProfileIndex == null ||
          _selectedProfileIndex! >= _jobProfiles.length) {
        _selectedProfileIndex = 0;
      }
    });
    await _persistProfiles();
  }
  // Opens the settings page and waits for it to pop with updated settings, then saves those settings if they are not null.
  Future<void> _openSettingsPage() async {
    final AppSettings? savedSettings = await Navigator.of(context).push<AppSettings>(
      MaterialPageRoute<AppSettings>(
        builder: (BuildContext context) => SettingsPage(
          initialSettings: _settings,
        ),
      ),
    );

    if (savedSettings == null) {
      return;
    }

    await _saveSettings(savedSettings);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_showSettingsAsHome) {
      return SettingsPage(
        initialSettings: _settings,
        onSavedInline: (AppSettings settings) async {
          await _saveSettings(settings);
        },
      );
    }

    final String selectedProfile = _selectedProfileIndex == null
        ? ''
        : _jobProfiles[_selectedProfileIndex!];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Hours Tracker'),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Job Profiles',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'App Settings',
                      onPressed: () {
                        Navigator.of(context).pop();
                        _openSettingsPage();
                      },
                      icon: const Icon(Icons.settings),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: _jobProfiles.length,
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                      selected: _selectedProfileIndex == index,
                      title: Text(_jobProfiles[index]),
                      onTap: () {
                        setState(() {
                          _selectedProfileIndex = index;
                        });
                        Navigator.of(context).pop();
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete profile',
                        onPressed: () => _deleteProfile(index),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add Job Profile'),
                onTap: () {
                  Navigator.of(context).pop();
                  _addJobProfile();
                },
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _jobProfiles.isEmpty
            ? const Center(
                child: Text(
                  'No job profiles yet. Open the sidebar to add one.',
                  textAlign: TextAlign.center,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Selected profile: $selectedProfile',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text('Date format: ${_settings.dateFormat}'),
                  Text('Time format: ${_settings.timeFormat}'),
                  Text('Currency symbol: ${_settings.currencySymbol}'),
                ],
              ),
      ),
    );
  }
}
// Separate page for editing app settings, which can be used both as a standalone page or as a home screen for first time users who haven't initialized settings yet.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.initialSettings,
    this.onSavedInline,
  });

  final AppSettings initialSettings;
  final Future<void> Function(AppSettings settings)? onSavedInline;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? _selectedDateFormat;
  String? _selectedTimeFormat;
  String? _selectedCurrency;

  @override
  void initState() {
    super.initState();
    _selectedDateFormat = widget.initialSettings.dateFormat;
    _selectedTimeFormat = widget.initialSettings.timeFormat;
    _selectedCurrency = widget.initialSettings.currencySymbol;
  }

  Future<void> _handleSave() async {
    final FormState? formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final AppSettings updated = AppSettings(
      dateFormat: _selectedDateFormat!,
      timeFormat: _selectedTimeFormat!,
      currencySymbol: _selectedCurrency!,
    );

    if (widget.onSavedInline != null) {
      await widget.onSavedInline!(updated);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved.')),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop<AppSettings>(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DropdownButtonFormField<String>(
                initialValue: _selectedDateFormat,
                decoration: const InputDecoration(
                  labelText: 'Date format',
                  border: OutlineInputBorder(),
                ),
                items: _dateFormats
                    .map(
                      (String format) => DropdownMenuItem<String>(
                        value: format,
                        child: Text(format),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedDateFormat = value;
                  });
                },
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a date format.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedTimeFormat,
                decoration: const InputDecoration(
                  labelText: 'Time format',
                  border: OutlineInputBorder(),
                ),
                items: _timeFormats
                    .map(
                      (String format) => DropdownMenuItem<String>(
                        value: format,
                        child: Text(format),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedTimeFormat = value;
                  });
                },
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a time format.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FormField<String>(
                initialValue: _selectedCurrency,
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a currency symbol.';
                  }
                  return null;
                },
                builder: (FormFieldState<String> field) {
                  return Autocomplete<String>(
                    initialValue:
                        TextEditingValue(text: field.value ?? ''),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      final String query = textEditingValue.text.trim();
                      if (query.isEmpty) {
                        return _currencySymbols;
                      }
                      return _currencySymbols.where((String symbol) {
                        return symbol.contains(query);
                      });
                    },
                    displayStringForOption: (String option) => option,
                    onSelected: (String selection) {
                      setState(() {
                        _selectedCurrency = selection;
                      });
                      field.didChange(selection);
                    },
                    fieldViewBuilder: (
                      BuildContext context,
                      TextEditingController textEditingController,
                      FocusNode focusNode,
                      VoidCallback onFieldSubmitted,
                    ) {
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Currency symbol',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: 'Show currency options',
                            onPressed: () {
                              FocusScope.of(context).requestFocus(focusNode);
                            },
                            icon: const Icon(Icons.arrow_drop_down),
                          ),
                        ),
                        onChanged: (String value) {
                          if (value != field.value) {
                            setState(() {
                              _selectedCurrency = null;
                            });
                            field.didChange(null);
                          }
                        },
                        onFieldSubmitted: (_) => onFieldSubmitted(),
                      );
                    },
                    optionsViewBuilder: (
                      BuildContext context,
                      AutocompleteOnSelected<String> onSelected,
                      Iterable<String> options,
                    ) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 220),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final String option = options.elementAt(index);
                                return ListTile(
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const Spacer(),
              FilledButton(
                onPressed: _handleSave,
                child: const Text('Save Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
