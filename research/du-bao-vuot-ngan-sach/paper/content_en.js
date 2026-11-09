// English text of the paper. Markup: $...$ math (mini-LaTeX), [@key] citation, *x* italic, **x** bold.
// Numbers in Sections V-VI come from ../experiment/results/{berka,berka_nofixed,berka_rows12000,tabformer,synthetic,
// bootstrap,bootstrap_tabformer,m1_compare,m1_compare_tabformer}.json.
'use strict';

exports.title = 'Median, Exponential Smoothing, and Quantile Regression Forecasts for Early Warning of Budget Overruns';
exports.authors = 'Quang Dat Tran, Phu Bao Nguyen, and Nam Huynh';
exports.header = 'STUDENT SCIENTIFIC RESEARCH, INDUSTRIAL UNIVERSITY OF HO CHI MINH CITY, DRAFT, NOVEMBER 2026';
exports.runhead = 'TRAN *et al.*: FORECASTS FOR EARLY WARNING OF BUDGET OVERRUNS';
exports.footnote = 'Draft submitted for review on November 9, 2026. This work is a student scientific research project at the Industrial University of Ho Chi Minh City. Q. D. Tran and P. B. Nguyen are students, and N. Huynh is a lecturer, with the Faculty of Information Technology, Industrial University of Ho Chi Minh City, Ho Chi Minh City, Vietnam (e-mail: [to be added]).';

