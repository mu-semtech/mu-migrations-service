# see https://github.com/mu-semtech/mu-ruby-template for more info
get '/' do
  content_type 'application/json'
  { data: { attributes: { hello: 'world' } } }
end
