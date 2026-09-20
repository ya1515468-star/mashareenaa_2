create policy "platform_ui_runtime_public_read"
on public.platform_ui_runtime
for select
to anon, authenticated
using (id = true);

update public.platform_ui_runtime
set
  version = version + 1,
  config = jsonb_set(
    config,
    '{auth}',
    $cfg$
    {
      "mode": "tailor_atelier_v1",
      "brand_tagline_ar": "كل غرزة تصنع فرصة جديدة",
      "login_title_ar": "ادخل إلى مشغلك الرقمي",
      "login_subtitle_ar": "خدمات الخياطة والألبسة والتجارة في مساحة واحدة احترافية.",
      "login_button_ar": "دخول إلى المشغل",
      "register_title_ar": "أنشئ حسابك في مشاريعنا",
      "register_subtitle_ar": "ابدأ ملفك المهني وابنِ حضورك داخل منظومة الألبسة والخياطة.",
      "register_button_ar": "ابدأ مشواري",
      "switch_to_register_ar": "إنشاء حساب جديد",
      "switch_to_login_ar": "لديك حساب؟ تسجيل الدخول",
      "pattern_opacity": 0.11,
      "features": [
        {"icon": "content_cut", "label_ar": "الخياطة"},
        {"icon": "checkroom", "label_ar": "الألبسة"},
        {"icon": "handshake", "label_ar": "التجارة"},
        {"icon": "design", "label_ar": "التفصيل"}
      ],
      "palette": {
        "name_ar": "مشغل مشاريعنا",
        "accent": "#D4AF37",
        "accent_muted": "#B8944A",
        "accent_bright": "#F1D07A",
        "secondary": "#7A1F3D",
        "secondary_bright": "#A23A5C",
        "background": "#0A0A0C",
        "surface": "#15141A",
        "surface_elevated": "#1E1C24",
        "surface_highlight": "#28242E",
        "text_primary": "#F5F1E8",
        "text_secondary": "#AFA79A",
        "text_muted": "#6E6A63",
        "divider": "#2A2830",
        "error": "#CF6679",
        "success": "#3FA377",
        "warning": "#E0A96D"
      }
    }
    $cfg$::jsonb,
    true
  ),
  updated_at = now()
where id = true;
