import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/core/theme/app_gradients.dart';
import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/ai/ai_prompts.dart';
import 'package:darooyar/features/ai/ai_provider.dart';
import 'package:darooyar/features/ai/ai_snapshot.dart';

/// بخش «پزشک دارویار»: چت با پزشک هوش مصنوعی + بررسی روزانهٔ خودکار.
///
/// - پزشک برای عموم آماده است: کاربر کلیدی وارد نمی‌کند، فقط دکمهٔ
///   فعال‌سازی را می‌زند (opt-in؛ تا فعال نشود ترافیک شبکه‌ای نیست).
/// - با هر پیام، زمینهٔ کامل «اطلاعات کاربر» (افراد، داروها، برنامهٔ امروز،
///   شاخص‌های سلامت، آب و وعده‌ها) از `buildAiSnapshot` ساخته و به مدل
///   فرستاده می‌شود تا تحلیل شخصی باشد.
/// - تاریخچهٔ چت محلی می‌ماند و فقط همین خلاصهٔ ساختاریافته ارسال می‌شود.
class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  bool _dailyCheck = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ai = context.read<AiProvider>();
      await ai.load();
      if (!mounted) return;
      setState(() => _dailyCheck = ai.dailyCheck);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('پزشک دارویار'),
        actions: [
          if (ai.isConfigured)
            PopupMenuButton<String>(
              tooltip: 'گزینه‌ها',
              icon: const Icon(Icons.more_vert_outlined),
              onSelected: (value) {
                if (value == 'clear') {
                  ai.clearChat();
                } else if (value == 'daily') {
                  ai.runDailyCheck(buildAiSnapshot(context));
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'daily',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 20),
                      SizedBox(width: 10),
                      // متن باید در عرض منو جا شود؛ در غیر این صورت Row سرریز می‌کند.
                      Expanded(
                        child: Text('اجرای دوبارهٔ بررسی روزانه'),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_outlined, size: 20),
                      SizedBox(width: 10),
                      Expanded(child: Text('پاک کردن گفتگو')),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          if (ai.busy) const LinearProgressIndicator(),
          if (ai.error != null) _ErrorBanner(message: ai.error!),
          Expanded(
            child: ai.isConfigured
                ? _buildConfigured(context, ai)
                : _buildSetup(context, ai),
          ),
        ],
      ),
    );
  }

  // ── حالت تنظیمات (هنوز فعال نشده) ────────────────────────────────

  Widget _buildSetup(BuildContext context, AiProvider ai) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppGradients.soft,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined,
                      color: Color(0xFF00382B)),
                  const SizedBox(width: 8),
                  Text(
                    'پزشک آنلاین دارویار',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFF00382B),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'با پزشک هوش مصنوعی دارویار چت کنید: علائم را توضیح بدهید، '
                'شروع به پرسیدن شرح‌حال می‌کند و برداشت بالینی، دلایل محتمل و '
                'اقدام بعدی را دقیقاً مانند یک پزشک واقعی می‌دهد. دستیار به '
                'اطلاعات ثبت‌شدهٔ شما در اپ (افراد، داروها، برنامهٔ امروز، '
                'شاخص‌های سلامت و تغذیه) دسترسی دارد و می‌تواند وضعیت‌تان را '
                'شخصاً تحلیل کند — بدون هیچ تنظیم یا کلیدی؛ فقط دکمهٔ '
                'فعال‌سازی را بزنید.',
                style: TextStyle(
                  color: Color(0xFF0E1F1A),
                  height: 1.7,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'حریم خصوصی: با فعال کردن دستیار، اطلاعات ثبت‌شده در اپ '
                '(نام افراد، داروها، برنامهٔ امروز و شاخص‌های سلامت) به‌صورت '
                'خلاصه‌شده به سرور هوش مصنوعی ارسال می‌شود. بدون فعالسازی، '
                'اپ همچنان کاملاً آفلاین است.',
                style: TextStyle(
                  color: Color(0xFF00382B),
                  height: 1.7,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('بررسی روزانهٔ خودکار'),
          subtitle: Text(
            'هر روز یک‌بار وضعیت شما بررسی و کارت آن ذخیره می‌شود.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          value: _dailyCheck,
          onChanged: (v) => setState(() => _dailyCheck = v),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('فعال‌سازی پزشک'),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await ai.saveSettings(enabled: true, dailyCheck: _dailyCheck);
            if (!mounted) return;
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  ai.hasApiKey
                      ? 'پزشک دارویار فعال شد؛ می‌توانید چت را شروع کنید.'
                      : 'پزشک فعال شد، اما کلید هوش مصنوعی در این ساخت '
                          'قرار نگرفته است.',
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── حالت فعال ────────────────────────────────────────────────────

  Widget _buildConfigured(BuildContext context, AiProvider ai) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _InsightCard(ai: ai),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: _QuickActions(ai: ai),
        ),
        Expanded(child: _ChatList(ai: ai)),
        _ChatInputBar(ai: ai),
      ],
    );
  }
}

