
# ローカルのDocker上でrailsアプリを準備

## 初期のrails newを実行
すでに既存のrailsアプリがあればこの工程は必要ない。

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

置き換えた後に以下を実行

```
$ docker-compose up --build
```

## config/environments/development.rbに以下を追加

```
$ vi config/environments/development.rb
```

```
Rails.application.configure do
  config.hosts.clear #追加（本番環境にデプロイするときはIPに書き換える）
```

##  socketファイルの置き場所を確保

railsとnginxがtmp/sockets/puma.sockを介して通信する

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

# AWSでECSにデプロイする工程

## キーペアの作成
sshでECSのEC2インスタンスに接続するのに必要なためキーペアを作成

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
* https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/cmd-ecs-cli-compose-up.html

## RDSの作成

awsのcliを使用できるように
~/.aws/credentialsに保存されている適切なprofileを選択する

まだ、profileがない場合はIAM作成、`$ aws configure --profile <profile name>`で新しくprofileを登録する

```
$ export AWS_PROFILE=iam-aws.yuks0810
```
profileが複数ある場合は↑を実行した後に、aws cliコマンドを実行する

### rds作成コマンド

* awsでぽちぽち作成
* 無料枠
* パブリックアクセスあり（後で変える予定）
* 新しいセキュリティグループを作成してRDSに紐付ける
  * このセキュリティグループは3306ポートにアクセスできるように設定する

インバウンドルールの変更：
新しく作成したRDSのセキュリティグループのインバウンドルールを変更してローカルから接続できるか確認する

全てのアクセスを許可する

そしたら、このようなコマンドでローカルから接続できるか確認する

```
$ mysql -h rails-docker-webapp-db.ckjsvhuzo8hi.ap-northeast-1.rds.amazonaws.com -u root -p
```

※この設定では全てのネットワークから接続できるようになってしまうので、後で設定を変更してインバウンドを絞り込む

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

## clusterにデプロイ

デプロイコマンド
```
$ ecs-cli compose -file docker-compose.production.yml --ecs-params ecs-params.yml up --cluster-config rails-docker-webapp --ecs-profile rails-docker-webapp
```

実行中のclusterのコンテナを確認
```
$ watch -n 0.5 ecs-cli ps --cluster rails-docker-webapp-cluster --region ap-northeast-1 --cluster-config rails-docker-webapp --ecs-profile rails-docker-webapp

Name                                                              State    Ports                          TaskDefinition          Health
rails-docker-webapp-cluster/25e215df68a544ff860ade0a575bd600/app  RUNNING  52.199.135.254:3000->3000/tcp  rails_docker_webapp:21  UNKNOWN
rails-docker-webapp-cluster/25e215df68a544ff860ade0a575bd600/web  RUNNING  52.199.135.254:80->80/tcp      rails_docker_webapp:21  UNKNOWN
rails-docker-webapp-cluster/a4f469986ab04fc9bb5fcb4644d9d322/app  RUNNING  18.183.196.217:3000->3000/tcp  rails_docker_webapp:22  UNKNOWN
rails-docker-webapp-cluster/a4f469986ab04fc9bb5fcb4644d9d322/web  RUNNING  18.183.196.217:80->80/tcp      rails_docker_webapp:22  UNKNOWN
```

### メモリ不足エラー

こんな感じのエラーが出たのでメモリーを制限してタスクを実行して対応

```
bapp --ecs-profile rails-docker-webapp 
INFO[0022] Using ECS task definition                     TaskDefinition="rails_docker_webapp:3"
INFO[0022] Auto-enabling ECS Managed Tags               
INFO[0022] Couldn't run containers                       reason="RESOURCE:MEMORY"
```

#### メモリ制御
mem_limitを使って
mem_limit: 268435456 # byte
のように書くと良い。というのが載っていたのだが、docker-compose.ymlのversino3では、この書き方はサポートされておらず
ecs_params.ymlを使って指定しないとだめらしい。

mem_limit参考ドキュメント：
* https://t-kuni-tech.com/2020/10/17/ecs%E3%81%AEdocker-compose%E3%81%AE%E3%83%8F%E3%83%9E%E3%82%8A%E3%83%9D%E3%82%A4%E3%83%B3%E3%83%88%E3%81%BE%E3%81%A8%E3%82%81/
* 公式サイト：
  * https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/cmd-ecs-cli-compose-ecsparams.html
  * https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/cmd-ecs-cli-compose-parameters.html
  * https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/cmd-ecs-cli-compose-ecsparams.html

