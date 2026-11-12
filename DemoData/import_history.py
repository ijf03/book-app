import json, plistlib, urllib.request, urllib.error, urllib.parse, getpass, hashlib, uuid, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = plistlib.loads((ROOT / 'GoogleService-Info.plist').read_bytes())
EMAIL = 'dev@test.com'

def request(url, body=None, token=None):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        # Never print URLs, headers, request bodies or credentials.
        result = json.loads(error.read())
        raise RuntimeError('Service rejected request: ' + str(error.code) + ' ' + result.get('error', {}).get('message', 'Unknown error')) from None

def decode(value):
    if 'mapValue' in value:
        return {k: decode(v) for k, v in value['mapValue'].get('fields', {}).items()}
    if 'arrayValue' in value:
        return [decode(v) for v in value['arrayValue'].get('values', [])]
    if 'integerValue' in value:
        return int(value['integerValue'])
    return next(iter(value.values()))

password = getpass.getpass('Demo account password: ')
auth = request('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=' + CONFIG['API_KEY'],
               {'email': EMAIL, 'password': password, 'returnSecureToken': True})
del password
assert auth['email'].lower() == EMAIL
token, uid = auth['idToken'], auth['localId']
del auth
database = 'projects/' + CONFIG['PROJECT_ID'] + '/databases/(default)'
base = 'https://firestore.googleapis.com/v1/' + database + '/documents'
collections = ['books', 'sessions', 'notes', 'reviews', 'goals', 'lists', 'preferences']
existing = {}
for collection in collections:
    page = None
    docs = []
    while True:
        url = base + '/users/' + uid + '/' + collection + '?pageSize=1000'
        if page:
            url += '&pageToken=' + urllib.parse.quote(page)
        result = request(url, token=token)
        docs.extend(result.get('documents', []))
        page = result.get('nextPageToken')
        if not page:
            break
    existing[collection] = {decode(d['fields']['entityID']): d for d in docs}
print('Authenticated intended demo account. Existing record counts:', {c: len(v) for c, v in existing.items()}, flush=True)
print('Existing live goal values:', [decode({'mapValue': {'fields': d['fields']}})['data'] for d in existing['goals'].values() if not decode(d['fields']['deleted'])], flush=True)
if '--apply' not in sys.argv:
    print('Read-only inspection complete.', flush=True)
    raise SystemExit(0)

def encode(value):
    if isinstance(value, bool): return {'booleanValue': value}
    if isinstance(value, int): return {'integerValue': str(value)}
    if isinstance(value, float): return {'doubleValue': value}
    if isinstance(value, str): return {'stringValue': value}
    if isinstance(value, list): return {'arrayValue': {'values': [encode(v) for v in value]}}
    if isinstance(value, dict): return {'mapValue': {'fields': {k: encode(v) for k, v in value.items()}}}
    raise TypeError(type(value).__name__)

fixture = json.loads((Path(__file__).resolve().parent / 'history.json').read_text())
assert fixture['account'] == EMAIL
planned = [r for r in fixture['records'] if r['id'] not in existing[r['collection']]]
assert len({(r['collection'], r['id']) for r in planned}) == len(planned)
writes = []
for row in planned:
    name = database + '/documents/users/' + uid + '/' + row['collection'] + '/' + hashlib.sha256(row['id'].encode()).hexdigest()
    fields = encode({'schemaVersion': 1, 'entityID': row['id'], 'revision': 1,
                     'operationID': str(uuid.uuid4()).upper(), 'deleted': False, 'data': row['data']})['mapValue']['fields']
    writes.append({'update': {'name': name, 'fields': fields}, 'currentDocument': {'exists': False},
                   'updateTransforms': [{'fieldPath': 'updatedAt', 'setToServerValue': 'REQUEST_TIME'}]})
print('Creating only missing demo records:', len(writes), '; preserving all existing documents.', flush=True)
manifest = {'account': EMAIL, 'generatedAt': fixture['generatedAt'], 'status': 'prepared', 'records': planned}
manifest_path = ROOT / 'DEMO_ACCOUNT_DATA.json'
if writes:
    manifest_path.write_text(json.dumps(manifest, indent=2))
    manifest['committedRecordIDs'] = []
    # Small requests stay below Firestore's security-rule evaluation budget.
    for offset in range(0, len(writes), 2):
        batch = writes[offset:offset + 2]
        result = request(base + ':commit', {'writes': batch}, token)
        assert len(result['writeResults']) == len(batch)
        manifest['committedRecordIDs'].extend(r['collection'] + '/' + r['id'] for r in planned[offset:offset + 2])
        manifest['status'] = 'partially_committed'
        manifest_path.write_text(json.dumps(manifest, indent=2))
    manifest['status'] = 'committed'
    manifest['commitTime'] = result['commitTime']
    manifest_path.write_text(json.dumps(manifest, indent=2))
    print('Server commits succeeded.', flush=True)

verified = {}
for collection in collections:
    docs, page = [], None
    while True:
        url = base + '/users/' + uid + '/' + collection + '?pageSize=1000'
        if page: url += '&pageToken=' + urllib.parse.quote(page)
        result = request(url, token=token)
        docs.extend(result.get('documents', []))
        page = result.get('nextPageToken')
        if not page: break
    found = {decode(d['fields']['entityID']): d for d in docs}
    for key, old in existing[collection].items():
        assert found[key]['fields'] == old['fields'], 'An existing document changed during verification'
    for row in planned:
        if row['collection'] != collection: continue
        decoded = decode({'mapValue': {'fields': found[row['id']]['fields']}})
        assert decoded['data'] == row['data'] and decoded['revision'] == 1 and not decoded['deleted']
    verified[collection] = len(found)
if writes:
    manifest['status'] = 'verified'
    manifest['verifiedCollectionCounts'] = verified
    manifest_path.write_text(json.dumps(manifest, indent=2))
print('Verified server records and preservation of pre-existing documents:', verified, flush=True)
del token
