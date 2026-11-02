// The tiramisu, basque cheesecake and strawberry cream cakes (user Meshy STL
// files 2026-10-30, D-781): their colour groups, colours and insides, for
// CakeCut like the vintage lettering cake's (CakeTool.VintageGroup).
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

public static class CakeKinds
{
    // c = centre x, y, z (model units, Z up, the cakes are centred on 0, 0
    // within 0.15) then the face normal; all three are 50 units tall
    static double R(double[] c) { return Math.Sqrt(c[0] * c[0] + c[1] * c[1]); }
    static double Out(double[] c) { double r = R(c); return r < 1e-9 ? 0 : (c[3] * c[0] + c[4] * c[1]) / r; }
    static bool Near(double[] c, double x, double y, double z, double d)
    {
        return (c[0] - x) * (c[0] - x) + (c[1] - y) * (c[1] - y) + (c[2] - z) * (c[2] - z) < d * d;
    }

    // ---- tiramisu (photo docs/04_ART/references/cakes/cake_tiramisu.png):
    // a crumb base, a white mascarpone wall, a cocoa top in ridges, a plain
    // gold plaque (no lettering) and two gold flakes ----
    public static string Tiramisu(double[] c)
    {
        double z = c[2], nz = c[5];
        if (z < 10) return "Crust";
        if (z >= 43.2 && c[0] > -14 && c[0] < 23 && c[1] > 31 && c[1] < 66 && nz > 0.6) return "Gold";
        if (z > 41 && (Near(c, 40, 27, 44, 4) || Near(c, -56, 10, 43, 4))) return "Gold";
        if (z < 37.5 && R(c) > 60) return "Mascarpone";
        return nz > 0.92 ? "Cocoa" : "CocoaDark";
    }
    public static readonly string TiramisuColors =
        "Board=246,244,240;Crust=112,78,52;Mascarpone=246,240,224;Cocoa=112,66,40;CocoaDark=78,44,27;Gold=112,66,40"; // (Gold = Cocoa since D-783, user: no odd-coloured patches; the group stays so the palette cells line up)

    // ---- basque burnt cheesecake (photo cake_basque_cheese.png): a caramel
    // top, a near-black burnt rim and sides, the cream showing in the folds ----
    public static string Basque(double[] c)
    {
        double z = c[2], nz = c[5], r = R(c);
        if (z < 1.5 && nz < -0.7) return "Bottom";
        if (nz > 0.55) return r < 42 ? "Top" : "Rim";
        // the sides: burnt where they face straight out, golden where they
        // turn, the cream in the folds (no band by height: it read as a line)
        double o = Out(c);
        if (o > 0.75) return nz > 0.2 ? "BurntDark" : "Burnt";
        if (o > 0.35) return "Golden";
        return "Fold";
    }
    public static readonly string BasqueColors =
        "Board=246,244,240;Bottom=120,72,40;Top=135,72,35;Rim=70,36,20;BurntDark=62,32,18;Burnt=92,50,28;Golden=160,98,48;Fold=236,196,120";

