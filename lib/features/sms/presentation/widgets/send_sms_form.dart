import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/send_sms_input.dart';

class SendSmsForm extends StatefulWidget {
  const SendSmsForm({
    super.key,
    required this.isSending,
    required this.onSubmit,
  });

  final bool isSending;
  final ValueChanged<SendSmsInput> onSubmit;

  @override
  State<SendSmsForm> createState() => _SendSmsFormState();
}

class _SendSmsFormState extends State<SendSmsForm> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController(text: '+4915112345678');
  final _bodyController = TextEditingController(text: 'Your code is 123456');
  final _referenceController = TextEditingController(text: 'opt-1');

  @override
  void dispose() {
    _recipientController.dispose();
    _bodyController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Send SMS', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _recipientController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Recipient',
                  hintText: '+4915112345678',
                  helperText: 'Use E.164 format.',
                ),
                validator: _validateRecipient,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _bodyController,
                minLines: 3,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Message body',
                  alignLabelWithHint: true,
                ),
                validator: _validateBody,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _referenceController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Reference ID',
                  helperText: 'Optional idempotency/reference value.',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                button: true,
                label: widget.isSending ? 'Sending SMS' : 'Send SMS',
                child: FilledButton.icon(
                  onPressed: widget.isSending ? null : _submit,
                  icon: widget.isSending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(widget.isSending ? 'Sending…' : 'Send SMS'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateRecipient(String? value) {
    final recipient = value?.trim() ?? '';

    if (recipient.isEmpty) {
      return 'Recipient phone number is required.';
    }

    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(recipient)) {
      return 'Phone number must be in E.164 format, for example +4915112345678.';
    }

    return null;
  }

  String? _validateBody(String? value) {
    final body = value ?? '';

    if (body.trim().isEmpty) {
      return 'Message body is required.';
    }

    if (body.length > 1000) {
      return 'Message is too long for this demo console.';
    }

    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final referenceId = _referenceController.text.trim();

    widget.onSubmit(
      SendSmsInput(
        to: _recipientController.text.trim(),
        body: _bodyController.text,
        referenceId: referenceId.isEmpty ? null : referenceId,
      ),
    );
  }
}
