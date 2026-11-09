// Builds the IEEE-style (two-column, Times 10 pt) draft paper as .docx.
// Run:  NODE_PATH=<folder containing node_modules/docx 9.x> node build_paper.js
// Output: draft_paper.docx next to this script. Figures come from make_figures.py.
'use strict';
const fs = require('fs');
const path = require('path');
const d = require('docx');
const {
  Document, Packer, Paragraph, TextRun, AlignmentType, TabStopType, SectionType, Header,
  PageNumber, ImageRun, Table, TableRow, TableCell, WidthType, BorderStyle, FootnoteReferenceRun,
  Math: OMath, MathRun, MathSubScript, MathSuperScript, MathSubSuperScript, MathFraction, MathRadical,
  MathSum, VerticalAlign,
} = d;

const HERE = __dirname;
const r = String.raw;
const COL = 5040; // column width in twips (3.5 in)
const FONT = 'Times New Roman';

// ---------------------------------------------------------------- references
const REFS = {
  lusardi: 'A. Lusardi and O. S. Mitchell, “The economic importance of financial literacy: Theory and evidence,” *J. Econ. Lit.*, vol. 52, no. 1, pp. 5–44, 2014.',
  thaler: 'R. H. Thaler, “Mental accounting matters,” *J. Behav. Decis. Making*, vol. 12, no. 3, pp. 183–206, 1999.',
  karlan: 'D. Karlan, M. McConnell, S. Mullainathan, and J. Zinman, “Getting to the top of mind: How reminders increase saving,” *Manage. Sci.*, vol. 62, no. 12, pp. 3393–3411, 2016.',
  gneitingR: 'T. Gneiting and A. E. Raftery, “Strictly proper scoring rules, prediction, and estimation,” *J. Amer. Statist. Assoc.*, vol. 102, no. 477, pp. 359–378, 2007.',
  gneitingC: 'T. Gneiting, F. Balabdaoui, and A. E. Raftery, “Probabilistic forecasts, calibration and sharpness,” *J. Roy. Statist. Soc. B*, vol. 69, no. 2, pp. 243–268, 2007.',
  roberts: 'S. W. Roberts, “Control chart tests based on geometric moving averages,” *Technometrics*, vol. 1, no. 3, pp. 239–250, 1959.',
  holt: 'C. C. Holt, “Forecasting seasonals and trends by exponentially weighted moving averages,” *Int. J. Forecast.*, vol. 20, no. 1, pp. 5–10, 2004 (reprint of 1957 report).',
  hunter: 'J. S. Hunter, “The exponentially weighted moving average,” *J. Qual. Technol.*, vol. 18, no. 4, pp. 203–210, 1986.',
  riskmetrics: 'J. P. Morgan/Reuters, "RiskMetrics—Technical document," 4th ed., New York, NY, USA, 1996.',
  hyndman: 'R. J. Hyndman and G. Athanasopoulos, *Forecasting: Principles and Practice*, 3rd ed. Melbourne, Australia: OTexts, 2021.',
  koenkerB: 'R. Koenker and G. Bassett, Jr., “Regression quantiles,” *Econometrica*, vol. 46, no. 1, pp. 33–50, 1978.',
  koenker: 'R. Koenker, *Quantile Regression*. Cambridge, U.K.: Cambridge Univ. Press, 2005.',
  taylor: 'J. W. Taylor, “Forecasting daily supermarket sales using exponentially weighted quantile regression,” *Eur. J. Oper. Res.*, vol. 178, no. 1, pp. 154–167, 2007.',
  meinshausen: 'N. Meinshausen, “Quantile regression forests,” *J. Mach. Learn. Res.*, vol. 7, pp. 983–999, 2006.',
  chernozhukov: 'V. Chernozhukov, I. Fernández-Val, and A. Galichon, “Quantile and probability curves without crossing,” *Econometrica*, vol. 78, no. 3, pp. 1093–1125, 2010.',
  brier: 'G. W. Brier, “Verification of forecasts expressed in terms of probability,” *Monthly Weather Rev.*, vol. 78, no. 1, pp. 1–3, 1950.',
  naeini: 'M. P. Naeini, G. F. Cooper, and M. Hauskrecht, “Obtaining well calibrated probabilities using Bayesian binning,” in *Proc. AAAI Conf. Artif. Intell.*, Austin, TX, USA, 2015, pp. 2901–2907.',
  guo: 'C. Guo, G. Pleiss, Y. Sun, and K. Q. Weinberger, “On calibration of modern neural networks,” in *Proc. Int. Conf. Mach. Learn.*, Sydney, NSW, Australia, 2017, pp. 1321–1330.',
  fawcett: 'T. Fawcett, “An introduction to ROC analysis,” *Pattern Recognit. Lett.*, vol. 27, no. 8, pp. 861–874, 2006.',
  tashman: 'L. J. Tashman, “Out-of-sample tests of forecasting accuracy: An analysis and review,” *Int. J. Forecast.*, vol. 16, no. 4, pp. 437–450, 2000.',
  dm: 'F. X. Diebold and R. S. Mariano, “Comparing predictive accuracy,” *J. Bus. Econ. Statist.*, vol. 13, no. 3, pp. 253–263, 1995.',
  efron: 'B. Efron and R. J. Tibshirani, *An Introduction to the Bootstrap*. New York, NY, USA: Chapman & Hall, 1993.',
  berka: 'P. Berka, “Guide to the financial data set,” in *PKDD-99 Discovery Challenge*, Prague, Czech Republic, 1999.',
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
const body = (str, opt = {}) => new Paragraph({
  alignment: AlignmentType.JUSTIFIED, indent: { firstLine: opt.noIndent ? 0 : 202 },
  spacing: { after: 0, line: 240 }, children: runs(str),
});
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
  alignment: AlignmentType.JUSTIFIED, indent: { left: 288, hanging: 202 }, spacing: { after: 0 },
  children: [new TextRun('•\t'), ...runs(str)], tabStops: [{ type: TabStopType.LEFT, position: 288 }],
});
let figNo = 0;
function FIG(file, wPx, hPx, caption) {
  figNo++;
  return [
    new Paragraph({
      alignment: AlignmentType.CENTER, spacing: { before: 120, after: 40 }, keepNext: true,
      children: [new ImageRun({ type: 'png', data: fs.readFileSync(path.join(HERE, file)), transformation: { width: wPx, height: hPx } })],
    }),
    new Paragraph({
      alignment: AlignmentType.JUSTIFIED, spacing: { after: 120 },
      children: [new TextRun({ text: 'Fig. ' + figNo + '.  ', size: 16 }), ...runs(caption, { size: 16 })],
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
      children: [new TextRun({ text: 'Fig. ' + figNo + '.  ', size: 16 }), ...runs(caption, { size: 16 })],
    }),
  ];
}
let tabNo = 0;
const NONE = { style: BorderStyle.NONE, size: 0, color: 'FFFFFF' };
const LINE = { style: BorderStyle.SINGLE, size: 4, color: '000000' };
function TABLE(title, widths, header, rows, note, align) {
  tabNo++;
  const total = widths.reduce((a, b) => a + b, 0);
  const mk = (cells, isHead, isLast) => new TableRow({
    tableHeader: isHead,
    children: cells.map((c, j) => new TableCell({
      width: { size: widths[j], type: WidthType.DXA },
      margins: { left: 50, right: 50, top: 20, bottom: 20 },
      borders: { top: isHead ? LINE : NONE, bottom: isHead || isLast ? LINE : NONE, left: NONE, right: NONE },
      children: [new Paragraph({ alignment: (align ? align[j] === 'L' : j === 0) ? AlignmentType.LEFT : AlignmentType.CENTER, children: runs(c, { size: 16, bold: false }) })],
    })),
  });
  const out = [
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 160, after: 0 }, keepNext: true, children: [new TextRun({ text: 'TABLE ' + romans[tabNo - 1], size: 16 })] }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 60 }, keepNext: true, children: [new TextRun({ text: title, smallCaps: true, size: 16 })] }),
    new Table({
      width: { size: total, type: WidthType.DXA }, columnWidths: widths, alignment: AlignmentType.CENTER,
      rows: [mk(header, true, false), ...rows.map((rw, k) => mk(rw, false, k === rows.length - 1))],
    }),
  ];
  out.push(new Paragraph({ spacing: { before: 40, after: 120 }, alignment: AlignmentType.JUSTIFIED, children: note ? runs(note, { size: 14 }) : [] }));
  return out;
}

