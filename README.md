# playlist_sorter_app

ローカル音楽ファイルをスワイプで仕分けし、プレイリストとして整理・エクスポートできる Flutter アプリです。

## 主な機能

- 音楽フォルダから曲を読み込み
- 曲を4方向にスワイプして振り分け
- カテゴリ名を自由に設定
- 再生プレビュー（Windowsでは Win32/MCI を利用）
- 音量調整機能を搭載
- 途中セーブやエクスポートに対応

## 動作環境

- Flutter 3.x / Dart 3.x
- Windows、macOS、Linux、Web を想定した構成
- 現状は Windows での音声再生を優先して検証しています

## セットアップ

```bash
git clone https://github.com/NieRTama/playlist_sorter_app.git
cd playlist_sorter_app
flutter pub get
```

## 実行方法

Windows で実行する場合:

```bash
flutter run -d windows
```

## iOS 用 IPA のビルド（Mac 不要）

GitHub Actions の macOS ランナーで署名なし IPA を作ります（`.github/workflows/ios-ipa.yml`）。

1. GitHub の Actions タブ →「iOS IPA (unsigned)」→「Run workflow」で実行（main への push や PR でも自動実行）
2. 完了した実行ページの Artifacts から `playlist_sorter-unsigned-ipa` をダウンロードして解凍
3. Windows で Sideloadly などを使い、自分の Apple ID で署名して iPhone にインストール

無料の Apple ID で署名した場合、アプリは 7 日で期限切れになるので再インストール（再署名）が必要です。
iOS 版は端末の「ミュージック」ライブラリから曲を読み込みます（DRM 付き / ストリーミングのみの曲は再生できません）。

## 使い方

1. 音楽フォルダを選択して曲を読み込み
2. カードをスワイプしてプレイリストに振り分け
3. 画面右上のスピーカーアイコンから音量を調節
4. 仕分けが完了したらエクスポート画面へ進む

## 既知の注意点

- Windows では `just_audio` の再生に問題があるため、`Win32 MCI` を使った補助再生を導入しています
- 日本語を含むファイル名やパスで再生が不安定になる可能性があります
- 環境により依存パッケージのバージョン調整が必要になる場合があります

## 主要ファイル構成

- `lib/main.dart`: アプリのエントリポイント
- `lib/screens/`: 各種画面 UI
- `lib/services/`: 音声再生、ファイル読み込み、エクスポート処理
- `lib/models/`: データモデル
- `lib/widgets/`: 再利用可能な UI コンポーネント

## GitHub

https://github.com/NieRTama/playlist_sorter_app

## ライセンス

このプロジェクトは MIT ライセンスの下で公開されています。詳細は `LICENSE` ファイルを参照してください。
