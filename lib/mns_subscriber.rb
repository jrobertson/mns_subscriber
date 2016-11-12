#!/usr/bin/env ruby

# file: mns_subscriber.rb


require 'sps-sub'
require 'dynarex'
require "sqlite3"
require 'fileutils'


class MNSSubscriber < SPSSub

  def initialize(host: 'sps', port: 59000, dir: '.', timeline_xsl: nil)

    super(host: host, port: port)
    @filepath, @timeline_xsl = dir, timeline_xsl

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
    filename = File.join(topic_dir, topic + '.xml')

    db = SQLite3::Database.new File.join(topic_dir, topic + '.db')    
    
    dx = if File.exists? filename then

      Dynarex.new(filename)
      
      
    else

      FileUtils.mkdir_p File.dirname(filename)
      dx = Dynarex.new('notices[identity]/notice(message)')
      dx.identity = topic
      dx.xslt = @timeline_xsl if @timeline_xsl
      
      
db.execute <<-SQL
  create table notices (
    ID INT PRIMARY KEY     NOT NULL,
    MESSAGE TEXT
  );
SQL

      dx

    end
    
    id = Time.now.to_i
    dx.create message: msg, id: id
    
    dx.save filename
    puts "%s: saved file %s" % [Time.now, filename]

    db.execute("INSERT INTO notices (id, message) 
            VALUES (?, ?)", [id, msg])    
    
  end  

end