// ---------------------------------------------------------------- content
const TITLE = 'Research and Development of Probabilistic Forecasting Models Based on Median, EWMA, and Quantile Regression for Early Warning of End-of-Period Budget Overruns in Personal Finance Management Applications';

const front = [
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 120, after: 200 }, children: [new TextRun({ text: TITLE, size: 40 })] }),
  new Paragraph({
    alignment: AlignmentType.CENTER, spacing: { after: 320 },
    children: [new TextRun({ text: 'Phu Bao Nguyen and Quang Dat Tran', size: 22 }), new FootnoteReferenceRun(1)],
  }),
];

const abstractTxt = 'Personal finance applications let users set a monthly spending budget, yet most of them only report an overrun after the limit has been crossed, or extrapolate spending linearly, which misfires for users whose spending is front-loaded by rent or recurring bills. We study how to estimate, at any day of a budget period, the probability that total spending will exceed the budget by the end of the period, and how early such an estimate can support a useful warning. We formulate the task as probabilistic forecasting of the remaining spend and compare four forecasters of increasing complexity: a pro-rata baseline, the median spending-rhythm model currently deployed in the FlowMoney mobile application, an exponentially weighted moving average model of daily spending rate and volatility, and a pooled linear quantile regression with monotone rearrangement. The forecasters are evaluated on the public PKDD-99 Berka bank transaction data set and on a synthetic population with known spending archetypes, using rolling-origin evaluation at five checkpoints per period and three levels of budget tightness. Evaluation covers probability quality (Brier score, logarithmic loss, area under the receiver operating characteristic curve, and expected calibration error), point accuracy (mean absolute error and pinball loss), and warning utility (recall at a fixed false-alarm rate and lead time in days). We also describe how the selected forecaster can run entirely on the device in an offline-first application. This draft reports the study design; the experimental results will be added in the final version.';

