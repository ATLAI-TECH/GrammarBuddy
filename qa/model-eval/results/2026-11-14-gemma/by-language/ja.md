# Model outputs: ja

## ja-fix-1 · fix

Note: 面白いでした→面白かったです

Original:

> 昨日は友達と映画を見に行きましたが、とても面白いでした。

**google/gemma-4-e4b** (13.88 s, thinking 2100 chars, changed 11% of 28 words):

> 昨日は友達と映画を見に行きましたが、とても面白かったです。

**google/gemma-4-12b-qat** (11.91 s, thinking 1177 chars, changed 11% of 28 words):

> 昨日は友達と映画を見に行きましたが、とても面白かったです。

## ja-fix-2 · fix

Note: い抜き言葉・文体の混在（しめしてる／なりました）

Original:

> この実験の結果は、温度が開花時期に大きな影響をあたえることをしめしてる。前回の報告と同じ結果になりました。

**google/gemma-4-e4b** (12.89 s, thinking 1633 chars, changed 8% of 53 words):

> この実験の結果は、温度が開花時期に大きな影響を与えることを示している。前回の報告と同じ結果になりました。

**google/gemma-4-12b-qat** (32.65 s, thinking 3214 chars, finish=length, changed 100% of 53 words):

> 

## ja-fix-3 · fix

Note: しているです→しています、思うです→思います

Original:

> 私は日本語を三年間勉強しているですが、まだ敬語が難しいと思うです。

**google/gemma-4-e4b** (15.18 s, thinking 2094 chars, changed 12% of 33 words):

> 私は日本語を三年間勉強していますが、まだ敬語が難しいと思います。

**google/gemma-4-12b-qat** (30.48 s, thinking 2743 chars, changed 12% of 33 words):

> 私は日本語を三年間勉強していますが、まだ敬語が難しいと思います。

## ja-en-1 · translate → English

Note: 敬语的商务邮件

Original:

> お世話になっております。先日ご依頼いただいた資料を添付いたしますので、ご確認のほどよろしくお願いいたします。

**google/gemma-4-e4b** (15.1 s, thinking 2304 chars):

> Thank you for your continued support. I have attached the documents that you requested the other day, so please take a look when you have a moment.

**google/gemma-4-12b-qat** (30.88 s, thinking 4244 chars, finish=length):

> 

## en-ja-1 · translate → Japanese

Note: 应为です・ます体或敬语

Original:

> Thank you for your email. I will check the schedule and get back to you by tomorrow afternoon.

**google/gemma-4-e4b** (13.55 s, thinking 1886 chars):

> メールをいただきありがとうございます。スケジュールを確認し、明日午後に改めてご連絡いたします。

**google/gemma-4-12b-qat** (13.71 s, thinking 1408 chars):

> メールをいただきありがとうございます。スケジュールを確認し、明日の午後までにご連絡いたします。
