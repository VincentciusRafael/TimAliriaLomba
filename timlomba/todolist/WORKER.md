# Cloudflare Worker — alteco-writer

Write proxy untuk Kelola Alteco. Semua perubahan data dari browser dikirim ke Worker ini, bukan langsung ke GitHub Gist API. Worker juga menjadi proxy untuk pengiriman push notification OneSignal.

---

## Secrets yang Dibutuhkan

Tambahkan di: **Cloudflare Dashboard → Workers & Pages → `alteco-writer` → Settings → Variables and Secrets → Add**

| Secret | Nilai | Keterangan |
|--------|-------|-----------|
| `GIST_ID` | Gist ID | ID dari Gist `alteco-data.json` |
| `GIST_PAT` | GitHub PAT (scope: `gist`) | Untuk baca & tulis Gist |
| `ONESIGNAL_APP_ID` | OneSignal App ID | Untuk kirim push notification |
| `ONESIGNAL_REST_KEY` | OneSignal REST API Key | Untuk otorisasi OneSignal API |

---

## Routes

| Method | Path | Fungsi |
|--------|------|--------|
| `POST /` | Default | Read-merge-write ke Gist (simpan data) |
| `POST /notify` | Notify | Forward push notification ke OneSignal |
| `OPTIONS *` | CORS preflight | Respons CORS untuk browser |

---

## Cara Deploy

