#!/usr/bin/env ruby

# file: mns_subscriber.rb


require 'sps-sub'
require "sqlite3"
require 'fileutils'
require 'daily_notices'


class MNSSubscriber < SPSSub

  def initialize(host: 'sps', port: 59000, dir: '.', options: {})
    
    # note: a valid url_base must be provided
    
    @options = {
      url_base: 'http://yourwebsitehere.co.uk/', 
      dx_xslt: '/xsl/dynarex.xsl', 
      rss_xslt: '/xsl/feed.xsl', 
      target_page: :page, 
      target_xslt: '/xsl/page.xsl'
    }.merge(options)

    super(host: host, port: port)
    @filepath = dir

  end

  def subscribe(topic='notice/*')
    super(topic)
  end

  private

  def ontopic(topic, msg)

    subtopic = topic.split('/').last
    puts "%s: %s %s"  % [topic, Time.now.to_s, msg.inspect]

    add_notice(subtopic, msg)

  end

  def add_notice(topic, msg)

    topic_dir = File.join(@filepath, topic)
    filename = File.join(topic_dir, 'feed.xml')

    db = SQLite3::Database.new File.join(topic_dir, topic + '.db')    
    
    unless File.exists? filename then

db.execute <<-SQL
  create table notices (
    ID INT PRIMARY KEY     NOT NULL,
    MESSAGE TEXT
  );
SQL
            
    end
   
    
    id = Time.now.to_i.to_s    

    notices = DailyNotices.new topic_dir, @options.merge(identifier: topic)
    notices.add msg, id: id

    db.execute("INSERT INTO notices (id, message) 
            VALUES (?, ?)", [id, msg])    
    
  end  

end