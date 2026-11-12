// Builds the IEEE-style (two-column, Times 10 pt) draft paper as .docx, in English or Vietnamese.
// Run:  NODE_PATH=<folder containing node_modules/docx 9.x> node build_paper.js [en|vi]
// Text lives in content_en.js / content_vi.js; this file holds only the layout helpers.
// Output: NCKH_DuBaoXacSuatVuotNganSach_EN.docx (en) or NCKH_DuBaoXacSuatVuotNganSach_VI.docx (vi). Figures come from make_figures.py.
'use strict';
const fs = require('fs');
const path = require('path');
const d = require('docx');
const {
  Document, Packer, Paragraph, TextRun, AlignmentType, TabStopType, SectionType, Header,
  PageNumber, ImageRun, Table, TableRow, TableCell, WidthType, BorderStyle, FootnoteReferenceRun,
  Math: OMath, MathRun, MathSubScript, MathSuperScript, MathSubSuperScript, MathFraction, MathRadical,
  MathSum, VerticalAlign, LineRuleType,
} = d;
const JSZip = require('jszip');

const HERE = __dirname;
const r = String.raw;
const COL = 5040; // column width in twips (3.5 in)
const FONT = 'Times New Roman';
const LANG = process.argv[2] || 'en';
if (!['en', 'vi'].includes(LANG)) throw new Error('language must be en or vi');
const L = LANG === 'vi'
  ? { fig: 'Hình', table: 'BẢNG', out: 'NCKH_DuBaoXacSuatVuotNganSach_VI.docx', figSuffix: '_vi' }
  : { fig: 'Fig.', table: 'TABLE', out: 'NCKH_DuBaoXacSuatVuotNganSach_EN.docx', figSuffix: '' };

