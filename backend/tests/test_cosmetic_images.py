import io
import unittest
from unittest.mock import MagicMock, patch

from fastapi import HTTPException
from fastapi.testclient import TestClient
from PIL import Image

from main import app
from services.admin import cosmetic_image_service as images
from services.staff import staff_auth_service


class CosmeticImagesTests(unittest.TestCase):
    def test_validates_image_bytes_instead_of_filename(self):
        output = io.BytesIO()
        Image.new('RGB', (2, 2)).save(output, format='PNG')
        self.assertEqual(images.validate_image(output.getvalue()), 'image/png')
        for content in (b'', b'not an image', b'x' * (images.MAX_IMAGE_BYTES + 1)):
            with self.assertRaises(HTTPException) as error:
                images.validate_image(content)
            self.assertEqual(error.exception.status_code, 422)

    def test_upload_uses_cosmetic_id_and_preserves_existing_when_seeding(self):
        output = io.BytesIO()
        Image.new('RGB', (2, 2)).save(output, format='PNG')
        bucket = MagicMock()
        bucket.get_blob.return_value = None
        blob = bucket.blob.return_value
        blob.name = 'cosmetics/c1/image'
        blob.generation = 1
        with patch.object(images, 'get_bucket', return_value=bucket):
            result = images.upload_image('c1', output.getvalue(), 'cream.png')
            bucket.blob.assert_called_once_with('cosmetics/c1/image')
            self.assertEqual(blob.metadata['cosmetic_id'], 'c1')
            self.assertIn('cosmetics%2Fc1%2Fimage?alt=media&token=', result['image_url'])
            self.assertEqual(blob.upload_from_string.call_args.kwargs['if_generation_match'], 0)
            bucket.get_blob.return_value = blob
            self.assertTrue(images.upload_image('c1', output.getvalue(), overwrite=False)['skipped'])
            self.assertEqual(blob.upload_from_string.call_count, 1)

    def test_upload_requires_admin_and_read_requires_staff(self):
        client = TestClient(app)
        self.addCleanup(app.dependency_overrides.clear)
        path = '/admin/cosmetics/c1/image'
        self.assertEqual(client.post(path, files={'file': ('a.png', b'abc')}).status_code, 401)
        self.assertEqual(client.get('/staff/cosmetics/c1/image').status_code, 401)
        app.dependency_overrides[staff_auth_service.require_staff] = lambda: {'employee_id': 'e1', 'employee_role': 'STAFF'}
        app.dependency_overrides[staff_auth_service.bearer_scheme] = lambda: object()
        self.assertEqual(client.post(path, files={'file': ('a.png', b'abc')}).status_code, 403)
        app.dependency_overrides[staff_auth_service.require_staff] = lambda: {'employee_id': 'e1', 'employee_role': 'ADMIN'}
        with patch('routers.admin.cosmetic_image_router._require_cosmetic'), patch('routers.admin.cosmetic_image_router.upload_image', return_value={'image_url': 'url'}) as upload:
            self.assertEqual(client.post(path, files={'file': ('a.png', b'abc')}).status_code, 200)
            upload.assert_called_once_with('c1', b'abc', 'a.png')
