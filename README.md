# Terraform で構築する AWS サーバーレス Web 環境（Lambda 構成）

研究ゼミで取り組んでいる AWS 学習プロジェクトの第 3 段階です。SSH と踏み台サーバーを使う構成から SSM Session Manager による EC2 管理へ移行した後、AWS Lambda と API Gateway を使って商品データを返す構成に発展させました。

## 目次

- [研究の流れ](#研究の流れ)
- [概要](#概要)
- [主要技術](#主要技術)
- [システム構成](#システム構成)
- [Lambda の処理](#lambda-の処理)
- [ディレクトリ構成](#ディレクトリ構成)
- [必要環境](#必要環境)
- [セットアップ](#セットアップ)
- [セキュリティとコストに関する注意](#セキュリティとコストに関する注意)
- [次の取り組み：PicCaption](#次の取り組みpiccaption)

## 研究の流れ

1. **SSH 構成** — 踏み台サーバーを経由して EC2 を SSH で管理します。
2. **SSM 構成** — [SSM プロジェクト](../ssm/README.md)で、Session Manager を使い、SSH ポートや踏み台サーバーを使わずに EC2 を管理します。
3. **Lambda 構成（本プロジェクト）** — API Gateway と Lambda を使って商品データを返し、EC2 上で Web アプリケーションを実行する方式からサーバーレス構成へ発展させます。

SSH のプロジェクトは [こちら](../ssh/README.md) です。SSH から SSM への移行でサーバー管理方法を比較し、本プロジェクトではさらにアプリケーションの実行方式を拡張します。

## 概要

Terraform で AWS のネットワーク、RDS for MySQL、Lambda 関数、HTTP API を構築します。Lambda 関数は VPC 内から RDS に接続し、`GET /products` リクエストに対して商品一覧を HTML で返します。

## 主要技術

- **AWS** — VPC、Public / Private subnet、Internet Gateway、NAT Gateway、RDS for MySQL、Lambda、API Gateway HTTP API
- **Terraform** — AWS リソースの定義・作成・削除
- **Python 3.12** — Lambda 関数の実行環境
- **PyMySQL** — Lambda から MySQL に接続するライブラリ

このプロジェクトの Lambda は Python で実装されています。SSH / SSM プロジェクトの PHP 実行環境とは異なり、ローカルの PHP バージョン更新はこの Lambda の実行環境に影響しません。

## システム構成

![AWS Lambda 商品 API の構成図](./architecture.svg)

※図は Terraform の現行設定に合わせた構成図です。編集可能な draw.io ファイルは [`architecture.drawio`](./architecture.drawio) です。

- リージョンは Terraform の変数 `region` で指定します。既定値は `us-east-1` です。
- Lambda は `us-east-1a` / `us-east-1b` の Private subnet に接続します。
- RDS は `us-east-1a` に 1 台作成し、Public access を無効にします。DB subnet group には複数 AZ の subnet が含まれます。
- RDS のポート 3306 への inbound は Lambda 用 Security Group からに制限されています。
- API Gateway の `$default` stage は自動デプロイされます。

## Lambda の処理

1. API Gateway から `GET /products` リクエストを受け取ります。
2. Lambda が環境変数の接続情報を使って RDS に接続します。
3. `lambda/index.py` 内の SQL で `products` テーブルを削除・再作成し、サンプル商品を挿入します。
4. 商品一覧を取得して HTML テーブルにし、HTTP レスポンスとして返します。

> **重要:** 現在の実装はリクエストのたびに `DROP TABLE` を実行して商品データを作り直します。既存データを保持する用途や本番環境には適しません。データ初期化は Lambda の読み取りリクエストから分離する必要があります。

## ディレクトリ構成

```text
.
├── architecture.drawio
├── architecture.svg
├── database/
│   └── init.sql
├── lambda/
│   ├── index.py
│   └── init.sql
└── terraform/
    ├── main.tf
    ├── outputs.tf
    └── variables.tf
```

`lambda/` には Lambda のコードとデプロイ対象の PyMySQL ライブラリが含まれます。`database/init.sql` と `lambda/init.sql` は DB 初期化用の SQL ですが、現在の Lambda コードは SQL ファイルを読み込まず、初期化 SQL を `index.py` 内に定義しています。

## 必要環境

- AWS アカウントと Terraform リソースを作成できる IAM 権限
- [Terraform](https://developer.hashicorp.com/terraform/install)
- AWS CLI と設定済みの AWS 認証情報
- Python 3.12（Lambda のローカルテストやコード確認を行う場合）

## セットアップ

1. Terraform のディレクトリへ移動します。

   ```bash
   cd terraform
   ```

2. `terraform.tfvars` を作成し、RDS のパスワードを設定します。

   ```hcl
   db_password = "REPLACE_WITH_A_STRONG_DATABASE_PASSWORD"
   ```

   `terraform.tfvars` は Git 管理対象外です。実際のパスワードを README やソースコードに記載しないでください。

3. Terraform を初期化し、構成を確認します。

   ```bash
   terraform init
   terraform validate
   terraform plan
   ```

4. AWS リソースを作成する場合は、plan の内容と利用料金を確認してから実行します。

   ```bash
   terraform apply
   ```

`terraform apply` 後、HTTP API の URL は次のコマンドで確認できます。

```bash
terraform output api_gateway_url
```

ブラウザーまたは HTTP クライアントで、出力された URL にアクセスします。

```text
<api_gateway_url>
```

作成したリソースを削除する場合：

```bash
terraform destroy
```

## セキュリティとコストに関する注意

- `terraform.tfvars`、Terraform state、AWS 認証情報、秘密情報を Git に追加しないでください。
- Terraform の `sensitive = true` は値を state から取り除く設定ではありません。state には RDS パスワードなどの機密値が含まれるため、安全に保管してください。
- 現在の Terraform は RDS のパスワードを Lambda の環境変数に渡します。本番利用では Secrets Manager などを使った管理を検討してください。
- Lambda はデータベース接続エラーや SQL エラーの詳細をレスポンス本文に含める実装です。公開環境に使う前に、利用者へ詳細な内部エラーを返さないよう変更してください。
- NAT Gateway、RDS、Lambda、API Gateway などは利用料金が発生します。リソースを作成する前に費用を確認し、検証後は不要なリソースを削除してください。

## 次の取り組み：PicCaption

この Lambda の学習を発展させ、画像にキャプションを付けるアプリケーション「PicCaption」に取り組みました。日報に記録した主な機能は次のとおりです。

- フロントエンドから画像をアップロードし、API Gateway 経由で Lambda を実行
- アップロードした画像を S3 に保存し、画像に関するデータを DynamoDB に保存
- EventBridge を使って画像処理用 Lambda を起動し、Amazon Bedrock で画像キャプションを生成
- Amazon Cognito によるユーザー登録・ログインと、登録時のメールアドレス確認
