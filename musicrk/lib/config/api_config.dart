class ApiConfig {
  // IMPORTANTE: Cambia esta IP por la IP de tu PC
  // Para obtener tu IP en Windows: abre CMD y ejecuta "ipconfig"
  // Busca "IPv4 Address" (ejemplo: 192.168.1.100)
  static const String baseUrl = 'https://web-production-90906.up.railway.app';
  
  // Endpoints
  static const String searchEndpoint = '/search';
  static const String downloadEndpoint = '/download';
  static const String healthEndpoint = '/health';
  static const String searchAlbumsEndpoint = '/search_albums';
  static const String albumTracksEndpoint = '/album_tracks';
  static const String downloadAlbumEndpoint = '/download_album';
}
