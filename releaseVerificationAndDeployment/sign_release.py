"""Fixed-authority signing and independent verification of WAIT candidates."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile
from mod_pipeline import ROOT, inventory, verify

IDENTITY = json.loads((ROOT/'releaseVerificationAndDeployment/signing-identity.json').read_text())

def validate_keys(private, public):
    authority = IDENTITY['authority'].encode()
    if private.split(b'\0', 1)[0] != authority or public.split(b'\0', 1)[0] != authority:
        raise ValueError('Wrong key authority')
    if hashlib.sha256(public).hexdigest() != IDENTITY['publicKeySHA256']:
        raise ValueError('Wrong public key fingerprint')

def decode_pair(secret):
    if not secret:
        raise ValueError('WALDO_SIGNING_KEYPAIR is required; no fallback')
    try:
        pair = json.loads(secret)
        private = base64.b64decode(pair['privateKey'], validate=True)
        public = base64.b64decode(pair['publicKey'], validate=True)
    except (ValueError, KeyError, TypeError):
        raise ValueError('Invalid signing secret') from None
    validate_keys(private, public)
    return private, public

def check(package, hemtt):
    key = package/'keys'/f'{IDENTITY["authority"]}.bikey'
    if not key.is_file() or hashlib.sha256(key.read_bytes()).hexdigest() != IDENTITY['publicKeySHA256']:
        raise ValueError('Missing or mismatched public key')
    rows = inventory(package)
    expected = {p.relative_to(package).as_posix()+f'.{IDENTITY["authority"]}.bisign' for p in package.rglob('*.pbo')}
    actual = {n for n in rows if n.endswith('.bisign')}
    if not expected or expected != actual or {n for n in rows if n.endswith('.bikey')} != {key.relative_to(package).as_posix()}:
        raise ValueError('Unexpected signature/key inventory')
    if any(n.lower().endswith(('.biprivatekey','.pem','.key')) or n.lower().endswith('signing-keypair.json') for n in rows):
        raise ValueError('Forbidden private material in package')
    results=[]
    for pbo in sorted(package.rglob('*.pbo')):
        result=subprocess.run([hemtt,'utils','verify',str(pbo),str(key)],capture_output=True,text=True)
        if result.returncode or 'Verified!' not in result.stdout+result.stderr:
            raise ValueError('Independent signature verification failed')
        with tempfile.TemporaryDirectory(prefix='wait-negative-') as temporary:
            scratch=Path(temporary); copy=scratch/pbo.name; shutil.copyfile(pbo,copy)
            signature=pbo.with_name(pbo.name+f'.{IDENTITY["authority"]}.bisign')
            data=bytearray(signature.read_bytes())
            if len(data)<32: raise ValueError('Truncated signature')
            data[-1]^=255
            copy.with_name(signature.name).write_bytes(data)
            invalid=subprocess.run([hemtt,'utils','verify',str(copy),str(key)],capture_output=True,text=True)
            if invalid.returncode==0 and 'Verified!' in invalid.stdout+invalid.stderr:
                raise ValueError('Damaged signature accepted')
        results.append({'pbo':pbo.relative_to(package).as_posix(),'valid':True,'damagedRejected':True})
    return results

def seal_signed(package, source):
    # Signing changes files, never the source identity captured by the build.
    rows=inventory(package)
    record=dict(source,files=rows,fingerprint=hashlib.sha256(json.dumps(rows,sort_keys=True).encode()).hexdigest())
    record['signing']={'authority':IDENTITY['authority'],'publicKeySHA256':IDENTITY['publicKeySHA256']}
    (package/'wait-build.json').write_text(json.dumps(record,indent=2)+'\n')
    return record

def sign(package, signer, hemtt, keys=None, native=False):
    source=verify(package)
    if list(package.rglob('*.bisign')) or list(package.rglob('*.bikey')):
        raise ValueError('Unsigned package required')
    secret=os.environ.pop('WALDO_SIGNING_KEYPAIR',None)
    if native and hashlib.sha256(Path(signer).read_bytes()).hexdigest()!=IDENTITY['nativeSignerSHA256']:
        raise ValueError('Unpinned native signer')
    with tempfile.TemporaryDirectory(prefix='wait-signing-') as temporary:
        scratch=Path(temporary).resolve()
        if scratch.is_relative_to(ROOT): raise ValueError('Private key scratch must be outside checkout')
        scratch.chmod(0o700)
        if keys:
            keys=keys.resolve()
            if keys.is_relative_to(ROOT): raise ValueError('External keys required')
            private=(keys/f'{IDENTITY["authority"]}.biprivatekey').read_bytes()
            public=(keys/f'{IDENTITY["authority"]}.bikey').read_bytes()
            validate_keys(private,public)
        else: private,public=decode_pair(secret)
        private_path=scratch/f'{IDENTITY["authority"]}.biprivatekey'
        private_path.write_bytes(private); private_path.chmod(0o600)
        public_path=scratch/f'{IDENTITY["authority"]}.bikey'; public_path.write_bytes(public)
        for pbo in sorted(package.rglob('*.pbo')):
            signature=pbo.with_name(pbo.name+f'.{IDENTITY["authority"]}.bisign')
            command=[signer,str(private_path),str(pbo)] if native else [signer,'sign',str(private_path),str(pbo),str(signature)]
            result=subprocess.run(command,capture_output=True)
            if result.returncode or not signature.is_file(): raise ValueError('Signing failed')
        (package/'keys').mkdir(exist_ok=True)
        shutil.copyfile(public_path,package/'keys'/public_path.name)
    checks=check(package,hemtt)
    record=seal_signed(package,source)
    return record,checks

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('package',type=Path)
    parser.add_argument('--signer')
    parser.add_argument('--hemtt',default='hemtt')
    parser.add_argument('--key-directory',type=Path)
    parser.add_argument('--native',action='store_true')
    parser.add_argument('--output',type=Path)
    args=parser.parse_args(); package=args.package.resolve()
    if args.signer: record,checks=sign(package,args.signer,args.hemtt,args.key_directory,args.native)
    else: record=verify(package); checks=check(package,args.hemtt)
    if args.output:
        args.output.mkdir(parents=True,exist_ok=False)
        archive=args.output/'wait-candidate.zip'
        with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as zipped:
            for path in sorted(package.rglob('*')):
                if path.is_file(): zipped.write(path,path.relative_to(package).as_posix())
        with zipfile.ZipFile(archive) as zipped:
            for name in zipped.namelist():
                if hashlib.sha256(zipped.read(name)).hexdigest()!=hashlib.sha256((package/name).read_bytes()).hexdigest():
                    raise ValueError('Archive hash mismatch')
        sha=hashlib.sha256(archive.read_bytes()).hexdigest()
        (args.output/'wait-candidate.zip.sha256').write_text(sha+'  wait-candidate.zip\n')
        (args.output/'signing-verification.json').write_text(json.dumps({'sourceCommit':record['commit'],'sourceDirty':record['dirty'],'packageFingerprint':record['fingerprint'],'archiveSHA256':sha,'publicKeySHA256':IDENTITY['publicKeySHA256'],'checks':checks,'published':False},indent=2)+'\n')
    print('WAIT fixed-key signing/verification passed')

if __name__=='__main__':
    try: main()
    except (ValueError,OSError,KeyError):
        raise SystemExit('WAIT signing failed; check key identity, package and pinned tools. Secret/tool output suppressed.') from None