match "/migrations/*path" do
  Proxy.forward conn, path, "http://migrations/"
end
