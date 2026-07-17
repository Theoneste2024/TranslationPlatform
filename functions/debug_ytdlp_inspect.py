from yt_dlp import YoutubeDL
import json

url = 'https://youtu.be/ZJnMqt84FBA'
opts = {
    'format': 'bestaudio/best',
    'quiet': True,
    'no_warnings': True,
    'noplaylist': True,
    'nocheckcertificate': True,
    'geo_bypass': True,
    'socket_timeout': 30,
    'cachedir': False,
    'http_headers': {
        'User-Agent': 'Mozilla/5.0',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': 'https://www.youtube.com/'
    }
}
with YoutubeDL(opts) as ydl:
    info = ydl.extract_info(url, download=False)

summary = {
    'id': info.get('id'),
    'title': info.get('title'),
    'protocol': info.get('protocol'),
    'ext': info.get('ext'),
    'url': info.get('url')[:300] if info.get('url') else None,
    'formats_count': len(info.get('formats') or []),
}
print(json.dumps(summary, ensure_ascii=False, indent=2))
for f in (info.get('formats') or [])[:40]:
    print(json.dumps({
        'format_id': f.get('format_id'),
        'ext': f.get('ext'),
        'acodec': f.get('acodec'),
        'vcodec': f.get('vcodec'),
        'protocol': f.get('protocol'),
        'url': (f.get('url') or '')[:300],
        'abr': f.get('abr'),
        'tbr': f.get('tbr'),
        'format_note': f.get('format_note')
    }, ensure_ascii=False))
