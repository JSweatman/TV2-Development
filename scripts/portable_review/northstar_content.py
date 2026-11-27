"""Original silent sample introduction; local shapes/fonts only, no paid assets."""
from pathlib import Path
import subprocess
import tempfile

SCENES = [
    ('Northstar Workshop', ['Your first woodwork class.', 'Make a small shelf.']),
    ('Learn by making', ['A tutor guides each step.', 'No past skill needed.']),
    ('Bring two things', ['Closed-toe shoes.', 'A water bottle.']),
    ('We supply the rest', ['Wood, tools and eye protection.', 'Tap WEBSITE for class notes.']),
]
TRANSCRIPT = ' '.join(' '.join([title] + lines) for title, lines in SCENES)


def make_intro(destination):
    font = Path('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')
    if not font.is_file():
        raise RuntimeError('Local DejaVu Sans font required')
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        filters = [
            'drawbox=x=0:y=0:w=768:h=8:color=0xe4c987:t=fill',
            'drawbox=x=32:y=105:w=704:h=2:color=0xe4c987:t=fill',
            # Simple original shelf motif, separate from the caption text.
            'drawbox=x=478:y=285:w=210:h=16:color=0xb58a59:t=fill',
            'drawbox=x=500:y=301:w=12:h=28:color=0xb58a59:t=fill',
            'drawbox=x=654:y=301:w=12:h=28:color=0xb58a59:t=fill',
        ]
        def text(value, label, y, size, color, enable=None):
            path = root / (label + '.txt');path.write_text(value)
            effect = f"drawtext=fontfile={font}:textfile={path}:x=32:y={y}:fontsize={size}:fontcolor={color}"
            if enable: effect += f":enable='{enable}'"
            filters.append(effect)
        text('FICTIONAL SAMPLE CLASS', 'sample', 384, 24, '0xe4c987')
        for i, (title, lines) in enumerate(SCENES):
            enable = f'gte(t,{i*4})*lt(t,{(i+1)*4})'
            text(title, f'title-{i}', 38, 46, 'white', enable)
            for j, line in enumerate(lines):
                text(line, f'caption-{i}-{j}', 142+j*58, 40, 'white', enable)
        subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i','color=c=0x101920:s=768x432:r=15',
            '-vf',','.join(filters),'-t','16','-an','-c:v','libx264','-pix_fmt','yuv420p',
            '-movflags','+faststart',str(destination)],check=True)
