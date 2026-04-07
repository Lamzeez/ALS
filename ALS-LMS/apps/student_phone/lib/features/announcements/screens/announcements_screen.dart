import 'package:flutter/material.dart';
import 'package:shared_services/shared_services.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_ui/shared_ui.dart';

/// Screen showing course announcements with optional comment support.
class AnnouncementsScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final bool embedded;

  const AnnouncementsScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
    this.embedded = false,
  });

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _announcementService = AnnouncementService();
  List<Announcement> _announcements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoading = true);
    try {
      _announcements =
          await _announcementService.getCourseAnnouncements(widget.courseId);
    } catch (e) {
      debugPrint('Error loading announcements: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _announcements.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: _loadAnnouncements,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _announcements.length,
                  itemBuilder: (context, index) {
                    return _buildAnnouncementCard(_announcements[index]);
                  },
                ),
              );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseTitle),
      ),
      body: body,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign_outlined, size: 80, color: AlsColors.textHint),
          const SizedBox(height: 16),
          Text(
            'No Announcements Yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Your teacher hasn\'t posted any\nannouncements for this course.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AlsColors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(Announcement announcement) {
    final timeAgo = _formatTimeAgo(announcement.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: announcement.isPinned
                  ? AlsColors.accentLight.withValues(alpha: 0.15)
                  : null,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AlsColors.primarySurface,
                  child: Icon(Icons.person, size: 20, color: AlsColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        announcement.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      Text(
                        timeAgo,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (announcement.isPinned)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AlsColors.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin,
                            size: 12, color: AlsColors.accentDark),
                        const SizedBox(width: 4),
                        Text(
                          'Pinned',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AlsColors.accentDark,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              announcement.content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: AlsColors.textPrimary,
                  ),
            ),
          ),

          // Comment action
          if (announcement.allowComments)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AlsColors.divider),
                ),
              ),
              child: TextButton.icon(
                onPressed: () => _showCommentSheet(announcement),
                icon: Icon(Icons.comment_outlined,
                    size: 18, color: AlsColors.textSecondary),
                label: Text(
                  'Comment',
                  style:
                      TextStyle(color: AlsColors.textSecondary, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showCommentSheet(Announcement announcement) {
    final commentController = TextEditingController();
    final outerContext = context;

    showModalBottomSheet(
      context: outerContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AlsColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Comments',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),

                // Comments list
                Expanded(
                  child: FutureBuilder<List<AnnouncementComment>>(
                    future: _announcementService.getComments(announcement.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final comments = snapshot.data ?? [];
                      if (comments.isEmpty) {
                        return Center(
                          child: Text(
                            'No comments yet. Be the first!',
                            style: TextStyle(color: AlsColors.textHint),
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: comments.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: AlsColors.primarySurface,
                              child: Icon(Icons.person,
                                  size: 16, color: AlsColors.primary),
                            ),
                            title: Text(comment.content),
                            subtitle: Text(
                              _formatTimeAgo(comment.createdAt),
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Comment input
                Container(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    8 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: AlsColors.surface,
                    border: Border(top: BorderSide(color: AlsColors.divider)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentController,
                          decoration: InputDecoration(
                            hintText: 'Write a comment...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: AlsColors.surfaceVariant,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () async {
                          final text = commentController.text.trim();
                          if (text.isEmpty) return;
                          try {
                            await _announcementService.addComment(
                              announcementId: announcement.id,
                              content: text,
                            );
                            commentController.clear();
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(outerContext).showSnackBar(
                                SnackBar(
                                  content: const Text('Comment posted!'),
                                  backgroundColor: AlsColors.success,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(outerContext).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to post comment: $e'),
                                  backgroundColor: AlsColors.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon:
                            Icon(Icons.send_rounded, color: AlsColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
