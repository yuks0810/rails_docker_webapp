# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version
2.6.7

* Rails version
6.1.3

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## RUN
### 開発開始

初回のみbuildが必要

```
$ docker-compose up --build -d
```

初回以降buildが必要ない場合

```
$ docker-compose start
```

### docker-composeコマンド

コンテナの停止

```
$ docker-compose stop
```

コンテナの停止と削除

```
$ docker-compose down
```

コンテナの起動

```
$ docker-compose start
```

MySQLへの接続

```
$ docker-compose exec service_name mysql -u user_name -p [-D DB名]
```


## デプロイ
細かいことは書いていないので、一旦src/deploy/README.mdを参照

### buildとECRへのpush

nginx:
```
$ aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin 184571202268.dkr.ecr.ap-northeast-1.amazonaws.com
$ docker build -t nginx/rails-docker-webapp containers/nginx
$ docker tag nginx/rails-docker-webapp:latest 184571202268.dkr.ecr.ap-northeast-1.amazonaws.com/nginx/rails-docker-webapp:latest
$ docker push 184571202268.dkr.ecr.ap-northeast-1.amazonaws.com/nginx/rails-docker-webapp:latest
```

rails:
```
$ aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin 184571202268.dkr.ecr.ap-northeast-1.amazonaws.com
$ docker build -t rails/rails-docker-webapp .
$ docker tag rails/rails-docker-webapp:latest 184571202268.dkr.ecr.ap-northeast-1.amazonaws.com/rails/rails-docker-webapp:latest
$ docker push 184571202268.dkr.ecr.ap-northeast-1.amazonaws.com/rails/rails-docker-webapp:latest
```

### コンテナデプロイ

デプロイコマンド
```
$ ecs-cli compose -file docker-compose.production.yml --ecs-params ecs-params.yml up --cluster-config rails-docker-webapp --ecs-profile rails-docker-webapp
```

実行中のclusterのコンテナを確認
```
$ watch -n 0.5 ecs-cli ps --cluster rails-docker-webapp-cluster --region ap-northeast-1 --cluster-config rails-docker-webapp --ecs-profile rails-docker-webapp
```

使用するECRのイメージを変更したければ、`docker-compose.production.yml`の`image:`の部分を変更する。
