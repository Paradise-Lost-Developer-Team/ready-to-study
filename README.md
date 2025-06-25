# Ready to Study - 高校生学習支援アプリ

2025年度の高校教育課程に完全対応した、包括的な学習支援アプリケーションです。

## 機能概要

### 📚 対応教科（2025年度）
- **国語** - 現代文、古文、漢文
- **数学** - 数学I、数学II、数学III、数学A、数学B、数学C
- **英語** - 英語コミュニケーションI・II・III、論理・表現I・II・III
- **理科** - 物理基礎・物理、化学基礎・化学、生物基礎・生物、地学基礎・地学
- **社会** - 地理総合・地理探究、歴史総合・日本史探究・世界史探究、公共・政治経済・倫理
- **情報** - 情報I
- **その他** - 芸術科目、体育・保健

### 🎯 主要機能
- **学習進捗管理** - 各教科の学習状況を可視化
- **問題演習システム** - 教科別の問題集と自動採点
- **スケジュール管理** - 定期テスト・模試対策のスケジューリング
- **成績分析** - 苦手分野の特定と学習計画の提案
- **学習記録** - 日々の学習時間と内容の記録
- **リマインダー機能** - 課題期限や復習タイミングの通知

## 技術仕様
- **フロントエンド**: Streamlit (Webインターフェース)
- **バックエンド**: Python 3.11+
- **データベース**: SQLite (ローカル) / PostgreSQL (本番環境)
- **データ分析**: pandas, matplotlib, seaborn
- **機械学習**: scikit-learn (学習パターン分析)

## セットアップ

### 💻 ローカル開発環境

```bash
# 依存関係のインストール
pip install -r requirements.txt

# データベースの初期化
python scripts/init_database.py

# アプリケーションの起動
streamlit run app.py
```

### 🐧 openSUSE Leap サーバー自動起動設定

```bash
# 1. 実行権限を設定
chmod +x install-autostart-service.sh service-manager.sh health-check.sh

# 2. サービスのインストールと自動起動設定
sudo ./install-autostart-service.sh

# 3. システム再起動後の動作確認
sudo reboot
# 再起動後
./health-check.sh

# 4. サービス管理
./service-manager.sh status    # 状態確認
./service-manager.sh logs      # ログ確認
./service-manager.sh restart   # 再起動
```

### 🌐 アクセス方法
- **ローカル**: http://localhost:8501
- **ネットワーク**: http://[サーバーIP]:8501

### 🛠️ サービス管理コマンド

```bash
# サービス制御
sudo systemctl start ready-to-study     # 開始
sudo systemctl stop ready-to-study      # 停止
sudo systemctl restart ready-to-study   # 再起動
sudo systemctl status ready-to-study    # 状態確認

# ログ確認
sudo journalctl -u ready-to-study -f    # リアルタイムログ

# 便利なスクリプト
./service-manager.sh help               # ヘルプ表示
./health-check.sh                       # システム状態確認
```

## 🔧 トラブルシューティング

### Python環境の問題

#### Python 3.8未満・Streamlit動作問題
```bash
# 【推奨】改良版Python環境修復スクリプト
sudo bash fix-python-env-v2.sh

# 従来版の修復スクリプト
sudo bash fix-python-env.sh
```

#### 仮想環境の問題
```bash
# 仮想環境の確認
ls -la /opt/ready-to-study/venv/bin/

# Streamlitの存在確認
sudo -u ready-to-study /opt/ready-to-study/venv/bin/pip list | grep streamlit

# 手動でStreamlit再インストール
sudo -u ready-to-study /opt/ready-to-study/venv/bin/pip install streamlit==1.28.0
```

### 環境診断とヘルスチェック

#### 総合診断ツール
```bash
# サーバー環境の総合診断（システム、Python、サービス、ネットワーク）
sudo bash server-diagnosis.sh

# 基本ヘルスチェック
sudo bash health-check.sh

# クイック修復
sudo bash quick-fix.sh
```

### サービス関連の問題

#### サービスが起動しない
```bash
# 1. 環境診断で問題特定
sudo bash server-diagnosis.sh

# 2. サービス状態確認
sudo systemctl status ready-to-study

# 3. 詳細ログ確認
sudo journalctl -u ready-to-study -n 50

# 4. 一括修復実行
sudo bash quick-fix.sh
```

#### ポート8501にアクセスできない
```bash
# ポート確認
sudo netstat -tlnp | grep 8501
# または
sudo ss -tlnp | grep 8501

# ファイアウォール確認・設定
sudo firewall-cmd --query-port=8501/tcp
sudo firewall-cmd --permanent --add-port=8501/tcp
sudo firewall-cmd --reload
```

### 権限関連の問題

#### ファイル・ディレクトリの権限エラー
```bash
# 権限の一括修復
sudo bash set-permissions.sh

# 手動権限設定
sudo chown -R ready-to-study:ready-to-study /opt/ready-to-study
sudo chmod +x /opt/ready-to-study/venv/bin/streamlit
```

### 定期メンテナンス

#### システム更新
```bash
# openSUSE Leapのシステム更新
sudo zypper update

# Python環境の更新（必要に応じて）
sudo bash fix-python-env-v2.sh
```

#### データベースバックアップ
```bash
# データベースのバックアップ
sudo -u ready-to-study cp /opt/ready-to-study/data/study_app.db /opt/ready-to-study/data/study_app.db.backup.$(date +%Y%m%d)
```

### よくある問題と解決方法

| 問題 | 症状 | 解決方法 |
|------|------|----------|
| Python古い | `ModuleNotFoundError: No module named 'streamlit'` | `sudo bash fix-python-env-v2.sh` |
| 権限エラー | `Permission denied` | `sudo bash set-permissions.sh` |
| ポート使用中 | `Address already in use` | `sudo systemctl restart ready-to-study` |
| サービス停止 | アクセスできない | `sudo bash quick-fix.sh` |
| メモリ不足 | アプリが遅い | サーバーリソース確認、再起動 |

### サポートツール一覧

- `server-diagnosis.sh` - 総合環境診断
- `fix-python-env-v2.sh` - Python環境修復（改良版）
- `fix-python-env.sh` - Python環境修復（従来版）
- `health-check.sh` - 基本ヘルスチェック
- `quick-fix.sh` - 自動修復
- `service-manager.sh` - サービス管理
- `set-permissions.sh` - 権限修復

### ログの確認方法

```bash
# リアルタイムログ
sudo journalctl -u ready-to-study -f

# 最新ログ（50行）
sudo journalctl -u ready-to-study -n 50

# エラーログのみ
sudo journalctl -u ready-to-study -p err

# 特定日時のログ
sudo journalctl -u ready-to-study --since "2024-01-01 09:00:00" --until "2024-01-01 18:00:00"
```