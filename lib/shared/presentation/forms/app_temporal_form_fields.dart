import 'package:flutter/material.dart';

import 'package:mugen_ui/shared/presentation/admin/admin_components.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

class AppDateTimeFormField extends StatefulWidget {
  const AppDateTimeFormField({
    required this.labelText,
    required this.helpText,
    required this.value,
    required this.onChanged,
    super.key,
    this.hintText = 'Select a UTC date and time',
    this.helpKey,
    this.pickerButtonKey,
    this.clearButtonKey,
    this.required = false,
    this.enabled = true,
    this.readOnly = false,
    this.firstDate,
    this.lastDate,
    this.validator,
    this.diagnosticValue,
  }) : assert(helpText != '', 'helpText must not be blank.');

  final String labelText;
  final String helpText;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String? hintText;
  final Key? helpKey;
  final Key? pickerButtonKey;
  final Key? clearButtonKey;
  final bool required;
  final bool enabled;
  final bool readOnly;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final FormFieldValidator<DateTime>? validator;
  final String? diagnosticValue;

  @override
  State<AppDateTimeFormField> createState() => _AppDateTimeFormFieldState();
}

class _AppDateTimeFormFieldState extends State<AppDateTimeFormField> {
  final GlobalKey<FormFieldState<DateTime>> _formFieldKey =
      GlobalKey<FormFieldState<DateTime>>();
  bool _focused = false;

  bool get _interactive => widget.enabled && !widget.readOnly;

  @override
  void didUpdateWidget(covariant AppDateTimeFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final fieldState = _formFieldKey.currentState;
        if (fieldState != null && fieldState.value != widget.value) {
          fieldState.didChange(widget.value);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<DateTime>(
      key: _formFieldKey,
      initialValue: widget.value,
      validator: widget.validator,
      builder: (fieldState) {
        final value = fieldState.value?.toUtc();
        final diagnostic =
            _nonBlank(widget.diagnosticValue) ?? value?.toIso8601String();
        final content = value == null
            ? null
            : Text(
                _formatUtcDateTime(value),
                key: const Key('app-date-time-field-value'),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppUiPalette.textPrimary,
                ),
              );
        final decorator = InputDecorator(
          isEmpty: value == null,
          isFocused: _focused,
          decoration:
              appFormInputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                helpText: widget.helpText,
                helpKey: widget.helpKey,
                errorMaxLines: 4,
                suffixIcon: _TemporalActions(
                  pickerButtonKey: widget.pickerButtonKey,
                  clearButtonKey: widget.clearButtonKey,
                  pickerTooltip: 'Choose ${widget.labelText} in UTC',
                  pickerIcon: Icons.event_outlined,
                  onPick: _interactive ? () => _select(fieldState) : null,
                  onClear: _interactive && !widget.required && value != null
                      ? () => _update(fieldState, null)
                      : null,
                ),
              ).copyWith(
                errorText: fieldState.errorText,
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
          child: content,
        );
        return Semantics(
          button: _interactive,
          enabled: _interactive,
          label: '${widget.labelText}, UTC date and time selector',
          child: InkWell(
            onTap: _interactive ? () => _select(fieldState) : null,
            onFocusChange: (focused) => setState(() => _focused = focused),
            borderRadius: BorderRadius.circular(adminRadius),
            child: diagnostic == null
                ? decorator
                : Tooltip(message: diagnostic, child: decorator),
          ),
        );
      },
    );
  }

  Future<void> _select(FormFieldState<DateTime> fieldState) async {
    final now = DateTime.now().toUtc();
    final current = fieldState.value?.toUtc() ?? now;
    final first = _dateOnly(widget.firstDate ?? DateTime.utc(1));
    final last = _dateOnly(widget.lastDate ?? DateTime.utc(9999, 12, 31));
    final initialDate = _clampDate(_dateOnly(current), first, last);
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: first,
      lastDate: last,
      helpText: 'Choose ${widget.labelText} date (UTC)',
    );
    if (selectedDate == null || !mounted) {
      return;
    }

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: 'Choose ${widget.labelText} time (UTC)',
      builder: _forceTwentyFourHourTime,
    );
    if (selectedTime == null || !mounted) {
      return;
    }

    _update(
      fieldState,
      DateTime.utc(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      ),
    );
  }

  void _update(FormFieldState<DateTime> fieldState, DateTime? value) {
    fieldState.didChange(value);
    widget.onChanged(value);
  }
}

