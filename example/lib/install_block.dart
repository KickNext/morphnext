import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reel_text/reel_text.dart';

import 'studio.dart';

final class MorphnextInstallBlock extends StatefulWidget {
  const MorphnextInstallBlock({super.key});

  @override
  State<MorphnextInstallBlock> createState() => _MorphnextInstallBlockState();
}

final class _MorphnextInstallBlockState extends State<MorphnextInstallBlock> {
  static const _installCommand = 'flutter pub add morphnext';
  static const _controlHeight = 48.0;

  late final ReelTextController _copyLabel;

  @override
  void initState() {
    super.initState();
    _copyLabel = ReelTextController(initialText: 'Copy');
  }

  @override
  void dispose() {
    _copyLabel.dispose();
    super.dispose();
  }

  void _copyInstallCommand() {
    unawaited(Clipboard.setData(const ClipboardData(text: _installCommand)));
    _copyLabel.flash(
      'Copied',
      options: const ReelTextFlashOptions(
        enter: ReelTextOptions(
          duration: Duration(milliseconds: 220),
          stagger: Duration(milliseconds: 18),
        ),
        exit: ReelTextOptions(
          direction: ReelTextDirection.down,
          duration: Duration(milliseconds: 220),
          stagger: Duration(milliseconds: 18),
        ),
      ),
    );
  }

  /// The block is the preview film's closing capsule brought to the page: no
  /// panel around it, just the command in a bordered pill on the bare ground,
  /// with the copy action as a second pill beside it.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final inline = constraints.maxWidth >= 520;
        final caption = StudioCaption(
          'Install',
          color: scheme.onSurfaceVariant,
        );
        final command = _CommandField(
          key: const ValueKey<String>('install-command'),
          command: _installCommand,
        );
        final button = SizedBox(
          key: const ValueKey<String>('install-copy-button'),
          width: inline ? 92 : 84,
          height: _controlHeight,
          child: FilledButton(
            onPressed: _copyInstallCommand,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: const StadiumBorder(),
            ),
            child: SizedBox(
              key: const ValueKey<String>('install-copy-label-slot'),
              width: 60,
              height: 30,
              child: Center(
                child: ReelText.controller(
                  controller: _copyLabel,
                  style: Studio.buttonLabel(color: scheme.onPrimary),
                  semanticsLabel: 'Copy install command',
                ),
              ),
            ),
          ),
        );

        return KeyedSubtree(
          key: const ValueKey<String>('morphnext-install-block'),
          child: inline
              ? Row(
                  children: <Widget>[
                    SizedBox(width: 82, child: caption),
                    Expanded(child: command),
                    const SizedBox(width: 10),
                    button,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    caption,
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(child: command),
                        const SizedBox(width: 8),
                        button,
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }
}

final class _CommandField extends StatelessWidget {
  const _CommandField({super.key, required this.command});

  final String command;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: _MorphnextInstallBlockState._controlHeight,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          command,
          maxLines: 1,
          style: Studio.mono(
            size: 12.5,
            color: scheme.onSurface,
            weight: FontWeight.w700,
            letterSpacing: 0.15,
          ),
        ),
      ),
    );
  }
}
