// Quadric edge-collapse simplification (Garland & Heckbert) for the food
// models (user 2026-10-30: the grid reduction folded thin parts over, the
// board and the cake wall showed flipped faces and cracks between colours).
// - every face keeps its group (colour); edges where two groups meet, and
//   open edges, get heavy side planes so the borders keep their place and the
//   groups stay joined (one shared vertex set, no cracks)
// - a collapse that would turn any face around (normal against its old one)
//   or make a sliver is refused, so the result has no flipped faces
using System;
using System.Collections.Generic;
using System.Linq;

public static class Qem
{
    struct Q
    {
        public double a, b, c, d, e, f, g, h, i, j; // symmetric 4x4: [a b c d; b e f g; c f h i; d g i j]
        public static Q Plane(double nx, double ny, double nz, double dd, double w)
        {
            return new Q { a = w * nx * nx, b = w * nx * ny, c = w * nx * nz, d = w * nx * dd, e = w * ny * ny, f = w * ny * nz, g = w * ny * dd, h = w * nz * nz, i = w * nz * dd, j = w * dd * dd };
        }
        public static Q operator +(Q p, Q q) { return new Q { a = p.a + q.a, b = p.b + q.b, c = p.c + q.c, d = p.d + q.d, e = p.e + q.e, f = p.f + q.f, g = p.g + q.g, h = p.h + q.h, i = p.i + q.i, j = p.j + q.j }; }
        public double Err(double x, double y, double z)
        {
            return a * x * x + 2 * b * x * y + 2 * c * x * z + 2 * d * x + e * y * y + 2 * f * y * z + 2 * g * y + h * z * z + 2 * i * z + j;
        }
        // the point of least error, when the 3x3 part can be solved
        public bool Best(out double x, out double y, out double z)
        {
            double det = a * (e * h - f * f) - b * (b * h - f * c) + c * (b * f - e * c);
            x = y = z = 0;
            if (Math.Abs(det) < 1e-12) return false;
            double i00 = (e * h - f * f) / det, i01 = -(b * h - c * f) / det, i02 = (b * f - c * e) / det;
            double i11 = (a * h - c * c) / det, i12 = -(a * f - b * c) / det, i22 = (a * e - b * b) / det;
            x = -(i00 * d + i01 * g + i02 * i); y = -(i01 * d + i11 * g + i12 * i); z = -(i02 * d + i12 * g + i22 * i);
            return true;
        }
    }

    class Heap
    {
        List<double> cost = new List<double>(); List<int> u = new List<int>(); List<int> v = new List<int>(); List<int> vu = new List<int>(); List<int> vv = new List<int>();
        public int Count { get { return cost.Count; } }
        void Swap(int p, int q)
        {
            double tc = cost[p]; cost[p] = cost[q]; cost[q] = tc;
            int t = u[p]; u[p] = u[q]; u[q] = t; t = v[p]; v[p] = v[q]; v[q] = t;
            t = vu[p]; vu[p] = vu[q]; vu[q] = t; t = vv[p]; vv[p] = vv[q]; vv[q] = t;
        }
        public void Push(double c, int a, int b, int va, int vb)
        {
            cost.Add(c); u.Add(a); v.Add(b); vu.Add(va); vv.Add(vb);
            int k = cost.Count - 1;
            while (k > 0) { int p = (k - 1) / 2; if (cost[p] <= cost[k]) break; Swap(p, k); k = p; }
        }
        public void Pop(out double c, out int a, out int b, out int va, out int vb)
        {
            c = cost[0]; a = u[0]; b = v[0]; va = vu[0]; vb = vv[0];
            int last = cost.Count - 1; Swap(0, last);
            cost.RemoveAt(last); u.RemoveAt(last); v.RemoveAt(last); vu.RemoveAt(last); vv.RemoveAt(last);
            int k = 0;
            while (true)
            {
                int l = 2 * k + 1, r = l + 1, s = k;
                if (l < cost.Count && cost[l] < cost[s]) s = l;
                if (r < cost.Count && cost[r] < cost[s]) s = r;
                if (s == k) break; Swap(s, k); k = s;
            }
        }
    }

