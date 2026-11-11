import 'package:flutter/material.dart';

import '../services/inventory_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final InventoryService inventoryService = InventoryService();

  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  // ------------------------------------------------------------
  // LOAD NOTIFICATIONS
  // ------------------------------------------------------------

  Future<void> _loadNotifications() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final result = await inventoryService.getNotifications();

      if (!mounted) return;

      setState(() {
        notifications = result;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showMessage(
        'Failed to load notifications.',
        isError: true,
      );
    }
  }

  // ------------------------------------------------------------
  // MARK AS READ
  // ------------------------------------------------------------

  Future<void> _markAsRead(int id) async {
    try {
      await inventoryService.markNotificationAsRead(id);

      await _loadNotifications();
    } catch (e) {
      _showMessage(
        'Could not mark notification as read.',
        isError: true,
      );
    }
  }

  // ------------------------------------------------------------
  // DELETE NOTIFICATION
  // ------------------------------------------------------------

  Future<void> _deleteNotification(int id) async {
    try {
      await inventoryService.deleteNotification(id);

      await _loadNotifications();

      if (!mounted) return;

      _showMessage('Notification deleted.');
    } catch (e) {
      _showMessage(
        'Could not delete notification.',
        isError: true,
      );
    }
  }

  // ------------------------------------------------------------
  // DELETE ALL READ NOTIFICATIONS
  // ------------------------------------------------------------

  Future<void> _deleteReadNotifications() async {
    final readNotifications = notifications
        .where((notification) =>
            (notification['is_read'] ?? 0).toString() == '1')
        .toList();

    if (readNotifications.isEmpty) {
      _showMessage('There are no read notifications to delete.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete read notifications?'),
          content: Text(
            'This will delete ${readNotifications.length} read notification'
            '${readNotifications.length == 1 ? '' : 's'}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      for (final notification in readNotifications) {
        final id = _toInt(notification['id']);

        if (id != null) {
          await inventoryService.deleteNotification(id);
        }
      }

      await _loadNotifications();

      if (!mounted) return;

      _showMessage('Read notifications deleted.');
    } catch (e) {
      _showMessage(
        'Could not delete notifications.',
        isError: true,
      );
    }
  }

  // ------------------------------------------------------------
  // NOTIFICATION DETAILS
  // ------------------------------------------------------------

  Future<void> _openNotification(
    Map<String, dynamic> notification,
  ) async {
    final id = _toInt(notification['id']);

    final isRead = _isRead(notification);

    if (!isRead && id != null) {
      await _markAsRead(id);
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _NotificationDetails(
          notification: notification,
        );
      },
    );
  }

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------

  int? _toInt(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;

    return int.tryParse(value.toString());
  }

  bool _isRead(Map<String, dynamic> notification) {
    final value = notification['is_read'];

    if (value is bool) return value;

    return value.toString() == '1';
  }

  String _notificationType(Map<String, dynamic> notification) {
    return (notification['notification_type'] ?? 'General')
        .toString()
        .toLowerCase();
  }

  String _title(Map<String, dynamic> notification) {
    return (notification['title'] ?? 'Notification').toString();
  }

  String _message(Map<String, dynamic> notification) {
    return (notification['message'] ?? '').toString();
  }

  DateTime? _notificationDate(
    Map<String, dynamic> notification,
  ) {
    final value = notification['created_at'];

    if (value == null) return null;

    return DateTime.tryParse(value.toString());
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';

    final localDate = date.toLocal();

    final now = DateTime.now();
    final difference = now.difference(localDate);

    if (difference.inSeconds < 60) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }

    if (difference.inDays == 1) {
      return 'Yesterday';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }

    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');

    return '$day/$month/${localDate.year}';
  }

  int get unreadCount {
    return notifications.where((notification) {
      return !_isRead(notification);
    }).length;
  }

  int get criticalCount {
    return notifications.where((notification) {
      final type = _notificationType(notification);
      return type.contains('critical');
    }).length;
  }

  int get lowStockCount {
    return notifications.where((notification) {
      final type = _notificationType(notification);
      return type.contains('low');
    }).length;
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? Colors.red.shade700
              : const Color(0xFF379805),
        ),
      );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF379805);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,

        title: Row(
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),

            if (unreadCount > 0) ...[
              const SizedBox(width: 10),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: primaryGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),

        actions: [
          if (notifications.any((notification) => _isRead(notification)))
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'delete_read') {
                  _deleteReadNotifications();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'delete_read',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_sweep_outlined,
                        color: Colors.red,
                      ),
                      SizedBox(width: 10),
                      Text('Delete read'),
                    ],
                  ),
                ),
              ],
            ),

          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadNotifications,
            icon: const Icon(Icons.refresh),
          ),

          const SizedBox(width: 4),
        ],
      ),

      body: RefreshIndicator(
        color: primaryGreen,
        onRefresh: _loadNotifications,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF379805),
        ),
      );
    }

    if (notifications.isEmpty) {
      return _buildEmptyState();
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _buildSummary(),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            24,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final notification = notifications[index];

                return _buildNotificationCard(
                  notification,
                );
              },
              childCount: notifications.length,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // SUMMARY
  // ------------------------------------------------------------

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inventory Alerts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            unreadCount == 0
                ? 'You are all caught up.'
                : '$unreadCount unread inventory alert'
                    '${unreadCount == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  icon: Icons.notifications_active_outlined,
                  title: 'Unread',
                  value: '$unreadCount',
                  iconColor: const Color(0xFF379805),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _summaryCard(
                  icon: Icons.warning_amber_rounded,
                  title: 'Low Stock',
                  value: '$lowStockCount',
                  iconColor: Colors.orange,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _summaryCard(
                  icon: Icons.error_outline_rounded,
                  title: 'Critical',
                  value: '$criticalCount',
                  iconColor: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 22,
          ),

          const SizedBox(height: 9),

          Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // NOTIFICATION CARD
  // ------------------------------------------------------------

  Widget _buildNotificationCard(
    Map<String, dynamic> notification,
  ) {
    final isRead = _isRead(notification);
    final type = _notificationType(notification);

    final isCritical = type.contains('critical');
    final isLowStock = type.contains('low');

    final Color iconColor;

    if (isCritical) {
      iconColor = Colors.red;
    } else if (isLowStock) {
      iconColor = Colors.orange;
    } else {
      iconColor = const Color(0xFF379805);
    }

    final IconData icon;

    if (isCritical) {
      icon = Icons.error_rounded;
    } else if (isLowStock) {
      icon = Icons.warning_amber_rounded;
    } else {
      icon = Icons.notifications_active_rounded;
    }

    return Dismissible(
      key: ValueKey(
        notification['id'] ??
            '${notification['title']}_${notification['created_at']}',
      ),

      direction: DismissDirection.endToStart,

      confirmDismiss: (direction) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Delete notification?'),
              content: const Text(
                'This notification will be permanently removed.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    false,
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(
                    context,
                    true,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );

        return confirmed ?? false;
      },

      onDismissed: (_) {
        final id = _toInt(notification['id']);

        if (id != null) {
          _deleteNotification(id);
        }
      },

      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 28,
        ),
      ),

      child: Container(
        margin: const EdgeInsets.only(bottom: 12),

        decoration: BoxDecoration(
          color: isRead
              ? Colors.white
              : const Color(0xFFF1F8EE),

          borderRadius: BorderRadius.circular(18),

          border: Border.all(
            color: isRead
                ? Colors.grey.shade200
                : const Color(0xFF379805).withValues(alpha: 0.25),
          ),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),

        child: Material(
          color: Colors.transparent,

          child: InkWell(
            borderRadius: BorderRadius.circular(18),

            onTap: () => _openNotification(
              notification,
            ),

            child: Padding(
              padding: const EdgeInsets.all(15),

              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ICON
                  Container(
                    width: 46,
                    height: 46,

                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),

                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 23,
                    ),
                  ),

                  const SizedBox(width: 13),

                  // CONTENT
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                _title(notification),
                                maxLines: 2,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isRead
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                            ),

                            if (!isRead)
                              Container(
                                width: 9,
                                height: 9,
                                margin:
                                    const EdgeInsets.only(
                                  top: 5,
                                  left: 8,
                                ),
                                decoration:
                                    const BoxDecoration(
                                  color:
                                      Color(0xFF379805),
                                  shape:
                                      BoxShape.circle,
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        Text(
                          _message(notification),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Colors.grey.shade700,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Row(
                          children: [
                            _typeBadge(
                              type: type,
                              isCritical: isCritical,
                              isLowStock: isLowStock,
                            ),

                            const SizedBox(width: 8),

                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),

                            const SizedBox(width: 4),

                            Expanded(
                              child: Text(
                                _formatDate(
                                  _notificationDate(
                                    notification,
                                  ),
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 4),

                  // MENU
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_vert,
                      color: Colors.grey.shade600,
                    ),
                    onSelected: (value) {
                      final id =
                          _toInt(notification['id']);

                      if (id == null) return;

                      if (value == 'read') {
                        _markAsRead(id);
                      } else if (value == 'delete') {
                        _deleteNotification(id);
                      }
                    },
                    itemBuilder: (context) => [
                      if (!isRead)
                        const PopupMenuItem<String>(
                          value: 'read',
                          child: Row(
                            children: [
                              Icon(
                                Icons.done,
                                color: Color(0xFF379805),
                              ),
                              SizedBox(width: 10),
                              Text('Mark as read'),
                            ],
                          ),
                        ),

                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            SizedBox(width: 10),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeBadge({
    required String type,
    required bool isCritical,
    required bool isLowStock,
  }) {
    final String label;
    final Color color;

    if (isCritical) {
      label = 'CRITICAL';
      color = Colors.red;
    } else if (isLowStock) {
      label = 'LOW STOCK';
      color = Colors.orange;
    } else {
      label = type.isEmpty
          ? 'GENERAL'
          : type.toUpperCase();
      color = const Color(0xFF379805);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // EMPTY STATE
  // ------------------------------------------------------------

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),

      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.25,
        ),

        Center(
          child: Container(
            width: 100,
            height: 100,

            decoration: BoxDecoration(
              color: const Color(0xFF379805)
                  .withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),

            child: const Icon(
              Icons.notifications_none_rounded,
              size: 52,
              color: Color(0xFF379805),
            ),
          ),
        ),

        const SizedBox(height: 22),

        const Center(
          child: Text(
            'No Notifications',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ),

        const SizedBox(height: 8),

        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 40,
            ),
            child: Text(
              'You do not have any inventory alerts at the moment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 22),

        Center(
          child: OutlinedButton.icon(
            onPressed: _loadNotifications,
            icon: const Icon(
              Icons.refresh,
              size: 18,
            ),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  const Color(0xFF379805),
              side: const BorderSide(
                color: Color(0xFF379805),
              ),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// NOTIFICATION DETAILS BOTTOM SHEET
// ============================================================

class _NotificationDetails extends StatelessWidget {
  final Map<String, dynamic> notification;

  const _NotificationDetails({
    required this.notification,
  });

  String _type() {
    return (notification['notification_type'] ??
            'General')
        .toString()
        .toLowerCase();
  }

  String _title() {
    return (notification['title'] ?? 'Notification')
        .toString();
  }

  String _message() {
    return (notification['message'] ?? '')
        .toString();
  }

  String _createdAt() {
    final value = notification['created_at'];

    if (value == null) {
      return 'Unknown';
    }

    final date = DateTime.tryParse(
      value.toString(),
    );

    if (date == null) {
      return value.toString();
    }

    final local = date.toLocal();

    final day =
        local.day.toString().padLeft(2, '0');

    final month =
        local.month.toString().padLeft(2, '0');

    final hour = local.hour
        .toString()
        .padLeft(2, '0');

    final minute = local.minute
        .toString()
        .padLeft(2, '0');

    return '$day/$month/${local.year} '
        '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final type = _type();

    final bool isCritical =
        type.contains('critical');

    final bool isLow =
        type.contains('low');

    final Color color;

    final IconData icon;

    if (isCritical) {
      color = Colors.red;
      icon = Icons.error_rounded;
    } else if (isLow) {
      color = Colors.orange;
      icon = Icons.warning_amber_rounded;
    } else {
      color = const Color(0xFF379805);
      icon = Icons.notifications_active_rounded;
    }

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 20 +
            MediaQuery.of(context)
                .viewInsets
                .bottom,
      ),

      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),

      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius:
                      BorderRadius.circular(20),
                ),
              ),
            ),

            const SizedBox(height: 22),

            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 26,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Text(
                    _title(),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius:
                    BorderRadius.circular(16),
              ),
              child: Text(
                _message(),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: Colors.black87,
                ),
              ),
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 18,
                  color: Colors.grey.shade600,
                ),

                const SizedBox(width: 8),

                Text(
                  'Type: ',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),

                Text(
                  type.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: Colors.grey.shade600,
                ),

                const SizedBox(width: 8),

                Text(
                  'Created: ',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),

                Text(
                  _createdAt(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF379805),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

