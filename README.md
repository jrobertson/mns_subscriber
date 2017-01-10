# Introducing the MyNotificationsSubscriber gem


This example listens for an SPS topic which contains a notice e.g. 'notice/weather' and publishes a microblog entry to the specified file directory.

    require 'mns_subscriber'


    options = {
      url_base: 'http://www.jamesrobertson.eu/', 
      dx_xslt: '/xsl/dynarex-b.xsl', 
      rss_xslt: '/xsl/feed.xsl', 
      target_page: :page, 
      target_xslt: '/tmp/page.xsl'
    }

    mnss = MNSSubscriber.new(host: 'sps', port: 59000, 
      dir: '/home/james/jamesrobertson.eu/notices', options: options)
    mnss.subscribe topic: 'notice/*'

Note: If a new kind of notice is received the system will automatically create a new microblog feed for it.

## Resources

* mns_subscriber https://rubygems.org/gems/mns_subscriber

mns_subscriber sps notices feed microblog