const impactTxt = 'Overspending is easier to prevent than to repair. A warning that arrives when the budget is already exhausted leaves the user nothing to act on, and a warning that fires every month for someone who always pays rent on the first day teaches the user to ignore it. This study gives personal finance applications a way to state the risk of an overrun as a calibrated probability, early enough in the month for the user to adjust, and with a measured false-alarm rate. The methods are light enough to run on a mobile phone without sending transaction data to a server, which matters for users who keep their finances private. The comparison also tells developers when a simple median rule is sufficient and when a learned quantile model is worth its added complexity.';

const content = [];
const add = (...xs) => xs.forEach((x) => (Array.isArray(x) ? content.push(...x) : content.push(x)));

add(new Paragraph({ alignment: AlignmentType.JUSTIFIED, spacing: { after: 100 }, children: [new TextRun({ text: 'Abstract', bold: true, italics: true, size: 18 }), new TextRun({ text: '—' + abstractTxt, bold: true, size: 18 })] }));
add(new Paragraph({ alignment: AlignmentType.JUSTIFIED, spacing: { after: 100 }, children: [new TextRun({ text: 'Impact Statement', bold: true, italics: true, size: 18 }), new TextRun({ text: '—' + impactTxt, bold: true, size: 18 })] }));
add(new Paragraph({ alignment: AlignmentType.JUSTIFIED, spacing: { after: 160 }, children: [new TextRun({ text: 'Index Terms', bold: true, italics: true, size: 18 }), new TextRun({ text: '—Budget overrun, early warning, exponentially weighted moving average, personal finance management, probabilistic forecasting, quantile regression.', bold: true, size: 18 })] }));

