// Textured food models (user 2026-10-29 (18): "make them like the photos").
// Input: the reduced group mesh JSON from StlTool.ExportNamed ({group: {v, f}},
// studs, Y up, bottom at 0). Every triangle gets its own three corners and UVs
// into one texture:
//   mode "photo"  (parfait): a straight front projection onto the user's photo
//                  (px = cx + X * k, py = by - Y * k, in photo pixels)
//   mode "bread"  (honey bread): an atlas of four 512 squares painted by
//                  tools/art/food_textures.ps1: top of the loaf (0,0), its
//                  sides (0.5,0), the plate (0,0.5), the cream (0.5,0.5)
// Thin groups (doubleSided) also get the back faces, so a part squeezed flat
// by the reduction still shows from below (the plate had holes).
// Writes: a glTF (one mesh + material per group, the texture embedded) and a
// preview JSON {group: {v: [...], uv: [...]}} for an EditableMesh in Studio.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Web.Script.Serialization;

public static class FoodGltf
{
    static string F(double d) { return d.ToString("0.#####", CultureInfo.InvariantCulture); }

    public static string Build(string jsonPath, string texPath, string gltfPath, string previewPath, string mode,
        double cx, double by, double k, double texW, double texH, string doubleSided, string alphaGroups)
    {
        var ser = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
        var data = (Dictionary<string, object>)ser.DeserializeObject(File.ReadAllText(jsonPath));
        var dbl = new HashSet<string>(doubleSided.Split(',').Where(s => s != ""));
        var alpha = new Dictionary<string, double>();
        foreach (var a in alphaGroups.Split(',').Where(s => s != "")) { var kv = a.Split('='); alpha[kv[0]] = double.Parse(kv[1], CultureInfo.InvariantCulture); }

        var ms = new MemoryStream(); var bw = new BinaryWriter(ms);
        var bufferViews = new List<object>(); var accessors = new List<object>(); var meshes = new List<object>(); var materials = new List<object>(); var nodes = new List<object>();
        var preview = new StringBuilder("{"); var rep = new StringBuilder();
        bool firstG = true;
        foreach (var kv in data)
        {
            string g = kv.Key;
            var o = (Dictionary<string, object>)kv.Value;
            var vRaw = ((object[])o["v"]).Select(Convert.ToDouble).ToArray();
            var fRaw = ((object[])o["f"]).Select(Convert.ToInt32).ToArray();
            double[] lo = { 1e9, 1e9, 1e9 }, hi = { -1e9, -1e9, -1e9 };
            for (int i = 0; i < vRaw.Length; i += 3) for (int a = 0; a < 3; a++) { lo[a] = Math.Min(lo[a], vRaw[i + a]); hi[a] = Math.Max(hi[a], vRaw[i + a]); }
            var pos = new List<double>(); var nrm = new List<double>(); var uv = new List<double>();
            int passes = dbl.Contains(g) ? 2 : 1;
            for (int pass = 0; pass < passes; pass++)
            for (int t = 0; t < fRaw.Length; t += 3)
            {
                int[] idx = pass == 0 ? new[] { fRaw[t], fRaw[t + 1], fRaw[t + 2] } : new[] { fRaw[t], fRaw[t + 2], fRaw[t + 1] };
                var P = idx.Select(i => new[] { vRaw[i * 3], vRaw[i * 3 + 1], vRaw[i * 3 + 2] }).ToArray();
                double ux = P[1][0] - P[0][0], uy = P[1][1] - P[0][1], uz = P[1][2] - P[0][2];
                double wx = P[2][0] - P[0][0], wy = P[2][1] - P[0][1], wz = P[2][2] - P[0][2];
                double nx = uy * wz - uz * wy, ny = uz * wx - ux * wz, nz = ux * wy - uy * wx;
                double l = Math.Sqrt(nx * nx + ny * ny + nz * nz); if (l < 1e-12) continue;
                nx /= l; ny /= l; nz /= l;
                foreach (var p in P)
                {
                    pos.Add(p[0]); pos.Add(p[1]); pos.Add(p[2]);
                    nrm.Add(nx); nrm.Add(ny); nrm.Add(nz);
                    double u, v;
                    if (mode == "photo") { u = (cx + p[0] * k) / texW; v = (by - p[1] * k) / texH; }
                    else
                    {
                        // atlas square (ox, oy), local s/t in 0..1
                        double ox, oy, s, tt;
                        double sx = (p[0] - (lo[0] + hi[0]) / 2) / Math.Max(1e-6, hi[0] - lo[0]) + 0.5;
                        double sz = (p[2] - (lo[2] + hi[2]) / 2) / Math.Max(1e-6, hi[2] - lo[2]) + 0.5;
                        if (g == "Plate") { ox = 0; oy = 0.5; s = sx; tt = sz; }
                        else if (g == "Cream") { ox = 0.5; oy = 0.5; s = sx; tt = sz; }
                        else if (Math.Abs(ny) > 0.55) { ox = 0; oy = 0; s = sx; tt = sz; }
                        else
                        {
                            ox = 0.5; oy = 0;
                            s = Math.Abs(nx) > Math.Abs(nz) ? sz : sx;
                            tt = (hi[1] - p[1]) / Math.Max(1e-6, hi[1] - lo[1]);
                        }
                        s = Math.Min(0.995, Math.Max(0.005, s)); tt = Math.Min(0.995, Math.Max(0.005, tt));
                        u = ox + 0.5 * s; v = oy + 0.5 * tt;
                    }
                    uv.Add(u); uv.Add(v);
                }
            }
            int nv = pos.Count / 3;
            // positions
            double[] mn = { 1e9, 1e9, 1e9 }, mx = { -1e9, -1e9, -1e9 };
            long start = ms.Position;
            for (int i = 0; i < pos.Count; i++) { bw.Write((float)pos[i]); int a = i % 3; mn[a] = Math.Min(mn[a], pos[i]); mx[a] = Math.Max(mx[a], pos[i]); }
            bufferViews.Add(new Dictionary<string, object> { { "buffer", 0 }, { "byteOffset", (int)start }, { "byteLength", (int)(ms.Position - start) }, { "target", 34962 } });
            accessors.Add(new Dictionary<string, object> { { "bufferView", bufferViews.Count - 1 }, { "componentType", 5126 }, { "count", nv }, { "type", "VEC3" }, { "min", mn }, { "max", mx } });
            int aPos = accessors.Count - 1;
            start = ms.Position; foreach (var x in nrm) bw.Write((float)x);
            bufferViews.Add(new Dictionary<string, object> { { "buffer", 0 }, { "byteOffset", (int)start }, { "byteLength", (int)(ms.Position - start) }, { "target", 34962 } });
            accessors.Add(new Dictionary<string, object> { { "bufferView", bufferViews.Count - 1 }, { "componentType", 5126 }, { "count", nv }, { "type", "VEC3" } });
            int aNrm = accessors.Count - 1;
            start = ms.Position; foreach (var x in uv) bw.Write((float)x);
            bufferViews.Add(new Dictionary<string, object> { { "buffer", 0 }, { "byteOffset", (int)start }, { "byteLength", (int)(ms.Position - start) }, { "target", 34962 } });
            accessors.Add(new Dictionary<string, object> { { "bufferView", bufferViews.Count - 1 }, { "componentType", 5126 }, { "count", nv }, { "type", "VEC2" } });
            int aUv = accessors.Count - 1;
            double al = alpha.ContainsKey(g) ? alpha[g] : 1;
            var pbr = new Dictionary<string, object> { { "baseColorTexture", new Dictionary<string, object> { { "index", 0 } } }, { "baseColorFactor", new[] { 1.0, 1.0, 1.0, al } }, { "metallicFactor", 0 }, { "roughnessFactor", 0.55 } };
            var mat = new Dictionary<string, object> { { "name", g }, { "pbrMetallicRoughness", pbr } };
            if (al < 1) mat["alphaMode"] = "BLEND";
            materials.Add(mat);
            meshes.Add(new Dictionary<string, object> { { "name", g }, { "primitives", new[] { new Dictionary<string, object> { { "attributes", new Dictionary<string, object> { { "POSITION", aPos }, { "NORMAL", aNrm }, { "TEXCOORD_0", aUv } } }, { "material", materials.Count - 1 } } } } });
            nodes.Add(new Dictionary<string, object> { { "name", g }, { "mesh", meshes.Count - 1 } });
            // preview
            preview.Append(firstG ? "" : ",").Append('"').Append(g).Append("\":{\"v\":[").Append(string.Join(",", pos.Select(F))).Append("],\"uv\":[").Append(string.Join(",", uv.Select(F))).Append("]}");
            firstG = false;
            rep.AppendFormat("{0}: {1} tris\n", g, nv / 3);
        }
        preview.Append("}");
        File.WriteAllText(previewPath, preview.ToString());
        bw.Flush();
        var bytes = ms.ToArray();
        var png = File.ReadAllBytes(texPath);
        var gltf = new Dictionary<string, object> {
            { "asset", new Dictionary<string, object> { { "version", "2.0" }, { "generator", "OHU FoodGltf" } } },
            { "scene", 0 },
            { "scenes", new[] { new Dictionary<string, object> { { "nodes", Enumerable.Range(0, nodes.Count).ToArray() } } } },
            { "nodes", nodes }, { "meshes", meshes }, { "materials", materials }, { "accessors", accessors }, { "bufferViews", bufferViews },
            { "samplers", new[] { new Dictionary<string, object> { { "magFilter", 9729 }, { "minFilter", 9987 } } } },
            { "images", new[] { new Dictionary<string, object> { { "uri", "data:image/png;base64," + Convert.ToBase64String(png) } } } },
            { "textures", new[] { new Dictionary<string, object> { { "sampler", 0 }, { "source", 0 } } } },
            { "buffers", new[] { new Dictionary<string, object> { { "byteLength", bytes.Length }, { "uri", "data:application/octet-stream;base64," + Convert.ToBase64String(bytes) } } } },
        };
        File.WriteAllText(gltfPath, ser.Serialize(gltf));
        return rep.ToString();
    }
}
