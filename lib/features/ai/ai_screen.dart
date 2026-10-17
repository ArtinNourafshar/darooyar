import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/core/theme/app_gradients.dart';
import 'package:darooyar/features/ai/ai_prompts.dart';
import 'package:darooyar/features/ai/ai_provider.dart';
import 'package:darooyar/features/ai/ai_snapshot.dart';
import 'package:darooyar/features/ai/gemini_service.dart';

/// بخش «دستیار سلامت»: بررسی روزانهٔ خودکار + گفتگو با هوش مصنوعی.
///
/// - opt-in: تا کاربر کلید API خودش را ثبت و دستیار را فعال نکند،
///   هیچ درخواست شبکه‌ای ارسال نمی‌شود.
/// - فقط خلاصهٔ آماری وضعیت (اعداد) به مدل ارسال می‌شود.
class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();

  bool _obscureKey = true;
  bool _dailyCheck = true;
  bool _formSeeded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ai = context.read<AiProvider>();
      await ai.load();
      if (!mounted) return;
      setState(() {
        _dailyCheck = ai.dailyCheck;
        if (ai.model != GeminiService.defaultModel) {
          _modelController.text = ai.model;
        }
        _formSeeded = true;
      });
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    _modelController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('دستیار سلامت'),
        actions: [
          if (ai.isConfigured && ai.messages.isNotEmpty)
            IconButton(
              tooltip: 'پاک کردن گفتگو',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: ai.busy ? null : ai.clearChat,
            ),
        ],
      ),
      body: Column(
        children: [
          if (ai.busy) const LinearProgressIndicator(),
          if (ai.error != null) _ErrorBanner(message: ai.error!),
          Expanded(
            child: ai.isConfigured && _formSeeded
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
                      color: Color(0xFF7A2B00)),
                  const SizedBox(width: 8),
                  Text(
                    'دستیار سلامت و تغذیه',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFF7A2B00),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'دستیار هر روز وضعیت سلامت، خواب، تغذیه و مصرف داروهای شما را '
                'بررسی می‌کند و می‌توانید دربارهٔ هر موضوعی از او بپرسید. '
                'مدل پیش‌فرض ارزان‌ترین مدل رایگان گوگل (Gemini Flash Lite) است.',
                style: TextStyle(
                  color: Color(0xFF211A16),
                  height: 1.7,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'حریم خصوصی: با فعال کردن دستیار، فقط خلاصهٔ آماری وضعیت شما '
                '(اعداد سلامت، تعداد نوبت‌ها و وعده‌ها) به سرور گوگل ارسال می‌شود. '
                'بدون فعالسازی، اپ همچنان کاملاً آفلاین است.',
                style: TextStyle(
                  color: Color(0xFF7A2B00),
                  height: 1.7,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _keyController,
          obscureText: _obscureKey,
          decoration: InputDecoration(
            labelText: 'کلید API گوگل',
            hintText: 'AIza…',
            prefixIcon: const Icon(Icons.key_outlined),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              ),
              onPressed: () => setState(() => _obscureKey = !_obscureKey),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'کلید رایگان را از آدرس زیر بسازید و اینجا وارد کنید:\n'
          'aistudio.google.com/app/apikey',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.6,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _modelController,
          decoration: InputDecoration(
            labelText: 'شناسهٔ مدل (اختیاری)',
            hintText: ai.model,
            prefixIcon: const Icon(Icons.smart_toy_outlined),
          ),
        ),
        const SizedBox(height: 8),
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
          label: const Text('فعال‌سازی دستیار'),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await ai.saveSettings(
              enabled: true,
              dailyCheck: _dailyCheck,
              apiKey: _keyController.text,
              model: _modelController.text,
            );
            if (!mounted) return;
            if (ai.hasApiKey) {
              messenger.showSnackBar(
                const SnackBar(content: Text('دستیار فعال شد.')),
              );
            }
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _QuickTopics(ai: ai),
        ),
        const Divider(),
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
              const Icon(Icons.monitor_heart_outlined, color: Color(0xFF7A2B00)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'بررسی روزانهٔ سلامت',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF7A2B00),
                      ),
                ),
              ),
              IconButton(
                tooltip: 'بررسی دوباره',
                icon: const Icon(Icons.refresh, color: Color(0xFF7A2B00)),
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
                color: Color(0xFF211A16),
                fontSize: 14,
                height: 1.8,
              ),
            ),
        ],
      ),
    );
  }
}

// ── موضوع‌های آماده ────────────────────────────────────────────────

class _QuickTopics extends StatelessWidget {
  const _QuickTopics({required this.ai});

  final AiProvider ai;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final topic in AiPrompts.quickTopics)
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
                        ),
              ),
            ),
        ],
      ),
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
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'هنوز پرسشی نپرسیده‌اید.\nاز دکمه‌های بالا استفاده کنید یا '
            'خودتان بپرسید؛ مثلاً «خوابم چطور بود؟»',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.7,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
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

    return Align(
      alignment: fromUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
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
        child: SelectableText(
          message.text,
          style: TextStyle(
            color: fromUser ? scheme.onPrimary : scheme.onSurface,
            height: 1.7,
            fontSize: 14.5,
          ),
        ),
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
    _chatController = TextEditingController();
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
                enabled: !widget.ai.busy,
                decoration: InputDecoration(
                  hintText: widget.ai.busy
                      ? 'در حال پاسخ‌گویی…'
                      : 'مثلاً: خوابم این هفته چطور بود؟',
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'ارسال',
              icon: const Icon(Icons.send),
              style: IconButton.styleFrom(
                minimumSize: const Size(52, 52),
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
              onPressed: widget.ai.busy ? null : _send,
            ),
          ],
        ),
      ),
    );
  }

  void _send() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
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
