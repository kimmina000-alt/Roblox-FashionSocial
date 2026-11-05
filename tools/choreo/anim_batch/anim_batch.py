"""영상 → 애니메이션 일괄 처리 (user 2026-11-05: "로블록스 스튜디오에 비디오 선택해서
애니메이션 따는 단순 반복 작업하는 프로그램 만들어")

Roblox Studio 애니메이션 편집기에서 영상마다 손으로 하던 일을 차례로 되풀이한다:
  1. ⋯ → 가져오기 → 라이브 애니메이션 제작기 → 안내 창의 "비디오 선택" →
     "비디오 선택" 파일 창에 영상 경로 → 열기
  2. "애니메이션을 처리 중입니다" 창이 사라질 때까지 기다림
  3. ⋯ → Roblox에 게시 → Asset Configuration 창의 제목에 "<접두어><번호>" → 저장
  4. 업로드 창이 닫힐 때까지 기다림, 다음 영상

Studio 화면 안의 버튼(⋯, 메뉴, 게시 창)은 Windows가 읽을 수 없어서, 처음 한 번
마우스를 그 자리에 두고 F8을 눌러 위치를 기록한다(설정 → anim_batch_points.json).
위치는 Studio 창 / 게시 창의 왼쪽 위 기준이라 창을 옮겨도 되지만, 창 크기나
패널 배치를 바꾸면 다시 기록한다.

추가 설치 없음(Python 3 + Pillow). 멈추기: 창의 "멈춤" 버튼 또는 F9.
"""
import ctypes
import ctypes.wintypes as wt
import json
import os
import re
import threading
import time
import tkinter as tk
from tkinter import filedialog, ttk

from PIL import ImageGrab

try:
    ctypes.windll.shcore.SetProcessDpiAwareness(2)  # real pixels, the same as the screen grab
except Exception:
    ctypes.windll.user32.SetProcessDPIAware()

user32 = ctypes.windll.user32
HERE = os.path.dirname(os.path.abspath(__file__))
POINTS_FILE = os.path.join(HERE, "anim_batch_points.json")
LOG_FILE = os.path.join(HERE, "anim_batch_log.csv")

# --------------------------------------------------------------------------
# Windows: windows, mouse, keys
# --------------------------------------------------------------------------

def windows():
    out = []

    @ctypes.WINFUNCTYPE(ctypes.c_bool, wt.HWND, wt.LPARAM)
    def cb(hwnd, _):
        if user32.IsWindowVisible(hwnd):
            n = user32.GetWindowTextLengthW(hwnd)
            if n:
                buf = ctypes.create_unicode_buffer(n + 1)
                user32.GetWindowTextW(hwnd, buf, n + 1)
                out.append((hwnd, buf.value))
        return True

    user32.EnumWindows(cb, 0)
    return out


def find_window(part):
    for hwnd, title in windows():
        if part in title:
            return hwnd
    return None


def rect(hwnd):
    r = wt.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(r))
    return r.left, r.top, r.right, r.bottom


def cursor():
    p = wt.POINT()
    user32.GetCursorPos(ctypes.byref(p))
    return p.x, p.y


def click(x, y):
    user32.SetCursorPos(int(x), int(y))
    time.sleep(0.08)
    user32.mouse_event(0x0002, 0, 0, 0, 0)  # left down
    time.sleep(0.05)
    user32.mouse_event(0x0004, 0, 0, 0, 0)  # left up


def key(vk, up=False):
    user32.keybd_event(vk, 0, 0x0002 if up else 0, 0)


def press(*vks):
    for vk in vks:
        key(vk)
        time.sleep(0.03)
    for vk in reversed(vks):
        key(vk, True)
        time.sleep(0.03)


VK_CTRL, VK_A, VK_V, VK_ENTER, VK_ESC = 0x11, 0x41, 0x56, 0x0D, 0x1B


def pixel(x, y):
    return ImageGrab.grab(bbox=(x, y, x + 1, y + 1), all_screens=True).getpixel((0, 0))[:3]