// ---------------------------------------------------------------- references
// Only cited keys may stay (the build throws on an uncited reference). Pruned 2026-11-10 for the rewritten paper.
// DOIs checked against api.crossref.org on 2026-11-10 (title, venue, year, volume, pages all matched).
// On the user's request (2026-11-10) the printed list carries no DOIs, to keep it short; IEEE does not require
// them. The checked DOIs are in git history (commit abfbf418) if they are wanted back.
// 2026-11-12, supervisor's review ("at most 15 references, the newest, check that each is cited correctly"):
// 17 -> 15. Replaced by newer work: Thaler 1999 -> Zhang & Sussman 2018; Karlan 2016 -> Medina 2021 + Levi 2026;
// Roberts 1959 + Tashman 2000 -> Petropoulos 2022; Koenker & Bassett 1978 -> Handbook of Quantile Regression 2017;
// Taylor 2007 -> M5 uncertainty 2022; Gneiting 2007 + Naeini 2015 -> Dimitriadis 2021; new: Assefa 2020.
// Dropped without replacement: Likert 1932, Efron 1993. Kept as the exact source of a step: RiskMetrics (M2 update),
// Brier (the score), Chernozhukov (sorting quantiles). Every entry checked on api.crossref.org on 2026-11-12 (title,
// authors, venue, volume, issue, pages, year), except RiskMetrics (technical report, no DOI) and the Claude entry.
// DOIs (not printed): zhang 10.1002/cfp2.1011 · medina 10.1093/rfs/hhaa108 · levi 10.1017/s0022109026102749 ·
// petropoulos 10.1016/j.ijforecast.2021.11.001 · handbookQR 10.1201/9781315120256 · makridakis
// 10.1016/j.ijforecast.2021.10.009 · chernozhukov 10.3982/ECTA7880 · dimitriadis 10.1073/pnas.2016191118 ·
// padhi 10.1109/ICASSP39728.2021.9414142 · altman 10.1145/3490354.3494378 · assefa 10.1145/3383455.3422554.
const REFS = {
  zhang: 'C. Y. Zhang and A. B. Sussman, “Perspectives on mental accounting: An exploration of budgeting and investing,” *Financial Planning Rev.*, vol. 1, no. 1–2, Art. no. e1011, 2018.',
  medina: 'P. C. Medina, “Side effects of nudging: Evidence from a randomized intervention in the credit card market,” *Rev. Financial Stud.*, vol. 34, no. 5, pp. 2580–2607, 2021.',
  levi: 'Y. Levi, “Personal financial information presentation and consumer spending,” *J. Financial Quant. Anal.*, vol. 61, no. 5, pp. 2455–2480, 2026.',
  petropoulos: 'F. Petropoulos *et al.*, “Forecasting: Theory and practice,” *Int. J. Forecast.*, vol. 38, no. 3, pp. 705–871, 2022.',
  riskmetrics: 'J. P. Morgan/Reuters, *RiskMetrics—Technical Document*, 4th ed., New York, NY, USA, 1996.',
  handbookQR: 'R. Koenker, V. Chernozhukov, X. He, and L. Peng, Eds., *Handbook of Quantile Regression*. Boca Raton, FL, USA: Chapman & Hall/CRC, 2017.',
  makridakis: 'S. Makridakis *et al.*, “The M5 uncertainty competition: Results, findings and conclusions,” *Int. J. Forecast.*, vol. 38, no. 4, pp. 1365–1385, 2022.',
  chernozhukov: 'V. Chernozhukov, I. Fernández-Val, and A. Galichon, “Quantile and probability curves without crossing,” *Econometrica*, vol. 78, no. 3, pp. 1093–1125, 2010.',
  brier: 'G. W. Brier, “Verification of forecasts expressed in terms of probability,” *Monthly Weather Rev.*, vol. 78, no. 1, pp. 1–3, 1950.',
  dimitriadis: 'T. Dimitriadis, T. Gneiting, and A. I. Jordan, “Stable reliability diagrams for probabilistic classifiers,” *Proc. Nat. Acad. Sci. USA*, vol. 118, no. 8, Art. no. e2016191118, 2021.',
  padhi: 'I. Padhi *et al.*, “Tabular transformers for modeling multivariate time series,” in *Proc. IEEE Int. Conf. Acoust., Speech Signal Process. (ICASSP)*, Toronto, ON, Canada, 2021, pp. 3565–3569.',
  altman: 'E. Altman, “Synthesizing credit card transactions,” in *Proc. 2nd ACM Int. Conf. AI in Finance (ICAIF)*, 2021, pp. 1–9.',
  assefa: 'S. A. Assefa, D. Dervovic, M. Mahfouz, R. E. Tillman, P. Reddy, and M. Veloso, “Generating synthetic data in finance: Opportunities, challenges and pitfalls,” in *Proc. 1st ACM Int. Conf. AI in Finance (ICAIF)*, 2020, pp. 1–8.',
  iso: 'ISO 18245:2023, *Retail Financial Services—Merchant Category Codes*, 2nd ed. Geneva, Switzerland: International Organization for Standardization, 2023.',
  claude: 'Anthropic, “Claude Opus 5.5,” 2026. [Online]. Available: https://www.anthropic.com. Accessed: Nov. 12, 2026.',
};
const citeOrder = [];
function cite(keys) {
  return keys.split(',').map((k) => {
    k = k.trim();
    if (!REFS[k]) throw new Error('unknown reference ' + k);
    if (!citeOrder.includes(k)) citeOrder.push(k);
    return '[' + (citeOrder.indexOf(k) + 1) + ']';
  }).join(', ');
}

