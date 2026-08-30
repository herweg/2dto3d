"""Genera N variantes de color de una textura, rotando el matiz (hue) de
los pixeles no transparentes/no grises. Cada salida es un PNG nuevo con
nombre distinto -> Godot lo importa como una textura real y separada
(no un tinte en tiempo de render), que es justo lo que hace falta para
medir el costo real de variedad de textura, no una simulación de eso.
"""
import sys
import colorsys
from PIL import Image

def recolor(src_path: str, out_path: str, hue_shift: float) -> None:
    img = Image.open(src_path).convert("RGBA")
    pixels = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            hh, ll, ss = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
            hh = (hh + hue_shift) % 1.0
            nr, ng, nb = colorsys.hls_to_rgb(hh, ll, ss)
            pixels[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    img.save(out_path)

if __name__ == "__main__":
    src = sys.argv[1]
    out_dir = sys.argv[2]
    n = int(sys.argv[3])
    import os
    os.makedirs(out_dir, exist_ok=True)
    for i in range(n):
        shift = i / n
        out_path = os.path.join(out_dir, f"variant_{i:02d}.png")
        recolor(src, out_path, shift)
        print("wrote", out_path)
