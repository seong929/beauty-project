"""Firebase Storage objects keyed by cosmetic_id; no database image columns."""
import hashlib
import io
import json
import os
import shutil
import subprocess
import threading
import uuid
from datetime import datetime, timedelta
from functools import lru_cache
from pathlib import Path
from urllib.parse import quote

import google.auth
from google.auth.credentials import Credentials
from google.auth.exceptions import DefaultCredentialsError
from google.cloud import storage
from google.api_core.exceptions import GoogleAPIError, NotFound, PreconditionFailed
from PIL import Image, UnidentifiedImageError
from fastapi import HTTPException

BUCKET_NAME = os.getenv('FIREBASE_STORAGE_BUCKET', 'cosmetics-store-image-storage.firebasestorage.app')
PROJECT_ID = 'cosmetics-store-image-storage'
MAX_IMAGE_BYTES = 10 * 1024 * 1024
_write_lock = threading.Lock()
_credential_lock = threading.Lock()


class FirebaseCliCredentials(Credentials):
    """Local development only: reuse this machine's firebase login, never copy tokens."""
    def refresh(self, request):
        with _credential_lock:
            if self.valid:
                return
            self._refresh_from_cli()

    def _refresh_from_cli(self):
        binary = shutil.which('firebase') or shutil.which('firebase.cmd')
        node = shutil.which('node')
        if not binary or not node:
            raise DefaultCredentialsError('Google ADC 또는 Firebase CLI 로그인이 필요합니다.')
        executable = Path(binary)
        candidates = [executable.parent / 'node_modules' / 'firebase-tools', executable.resolve().parents[2]]
        package = next((p for p in candidates if (p / 'lib' / 'auth.js').is_file()), None)
        if package is None:
            raise DefaultCredentialsError('Firebase CLI 설치 경로를 찾을 수 없습니다. Google ADC를 설정하세요.')
        script = """
const auth = require(process.argv[1] + '/lib/auth.js');
const account = auth.getProjectDefaultAccount(process.argv[2]) || auth.getGlobalDefaultAccount();
if (!account?.tokens?.refresh_token) { process.stderr.write('firebase login required'); process.exit(1); }
auth.getAccessToken(account.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform'])
 .then(result => process.stdout.write(JSON.stringify({token:result.access_token, expires_at:result.expires_at})))
 .catch(() => {process.stderr.write('firebase login expired'); process.exit(1);});
"""
        result = subprocess.run([node, '-e', script, str(package), str(Path(__file__).resolve().parents[3] / 'frontend')],
                                capture_output=True, text=True, timeout=30,
                                creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        if result.returncode:
            raise DefaultCredentialsError('Firebase CLI 인증을 확인하세요: firebase login --reauth')
        try:
            token = json.loads(result.stdout)
            self.token = token['token']
            self.expiry = datetime.utcnow() + timedelta(minutes=45)
        except (ValueError, KeyError):
            raise DefaultCredentialsError('Firebase CLI 인증 응답을 읽지 못했습니다.') from None


@lru_cache(maxsize=1)
def get_bucket():
    try:
        credentials, _ = google.auth.default(scopes=['https://www.googleapis.com/auth/cloud-platform'])
    except DefaultCredentialsError:
        # Existing local Firebase login supports this project's development setup.
        # Deployed servers should use ADC / an attached service account.
        credentials = FirebaseCliCredentials()
    return storage.Client(project=PROJECT_ID, credentials=credentials).bucket(BUCKET_NAME)


def object_name(cosmetic_id):
    return f'cosmetics/{cosmetic_id}/image'


def validate_image(content: bytes):
    if not content or len(content) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=422, detail='이미지는 10MB 이하로 선택해 주세요.')
    try:
        with Image.open(io.BytesIO(content)) as image:
            if image.width * image.height > 32_000_000:
                raise ValueError('too many pixels')
            image_type = image.format
            image.verify()
        types = {'JPEG': 'image/jpeg', 'PNG': 'image/png', 'WEBP': 'image/webp'}
        if image_type not in types:
            raise ValueError('unsupported image')
        return types[image_type]
    except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError):
        raise HTTPException(status_code=422, detail='정상적인 PNG, JPG 또는 WebP 이미지를 선택해 주세요.') from None


def _image_info(blob):
    token = (blob.metadata or {}).get('firebaseStorageDownloadTokens', '').split(',')[0]
    url = f'https://firebasestorage.googleapis.com/v0/b/{BUCKET_NAME}/o/{quote(blob.name, safe="")}?alt=media'
    if token:
        url += f'&token={quote(token, safe="")}'
    if blob.generation:
        url += f'&v={blob.generation}'
    return {'image_url': url, 'object_name': blob.name, 'generation': str(blob.generation or '')}


def get_image_info(cosmetic_id):
    try:
        blob = get_bucket().get_blob(object_name(cosmetic_id), timeout=15)
        return _image_info(blob) if blob else {'image_url': None}
    except (GoogleAPIError, DefaultCredentialsError, subprocess.SubprocessError):
        raise HTTPException(status_code=503, detail='이미지 저장소에 연결할 수 없습니다.') from None


def upload_image(cosmetic_id, content, filename='', overwrite=True):
    content_type = validate_image(content)
    try:
        with _write_lock:
            bucket = get_bucket()
            previous = bucket.get_blob(object_name(cosmetic_id), timeout=15)
            if previous and not overwrite:
                return {**_image_info(previous), 'skipped': True}
            blob = bucket.blob(object_name(cosmetic_id))
            blob.metadata = {'cosmetic_id': cosmetic_id, 'sha256': hashlib.sha256(content).hexdigest(),
                             'source_filename': Path(filename).name,
                             'firebaseStorageDownloadTokens': str(uuid.uuid4())}
            blob.cache_control = 'public, max-age=3600'
            blob.upload_from_string(content, content_type=content_type,
                                    if_generation_match=int(previous.generation) if previous else 0, timeout=45)
            return _image_info(blob)
    except PreconditionFailed:
        raise HTTPException(status_code=409, detail='다른 사용자가 이미지를 변경했습니다. 새로고침 후 다시 시도하세요.') from None
    except (GoogleAPIError, DefaultCredentialsError, subprocess.SubprocessError):
        raise HTTPException(status_code=503, detail='이미지 업로드에 실패했습니다. Firebase 인증과 저장소 상태를 확인하세요.') from None