exports.build = ({ add, body, H1, H2, EQ, bullet, FIG, TABLE, LABELED, REFLIST, r }) => {
  add(LABELED('Abstract', 'Budget warnings in personal finance applications usually compare the amount spent with the budget, which reacts only after the money is gone, or project spending linearly, which misreads users who pay rent early in the month. This study estimates, on any day of a budget period, the probability that spending will exceed the budget by the period end, and how early that probability can trigger a warning. We compare a pro-rata baseline, the median spending-rhythm rule of the FlowMoney mobile application, an exponentially weighted moving average of daily spending, and a linear quantile regression trained on all users. Evaluation uses a rolling origin, five checkpoints per month, and three budget levels on the PKDD-99 Berka bank data (4,051 accounts, 1993 to 1998), IBM synthetic card transactions (1,518 users, 2015 to 2020), and a simulated population. On the bank data the median rule has the lowest Brier score at the neutral budget (0.169 against 0.172), while quantile regression is the best calibrated. On the card data quantile regression and the moving average beat the median rule (0.148 and 0.149 against 0.166), and quantile regression catches 77% of overruns a median of 12 days ahead with at most 10% false alarms; on the bank data every forecaster catches about one in five. Quantile regression also wins on the bank data once fixed payments are removed, and on the simulated population. The median rule suits spending dominated by fixed payments; a pooled quantile model suits card-like spending, and both run on the phone.'));
  add(LABELED('Impact Statement', 'A budget warning helps only if it comes early enough to change spending and rarely enough to be believed. This study turns the risk of an overrun into a probability and measures how many overruns can be caught at a given false-alarm rate and how many days ahead. Allowing one false alarm in ten months that do not overrun, about one overrun in five is caught five days ahead on 1990s bank accounts, where a month holds a few large payments. On synthetic card spending from 2015 to 2020, three in four are caught 12 days ahead. The median rule that FlowMoney already runs matches a learned quantile model on the bank data and falls behind it on the card data. The learned model is better calibrated on both and needs only a few coefficients, so either can run on the phone without sending transactions to a server.'));
  add(LABELED('Index Terms', 'Budget overrun, early warning, exponentially weighted moving average, personal finance management, probabilistic forecasting, quantile regression.', 160));

  // I
  add(H1('Introduction'));
  add(body(r`Weak financial planning has measurable costs for households [@lusardi]. People tend to treat money in per-period mental accounts, such as the money set aside for this month's food [@thaler], and a monthly budget in a personal finance application follows the same idea. Reminders sent at the right moment have been shown to change financial behaviour [@karlan], so the timing of a budget warning is part of whether it works.`, { dropCap: true }));
  add(body(r`One simple warning is a threshold alert that fires when spending reaches a fixed share of the budget, such as 80% or 100%. It looks only at what has been spent. Another is a linear projection: if 40% of the month has passed and 60% of the budget is gone, the user is spending too fast. The projection fails for anyone whose spending is front-loaded. A user who pays rent on the first day looks over budget at every early checkpoint and soon ignores the warning.`));
  add(body(r`FlowMoney, the offline-first personal finance application built by our team, learns a *spending rhythm* for each budget from the three to six most recent closed periods that contain spending. For each elapsed share of the period it takes the median, over those periods, of the share of spending already reached and of the amount still to be spent. The current pace is labelled slow, on track, or fast using a band of five percentage points around that rhythm, and until three periods are available the application assumes even spending. The median is not thrown off by one unusual month. It gives a point forecast, though, not a probability, and six past periods allow only a coarse empirical distribution.`));
  add(body(r`This paper asks whether a probabilistic forecast gives better early warnings. A probability $p_{t}=P(S_{T}>B\mid\F_{t})$ that end-of-period spending $S_{T}$ exceeds the budget $B$ can be scored with proper scoring rules [@gneitingR] and checked for calibration [@gneitingC]. It also lets the application set its alert threshold to trade false alarms against lead time. The study addresses three research questions:`));
  add(bullet(r`RQ1: Which forecaster gives the best calibrated and sharpest overrun probabilities?`));
  add(bullet(r`RQ2: At a fixed false-alarm rate, how many days earlier than the baselines can each forecaster warn of an overrun?`));
  add(bullet(r`RQ3: How do budget tightness and the regularity of a user's spending change the ranking?`));
  add(body(r`This paper makes four contributions. We set up budget-overrun warning as probabilistic forecasting of the remaining spend and evaluate both the probabilities and the alerts they trigger. We compare four forecasters on public bank data, synthetic card data, and a synthetic population, including the median rhythm already used in a deployed application, and we check our implementation of that rule against the application's code. We find that the deployed median rule is as accurate as a learned quantile model on the bank data, where fixed payments dominate, and clearly less accurate on the card data, and that calibration is its weak point on all three. Finally, we give a guideline for computing the forecast on the phone without sending transactions to a server.`));
  add(body(r`Section II reviews related work, Section III defines the problem, and Section IV describes the forecasters. Section V covers the data and the evaluation protocol, and Section VI reports and discusses the results. Section VII covers the integration into FlowMoney and Section VIII the remaining work. Section IX concludes.`));

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
  add(body(r`M1 is the rule behind FlowMoney's pace label and end-of-period projection. For each of the user's $K$ most recent closed periods with positive spending ($3\le K\le6$), let $r_{k}(x)=S_{T}^{(k)}-S^{(k)}(x)$ be the amount spent after elapsed share $x$. The point forecast $r_{t}^{med}$ is the median of $r_{k}(x_{t})$ over $k$, so one unusual month has little effect, and the application projects $S_{t}+r_{t}^{med}$. The application shows no probability. We add one by treating the same $K$ values as an empirical predictive distribution, smoothed as in (3):`));
  add(EQ(r`p_{t}=\frac{\sum_{k=1}^{K}{\one[S_{t}+r_{k}(x_{t})>B]}+1/2}{K+1}.`));
  add(body(r`With $K\le6$ this probability takes at most seven values. When fewer than three periods are available the application assumes even spending, and we use M0.`));
  add(H2('M2: EWMA Rate and Volatility'));
  add(body(r`M2 smooths the user's daily spending, including the current period up to day $t$, with one constant $\lambda\in(0,1]$ for both level and variance [@riskmetrics]:`));
  add(EQ(r`\mu_{d}=\lambda y_{d}+(1-\lambda)\mu_{d-1},`));
  add(EQ(r`v_{d}=\lambda(y_{d}-\mu_{d-1})^{2}+(1-\lambda)v_{d-1}.`));
  add(body(r`If the $n=T-t$ remaining days are treated as independent, $R_{t}\sim N(n\mu_{t},nv_{t})$ and`, { noIndent: true }));
  add(EQ(r`p_{t}=1-\Phi(\frac{B-S_{t}-n\mu_{t}}{\sqrt{nv_{t}}}),`));
  add(body(r`where $\Phi$ is the standard normal distribution function. $R_{t}$ cannot be negative and is skewed to the right, so a log-normal form with the same mean and variance is planned as a variant. $\lambda$ is chosen from $\{0.001,0.002,0.005,0.01,0.02,0.05,0.1,0.2\}$ on the validation months. M2 has no notion of calendar effects such as rent on day one, so we expected it to do poorly on front-loaded spending and to adjust fastest when habits change.`, { noIndent: true }));
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
  add(body(r`The main data set is the PKDD-99 financial data released by a Czech bank [@berka], obtained from a public mirror of the challenge files. It has 1,056,320 transactions on 4,500 accounts from January 1993 to December 1998, plus account, loan, and standing-order tables. Spending is every debit transaction except bank charges (statement fees and penalty interest). It is summed per day, and calendar months serve as budget periods. An account starts in the first full month after it was opened, and accounts with fewer than 18 months are dropped, which leaves 4,051 accounts. The data are lumpy: the median account-month has spending on only two days, mostly cash withdrawals and standing payments, and 6.6% of account-months have no spending at all. Amounts are in Czech koruna and vary widely between accounts, so every model works with ratios to the budget. A sensitivity analysis removes loan repayments and household standing payments, which are fixed monthly obligations.`));
  add(H2('Synthetic Card Transactions'));
  add(body(r`The second data set is IBM's synthetic credit card data, released with the TabFormer models [@padhi] and produced by IBM's card transaction generator [@altman]. It holds 24,386,900 transactions of 2,000 users from 1991 to February 2020, each with a date, a time of day, an amount, a merchant category, and a fraud label. We keep January 2015 to January 2020, since February 2020 is incomplete. Spending is every transaction with a positive amount that is not marked as fraud, so refunds (5.1% of rows) are dropped, and a user's cards are pooled. Users spanning fewer than 18 months are dropped, as are 27 users whose spending stops before the last month, which leaves 1,518 users. Over the whole file the median user-month has 78 transactions on 29 days, the median coefficient of variation of a user's monthly totals is 0.24, and payments of the same amount in the same merchant category recurring in at least six months make up 16.8% of spending. The data are generated, so they show how the forecasters behave on frequent card spending but say nothing direct about real users.`));
  add(H2('Synthetic Population'));
  add(body(r`Real data cannot show why a forecaster wins, so we also generate 2,000 synthetic users over 36 months, 500 for each spending pattern. A1 users spend steadily every day. A2 users are front-loaded and pay 30-45% of the month on day one. A3 users spend in a burst after payday on day ten. A4 users make a large unplanned purchase in about 15% of months. Each user's spending level drifts slowly. Because the generating process is known, the results can be read against the patterns.`));
  add(H2('Budget Construction'));
  add(body(r`The public data have no budgets. FlowMoney suggests a budget from the user's spending over the last 90 days (or since the first transaction, if that is shorter), converted to a monthly rate. We use its calendar equivalent and set the budget of month $m$ to $B_{m}=\kappa(S_{m-1}+S_{m-2}+S_{m-3})/3$, where $S_{m}$ is the total spending of month $m$ and $\kappa\in\{0.9,1.0,1.1\}$. The three levels give a tight, a neutral, and a loose budget, and so different overrun rates.`));
  add(H2('Evaluation Protocol'));
  add(body(r`Evaluation uses a rolling origin over calendar months [@tashman]. For evaluation month $m$, each forecaster sees only data from before $m$ plus the current month up to the checkpoint, and M3 is refitted on all users' data from before $m$. The first 20% of evaluable months tune $\lambda$ for M2 and are not reported: months before November 1995 for the bank data, months before June 2016 for the card data, and months 6 to 11 for the synthetic population. Forecasts are made on days 5, 10, 15, 20, and 25, and checkpoints where the budget is already exceeded are left out. A split that holds out 30% of users entirely is planned for the final version.`));
  add(H2('Metrics'));
  add(body(r`Table II lists the metrics. Probability quality is measured by the Brier score`));
  add(EQ(r`\text{BS}=\frac{1}{N}\sum_{i=1}^{N}{(p_{i}-o_{i})^{2}},`));
  add(body(r`the logarithmic loss with probabilities clipped to $[10^{-3},1-10^{-3}]$, the area under the ROC curve, and the expected calibration error over ten equal-frequency bins,`, { noIndent: true }));
  add(EQ(r`\text{ECE}=\sum_{b=1}^{10}{\frac{N_{b}}{N}|O_{b}-P_{b}|},`));
  add(body(r`where $N_{b}$ is the number of forecasts in bin $b$, and $O_{b}$ and $P_{b}$ are the observed overrun frequency and the mean forecast probability in that bin. Reliability diagrams show the same comparison bin by bin. For warnings, each threshold $p^{*}$ on a grid of step 0.02 gives a false-alarm rate (the share of user-months without an overrun that receive at least one alert), a recall, and a median lead time (2). Tables report the threshold with the highest recall among those whose false-alarm rate is at most 10%.`, { noIndent: true }));
  add(TABLE('Evaluation Metrics', [1500, 2640, 900],
    ['Metric', 'Question answered', 'Better'],
    [
      ['Brier score, log loss', 'Is the probability accurate overall?', 'lower'],
      ['ECE, reliability diagram', 'When it says 30%, do overruns happen 30% of the time?', 'lower'],
      ['AUC', 'Are overrun months ranked above the rest?', 'higher'],
      ['Recall at fixed false-alarm rate', 'What share of overruns get a warning?', 'higher'],
      ['Median lead time', 'How many days ahead is the warning?', 'higher'],
    ], null, 'LLC'));
  add(H2('Statistical Comparison and Implementation'));
  add(body(r`Brier scores are first averaged per user so that users with long histories do not dominate. Each difference between two forecasters is reported with a 95% confidence interval from 2,000 bootstrap resamples of users [@efron]. The experiments use Python 3.13 with NumPy, pandas, SciPy, and the quantile regression of scikit-learn with the HiGHS solver; one run with three budget levels takes about eight minutes on a laptop for either the bank or the card data. The Python version of M1 follows FlowMoney's Dart code (median over at most six periods with spending, fallback below three), and Section VI-E checks it against that code. Two shortcuts keep the runs short. M3 is refitted every six months on a random subsample of 4,000 earlier rows; with 12,000 rows its Brier score on the bank data at $\kappa=1.0$ moves only from 0.1716 to 0.1707, so the subsample does not change the ranking. M2 uses the Gaussian form only. Code, seeds, and results are kept in the project repository.`));

  // VI
  add(H1('Results and Discussion'));
  add(H2('Hypotheses'));
  add(body(r`Three hypotheses were written before any experiment was run.`));
  add(bullet(r`H1 (RQ1). M3 has the lowest Brier score and calibration error overall. M1 is close in point accuracy, but its probabilities are coarse because they take at most $K+1$ values.`));
  add(bullet(r`H2 (RQ2). At a 10% false-alarm rate, M1 and M3 warn several days earlier than M0 for front-loaded users. M2 does poorly on front-loaded spending but adapts fastest after a change in habits.`));
  add(bullet(r`H3 (RQ3). The differences are largest in mid-month and for tight budgets, and the forecasters converge by day 25.`));
  add(H2('Results on the Bank Data'));
  add(body(r`At $\kappa=1.0$ there are 478,778 scored forecasts over 120,358 account-months, and 27.8% of them belong to months that end in an overrun. M1 fell back to M0 for 0.9% of them. For M2, $\lambda=0.002$ gave the lowest validation Brier score (0.207), which corresponds to a half-life of about a year. Table III gives the scores.`));
  add(TABLE('Results on the Bank Data (κ = 1.0)', [900, 520, 560, 500, 520, 620, 600, 820],
    ['Method', 'Brier', 'Log loss', 'AUC', 'ECE', 'FAR', 'Recall', 'Lead time (days)'],
    [
      ['M0', '0.180', '0.540', '0.720', '0.066', '0.080', '0.20', '5'],
      ['M1', '0.169', '0.512', '0.760', '0.062', '0.042', '0.21', '5'],
      ['M2', '0.211', '0.627', '0.657', '0.116', '0.096', '0.17', '6'],
      ['M3', '0.172', '0.515', '0.761', '0.040', '0.096', '0.20', '5'],
    ],
    r`All checkpoints pooled. FAR, recall, and median lead time at the threshold with the highest recall whose false-alarm rate is at most 10%; M1's next threshold jumps to a rate of 10.2%.`));
  add(body(r`M1 has the lowest Brier score (0.169) and log loss (0.512), and M3 is close behind (0.172 and 0.515) with almost the same AUC (0.761 against 0.760). Averaged per user, M3 minus M1 is 0.0018 in Brier score, with a 95% interval of 0.0010 to 0.0025, so the median rule is better by a small but significant margin; M3 is better for 49% of users. Both are clearly better than M0, by 0.008 (M3) and 0.010 (M1), with intervals well away from zero. M2 is the worst on every measure, and its Brier score does not improve between day 5 and day 15 (0.228 and 0.230) while every other forecaster improves.`));
  add(body(r`Fig. 3 shows the calibration. M3 follows the diagonal up to a forecast of about 0.4 and overstates the risk above it (forecasts near 0.78 are followed by an overrun 50% of the time). M0 and M1 overstate high risks less (0.77 against 0.58) but are uneven at low probabilities because they take only seven values. M2 understates the lowest risks and overstates the rest.`));
  add(TABLE('Brier Score / ECE by Budget Level, With and Without Fixed Payments', [700, 720, 720, 720, 720, 720, 720],
    ['Method', 'All, κ=0.9', 'All, 1.0', 'All, 1.1', 'No fixed, 0.9', 'No fixed, 1.0', 'No fixed, 1.1'],
    [
      ['M0', '.197/.068', '.180/.066', '.166/.052', '.199/.076', '.183/.069', '.171/.061'],
      ['M1', '.176/.060', '.169/.062', '.157/.060', '.186/.089', '.177/.086', '.167/.085'],
      ['M2', '.228/.103', '.211/.116', '.189/.113', '.208/.091', '.196/.101', '.181/.100'],
      ['M3', '.183/.046', '.172/.040', '.153/.032', '.181/.034', '.170/.036', '.155/.030'],
    ],
    r`"No fixed" removes loan repayments and household standing payments from spending. Overrun base rates: 34.1%, 27.8%, 23.3% (all) and 30.7%, 26.4%, 23.2% (no fixed).`));
  add(body(r`Table IV shows how the ranking moves. M1 has the lowest Brier score at the tight and neutral budgets, and M3 at the loose budget (0.153 against 0.157). M3 has the lowest calibration error in all six settings. When loan repayments and household standing payments are removed, M3 has the lowest Brier score at all three levels while M1 gets worse (0.177 against 0.169 at $\kappa=1.0$). The advantage of the median rule on the full data therefore seems to come from fixed payments that repeat at the same point of every month, which the median of past periods captures directly.`));
  add(body(r`Fig. 4 shows the warning trade-off. Early warning is hard on this data for every forecaster: at a false-alarm rate of at most 10%, recall is 17% to 21% and the median lead time is five or six days (Table III). M1 has the highest recall over most of the range; at a false-alarm rate of about 11% it catches 33% of overruns, against 22% for M3, and at about 24% it catches 50%, against about 42%. The median lead time reaches ten days only at false-alarm rates above 50%.`));
  add(FIG('fig3_reliability.png', 300, 291, r`Reliability diagrams at day 15 on the bank data ($\kappa=1.0$), ten equal-frequency bins. The dashed line is perfect calibration.`));
  add(FIG('fig4_warning.png', 300, 291, r`Warning trade-off on the bank data ($\kappa=1.0$): (a) recall and (b) median lead time against the false-alarm rate as $p^{*}$ varies.`));
  add(H2('Results on the Card Data'));
  add(body(r`At $\kappa=1.0$ the card data give 310,973 scored forecasts over 65,734 user-months, 44.3% of them in months that end in an overrun, and M1 fell back to M0 for 0.02% of them. $\lambda=0.01$ was selected (validation Brier 0.151). Table V gives the scores. The ranking is the reverse of the bank data. M3 is the best on every measure, but M2 is close behind (Brier 0.148 against 0.149, AUC 0.864 against 0.863), and both are well ahead of M1 and M0. The order holds at the tight budget (Brier 0.138, 0.139, 0.155, and 0.168 for M3, M2, M1, and M0), at the loose budget (0.124, 0.125, 0.139, and 0.166), and at every checkpoint. Averaged per user, M3 minus M1 is $-0.0177$ in Brier score (95% interval $-0.0184$ to $-0.0171$), and M3 is better for 94% of users. M2 beats M1 by 0.017 (interval 0.016 to 0.017), and M1 beats M0 by 0.012.`));
  add(TABLE('Results on the Card Data (κ = 1.0)', [900, 520, 560, 500, 520, 620, 600, 820],
    ['Method', 'Brier', 'Log loss', 'AUC', 'ECE', 'FAR', 'Recall', 'Lead time (days)'],
    [
      ['M0', '0.177', '0.538', '0.812', '0.062', 'n/a', 'n/a', 'n/a'],
      ['M1', '0.166', '0.501', '0.828', '0.030', '0.062', '0.68', '9'],
      ['M2', '0.149', '0.454', '0.863', '0.024', '0.098', '0.78', '12'],
      ['M3', '0.148', '0.450', '0.864', '0.005', '0.089', '0.77', '12'],
    ],
    r`Same layout as Table III. M0 has no threshold that raises any alert at a false-alarm rate of at most 10%.`));
  add(body(r`M3 is almost perfectly calibrated (ECE 0.005 at $\kappa=1.0$ and at most 0.005 at every budget level; Fig. 5). M1 overstates risks between about 0.3 and 0.8, M2 understates low risks and overstates high ones, and M0 overstates the risk throughout its upper range. Warnings work far better than on the bank data (Fig. 6). At a false-alarm rate of at most 10%, M2 and M3 catch 78% and 77% of overruns with a median of 12 days to spare, against 68% and nine days for M1. M0 raises no alert in that range. At a false-alarm rate of 2%, M3 still catches 60% of overruns eight days ahead and M2 about 54%, while M1 raises no alert.`));
  add(FIG('fig5_reliability.png', 300, 291, r`Reliability diagrams at day 15 on the card data ($\kappa=1.0$).`));
  add(FIG('fig6_warning.png', 300, 291, r`Warning trade-off on the card data ($\kappa=1.0$).`));
  add(H2('Results on the Synthetic Population'));
  add(body(r`The synthetic run gives 225,889 scored forecasts at $\kappa=1.0$, 44% of them in months that end in an overrun; $\lambda=0.01$ was selected. Table VI gives the scores. Here M3 is the most accurate at every budget level (Brier 0.120, 0.125, and 0.103 for $\kappa$ = 0.9, 1.0, and 1.1) and at every checkpoint, with calibration error below 0.02. Per user, M3 beats M1 by 0.013 (95% interval 0.013 to 0.014), while M1 and M0 do not differ significantly (interval -0.001 to 0.001).`));
  add(TABLE('Results on the Synthetic Population (κ = 1.0)', [900, 520, 560, 500, 520, 620, 600, 820],
    ['Method', 'Brier', 'Log loss', 'AUC', 'ECE', 'FAR', 'Recall', 'Lead time (days)'],
    [
      ['M0', '0.138', '0.434', '0.879', '0.042', 'n/a', 'n/a', 'n/a'],
      ['M1', '0.138', '0.429', '0.881', '0.045', '0.044', '0.78', '9'],
      ['M2', '0.172', '0.504', '0.850', '0.105', '0.097', '0.81', '13'],
      ['M3', '0.125', '0.387', '0.903', '0.017', '0.098', '0.87', '13'],
    ],
    r`Same layout as Table III. M0 has no threshold that raises any alert at a false-alarm rate of at most 10%.`));
  add(body(r`By spending pattern, M2 is the weakest on front-loaded users (Brier 0.240 on A2, against 0.096 to 0.110 for the others) and slightly beats M3 on steady spenders (0.131 against 0.135 on A1). M0 beats M1 on A2 (0.099 against 0.110): as defined in (3), M0 learns its error ratios from past periods, so it also captures day-one rent. Warnings are far easier than on the bank data; at a false-alarm rate of about 10%, M3 catches 87% of overruns with a median of 13 days to spare (Fig. 8).`));
  add(FIG('fig7_reliability.png', 300, 291, r`Reliability diagrams at day 15 on the synthetic population ($\kappa=1.0$).`));
  add(FIG('fig8_warning.png', 300, 291, r`Warning trade-off on the synthetic population ($\kappa=1.0$). M0 and M1 have only seven probability levels, so their curves have few points.`));
  add(H2('Agreement With the Application Code'));
  add(body(r`To check that the evaluated M1 is the rule the application runs, we drew 20,000 random forecasts with $K\ge3$ from each of the bank and card data and ran FlowMoney's Dart function on them, unchanged. The application places each transaction in the period by the moment it was entered, while our Python code adds a day's spending at the end of that day. With every transaction placed at 23:59:59, the two agree in all 40,000 cases on $K$, on $r_{t}^{med}$, on the median spent share, and on the overrun decision. Placed at midnight instead, 18.8% of the bank cases differ in $r_{t}^{med}$ and 2.9% in the decision. With the real times of day in the card data, 57.5% differ, by a median of 1.0% of the budget, and 2.1% of the decisions change. The probability (4) and the application's projection lead to the same decision ($p_{t}>0.5$ against $S_{t}+r_{t}^{med}>B$) whenever $K$ is odd. For even $K$ the median averages the two middle values, and the decisions differ in 5.6% of bank cases and 6.7% of card cases.`));
  add(H2('Hypotheses Revisited'));
  add(body(r`H1 holds on the card data and on the synthetic population but not on the bank data, where M1 is slightly more accurate than M3. The calibration part of H1 holds on all three: M3 has the lowest calibration error in every setting. H2 is not supported on the bank data, where at a 10% false-alarm rate M1 and M3 warn no earlier than M0 (five and four days against five). On the card data M0 raises no alert at that rate while M3 warns a median of 12 days ahead, but the card users are not front-loaded, so this does not test the claim as written. M2 does fail on front-loaded spending, as expected, and also on the lumpy bank data, while on the card data it nearly matches M3. H3 is contradicted. On the bank data M3 gains as the budget gets looser, not tighter, and M1 is at least as accurate as M3 at every checkpoint, with the largest gap at day 20 (0.141 against 0.146). On the card data the gap between M3 and M1 stays between 0.017 and 0.019 from day 5 to day 25 instead of closing, and it is about the same at every budget level (0.015 to 0.018).`));
  add(body(r`Our generator spends a little every day with smooth noise, which suits a pooled model that reads the spent share and the elapsed share. Bank accounts in the Berka data spend on about two days a month, and much of that is the same standing payment every month. A median over the account's own past months captures that structure directly, while a single linear model shared by all accounts does not. The card users spend on most days and repeat only a sixth of their spending, and there the pooled model wins as it does on our generator, with the EWMA, which follows the daily level, almost as good. Across the three data sets, M1 beats M3 only where a large part of spending is the same payment at the same point of each month.`));
  add(H2('Threats to Validity'));
  add(body(r`The Berka customers are Czech bank clients from the 1990s, and their spending is lumpier than that of a user who records daily purchases in an app. The budgets are constructed, not chosen by users. Debits include transfers that are not consumption. An offline evaluation cannot show how users respond to a warning; a warning may prevent the overrun it predicts, so the measured lead time describes the forecaster and says nothing about its effect on behaviour. The card data are synthetic: they describe the users of IBM's generator, whose spending is smoother than the bank data and possibly smoother than real card holders. The Python version of M1 matches the Dart code exactly only when transactions sit at the end of their day, and with real entry times about 2% of decisions differ. $\lambda$ was chosen from a grid of eight values, and every run uses a single random seed.`));

  // VII
  add(H1('Integration Into FlowMoney'));
  add(body(r`The results do not name a single engine. On the bank data M1 is as accurate as M3 and gives the highest recall at low false-alarm rates; on the card data M3 is better on every measure and warns three days earlier, and M2, which keeps only two running averages per user, comes close to it. M1 needs no training and already runs on the phone, where FlowMoney keeps all transactions in an SQLite database and syncs with its server in the background. Its weak point is calibration, which matters if the probability is shown to the user as a percentage. A cautious path is to keep M1 as the default and to map its seven probability levels to observed overrun rates measured on earlier months, a step not tested here, so that the percentage on screen can be taken at face value. M3 becomes the better choice once the application has enough of its own data to show that its users spend like the card users rather than like the bank customers. The overrun probability would be recomputed when a transaction is saved and during the daily background scan that drives the existing notifications, shown next to the pace label, and notified once per period the first time $p_{t}$ crosses $p^{*}$, with a per-period de-duplication key like the application's other reminders. M3's coefficients can be trained offline and shipped as generated constants, as the application already does for the weights of its question router, so no transaction leaves the phone. This study does not change any application code; the integration is a recommendation.`));

  // VIII
  add(H1('Remaining Work'));
  add(TABLE('Schedule', [1000, 4040],
    ['Date (2026)', 'Task'],
    [
      ['Nov. 9', 'Design; bank, card, and synthetic runs; sensitivity analyses; bootstrap intervals; check of M1 against the Dart code; wider λ grid (done).'],
      ['Nov. 10', 'Log-normal M2.'],
      ['Nov. 11', 'User hold-out split; monthly M3 refits with larger samples.'],
      ['Nov. 12', 'Recalibration of M1 probabilities on earlier months.'],
      ['Nov. 13', 'Tables per checkpoint and budget level; several seeds; reference check.'],
      ['Nov. 14', 'Final paper.'],
    ], null, 'LL'));

  // IX
  add(H1('Conclusion'));
  add(body(r`This paper sets up early warning of budget overruns as probabilistic forecasting of the remaining spend and compares four forecasters, from a pro-rata rule to quantile regression trained on all users, on public bank data, synthetic card data, and a synthetic population. On the bank data the median rhythm rule that FlowMoney already uses is slightly more accurate than quantile regression and gives the best warnings. On the card data, on the synthetic population, and on bank spending without fixed payments, quantile regression wins, and it is the best calibrated everywhere. How early a warning can come depends on the data: about one overrun in five is caught a few days ahead on the bank data at a 10% false-alarm rate, and three in four, 12 days ahead, on the card data. Our implementation of the median rule reproduces the application's code. For the application, this means keeping the median rule for now, calibrating its probabilities before showing them to users, and moving to the quantile model if its own users turn out to spend like the card users.`));

  add(H1('References', false));
  add(REFLIST());
};
