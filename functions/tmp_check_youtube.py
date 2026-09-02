import yt_dlp

url = 'https://www.youtube.com/watch?v=aqz-KE-bpKQ'
opts = {'quiet': True, 'no_warnings': True, 'noplaylist': True, 'socket_timeout': 8, 'extract_flat': True, 'skip_download': True}
with yt_dlp.YoutubeDL(opts) as ydl:
    info = ydl.extract_info(url, download=False)
    print(type(info).__name__)
    print(info.get('id'))
    print(info.get('title'))
