# YO‘L ILMI: saytni ishga tushirish yo‘riqnomasi

Sayt ikki qismdan iborat:

- **Sayt fayllari** (`index.html`, `config.js`). Ularni GitHub Pages yoki Vercel'ga joylaysiz, xuddi `yol-laboratoriyasi` saytingiz kabi. Saytga istalgan odam akkauntsiz kiradi.
- **Ma'lumotlar bazasi** (Supabase, bepul). Javoblar shu yerga tushadi. Javoblarni faqat siz qo'shgan admin ko'radi.

Taxminan 20–30 daqiqa vaqt oladi.

---

## 1-qadam. Supabase loyihasini yaratish

1. https://supabase.com saytiga kiring va **Start your project** tugmasini bosing. GitHub akkauntingiz bilan kirishingiz mumkin.
2. **New project** tugmasini bosing:
   - Name: `yol-ilmi`
   - Database Password: kuchli parol o'ylab toping va saqlab qo'ying
   - Region: **Central EU (Frankfurt)**, O'zbekistonga yaqin hudud
3. **Create new project** tugmasini bosing va 1–2 daqiqa kuting.

## 2-qadam. Bazani yaratish (bir marta)

1. Chap menyudan **SQL Editor**ni tanlang va **New query** tugmasini bosing.
2. `supabase/schema.sql` faylini oching, ichidagi hamma matnni nusxalab, shu oynaga joylang.
3. **Run** tugmasini bosing. Pastda `Success. No rows returned` yozuvi chiqishi kerak.

## 3-qadam. Begona ro'yxatdan o'tishni yopish

1. **Authentication → Sign In / Providers** bo'limiga kiring.
2. **Allow new users to sign up** sozlamasini **o'chiring** va **Save** tugmasini bosing.

Respondentlarga akkaunt kerak emas. Bu sozlama faqat admin kirishiga tegishli.

## 4-qadam. Admin yaratish

1. **Authentication → Users → Add user → Create new user** yo'lidan boring.
   - Email: o'zingizning emailingiz
   - Password: kuchli parol
   - **Auto Confirm User** belgisini qo'ying
2. **SQL Editor → New query** oynasiga quyidagini yozing. Emailni o'zingiznikiga almashtiring va **Run** tugmasini bosing:

```sql
insert into public.admin_users (user_id, role)
select id, 'superadmin' from auth.users where email = 'sizning@email.uz'
on conflict (user_id) do update set active = true, role = excluded.role;
```

Yana admin qo'shmoqchi bo'lsangiz, shu ikki amalni har bir hamkasb uchun takrorlang (rol sifatida masalan `'analyst'` yozasiz). Adminni o'chirish uchun:
`update public.admin_users set active = false where user_id = (select id from auth.users where email = '...');`

## 5-qadam. Saytni bazaga ulash

1. Supabase'da **Project Settings → API Keys** bo'limiga kiring (yoki yuqoridagi **Connect** tugmasini bosing).
2. Ikki qiymatni ko'chirib oling:
   - **Project URL**, masalan `https://abcd1234.supabase.co`
   - **anon public** (yoki **Publishable**) kalit
3. `config.js` faylini Bloknot yoki VS Code'da oching va `XXXX` yozilgan joylarni shu qiymatlarga almashtiring:

```js
window.YOL_ILMI_CONFIG = {
  SUPABASE_URL: 'https://abcd1234.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOi...',
  SITE_URL: ''
};
```

> ⚠️ **service_role** yoki **secret** kalitni hech qachon bu faylga qo'ymang. Sayt uchun faqat **anon / publishable** kalit kerak. U ochiq turishi uchun mo'ljallangan, himoyani bazadagi qoidalar ta'minlaydi.

## 6-qadam. Saytni joylash

### Variant A: GitHub Pages (`yol-laboratoriyasi` kabi)