class AppTimeOfDayFormField extends StatefulWidget {
  const AppTimeOfDayFormField({
    required this.labelText,
    required this.helpText,
    required this.value,
    required this.onChanged,
    super.key,
    this.hintText = 'Select a time',
    this.helpKey,
    this.pickerButtonKey,
    this.clearButtonKey,
    this.required = false,
    this.enabled = true,
    this.readOnly = false,
    this.validator,
    this.diagnosticValue,
  }) : assert(helpText != '', 'helpText must not be blank.');

  final String labelText;
  final String helpText;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?> onChanged;
  final String? hintText;
  final Key? helpKey;
  final Key? pickerButtonKey;
  final Key? clearButtonKey;
  final bool required;
  final bool enabled;
  final bool readOnly;
  final FormFieldValidator<TimeOfDay>? validator;
  final String? diagnosticValue;

  @override
  State<AppTimeOfDayFormField> createState() => _AppTimeOfDayFormFieldState();
}

class _AppTimeOfDayFormFieldState extends State<AppTimeOfDayFormField> {
  final GlobalKey<FormFieldState<TimeOfDay>> _formFieldKey =
      GlobalKey<FormFieldState<TimeOfDay>>();
  bool _focused = false;

  bool get _interactive => widget.enabled && !widget.readOnly;

  @override
  void didUpdateWidget(covariant AppTimeOfDayFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final fieldState = _formFieldKey.currentState;
        if (fieldState != null && fieldState.value != widget.value) {
          fieldState.didChange(widget.value);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<TimeOfDay>(
      key: _formFieldKey,
      initialValue: widget.value,
      validator: widget.validator,
      builder: (fieldState) {
        final value = fieldState.value;
        final diagnostic =
            _nonBlank(widget.diagnosticValue) ??
            (value == null
                ? null
                : '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}:00');
        final content = value == null
            ? null
            : Text(
                _formatTime(value),
                key: const Key('app-time-of-day-field-value'),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppUiPalette.textPrimary,
                ),
              );
        final decorator = InputDecorator(
          isEmpty: value == null,
          isFocused: _focused,
          decoration:
              appFormInputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                helpText: widget.helpText,
                helpKey: widget.helpKey,
                errorMaxLines: 4,
                suffixIcon: _TemporalActions(
                  pickerButtonKey: widget.pickerButtonKey,
                  clearButtonKey: widget.clearButtonKey,
                  pickerTooltip: 'Choose ${widget.labelText}',
                  pickerIcon: Icons.schedule_outlined,
                  onPick: _interactive ? () => _select(fieldState) : null,
                  onClear: _interactive && !widget.required && value != null
                      ? () => _update(fieldState, null)
                      : null,
                ),
              ).copyWith(
                errorText: fieldState.errorText,
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
          child: content,
        );
        return Semantics(
          button: _interactive,
          enabled: _interactive,
          label: '${widget.labelText}, time selector',
          child: InkWell(
            onTap: _interactive ? () => _select(fieldState) : null,
            onFocusChange: (focused) => setState(() => _focused = focused),
            borderRadius: BorderRadius.circular(adminRadius),
            child: diagnostic == null
                ? decorator
                : Tooltip(message: diagnostic, child: decorator),
          ),
        );
      },
    );
  }

