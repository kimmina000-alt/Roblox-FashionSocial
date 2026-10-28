// STL helper for food models (user 2026-10-29): read a binary STL, weld its
// vertices, split it into connected shells, report them, and write a light
// OBJ (vertex-clustering decimation) with one object per group of shells so
// each group can be coloured as its own MeshPart in Roblox.
// Used from PowerShell: Add-Type -Path tools/art/StlTool.cs
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;

public static class StlTool
{
    public class Mesh
    {
        public List<double[]> V = new List<double[]>();
        public List<int[]> T = new List<int[]>();
        public double[] Min = { double.MaxValue, double.MaxValue, double.MaxValue };
        public double[] Max = { double.MinValue, double.MinValue, double.MinValue };
    }

    public static Mesh Load(string path)
    {
        var b = File.ReadAllBytes(path);
        int n = BitConverter.ToInt32(b, 80);
        var m = new Mesh();
        var map = new Dictionary<string, int>();
        for (int i = 0; i < n; i++)
        {
            int o = 84 + i * 50 + 12;
            var tri = new int[3];
            for (int k = 0; k < 3; k++)
            {
                double x = BitConverter.ToSingle(b, o + k * 12), y = BitConverter.ToSingle(b, o + k * 12 + 4), z = BitConverter.ToSingle(b, o + k * 12 + 8);
                string key = Math.Round(x, 4) + "," + Math.Round(y, 4) + "," + Math.Round(z, 4);
                int id;
                if (!map.TryGetValue(key, out id))
                {
                    id = m.V.Count; map[key] = id; m.V.Add(new[] { x, y, z });
                    for (int a = 0; a < 3; a++) { double v = a == 0 ? x : a == 1 ? y : z; m.Min[a] = Math.Min(m.Min[a], v); m.Max[a] = Math.Max(m.Max[a], v); }
                }
                tri[k] = id;
            }
            if (tri[0] != tri[1] && tri[1] != tri[2] && tri[0] != tri[2]) m.T.Add(tri);
        }
        return m;
    }

    static int Find(int[] p, int x) { while (p[x] != x) { p[x] = p[p[x]]; x = p[x]; } return x; }

    // shell id for every triangle (shells = triangles sharing vertices)
    public static int[] Shells(Mesh m, out int count)
    {
        var p = Enumerable.Range(0, m.V.Count).ToArray();
        foreach (var t in m.T) { int a = Find(p, t[0]); int b = Find(p, t[1]); int c = Find(p, t[2]); p[b] = a; p[Find(p, c)] = a; }
        var ids = new Dictionary<int, int>();
        var res = new int[m.T.Count];
        for (int i = 0; i < m.T.Count; i++) { int r = Find(p, m.T[i][0]); int id; if (!ids.TryGetValue(r, out id)) { id = ids.Count; ids[r] = id; } res[i] = id; }
        count = ids.Count;
        return res;
    }

    public static string Analyze(string path)
    {
        var m = Load(path);
        int count; var sh = Shells(m, out count);
        var sb = new StringBuilder();
        sb.AppendFormat(CultureInfo.InvariantCulture, "verts {0} tris {1} shells {2} bbox {3:F2},{4:F2},{5:F2} .. {6:F2},{7:F2},{8:F2}\n", m.V.Count, m.T.Count, count, m.Min[0], m.Min[1], m.Min[2], m.Max[0], m.Max[1], m.Max[2]);
        var info = new List<Tuple<int, int, double[], double[]>>();
        for (int s = 0; s < count; s++) info.Add(Tuple.Create(s, 0, new[] { double.MaxValue, double.MaxValue, double.MaxValue }, new[] { double.MinValue, double.MinValue, double.MinValue }));
        var cnt = new int[count];
        for (int i = 0; i < m.T.Count; i++)
        {
            int s = sh[i]; cnt[s]++;
            foreach (int vi in m.T[i]) for (int a = 0; a < 3; a++) { info[s].Item3[a] = Math.Min(info[s].Item3[a], m.V[vi][a]); info[s].Item4[a] = Math.Max(info[s].Item4[a], m.V[vi][a]); }
        }
        foreach (var s in Enumerable.Range(0, count).OrderByDescending(i => cnt[i]).Take(60))
        {
            var lo = info[s].Item3; var hi = info[s].Item4;
            sb.AppendFormat(CultureInfo.InvariantCulture, "#{0} tris {1} min {2:F2},{3:F2},{4:F2} max {5:F2},{6:F2},{7:F2}\n", s, cnt[s], lo[0], lo[1], lo[2], hi[0], hi[1], hi[2]);
        }
        return sb.ToString();
    }

