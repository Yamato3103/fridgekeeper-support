# スポットキーパー

行きたい場所を地図に登録し、訪れたら記録していく iOS アプリ。

- 地図: **MapKit**（API キー不要・費用ゼロ）
- 永続化: **SwiftData**
- 同期: **CloudKit** 私有DB
- 最小 OS: **iOS 17.0**

仕様書は別途 Artifact にまとめてある。この README はビルド手順のみ。

---

## 1. Xcode プロジェクトを用意する

`.xcodeproj` はリポジトリに含めていない。以下のどちらかで作る。

### A. XcodeGen で生成する（推奨・1分）

```sh
brew install xcodegen
cd spotkeeper
xcodegen generate
open SpotKeeper.xcodeproj
```

`project.yml` に Info.plist のキー（位置情報・写真の用途説明、`LSApplicationQueriesSchemes`）と
ビルド設定が入っているので、生成した時点でビルドが通る状態になる。

### B. Xcode で手動作成する

1. `File → New → Project → iOS → App`
   - Interface: **SwiftUI** / Language: **Swift** / Storage: **None**
2. Minimum Deployments を **iOS 17.0** に変更
3. `SpotKeeper/` 以下のフォルダを Xcode のナビゲータにドラッグ
   （Create groups ではなく **Create folder references を使わない**＝グループとして追加）
4. `project.yml` の `info.properties` にあるキーを Info に手で追加

---

## 2. 署名とバンドル ID

`project.yml` の `PRODUCT_BUNDLE_IDENTIFIER` は `com.example.spotkeeper` の仮値。
自分のドメインに書き換えてから、Xcode の Signing & Capabilities で Team を選ぶ。

冷蔵庫キーパーとは**別の新規バンドル ID** が必要。

---

## 3. iCloud 同期を有効にする

初回ビルドは**端末内保存のみ**で動くようにしてある。entitlement が無い状態で
CloudKit を有効にすると起動時に落ちるため、意図的に既定を off にしてある。

同期を入れるときは次の順で行う。

1. Signing & Capabilities で `iCloud` を追加 → **CloudKit** にチェック
2. コンテナを新規作成（`iCloud.com.〈自分のドメイン〉.spotkeeper`）
3. `Background Modes` を追加 → **Remote notifications** にチェック
4. `SpotKeeper/Models/SpotKeeperModelContainer.swift` の

   ```swift
   static let isCloudKitEnabled = false
   ```

   を `true` に変更

リリース前に CloudKit Console で Development → Production へ
**スキーマを Deploy** すること。これを忘れるとリリース版だけ同期しない。

---

## 4. 動作確認

DEBUG ビルドでは、データが1件も無いときにサンプルが入る（`SampleData.swift`）。
起動したら次を確認してほしい。

| 確認すること | 期待する挙動 |
|---|---|
| 地図タブ | 日本全体が表示され、5つのピンが state ごとに違う見た目で並ぶ |
| 高尾山 | グレーの中抜き（未訪問） |
| 金沢21世紀美術館 | アンバーの星（未訪問・優先） |
| 伏見稲荷大社 | 朱の塗り（訪問1回） |
| 道後温泉本館 | 朱の塗り＋リング＋「3」バッジ（常連） |
| ピンをタップ | 詳細シートが立ち上がる |
| チェックイン | ピンが灰→朱に 0.4 秒で切り替わり一度弾む |
| 道後温泉本館の訪問履歴 | 3件の訪問が**それぞれ別のメモ**を持って並ぶ |
| リストタブ | 未訪問／訪問済みで絞り込める |
| 記録タブ | 訪問のタイムラインと件数サマリー |

### スポットの登録4経路

右上の `+` から3つ、地図の長押しで1つ。いずれも最後は同じ登録画面に合流する。

| 経路 | 操作 | 確認すること |
|---|---|---|
| 検索 | `+` → 検索して追加 | 表示中の地図の周辺が優先されて候補が出る |
| 地図を長押し | 地図上を 0.45 秒長押し | 触覚フィードバックのあと登録画面が開く |
| Google マップ | `+` → URL から | 共有リンクを貼ると座標と店名が入る |
| 写真 | `+` → 写真から | 位置情報つきの写真を選ぶとその地点が入る |

登録画面では住所を自動取得する（`CLGeocoder` は登録時の1回だけ呼び、
結果は Place に保存して以後は再取得しない）。

Google マップの URL 取り込みは Google が公式にサポートする使い方ではないため、
将来 URL 形式が変わると座標を取り出せなくなる可能性がある。
失敗時は「地図を長押しして手で登録する」への逃げ道が出る。

### 訪問記録と写真

| 操作 | 期待する挙動 |
|---|---|
| チェックイン | 「記録しました」に変わり、下に「メモや写真を追加」が出る |
| そのまま閉じる | 日時だけの記録として残る（入力は強制しない） |
| 訪問履歴の行をタップ | 編集画面が開き、日時・メモ・評価・費用・同行者を直せる |
| 写真を追加 | サムネイルが履歴の行に並ぶ（1行あたり4枚まで、以降は +N 表示） |
| 写真を長押し | 削除メニュー。ファイルの実体も一緒に消える |
| 訪問を削除 | 紐づく写真のファイルも削除される |

写真の原寸は `Application Support/Photos/` に置き、SwiftData にはファイル名だけを持たせる。
同期対象になるのは長辺 512px のサムネイルのみ。

---

## 5. 現在の実装範囲

実装済み:

- データモデル 3つ（`Place` / `Visit` / `VisitPhoto`）と CloudKit 対応の `ModelContainer`
- 地図タブ、ピンの状態表示（5状態）、凡例、現在地
- スポット詳細シート、手動チェックイン、訪問履歴
- Apple マップ / Google マップへの経路案内の受け渡し
- リストタブ（絞り込み）、記録タブ（タイムライン）
- **スポットの登録4経路**（検索 / 地図長押し / Google マップ URL / 写真）と共通の登録画面
- 逆ジオコーディングによる住所・都道府県・市区町村の保存
- **訪問記録の編集**（日時・メモ・評価・費用・同行者）
- **写真の保存とサムネイル生成**（原寸はファイル、同期はサムネイルのみ）

未実装（次の段階）:

- 制覇マップ（都道府県47区分）
- エクスポート、設定画面
- Share Extension（Google マップから直接共有を受ける）

---

## ディレクトリ構成

```
SpotKeeper/
  App/        アプリのエントリポイントとタブ構成
  Models/     SwiftData モデル、ModelContainer、サンプルデータ
  Features/
    Map/      地図タブ、ピンの状態と描画
    AddPlace/ スポット登録の4経路と共通の登録画面
    Place/    スポット詳細シート
    Visit/    訪問記録の編集と評価
    List/     リストタブ
    Record/   記録タブ
  Support/    配色、現在地、逆ジオコーディング、写真の保管
  Resources/  Asset Catalog
```