  Future<void> _select(FormFieldState<TimeOfDay> fieldState) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: fieldState.value ?? TimeOfDay.fromDateTime(DateTime.now()),
      helpText: 'Choose ${widget.labelText}',
      builder: _forceTwentyFourHourTime,
    );
    if (selected != null && mounted) {
      _update(fieldState, selected);
    }
  }

  void _update(FormFieldState<TimeOfDay> fieldState, TimeOfDay? value) {
    fieldState.didChange(value);
    widget.onChanged(value);
  }
}

class AppDateListFormField extends StatefulWidget {
  const AppDateListFormField({
    required this.labelText,
    required this.helpText,
    required this.values,
    required this.onChanged,
    super.key,
    this.hintText = 'Add one or more dates',
    this.helpKey,
    this.pickerButtonKey,
    this.clearButtonKey,
    this.required = false,
    this.enabled = true,
    this.readOnly = false,
    this.firstDate,
    this.lastDate,
    this.validator,
    this.diagnosticValue,
  }) : assert(helpText != '', 'helpText must not be blank.');

  final String labelText;
  final String helpText;
  final List<DateTime> values;
  final ValueChanged<List<DateTime>> onChanged;
  final String? hintText;
  final Key? helpKey;
  final Key? pickerButtonKey;
  final Key? clearButtonKey;
  final bool required;
  final bool enabled;
  final bool readOnly;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final FormFieldValidator<List<DateTime>>? validator;
  final String? diagnosticValue;

  @override
  State<AppDateListFormField> createState() => _AppDateListFormFieldState();
}

class _AppDateListFormFieldState extends State<AppDateListFormField> {
  final GlobalKey<FormFieldState<List<DateTime>>> _formFieldKey =
      GlobalKey<FormFieldState<List<DateTime>>>();
  bool _focused = false;

  bool get _interactive => widget.enabled && !widget.readOnly;

  @override
  void didUpdateWidget(covariant AppDateListFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldValues = _normalizedDates(oldWidget.values);
    final values = _normalizedDates(widget.values);
    if (!_sameDates(oldValues, values)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final fieldState = _formFieldKey.currentState;
        final current = _normalizedDates(
          fieldState?.value ?? const <DateTime>[],
        );
        if (fieldState != null && !_sameDates(current, values)) {
          fieldState.didChange(values);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<List<DateTime>>(
      key: _formFieldKey,
      initialValue: _normalizedDates(widget.values),
      validator: widget.validator,
      builder: (fieldState) {
        final values = _normalizedDates(fieldState.value ?? const <DateTime>[]);
        final diagnostic =
            _nonBlank(widget.diagnosticValue) ??
            (values.isEmpty ? null : values.map(_formatDate).join(', '));
        final content = values.isEmpty
            ? null
            : Wrap(
                key: const Key('app-date-list-field-values'),
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final value in values)
                    InputChip(
                      key: Key('app-date-list-chip-${_formatDate(value)}'),
                      label: Text(_formatDate(value)),
                      onDeleted:
                          _interactive &&
                              (!widget.required || values.length > 1)
                          ? () => _remove(fieldState, value)
                          : null,
                    ),
                ],
              );
        final decorator = InputDecorator(
          isEmpty: values.isEmpty,
          isFocused: _focused,
          decoration:
              appFormInputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                helpText: widget.helpText,
                helpKey: widget.helpKey,
                errorMaxLines: 4,
                suffixIcon: _TemporalActions(
                  pickerButtonKey: widget.pickerButtonKey,
                  clearButtonKey: widget.clearButtonKey,
                  pickerTooltip: 'Add ${widget.labelText} date',
                  pickerIcon: Icons.event_available_outlined,
                  onPick: _interactive ? () => _add(fieldState) : null,
                  onClear: _interactive && !widget.required && values.isNotEmpty
                      ? () => _update(fieldState, const <DateTime>[])
                      : null,
                ),
              ).copyWith(
                errorText: fieldState.errorText,
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
          child: content,
        );
        return Semantics(
          button: _interactive,
          enabled: _interactive,
          label: '${widget.labelText}, date list selector',
          child: InkWell(
            onTap: _interactive ? () => _add(fieldState) : null,
            onFocusChange: (focused) => setState(() => _focused = focused),
            borderRadius: BorderRadius.circular(adminRadius),
            child: diagnostic == null
                ? decorator
                : Tooltip(message: diagnostic, child: decorator),
          ),
        );
      },
    );
  }

