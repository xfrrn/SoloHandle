import "dart:async";

import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "api_client.dart";
import "models.dart";

const String _defaultBaseUrl =
    String.fromEnvironment("API_BASE_URL", defaultValue: "http://localhost:8000");

void main() {
  runApp(const CompanionApp());
}

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      textTheme: GoogleFonts.spaceGroteskTextTheme(),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1B4959),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF4F1EC),
    );

    return MaterialApp(
      title: "AI Companion",
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  late final ApiClient _client;

  bool _loading = false;
  String? _status;
  String? _clarify;
  String? _reply;
  String? _undoToken;
  List<Draft> _drafts = [];
  List<CardData> _cards = [];

  late final AnimationController _anim;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _client = ApiClient(baseUrl: _defaultBaseUrl);
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _anim.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _status = "请输入一句话来生成草稿");
      return;
    }
    setState(() {
      _loading = true;
      _status = "正在生成草稿...";
      _clarify = null;
      _reply = null;
      _drafts = [];
      _cards = [];
    });
    try {
      final resp = await _client.chat(text: text);
      setState(() {
        _loading = false;
        _clarify = resp.needClarification ? resp.clarifyQuestion : null;
        _reply = resp.replyToUser;
        _drafts = resp.drafts;
        _cards = resp.cards;
        _status = resp.needClarification ? "需要补充说明" : "草稿已生成";
      });
    } catch (exc) {
      setState(() {
        _loading = false;
        _status = "请求失败：$exc";
      });
    }
  }

  Future<void> _confirmDrafts(List<String> draftIds) async {
    if (draftIds.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _status = "正在确认...";
    });
    try {
      final resp = await _client.chat(confirmDraftIds: draftIds);
      setState(() {
        _loading = false;
        _undoToken = resp.undoToken;
        _drafts = [];
        _cards = [];
        _status = "已确认 ${resp.committed.length} 条记录";
      });
    } catch (exc) {
      setState(() {
        _loading = false;
        _status = "确认失败：$exc";
      });
    }
  }

  Future<void> _undo() async {
    final token = _undoToken;
    if (token == null) {
      return;
    }
    setState(() {
      _loading = true;
      _status = "正在撤销...";
    });
    try {
      final resp = await _client.chat(undoToken: token);
      setState(() {
        _loading = false;
        _status = "已撤销 ${resp.undone.length} 条记录";
      });
    } catch (exc) {
      setState(() {
        _loading = false;
        _status = "撤销失败：$exc";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 920;

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeIn,
        child: Stack(
          children: [
            const _Backdrop(),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 64),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeroHeader(isWide: isWide),
                        const SizedBox(height: 24),
                        _InputPanel(
                          controller: _controller,
                          loading: _loading,
                          onSend: _sendText,
                        ),
                        const SizedBox(height: 16),
                        _StatusBar(
                          status: _status,
                          clarify: _clarify,
                          reply: _reply,
                        ),
                        const SizedBox(height: 20),
                        if (_drafts.isNotEmpty) _ConfirmBar(onConfirmAll: _confirmAll),
                        if (_cards.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _CardList(
                            cards: _cards,
                            onConfirm: _confirmSingle,
                          ),
                        ],
                        const SizedBox(height: 16),
                        _UndoPanel(
                          undoToken: _undoToken,
                          onUndo: _undo,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmAll() {
    final ids = _drafts.map((d) => d.draftId).toList();
    _confirmDrafts(ids);
  }

  void _confirmSingle(String draftId) {
    _confirmDrafts([draftId]);
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFF4F1EC),
            Color(0xFFE8EEF0),
            Color(0xFFF2E8DB),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: const [
          Positioned(
            top: -120,
            right: -60,
            child: _GlowBall(size: 260, color: Color(0xFFB9E3D5)),
          ),
          Positioned(
            bottom: -140,
            left: -80,
            child: _GlowBall(size: 300, color: Color(0xFFF2C9A0)),
          ),
        ],
      ),
    );
  }
}

class _GlowBall extends StatelessWidget {
  const _GlowBall({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.25),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 80,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "SoloHandle / Web",
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: const Color(0xFF4A6A75),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "最小卡片式 AI 记录台",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F2D3A),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                "输入一句话，生成草稿，确认后入库。支持撤销。",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF3B4F58),
                    ),
              ),
            ],
          ),
        ),
        if (isWide) ...[
          const SizedBox(width: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F2D3A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "本地 API",
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _defaultBaseUrl,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _InputPanel extends StatelessWidget {
  const _InputPanel({
    required this.controller,
    required this.loading,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2D8CA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "输入",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F2D3A),
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: "比如：我今天花了25元买咖啡",
              filled: true,
              fillColor: const Color(0xFFF8F6F2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: loading ? null : onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B4959),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(loading ? "处理中..." : "生成草稿"),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.status, required this.clarify, required this.reply});

  final String? status;
  final String? clarify;
  final String? reply;

  @override
  Widget build(BuildContext context) {
    if (status == null && clarify == null && reply == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2D3A).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0F2D3A).withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (status != null)
            Text(
              status!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF0F2D3A),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          if (clarify != null) ...[
            const SizedBox(height: 6),
            Text("需要补充：$clarify"),
          ],
          if (reply != null) ...[
            const SizedBox(height: 6),
            Text("提示：$reply"),
          ],
        ],
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({required this.onConfirmAll});

  final VoidCallback onConfirmAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          "草稿",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F2D3A),
              ),
        ),
        const Spacer(),
        TextButton(
          onPressed: onConfirmAll,
          child: const Text("确认全部"),
        ),
      ],
    );
  }
}

class _CardList extends StatelessWidget {
  const _CardList({required this.cards, required this.onConfirm});

  final List<CardData> cards;
  final void Function(String draftId) onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: cards.map((card) => _CardItem(card: card, onConfirm: onConfirm)).toList(),
    );
  }
}

class _CardItem extends StatelessWidget {
  const _CardItem({required this.card, required this.onConfirm});

  final CardData card;
  final void Function(String draftId) onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2D8CA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                card.title.isEmpty ? "草稿" : card.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F2D3A),
                    ),
              ),
              const Spacer(),
              Text(
                card.type.toUpperCase(),
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 11,
                  color: const Color(0xFF6A7C82),
                ),
              ),
            ],
          ),
          if (card.subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              card.subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF4A5A61),
                  ),
            ),
          ],
          if (card.data.isNotEmpty) ...[
            const SizedBox(height: 10),
            _KeyValueGrid(data: card.data),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () => onConfirm(card.cardId),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1B4959),
                side: const BorderSide(color: Color(0xFF1B4959)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("确认"),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValueGrid extends StatelessWidget {
  const _KeyValueGrid({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: entries.map((entry) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F6F2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "${entry.key}: ${entry.value}",
            style: GoogleFonts.ibmPlexMono(
              fontSize: 11,
              color: const Color(0xFF384A52),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _UndoPanel extends StatelessWidget {
  const _UndoPanel({required this.undoToken, required this.onUndo});

  final String? undoToken;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    if (undoToken == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12262F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "最近一次操作可撤销",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          TextButton(
            onPressed: onUndo,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text("撤销"),
          ),
        ],
      ),
    );
  }
}