// I. Introduction
add(H1('Introduction'));
add(body('Keeping spending within a planned amount is one of the basic skills of personal financial management, and weak financial planning has measurable costs for households [@lusardi]. People already think about money in per-period mental accounts such as "this month\'s food money" [@thaler], so a monthly budget is the most common planning tool offered by personal finance applications. What these applications do with the budget during the month matters: reminders delivered at the right moment change financial behaviour [@karlan], while a reminder that comes too late, or too often, does not.'));
add(body('Two warning designs dominate in practice. The first is a threshold alert that fires when spending reaches a fixed share of the budget, for example 80% or 100%. It reacts to what has already been spent and says nothing about where the month is heading. The second extrapolates linearly: if 40% of the month has passed and 60% of the budget is gone, the user is "spending too fast". This rule is wrong for anyone whose spending is front-loaded. A user who pays rent on the first day of the month looks over budget on every early checkpoint, and quickly learns to ignore the warning.'));
add(body('FlowMoney, the offline-first personal finance application developed by our team, already moves beyond both designs. For each budget it learns a *spending rhythm* from the three to six most recent closed periods: at every elapsed share of the period, it takes the median, across past periods, of the share of spending already reached and of the amount still to be spent. The current pace is then labelled slow, on track, or fast within a band of five percentage points around that rhythm. The rule is robust to one unusual month, but it produces a point forecast rather than a probability, and with at most six past periods its empirical distribution has very coarse resolution.'));
add(body('This paper asks whether an explicitly probabilistic forecast gives better early warnings. A probability $p_{t}=P(S_{T}>B\\mid\\F_{t})$ that the end-of-period spending $S_{T}$ exceeds the budget $B$ can be judged with proper scoring rules [@gneitingR], can be checked for calibration [@gneitingC], and lets the application choose an alert threshold that trades false alarms against warning lead time. We study three research questions:'));
add(bullet('**RQ1:** Which forecaster produces the best calibrated and sharpest overrun probabilities?'));
add(bullet('**RQ2:** At a fixed false-alarm rate, how many days earlier than the baselines can each forecaster warn about an overrun?'));
add(bullet('**RQ3:** How do budget tightness and the regularity of a user\'s spending change the ranking?'));
add(body('The contributions are as follows. First, we formulate budget-overrun warning as probabilistic forecasting of the remaining spend, with evaluation at both the probability level and the alert level. Second, we compare four forecasters of increasing complexity, including the median rhythm that is already deployed in a production application. Third, we use a synthetic population with known spending archetypes to explain when each forecaster wins. Fourth, we give a deployment guideline for computing the forecast on the device without sending transactions to a server.'));
add(body('Section II reviews related work. Section III defines the problem and Section IV the four forecasters. Section V describes the data and the evaluation protocol, Section VI the expected results and the analysis plan, and Section VII the integration into FlowMoney. Section VIII gives the work plan and Section IX concludes.'));

// II. Related work
add(H1('Related Work'));
add(H2('Exponential Smoothing'));
add(body('The exponentially weighted moving average (EWMA) was introduced for process monitoring by Roberts [@roberts] and became the basis of exponential smoothing forecasts [@holt], [@hunter]. The RiskMetrics methodology applies the same recursion to the variance of financial returns, so that one smoothing constant tracks both level and volatility [@riskmetrics]. Exponential smoothing methods and their prediction intervals are surveyed by Hyndman and Athanasopoulos [@hyndman]. EWMA reacts quickly to change at almost no computational cost, which makes it attractive on a phone; its weakness for our task is the assumption that daily spending is exchangeable within the month.'));
add(H2('Quantile Regression and Probabilistic Forecasts'));
add(body('Quantile regression estimates conditional quantiles by minimising the check loss [@koenkerB], [@koenker]. Taylor combined it with exponential weighting to forecast the distribution of daily retail sales [@taylor], a setting close to ours, and quantile regression forests extend the idea to non-linear models [@meinshausen]. Quantiles estimated separately may cross; monotone rearrangement fixes this without loss of accuracy [@chernozhukov]. A probabilistic forecast should be calibrated and, subject to calibration, as sharp as possible [@gneitingC]; it is evaluated with strictly proper scores such as the Brier score [@brier] and the logarithmic score [@gneitingR]. Calibration is commonly summarised by the expected calibration error [@naeini], [@guo], and discrimination by the area under the ROC curve [@fawcett].'));
add(H2('Forecast Evaluation'));
add(body('Forecasts must be evaluated out of sample in time order. Rolling-origin evaluation refits or updates the model at each forecast origin using only past data [@tashman]. Differences in accuracy between two forecasters are tested with the Diebold–Mariano test [@dm] or, when observations are grouped by user, with a bootstrap over users [@efron].'));
add(body('We are not aware of a published comparison that evaluates in-period budget-overrun warnings as calibrated probabilities with an explicit lead-time measure, which is the gap this study addresses.'));