// ---------------------------------------------------------------- mini-LaTeX → OMML
const SYM = {
  le: '≤', ge: '≥', cdot: '·', mid: '∣', Phi: 'Φ', mu: 'μ', lambda: 'λ', sigma: 'σ', tau: 'τ',
  rho: 'ρ', phi: 'φ', beta: 'β', kappa: 'κ', top: '⊤', in: '∈', times: '×', infty: '∞',
  one: '𝟙', F: '𝓕', T: '𝒯', approx: '≈', sim: '∼', ldots: '…', minus: '−', ell: 'ℓ', quad: '  ',
};
function parseMath(s) {
  let i = 0;
  function group() { // after '{'
    const out = seq('}');
    i++; // skip '}'
    return out;
  }
  function single() {
    if (s[i] === '{') { i++; return group(); }
    if (s[i] === '\\') return [command()];
    return [{ t: s[i++] }];
  }
  function command() {
    i++; // backslash
    if (!/[A-Za-z]/.test(s[i])) return { t: s[i++] }; // \{ \} \| …
    let name = '';
    while (i < s.length && /[A-Za-z]/.test(s[i])) name += s[i++];
    if (name === 'frac') {
      const a = single(); const b = single();
      return { c: new MathFraction({ numerator: comps(a), denominator: comps(b) }) };
    }
    if (name === 'sqrt') return { c: new MathRadical({ children: comps(single()) }) };
    if (name === 'hat') return { t: flat(single()) + '̂' };
    if (name === 'bar') return { t: flat(single()) + '̄' };
    if (name === 'text') return { t: flat(single()), up: true };
    if (name === 'sum') {
      let sub = [], sup = [];
      for (let k = 0; k < 2; k++) {
        if (s[i] === '_') { i++; sub = single(); }
        else if (s[i] === '^') { i++; sup = single(); }
      }
      const body = single();
      return { c: new MathSum({ children: comps(body), subScript: comps(sub), superScript: comps(sup) }) };
    }
    if (SYM[name] === undefined) throw new Error('unknown math command ' + name);
    return { t: SYM[name] };
  }
  function seq(end) {
    const atoms = [];
    while (i < s.length && s[i] !== end) {
      const ch = s[i];
      if (ch === '_' || ch === '^') {
        const base = atoms.pop();
        let sub = null, sup = null;
        for (let k = 0; k < 2 && (s[i] === '_' || s[i] === '^'); k++) {
          const which = s[i++];
          const g = single();
          if (which === '_') sub = g; else sup = g;
        }
        const ch2 = comps([base]);
        let c;
        if (sub && sup) c = new MathSubSuperScript({ children: ch2, subScript: comps(sub), superScript: comps(sup) });
        else if (sub) c = new MathSubScript({ children: ch2, subScript: comps(sub) });
        else c = new MathSuperScript({ children: ch2, superScript: comps(sup) });
        atoms.push({ c });
      } else if (ch === '{') { i++; atoms.push({ g: group() }); }
      else if (ch === '\\') atoms.push(command());
      else { atoms.push({ t: ch }); i++; }
    }
    return atoms;
  }
  function flat(atoms) { return atoms.map((a) => a.t || '').join(''); }
  function comps(atoms) {
    const out = []; let buf = '';
    const flush = () => { if (buf) { out.push(new MathRun(buf)); buf = ''; } };
    for (const a of atoms) {
      if (a.t !== undefined) buf += a.t;
      else if (a.g) { flush(); out.push(...comps(a.g)); }
      else { flush(); out.push(a.c); }
    }
    flush();
    return out;
  }
  const atoms = seq(undefined);
  return comps(atoms);
}
const M = (s) => new OMath({ children: parseMath(s) });

