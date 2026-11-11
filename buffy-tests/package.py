"""Build a deterministic manual-install ZIP using only Python's standard library."""
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED
import hashlib

root = Path(__file__).resolve().parents[1]
output = root / 'dist/BuffyLover-0.6.1.zip'
output.parent.mkdir(exist_ok=True)
files = [(p, 'BuffyLover/' + p.name) for p in sorted((root / 'BuffyLover').iterdir()) if p.is_file()]
files += [(root / name, 'BuffyLover/' + name) for name in ('LICENSE', 'README.md', 'CHANGELOG.md', 'TESTING.md', 'RESEARCH.md')]
with ZipFile(output, 'w', compression=ZIP_DEFLATED) as archive:
    for source, destination in files:
        info = ZipInfo(destination, (2026, 11, 10, 0, 0, 0))
        info.compress_type = ZIP_DEFLATED
        archive.writestr(info, source.read_bytes())
with ZipFile(output) as archive:
    assert archive.testzip() is None
    for source, destination in files:
        assert archive.read(destination) == source.read_bytes()
print(f'PASS: {len(files)} packaged files verified against source.')
print(f'{output}\nSHA256 {hashlib.sha256(output.read_bytes()).hexdigest()}')
