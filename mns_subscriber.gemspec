Gem::Specification.new do |s|
  s.name = 'mns_subscriber'
  s.version = '0.1.0'
  s.summary = "Creates microblog posts from different identities by " +  \
                "subscribing to the SPS topic 'notices/*' by default."
  s.authors = ['James Robertson']
  s.files = Dir['lib/mns_subscriber.rb']
  s.add_runtime_dependency('sps-sub', '~> 0.4', '>=0.4.3')
  s.add_runtime_dependency('dynarex', '~> 1.7', '>=1.7.15')
  s.add_runtime_dependency('sqlite3', '~> 1.3', '>=1.3.12')
  s.signing_key = '../privatekeys/mns_subscriber.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@r0bertson.co.uk'
  s.homepage = 'https://github.com/jrobertson/mns_subscriber'
end
