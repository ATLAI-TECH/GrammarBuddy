# Model outputs: zh

## zh-fix-1 · fix

Note: 主语残缺（通过……使）；有效的→有效地

Original:

> 通过这次实验，使我们了解到了温度对开花时间的影响，实验结果表明了低温处理能够有效的促进开花。

**google/gemma-4-e4b** (18.49 s, thinking 2399 chars, changed 11% of 46 words):

> 通过这次实验，我们了解了温度对开花时间的影响，实验结果表明低温处理能有效地促进开花。

**google/gemma-4-12b-qat** (33.82 s, thinking 2933 chars, finish=length, changed 100% of 46 words):

> 

## zh-fix-2 · fix

Note: 错别字：在加上→再加上，以经→已经；搭配：水平……改善→提高

Original:

> 他的写作水平有了明显的改善，在加上平时的努力，以经可以独立完成论文了。

**google/gemma-4-e4b** (11.4 s, thinking 1326 chars, changed 6% of 35 words):

> 他的写作水平有了明显的改善，再加上平时的努力，已经可以独立完成论文了。

**google/gemma-4-12b-qat** (34.76 s, thinking 3060 chars, finish=length, changed 100% of 35 words):

> 

## zh-fix-3 · fix

Note: 错别字：必需→必须，进渡→进度，即使→及时

Original:

> 我们必需在周五之前把报告交上去，否则会影响到项目的进渡，请大家即使回复。

**google/gemma-4-e4b** (18.6 s, thinking 2451 chars, changed 17% of 36 words):

> 我们必须在周五之前把报告交上去，否则会影响项目进度，请大家及时回复。

**google/gemma-4-12b-qat** (24.81 s, thinking 2213 chars, changed 11% of 36 words):

> 我们必须在周五之前把报告交上去，否则会影响到项目的进度，请大家及时回复。

## zh-fix-4 · fix

Note: 中英混排，保留 Col-0、FLC、[12]、P < 0.05；的地得

Original:

> 春化处理 30 天后，拟南芥 Col-0 中 FLC 的表达量明显的下降了约 50%（P < 0.05），这于前人的报道一至 [12]。

**google/gemma-4-e4b** (22.65 s, thinking 2851 chars, changed 8% of 38 words):

> 春化处理 30 天后，拟南芥 Col-0 中 FLC 的表达量明显的下降了约 50%（P < 0.05），这与前人的报道[12]。

**google/gemma-4-12b-qat** (33.19 s, thinking 2945 chars, finish=length, protected items missing: 0.05 30 50% Col-0 [12], changed 100% of 38 words):

> 

## zh-polish-1 · polish

Note: 口语化、啰嗦

Original:

> 这个方法我觉得还是挺好用的，然后就是它的速度也比较快，然后准确率的话也还可以，所以我们最后就决定用它了。

**google/gemma-4-e4b** (18.85 s, thinking 2473 chars, changed 56% of 52 words):

> 我认为这个方法非常实用，而且速度也很快。同时，其准确率表现良好，综合考虑这些因素后，我们最终决定采用它。

**google/gemma-4-12b-qat** (32.03 s, thinking 2815 chars, finish=length, changed 100% of 52 words):

> 

## zh-tone-1 · tone (formal)

Note: 口语改正式

Original:

> 老板，那个报告我明天给你行不行？今天实在搞不完了。

**google/gemma-4-e4b** (10.15 s, thinking 1456 chars, changed 80% of 25 words):

> 关于这份报告，我预计无法在今日完成。请问是否可以向您提交于明日？

**google/gemma-4-12b-qat** (21.67 s, thinking 1945 chars, changed 80% of 25 words):

> 领导，由于今日工作任务繁重，该报告未能如期完成，请问是否可以于明日提交？

## zh-en-1 · translate → English

Note: 学术；保留 Col-0、FLC、50%、P < 0.05、[12]

Original:

> 本研究发现，春化处理 30 天后，拟南芥 Col-0 中 FLC 的表达量下降了约 50%（P < 0.05），这与前人的报道一致 [12]。

**google/gemma-4-e4b** (10.56 s, thinking 1125 chars):

> This study found that after 30 days of vernalization treatment, the expression level of *FLC* in *Arabidopsis thaliana* Col-0 decreased by approximately 50% (P < 0.05), which is consistent with previous reports [12].

**google/gemma-4-12b-qat** (25.82 s, thinking 2651 chars):

> This study found that after 30 days of vernalization treatment, the expression level of FLC in Arabidopsis Col-0 decreased by approximately 50% (P < 0.05), which is consistent with previous reports [12].

## en-zh-1 · translate → Simplified Chinese

Note: 工作邮件；中文标点

Original:

> The committee has not yet reached a decision, but we expect to hear back by the end of next week. In the meantime, please do not share the draft outside the team.

**google/gemma-4-e4b** (13.77 s, thinking 1811 chars):

> 委员会尚未做出决定，但我们预计下周末前会得到回复。在此期间，请不要将这份草稿分享给团队以外的人。

**google/gemma-4-12b-qat** (16.27 s, thinking 1413 chars):

> 委员会尚未做出决定，但我们预计在下周末前会收到回复。在此期间，请不要将草案分享给团队以外的人。

## en-zh-2 · translate → Simplified Chinese

Note: 学术摘要；术语

Original:

> Vernalization, the acquisition of the competence to flower after prolonged cold, is mediated by epigenetic silencing of the floral repressor FLC in Arabidopsis thaliana.

**google/gemma-4-e4b** (14.12 s, thinking 1935 chars):

> 春化，即在长时间低温后获得开花能力，是通过拟南芥 *Arabidopsis thaliana* 中对花期抑制因子 FLC 的表观遗传沉默介导的。

**google/gemma-4-12b-qat** (31.2 s, thinking 3014 chars, finish=length):

> 
