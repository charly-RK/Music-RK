from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import yt_dlp
import os
import json
import subprocess
from pathlib import Path
from proxy_manager import get_spotdl_proxy_args

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
            'nocheckcertificate': True,
            'source_address': '0.0.0.0',
            'user-agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'extractor_args': {'youtube': {'player_client': ['web_creator', 'ios']}},
        }
        
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            search_results = ydl.extract_info(f"ytsearch10:{query} official audio", download=False)
            
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
def find_downloaded_file(downloads_dir, title_query):
    """Find the downloaded file in the directory using modification time and word matching."""
    import time
    files = list(downloads_dir.glob('*.mp3'))
    if not files:
        files = list(downloads_dir.glob('*'))
        
    if not files:
        return None
        
    # Sort by modification time, newest first
    files.sort(key=lambda x: x.stat().st_mtime, reverse=True)
    
    # If the newest file was modified within the last 5 minutes, it's our file
    if time.time() - files[0].stat().st_mtime < 300:
        return files[0]
        
    # If the download was skipped (duplicate), find the file matching the title words
    words = [w.lower() for w in title_query.split() if len(w) > 2 and w.isalnum()]
    best_match = None
    max_matches = 0
    
    for f in files:
        matches = sum(1 for w in words if w in f.name.lower())
        if matches > max_matches:
            max_matches = matches
            best_match = f
            
    if best_match and max_matches > 0:
        return best_match
        
    return files[0]

