#!/usr/bin/env python3
"""Collect only official parallel-world Hachiware monster references."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
from io import BytesIO
import json
from pathlib import Path
import re
from urllib.request import Request, urlopen

from PIL import Image

ROOT = Path(__file__).resolve().parent
PREVIOUS = ROOT.parent / 'HachiwareTransformations-v49'
VERIFIED = '2026-10-23'


def fetch(url):
    with urlopen(Request(url, headers={'User-Agent': 'Mozilla/5.0'}), timeout=35) as response:
        return response.read(), response.headers.get_content_type()


def save_json(relative, value):
    destination = ROOT / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def main():
    previous = {item['path']: item for item in json.loads((PREVIOUS / 'sources.json').read_text())}
    selected = [
        ('Original/01-official-transformation-comparison.jpg', 'OriginalComic/parallel-stages-2102236239995031704-01.jpg', '변화 비교 · 큰 귀, 손발, 발톱, 파란 꼬리'),
        ('Original/02-official-monster-face-expressions.jpg', 'OriginalComic/parallel-strong-1767525203222143077-01.jpg', '얼굴 · 검은 눈, 소용돌이 눈, 볼 옆 선'),
        ('Original/03-official-comic-body-claws-tail.jpg', 'OriginalComic/parallel-strong-1765317655823839639-01.jpg', '원작 동작 · 큰 손과 발톱, 옆·뒷모습 일부'),
        ('Anime/01-episode-380-transition.jpg', 'Anime/episode-380.jpg', '중간 변화 모습 · 애니 380화'),
        ('Anime/02-episode-381-monster.jpg', 'Anime/episode-381.jpg', '괴물 모습 · 애니 381화'),
        ('Merchandise/01-monster-front.jpg', 'Market/parallel-strong-4571609344117-04.jpg', '괴물 모습 · 정면 전신, 입체 상품'),
        ('Merchandise/02-monster-back.jpg', 'Market/parallel-strong-4571609344117-05.jpg', '괴물 모습 · 뒷면과 큰 파란 꼬리, 입체 상품'),
        ('Merchandise/03-monster-acrylic-art.jpg', 'Market/parallel-strong-4571609347347-01.jpg', '2D 상품 그림 · 표정과 털 실루엣'),
        ('Transition/01-fluffy-form-front.jpg', 'Market/parallel-mid-4571609344094-05.jpg', '중간 변화 모습 · 정면, 입체 상품'),
        ('Transition/02-fluffy-form-back.jpg', 'Market/parallel-mid-4571609344094-06.jpg', '중간 변화 모습 · 후면, 입체 상품'),
    ]
    jobs = []
    for destination, source, role in selected:
        original = previous['References/Official/' + source]
        jobs.append({'path': destination, 'url': original['url'], 'page': original['page'],
                     'role': role, 'previous_archive_path': str((PREVIOUS / original['path']).relative_to(ROOT.parent)),
                     'previous_sha256': original['sha256'], 'use_as_character_reference': True})

    # The public embed response supplies the official author and actual media URL.
    for post_id in ['2102236239995031704', '1767525203222143077', '1765317655823839639']:
        url = f'https://cdn.syndication.twimg.com/tweet-result?id={post_id}&lang=ja&token=0'
        body, _ = fetch(url)
        post = json.loads(body)
        assert post['user']['screen_name'] == 'ngnchiikawa', post_id
        assert str(post['id_str']) == post_id, post_id
        save_json(f'Metadata/official-post-{post_id}.json', post)

    for product_id in ['4571609344117', '4571609344094', '4571609347347', '4571609347477', '4571609347446']:
        body, _ = fetch(f'https://chiikawamarket.jp/products/{product_id}.js')
        product = json.loads(body)
        save_json(f'Metadata/product-{product_id}.json', product)
        if product_id not in ['4571609347477', '4571609347446']:
            continue
        assert '強くなったハチワレ' in product['title']
        images = product['images'] if product_id == '4571609347477' else product['images'][:1]
        label = 'memo' if product_id == '4571609347477' else 'towel'
        for number, url in enumerate(images, 1):
            context_only = label == 'memo' and number == 4
            jobs.append({'path': f'Merchandise/monster-{label}-{number:02d}.jpg',
                         'url': 'https:' + url if url.startswith('//') else url,
                         'page': f'https://chiikawamarket.jp/products/{product_id}',
                         'role': '동일 상품의 관련 캐릭터 페이지 · 하치와레 외형 참고 제외' if context_only else '공식 2D 상품 그림 · 몸과 표정의 보조 자료',
                         'use_as_character_reference': not context_only, 'product_title': product['title']})

    page = 'https://mezamashi.media/articles/-/350285'
    body, _ = fetch(page)
    match = re.search(r'<meta property="og:image" content="([^"]+)"', body.decode('utf-8'))
    assert match and match.group(1).startswith('https://mezamashi.ismcdn.jp/')
    jobs.append({'path': 'Anime/03-episode-381-official-media.jpg', 'url': match.group(1), 'page': page,
                 'role': '방송사 공식 381화 대표 장면 · 고해상도', 'use_as_character_reference': True})
    save_json('Metadata/broadcaster-source.json', {'page': page, 'title': 'アニメ「ちいかわ」第381話「パラレルワールド⑦」',
                                                'image_url': match.group(1), 'verified': VERIFIED})

    def download(item):
        data, content_type = fetch(item['url'])
        with Image.open(BytesIO(data)) as image:
            image.verify()
        with Image.open(BytesIO(data)) as image:
            dimensions = list(image.size)
        destination = ROOT / item['path']
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        return {**item, 'verified': VERIFIED, 'content_type': content_type, 'bytes': len(data),
                'sha256': hashlib.sha256(data).hexdigest(), 'dimensions': dimensions}

    with ThreadPoolExecutor(max_workers=4) as executor:
        sources = list(executor.map(download, jobs))
    save_json('sources.json', sources)
    save_json('validation.json', {'verified': VERIFIED, 'image_files': len(sources),
              'unique_image_contents': len({item['sha256'] for item in sources}),
              'all_images_decode': True,
              'previous_downloads_identical': all(item['sha256'] == item['previous_sha256'] for item in sources if 'previous_sha256' in item),
              'generated_at': datetime.now(timezone.utc).isoformat(), 'failures': []})
    print(json.dumps({'images': len(sources), 'bytes': sum(item['bytes'] for item in sources),
                      'files': [{'path': item['path'], 'size': item['dimensions']} for item in sources]}, ensure_ascii=False))


if __name__ == '__main__':
    main()
