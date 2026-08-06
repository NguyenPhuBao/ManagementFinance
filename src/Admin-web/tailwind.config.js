/** @type {import('tailwindcss').Config} */
export default {
  darkMode: "class",
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      "colors": {
        "on-secondary-fixed-variant": "#3f465c",
        "on-background": "#0b1c30",
        "on-primary-fixed": "#002113",
        "on-tertiary-fixed": "#191c1e",
        "surface-container": "#e5eeff",
        "on-secondary-container": "#5c647a",
        "secondary": "#565e74",
        "on-tertiary-container": "#36393b",
        "primary-fixed-dim": "#4edea3",
        "on-error-container": "#93000a",
        "surface-bright": "#f8f9ff",
        "secondary-container": "#dae2fd",
        "inverse-on-surface": "#eaf1ff",
        "on-surface": "#0b1c30",
        "primary-container": "#10b981",
        "on-primary-fixed-variant": "#005236",
        "surface-dim": "#cbdbf5",
        "surface-tint": "#006c49",
        "on-error": "#ffffff",
        "error-container": "#ffdad6",
        "tertiary": "#5c5f61",
        "on-tertiary-fixed-variant": "#444749",
        "on-secondary": "#ffffff",
        "on-surface-variant": "#3c4a42",
        "on-tertiary": "#ffffff",
        "tertiary-fixed": "#e0e3e5",
        "tertiary-fixed-dim": "#c4c7c9",
        "on-primary-container": "#00422b",
        "tertiary-container": "#a0a3a5",
        "surface-container-low": "#eff4ff",
        "surface": "#f8f9ff",
        "error": "#ba1a1a",
        "secondary-fixed-dim": "#bec6e0",
        "outline-variant": "#bbcabf",
        "inverse-primary": "#4edea3",
        "secondary-fixed": "#dae2fd",
        "on-secondary-fixed": "#131b2e",
        "surface-variant": "#d3e4fe",
        "outline": "#6c7a71",
        "surface-container-highest": "#d3e4fe",
        "surface-container-high": "#dce9ff",
        "primary-fixed": "#6ffbbe",
        "background": "#f8f9ff",
        "primary": "#006c49",
        "on-primary": "#ffffff",
        "inverse-surface": "#213145",
        "surface-container-lowest": "#ffffff"
      },
      "borderRadius": {
        "DEFAULT": "0.125rem",
        "lg": "0.25rem",
        "xl": "0.5rem",
        "full": "0.75rem"
      },
      "spacing": {
        "card-gap": "24px",
        "stack-md": "16px",
        "stack-sm": "8px",
        "page-padding": "24px",
        "gutter": "24px",
        "stack-lg": "24px"
      },
      "fontFamily": {
        "headline-sm": ["Inter"],
        "headline-md": ["Inter"],
        "tabular-nums": ["Inter"],
        "body-lg": ["Inter"],
        "headline-md-mobile": ["Inter"],
        "display-lg": ["Inter"],
        "label-md": ["Inter"],
        "body-md": ["Inter"]
      },
      "fontSize": {
        "headline-sm": ["20px", { "lineHeight": "28px", "fontWeight": "600" }],
        "headline-md": ["24px", { "lineHeight": "32px", "letterSpacing": "-0.01em", "fontWeight": "600" }],
        "tabular-nums": ["14px", { "lineHeight": "20px", "fontWeight": "500" }],
        "body-lg": ["16px", { "lineHeight": "24px", "fontWeight": "400" }],
        "headline-md-mobile": ["20px", { "lineHeight": "28px", "fontWeight": "600" }],
        "display-lg": ["36px", { "lineHeight": "44px", "letterSpacing": "-0.02em", "fontWeight": "700" }],
        "label-md": ["12px", { "lineHeight": "16px", "letterSpacing": "0.05em", "fontWeight": "600" }],
        "body-md": ["14px", { "lineHeight": "20px", "fontWeight": "400" }]
      }
    }
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/container-queries')
  ],
}
