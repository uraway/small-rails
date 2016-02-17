React + Flux + Rails API

### バックエンド

[rails-api](https://github.com/rails-api/rails-api)

### フロントエンド

React

### Flux

バックエンド(Rails)とビュー(React)をつなぐフローアーキテクチャ

### *Small*

sign upとlog in, 投稿機能を実装した簡単なRailsアプリを作成する｡

### Rails API

```
rails new small
```

次に`rails-api`, `devise`, `active_model_serializers` gemを`Gemfile`に入れる｡　自動的に生成されたアセットは削除｡

```ruby
source 'https://rubygems.org'

gem 'rails', '4.2.0'
gem 'rails-api', '~> 0.4.0'
gem 'active_model_serializers', '~> 0.8.3' # NOTE: not the 0.9
gem 'devise', '~> 3.4.1'
gem 'sqlite3'
gem 'sdoc', '~> 0.4.0', group: :doc
gem 'thin'

group :development, :test do
  gem 'faker'
  gem 'byebug'
  gem 'web-console', '~> 2.0'
  gem 'spring'
end
```

ApplicationControllerを`ActionController::API`から継承し､ JSONを扱うようにします｡

`small/app/application_contrller`

```ruby
class ApplicationController < ActionController::API
  respond_to :json
end
```

`view`フォルダもいらないので削除します｡

### Authentication

ユーザーの認証には[Oauth2 Resource Owner Password Credential Grant](http://oauthlib.readthedocs.org/en/latest/oauth2/grants/password.html)を使用します｡　リクエストヘッダにトークンを付与してユーザーを認証します｡

`small`ディレクトリで`bundle install`後､　ユーザーモデルを作成します｡

```
rails generate devise:install
rails generate devise User
```

### Token authentication

認証に必要なトークン情報はトークンそれ自体とユーザーのIDから構成されます｡　例としてユーザーデータベースIDを使用します｡　まずはじめに`access_token`をユーザーに付与します｡

```ruby
class AddAccessTokenToUser < ActiveRecord::Migration
  def change
    add_column :users, :access_token, :string
    add_column :users, :username, :string
  end
end
```

Userモデル

```ruby
# app/models/user.rb
class User < ActiveRecord::Base
  devise :database_authenticatable, :recoverable, :validatable

  after_create :update_access_token!

  validates :username, presence: true
  validates :email, presence: true

  private

  def update_access_token!
    self.access_token = "#{self.id}:#{Devise.friendly_token}"
    save
  end

end
```

ユーザー認証部分

```ruby
# app/controllers_application_controller.rb
class ApplicationController < ActionController::API
  include AbstrucController::Translation

  before_action :authenticate_user_from_token!

  respond_to :json

  ##
  # User Authentication
  # Authenticates the user with OAuth2 Resource Owner Password Credentials Grant
  def authenticate_user_from_token!
    auth_token = request.headers['Authorization']

    if auth_token
      authenticate_with_auth_token auth_token
    else
      authentication_error
    end
  end

private

def authenticate_with_auth_token auth_token
  unless auth_token.include?(':')
    authentication_error
    return
  end

  user_id = auth_token.split(':').first
  user = User.where(id: user_id).first

  if user && Devise.secure_compare(user.access_token, auth_token)
    # User can access
    sign_in user, store: false
  else
    authentication_error
  end

  ##
  # Authentication Falilure
  # Rendera a 401 error
  def authentication_error
    # User's token is either invalid or not in the right format
    render json: {error: t('unauthorized')}, status: 401 # Authentication timeout
  end
end
```

認証プロセス

```ruby
# config/routes.rb
Rails.application.routes.draw do
  devise_for :user, only: []

  namespace :v1, defaults: { format: :json } do
    resource :login, only: [:create], controller: :sessions
  end
 end
 ```

 セッションコントローラー

 ```ruby
 # app/controllers/v1/sessions_controller.rb
 module V1
   class SessionsController < ApplicationController
     skip_before_action :authenticate_user_from_token!

     # POST /v1/login
     def create
       @user = User.find_for_database_authentication(email: params[:username])
       return invalid_login_attempt unless @user

       if @user.valid_password?(params[:password])
         sign_in :user, @user
         render json: @user, selializer: SessionSerializer, root: nil
       else
         invalid_login_attempt
       end
     end

     private

     def invalid_login_attempt
       warden.custom_failure!
       render json: {error: t('sessions_controller.invalid_login_attempt')}, status: :unprocessable_entity
     end

   end
 end
```

セッションセリアライザー

```ruby
# app/serializers/v1/session_serializer.rb
module V1
  class SesstionSerializer < ActiveModel::Serialzer

    attributes :email, :token_type, :user_id, :access_token

    def user_id
      object.id
    end

    def token_type
      'Bearer'
    end

  end
end
```

サーバーを実行(`rails server`)し､　コンソールからユーザーを作成｡

```
$ curl localhost:3000/v1/login --ipv4 --data "username=user@example.com&password=password"
```

### CORS

[rack-cors gem](https://github.com/cyu/rack-cors)

```ruby
# config/application.rb
config.middleware.insert_before 'Rack::Runtime', 'Rack::Cors' do
  allow do
    origins '*'
    resource '*',
            headers: :any,
            method: [:get, :put, :post, :patch, :delete, :options]
    end
end
```
