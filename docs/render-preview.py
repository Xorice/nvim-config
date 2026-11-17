# /// script
# requires-python = ">=3.11"
# dependencies = ["pynvim==0.6.0", "Pillow==12.2.0", "fonttools==4.63.0"]
# ///
"""Export the README GIF from a private Neovim UI. See docs/README.md."""

import argparse
from copy import deepcopy
from functools import lru_cache
import json
import math
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading

import pynvim
from PIL import Image, ImageChops, ImageDraw, ImageFont
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
COLS, ROWS, CW, CH, SCALE, FRAMES = 100, 28, 12, 24, 2, 120
SAMPLE = '''type Player = { name: string }

local function greet(p: Player)
    print(`Hello, {p.name}!`)
end

greet { name = "bread" }
'''


def find_font(name):
    roots = [Path.home() / '.local/share/fonts', Path.home() / '.fonts',
        Path('/usr/share/fonts'), Path('/usr/local/share/fonts'),
        Path.home() / 'Library/Fonts', Path('/Library/Fonts')]
    if os.environ.get('LOCALAPPDATA'):
        roots.insert(0, Path(os.environ['LOCALAPPDATA']) / 'Microsoft/Windows/Fonts')
    if os.environ.get('WINDIR'):
        roots.append(Path(os.environ['WINDIR']) / 'Fonts')
    for root in roots:
        if root.is_dir():
            try:
                match = next(root.rglob(name), None)
                if match:
                    return match
            except PermissionError:
                continue
    return None


def make_fixture(path):
    (path / 'src').mkdir(parents=True)
    (path / 'assets').mkdir()
    main = path / 'src/main.luau'
    main.write_text(SAMPLE.replace('bread', 'world').replace('end\n\ngreet', 'end\ngreet'), encoding='utf-8')
    (path / 'src/types.luau').write_text('export type Player = { name: string }\n', encoding='utf-8')
    (path / 'README.md').write_text('# Luau example\n', encoding='utf-8')
    (path / 'default.project.json').write_text(json.dumps({ 'name': 'ReadmePreview',
        'tree': { '$className': 'DataModel', 'ReplicatedStorage': { '$path': 'src' } } }), encoding='utf-8')
    empty = path.parent / 'empty-git-template'
    empty.mkdir()
    def git(*args):
        subprocess.run(['git', '-C', str(path), '-c', f'core.hooksPath={empty}', *args],
            check=True, capture_output=True, text=True, timeout=20)
    git('init', '--quiet', f'--template={empty}', '--initial-branch=main')
    git('add', '.')
    git('-c', 'user.name=Readme Preview', '-c', 'user.email=preview@localhost',
        '-c', 'commit.gpgsign=false', 'commit', '--quiet', '-m', 'Create isolated preview fixture')
    main.write_text(SAMPLE, encoding='utf-8')


def cmap(path):
    with TTFont(path) as font:
        return set(font.getBestCmap())