1. Buka [workers.cloudflare.com](https://workers.cloudflare.com) → login
2. **Workers & Pages → Create application → Create Worker**
3. Beri nama: `alteco-writer` → **Deploy**
4. Klik **Edit code** → hapus isi default → paste kode di bawah
5. Ganti `https://dionisiusnp.github.io` dengan domain GitHub Pages-mu (baris `Access-Control-Allow-Origin`)
6. Klik **Deploy**
7. Tambahkan 4 secrets (lihat tabel di atas)
8. Salin URL Worker (format: `https://alteco-writer.<subdomain>.workers.dev`)
9. Paste ke `WORKER_URL` di `todolist/index.html` baris ~598

---

## Kode Worker

```javascript
export default {
  async fetch(request, env) {
    const cors = {
      'Access-Control-Allow-Origin': 'https://dionisiusnp.github.io',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };
    if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
    if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 });

    const url = new URL(request.url);
    const ghHdr = {
      'Authorization': `Bearer ${env.GIST_PAT}`,
      'Content-Type': 'application/json',
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'alteco-worker',
    };

    try {
      if (url.pathname === '/notify') {
        const payload = await request.json();
        const r = await fetch('https://onesignal.com/api/v1/notifications', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Authorization': `Key ${env.ONESIGNAL_REST_KEY}` },
          body: JSON.stringify({ ...payload, app_id: env.ONESIGNAL_APP_ID })
        });
        const result = await r.json();
        if (!r.ok) return new Response(JSON.stringify({ error: result }), { status: r.status, headers: { ...cors, 'Content-Type': 'application/json' } });
        return new Response(JSON.stringify({ ok: true, id: result.id }), { headers: { ...cors, 'Content-Type': 'application/json' } });
      }

      // Default: read-merge-write to Gist
      const browserDb = await request.json();

      const getResp = await fetch(`https://api.github.com/gists/${env.GIST_ID}`, { headers: ghHdr });
      const gistData = await getResp.json();
      const currentContent = gistData.files?.['alteco-data.json']?.content;
      const gistDb = currentContent ? JSON.parse(currentContent) : browserDb;

      function mergeArr(gistArr = [], browserArr = []) {
        const map = new Map();
        for (const item of gistArr) map.set(item.id, item);
        for (const item of browserArr) {
          const ex = map.get(item.id);
          if (!ex || (item.updatedAt || 0) >= (ex.updatedAt || 0)) map.set(item.id, item);
        }
        // Prefer browser order (preserves reordering); gist-only items appended at end
        const bIds = new Set(browserArr.map(x => x.id));
        return [
          ...browserArr.map(x => map.get(x.id)).filter(Boolean),
          ...[...map.values()].filter(x => !bIds.has(x.id)),
        ];
      }

      function mergeTasks(gt = [], bt = []) {
        const map = new Map();
        for (const t of gt) map.set(t.id, t);
        for (const t of bt) {
          const ex = map.get(t.id);
          if (!ex || (t.updatedAt || 0) >= (ex.updatedAt || 0)) map.set(t.id, t);
        }
        return [...map.values()];
      }

      function mergeMembers(gm = [], bm = []) {
        const gMap = new Map(gm.map(m => [m.id, m]));
        const bMap = new Map(bm.map(m => [m.id, m]));
        const ids = new Set([...gMap.keys(), ...bMap.keys()]);
        return [...ids].map(id => {
          const g = gMap.get(id), b = bMap.get(id);
          if (!g) return b;
          if (!b) return g;
          return { ...g, ...b, tasks: mergeTasks(g.tasks || [], b.tasks || []) };
        });
      }

      function mergeProjects(gp = [], bp = []) {
        const gMap = new Map(gp.map(p => [p.id, p]));
        const bMap = new Map(bp.map(p => [p.id, p]));
        const ids = new Set([...gMap.keys(), ...bMap.keys()]);
        return [...ids].map(id => {
          const g = gMap.get(id), b = bMap.get(id);
          if (!g) return b;
          if (!b) return g;
          return { ...g, ...b, members: mergeMembers(g.members || [], b.members || []) };
        });
      }

      function mergeBroadcastItems(gi = [], bi = []) {
        const map = new Map();
        for (const t of gi) map.set(t.id, t);
        for (const t of bi) {
          const ex = map.get(t.id);
          if (!ex || (t.updatedAt || 0) >= (ex.updatedAt || 0)) map.set(t.id, t);
        }
        return [...map.values()];
      }

      function mergeBroadcastKondisi(gk = [], bk = []) {
        const gMap = new Map(gk.map(k => [k.id, k]));
        const bMap = new Map(bk.map(k => [k.id, k]));
        const ids = new Set([...gMap.keys(), ...bMap.keys()]);
        return [...ids].map(id => {
          const g = gMap.get(id), b = bMap.get(id);
          if (!g) return b;
          if (!b) return g;
          return { ...g, ...b, items: mergeBroadcastItems(g.items || [], b.items || []) };
        });
      }

      function mergeBroadcastProduk(gp = [], bp = []) {
        const gMap = new Map(gp.map(p => [p.id, p]));
        const bMap = new Map(bp.map(p => [p.id, p]));
        const ids = new Set([...gMap.keys(), ...bMap.keys()]);
        return [...ids].map(id => {
          const g = gMap.get(id), b = bMap.get(id);
          if (!g) return b;
          if (!b) return g;
          return { ...g, ...b, kondisi: mergeBroadcastKondisi(g.kondisi || [], b.kondisi || []) };
        });
      }

      function mergeLombaIde(gi = [], bi = []) {
        const map = new Map();
        for (const t of gi) map.set(t.id, t);
        for (const t of bi) {
          const ex = map.get(t.id);
          if (!ex || (t.updatedAt || 0) >= (ex.updatedAt || 0)) map.set(t.id, t);
        }
        return [...map.values()];
      }

      function mergeLombas(gl = [], bl = []) {
        const gMap = new Map(gl.map(l => [l.id, l]));
        const bMap = new Map(bl.map(l => [l.id, l]));
        const ids = new Set([...gMap.keys(), ...bMap.keys()]);
        return [...ids].map(id => {
          const g = gMap.get(id), b = bMap.get(id);
          if (!g) return b;
          if (!b) return g;
          return { ...g, ...b, ide: mergeLombaIde(g.ide || [], b.ide || []) };
        });
      }

      // Daftar tim master (template) — merge per tim + per anggota
      function mergeTimLomba(gt = [], bt = []) {
        const gMap = new Map(gt.map(t => [t.id, t]));
        const bMap = new Map(bt.map(t => [t.id, t]));
        const ids = new Set([...gMap.keys(), ...bMap.keys()]);
        return [...ids].map(id => {
          const g = gMap.get(id), b = bMap.get(id);
          if (!g) return b;
          if (!b) return g;
          const newer = (b.updatedAt || 0) >= (g.updatedAt || 0) ? b : g;
          return { ...g, ...newer, members: mergeMembers(g.members || [], b.members || []) };
        });
      }

      function mergeRegulasi(gr, br) {
        const base = { visi: '', misi: '', syaratAnggota: [], syaratTim: [], keuntungan: [], sanksi: [] };
        gr = { ...base, ...gr };
        br = { ...base, ...br };
        return {
          visi: br.visi,
          misi: br.misi,
          syaratAnggota: mergeArr(gr.syaratAnggota, br.syaratAnggota),
          syaratTim:     mergeArr(gr.syaratTim,     br.syaratTim),
          keuntungan:    mergeArr(gr.keuntungan,    br.keuntungan),
          sanksi:        mergeArr(gr.sanksi,         br.sanksi),
        };
      }

      const merged = {
        ...gistDb,
        ...browserDb,
        kelompoks:  mergeArr(gistDb.kelompoks  || [], browserDb.kelompoks  || []),
        members:    mergeArr(gistDb.members    || [], browserDb.members    || []),
        tasks:      mergeArr(gistDb.tasks      || [], browserDb.tasks      || []),
        assets:     mergeArr(gistDb.assets     || [], browserDb.assets     || []),
        events:     mergeArr(gistDb.events     || [], browserDb.events     || []),
        cultures:   mergeArr(gistDb.cultures   || [], browserDb.cultures   || []),
        notulensi:       mergeArr(gistDb.notulensi      || [], browserDb.notulensi      || []),
        notulensiTopik:  mergeArr(gistDb.notulensiTopik || [], browserDb.notulensiTopik || []),
        broadcastProduk: mergeBroadcastProduk(gistDb.broadcastProduk || [], browserDb.broadcastProduk || []),
        lombas:     mergeLombas(gistDb.lombas || [], browserDb.lombas || []),
        timLomba:   mergeTimLomba(gistDb.timLomba || [], browserDb.timLomba || []),
        jenisLomba: mergeArr(gistDb.jenisLomba || [], browserDb.jenisLomba || []),
        hallOfFame: mergeArr(gistDb.hallOfFame || [], browserDb.hallOfFame || []),
        bahanPers:  mergeArr(gistDb.bahanPers || [], browserDb.bahanPers || []),
        ruangan:    mergeArr(gistDb.ruangan   || [], browserDb.ruangan   || []),
        projects:   mergeProjects(gistDb.projects || [], browserDb.projects || []),
        regulasi:   mergeRegulasi(gistDb.regulasi || gistDb.komunitas || {}, browserDb.regulasi || {}),
        settings:   browserDb.settings,
        orgName:    browserDb.orgName,
      };

      const r = await fetch(`https://api.github.com/gists/${env.GIST_ID}`, {
        method: 'PATCH', headers: ghHdr,
        body: JSON.stringify({ files: { 'alteco-data.json': { content: JSON.stringify(merged) } } })
      });
      const result = await r.json();
      if (!r.ok) return new Response(JSON.stringify({ error: result.message }), { status: r.status, headers: { ...cors, 'Content-Type': 'application/json' } });
      return new Response(JSON.stringify({ ok: true }), { headers: { ...cors, 'Content-Type': 'application/json' } });

    } catch (e) {
      return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: cors });
    }
  }
};
```

---

## Merge Strategy

Worker tidak langsung timpa Gist — melakukan **read-merge-write**:

| Tipe data | Strategi merge |
|-----------|---------------|
| Array top-level (`tasks`, `members`, `kelompoks`, `assets`, `events`, `cultures`, `notulensi`, `notulensiTopik`, `bahanPers`, `ruangan`) | Merge by `id`, item dengan `updatedAt` lebih baru menang |
| `projects[].members[].tasks[]` | Deep merge 3 level — per-task `updatedAt` menang |
| `timLomba[]` (daftar tim master) | Merge by `id`, per tim `updatedAt` menang |
| `timLomba[].members[]` | Deep merge 2 level — per-anggota `updatedAt` menang |
| `jenisLomba[]` (daftar jenis master's) | Merge by `id`, item dengan `updatedAt` lebih baru menang |
| `hallOfFame[]` (entri hall of fame) | Merge by `id`, item dengan `updatedAt` lebih baru menang |
| `broadcastProduk[].kondisi[].items[]` | Deep merge 3 level — per-item `updatedAt` menang |
| `regulasi.syaratAnggota` / `regulasi.syaratTim` / `regulasi.keuntungan` / `regulasi.sanksi` | Merge by `id` + `updatedAt` |
| `settings`, `orgName`, `visi`, `misi` | Browser always wins (last write) |

Ini mencegah data hilang saat dua user edit data berbeda secara bersamaan (race condition).

### Soft Delete (Tombstone)

Semua operasi hapus di browser **tidak** membuang item dari array — melainkan menandai `deleted: true` + memperbarui `updatedAt`. Worker tidak perlu perubahan: item bertanda `deleted` dengan `updatedAt` lebih baru akan menang di `mergeArr` dan masuk ke Gist. Render di browser sudah memfilter item dengan `deleted: true`.

---

## Update Worker

Jika ada perubahan kode Worker di masa depan:

1. Cloudflare → `alteco-writer` → **Edit code**
2. Replace seluruh kode → **Deploy**
3. Secrets tidak perlu diubah kecuali ada rotasi token
