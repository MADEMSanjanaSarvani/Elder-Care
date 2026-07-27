import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_tokens.dart';

/// Shared presentation helpers so every screen speaks the same visual
/// language — a coloured icon chip, a friendly empty state, and human-
/// readable timestamps — without each feature re-inventing them.

/// A coloured circular icon badge used at the start of list rows and cards.
class SetuIconChip extends StatelessWidget {
  const SetuIconChip({
    required this.icon,
    this.color = SetuColors.accentLight,
    this.size = 20,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(size * 0.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size),
    );
  }
}

/// A calm, centered empty state: artwork (or icon), title, and a short line
/// of guidance.
///
/// [artwork] takes precedence over [icon] when supplied — screens pass an
/// illustration from the app's asset bundle. The widget rather than an asset
/// path keeps this package free of asset declarations of its own.
class SetuEmptyState extends StatelessWidget {
  const SetuEmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.artwork,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? artwork;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SetuSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            artwork ??
                Icon(icon, size: 56, color: SetuColors.mutedLight),
            const SizedBox(height: SetuSpacing.md),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            if (message != null) ...[
              const SizedBox(height: SetuSpacing.xs),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: SetuColors.mutedLight)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A calm branded loading state — a soft sage spinner centred with a little
/// breathing room, so every screen waits the same gentle way.
class SetuLoading extends StatelessWidget {
  const SetuLoading({this.label, super.key});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
                strokeWidth: 3, color: SetuColors.accentLight),
          ),
          if (label != null) ...[
            const SizedBox(height: SetuSpacing.md),
            Text(label!, style: const TextStyle(color: SetuColors.mutedLight)),
          ],
        ],
      ),
    );
  }
}

/// A friendly error state — never a raw exception dumped on screen. Shows a
/// soft icon, a reassuring line, and an optional "Try again" button wired to
/// whatever refresh the caller provides.
class SetuErrorState extends StatelessWidget {
  const SetuErrorState({
    this.title = "That didn't load",
    this.message = 'Please check your connection and try again.',
    this.onRetry,
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SetuSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SetuIconChip(
                icon: Icons.cloud_off_outlined,
                color: SetuColors.peachLight,
                size: 34),
            const SizedBox(height: SetuSpacing.md),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: SetuSpacing.xs),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: SetuColors.mutedLight)),
            if (onRetry != null) ...[
              const SizedBox(height: SetuSpacing.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A small status pill (coloured text on a soft tinted background).
class SetuStatusPill extends StatelessWidget {
  const SetuStatusPill({
    required this.label,
    this.color = SetuColors.accentLight,
    super.key,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SetuSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Human-readable date/time formatting shared across the app.
class SetuFormat {
  const SetuFormat._();

  static String _clock(DateTime dt) {
    final h = dt.hour == 0 || dt.hour == 12 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
  }

  /// e.g. "Today, 3:40 PM" · "Yesterday, 9:05 AM" · "12 Jan, 4:00 PM".
  static String friendlyTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(dt.year, dt.month, dt.day);
    final days = today.difference(that).inDays;
    final clock = _clock(dt);
    if (days == 0) return 'Today, $clock';
    if (days == 1) return 'Yesterday, $clock';
    if (days == -1) return 'Tomorrow, $clock';
    return '${dt.day} ${_month(dt.month)}, $clock';
  }

  /// e.g. "12 Jan 2026".
  static String friendlyDate(DateTime dt) =>
      '${dt.day} ${_month(dt.month)} ${dt.year}';

  static String _month(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];
}

/// Lifts a bottom navigation bar off the page the way every SETU design draws
/// it: white, rounded across the top, with a warm shadow falling upward.
///
/// NavigationBarThemeData has no shape, so this cannot come from the theme.
/// Wrapping is the only way to get the rounded top, and the upward shadow is
/// what separates the bar from the content instead of letting it blend into
/// the bottom of a scrolling list.
class SetuNavSurface extends StatelessWidget {
  const SetuNavSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? SetuColors.paperRaisedDark : SetuColors.paperRaisedLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: (dark ? Colors.black : SetuColors.peachLight)
                .withValues(alpha: dark ? 0.4 : 0.10),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: child,
      ),
    );
  }
}

/// The soft out-of-focus colour blobs behind the SETU screens.
///
/// Two large circles bled off opposite corners at very low alpha. Cheap —
/// they are plain circles with a radial gradient, painted once, with no blur
/// filter and no animation, so they cost nothing per frame. That matters: the
/// designs achieve this with backdrop blur, which is one of the most expensive
/// things you can put on an entry-level Android GPU, and repeating it behind
/// every screen would be felt.
///
/// Put it at the bottom of a Stack, under the content.
class SetuAtmosphere extends StatelessWidget {
  const SetuAtmosphere({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -120,
            child: _Blob(size: 340, color: SetuColors.peachLight),
          ),
          Positioned(
            bottom: -140,
            left: -110,
            child: _Blob(size: 300, color: SetuColors.lavenderLight),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // A radial gradient fading to nothing gives the same soft edge a blur
        // would, for none of the cost.
        gradient: RadialGradient(colors: [
          color.withValues(alpha: 0.14),
          color.withValues(alpha: 0.0),
        ]),
      ),
    );
  }
}

