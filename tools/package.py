from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib

root = Path(__file__).resolve().parents[1]
folder = 'ThanksForTheBuffForever'
files = ['ThanksForTheBuffForever.toc', 'ThanksForTheBuffForever.lua', 'Settings.lua', 'Rules.lua', 'Messages.lua', 'ClickBuff.lua', 'BuffBack.lua', 'Bindings.xml', 'Buffs.lua', 'Media/RoundedIconMask.tga', 'LICENSE', 'NOTICE.md']
for line in (root/folder/files[0]).read_text().splitlines():
    if line.strip() and not line.startswith('#'):
        assert line.strip() in files and (root/folder/line.strip()).is_file(), line
version = next(line.split(':', 1)[1].strip() for line in (root/folder/files[0]).read_text().splitlines() if line.startswith('## Version:'))
out = root/'dist'/f'ThanksForTheBuffForever-{version}.zip'
out.parent.mkdir(exist_ok=True)
with ZipFile(out, 'w', ZIP_DEFLATED) as z:
    for name in files:
        z.write(root/folder/name, folder+'/'+name)
    for name in ['README.md', 'CHANGELOG.md']:
        z.write(root/name, folder+'/'+name)
with ZipFile(out) as z:
    assert z.testzip() is None
    assert len(z.namelist()) == len(files) + 2
print(out)
print('SHA256:', hashlib.sha256(out.read_bytes()).hexdigest())