// III. Problem formulation
add(H1('Problem Formulation'));
add(body('Consider one user and one budget period of $T$ days with budget $B>0$. Let $y_{d}\\ge0$ be the amount spent on day $d$ and $S_{t}=\\sum_{d=1}^{t}{y_{d}}$ the cumulative spending after day $t$, with elapsed share $x_{t}=t/T$. The period ends in an overrun when $O=\\one[S_{T}>B]$ equals one. At a checkpoint $t$ the forecaster observes the information set $\\F_{t}$, which contains the current period up to day $t$ and all of the user\'s earlier periods, and returns'));
add(EQ(r`p_{t}=P(S_{T}>B\mid\F_{t})=P(R_{t}>B-S_{t}\mid\F_{t}),`));
add(body('where $R_{t}=S_{T}-S_{t}\\ge0$ is the spending still to come. Every forecaster in Section IV therefore produces a predictive distribution of $R_{t}$. When $S_{t}>B$ the overrun has already happened, $p_{t}=1$ trivially, and the checkpoint is excluded from probability scoring.', { noIndent: true }));
add(body('An alert is raised at the first checkpoint with $p_{t}\\ge p^{*}$. Let $\\tau_{O}$ be the first day on which $S_{d}>B$. For a period that ends in an overrun, the lead time of an alert raised at day $t_{a}$ is'));
add(EQ(r`L=\tau_{O}-t_{a},`));
add(body('so a positive $L$ means the user was warned before the budget was actually exceeded. Fig. 1 summarises the pipeline and Fig. 2 illustrates the forecasting problem at one checkpoint.', { noIndent: true }));
add(FIG('fig1_pipeline.png', 300, 265, 'Forecasting and warning pipeline. All four forecasters output a predictive distribution of the remaining spend, from which the overrun probability and the alert decision follow.'));
add(FIG('fig2_problem.png', 320, 198, 'Illustration of the problem on a hand-made series (not real data): rent paid on day 1, a spike on day 10, and a 10–90% forecast band for end-of-period spending at checkpoint $t=12$.'));

// IV. Methods
add(H1('Methods'));
add(body('The four forecasters, summarised in Table I, use increasing amounts of information.'));
add(TABLE('Summary of the Four Forecasters', [1150, 1330, 1330, 1230],
  ['Method', 'Information used', 'Predictive output', 'On-device cost'],
  [
    ['M0 Pro-rata', 'own past periods', 'empirical, $K+1$ levels', '$O(K)$'],
    ['M1 Median rhythm', 'own last 3–6 periods', 'empirical, $K+1$ levels', '$O(K\\cdot n)$'],
    ['M2 EWMA', 'own daily series', 'Gaussian or log-normal', '$O(1)$ per day'],
    ['M3 Quantile regression', 'features + pooled training', '19 quantiles', '$O(|\\T|\\cdot|\\phi|)$'],
  ],
  '$K$: number of usable past periods; $n$: transactions per period; $\\T$: quantile levels; $\\phi$: feature vector.'));
add(H2('M0: Pro-Rata Baseline'));
add(body('The pro-rata forecast assumes spending is spread evenly over the period, $S_{T}^{pr}=S_{t}/x_{t}$, which is the fallback FlowMoney uses before a rhythm can be learned. To turn it into a probability we use the multiplicative errors $e_{k}=S_{T}^{(k)}x_{t}/S^{(k)}(x_{t})$ observed in the user\'s past periods $k=1,\\ldots,K$, where $S^{(k)}(x)$ is the cumulative spending of period $k$ at elapsed share $x$:'));
add(EQ(r`p_{t}=\frac{\sum_{k=1}^{K}{\one[S_{t}e_{k}/x_{t}>B]}+1/2}{K+1}.`));
add(H2('M1: Median Spending Rhythm'));
add(body('M1 is the rule currently deployed in FlowMoney. For each of the user\'s $K$ most recent closed periods with positive spending ($3\\le K\\le6$), let $r_{k}(x)=S_{T}^{(k)}-S^{(k)}(x)$ be the amount spent after elapsed share $x$. The point forecast of the remaining spend is $r_{t}^{med}$, the median of $r_{k}(x_{t})$ over $k$; the median keeps one unusual month from dominating. We read the same $K$ values as an empirical predictive distribution with the smoothing used in (3):'));
add(EQ(r`p_{t}=\frac{\sum_{k=1}^{K}{\one[S_{t}+r_{k}(x_{t})>B]}+1/2}{K+1}.`));
add(body('With $K\\le6$ this probability can take at most seven values, which limits its resolution. When fewer than three periods are available the application falls back to M0; we report how often this happens.'));
add(H2('M2: EWMA Rate and Volatility'));
add(body('M2 smooths the user\'s daily spending series, including the current period up to day $t$, with one constant $\\lambda\\in(0,1]$ for the level and the variance [@riskmetrics]:'));
add(EQ(r`\mu_{d}=\lambda y_{d}+(1-\lambda)\mu_{d-1},`));
add(EQ(r`v_{d}=\lambda(y_{d}-\mu_{d-1})^{2}+(1-\lambda)v_{d-1}.`));
add(body('Treating the $n=T-t$ remaining days as independent gives $R_{t}\\sim N(n\\mu_{t},nv_{t})$ and', { noIndent: true }));
add(EQ(r`p_{t}=1-\Phi\left(\frac{B-S_{t}-n\mu_{t}}{\sqrt{nv_{t}}}\right),`.replace(r`\left(`, '(').replace(r`\right)`, ')')));
add(body('where $\\Phi$ is the standard normal distribution function. Because $R_{t}$ is non-negative and right-skewed, we also test a log-normal distribution with the same mean and variance. $\\lambda$ is chosen from $\\{0.02,0.05,0.1,0.2\\}$ on the validation months. M2 ignores calendar effects such as rent on day one, so we expect it to struggle on front-loaded spending and to adapt fastest after a change in habits.', { noIndent: true }));
add(H2('M3: Pooled Linear Quantile Regression'));
add(body('M3 learns from all users at once. The target is the scale-free remaining spend $z=R_{t}/B$. The feature vector $\\phi$ contains the elapsed share $x_{t}$, the spent share $S_{t}/B$, the M1 forecast $r_{t}^{med}/B$, the M2 mean $n\\mu_{t}/B$ and spread $\\sqrt{nv_{t}}/B$, the share of past spending that historically fell in the remaining days of the month, the coefficient of variation of past period totals, and $K$. For each level $\\tau\\in\\T=\\{0.05,0.10,\\ldots,0.95\\}$ the coefficients minimise the check loss [@koenkerB]'));
add(EQ(r`b_{\tau}=\text{arg min}_{\beta}\sum_{i}{\rho_{\tau}(z_{i}-\phi_{i}^{\top}\beta)},`));
add(EQ(r`\rho_{\tau}(u)=u(\tau-\one[u<0]).`));
add(body('The 19 predicted quantiles are sorted to remove crossings [@chernozhukov], joined into a predictive distribution function $F_{t}$ of $z$ by linear interpolation with flat tails, and', { noIndent: true }));
add(EQ(r`p_{t}=1-F_{t}((B-S_{t})/B).`));
add(body('On the device, M3 costs 19 dot products with a nine-element feature vector, and only the coefficients have to be shipped with the application.', { noIndent: true }));

