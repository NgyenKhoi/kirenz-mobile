import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/profile_repository.dart';
import '../../domain/entities/user_profile.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _bio = TextEditingController();
  final _location = TextEditingController();
  final _website = TextEditingController();
  UserProfile? _initial;
  DateTime? _birthDate;
  ProfileGender? _gender;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _displayName.dispose();
    _bio.dispose();
    _location.dispose();
    _website.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final initial = _initial;
    if (initial == null) return false;
    return _displayName.text.trim() != initial.displayName ||
        _nullable(_bio.text) != initial.bio ||
        _birthDate != initial.birthDate ||
        _gender != initial.gender ||
        _nullable(_location.text) != initial.location ||
        _nullable(_website.text) != initial.website;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider);
    return PopScope(
      canPop: !_hasChanges || _isSubmitting,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && !_isSubmitting && await _confirmDiscard()) {
          if (context.mounted) context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit profile'),
          leading: IconButton(
            tooltip: 'Close',
            onPressed: _isSubmitting ? null : _close,
            icon: const Icon(Icons.close),
          ),
        ),
        body: SafeArea(
          child: profile.when(
            data: (value) {
              _initialize(value);
              return _form();
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _LoadError(
              message: error.toString(),
              onRetry: () => ref.invalidate(currentUserProfileProvider),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      onChanged: () => setState(() {}),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextFormField(
            controller: _displayName,
            enabled: !_isSubmitting,
            textInputAction: TextInputAction.next,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Display name'),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Display name is required';
              if (text.length > 100) return 'Use 100 characters or fewer';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _bio,
            enabled: !_isSubmitting,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Bio'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _location,
            enabled: !_isSubmitting,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Location'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _website,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Website'),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return null;
              final uri = Uri.tryParse(text);
              if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                return 'Enter a complete URL, including https://';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ProfileGender?>(
            initialValue: _gender,
            decoration: const InputDecoration(labelText: 'Gender'),
            items: const [
              DropdownMenuItem(value: null, child: Text('Not specified')),
              DropdownMenuItem(value: ProfileGender.male, child: Text('Male')),
              DropdownMenuItem(
                value: ProfileGender.female,
                child: Text('Female'),
              ),
              DropdownMenuItem(
                value: ProfileGender.other,
                child: Text('Other'),
              ),
              DropdownMenuItem(
                value: ProfileGender.preferNotToSay,
                child: Text('Prefer not to say'),
              ),
            ],
            onChanged: _isSubmitting
                ? null
                : (value) => setState(() => _gender = value),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            title: const Text('Birth date'),
            subtitle: Text(
              _birthDate == null ? 'Not specified' : _formatDate(_birthDate!),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_birthDate != null)
                  IconButton(
                    tooltip: 'Clear birth date',
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(() => _birthDate = null),
                    icon: const Icon(Icons.clear),
                  ),
                const Icon(Icons.calendar_month_outlined),
              ],
            ),
            onTap: _isSubmitting ? null : _pickBirthDate,
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _isSubmitting || !_hasChanges ? null : _submit,
            child: _isSubmitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }

  void _initialize(UserProfile profile) {
    if (_initial != null) return;
    _initial = profile;
    _displayName.text = profile.displayName;
    _bio.text = profile.bio ?? '';
    _location.text = profile.location ?? '';
    _website.text = profile.website ?? '';
    _birthDate = profile.birthDate;
    _gender = profile.gender;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (selected != null) setState(() => _birthDate = selected);
  }

  Future<void> _close() async {
    if (!_hasChanges || await _confirmDiscard()) {
      if (mounted) context.pop();
    }
  }

  Future<bool> _confirmDiscard() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text('Your profile edits have not been saved.'),
            actions: [
              TextButton(
                onPressed: () => context.pop(false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => context.pop(true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || !_hasChanges) return;
    setState(() => _isSubmitting = true);
    try {
      final updated = await ref
          .read(profileRepositoryProvider)
          .updateCurrentUser(
            ProfileUpdate(
              displayName: _displayName.text.trim(),
              bio: _nullable(_bio.text),
              birthDate: _birthDate,
              gender: _gender,
              location: _nullable(_location.text),
              website: _nullable(_website.text),
            ),
          );
      ref.read(currentUserProfileProvider.notifier).replace(updated);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

String? _nullable(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
