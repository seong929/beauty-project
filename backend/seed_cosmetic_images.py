"""Match the supplied image archive to existing cosmetics without changing the DB."""
import argparse
import hashlib
import json
import re
import zipfile
from difflib import SequenceMatcher
from pathlib import Path

from database import get_connection
from services.admin.cosmetic_image_service import upload_image, object_name


def normalized(value):
    return re.sub(r'[^a-z0-9가-힣]', '', value.lower())


def match_image(product_name, files):
    name = normalized(product_name)
    for filename in files:
        if normalized(Path(filename).stem) == name:
            return filename, '상품명 일치'
    if '테스트' in product_name:
        return None, '자동품의 테스트용 상품: 대표 제품이 없음'
    # Do not label a tint/shampoo/sunscreen with an unrelated skincare photo.
    for kind in ('선크림', '틴트', '샴푸'):
        if kind in name and not any(kind in normalized(f) for f in files):
            return None, f'압축파일에 {kind} 이미지가 없음'
    kind = next((kind for kind in ('토너', '로션', '선크림', '틴트', '샴푸', '크림') if kind in name), None)
    candidates = [f for f in files if kind and kind in normalized(f)]
    if not candidates:
        return None, '같은 상품 종류의 이미지가 없음'
    def score(filename):
        candidate = normalized(Path(filename).stem)
        result = SequenceMatcher(None, name, candidate).ratio()
        if '진정' in name and '진정' in candidate: result += 1
        if '바디' in name and '아토' in candidate: result += 1
        return result
    return max(candidates, key=score), '예시 상품명에 맞춘 동일 종류의 유사 이미지'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive')
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--report', default=str(Path(__file__).resolve().parents[1] / 'database' / 'cosmetic_image_mapping.json'))
    args = parser.parse_args()
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute('SELECT cosmetic_id, cosmetic_name FROM cosmetics ORDER BY cosmetic_id')
            products = cursor.fetchall()
    finally:
        conn.close()
    entries = []
    with zipfile.ZipFile(args.archive) as archive:
        files = [x.filename for x in archive.infolist() if not x.is_dir() and x.filename.lower().endswith(('.png','.jpg','.jpeg','.webp'))]
        for product in products:
            filename, reason = match_image(product['cosmetic_name'], files)
            entry = {**product, 'source_image': filename, 'reason': reason, 'object_name': object_name(product['cosmetic_id']), 'status': 'unmatched' if filename is None else 'planned'}
            if filename:
                info = archive.getinfo(filename)
                if info.file_size > 10 * 1024 * 1024:
                    raise ValueError('Archive image exceeds 10 MB')
                content = archive.read(filename)
                entry['sha256'] = hashlib.sha256(content).hexdigest()
                if args.apply:
                    try:
                        result = upload_image(product['cosmetic_id'], content, filename, overwrite=False)
                        entry['status'] = 'existing' if result.get('skipped') else 'uploaded'
                    except Exception as error:
                        entry['status'] = 'error'
                        entry['error'] = type(error).__name__
            entries.append(entry)
    Path(args.report).write_text(json.dumps({'bucket': 'cosmetics-store-image-storage.firebasestorage.app', 'products': entries}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({status: sum(e['status'] == status for e in entries) for status in ('planned','uploaded','existing','unmatched','error')}))
    if any(e['status'] == 'error' for e in entries): raise SystemExit(1)


if __name__ == '__main__': main()
