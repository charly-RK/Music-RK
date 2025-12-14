import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class NotificacionesPage extends StatefulWidget {
  const NotificacionesPage({super.key});

  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  List<Map<String, dynamic>> _notificaciones = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final notifs = await DatabaseHelper.instance.getAllNotifications();
    if (mounted) {
      setState(() {
        _notificaciones = notifs;
        _isLoading = false;
      });
    }
  }

  void _marcarComoLeida(int index) async {
    final notif = _notificaciones[index];
    await DatabaseHelper.instance.markNotificationAsRead(notif['id']);
    await _loadNotifications();
  }

  void _marcarTodasComoLeidas() async {
    await DatabaseHelper.instance.markAllNotificationsAsRead();
    await _loadNotifications();
  }

  void _eliminarNotificacion(int index) async {
    final notif = _notificaciones[index];
    await DatabaseHelper.instance.deleteNotification(notif['id']);
    // No need to reload, just remove from list
    setState(() {
      _notificaciones.removeAt(index);
    });
  }

  String _formatearFecha(String fechaStr) {
    final fecha = DateTime.parse(fechaStr);
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);

    if (diferencia.inMinutes < 60) {
      return 'Hace ${diferencia.inMinutes} min';
    } else if (diferencia.inHours < 24) {
      return 'Hace ${diferencia.inHours} h';
    } else if (diferencia.inDays == 1) {
      return 'Ayer';
    } else if (diferencia.inDays < 7) {
      return 'Hace ${diferencia.inDays} días';
    } else {
      final day = fecha.day.toString().padLeft(2, '0');
      final month = fecha.month.toString().padLeft(2, '0');
      final year = fecha.year;
      return '$day/$month/$year';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // Header Background
          Container(
            height: 180,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1F3D), Color(0xFF2A2948)],
              ),
            ),
          ),
          
          SafeArea(
            child: StreamBuilder<void>(
              stream: DatabaseHelper.instance.notificationsStream,
              builder: (context, snapshot) {
                // Reload when stream emits
                if (snapshot.hasData) {
                  _loadNotifications();
                }
                
                final notificacionesNoLeidas = _notificaciones.where((n) => n['leida'] == 0).length;

                return Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              "Notificaciones",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (notificacionesNoLeidas > 0)
                            TextButton.icon(
                              onPressed: _marcarTodasComoLeidas,
                              icon: const Icon(Icons.done_all, color: Colors.white70, size: 18),
                              label: const Text(
                                "Marcar todas",
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Notification Count Badge
                    if (notificacionesNoLeidas > 0)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "$notificacionesNoLeidas ${notificacionesNoLeidas == 1 ? 'notificación nueva' : 'notificaciones nuevas'}",
                          style: const TextStyle(
                            color: Color(0xFFE91E63),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    // Notifications List
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, -5),
                            ),
                          ],
                        ),
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                            : _notificaciones.isEmpty
                                ? _buildEmptyState()
                                : RefreshIndicator(
                                    onRefresh: _loadNotifications,
                                    color: const Color(0xFFE91E63),
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                                      child: ListView.separated(
                                        padding: const EdgeInsets.only(top: 20, bottom: 20),
                                        itemCount: _notificaciones.length,
                                        separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
                                        itemBuilder: (context, index) {
                                          return _buildNotificationItem(index);
                                        },
                                      ),
                                    ),
                                  ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No hay notificaciones",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tus descargas aparecerán aquí",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(int index) {
    final notif = _notificaciones[index];
    final bool esAlbum = notif['tipo'] == 'album';
    final bool leida = notif['leida'] == 1;

    return Dismissible(
      key: Key('notif_${notif['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      onDismissed: (direction) {
        _eliminarNotificacion(index);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notificación eliminada'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF1A1F3D),
          ),
        );
      },
      child: Material(
        color: leida ? Colors.white : const Color(0xFFE91E63).withOpacity(0.05),
        child: InkWell(
          onTap: () => _marcarComoLeida(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: esAlbum 
                        ? const Color(0xFF2196F3).withOpacity(0.1)
                        : const Color(0xFFE91E63).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    esAlbum ? Icons.album_rounded : Icons.music_note_rounded,
                    color: esAlbum ? const Color(0xFF2196F3) : const Color(0xFFE91E63),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notif['titulo'],
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: leida ? FontWeight.w600 : FontWeight.bold,
                                color: const Color(0xFF1A1F3D),
                              ),
                            ),
                          ),
                          if (!leida)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE91E63),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notif['descripcion'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            esAlbum ? Icons.library_music : Icons.music_note,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${notif['cantidad']} ${esAlbum ? (notif['cantidad'] == 1 ? 'canción' : 'canciones') : 'descargada'}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            _formatearFecha(notif['fecha']),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Chevron
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey[400],
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
