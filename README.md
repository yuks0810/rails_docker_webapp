# rails_docker_webapp

参考：
https://qiita.com/eighty8/items/0288ab9c127ddb683315


## RUN

```
$ vim environments/db.env
```

db.envに下記の内容を書く。（それぞれの値は適宜変更）
```
MYSQL_ROOT_PASSWORD=<db root password>
MYSQL_USER=<db user name>
MYSQL_PASSWORD=<db user password>
```

### rails new

```
$ docker-compose run --rm app rails new . --force --database=mysql --skip-bundle --webpack=vue
```

## 権限の変更

生成されたRailsアプリの所有権が root:root となっているので（Dockerの操作は基本すべてroot権限で実行されるため）、現在のログインユーザーに変更しておきます。

どちらかを実行

```
$ sudo chown -R $USER:$USER .
OR
$ sudo chown -R $USER: .
```

## puma.rb の編集

```
$ cp environments/puma.rb config/puma.rb
```

## database.yml編集

```
$ cp environments/database.template.yml config/database.yml
```

```database.yml
default: &default
  adapter: mysql2
  encoding: utf8
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  username: <%= ENV.fetch('MYSQL_USER') { 'root' } %>
  password: <%= ENV.fetch('MYSQL_PASSWORD') { 'password' } %>
  host: db

development:
  <<: *default
  database: webapp_development

test:
  <<: *default
  database: webapp_test
```
  
## docker build

```
$ docker-compose up --build
```

## DBの設定

ユーザー作成
```
$ docker-compose exec db mysql -u root -p -e"$(cat db/grant_user.sql)"
```

ユーザーが作成できたかを確認
```
$ docker-compose exec db mysql -u user_name -p -e"show grants;"
```

dbの作成

```
$ docker-compose exec app rails db:create
```

以上の作業が終わったら、localhostにアクセスするとWelcomeページが見れる
http://localhost
http://localhost:80
