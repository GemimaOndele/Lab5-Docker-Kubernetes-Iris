"""Check versioned lab sources and proof archives without printing candidate secrets."""
import subprocess,re,json,io,zipfile,argparse,datetime
from pathlib import Path

parser=argparse.ArgumentParser();parser.add_argument('--report',required=True);args=parser.parse_args()
patterns={
 'private_key':re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
 'github_token':re.compile(r'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{50,})'),
 'storage_account_key':re.compile(r'AccountKey=[A-Za-z0-9+/]{40,}={0,2}',re.I),
 'sas_signature':re.compile(r'(?<![A-Za-z])sig=[A-Za-z0-9%+/]{32,}',re.I),
 'literal_password_or_key':re.compile(r'''(?:client_secret|AZURE_CLIENT_SECRET|API_KEY|password)\s*[:=]\s*["']([A-Za-z0-9+/=_-]{24,})["']''',re.I),
}
findings=[];checked=0;advisories_excluded=0
def scan(data,path,object_id):
 global checked,advisories_excluded
 if path.endswith('.zip'):
  try:
   with zipfile.ZipFile(io.BytesIO(data)) as z:
    for item in z.infolist():
     if not item.is_dir() and item.file_size<10000000:
      scan(z.read(item),path+'!'+item.filename,object_id)
  except zipfile.BadZipFile:findings.append({'path':path,'object':object_id,'kind':'invalid_archive'})
  return
 try:text=data.decode('utf-8')
 except UnicodeDecodeError:return
 if '/trivy-' in path and path.endswith('.json'):
  try:
   doc=json.loads(text)
   for result in doc.get('Results',[]):result.pop('Vulnerabilities',None)
   text=json.dumps(doc);advisories_excluded+=1
  except ValueError:pass
 checked+=1
 for name,pattern in patterns.items():
  if pattern.search(text):findings.append({'path':path,'object':object_id,'kind':name})

objects=subprocess.check_output(['git','rev-list','--objects','--all'],text=True).splitlines()
process=subprocess.Popen(['git','cat-file','--batch'],stdin=subprocess.PIPE,stdout=subprocess.PIPE)
for line in objects:
 parts=line.split(' ',1);oid=parts[0];path=parts[1] if len(parts)>1 else ''
 process.stdin.write((oid+'\n').encode());process.stdin.flush()
 header=process.stdout.readline().decode().split()
 size=int(header[2]);data=process.stdout.read(size);process.stdout.read(1)
 if header[1]=='blob':scan(data,path,oid)
process.stdin.close();process.wait()
report={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'text_blobs_and_archive_entries_checked':checked,'upstream_vulnerability_advisory_text_excluded':advisories_excluded,'findings':findings,'scope':'All fetched Git objects and readable proof archive entries; identifiers are not credentials. This automated check complements review of the lab sources.'}
target=Path(args.report);target.parent.mkdir(parents=True,exist_ok=True);target.write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
raise SystemExit(bool(findings))
