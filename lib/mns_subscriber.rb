#!/usr/bin/env ruby

# file: mns_subscriber.rb


require 'mtlite'
require 'sps-sub'
require 'daily_notices'
require 'recordx_sqlite'


class MNSSubscriber < SPSSub

  def initialize(host: 'sps', port: 59000, dir: '.', options: {}, 
                 timeline: nil)
    
    # note: a valid url_base must be provided
    
    @options = {
      url_base: 'http://yourwebsitehere.co.uk/', 
      dx_xslt: '/xsl/dynarex.xsl', 
      rss_xslt: '/xsl/feed.xsl', 
      target_page: :page, 
      target_xslt: '/xsl/page.xsl'      
    }.merge(options)

    super(host: host, port: port)
    @filepath, @timeline = dir, timeline

  end

  def subscribe(topic='notice/*')
    super(topic)
  end

  private

  def ontopic(topic, msg)

    a = topic.split('/')
    puts "%s: %s %s"  % [topic, Time.now.to_s, msg.inspect]
    
    
    case a.last.to_sym
      
    when :profile
          
      update_attributes(:description, subtopic=a[-2], profile=msg)

    when :link
          
      update_attributes(:link, subtopic=a[-2], link=msg)
      
    when :title
          
      update_attributes(:title, subtopic=a[-2], title=msg)
      
    when :delete
      
      delete_notice(subtopic=a[-2], msg)
      
    else
      
      subtopic = a.last
      add_notice(subtopic, msg)
      
    end    

  end

  def add_notice(topic, raw_msg)

    topic_dir = File.join(@filepath, topic)
    notices = DailyNotices.new topic_dir, @options.merge(identifier: topic, 
                                    title: topic.capitalize + ' daily notices')

    id = Time.now.to_i
    
    # strip out any JSON from the end of the message
    msg, raw_json = raw_msg.split(/(?=\{.*)/) 
    
    h = {
      description: MTLite.new(msg).to_html,
      topic: topic
    }
    return_status = notices.add(item: h, id: id.to_s)
    
    return if return_status == :duplicate
    
    notices = RecordxSqlite.new(File.join(topic_dir, 'notices.db'),
      table: {notices: {id: 0, message: ''}})
    notices.create id: id.to_s, message: msg
    
    if raw_json then
      
      record = {id: id}.merge(JSON.parse(raw_json))
      index = RecordxSqlite.new(File.join(topic_dir, 'index.db'),
        table: {items: record})
      index.create record
      
    end
    
    self.notice "%s/add: %s/status/%s"  % [@timeline, topic, id] if @timeline
    
    sleep 0.3
    
  end
  
  def delete_notice(topic, msg)
    
    topic_dir = File.join(@filepath, topic)
    
    notices = RecordxSqlite.new(File.join(topic_dir, 'notices.db'), 
                                table: 'notices')
    id = msg.to_i
    notices.delete id
    
    indexdb = File.join(topic_dir, 'index.db')
    
    if File.exists? indexdb then
      
      RecordxSqlite.new(indexdb, table: 'items').delete id
      
    end
    
  end

  def update_attributes(attribute, topic, value)
    
    topic_dir = File.join(@filepath, topic)
    notices = DailyNotices.new topic_dir, @options.merge(identifier: topic)              
    notices.method((attribute.to_s + '=').to_sym).call(value)
    notices.save
  
  end

end