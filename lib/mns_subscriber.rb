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
    
    @index = nil

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
      
      subtopic, id = a[1..-1]
      add_notice(subtopic, msg, id)
      
    end    

  end

  def add_notice(topic, raw_msg, raw_id=Time.now)

    topic_dir = File.join(@filepath, topic)
    notices = DailyNotices.new topic_dir, @options.merge(identifier: topic, 
                                    title: topic.capitalize + ' daily notices')

    id = (raw_id || Time.now).to_i
    
    # strip out any JSON from the end of the message
    msg, raw_json = raw_msg.split(/(?=\{.*)/) 
    
    h = {
      description: MTLite.new(msg)
          .to_html(para: true, ignore_domainlabel:true),
      topic: topic
    }
    return_status = notices.add(item: h, id: id.to_s)
    
    return if return_status == :duplicate
    
    rxnotices = RecordxSqlite.new(File.join(topic_dir, 'notices.db'),
      table: {notices: {id: 0, message: ''}})
    rxnotices.create id: id.to_s, message: msg
    
    if raw_json then
      
      record = JSON.parse(raw_json)
      index = RecordxSqlite.new(File.join(topic_dir, 'index.db'),
        table: {items: record})
      index.create record
      
      update_index_xml(index, topic_dir)
      
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
      
      index = RecordxSqlite.new(indexdb, table: 'items')
      index.delete id
      update_index_xml(index, topic_dir)
    end
    
  end
  
  def update_index_xml(index, topic_dir)
                            
    # create the index.xml file
    
    a = index.order(:desc).first(15)
    a2 = a.map {|x| h = x.to_h; id = h.delete(:id); {item_id: id}.merge(h)}

    dx = Dynarex.new    
    dx.import a2
    dx.order ='descending'
    
    dx.save File.join(topic_dir, 'index.xml')    
    
  end

  def update_attributes(attribute, topic, value)
    
    topic_dir = File.join(@filepath, topic)
    notices = DailyNotices.new topic_dir, @options.merge(identifier: topic)
    notices.method((attribute.to_s + '=').to_sym).call(value)
    notices.save
  
  end

end