// ---------------------------------------------------------------- text helpers
// Inline markup in body strings: $...$ math, [@k1,k2] citation, *...* italic, **...** bold.
function runs(str, base = {}) {
  const out = [];
  const re = /(\$[^$]+\$|\[@[^\]]+\]|\*\*[^*]+\*\*|\*[^*]+\*)/g;
  let last = 0; let m;
  while ((m = re.exec(str))) {
    if (m.index > last) out.push(new TextRun({ text: str.slice(last, m.index), ...base }));
    const tok = m[0];
    if (tok[0] === '$') out.push(M(tok.slice(1, -1)));
    else if (tok.startsWith('[@')) out.push(new TextRun({ text: cite(tok.slice(2, -1)), ...base }));
    else if (tok.startsWith('**')) out.push(new TextRun({ text: tok.slice(2, -2), ...base, bold: true }));
    else out.push(new TextRun({ text: tok.slice(1, -1), ...base, italics: true }));
    last = m.index + tok.length;
  }
  if (last < str.length) out.push(new TextRun({ text: str.slice(last), ...base }));
  return out;
}
// IEEE body: 10 pt Times on a 12 pt baseline (line 240 twips, "at least" so inline math can still grow a line).
const LINE12 = { after: 0, line: 240, lineRule: LineRuleType.AT_LEAST };
const DROPCAP_STYLE = 'FMDropCap';
function body(str, opt = {}) {
  if (opt.dropCap) {
    // IEEE opens the first section with a two-line drop cap and the rest of the first word in capitals.
    // The frame properties are written in post-processing (Packer step at the end of this file).
    const sp = str.indexOf(' ');
    return [
      new Paragraph({ style: DROPCAP_STYLE, children: [new TextRun({ text: str[0], size: 50 })] }),
      new Paragraph({ alignment: AlignmentType.JUSTIFIED, spacing: LINE12, children: runs(str.slice(1, sp).toUpperCase() + str.slice(sp)) }),
    ];
  }
  return new Paragraph({
    alignment: AlignmentType.JUSTIFIED, indent: { firstLine: opt.noIndent ? 0 : 202 },
    spacing: LINE12, children: runs(str),
  });
}
const romans = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI'];
let secNo = 0; let subNo = 0;
function H1(title, numbered = true) {
  subNo = 0;
  const label = numbered ? romans[secNo++] + '. ' : '';
  return new Paragraph({
    alignment: AlignmentType.CENTER, spacing: { before: 200, after: 80 }, keepNext: true,
    children: [new TextRun({ text: label + title, smallCaps: true, size: 20 })],
  });
}
function H2(title) {
  const label = String.fromCharCode(65 + subNo++) + '. ';
  return new Paragraph({
    spacing: { before: 120, after: 60 }, keepNext: true,
    children: [new TextRun({ text: label + title, italics: true, size: 20 })],
  });
}
let eqNo = 0;
function EQ(latex) {
  eqNo++;
  return new Paragraph({
    tabStops: [{ type: TabStopType.CENTER, position: COL / 2 }, { type: TabStopType.RIGHT, position: COL }],
    spacing: { before: 60, after: 60 },
    children: [new TextRun('\t'), M(latex), new TextRun('\t(' + eqNo + ')')],
  });
}
const bullet = (str) => new Paragraph({
  alignment: AlignmentType.JUSTIFIED, indent: { left: 288, hanging: 202 }, spacing: LINE12,
  children: [new TextRun('•\t'), ...runs(str)], tabStops: [{ type: TabStopType.LEFT, position: 288 }],
});
let figNo = 0;
function FIG(file, wPx, hPx, caption) {
  figNo++;
  return [
    new Paragraph({
      alignment: AlignmentType.CENTER, spacing: { before: 120, after: 40 }, keepNext: true,
      children: [new ImageRun({ type: 'png', data: fs.readFileSync(path.join(HERE, file.replace('.png', L.figSuffix + '.png'))), transformation: { width: wPx, height: hPx } })],
    }),
    new Paragraph({
      alignment: AlignmentType.JUSTIFIED, spacing: { after: 120 }, keepLines: true,
      children: [new TextRun({ text: L.fig + ' ' + figNo + '.  ', size: 16 }), ...runs(caption, { size: 16 })],
    }),
  ];
}
function FIGBOX(text, caption) {
  figNo++;
  const cell = new TableCell({
    width: { size: COL - 200, type: WidthType.DXA },
    children: [new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 500, after: 500 }, children: [new TextRun({ text, size: 16, italics: true })] })],
  });
  return [
    new Table({ width: { size: COL - 200, type: WidthType.DXA }, columnWidths: [COL - 200], alignment: AlignmentType.CENTER, rows: [new TableRow({ children: [cell] })] }),
    new Paragraph({
      alignment: AlignmentType.JUSTIFIED, spacing: { before: 60, after: 120 },
      children: [new TextRun({ text: L.fig + ' ' + figNo + '.  ', size: 16 }), ...runs(caption, { size: 16 })],
    }),
  ];
}
let tabNo = 0;
const NONE = { style: BorderStyle.NONE, size: 0, color: 'FFFFFF' };
const LINE = { style: BorderStyle.SINGLE, size: 4, color: '000000' };
function TABLE(title, widths, header, rows, note, align) {
  tabNo++;
  const total = widths.reduce((a, b) => a + b, 0);
  // Rows never split. A short table (up to five rows) also keeps every row with the next, so it is not broken across
  // columns; a long one may break between rows (keeping it whole left large gaps), with its header row repeated.
  const keep = rows.length <= 5;
  const mk = (cells, isHead, isLast) => new TableRow({
    tableHeader: isHead, cantSplit: true,
    children: cells.map((c, j) => new TableCell({
      width: { size: widths[j], type: WidthType.DXA },
      margins: { left: 50, right: 50, top: 20, bottom: 20 },
      borders: { top: isHead ? LINE : NONE, bottom: isHead || isLast ? LINE : NONE, left: NONE, right: NONE },
      children: [new Paragraph({ keepNext: ((keep || isHead) && !isLast) || (keep && isLast && !!note), alignment: (align ? align[j] === 'L' : j === 0) ? AlignmentType.LEFT : AlignmentType.CENTER, children: runs(c, { size: 16, bold: false }) })],
    })),
  });
  const out = [
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 160, after: 0 }, keepNext: true, children: [new TextRun({ text: L.table + ' ' + romans[tabNo - 1], size: 16 })] }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 60 }, keepNext: true, children: [new TextRun({ text: title, smallCaps: true, size: 16 })] }),
    new Table({
      width: { size: total, type: WidthType.DXA }, columnWidths: widths, alignment: AlignmentType.CENTER,
      rows: [mk(header, true, false), ...rows.map((rw, k) => mk(rw, false, k === rows.length - 1))],
    }),
  ];
  out.push(new Paragraph({ spacing: { before: 40, after: 120 }, alignment: AlignmentType.JUSTIFIED, children: note ? runs(note, { size: 16 }) : [] }));
  return out;
}