def near_white(c):
    return min(c) >= 225


# --------------------------------------------------------------------------
# the points
# --------------------------------------------------------------------------

STEPS = [
    ("dots", "studio", "애니메이션 편집기 왼쪽 위 ⋯ 버튼 위에 마우스를 두고 F8"),
    ("import", "studio", "⋯를 눌러 메뉴를 열고 '가져오기' 위에서 F8"),
    ("from_file", "studio", "'가져오기' 옆에 열린 '라이브 애니메이션 제작기' 위에서 F8"),
    ("video_btn", "studio", "'라이브 애니메이션 제작기'를 눌러 뜬 안내 창의 파란 '비디오 선택' 위에서 F8, 그다음 '취소'"),
    ("publish", "studio", "Esc로 닫고 ⋯를 다시 열어 'Roblox에 게시' 위에서 F8 (누르지 마세요)"),
    ("busy", "studio", "Esc로 메뉴를 닫고, 편집기 가운데(처리 중 흰 창이 뜨는 자리) 위에서 F8"),
    ("title", "asset", "⋯ → 'Roblox에 게시'를 눌러 창을 연 뒤 '제목' 칸 위에서 F8"),
    ("save", "asset", "같은 창 오른쪽 아래 파란 '저장' 버튼 위에서 F8, 그다음 '취소'로 닫기"),
]
ASSET_TITLE = "Asset Configuration"
VIDEO_TITLE = "비디오 선택"


