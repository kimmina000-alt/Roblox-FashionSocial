// Cut a model out of two game shots (user 2026-11-03, D-787: cake icons without
// a background): the same view over a black and over a light backdrop, plus the
// two backdrops alone. Where the backdrop shows through, the two shots differ by
// as much as the backdrops do; on the model they are the same:
//   1 - alpha = (onBlack - onLight) / (black - light), colour = (onBlack - (1 - alpha) black) / alpha
// The result is cropped to the model, padded and put in the middle of a square.
using System;
using System.Drawing;
using System.Drawing.Imaging;

public static class Matte
{
    public static string Cut(string onBlack, string onLight, string black, string light, string outPng, int size, double pad)
    {
        var b1 = new Bitmap(onBlack); var w1 = new Bitmap(onLight); var b0 = new Bitmap(black); var w0 = new Bitmap(light);
        int W = b1.Width, H = b1.Height;
        var a = new double[W, H]; var col = new Color[W, H];
        int x0 = W, y0 = H, x1 = 0, y1 = 0;
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                Color cb = b1.GetPixel(x, y), cw = w1.GetPixel(x, y), kb = b0.GetPixel(x, y), kw = w0.GetPixel(x, y);
                double den = (kw.R - kb.R) + (kw.G - kb.G) + (kw.B - kb.B);
                double num = (cw.R - cb.R) + (cw.G - cb.G) + (cw.B - cb.B);
                double t = den > 30 ? num / den : 1; // 1 - alpha
                double al = 1 - Math.Max(0, Math.Min(1, t));
                // (JPEG noise: nearly clear is clear, nearly solid is solid)
                if (al < 0.06) al = 0; else if (al > 0.94) al = 1; else al = (al - 0.06) / 0.88;
                a[x, y] = al;
                if (al > 0)
                {
                    double k = 1 - al;
                    Func<int, int, int> un = (c, bg) => (int)Math.Max(0, Math.Min(255, Math.Round((c - k * bg) / al)));
                    col[x, y] = Color.FromArgb(un(cb.R, kb.R), un(cb.G, kb.G), un(cb.B, kb.B));
                    if (al > 0.3) { x0 = Math.Min(x0, x); y0 = Math.Min(y0, y); x1 = Math.Max(x1, x); y1 = Math.Max(y1, y); }
                }
            }
        if (x1 < x0) return "nothing found";
        int cw0 = x1 - x0 + 1, ch0 = y1 - y0 + 1;
        int side = (int)(Math.Max(cw0, ch0) * (1 + 2 * pad));
        var crop = new Bitmap(side, side, PixelFormat.Format32bppArgb);
        int ox = x0 - (side - cw0) / 2, oy = y0 - (side - ch0) / 2;
        for (int y = 0; y < side; y++)
            for (int x = 0; x < side; x++)
            {
                int sx = ox + x, sy = oy + y;
                if (sx < 0 || sy < 0 || sx >= W || sy >= H || a[sx, sy] <= 0) { crop.SetPixel(x, y, Color.Transparent); continue; }
                var c = col[sx, sy];
                crop.SetPixel(x, y, Color.FromArgb((int)Math.Round(a[sx, sy] * 255), c.R, c.G, c.B));
            }
        var outB = new Bitmap(size, size, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(outB))
        {
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
            g.Clear(Color.Transparent);
            g.DrawImage(crop, 0, 0, size, size);
        }
        outB.Save(outPng, ImageFormat.Png);
        b1.Dispose(); w1.Dispose(); b0.Dispose(); w0.Dispose(); crop.Dispose(); outB.Dispose();
        return string.Format("model box {0}x{1} at {2},{3} -> {4}", cw0, ch0, x0, y0, outPng);
    }
}
