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
