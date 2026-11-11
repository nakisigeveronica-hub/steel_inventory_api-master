import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/supplier.dart';
import '../models/transaction.dart';
import '../services/deepseek_service.dart';
import '../services/inventory_service.dart';
import '../services/inventory_report_service.dart';
import '../services/user_permissions.dart';
import 'inventory_report_preview_screen.dart';

class _AssistantMessage {
  final String role;
  final String content;

  const _AssistantMessage({required this.role, required this.content});
}

class InventoryAssistantScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final int initialTab;

  const InventoryAssistantScreen({
    super.key,
    required this.user,
    this.initialTab = 0,
  });

  @override
  State<InventoryAssistantScreen> createState() =>
      _InventoryAssistantScreenState();
}

class _InventoryAssistantScreenState extends State<InventoryAssistantScreen> {
  final InventoryService inventoryService = InventoryService();
  final DeepSeekService _deepSeekService = DeepSeekService();
  final InventoryReportService _reportService = InventoryReportService();
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  bool isLoading = true;
  bool _isSending = false;
  bool _isGeneratingReport = false;
  bool _inventoryDataAvailable = false;
  int _reportRequestId = 0;

  List<Product> products = [];
  List<Product> lowStockProducts = [];
  List<Product> criticalStockProducts = [];
  List<InventoryTransaction> transactions = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> suppliers = [];
  List<Map<String, dynamic>> notifications = [];

  Map<String, dynamic> statistics = {};
  ReportPeriod _reportPeriod = ReportPeriod.weekly;
  Map<String, dynamic>? _generatedReport;
  String? _reportSummary;
  String? _reportError;
  final List<_AssistantMessage> _messages = [
    const _AssistantMessage(
      role: 'assistant',
      content:
          'Hello! I can answer questions using the inventory data saved in this app. Ask me about stock levels, transactions, or restocking.',
    ),
  ];

  final TextEditingController searchController = TextEditingController();

  String searchQuery = '';

  bool get _canGenerateReports =>
      UserPermissions.canGenerateReports(widget.user['role']);

  @override
  void initState() {
    super.initState();
    _loadAssistantData();
  }

  @override
  void dispose() {
    searchController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    _deepSeekService.close();
    super.dispose();
  }

  // ============================================================
  // LOAD DATA
  // ============================================================

