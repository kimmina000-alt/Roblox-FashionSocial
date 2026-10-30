// Helpers for the cake models (user STL files 2026-10-30): check the winding
// (signed volume: a closed shell with its faces turned inside out has a
// negative one), and draw shaded top / side views, optionally coloured by
// group, to pick the groups and check them against the photo.
// Used from PowerShell: Add-Type -Path tools/art/StlTool.cs, tools/art/CakeTool.cs
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.Linq;

public static class CakeTool
{
    // signed volume (model units^3) and how many triangles face away from the
    // middle on the sides (a rough second check)
    public static string Winding(string path)
    {
        var m = StlTool.Load(path);
        double vol = 0; int outSide = 0, inSide = 0;
        double cx = (m.Min[0] + m.Max[0]) / 2, cy = (m.Min[1] + m.Max[1]) / 2;
        foreach (var t in m.T)
        {
            var a = m.V[t[0]]; var b = m.V[t[1]]; var c = m.V[t[2]];
            vol += (a[0] * (b[1] * c[2] - b[2] * c[1]) - a[1] * (b[0] * c[2] - b[2] * c[0]) + a[2] * (b[0] * c[1] - b[1] * c[0])) / 6;
            double nx = (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]);
            double ny = (b[2] - a[2]) * (c[0] - a[0]) - (b[0] - a[0]) * (c[2] - a[2]);
            double mx = (a[0] + b[0] + c[0]) / 3 - cx, my = (a[1] + b[1] + c[1]) / 3 - cy;
            double r = Math.Sqrt(mx * mx + my * my);
            if (r > (m.Max[0] - m.Min[0]) * 0.45) { if (nx * mx + ny * my > 0) outSide++; else inSide++; }
        }
        return string.Format(CultureInfo.InvariantCulture, "signed volume {0:F0} ({1}), outer side faces out {2} / in {3}", vol, vol > 0 ? "faces point out: OK" : "INSIDE OUT", outSide, inSide);
    }

    // Ball finder (Hough): every triangle in the band votes for the point R
    // inside its face (p - R n) for each R from r0 to r1; vote cells of `cell`;
    // returns the strongest centres (one per neighbourhood) as
    // "x,y,z,R,votes" lines (model units).
    public static string Balls(string path, double z0, double z1, double r0, double r1, double rStep, double cell, int maxOut, int minVotes)
    {
        var m = StlTool.Load(path);
        var votes = new Dictionary<long, double[]>(); // key -> sum x,y,z,R,count
        foreach (var t in m.T)
        {
            var a = m.V[t[0]]; var b = m.V[t[1]]; var c = m.V[t[2]];
            double px = (a[0] + b[0] + c[0]) / 3, py = (a[1] + b[1] + c[1]) / 3, pz = (a[2] + b[2] + c[2]) / 3;
            if (pz < z0 || pz >= z1) continue;
            double nx = (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]);
            double ny = (b[2] - a[2]) * (c[0] - a[0]) - (b[0] - a[0]) * (c[2] - a[2]);
            double nz = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
            double l = Math.Sqrt(nx * nx + ny * ny + nz * nz); if (l < 1e-12) continue;
            nx /= l; ny /= l; nz /= l;
            for (double R = r0; R <= r1 + 1e-9; R += rStep)
            {
                double x = px - R * nx, y = py - R * ny, z = pz - R * nz;
                long key = ((long)Math.Floor(x / cell) & 0xFFFF) << 32 | ((long)Math.Floor(y / cell) & 0xFFFF) << 16 | ((long)Math.Floor(z / cell) & 0xFFFF);
                key = key * 64 + (long)Math.Round((R - r0) / rStep);
                double[] e; if (!votes.TryGetValue(key, out e)) { e = new double[5]; votes[key] = e; }
                e[0] += x; e[1] += y; e[2] += z; e[3] += R; e[4] += 1;
            }
        }
        var list = votes.Values.Where(e => e[4] >= minVotes).OrderByDescending(e => e[4]).ToList();
        var outL = new List<double[]>();
        foreach (var e in list)
        {
            double x = e[0] / e[4], y = e[1] / e[4], z = e[2] / e[4], R = e[3] / e[4];
            bool near = outL.Any(o => Math.Sqrt((o[0] - x) * (o[0] - x) + (o[1] - y) * (o[1] - y) + (o[2] - z) * (o[2] - z)) < Math.Max(o[3], R) * 1.2);
            if (near) continue;
            outL.Add(new[] { x, y, z, R, e[4] });
            if (outL.Count >= maxOut) break;
        }
        var sb = new System.Text.StringBuilder();
        foreach (var o in outL) sb.AppendFormat(CultureInfo.InvariantCulture, "{0:F2},{1:F2},{2:F2},{3:F2},{4}\n", o[0], o[1], o[2], o[3], o[4]);
        return sb.ToString();
    }

    // ---- the vintage lettering cake (user STL 2026-10-30, Z up, model units;
    // photo docs/04_ART/references/cakes/cake_vintage_lettering.png) ----
    // balls found with Balls(): the six cherries on the rosettes, the two
    // flower-centre pearls, the dome dots on the top, the cherry pairs on the side
    static readonly double[][] VCherries = {
        new[] { -10.59, -29.20, 43.53, 4.5 }, new[] { 33.81, -1.55, 38.72, 4.75 }, new[] { -29.70, -2.03, 41.14, 4.25 },
        new[] { 23.63, -22.51, 40.96, 3.75 }, new[] { -13.01, 26.75, 40.50, 4.5 }, new[] { 14.81, 26.66, 39.24, 4.5 } };
    static readonly double[][] VPearls = { new[] { -13.41, -7.02, 34.00, 2.6 }, new[] { 16.64, -8.53, 34.07, 2.8 } };
    static readonly double[][] VDots = {
        new[] { -4.64, -15.42, 31.10, 1.4 }, new[] { 13.06, -16.97, 31.10, 1.4 }, new[] { -7.87, 12.99, 31.30, 1.4 }, new[] { 4.01, 10.25, 31.36, 1.4 },
        new[] { 14.30, 2.17, 31.11, 1.2 }, new[] { 5.00, 16.96, 31.08, 1.2 }, new[] { -1.32, -17.31, 31.12, 1.2 }, new[] { -16.58, -0.07, 31.34, 1.6 },
        new[] { -13.55, 5.30, 31.04, 2.0 }, new[] { 8.77, 15.38, 31.08, 1.0 }, new[] { 17.27, -3.77, 31.28, 1.8 } };
    static readonly double[][] VSideBalls = { new[] { -13.21, -35.15, 23.76, 2.25 }, new[] { 11.76, -35.67, 24.75, 2.75 }, new[] { 6.24, -36.26, 24.79, 2.75 } };
    public static double VTreble = 41.3; // bottom band: further out than this = the blue scroll piping

    static double D3(double[] c, double[] b) { return Math.Sqrt((c[0] - b[0]) * (c[0] - b[0]) + (c[1] - b[1]) * (c[1] - b[1]) + (c[2] - b[2]) * (c[2] - b[2])); }
    static double D2(double[] c, double[] b) { return Math.Sqrt((c[0] - b[0]) * (c[0] - b[0]) + (c[1] - b[1]) * (c[1] - b[1])); }

    // c = centre x, y, z, then the face normal nx, ny, nz
    public static string VintageGroup(double[] c)
    {
        double x = c[0], y = c[1], z = c[2], nz = c.Length > 5 ? c[5] : 0;
        double r = Math.Sqrt(x * x + y * y);
        // (the sticker stands a little over the board's top, 0.75..1.0)
        if (z < 2.2 && x > 20 && y < -24 && r > 39 && z > 1.02) return "Label";
        if (z < 1.05) return "Board";
        foreach (var b in VCherries) if (D3(c, b) < b[3] + 0.5) return "Cherry";
        foreach (var b in VCherries) { double d = D3(c, b); if (d < 13 && z > b[2] + b[3] * 0.55 && D2(c, b) < 9) return "Stem"; }
        foreach (var b in VPearls) if (D3(c, b) < b[3] + 0.35) return "Pearl";
        foreach (var b in VDots) if (D3(c, b) < b[3] + 0.3) return "Pearl";
        foreach (var b in VSideBalls) if (D3(c, b) < b[3] + 3.2 && r > 36.6) return "Cherry"; // (not the cake wall behind)
        if (z >= 31.45 && r < 22.5)
        {
            for (int i = 0; i < VPearls.Length; i++) if (D2(c, VPearls[i]) < 5.6) return i == 0 ? "FlowerPink" : "FlowerPurple";
            bool letters = x > -12.5 && x < 12.5 && y > -15.5 && y < 10.5 && z > 31.9;
            if (letters)
            {
                string line = y > 1.5 ? "Happy" : y > -7.5 ? "Name" : "Day";
                return nz > 0.6 ? "Letter" + line : "LetterEdge";
            }
            // (the rosettes' inner feet reach in to about r 19.5: cream)
            if (r > 19.5) return "Cream";
            // sprinkles: little bits standing on the top, one colour per patch
            int h = (int)(Math.Floor(x / 2.5) * 7 + Math.Floor(y / 2.5) * 13);
            return "Sprinkle" + (((h % 5) + 5) % 5);
        }
        if (z < 31.45 && r < 33) return "Top";
        if (z >= 31.45) return "Cream";
        if (z < 11.5) return r > VTreble ? "Piping" : (r < 36.9 ? "Side" : "BottomCream");
        if (r < 36.9) return "Side";
        return "SideCream";
    }

    // Views() with the normal passed to the group function too
    public static void VintageViews(string path, string outPng, int size)
    {
        Views(path, outPng, size, null, null, true);
    }

    public static readonly string VintageColors =
        "Board=246,244,240;Label=236,120,160;Cherry=214,30,40;Stem=150,20,30;Pearl=252,250,244;Top=120,205,215;Side=120,205,215;" +
        "Cream=255,246,215;SideCream=255,248,228;BottomCream=255,248,228;Piping=90,190,215;FlowerPink=245,140,150;FlowerPurple=160,150,220;" +
        "LetterHappy=255,252,250;LetterName=250,200,60;LetterDay=255,252,250;LetterEdge=220,50,50;" +
        "Sprinkle0=240,80,120;Sprinkle1=250,200,60;Sprinkle2=90,190,120;Sprinkle3=250,140,60;Sprinkle4=110,160,240";

    // Reduce and write the cake as a glTF: one mesh + plain colour material per
    // group (VintageGroup, normals included), vertices clustered on a grid of
    // `cell` model units per group (cellScale for flat groups), smooth normals,
    // studs (scale), Y up, centred on x / z with the bottom at 0.
    public static string VintageGltf(string path, string gltfPath, double cell, double scale, string previewStl = null)
    {
        var prev = previewStl != null ? new List<double[][]>() : null;
        var m = StlTool.Load(path);
        var colors = new Dictionary<string, double[]>();
        foreach (var kv in VintageColors.Split(';')) { var p = kv.Split('='); var c = p[1].Split(','); colors[p[0]] = new[] { int.Parse(c[0]) / 255.0, int.Parse(c[1]) / 255.0, int.Parse(c[2]) / 255.0 }; }
        var byGroup = new SortedDictionary<string, List<int>>();
        for (int i = 0; i < m.T.Count; i++)
        {
            var P = m.T[i].Select(v => m.V[v]).ToArray();
            double nx = (P[1][1] - P[0][1]) * (P[2][2] - P[0][2]) - (P[1][2] - P[0][2]) * (P[2][1] - P[0][1]);
            double ny = (P[1][2] - P[0][2]) * (P[2][0] - P[0][0]) - (P[1][0] - P[0][0]) * (P[2][2] - P[0][2]);
            double nz = (P[1][0] - P[0][0]) * (P[2][1] - P[0][1]) - (P[1][1] - P[0][1]) * (P[2][0] - P[0][0]);
            double l = Math.Sqrt(nx * nx + ny * ny + nz * nz); if (l < 1e-12) continue;
            string g = VintageGroup(new[] { (P[0][0] + P[1][0] + P[2][0]) / 3, (P[0][1] + P[1][1] + P[2][1]) / 3, (P[0][2] + P[1][2] + P[2][2]) / 3, nx / l, ny / l, nz / l });
            List<int> list; if (!byGroup.TryGetValue(g, out list)) { list = new List<int>(); byGroup[g] = list; } list.Add(i);
        }
        double cx = (m.Min[0] + m.Max[0]) / 2, cy = (m.Min[1] + m.Max[1]) / 2;
        var ms = new System.IO.MemoryStream(); var bw = new System.IO.BinaryWriter(ms);
        var bufferViews = new List<object>(); var accessors = new List<object>(); var meshes = new List<object>(); var materials = new List<object>(); var nodes = new List<object>();
        var rep = new System.Text.StringBuilder(); int total = 0;
        foreach (var kv in byGroup)
        {
            string g = kv.Key;
            // flat / plain groups can take a coarser grid; small detailed ones a finer one
            double gc = cell * (g == "Board" ? 3.0 : g == "Top" || g == "Side" ? 1.6 : g.StartsWith("Letter") || g == "Stem" || g.StartsWith("Sprinkle") || g == "Pearl" ? 0.55 : 1.0);
            var cellOf = new Dictionary<long, int>(); var sum = new List<double[]>(); var vmap = new Dictionary<int, int>();
            foreach (int ti in kv.Value) foreach (int vi in m.T[ti])
            {
                if (vmap.ContainsKey(vi)) continue;
                var v = m.V[vi];
                long key = ((long)Math.Floor(v[0] / gc) & 0x1FFFFF) << 42 | ((long)Math.Floor(v[1] / gc) & 0x1FFFFF) << 21 | ((long)Math.Floor(v[2] / gc) & 0x1FFFFF);
                int c; if (!cellOf.TryGetValue(key, out c)) { c = sum.Count; cellOf[key] = c; sum.Add(new double[4]); }
                sum[c][0] += v[0]; sum[c][1] += v[1]; sum[c][2] += v[2]; sum[c][3] += 1; vmap[vi] = c;
            }
            var pos = sum.Select(s => new[] { (s[0] / s[3] - cx) * scale, (s[2] / s[3] - m.Min[2]) * scale, -(s[1] / s[3] - cy) * scale }).ToList(); // Y up
            var seen = new HashSet<string>(); var tris = new List<int[]>();
            foreach (int ti in kv.Value)
            {
                int a = vmap[m.T[ti][0]], b = vmap[m.T[ti][1]], c = vmap[m.T[ti][2]];
                if (a == b || b == c || a == c) continue;
                var s3 = new[] { a, b, c }; Array.Sort(s3);
                if (!seen.Add(s3[0] + "_" + s3[1] + "_" + s3[2])) continue;
                tris.Add(new[] { a, b, c }); // (the axis swap x, z, -y keeps the winding)
                if (prev != null) prev.Add(new[] { a, b, c }.Select(k => new[] { sum[k][0] / sum[k][3], sum[k][1] / sum[k][3], sum[k][2] / sum[k][3] }).ToArray());
            }
            if (tris.Count == 0) continue;
            var nrm = new double[pos.Count][]; for (int i = 0; i < pos.Count; i++) nrm[i] = new double[3];
            foreach (var t in tris)
            {
                var A = pos[t[0]]; var B = pos[t[1]]; var C = pos[t[2]];
                double ux = B[0] - A[0], uy = B[1] - A[1], uz = B[2] - A[2], wx = C[0] - A[0], wy = C[1] - A[1], wz = C[2] - A[2];
                double nx = uy * wz - uz * wy, ny = uz * wx - ux * wz, nz = ux * wy - uy * wx;
                foreach (int k in t) { nrm[k][0] += nx; nrm[k][1] += ny; nrm[k][2] += nz; }
            }
            long start = ms.Position; double[] mn = { 1e9, 1e9, 1e9 }, mx = { -1e9, -1e9, -1e9 };
            foreach (var p in pos) for (int a = 0; a < 3; a++) { bw.Write((float)p[a]); mn[a] = Math.Min(mn[a], p[a]); mx[a] = Math.Max(mx[a], p[a]); }
            bufferViews.Add(new Dictionary<string, object> { { "buffer", 0 }, { "byteOffset", (int)start }, { "byteLength", (int)(ms.Position - start) }, { "target", 34962 } });
            accessors.Add(new Dictionary<string, object> { { "bufferView", bufferViews.Count - 1 }, { "componentType", 5126 }, { "count", pos.Count }, { "type", "VEC3" }, { "min", mn }, { "max", mx } });
            int aPos = accessors.Count - 1;
            start = ms.Position;
            foreach (var n in nrm) { double l = Math.Sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]); if (l < 1e-12) l = 1; for (int a = 0; a < 3; a++) bw.Write((float)(n[a] / l)); }
            bufferViews.Add(new Dictionary<string, object> { { "buffer", 0 }, { "byteOffset", (int)start }, { "byteLength", (int)(ms.Position - start) }, { "target", 34962 } });
            accessors.Add(new Dictionary<string, object> { { "bufferView", bufferViews.Count - 1 }, { "componentType", 5126 }, { "count", pos.Count }, { "type", "VEC3" } });
            int aNrm = accessors.Count - 1;
            start = ms.Position; foreach (var t in tris) foreach (int k in t) bw.Write((uint)k);
            bufferViews.Add(new Dictionary<string, object> { { "buffer", 0 }, { "byteOffset", (int)start }, { "byteLength", (int)(ms.Position - start) }, { "target", 34963 } });
            accessors.Add(new Dictionary<string, object> { { "bufferView", bufferViews.Count - 1 }, { "componentType", 5125 }, { "count", tris.Count * 3 }, { "type", "SCALAR" } });
            int aIdx = accessors.Count - 1;
            double[] col = colors.ContainsKey(g) ? colors[g] : new[] { 0.8, 0.8, 0.8 };
            materials.Add(new Dictionary<string, object> { { "name", g }, { "pbrMetallicRoughness", new Dictionary<string, object> { { "baseColorFactor", new[] { col[0], col[1], col[2], 1.0 } }, { "metallicFactor", 0 }, { "roughnessFactor", g == "Cherry" || g == "Pearl" ? 0.3 : 0.7 } } } });
            meshes.Add(new Dictionary<string, object> { { "name", g }, { "primitives", new[] { new Dictionary<string, object> { { "attributes", new Dictionary<string, object> { { "POSITION", aPos }, { "NORMAL", aNrm } } }, { "indices", aIdx }, { "material", materials.Count - 1 } } } } });
            nodes.Add(new Dictionary<string, object> { { "name", g }, { "mesh", meshes.Count - 1 } });
            rep.AppendFormat("{0}: {1} tris (from {2})\n", g, tris.Count, kv.Value.Count); total += tris.Count;
        }
        bw.Flush(); var bytes = ms.ToArray();
        var gltf = new Dictionary<string, object> {
            { "asset", new Dictionary<string, object> { { "version", "2.0" }, { "generator", "OHU CakeTool" } } },
            { "scene", 0 }, { "scenes", new[] { new Dictionary<string, object> { { "nodes", Enumerable.Range(0, nodes.Count).ToArray() } } } },
            { "nodes", nodes }, { "meshes", meshes }, { "materials", materials }, { "accessors", accessors }, { "bufferViews", bufferViews },
            { "buffers", new[] { new Dictionary<string, object> { { "byteLength", bytes.Length }, { "uri", "data:application/octet-stream;base64," + Convert.ToBase64String(bytes) } } } } };
        var ser = new System.Web.Script.Serialization.JavaScriptSerializer { MaxJsonLength = int.MaxValue };
        System.IO.File.WriteAllText(gltfPath, ser.Serialize(gltf));
        rep.AppendFormat("total {0} tris\n", total);
        if (prev != null)
        {
            // the reduced model as a binary STL in the source's units (Z up), to draw with Views
            var fs = new System.IO.BinaryWriter(System.IO.File.Create(previewStl));
            fs.Write(new byte[80]); fs.Write((uint)prev.Count);
            foreach (var t in prev) { fs.Write(0f); fs.Write(0f); fs.Write(0f); foreach (var v in t) { fs.Write((float)v[0]); fs.Write((float)v[1]); fs.Write((float)v[2]); } fs.Write((ushort)0); }
            fs.Close();
        }
        return rep.ToString();
    }

    // The same cake reduced with Qem (no flipped faces, no cracks between the
    // colours) to about `target` triangles, written like VintageGltf.
    public static string VintageQem(string path, string gltfPath, int target, double borderWeight, double scale, string previewStl)
    {
        var m = StlTool.Load(path);
        var names = new List<string>(); var gid = new Dictionary<string, int>(); var G = new List<int>();
        var T = new List<int[]>();
        foreach (var t in m.T)
        {
            var P = t.Select(v => m.V[v]).ToArray();
            double nx = (P[1][1] - P[0][1]) * (P[2][2] - P[0][2]) - (P[1][2] - P[0][2]) * (P[2][1] - P[0][1]);
            double ny = (P[1][2] - P[0][2]) * (P[2][0] - P[0][0]) - (P[1][0] - P[0][0]) * (P[2][2] - P[0][2]);
            double nz = (P[1][0] - P[0][0]) * (P[2][1] - P[0][1]) - (P[1][1] - P[0][1]) * (P[2][0] - P[0][0]);
            double l = Math.Sqrt(nx * nx + ny * ny + nz * nz); if (l < 1e-12) continue;
            string g = VintageGroup(new[] { (P[0][0] + P[1][0] + P[2][0]) / 3, (P[0][1] + P[1][1] + P[2][1]) / 3, (P[0][2] + P[1][2] + P[2][2]) / 3, nx / l, ny / l, nz / l });
            int id; if (!gid.TryGetValue(g, out id)) { id = names.Count; gid[g] = id; names.Add(g); }
            T.Add(t); G.Add(id);
        }
        List<double[]> oV; List<int[]> oT; List<int> oG;
        // detail weights: the letters, flowers, pearls and stems keep their shape longest
        var w = names.Select(n => n.StartsWith("Letter") || n.StartsWith("Flower") ? 40.0 : n == "Pearl" || n == "Stem" || n == "Cherry" ? 10.0 : n == "Board" || n == "Top" || n == "Side" ? 0.5 : 1.0).ToArray();
        Qem.Simplify(m.V, T, G, target, borderWeight, out oV, out oT, out oG, w);
        return WriteGltf(oV, oT, oG.Select(i => names[i]).ToList(), gltfPath, scale, (m.Min[0] + m.Max[0]) / 2, (m.Min[1] + m.Max[1]) / 2, m.Min[2], previewStl);
    }

    // glTF writer: one mesh per group (its own vertex copies, smooth normals
    // within the group), plain colour materials from VintageColors; studs, Y up
    static string WriteGltf(List<double[]> V, List<int[]> T, List<string> G, string gltfPath, double scale, double cx, double cy, double minZ, string previewStl)
    {
        var colors = new Dictionary<string, double[]>();
        foreach (var kv in VintageColors.Split(';')) { var p = kv.Split('='); var c = p[1].Split(','); colors[p[0]] = new[] { int.Parse(c[0]) / 255.0, int.Parse(c[1]) / 255.0, int.Parse(c[2]) / 255.0 }; }
        var ms = new System.IO.MemoryStream(); var bw = new System.IO.BinaryWriter(ms);
        var bufferViews = new List<object>(); var accessors = new List<object>(); var meshes = new List<object>(); var materials = new List<object>(); var nodes = new List<object>();
        var rep = new System.Text.StringBuilder(); int total = 0;
        foreach (var g in G.Distinct().OrderBy(s => s))
        {
            var map = new Dictionary<int, int>(); var pos = new List<double[]>(); var tris = new List<int[]>();
            for (int f = 0; f < T.Count; f++)
            {
                if (G[f] != g) continue;
                var t = new int[3];
                for (int k = 0; k < 3; k++)
                {
                    int o = T[f][k]; int n;
                    if (!map.TryGetValue(o, out n)) { n = pos.Count; map[o] = n; var v = V[o]; pos.Add(new[] { (v[0] - cx) * scale, (v[2] - minZ) * scale, -(v[1] - cy) * scale }); }
                    t[k] = n;
                }
                tris.Add(t);
            }
            var nrm = new double[pos.Count][]; for (int i = 0; i < pos.Count; i++) nrm[i] = new double[3];
            foreach (var t in tris)
            {
                var A = pos[t[0]]; var B = pos[t[1]]; var C = pos[t[2]];
                double ux = B[0] - A[0], uy = B[1] - A[1], uz = B[2] - A[2], wx = C[0] - A[0], wy = C[1] - A[1], wz = C[2] - A[2];
                double nx = uy * wz - uz * wy, ny = uz * wx - ux * wz, nz = ux * wy - uy * wx;
                foreach (int k in t) { nrm[k][0] += nx; nrm[k][1] += ny; nrm[k][2] += nz; }
            }
            long start = ms.Position; double[] mn = { 1e9, 1e9, 1e9 }, mx = { -1e9, -1e9, -1e9 };
            foreach (var p in pos) for (int a = 0; a < 3; a++) { bw.Write((float)p[a]); mn[a] = Math.Min(mn[a], p[a]); mx[a] = Math.Max(mx[a], p[a]); }
            bufferViews.Add(new Dictionary<string, object> { { "buffer", 0 }, { "byteOffset", (int)start }, { "byteLength", (int)(ms.Position - start) }, { "target", 34962 } });
            accessors.Add(new Dictionary<string, object> { { "bufferView", bufferViews.Count - 1 }, { "componentType", 5126 }, { "count", pos.Count }, { "type", "VEC3" }, { "min", mn }, { "max", mx } });
            int aPos = accessors.Count - 1;
            start = ms.Position;
            foreach (var n in nrm) { double l = Math.Sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]); if (l < 1e-12) l = 1; for (int a = 0; a < 3; a++) bw.Write((float)(n[a] / l)); }
            bufferViews.Add(new Dictionary<string, object> { { "buffer", 0 }, { "byteOffset", (int)start }, { "byteLength", (int)(ms.Position - start) }, { "target", 34962 } });
            accessors.Add(new Dictionary<string, object> { { "bufferView", bufferViews.Count - 1 }, { "componentType", 5126 }, { "count", pos.Count }, { "type", "VEC3" } });
            int aNrm = accessors.Count - 1;
            start = ms.Position; foreach (var t in tris) foreach (int k in t) bw.Write((uint)k);
            bufferViews.Add(new Dictionary<string, object> { { "buffer", 0 }, { "byteOffset", (int)start }, { "byteLength", (int)(ms.Position - start) }, { "target", 34963 } });
            accessors.Add(new Dictionary<string, object> { { "bufferView", bufferViews.Count - 1 }, { "componentType", 5125 }, { "count", tris.Count * 3 }, { "type", "SCALAR" } });
            int aIdx = accessors.Count - 1;
            double[] col = colors.ContainsKey(g) ? colors[g] : new[] { 0.8, 0.8, 0.8 };
            materials.Add(new Dictionary<string, object> { { "name", g }, { "pbrMetallicRoughness", new Dictionary<string, object> { { "baseColorFactor", new[] { col[0], col[1], col[2], 1.0 } }, { "metallicFactor", 0 }, { "roughnessFactor", g == "Cherry" || g == "Pearl" ? 0.3 : 0.7 } } } });
            meshes.Add(new Dictionary<string, object> { { "name", g }, { "primitives", new[] { new Dictionary<string, object> { { "attributes", new Dictionary<string, object> { { "POSITION", aPos }, { "NORMAL", aNrm } } }, { "indices", aIdx }, { "material", materials.Count - 1 } } } } });
            nodes.Add(new Dictionary<string, object> { { "name", g }, { "mesh", meshes.Count - 1 } });
            rep.AppendFormat("{0}: {1} tris\n", g, tris.Count); total += tris.Count;
        }
        bw.Flush(); var bytes = ms.ToArray();
        var gltf = new Dictionary<string, object> {
            { "asset", new Dictionary<string, object> { { "version", "2.0" }, { "generator", "OHU CakeTool" } } },
            { "scene", 0 }, { "scenes", new[] { new Dictionary<string, object> { { "nodes", Enumerable.Range(0, nodes.Count).ToArray() } } } },
            { "nodes", nodes }, { "meshes", meshes }, { "materials", materials }, { "accessors", accessors }, { "bufferViews", bufferViews },
            { "buffers", new[] { new Dictionary<string, object> { { "byteLength", bytes.Length }, { "uri", "data:application/octet-stream;base64," + Convert.ToBase64String(bytes) } } } } };
        var ser = new System.Web.Script.Serialization.JavaScriptSerializer { MaxJsonLength = int.MaxValue };
        System.IO.File.WriteAllText(gltfPath, ser.Serialize(gltf));
        if (previewStl != null)
        {
            var fs = new System.IO.BinaryWriter(System.IO.File.Create(previewStl));
            fs.Write(new byte[80]); fs.Write((uint)T.Count);
            foreach (var t in T) { fs.Write(0f); fs.Write(0f); fs.Write(0f); foreach (int k in t) { fs.Write((float)V[k][0]); fs.Write((float)V[k][1]); fs.Write((float)V[k][2]); } fs.Write((ushort)0); }
            fs.Close();
        }
        rep.AppendFormat("total {0} tris\n", total);
        return rep.ToString();
    }

    // triangles in a height band by distance from the middle (rstep bins),
    // with how many face up (n.z > 0.8) and out (horizontal, facing away)
    public static string RHist(string path, double z0, double z1, double rstep)
    {
        var m = StlTool.Load(path);
        double cx = (m.Min[0] + m.Max[0]) / 2, cy = (m.Min[1] + m.Max[1]) / 2;
        var cnt = new SortedDictionary<int, int[]>();
        foreach (var t in m.T)
        {
            var a = m.V[t[0]]; var b = m.V[t[1]]; var c = m.V[t[2]];
            double x = (a[0] + b[0] + c[0]) / 3 - cx, y = (a[1] + b[1] + c[1]) / 3 - cy, z = (a[2] + b[2] + c[2]) / 3;
            if (z < z0 || z >= z1) continue;
            double nx = (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]);
            double ny = (b[2] - a[2]) * (c[0] - a[0]) - (b[0] - a[0]) * (c[2] - a[2]);
            double nz = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
            double l = Math.Sqrt(nx * nx + ny * ny + nz * nz); if (l < 1e-12) continue;
            double r = Math.Sqrt(x * x + y * y);
            int k = (int)(r / rstep);
            int[] e; if (!cnt.TryGetValue(k, out e)) { e = new int[3]; cnt[k] = e; }
            e[0]++; if (nz / l > 0.8) e[1]++;
            if (r > 0 && (nx * x + ny * y) / (l * r) > 0.8) e[2]++;
        }
        var sb = new System.Text.StringBuilder();
        foreach (var kv in cnt) sb.AppendFormat(CultureInfo.InvariantCulture, "r {0,5:F1}: {1,6} up {2,6} out {3,6}\n", kv.Key * rstep, kv.Value[0], kv.Value[1], kv.Value[2]);
        return sb.ToString();
    }

    // Shaded views: top (looking down -z) and side (looking along +y), each
    // `size` px. groupOf colours a triangle by its centre (null = grey).
    public static void Views(string path, string outPng, int size, Func<double[], string> groupOf, string colorsCsv, bool vintage = false)
    {
        var m = StlTool.Load(path);
        if (vintage && string.IsNullOrEmpty(colorsCsv)) colorsCsv = VintageColors;
        var colors = new Dictionary<string, Color>();
        if (!string.IsNullOrEmpty(colorsCsv))
            foreach (var kv in colorsCsv.Split(';'))
            {
                var p = kv.Split('='); if (p.Length < 2) continue;
                var c = p[1].Split(',');
                colors[p[0]] = Color.FromArgb(int.Parse(c[0]), int.Parse(c[1]), int.Parse(c[2]));
            }
        var bmp = new Bitmap(size * 2, size);
        double span = Math.Max(m.Max[0] - m.Min[0], Math.Max(m.Max[1] - m.Min[1], m.Max[2] - m.Min[2])) * 1.05;
        double cx = (m.Min[0] + m.Max[0]) / 2, cy = (m.Min[1] + m.Max[1]) / 2, cz = (m.Min[2] + m.Max[2]) / 2;
        for (int view = 0; view < 2; view++)
        {
            var zb = new double[size, size];
            var col = new Color[size, size];
            for (int i = 0; i < size; i++) for (int j = 0; j < size; j++) { zb[i, j] = double.MinValue; col[i, j] = Color.FromArgb(235, 235, 240); }
            foreach (var t in m.T)
            {
                var P = t.Select(i => m.V[i]).ToArray();
                double[] cen = { (P[0][0] + P[1][0] + P[2][0]) / 3, (P[0][1] + P[1][1] + P[2][1]) / 3, (P[0][2] + P[1][2] + P[2][2]) / 3 };
                double nx = (P[1][1] - P[0][1]) * (P[2][2] - P[0][2]) - (P[1][2] - P[0][2]) * (P[2][1] - P[0][1]);
                double ny = (P[1][2] - P[0][2]) * (P[2][0] - P[0][0]) - (P[1][0] - P[0][0]) * (P[2][2] - P[0][2]);
                double nz = (P[1][0] - P[0][0]) * (P[2][1] - P[0][1]) - (P[1][1] - P[0][1]) * (P[2][0] - P[0][0]);
                double l = Math.Sqrt(nx * nx + ny * ny + nz * nz); if (l < 1e-12) continue;
                nx /= l; ny /= l; nz /= l;
                // screen coords: top = (x, -y) depth z; side = (x, -z) depth -y
                Func<double[], double[]> proj = v => view == 0
                    ? new[] { (v[0] - cx) / span * size + size / 2.0, -(v[1] - cy) / span * size + size / 2.0, v[2] }
                    : new[] { (v[0] - cx) / span * size + size / 2.0, -(v[2] - cz) / span * size + size / 2.0, -v[1] };
                var S = P.Select(proj).ToArray();
                double facing = view == 0 ? nz : -ny;
                double shade = Math.Max(0.25, 0.35 + 0.65 * Math.Max(0, 0.5 * facing + 0.5 * (view == 0 ? (nx * -0.4 + ny * 0.4 + nz * 0.8) : (nx * -0.4 - ny * 0.6 + nz * 0.6))));
                string g = vintage ? VintageGroup(new[] { cen[0], cen[1], cen[2], nx, ny, nz }) : groupOf != null ? groupOf(cen) : null;
                Color baseC = g != null && colors.ContainsKey(g) ? colors[g] : Color.FromArgb(200, 200, 205);
                if (g == "") continue;
                Color c2 = Color.FromArgb((int)(baseC.R * shade), (int)(baseC.G * shade), (int)(baseC.B * shade));
                int x0 = (int)Math.Max(0, Math.Floor(S.Min(s => s[0]))), x1 = (int)Math.Min(size - 1, Math.Ceiling(S.Max(s => s[0])));
                int y0 = (int)Math.Max(0, Math.Floor(S.Min(s => s[1]))), y1 = (int)Math.Min(size - 1, Math.Ceiling(S.Max(s => s[1])));
                double den = (S[1][1] - S[2][1]) * (S[0][0] - S[2][0]) + (S[2][0] - S[1][0]) * (S[0][1] - S[2][1]);
                if (Math.Abs(den) < 1e-12) continue;
                for (int py = y0; py <= y1; py++) for (int px = x0; px <= x1; px++)
                {
                    double w0 = ((S[1][1] - S[2][1]) * (px + 0.5 - S[2][0]) + (S[2][0] - S[1][0]) * (py + 0.5 - S[2][1])) / den;
                    double w1 = ((S[2][1] - S[0][1]) * (px + 0.5 - S[2][0]) + (S[0][0] - S[2][0]) * (py + 0.5 - S[2][1])) / den;
                    double w2 = 1 - w0 - w1;
                    if (w0 < 0 || w1 < 0 || w2 < 0) continue;
                    double d = w0 * S[0][2] + w1 * S[1][2] + w2 * S[2][2];
                    if (d > zb[px, py]) { zb[px, py] = d; col[px, py] = c2; }
                }
            }
            for (int i = 0; i < size; i++) for (int j = 0; j < size; j++) bmp.SetPixel(view * size + i, j, col[i, j]);
        }
        bmp.Save(outPng, ImageFormat.Png);
    }
}
