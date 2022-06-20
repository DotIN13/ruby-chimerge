# ChiMerge

My previous implementation of ChiMerge is hurried and flawed, moreover I was not able to replicate the results in the original work (Kerber, 1992). So I decided to dig a bit deeper, and try to understand how ChiMerge works and the best practices for its implementation.

## An algorithm for discretization

ChiMerge is an algorithm designed for data discretization. Its main characteristics are as follows:

1. A bottom-up merging algorithm. Common discretization algorithms are top-down, in other words, we designate grouping criteria first and conduct binning accordingly. ChiMerge starts its way from data tuples, or data intervals, and merge adjacent ones recursively until discrete intervals with different class distributions are formed. Thus, knowledge on the nature of the original dataset is no longer compulsory before discretization, which renders headless partitioning and experimenting unnecessary.
2. A class-based discretization method. The ChiMerge method requires class information provided for each data example as the reference for merging. As a result, the ChiMerge algorithm would perform better on datasets with continuous data attributes associated with a *discrete class attribute*, which would better be a natural and random class description for the data examples.

## The ChiMerge algorithm

ChiMerge depends on Chi-Square independence tests to determine whether to merge adjacent data intervals. After recursive Chi-Square tests and merging, data can be stratified into wider-spanning intervals with similar in-group class distributions.

The procedures of the algorithm are rather simple and straight forward. Do notice that discretization happens only on one attribute and other data attributes are ignored during the process.

1. Choose one data attribute to discretize with ChiMerge. Also identify one class attribute as the reference for merging.
2. Place all data examples in their own intervals, and count the frequencies of all different classes for every interval.
3. Conduct Chi-Square tests on each pair of adjacent intervals.
4. Merge adjacent intervals with the lowest Chi-Square value.
5. If the stopping criteria are not met, repeat step 3 and 4, otherwise stop the merging process. Usually the stopping criteria consists of a minimum and maximum interval number, and the merging Chi-Square value threshold.

The fundamental logic for the algorithm lies in the relationship between intervals and their class distributions. To be specific, if the difference of intervals are independent of the class distribution, or in other words, the difference of intervals is not a result of the difference in class distributions, the two intervals can be merged into one stratum. On the opposite, if the intervals and classes are correlated, then the different class distributions is responsible for the difference in intervals, and thus the two intervals should remain separate. And this is why ChiMgerge depends on Chi-Square tests, which provides a way to measure independence.

## The side effects of varying merging order

However, a few critical details are not explicitly available in Kerber's (1992) work. For instance, it is not discussed whether we should merge all intervals with lowest Chi-Square values in each round, or recalculate and re-evaluate Chi-Square values after every merge. And it is also not documented how an extremely low expected frequency should be handled during the Chi-Square tests.

Different orders of merging can result in vastly different discretization. According to Kerber's (1992) description, we repeat the merging and re-evaluation of Chi-Square values, one after another. But it is possible that we merge multiple intervals with the same Chi-Square values in one round. To illustrate, we have the following options when conducting merges:

1. Calculate Chi-Square values → Merge the pair with the lowest value → Calculate the missing values → Merge again
2. Calculate Chi-Square values → Recursively merge pairs of intervals with the lowest Chi-Square value → Calculate the missing values → Merge recursively again

However, an interval might be merged to a different cluster depending on whether we merge recursively in each round. The underlying issue can be better illustrated by a simple example:

```log
Interval 1: 1, 1, 8 (2.0)
Interval 2: 0, 1, 1 (2.3)
Interval 3: 5, 2, 10 (2.0)
Interval 4: 25, 4, 22
```

If we merge recursively, every two intervals would get merged, and the final result would look like:

```log
Interval 1: 1, 2, 9 (5.6)
Interval 2: 30, 6, 32
```

However, if we re-evaluate Chi-Square values every merge, interval 1, 2 and 3 are likely to be merged in two rounds, resulting in the following discretization:

```log
Interval 1: 6, 4, 19 (6.3)
Interval 2: 25, 4, 22
```

Aesthetically in the above example we would want the first three intervals to be merged, as distribution `[5, 2, 10]` is closer to `[1, 2, 9]`, but not `[25, 4, 22]`. Even though the situation where multiple interval pairs generate identical Chi-Square values is rather rare, varying or even unwelcome results might still be produced if batch merging is not handled with care.

Besides, the merging sequence can also be significant if we reverse the order of the intervals in the example. When merging from interval 4 to interval 1, The lower two intervals would have been merged in the first round, producing undesired results.

The different results of different merging orders undermine the presumptions of ChiMerge as a supervised discretization process. The ChiMerge is supervised, but not automatically controlled. The merging is after all bottom-up and free from predefined grouping criteria, so the results can and will vary depending on the methods and ordering adopted. Intensive experimenting on merging procedure and criteria should be conducted to obtain satisfactory discretization results.

## Expected frequency threshold necessary for Chi-Square tests

When we conduct a Chi-Square test, The expected frequency might get so small that it would impair the robustness of the Chi-Square test (Preacher, 2001). On the one hand, it is important to ensure that the expected frequency not be zero, as it is used as denominator in the formula. On the other hand, the Chi-Square test is generally considered inaccurate if the expected frequency is too low, or by value lower than 5.

