Gem::Specification.new do |s|
  s.name = 'mns_subscriber'
  s.version = '0.4.9'
  s.summary = "Creates microblog posts from different identities by " +  \
                "subscribing to the SPS topic 'notices/*' by default."
  s.authors = ['James Robertson']
  s.files = Dir['lib/mns_subscriber.rb']
  s.add_runtime_dependency('mtlite', '~> 0.3', '>=0.3.4')
  s.add_runtime_dependency('sps-sub', '~> 0.3', '>=0.3.5')
  s.add_runtime_dependency('daily_notices', '~> 0.6', '>=0.6.2')
  s.add_runtime_dependency('recordx_sqlite', '~> 0.2', '>=0.2.6')
  s.signing_key = '../privatekeys/mns_subscriber.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/mns_subscriber'
end
