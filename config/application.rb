# config/application.rb
config.middleware.insert_before 'Rack::Runtime', 'Rack::Cors' do
  allow do
    origins '*'
    resource '*',
            headers: :any,
            method: [:get, :put, :post, :patch, :delete, :options]
    end
end
