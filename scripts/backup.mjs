// YO‘L ILMI — haftalik zaxira nusxa: Supabase'dagi barcha ma'lumotlarni Excel faylga yig'ib, emailga yuboradi.
// GitHub Actions orqali ishga tushadi (.github/workflows/weekly-backup.yml).
// Kerakli maxfiy qiymatlar (GitHub → Settings → Secrets and variables → Actions):
//   SUPABASE_URL, SUPABASE_SERVICE_KEY, SMTP_USER, SMTP_PASS, MAIL_TO
import fs from 'node:fs';
import * as XLSX from 'xlsx';
import nodemailer from 'nodemailer';

const env = k => { const v = process.env[k]; if (!v) { console.error(`Maxfiy qiymat yo'q: ${k}`); process.exit(1); } return v.trim(); };
const URL0 = env('SUPABASE_URL').replace(/\/$/, ''), KEY = env('SUPABASE_SERVICE_KEY');

// Savollar matni va transliteratsiya sayt faylidan olinadi (bitta manba).
const html = fs.readFileSync(new URL('../index.html', import.meta.url), 'utf8');
const qline = html.match(/const QDATA = (\{.*\});\n/);
const QDATA = JSON.parse(qline[1]);
const trSrc = html.slice(html.indexOf('const TR = '), html.indexOf('/* ---------- Holat'));
const lat = new Function(trSrc + '; return lat;')();
const REG = QDATA.regions.map(lat);

const headers = KEY.startsWith('sb_') ? { apikey: KEY } : { apikey: KEY, Authorization: `Bearer ${KEY}` };
async function all(table, order){
  const out = [];
  for (let from = 0; ; from += 1000){
    const r = await fetch(`${URL0}/rest/v1/${table}?select=*&order=${order}&offset=${from}&limit=1000`, { headers });
    if (!r.ok){ if (r.status === 404) return out; throw new Error(`${table}: ${r.status} ${await r.text()}`); }
    const d = await r.json(); out.push(...d); if (d.length < 1000) break;
  }
  return out;
}

const [responses, starts, links, topics, scores, reports, audit] = await Promise.all([
  all('responses', 'date_bucket.asc'), all('survey_starts', 'id.asc'), all('access_links', 'created_at.asc'),
  all('research_topics', 'created_at.asc'), all('expert_scores', 'topic_id.asc'), all('road_reports', 'created_at.asc'), all('admin_audit', 'id.asc')
]);
const chan = t => (links.find(l => l.token === t) || {}).label || (t ? '—' : '');
const regName = i => i == null ? lat('Кўрсатилмаган') : REG[i];
function ans(q, a){
  if (a == null || a === '' || (Array.isArray(a) && !a.length)) return '';
  if (q.type === 'multi') return a.map(i => lat(q.options[i] ?? String(i))).join('; ');
  if (q.type === 'scale') return a;
  if (q.type === 'text') return String(a);
  return lat(q.options?.[a] ?? String(a));
}
const wb = XLSX.utils.book_new();
const add = (rows, name, w) => { const ws = XLSX.utils.aoa_to_sheet(rows); if (w) ws['!cols'] = w.map(x => ({ wch: x })); XLSX.utils.book_append_sheet(wb, ws, name.slice(0, 31)); };
for (const [aud, key, name] of [['citizen', 'citizen', 'Aholi javoblari'], ['expert', 'experts', 'Mutaxassis javoblari']]){
  const Q = QDATA[key], list = responses.filter(r => r.audience === aud);
  add([['ID', 'Sana', 'Versiya', 'Hudud', 'Kanal', ...Q.map((q, i) => `${aud === 'citizen' ? 'A' : 'M'}-${String(i + 1).padStart(2, '0')}. ${lat(q.q)}`)],
    ...list.map(r => [String(r.id).slice(0, 8), r.date_bucket, r.version, regName(r.region), chan(r.link_token), ...Q.map(q => ans(q, (r.answers || {})[q.id]))])], name, [10, 11, 8, 22, 18, ...Q.map(() => 28)]);
}
add([['Kanal', 'Auditoriya', 'Faol', 'Boshlagan', 'Yuborgan', 'Yaratilgan'], ...links.map(l => [l.label, l.audience || 'ikkalasi', l.active ? 'ha' : "yo'q", starts.filter(s => s.link_token === l.token).length, responses.filter(r => r.link_token === l.token).length, (l.created_at || '').slice(0, 10)])], 'Kanallar', [30, 12, 8, 10, 10, 12]);
add([["Yo'nalish", 'Holat', 'Asos', 'Ekspertlar', 'Dolzarblik', 'Imkoniyat', 'Samara'], ...topics.map(t => { const s = scores.filter(x => x.topic_id === t.id); const m = k => s.length ? +(s.reduce((a, x) => a + x[k], 0) / s.length).toFixed(2) : ''; return [t.name, t.status, t.evidence, s.length, m('relevance'), m('feasibility'), m('impact')]; })], 'Tadqiqot portfeli', [40, 12, 50, 10, 10, 10, 10]);
add([['ID', 'Sana', 'Hudud', 'Tur', 'Joy', 'Tavsif', 'Lat', 'Lng', 'Rasmlar', 'Aloqa', 'Holat'], ...reports.map(r => [String(r.id).slice(0, 8).toUpperCase(), (r.created_at || '').slice(0, 10), regName(r.region), lat(r.category), r.place, r.description, r.lat, r.lng, (r.photos || []).length, r.contact || '', r.status])], 'Muammo xabarlari', [10, 11, 22, 22, 30, 40, 9, 9, 8, 20, 10]);
add([['Vaqt', 'Admin', 'Hodisa', 'Izoh'], ...audit.map(a => [a.ts, a.admin_email, a.event, a.ref])], 'Audit', [22, 28, 18, 40]);

const today = new Date().toISOString().slice(0, 10);
const file = `yol-ilmi-zaxira-${today}.xlsx`;
const buf = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' });
fs.mkdirSync('backup', { recursive: true }); fs.writeFileSync(`backup/${file}`, buf);

const cit = responses.filter(r => r.audience === 'citizen').length, exp = responses.length - cit;
const tx = nodemailer.createTransport({ host: process.env.SMTP_HOST || 'smtp.gmail.com', port: +(process.env.SMTP_PORT || 465), secure: true, auth: { user: env('SMTP_USER'), pass: env('SMTP_PASS') } });
await tx.sendMail({
  from: `YO‘L ILMI <${env('SMTP_USER')}>`, to: env('MAIL_TO'),
  subject: `YO‘L ILMI: haftalik zaxira nusxa, ${today}`,
  text: `Assalomu alaykum!\n\nHaftalik zaxira nusxa ilova qilindi.\n\nAholi javoblari: ${cit}\nMutaxassis javoblari: ${exp}\nMuammo xabarlari: ${reports.length}\nTaklif havolalari: ${links.length}\n\nFaylni xavfsiz joyda saqlang: unda muammo xabarlaridagi aloqa ma'lumotlari bor.\n\nYO‘L ILMI platformasi`,
  attachments: [{ filename: file, content: buf }]
});
console.log(`Yuborildi: ${file} (${cit} + ${exp} javob, ${reports.length} xabar)`);
