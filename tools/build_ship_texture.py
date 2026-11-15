from PIL import Image, ImageDraw
from pathlib import Path
out = Path(__file__).resolve().parents[1] / 'assets/art/base/ship_integrated.png'
# Full-size 224 x 112 pixel art, nearest interpolation (native map texel resolution).
img=Image.new('RGBA',(224,112),(0,0,0,0)); d=ImageDraw.Draw(img)
ink='#25121c'; plum='#4a2238'; shadow='#682a3f'; rusty='#9f3d26'; rust='#df6130'; orange='#ff892d';
cream='#fff0ce'; white='#fff9e8'; silver='#9ca9b0'; metal='#64717f'; darkmetal='#313d4f'; navy='#17293e';
blue='#35cbd6'; brightblue='#aaf8fa'; green='#7ce54e'; gold='#ffdf48';
# terrain shadow under landing struts
d.ellipse((5,91,216,111),fill='#491726')
d.ellipse((18,94,204,108),fill='#8f3b22')
# articulated landing legs, visible under the assembled ship
for x in [22,77,142,198]:
 d.polygon([(x-2,71),(x+6,73),(x+4,95),(x+13,97),(x+14,102),(x-8,102),(x-8,96),(x-3,93)],fill=ink)
 d.polygon([(x,74),(x+4,75),(x+2,92),(x+8,96),(x+6,98),(x-5,98),(x-5,96),(x,91)],fill=silver)
 d.line([(x,84),(x+2,89)],fill=orange,width=2)
# seamless shared lower chassis and connection corridor
d.rectangle((17,52,207,81),fill=ink)
d.rectangle((19,55,205,76),fill=metal)
d.rectangle((19,67,205,79),fill=plum)
d.rectangle((20,55,204,61),fill=cream)
d.line((20,63,203,63),fill=rust,width=3)
d.line((21,74,204,74),fill=orange,width=2)
# greenhouse left pressure bay: single hull joins main corridor
d.polygon([(7,57),(10,34),(23,18),(55,12),(79,22),(91,42),(94,66),(85,82),(12,82)],fill=ink)
d.polygon([(11,57),(15,36),(26,23),(56,16),(76,26),(87,43),(90,65),(82,78),(15,78)],fill=cream)
d.polygon([(18,52),(21,39),(30,27),(55,22),(72,30),(81,43),(84,56)],fill=navy)
d.polygon([(21,51),(25,39),(32,30),(55,26),(70,33),(77,43),(79,52)],fill=blue)
d.line((24,38,75,47),fill=brightblue,width=2)
d.line((36,27,36,53),fill=cream,width=3)
d.line((59,27,59,53),fill=cream,width=3)
d.rectangle((19,56,83,63),fill=darkmetal)
for x,y in [(27,53),(40,54),(53,55),(65,53),(75,54)]:
 d.line((x,y,x-2,y-7),fill='#428c38',width=2);d.polygon([(x-2,y-8),(x-6,y-10),(x-2,y-13),(x+2,y-9)],fill=green)
d.rectangle((21,68,78,75),fill=plum)
for x in [26,36,46,56,66]:d.rectangle((x,69,x+4,70),fill=gold)
# command/life-support center pod (unique shape, prominent entrance)
d.polygon([(76,56),(83,29),(94,13),(123,4),(147,13),(159,30),(167,54),(165,85),(79,85)],fill=ink)
d.polygon([(81,53),(88,31),(98,18),(123,9),(143,17),(153,31),(161,52),(160,81),(84,81)],fill=cream)
d.polygon([(96,26),(108,18),(137,18),(147,28),(149,46),(95,46)],fill=darkmetal)
d.polygon([(100,29),(109,23),(135,23),(143,29),(145,42),(99,42)],fill=blue)
d.line((104,29,138,29),fill=brightblue,width=2)
d.line((103,34,139,34),fill='#69e0e3',width=1)
d.rectangle((81,49,161,55),fill=rust);d.line((83,49,159,49),fill=gold,width=1)
d.rectangle((88,59,156,76),fill=metal)
d.rectangle((90,61,154,73),fill=darkmetal)
for x in [92,151]:d.rectangle((x,65,x+2,67),fill=gold)
# airlock bulges out from a continuous hull
d.rectangle((113,58,139,91),fill=ink)
d.rectangle((116,59,136,88),fill=silver)
d.rectangle((118,63,134,86),fill=navy)
d.rectangle((121,65,131,79),fill=plum)
d.rectangle((125,68,130,76),fill=orange)
d.line((117,82,136,82),fill=gold,width=2)
d.rectangle((117,89,137,95),fill=ink)
d.rectangle((119,90,135,93),fill=orange)
# right science/navigation deck, tied by the same chassis
d.polygon([(154,48),(162,26),(180,19),(207,24),(216,39),(220,62),(212,81),(158,81)],fill=ink)
d.polygon([(159,47),(166,29),(181,23),(205,29),(211,41),(215,61),(209,76),(161,76)],fill=cream)
d.polygon([(167,35),(177,30),(207,35),(210,46),(208,54),(164,54)],fill=darkmetal)
d.rectangle((171,36,204,49),fill=blue)
d.rectangle((173,38,202,41),fill=brightblue)
for x in [178,186,194]:d.line((x,37,x,49),fill=navy,width=2)
d.rectangle((164,58,209,71),fill=metal)
d.rectangle((167,61,205,67),fill=navy)
for x in [170,181,192,201]:d.rectangle((x,62,x+3,64),fill=gold)
# antenna on top of science wing, mounted to the one ship
for x,y in [(188,12),(188,18)]:d.rectangle((x,y,x+2,y+6),fill=silver)
d.polygon([(177,10),(188,3),(200,7),(195,15),(182,16)],fill=ink)
d.polygon([(179,10),(188,6),(198,8),(193,12),(183,13)],fill=metal)
d.line((189,4,195,0),fill=brightblue,width=2)
# structural weld lines and national colors on central hull
d.rectangle((90,72,107,79),fill=gold)
d.rectangle((90,75,107,76),fill='#1555bd')
d.rectangle((90,77,107,79),fill='#df2b36')
# extra outer highlights for crisp 2D pixel presentation
d.line((88,36,92,23,100,15),fill=white,width=2)
d.line((166,29,178,23),fill=white,width=2)
img.save(out)
print(out,img.size)
