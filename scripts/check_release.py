"""Static synthetic-candidate secret, transport and Android recovery boundary gate."""
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
ANDROID='{http://schemas.android.com/apk/res/android}'
manifest=ET.parse(ROOT/'udhaarkhata/android/app/src/main/AndroidManifest.xml').getroot()
application=manifest.find('application')
assert application is not None
for key,value in [('allowBackup','false'),('fullBackupContent','false'),('usesCleartextTraffic','false')]:
    assert application.get(ANDROID+key)==value,key
permissions={p.get(ANDROID+'name') for p in manifest.findall('uses-permission')}
assert 'android.permission.INTERNET' in permissions
assert permissions <= {'android.permission.CAMERA','android.permission.INTERNET'},permissions
rules=ET.parse(ROOT/'udhaarkhata/android/app/src/main/res/xml/data_extraction_rules.xml').getroot()
for area in ['cloud-backup','device-transfer']:
    assert {e.get('domain') for e in rules.find(area).findall('exclude')} >= {'database','sharedpref','file','root','external'},area
client=(ROOT/'udhaarkhata/lib/core/network/api_client.dart').read_text()
assert client.count("uri.scheme != 'https'")==2
files=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z'],cwd=ROOT).decode().split('\0')
patterns=[re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
          re.compile(r'(?<![A-Za-z0-9])(?:ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{70,}|AKIA[A-Z0-9]{16})(?![A-Za-z0-9])')]
checked=0
for name in files:
    path=ROOT/name
    if not name or path.is_symlink() or not path.is_file() or path.suffix.lower() not in {'.dart','.ts','.js','.mjs','.py','.sql','.json','.jsonc','.yaml','.yml','.xml','.kts','.md','.arb','.env','.pem'}:
        continue
    content=path.read_text(errors='replace')
    assert not any(pattern.search(content) for pattern in patterns),f'Secret signature in {name}'
    checked+=1
print(f'Static release checks passed: {checked} text files; TLS-only client, no contacts, backup/transfer excluded, cleartext disabled, no recognized private-key/token signatures.')
print('Not an entropy audit or physical-device/network-trace check; final APK signer/configuration audit is a separate CI gate.')
