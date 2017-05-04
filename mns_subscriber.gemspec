Gem::Specification.new do |s|
  s.name = 'mns_subscriber'
  s.version = '0.3.0'
  s.summary = "Creates microblog posts from different identities by " +  \
                "subscribing to the SPS topic 'notices/*' by default."
  s.authors = ['James Robertson']
  s.files = Dir['lib/mns_subscriber.rb']
  s.add_runtime_dependency('mtlite', '~> 0.3', '>=0.3.2')  
  s.add_runtime_dependency('sps-sub', '~> 0.3', '>=0.3.3')  
  s.add_runtime_dependency('sqlite3', '~> 1.3', '>=1.3.12')
  s.add_runtime_dependency('daily_notices', '~> 0.4', '>=0.4.3')
  
  s.signing_key = '../privatekeys/mns_subscriber.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/mns_subscriber'
end