// V. Experimental design
add(H1('Experimental Design'));
add(H2('Data'));
add(body('The main data set is the PKDD-99 financial data set released by a Czech bank [@berka]. It contains about one million transactions on 4,500 accounts between 1993 and 1998, together with account, loan, and standing-order tables. We treat debit transactions as spending, aggregate them per day, and use calendar months as budget periods. Accounts with fewer than 18 months of history are dropped so that every evaluated month has at least six earlier months. Because the amounts are in Czech koruna and the levels differ widely between accounts, every model works with ratios to the budget. In a sensitivity analysis we remove loan repayments and household standing payments to separate fixed obligations from discretionary spending.'));
add(H2('Synthetic Population'));
add(body('To see *why* a forecaster wins, we also generate 2,000 synthetic users over 36 months, 500 for each of four archetypes: A1 steady daily spending; A2 front-loaded, with 30–45% of the month paid on day one; A3 payday-driven, with a burst after day ten; and A4 shock-prone, with a large unplanned purchase in about 15% of months. Each user has a slow drift in spending level. The generating process is known, so calibration can be checked against the true overrun probability.'));
add(H2('Budget Construction'));
add(body('The public data contain no budgets. We follow the budget suggestion rule of FlowMoney, which proposes the average spending of recent periods, and set the budget of month $m$ to $B_{m}=\\kappa(S_{m-1}+S_{m-2}+S_{m-3})/3$, where $S_{m}$ is the total spending of month $m$, with $\\kappa\\in\\{0.9,1.0,1.1\\}$. The three levels give a tight, a neutral, and a loose budget, and therefore different overrun base rates.'));
add(H2('Evaluation Protocol'));
add(body('We use rolling-origin evaluation by calendar month [@tashman]. For an evaluation month $m$, every forecaster uses only data from before month $m$ plus the current month up to the checkpoint; M3 is refitted on all users\' data before $m$ with an expanding window. Hyperparameters ($\\lambda$ for M2) are chosen on the first 20% of evaluation months and then frozen. Forecasts are issued at days 5, 10, 15, 20, and 25. A second split holds out 30% of users entirely to measure how M3 performs for a new user.'));
add(H2('Metrics'));
add(body('Table II lists the metrics. Probability quality is measured by the Brier score'));
add(EQ(r`\text{BS}=\frac{1}{N}\sum_{i=1}^{N}{(p_{i}-o_{i})^{2}},`));
add(body('the logarithmic loss with probabilities clipped to $[10^{-3},1-10^{-3}]$, the area under the ROC curve, and the expected calibration error over ten equal-frequency bins $b$,', { noIndent: true }));
add(EQ(r`\text{ECE}=\sum_{b=1}^{10}{\frac{N_{b}}{N}|O_{b}-P_{b}|},`));
add(body('where $N_{b}$ is the number of forecasts in bin $b$ and $O_{b}$, $P_{b}$ are the observed overrun frequency and the mean forecast probability in that bin, together with reliability diagrams. Point accuracy of the median forecast of $R_{t}$ is measured by the mean absolute error, and the full quantile forecast by the pinball loss averaged over $\\T$. For warnings, the threshold $p^{*}$ of each forecaster is set so that 10% (and, separately, 20%) of non-overrun user-months receive at least one alert; at that false-alarm rate we report recall, precision, and the median lead time (2).', { noIndent: true }));
add(TABLE('Evaluation Metrics', [1500, 2640, 900],
  ['Metric', 'Question answered', 'Better'],
  [
    ['Brier score, log loss', 'Is the probability accurate overall?', 'lower'],
    ['ECE, reliability diagram', 'Does 30% mean 30%?', 'lower'],
    ['AUC', 'Are overruns ranked above non-overruns?', 'higher'],
    ['MAE, pinball loss', 'How close is the remaining-spend forecast?', 'lower'],
    ['Recall at fixed false-alarm rate', 'How many overruns are caught?', 'higher'],
    ['Median lead time', 'How many days of warning?', 'higher'],
  ], null, 'LLC'));