// ---------------------------------------------------------------- content (per language)
const content = [];
const add = (...xs) => xs.forEach((x) => (Array.isArray(x) ? content.push(...x) : content.push(x)));
// "Abstract—text" style paragraph used for Abstract and Index Terms (inline math and citations allowed).
const LABELED = (label, text, after = 100) => new Paragraph({
  alignment: AlignmentType.JUSTIFIED, spacing: { after },
  children: [new TextRun({ text: label, bold: true, italics: true, size: 18 }), ...runs('—' + text, { bold: true, size: 18 })],
});
// Left-aligned: a justified line that ends before a long DOI or URL gets stretched into wide gaps.
const REFLIST = () => citeOrder.map((k, idx) => new Paragraph({
  alignment: AlignmentType.LEFT, indent: { left: 360, hanging: 360 }, spacing: { after: 20 },
  tabStops: [{ type: TabStopType.LEFT, position: 360 }],
  children: [new TextRun({ text: '[' + (idx + 1) + ']\t', size: 16 }), ...runs(REFS[k], { size: 16 })],
}));
const C = require('./content_' + LANG + '.js');
C.build({ add, body, H1, H2, EQ, bullet, FIG, FIGBOX, TABLE, LABELED, REFLIST, r });
const unused = Object.keys(REFS).filter((k) => !citeOrder.includes(k));
if (unused.length) throw new Error('uncited references: ' + unused.join(', '));

