
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
