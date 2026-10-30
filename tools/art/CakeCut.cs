// Cut a whole cake into slices that can be taken away one by one
// (user 2026-10-30: the vintage lettering cake on a table loses a slice per
// "한 조각 먹기", so each slice needs its cut faces). Input: the reduced,
// grouped mesh (Qem, CakeTool.VintageGroup). Output: one glTF with a mesh
// per slice ("Slice1".."SliceN", round from the start angle), all coloured
// from one small palette texture (the importer drops plain material colours
// but keeps a texture), each slice closed at its two cut planes by a cut face
// showing the layers inside (sponge, cream, jam, the blue icing shell).
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Linq;

public static class CakeCut
{
    // ---- reduced mesh cache (V in model units Z up, T, group names) ----
    public static string ReduceAndCache(string stlPath, string cachePath, int target)
    {
        var m = StlTool.Load(stlPath);
        var names = new List<string>(); var gid = new Dictionary<string, int>(); var G = new List<int>(); var T = new List<int[]>();
        foreach (var t in m.T)
        {
            var P = t.Select(v => m.V[v]).ToArray();
            double nx = (P[1][1] - P[0][1]) * (P[2][2] - P[0][2]) - (P[1][2] - P[0][2]) * (P[2][1] - P[0][1]);
            double ny = (P[1][2] - P[0][2]) * (P[2][0] - P[0][0]) - (P[1][0] - P[0][0]) * (P[2][2] - P[0][2]);
            double nz = (P[1][0] - P[0][0]) * (P[2][1] - P[0][1]) - (P[1][1] - P[0][1]) * (P[2][0] - P[0][0]);
            double l = Math.Sqrt(nx * nx + ny * ny + nz * nz); if (l < 1e-12) continue;
            string g = CakeTool.VintageGroup(new[] { (P[0][0] + P[1][0] + P[2][0]) / 3, (P[0][1] + P[1][1] + P[2][1]) / 3, (P[0][2] + P[1][2] + P[2][2]) / 3, nx / l, ny / l, nz / l });
            int id; if (!gid.TryGetValue(g, out id)) { id = names.Count; gid[g] = id; names.Add(g); }
            T.Add(t); G.Add(id);
        }
        var w = names.Select(n => n.StartsWith("Letter") || n.StartsWith("Flower") ? 40.0 : n == "Pearl" || n == "Stem" || n == "Cherry" ? 10.0 : n == "Board" || n == "Top" || n == "Side" ? 0.5 : 1.0).ToArray();
        List<double[]> oV; List<int[]> oT; List<int> oG;
        Qem.Simplify(m.V, T, G, target, 100, out oV, out oT, out oG, w);
        using (var bw = new BinaryWriter(File.Create(cachePath)))
        {
            bw.Write(m.Min[0]); bw.Write(m.Max[0]); bw.Write(m.Min[1]); bw.Write(m.Max[1]); bw.Write(m.Min[2]); bw.Write(m.Max[2]);
            bw.Write(names.Count); foreach (var n in names) bw.Write(n);
            bw.Write(oV.Count); foreach (var v in oV) { bw.Write(v[0]); bw.Write(v[1]); bw.Write(v[2]); }
            bw.Write(oT.Count); for (int i = 0; i < oT.Count; i++) { bw.Write(oT[i][0]); bw.Write(oT[i][1]); bw.Write(oT[i][2]); bw.Write(oG[i]); }
        }
        return string.Format("cached {0} verts {1} tris", oV.Count, oT.Count);
    }

    class Cache { public double[] Box = new double[6]; public List<string> Names = new List<string>(); public List<double[]> V = new List<double[]>(); public List<int[]> T = new List<int[]>(); public List<int> G = new List<int>(); }
    static Cache Read(string path)
    {
        var c = new Cache();
        using (var br = new BinaryReader(File.OpenRead(path)))
        {
            for (int i = 0; i < 6; i++) c.Box[i] = br.ReadDouble();
            int nn = br.ReadInt32(); for (int i = 0; i < nn; i++) c.Names.Add(br.ReadString());
            int nv = br.ReadInt32(); for (int i = 0; i < nv; i++) c.V.Add(new[] { br.ReadDouble(), br.ReadDouble(), br.ReadDouble() });
            int nt = br.ReadInt32(); for (int i = 0; i < nt; i++) { c.T.Add(new[] { br.ReadInt32(), br.ReadInt32(), br.ReadInt32() }); c.G.Add(br.ReadInt32()); }
        }
        return c;
    }

