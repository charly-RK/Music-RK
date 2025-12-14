from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import yt_dlp
import os
import json
from pathlib import Path

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter app

# Configuration
DOWNLOAD_DIR = Path("downloads")
DOWNLOAD_DIR.mkdir(exist_ok=True)

@app.route('/')
def index():
    """Root endpoint"""
    return jsonify({'message': 'YouTube Download API', 'status': 'running'})

@app.route('/search', methods=['POST'])
def search_videos():
    """Search YouTube videos"""
    try:
        data = request.json
        query = data.get('query', '')
        
        if not query:
            return jsonify({'error': 'Query is required'}), 400
        
        ydl_opts = {
            'quiet': True,
            'no_warnings': True,
            'extract_flat': True,
            'extractor_args': {'youtube': {'player_client': ['android', 'web']}},
        }
        
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            search_results = ydl.extract_info(f"ytsearch10:{query}", download=False)
            
            videos = []
            for entry in search_results.get('entries', []):
                video_id = entry.get('id', '')
                video_url = entry.get('webpage_url', f"https://www.youtube.com/watch?v={video_id}")
                
                print(f"DEBUG - Video ID: {video_id}, URL: {video_url}")
                
                videos.append({
                    'id': video_id,
                    'title': entry.get('title', ''),
                    'url': video_url,
                    'thumbnail': entry.get('thumbnail', ''),
                    'duration': entry.get('duration', 0),
                    'author': entry.get('uploader', ''),
                })
            
            return jsonify({'results': videos})
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/download', methods=['POST'])
def download_video():
    """Download YouTube video as MP3"""
    try:
        data = request.json
        video_id = data.get('video_id', '')
        title = data.get('title', 'audio')
        
        if not video_id:
            return jsonify({'error': 'Video ID is required'}), 400
        
        # Sanitize filename
        safe_title = "".join(c for c in title if c.isalnum() or c in (' ', '-', '_')).strip()
        output_path = DOWNLOAD_DIR / f"{safe_title}.mp3"
        
        # yt-dlp options for MP3 download with metadata and artwork
        ydl_opts = {
            'format': 'bestaudio/best',
            'postprocessors': [
                {
                    'key': 'FFmpegExtractAudio',
                    'preferredcodec': 'mp3',
                    'preferredquality': '320',
                },
                {
                    'key': 'FFmpegMetadata',
                    'add_metadata': True,
                },
                {
                    'key': 'EmbedThumbnail',
                    'already_have_thumbnail': False,
                }
            ],
            'writethumbnail': True,  # Download thumbnail
            'outtmpl': str(DOWNLOAD_DIR / f"{safe_title}.%(ext)s"),
            'quiet': False,
            'no_warnings': False,
            'progress_hooks': [lambda d: print(f"Progress: {d.get('_percent_str', '0%')}")],
            'extractor_args': {'youtube': {'player_client': ['android', 'web']}},
        }
        
        # Download
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([f"https://www.youtube.com/watch?v={video_id}"])
        
        # Check if file exists
        if output_path.exists():
            return jsonify({
                'success': True,
                'file_path': f"{safe_title}.mp3",  # Return only filename
                'file_size': output_path.stat().st_size
            })
        else:
            return jsonify({'error': 'Download failed'}), 500
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/download_file/<path:filename>', methods=['GET'])
def download_file(filename):
    """Serve downloaded MP3 file with streaming"""
    try:
        file_path = DOWNLOAD_DIR / filename
        if file_path.exists():
            def generate():
                with open(file_path, 'rb') as f:
                    while True:
                        chunk = f.read(8192)  # Read in 8KB chunks
                        if not chunk:
                            break
                        yield chunk
            
            from flask import Response
            return Response(
                generate(),
                mimetype='audio/mpeg',
                headers={
                    'Content-Disposition': f'attachment; filename="{filename}"',
                    'Content-Length': str(file_path.stat().st_size)
                }
            )
        else:
            return jsonify({'error': 'File not found'}), 404
    except Exception as e:
        print(f"Error serving file: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/search_albums', methods=['POST'])
def search_albums():
    """Search YouTube albums/playlists (official only)"""
    try:
        data = request.json
        query = data.get('query', '')
        
        if not query:
            return jsonify({'error': 'Query is required'}), 400
        
        ydl_opts = {
            'quiet': True,
            'no_warnings': True,
            'extract_flat': True,
            'extractor_args': {'youtube': {'player_client': ['android', 'web']}},
        }
        
        albums = []
        
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            # Search for the artist's channel
            try:
                # First, find the artist's channel
                channel_query = f"ytsearch1:{query} official"
                print(f"Searching for channel: {channel_query}")
                search_results = ydl.extract_info(channel_query, download=False)
                
                channel_url = None
                if search_results and 'entries' in search_results:
                    first_result = search_results['entries'][0]
                    if first_result:
                        # Get channel URL from the video
                        channel_id = first_result.get('channel_id', '')
                        if channel_id:
                            channel_url = f"https://www.youtube.com/channel/{channel_id}/releases"
                            print(f"Found channel: {channel_url}")
                
                # If we found a channel, extract albums from releases
                if channel_url:
                    try:
                        print(f"Extracting releases from: {channel_url}")
                        channel_info = ydl.extract_info(channel_url, download=False)
                        
                        if channel_info and 'entries' in channel_info:
                            for item in channel_info['entries'][:10]:  # Limit to 10 albums
                                if not item:
                                    continue
                                
                                # Check if it's a playlist (album)
                                item_id = item.get('id', '')
                                
                                # Official albums have OLAK5uy_ in their playlist ID
                                if item_id and 'OLAK5uy_' in item_id:
                                    try:
                                        # Extract full playlist info to get track count
                                        playlist_url = f"https://www.youtube.com/playlist?list={item_id}"
                                        print(f"Extracting playlist: {playlist_url}")
                                        
                                        playlist_info = ydl.extract_info(playlist_url, download=False)
                                        
                                        if playlist_info:
                                            title = playlist_info.get('title', '')
                                            uploader = playlist_info.get('uploader', '') or playlist_info.get('channel', '')
                                            
                                            # Get thumbnail
                                            thumbnail = ''
                                            if 'thumbnail' in playlist_info:
                                                thumbnail = playlist_info['thumbnail']
                                            elif 'thumbnails' in playlist_info and len(playlist_info['thumbnails']) > 0:
                                                thumbnail = playlist_info['thumbnails'][-1].get('url', '')
                                            
                                            # Get accurate track count from entries
                                            track_count = len(playlist_info.get('entries', []))
                                            
                                            if title and track_count > 0:
                                                print(f"Found official album: {title} ({track_count} tracks)")
                                                albums.append({
                                                    'id': item_id,
                                                    'title': title,
                                                    'thumbnail': thumbnail,
                                                    'author': uploader,
                                                    'track_count': track_count,
                                                })
                                    except Exception as e:
                                        print(f"Error extracting playlist {item_id}: {e}")
                                        continue

                    except Exception as e:
                        print(f"Error extracting channel releases: {e}")
                        import traceback
                        traceback.print_exc()
            except Exception as e:
                print(f"Error finding channel: {e}")
                import traceback
                traceback.print_exc()
            
            # Fallback: Search for official album playlists directly
            if len(albums) == 0:
                try:
                    # Search for playlists with OLAK identifier (official albums)
                    album_query = f"ytsearch10:{query} OLAK5uy"
                    print(f"Fallback search: {album_query}")
                    search_results = ydl.extract_info(album_query, download=False)
                    
                    if search_results and 'entries' in search_results:
                        for entry in search_results.get('entries', []):
                            if not entry:
                                continue
                            
                            # Check if URL contains playlist
                            url = entry.get('url', '')
                            webpage_url = entry.get('webpage_url', '')
                            
                            if 'OLAK5uy_' in url or 'OLAK5uy_' in webpage_url or 'list=' in webpage_url:
                                # Extract playlist ID from URL
                                playlist_id = None
                                if 'list=' in webpage_url:
                                    playlist_id = webpage_url.split('list=')[1].split('&')[0]
                                
                                if playlist_id and 'OLAK5uy_' in playlist_id:
                                    try:
                                        playlist_url = f"https://www.youtube.com/playlist?list={playlist_id}"
                                        playlist_info = ydl.extract_info(playlist_url, download=False)
                                        
                                        if playlist_info:
                                            title = playlist_info.get('title', '')
                                            uploader = playlist_info.get('uploader', '') or playlist_info.get('channel', '')
                                            
                                            # Get thumbnail
                                            thumbnail = ''
                                            if 'thumbnail' in playlist_info:
                                                thumbnail = playlist_info['thumbnail']
                                            elif 'thumbnails' in playlist_info and len(playlist_info['thumbnails']) > 0:
                                                thumbnail = playlist_info['thumbnails'][-1].get('url', '')
                                            
                                            track_count = len(playlist_info.get('entries', []))
                                            
                                            if title and track_count > 0:
                                                print(f"Found official album (fallback): {title} ({track_count} tracks)")
                                                albums.append({
                                                    'id': playlist_id,
                                                    'title': title,
                                                    'thumbnail': thumbnail,
                                                    'author': uploader,
                                                    'track_count': track_count,
                                                })
                                                
                                                if len(albums) >= 5:
                                                    break
                                    except Exception as e:
                                        print(f"Error extracting playlist: {e}")
                                        continue
                except Exception as e:
                    print(f"Error in fallback search: {e}")
                    import traceback
                    traceback.print_exc()
            
            print(f"Returning {len(albums)} albums")
            return jsonify({'results': albums})
    
    except Exception as e:
        print(f"Error in search_albums: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/album_tracks', methods=['POST'])
def get_album_tracks():
    """Get tracks from a YouTube album/playlist"""
    try:
        data = request.json
        playlist_id = data.get('playlist_id', '')
        
        if not playlist_id:
            return jsonify({'error': 'Playlist ID is required'}), 400
        
        ydl_opts = {
            'quiet': True,
            'no_warnings': True,
            'extract_flat': True,
            'extractor_args': {'youtube': {'player_client': ['android', 'web']}},
        }
        
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            playlist_url = f"https://www.youtube.com/playlist?list={playlist_id}"
            playlist_info = ydl.extract_info(playlist_url, download=False)
            
            tracks = []
            for entry in playlist_info.get('entries', []):
                if entry:
                    tracks.append({
                        'id': entry.get('id', ''),
                        'title': entry.get('title', ''),
                        'url': entry.get('url', f"https://www.youtube.com/watch?v={entry.get('id', '')}"),
                        'thumbnail': entry.get('thumbnail', ''),
                        'duration': entry.get('duration', 0),
                        'author': entry.get('uploader', ''),
                    })
            
            return jsonify({'tracks': tracks})
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/download_album', methods=['POST'])
def download_album():
    """Download entire album into a dedicated folder"""
    try:
        data = request.json
        playlist_id = data.get('playlist_id', '')
        album_title = data.get('album_title', 'Album')
        
        if not playlist_id:
            return jsonify({'error': 'Playlist ID is required'}), 400
        
        # Sanitize album name for folder
        safe_album_name = "".join(c for c in album_title if c.isalnum() or c in (' ', '-', '_')).strip()
        album_folder = DOWNLOAD_DIR / safe_album_name
        album_folder.mkdir(exist_ok=True)
        
        # Get playlist tracks
        ydl_opts = {
            'quiet': True,
            'no_warnings': True,
            'extract_flat': True,
            'extractor_args': {'youtube': {'player_client': ['android', 'web']}},
        }
        
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            playlist_url = f"https://www.youtube.com/playlist?list={playlist_id}"
            playlist_info = ydl.extract_info(playlist_url, download=False)
            
            downloaded_files = []
            total_tracks = len(playlist_info.get('entries', []))
            
            # Download each track
            for idx, entry in enumerate(playlist_info.get('entries', []), 1):
                if entry:
                    video_id = entry.get('id', '')
                    title = entry.get('title', f'Track {idx}')
                    safe_title = "".join(c for c in title if c.isalnum() or c in (' ', '-', '_')).strip()
                    
                    output_path = album_folder / f"{safe_title}.mp3"
                    
                    # Download options with metadata and artwork
                    download_opts = {
                        'format': 'bestaudio/best',
                        'postprocessors': [
                            {
                                'key': 'FFmpegExtractAudio',
                                'preferredcodec': 'mp3',
                                'preferredquality': '320',
                            },
                            {
                                'key': 'FFmpegMetadata',
                                'add_metadata': True,
                            },
                            {
                                'key': 'EmbedThumbnail',
                                'already_have_thumbnail': False,
                            }
                        ],
                        'writethumbnail': True,  # Download thumbnail
                        'outtmpl': str(album_folder / f"{safe_title}.%(ext)s"),
                        'quiet': False,
                        'no_warnings': False,
                        'extractor_args': {'youtube': {'player_client': ['android', 'web']}},
                    }
                    
                    try:
                        with yt_dlp.YoutubeDL(download_opts) as download_ydl:
                            download_ydl.download([f"https://www.youtube.com/watch?v={video_id}"])
                        
                        if output_path.exists():
                            downloaded_files.append({
                                'title': title,
                                'file_path': f"{safe_album_name}/{safe_title}.mp3",
                                'progress': f"{idx}/{total_tracks}"
                            })
                    except Exception as e:
                        print(f"Error downloading {title}: {e}")
                        continue
            
            return jsonify({
                'success': True,
                'album_folder': safe_album_name,
                'downloaded_files': downloaded_files,
                'total_tracks': total_tracks
            })
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({'status': 'ok', 'message': 'Server is running'})

if __name__ == '__main__':
    print("YouTube Download Server Starting...")
    print(f"Download directory: {DOWNLOAD_DIR.absolute()}")
    port = int(os.environ.get('PORT', 5001))
    print(f"Server running on http://0.0.0.0:{port}")
    print("Use your PC's IP address to connect from Flutter app")
    app.run(host='0.0.0.0', port=port, debug=False)