    // V: vertices, T: triangles, G: group per triangle. Returns the kept
    // triangles (indices into the returned vertex list) with their groups.
    public static void Simplify(List<double[]> V, List<int[]> T, List<int> G, int target, double borderWeight,
        out List<double[]> outV, out List<int[]> outT, out List<int> outG, double[] groupWeight = null)
    {
        int nv = V.Count;
        var P = V.Select(p => new[] { p[0], p[1], p[2] }).ToArray();
        var faces = T.Select(t => new[] { t[0], t[1], t[2] }).ToList();
        var alive = Enumerable.Repeat(true, faces.Count).ToArray();
        var vf = new List<int>[nv]; for (int k = 0; k < nv; k++) vf[k] = new List<int>();
        for (int f = 0; f < faces.Count; f++) foreach (int k in faces[f]) vf[k].Add(f);
        var q = new Q[nv];
        // face quadrics (area weighted)
        for (int f = 0; f < faces.Count; f++)
        {
            double nx, ny, nz, area; Normal(P, faces[f], out nx, out ny, out nz, out area);
            if (area <= 0) continue;
            double dd = -(nx * P[faces[f][0]][0] + ny * P[faces[f][0]][1] + nz * P[faces[f][0]][2]);
            // (small detailed groups weigh more, so their shape is kept longer)
            var fq = Q.Plane(nx, ny, nz, dd, area * (groupWeight != null ? groupWeight[G[f]] : 1));
            foreach (int k in faces[f]) q[k] = q[k] + fq;
        }
        // border planes: edges between groups or with one face
        var edgeFaces = new Dictionary<long, List<int>>();
        for (int f = 0; f < faces.Count; f++)
            for (int e = 0; e < 3; e++)
            {
                int a = faces[f][e], b = faces[f][(e + 1) % 3];
                long key = Key(a, b); List<int> l; if (!edgeFaces.TryGetValue(key, out l)) { l = new List<int>(); edgeFaces[key] = l; } l.Add(f);
            }
        foreach (var kv in edgeFaces)
        {
            var fl = kv.Value;
            bool border = fl.Count != 2 || G[fl[0]] != G[fl[1]];
            if (!border) continue;
            int a = (int)(kv.Key >> 32), b = (int)(kv.Key & 0xFFFFFFFF);
            foreach (int f in fl)
            {
                double nx, ny, nz, area; Normal(P, faces[f], out nx, out ny, out nz, out area);
                if (area <= 0) continue;
                double ex = P[b][0] - P[a][0], ey = P[b][1] - P[a][1], ez = P[b][2] - P[a][2];
                double len2 = ex * ex + ey * ey + ez * ez; if (len2 <= 0) continue;
                double px = ey * nz - ez * ny, py = ez * nx - ex * nz, pz = ex * ny - ey * nx;
                double pl = Math.Sqrt(px * px + py * py + pz * pz); if (pl <= 0) continue;
                px /= pl; py /= pl; pz /= pl;
                var bq = Q.Plane(px, py, pz, -(px * P[a][0] + py * P[a][1] + pz * P[a][2]), borderWeight * len2);
                q[a] = q[a] + bq; q[b] = q[b] + bq;
            }
        }
        var ver = new int[nv]; var dead = new bool[nv];
        var heap = new Heap();
        Action<int, int> push = (a, b) =>
        {
            double x, y, z; double c = Cost(q[a] + q[b], P[a], P[b], out x, out y, out z);
            heap.Push(c, a, b, ver[a], ver[b]);
        };
        foreach (var kv in edgeFaces) push((int)(kv.Key >> 32), (int)(kv.Key & 0xFFFFFFFF));
        int faceCount = faces.Count;
        while (faceCount > target && heap.Count > 0)
        {
            double c; int a, b, va, vb; heap.Pop(out c, out a, out b, out va, out vb);
            if (dead[a] || dead[b] || ver[a] != va || ver[b] != vb) continue;
            double x, y, z; var qs = q[a] + q[b]; Cost(qs, P[a], P[b], out x, out y, out z);
            // refuse a collapse that turns a face over or squeezes it to a sliver
            if (Flips(P, faces, alive, vf[a], a, b, x, y, z) || Flips(P, faces, alive, vf[b], b, a, x, y, z))
                continue; // (dropped; it comes back when a neighbour's collapse pushes it again)
            // collapse b into a
            P[a] = new[] { x, y, z }; q[a] = qs; dead[b] = true;
            foreach (int f in vf[b])
            {
                if (!alive[f]) continue;
                var fc = faces[f];
                if (fc[0] == a || fc[1] == a || fc[2] == a) { alive[f] = false; faceCount--; continue; }
                for (int k = 0; k < 3; k++) if (fc[k] == b) fc[k] = a;
                vf[a].Add(f);
            }
            vf[a] = vf[a].Where(f => alive[f]).Distinct().ToList();
            ver[a]++;
            var nb = new HashSet<int>();
            foreach (int f in vf[a]) foreach (int k in faces[f]) if (k != a) nb.Add(k);
            foreach (int k in nb) push(a, k);
        }
        // compact
        var map = new int[nv]; for (int k = 0; k < nv; k++) map[k] = -1;
        outV = new List<double[]>(); outT = new List<int[]>(); outG = new List<int>();
        for (int f = 0; f < faces.Count; f++)
        {
            if (!alive[f]) continue;
            var t = new int[3];
            for (int k = 0; k < 3; k++) { int o = faces[f][k]; if (map[o] < 0) { map[o] = outV.Count; outV.Add(P[o]); } t[k] = map[o]; }
            if (t[0] == t[1] || t[1] == t[2] || t[0] == t[2]) continue;
            outT.Add(t); outG.Add(G[f]);
        }
    }