    // ---- the inside of the cake, by height (model units) and distance out ----
    // board under it all; the blue icing shell 1.6 thick under the outer wall
    // and the top; inside, sponge with cream, jam and cream layers
    public static double Rwall = 35.6, Ztop = 31.2, Zboard = 1.0;
    static string Inside(double u, double z)
    {
        if (u > Rwall + 1.3 || z > Ztop + 0.2) return "CutCream"; // the piping and rosettes cut through
        if (u > Rwall - 1.6 || z > Ztop - 1.6) return "Top"; // the blue icing
        if (z < 8.5) return "Sponge";
        if (z < 10.0) return "CutCream";
        if (z < 17.5) return "Sponge";
        if (z < 18.4) return "Jam";
        if (z < 19.6) return "CutCream";
        return "Sponge";
    }

    // pick the start angle (degrees) whose cut planes cross the fewest rosette
    // triangles (high, out at the ring), so the cuts go between the rosettes
    public static string BestStart(string cachePath, int slices)
    {
        var c = Read(cachePath);
        double cx = (c.Box[0] + c.Box[1]) / 2, cy = (c.Box[2] + c.Box[3]) / 2;
        var hist = new double[360];
        foreach (var t in c.T)
        {
            double x = 0, y = 0, z = 0; foreach (int k in t) { x += c.V[k][0] / 3; y += c.V[k][1] / 3; z += c.V[k][2] / 3; }
            x -= cx; y -= cy;
            double r = Math.Sqrt(x * x + y * y);
            if (z < 34 || r < 20) continue;
            int a = ((int)Math.Floor(Math.Atan2(y, x) * 180 / Math.PI) + 360) % 360;
            hist[a] += 1;
        }
        double best = double.MaxValue; int bestA = 0;
        int step = 360 / slices;
        for (int a0 = 0; a0 < step; a0++)
        {
            double s = 0;
            for (int k = 0; k < slices; k++) for (int d = -4; d <= 4; d++) s += hist[((a0 + k * step + d) % 360 + 360) % 360];
            if (s < best) { best = s; bestA = a0; }
        }
        return bestA + " (" + best + ")";
    }

    static readonly string[] Extra = { "Sponge=246,220,160", "CutCream=255,250,240", "Jam=225,70,90" };

