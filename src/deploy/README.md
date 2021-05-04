
## 参考：
* https://qiita.com/saongtx7/items/f36909587014d746db73#%E4%B8%8B%E6%BA%96%E5%82%99
* https://qiita.com/sibakenY/items/d81c1fa4ee1f41fee8d7#rails%E3%82%A2%E3%83%97%E3%83%AA%E3%81%AE%E4%BD%9C%E6%88%90
* https://qiita.com/t-fujiwara/items/835cccbef7ec6d199251#%E3%82%BB%E3%82%AD%E3%83%A5%E3%83%AA%E3%83%86%E3%82%A3%E3%82%B0%E3%83%AB%E3%83%BC%E3%83%97
* https://qiita.com/suin/items/19d65e191b96a0079417
* https://www.slideshare.net/yoshikikobayashi7/ecs-146889234

# 初期のrails newを実行
$ docker-compose run --rm app rails new . --database=mysql --skip-bundle --skip-test


config/database.ymlのdevelopmentの部分を下記の様に変更します。

```database.yml
development:
  <<: *default
  host: db
  username: myuser
  password: password
  database: ecs_development
```

置き換えた後

```
$ docker-compose up --build
```

## config/environments/development.rbに以下を追加
```
$ vi config/environments/development.rb
```

```
Rails.application.configure do
  config.hosts.clear #追加
```

##  socketファイルの置き場所を確保
```
$ mkdir -p tmp/sockets
```

## config/puma.rbを書き換え

```
  threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }.to_i
threads threads_count, threads_count
port        ENV.fetch("PORT") { 3000 }
environment ENV.fetch("RAILS_ENV") { "development" }
plugin :tmp_restart

app_root = File.expand_path("../..", __FILE__)
bind "unix://#{app_root}/tmp/sockets/puma.sock"

stdout_redirect "#{app_root}/log/puma.stdout.log", "#{app_root}/log/puma.stderr.log", true
```

## コンテナ起動

```
$ docker-compose up —build
```

## webpack install

```
$ docker-compose exec app rails webpacker:install
```


## pem

キーペアを作成した後に、chmodで権限変更する
```
$ chmod 400 rails-docker-webapp-keypair.pem
```

## ECSクラスター作成

```
# ローカルの~/.ecs/credentialsにecs-cliに使うprofileが保存される
$ ecs-cli configure --cluster rails-docker-webapp-cluster --default-launch-type EC2 --config-name rails-docker-webapp --region ap-northeast-1
$ ecs-cli configure profile --access-key AKIASV6KNBLON3WGCW5I --secret-key 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 --profile-name rails-docker-webapp

# ECS cluster作成コマンド
$ ecs-cli up --keypair rails-docker-webapp-keypair --capability-iam --size 1 --instance-type t2.micro --cluster-config rails-docker-webapp --ecs-profile rails-docker-webapp
```

参考ページ：
https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/cmd-ecs-cli-compose-up.html

## RDSの作成

awsのcliを使用できるように
~/.aws/credentialsに保存されている適切なprofileを選択する

まだ、profileがない場合はIAM作成、`$ aws configure --profile <profile name>`で新しくprofileを登録する

```
$ export AWS_PROFILE=iam-aws.yuks0810

```

### rds作成コマンド

* awsでぽちぽち作成
* 無料枠
* パブリックアクセスあり（後で変える予定）
* 新しいセキュリティグループ

インバウンドルールの変更：
新しく作成したRDSのセキュリティグループのインバウンドルールを変更してローカルから接続できるか確認する

全てのアクセスを許可する

そしたら、このようなコマンドでローカルから接続できるか確認する

```
$ mysql -h rails-docker-webapp-db.ckjsvhuzo8hi.ap-northeast-1.rds.amazonaws.com -u root -p
```

#### DBの作成

```
mysql> CREATE DATABASE ecs_development default character set utf8;
Query OK, 1 row affected (0.02 sec)

mysql> show databases;
+---------------------------------+
| Database                        |
+---------------------------------+
| information_schema              |
| ecs_development                 |
| innodb                          |
| mysql                           |
| performance_schema              |
| sys                             |
+---------------------------------+
6 rows in set (0.04 sec)
```

## database.ymlの修正
host,username,passwordを環境変数を見る様に修正します。

```
development:
  <<: *default
  host: <%= ENV['MYSQL_HOST'] %>
  username: <%= ENV['MYSQL_USER'] %>
  password: <%= ENV['MYSQL_PASSWORD'] %>
  database: ecs_development
```

## ALBの設定
Application Load Balancerを作成する。
（ロードバランサー作成時にHTTP, HTTPSとなっているやつ）

まず名前を入力します。

リスナーはそのままで大丈夫です。


vpcの設定ですがecsのec2インスタンスのvpcを選択しなくてはいけません。


### config/environment/development.rbの修正

rails6ではhost名を明示的に記載しないと起動しません。
なのでconfig/environment/development.rbに下記を追加します。

```development.rb
config.hosts << ALBのdns名を記載
# ex) config.hosts << "rails-docker-webapp-lb-1696474826.ap-northeast-1.elb.amazonaws.com"
```

## サービスの作成

クラスター一覧で先ほど作成したクラスターを選択します。
サービスという項目に作成ボタンがあるのでそちらをクリックします
