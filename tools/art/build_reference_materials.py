"""Extract the coordinated imagegen material atlas; preserve the original unchanged."""
import hashlib,json
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[2]
source=root/'assets/sources/snow_reference_materials_v1/original_atlas.png'
im=Image.open(source).convert('RGB')
out=Image.new('RGB',(640,320))
for i in range(8):
 x,y=i%4,i//4
 cell=im.crop((round(x*im.width/4),round(y*im.height/2),round((x+1)*im.width/4),round((y+1)*im.height/2)))
 out.paste(cell.resize((160,160),Image.Resampling.NEAREST),(x*160,y*160))
out.save(root/'assets/game/snow/reference/materials.png')
(source.parent/'provenance.json').write_text(json.dumps({'source':'OpenAI built-in image_gen tool','model':'not reported by tool','date':'2026-11-05','status':'candidate','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'source_size':list(im.size),'derivation':'Exact 4x2 material-cell extraction; nearest-neighbour native 160px material fields; source unchanged','materials':['snow','packed_trail','rock_strata','timber','snow_slate_roof','granite','cold_water','bridge_boards']},indent=2)+'\n')
print('Built native 640x320 material atlas')
