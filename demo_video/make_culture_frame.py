from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
W,H=1920,1080; bg='#071B17'; white='#FFFFFF'; gold='#E7B04B'; cream='#F7F5EF'
items=[('majuli.jpg','Majuli Island'),('loktak.jpg','Loktak Lake'),('kangla.jpg','Kangla Fort'),('root_bridge.jpg','Living Root Bridge'),('muga.jpg','Muga Silk'),('naga_shawl.jpg','Naga Shawl')]
im=Image.new('RGB',(W,H),bg); d=ImageDraw.Draw(im)
fb='C:/Windows/Fonts/seguisb.ttf'; fr='C:/Windows/Fonts/segoeui.ttf'
d.text((90,55),'North-East Memories',font=ImageFont.truetype(fb,55),fill=white)
d.text((90,122),'Culturally familiar reminiscence activities',font=ImageFont.truetype(fr,30),fill=gold)
for i,(fn,label) in enumerate(items):
    col=i%3; row=i//3; x=90+col*590; y=190+row*415
    src=Image.open(Path('patient_app/assets/culture')/fn).convert('RGB')
    ratio=max(530/src.width,315/src.height); src=src.resize((int(src.width*ratio),int(src.height*ratio)))
    left=(src.width-530)//2; top=(src.height-315)//2; src=src.crop((left,top,left+530,top+315))
    im.paste(src,(x,y)); d.rounded_rectangle((x,y,x+530,y+315),radius=20,outline=cream,width=4)
    d.rectangle((x,y+255,x+530,y+315),fill='#0D2922'); d.text((x+20,y+269),label,font=ImageFont.truetype(fb,27),fill=white)
im.save('demo_video/frames/06_culture.png')