  Future<void> _add(FormFieldState<List<DateTime>> fieldState) async {
    final values = _normalizedDates(fieldState.value ?? const <DateTime>[]);
    final first = _dateOnly(widget.firstDate ?? DateTime.utc(1));
    final last = _dateOnly(widget.lastDate ?? DateTime.utc(9999, 12, 31));
    final initial = _clampDate(
      values.isEmpty ? _dateOnly(DateTime.now().toUtc()) : values.last,
      first,
      last,
    );
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Add a ${widget.labelText} date',
    );
    if (selected == null || !mounted) {
      return;
    }
    _update(fieldState, <DateTime>[...values, _dateOnly(selected)]);
  }

  void _remove(FormFieldState<List<DateTime>> fieldState, DateTime value) {
    _update(
      fieldState,
      (fieldState.value ?? const <DateTime>[])
          .where((candidate) => !_sameDate(candidate, value))
          .toList(),
    );
  }

  void _update(
    FormFieldState<List<DateTime>> fieldState,
    List<DateTime> values,
  ) {
    final normalized = _normalizedDates(values);
    fieldState.didChange(normalized);
    widget.onChanged(normalized);
  }
}

class _TemporalActions extends StatelessWidget {
  const _TemporalActions({
    required this.pickerTooltip,
    required this.pickerIcon,
    required this.onPick,
    required this.onClear,
    this.pickerButtonKey,
    this.clearButtonKey,
  });

  final String pickerTooltip;
  final IconData pickerIcon;
  final VoidCallback? onPick;
  final VoidCallback? onClear;
  final Key? pickerButtonKey;
  final Key? clearButtonKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onClear != null)
          IconButton(
            key: clearButtonKey,
            tooltip: 'Clear selection',
            onPressed: onClear,
            icon: const Icon(Icons.clear),
          ),
        IconButton(
          key: pickerButtonKey,
          tooltip: pickerTooltip,
          onPressed: onPick,
          icon: Icon(pickerIcon),
        ),
      ],
    );
  }
}

Widget _forceTwentyFourHourTime(BuildContext context, Widget? child) {
  return MediaQuery(
    data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
    child: child ?? const SizedBox.shrink(),
  );
}

List<DateTime> _normalizedDates(Iterable<DateTime> values) {
  final byDate = <String, DateTime>{};
  for (final value in values) {
    final date = _dateOnly(value);
    byDate[_formatDate(date)] = date;
  }
  final result = byDate.values.toList()..sort();
  return List<DateTime>.unmodifiable(result);
}

DateTime _dateOnly(DateTime value) {
  return DateTime.utc(value.year, value.month, value.day);
}

DateTime _clampDate(DateTime value, DateTime first, DateTime last) {
  if (value.isBefore(first)) {
    return first;
  }
  if (value.isAfter(last)) {
    return last;
  }
  return value;
}

bool _sameDate(DateTime left, DateTime right) =>
    _formatDate(_dateOnly(left)) == _formatDate(_dateOnly(right));

bool _sameDates(List<DateTime> left, List<DateTime> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (!_sameDate(left[index], right[index])) {
      return false;
    }
  }
  return true;
}

String _formatUtcDateTime(DateTime value) {
  final utc = value.toUtc();
  return '${_formatDate(utc)} ${_twoDigits(utc.hour)}:${_twoDigits(utc.minute)} UTC';
}

String _formatDate(DateTime value) {
  final utc = value.toUtc();
  return '${utc.year.toString().padLeft(4, '0')}-${_twoDigits(utc.month)}-${_twoDigits(utc.day)}';
}

String _formatTime(TimeOfDay value) =>
    '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String? _nonBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