    // height profile: per z slice, how many triangle centres and how far out they reach
    public static string Profile(string path, int bins)
    {
        var m = Load(path);
        var sb = new StringBuilder();
        double h = (m.Max[2] - m.Min[2]) / bins;
        var cnt = new int[bins]; var rmax = new double[bins]; var lo = new double[bins, 2]; var hi = new double[bins, 2];
        for (int b = 0; b < bins; b++) { lo[b, 0] = lo[b, 1] = double.MaxValue; hi[b, 0] = hi[b, 1] = double.MinValue; }
        foreach (var t in m.T)
        {
            double x = 0, y = 0, z = 0; foreach (int vi in t) { x += m.V[vi][0] / 3; y += m.V[vi][1] / 3; z += m.V[vi][2] / 3; }
            int b = Math.Min(bins - 1, (int)((z - m.Min[2]) / h));
            cnt[b]++; rmax[b] = Math.Max(rmax[b], Math.Sqrt(x * x + y * y));
            lo[b, 0] = Math.Min(lo[b, 0], x); hi[b, 0] = Math.Max(hi[b, 0], x); lo[b, 1] = Math.Min(lo[b, 1], y); hi[b, 1] = Math.Max(hi[b, 1], y);
        }
        for (int b = 0; b < bins; b++)
            sb.AppendFormat(CultureInfo.InvariantCulture, "z {0,5:F1}-{1,5:F1}: {2,6} tris  r<={3,6:F2}  x {4:F1}..{5:F1} y {6:F1}..{7:F1}\n", m.Min[2] + b * h, m.Min[2] + (b + 1) * h, cnt[b], rmax[b], lo[b, 0], hi[b, 0], lo[b, 1], hi[b, 1]);
        return sb.ToString();
    }

