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

    a = topic.split('/')
    puts "%s: %s %s"  % [topic, Time.now.to_s, msg.inspect]
    
    
    case a.last
      
    when 'profile'
          
      update_attributes(:description, subtopic=a[-2], profile=msg)

    when 'link'
          
      update_attributes(:link, subtopic=a[-2], link=msg)
      
    when 'title'
          
      update_attributes(:title, subtopic=a[-2], title=msg)
      
    else
      
      subtopic = a.last
      add_notice(subtopic, msg)
      
    end    

  end

  def add_notice(topic, msg)

    topic_dir = File.join(@filepath, topic)
    notices = DailyNotices.new topic_dir, @options.merge(identifier: topic)
        
    id = Time.now.to_i.to_s

    return_status = notices.add msg, id: id
    
    return if return_status == :duplicate

    dbfilename = File.join(topic_dir, topic + '.db')
    
    if File.exists? dbfilename then

      db = SQLite3::Database.new dbfilename   
      
    else

      db = SQLite3::Database.new dbfilename   
      
db.execute <<-SQL
  create table notices (
    ID INT PRIMARY KEY     NOT NULL,
    MESSAGE TEXT
  );
SQL
            
    end
    
  
    db.execute("INSERT INTO notices (id, message) 
            VALUES (?, ?)", [id, msg])    
    
    self.notice "timeline/add: %s/status/%s"  % [topic, id] 
    
    sleep 1.5
    
  end

  def update_attributes(attribute, topic, value)
    
    topic_dir = File.join(@filepath, topic)
    notices = DailyNotices.new topic_dir, @options.merge(identifier: topic)              
    notices.method((attribute.to_s + '=').to_sym).call(value)
    notices.save
  
  end

end