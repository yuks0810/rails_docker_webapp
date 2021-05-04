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
