"""Local-only provider contracts. Never configured by the deployed resolver."""
from pathlib import Path
from uuid import UUID
from urllib.parse import urlsplit
import os
import httpx


def local_origin(value: str) -> str:
    u = urlsplit(value)
    if (u.scheme != 'http' or u.hostname != '127.0.0.1' or not u.port
            or u.username or u.password or u.path or u.query or u.fragment):
        raise ValueError('This experimental adapter only accepts explicit loopback HTTP origins')
    return value


class AuthRejected(Exception):
    pass


class SupabaseAuth:
    """Server verifies the bearer with GoTrue on every operation; never decodes claims."""
    def __init__(self, origin: str, client=None):
        self.origin = local_origin(origin)
        self.client = client or httpx.Client(timeout=5, follow_redirects=False, trust_env=False)

    def user(self, token: str) -> str:
        if not token or len(token) > 8192:
            raise AuthRejected()
        try:
            r = self.client.get(self.origin + '/user', headers={'Authorization': 'Bearer ' + token})
            r.raise_for_status()
            user = r.json()
            if user.get('is_anonymous') is not False or user.get('role') != 'authenticated':
                raise AuthRejected()
            return str(UUID(user['id']))
        except (httpx.HTTPError, ValueError, KeyError, TypeError):
            raise AuthRejected() from None


class DiskPrivateStore:
    """Durable local control provider, not Supabase Storage/RLS emulation."""
    def __init__(self, root: Path):
        self.root = root
        root.mkdir(mode=0o700, parents=True, exist_ok=True)
        root.chmod(0o700)

    def path(self, key):
        return self.root / (str(UUID(key)) + '.mp4')

    def put(self, key, data):
        with self.path(key).open('xb') as f:
            os.chmod(f.name, 0o600)
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
        fd = os.open(self.root, os.O_RDONLY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)

    def get(self, key):
        return self.path(key).read_bytes()

    def delete(self, key):
        self.path(key).unlink(missing_ok=True)


class SupabasePrivateStore:
    """Server-only local Storage REST adapter; no public URL or upsert path.

    The injected credential must stay on the server. Production activation is
    intentionally impossible here. Bucket creation/ACL changes are not exposed.
    """
    def __init__(self, origin: str, credential: str, client=None):
        self.origin = local_origin(origin)
        self.client = client or httpx.Client(timeout=10, follow_redirects=False, trust_env=False)
        self.headers = {'Authorization': 'Bearer ' + credential, 'apikey': credential}
        self.bucket = 'tv2-private-lab'
        r = self.client.get(self.origin + '/bucket/' + self.bucket, headers=self.headers)
        r.raise_for_status()
        config = r.json()
        if (config.get('public') is not False or config.get('file_size_limit') != 5242880
                or config.get('allowed_mime_types') != ['video/mp4']):
            raise ValueError('Explicit private, size-limited MP4 bucket required')

    def url(self, key):
        return self.origin + '/object/' + self.bucket + '/' + str(UUID(key)) + '.mp4'

    def put(self, key, data):
        r = self.client.post(self.url(key), headers={**self.headers, 'Content-Type': 'video/mp4', 'x-upsert': 'false'}, content=data)
        r.raise_for_status()

    def get(self, key):
        r = self.client.get(self.url(key), headers=self.headers)
        r.raise_for_status()
        if len(r.content) > 5242880:
            raise ValueError('Oversized stored object')
        return r.content

    def delete(self, key):
        r = self.client.request('DELETE', self.origin + '/object/' + self.bucket, headers=self.headers,
                               json={'prefixes': [str(UUID(key)) + '.mp4']})
        r.raise_for_status()