@app.route('/download', methods=['POST'])
def download_video():
    """Download YouTube video as MP3 using spotdl with proxy fallback"""
    try:
        data = request.json or {}
        video_id = data.get('video_id', '')
        title = data.get('title', 'audio')
        
        if not video_id:
            return jsonify({'error': 'Video ID is required'}), 400
        
        video_url = f"https://www.youtube.com/watch?v={video_id}"
        
        last_error = None
        success = False
        
        # Try direct download first, then fallback to rotated proxy/Tor/IPv6
        for attempt in range(1, 3):
            cmd = ['spotdl', 'download', video_url, '--output', str(DOWNLOAD_DIR)]
            
            # Get proxy args for this attempt
            proxy_args = get_spotdl_proxy_args(attempt=attempt)
            cmd.extend(proxy_args)
            
            if os.path.exists('cookies.txt'):
                cmd.extend(['--cookie-file', 'cookies.txt'])
                
            print(f"Executing spotdl download command (Attempt {attempt}): {' '.join(cmd)}")
            
            try:
                result = subprocess.run(cmd, capture_output=True, text=True, check=True)
                print(f"spotdl output (Attempt {attempt}):", result.stdout)
                success = True
                break
            except subprocess.CalledProcessError as e:
                print(f"Attempt {attempt} failed: {e.stderr or e.stdout or str(e)}")
                last_error = e
                
        if not success:
            return jsonify({'error': f'Download failed after all attempts: {str(last_error)}'}), 500
            
        # Find the correct downloaded file (handles duplicate skips)
        downloaded_file = find_downloaded_file(DOWNLOAD_DIR, title)
        
        if downloaded_file:
            return jsonify({
                'success': True,
                'file_path': downloaded_file.name,
                'file_size': downloaded_file.stat().st_size
            })
        else:
            return jsonify({'error': 'No file found after download'}), 500
            
    except Exception as e:
        print(f"Error in download: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/download_file/<path:filename>', methods=['GET'])
def download_file(filename):
    """Serve downloaded MP3 file"""
    try:
        from urllib.parse import unquote
        decoded_filename = unquote(filename)
        file_path = DOWNLOAD_DIR / decoded_filename
        
        if file_path.exists():
            return send_file(file_path, as_attachment=True, download_name=file_path.name)
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
            'nocheckcertificate': True,
            'source_address': '0.0.0.0',
            'user-agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'extractor_args': {'youtube': {'player_client': ['web_creator', 'ios']}},
        }

        if os.path.exists('cookies.txt'):
            ydl_opts['cookiefile'] = 'cookies.txt'
        
        albums = []
        
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            # Search for the artist's channel
            try:
                # First, find the artist's channel (Topic preferred)
                channel_query = f"ytsearch1:{query} topic"
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
            
            # Download each track using spotdl with proxy fallback
            for idx, entry in enumerate(playlist_info.get('entries', []), 1):
                if entry:
                    video_id = entry.get('id', '')
                    title = entry.get('title', f'Track {idx}')
                    
                    track_url = f"https://www.youtube.com/watch?v={video_id}"
                    
                    success = False
                    for attempt in range(1, 3):
                        cmd = ['spotdl', 'download', track_url, '--output', str(album_folder)]
                        
                        proxy_args = get_spotdl_proxy_args(attempt=attempt)
                        cmd.extend(proxy_args)
                            
                        if os.path.exists('cookies.txt'):
                            cmd.extend(['--cookie-file', 'cookies.txt'])
                            
                        try:
                            subprocess.run(cmd, check=True, capture_output=True)
                            success = True
                            break
                        except Exception as e:
                            print(f"Attempt {attempt} for track {title} failed: {e}")
                            
                    if success:
                        downloaded_file = find_downloaded_file(album_folder, title)
                        if downloaded_file:
                            file_rel_path = f"{safe_album_name}/{downloaded_file.name}"
                            if not any(f['file_path'] == file_rel_path for f in downloaded_files):
                                downloaded_files.append({
                                    'title': title,
                                    'file_path': file_rel_path,
                                    'progress': f"{idx}/{total_tracks}"
                                })
            
            return jsonify({
                'success': True,
                'album_folder': safe_album_name,
                'downloaded_files': downloaded_files,
                'total_tracks': total_tracks
            })
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/download_spotify', methods=['POST'])
def download_spotify():
    """Download Spotify track using spotdl"""
    try:
        data = request.json or {}
        spotify_url = data.get('spotify_url', '')
        
        if not spotify_url:
            return jsonify({'error': 'Spotify URL is required'}), 400
            
        # Basic validation of URL/URI to prevent command injection
        if not (spotify_url.startswith('https://open.spotify.com/') or spotify_url.startswith('spotify:')):
            return jsonify({'error': 'Invalid Spotify URL'}), 400
            
        # Sanitize input to only allow URL-safe characters
        safe_url = "".join(c for c in spotify_url if c.isalnum() or c in ('/', ':', '?', '=', '-', '_', '.')).strip()
        
        # Execute spotdl
        cmd = ['spotdl', 'download', safe_url, '--output', str(DOWNLOAD_DIR)]
        
        # Pass proxy if environment variable is set
        proxy = os.environ.get('SPOTDL_PROXY')
        if proxy:
            cmd.extend(['--proxy', proxy])
            
        # Pass cookie file if cookies.txt exists (underlying yt-dlp uses it)
        if os.path.exists('cookies.txt'):
            cmd.extend(['--cookie-file', 'cookies.txt'])
            
        print(f"Executing spotdl command: {' '.join(cmd)}")
        
        # Run spotdl command. Note: spotdl downloaded files will go to DOWNLOAD_DIR
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        print("spotdl output:", result.stdout)
        
        # Find the downloaded file (newest MP3 in downloads directory)
        files = list(DOWNLOAD_DIR.glob('*.mp3'))
        if not files:
            # Maybe the download failed or returned different extension, let's look for any audio
            files = list(DOWNLOAD_DIR.glob('*'))
            # Filter for files modified within last 2 minutes
            import time
            now = time.time()
            recent_files = [f for f in files if f.is_file() and now - f.stat().st_mtime < 120]
            if not recent_files:
                return jsonify({'error': 'No file downloaded', 'details': result.stderr}), 500
            newest_file = max(recent_files, key=os.path.getmtime)
        else:
            newest_file = max(files, key=os.path.getmtime)
            
        filename = newest_file.name
        print(f"Downloaded Spotify track successfully saved as: {filename}")
        
        return jsonify({
            'success': True,
            'file_path': filename,
            'file_size': newest_file.stat().st_size
        })
        
    except subprocess.CalledProcessError as e:
        print(f"spotdl process failed: {e.stdout}\n{e.stderr}")
        return jsonify({'error': 'spotdl failed', 'details': e.stderr}), 500
    except Exception as e:
        print(f"Error downloading Spotify track: {e}")
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