In cases where the expected frequencies are too small, there is a high probability where the denominator is overwhelmed by its numerator, and hence generating a very large Chi-Square value, or in other words, a smaller p-value. McDonald (2014) claimed that a sample too small would likely to produce a P-value only 54% of that of a Fisher's exact test.

For example, two intervals with class distribution `[0, 2, 2]` and `[3, 0, 2]` can easily produce a Chi-Square value of 4.9, or in p-value less than 0.10, indicating that the two intervals should remain separate. In practice, it is rather common to have a lot of null or small values in the early phase of merging, and the inaccurate Chi-Square values might bring more interval orphanage, segregating intervals could have been merged otherwise.

As a counter measure, the expected frequency threshold is set to a positive value, that is, whenever the expected frequency is below the threshold, use the threshold value instead. For instance, Lisette Espin (2016) suggested a value of 0.5 in her implementation of ChiMerge, and managed to prevent surprisingly large Chi-Square values and produce more consistent discretization.

## Conclusions

The ChiMerge is only special because it is a bottom-up implementation, which allows data scientists to perform data stratification without extensive knowledge of the data attributes.

That said, ChiMerge still is sensitive to details, and require manual tweaking nonetheless. A different merging order can produce radically different results, and small expected frequencies could generate inaccurate ones. Data mining is an automatic knowledge discovery process as Jiawei Han described it when comparing to OLAP. But I propose that automatic thing are still invented by human. It is still the researcher's responsibility to ensure the consistency of the discretization by fine-tuning crucial criteria including the merging order, the Chi-Square threshold, the expected frequency threshold, and others to come.

## Bibliography

Espin, L. (2016). Pychimerge [Computer Software]. Available online at: [https://github.com/lisette-espin/pychimerge](https://github.com/lisette-espin/pychimerge).

Kerber, R. (1992, July). Chimerge: Discretization of numeric attributes. In Proceedings of the tenth national conference on Artificial intelligence (pp. 123-128).

McDonald, J. H. (2014). Handbook of Biological Statistics (3rd ed.). Baltimore, Sparky House Publishing. Available online at: [http://www.biostathandbook.com/small.html](http://www.biostathandbook.com/small.html)

Preacher, K. J. (2001). Calculation for the Chi-square test. An Interactive Calculation Tool for Chi-Square Tests of Goodness of Fit and Independence [Computer Software]. Ohio State University. Available online at: [http://www.quantpsy.org/chisq/chisq.htm](http://www.quantpsy.org/chisq/chisq.htm).

## Appendix: ChiMerge Results

Sepal length:

```log
############################################
# Data column 0 discretized with ChiMerge
# Rounds elapsed: 21
# Max interval: 6
# Chi threshold: 4.61
# Expected frequency threshold: 0.5
# Batch merged: true
++++++++++++++++++++++++++++++++++++++++++++
# [4.3..5.4]: [45, 6, 1], chi: 30.91
# [5.5..5.7]: [4, 15, 2], chi: 6.68
# [5.8..6.2]: [1, 15, 10], chi: 4.67
# [6.3..7.0]: [0, 14, 25], chi: 5.94
# [7.1..7.9]: [0, 0, 12], chi: nil
############################################
```

Sepal width:

```log
############################################
# Data column 1 discretized with ChiMerge
# Rounds elapsed: 19
# Max interval: 5
# Chi threshold: 4.61
# Expected frequency threshold: 0.5
# Batch merged: true
++++++++++++++++++++++++++++++++++++++++++++
# [2.0..2.4]: [1, 9, 1], chi: 4.71
# [2.5..2.9]: [1, 25, 20], chi: 17.09
# [3.0..3.3]: [18, 15, 24], chi: 24.19
# [3.4..4.4]: [30, 1, 5], chi: nil
############################################
```

Petal length

```log
############################################
# Data column 2 discretized with ChiMerge
# Rounds elapsed: 10
# Max interval: 5
# Chi threshold: 4.61
# Expected frequency threshold: 0.5
# Batch merged: true
++++++++++++++++++++++++++++++++++++++++++++
# [1.0..1.9]: [50, 0, 0], chi: 94.92
# [3.0..4.7]: [0, 44, 1], chi: 37.34
# [4.8..5.1]: [0, 6, 15], chi: 10.9
# [5.2..6.9]: [0, 0, 34], chi: nil
############################################
```

Petal width:

```log
############################################
# Data column 3 discretized with ChiMerge
# Rounds elapsed: 8
# Max interval: 5
# Chi threshold: 4.61
# Expected frequency threshold: 0.5
# Batch merged: true
++++++++++++++++++++++++++++++++++++++++++++
# [0.1..0.6]: [50, 0, 0], chi: 78.0
# [1.0..1.3]: [0, 28, 0], chi: 5.93
# [1.4..1.7]: [0, 21, 5], chi: 48.36
# [1.8..2.5]: [0, 1, 45], chi: nil
############################################
```