    static long Key(int a, int b) { if (a > b) { int t = a; a = b; b = t; } return ((long)a << 32) | (uint)b; }

    static void Normal(double[][] P, int[] t, out double nx, out double ny, out double nz, out double area)
    {
        var A = P[t[0]]; var B = P[t[1]]; var C = P[t[2]];
        double ux = B[0] - A[0], uy = B[1] - A[1], uz = B[2] - A[2], wx = C[0] - A[0], wy = C[1] - A[1], wz = C[2] - A[2];
        nx = uy * wz - uz * wy; ny = uz * wx - ux * wz; nz = ux * wy - uy * wx;
        double l = Math.Sqrt(nx * nx + ny * ny + nz * nz); area = l / 2;
        if (l > 0) { nx /= l; ny /= l; nz /= l; }
    }

    static double Cost(Q q, double[] pa, double[] pb, out double x, out double y, out double z)
    {
        double bx, by, bz;
        double best = double.MaxValue; x = y = z = 0;
        var cands = new List<double[]> { pa, pb, new[] { (pa[0] + pb[0]) / 2, (pa[1] + pb[1]) / 2, (pa[2] + pb[2]) / 2 } };
        if (q.Best(out bx, out by, out bz))
        {
            // only when it stays near the edge (far solutions are unstable)
            double ex = pb[0] - pa[0], ey = pb[1] - pa[1], ez = pb[2] - pa[2];
            double len = Math.Sqrt(ex * ex + ey * ey + ez * ez);
            double mx = (pa[0] + pb[0]) / 2, my = (pa[1] + pb[1]) / 2, mz = (pa[2] + pb[2]) / 2;
            if (Math.Sqrt((bx - mx) * (bx - mx) + (by - my) * (by - my) + (bz - mz) * (bz - mz)) < len * 2) cands.Add(new[] { bx, by, bz });
        }
        foreach (var p in cands) { double e = q.Err(p[0], p[1], p[2]); if (e < best) { best = e; x = p[0]; y = p[1]; z = p[2]; } }
        return best;
    }

    // would moving `moving` (collapsing with `other`) to (x, y, z) turn a face
    // round or make it a sliver? (faces with both are removed: skipped)
    static bool Flips(double[][] P, List<int[]> faces, bool[] alive, List<int> around, int moving, int other, double x, double y, double z)
    {
        foreach (int f in around)
        {
            if (!alive[f]) continue;
            var t = faces[f];
            if (t[0] == other || t[1] == other || t[2] == other) continue;
            double nx, ny, nz, area; Normal(P, t, out nx, out ny, out nz, out area);
            if (area <= 0) continue;
            var save = P[moving]; P[moving] = new[] { x, y, z };
            double mx, my, mz, area2; Normal(P, t, out mx, out my, out mz, out area2);
            // sliver: the new face has almost no area for its edges
            var A = P[t[0]]; var B = P[t[1]]; var C = P[t[2]];
            double e2 = D2(A, B) + D2(B, C) + D2(C, A);
            P[moving] = save;
            if (area2 <= 0 || nx * mx + ny * my + nz * mz < 0.3) return true;
            if (e2 > 0 && area2 / e2 < 0.02) return true;
        }
        return false;
    }
    static double D2(double[] a, double[] b) { return (a[0] - b[0]) * (a[0] - b[0]) + (a[1] - b[1]) * (a[1] - b[1]) + (a[2] - b[2]) * (a[2] - b[2]); }
}
