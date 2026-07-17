from urllib.parse import urlparse
from pytube import YouTube
import traceback
import tempfile
import os

url = 'https://youtu.be/KJmtLy7qBA8?list='
print('raw url:', url)
parsed = urlparse(url)
print('parsed:', parsed)

if parsed.scheme == '':
    url = f'https://{url}'
    parsed = urlparse(url)

if parsed.scheme not in ('http', 'https'):
    raise ValueError('invalid scheme')

host = parsed.netloc.lower()
if 'youtu.be' in host:
    video_id = parsed.path.lstrip('/')
    print('video_id:', video_id)
    if not video_id:
        raise ValueError('no video id')
    url = f'https://www.youtube.com/watch?v={video_id}'
elif 'youtube.com' in host:
    query_items = [part.split('=', 1) for part in parsed.query.split('&') if '=' in part]
    query = {k: v for k, v in query_items}
    video_id = query.get('v')
    print('query video_id:', video_id)
    if not video_id and parsed.path.startswith('/embed/'):
        video_id = parsed.path.split('/embed/')[1]
    print('video_id final:', video_id)
    if not video_id:
        raise ValueError('no video id')
    url = f'https://www.youtube.com/watch?v={video_id}'
else:
    raise ValueError(f'invalid host {host}')

print('final url:', url)

try:
    yt = YouTube(url)
    print('title:', yt.title)
    streams = yt.streams.filter(only_audio=True).order_by('abr').desc()
    print('audio stream count:', len(streams))
    print('first stream:', streams.first())
except Exception as e:
    traceback.print_exc()

print('\n--- testing yt_dlp ---')
try:
    from yt_dlp import YoutubeDL
    opts = {
        'format': 'bestaudio/best',
        'quiet': True,
        'no_warnings': True,
        'noplaylist': True,
    }
    with YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url, download=False)
        print('yt_dlp info type', type(info))
        if isinstance(info, dict):
            print('yt_dlp id', info.get('id'))
            print('yt_dlp requested_downloads', info.get('requested_downloads'))
            print('yt_dlp url', info.get('url'))
    temp_dir = tempfile.mkdtemp()
    opts['outtmpl'] = os.path.join(temp_dir, '%(id)s.%(ext)s')
    with YoutubeDL(opts) as ydl:
        info2 = ydl.extract_info(url, download=True)
        print('yt_dlp download info type', type(info2))
        if isinstance(info2, dict):
            print('yt_dlp download keys', list(info2.keys()))
            print('yt_dlp download filepath', info2.get('filepath'))
            print('yt_dlp download requested_downloads', info2.get('requested_downloads'))
            if info2.get('requested_downloads'):
                print('first download filepath', info2['requested_downloads'][0].get('filepath'))
        print('temp_dir contents:', os.listdir(temp_dir))
except Exception:
    traceback.print_exc()