const front = [
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 120, after: 200 }, children: [new TextRun({ text: C.title, size: 48 })] }),
  new Paragraph({
    alignment: AlignmentType.CENTER, spacing: { after: 160 },
    children: [new TextRun({ text: C.authors, size: 22 })],
  }),
  // Supervisor's review 2026-11-12 struck the e-mail placeholder: no e-mail line unless C.emails is set.
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: C.emails ? 0 : 320 }, children: [new TextRun({ text: C.affiliation, italics: true, size: 20 })] }),
  ...(C.emails ? [new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 320 }, children: [new TextRun({ text: C.emails, size: 20 })] })] : []),
];

// ---------------------------------------------------------------- document
// Page measured on the faculty's model paper (2026-11-10): Letter, two 3.5 in columns about 0.21 in apart,
// so the text block is about 7.21 in wide -> side margins 925 twips, column gap 310 twips.
const SIDE = 925, GAP = 310;
const TEXTW = 12240 - 2 * SIDE;
const txt = (t) => new TextRun({ text: t, size: 14 });
const pageNo = () => new TextRun({ children: [PageNumber.CURRENT], size: 14 });
const hdr = (left, right) => new Header({
  children: [new Paragraph({ tabStops: [{ type: TabStopType.RIGHT, position: TEXTW }], children: [...left, txt('\t'), ...right] })],
});
// Every page: proceedings line left, page number right (faculty's model paper, 2026-11-10).
const headers = { default: hdr([new TextRun({ text: C.header, size: 18 })], [new TextRun({ children: [PageNumber.CURRENT], size: 18 })]) };
const page = { size: { width: 12240, height: 15840 }, margin: { top: 1080, bottom: 1080, left: SIDE, right: SIDE, header: 540, footer: 540 } };

const doc = new Document({
  creator: C.authors,
  title: C.title,
  styles: { default: { document: { run: { font: FONT, size: 20 } } } },
  sections: [
    { properties: { page }, headers, children: front },
    { properties: { page, type: SectionType.CONTINUOUS, column: { count: 2, space: GAP } }, headers, children: content },
  ],
});

Packer.toBuffer(doc).then(async (buf) => {
  // Post-process the drop-cap frame of the first paragraph, which docx 9.5.1 does not write directly.
  // (The unnumbered first-page footnote of the IEEE TAI layout was removed 2026-11-10: the model paper has none.)
  const zip = await JSZip.loadAsync(buf);
  let docXml = await zip.file('word/document.xml').async('string');
  const dropFrom = '<w:pPr><w:pStyle w:val="' + DROPCAP_STYLE + '"/></w:pPr>';
  const dropTo = '<w:pPr><w:keepNext/><w:framePr w:dropCap="drop" w:lines="2" w:wrap="around" w:vAnchor="text" w:hAnchor="text"/>'
    + '<w:spacing w:after="0" w:line="480" w:lineRule="exact"/><w:textAlignment w:val="baseline"/></w:pPr>';
  if (docXml.split(dropFrom).length !== 2) throw new Error('drop cap paragraph not found exactly once');
  docXml = docXml.replace(dropFrom, dropTo);
  // A hyphen inside a DOI must not end a line: PDF readers drop a line-final hyphen on copy, so
  // "1099-" + "0771" came out as "10990771" (2026-11-10). Hyphens in DOIs become non-breaking hyphens.
  const esc = (t) => t.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  for (const k of citeOrder) {
    const m = /doi: (\S+)\.$/.exec(REFS[k]);
    if (!m || !m[1].includes('-')) continue;
    const doi = esc(m[1]);
    if (docXml.split(doi).length !== 2) throw new Error('DOI not found exactly once: ' + m[1]);
    docXml = docXml.replace(doi, doi.split('-').join('</w:t><w:noBreakHyphen/><w:t xml:space="preserve">'));
  }
  zip.file('word/document.xml', docXml);
  buf = await zip.generateAsync({ type: 'nodebuffer', compression: 'DEFLATE' });
  fs.writeFileSync(path.join(HERE, L.out), buf);
  console.log(L.out + ' equations=' + eqNo + ' figures=' + figNo + ' tables=' + tabNo + ' refs=' + citeOrder.length);
});