    // ---- strawberry cream cake (photo cake_strawberry_cream.png): a cream
    // board under it, a white cream cake, a ring of piped cream balls, the
    // strawberries inside the ring, thyme sprigs on the ring, a plain card
    // (no lettering) in the middle ----
    static readonly double[][] SBerries = {
        new[] { -13.18, 25.31 }, new[] { 10.86, 22.99 }, new[] { -24.66, 12.56 }, new[] { 21.07, 1.10 }, new[] { -20.30, -3.72 }, new[] { -0.70, -12.76 } };
    // (D-783, user: the strawberries' seeds) little yellow dots: one in every
    // third 1.8-unit cell of the surface, within 0.6 of its middle
    static bool Seed(double[] c)
    {
        const double S = 1.8;
        long qx = (long)Math.Floor(c[0] / S), qy = (long)Math.Floor(c[1] / S), qz = (long)Math.Floor(c[2] / S);
        long h = (qx * 73856093) ^ (qy * 19349663) ^ (qz * 83492791);
        if (((h % 3) + 3) % 3 != 0) return false;
        double dx = c[0] - (qx + 0.5) * S, dy = c[1] - (qy + 0.5) * S, dz = c[2] - (qz + 0.5) * S;
        return dx * dx + dy * dy + dz * dz < 0.6 * 0.6;
    }
    public static string Strawberry(double[] c)
    {
        double z = c[2], r = R(c);
        if (z < 1.0) return "Board"; // (its top is at 0.8..1.0)
        if (z < 29) return "Side";
        // the piped balls sit on a ring off the cake's middle (found with
        // CakeTool.Balls: centre 0.5, 5.5, radius 38.5, z 35): near it in
        // (distance out, z) = piping
        double rr = Math.Sqrt((c[0] - 0.5) * (c[0] - 0.5) + (c[1] - 5.5) * (c[1] - 5.5));
        double d = Math.Sqrt((rr - 38.5) * (rr - 38.5) + (z - 35) * (z - 35));
        if (z < 31) return rr >= 34 ? "Side" : "TopCream";
        if (d < 7.2 || (rr >= 30 && z < 37.5)) return "Piping"; // (and the balls' inner feet)
        if (rr >= 34) return "Leaf"; // (the sprigs stand out of the ring)
        if (z < 33.8) return "TopCream";
        if (c[0] > -12 && c[0] < 9 && c[1] > 1 && c[1] < 15 && z < 40) return "Label";
        // the six strawberries (centres from CakeTool.Balls); thin bits
        // elsewhere are thyme
        foreach (var b in SBerries) if ((c[0] - b[0]) * (c[0] - b[0]) + (c[1] - b[1]) * (c[1] - b[1]) < 100) return Seed(c) ? "Seed" : "Berry";
        return "Leaf";
    }
    public static readonly string StrawberryColors =
        "Board=238,222,178;Side=252,250,246;TopCream=255,253,248;Piping=255,252,246;Leaf=86,140,62;Label=246,240,230;Berry=205,30,45;Seed=240,205,100";

    // What CakeCut needs to know about a cake (the vintage one as before):
    // its groups and colours, the groups left whole under the slices (the
    // board), the board's top height, the inside colour of a cut face at
    // distance u out and height z, the u where that colour may change, the
    // reduction weights, and where its decoration ring is (to cut between it)
    public class Kind
    {
        public string Name;
        public Func<double[], string> Group;
        public string Colors;
        public string[] Whole;
        public double Zboard;
        public Func<double, double, string> Inside;
        public double[] SplitU;
        public Func<string, double> Weight;
        public double RingZ, RingR; // BestStart counts triangles above RingZ and out past RingR
    }

