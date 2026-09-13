import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import ar from './resources/ar';
import fr from './resources/fr';
import en from './resources/en';

export const RTL_LANGUAGES = new Set(['ar']);

export function isRtl(language: string): boolean {
  return RTL_LANGUAGES.has(language);
}

export function initI18n(defaultLanguage: 'ar' | 'fr' | 'en' = 'ar') {
  if (!i18n.isInitialized) {
    i18n.use(initReactI18next).init({
      resources: {
        ar: { translation: ar },
        fr: { translation: fr },
        en: { translation: en },
      },
      lng: defaultLanguage,
      fallbackLng: 'ar',
      interpolation: { escapeValue: false },
    });
  }
  applyDirection(defaultLanguage);
  return i18n;
}

// Keeps <html dir="rtl|ltr"> in sync with the active language, so every
// browser-native layout behavior (scrollbars, form controls, CSS logical
// properties) follows automatically — this is what Section 38's "correct RTL
// tables/forms/navigation" actually resolves to in practice, not a manual
// left/right flip per component.
export function applyDirection(language: string) {
  const dir = isRtl(language) ? 'rtl' : 'ltr';
  document.documentElement.dir = dir;
  document.documentElement.lang = language;
}

export function changeLanguage(language: 'ar' | 'fr' | 'en') {
  i18n.changeLanguage(language);
  applyDirection(language);
}

export { i18n };