    // Split the triangles into named groups by their centre (groupOf returns ""
    // to drop one), decimate each group by clustering vertices on a grid of
    // `cell` (model units), and write a JSON {name: {v: [x,y,z,...], f: [a,b,c,...]}}
    // in studs (scale), Y up (a Z-up model turns (x, y, z) -> (x, z, -y)),
    // centred on x/z with the bottom at y 0. Returns triangle counts.
    public static string Export(string path, string jsonPath, double cell, Func<double[], string> groupOf, double scale, bool zUp, Func<string, double> cellScale = null)
    {
        var m = Load(path);
        var byGroup = new SortedDictionary<string, List<int>>();
        for (int i = 0; i < m.T.Count; i++)
        {
            var c = new double[3];
            foreach (int vi in m.T[i]) for (int a = 0; a < 3; a++) c[a] += m.V[vi][a] / 3;
            string g = groupOf(c) ?? "";
            if (g == "") continue;
            List<int> l; if (!byGroup.TryGetValue(g, out l)) { l = new List<int>(); byGroup[g] = l; } l.Add(i);
        }
        double cx = (m.Min[0] + m.Max[0]) / 2, cy = (m.Min[1] + m.Max[1]) / 2;
        var sb = new StringBuilder("{"); var rep = new StringBuilder();
        bool firstG = true;
        foreach (var kv in byGroup)
        {
            var cellOf = new Dictionary<long, int>(); var sum = new List<double[]>(); var vmap = new Dictionary<int, int>();
            double gc = cell * (cellScale != null ? cellScale(kv.Key) : 1); // (flat parts can take a coarser grid)
            foreach (int ti in kv.Value) foreach (int vi in m.T[ti])
            {
                if (vmap.ContainsKey(vi)) continue;
                var v = m.V[vi];
                long key = ((long)Math.Floor(v[0] / gc) & 0x1FFFFF) << 42 | ((long)Math.Floor(v[1] / gc) & 0x1FFFFF) << 21 | ((long)Math.Floor(v[2] / gc) & 0x1FFFFF);
                int c; if (!cellOf.TryGetValue(key, out c)) { c = sum.Count; cellOf[key] = c; sum.Add(new double[4]); }
                sum[c][0] += v[0]; sum[c][1] += v[1]; sum[c][2] += v[2]; sum[c][3] += 1; vmap[vi] = c;
            }
            var seen = new HashSet<string>(); var outT = new List<int[]>();
            foreach (int ti in kv.Value)
            {
                int a = vmap[m.T[ti][0]], b = vmap[m.T[ti][1]], c = vmap[m.T[ti][2]];
                if (a == b || b == c || a == c) continue;
                var srt = new[] { a, b, c }; Array.Sort(srt);
                if (!seen.Add(srt[0] + "_" + srt[1] + "_" + srt[2])) continue;
                outT.Add(new[] { a, b, c });
            }
            sb.Append(firstG ? "" : ",").Append('"').Append(kv.Key).Append("\":{\"v\":[");
            firstG = false;
            for (int i = 0; i < sum.Count; i++)
            {
                var s = sum[i];
                double x = (s[0] / s[3] - cx) * scale, y = (s[1] / s[3] - cy) * scale, z = (s[2] / s[3] - m.Min[2]) * scale;
                if (zUp) { double t = y; y = z; z = -t; }
                sb.AppendFormat(CultureInfo.InvariantCulture, "{0}{1:F4},{2:F4},{3:F4}", i == 0 ? "" : ",", x, y, z);
            }
            sb.Append("],\"f\":[");
            for (int i = 0; i < outT.Count; i++) sb.AppendFormat("{0}{1},{2},{3}", i == 0 ? "" : ",", outT[i][0], outT[i][1], outT[i][2]);
            sb.Append("]}");
            rep.AppendFormat("{0}: {1} tris (from {2}), {3} verts\n", kv.Key, outT.Count, kv.Value.Count, sum.Count);
        }
        sb.Append("}");
        File.WriteAllText(jsonPath, sb.ToString());
        return rep.ToString();
    }

    // the colour groups of the two cafe foods (user STL files 2026-10-29, Z up,
    // model units): split by height and distance from the middle
    public static string HoneyBreadGroup(double[] c)
    {
        double r = Math.Sqrt(c[0] * c[0] + c[1] * c[1]);
        if (c[2] < 10.3) return "Plate";
        if (c[2] > 25.8 && r <= 19.5) return "Cream";
        return "Bread";
    }
    public static string ParfaitGroup(double[] c)
    {
        double r = Math.Sqrt(c[0] * c[0] + c[1] * c[1]), z = c[2];
        if (z < 12) return "Stem";        // foot and stem: clear glass
        if (z < 21) return "Sauce";       // strawberry layer seen through the glass
        if (z < 30.5) return "Layer";     // cream layer seen through the glass
        if (z > 38 && c[1] > 1) return "Wafer"; // the wafer and the biscuit stick at the back
        if (r > 5.2 && z < 40) return "Berry";  // strawberries round the rim
        return "Cream";
    }
    public static string ExportNamed(string path, string jsonPath, double cell, string which, double scale)
    {
        Func<double[], string> g = which == "parfait" ? (Func<double[], string>)ParfaitGroup : HoneyBreadGroup;
        return Export(path, jsonPath, cell, g, scale, true, n => n == "Plate" ? 1.6 : n == "Stem" ? 1.6 : 1.0);
    }}