/// Keeps a perpetual "breathing" animation in step with the platform's
/// reduce-motion setting. Call from `didChangeDependencies`.
///
/// Six things in this app breathe forever — the SOS halo, the assistant orb,
/// the empty-inbox blob, the success screen, the elder-home SOS button, the
/// dashboard status dot. Three of them ignored the setting entirely, which is
/// the wrong way round for an app whose users are older adults: vestibular
/// sensitivity, migraine and vertigo all get worse with age, and "reduce
/// motion" is precisely the switch those people have already found.
///
/// It stops the controller rather than merely ignoring its output. A repeating
/// controller nobody reads still schedules a frame on every vsync, so leaving
/// it running would keep the screen awake and the battery draining to animate
/// something deliberately not being shown.
///
/// [restingValue] is where the animation settles — pick whatever the design
/// looks right at when still, usually its midpoint rather than an endpoint.
void setuSyncBreathing(
  BuildContext context,
  AnimationController controller, {
  double restingValue = 0.5,
  bool reverse = true,
}) {
  if (MediaQuery.of(context).disableAnimations) {
    if (controller.isAnimating) controller.stop();
    controller.value = restingValue;
  } else if (!controller.isAnimating) {
    controller.repeat(reverse: reverse);
  }
}

/// A code entry laid out as separate boxes, one per digit.
///
/// Six of them, because every code SETU issues is six digits — the visit OTP is
/// generated as `100000 + random * 900000`, which cannot produce anything else.
///
/// Built as one real text field drawn invisibly over decorative boxes, rather
/// than as six fields that pass focus between themselves. Six fields is the
/// obvious implementation and it breaks in all the ways that matter at a
/// doorway: pasting a code fills only the first box, backspace at the start of
/// a box does nothing, and platform autofill has no single target to fill.
/// One field behind the boxes gets paste, backspace, selection and autofill for
/// free, and the caller keeps the plain [TextEditingController] it already had.
class SetuCodeField extends StatefulWidget {
  const SetuCodeField({
    required this.controller,
    this.length = 6,
    this.autofocus = false,
    this.enabled = true,
    this.onCompleted,
    super.key,
  });

  final TextEditingController controller;
  final int length;
  final bool autofocus;
  final bool enabled;

  /// Fires once the last digit lands, so the caller can submit without making
  /// someone reach for a button they have already earned.
  final ValueChanged<String>? onCompleted;

  @override
  State<SetuCodeField> createState() => _SetuCodeFieldState();
}

class _SetuCodeFieldState extends State<SetuCodeField> {
  final _node = FocusNode();

  @override
  void initState() {
    super.initState();
    // The active box is drawn from focus as well as from length, so both have
    // to trigger a repaint.
    _node.addListener(_onChanged);
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _node.removeListener(_onChanged);
    widget.controller.removeListener(_onChanged);
    // The node is ours; the controller belongs to the caller and is not
    // disposed here.
    _node.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
    if (widget.controller.text.length == widget.length) {
      widget.onCompleted?.call(widget.controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;

    return Stack(
      alignment: Alignment.center,
      children: [
        // The boxes are a picture of the field's value, so a screen reader
        // should hear the field once rather than the field followed by six
        // loose digits.
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < widget.length; i++)
                _CodeBox(
                  digit: i < code.length ? code[i] : null,
                  // The caret sits on the next empty box, or on the last one
                  // when the code is full — never nowhere.
                  active: _node.hasFocus &&
                      (i == code.length ||
                          (code.length == widget.length &&
                              i == widget.length - 1)),
                ),
            ],
          ),
        ),
        // The real field, invisible and on top so it takes every tap.
        Positioned.fill(
          child: TextField(
            controller: widget.controller,
            focusNode: _node,
            autofocus: widget.autofocus,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            enableInteractiveSelection: false,
            showCursor: false,
            cursorColor: Colors.transparent,
            style: const TextStyle(color: Colors.transparent, fontSize: 1),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(widget.length),
            ],
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              filled: false,
              counterText: '',
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.digit, required this.active});

  final String? digit;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final filled = digit != null;
    final border = active
        ? SetuColors.accentLight
        : filled
            ? SetuColors.accentLight.withValues(alpha: 0.4)
            : SetuColors.borderLight;

    return Container(
      width: 46,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 2),
      ),
      child: Text(
        digit ?? '',
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: SetuColors.inkLight,
        ),
      ),
    );
  }
}