add(H2('Statistical Comparison and Implementation'));
add(body('Scores are averaged per user first, so that users with long histories do not dominate. Differences between two forecasters are reported with 95% confidence intervals from 2,000 bootstrap resamples of users [@efron], with the Diebold–Mariano test [@dm] as a secondary check. The experiments are written in Python with pandas and the quantile regression of statsmodels. The Python version of M1 is checked against the Dart implementation in FlowMoney on shared test vectors, so the baseline is exactly the deployed rule. Code, random seeds, and the synthetic generator are kept in the project repository.'));

// VI. Expected results
add(H1('Expected Results and Analysis Plan'));
add(body('The following hypotheses guide the analysis; they are expectations, not results.'));
add(bullet('**H1 (RQ1).** M3 attains the lowest Brier score and calibration error overall. M1 is competitive in point accuracy, but its probabilities are coarse because they take at most $K+1$ values.'));
add(bullet('**H2 (RQ2).** At a 10% false-alarm rate, M1 and M3 warn several days earlier than M0 for front-loaded users (A2). M2 does poorly on A2, because rent on day one breaks its exchangeability assumption, but adapts fastest after a change in habits.'));
add(bullet('**H3 (RQ3).** The gaps are largest in mid-period (days 10–20) and for tight budgets, and all forecasters converge by day 25.'));
add(TABLE('Planned Results Table (to Be Filled)', [1130, 560, 560, 560, 560, 830, 840],
  ['Method', 'Brier', 'Log loss', 'AUC', 'ECE', 'Recall @10% FAR', 'Lead time (days)'],
  [['M0', '—', '—', '—', '—', '—', '—'], ['M1', '—', '—', '—', '—', '—', '—'], ['M2', '—', '—', '—', '—', '—', '—'], ['M3', '—', '—', '—', '—', '—', '—']],
  'Berka data, $\\kappa=1.0$, all checkpoints pooled. Per-checkpoint and per-archetype tables will follow the same layout.'));
add(FIGBOX('[Reliability diagrams of M0–M3 at day 15 — to be produced]', 'Planned figure: observed overrun frequency against forecast probability, one panel per forecaster.'));
add(FIGBOX('[Median lead time against false-alarm rate — to be produced]', 'Planned figure: trade-off between early warning and false alarms as $p^{*}$ varies.'));
add(body('Threats to validity. The Berka data come from a Czech bank in the 1990s, and its customers do not spend like Vietnamese users of mobile wallets in 2026. The budgets are constructed rather than chosen by users. Debit transactions include transfers that are not consumption. Finally, an offline evaluation cannot measure how users react to a warning: in deployment a warning may itself prevent the overrun it predicts, so the measured lead time describes the forecaster, not the effect on behaviour.'));