最終的にはecs-params.ymlファイルにリミットを記述して、実行コマンドでecs-params.ymlを使うことを引数で指定することで解決
clusterのデプロイコマンドの中でこのような引数で指定する

```
--ecs-params ecs-params.yml
```

ecs-params.ymlの内容

```ecs-params.yml
version: 1
task_definition:
  task_size:
    cpu_limit: "256"
    mem_limit: "512"
  service:
    app:
      mem_limit: 250
      docker_volumes:
        - name: tmp-data
          scope: shared
          autoprovision:  true
          driver: local
          labels:
              string: tmp-data
        - name: public-data
          scope: shared
          autoprovision:  true
          driver: local
          labels:
              string: public-data
    nginx:
      mem_limit: 250
      docker_volumes:
        - name: tmp-data
          scope: shared
          autoprovision:  true
          driver: local
          labels:
              string: tmp-data
        - name: log-data
          scope: shared
          autoprovision:  true
          driver: local
          labels:
              string: log-data
        - name: public-data
          scope: shared
          autoprovision:  true
          driver: local
          labels:
              string: public-data
```

## volumeの指定

docker_volumes: をecs-params.ymlの中で指定して、volumeをタスク定義に組み込む
（ecs-params.yml参照）


その後再度clusterデプロイ実行

```
$ ecs-cli compose -file docker-compose.production.yml --ecs-params ecs-params.yml up --cluster-config rails-docker-webapp --ecs-profile rails-docker-webapp
WARN[0000] Skipping unsupported YAML option for service...  option name=depends_on service name=web
INFO[0026] Using ECS task definition                     TaskDefinition="rails_docker_webapp:12"
INFO[0026] Auto-enabling ECS Managed Tags               
INFO[0027] Starting container...                         container=rails-docker-webapp-cluster/96eefca34f34444d86d918788281b9ee/app
INFO[0027] Starting container...                         container=rails-docker-webapp-cluster/96eefca34f34444d86d918788281b9ee/web
INFO[0027] Describe ECS container status                 container=rails-docker-webapp-cluster/96eefca34f34444d86d918788281b9ee/web desiredStatus=RUNNING lastStatus=PENDING taskDefinition="rails_docker_webapp:12"
INFO[0027] Describe ECS container status                 container=rails-docker-webapp-cluster/96eefca34f34444d86d918788281b9ee/app desiredStatus=RUNNING lastStatus=PENDING taskDefinition="rails_docker_webapp:12"
INFO[0051] Started container...                          container=rails-docker-webapp-cluster/96eefca34f34444d86d918788281b9ee/web desiredStatus=RUNNING lastStatus=RUNNING taskDefinition="rails_docker_webapp:12"
INFO[0051] Started container...                          container=rails-docker-webapp-cluster/96eefca34f34444d86d918788281b9ee/app desiredStatus=RUNNING lastStatus=RUNNING taskDefinition="rails_docker_webapp:12"
```

### 今回参考にしたECS参考ドキュメント：
* [初心者でもできる！ ECS × ECR × CircleCIでRailsアプリケーションをコンテナデプロイ](https://qiita.com/saongtx7/items/f36909587014d746db73)
* [(ECS,Rails6)ロードバランサー ALB と データベース RDS とECRを使ってコマンドラインから ECSにRails6のアプリをデプロイ](https://qiita.com/sibakenY/items/d81c1fa4ee1f41fee8d7)
*[AWS CLIでよく使うコマンド集](https://qiita.com/t-fujiwara/items/835cccbef7ec6d199251)
* [《滅びの呪文》Docker Composeで作ったコンテナ、イメージ、ボリューム、ネットワークを一括完全消去する便利コマンド](https://qiita.com/suin/items/19d65e191b96a0079417)
* [ニワトリでもわかるECS入門](https://www.slideshare.net/yoshikikobayashi7/ecs-146889234)
* [【図解】Dockerの全体像を理解する -前編-](https://qiita.com/etaroid/items/b1024c7d200a75b992fc)
