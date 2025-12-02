;; ----------------------------------------------------------------------
;;; [開発メモ] 現フェーズまとめ  (2025-10-11)
;;; ----------------------------------------------------------------------
;; このメモは egg-integration-tests の第3フェーズ (dual-mode 拡張および
;; self-verifying test harness) の成果と設計意図を記録する。
;; 実行対象: Emacs 29.3+ / UTF-8 環境前提。そのあとemacs 30.2
;;
;; ----------------------------------------------------------------------
;; 【目的】
;;   - 文字コード処理の二重モード (internal-mode=ON/OFF) 双方における
;;     encode/decode 一貫性検証を自動化。
;;   - Invalid byte sequence を含むケースの挙動をロギング・可視化。
;;   - デバッグフラグや default/buffer coding の各組み合わせを包括的に走査。
;;
;; ----------------------------------------------------------------------
;; 【新規/変更関数】
;;
;; 1. egg--verify-wrapper
;;    - 各テスト関数呼び出しを標準化し、OK/NG のログ出力を統一。
;;    - テスト単位での実行時間を計測。
;;
;; 2. egg-verify-all-extended-dual-mode-with-diff
;;    - 旧 egg-verify-all-dual-mode を拡張。
;;    - internal-mode (t/nil) 切替えを自動で行い、総括レポートを生成。
;;    - invalid-bytes 系テストを追加し、re-encode の再一致を検証。
;;    - 「Decoded identically」「Re-encode mismatch」など詳細ログ出力対応。
;;
;; 3. egg-run-all-config-combinations
;;    - dual-mode 検証をさらに多軸展開。
;;    - internal/debug/default/buffer coding の組み合わせごとにセクション分離。
;;    - 各構成ごとの NG 件数と elapsed time を自動集計しログに出力。
;;
;; ----------------------------------------------------------------------
;; 【ログ出力仕様】
;;
;; *EGG-Log* に次の構造で出力される：
;;
;;   [YYYY-MM-DD HH:MM:SS] ==== [EGG TEST CONFIGURATION SNAPSHOT] ====
;;   egg-internal-mode              : t
;;   egg-string-as-debug-flag       : t
;;   egg-default-coding             : utf-8
;;   buffer-file-coding-system      : utf-8
;;   -------------------------------------------
;;   ==== Running tests with egg-internal-mode=ON (emacs-internal) ====
;;   ...
;;   [SUMMARY] elapsed=0.045s, NG=0
;;   ==== END CONFIG ====
;;
;; NG は "→ NG" をカウントすることで集計。詳細な不一致点は既存 diff 機構により別途出力。
;;
;; ----------------------------------------------------------------------
;; 【デバッグ補助】
;;
;; (setq egg-string-as-debug-flag t)
;;   → encode/decode の詳細比較 ("Decoded identically", "Re-encode mismatch") を常時出力。
;;
;; (setq egg-internal-mode nil)
;;   → 外部 UTF-8 経路での再現性確認。
;;
;; (setq egg-default-coding 'euc-jp)
;; (setq buffer-file-coding-system 'euc-jp)
;;   → 非 UTF-8 パスでのテスト用。
;;
;; ----------------------------------------------------------------------
;; 【今後の展開】
;;
;; - (A) NG レポートの自動要約 (summary view buffer)
;; - (B) test-case レベルでの diff 保存機能 (再現比較)
;; - (C) CI 向けバッチ実行 (非対話 emacs -batch 用)
;; - (D) locale 切替えによる system-coding-system レベルの影響比較
;;
;; ----------------------------------------------------------------------
;;; End of current phase memo
;;; ----------------------------------------------------------------------

シンボル vs 関数オブジェクト
egg--verify-wrapper は呼出を柔軟にしています。tests リストはシンボルの一覧にしておくと管理しやすいです（上の egg-run-all-encoding-tests でもシンボルを列挙しています）。

既存のテスト登録との整合性
もし将来 egg--integration-tests にまとめてあるテストをそのまま使いたいなら、egg-run-all-encoding-tests を次のように書き換えれば egg--integration-tests の中からフィルタして実行できます（必要ならその実装も示します）。

ログの整列
egg--integration-log が各行を出しているため、ログの整列（→ OK を固定列に揃える）は format のフィールド幅の設定でずいぶん揃います。上の %-40s を変えれば列幅の調整が可能です。

既存の「defalias」や「余分な test-pre-test 関数」
それらは混乱の元なので、削除かコメントアウトしておくのが良いです（既にコメントにしたとのことでしたが念のため）。
