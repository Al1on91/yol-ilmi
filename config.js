// YO‘L ILMI — ulanish sozlamalari.
// Supabase → Project Settings → API (yoki "Connect") bo'limidan ikki qiymatni ko'chirib qo'ying.
// Bu "anon / publishable" kalit ochiq bo'lishi uchun mo'ljallangan: himoyani bazadagi RLS qoidalari ta'minlaydi.
// HECH QACHON bu yerga "service_role" / "secret" kalitni qo'ymang.
window.YOL_ILMI_CONFIG = {
  SUPABASE_URL: 'https://XXXX.supabase.co',
  SUPABASE_ANON_KEY: 'XXXX',
  // Ixtiyoriy: sayt manzili (QR-kodlar uchun). Bo'sh qolsa, joriy manzil olinadi.
  SITE_URL: ''
};