class TerminalGrid:
    def __init__(self, font, bold, fallback):
        self.regular = ImageFont.truetype(str(font), 20 * SCALE)
        self.bold = ImageFont.truetype(str(bold or font), 20 * SCALE)
        self.fallback = ImageFont.truetype(str(fallback), 20 * SCALE) if fallback else None
        self.primary_chars, self.fallback_chars = cmap(font), cmap(fallback) if fallback else set()
        self.grids, self.attrs, self.images, self.missing = {}, {}, [], set()
        self.fg, self.bg = 0xbbbebf, 0x121314

    @lru_cache(maxsize=8192)
    def glyph(self, char, attributes, width):
        style = dict(attributes)
        fg, bg = style.get('foreground', self.fg), style.get('background', self.bg)
        if style.get('reverse'):
            fg, bg = bg, fg
        tile = Image.new('RGB', (width * CW * SCALE, CH * SCALE), f'#{bg:06x}')
        draw = ImageDraw.Draw(tile)
        if char and char != ' ':
            point = ord(char[0])
            if 0x2800 <= point <= 0x28ff and point not in self.primary_chars:
                # Older 0xProto releases lack braille. Use the exact Unicode dot
                # mask from Neovim rather than falling back to a proprietary font.
                for bit, (dx, dy) in enumerate(((0,0),(0,1),(0,2),(1,0),(1,1),(1,2),(0,3),(1,3))):
                    if (point - 0x2800) & (1 << bit):
                        x, y, radius = (3 + dx * 6) * SCALE, (3 + dy * 6) * SCALE, .9 * SCALE
                        draw.ellipse((x-radius, y-radius, x+radius, y+radius), fill=f'#{fg:06x}')
            else:
                if point in self.primary_chars:
                    face = self.bold if style.get('bold') else self.regular
                elif point in self.fallback_chars:
                    face = self.fallback
                else:
                    self.missing.add(char)
                    face = self.regular
                ascent, descent = self.regular.getmetrics()
                advance = face.getlength(char)
                layer = Image.new('RGBA', (max(tile.width, math.ceil(advance)), tile.height))
                ImageDraw.Draw(layer).text((0, (CH*SCALE-ascent-descent)//2+ascent), char,
                    font=face, fill=f'#{fg:06x}', anchor='ls')
                if advance > tile.width:
                    layer = layer.resize(tile.size, Image.Resampling.LANCZOS)
                tile.paste(layer, (0, 0), layer)
        if style.get('underline'):
            draw.line((0, 22*SCALE, tile.width, 22*SCALE), fill=f'#{fg:06x}', width=SCALE)
        return tile

    def redraw(self, events):
        for event in events:
            for args in event[1:]:
                name = event[0]
                if name == 'grid_resize':
                    grid, width, height = args
                    self.grids[grid] = [[(' ', 0) for _ in range(width)] for _ in range(height)]
                elif name == 'default_colors_set':
                    if args[0] >= 0: self.fg = args[0]
                    if args[1] >= 0: self.bg = args[1]
                elif name == 'hl_attr_define':
                    self.attrs[args[0]] = args[1]
                elif name == 'grid_clear':
                    for row in self.grids[args[0]]:
                        row[:] = [(' ', 0)] * len(row)
                elif name == 'grid_line':
                    grid, row, col, cells = args[:4]
                    group = 0
                    for cell in cells:
                        if len(cell) > 1: group = cell[1]
                        for _ in range(cell[2] if len(cell) > 2 else 1):
                            self.grids[grid][row][col] = (cell[0], group)
                            col += 1
                elif name == 'grid_scroll':
                    grid, top, bottom, left, right, rows, cols = args
                    old = deepcopy(self.grids[grid])
                    for y in range(top, bottom):
                        for x in range(left, right):
                            sy, sx = y+rows, x+cols
                            self.grids[grid][y][x] = old[sy][sx] if top <= sy < bottom and left <= sx < right else (' ', 0)

    def snapshot(self):
        canvas = Image.new('RGB', (COLS*CW*SCALE, ROWS*CH*SCALE), f'#{self.bg:06x}')
        for y, row in enumerate(self.grids[1]):
            for x, (char, group) in enumerate(row):
                if char == '': continue
                width = 2 if x+1 < COLS and row[x+1][0] == '' else 1
                canvas.paste(self.glyph(char, tuple(sorted(self.attrs.get(group, {}).items())), width),
                    (x*CW*SCALE, y*CH*SCALE))
        self.images.append(canvas.resize((COLS*CW, ROWS*CH), Image.Resampling.LANCZOS))


def capture(nvim_path, scene, terminal):
    nvim = pynvim.attach('child', argv=[nvim_path, '--embed', '--headless', '-u', 'NONE', '-i', 'NONE', '-n', '--noplugin'])
    pid = nvim.eval('getpid()')
    timed_out = threading.Event()
    def abort():
        timed_out.set()
        try: os.kill(pid, signal.SIGTERM)
        except OSError: pass
    watchdog = threading.Timer(120, abort)
    watchdog.daemon = True
    watchdog.start()
    try:
        nvim.ui_attach(COLS, ROWS, rgb=True, ext_linegrid=True, ext_multigrid=False)
        def notify(name, args):
            if name == 'redraw': terminal.redraw(args)
            elif name == 'preview_frame':
                terminal.snapshot()
                if len(terminal.images) % 30 == 0: print(f'Captured {len(terminal.images)}/{FRAMES+1} frames', flush=True)
            elif name == 'preview_done': nvim.stop_loop()
        def setup():
            nvim.exec_lua('''
                local root, fixture, helper, count = ...
                local scene = assert(loadfile(helper))()
                scene.setup(root, fixture)
                for i=0,count do scene.frame(i,count); vim.rpcnotify(1,'preview_frame',i) end
                vim.rpcnotify(1,'preview_done')
            ''', str(ROOT), str(scene), str(ROOT / 'docs/render-preview.lua'), FRAMES)
        nvim.run_loop(None, notify, setup)
    except Exception:
        if timed_out.is_set(): raise RuntimeError('Neovim export timed out after 120 seconds') from None
        raise
    finally:
        watchdog.cancel()
        try: nvim.command('qa!')
        except (EOFError, OSError): pass
        nvim.close()


def save(images, output):
    if len(images) != FRAMES+1 or ImageChops.difference(images[0], images[-1]).getbbox() is not None:
        raise RuntimeError('The exported loop is not seamless; the existing GIF was not replaced')
    swatch = Image.new('RGB', (COLS*CW, ROWS*CH*3))
    for i, index in enumerate((0, 19, 47)): swatch.paste(images[index], (0, i*ROWS*CH))
    palette = swatch.quantize(colors=160, method=Image.Quantize.MEDIANCUT)
    frames = [image.quantize(palette=palette, dither=Image.Dither.NONE) for image in images[:-1]]
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=output.parent, suffix='.gif', delete=False) as file:
        pending = Path(file.name)
    try:
        frames[0].save(pending, save_all=True, append_images=frames[1:], duration=20, loop=0,
            optimize=True, disposal=1, comment=b'Native Neovim grid; local Nerd Font; generator in docs/render-preview.py')
        with Image.open(pending) as gif:
            if gif.n_frames != FRAMES or gif.info.get('loop') != 0:
                raise RuntimeError('GIF frame/loop validation failed')
        os.replace(pending, output)
    finally:
        pending.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--font', type=Path, help='Nerd Font TTF/OTF; auto-detects installed 0xProto Nerd Font Mono')
    parser.add_argument('--bold-font', type=Path, help='Matching bold font; otherwise use the regular font')
    parser.add_argument('--fallback-font', type=Path, help='Optional open font for characters absent from the Nerd Font')
    parser.add_argument('--nvim', default=shutil.which('nvim'), help='Neovim executable, default: nvim on PATH')
    parser.add_argument('--output', type=Path, default=ROOT / 'docs/readme-preview.gif', help='Destination GIF')
    args = parser.parse_args()
    if not args.nvim or not shutil.which('git'):
        parser.error('Neovim 0.12+ and Git must be installed and available on PATH (or specify --nvim)')
    version = subprocess.run([args.nvim, '--version'], check=True, capture_output=True, text=True, timeout=10)
    release = re.search(r'NVIM v(\d+)\.(\d+)', version.stdout)
    if not release or tuple(map(int, release.groups())) < (0, 12):
        parser.error('This exporter requires Neovim 0.12 or newer')
    font = args.font or find_font('0xProtoNerdFontMono-Regular.ttf')
    if not font or not font.is_file(): parser.error('Font not found; pass --font /path/to/YourNerdFont.ttf')
    bold = args.bold_font or font.with_name(font.name.replace('-Regular', '-Bold'))
    fallback = args.fallback_font or find_font('SourceHanSansSC-Regular.otf')
    for label, path in (('--bold-font', args.bold_font), ('--fallback-font', args.fallback_font)):
        if path and not path.is_file(): parser.error(f'{label} does not exist: {path}')
    terminal = TerminalGrid(font, bold if bold.is_file() else font, fallback)
    print(f'Font: {font}', flush=True)
    with tempfile.TemporaryDirectory(prefix='bread-preview-') as directory:
        fixture = Path(directory) / 'scene'
        make_fixture(fixture)
        capture(args.nvim, fixture, terminal)
    if terminal.missing:
        raise RuntimeError('Font lacks glyphs: ' + ', '.join(f'U+{ord(char[0]):04X}' for char in sorted(terminal.missing)))
    save(terminal.images, args.output.resolve())
    print(f'Saved {args.output.resolve()} ({args.output.stat().st_size:,} bytes; 1200x672; 50 FPS; 2.4 seconds; seamless loop)')


if __name__ == '__main__':
    try: main()
    except (RuntimeError, OSError, subprocess.SubprocessError, pynvim.api.common.NvimError) as error:
        print(f'Export failed: {error}', file=sys.stderr)
        raise SystemExit(1)