    // Cut and write. start: degrees; dz: the cut faces' row height (model units)
    public static string Cut(string cachePath, string gltfPath, int slices, double startDeg, double scale, double dz, string previewPng)
    {
        var c = Read(cachePath);
        double cx = (c.Box[0] + c.Box[1]) / 2, cy = (c.Box[2] + c.Box[3]) / 2, minZ = c.Box[4];
        // palette: every group a cell
        var colors = new Dictionary<string, Color>();
        foreach (var kv in CakeTool.VintageColors.Split(';').Concat(Extra))
        {
            var p = kv.Split('='); var q = p[1].Split(',');
            colors[p[0]] = Color.FromArgb(int.Parse(q[0]), int.Parse(q[1]), int.Parse(q[2]));
        }
        var palNames = colors.Keys.ToList();
        const int CELLS = 8, CPX = 16;
        var pal = new Bitmap(CELLS * CPX, CELLS * CPX);
        using (var g = Graphics.FromImage(pal))
        {
            g.Clear(Color.Magenta);
            for (int i = 0; i < palNames.Count; i++) g.FillRectangle(new SolidBrush(colors[palNames[i]]), (i % CELLS) * CPX, (i / CELLS) * CPX, CPX, CPX);
        }
        Func<string, double[]> uvOf = name =>
        {
            int i = palNames.IndexOf(name); if (i < 0) i = palNames.IndexOf("Cream");
            return new[] { ((i % CELLS) + 0.5) / CELLS, ((i / CELLS) + 0.5) / CELLS };
        };
        var rep = new System.Text.StringBuilder();
        // cut faces per boundary angle: rectangles in (u, z), coloured
        var caps = new List<List<Tuple<double, double, double, double, string>>>();
        for (int k = 0; k < slices; k++) caps.Add(CapRects(c, cx, cy, (startDeg + k * 360.0 / slices) * Math.PI / 180, dz));
        var meshes = new List<Tuple<string, List<double[]>, List<double[]>, List<double[]>, List<int>>>(); // name, pos, nrm, uv, idx
        // how far the cake reaches at its foot (the lowest cut-face rows)
        double baseR = 0;
        foreach (var cap in caps) foreach (var r in cap) if (r.Item3 <= Zboard + dz * 1.5) baseR = Math.Max(baseR, r.Item2);
        rep.AppendFormat("foot radius {0:F1}\n", baseR);
        // the board (and its sticker) stays whole under the slices: its own mesh
        {
            var pos = new List<double[]>(); var nrm = new List<double[]>(); var uvs = new List<double[]>(); var idx = new List<int>();
            for (int i = 0; i < c.T.Count; i++)
            {
                string gname = c.Names[c.G[i]];
                if (gname != "Board" && gname != "Label") continue;
                var P = c.T[i].Select(k => new[] { c.V[k][0] - cx, c.V[k][1] - cy, c.V[k][2] }).ToArray();
                var n = Cross(Sub(P[1], P[0]), Sub(P[2], P[0])); double l = Math.Sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]); if (l < 1e-12) continue;
                var uv = uvOf(gname);
                foreach (var p in P) { idx.Add(pos.Count); pos.Add(new[] { p[0] * scale, (p[2] - minZ) * scale, -p[1] * scale }); nrm.Add(new[] { n[0] / l, n[2] / l, -n[1] / l }); uvs.Add(uv); }
            }
            // the board's top under the cake (inside the one shell there was
            // none): a disc just under the foot, seen where slices are gone
            {
                var uvB = uvOf("Board"); int seg = 48; double rr = baseR + 0.6, zz = Zboard - 0.03;
                int c0 = pos.Count; pos.Add(new[] { 0.0, (zz - minZ) * scale, 0.0 }); nrm.Add(new[] { 0.0, 1.0, 0.0 }); uvs.Add(uvB);
                for (int k = 0; k < seg; k++) { double an = k * 2 * Math.PI / seg; pos.Add(new[] { Math.Cos(an) * rr * scale, (zz - minZ) * scale, -Math.Sin(an) * rr * scale }); nrm.Add(new[] { 0.0, 1.0, 0.0 }); uvs.Add(uvB); }
                // (Y up, ring at (cos, -sin): c0, a, b turns counter-clockwise seen from above)
                for (int k = 0; k < seg; k++) { int a = c0 + 1 + k, b = c0 + 1 + (k + 1) % seg; idx.Add(c0); idx.Add(a); idx.Add(b); }
            }
            meshes.Add(Tuple.Create("Board", pos, nrm, uvs, idx));
            rep.AppendFormat("Board: {0} tris\n", idx.Count / 3);
        }
        for (int s = 0; s < slices; s++)
        {
            double a0 = (startDeg + s * 360.0 / slices) * Math.PI / 180, a1 = (startDeg + (s + 1) * 360.0 / slices) * Math.PI / 180;
            double[] t0 = { -Math.Sin(a0), Math.Cos(a0) }, t1 = { -Math.Sin(a1), Math.Cos(a1) };
            // surface: the triangles clipped to the wedge (t0.p >= 0 and t1.p <= 0)
            var polys = new List<Tuple<List<double[]>, string>>();
            for (int i = 0; i < c.T.Count; i++)
            {
                if (c.Names[c.G[i]] == "Board" || c.Names[c.G[i]] == "Label") continue;
                var poly = c.T[i].Select(k => new[] { c.V[k][0] - cx, c.V[k][1] - cy, c.V[k][2] }).ToList();
                poly = Clip(poly, p => t0[0] * p[0] + t0[1] * p[1]);
                if (poly.Count < 3) continue;
                poly = Clip(poly, p => -(t1[0] * p[0] + t1[1] * p[1]));
                if (poly.Count < 3) continue;
                polys.Add(Tuple.Create(poly, c.Names[c.G[i]]));
            }
            // smooth normals over the surface (shared by position), per group uv
            var key = new Func<double[], string>(p => Math.Round(p[0], 3) + "," + Math.Round(p[1], 3) + "," + Math.Round(p[2], 3));
            var nsum = new Dictionary<string, double[]>();
            foreach (var pg in polys)
            {
                var P = pg.Item1; var n = Cross(Sub(P[1], P[0]), Sub(P[2], P[0]));
                for (int k = 2; k < P.Count; k++) { var nk = Cross(Sub(P[k - 1], P[0]), Sub(P[k], P[0])); n = new[] { n[0] + (k > 2 ? nk[0] : 0), n[1] + (k > 2 ? nk[1] : 0), n[2] + (k > 2 ? nk[2] : 0) }; }
                foreach (var p in P) { string kk = key(p); double[] e; if (!nsum.TryGetValue(kk, out e)) { e = new double[3]; nsum[kk] = e; } e[0] += n[0]; e[1] += n[1]; e[2] += n[2]; }
            }
            var pos = new List<double[]>(); var nrm = new List<double[]>(); var uvs = new List<double[]>(); var idx = new List<int>();
            var vid = new Dictionary<string, int>();
            Func<double[], double[], double[], string, int> vert = (p, n, uv, tag) =>
            {
                string kk = tag + "|" + key(p); int id;
                if (vid.TryGetValue(kk, out id)) return id;
                id = pos.Count; vid[kk] = id;
                pos.Add(new[] { p[0] * scale, (p[2] - minZ) * scale, -p[1] * scale }); // Y up
                double l = Math.Sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]); if (l < 1e-12) l = 1;
                nrm.Add(new[] { n[0] / l, n[2] / l, -n[1] / l }); uvs.Add(uv);
                return id;
            };
            int surf = 0;
            foreach (var pg in polys)
            {
                var uv = uvOf(pg.Item2);
                var ids = pg.Item1.Select(p => vert(p, nsum[key(p)], uv, pg.Item2)).ToList();
                for (int k = 1; k + 1 < ids.Count; k++) { if (ids[0] == ids[k] || ids[k] == ids[k + 1] || ids[0] == ids[k + 1]) continue; idx.Add(ids[0]); idx.Add(ids[k]); idx.Add(ids[k + 1]); surf++; }
            }
            // cut faces: at a0 facing -t0, at a1 facing +t1 (own flat vertices)
            int capTris = 0;
            for (int side = 0; side < 2; side++)
            {
                double ang = side == 0 ? a0 : a1;
                double[] d = { Math.Cos(ang), Math.Sin(ang) };
                double[] n = side == 0 ? new[] { -t0[0], -t0[1], 0.0 } : new[] { t1[0], t1[1], 0.0 };
                foreach (var r in caps[side == 0 ? s : (s + 1) % slices])
                {
                    var uv = uvOf(r.Item5);
                    Func<double, double, double[]> P3 = (u, z) => new[] { d[0] * u, d[1] * u, z };
                    var q = new[] { P3(r.Item1, r.Item3), P3(r.Item2, r.Item3), P3(r.Item2, r.Item4), P3(r.Item1, r.Item4) };
                    var ids = q.Select(p => vert(p, n, uv, "cap" + side + r.Item5)).ToArray();
                    // winding so the face looks along n
                    var fn = Cross(Sub(q[1], q[0]), Sub(q[2], q[0]));
                    bool same = fn[0] * n[0] + fn[1] * n[1] + fn[2] * n[2] > 0;
                    if (same) { idx.AddRange(new[] { ids[0], ids[1], ids[2], ids[0], ids[2], ids[3] }); }
                    else { idx.AddRange(new[] { ids[0], ids[2], ids[1], ids[0], ids[3], ids[2] }); }
                    capTris += 2;
                }
            }
            // the slice's foot, facing down (seen when it is in the hand)
            {
                var uvF = uvOf("Sponge"); int seg = 10; double zz = Zboard + 0.02;
                var ctr = vert(new[] { 0.0, 0.0, zz }, new[] { 0.0, 0.0, -1.0 }, uvF, "foot");
                var ring = new List<int>();
                for (int k = 0; k <= seg; k++)
                {
                    double an = a0 + (a1 - a0) * k / seg;
                    ring.Add(vert(new[] { Math.Cos(an) * baseR, Math.Sin(an) * baseR, zz }, new[] { 0.0, 0.0, -1.0 }, uvF, "foot"));
                }
                // (the ring runs counter-clockwise seen from above: reversed, so the face looks down)
                for (int k = 0; k < seg; k++) { idx.Add(ctr); idx.Add(ring[k + 1]); idx.Add(ring[k]); capTris++; }
            }
            meshes.Add(Tuple.Create("Slice" + (s + 1), pos, nrm, uvs, idx));
            rep.AppendFormat("Slice{0}: {1} surface + {2} cut tris\n", s + 1, surf, capTris);
        }
        // write glTF
        var ms = new MemoryStream(); var bw = new BinaryWriter(ms);
        var bufferViews = new List<object>(); var accessors = new List<object>(); var gmeshes = new List<object>(); var nodes = new List<object>();
        foreach (var mm in meshes)
        {
            var pos = mm.Item2; var nrm = mm.Item3; var uvs = mm.Item4; var idx = mm.Item5;
            long st = ms.Position; double[] mn = { 1e9, 1e9, 1e9 }, mx = { -1e9, -1e9, -1e9 };
            foreach (var p in pos) for (int a = 0; a < 3; a++) { bw.Write((float)p[a]); mn[a] = Math.Min(mn[a], p[a]); mx[a] = Math.Max(mx[a], p[a]); }
            bufferViews.Add(new Dictionary<string, object> { { "buffer", 0 }, { "byteOffset", (int)st }, { "byteLength", (int)(ms.Position - st) }, { "target", 34962 } });
            accessors.Add(new Dictionary<string, object> { { "bufferView", bufferViews.Count - 1 }, { "componentType", 5126 }, { "count", pos.Count }, { "type", "VEC3" }, { "min", mn }, { "max", mx } });
            int aP = accessors.Count - 1;
            st = ms.Position; foreach (var n in nrm) for (int a = 0; a < 3; a++) bw.Write((float)n[a]);
            bufferViews.Add(new Dictionary<string, object> { { "buffer", 0 }, { "byteOffset", (int)st }, { "byteLength", (int)(ms.Position - st) }, { "target", 34962 } });
            accessors.Add(new Dictionary<string, object> { { "bufferView", bufferViews.Count - 1 }, { "componentType", 5126 }, { "count", nrm.Count }, { "type", "VEC3" } });
            int aN = accessors.Count - 1;
            st = ms.Position; foreach (var uv in uvs) { bw.Write((float)uv[0]); bw.Write((float)uv[1]); }
            bufferViews.Add(new Dictionary<string, object> { { "buffer", 0 }, { "byteOffset", (int)st }, { "byteLength", (int)(ms.Position - st) }, { "target", 34962 } });
            accessors.Add(new Dictionary<string, object> { { "bufferView", bufferViews.Count - 1 }, { "componentType", 5126 }, { "count", uvs.Count }, { "type", "VEC2" } });
            int aU = accessors.Count - 1;
            st = ms.Position; foreach (int k in idx) bw.Write((uint)k);
            bufferViews.Add(new Dictionary<string, object> { { "buffer", 0 }, { "byteOffset", (int)st }, { "byteLength", (int)(ms.Position - st) }, { "target", 34963 } });
            accessors.Add(new Dictionary<string, object> { { "bufferView", bufferViews.Count - 1 }, { "componentType", 5125 }, { "count", idx.Count }, { "type", "SCALAR" } });
            int aI = accessors.Count - 1;
            gmeshes.Add(new Dictionary<string, object> { { "name", mm.Item1 }, { "primitives", new[] { new Dictionary<string, object> { { "attributes", new Dictionary<string, object> { { "POSITION", aP }, { "NORMAL", aN }, { "TEXCOORD_0", aU } } }, { "indices", aI }, { "material", 0 } } } } });
            nodes.Add(new Dictionary<string, object> { { "name", mm.Item1 }, { "mesh", gmeshes.Count - 1 } });
        }
        bw.Flush(); var bytes = ms.ToArray();
        var pms = new MemoryStream(); pal.Save(pms, ImageFormat.Png);
        if (previewPng != null) Preview(meshes, pal, previewPng, new HashSet<string> { "Slice4", "Slice5" });
        var gltf = new Dictionary<string, object> {
            { "asset", new Dictionary<string, object> { { "version", "2.0" }, { "generator", "OHU CakeCut" } } },
            { "scene", 0 }, { "scenes", new[] { new Dictionary<string, object> { { "nodes", Enumerable.Range(0, nodes.Count).ToArray() } } } },
            { "nodes", nodes }, { "meshes", gmeshes },
            { "materials", new[] { new Dictionary<string, object> { { "name", "CakePalette" }, { "pbrMetallicRoughness", new Dictionary<string, object> { { "baseColorTexture", new Dictionary<string, object> { { "index", 0 } } }, { "metallicFactor", 0 }, { "roughnessFactor", 0.65 } } } } } },
            { "samplers", new[] { new Dictionary<string, object> { { "magFilter", 9728 }, { "minFilter", 9728 } } } },
            { "images", new[] { new Dictionary<string, object> { { "uri", "data:image/png;base64," + Convert.ToBase64String(pms.ToArray()) } } } },
            { "textures", new[] { new Dictionary<string, object> { { "sampler", 0 }, { "source", 0 } } } },
            { "accessors", accessors }, { "bufferViews", bufferViews },
            { "buffers", new[] { new Dictionary<string, object> { { "byteLength", bytes.Length }, { "uri", "data:application/octet-stream;base64," + Convert.ToBase64String(bytes) } } } } };
        var ser = new System.Web.Script.Serialization.JavaScriptSerializer { MaxJsonLength = int.MaxValue };
        File.WriteAllText(gltfPath, ser.Serialize(gltf));
        return rep.ToString();
    }

    // the cut face at angle a: rows of height dz; in each row the inside
    // intervals along the plane (even-odd over the whole line), kept for
    // u >= 0, split where the inside colour changes; rows with the same
    // pieces are joined upward
    static List<Tuple<double, double, double, double, string>> CapRects(Cache c, double cx, double cy, double a, double dz)
    {
        double[] t = { -Math.Sin(a), Math.Cos(a) }, d = { Math.Cos(a), Math.Sin(a) };
        var segs = new List<double[]>(); // u0, z0, u1, z1
        foreach (var tri in c.T)
        {
            var P = tri.Select(k => new[] { c.V[k][0] - cx, c.V[k][1] - cy, c.V[k][2] }).ToArray();
            var s = P.Select(p => t[0] * p[0] + t[1] * p[1]).ToArray();
            var pts = new List<double[]>();
            for (int e = 0; e < 3; e++)
            {
                int f = (e + 1) % 3;
                if ((s[e] > 0) != (s[f] > 0))
                {
                    double k = s[e] / (s[e] - s[f]);
                    var p = new[] { P[e][0] + (P[f][0] - P[e][0]) * k, P[e][1] + (P[f][1] - P[e][1]) * k, P[e][2] + (P[f][2] - P[e][2]) * k };
                    pts.Add(new[] { d[0] * p[0] + d[1] * p[1], p[2] });
                }
            }
            if (pts.Count == 2) segs.Add(new[] { pts[0][0], pts[0][1], pts[1][0], pts[1][1] });
        }
        double zmin = c.Box[4], zmax = c.Box[5];
        var rows = new List<List<Tuple<double, double, string>>>(); var rowZ = new List<double>();
        for (double z = zmin; z < zmax; z += dz)
        {
            double zc = z + dz / 2;
            if (zc < Zboard + 0.05) continue; // (the board is not cut)
            var xs = new List<double>();
            foreach (var sg in segs)
                if ((sg[1] > zc) != (sg[3] > zc)) xs.Add(sg[0] + (sg[2] - sg[0]) * (zc - sg[1]) / (sg[3] - sg[1]));
            xs.Sort();
            var pieces = new List<Tuple<double, double, string>>();
            for (int i = 0; i + 1 < xs.Count; i += 2)
            {
                double u0 = Math.Max(0, xs[i]), u1 = xs[i + 1];
                if (u1 <= u0 + 1e-6) continue;
                // split where the colour changes
                var cuts = new List<double> { u0 };
                foreach (double b in new[] { Rwall - 1.6, Rwall + 1.3 }) if (b > u0 && b < u1) cuts.Add(b);
                cuts.Add(u1);
                for (int k = 0; k + 1 < cuts.Count; k++) pieces.Add(Tuple.Create(cuts[k], cuts[k + 1], Inside((cuts[k] + cuts[k + 1]) / 2, zc)));
            }
            rows.Add(pieces); rowZ.Add(z);
        }
        // join rows upward when a piece matches the one below (same colour, ends within 0.35)
        var outR = new List<Tuple<double, double, double, double, string>>();
        var open = new List<double[]>(); var openC = new List<string>(); // u0, u1, z0, z1
        for (int r = 0; r < rows.Count; r++)
        {
            var next = new List<double[]>(); var nextC = new List<string>();
            var used = new bool[open.Count];
            foreach (var p in rows[r])
            {
                int hit = -1;
                for (int o = 0; o < open.Count; o++) if (!used[o] && openC[o] == p.Item3 && Math.Abs(open[o][0] - p.Item1) < 0.35 && Math.Abs(open[o][1] - p.Item2) < 0.35) { hit = o; break; }
                if (hit >= 0) { used[hit] = true; var e = open[hit]; e[3] = rowZ[r] + dz; e[0] = Math.Min(e[0], p.Item1); e[1] = Math.Max(e[1], p.Item2); next.Add(e); nextC.Add(openC[hit]); }
                else { next.Add(new[] { p.Item1, p.Item2, rowZ[r], rowZ[r] + dz }); nextC.Add(p.Item3); }
            }
            for (int o = 0; o < open.Count; o++) if (!used[o]) outR.Add(Tuple.Create(open[o][0], open[o][1], open[o][2], open[o][3], openC[o]));
            open = next; openC = nextC;
        }
        for (int o = 0; o < open.Count; o++) outR.Add(Tuple.Create(open[o][0], open[o][1], open[o][2], open[o][3], openC[o]));
        return outR;
    }

    // two oblique views of the output (Y up), palette colours, flat light,
    // back faces drawn dark red (a flipped face would show as red): the whole
    // cake, and the cake with `skip` slices taken away; plus one slice alone
    static void Preview(List<Tuple<string, List<double[]>, List<double[]>, List<double[]>, List<int>>> meshes, Bitmap pal, string png, HashSet<string> skip)
    {
        int W = 600; var bmp = new Bitmap(W * 3, W);
        for (int view = 0; view < 3; view++)
        {
            var zb = new double[W, W]; var col = new Color[W, W];
            for (int i = 0; i < W; i++) for (int j = 0; j < W; j++) { zb[i, j] = double.MaxValue; col[i, j] = Color.FromArgb(235, 235, 240); }
            // camera: from the front (+z) and above, looking at the middle
            double yaw = view == 2 ? -0.9 : 0.35, pitch = view == 2 ? 0.35 : 0.6;
            double[] f = { -Math.Sin(yaw) * Math.Cos(pitch), -Math.Sin(pitch), -Math.Cos(yaw) * Math.Cos(pitch) }; // forward
            double[] rgt = { Math.Cos(yaw), 0, -Math.Sin(yaw) };
            double[] up = { rgt[1] * f[2] - rgt[2] * f[1], rgt[2] * f[0] - rgt[0] * f[2], rgt[0] * f[1] - rgt[1] * f[0] };
            double span = 3.4, cy = 0.8;
            foreach (var mm in meshes)
            {
                if (view == 1 && skip.Contains(mm.Item1)) continue;
                if (view == 2 && mm.Item1 != "Slice4") continue;
                var P = mm.Item2; var UV = mm.Item4; var I = mm.Item5;
                for (int t = 0; t + 2 < I.Count; t += 3)
                {
                    var A = P[I[t]]; var B = P[I[t + 1]]; var C = P[I[t + 2]];
                    var n = Cross(Sub(B, A), Sub(C, A)); double l = Math.Sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]); if (l < 1e-12) continue;
                    n = new[] { n[0] / l, n[1] / l, n[2] / l };
                    bool back = n[0] * f[0] + n[1] * f[1] + n[2] * f[2] > 0;
                    var uv = UV[I[t]];
                    var pc = pal.GetPixel(Math.Min(pal.Width - 1, (int)(uv[0] * pal.Width)), Math.Min(pal.Height - 1, (int)(uv[1] * pal.Height)));
                    double lt = 0.45 + 0.55 * Math.Max(0, n[0] * -0.3 + n[1] * 0.8 + n[2] * 0.5);
                    Color cc = back ? Color.FromArgb(120, 0, 0) : Color.FromArgb((int)(pc.R * lt), (int)(pc.G * lt), (int)(pc.B * lt));
                    var S = new[] { A, B, C }.Select(p => { var q = new[] { p[0], p[1] - cy, p[2] }; return new[] { (q[0] * rgt[0] + q[1] * rgt[1] + q[2] * rgt[2]) / span * W + W / 2.0, -(q[0] * up[0] + q[1] * up[1] + q[2] * up[2]) / span * W + W / 2.0, q[0] * f[0] + q[1] * f[1] + q[2] * f[2] }; }).ToArray();
                    int x0 = (int)Math.Max(0, Math.Floor(S.Min(s => s[0]))), x1 = (int)Math.Min(W - 1, Math.Ceiling(S.Max(s => s[0])));
                    int y0 = (int)Math.Max(0, Math.Floor(S.Min(s => s[1]))), y1 = (int)Math.Min(W - 1, Math.Ceiling(S.Max(s => s[1])));
                    double den = (S[1][1] - S[2][1]) * (S[0][0] - S[2][0]) + (S[2][0] - S[1][0]) * (S[0][1] - S[2][1]);
                    if (Math.Abs(den) < 1e-12) continue;
                    for (int py = y0; py <= y1; py++) for (int px = x0; px <= x1; px++)
                    {
                        double w0 = ((S[1][1] - S[2][1]) * (px + 0.5 - S[2][0]) + (S[2][0] - S[1][0]) * (py + 0.5 - S[2][1])) / den;
                        double w1 = ((S[2][1] - S[0][1]) * (px + 0.5 - S[2][0]) + (S[0][0] - S[2][0]) * (py + 0.5 - S[2][1])) / den;
                        double w2 = 1 - w0 - w1;
                        if (w0 < 0 || w1 < 0 || w2 < 0) continue;
                        double dd = w0 * S[0][2] + w1 * S[1][2] + w2 * S[2][2];
                        if (dd < zb[px, py]) { zb[px, py] = dd; col[px, py] = cc; }
                    }
                }
            }
            for (int i = 0; i < W; i++) for (int j = 0; j < W; j++) bmp.SetPixel(view * W + i, j, col[i, j]);
        }
        bmp.Save(png, ImageFormat.Png);
    }

    static List<double[]> Clip(List<double[]> poly, Func<double[], double> f)
    {
        var res = new List<double[]>();
        for (int i = 0; i < poly.Count; i++)
        {
            var A = poly[i]; var B = poly[(i + 1) % poly.Count];
            double fa = f(A), fb = f(B);
            if (fa >= 0) res.Add(A);
            if ((fa >= 0) != (fb >= 0))
            {
                double k = fa / (fa - fb);
                res.Add(new[] { A[0] + (B[0] - A[0]) * k, A[1] + (B[1] - A[1]) * k, A[2] + (B[2] - A[2]) * k });
            }
        }
        return res;
    }
    static double[] Sub(double[] a, double[] b) { return new[] { a[0] - b[0], a[1] - b[1], a[2] - b[2] }; }
    static double[] Cross(double[] a, double[] b) { return new[] { a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0] }; }
}
