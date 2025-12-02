;;; ========================================================================
;;;  開発メモ（現フェーズ総括）
;;; ========================================================================
;;;
;;;  tamago（EGG + Wnn）環境を現行 Emacs に適合させるための全体方針の中で、
;;;  本フェーズでは主に以下を目的としている：
;;;
;;;    - 廃止予定／非推奨関数 `str-as-*` 群の排除
;;;    - その互換実装としての `egg-str-as-*` 関数群の完全置換
;;;    - `encode-coding-string` / `decode-coding-string` を使用した
;;;      正規の符号化／復号処理への移行
;;;    - 旧版 `str-as-*` との動作一致性（compatibility）の保証
;;;
;;; ------------------------------------------------------------------------
;;;  今後の検討項目（構文・API レベル）
;;; ------------------------------------------------------------------------
;;;
;;;  (i) 旧 `inhibit-point-motion-hooks` の置換：
;;;       → `cursor-sensor-inhibit` と `cursor-sensor-mode` に移行するか、
;;;          あるいは `cursor-intangible-mode` を使うべきか要再検討。
;;;
;;;  (ii) `intangible` テキストプロパティの再確認：
;;;       → 現行 Emacs における非推奨化状況と代替仕様の把握が必要。
;;;
;;;  (iii) obarray の使用見直し：
;;;       → “貧弱なハッシュテーブル代用” として利用していた箇所を、
;;;          正式な `make-hash-table` / `gethash` / `puthash` 系 API に置換。
;;;
;;; ------------------------------------------------------------------------
;;;  現フェーズの主目的
;;; ------------------------------------------------------------------------
;;;
;;;  → `egg-str-as-*` 関数群が旧 `str-as-*` と同等に動作することを確認する。
;;;     特に、有効な文字列（対応コード系で正しく表現できる範囲）において
;;;     双方が同一の結果を返すことを確認する。
;;;
;;;  以下の拡張テストにより互換性検証を強化する：
;;;
;;;    (1) Round-trip 検証
;;;         decode → encode → decode の三段階で、
;;;         内容が恒等的に保持されるかを確認。
;;;
;;;    (2) Buffer I/O テスト
;;;         実際のバッファ書き出し (`write-region`) を経由して、
;;;         ファイルレベルの符号化／復号動作を検証。
;;;
;;;    (3) 複合文字セット拡充
;;;         EUC-TW, EUC-KR など、複数バイトセットの正確な扱いを確認。
;;;
;;;    (4) `egg-run-all-encoding-tests` の再統合
;;;         現状は簡略版 helper が部分利用されているため、
;;;         旧来の出力構造（スナップショット含む）を正式版に統一予定。
;;;
;;; ------------------------------------------------------------------------
;;;  コメント
;;; ------------------------------------------------------------------------
;;;
;;;  現状の印象としては、有効な文字列範囲においては既に
;;;  `egg-str-as-*` が旧 `str-as-*` と同等に動作している。
;;;  ただし invalid byte の扱い方（signal の種類や message 文言）など、
;;;  境界条件の比較テストは今後強化の余地がある。
;;;
;;;
;;; | Phase | Scope                                 | Key variable(s)                                            | Goal                                                         | 
;;;| ----- | ---------------------------- | --------------------------------------------- | ------------------------------------------------------------ |
;;;| (1)   | Round-trip                   | `egg-str-as-*`
;;;        | (encode/decode only)         | `egg-internal-mode`
;;;                                       | Confirm identical behavior of replacement functions
;;;| (2)   | Buffer I/O                   | `buffer-file-coding-system`,
;;;|       |                              |  `default-coding-system-for-*`
;;;                                       | Check file write/read consistency
;;;| (A')  | Dual-mode                    | `egg-internal-mode`
;;;|       | I/O (recommended extension)  | See if I/O behaves differently under emacs-internal vs utf-8 |
;;;|       |                              |
;;;| (D)   | Locale variation             | `set-locale-environment`
;;;|       | (optional extension)         | Check independence from system locale                        |
;;;| (3)   | Multi-byte charset coverage  | `euc-tw`, `euc-kr`, etc.
;;;                                       | Deep dive into complex CJK mappings                          |

;;; ========================================================================
;;;  End of Development Notes Section
;;; ========================================================================



コメント: 新しい emacs, 例 30.2, は不正なバイト列に対して寛容になってる。すぐにエラーをもどさない

その寛容になったことがファイルシステムのエラー、あるいはメディアの劣化
でデータが壊れてしまった場合のテキストや辞書の扱いにどういう結果をもた
らすかは不明。

ただし、単純なテキストの場合には、変換エラーがあったというような目立つ
文字を埋め込んでくるから読む側で気づけると思う。

具体的には以下でテストする。
(load "egg-integration-tests.el" のフルパス)

(egg-verify-all-extended-dual-mode-with-diff)

Note: もっと不正な文字列事例を増やした方がいいかもしれないが、肝心の
emacs 30.2 が error を戻さないので古い API と新しいAPIが正しい文字列場
合の挙動が同じ事に重点をおいて、あまり例を増やす事は労多くして益少なし
という事で現時点は簡単な事例で済ませている。）

============================================================
(B) 不正バイト列に対する挙動の検証
============================================================
目的

本セクションでは、各種文字エンコーディングにおいて不正なマルチバイト列
や混合バイト列を Emacs 標準デコーダと EGG の内部デコーダが同一の挙動を
示すかどうか を検証する。

対象とするのは以下のカテゴリである。

分類	内容
(B1)	純粋に不正な（デコード不能な）バイト列
(B2)	部分的に正しいシーケンス＋不正孤立バイトを含む列
(B3)	他エンコーディングの断片を混入させた混合列

各テストは共通関数 egg--test-invalid-bytes-common により駆動され、
Emacs 標準の decode-coding-string と
EGG 内部実装の egg-string-as-multibyte の結果を比較する。

比較結果は EGG-Log に以下のような形式で出力される：

[invalid-bytes:euc-jp] Both signaled error → [expected error OK]
[invalid-bytes:utf-8] Decoded identically → OK

これらの結果はそれぞれ次の意味を持つ：

Both signaled error → [expected error OK]
→ 標準／EGG 双方が同様にデコードエラーを報告した（期待どおり）。

Decoded identically → OK
→ 双方が同じ文字列として正常にデコードした。

MISMATCH ...
→ どちらか片方だけがエラーを出す、または異なる文字列を生成した（要調
査）。

(B1) 不正バイト列（単体／不完全）

各エンコーディングの「開始バイトのみ」や「中途で終わるマルチバイト列」を対象とする。

例：
(egg-test-invalid-bytes-euc-jp)   ;; (string #x8F #xA2)
(egg-test-invalid-bytes-euc-kr)   ;; (string #xA4)
(egg-test-invalid-bytes-euc-cn)   ;; (string #xA1)
(egg-test-invalid-bytes-euc-tw)   ;; (string #x8E)
(egg-test-invalid-bytes-utf-8)    ;; (string #xE3 #x81)   ← UTF-8版


これらのテストにより、各デコーダが「不完全シーケンス」を
例外として扱うか／代替文字列を生成するかを検証する。

(B2) 部分的に正しいシーケンス＋不正バイト列

冒頭部分に正しい文字を含み、末尾に孤立バイト（不正な部分）を持つケース。

例：

(egg-test-invalid-bytes-euc-jp-partial)  ;; (string #xA4 #xA2 #x8F)
(egg-test-invalid-bytes-euc-kr-partial)
(egg-test-invalid-bytes-euc-cn-partial)
(egg-test-invalid-bytes-euc-tw-partial)
(egg-test-invalid-bytes-utf-8-partial)   ;; (string #xC3 #x81 #xE3)

これにより、デコーダが部分的に有効な部分を正しくデコードした上で
不正部分で停止／置換するかを確認する。

(B3) 異種混合バイト列（他エンコーディングの断片混入）

他のエンコーディングの断片を意図的に挿入し、
誤検出や部分成功などの差異が発生しないかを検証する。

例：
(egg-test-invalid-bytes-euc-jp-mixed-sjis)  ;; EUC-JP中にSJIS断片 (#x82 #xA0)
(egg-test-invalid-bytes-euc-kr-mixed-sjis)
(egg-test-invalid-bytes-euc-cn-mixed-sjis)
(egg-test-invalid-bytes-euc-tw-mixed-sjis)
(egg-test-invalid-bytes-utf-8-mixed-sjis)   ;; UTF-8中にSJIS断片
(egg-test-invalid-bytes-utf-8-mixed-euc-jp) ;; UTF-8中にEUC断片

このカテゴリでは、異常バイトを含んでも Emacs と EGG の挙動が一致することを保証する。

ログ出力と整形

egg--integration-log 関数は出力整列のため、
「→ OK」部分が約50カラム目に位置するように自動調整される。
そのため EGG-Log は次のように読みやすく整列される：

[invalid-bytes:euc-jp] Decoded identically             → OK
[invalid-bytes:utf-8]  Both signaled error             → [expected error OK]
[egg-verify] pre-test-write-encode-fixed-euc-china     → OK   (0.000 sec)

実行と検証結果の解釈

全テストは (egg-run-integration-tests) により一括実行される。
*EGG-Log* の末尾に以下のような統計情報が表示される。

[SECTION INTERNAL] Total elapsed time: 0.013 sec
[SECTION UTF-8]     Total elapsed time: 0.142 sec
[Dual-mode summary] mismatch: 0


mismatch: 0 が示されれば、全コーディング系において
Emacs 標準と EGG の挙動が完全に一致していることを意味する。

============================================================
(C) エンコード／デコード双方向整合性テスト（予定）
============================================================
概要

セクション (C) では、実際の 往復変換テスト を行う。
すなわち：

あるコーディングで encode-coding-string によりバイト列を生成し、

それを同じコーディングで decode-coding-string（および EGG 相当処理）で戻す。

このとき、

元の文字列と復元後の文字列が一致するか

Emacs 標準と EGG がともに一致した結果を返すか
を検証する。

さらに、UTF-8・EUC・SJIS 間のクロスコンバージョン（例：UTF-8→SJIS→UTF-8）についても
同様の往復整合性を確認する予定である。

次のステップ

(C1) 単純往復整合性（同一コーディング内）

(C2) 異種エンコーディング変換（UTF-8 ↔ EUC-JP, SJIS など）

(C3) 内部文字表現 (egg-internal-mode) のON/OFF差異比較

これらを順に構築していく。