def load_points():
    try:
        with open(POINTS_FILE, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


# --------------------------------------------------------------------------
# the run
# --------------------------------------------------------------------------

class Stop(Exception):
    pass


class Runner:
    def __init__(self, app):
        self.app = app
        self.stop = False

    def check(self):
        if self.stop:
            raise Stop()

    def sleep(self, s):
        end = time.time() + s
        while time.time() < end:
            self.check()
            time.sleep(0.1)

    def wait(self, cond, timeout, what):
        end = time.time() + timeout
        while time.time() < end:
            self.check()
            if cond():
                return True
            time.sleep(0.25)
        raise RuntimeError(what + " 시간 초과")

    def at(self, name, hwnd):
        p = self.app.points[name]
        l, t, _, _ = rect(hwnd)
        return l + p[0], t + p[1]

    def paste(self, text):
        self.app.set_clipboard(text)
        time.sleep(0.15)
        press(VK_CTRL, VK_A)
        time.sleep(0.05)
        press(VK_CTRL, VK_V)

    def busy_state(self, studio):
        """'none' (no box), 'working' or 'done' for the white processing box
        round the busy point. (user 2026-11-05: the "작업 완료!" box can stay
        on screen, so "done" is read from its progress bar: blue to the end)"""
        # (works in the light and the dark Studio theme: only the box's progress
        # bar is read, a long horizontal blue run; the playhead is a thin
        # vertical line and the key rows are grey)
        x, y = self.at("busy", studio)
        w, h = 230, 130
        img = ImageGrab.grab(bbox=(x - w, y - h, x + w, y + h), all_screens=True).convert("RGB")
        W, H = img.size
        px = img.load()

        def blue(c):
            r, g, b = c
            return b > 170 and b - r > 60

        def grey(c):
            r, g, b = c
            return abs(r - g) < 16 and abs(g - b) < 16 and 140 < r < 236

        rows = []  # (longest blue run, row, its end x) per row
        for yy in range(0, H, 2):
            run, top = 0, (0, yy, 0)
            for xx in range(W):
                if blue(px[xx, yy]):
                    run += 1
                    if run > top[0]:
                        top = (run, yy, xx)
                else:
                    run = 0
            rows.append(top)
        longest = max(r[0] for r in rows)
        if longest < 40:
            return "none", longest, 0.0
        # the bar's middle row (its top and bottom edges blend into the box)
        bar = [r for r in rows if r[0] >= longest * 0.9]
        run, row, end = bar[len(bar) // 2]
        tail = 0
        xx = end + 1
        # (a thin dark edge can sit between the blue and the grey rest)
        skip = 0
        while xx < W and skip < 4 and not grey(px[xx, row]):
            xx += 1
            skip += 1
        while xx < W and grey(px[xx, row]):
            tail += 1
            xx += 1
        fill = run / (run + tail)
        return ("done" if tail <= max(3, run * 0.02) else "working"), run, fill

    def menu(self, studio, *names):
        for n in names:
            click(*self.at(n, studio))
            self.sleep(0.7)

    def one(self, studio, path, title):
        log = self.app.log
        # 1. import the video
        log(f"  가져오기: {os.path.basename(path)}")
        self.menu(studio, "dots", "import", "from_file")
        # (the user 2026-11-05: 라이브 애니메이션 제작기 first shows a note with
        # 취소 / 비디오 선택; the file window opens from 비디오 선택)
        self.sleep(0.8)
        click(*self.at("video_btn", studio))
        self.wait(lambda: find_window(VIDEO_TITLE) is not None, 15, "비디오 선택 창")
        self.sleep(0.6)
        self.paste(path)
        self.sleep(0.2)
        press(VK_ENTER)
        self.wait(lambda: find_window(VIDEO_TITLE) is None, 10, "비디오 선택 창 닫기")
        # 2. processing
        log("  처리 중...")
        self.wait(lambda: self.busy_state(studio)[0] != "none", 90, "처리 창(파란 진행 막대) 나타나기")
        quiet = None
        end = time.time() + 20 * 60
        last_note = 0.0
        while True:
            self.check()
            if time.time() > end:
                raise RuntimeError("처리 20분 초과")
            state, run, fill = self.busy_state(studio)
            if time.time() - last_note > 10:
                last_note = time.time()
                log(f"    (진행 막대 {fill:.0%})")
            if state == "done":
                log("  작업 완료")
                break
            # (the box closed by itself after it was seen working)
            if state == "none":
                quiet = quiet or time.time()
                if time.time() - quiet > 5:
                    log("  처리 창이 닫혀서 완료로 봐요")
                    break
            else:
                quiet = None
            time.sleep(0.5)
        self.sleep(2.0)
        # 3. publish
        log(f"  게시: {title}")
        self.menu(studio, "dots", "publish")
        self.wait(lambda: find_window(ASSET_TITLE) is not None, 30, "게시 창")
        self.sleep(2.0)
        asset = find_window(ASSET_TITLE)
        click(*self.at("title", asset))
        self.sleep(0.3)
        self.paste(title)
        self.sleep(0.4)
        click(*self.at("save", asset))
        # 4. upload
        self.wait(lambda: find_window(ASSET_TITLE) is None, 10 * 60, "업로드")
        self.sleep(2.0)

    def run(self, files, prefix):
        app = self.app
        studio = app.studio_hwnd()
        if not studio:
            app.log("Studio 창을 찾지 못했어요.")
            return
        done = 0
        try:
            for path, number in files:
                self.check()
                title = f"{prefix}{number}"
                app.log(f"[{done + 1}/{len(files)}] {os.path.basename(path)} → {title}")
                t0 = time.time()
                try:
                    self.one(studio, path, title)
                except RuntimeError as e:
                    app.log(f"  ✗ {e} — 여기서 멈춰요. 화면을 확인해 주세요.")
                    write_log(path, title, "실패: " + str(e), t0)
                    return
                write_log(path, title, "완료", t0)
                done += 1
                app.log(f"  ✓ 완료 ({time.time() - t0:.0f}초)")
            app.log(f"끝: {done}개 완료")
        except Stop:
            app.log(f"멈춤 ({done}개 완료)")
        finally:
            app.running_done()


def write_log(path, title, status, t0):
    new = not os.path.exists(LOG_FILE)
    with open(LOG_FILE, "a", encoding="utf-8-sig") as f:
        if new:
            f.write("시각,파일,제목,결과,초\n")
        f.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')},{path},{title},{status},{time.time() - t0:.0f}\n")


def video_files(folder, first, last):
    out = []
    for name in os.listdir(folder):
        stem, ext = os.path.splitext(name)
        if ext.lower() in (".mp4", ".mov") and re.fullmatch(r"\d+", stem):
            n = int(stem)
            if (first is None or n >= first) and (last is None or n <= last):
                out.append((os.path.join(folder, name), n))
    return sorted(out, key=lambda e: e[1])


# --------------------------------------------------------------------------
# the window
# --------------------------------------------------------------------------

class App:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("영상 → 애니메이션 일괄 처리")
        self.root.attributes("-topmost", True)
        self.points = load_points()
        self.calib_index = None
        self.runner = None
        f = ttk.Frame(self.root, padding=10)
        f.grid(sticky="nsew")

        ttk.Label(f, text="Studio 창").grid(row=0, column=0, sticky="w")
        self.studio_var = tk.StringVar()
        self.studio_box = ttk.Combobox(f, textvariable=self.studio_var, width=48, state="readonly")
        self.studio_box.grid(row=0, column=1, columnspan=2, sticky="we")
        ttk.Button(f, text="새로고침", command=self.refresh).grid(row=0, column=3)

        ttk.Label(f, text="영상 폴더").grid(row=1, column=0, sticky="w")
        self.folder_var = tk.StringVar()
        ttk.Entry(f, textvariable=self.folder_var, width=50).grid(row=1, column=1, columnspan=2, sticky="we")
        ttk.Button(f, text="찾기", command=self.pick_folder).grid(row=1, column=3)

        ttk.Label(f, text="제목 접두어").grid(row=2, column=0, sticky="w")
        self.prefix_var = tk.StringVar(value="Arrest")
        ttk.Entry(f, textvariable=self.prefix_var, width=20).grid(row=2, column=1, sticky="w")
        rng = ttk.Frame(f)
        rng.grid(row=2, column=2, columnspan=2, sticky="e")
        ttk.Label(rng, text="번호").pack(side="left")
        self.first_var = tk.StringVar()
        self.last_var = tk.StringVar()
        ttk.Entry(rng, textvariable=self.first_var, width=5).pack(side="left")
        ttk.Label(rng, text="~").pack(side="left")
        ttk.Entry(rng, textvariable=self.last_var, width=5).pack(side="left")
        ttk.Label(rng, text="(비우면 전부)").pack(side="left")

        bar = ttk.Frame(f)
        bar.grid(row=3, column=0, columnspan=4, pady=6, sticky="we")
        ttk.Button(bar, text="① 위치 기록 (F8)", command=self.start_calib).pack(side="left")
        self.start_btn = ttk.Button(bar, text="② 시작", command=self.start)
        self.start_btn.pack(side="left", padx=6)
        self.stop_btn = ttk.Button(bar, text="멈춤 (F9)", command=self.stop, state="disabled")
        self.stop_btn.pack(side="left")
        ttk.Button(bar, text="목록 보기", command=self.preview).pack(side="left", padx=6)

        self.text = tk.Text(f, width=72, height=18)
        self.text.grid(row=4, column=0, columnspan=4, sticky="nsew")
        self.refresh()
        self.log("처음이면 ① 위치 기록부터 하세요. 기록된 위치: " + (", ".join(self.points) or "없음"))
        threading.Thread(target=self.hotkeys, daemon=True).start()

    # -- helpers
    def log(self, s):
        self.root.after(0, lambda: (self.text.insert("end", s + "\n"), self.text.see("end")))

    def set_clipboard(self, s):
        done = threading.Event()

        def put():
            self.root.clipboard_clear()
            self.root.clipboard_append(s)
            self.root.update()
            done.set()

        self.root.after(0, put)
        done.wait(2)

    def refresh(self):
        self.studios = [(h, t) for h, t in windows() if "Roblox Studio" in t]
        self.studio_box["values"] = [t for _, t in self.studios]
        if self.studios and self.studio_var.get() not in self.studio_box["values"]:
            self.studio_box.current(0)

    def studio_hwnd(self):
        for h, t in self.studios:
            if t == self.studio_var.get() and user32.IsWindow(h):
                return h
        self.refresh()
        return self.studios[0][0] if self.studios else None

    def pick_folder(self):
        d = filedialog.askdirectory()
        if d:
            self.folder_var.set(os.path.normpath(d))

    def num(self, v):
        v = v.get().strip()
        return int(v) if v.isdigit() else None

    def files(self):
        folder = self.folder_var.get().strip()
        if not os.path.isdir(folder):
            self.log("영상 폴더를 골라 주세요.")
            return None
        return video_files(folder, self.num(self.first_var), self.num(self.last_var))

    def preview(self):
        fs = self.files()
        if fs is not None:
            self.log(f"{len(fs)}개: " + ", ".join(f"{n}" for _, n in fs))

    # -- F8 / F9 (global: Studio keeps the focus while recording)
    def hotkeys(self):
        user32.RegisterHotKey(None, 1, 0, 0x77)  # F8
        user32.RegisterHotKey(None, 2, 0, 0x78)  # F9
        msg = wt.MSG()
        while user32.GetMessageW(ctypes.byref(msg), None, 0, 0) != 0:
            if msg.message == 0x0312:  # WM_HOTKEY
                if msg.wParam == 1:
                    self.root.after(0, self.calib_record)
                elif msg.wParam == 2:
                    self.root.after(0, self.stop)

    def start_calib(self):
        self.refresh()
        # only the missing points when some are kept; all of them otherwise
        missing = [i for i, s in enumerate(STEPS) if s[0] not in self.points]
        self.calib_list = missing if 0 < len(missing) < len(STEPS) else list(range(len(STEPS)))
        self.calib_pos = 0
        self.calib_index = self.calib_list[0]
        self.log("— 위치 기록 —")
        self.log(f"1/{len(self.calib_list)}: " + STEPS[self.calib_index][2])

    def calib_record(self):
        if self.calib_index is None:
            return
        name, base, _ = STEPS[self.calib_index]
        hwnd = self.studio_hwnd() if base == "studio" else find_window(ASSET_TITLE)
        if not hwnd:
            self.log("  " + ("Studio 창" if base == "studio" else "게시(Asset Configuration) 창") + "을 찾지 못했어요. 열고 다시 F8.")
            return
        x, y = cursor()
        l, t, _, _ = rect(hwnd)
        self.points[name] = [x - l, y - t]
        self.log(f"  기록: {name} = ({x - l}, {y - t})")
        self.calib_pos += 1
        if self.calib_pos >= len(self.calib_list):
            self.calib_index = None
            with open(POINTS_FILE, "w", encoding="utf-8") as f:
                json.dump(self.points, f, ensure_ascii=False, indent=1)
            self.log("위치 기록 끝 (저장됨). 이제 ② 시작.")
        else:
            self.calib_index = self.calib_list[self.calib_pos]
            self.log(f"{self.calib_pos + 1}/{len(self.calib_list)}: " + STEPS[self.calib_index][2])

    # -- run
    def start(self):
        missing = [n for n, _, _ in STEPS if n not in self.points]
        if missing:
            self.log("먼저 ① 위치 기록을 해 주세요 (없음: " + ", ".join(missing) + ")")
            return
        fs = self.files()
        if not fs:
            self.log("처리할 영상이 없어요 (이름이 1.mp4, 2.mp4… 인 영상만).")
            return
        self.log(f"시작: {len(fs)}개. 도중에 마우스·키보드를 건드리지 마세요. 멈춤은 F9.")
        self.start_btn["state"] = "disabled"
        self.stop_btn["state"] = "normal"
        self.runner = Runner(self)
        threading.Thread(target=self.runner.run, args=(fs, self.prefix_var.get().strip()), daemon=True).start()

    def stop(self):
        if self.runner:
            self.runner.stop = True

    def running_done(self):
        def ui():
            self.start_btn["state"] = "normal"
            self.stop_btn["state"] = "disabled"
            self.runner = None
        self.root.after(0, ui)


if __name__ == "__main__":
    App().root.mainloop()
