from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

OUT=Path('demo_video/frames'); OUT.mkdir(parents=True,exist_ok=True)
W,H=1920,1080
BG='#071B17'; GREEN='#185A49'; CREAM='#F7F5EF'; GOLD='#E7B04B'; MINT='#A7D7C5'; WHITE='#FFFFFF'
font_path='C:/Windows/Fonts/segoeui.ttf'; bold='C:/Windows/Fonts/seguisb.ttf'

def font(size, heavy=False): return ImageFont.truetype(bold if heavy else font_path,size)
def wrap(draw,text,f,maxw):
    words=text.split(); lines=[]; cur=''
    for w in words:
        test=(cur+' '+w).strip()
        if draw.textbbox((0,0),test,font=f)[2] <= maxw: cur=test
        else: lines.append(cur); cur=w
    if cur: lines.append(cur)
    return lines

def card(name,kicker,title,subtitle,accent=GOLD,bullets=None):
    im=Image.new('RGB',(W,H),BG); d=ImageDraw.Draw(im)
    d.rounded_rectangle((90,80,1830,1000),radius=44,fill='#0D2922',outline=GREEN,width=3)
    d.rounded_rectangle((120,115,145,965),radius=12,fill=accent)
    d.text((210,150),kicker.upper(),font=font(30,True),fill=accent)
    y=255
    for line in wrap(d,title,font(78,True),1450): d.text((210,y),line,font=font(78,True),fill=WHITE); y+=96
    y+=20
    for line in wrap(d,subtitle,font(38),1420): d.text((210,y),line,font=font(38),fill=CREAM); y+=55
    if bullets:
        y+=48
        for b in bullets:
            d.ellipse((220,y+13,236,y+29),fill=MINT)
            d.text((265,y),b,font=font(31),fill=MINT); y+=58
    d.text((210,905),'SAATHI  •  SIH PROTOTYPE',font=font(25,True),fill='#7DA99A')
    im.save(OUT/name)

card('01_title.png','Smart India Hackathon','Saathi — AI Cognitive Companion','A voice-first Android launcher for people living with dementia.')
card('02_problem.png','The challenge','Everyday phone use can become disorienting','Saathi simplifies access, recalls trusted personal context, and supports daily independence.')
card('03_architecture.png','Working prototype','Privacy-first hybrid architecture','Flutter patient UI • Kotlin Android bridge • SQLite offline storage • Firebase sync • Gemini conversation',bullets=['Default HOME launcher and phone actions','Consent-based caretaker synchronization','Culturally familiar cognitive exercises'])
card('04_end.png','Saathi','Familiar. Supportive. Independent.','Daily life becomes gentle cognitive support.',accent=MINT)
print('created',len(list(OUT.glob('*.png'))),'title cards')