// VII. Integration
add(H1('Integration Into FlowMoney'));
add(body('FlowMoney stores all transactions in an on-device SQLite database and synchronises with its server in the background, and M1 already runs on the device. The proposed integration keeps that property. The overrun probability is recomputed whenever a transaction is saved and during the daily background scan that drives the existing notifications. The budget screen shows the probability next to the existing pace label, and a notification is sent once per period, the first time $p_{t}$ crosses $p^{*}$, using a per-period de-duplication key as the application already does for its other reminders. The coefficients of M3 are trained offline and shipped as generated constants, as the application already does for the weights of its learned question router, so no transaction leaves the phone. When fewer than three past periods exist, the application falls back to M2 or M0. This study changes no application code; the integration is a recommendation that follows from the results.'));

// VIII. Work plan
add(H1('Work Plan'));
add(TABLE('Schedule', [1000, 4040],
  ['Date (2026)', 'Task'],
  [
    ['Nov. 9', 'Study design and draft paper (this document).'],
    ['Nov. 10', 'Load and clean the Berka data; synthetic generator; budget construction.'],
    ['Nov. 11', 'M0, M1 (checked against the Dart code), M2; evaluation harness.'],
    ['Nov. 12', 'M3 with rolling-origin refits; user hold-out split.'],
    ['Nov. 13', 'Metrics, bootstrap intervals, figures, sensitivity analyses.'],
    ['Nov. 14', 'Results, discussion, and final paper.'],
  ], null, 'LL'));

// IX. Conclusion
add(H1('Conclusion'));
add(body('We have framed early warning of budget overruns as probabilistic forecasting of the remaining spend, and designed a comparison of four forecasters, from a pro-rata rule to pooled quantile regression, that measures both the quality of the probabilities and the lead time of the warnings. The deployed median rhythm of FlowMoney serves as the main baseline, so the outcome will answer a practical question: whether a learned probabilistic model gives users meaningfully earlier and more trustworthy warnings than the rule they use today.'));

add(H1('Acknowledgment', false));
add(body('The authors thank their supervisor, Huynh Nam, MSc in Information Systems, for his guidance on this study.'));

// References
add(H1('References', false));
citeOrder.forEach((k, idx) => add(new Paragraph({
  alignment: AlignmentType.JUSTIFIED, indent: { left: 360, hanging: 360 }, spacing: { after: 20 },
  tabStops: [{ type: TabStopType.LEFT, position: 360 }],
  children: [new TextRun({ text: '[' + (idx + 1) + ']\t', size: 16 }), ...runs(REFS[k], { size: 16 })],
})));
const unused = Object.keys(REFS).filter((k) => !citeOrder.includes(k));
if (unused.length) throw new Error('uncited references: ' + unused.join(', '));

// ---------------------------------------------------------------- document
const header = new Header({
  children: [new Paragraph({
    tabStops: [{ type: TabStopType.RIGHT, position: 10440 }],
    children: [new TextRun({ text: 'STUDENT SCIENTIFIC RESEARCH, INDUSTRIAL UNIVERSITY OF HO CHI MINH CITY — DRAFT, NOVEMBER 2026', size: 14 }),
      new TextRun({ text: '\t', size: 14 }), new TextRun({ children: [PageNumber.CURRENT], size: 14 })],
  })],
});
const page = { size: { width: 12240, height: 15840 }, margin: { top: 1080, bottom: 1080, left: 900, right: 900, header: 540, footer: 540 } };

const doc = new Document({
  creator: 'Phu Bao Nguyen, Quang Dat Tran',
  title: TITLE,
  styles: { default: { document: { run: { font: FONT, size: 20 } } } },
  footnotes: {
    1: { children: [new Paragraph({ alignment: AlignmentType.JUSTIFIED, children: [new TextRun({ text: 'Draft submitted for review on November 9, 2026. This work is a student scientific research project supervised by Huynh Nam, MSc in Information Systems. P. B. Nguyen and Q. D. Tran are with the Faculty of Information Technology, Industrial University of Ho Chi Minh City, Ho Chi Minh City, Vietnam (e-mail: [to be added]).', size: 16 })] })] },
  },
  sections: [
    { properties: { page }, headers: { default: header }, children: front },
    { properties: { page, type: SectionType.CONTINUOUS, column: { count: 2, space: 360 } }, headers: { default: header }, children: content },
  ],
});

Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync(path.join(HERE, 'draft_paper.docx'), buf);
  console.log('ok equations=' + eqNo + ' figures=' + figNo + ' tables=' + tabNo + ' refs=' + citeOrder.length);
});
