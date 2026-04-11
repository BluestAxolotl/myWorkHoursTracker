import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'create_job_profile_page.dart';
import 'job_profile.dart';
import 'job_profile_database.dart';
import 'job_profile_details_page.dart';

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
// TODO: Add option for user to input custom currency symbol in case theirs is not in the list, and validate that input is not empty and does not contain whitespace. For now we just fallback to default currency if their desired currency is not in the list.
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
  static const String _jobProfileOrderKey = 'job_profile_order_v1';

  bool _isLoading = true;
  bool _showSettingsAsHome = false;
  AppSettings _settings = AppSettings.fallback;
  List<JobProfile> _jobProfiles = <JobProfile>[];
  int? _selectedProfileId;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    AppSettings loadedSettings = AppSettings.fallback;
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

      // Fill in settings that were able to be fatched, and fallback to defaults for any that were not
      loadedSettings = AppSettings(
        dateFormat: savedDateFormat ?? AppSettings.fallback.dateFormat,
        timeFormat: savedTimeFormat ?? AppSettings.fallback.timeFormat,
        currencySymbol:
            savedCurrencySymbol ?? AppSettings.fallback.currencySymbol,
      );
    } catch (_) {
      // If any error occurs during loading (e.g. data corruption), fallback to defaults
      loadedSettings = AppSettings.fallback;
      hasInitializedSettings = false;
    }

    List<JobProfile> loadedProfiles = <JobProfile>[];
    // Fetch job profiles from local database, if this fails show empty list of profiles
    try {
      loadedProfiles = await JobProfileDatabase.instance.getAllJobProfiles();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> savedOrderRaw =
          prefs.getStringList(_jobProfileOrderKey) ?? <String>[];
      final List<int> savedOrder = savedOrderRaw
          .map(int.tryParse)
          .whereType<int>()
          .toList();
      loadedProfiles = _applySavedProfileOrder(loadedProfiles, savedOrder);
    } catch (_) {
      // TODO: Surface error to user with option to retry loading profiles
      loadedProfiles = <JobProfile>[];
    }

    if (!mounted) {
      return;
    }
    // Update state with loaded settings and profiles. If settings were never initialized, show settings page as home, otherwise show main screen.
    setState(() {
      _settings = loadedSettings;
      _jobProfiles = loadedProfiles;
      _selectedProfileId = loadedProfiles.isEmpty ? null : loadedProfiles.first.id;
      // User is taken to app settings on first launch or if settings failed to load, otherwise show main screen
      _showSettingsAsHome = !hasInitializedSettings;
      _isLoading = false;
    });

    await _persistProfileOrder(loadedProfiles);
  }

  List<JobProfile> _applySavedProfileOrder(
    List<JobProfile> profiles,
    List<int> orderedIds,
  ) {
    if (profiles.isEmpty || orderedIds.isEmpty) {
      return profiles;
    }

    final Map<int, JobProfile> byId = <int, JobProfile>{
      for (final JobProfile profile in profiles)
        if (profile.id != null) profile.id!: profile,
    };

    final Set<int> seen = <int>{};
    final List<JobProfile> reordered = <JobProfile>[];

    for (final int id in orderedIds) {
      final JobProfile? profile = byId[id];
      if (profile != null) {
        reordered.add(profile);
        seen.add(id);
      }
    }

    for (final JobProfile profile in profiles) {
      final int? id = profile.id;
      if (id == null || !seen.contains(id)) {
        reordered.add(profile);
      }
    }

    return reordered;
  }

  Future<void> _persistProfileOrder(List<JobProfile> profiles) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> orderedIds = profiles
          .map((JobProfile profile) => profile.id)
          .whereType<int>()
          .map((int id) => id.toString())
          .toList();
      await prefs.setStringList(_jobProfileOrderKey, orderedIds);
    } catch (_) {
      // Best effort only; sidebar still works without persistence.
    }
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

  Future<void> _refreshProfilesFromDb() async {
    try {
      final List<JobProfile> profilesFromDb = await JobProfileDatabase.instance.getAllJobProfiles();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> savedOrderRaw =
          prefs.getStringList(_jobProfileOrderKey) ?? <String>[];
      final List<int> savedOrder = savedOrderRaw
          .map(int.tryParse)
          .whereType<int>()
          .toList();
      final List<JobProfile> profiles = _applySavedProfileOrder(
        profilesFromDb,
        savedOrder,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _jobProfiles = profiles;
        if (_jobProfiles.isEmpty) {
          _selectedProfileId = null;
          return;
        }
        final bool selectedExists = _jobProfiles.any((JobProfile p) => p.id == _selectedProfileId);
        if (!selectedExists) {
          _selectedProfileId = _jobProfiles.first.id;
        }
      });
      await _persistProfileOrder(profiles);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load job profiles from local database.'),
        ),
      );
    }
  }

  Future<void> _openCreateJobProfile() async {
    final JobProfile? created = await Navigator.of(context).push<JobProfile>(
      MaterialPageRoute<JobProfile>(
        builder: (BuildContext context) => const CreateJobProfilePage(),
      ),
    );

    if (created == null) {
      return;
    }

    await _refreshProfilesFromDb();

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedProfileId = created.id;
    });
  }

  Future<void> _deleteProfileById(int id) async {
    final int index = _jobProfiles.indexWhere((JobProfile profile) => profile.id == id);
    if (index == -1) {
      return;
    }

    try {
      await JobProfileDatabase.instance.deleteJobProfile(id);
      await _refreshProfilesFromDb();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete profile.')),
      );
    }
  }

  Future<void> _reorderSidebarProfiles(int oldIndex, int newIndex) async {
    final int targetIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (oldIndex == targetIndex ||
        oldIndex < 0 ||
        targetIndex < 0 ||
        oldIndex >= _jobProfiles.length ||
        targetIndex >= _jobProfiles.length) {
      return;
    }

    setState(() {
      final JobProfile moved = _jobProfiles.removeAt(oldIndex);
      _jobProfiles.insert(targetIndex, moved);
    });

    await _persistProfileOrder(_jobProfiles);
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

    final JobProfile? selectedProfile = _selectedProfileId == null
      ? null
      : _jobProfiles
          .where((JobProfile profile) => profile.id == _selectedProfileId)
          .cast<JobProfile?>()
          .firstOrNull;

    // Long form page title is job profile name but app name otherwise
    final String pageTitle = selectedProfile?.name ?? 'Work Hours Tracker';

    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitle),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
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
                    // Show drag to reorder hint if there are multiple profiles
                    if (_jobProfiles.length > 1)
                      const Padding(
                        padding: EdgeInsets.only(left: 2, top: 2),
                        child: Text(
                          'Drag profile rows to reorder',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: _jobProfiles.length,
                  onReorder: _reorderSidebarProfiles,
                  itemBuilder: (BuildContext context, int index) {
                    final JobProfile profile = _jobProfiles[index];
                    return ListTile(
                      key: ValueKey<int?>(profile.id),
                      selected: _selectedProfileId == profile.id,
                      title: Text(profile.name),
                      onTap: () {
                        setState(() {
                          _selectedProfileId = profile.id;
                        });
                        Navigator.of(context).pop();
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete profile',
                            onPressed: profile.id == null
                                ? null
                                : () => _deleteProfileById(profile.id!),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.drag_handle),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Create Job Profile'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openCreateJobProfile();
                },
              ),
            ],
          ),
        ),
      ),
      body: _jobProfiles.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No job profiles yet. Open the sidebar to add one.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : selectedProfile == null
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text('Select a job profile from the sidebar.'),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: JobProfileLongForm(profile: selectedProfile),
                ),
    );
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) {
      return null;
    }
    return first;
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