// ── کارت بررسی روزانه ──────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.ai});

  final AiProvider ai;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final insight = ai.dailyInsight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppGradients.soft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart_outlined, color: Color(0xFF00382B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'بررسی روزانهٔ سلامت',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF00382B),
                      ),
                ),
              ),
              IconButton(
                tooltip: 'بررسی دوباره',
                icon: const Icon(Icons.refresh, color: Color(0xFF00382B)),
                onPressed: ai.busy
                    ? null
                    : () => ai.runDailyCheck(buildAiSnapshot(context)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (insight == null)
            Text(
              'هنوز بررسی‌ای ساخته نشده است؛ روی باززنگ بزنید.',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13.5,
                height: 1.6,
              ),
            )
          else
            Text(
              insight.text,
              style: const TextStyle(
                color: Color(0xFF0E1F1A),
                fontSize: 14,
                height: 1.8,
              ),
            ),
        ],
      ),
    );
  }
}

// ── اکشن‌های سریع (تحلیل کامل + چیپ‌ها) ─────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.ai});

  final AiProvider ai;

  @override
  Widget build(BuildContext context) {
    final topics = AiPrompts.quickTopics;
    final full = topics.first;
    final rest = [for (final t in topics.skip(1)) t];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // دکمهٔ برجستهٔ «تحلیل کامل من» با گرادیان برند.
        SizedBox(
          width: double.infinity,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: ai.busy
                  ? null
                  : () => ai.quickAnalysis(
                        full.label,
                        snapshot: buildAiSnapshot(context),
                        prompt: full.prompt,
                      ),
              child: Ink(
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppGradients.activity,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome_outlined,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      full.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final topic in rest)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ActionChip(
                    avatar: Icon(topic.icon, size: 18),
                    label: Text(topic.label),
                    onPressed: ai.busy
                        ? null
                        : () => ai.quickAnalysis(
                              topic.label,
                              snapshot: buildAiSnapshot(context),
                              prompt: topic.prompt,
                            ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── حالت خالی (خوش‌آمدگویی + معرفی قابلیت‌ها) ───────────────────────

class _WelcomeState extends StatelessWidget {
  const _WelcomeState();

  static const List<String> _capabilities = [
    'داروهای افراد خانواده، نوبت‌های جامانده و داروی رو به اتمام',
    'برنامهٔ امروز و پایبندی به مصرف دارو (با استریک)',
    'شاخص‌های سلامت: وزن، BMI، فشار، قند، خواب و لیوان آب',
    'وعده‌های غذایی و روند تغذیه',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppGradients.soft,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined,
                      color: Color(0xFF00382B)),
                  const SizedBox(width: 8),
                  Text(
                    'سلام! من پزشک دارویارم',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFF00382B),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'من به اطلاعات ثبت‌شدهٔ شما در اپ دسترسی دارم و می‌توانم '
                'شخصاً وضعیت‌تان را تحلیل کنم:',
                style: TextStyle(
                  color: Color(0xFF0E1F1A),
                  height: 1.7,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 8),
              for (final item in _capabilities)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 18, color: Color(0xFF0E7C66)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            height: 1.6,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              const Text(
                'برای شروع، «تحلیل کامل من» را بزنید یا هر سؤالی دربارهٔ '
                'سلامت‌تان بپرسید.',
                style: TextStyle(
                  color: Color(0xFF00382B),
                  height: 1.7,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── فهرست پیام‌ها ──────────────────────────────────────────────────

class _ChatList extends StatelessWidget {
  const _ChatList({required this.ai});

  final AiProvider ai;

  @override
  Widget build(BuildContext context) {
    final messages = ai.messages;
    final waiting = ai.busy;
    final count = messages.length + (waiting ? 1 : 0);

    if (count == 0) return const _WelcomeState();

    // فهرست وارونه است: آیتم ۰ پایین‌ترین (تازه‌ترین) است؛ پس همیشه
    // آخرین پیام و نشانگر تایپ دیده می‌شوند و اسکرول خودکار انجام می‌شود.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: count,
      itemBuilder: (context, index) {
        if (waiting && index == 0) return const _TypingBubble();
        final offset = waiting ? index - 1 : index;
        final message = messages[messages.length - 1 - offset];
        return _Bubble(message: message);
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final AiMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fromUser = message.fromUser;

    final avatar = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fromUser ? scheme.primary : null,
        gradient: fromUser ? null : AppGradients.soft,
        border: fromUser ? null : Border.all(color: scheme.outlineVariant),
      ),
      child: Icon(
        fromUser ? Icons.person_outline : Icons.medical_services_outlined,
        size: 18,
        color: fromUser ? scheme.onPrimary : const Color(0xFF00382B),
      ),
    );

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.74,
      ),
      decoration: BoxDecoration(
        color: fromUser ? scheme.primary : scheme.surfaceContainerLow,
        borderRadius: BorderRadiusDirectional.only(
          topStart: const Radius.circular(20),
          topEnd: const Radius.circular(20),
          bottomStart: Radius.circular(fromUser ? 20 : 6),
          bottomEnd: Radius.circular(fromUser ? 6 : 20),
        ),
        border: fromUser ? null : Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment:
            fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          SelectableText(
            message.text,
            style: TextStyle(
              color: fromUser ? scheme.onPrimary : scheme.onSurface,
              height: 1.7,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            PersianUtils.formatTime(message.time),
            style: TextStyle(
              color: fromUser ? scheme.onPrimary : scheme.onSurfaceVariant,
              fontSize: 10.5,
              height: 1.2,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            fromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: fromUser
            ? [bubble, const SizedBox(width: 8), avatar]
            : [avatar, const SizedBox(width: 8), bubble],
      ),
    );
  }
}

// ── نشانگر «در حال تایپ» (سه نقطهٔ متحرک) ──────────────────────────

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _dot(int index) {
    final animation = Tween<double>(begin: 0.25, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          index * 0.2,
          index * 0.2 + 0.5,
          curve: Curves.easeInOut,
        ),
      ),
    );
    return FadeTransition(
      opacity: animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF00382B),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.soft,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: const Icon(
              Icons.medical_services_outlined,
              size: 18,
              color: Color(0xFF00382B),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: const BorderRadiusDirectional.only(
                topStart: Radius.circular(20),
                topEnd: Radius.circular(20),
                bottomEnd: Radius.circular(20),
                bottomStart: Radius.circular(6),
              ),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(0),
                const SizedBox(width: 6),
                _dot(1),
                const SizedBox(width: 6),
                _dot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── نوار نوشتن پیام ───────────────────────────────────────────────

class _ChatInputBar extends StatefulWidget {
  const _ChatInputBar({required this.ai});

  final AiProvider ai;

  @override
  State<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<_ChatInputBar> {
  late final TextEditingController _chatController;

  @override
  void initState() {
    super.initState();
    _chatController = TextEditingController()..addListener(_onTextChanged);
  }

  void _onTextChanged() {
    // برای فعال/غیرفعال کردن دکمهٔ ارسال بر اساس متن واردشده.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  bool get _canSend => _chatController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = widget.ai.busy;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _chatController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: busy
                      ? 'پزشک در حال بررسی اطلاعات شماست…'
                      : 'مثلاً: سردرد سه روزه دارم، دلیلش چیست؟',
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'ارسال',
              icon: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.6),
                    )
                  : const Icon(Icons.send),
              style: IconButton.styleFrom(
                minimumSize: const Size(52, 52),
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
              onPressed: busy || !_canSend ? null : _send,
            ),
          ],
        ),
      ),
    );
  }

  void _send() {
    final text = _chatController.text.trim();
    if (text.isEmpty || widget.ai.busy) return;
    _chatController.clear();
    widget.ai.sendChat(text, snapshot: buildAiSnapshot(context));
  }
}

// ── بنر خطا ───────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: context.read<AiProvider>().clearError,
          ),
        ],
      ),
    );
  }
}
