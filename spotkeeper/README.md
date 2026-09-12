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

---

## 5. 現在の実装範囲

実装済み:

- データモデル 3つ（`Place` / `Visit` / `VisitPhoto`）と CloudKit 対応の `ModelContainer`
- 地図タブ、ピンの状態表示（5状態）、凡例
- スポット詳細シート、手動チェックイン、訪問履歴
- Apple マップ / Google マップへの経路案内の受け渡し
- リストタブ（絞り込み）、記録タブ（タイムライン）

未実装（次の段階）:

- スポットの登録4経路（検索・地図長押し・Google マップから共有・写真から）
- 訪問記録の入力フォーム（メモ・評価・費用・同行者の編集）
- 写真の保存とサムネイル生成
- 制覇マップ（都道府県47区分）
- エクスポート、設定画面

---

## ディレクトリ構成

```
SpotKeeper/
  App/        アプリのエントリポイントとタブ構成
  Models/     SwiftData モデル、ModelContainer、サンプルデータ
  Features/
    Map/      地図タブ、ピンの状態と描画
    Place/    スポット詳細シート
    List/     リストタブ
    Record/   記録タブ
  Support/    配色などの共通定義
  Resources/  Asset Catalog
```
