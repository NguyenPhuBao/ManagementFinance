// English text of the draft paper. Markup: $...$ math (mini-LaTeX), [@key] citation, *x* italic, **x** bold.
'use strict';

exports.title = 'Research and Development of Probabilistic Forecasting Models Based on Median, EWMA, and Quantile Regression for Early Warning of End-of-Period Budget Overruns in Personal Finance Management Applications';
exports.authors = 'Phu Bao Nguyen and Quang Dat Tran';
exports.header = 'STUDENT SCIENTIFIC RESEARCH, INDUSTRIAL UNIVERSITY OF HO CHI MINH CITY, DRAFT, NOVEMBER 2026';
exports.footnote = 'Draft submitted for review on November 9, 2026. This work is a student scientific research project supervised by Huynh Nam, MSc in Information Systems. P. B. Nguyen and Q. D. Tran are with the Faculty of Information Technology, Industrial University of Ho Chi Minh City, Ho Chi Minh City, Vietnam (e-mail: [to be added]).';

exports.build = ({ add, body, H1, H2, EQ, bullet, FIG, FIGBOX, TABLE, LABELED, REFLIST, r }) => {
  add(LABELED('Abstract', 'A budget warning in a personal finance application can be built in two simple ways: an alert when a fixed share of the budget has been spent, or a linear projection of spending to the end of the month. The first reacts after the money is gone. The second misreads users who pay rent or recurring bills early in the month. This study estimates, on any day of a budget period, the probability that spending will exceed the budget by the end of the period, and measures how early that probability can trigger a useful warning. The task is set up as probabilistic forecasting of the spending still to come. Four forecasters are compared: a pro-rata baseline, the median spending-rhythm model used in the FlowMoney mobile application, an exponentially weighted moving average of daily spending level and variance, and a linear quantile regression trained on all users with monotone rearrangement. They are evaluated on the public PKDD-99 Berka bank transaction data and on a synthetic population with known spending patterns, using rolling-origin evaluation at five checkpoints per month and three levels of budget tightness. The probabilities are scored with the Brier score, logarithmic loss, area under the receiver operating characteristic curve, and expected calibration error; the amounts with mean absolute error and pinball loss; and the warnings with recall and lead time in days at a fixed false-alarm rate. The paper also describes how the chosen forecaster can run on the phone in an offline-first application. This draft reports the study design, and results will be added in the final version.'));
  add(LABELED('Impact Statement', 'A budget warning helps only if it comes early enough to change spending and rarely enough to be believed. An alert at 100% of the budget comes too late to act on. A linear projection warns every month for a user who pays rent on the first day, and that user stops reading it. This study states the risk of an overrun as a calibrated probability, early in the month, with a known false-alarm rate. The methods are cheap enough to run on a phone, so transaction data does not have to leave the device. The comparison will show developers whether a simple median rule is enough or whether a learned quantile model is worth the extra work.'));
  add(LABELED('Index Terms', 'Budget overrun, early warning, exponentially weighted moving average, personal finance management, probabilistic forecasting, quantile regression.', 160));

  // I
  add(H1('Introduction'));
  add(body(r`Weak financial planning has measurable costs for households [@lusardi]. People tend to treat money in per-period mental accounts, such as the money set aside for this month's food [@thaler], and a monthly budget in a personal finance application follows the same idea. Reminders sent at the right moment have been shown to change financial behaviour [@karlan], so the timing of a budget warning is part of whether it works.`));
  add(body(r`One simple warning is a threshold alert that fires when spending reaches a fixed share of the budget, such as 80% or 100%. It looks only at what has been spent. Another is a linear projection: if 40% of the month has passed and 60% of the budget is gone, the user is spending too fast. The projection fails for anyone whose spending is front-loaded. A user who pays rent on the first day looks over budget at every early checkpoint and soon ignores the warning.`));
  add(body(r`FlowMoney, the offline-first personal finance application built by our team, learns a *spending rhythm* for each budget from the three to six most recent closed periods that contain spending. For each elapsed share of the period it takes the median, over those periods, of the share of spending already reached and of the amount still to be spent. The current pace is labelled slow, on track, or fast using a band of five percentage points around that rhythm, and until three periods are available the application assumes even spending. The median is not thrown off by one unusual month. It gives a point forecast, though, not a probability, and six past periods allow only a coarse empirical distribution.`));
  add(body(r`This paper asks whether a probabilistic forecast gives better early warnings. A probability $p_{t}=P(S_{T}>B\mid\F_{t})$ that end-of-period spending $S_{T}$ exceeds the budget $B$ can be scored with proper scoring rules [@gneitingR] and checked for calibration [@gneitingC]. It also lets the application set its alert threshold to trade false alarms against lead time. The study addresses three research questions:`));
  add(bullet(r`RQ1: Which forecaster gives the best calibrated and sharpest overrun probabilities?`));
  add(bullet(r`RQ2: At a fixed false-alarm rate, how many days earlier than the baselines can each forecaster warn of an overrun?`));
  add(bullet(r`RQ3: How do budget tightness and the regularity of a user's spending change the ranking?`));
  add(body(r`This paper makes four contributions. We set up budget-overrun warning as probabilistic forecasting of the remaining spend and evaluate both the probabilities and the alerts they trigger. We compare four forecasters, including the median rhythm already used in a deployed application. A synthetic population with known spending patterns is used to explain which forecaster wins in which case. Finally, we give a guideline for computing the forecast on the phone without sending transactions to a server.`));
  add(body(r`Section II reviews related work, Section III defines the problem, and Section IV describes the forecasters. Section V covers the data and the evaluation protocol, Section VI the hypotheses and analysis plan, Section VII the integration into FlowMoney, and Section VIII the work plan. Section IX concludes.`));

  // II
  add(H1('Related Work'));
  add(H2('Exponential Smoothing'));
  add(body(r`Roberts introduced the exponentially weighted moving average (EWMA) for process monitoring [@roberts], and it became the basis of exponential smoothing forecasts [@holt], [@hunter]. RiskMetrics applies the same recursion to the variance of financial returns, so one smoothing constant tracks both level and volatility [@riskmetrics]. Hyndman and Athanasopoulos survey exponential smoothing and its prediction intervals [@hyndman]. EWMA adapts quickly and costs almost nothing to compute, which suits a phone. For our task its weak point is that it treats every day of the month alike.`));
  add(H2('Quantile Regression and Probabilistic Forecasts'));
  add(body(r`Quantile regression estimates conditional quantiles by minimising the check loss [@koenkerB], [@koenker]. Taylor combined it with exponential weighting to forecast the distribution of daily supermarket sales [@taylor], a problem close to ours, and quantile regression forests extend the method to non-linear models [@meinshausen]. Quantiles fitted separately can cross; monotone rearrangement removes the crossings without losing accuracy [@chernozhukov]. A probabilistic forecast should be calibrated and, given calibration, as sharp as possible [@gneitingC]. It is evaluated with strictly proper scores such as the Brier score [@brier] and the logarithmic score [@gneitingR]. Calibration is often summarised by the expected calibration error [@naeini], [@guo], and discrimination by the area under the ROC curve [@fawcett].`));
  add(H2('Forecast Evaluation'));
  add(body(r`Forecasts have to be evaluated out of sample and in time order. Rolling-origin evaluation refits or updates the model at each forecast origin using only earlier data [@tashman]. Two forecasters can be compared with the Diebold–Mariano test [@dm] or, when observations are grouped by user, with a bootstrap over users [@efron].`));
  add(body(r`The studies above evaluate forecasts of quantities. In this study the object being evaluated is a warning, so lead time is measured together with the quality of the probabilities.`));

  // III
  add(H1('Problem Formulation'));
  add(body(r`Consider one user and one budget period of $T$ days with budget $B>0$. Let $y_{d}\ge0$ be the amount spent on day $d$, $S_{t}=\sum_{d=1}^{t}{y_{d}}$ the cumulative spending after day $t$, and $x_{t}=t/T$ the elapsed share. The period ends in an overrun when $O=\one[S_{T}>B]$ equals one. At checkpoint $t$ the forecaster sees the information set $\F_{t}$, which holds the current period up to day $t$ and all of the user's earlier periods, and returns`));
  add(EQ(r`p_{t}=P(S_{T}>B\mid\F_{t})=P(R_{t}>B-S_{t}\mid\F_{t}),`));
  add(body(r`where $R_{t}=S_{T}-S_{t}\ge0$ is the spending still to come. Each forecaster in Section IV therefore outputs a predictive distribution of $R_{t}$. When $S_{t}>B$ the overrun has already happened; $p_{t}=1$ and the checkpoint is left out of probability scoring.`, { noIndent: true }));
  add(body(r`An alert is raised at the first checkpoint with $p_{t}\ge p^{*}$. Let $\tau_{O}$ be the first day on which $S_{d}>B$. For a period that ends in an overrun, the lead time of an alert raised on day $t_{a}$ is`));
  add(EQ(r`L=\tau_{O}-t_{a},`));
  add(body(r`and a positive $L$ means the warning came before the budget was exceeded. Fig. 1 shows the pipeline and Fig. 2 illustrates the problem at one checkpoint.`, { noIndent: true }));
  add(FIG('fig1_pipeline.png', 300, 265, r`Forecasting and warning pipeline. Each forecaster outputs a predictive distribution of the remaining spend, and the overrun probability and the alert decision are computed from it.`));
  add(FIG('fig2_problem.png', 320, 198, r`A hand-made series used for illustration (not real data): rent paid on day 1, a spike on day 10, and the 10-90% forecast band for end-of-month spending at checkpoint $t=12$.`));

  // IV
  add(H1('Methods'));
  add(body(r`Table I summarises the four forecasters, which use progressively more information.`));
  add(TABLE('Summary of the Four Forecasters', [1150, 1330, 1330, 1230],
    ['Method', 'Information used', 'Predictive output', 'On-device cost'],
    [
      ['M0 Pro-rata', 'own past periods', r`empirical, $K+1$ levels`, r`$O(K)$`],
      ['M1 Median rhythm', 'own last 3-6 periods', r`empirical, $K+1$ levels`, r`$O(K\cdot n)$`],
      ['M2 EWMA', 'own daily series', 'Gaussian or log-normal', r`$O(1)$ per day`],
      ['M3 Quantile regression', 'features + pooled training', '19 quantiles', r`$O(|\T|\cdot|\phi|)$`],
    ],
    r`$K$: number of usable past periods; $n$: transactions per period; $\T$: quantile levels; $\phi$: feature vector.`));
  add(H2('M0: Pro-Rata Baseline'));
  add(body(r`The pro-rata forecast assumes even spending over the period, $S_{T}^{pr}=S_{t}/x_{t}$. FlowMoney uses this assumption until it has learned a rhythm. To get a probability we use the multiplicative errors $e_{k}=S_{T}^{(k)}x_{t}/S^{(k)}(x_{t})$ observed in the user's past periods $k=1,\ldots,K$, where $S^{(k)}(x)$ is the cumulative spending of period $k$ at elapsed share $x$:`));
  add(EQ(r`p_{t}=\frac{\sum_{k=1}^{K}{\one[S_{t}e_{k}/x_{t}>B]}+1/2}{K+1}.`));
  add(H2('M1: Median Spending Rhythm'));
  add(body(r`M1 is the rule FlowMoney uses today. For each of the user's $K$ most recent closed periods with positive spending ($3\le K\le6$), let $r_{k}(x)=S_{T}^{(k)}-S^{(k)}(x)$ be the amount spent after elapsed share $x$. The point forecast $r_{t}^{med}$ is the median of $r_{k}(x_{t})$ over $k$, so one unusual month has little effect. The same $K$ values also form an empirical predictive distribution, smoothed as in (3):`));
  add(EQ(r`p_{t}=\frac{\sum_{k=1}^{K}{\one[S_{t}+r_{k}(x_{t})>B]}+1/2}{K+1}.`));
  add(body(r`With $K\le6$ this probability takes at most seven values. When fewer than three periods are available the application falls back to M0, and we report how often that happens.`));
  add(H2('M2: EWMA Rate and Volatility'));
  add(body(r`M2 smooths the user's daily spending, including the current period up to day $t$, with one constant $\lambda\in(0,1]$ for both level and variance [@riskmetrics]:`));
  add(EQ(r`\mu_{d}=\lambda y_{d}+(1-\lambda)\mu_{d-1},`));
  add(EQ(r`v_{d}=\lambda(y_{d}-\mu_{d-1})^{2}+(1-\lambda)v_{d-1}.`));
  add(body(r`If the $n=T-t$ remaining days are treated as independent, $R_{t}\sim N(n\mu_{t},nv_{t})$ and`, { noIndent: true }));
  add(EQ(r`p_{t}=1-\Phi(\frac{B-S_{t}-n\mu_{t}}{\sqrt{nv_{t}}}),`));
  add(body(r`where $\Phi$ is the standard normal distribution function. $R_{t}$ cannot be negative and is skewed to the right, so we also test a log-normal distribution with the same mean and variance. $\lambda$ is chosen from $\{0.02,0.05,0.1,0.2\}$ on the validation months. M2 has no notion of calendar effects such as rent on day one. We expect it to do poorly on front-loaded spending and to adjust fastest when habits change.`, { noIndent: true }));
  add(H2('M3: Pooled Linear Quantile Regression'));
  add(body(r`M3 is trained on all users together. Its target is the remaining spend scaled by the budget, $z=R_{t}/B$. The feature vector $\phi$ holds eight features and an intercept: the elapsed share $x_{t}$, the spent share $S_{t}/B$, the M1 forecast $r_{t}^{med}/B$, the M2 mean $n\mu_{t}/B$ and spread $\sqrt{nv_{t}}/B$, the share of past spending that fell in the remaining days of the month, the coefficient of variation of past monthly totals, and $K$. For each level $\tau\in\T=\{0.05,0.10,\ldots,0.95\}$ the coefficients minimise the check loss [@koenkerB]`));
  add(EQ(r`b_{\tau}=\text{arg min}_{\beta}\sum_{i}{\rho_{\tau}(z_{i}-\phi_{i}^{\top}\beta)},`));
  add(EQ(r`\rho_{\tau}(u)=u(\tau-\one[u<0]).`));
  add(body(r`The 19 predicted quantiles are sorted to remove crossings [@chernozhukov] and joined by linear interpolation, with flat tails, into a predictive distribution function $F_{t}$ of $z$. Then`, { noIndent: true }));
  add(EQ(r`p_{t}=1-F_{t}((B-S_{t})/B).`));
  add(body(r`On the phone, M3 needs 19 dot products of nine numbers each, and the application only has to ship the coefficients.`, { noIndent: true }));

  // V
  add(H1('Experimental Design'));
  add(H2('Data'));
  add(body(r`The main data set is the PKDD-99 financial data released by a Czech bank [@berka]. It has about one million transactions on 4,500 accounts from 1993 to 1998, plus account, loan, and standing-order tables. Debit transactions count as spending. They are summed per day, and calendar months serve as budget periods. Accounts with fewer than 18 months of history are dropped so that each evaluated month has at least six earlier months. Amounts are in Czech koruna and vary widely between accounts, so every model works with ratios to the budget. A sensitivity analysis removes loan repayments and household standing payments to separate fixed obligations from discretionary spending.`));
  add(H2('Synthetic Population'));
  add(body(r`Real data cannot show why a forecaster wins, so we also generate 2,000 synthetic users over 36 months, 500 for each spending pattern. A1 users spend steadily every day. A2 users are front-loaded and pay 30-45% of the month on day one. A3 users spend in a burst after payday on day ten. A4 users make a large unplanned purchase in about 15% of months. Each user's spending level drifts slowly. Because the generating process is known, calibration can be checked against the true overrun probability.`));
  add(H2('Budget Construction'));
  add(body(r`The public data have no budgets. FlowMoney suggests a budget from the user's spending over the last 90 days (or since the first transaction, if that is shorter), converted to a monthly rate. We use its calendar equivalent and set the budget of month $m$ to $B_{m}=\kappa(S_{m-1}+S_{m-2}+S_{m-3})/3$, where $S_{m}$ is the total spending of month $m$ and $\kappa\in\{0.9,1.0,1.1\}$. The three levels give a tight, a neutral, and a loose budget, and so different overrun rates.`));
  add(H2('Evaluation Protocol'));
  add(body(r`Evaluation uses a rolling origin over calendar months [@tashman]. For evaluation month $m$, each forecaster sees only data from before $m$ plus the current month up to the checkpoint. M3 is refitted on all users' data before $m$ with an expanding window. The constant $\lambda$ of M2 is tuned on the first 20% of evaluation months and then fixed. Forecasts are made on days 5, 10, 15, 20, and 25. In a second split, 30% of users are held out completely to measure how M3 does for a new user.`));
  add(H2('Metrics'));
  add(body(r`Table II lists the metrics. Probability quality is measured by the Brier score`));
  add(EQ(r`\text{BS}=\frac{1}{N}\sum_{i=1}^{N}{(p_{i}-o_{i})^{2}},`));
  add(body(r`the logarithmic loss with probabilities clipped to $[10^{-3},1-10^{-3}]$, the area under the ROC curve, and the expected calibration error over ten equal-frequency bins,`, { noIndent: true }));
  add(EQ(r`\text{ECE}=\sum_{b=1}^{10}{\frac{N_{b}}{N}|O_{b}-P_{b}|},`));
  add(body(r`where $N_{b}$ is the number of forecasts in bin $b$, and $O_{b}$ and $P_{b}$ are the observed overrun frequency and the mean forecast probability in that bin. Reliability diagrams show the same comparison bin by bin. The mean absolute error measures the median forecast of $R_{t}$, and the pinball loss averaged over $\T$ measures the full quantile forecast. For warnings, each forecaster's threshold $p^{*}$ is set so that 10% (and, separately, 20%) of user-months without an overrun receive at least one alert. At that false-alarm rate we report recall, precision, and the median lead time (2).`, { noIndent: true }));
  add(TABLE('Evaluation Metrics', [1500, 2640, 900],
    ['Metric', 'Question answered', 'Better'],
    [
      ['Brier score, log loss', 'Is the probability accurate overall?', 'lower'],
      ['ECE, reliability diagram', 'When it says 30%, do overruns happen 30% of the time?', 'lower'],
      ['AUC', 'Are overrun months ranked above the rest?', 'higher'],
      ['MAE, pinball loss', 'How close is the remaining-spend forecast?', 'lower'],
      ['Recall at fixed false-alarm rate', 'What share of overruns get a warning?', 'higher'],
      ['Median lead time', 'How many days ahead is the warning?', 'higher'],
    ], null, 'LLC'));
  add(H2('Statistical Comparison and Implementation'));
  add(body(r`Scores are first averaged per user so that users with long histories do not dominate. Each difference between two forecasters is reported with a 95% confidence interval from 2,000 bootstrap resamples of users [@efron], and the Diebold–Mariano test [@dm] serves as a secondary check. The experiments use Python with pandas and the quantile regression in statsmodels. The Python version of M1 will be checked against FlowMoney's Dart code on shared test vectors, so the baseline is the rule the application actually runs. Code, random seeds, and the synthetic generator are kept in the project repository.`));

  // VI
  add(H1('Expected Results and Analysis Plan'));
  add(body(r`The hypotheses below guide the analysis. They are expectations, not results.`));
  add(bullet(r`H1 (RQ1). M3 has the lowest Brier score and calibration error overall. M1 is close in point accuracy, but its probabilities are coarse because they take at most $K+1$ values.`));
  add(bullet(r`H2 (RQ2). At a 10% false-alarm rate, M1 and M3 warn several days earlier than M0 for front-loaded users (A2). M2 does poorly on A2 because rent on day one breaks its assumption that days are alike, but it adapts fastest after a change in habits.`));
  add(bullet(r`H3 (RQ3). The differences are largest in mid-month (days 10 to 20) and for tight budgets, and the forecasters converge by day 25.`));
  add(TABLE('Planned Results Table (to Be Filled)', [1130, 560, 560, 560, 560, 830, 840],
    ['Method', 'Brier', 'Log loss', 'AUC', 'ECE', 'Recall @10% FAR', 'Lead time (days)'],
    [['M0', '-', '-', '-', '-', '-', '-'], ['M1', '-', '-', '-', '-', '-', '-'], ['M2', '-', '-', '-', '-', '-', '-'], ['M3', '-', '-', '-', '-', '-', '-']],
    r`Berka data, $\kappa=1.0$, all checkpoints pooled. Tables per checkpoint and per spending pattern will use the same layout.`));
  add(FIGBOX('[Reliability diagrams of M0 to M3 at day 15: to be produced]', r`Planned: observed overrun frequency against forecast probability, one panel per forecaster.`));
  add(FIGBOX('[Median lead time against false-alarm rate: to be produced]', r`Planned: lead time against false-alarm rate as $p^{*}$ varies.`));
  add(body(r`Threats to validity. The Berka customers are Czech bank clients from the 1990s, and they do not spend like Vietnamese mobile-wallet users in 2026. The budgets are constructed, not chosen by users. Debits include transfers that are not consumption. An offline evaluation also cannot show how users respond to a warning. A warning may prevent the overrun it predicts, so the measured lead time describes the forecaster and says nothing about its effect on behaviour.`));

  // VII
  add(H1('Integration Into FlowMoney'));
  add(body(r`FlowMoney keeps all transactions in an SQLite database on the phone and syncs with its server in the background. M1 already runs on the device, and the proposed integration keeps everything there. The overrun probability is recomputed when a transaction is saved and during the daily background scan that drives the existing notifications. The budget screen shows the probability next to the pace label. A notification is sent once per period, the first time $p_{t}$ crosses $p^{*}$, with a per-period de-duplication key like the application's other reminders. The coefficients of M3 are trained offline and shipped as generated constants, the way the application already ships the weights of its learned question router, so no transaction leaves the phone. With fewer than three past periods the application falls back to M2 or M0. This study does not change any application code; the integration is a recommendation.`));

  // VIII
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

  // IX
  add(H1('Conclusion'));
  add(body(r`This paper sets up early warning of budget overruns as probabilistic forecasting of the remaining spend and designs a comparison of four forecasters, from a pro-rata rule to quantile regression trained on all users. The comparison measures both the quality of the probabilities and the lead time of the warnings. FlowMoney's median rhythm is the main baseline, so the results will show whether a learned probabilistic model warns users earlier, and with fewer false alarms, than the rule the application uses now.`));

  add(H1('Acknowledgment', false));
  add(body(r`The authors thank their supervisor, Huynh Nam, MSc in Information Systems, for his guidance on this study.`));
  add(H1('References', false));
  add(REFLIST());
};
