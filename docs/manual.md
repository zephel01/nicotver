# nicotver インストール・使い方マニュアル

## 概要

nicotver は、TVer の再生ページ上にニコニコ実況の過去ログコメントを流す Chrome 拡張です。

このリポジトリ（zephel01/nicotver）は、nyankomaher さんの [nyankomaher/nicotver](https://github.com/nyankomaher/nicotver) の fork です。2026年10月時点の TVer のページ構造の変更に対応する修正を加えています。元の作者による公式版ではありません。

- 元のリポジトリ: https://github.com/nyankomaher/nicotver
- コメント取得元: ニコニコ実況 過去ログ API（https://jikkyo.tsukumijima.net/ ）
- コメント描画: [niconicomments](https://github.com/xpadev-net/niconicomments)（MIT License）

### 元リポジトリからの変更点

`src/nicotver.ts` のみを変更しています。

| 箇所 | 変更前 | 変更後 |
| --- | --- | --- |
| 操作フォームの挿入先（`getTitles()`） | `[class^=titles_container]` | `[class*=EpisodeDescription_root]`（旧セレクタはフォールバック） |
| 放送局・放送日の取得（`getProgramInfo()`） | `[class^=description_metaDetail]` の1番目／2番目 | `[class*=EpisodeDescription_producer]` / `[class*=EpisodeDescription_broadcastDateLabel]`。要素が無くても例外にしない |

## インストーラーで入れる（かんたん）

Node.js の用意、ソースの取得、ビルドまでを自動で行うインストーラーを用意しています。管理者権限は不要です。

Chrome の仕様で、拡張機能の読み込みだけは自動化できません。インストーラーの実行後に、表示される手順に従って一度だけ読み込んでください。

インストーラーが行うこと:

1. Node.js 18 以上が入っていればそれを使い、無ければ Node.js 22 LTS を nodejs.org からダウンロードします（SHA256 を SHASUMS256.txt と照合します）。
2. ソースを取得します（git があれば `git clone` / `git pull`、無ければ GitHub から main の ZIP をダウンロード）。
3. `npm install --ignore-scripts` とビルドを行います。
4. ビルド結果を決まったフォルダ（拡張機能フォルダ）にコピーし、そのフォルダを開きます。

もう一度実行すると、同じ場所に最新版で上書き更新されます。

### Windows

1. GitHub のリポジトリページで「Code」→「Download ZIP」を押してダウンロードし、展開します。
2. `installer\windows\install.bat` をダブルクリックします。
   「WindowsによってPCが保護されました」と表示された場合は、「詳細情報」→「実行」を押してください。
3. 完了すると拡張機能フォルダがエクスプローラーで開き、読み込み手順が表示されます。

| 用途 | 場所 |
| --- | --- |
| 拡張機能フォルダ（ブラウザに読み込む） | `%LOCALAPPDATA%\nicotver\extension` |
| ソース | `%LOCALAPPDATA%\nicotver\src` |
| ダウンロードした Node.js（必要な場合のみ） | `%LOCALAPPDATA%\nicotver\node` |

PowerShell から直接実行することもできます。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\installer\windows\install.ps1
```

### Mac

ターミナルで次の1行を実行します。

```sh
curl -fsSL https://raw.githubusercontent.com/zephel01/nicotver/main/installer/mac/install.sh | bash
```

または、リポジトリの ZIP を展開して `installer/mac/install.command` をダブルクリックします。開けないと表示された場合は、ターミナルで `bash installer/mac/install.sh` を実行してください。

完了すると拡張機能フォルダが Finder で開き、読み込み手順が表示されます。

| 用途 | 場所 |
| --- | --- |
| 拡張機能フォルダ（ブラウザに読み込む） | `~/Library/Application Support/nicotver/extension` |
| ソース | `~/Library/Application Support/nicotver/src` |
| ダウンロードした Node.js（必要な場合のみ） | `~/Library/Application Support/nicotver/node` |

Chrome のフォルダ選択画面で ⌘+Shift+G を押し、`~/Library/Application Support/nicotver/extension` を貼り付けると、すぐにフォルダを選べます。

### 読み込みと更新

- はじめてのときは、下の「ブラウザへの読み込み」の手順で拡張機能フォルダを読み込んでください。
- 更新するときはインストーラーをもう一度実行し、拡張機能のページで nicotver の再読み込みボタン（↻）を押してから、TVer のページを再読み込みしてください。

### アンインストール

1. `chrome://extensions`（Edge は `edge://extensions`）で nicotver を削除します。
2. 次のフォルダを削除します。
   - Windows: `%LOCALAPPDATA%\nicotver`
   - Mac: `~/Library/Application Support/nicotver`

インストーラーはこのフォルダの外には何も作成・変更しません。

以下は、インストーラーを使わずに手動でビルドする場合の手順です。

## 動作確認した環境

| OS | Node.js | npm | ブラウザ |
| --- | --- | --- | --- |
| macOS（Apple Silicon） | v23.9.0（fnm） | 10.9.2 | ビルドのみ確認 |
| Windows | v22.23.3 LTS（公式 zip 版） | 10.9.9 | Google Chrome 155 で動作確認 |

## 必要なもの

- Node.js と npm
- Google Chrome または Microsoft Edge
- （任意）Git

## ソースの取得

Git を使う場合:

```sh
git clone https://github.com/zephel01/nicotver.git
cd nicotver
```

Git を使わない場合は、GitHub のリポジトリページで「Code」→「Download ZIP」を押してダウンロードし、任意のフォルダに展開してください。

## ビルドの前に知っておくこと

- **`npm install --ignore-scripts` を使ってください。** 依存パッケージの node-sass（v6）は、新しい Node.js ではネイティブビルドに失敗します（Node.js v23.9.0 で node-gyp のエラーを確認）。ビルドでは同梱の sass（dart-sass）が使われるので、node-sass のインストールスクリプトは実行しなくても問題ありません。
- **webpack 4 を使っているため、`NODE_OPTIONS=--openssl-legacy-provider` が必要です。** `npm run build` にはこの指定が含まれていますが、Mac/Linux のシェル向けの書き方なので Windows ではそのまま使えません。Windows では下記の PowerShell の手順でビルドしてください。

## ビルド（Mac）

Node.js が入っていない場合は、fnm や Homebrew などで導入してください。

```sh
cd nicotver
npm install --ignore-scripts
npm run build
```

`build/` フォルダに `manifest.json`、`nicotver.js` などが出力されれば成功です。

## ビルド（Windows）

1. Node.js を用意します。インストーラー版でも、公式サイト（https://nodejs.org/ ）の zip 版（`node-v22.x.x-win-x64.zip`）を展開したものでも構いません。zip 版なら管理者権限は不要です。
2. PowerShell で次を実行します。

```powershell
cd C:\path\to\nicotver

# zip 版の Node.js を使う場合のみ（展開したフォルダに合わせて変更）
$env:Path = "C:\path\to\node-v22.23.3-win-x64;" + $env:Path

npm install --ignore-scripts
$env:NODE_OPTIONS = '--openssl-legacy-provider'
node node_modules\webpack-cli\bin\cli.js --mode=production --config config\webpack.config.js
```

`build\` フォルダに `manifest.json`、`nicotver.js` などが出力されれば成功です。

## ブラウザへの読み込み

### Google Chrome

1. アドレスバーに `chrome://extensions` と入力して開く
2. 右上の「デベロッパー モード」をオンにする
3. 「パッケージ化されていない拡張機能を読み込む」を押す
4. ビルドで出力された `build` フォルダを選ぶ

### Microsoft Edge

1. アドレスバーに `edge://extensions` と入力して開く
2. 「開発者モード」をオンにする
3. 「展開して読み込み」を押す
4. ビルドで出力された `build` フォルダを選ぶ

## 使い方

1. TVer の再生ページ（`https://tver.jp/episodes/...`）を開くと、動画の下に nicotver の操作フォームが表示されます。表示されない場合はページを再読み込みしてください。
2. **チャンネル**と**開始日**は、TVer のページの放送局・放送日から自動で入力されます（例: TBS → jk6）。入力されない場合は手動で選んでください。
3. **開始時刻**には、地上波などで実際に放送された時刻を入力します。自動では入力されず、初期値は `00:00` です。
4. **番組時間**で、何分ぶんのコメントを取得するかを選びます（5〜180分、初期値は5分）。
5. 「コメント取得」を押し、「コメントを再生する準備が完了しました！」と表示されれば準備完了です。あとは普通に再生するとコメントが流れます。

### コメント時間オフセット

TVer と放送ではCMの入り方などが違うため、途中で映像とコメントがずれることがあります。その場合は次の方法でずれを調整します。

- 「コメント時間オフセット」の `-15` / `+15` ボタンを押す
- テキストボックスに秒数を直接入力する
- コメント一覧のコメントをクリックする（そのコメントが今表示されるように調整されます）

コメント一覧の「再生位置までスクロール」で現在位置のコメントへ、「A」「B」「C」ボタンでA/B/Cパートと思われる位置へスクロールできます。

## 更新

```sh
cd nicotver
git pull
```

その後、上記の手順でもう一度ビルドし、`chrome://extensions`（Edge は `edge://extensions`）で nicotver の再読み込みボタン（↻）を押してから、TVer のページを再読み込みしてください。

ZIP で取得した場合は、ZIP をダウンロードし直して展開し、ビルドし直してください。読み込んでいるフォルダの場所が変わった場合は、拡張機能を読み込み直してください。

## トラブルシューティング

### 「nicotverの初期化に失敗しました。」と表示される

- 操作フォームの挿入先（TVer の番組情報欄）が30秒以内に見つからないと表示されます。
- ビルドし直した後に拡張機能を再読み込みしていない場合、古いビルドが動いています。拡張機能のページで ↻ を押し、TVer のページを再読み込みしてください。
- 拡張機能のページで、読み込んでいるフォルダが今ビルドした `build` フォルダか確認してください。
- それでも出る場合は、TVer のページ構造がまた変わった可能性があります。

### コメントが0件、または別の番組のコメントが流れる

- 開始時刻が初期値の `00:00` のままになっていないか確認してください。開始時刻は実際の放送時刻を入力する必要があります。
- チャンネルと開始日が正しいか確認してください。
- コメント取得元はリアルタイムでコメントを収集しているわけではないので、直近の放送のコメントは取得できないことがあります。

### `npm install` が node-sass / node-gyp のエラーで失敗する

`npm install --ignore-scripts` でインストールし直してください（「ビルドの前に知っておくこと」を参照）。

### Windows で `npm run build` が失敗する

`npm run build` のスクリプトは Mac/Linux のシェル向けです。Windows では「ビルド（Windows）」の PowerShell のコマンドでビルドしてください。

## 注意事項

- TVer 側の変更により、再び動作しなくなる可能性があります。
- この fork は非公式の修正版です。この fork に関する問題を元の作者に問い合わせないでください。
- 元のリポジトリにはライセンスファイルがありません。
- コメントの取得元は個人の方が善意で運営しているサービスです。無用な負荷をかけないようにしてください。
