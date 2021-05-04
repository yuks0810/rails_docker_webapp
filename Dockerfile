FROM node:13.5-alpine as node

RUN apk add --no-cache bash curl && \
    curl -o- -L https://yarnpkg.com/install.sh | bash -s -- --version 1.21.1


FROM ruby:2.6.5-alpine

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /opt/yarn-* /opt/yarn
RUN ln -fs /opt/yarn/bin/yarn /usr/local/bin/yarn
RUN apk update
RUN apk add --no-cache git build-base libxml2-dev libxslt-dev postgresql-dev postgresql-client tzdata bash less curl&& \
    cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
# RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
# RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

RUN apk add --no-cache alpine-sdk \
    mysql-client \
    mysql-dev

ENV APP_ROOT /webapp
RUN mkdir $APP_ROOT
WORKDIR $APP_ROOT

RUN gem update --system && \
    gem install --no-document bundler:2.1.4

ADD Gemfile $APP_ROOT/Gemfile
ADD Gemfile.lock $APP_ROOT/Gemfile.lock

RUN bundle install

# ホストのアプリケーションディレクトリ内をすべてコンテナにコピー
COPY . $APP_ROOT
EXPOSE 3000

# puma.sockを配置するディレクトリを作成
RUN mkdir -p tmp/sockets

CMD ["rails", "server", "-b", "0.0.0.0"]


# FROM ruby:2.6.5

# # リポジトリを更新し依存モジュールをインストール
# RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
# RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
# RUN apt-get update -qq && \
#     apt-get install -y  nodejs \
#                         libpq-dev \
#                         vim \
#                         git \
#                         yarn \
#                         default-mysql-client

# # ルート直下にwebappという名前で作業ディレクトリを作成（コンテナ内のアプリケーションディレクトリ）
# RUN mkdir /webapp
# WORKDIR /webapp

# # ホストのGemfileとGemfile.lockをコンテナにコピー
# COPY Gemfile /webapp/Gemfile
# COPY Gemfile.lock /webapp/Gemfile.lock

# # bundle installの実行
# RUN bundle install
# RUN rails webpacker:install && rails webpacker:compile

# # ホストのアプリケーションディレクトリ内をすべてコンテナにコピー
# COPY . /webapp

# EXPOSE 3000

# # puma.sockを配置するディレクトリを作成
# RUN mkdir -p tmp/sockets

# CMD ["rails", "server", "-b", "0.0.0.0"]