1. GitHub'da **New repository** tugmasini bosing, nomiga `yol-ilmi` deb yozing, **Public** turini tanlang va **Create repository** tugmasini bosing.
2. **uploading an existing file** havolasini bosing va `index.html` hamda `config.js` fayllarini tortib tashlang. So'ng **Commit changes** tugmasini bosing.
3. **Settings → Pages** bo'limida Source: **Deploy from a branch**, Branch: **main** va **/(root)** ni tanlab, **Save** tugmasini bosing.
4. 1–2 daqiqadan keyin sayt shu manzilda ochiladi: `https://al1on91.github.io/yol-ilmi/`

### Variant B: Vercel (`nega-nega2` kabi)

1. vercel.com saytida **Add New → Project** ni tanlang, A variantdagi GitHub repozitoriyani import qiling va **Deploy** tugmasini bosing.

## 7-qadam. Tekshirish

1. Telefonda **inkognito** oynada saytni oching, so'rovni to'ldirib yuboring. "Javoblar qabul qilindi" yozuvi chiqishi kerak.
2. Saytning pastki qismidagi **Admin kirishi** havolasini bosing (yoki manzil oxiriga `#admin` qo'shing) va 4-qadamdagi email va parol bilan kiring.
3. **Monitoring** bo'limida javob ko'rinadi.

## 8-qadam. Taklif havolalarini yaratish (majburiy)

Saytga faqat siz yaratgan havola orqali kiriladi. Havolasiz kirgan odam "Kirish faqat taklif havolasi orqali" degan yozuvni ko'radi.

1. Admin → **Taklif havolalari** bo'limiga kiring.
2. Kanal nomini yozing (masalan, "Samarqand, Telegram") va qaysi so'rov uchun ekanini tanlang (ikkala so'rov, faqat aholi yoki faqat mutaxassislar).
3. **Havola yaratish** tugmasini bosing. Havolani nusxalang yoki QR-kodni PNG qilib yuklab oling va tarqating.
4. Havolani to'xtatish uchun **Havolani o'chirish** tugmasini bosing. Shu havola orqali boshqa javob qabul qilinmaydi.

Har bir havola orqali nechta javob kelgani ko'rinadi, CSV eksportda esa "Kanal" ustuni chiqadi.

## Kundalik ish

- **Natijalarni e'lon qilish:** shu bo'limdagi **Natijalarni e'lon qilish** tugmasini bosing. Ommaviy sahifaga faqat agregat raqamlar chiqadi, n<10 guruhlar yashiriladi.
- **Excel uchun eksport:** CSV tugmalarini bosing.
- **So'rovni yopish yoki savol matnini tahrirlash:** **So'rov sozlamalari** bo'limida qilinadi.

## Muhim eslatmalar

- **Bepul tarif:** Supabase bepul loyihani 7 kun davomida hech qanday faollik bo'lmasa to'xtatib qo'yadi. So'rov faol ketayotganda bu muammo emas. Agar to'xtab qolsa, Supabase panelida **Restore** tugmasini bosasiz. Ma'lumotlarni muntazam CSV'ga eksport qilib turing.
- **Anonimlik:** bazaga IP, vaqt (soat) va qurilma ma'lumoti yozilmaydi, sana faqat kun aniqligida saqlanadi. Lekin Supabase va GitHub/Vercel serverlari o'zlarining texnik jurnallarida IP-manzilni vaqtincha saqlashi mumkin. TZ'ning 11-bandiga ko'ra respublika miqyosida ishga tushirishdan oldin buni huquqiy va axborot xavfsizligi bo'yicha ko'rib chiqing.
- **Bot va takroriy javoblar:** sayt oddiy bot-tuzoq va seans cheklovidan foydalanadi. "Bir shaxs, bir javob" qoidasini qat'iy ta'minlab bo'lmaydi (TZ'da ham shunday deyilgan).
- **Ma'lumotlarni sinov paytida tozalash:** Supabase'da **Table Editor → responses** jadvaliga kiring, qatorlarni belgilab, **Delete** tugmasini bosing.