  Future<void> _loadAssistantData() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        _inventoryDataAvailable = false;
        _generatedReport = null;
        _reportSummary = null;
        _reportError = null;
        _isGeneratingReport = false;
        _reportRequestId++;
      });
    }

    try {
      final results = await Future.wait([
        inventoryService.getProducts(),
        inventoryService.getLowStockProducts(),
        inventoryService.getCriticalStockProducts(),
        inventoryService.getTransactions(),
        inventoryService.getDashboardStatistics(),
        inventoryService.getCategories(),
        inventoryService.getSuppliers(),
        inventoryService.getNotifications(),
      ]);

      if (!mounted) return;

      setState(() {
        products = List<Product>.from(results[0] as List);
        lowStockProducts = List<Product>.from(results[1] as List);
        criticalStockProducts = List<Product>.from(results[2] as List);
        transactions = List<InventoryTransaction>.from(results[3] as List);
        statistics = Map<String, dynamic>.from(results[4] as Map);
        categories = List<Map<String, dynamic>>.from(results[5] as List);
        suppliers = List<Supplier>.from(
          results[6] as List,
        ).map((supplier) => supplier.toJson()).toList();
        notifications = List<Map<String, dynamic>>.from(results[7] as List);
        isLoading = false;
        _inventoryDataAvailable = true;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;

      debugPrint('Inventory assistant data load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      setState(() {
        isLoading = false;
      });

      _showMessage(
        'Unable to load inventory assistant data: $error',
        isError: true,
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  int _intStat(String key) {
    final value = statistics[key];

    if (value is int) return value;
    if (value is num) return value.toInt();

    return 0;
  }

  double _recommendedQuantity(Product product) {
    if (product.minimumStock <= 0) {
      return 0;
    }

    final targetStock = product.minimumStock * 2;
    final recommended = targetStock - product.quantity;

    return recommended > 0 ? recommended : 0;
  }

  bool _isCritical(Product product) {
    if (product.minimumStock <= 0) {
      return false;
    }

    return product.quantity <= product.minimumStock * 0.5;
  }

  bool _isLowStock(Product product) {
    if (product.minimumStock <= 0) {
      return false;
    }

    return product.quantity <= product.minimumStock;
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';

    final localDate = date.toLocal();

    return '${localDate.day.toString().padLeft(2, '0')}/'
        '${localDate.month.toString().padLeft(2, '0')}/'
        '${localDate.year}';
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';

    final localDate = date.toLocal();

    final hour = localDate.hour == 0
        ? 12
        : localDate.hour > 12
        ? localDate.hour - 12
        : localDate.hour;

    final minute = localDate.minute.toString().padLeft(2, '0');

    final period = localDate.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  String _stockStatus(Product product) {
    if (product.quantity <= 0) {
      return 'Out of Stock';
    }

    if (_isCritical(product)) {
      return 'Critical';
    }

    if (_isLowStock(product)) {
      return 'Low Stock';
    }

    return 'Healthy';
  }

  Color _stockStatusColor(Product product) {
    if (product.quantity <= 0) {
      return Colors.red.shade700;
    }

    if (_isCritical(product)) {
      return Colors.red.shade600;
    }

    if (_isLowStock(product)) {
      return Colors.orange.shade700;
    }

    return Colors.green;
  }

  IconData _stockStatusIcon(Product product) {
    if (product.quantity <= 0) {
      return Icons.remove_shopping_cart_rounded;
    }

    if (_isCritical(product)) {
      return Icons.warning_rounded;
    }

    if (_isLowStock(product)) {
      return Icons.priority_high_rounded;
    }

    return Icons.check_circle_rounded;
  }

  List<Product> get _filteredProducts {
    if (searchQuery.trim().isEmpty) {
      return products;
    }

    final query = searchQuery.toLowerCase().trim();

    return products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.itemType.toLowerCase().contains(query) ||
          product.unit.toLowerCase().contains(query);
    }).toList();
  }

  // ============================================================
  // MESSAGES
  // ============================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    final theme = Theme.of(context);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: theme.colorScheme.onPrimary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: isError
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabs = <Widget>[
      _buildChatTab(),
      if (_canGenerateReports) _buildReportTab(),
      RefreshIndicator(
        color: theme.colorScheme.primary,
        onRefresh: _loadAssistantData,
        child: _buildBody(),
      ),
    ];

    return DefaultTabController(
      length: tabs.length,
      initialIndex: widget.initialTab >= 0 && widget.initialTab < tabs.length
          ? widget.initialTab
          : 0,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: _buildAppBar(),
        body: isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              )
            : TabBarView(children: tabs),
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);

    return AppBar(
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
          color: theme.colorScheme.onSurface,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: theme.colorScheme.primary,
            size: 25,
          ),
          const SizedBox(width: 9),
          Text(
            'Inventory Assistant',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      bottom: TabBar(
        tabs: [
          const Tab(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            text: 'Assistant',
          ),
          if (_canGenerateReports)
            const Tab(icon: Icon(Icons.summarize_outlined), text: 'Reports'),
          const Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Overview'),
        ],
      ),
      actions: [
        if (UserPermissions.canManageUsers(widget.user['role']))
          IconButton(
            tooltip: 'Configure DeepSeek API key',
            icon: const Icon(Icons.key_rounded),
            onPressed: _configureApiKey,
          ),
        IconButton(
          tooltip: 'Clear conversation',
          icon: Icon(
            Icons.delete_outline_rounded,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
          ),
          onPressed: _clearConversation,
        ),
        IconButton(
          tooltip: 'Refresh',
          icon: Icon(
            Icons.refresh_rounded,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
          ),
          onPressed: _isGeneratingReport ? null : _loadAssistantData,
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        _buildWelcomeCard(),

        const SizedBox(height: 20),

        _buildInventoryHealth(),

        const SizedBox(height: 24),

        _buildSearch(),

        const SizedBox(height: 20),

        if (criticalStockProducts.isNotEmpty) _buildCriticalSection(),

        if (criticalStockProducts.isNotEmpty) const SizedBox(height: 24),

        if (lowStockProducts.isNotEmpty) _buildLowStockSection(),

        if (lowStockProducts.isNotEmpty) const SizedBox(height: 24),

        _buildSmartRecommendation(),

        const SizedBox(height: 24),

        _buildQuickActions(),

        const SizedBox(height: 24),

        _buildRecentActivity(),

        const SizedBox(height: 24),

        _buildInventoryInsights(),

        const SizedBox(height: 20),

        _buildProductStatusList(),
      ],
    );
  }

  Map<String, dynamic> _inventorySnapshot() {
    return _reportService.buildSnapshot(
      now: DateTime.now(),
      products: products,
      categories: categories,
      suppliers: suppliers,
      transactions: transactions,
      notifications: notifications,
    );
  }

  Future<void> _sendMessage([String? suggestion]) async {
    if (!_inventoryDataAvailable) {
      _showMessage(
        'Inventory data is unavailable. Refresh before asking a question.',
        isError: true,
      );
      return;
    }

    final question = (suggestion ?? _chatController.text).trim();
    if (question.isEmpty) {
      _showMessage('Enter a question before sending.', isError: true);
      return;
    }
    if (_isSending) return;

    _chatController.clear();
    setState(() {
      _messages.add(_AssistantMessage(role: 'user', content: question));
      _isSending = true;
    });
    _scrollChatToEnd();

    final chatHistory = _messages
        .map((message) => {'role': message.role, 'content': message.content})
        .toList();
    if (chatHistory.length > 12) {
      chatHistory.removeRange(0, chatHistory.length - 12);
    }

    try {
      final answer = await _deepSeekService.reply(
        messages: chatHistory,
        inventoryContext: _inventorySnapshot(),
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_AssistantMessage(role: 'assistant', content: answer));
        _isSending = false;
      });
    } on DeepSeekException catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _AssistantMessage(
            role: 'assistant',
            content: 'I could not answer that right now. ${error.message}',
          ),
        );
        _isSending = false;
      });
    }
    _scrollChatToEnd();
  }

  void _scrollChatToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearConversation() {
    setState(() {
      _messages
        ..clear()
        ..add(
          const _AssistantMessage(
            role: 'assistant',
            content:
                'Conversation cleared. Ask me a question about the current inventory.',
          ),
        );
    });
    _scrollChatToEnd();
  }

  Future<void> _configureApiKey() async {
    if (!UserPermissions.canManageUsers(widget.user['role'])) return;
    bool hasSavedKey;
    try {
      hasSavedKey = await _deepSeekService.hasApiKey();
    } on DeepSeekException catch (error) {
      _showMessage(error.message, isError: true);
      return;
    }

    if (!mounted) return;
    final controller = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('DeepSeek API key'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasSavedKey
                    ? 'A key is saved securely on this device. Enter a new key to replace it.'
                    : 'Enter your personal DeepSeek API key to enable chat and AI report summaries.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'API key',
                  hintText: 'Enter your DeepSeek API key',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'The key is stored using device secure storage and sent directly to DeepSeek. '
                'Inventory details included in your questions are also sent to DeepSeek.',
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          if (hasSavedKey)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'remove'),
              child: const Text('Remove key'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Enter an API key to save.')),
                );
                return;
              }
              Navigator.pop(dialogContext, 'save');
            },
            child: const Text('Save key'),
          ),
        ],
      ),
    );

    try {
      if (action == 'remove') {
        await _deepSeekService.removeApiKey();
        _showMessage('DeepSeek API key removed from this device.');
      } else if (action == 'save') {
        await _deepSeekService.saveApiKey(controller.text);
        _showMessage('DeepSeek API key saved securely on this device.');
      }
    } on DeepSeekException catch (error) {
      _showMessage(error.message, isError: true);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _generateReport() async {
    if (!_inventoryDataAvailable) {
      _showMessage(
        'Inventory data is unavailable. Refresh before generating a report.',
        isError: true,
      );
      return;
    }

    final report = _reportService.buildReport(
      period: _reportPeriod,
      now: DateTime.now(),
      products: products,
      categories: categories,
      suppliers: suppliers,
      transactions: transactions,
      notifications: notifications,
    );
    final requestId = ++_reportRequestId;

    setState(() {
      _generatedReport = report;
      _reportSummary = null;
      _reportError = null;
      _isGeneratingReport = true;
    });

    try {
      final summary = await _deepSeekService.reply(
        messages: const [
          {
            'role': 'user',
            'content':
                'Write a concise, professional executive summary of this inventory report. '
                'Use only the supplied data. Do not invent causes, quantities, suppliers, '
                'or trends. If the data does not establish a trend, say so.',
          },
        ],
        inventoryContext: report,
      );
      if (!mounted || requestId != _reportRequestId) return;
      setState(() {
        _reportSummary = summary;
        _isGeneratingReport = false;
      });
    } on DeepSeekException catch (error) {
      if (!mounted || requestId != _reportRequestId) return;
      setState(() {
        _reportError = error.message;
        _isGeneratingReport = false;
      });
    }
  }

  List<Map<String, dynamic>> _reportItems(String key) {
    final values = _generatedReport?[key];
    if (values is! List) return const [];
    return values
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  String _reportNumber(dynamic value) {
    if (value is num) {
      return value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(2);
    }
    return value?.toString() ?? '0';
  }

  Widget _buildChatTab() {
    final theme = Theme.of(context);
    const suggestedQuestions = [
      'Which products are critically low?',
      'What needs restocking?',
      'Summarize recent transactions.',
      'Which materials were issued most often?',
    ];

    return Column(
      children: [
        if (_messages.length == 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Answers are grounded in the inventory records stored on this device.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_messages.length == 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                for (final question in suggestedQuestions)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                      label: Text(question),
                      onPressed: _isSending || !_inventoryDataAvailable
                          ? null
                          : () => _sendMessage(question),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _chatScrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            itemCount: _messages.length + (_isSending ? 1 : 0),
            itemBuilder: (context, index) {
              if (_isSending && index == _messages.length) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                );
              }

              final message = _messages[index];
              final isUser = message.role == 'user';
              return Align(
                alignment: isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: SelectableText(
                    message.content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isUser
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      height: 1.4,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Ask about your inventory...',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send message',
                  onPressed: _isSending || !_inventoryDataAvailable
                      ? null
                      : _sendMessage,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportTab() {
    final theme = Theme.of(context);
    final report = _generatedReport;
    final stockLevels = _reportItems('stock_levels');
    final lowStock = _reportItems('low_stock_products');
    final criticalStock = _reportItems('critical_stock_products');
    final transactionsForPeriod = _reportItems('transactions');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Text(
          'AI Inventory Report',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Generate a factual report from your local inventory records.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 18),
        SegmentedButton<ReportPeriod>(
          segments: const [
            ButtonSegment(value: ReportPeriod.daily, label: Text('Daily')),
            ButtonSegment(value: ReportPeriod.weekly, label: Text('Weekly')),
            ButtonSegment(value: ReportPeriod.monthly, label: Text('Monthly')),
          ],
          selected: {_reportPeriod},
          onSelectionChanged: _isGeneratingReport
              ? null
              : (selection) {
                  setState(() {
                    _reportPeriod = selection.first;
                    _generatedReport = null;
                    _reportSummary = null;
                    _reportError = null;
                  });
                },
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _isGeneratingReport || !_inventoryDataAvailable
              ? null
              : _generateReport,
          icon: _isGeneratingReport
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome_rounded),
          label: Text(
            _isGeneratingReport ? 'Generating report...' : 'Generate report',
          ),
        ),
        if (report != null) ...[
          const SizedBox(height: 20),
          _buildReportCard(
            title: 'Executive Summary',
            icon: Icons.insights_rounded,
            child: Text(
              _reportSummary ??
                  (_isGeneratingReport
                      ? 'Preparing the AI summary...'
                      : _reportError == null
                      ? 'The AI summary has not been generated.'
                      : 'AI summary unavailable: $_reportError'),
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          _buildReportCard(
            title: '${report['period']} report',
            icon: Icons.calendar_month_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${report['period_start']} to ${report['period_end']}'),
                const SizedBox(height: 12),
                _reportFactRow('Total products', report['total_products']),
                _reportFactRow('Raw materials', report['raw_materials']),
                _reportFactRow(
                  'Finished products',
                  report['finished_products'],
                ),
                _reportFactRow('Suppliers', report['total_suppliers']),
                _reportFactRow('Out of stock', report['out_of_stock_count']),
                _reportFactRow('Low-stock products', report['low_stock_count']),
                _reportFactRow(
                  'Critical-stock products',
                  report['critical_stock_count'],
                ),
                _reportFactRow(
                  'Stock-in transactions',
                  (report['stock_in'] as Map)['transaction_count'],
                ),
                _reportFactRow(
                  'Quantity received',
                  (report['stock_in'] as Map)['quantity_total'],
                ),
                _reportFactRow(
                  'Stock-out transactions',
                  (report['stock_out'] as Map)['transaction_count'],
                ),
                _reportFactRow(
                  'Quantity issued',
                  (report['stock_out'] as Map)['quantity_total'],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildReportCard(
            title: 'Restocking recommendations',
            icon: Icons.shopping_cart_checkout_rounded,
            child: lowStock.isEmpty
                ? const Text('No products are below their minimum stock.')
                : Column(
                    children: [
                      for (final product in lowStock)
                        _reportProductRow(product, showRecommendation: true),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          _buildReportCard(
            title: 'Inventory trends',
            icon: Icons.trending_up_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Products with more stock-out transactions than the previous '
                  'equivalent period '
                  '(${report['previous_period_stock_out_count']} stock-outs in that period):',
                ),
                const SizedBox(height: 8),
                ..._reportItems('increased_stock_outs').map(
                  (product) => Text(
                    '• ${product['product']}: '
                    '${product['current_period_stock_outs']} vs '
                    '${product['previous_period_stock_outs']}',
                  ),
                ),
                if (_reportItems('increased_stock_outs').isEmpty)
                  const Text('No increases were found in the recorded data.'),
                const SizedBox(height: 12),
                const Text('Most frequently issued during this period:'),
                const SizedBox(height: 6),
                ..._reportItems('most_frequently_issued').map(
                  (item) => Text(
                    '• ${item['product']}: ${item['issue_count']} issues, '
                    '${_reportNumber(item['quantity_issued'])} ${item['unit']}',
                  ),
                ),
                if (_reportItems('most_frequently_issued').isEmpty)
                  const Text('No stock-out transactions were recorded.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildReportCard(
            title: 'Current stock levels (${stockLevels.length} products)',
            icon: Icons.inventory_2_rounded,
            child: stockLevels.isEmpty
                ? const Text('No products are recorded.')
                : ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('View all current stock levels'),
                    children: [
                      for (final product in stockLevels)
                        _reportProductRow(product),
                    ],
                  ),
          ),
          if (criticalStock.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildReportCard(
              title: 'Critical-stock products',
              icon: Icons.warning_amber_rounded,
              child: Column(
                children: [
                  for (final product in criticalStock)
                    _reportProductRow(product),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildReportCard(
            title:
                'Transactions (${report['transaction_count']} total, showing '
                '${transactionsForPeriod.length})',
            icon: Icons.receipt_long_rounded,
            child: transactionsForPeriod.isEmpty
                ? const Text('No transactions were recorded in this period.')
                : Column(
                    children: [
                      for (final transaction in transactionsForPeriod)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${transaction['type']} · ${transaction['product']}',
                          ),
                          subtitle: Text(
                            transaction['date']?.toString() ?? 'Unknown date',
                          ),
                          trailing: Text(
                            '${_reportNumber(transaction['quantity'])} '
                            '${transaction['unit']}',
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => InventoryReportPreviewScreen(
                    report: report,
                    executiveSummary:
                        _reportSummary ??
                        'AI-generated executive summary unavailable: '
                            '${_reportError ?? 'not generated'}',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('View and export PDF'),
          ),
        ],
      ],
    );
  }

  Widget _buildReportCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _reportFactRow(String title, dynamic value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          Text(
            _reportNumber(value),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportProductRow(
    Map<String, dynamic> product, {
    bool showRecommendation = false,
  }) {
    final name = product['name'] ?? product['product'] ?? 'Unknown product';
    final quantity = _reportNumber(product['quantity']);
    final unit = product['unit']?.toString() ?? '';
    final status = product['status']?.toString();
    final recommendation = _reportNumber(
      product['recommended_restock_quantity'],
    );

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(name.toString()),
      subtitle: Text(
        '$quantity $unit · Minimum ${_reportNumber(product['minimum_stock'])}'
        '${status == null ? '' : ' · $status'}'
        '${showRecommendation ? ' · Suggested order: $recommendation $unit' : ''}',
      ),
      isThreeLine: showRecommendation,
    );
  }

  // ============================================================
  // WELCOME CARD
  // ============================================================

  Widget _buildWelcomeCard() {
    final theme = Theme.of(context);
    final fullName = widget.user['full_name']?.toString() ?? 'User';

    final firstName = fullName.split(' ').first;

    final attentionCount =
        criticalStockProducts.length + lowStockProducts.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$attentionCount attention item'
                  '${attentionCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Hello, $firstName 👋',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            attentionCount == 0
                ? 'Your inventory is currently in good condition.'
                : 'Here is what needs your attention today.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INVENTORY HEALTH
  // ============================================================

  Widget _buildInventoryHealth() {
    final totalProducts = _intStat('total_products');
    final totalSuppliers = _intStat('total_suppliers');
    final lowStock = _intStat('low_stock_items');
    final critical = _intStat('critical_stock_items');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Inventory Health',
          'Current inventory status',
          Icons.health_and_safety_rounded,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildHealthCard(
                title: 'Products',
                value: totalProducts.toString(),
                icon: Icons.inventory_2_rounded,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildHealthCard(
                title: 'Suppliers',
                value: totalSuppliers.toString(),
                icon: Icons.local_shipping_rounded,
                color: Colors.deepPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildHealthCard(
                title: 'Low Stock',
                value: lowStock.toString(),
                icon: Icons.inventory_rounded,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildHealthCard(
                title: 'Critical',
                value: critical.toString(),
                icon: Icons.warning_rounded,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHealthCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearch() {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        onChanged: (value) {
          setState(() {
            searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search inventory...',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: theme.colorScheme.primary,
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear search',
                  icon: Icon(
                    Icons.clear_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  onPressed: () {
                    searchController.clear();

                    setState(() {
                      searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: theme.cardColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CRITICAL STOCK
  // ============================================================

  Widget _buildCriticalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Needs Immediate Attention',
          '${criticalStockProducts.length} critical item'
              '${criticalStockProducts.length == 1 ? '' : 's'}',
          Icons.warning_rounded,
          iconColor: Colors.red,
        ),
        const SizedBox(height: 12),
        ...criticalStockProducts.take(5).map(_buildCriticalProductCard),
      ],
    );
  }

  Widget _buildCriticalProductCard(Product product) {
    final theme = Theme.of(context);
    final recommended = _recommendedQuantity(product);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildProductIcon(product, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.itemType,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(product),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildStockValue(
                  'Current',
                  '${_formatQuantity(product.quantity)} ${product.unit}',
                  Colors.red,
                ),
              ),
              Expanded(
                child: _buildStockValue(
                  'Minimum',
                  '${_formatQuantity(product.minimumStock)} ${product.unit}',
                  Colors.orange,
                ),
              ),
              Expanded(
                child: _buildStockValue(
                  'Suggested',
                  '${_formatQuantity(recommended)} ${product.unit}',
                  theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showRestockDialog(product),
              icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
              label: const Text('Restock Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOW STOCK
  // ============================================================

  Widget _buildLowStockSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Low Stock',
          '${lowStockProducts.length} item'
              '${lowStockProducts.length == 1 ? '' : 's'} below minimum',
          Icons.inventory_rounded,
          iconColor: Colors.orange,
        ),
        const SizedBox(height: 12),
        ...lowStockProducts
            .where((product) => !_isCritical(product))
            .take(5)
            .map(_buildLowStockProductCard),
      ],
    );
  }

  Widget _buildLowStockProductCard(Product product) {
    final theme = Theme.of(context);
    final recommended = _recommendedQuantity(product);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          _buildProductIcon(product, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Stock: ${_formatQuantity(product.quantity)} ${product.unit}'
                  '  •  Min: ${_formatQuantity(product.minimumStock)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Recommended: ${_formatQuantity(recommended)} ${product.unit}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Restock',
            onPressed: () => _showRestockDialog(product),
            icon: Icon(
              Icons.shopping_cart_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SMART RECOMMENDATION
  // ============================================================

  Widget _buildSmartRecommendation() {
    final theme = Theme.of(context);
    Product? recommendation;

    if (criticalStockProducts.isNotEmpty) {
      recommendation = criticalStockProducts.first;
    } else if (lowStockProducts.isNotEmpty) {
      recommendation = lowStockProducts.first;
    }

    if (recommendation == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart Recommendation',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No restocking action is currently required.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final recommendedQuantity = _recommendedQuantity(recommendation);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.08),
            theme.colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Recommendation',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Suggested action based on stock level',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            recommendation.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Current stock is ${_formatQuantity(recommendation.quantity)} '
            '${recommendation.unit}. '
            'The recommended order quantity is '
            '${_formatQuantity(recommendedQuantity)} '
            '${recommendation.unit}.',
            style: theme.textTheme.bodySmall?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRestockDialog(recommendation!),
                  icon: const Icon(Icons.edit_rounded, size: 17),
                  label: const Text('Review'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    side: BorderSide(color: theme.colorScheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showRestockDialog(recommendation!),
                  icon: const Icon(Icons.chat_rounded, size: 17),
                  label: const Text('Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Quick Actions',
          'Manage your inventory',
          Icons.flash_on_rounded,
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.65,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildActionCard(
              title: 'Stock In',
              subtitle: 'Receive items',
              icon: Icons.add_box_rounded,
              color: theme.colorScheme.primary,
              onTap: () {
                // Replace with your StockInScreen if needed.
                _showMessage('Open Stock In from the dashboard.');
              },
            ),
            _buildActionCard(
              title: 'Stock Out',
              subtitle: 'Issue items',
              icon: Icons.indeterminate_check_box_rounded,
              color: Colors.orange,
              onTap: () {
                _showMessage('Open Stock Out from the dashboard.');
              },
            ),
            _buildActionCard(
              title: 'Products',
              subtitle: 'Manage products',
              icon: Icons.inventory_2_rounded,
              color: Colors.blue,
              onTap: () {
                _showMessage('Open Products from the dashboard.');
              },
            ),
            _buildActionCard(
              title: 'Suppliers',
              subtitle: 'Manage suppliers',
              icon: Icons.local_shipping_rounded,
              color: Colors.deepPurple,
              onTap: () {
                _showMessage('Open Suppliers from the dashboard.');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RECENT ACTIVITY
  // ============================================================

  Widget _buildRecentActivity() {
    final theme = Theme.of(context);
    final recent = transactions.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Recent Activity',
          'Latest inventory movements',
          Icons.history_rounded,
        ),
        const SizedBox(height: 12),
        if (recent.isEmpty)
          _buildEmptyCard(
            icon: Icons.history_toggle_off_rounded,
            title: 'No recent activity',
            subtitle: 'Inventory transactions will appear here.',
          )
        else
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              children: [
                for (int i = 0; i < recent.length; i++) ...[
                  _buildTransactionItem(recent[i]),
                  if (i != recent.length - 1)
                    Divider(
                      height: 1,
                      indent: 70,
                      endIndent: 15,
                      color: theme.dividerColor,
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTransactionItem(InventoryTransaction transaction) {
    final theme = Theme.of(context);
    final isStockIn = transaction.isStockIn;

    final iconColor = isStockIn
        ? theme.colorScheme.primary
        : Colors.orange.shade700;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              isStockIn
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: iconColor,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.productName ?? 'Unknown product',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  transaction.transactionType,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDate(transaction.transactionDate)} '
                  '${_formatTime(transaction.transactionDate)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isStockIn ? '+' : '-'}'
            '${_formatQuantity(transaction.quantity)} '
            '${transaction.unit ?? ''}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INVENTORY INSIGHTS
  // ============================================================

  Widget _buildInventoryInsights() {
    final theme = Theme.of(context);
    final rawMaterials = products
        .where((product) => product.normalizedItemType.contains('raw material'))
        .length;

    final finishedProducts = products
        .where(
          (product) => product.normalizedItemType.contains('finished product'),
        )
        .length;

    final healthyProducts = products
        .where((product) => product.quantity > 0 && !_isLowStock(product))
        .length;

    final outOfStock = products
        .where((product) => product.quantity <= 0)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Inventory Insights',
          'Quick analysis of your stock',
          Icons.analytics_rounded,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            children: [
              _buildInsightRow(
                icon: Icons.check_circle_rounded,
                color: theme.colorScheme.primary,
                title: 'Healthy Products',
                value: healthyProducts.toString(),
              ),
              _buildInsightDivider(),
              _buildInsightRow(
                icon: Icons.factory_rounded,
                color: Colors.blue,
                title: 'Raw Materials',
                value: rawMaterials.toString(),
              ),
              _buildInsightDivider(),
              _buildInsightRow(
                icon: Icons.inventory_2_rounded,
                color: Colors.deepPurple,
                title: 'Finished Products',
                value: finishedProducts.toString(),
              ),
              _buildInsightDivider(),
              _buildInsightRow(
                icon: Icons.remove_shopping_cart_rounded,
                color: theme.colorScheme.error,
                title: 'Out of Stock',
                value: outOfStock.toString(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightRow({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildInsightDivider() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Divider(height: 1, color: theme.dividerColor),
    );
  }

  // ============================================================
  // PRODUCT STATUS LIST
  // ============================================================

  Widget _buildProductStatusList() {
    final filtered = _filteredProducts;

    if (searchQuery.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Search Results',
          '${filtered.length} product'
              '${filtered.length == 1 ? '' : 's'} found',
          Icons.search_rounded,
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          _buildEmptyCard(
            icon: Icons.search_off_rounded,
            title: 'No products found',
            subtitle: 'Try another search term.',
          )
        else
          ...filtered.map(_buildSearchProductCard),
      ],
    );
  }

  Widget _buildSearchProductCard(Product product) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          _buildProductIcon(product, color: _stockStatusColor(product)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatQuantity(product.quantity)} ${product.unit}'
                  ' • Min ${_formatQuantity(product.minimumStock)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          _buildStatusBadge(product),
        ],
      ),
    );
  }

  // ============================================================
  // RESTOCK DIALOG
  // ============================================================

  Future<void> _showRestockDialog(Product product) async {
    final recommended = _recommendedQuantity(product);

    final quantityController = TextEditingController(
      text: recommended > 0 ? _formatQuantity(recommended) : '',
    );

    final notesController = TextEditingController();

    Supplier? supplier;
    bool loadingSupplier = true;
    List<Supplier> allSuppliers = [];

    try {
      supplier = await inventoryService.getPrimarySupplier(product.id);
      allSuppliers = await inventoryService.getSuppliersForProduct(product.id);
    } catch (_) {
      supplier = null;
      allSuppliers = [];
    } finally {
      loadingSupplier = false;
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool isOpening = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> orderViaWhatsApp() async {
              final quantity = double.tryParse(quantityController.text.trim());

              if (quantity == null || quantity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid order quantity.'),
                  ),
                );
                return;
              }

              if (supplier == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'No supplier assigned. Please assign a primary supplier first.',
                    ),
                  ),
                );
                return;
              }

              if (supplier?.phone.trim().isEmpty ?? true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('The supplier does not have a phone number.'),
                  ),
                );
                return;
              }

              setDialogState(() {
                isOpening = true;
              });

              try {
                final success = await inventoryService.sendCustomSupplierOrder(
                  productId: product.id,
                  quantity: quantity,
                  notes: notesController.text.trim(),
                );

                if (!mounted) return;

                if (success) {
                  Navigator.pop(dialogContext);

                  _showMessage('WhatsApp opened with your supplier order.');
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not open WhatsApp. Check the supplier phone number.',
                        ),
                      ),
                    );
                  }
                }
              } catch (_) {
                if (!mounted) return;

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not send supplier order.'),
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setDialogState(() {
                    isOpening = false;
                  });
                }
              }
            }

            final dialogTheme = Theme.of(context);

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              actionsPadding: const EdgeInsets.fromLTRB(20, 5, 20, 18),
              title: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: dialogTheme.colorScheme.primary.withValues(
                        alpha: 0.10,
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.shopping_cart_checkout_rounded,
                      color: dialogTheme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Text(
                      'Restock Product',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${product.itemType} • ${product.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 17),

                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildDialogStockValue(
                              'Current',
                              '${_formatQuantity(product.quantity)} '
                                  '${product.unit}',
                            ),
                          ),
                          Expanded(
                            child: _buildDialogStockValue(
                              'Minimum',
                              '${_formatQuantity(product.minimumStock)} '
                                  '${product.unit}',
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (loadingSupplier)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: dialogTheme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Loading supplier...',
                              style: dialogTheme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      )
                    else if (supplier != null)
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF25D366,
                          ).withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_shipping_rounded,
                              color: dialogTheme.colorScheme.primary,
                              size: 21,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Primary Supplier',
                                    style: dialogTheme.textTheme.labelSmall
                                        ?.copyWith(
                                          color: dialogTheme
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.7),
                                        ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    supplier!.name,
                                    style: dialogTheme.textTheme.bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    supplier!.phone,
                                    style: dialogTheme.textTheme.labelSmall
                                        ?.copyWith(
                                          color: dialogTheme
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.7),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange,
                                  size: 21,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'No supplier assigned to this product',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (allSuppliers.isEmpty)
                              Text(
                                'No suppliers available. Add suppliers to this product.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Select supplier:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: DropdownButton<Supplier>(
                                      isExpanded: true,
                                      hint: const Text('Choose a supplier'),
                                      items: allSuppliers
                                          .map(
                                            (s) => DropdownMenuItem(
                                              value: s,
                                              child: Text(s.name),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (Supplier? selected) {
                                        if (selected != null) {
                                          setDialogState(() {
                                            supplier = selected;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 17),

                    const Text(
                      'Order Quantity',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),

                    TextField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter quantity',
                        suffixText: product.unit,
                        prefixIcon: Icon(
                          Icons.numbers_rounded,
                          color: dialogTheme.colorScheme.primary,
                        ),
                        filled: true,
                        fillColor: dialogTheme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 14,
                        ),
                      ),
                    ),

                    const SizedBox(height: 7),

                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: dialogTheme.colorScheme.primary,
                          size: 15,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Suggested: '
                          '${_formatQuantity(recommended)} '
                          '${product.unit}',
                          style: dialogTheme.textTheme.labelSmall?.copyWith(
                            color: dialogTheme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            quantityController.text = _formatQuantity(
                              recommended,
                            );
                          },
                          child: const Text('Use Suggested'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'Notes',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),

                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Optional message for the supplier...',
                        filled: true,
                        fillColor: dialogTheme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(13),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isOpening
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancel',
                    style: dialogTheme.textTheme.labelLarge?.copyWith(
                      color: dialogTheme.colorScheme.onSurface.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isOpening || supplier == null
                      ? null
                      : orderViaWhatsApp,
                  icon: isOpening
                      ? SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: dialogTheme.colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.chat_rounded, size: 18),
                  label: Text(
                    isOpening
                        ? 'Opening...'
                        : supplier == null
                        ? 'Assign Supplier First'
                        : 'Order via WhatsApp',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade400,
                    disabledForegroundColor: Colors.grey.shade600,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    quantityController.dispose();
    notesController.dispose();
  }

  // ============================================================
  // SMALL UI HELPERS
  // ============================================================

  Widget _buildSectionTitle(
    String title,
    String subtitle,
    IconData icon, {
    Color iconColor = Colors.green,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 37,
          height: 37,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: iconColor, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductIcon(Product product, {required Color color}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(Icons.inventory_2_rounded, color: color, size: 21),
    );
  }

  Widget _buildStatusBadge(Product product) {
    final color = _stockStatusColor(product);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_stockStatusIcon(product), color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            _stockStatus(product),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockValue(String title, String value, Color color) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildDialogStockValue(String title, String value) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 35,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 9),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