    public static Kind Get(string name)
    {
        switch (name)
        {
            case "vintage":
                return new Kind
                {
                    Name = name, Group = CakeTool.VintageGroup, Colors = CakeTool.VintageColors + ";Sponge=246,220,160;CutCream=255,250,240;Jam=225,70,90",
                    Whole = new[] { "Board", "Label" }, Zboard = 1.0, Inside = CakeCut.VintageInside, SplitU = new[] { CakeCut.Rwall - 1.6, CakeCut.Rwall + 1.3 },
                    Weight = n => n.StartsWith("Letter") || n.StartsWith("Flower") ? 40.0 : n == "Pearl" || n == "Stem" || n == "Cherry" ? 10.0 : n == "Board" || n == "Top" || n == "Side" ? 0.5 : 1.0,
                    RingZ = 34, RingR = 20,
                };
            case "tiramisu":
                // inside: the crumb base, then mascarpone with a coffee-soaked
                // sponge layer, cocoa dusting on top
                return new Kind
                {
                    Name = name, Group = Tiramisu, Colors = TiramisuColors + ";Sponge=150,100,62;CutCream=248,242,226",
                    Whole = new string[0], Zboard = 0.0, SplitU = new double[0],
                    Inside = (u, z) => z < 9 ? "Crust" : z > 38.5 ? "Cocoa" : (z > 20 && z < 26) ? "Sponge" : "CutCream",
                    Weight = n => n == "Gold" ? 20.0 : n == "Mascarpone" || n == "Crust" ? 0.5 : 1.0,
                    RingZ = 43.2, RingR = 0,
                };
            case "basque":
                // inside: soft cheese custard under a thin burnt skin
                return new Kind
                {
                    Name = name, Group = Basque, Colors = BasqueColors + ";Custard=246,218,150;Skin=92,50,28",
                    Whole = new string[0], Zboard = 0.0, SplitU = new[] { 61.0 },
                    Inside = (u, z) => (u > 61 || z < 1.6) ? "Skin" : "Custard",
                    Weight = n => n == "Fold" ? 2.0 : 1.0,
                    RingZ = 44, RingR = 50,
                };
            case "strawberry":
                // inside: a cream coat round sponge layers with cream and
                // strawberry slices between them
                return new Kind
                {
                    Name = name, Group = Strawberry, Colors = StrawberryColors + ";Sponge=246,222,160;CutCream=255,252,246;BerryCut=228,70,80",
                    Whole = new[] { "Board" }, Zboard = 1.0, SplitU = new[] { 48.3 },
                    Inside = (u, z) => (u > 48.3 || z > 28.5 || z < 3.5) ? "CutCream" : z < 12 ? "Sponge" : z < 14.5 ? "BerryCut" : z < 16 ? "CutCream" : z < 24 ? "Sponge" : z < 26.5 ? "BerryCut" : "CutCream",
                    Weight = n => n == "Leaf" || n == "Label" ? 20.0 : n == "Berry" || n == "Seed" ? 6.0 : n == "Board" || n == "Side" ? 0.5 : 1.0,
                    RingZ = 33.8, RingR = 31,
                };
        }
        throw new ArgumentException("unknown cake " + name);
    }

    public static void Views(string name, string path, string png, int size)
    {
        var k = Get(name);
        CakeTool.Views(path, png, size, k.Group, k.Colors);
    }

    // height profile: per z band, triangles, the farthest r, and how many face up / out
    public static string ZHist(string path, double zstep)
    {
        var m = StlTool.Load(path);
        double cx = (m.Min[0] + m.Max[0]) / 2, cy = (m.Min[1] + m.Max[1]) / 2;
        var rows = new SortedDictionary<int, double[]>();
        foreach (var t in m.T)
        {
            var a = m.V[t[0]]; var b = m.V[t[1]]; var c = m.V[t[2]];
            double x = (a[0] + b[0] + c[0]) / 3 - cx, y = (a[1] + b[1] + c[1]) / 3 - cy, z = (a[2] + b[2] + c[2]) / 3;
            double nx = (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]);
            double ny = (b[2] - a[2]) * (c[0] - a[0]) - (b[0] - a[0]) * (c[2] - a[2]);
            double nz = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
            double l = Math.Sqrt(nx * nx + ny * ny + nz * nz); if (l < 1e-12) continue;
            double r = Math.Sqrt(x * x + y * y);
            int k = (int)Math.Floor(z / zstep);
            double[] e; if (!rows.TryGetValue(k, out e)) { e = new double[5]; rows[k] = e; }
            e[0]++; e[1] = Math.Max(e[1], r); if (nz / l > 0.7) e[2]++; if (nz / l < -0.7) e[3]++;
            if (r > 0 && (nx * x + ny * y) / (l * r) > 0.7) e[4]++;
        }
        var sb = new System.Text.StringBuilder();
        foreach (var kv in rows) sb.AppendFormat(CultureInfo.InvariantCulture, "z {0,5:F1}: {1,6} rmax {2,5:F1} up {3,6} down {4,6} out {5,6}\n", kv.Key * zstep, kv.Value[0], kv.Value[1], kv.Value[2], kv.Value[3], kv.Value[4]);
        return sb.ToString();
    }
}
